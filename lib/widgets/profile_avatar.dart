import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/ranking.dart';

String? resolveProfileImageUrl(String? raw) {
  final url = raw?.trim();
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  final base = (dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080')
      .replaceAll(RegExp(r'/+$'), '');
  if (url.startsWith('/')) return '$base$url';
  return '$base/$url';
}

class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? avatarValue;
  final String? avatarEmoji;
  final String nickname;
  final double size;
  final double emojiSize;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? backgroundGradient;

  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    this.avatarValue,
    this.avatarEmoji,
    required this.nickname,
    this.size = 60,
    this.emojiSize = 28,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.backgroundGradient,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveProfileImageUrl(
      avatarUrl ?? _urlLikeAvatarValue(avatarValue),
    );
    final radius = borderRadius ?? BorderRadius.circular(size / 2);
    final gradient = backgroundGradient ??
        const LinearGradient(
          colors: [Color(0xFF4F8EFF), Color(0xFF818CF8)],
        );

    Widget content;
    if (resolvedUrl != null) {
      content = Image.network(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _EmojiAvatar(
          emoji: avatarForProfile(
            avatarValue: avatarValue,
            avatarEmoji: avatarEmoji,
            nickname: nickname,
          ),
          emojiSize: emojiSize,
        ),
      );
    } else {
      content = _EmojiAvatar(
        emoji: avatarForProfile(
          avatarValue: avatarValue,
          avatarEmoji: avatarEmoji,
          nickname: nickname,
        ),
        emojiSize: emojiSize,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: resolvedUrl != null ? null : gradient,
        borderRadius: radius,
        border: border,
        boxShadow: boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class _EmojiAvatar extends StatelessWidget {
  final String emoji;
  final double emojiSize;

  const _EmojiAvatar({required this.emoji, required this.emojiSize});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
    );
  }
}

String? _urlLikeAvatarValue(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('/')) {
    return value;
  }
  return null;
}
