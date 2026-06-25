import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spot_quiz_summary.dart';
import '../models/tourist_spot.dart';
import '../models/ranking.dart';
import '../repositories/quiz_repository.dart';
import '../repositories/tourist_spot_repository.dart';
import '../utils/api_error_utils.dart';
import 'quiz_play_screen.dart';

class HeritageDetailScreen extends ConsumerStatefulWidget {
  final TouristSpot spot;

  const HeritageDetailScreen({super.key, required this.spot});

  @override
  ConsumerState<HeritageDetailScreen> createState() =>
      _HeritageDetailScreenState();
}

class _HeritageDetailScreenState extends ConsumerState<HeritageDetailScreen> {
  static const _accentBlue = Color(0xFF4F8EFF);
  static const _accentGreen = Color(0xFF10B981);
  static const _incompleteOrange = Color(0xFFFF6B35);
  static const _textPrimary = Color(0xFF1A1D23);

  TouristSpot? _detail;
  SpotQuizSummary? _missionQuiz;
  bool _isLoading = true;
  bool _isMissionLoading = false;
  String? _errorMessage;
  String? _missionErrorMessage;
  bool _completed = false;
  int _earnedPoints = 0;
  int _maxRewardPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  int get _maxPoints => _maxRewardPoints;

  String get _pointsBadgeLabel {
    if (_completed && _earnedPoints > 0) {
      return '완료 · ${formatRankingScore(_earnedPoints)}pt';
    }
    if (_maxRewardPoints > 0) {
      return '최대 ${formatRankingScore(_maxRewardPoints)}pt';
    }
    return '미완료';
  }

  String get _quizMissionSubtitle {
    if (_isMissionLoading) return '미션 불러오는 중...';
    if (_missionErrorMessage != null) return _missionErrorMessage!;
    if (_missionQuiz == null) return '연결된 퀴즈 없음';

    final count = _missionQuiz!.questionCount;
    final label =
        _missionQuiz!.title ?? _missionQuiz!.category ?? '역사/문화';
    if (count != null && count > 0) return '$count문제 · $label';
    return label;
  }

