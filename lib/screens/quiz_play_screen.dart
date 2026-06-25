import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz.dart';
import '../repositories/quiz_repository.dart';
import '../utils/api_error_utils.dart';
import 'quiz_result_screen.dart';

class QuizPlayScreen extends ConsumerStatefulWidget {
  final String quizId;
  final String spotName;

  const QuizPlayScreen({
    super.key,
    required this.quizId,
    required this.spotName,
  });

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen> {
  static const _accentBlue = Color(0xFF4F8EFF);
  static const _accentGreen = Color(0xFF10B981);
  static const _submitOrange = Color(0xFFFF6B35);
  static const _background = Color(0xFFF8F9FF);
  static const _textPrimary = Color(0xFF1A1D23);

  Quiz? _quiz;
  bool _isLoading = true;
  String? _errorMessage;

  int _currentIndex = 0;
  List<int?> _selected = const [];
  bool _showHint = false;
  bool _isSubmitting = false;

  static const _optionLabels = ['①', '②', '③', '④'];

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final quiz =
          await ref.read(quizRepositoryProvider).fetchQuiz(widget.quizId);
      if (!mounted) return;

      setState(() {
        _quiz = quiz;
        _selected = List<int?>.filled(quiz.questions.length, null);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorUtils.readable(
          e,
          fallback: '퀴즈를 불러오지 못했습니다.',
        );
      });
    }
  }

  int get _answeredCount => _selected.where((value) => value != null).length;

  bool get _allAnswered =>
      _selected.isNotEmpty && _selected.every((value) => value != null);

  QuizQuestion? get _currentQuestion {
    final quiz = _quiz;
    if (quiz == null || quiz.questions.isEmpty) return null;
    if (_currentIndex >= quiz.questions.length) return null;
    return quiz.questions[_currentIndex];
  }

  void _selectOption(int index) {
    setState(() {
      final next = List<int?>.from(_selected);
      next[_currentIndex] = index;
      _selected = next;
    });
  }

  void _goToQuestion(int index) {
    final quiz = _quiz;
    if (quiz == null) return;
    setState(() {
      _currentIndex = index.clamp(0, quiz.questions.length - 1);
      _showHint = false;
    });
  }

  void _goNext() {
    final quiz = _quiz;
    if (quiz == null) return;
    if (_selected[_currentIndex] == null) return;

    if (_currentIndex < quiz.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _showHint = false;
      });
    }
  }

  void _goPrev() {
    if (_currentIndex <= 0) return;
    setState(() {
      _currentIndex--;
      _showHint = false;
    });
  }

  Future<void> _submitQuiz() async {
    final quiz = _quiz;
    if (!_allAnswered || quiz == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final answers = List<QuizSubmitAnswer>.generate(quiz.questions.length, (index) {
        final question = quiz.questions[index];
        final selectedIndex = _selected[index]!;
        final choice = question.choices[selectedIndex];
        return QuizSubmitAnswer(
          quizQuestionId: question.questionId,
          quizChoiceId: choice.id,
        );
      });

      final result = await ref.read(quizRepositoryProvider).submitQuiz(
            quizId: widget.quizId,
            answers: answers,
          );

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => QuizResultScreen(
            quizId: widget.quizId,
            spotName: widget.spotName,
            initialResult: result.copyWithSpotName(widget.spotName),
            questions: quiz.questions,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiErrorUtils.readable(e, fallback: '퀴즈 제출에 실패했습니다.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;
    final question = _currentQuestion;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentBlue))
          : _errorMessage != null
              ? _buildErrorState()
              : quiz == null || question == null
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        Container(
                          color: Colors.white,
                          padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _CloseButton(onPressed: () => Navigator.pop(context)),
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(quiz.questions.length, (index) {
                                        final answered = _selected[index] != null;
                                        final isCurrent = index == _currentIndex;
                                        return GestureDetector(
                                          onTap: () => _goToQuestion(index),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            margin: const EdgeInsets.symmetric(horizontal: 3),
                                            width: isCurrent ? 28 : 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: answered
                                                  ? _accentGreen
                                                  : isCurrent
                                                      ? _accentBlue
                                                      : const Color(0xFFE5E7EB),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_currentIndex + 1}/${quiz.questions.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _accentBlue,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: quiz.questions.isEmpty
                                      ? 0
                                      : _answeredCount / quiz.questions.length,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    _accentBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    _TagChip(
                                      label: widget.spotName,
                                      background: const Color(0xFFFEF3C7),
                                      textColor: const Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 6),
                                    if (question.category != null)
                                      _TagChip(
                                        label: question.category!,
                                        background: const Color(0xFFEEF2FF),
                                        textColor: _accentBlue,
                                      ),
                                    const Spacer(),
                                    Text(
                                      '남은 문제 ${quiz.questions.length - _currentIndex - 1}개',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF9CA3AF),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE4E8EF), width: 1.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0D000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Q${_currentIndex + 1}.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: _accentBlue,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        question.question,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _textPrimary,
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ...List.generate(question.options.length, (index) {
                                  final selected = _selected[_currentIndex] == index;
                                  final label = index < _optionLabels.length
                                      ? _optionLabels[index]
                                      : '${index + 1}';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: Material(
                                      color: selected
                                          ? const Color(0xFFEEF2FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(13),
                                      child: InkWell(
                                        onTap: () => _selectOption(index),
                                        borderRadius: BorderRadius.circular(13),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(13),
                                            border: Border.all(
                                              color: selected
                                                  ? _accentBlue
                                                  : const Color(0xFFE5E7EB),
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? _accentBlue
                                                      : const Color(0xFFF3F4F6),
                                                  borderRadius: BorderRadius.circular(9),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: selected
                                                        ? Colors.white
                                                        : const Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  question.options[index],
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: selected
                                                        ? _accentBlue
                                                        : _textPrimary,
                                                    fontWeight: selected
                                                        ? FontWeight.w700
                                                        : FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                              if (selected)
                                                const Text(
                                                  '✓',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: _accentBlue,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                if (question.hint != null) ...[
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _showHint = !_showHint),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      '💡 힌트 보기',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  if (_showHint) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFCE8),
                                        border: Border.all(color: Color(0xFFFDE68A)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '💡 ${question.hint}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                                if (_allAnswered) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      border: Border.all(color: Color(0xFF6EE7B7)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      children: [
                                        Text('✅', style: TextStyle(fontSize: 16)),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '모든 문제를 풀었습니다. 제출 버튼을 눌러주세요!',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF065F46),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                if (_currentIndex > 0) ...[
                                  SizedBox(
                                    width: 48,
                                    height: 52,
                                    child: Material(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: _goPrev,
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Icon(
                                          Icons.arrow_back_ios_new,
                                          size: 18,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _currentIndex <
                                              quiz.questions.length - 1
                                          ? (_selected[_currentIndex] != null
                                              ? _goNext
                                              : null)
                                          : (_allAnswered && !_isSubmitting
                                              ? _submitQuiz
                                              : null),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _currentIndex <
                                                quiz.questions.length - 1
                                            ? (_selected[_currentIndex] != null
                                                ? _accentBlue
                                                : const Color(0xFFE5E7EB))
                                            : (_allAnswered
                                                ? _submitOrange
                                                : const Color(0xFFE5E7EB)),
                                        foregroundColor: _currentIndex <
                                                quiz.questions.length - 1
                                            ? (_selected[_currentIndex] != null
                                                ? Colors.white
                                                : const Color(0xFF9CA3AF))
                                            : (_allAnswered
                                                ? Colors.white
                                                : const Color(0xFF9CA3AF)),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _currentIndex <
                                                    quiz.questions.length - 1
                                                ? '다음 문제'
                                                : _isSubmitting
                                                    ? '제출 중...'
                                                    : '✓ 최종 제출하기',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (_currentIndex <
                                              quiz.questions.length - 1) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 14,
                                              color: _selected[_currentIndex] != null
                                                  ? Colors.white
                                                  : const Color(0xFF9CA3AF),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
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
              onPressed: _loadQuiz,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('표시할 퀴즈 문항이 없습니다.'),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: const Center(
            child: Text(
              '✕',
              style: TextStyle(fontSize: 17, color: Color(0xFF374151)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _TagChip({
    required this.label,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
