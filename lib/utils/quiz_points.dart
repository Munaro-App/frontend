class QuizPoints {
  static int pointsPerQuestion(String? difficulty) {
    return switch (difficulty?.trim().toUpperCase()) {
      'EASY' => 10,
      'HARD' || 'DIFFICULT' => 20,
      _ => 15,
    };
  }

  static int estimateMax({
    int? explicitPoints,
    required int questionCount,
    String? difficulty,
  }) {
    if (explicitPoints != null && explicitPoints > 0) {
      return explicitPoints;
    }
    if (questionCount <= 0) return 0;
    return questionCount * pointsPerQuestion(difficulty);
  }
}
