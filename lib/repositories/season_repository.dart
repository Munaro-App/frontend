import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layouts/login_layout.dart';
import '../models/ranking.dart';
import '../utils/api_error_utils.dart';

final seasonRepositoryProvider = Provider<SeasonRepository>((ref) {
  return SeasonRepository(ref.watch(dioProvider));
});

class SeasonRepository {
  final Dio _dio;

  SeasonRepository(this._dio);

  Future<SeasonOption> fetchCurrentSeason() async {
    try {
      final response = await _dio.get('/seasons/current');
      final map = _extractMap(response.data);
      return SeasonOption.fromJson(map);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '현재 시즌을 불러오지 못했습니다.'),
      );
    }
  }

  Future<List<SeasonOption>> fetchSeasons() async {
    try {
      final response = await _dio.get('/seasons');
      final list = _extractList(response.data);
      if (list.isEmpty) return const [];

      return list.map(SeasonOption.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '시즌 목록을 불러오지 못했습니다.'),
      );
    }
  }

  Future<List<SeasonOption>> fetchSeasonTabs() async {
    try {
      final current = await fetchCurrentSeason();
      final all = await fetchSeasons();
      final tabs = <SeasonOption>[];
      final seen = <String>{};

      void addTab(SeasonOption season) {
        if (season.id.isEmpty || seen.contains(season.id)) return;
        seen.add(season.id);
        tabs.add(season);
      }

      addTab(current);
      for (final season in all) {
        addTab(season);
      }

      return tabs.isNotEmpty ? tabs : defaultSeasons;
    } catch (_) {
      return defaultSeasons;
    }
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final root = data['data'];
      if (root is Map<String, dynamic>) return root;
      return data;
    }
    throw Exception('시즌 응답 형식이 올바르지 않습니다.');
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
        for (final key in ['seasons', 'content', 'items', 'list']) {
          final value = root[key];
          if (value is List) {
            return value.cast<Map<String, dynamic>>();
          }
        }
      }

      for (final key in ['seasons', 'content', 'items', 'list']) {
        final value = data[key];
        if (value is List) {
          return value.cast<Map<String, dynamic>>();
        }
      }
    }

    return const [];
  }
}
