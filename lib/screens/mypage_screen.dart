import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layouts/login_layout.dart';
import '../models/quiz_result.dart';
import '../models/ranking.dart';
import '../models/user_badge.dart';
import '../models/user_profile.dart';
import '../models/visited_sido.dart';
import '../repositories/quiz_repository.dart';
import '../repositories/ranking_repository.dart';
import '../repositories/season_repository.dart';
import '../repositories/user_repository.dart';
import '../utils/api_error_utils.dart';
import '../utils/jwt_utils.dart';
import '../widgets/profile_avatar.dart';
import 'profile_settings_screen.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const MyPageScreen({super.key, this.onNavigateToTab});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  UserProfile? _profile;
  int? _seasonRank;
  int? _seasonScore;
  List<_RankingHistoryEntry> _rankingHistory = [];
  List<UserBadge> _badges = const [];
  QuizResultSummary? _quizSummary;
  int _quizSpotCount = 0;
  bool _isLoading = true;
  bool _isRankingHistoryLoading = false;
  bool _showLogoutConfirm = false;
  bool _showWithdrawConfirm = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await ref.read(userRepositoryProvider).fetchMe();
      final nickname = await _resolveNickname(profile.nickname);

      int? seasonRank;
      int? seasonScore;
      try {
        final seasonProfile =
            await ref.read(rankingRepositoryProvider).fetchMyProfile();
        seasonRank = seasonProfile.seasonRank;
        seasonScore = seasonProfile.totalScore;
      } catch (_) {
        seasonRank = profile.seasonRank > 0 ? profile.seasonRank : null;
        seasonScore = profile.totalScore;
      }

      if (!mounted) return;
      setState(() {
        _profile = profile.copyWith(nickname: nickname);
        _badges = UserBadgeDisplay.fromRecentBadges(profile.recentBadges);
        _seasonRank = seasonRank;
        _seasonScore = seasonScore;
        _isLoading = false;
      });

      await Future.wait([
        _loadRankingHistory(),
        _loadQuizStats(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorUtils.readable(
          e,
          fallback: '마이페이지 정보를 불러오지 못했습니다.',
        );
      });
    }
  }

  Future<void> _loadQuizStats() async {
    try {
      final page = await ref.read(quizRepositoryProvider).fetchQuizHistory();
      if (!mounted) return;
      setState(() {
        _quizSummary = page.summary;
        _quizSpotCount = page.spots.length;
      });
    } catch (_) {}
  }

  Future<void> _loadRankingHistory() async {
    setState(() => _isRankingHistoryLoading = true);

    try {
      final seasons = await ref.read(seasonRepositoryProvider).fetchSeasons();
      final entries = <_RankingHistoryEntry>[];

      for (final season in seasons.take(5)) {
        try {
          final profile = await ref
              .read(rankingRepositoryProvider)
              .fetchMyRankForSeason(season.id);
          if (profile.seasonRank <= 0) continue;

          entries.add(
            _RankingHistoryEntry(
              rank: profile.seasonRank,
              dateLabel: season.label,
              pointsLabel: '${formatRankingScore(profile.totalScore)}pt 획득',
              medal: _medalForRank(profile.seasonRank),
            ),
          );
        } catch (_) {
          continue;
        }
      }

      if (!mounted) return;
      setState(() {
        _rankingHistory = entries;
        _isRankingHistoryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rankingHistory = const [];
        _isRankingHistoryLoading = false;
      });
    }
  }

  String? _medalForRank(int rank) {
    return switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
  }

  Future<String> _resolveNickname(String apiNickname) async {
    if (apiNickname.isNotEmpty && apiNickname != '탐험가') {
      return apiNickname;
    }

    final auth = await ref.read(tokenStorageProvider).read();
    final token = auth?.accessToken;
    if (token == null) return apiNickname;

    return JwtUtils.readClaim(token, ['nickname', 'name', 'sub']) ??
        apiNickname;
  }

  Future<void> _openProfileSettings() async {
    final profile = _profile;
    if (profile == null) return;

    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(initialProfile: profile),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() => _profile = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('프로필이 저장되었습니다.')),
    );
  }

  Future<void> _confirmLogout() async {
    setState(() => _showLogoutConfirm = false);

    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _confirmWithdraw() async {
    setState(() => _showWithdrawConfirm = false);

    try {
      await ref.read(authControllerProvider.notifier).withdraw();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiErrorUtils.readable(
              e,
              fallback: '회원 탈퇴에 실패했습니다.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _ErrorBody(
                  message: _errorMessage!,
                  onRetry: _loadData,
                  onLogout: () => setState(() => _showLogoutConfirm = true),
                )
              : Stack(
                  children: [
                    Column(
                      children: [
                        _ProfileHeaderCard(
                          profile: profile!,
                          seasonRank: _seasonRank,
                          seasonScore: _seasonScore,
                          quizSummary: _quizSummary,
                          quizSpotCount: _quizSpotCount,
                          onEdit: _openProfileSettings,
                          onLogoutTap: () =>
                              setState(() => _showLogoutConfirm = true),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            children: [
                              _RankingHistorySection(
                                entries: _rankingHistory,
                                isLoading: _isRankingHistoryLoading,
                                onViewAll: () =>
                                    widget.onNavigateToTab?.call(2),
                              ),
                              const SizedBox(height: 14),
                              _BadgeSection(
                                badges: _badges,
                                onViewAll: () =>
                                    widget.onNavigateToTab?.call(2),
                              ),
                              const SizedBox(height: 14),
                              _RecentHistorySection(
                                visitedSidos: profile.visitedSidos,
                                onViewAll: () =>
                                    widget.onNavigateToTab?.call(1),
                              ),
                              const SizedBox(height: 24),
                              _WithdrawButton(
                                onTap: () =>
                                    setState(() => _showWithdrawConfirm = true),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_showLogoutConfirm)
                      _LogoutBottomSheet(
                        onCancel: () =>
                            setState(() => _showLogoutConfirm = false),
                        onConfirm: _confirmLogout,
                      ),
                    if (_showWithdrawConfirm)
                      _WithdrawBottomSheet(
                        onCancel: () =>
                            setState(() => _showWithdrawConfirm = false),
                        onConfirm: _confirmWithdraw,
                      ),
                  ],
                ),
    );
  }
}

class _RankingHistoryEntry {
  final int rank;
  final String dateLabel;
  final String pointsLabel;
  final String? medal;

  const _RankingHistoryEntry({
    required this.rank,
    required this.dateLabel,
    required this.pointsLabel,
    this.medal,
  });
}

Color _rankBg(int rank) {
  if (rank <= 3) return const Color(0xFFD4EDFF);
  if (rank <= 5) return const Color(0xFFDDFBEE);
  return const Color(0xFFF0F0F0);
}

Color _rankColor(int rank) {
  if (rank <= 3) return const Color(0xFF4F8EFF);
  if (rank <= 5) return const Color(0xFF10B981);
  return const Color(0xFF9CA3AF);
}

class _ProfileHeaderCard extends StatelessWidget {
  final UserProfile profile;
  final int? seasonRank;
  final int? seasonScore;
  final QuizResultSummary? quizSummary;
  final int quizSpotCount;
  final VoidCallback? onEdit;
  final VoidCallback? onLogoutTap;

  const _ProfileHeaderCard({
    required this.profile,
    this.seasonRank,
    this.seasonScore,
    this.quizSummary,
    this.quizSpotCount = 0,
    this.onEdit,
    this.onLogoutTap,
  });

  int get _displayScore {
    final season = seasonScore ?? 0;
    final quiz = quizSummary?.totalScore ?? 0;
    if (season > 0) return season;
    if (quiz > 0) return quiz;
    return profile.totalScore;
  }

  int get _completedSpots {
    if (profile.completedSpots > 0) return profile.completedSpots;
    if (quizSpotCount > 0) return quizSpotCount;
    return profile.visitedSidos.fold(0, (sum, sido) => sum + sido.visitCount);
  }

  int get _completedQuizzes {
    if (profile.completedQuizzes > 0) return profile.completedQuizzes;
    return quizSpotCount;
  }

  int get _perfectCount =>
      quizSummary?.perfectCount ?? profile.perfectCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1421), Color(0xFF1D2660), Color(0xFF2D3A8C)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onLogoutTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ProfileAvatar(
                          avatarUrl: profile.displayAvatarImageUrl,
                          avatarValue: profile.hasUploadedAvatar
                              ? null
                              : profile.avatarValue,
                          avatarEmoji: profile.avatarEmoji,
                          nickname: profile.nickname,
                          size: 60,
                          emojiSize: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A1D23),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: onEdit,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: const Text(
                                        '수정',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (seasonRank != null && seasonRank! > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF5FF),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '🏆 시즌 ${seasonRank}위',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF4F8EFF),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '⭐ ${formatRankingScore(_displayScore)}pt',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatsGrid(
                      totalScore: _displayScore,
                      completedSpots: _completedSpots,
                      completedQuizzes: _completedQuizzes,
                      perfectCount: _perfectCount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int totalScore;
  final int completedSpots;
  final int completedQuizzes;
  final int perfectCount;

  const _StatsGrid({
    required this.totalScore,
    required this.completedSpots,
    required this.completedQuizzes,
    required this.perfectCount,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('⭐', formatRankingScore(totalScore), 'pt', '누적 점수', const Color(0xFF4F8EFF)),
      ('🏛', '$completedSpots', '곳', '완료 장소', const Color(0xFF059669)),
      ('❓', '$completedQuizzes', '개', '완료 퀴즈', const Color(0xFF7C3AED)),
      ('🏆', '$perfectCount', '회', '퍼펙트', const Color(0xFFD97706)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.35,
      children: stats.map((stat) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFEEF2FF)),
          ),
          child: Row(
            children: [
              Text(stat.$1, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: stat.$2,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: stat.$5,
                            ),
                          ),
                          TextSpan(
                            text: stat.$3,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat.$4,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RankingHistorySection extends StatelessWidget {
  final List<_RankingHistoryEntry> entries;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const _RankingHistorySection({
    required this.entries,
    required this.isLoading,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                '랭킹 기록',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D23),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '랭킹 기록이 없습니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RankingHistoryRow(entry: entry),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF8F9FF),
                foregroundColor: const Color(0xFF4F8EFF),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE4E8EF)),
                ),
              ),
              child: const Text(
                '전체 랭킹 보기 →',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingHistoryRow extends StatelessWidget {
  final _RankingHistoryEntry entry;

  const _RankingHistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _rankBg(entry.rank),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _rankColor(entry.rank),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.pointsLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          if (entry.medal != null)
            Text(entry.medal!, style: const TextStyle(fontSize: 22)),
        ],
      ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  final List<UserBadge> badges;
  final VoidCallback? onViewAll;

  const _BadgeSection({
    required this.badges,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🏅 획득 배지',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D23),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '전체보기 →',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4F8EFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const slotCount = UserBadgeDisplay.displayCount;
              const gap = 10.0;
              const slotHeight = 64.0;
              final slotWidth =
                  (constraints.maxWidth - gap * (slotCount - 1)) / slotCount;

              return Row(
                children: [
                  for (var i = 0; i < slotCount; i++)
                    Container(
                      width: slotWidth,
                      height: slotHeight,
                      margin: EdgeInsets.only(right: i < slotCount - 1 ? gap : 0),
                      decoration: BoxDecoration(
                        color: i < badges.length
                            ? const Color(0xFFFEF9EC)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: i < badges.length
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                      ),
                      child: i < badges.length
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  badges[i].emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 3),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    badges[i].label,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentHistorySection extends StatelessWidget {
  final List<VisitedSidoSummary> visitedSidos;
  final VoidCallback? onViewAll;

  const _RecentHistorySection({
    required this.visitedSidos,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final items = visitedSidos.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🗺 최근 탐험',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D23),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '전체보기 →',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4F8EFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '최근 탐험 기록이 없습니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _VisitedSidoRow(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitedSidoRow extends StatelessWidget {
  final VisitedSidoSummary item;

  const _VisitedSidoRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              _sidoIconFor(item.sidoName),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.sidoName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.visitLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.visitCount}곳',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4F8EFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _sidoIconFor(String sidoName) {
  if (sidoName.contains('서울')) return '🏙️';
  if (sidoName.contains('부산')) return '🌊';
  if (sidoName.contains('제주')) return '🍊';
  if (sidoName.contains('경기')) return '🏡';
  if (sidoName.contains('강원')) return '⛰️';
  if (sidoName.contains('전라') || sidoName.contains('전북') || sidoName.contains('전남')) {
    return '🌾';
  }
  if (sidoName.contains('경상') || sidoName.contains('경북') || sidoName.contains('경남')) {
    return '🏯';
  }
  if (sidoName.contains('충청') || sidoName.contains('충북') || sidoName.contains('충남')) {
    return '🌿';
  }
  if (sidoName.contains('인천')) return '✈️';
  if (sidoName.contains('대구')) return '🌺';
  if (sidoName.contains('대전')) return '🔬';
  if (sidoName.contains('광주')) return '🎨';
  if (sidoName.contains('울산')) return '🏭';
  if (sidoName.contains('세종')) return '🏛️';
  return '🗺️';
}

class _WithdrawButton extends StatelessWidget {
  final VoidCallback onTap;

  const _WithdrawButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF9CA3AF),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text(
          '탈퇴하기',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

class _LogoutBottomSheet extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _LogoutBottomSheet({
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: GestureDetector(
          onTap: onCancel,
          behavior: HitTestBehavior.opaque,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '로그아웃 하시겠어요?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D23),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '로그아웃 후 다시 로그인하면 기존 기록은 유지됩니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: TextButton(
                              onPressed: onCancel,
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFF3F4F6),
                                foregroundColor: const Color(0xFF374151),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: const Text(
                                '취소',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: TextButton(
                              onPressed: onConfirm,
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: const Text(
                                '로그아웃',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WithdrawBottomSheet extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _WithdrawBottomSheet({
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: GestureDetector(
          onTap: onCancel,
          behavior: HitTestBehavior.opaque,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '정말 탈퇴하시겠어요?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D23),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '탈퇴 시 모든 기록과 포인트가 삭제되며 복구할 수 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: TextButton(
                              onPressed: onCancel,
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFF3F4F6),
                                foregroundColor: const Color(0xFF374151),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: const Text(
                                '취소',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: TextButton(
                              onPressed: onConfirm,
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: const Text(
                                '탈퇴하기',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onLogout,
              child: const Text(
                '로그아웃',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
