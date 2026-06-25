import 'dart:convert';

class JwtUtils {
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool isExpired(
    String token, {
    Duration leeway = const Duration(seconds: 30),
  }) {
    final payload = decodePayload(token);
    if (payload == null) return true;

    final exp = payload['exp'];
    if (exp == null) return false;

    final expiresAt = exp is int
        ? exp
        : int.tryParse(exp.toString()) ?? 0;
    if (expiresAt <= 0) return false;

    final nowSeconds =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + leeway.inSeconds;
    return nowSeconds >= expiresAt;
  }

  static bool hasAdminRole(String accessToken) {
    final payload = decodePayload(accessToken);
    if (payload == null) return false;

    final role = payload['role'] ??
        payload['memberRole'] ??
        payload['userRole'] ??
        payload['authority'];
    if (role != null && isAdminRole(role.toString())) {
      return true;
    }

    final authorities = payload['authorities'] ?? payload['roles'];
    if (authorities is List) {
      return authorities.any((item) => isAdminRole(item.toString()));
    }

    return false;
  }

  static bool isAdminRole(String role) {
    final normalized = role.toUpperCase();
    return normalized == 'ADMIN' ||
        normalized == 'ROLE_ADMIN' ||
        normalized.contains('ADMIN');
  }

  static String? readClaim(String token, List<String> keys) {
    final payload = decodePayload(token);
    if (payload == null) return null;

    for (final key in keys) {
      final value = payload[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }
}
