class UserBadge {
  final String emoji;
  final String label;

  const UserBadge({
    required this.emoji,
    required this.label,
  });
}

class RecentBadge {
  final int rank;
  final String? seasonName;
  final String? name;

  const RecentBadge({
    required this.rank,
    this.seasonName,
    this.name,
  });

  factory RecentBadge.fromJson(Map<String, dynamic> json) {
    return RecentBadge(
      rank: _parseRank(json),
      seasonName: _nullableString(
        json['seasonName'] ??
            json['seasonLabel'] ??
            json['seasonTitle'] ??
            json['season'],
      ),
      name: _nullableString(
        json['name'] ??
            json['badgeName'] ??
            json['title'] ??
            json['label'],
      ),
    );
  }

  static int _parseRank(Map<String, dynamic> json) {
    final direct = _parseInt(
      json['rank'] ??
          json['seasonRank'] ??
          json['ranking'] ??
          json['badgeRank'],
    );
    if (direct != null && direct > 0) return direct;

    final badgeType = _nullableString(json['badgeType'] ?? json['type']);
    return switch (badgeType?.toUpperCase()) {
      'FIRST_PLACE' || 'GOLD' || 'GOLD_MEDAL' => 1,
      'SECOND_PLACE' || 'SILVER' || 'SILVER_MEDAL' => 2,
      'THIRD_PLACE' || 'BRONZE' || 'BRONZE_MEDAL' => 3,
      _ => 0,
    };
  }

  UserBadge toDisplayBadge() {
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => name != null && name!.contains('금') ? '🥇'
          : name != null && name!.contains('은') ? '🥈'
          : name != null && name!.contains('동') ? '🥉'
          : '🏅',
    };

    final label = _buildLabel();
    return UserBadge(emoji: medal, label: label);
  }

  String _buildLabel() {
    if (name != null && name!.isNotEmpty) {
      return _shortLabel(name!);
    }

    if (seasonName != null && seasonName!.isNotEmpty) {
      return _shortLabel(seasonName!);
    }

    if (rank >= 1 && rank <= 3) {
      return '시즌 ${rank}위';
    }

    return '배지';
  }

  static String _shortLabel(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 6) return trimmed;
    return '${trimmed.substring(0, 5)}…';
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

class UserBadgeDisplay {
  static const displayCount = 4;

  static List<UserBadge> fromRecentBadges(List<RecentBadge> badges) {
    return badges
        .where((badge) => badge.rank > 0 || (badge.name?.isNotEmpty ?? false))
        .map((badge) => badge.toDisplayBadge())
        .take(displayCount)
        .toList();
  }

  static List<RecentBadge> parseList(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => RecentBadge.fromJson(item.cast<String, dynamic>()))
        .where(
          (badge) => badge.rank > 0 || (badge.name?.isNotEmpty ?? false),
        )
        .toList();
  }
}
