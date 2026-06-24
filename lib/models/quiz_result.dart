class QuizAnswerResult {
  final int quizQuestionId;
  final bool correct;
  final int? correctChoiceId;
  final int? selectedChoiceId;
  final String? question;
  final String? selectedChoiceContent;
  final String? correctChoiceContent;

  const QuizAnswerResult({
    required this.quizQuestionId,
    required this.correct,
    this.correctChoiceId,
    this.selectedChoiceId,
    this.question,
    this.selectedChoiceContent,
    this.correctChoiceContent,
  });

  factory QuizAnswerResult.fromJson(Map<String, dynamic> json) {
    return QuizAnswerResult(
      quizQuestionId: _parseInt(
            json['quizQuestionId'] ??
                json['questionId'] ??
                json['quiz_question_id'],
          ) ??
          0,
      correct: json['correct'] == true,
      correctChoiceId: _parseInt(
        json['correctChoiceId'] ??
            json['choiceId'] ??
            json['quiz_choice_id'],
      ),
      selectedChoiceId: _parseInt(json['selectedChoiceId']),
      question: _nullableString(json['question']),
      selectedChoiceContent: _nullableString(json['selectedChoiceContent']),
      correctChoiceContent: _nullableString(json['correctChoiceContent']),
    );
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

class QuizResult {
  final String quizId;
  final String? touristSpotId;
  final String spotName;
  final String? category;
  final int score;
  final int earnedPoints;
  final DateTime? completedAt;
  final int correctCount;
  final int totalCount;
  final int? correctRatePercent;
  final bool? isPerfectClear;
  final bool passed;
  final List<QuizAnswerResult> questionResults;

  const QuizResult({
    required this.quizId,
    this.touristSpotId,
    required this.spotName,
    this.category,
    required this.score,
    required this.earnedPoints,
    this.completedAt,
    required this.correctCount,
    required this.totalCount,
    this.correctRatePercent,
    this.isPerfectClear,
    this.passed = false,
    this.questionResults = const [],
  });

  bool get perfect =>
      isPerfectClear ??
      (totalCount > 0 && correctCount >= totalCount);

  String get correctLabel {
    if (correctRatePercent != null && totalCount <= 0) {
      return '$correctRatePercent%';
    }
    return '$correctCount/$totalCount';
  }

  QuizResult copyWithSpotName(String spotName) {
    if (spotName.isEmpty || this.spotName == spotName) return this;
    return QuizResult(
      quizId: quizId,
      touristSpotId: touristSpotId,
      spotName: spotName,
      category: category,
      score: score,
      earnedPoints: earnedPoints,
      completedAt: completedAt,
      correctCount: correctCount,
      totalCount: totalCount,
      correctRatePercent: correctRatePercent,
      isPerfectClear: isPerfectClear,
      passed: passed,
      questionResults: questionResults,
    );
  }

  String get formattedDate {
    if (completedAt == null) return '';
    final y = completedAt!.year;
    final m = completedAt!.month.toString().padLeft(2, '0');
    final d = completedAt!.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  factory QuizResult.fromJson(
    Map<String, dynamic> json, {
    String? fallbackQuizId,
    String? fallbackSpotName,
  }) {
    final correct = _parseCorrect(json);
    final earnedPoints = _parseInt(json['earnedPoints'] ?? json['points']) ??
        _parseInt(json['score'] ?? json['quizScore']) ??
        0;

    return QuizResult(
      quizId: _stringId(json['quizId'] ?? json['id'] ?? fallbackQuizId),
      touristSpotId: _nullableString(
        json['touristSpotId'] ??
            json['spotId'] ??
            json['touristSpot_id'] ??
            _nestedSpotId(json['touristSpot']),
      ),
      spotName: (json['touristSpotName'] ??
              json['spotName'] ??
              json['location'] ??
              json['name'] ??
              fallbackSpotName ??
              '알 수 없는 장소')
          .toString(),
      category: _nullableString(json['category'] ?? json['cat']),
      score: _parseInt(json['score'] ?? json['quizScore']) ?? earnedPoints,
      earnedPoints: earnedPoints,
      completedAt: _parseDate(
        json['completedAt'] ??
            json['submittedAt'] ??
            json['latestSubmittedAt'] ??
            json['createdAt'] ??
            json['date'],
      ),
      correctCount: correct.$1,
      totalCount: correct.$2,
      correctRatePercent: _parseInt(json['correctRate']),
      isPerfectClear: json['perfect'] == true ? true : null,
      passed: json['passed'] == true || json['perfect'] == true,
      questionResults: _parseQuestionResults(json['answers'] ?? json['results']),
    );
  }

  static List<QuizAnswerResult> _parseQuestionResults(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => QuizAnswerResult.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.quizQuestionId > 0)
        .toList();
  }

  static (int, int) _parseCorrect(Map<String, dynamic> json) {
    final correctCount = _parseInt(
      json['correctCount'] ??
          json['correctAnswerCount'] ??
          json['correctAnswers'],
    );
    final totalCount = _parseInt(
      json['totalCount'] ??
          json['totalQuestionCount'] ??
          json['questionCount'] ??
          json['totalQuestions'],
    );

    if (correctCount != null && totalCount != null) {
      return (correctCount, totalCount);
    }

    final wrongCount = _parseInt(json['wrongCount']);
    if (correctCount != null && wrongCount != null) {
      return (correctCount, correctCount + wrongCount);
    }

    final ratio = json['correct'] ?? json['correctRatio'] ?? json['scoreRatio'];
    if (ratio is String && ratio.contains('/')) {
      final parts = ratio.split('/');
      if (parts.length == 2) {
        return (
          int.tryParse(parts[0].trim()) ?? 0,
          int.tryParse(parts[1].trim()) ?? 0,
        );
      }
    }

    final rate = _parseInt(json['correctRate'] ?? json['accuracy']);
    if (rate != null && totalCount != null && totalCount > 0) {
      return ((totalCount * rate / 100).round(), totalCount);
    }

    return (correctCount ?? 0, totalCount ?? 0);
  }

  static String _stringId(dynamic value) => value?.toString() ?? '';

  static String? _nestedSpotId(dynamic spot) {
    if (spot is Map) {
      return _nullableString(spot['id'] ?? spot['touristSpotId'] ?? spot['spotId']);
    }
    return null;
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

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
  factory QuizResult.fromHistorySpot(Map<String, dynamic> json) {
    final spotId =
        _nullableString(json['touristSpotId'] ?? json['spotId']) ?? '';
    final earnedPoints =
        _parseInt(json['earnedPoints'] ?? json['points']) ?? 0;

    return QuizResult(
      quizId: spotId,
      touristSpotId: spotId,
      spotName: (json['touristSpotName'] ??
              json['spotName'] ??
              '알 수 없는 장소')
          .toString(),
      score: earnedPoints,
      earnedPoints: earnedPoints,
      completedAt: _parseDate(json['latestSubmittedAt'] ?? json['completedAt']),
      correctCount: 0,
      totalCount: 0,
      correctRatePercent: _parseInt(json['correctRate']),
    );
  }

  factory QuizResult.fromHistoryDetail(Map<String, dynamic> root) {
    final spotId =
        _nullableString(root['touristSpotId'] ?? root['spotId']) ?? '';
    final spotName = (root['touristSpotName'] ??
            root['spotName'] ??
            '알 수 없는 장소')
        .toString();
    final submissions = root['submissions'];

    if (submissions is List && submissions.isNotEmpty) {
      final submission = _pickLatestSubmission(submissions);
      if (submission != null) {
        return QuizResult.fromSubmission(
          submission,
          touristSpotId: spotId,
          spotName: spotName,
        );
      }
    }

    final earnedPoints =
        _parseInt(root['totalEarnedPoints'] ?? root['earnedPoints']) ?? 0;

    return QuizResult(
      quizId: spotId,
      touristSpotId: spotId,
      spotName: spotName,
      score: earnedPoints,
      earnedPoints: earnedPoints,
      correctCount: 0,
      totalCount: 0,
      correctRatePercent: _parseInt(root['averageCorrectRate']),
      isPerfectClear: _parseInt(root['perfectClearCount']) != null &&
              (_parseInt(root['perfectClearCount']) ?? 0) > 0
          ? true
          : null,
    );
  }

  factory QuizResult.fromSubmission(
    Map<String, dynamic> json, {
    required String touristSpotId,
    required String spotName,
  }) {
    final correct = _parseCorrect(json);
    final earnedPoints =
        _parseInt(json['earnedPoints'] ?? json['points']) ?? 0;

    return QuizResult(
      quizId: _stringId(json['quizId'] ?? json['id']),
      touristSpotId: touristSpotId,
      spotName: spotName,
      category: _nullableString(json['quizTitle'] ?? json['category']),
      score: earnedPoints,
      earnedPoints: earnedPoints,
      completedAt: _parseDate(json['submittedAt'] ?? json['completedAt']),
      correctCount: correct.$1,
      totalCount: correct.$2,
      correctRatePercent:
          correct.$2 > 0 ? null : _parseInt(json['correctRate']),
      isPerfectClear: json['perfect'] == true ? true : null,
      passed: json['passed'] == true || json['perfect'] == true,
      questionResults: _parseQuestionResults(json['answers'] ?? json['results']),
    );
  }

  static Map<String, dynamic>? _pickLatestSubmission(List<dynamic> submissions) {
    Map<String, dynamic>? latest;
    DateTime? latestAt;

    for (final raw in submissions) {
      if (raw is! Map) continue;
      final item = raw.cast<String, dynamic>();
      final submittedAt = _parseDate(item['submittedAt'] ?? item['completedAt']);

      if (latest == null) {
        latest = item;
        latestAt = submittedAt;
        continue;
      }

      if (submittedAt != null &&
          (latestAt == null || submittedAt.isAfter(latestAt))) {
        latest = item;
        latestAt = submittedAt;
      }
    }

    return latest;
  }
}

class QuizHistoryData {
  final QuizResultSummary summary;
  final List<QuizResult> spots;

  const QuizHistoryData({
    required this.summary,
    required this.spots,
  });
}

class QuizResultSummary {
  final int totalScore;
  final int averageCorrectRate;
  final int perfectCount;

  const QuizResultSummary({
    required this.totalScore,
    required this.averageCorrectRate,
    required this.perfectCount,
  });

  factory QuizResultSummary.fromApiJson(Map<String, dynamic> json) {
    return QuizResultSummary(
      totalScore: _parseInt(json['totalEarnedPoints'] ?? json['totalScore']) ?? 0,
      averageCorrectRate:
          _parseInt(json['averageCorrectRate'] ?? json['averageAccuracy']) ?? 0,
      perfectCount:
          _parseInt(json['perfectClearCount'] ?? json['perfectCount']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  factory QuizResultSummary.fromResults(List<QuizResult> results) {
    if (results.isEmpty) {
      return const QuizResultSummary(
        totalScore: 0,
        averageCorrectRate: 0,
        perfectCount: 0,
      );
    }

    final totalScore =
        results.fold<int>(0, (sum, item) => sum + item.earnedPoints);
    final perfectCount = results.where((item) => item.perfect).length;

    final rates = results
        .where((item) => item.totalCount > 0)
        .map((item) => (item.correctCount / item.totalCount) * 100)
        .toList();

    final averageCorrectRate = rates.isEmpty
        ? 0
        : (rates.reduce((a, b) => a + b) / rates.length).round();

    return QuizResultSummary(
      totalScore: totalScore,
      averageCorrectRate: averageCorrectRate,
      perfectCount: perfectCount,
    );
  }
}
