class RankingEntry {
  final int rank;
  final String nickname;
  final int score;
  final int? rankChange;
  final bool isMe;
  final String? avatarValue;
  final String? avatarEmoji;
  final String? avatarUrl;

  const RankingEntry({
    required this.rank,
    required this.nickname,
    required this.score,
    this.rankChange,
    this.isMe = false,
    this.avatarValue,
    this.avatarEmoji,
    this.avatarUrl,
  });

  RankingEntry copyWith({
    int? rank,
    String? nickname,
    int? score,
    int? rankChange,
    bool? isMe,
    String? avatarValue,
    String? avatarEmoji,
    String? avatarUrl,
  }) {
    return RankingEntry(
      rank: rank ?? this.rank,
      nickname: nickname ?? this.nickname,
      score: score ?? this.score,
      rankChange: rankChange ?? this.rankChange,
      isMe: isMe ?? this.isMe,
      avatarValue: avatarValue ?? this.avatarValue,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  String get changeLabel {
    if (rankChange == null || rankChange == 0) return '–';
    if (rankChange! > 0) return '+$rankChange';
    return '$rankChange';
  }

  bool get isRankUp => rankChange != null && rankChange! > 0;
  bool get isRankDown => rankChange != null && rankChange! < 0;

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    final rawAvatarValue = json['avatarValue'] ?? json['avatar_value'];
    final normalizedAvatar = normalizeAvatarValue(
      rawAvatarValue?.toString(),
    );

    return RankingEntry(
      rank: _parseInt(json['rank'] ?? json['ranking'] ?? json['position']) ?? 0,
      nickname: (json['nickname'] ??
              json['name'] ??
              json['userName'] ??
              json['username'] ??
              '탐험가')
          .toString(),
      score: _parseInt(
            json['score'] ?? json['points'] ?? json['totalScore'] ?? json['totalPoints'],
          ) ??
          0,
      rankChange: _parseInt(
        json['rankChange'] ?? json['change'] ?? json['rankDelta'] ?? json['delta'],
      ),
      isMe: json['isMe'] == true || json['mine'] == true || json['me'] == true,
      avatarValue: normalizedAvatar ?? _nullableString(rawAvatarValue),
      avatarEmoji: _nullableString(
        json['avatarEmoji'] ?? json['avatar'] ?? json['profileEmoji'],
      ),
      avatarUrl: _nullableString(
        json['avatarUrl'] ?? json['avatarImageUrl'] ?? json['profileImageUrl'],
      ),
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

class SeasonOption {
  final String id;
  final String label;

  const SeasonOption({required this.id, required this.label});

  factory SeasonOption.fromJson(Map<String, dynamic> json) {
    return SeasonOption(
      id: (json['id'] ?? json['seasonId'] ?? '').toString(),
      label: (json['name'] ??
              json['label'] ??
              json['seasonName'] ??
              json['title'] ??
              '시즌')
          .toString(),
    );
  }
}

class RankingPageData {
  final List<RankingEntry> entries;
  final RankingEntry? myRank;
  final List<SeasonOption> seasons;

  const RankingPageData({
    required this.entries,
    this.myRank,
    this.seasons = const [],
  });

  List<RankingEntry> get topThree {
    final sorted = [...entries]..sort((a, b) => a.rank.compareTo(b.rank));
    return sorted.take(3).toList();
  }

  List<RankingEntry> get listFromFourth {
    final sorted = [...entries]..sort((a, b) => a.rank.compareTo(b.rank));
    return sorted.where((entry) => entry.rank > 3).toList();
  }

  RankingEntry? get second => _entryAtRank(2);
  RankingEntry? get first => _entryAtRank(1);
  RankingEntry? get third => _entryAtRank(3);

  RankingEntry? _entryAtRank(int rank) {
    for (final entry in entries) {
      if (entry.rank == rank) return entry;
    }
    return null;
  }
}

String formatRankingScore(int score) {
  final text = score.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}

const defaultSeasons = [
  SeasonOption(id: 'current', label: '현재 시즌'),
  SeasonOption(id: '1', label: '시즌 1 · 봄 탐험'),
  SeasonOption(id: '2', label: '시즌 2 · 여름 탐험'),
  SeasonOption(id: '3', label: '시즌 3 · 가을 탐험'),
  SeasonOption(id: '4', label: '시즌 4 · 겨울 탐험'),
];

const rankingAvatars = ['🦁', '🐯', '🦊', '🐺', '🐻', '🦝', '🦅', '🐬'];

class ProfileAvatarOption {
  final String emoji;
  final String name;
  final String value;

  const ProfileAvatarOption({
    required this.emoji,
    required this.name,
    required this.value,
  });
}

const profileAvatars = [
  ProfileAvatarOption(emoji: '🦁', name: '사자', value: 'lion'),
  ProfileAvatarOption(emoji: '🐯', name: '호랑이', value: 'tiger'),
  ProfileAvatarOption(emoji: '🐺', name: '늑대', value: 'wolf'),
  ProfileAvatarOption(emoji: '🦊', name: '여우', value: 'fox'),
  ProfileAvatarOption(emoji: '🐻', name: '곰', value: 'bear'),
  ProfileAvatarOption(emoji: '🦝', name: '너구리', value: 'raccoon'),
  ProfileAvatarOption(emoji: '🦅', name: '독수리', value: 'eagle'),
  ProfileAvatarOption(emoji: '🐬', name: '돌고래', value: 'dolphin'),
];

const _legacyAvatarValues = {
  'default_avatar': 'fox',
};

String? normalizeAvatarValue(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  final value = raw.trim().toLowerCase();
  final legacy = _legacyAvatarValues[value];
  if (legacy != null) return legacy;

  for (final avatar in profileAvatars) {
    if (avatar.value == value) return avatar.value;
  }

  return null;
}

String toApiPresetAvatarValue(String value) {
  return value.trim().toUpperCase();
}

int indexForAvatarValue(String? avatarValue, {String? avatarEmoji, String? nickname}) {
  final normalized = normalizeAvatarValue(avatarValue);
  if (normalized != null) {
    final index = profileAvatars.indexWhere((avatar) => avatar.value == normalized);
    if (index >= 0) return index;
  }

  if (avatarEmoji != null && avatarEmoji.isNotEmpty) {
    final index = profileAvatars.indexWhere((avatar) => avatar.emoji == avatarEmoji);
    if (index >= 0) return index;
  }

  if (nickname != null && nickname.isNotEmpty) {
    return rankingAvatars.indexOf(avatarForNickname(nickname)).clamp(0, profileAvatars.length - 1);
  }

  return 0;
}

String? avatarValueForEmoji(String? emoji) {
  if (emoji == null || emoji.isEmpty) return null;
  for (final avatar in profileAvatars) {
    if (avatar.emoji == emoji) return avatar.value;
  }
  return null;
}

String? avatarEmojiForValue(String? value) {
  final normalized = normalizeAvatarValue(value);
  if (normalized == null) return null;
  for (final avatar in profileAvatars) {
    if (avatar.value == normalized) return avatar.emoji;
  }
  return null;
}

String avatarForNickname(String nickname) {
  if (nickname.isEmpty) return '🦊';
  return rankingAvatars[nickname.hashCode.abs() % rankingAvatars.length];
}

String avatarForProfile({
  String? avatarValue,
  String? avatarEmoji,
  required String nickname,
}) {
  final fromValue = avatarEmojiForValue(avatarValue);
  if (fromValue != null) return fromValue;

  if (avatarEmoji != null &&
      avatarEmoji.isNotEmpty &&
      rankingAvatars.contains(avatarEmoji)) {
    return avatarEmoji;
  }
  return avatarForNickname(nickname);
}
