abstract final class NicknameRules {
  static const minLength = 2;
  static const maxLength = 10;

  static final pattern = RegExp(r'^[a-zA-Z0-9_\uAC00-\uD7A3]+$');

  static bool isValid(String nickname) {
    final trimmed = nickname.trim();
    return trimmed.length >= minLength &&
        trimmed.length <= maxLength &&
        pattern.hasMatch(trimmed);
  }

  static String temporaryFromEmail(String email) {
    var local = email
        .split('@')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\uAC00-\uD7A3]'), '');

    if (local.isEmpty) return '탐험가';

    if (local.length > maxLength) {
      local = local.substring(0, maxLength);
    }

    if (local.length < minLength) {
      local = '${local}0'.substring(0, minLength);
    }

    return local;
  }

  static String get lengthHint => '$minLength~$maxLength자 · 한글/영문/숫자 사용 가능';
}