  bool get _canStartQuiz =>
      !_completed &&
      !_isMissionLoading &&
      _missionQuiz != null &&
      _missionQuiz!.id.isNotEmpty;

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _isMissionLoading = true;
      _errorMessage = null;
      _missionErrorMessage = null;
    });

    try {
      final detail = await ref
          .read(touristSpotRepositoryProvider)
          .fetchSpotDetail(widget.spot.id);
      if (!mounted) return;

      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorUtils.fromDioException(
          e,
          fallback: '상세 정보를 불러오지 못했습니다.',
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '상세 정보를 불러오지 못했습니다.';
      });
    }

    try {
      final quizzes = await ref
          .read(quizRepositoryProvider)
          .fetchSpotQuizzes(widget.spot.id);
      if (!mounted) return;

      setState(() {
        _missionQuiz = quizzes.isNotEmpty ? quizzes.first : null;
        _isMissionLoading = false;
        if (quizzes.isEmpty) {
          _missionErrorMessage = '등록된 퀴즈 미션이 없습니다.';
        }
      });

      await _loadProgressAndRewards();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _missionQuiz = null;
        _isMissionLoading = false;
        _missionErrorMessage = ApiErrorUtils.readable(
          e,
          fallback: '미션 정보를 불러오지 못했습니다.',
        );
      });
    }
  }

  Future<void> _loadProgressAndRewards() async {
    try {
      final historyMap =
          await ref.read(quizRepositoryProvider).fetchSpotHistoryMap();
      final history = historyMap[widget.spot.id];
      if (history != null && history.earnedPoints > 0) {
        _earnedPoints = history.earnedPoints;
        _completed = true;
      }
    } catch (_) {}

    final mission = _missionQuiz;
    if (mission != null) {
      _maxRewardPoints = mission.maxRewardPoints;
      if (_maxRewardPoints == 0) {
        try {
          final quiz =
              await ref.read(quizRepositoryProvider).fetchQuiz(mission.id);
          _maxRewardPoints = quiz.maxRewardPoints;
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  void _onQuizPressed() async {
    if (!_canStartQuiz || _missionQuiz == null) return;

    final spot = _detail ?? widget.spot;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => QuizPlayScreen(
          quizId: _missionQuiz!.id,
          spotName: spot.name,
        ),
      ),
    );

    if (!mounted) return;
    await _loadProgressAndRewards();
  }

  @override
  Widget build(BuildContext context) {
    final spot = _detail ?? widget.spot;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4F46E5),
                        Color(0xFF818CF8),
                        Color(0xFFA5B4FC),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Text('🏯', style: TextStyle(fontSize: 64)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: topPadding + 8,
                  left: 14,
                  child: _OverlayIconButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                Positioned(
                  top: topPadding + 8,
                  right: 14,
                  child: _OverlayIconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('공유 기능은 준비 중입니다.')),
                      );
                    },
                    child: const Text(
                      '↗',
                      style: TextStyle(fontSize: 17, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 12,
                  child: _completed
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _accentGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('✓', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text(
                                _pointsBadgeLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _incompleteOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '미완료',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _ErrorBody(
                        message: _errorMessage!,
                        onRetry: _loadDetail,
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        spot.name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: _textPrimary,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 5,
                                        runSpacing: 5,
                                        children: const [
                                          _CategoryChip(
                                            label: '🏛 문화유산',
                                            color: _accentBlue,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FF),
                                    border: Border.all(
                                      color: const Color(0xFFC7D2FE),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        '최대 획득',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      Text(
                                        _maxPoints > 0
                                            ? formatRankingScore(_maxPoints)
                                            : '-',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: _accentBlue,
                                        ),
                                      ),
                                      const Text(
                                        '포인트',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: _accentBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FF),
                                border: Border.all(
                                  color: const Color(0xFFE4E8EF),
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '소개',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    spot.description?.trim().isNotEmpty == true
                                        ? spot.description!.trim()
                                        : '등록된 설명이 없습니다.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF374151),
                                      height: 1.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _InfoTile(
                                    emoji: '📍',
                                    label: '주소',
                                    value: spot.address ?? '주소 정보 없음',
                                    background: const Color(0xFFF3F4F6),
                                    labelColor: const Color(0xFF6B7280),
                                    valueColor: _textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 118,
                                  child: _InfoTile(
                                    emoji: '📡',
                                    label: '인증 반경',
                                    value: '500m 이내',
                                    background: const Color(0xFFFEF3C7),
                                    labelColor: const Color(0xFF92400E),
                                    valueColor: const Color(0xFFD97706),
                                    valueWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              '미션 현황',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: _completed
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFF8F9FF),
                                border: Border.all(
                                  color: _completed
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFFC7D2FE),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _completed ? '✅' : '❓',
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '퀴즈 미션',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _quizMissionSubtitle,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _missionErrorMessage != null
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isMissionLoading)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Text(
                                      _completed
                                          ? '+${formatRankingScore(_earnedPoints)}pt'
                                          : _maxRewardPoints > 0
                                              ? '+${formatRankingScore(_maxRewardPoints)}pt'
                                              : '-',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: _completed
                                            ? const Color(0xFF059669)
                                            : _accentBlue,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _canStartQuiz ? _onQuizPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _completed
                        ? const Color(0xFFD1FAE5)
                        : _accentBlue,
                    disabledBackgroundColor: const Color(0xFFD1FAE5),
                    foregroundColor:
                        _completed ? const Color(0xFF065F46) : Colors.white,
                    disabledForegroundColor: const Color(0xFF065F46),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('❓', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        _completed
                            ? '퀴즈 완료 ✓'
                            : _isMissionLoading
                                ? '퀴즈 불러오는 중...'
                                : _canStartQuiz
                                    ? '퀴즈 시작하기'
                                    : '퀴즈 없음',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _OverlayIconButton({
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? background;

  const _CategoryChip({
    required this.label,
    required this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color background;
  final Color labelColor;
  final Color valueColor;
  final FontWeight valueWeight;

  const _InfoTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.background,
    required this.labelColor,
    required this.valueColor,
    this.valueWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: labelColor),
                ),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: valueWeight,
                    color: valueColor,
                  ),
                ),
              ],
            ),
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
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
