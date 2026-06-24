import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layouts/login_layout.dart';
import '../models/ranking.dart';
import '../models/user_profile.dart';
import '../repositories/quiz_repository.dart';
import '../repositories/season_repository.dart';
import '../repositories/user_repository.dart';
import '../utils/api_error_utils.dart';

enum RankingFilter { all, week, nearby }

const currentSeasonId = 'current';

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  return RankingRepository(
    ref.watch(dioProvider),
    ref.watch(seasonRepositoryProvider),
    ref.watch(quizRepositoryProvider),
    ref.watch(userRepositoryProvider),
  );
});

class RankingRepository {
  final Dio _dio;
  final SeasonRepository _seasonRepository;
  final QuizRepository _quizRepository;
  final UserRepository _userRepository;

  RankingRepository(
    this._dio,
    this._seasonRepository,
    this._quizRepository,
    this._userRepository,
  );

  Future<List<SeasonOption>> fetchSeasonTabs() {
    return _seasonRepository.fetchSeasonTabs();
  }

  Future<UserProfile> fetchMyProfile() async {
    return fetchMyRankForSeason(currentSeasonId);
  }

  Future<UserProfile> fetchMyRankForSeason(String? seasonId) async {
    try {
      final response = await _dio.get(_myRankPath(seasonId));
      return _resolveMyProfile(seasonId, response.data);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '내 랭킹을 불러오지 못했습니다.'),
      );
    }
  }

  Future<List<RankingEntry>> fetchTop3({String? seasonId}) async {
    try {
      final response = await _dio.get(_top3Path(seasonId));
      return _extractRankingEntries(response.data);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: 'TOP3 랭킹을 불러오지 못했습니다.'),
      );
    }
  }

  Future<RankingPageData> fetchRankings({
    String? seasonId,
    RankingFilter filter = RankingFilter.all,
    List<SeasonOption>? seasons,
  }) async {
    try {
      final results = await Future.wait([
        _dio.get(_rankingsPath(seasonId)),
        _dio.get(_myRankPath(seasonId)),
        _dio.get(_top3Path(seasonId)),
      ]);

      UserProfile? meProfile;
      try {
        meProfile = await _userRepository.fetchMe();
      } catch (_) {}

      final listEntries = _extractRankingEntries(results[0].data);
      final myProfile = await _resolveMyProfile(seasonId, results[1].data);
      final parsedMyRank = _parseMyRankEntry(results[1].data);
      final top3 = _extractRankingEntries(results[2].data);
      final entries = _applyMeProfileToEntries(
        _mergeEntries(listEntries, top3),
        meProfile,
      );
      final myRank = _buildMyRankEntry(myProfile, parsedMyRank, meProfile);
      final resolvedSeasons = seasons ??
          _extractSeasonsFromResponse(results[0].data);

      return RankingPageData(
        entries: entries,
        myRank: myRank,
        seasons: resolvedSeasons.isEmpty ? defaultSeasons : resolvedSeasons,
      );
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '랭킹을 불러오지 못했습니다.'),
      );
    }
  }

  Future<UserProfile> _resolveMyProfile(String? seasonId, dynamic data) async {
    final profile = UserProfile.fromJson(_extractSingleMap(data));
    if (profile.totalScore > 0 || !_isCurrentSeason(seasonId)) {
      return profile;
    }
    return _applyQuizScoreFallback(profile);
  }

  Future<UserProfile> _applyQuizScoreFallback(UserProfile profile) async {
    try {
      final page = await _quizRepository.fetchQuizHistory();
      final summary = page.summary;
      if (summary.totalScore <= 0) return profile;

      return profile.copyWith(
        totalScore: summary.totalScore,
        completedSpots: profile.completedSpots > 0
            ? profile.completedSpots
            : page.spots.length,
        completedQuizzes: profile.completedQuizzes > 0
            ? profile.completedQuizzes
            : page.spots.length,
        perfectCount: profile.perfectCount > 0
            ? profile.perfectCount
            : summary.perfectCount,
      );
    } catch (_) {
      return profile;
    }
  }

  RankingEntry? _buildMyRankEntry(
    UserProfile profile,
    RankingEntry? parsed,
    UserProfile? meProfile,
  ) {
    if (profile.totalScore <= 0 &&
        profile.seasonRank <= 0 &&
        parsed == null) {
      return null;
    }

    return _entryWithMeProfile(
      RankingEntry(
        rank: profile.seasonRank > 0
            ? profile.seasonRank
            : (parsed?.rank ?? 0),
        nickname: parsed?.nickname ?? profile.nickname,
        score: profile.totalScore,
        rankChange: parsed?.rankChange,
        isMe: true,
        avatarValue: parsed?.avatarValue,
        avatarEmoji: parsed?.avatarEmoji,
        avatarUrl: parsed?.avatarUrl,
      ),
      meProfile,
    );
  }

  List<RankingEntry> _applyMeProfileToEntries(
    List<RankingEntry> entries,
    UserProfile? meProfile,
  ) {
    if (meProfile == null) return entries;

    return entries
        .map((entry) => entry.isMe ? _entryWithMeProfile(entry, meProfile) : entry)
        .toList();
  }

  RankingEntry _entryWithMeProfile(
    RankingEntry entry,
    UserProfile? meProfile,
  ) {
    if (meProfile == null) return entry;

    return entry.copyWith(
      nickname: _pickNickname(
        meProfile.nickname,
        entry.nickname,
      ),
      avatarValue: meProfile.avatarValue ?? entry.avatarValue,
      avatarEmoji: meProfile.avatarEmoji ??
          avatarEmojiForValue(meProfile.avatarValue) ??
          entry.avatarEmoji,
      avatarUrl: meProfile.displayAvatarImageUrl ?? entry.avatarUrl,
    );
  }

  String _pickNickname(String? primary, String? fallback) {
    for (final candidate in [primary, fallback]) {
      if (candidate != null &&
          candidate.isNotEmpty &&
          candidate != '탐험가') {
        return candidate;
      }
    }
    return primary?.isNotEmpty == true
        ? primary!
        : (fallback?.isNotEmpty == true ? fallback! : '탐험가');
  }

  bool _isCurrentSeason(String? seasonId) {
    if (seasonId == null || seasonId.isEmpty) return true;
    return seasonId == currentSeasonId;
  }

  String _rankingsPath(String? seasonId) {
    if (_isCurrentSeason(seasonId)) return '/rankings/current';
    return '/rankings/seasons/$seasonId';
  }

  String _myRankPath(String? seasonId) {
    if (_isCurrentSeason(seasonId)) return '/rankings/current/me';
    return '/rankings/seasons/$seasonId/me';
  }

  String _top3Path(String? seasonId) {
    if (_isCurrentSeason(seasonId)) return '/rankings/current/top3';
    return '/rankings/seasons/$seasonId/top3';
  }

  RankingEntry? _parseMyRankEntry(dynamic data) {
    try {
      final map = _extractSingleMap(data);
      return RankingEntry.fromJson({...map, 'isMe': true});
    } catch (_) {
      return null;
    }
  }

  List<RankingEntry> _mergeEntries(
    List<RankingEntry> listEntries,
    List<RankingEntry> top3,
  ) {
    if (top3.isEmpty) return listEntries;

    final topRanks = top3.map((entry) => entry.rank).toSet();
    final rest =
        listEntries.where((entry) => !topRanks.contains(entry.rank)).toList();
    final merged = [...top3, ...rest]
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return merged.isNotEmpty ? merged : top3;
  }

  Map<String, dynamic> _extractSingleMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final root = data['data'];
      if (root is Map<String, dynamic>) return root;
      return data;
    }
    throw Exception('랭킹 응답 형식이 올바르지 않습니다.');
  }

  List<RankingEntry> _extractRankingEntries(dynamic data) {
    final list = _extractRawList(data);
    return list.map(RankingEntry.fromJson).toList();
  }

  List<Map<String, dynamic>> _extractRawList(dynamic data) {
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }

    if (data is Map<String, dynamic>) {
      final root = data['data'];
      if (root is List) {
        return root.cast<Map<String, dynamic>>();
      }
      if (root is Map<String, dynamic>) {
        for (final key in ['rankings', 'entries', 'list', 'content', 'top3']) {
          final value = root[key];
          if (value is List) {
            return value.cast<Map<String, dynamic>>();
          }
        }
      }
      for (final key in ['rankings', 'entries', 'list', 'content', 'top3']) {
        final value = data[key];
        if (value is List) {
          return value.cast<Map<String, dynamic>>();
        }
      }
    }

    return const [];
  }

  List<SeasonOption> _extractSeasonsFromResponse(dynamic data) {
    if (data is! Map<String, dynamic>) return const [];

    final root = data['data'];
    if (root is Map<String, dynamic>) {
      return _extractSeasons(root);
    }

    return _extractSeasons(data);
  }

  List<SeasonOption> _extractSeasons(Map<String, dynamic> root) {
    final raw = root['seasons'] ?? root['seasonList'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => SeasonOption.fromJson(item.cast<String, dynamic>()))
        .toList();
  }
}
