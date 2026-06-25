class ActivityHistoryItem {
  final String submissionId;
  final String spotName;
  final String? category;
  final String? touristSpotId;
  final int points;
  final bool quizCompleted;
  final bool photoCompleted;
  final DateTime? completedAt;

  const ActivityHistoryItem({
    required this.submissionId,
    required this.spotName,
    this.category,
    this.touristSpotId,
    required this.points,
    this.quizCompleted = false,
    this.photoCompleted = false,
    this.completedAt,
  });

  String get shortDate {
    if (completedAt == null) return '';
    final m = completedAt!.month.toString().padLeft(2, '0');
    final d = completedAt!.day.toString().padLeft(2, '0');
    return '$m.$d';
  }

  factory ActivityHistoryItem.fromJson(Map<String, dynamic> json) {
    return ActivityHistoryItem(
      submissionId: (json['submissionId'] ??
              json['id'] ??
              json['historyId'] ??
              '')
          .toString(),
      spotName: (json['touristSpotName'] ??
              json['spotName'] ??
              json['location'] ??
              json['name'] ??
              '알 수 없는 장소')
          .toString(),
      category: _nullableString(json['category'] ?? json['cat']),
      touristSpotId: _nullableString(
        json['touristSpotId'] ?? json['spotId'],
      ),
      points: _parseInt(
            json['points'] ?? json['score'] ?? json['earnedPoints'] ?? json['pts'],
          ) ??
          0,
      quizCompleted: json['quizCompleted'] == true ||
          json['quiz'] == true ||
          json['quizDone'] == true,
      photoCompleted: json['photoCompleted'] == true ||
          json['photo'] == true ||
          json['photoDone'] == true,
      completedAt: _parseDate(
        json['completedAt'] ?? json['submittedAt'] ?? json['createdAt'] ?? json['date'],
      ),
    );
  }

  factory ActivityHistoryItem.fromQuizSpot({
    required String touristSpotId,
    required String spotName,
    required int points,
    DateTime? completedAt,
    String? category,
  }) {
    return ActivityHistoryItem(
      submissionId: '',
      spotName: spotName,
      category: category,
      touristSpotId: touristSpotId,
      points: points,
      quizCompleted: true,
      completedAt: completedAt,
    );
  }

  bool get isQuizHistoryOnly =>
      submissionId.isEmpty && (touristSpotId?.isNotEmpty ?? false);

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
}

class ActivityHistoryDetail extends ActivityHistoryItem {
  final String? description;
  final String? address;
  final int? correctCount;
  final int? totalCount;

  const ActivityHistoryDetail({
    required super.submissionId,
    required super.spotName,
    super.category,
    super.touristSpotId,
    required super.points,
    super.quizCompleted,
    super.photoCompleted,
    super.completedAt,
    this.description,
    this.address,
    this.correctCount,
    this.totalCount,
  });

  factory ActivityHistoryDetail.fromJson(Map<String, dynamic> json) {
    final base = ActivityHistoryItem.fromJson(json);
    return ActivityHistoryDetail(
      submissionId: base.submissionId,
      spotName: base.spotName,
      category: base.category,
      touristSpotId: base.touristSpotId,
      points: base.points,
      quizCompleted: base.quizCompleted,
      photoCompleted: base.photoCompleted,
      completedAt: base.completedAt,
      description: _nullableString(json['description'] ?? json['remark']),
      address: _nullableString(json['address']),
      correctCount: _parseInt(json['correctCount'] ?? json['correctAnswerCount']),
      totalCount: _parseInt(json['totalCount'] ?? json['totalQuestionCount']),
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

String historyIconFor(String spotName) {
  if (spotName.contains('궁')) return '🏯';
  if (spotName.contains('문')) return '⛩';
  if (spotName.contains('한옥')) return '🏘';
  return '🏛';
}
