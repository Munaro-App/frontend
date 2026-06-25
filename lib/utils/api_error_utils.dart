import 'package:dio/dio.dart';

class ApiErrorUtils {
  ApiErrorUtils._();

  static String messageFromResponse(
    dynamic data, {
    required String fallback,
  }) {
    if (data is! Map) return fallback;

    final error = data['error'];
    if (error is Map) {
      final message = error['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
      final code = error['code'];
      if (code != null && code.toString().trim().isNotEmpty) {
        return code.toString().trim();
      }
    }

    final legacyMessage = data['message'];
    if (legacyMessage != null && legacyMessage.toString().trim().isNotEmpty) {
      return legacyMessage.toString().trim();
    }

    return fallback;
  }

  static String fromDioException(
    DioException exception, {
    required String fallback,
  }) {
    final statusCode = exception.response?.statusCode;
    final parsed = messageFromResponse(exception.response?.data, fallback: fallback);

    if (statusCode == 401 || statusCode == 403) {
      if (parsed == fallback || parsed.trim().isEmpty) {
        return '로그인이 필요하거나 세션이 만료되었습니다. 다시 로그인해 주세요.';
      }
    }

    return parsed;
  }

  static String readable(
    Object error, {
    String fallback = '요청 처리 중 오류가 발생했습니다.',
  }) {
    final text = error.toString();
    const prefix = 'Exception: ';
    if (text.startsWith(prefix)) {
      final message = text.substring(prefix.length).trim();
      return message.isEmpty ? fallback : message;
    }
    return text.isEmpty ? fallback : text;
  }

  static Map<String, String> fieldMessages(String message) {
    final result = <String, String>{};
    for (final part in message.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final idx = trimmed.indexOf(' : ');
      if (idx == -1) continue;

      final field = trimmed.substring(0, idx).trim();
      final value = trimmed.substring(idx + 3).trim();
      if (field.isNotEmpty && value.isNotEmpty) {
        result[field] = value;
      }
    }
    return result;
  }
}
