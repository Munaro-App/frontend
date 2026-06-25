import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz_result.dart';
import '../models/ranking.dart';
import '../repositories/quiz_repository.dart';
import '../utils/api_error_utils.dart';
import 'quiz_result_screen.dart';

class QuizHistoryScreen extends ConsumerStatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  ConsumerState<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends ConsumerState<QuizHistoryScreen> {
  static const _accentBlue = Color(0xFF4F8EFF);
  static const _textPrimary = Color(0xFF1A1D23);

  List<QuizResult> _results = [];
  QuizResultSummary _summary = const QuizResultSummary(
    totalScore: 0,
    averageCorrectRate: 0,
    perfectCount: 0,
  );
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await ref.read(quizRepositoryProvider).fetchQuizHistory();
      if (!mounted) return;
      setState(() {
        _results = page.spots;
        _summary = page.summary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorUtils.readable(
          e,
          fallback: '퀴즈 기록을 불러오지 못했습니다.',
        );
      });
    }
  }

  Future<void> _openDetail(QuizResult result) async {
    try {
      final spotId = result.touristSpotId ?? result.quizId;
      if (spotId.isEmpty) {
        throw Exception('관광지 정보가 없습니다.');
      }

      final detail = await ref
          .read(quizRepositoryProvider)
          .fetchQuizHistoryDetail(spotId);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => QuizResultScreen(
            quizId: detail.quizId.isNotEmpty ? detail.quizId : result.quizId,
            spotName: detail.spotName,
            initialResult: detail,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiErrorUtils.readable(
              e,
              fallback: '퀴즈 기록 상세를 불러오지 못했습니다.',
            ),
          ),
        ),
      );
    }
  }

  String _iconFor(QuizResult result) {
    final name = result.spotName;
    if (name.contains('궁')) return '🏯';
    if (name.contains('문')) return '⛩';
    if (name.contains('한옥')) return '🏘';
    return '🏛';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '퀴즈 기록 📋',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '총 ${_results.length}개 장소 방문',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                children: [
                  _SummaryCard(
                    label: '총 획득 점수',
                    value: '${formatRankingScore(summary.totalScore)}pt',
                    color: _accentBlue,
                    background: const Color(0xFFEEF2FF),
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: '평균 정답률',
                    value: '${summary.averageCorrectRate}%',
                    color: const Color(0xFF10B981),
                    background: const Color(0xFFD1FAE5),
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: '퍼펙트 클리어',
                    value: '${summary.perfectCount}회',
                    color: const Color(0xFFD97706),
                    background: const Color(0xFFFEF3C7),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _ErrorState(
                          message: _errorMessage!,
                          onRetry: _loadResults,
                        )
                      : _results.isEmpty
                          ? const Center(
                              child: Text(
                                '아직 퀴즈 기록이 없습니다.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final result = _results[index];
                                return _HistoryCard(
                                  result: result,
                                  icon: _iconFor(result),
                                  onTap: () => _openDetail(result),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.67),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final QuizResult result;
  final String icon;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.result,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: result.perfect
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          result.spotName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1D23),
                          ),
                        ),
                        if (result.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              result.category!,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        if (result.perfect)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              '퍼펙트 🎯',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF4F8EFF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (result.formattedDate.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          result.formattedDate,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${formatRankingScore(result.earnedPoints)}pt',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F8EFF),
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    '${result.correctLabel} 정답',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
