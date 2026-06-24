import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layouts/login_layout.dart';
import '../models/activity_history.dart';
import '../models/avatar_upload.dart';
import '../models/ranking.dart';
import '../models/user_profile.dart';
import '../utils/api_error_utils.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(dioProvider));
});

class UserRepository {
  final Dio _dio;

  UserRepository(this._dio);

  Future<UserProfile> fetchMe() async {
    try {
      final response = await _dio.get('/users/me');
      return UserProfile.fromJson(_extractMap(response.data));
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '내 정보를 불러오지 못했습니다.'),
      );
    }
  }

  Future<UserProfile> updateProfile({
    required String nickname,
    String? avatarValue,
  }) async {
    try {
      final data = <String, dynamic>{'nickname': nickname};
      if (avatarValue != null && avatarValue.isNotEmpty) {
        final normalized = normalizeAvatarValue(avatarValue);
        if (normalized != null) {
          data['avatarType'] = AvatarTypes.preset;
          data['avatarValue'] = toApiPresetAvatarValue(normalized);
        }
      }

      await _dio.patch(
        '/users/me/profile',
        data: data,
      );
      return fetchMe();
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '프로필을 저장하지 못했습니다.'),
      );
    }
  }

  Future<List<ActivityHistoryItem>> fetchHistory() async {
    try {
      final response = await _dio.get('/me/history');
      final list = _extractList(response.data);
      return list.map(ActivityHistoryItem.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '활동 기록을 불러오지 못했습니다.'),
      );
    }
  }

  Future<ActivityHistoryDetail> fetchHistoryDetail(String submissionId) async {
    try {
      final response = await _dio.get('/me/history/$submissionId');
      final payload = _extractMap(response.data);
      return ActivityHistoryDetail.fromJson(payload);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '활동 상세를 불러오지 못했습니다.'),
      );
    }
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final root = data['data'];
      if (root is Map<String, dynamic>) return root;
      return data;
    }
    throw Exception('응답 형식이 올바르지 않습니다.');
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }

    if (data is Map<String, dynamic>) {
      final root = data['data'];

      if (root is List) {
        return root.cast<Map<String, dynamic>>();
      }

      if (root is Map<String, dynamic>) {
        final content = root['content'] ?? root['history'] ?? root['items'];
        if (content is List) {
          return content.cast<Map<String, dynamic>>();
        }
      }

      for (final key in ['history', 'content', 'items', 'results']) {
        final value = data[key];
        if (value is List) {
          return value.cast<Map<String, dynamic>>();
        }
      }
    }

    throw Exception('활동 기록 형식이 올바르지 않습니다.');
  }
}
