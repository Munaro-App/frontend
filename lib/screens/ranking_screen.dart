import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranking.dart';
import '../repositories/ranking_repository.dart';
import '../utils/api_error_utils.dart';
import '../widgets/profile_avatar.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  static const _accentBlue = Color(0xFF4F8EFF);
  static const _headerTop = Color(0xFF0F1421);
  static const _headerBottom = Color(0xFF1D2660);

  int _seasonIndex = 0;
  RankingPageData? _page;
  List<SeasonOption> _seasonTabs = defaultSeasons;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSeasonTabsAndRankings();
  }

  String _seasonIdForIndex(int index) {
    if (index <= 0) return currentSeasonId;
    return _seasonTabs[index.clamp(0, _seasonTabs.length - 1)].id;
  }

  Future<void> _loadSeasonTabsAndRankings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final seasons =
          await ref.read(rankingRepositoryProvider).fetchSeasonTabs();
      if (!mounted) return;

      setState(() => _seasonTabs = seasons);
      await _loadRankings(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorUtils.readable(
          e,
          fallback: '랭킹을 불러오지 못했습니다.',
        );
      });
    }
  }

  Future<void> _loadRankings({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final seasonId = _seasonIdForIndex(_seasonIndex);
      final page = await ref.read(rankingRepositoryProvider).fetchRankings(
            seasonId: seasonId,
            seasons: _seasonTabs,
          );

      if (!mounted) return;
      setState(() {
        _page = page;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorUtils.readable(
          e,
          fallback: '랭킹을 불러오지 못했습니다.',
        );
      });
    }
  }

  void _onSeasonChanged(int index) {
    if (_seasonIndex == index) return;
    setState(() => _seasonIndex = index);
    _loadRankings();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final topThree = page?.topThree ?? const <RankingEntry>[];
    final first = page?.first ?? (topThree.isNotEmpty ? topThree[0] : null);
    final second = page?.second ??
        (topThree.length > 1 ? topThree[1] : null);
    final third = page?.third ?? (topThree.length > 2 ? topThree[2] : null);
    final listEntries = page?.listFromFourth ?? const <RankingEntry>[];
    final myRank = page?.myRank;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_headerTop, _headerBottom],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '시즌 랭킹 🏆',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _seasonTabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final selected = _seasonIndex == index;
                        return GestureDetector(
                          onTap: () => _onSeasonChanged(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _accentBlue
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? _accentBlue
                                    : Colors.white.withValues(alpha: 0.12),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _seasonTabs[index].label,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.6),
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_headerBottom, _headerTop],
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (second != null)
                        _PodiumCard(entry: second, height: 56)
                      else
                        const SizedBox(width: 95),
                      const SizedBox(width: 8),
                      if (first != null)
                        _PodiumCard(entry: first, height: 76, crown: true)
                      else
                        const SizedBox(width: 110),
                      const SizedBox(width: 8),
                      if (third != null)
                        _PodiumCard(entry: third, height: 40)
                      else
                        const SizedBox(width: 95),
                    ],
                  ),
          ),
          Expanded(
            child: _errorMessage != null
                ? _ErrorBody(message: _errorMessage!, onRetry: _loadSeasonTabsAndRankings)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    children: [
                      if (!_isLoading && listEntries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              '표시할 순위가 없습니다.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        )
                      else
                        ...listEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _RankingListItem(entry: entry),
                          ),
                        ),
                    ],
                  ),
          ),
          if (myRank != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _accentBlue, width: 2)),
              ),
              child: _MyRankCard(entry: myRank),
            ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final RankingEntry entry;
  final double height;
  final bool crown;

  const _PodiumCard({
    required this.entry,
    required this.height,
    this.crown = false,
  });

  static const _gold = Color(0xFFFCD34D);
  static const _silver = Color(0xFFC0C0C0);
  static const _bronze = Color(0xFFCD7F32);

  Color get _glow {
    return switch (entry.rank) {
      1 => _gold,
      2 => _silver,
      _ => _bronze,
    };
  }

  String get _medal {
    return switch (entry.rank) {
      1 => '🥇',
      2 => '🥈',
      _ => '🥉',
    };
  }

  bool get _isFirst => entry.rank == 1;

  @override
  Widget build(BuildContext context) {
    final width = _isFirst ? 110.0 : 95.0;

    return SizedBox(
      width: width,
      child: Column(
        children: [
          if (crown)
            const Text('👑', style: TextStyle(fontSize: 20))
          else
            Text(_medal, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _glow.withValues(alpha: 0.33), width: 2),
              borderRadius: BorderRadius.circular(_isFirst ? 16 : 13),
            ),
            child: _RankingAvatar(
              entry: entry,
              size: _isFirst ? 56 : 46,
              emojiSize: _isFirst ? 28 : 22,
              borderRadius: BorderRadius.circular(_isFirst ? 16 : 13),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _isFirst ? 11 : 10,
              color: _isFirst
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${formatRankingScore(entry.score)}pt',
            style: TextStyle(
              fontSize: _isFirst ? 13 : 11,
              color: _glow,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: _glow.withValues(alpha: 0.13),
              border: Border.all(color: _glow.withValues(alpha: 0.2)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}위',
              style: TextStyle(
                fontSize: _isFirst ? 20 : 17,
                fontWeight: FontWeight.w800,
                color: _glow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingListItem extends StatelessWidget {
  final RankingEntry entry;

  const _RankingListItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final changeColor = entry.rankChange == null || entry.rankChange == 0
        ? const Color(0xFF9CA3AF)
        : entry.isRankUp
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          _RankingAvatar(
            entry: entry,
            size: 38,
            emojiSize: 20,
            borderRadius: BorderRadius.circular(11),
            backgroundColor: const Color(0xFFEEF2FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D23),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: formatRankingScore(entry.score),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1D23),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const TextSpan(
                      text: 'pt',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1D23),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                entry.changeLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: changeColor,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final RankingEntry entry;

  const _MyRankCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final changeText = entry.rankChange == null || entry.rankChange == 0
        ? '–'
        : entry.isRankUp
            ? '↑${entry.rankChange!.abs()}'
            : '↓${entry.rankChange!.abs()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF4F8EFF), width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4F8EFF),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          _RankingAvatar(
            entry: entry,
            size: 38,
            emojiSize: 20,
            borderRadius: BorderRadius.circular(11),
            backgroundColor: const Color(0xFF4F8EFF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F8EFF),
                  ),
                ),
                const Text(
                  '나의 순위',
                  style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: formatRankingScore(entry.score),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F8EFF),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const TextSpan(
                      text: 'pt',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF4F8EFF),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                changeText,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF10B981),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

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
          ],
        ),
      ),
    );
  }
}

class _RankingAvatar extends StatelessWidget {
  final RankingEntry entry;
  final double size;
  final double emojiSize;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const _RankingAvatar({
    required this.entry,
    required this.size,
    required this.emojiSize,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = backgroundColor == null
        ? null
        : LinearGradient(colors: [backgroundColor!, backgroundColor!]);

    return ProfileAvatar(
      avatarUrl: entry.avatarUrl,
      avatarValue: entry.avatarValue,
      avatarEmoji: entry.avatarEmoji,
      nickname: entry.nickname,
      size: size,
      emojiSize: emojiSize,
      borderRadius: borderRadius,
      backgroundGradient: gradient,
    );
  }
}
