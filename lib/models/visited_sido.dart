class VisitedSidoSummary {
  final String sidoName;
  final int visitCount;

  const VisitedSidoSummary({
    required this.sidoName,
    required this.visitCount,
  });

  String get shortName => shortSidoName(sidoName);

  String get visitLabel => '$visitCount곳 방문';

  static List<VisitedSidoSummary> parseList(
    dynamic raw, {
    int? completedSpots,
  }) {
    if (raw == null) return [];

    if (raw is Map) {
      final summaries = raw.entries
          .map((entry) {
            final name = entry.key.toString().trim();
            if (name.isEmpty) return null;
            final count = _parseCount(entry.value);
            return VisitedSidoSummary(sidoName: name, visitCount: count);
          })
          .whereType<VisitedSidoSummary>()
          .toList()
        ..sort(_compareByCountThenName);
      return _applyCompletedSpotsFallback(summaries, completedSpots);
    }

    if (raw is! List || raw.isEmpty) return [];

    if (raw.first is Map) {
      final summaries = raw
          .map((item) {
            if (item is! Map) return null;
            final map = Map<String, dynamic>.from(item);
            final name = _nullableString(
              map['sidoName'] ??
                  map['sido'] ??
                  map['name'] ??
                  map['regionName'],
            );
            if (name == null) return null;
            final count = _parseCount(
              map['visitCount'] ??
                  map['visitedSpotCount'] ??
                  map['spotCount'] ??
                  map['count'] ??
                  1,
            );
            return VisitedSidoSummary(sidoName: name, visitCount: count);
          })
          .whereType<VisitedSidoSummary>()
          .toList()
        ..sort(_compareByCountThenName);
      return _applyCompletedSpotsFallback(summaries, completedSpots);
    }

    final counts = <String, int>{};
    for (final item in raw) {
      final name = item.toString().trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final summaries = counts.entries
        .map(
          (entry) => VisitedSidoSummary(
            sidoName: entry.key,
            visitCount: entry.value,
          ),
        )
        .toList()
      ..sort(_compareByCountThenName);

    return _applyCompletedSpotsFallback(summaries, completedSpots);
  }

  static List<VisitedSidoSummary> _applyCompletedSpotsFallback(
    List<VisitedSidoSummary> summaries,
    int? completedSpots,
  ) {
    if (completedSpots == null || completedSpots <= 0 || summaries.isEmpty) {
      return summaries;
    }

    final totalVisits =
        summaries.fold<int>(0, (sum, item) => sum + item.visitCount);
    if (totalVisits >= completedSpots) return summaries;

    if (summaries.length == 1) {
      return [
        VisitedSidoSummary(
          sidoName: summaries.first.sidoName,
          visitCount: completedSpots,
        ),
      ];
    }

    return summaries;
  }

  static String shortSidoName(String fullName) {
    const suffixes = [
      '특별자치도',
      '특별자치시',
      '특별시',
      '광역시',
      '자치시',
      '자치도',
    ];
    for (final suffix in suffixes) {
      if (fullName.endsWith(suffix)) {
        return fullName.substring(0, fullName.length - suffix.length);
      }
    }
    if (fullName.endsWith('도')) {
      return fullName.substring(0, fullName.length - 1);
    }
    return fullName;
  }

  static int _compareByCountThenName(VisitedSidoSummary a, VisitedSidoSummary b) {
    final byCount = b.visitCount.compareTo(a.visitCount);
    if (byCount != 0) return byCount;
    return a.sidoName.compareTo(b.sidoName);
  }

  static int _parseCount(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value > 0 ? value : 1;
    if (value is num) return value.toInt() > 0 ? value.toInt() : 1;
    return int.tryParse(value.toString()) ?? 1;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
