import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../layouts/login_layout.dart';
import '../models/tourist_spot.dart';

final touristSpotRepositoryProvider = Provider<TouristSpotRepository>((ref) {
  return TouristSpotRepository(ref.watch(dioProvider));
});

class TouristSpotListResult {
  final List<TouristSpot> spots;
  final int totalElements;
  final int fetchedPages;

  const TouristSpotListResult({
    required this.spots,
    required this.totalElements,
    required this.fetchedPages,
  });
}

class TouristSpotRepository {
  final Dio _dio;

  TouristSpotRepository(this._dio);

  /// 관리자 전용: DB의 모든 관광지 조회
  Future<TouristSpotListResult> fetchAllSpots({
    int pageSize = 100,
    void Function(int loadedCount, int? totalElements)? onProgress,
  }) async {
    final allSpots = <TouristSpot>[];
    var page = 0;
    var totalElements = 0;
    var fetchedPages = 0;
    var hasMore = true;

    while (hasMore) {
      final response = await _dio.get(
        '/tourist-spots',
        queryParameters: {'page': page, 'size': pageSize},
      );

      final pageData = _extractPage(response.data);
      fetchedPages++;

      if (page == 0) {
        totalElements = pageData.totalElements;
      }

      allSpots.addAll(pageData.content.map(TouristSpot.fromJson));
      onProgress?.call(allSpots.length, totalElements > 0 ? totalElements : null);

      hasMore = !pageData.last && pageData.content.isNotEmpty;
      page++;

      if (page > 200) break;
    }

    if (totalElements == 0) {
      totalElements = allSpots.length;
    }

    return TouristSpotListResult(
      spots: allSpots,
      totalElements: totalElements,
      fetchedPages: fetchedPages,
    );
  }

  /// 일반 사용자: 위치 기반 주변 관광지 조회
  Future<List<TouristSpot>> fetchNearbySpots({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final response = await _dio.get(
      '/tourist-spots/nearby',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
      },
    );

    final list = _extractList(response.data);
    return list.map(TouristSpot.fromJson).toList();
  }

  Future<TouristSpot> fetchSpotDetail(String id) async {
    final response = await _dio.get('/tourist-spots/$id');
    final payload = _extractMap(response.data);
    return TouristSpot.fromJson(payload);
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
        final content = root['content'];
        if (content is List) {
          return content.cast<Map<String, dynamic>>();
        }
      }

      final content = data['content'];
      if (content is List) {
        return content.cast<Map<String, dynamic>>();
      }
    }

    throw Exception('관광지 목록 형식이 올바르지 않습니다.');
  }

  _PagePayload _extractPage(dynamic data) {
    final root = _extractPageRoot(data);
    final content = root['content'];

    if (content is! List) {
      throw Exception('관광지 목록 형식이 올바르지 않습니다.');
    }

    return _PagePayload(
      content: content.cast<Map<String, dynamic>>(),
      totalElements: _parseInt(root['totalElements']) ?? content.length,
      last: root['last'] == true || content.isEmpty,
    );
  }

  Map<String, dynamic> _extractPageRoot(dynamic data) {
    if (data is Map<String, dynamic>) {
      final nested = data['data'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      return data;
    }

    throw Exception('관광지 목록 형식이 올바르지 않습니다.');
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final root = data['data'];
      if (root is Map<String, dynamic>) {
        if (root['content'] is! List) {
          return root;
        }
      }
      return data;
    }

    throw Exception('관광지 상세 형식이 올바르지 않습니다.');
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class _PagePayload {
  final List<Map<String, dynamic>> content;
  final int totalElements;
  final bool last;

  const _PagePayload({
    required this.content,
    required this.totalElements,
    required this.last,
  });
}
