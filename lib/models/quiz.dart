import '../utils/quiz_points.dart';

class QuizChoice {
  final int id;
  final String content;

  const QuizChoice({
    required this.id,
    required this.content,
  });

  factory QuizChoice.fromJson(Map<String, dynamic> json) {
    return QuizChoice(
      id: _parseInt(json['choiceId'] ??
              json['quizChoiceId'] ??
              json['quiz_choice_id'] ??
              json['id']) ??
          0,
      content: (json['content'] ??
              json['text'] ??
              json['optionText'] ??
              json['answer'] ??
              json['value'] ??
              '')
          .toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class QuizQuestion {
  final int questionId;
  final String question;
  final List<QuizChoice> choices;
  final String? category;
  final String? hint;

  const QuizQuestion({
    required this.questionId,
    required this.question,
    required this.choices,
    this.category,
    this.hint,
  });

  List<String> get options => choices.map((choice) => choice.content).toList();

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'] ??
        json['options'] ??
        json['answers'] ??
        json['optionList'];

    final choices = _parseChoices(rawChoices);

    return QuizQuestion(
      questionId: _parseInt(
            json['questionId'] ??
                json['quizQuestionId'] ??
                json['quiz_question_id'] ??
                json['id'],
          ) ??
          0,
      question: (json['question'] ??
              json['questionText'] ??
              json['content'] ??
              json['title'] ??
              '')
          .toString(),
      choices: choices,
      category: _nullableString(json['category'] ?? json['questionCategory']),
      hint: _nullableString(json['hint'] ?? json['hintText'] ?? json['tip']),
    );
  }

  static List<QuizChoice> _parseChoices(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => QuizChoice.fromJson(item.cast<String, dynamic>()))
        .where((choice) => choice.id > 0 && choice.content.trim().isNotEmpty)
        .toList();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class Quiz {
  final String id;
  final String? title;
  final String? description;
  final String? touristSpotId;
  final int? points;
  final String? difficulty;
  final List<QuizQuestion> questions;

  const Quiz({
    required this.id,
    this.title,
    this.description,
    this.touristSpotId,
    this.points,
    this.difficulty,
    this.questions = const [],
  });

  int get maxRewardPoints => QuizPoints.estimateMax(
        explicitPoints: points,
        questionCount: questions.length,
        difficulty: difficulty,
      );

  factory Quiz.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] ??
        json['quizQuestions'] ??
        json['questionList'];

    return Quiz(
      id: _stringId(json['id'] ?? json['quizId']),
      title: _nullableString(json['title'] ?? json['name'] ?? json['quizTitle']),
      description: _nullableString(json['description'] ?? json['remark']),
      touristSpotId: _nullableString(
        json['touristSpotId'] ?? json['spotId'] ?? json['touristSpot_id'],
      ),
      difficulty: _nullableString(json['difficulty'] ?? json['level']),
      points: _parseInt(
        json['points'] ??
            json['rewardPoints'] ??
            json['maxPoints'] ??
            json['maxRewardPoints'] ??
            json['totalRewardPoints'],
      ),
      questions: rawQuestions is List
          ? rawQuestions
              .whereType<Map>()
              .map((item) => QuizQuestion.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }

  static String _stringId(dynamic value) => value?.toString() ?? '';

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

class QuizSubmitAnswer {
  final int quizQuestionId;
  final int quizChoiceId;

  const QuizSubmitAnswer({
    required this.quizQuestionId,
    required this.quizChoiceId,
  });

  Map<String, dynamic> toJson() => {
        'quizQuestionId': quizQuestionId,
        'quizChoiceId': quizChoiceId,
      };
}
