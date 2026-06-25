import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layouts/login_layout.dart';
import '../models/quiz.dart';
import '../models/quiz_result.dart';
import '../models/spot_quiz_summary.dart';
import '../utils/api_error_utils.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepository(ref.watch(dioProvider));
});

class QuizRepository {
  final Dio _dio;

  QuizRepository(this._dio);

  Future<Quiz> fetchQuiz(String quizId) async {
    try {
      final response = await _dio.get('/quizzes/$quizId');
      return _parseQuizResponse(response.data);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '퀴즈를 불러오지 못했습니다.'),
      );
    }
  }

  Future<List<SpotQuizSummary>> fetchSpotQuizzes(String spotId) async {
    try {
      final response = await _dio.get('/tourist-spots/$spotId/quizzes');
      return _parseSpotQuizList(response.data, spotId: spotId);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(
          e,
          fallback: '미션 정보를 불러오지 못했습니다.',
        ),
      );
    }
  }

  List<SpotQuizSummary> _parseSpotQuizList(
    dynamic data, {
    required String spotId,
  }) {
    final maps = _extractQuizMaps(data);
    if (maps.isEmpty) return const [];

    return maps
        .map(
          (item) => SpotQuizSummary.fromJson(item, fallbackSpotId: spotId),
        )
        .where((quiz) => quiz.id.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _extractQuizMaps(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (_looksLikeQuizMap(data)) {
        return [data];
      }

      final root = data['data'];
      if (root is Map<String, dynamic>) {
        if (_looksLikeQuizMap(root)) {
          return [root];
        }
        for (final key in ['quizzes', 'content', 'items', 'list']) {
          final list = _mapList(root[key]);
          if (list.isNotEmpty) return list;
        }
      }

      if (root is List) {
        final list = _mapList(root);
        if (list.isNotEmpty) return list;
      }

      for (final key in ['quizzes', 'content', 'items', 'list']) {
        final list = _mapList(data[key]);
        if (list.isNotEmpty) return list;
      }
    }

    if (data is List) {
      return _mapList(data);
    }

    return const [];
  }

  bool _looksLikeQuizMap(Map<String, dynamic> json) {
    return json.containsKey('id') ||
        json.containsKey('quizId') ||
        json.containsKey('questions') ||
        json.containsKey('quizQuestions') ||
        json.containsKey('questionCount');
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<QuizResult> submitQuiz({
    required String quizId,
    required List<QuizSubmitAnswer> answers,
  }) async {
    try {
      final response = await _dio.post(
        '/quizzes/$quizId/submit',
        data: {
          'answers': answers.map((answer) => answer.toJson()).toList(),
        },
      );

      try {
        return _parseQuizResult(
          response.data,
          quizId: quizId,
        );
      } catch (_) {
        return fetchQuizResult(quizId);
      }
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '퀴즈 제출에 실패했습니다.'),
      );
    }
  }

  Future<QuizResult> fetchQuizResult(String quizId) async {
    try {
      final response = await _dio.get('/quizzes/$quizId/result');
      return _parseQuizResult(response.data, quizId: quizId);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '퀴즈 결과를 불러오지 못했습니다.'),
      );
    }
  }

  QuizResult _parseQuizResult(
    dynamic data, {
    required String quizId,
  }) {
    final payload = _extractMap(data);
    return QuizResult.fromJson(payload, fallbackQuizId: quizId);
  }

  Future<QuizHistoryData> fetchQuizHistory() async {
    try {
      final response = await _dio.get('/quizzes/history');
      return _parseQuizHistoryPage(response.data);
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(e, fallback: '퀴즈 기록을 불러오지 못했습니다.'),
      );
    }
  }

  Future<Map<String, QuizResult>> fetchSpotHistoryMap() async {
    final page = await fetchQuizHistory();
    final map = <String, QuizResult>{};

    for (final spot in page.spots) {
      final id = spot.touristSpotId ?? spot.quizId;
      if (id.isEmpty) continue;
      map[id] = spot;
    }

    return map;
  }

  QuizHistoryData _parseQuizHistoryPage(dynamic data) {
    final root = _extractMap(data);
    final summaryRaw = root['summary'];
    final spotsRaw = root['touristSpots'];

    if (spotsRaw is List || summaryRaw is Map<String, dynamic>) {
      final summary = summaryRaw is Map<String, dynamic>
          ? QuizResultSummary.fromApiJson(summaryRaw)
          : const QuizResultSummary(
              totalScore: 0,
              averageCorrectRate: 0,
              perfectCount: 0,
            );

      final spots = spotsRaw is List
          ? spotsRaw
              .whereType<Map>()
              .map(
                (item) => QuizResult.fromHistorySpot(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList()
          : const <QuizResult>[];

      return QuizHistoryData(summary: summary, spots: spots);
    }

    final list = _extractList(data);
    final spots = list.map((item) => QuizResult.fromJson(item)).toList();
    return QuizHistoryData(
      summary: QuizResultSummary.fromResults(spots),
      spots: spots,
    );
  }

  Future<QuizResult> fetchQuizHistoryDetail(String touristSpotId) async {
    try {
      final response = await _dio.get(
        '/quizzes/history/tourist-spots/$touristSpotId',
      );
      return _parseQuizHistoryDetail(
        response.data,
        touristSpotId: touristSpotId,
      );
    } on DioException catch (e) {
      throw Exception(
        ApiErrorUtils.fromDioException(
          e,
          fallback: '퀴즈 기록 상세를 불러오지 못했습니다.',
        ),
      );
    }
  }

  QuizResult _parseQuizHistoryDetail(
    dynamic data, {
    required String touristSpotId,
  }) {
    final root = _extractMap(data);
    if (root.containsKey('submissions') || root.containsKey('touristSpotId')) {
      return QuizResult.fromHistoryDetail(root);
    }

    return QuizResult.fromJson(root, fallbackQuizId: touristSpotId);
  }

  Quiz _parseQuizResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      final root = data['data'];

      if (root is List && root.isNotEmpty) {
        final first = root.first;
        if (first is Map<String, dynamic>) {
          return Quiz.fromJson(first);
        }
        if (first is Map) {
          return Quiz.fromJson(first.cast<String, dynamic>());
        }
      }

      if (root is Map<String, dynamic>) {
        return Quiz.fromJson(root);
      }

      return Quiz.fromJson(data);
    }

    throw Exception('퀴즈 응답 형식이 올바르지 않습니다.');
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final root = data['data'];
      if (root is Map<String, dynamic>) {
        return root;
      }
      return data;
    }

    throw Exception('퀴즈 응답 형식이 올바르지 않습니다.');
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
        for (final key in ['history', 'results', 'items', 'list', 'touristSpots']) {
          final value = root[key];
          if (value is List) {
            return value.cast<Map<String, dynamic>>();
          }
        }
      }

      for (final key in ['history', 'content', 'results']) {
        final value = data[key];
        if (value is List) {
          return value.cast<Map<String, dynamic>>();
        }
      }

      final results = data['results'];
      if (results is List) {
        return results.cast<Map<String, dynamic>>();
      }
    }

    throw Exception('퀴즈 기록 형식이 올바르지 않습니다.');
  }
}
