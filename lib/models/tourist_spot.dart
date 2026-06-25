class TouristSpot {
  final String id;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? address;
  final String? publicAmenityInfo;
  final int? parkingCapacity;
  final int? visitorCapacity;
  final String? managementPhone;
  final String? quizId;

  const TouristSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
    this.address,
    this.publicAmenityInfo,
    this.parkingCapacity,
    this.visitorCapacity,
    this.managementPhone,
    this.quizId,
  });

  factory TouristSpot.fromJson(Map<String, dynamic> json) {
    return TouristSpot(
      id: _stringId(json['id'] ?? json['touristSpotId'] ?? json['spotId']),
      name: (json['touristSpotName'] ??
              json['alias'] ??
              json['name'] ??
              '')
          .toString(),
      description: _nullableString(json['description'] ?? json['remark']),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      address: _nullableString(json['address']),
      publicAmenityInfo: _nullableString(json['publicAmenityInfo']),
      parkingCapacity: _parseInt(json['parkingCapacity']),
      visitorCapacity: _parseInt(json['visitorCapacity']),
      managementPhone: _nullableString(json['managementPhone']),
      quizId: _nullableString(
        json['quizId'] ?? json['quiz_id'] ?? _nestedQuizId(json['quiz']),
      ),
    );
  }

  static String? _nestedQuizId(dynamic quiz) {
    if (quiz is Map) {
      final id = quiz['id'] ?? quiz['quizId'];
      return _nullableString(id);
    }
    return null;
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

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
