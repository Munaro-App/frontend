import '../utils/quiz_points.dart';

class SpotQuizSummary {
  final String id;
  final String? title;
  final String? category;
  final int? questionCount;
  final int? points;
  final String? difficulty;

  const SpotQuizSummary({
    required this.id,
    this.title,
    this.category,
    this.questionCount,
    this.points,
    this.difficulty,
  });

  int get maxRewardPoints => QuizPoints.estimateMax(
        explicitPoints: points,
        questionCount: questionCount ?? 0,
        difficulty: difficulty,
      );

  factory SpotQuizSummary.fromJson(
    Map<String, dynamic> json, {
    String? fallbackSpotId,
  }) {
    final rawQuestions = json['questions'] ??
        json['quizQuestions'] ??
        json['questionList'];

    int? questionCount = _parseInt(
      json['questionCount'] ??
          json['totalQuestions'] ??
          json['questionSize'],
    );
    if (questionCount == null && rawQuestions is List) {
      questionCount = rawQuestions.length;
    }

    final id = _stringId(
      json['id'] ??
          json['quizId'] ??
          json['touristSpotId'] ??
          json['spotId'] ??
          fallbackSpotId,
    );

    return SpotQuizSummary(
      id: id,
      title: _nullableString(
        json['title'] ?? json['name'] ?? json['quizTitle'],
      ),
      category: _nullableString(
        json['category'] ?? json['quizCategory'] ?? json['type'],
      ),
      questionCount: questionCount,
      difficulty: _nullableString(json['difficulty'] ?? json['level']),
      points: _parseInt(
        json['points'] ??
            json['rewardPoints'] ??
            json['maxPoints'] ??
            json['maxRewardPoints'] ??
            json['totalRewardPoints'],
      ),
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
