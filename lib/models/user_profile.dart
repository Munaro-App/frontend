import 'avatar_upload.dart';
import 'ranking.dart';
import 'user_badge.dart';
import 'visited_sido.dart';

class UserProfile {
  final String nickname;
  final String? avatarType;
  final String? avatarValue;
  final String? avatarEmoji;
  final String? avatarUrl;
  final int level;
  final String? levelLabel;
  final int totalScore;
  final int? nextLevelScore;
  final int seasonRank;
  final int completedSpots;
  final int completedQuizzes;
  final int perfectCount;
  final List<RecentBadge> recentBadges;
  final List<VisitedSidoSummary> visitedSidos;

  const UserProfile({
    required this.nickname,
    this.avatarType,
    this.avatarValue,
    this.avatarEmoji,
    this.avatarUrl,
    required this.level,
    this.levelLabel,
    required this.totalScore,
    this.nextLevelScore,
    required this.seasonRank,
    required this.completedSpots,
    required this.completedQuizzes,
    required this.perfectCount,
    this.recentBadges = const [],
    this.visitedSidos = const [],
  });

  bool get hasUploadedAvatar =>
      avatarType == AvatarTypes.uploaded ||
      (displayAvatarImageUrl?.startsWith('http') ?? false);

  String? get displayAvatarImageUrl {
    if (avatarType == AvatarTypes.uploaded) {
      return avatarValue ?? avatarUrl;
    }
    return avatarUrl;
  }

  UserProfile copyWith({
    String? nickname,
    String? avatarType,
    String? avatarValue,
    String? avatarEmoji,
    String? avatarUrl,
    int? totalScore,
    int? seasonRank,
    int? perfectCount,
    int? completedSpots,
    int? completedQuizzes,
    List<RecentBadge>? recentBadges,
    List<VisitedSidoSummary>? visitedSidos,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      avatarType: avatarType ?? this.avatarType,
      avatarValue: avatarValue ?? this.avatarValue,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      level: level,
      levelLabel: levelLabel,
      totalScore: totalScore ?? this.totalScore,
      nextLevelScore: nextLevelScore,
      seasonRank: seasonRank ?? this.seasonRank,
      completedSpots: completedSpots ?? this.completedSpots,
      completedQuizzes: completedQuizzes ?? this.completedQuizzes,
      perfectCount: perfectCount ?? this.perfectCount,
      recentBadges: recentBadges ?? this.recentBadges,
      visitedSidos: visitedSidos ?? this.visitedSidos,
    );
  }

  String get levelTitle => levelLabel ?? _defaultLevelTitle(level);

  double get xpProgress {
    final target = nextLevelScore;
    if (target == null || target <= 0) return 0;
    return (totalScore / target).clamp(0.0, 1.0);
  }

  String get xpLabel {
    final target = nextLevelScore;
    if (target == null) return '$totalScore pt';
    return '$totalScore / ${target}pt';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final source = user is Map<String, dynamic> ? user : json;
    final stats = source['statistics'];
    final statsMap = stats is Map<String, dynamic> ? stats : null;

    final level = _parseInt(source['level'] ?? source['userLevel']) ?? 1;
    final nickname = (source['nickname'] ??
            source['name'] ??
            source['userName'] ??
            '탐험가')
        .toString();
    final avatarType = _nullableString(source['avatarType'] ?? source['avatar_type']);
    final rawAvatarValue =
        _nullableString(source['avatarValue'] ?? source['avatar_value']);

    final String? avatarUrl;
    final String? avatarValue;
    final String? avatarEmoji;

    if (avatarType == AvatarTypes.uploaded) {
      avatarUrl = rawAvatarValue ??
          _nullableString(
            source['avatarUrl'] ??
                source['avatarImageUrl'] ??
                source['profileImageUrl'],
          );
      avatarValue = rawAvatarValue ?? avatarUrl;
      avatarEmoji = null;
    } else {
      avatarValue = normalizeAvatarValue(rawAvatarValue);
      avatarEmoji = avatarEmojiForValue(avatarValue) ??
          _nullableString(
            source['avatar'] ??
                source['avatarEmoji'] ??
                source['profileEmoji'],
          );
      avatarUrl = avatarType == AvatarTypes.preset
          ? null
          : _nullableString(
              source['avatarUrl'] ??
                  source['avatarImageUrl'] ??
                  source['profileImageUrl'],
            );
    }

    return UserProfile(
      nickname: nickname,
      avatarType: avatarType,
      avatarValue: avatarValue,
      avatarEmoji: avatarEmoji,
      avatarUrl: avatarUrl,
      level: level,
      levelLabel: _nullableString(
        source['levelTitle'] ?? source['levelName'] ?? source['gradeName'],
      ),
      totalScore: _parseInt(
            statsMap?['totalPoints'] ??
                source['score'] ??
                source['totalScore'] ??
                source['points'] ??
                source['totalPoints'],
          ) ??
          0,
      nextLevelScore: _parseInt(
        source['nextLevelScore'] ??
            source['expToNextLevel'] ??
            source['requiredScore'] ??
            source['nextLevelRequiredScore'],
      ),
      seasonRank:
          _parseInt(source['seasonRank'] ?? source['rank'] ?? source['ranking']) ??
              0,
      completedSpots: _parseInt(
            statsMap?['completedSpots'] ??
                source['completedSpots'] ??
                source['visitedSpotCount'] ??
                source['completedPlaceCount'],
          ) ??
          0,
      completedQuizzes: _parseInt(
            statsMap?['completedQuizzes'] ??
                source['completedQuizzes'] ??
                source['quizCompletedCount'] ??
                source['completedQuizCount'],
          ) ??
          0,
      perfectCount: _parseInt(
            statsMap?['perfectCount'] ??
                source['perfectCount'] ??
                source['perfectClearCount'] ??
                source['perfectQuizCount'],
          ) ??
          0,
      recentBadges: UserBadgeDisplay.parseList(source['recentBadges']),
      visitedSidos: VisitedSidoSummary.parseList(
        source['visitedSidos'] ?? source['visitedsidos'],
        completedSpots: _parseInt(statsMap?['completedSpots']),
      ),
    );
  }

  static String _defaultLevelTitle(int level) {
    if (level >= 10) return '전설 탐험가';
    if (level >= 7) return '숙련 탐험가';
    if (level >= 4) return '견습 탐험가';
    return '초보 탐험가';
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
