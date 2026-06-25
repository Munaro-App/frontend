import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz.dart';
import '../models/quiz_result.dart';
import '../models/ranking.dart';
import '../repositories/quiz_repository.dart';
import '../utils/api_error_utils.dart';

class QuizResultScreen extends ConsumerStatefulWidget {
  final String quizId;
  final String spotName;
  final QuizResult? initialResult;
  final List<QuizQuestion> questions;

  const QuizResultScreen({
    super.key,
    required this.quizId,
    required this.spotName,
    this.initialResult,
    this.questions = const [],
  });

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  static const _accentBlue = Color(0xFF4F8EFF);
  static const _accentGreen = Color(0xFF10B981);
  static const _submitOrange = Color(0xFFFF6B35);

  QuizResult? _result;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    if (_result == null) {
      _loadResult();
    }
  }

  Future<void> _loadResult() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result =
          await ref.read(quizRepositoryProvider).fetchQuizResult(widget.quizId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorUtils.readable(
          e,
          fallback: '퀴즈 결과를 불러오지 못했습니다.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentBlue))
          : _errorMessage != null
              ? _buildErrorState()
              : result == null
                  ? const Center(child: Text('결과를 표시할 수 없습니다.'))
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 28),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0F1421), Color(0xFF1D2660)],
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).popUntil((route) => route.isFirst),
                                    icon: const Icon(Icons.close, color: Colors.white),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      '퀴즈 결과',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 48),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                result.perfect ? '🎉' : '📋',
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result.perfect ? '퍼펙트 클리어!' : '퀴즈 완료',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.spotName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _ScoreCard(
                                  label: '획득 점수',
                                  value: '+${formatRankingScore(result.earnedPoints)}',
                                  unit: 'pt',
                                  color: _submitOrange,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ScoreCard(
                                        label: '정답',
                                        value: result.correctLabel,
                                        unit: '문항',
                                        color: _accentBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ScoreCard(
                                        label: '정답률',
                                        value: result.totalCount > 0
                                            ? '${((result.correctCount / result.totalCount) * 100).round()}'
                                            : '0',
                                        unit: '%',
                                        color: _accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                if (result.questionResults.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '문항별 결과',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1D23),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...List.generate(result.questionResults.length, (index) {
                                    final item = result.questionResults[index];
                                    final question = _findQuestion(item.quizQuestionId);
                                    final questionText = item.question ??
                                        question?.question ??
                                        '문항 ${item.quizQuestionId}';
                                    final correctAnswer = item.correct
                                        ? null
                                        : (item.correctChoiceContent ??
                                            _choiceText(
                                              question,
                                              item.correctChoiceId,
                                            ));
                                    final selectedAnswer = item.selectedChoiceContent;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _QuestionResultCard(
                                        index: index + 1,
                                        question: questionText,
                                        correct: item.correct,
                                        selectedAnswer: selectedAnswer,
                                        correctAnswer: correctAnswer,
                                      ),
                                    );
                                  }),
                                ] else if (widget.questions.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '문항별 결과',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1D23),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...List.generate(widget.questions.length, (index) {
                                    final question = widget.questions[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _QuestionResultCard(
                                        index: index + 1,
                                        question: question.question,
                                        correct: null,
                                      ),
                                    );
                                  }),
                                ],
                                if (!result.passed && result.totalCount > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFDBA74),
                                      ),
                                    ),
                                    child: const Text(
                                      '아쉽지만 통과 기준에 미달했습니다.\n다시 도전해 보세요!',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9A3412),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                                if (result.formattedDate.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    '완료일 ${result.formattedDate}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SafeArea(
                            top: false,
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).popUntil((route) => route.isFirst),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '홈으로 돌아가기',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  QuizQuestion? _findQuestion(int questionId) {
    for (final question in widget.questions) {
      if (question.questionId == questionId) return question;
    }
    return null;
  }

  String? _choiceText(QuizQuestion? question, int? choiceId) {
    if (question == null || choiceId == null) return null;
    for (final choice in question.choices) {
      if (choice.id == choiceId) return choice.content;
    }
    return null;
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadResult,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionResultCard extends StatelessWidget {
  final int index;
  final String question;
  final bool? correct;
  final String? selectedAnswer;
  final String? correctAnswer;

  const _QuestionResultCard({
    required this.index,
    required this.question,
    required this.correct,
    this.selectedAnswer,
    this.correctAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = correct == true;
    final isWrong = correct == false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFF6EE7B7)
              : isWrong
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE4E8EF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCorrect
                      ? const Color(0xFFD1FAE5)
                      : isWrong
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isCorrect
                        ? const Color(0xFF065F46)
                        : isWrong
                            ? const Color(0xFF991B1B)
                            : const Color(0xFF4F8EFF),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D23),
                    height: 1.4,
                  ),
                ),
              ),
              if (correct != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCorrect ? '정답' : '오답',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCorrect
                          ? const Color(0xFF065F46)
                          : const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (selectedAnswer != null && selectedAnswer!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isWrong
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '내 답: $selectedAnswer',
                style: TextStyle(
                  fontSize: 12,
                  color: isWrong
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF4F8EFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (correctAnswer != null && correctAnswer!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '정답: $correctAnswer',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4F8EFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _ScoreCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
