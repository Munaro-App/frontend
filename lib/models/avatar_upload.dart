class AvatarTypes {
  static const uploaded = 'UPLOADED';
  static const preset = 'PRESET';
}

class AvatarUploadUrl {
  final String uploadUrl;
  final String? avatarKey;
  final String? avatarUrl;
  final String? avatarValue;

  const AvatarUploadUrl({
    required this.uploadUrl,
    this.avatarKey,
    this.avatarUrl,
    this.avatarValue,
  });

  String? get publicImageUrl {
    for (final candidate in [avatarValue, avatarUrl]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  factory AvatarUploadUrl.fromJson(Map<String, dynamic> json) {
    return AvatarUploadUrl(
      uploadUrl: (json['uploadUrl'] ??
              json['presignedUrl'] ??
              json['preSignedUrl'] ??
              json['url'] ??
              '')
          .toString(),
      avatarKey: _nullableString(
        json['avatarKey'] ??
            json['objectKey'] ??
            json['key'] ??
            json['storageKey'],
      ),
      avatarUrl: _nullableString(
        json['avatarUrl'] ?? json['imageUrl'] ?? json['profileImageUrl'],
      ),
      avatarValue: _nullableString(json['avatarValue'] ?? json['avatar_value']),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
