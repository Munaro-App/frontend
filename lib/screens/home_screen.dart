import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import '../layouts/login_layout.dart';
import '../models/quiz_result.dart';
import '../models/ranking.dart';
import '../models/tourist_spot.dart';
import '../repositories/quiz_repository.dart';
import '../repositories/ranking_repository.dart';
import '../repositories/season_repository.dart';
import '../repositories/tourist_spot_repository.dart';
import '../utils/geo_utils.dart';
import '../utils/api_error_utils.dart';
import 'heritage_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static final _defaultCenter = LatLng(37.579617, 126.977041);
  static const _minZoomLevel = 1;
  static const _maxZoomLevel = 14;
  static const _userMarkerId = 'user_location';
  static const _nearbyReloadDistanceM = 300.0;
  static const _markerRefreshInterval = Duration(seconds: 2);

  KakaoMapController? mapController;
  StreamSubscription<Position>? _locationSubscription;
  LatLng? _lastNearbyLoadLocation;
  DateTime? _lastMarkerRefreshAt;
  bool _followUserLocation = false;
  List<Marker> markers = [];
  List<TouristSpot> _allSpots = [];
  final Map<String, TouristSpot> _spotByMarkerId = {};
  LatLng? _userLocation;
  int _currentZoomLevel = 5;
  double _visibleRadiusKm = 0;
  bool isLoading = true;
  bool _isMapReady = false;
  String? _errorMessage;
  String? _locationMessage;
  int _totalSpotCount = 0;
  int _loadedSpotCount = 0;
  int _markerCount = 0;
  bool _isAdmin = false;
  bool _sheetExpanded = false;
  int? _seasonScore;
  String _seasonLabel = '현재 시즌';
  bool _isSeasonScoreLoading = true;
  Map<String, QuizResult> _spotHistoryById = {};
  Map<String, int> _maxRewardBySpotId = {};

  static const _accentBlue = Color(0xFF4F8EFF);
  static const _hudDark = Color(0xE60F121E);
  static const _scoreGold = Color(0xFFFCD34D);

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  LatLng get _mapDisplayCenter {
    if (_userLocation != null &&
        GeoUtils.isInKorea(_userLocation!.latitude, _userLocation!.longitude)) {
      return _userLocation!;
    }
    return _defaultCenter;
  }

  bool get _canShowUserMarkerOnMap {
    final location = _userLocation;
    if (location == null) return false;
    return GeoUtils.isInKorea(location.latitude, location.longitude);
  }

  Future<void> _initialize() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
      _locationMessage = null;
    });

    final auth = await ref.read(tokenStorageProvider).read();
    _isAdmin = auth?.isAdmin ?? false;

    if (!_isAdmin) {
      _loadSeasonScore();
    } else {
      _isSeasonScoreLoading = false;
    }

    LatLng? userLocation;
    try {
      final permission = await _resolveLocationPermission();
      if (_canUseLocation(permission)) {
        _startLocationStream();
        userLocation = await _readCurrentPosition();
      }
    } catch (_) {
      userLocation = null;
    }

    try {
      if (_isAdmin) {
        await _loadAllSpotsForAdmin();
      } else {
        if (userLocation == null) {
          if (!mounted) return;
          setState(() {
            isLoading = false;
            _locationMessage = _locationMessage ?? '주변 관광지를 보려면 위치 권한이 필요합니다.';
          });
          return;
        }

        _userLocation = userLocation;
        _lastNearbyLoadLocation = userLocation;
        await _loadNearbySpots(recenter: true);
      }

      if (!mounted) return;

      setState(() {
        _userLocation = userLocation ?? _userLocation;
        isLoading = false;
      });

      if (_isAdmin) {
        await _updateVisibleMarkers(recenter: true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _errorMessage = _dioErrorMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _errorMessage = '관광지 목록을 불러오지 못했습니다.';
      });
    }
  }

  int _spotPointsLoadToken = 0;

  Future<void> _loadSpotPoints() async {
    if (_isAdmin || _allSpots.isEmpty) return;

    final loadToken = ++_spotPointsLoadToken;

    try {
      final historyMap =
          await ref.read(quizRepositoryProvider).fetchSpotHistoryMap();
      if (!mounted || loadToken != _spotPointsLoadToken) return;

      final maxRewards = <String, int>{};
      final spotsToLoad = _allSpots.take(12).toList();

      for (final spot in spotsToLoad) {
        if (historyMap.containsKey(spot.id)) continue;

        try {
          final quizzes = await ref
              .read(quizRepositoryProvider)
              .fetchSpotQuizzes(spot.id);
          if (quizzes.isEmpty) continue;

          final maxPoints = quizzes.first.maxRewardPoints;
          if (maxPoints > 0) {
            maxRewards[spot.id] = maxPoints;
          }
        } catch (_) {}
      }

      if (!mounted || loadToken != _spotPointsLoadToken) return;
      setState(() {
        _spotHistoryById = historyMap;
        _maxRewardBySpotId = maxRewards;
      });
    } catch (_) {}
  }

  String? _pointsLabel(TouristSpot spot) {
    final history = _spotHistoryById[spot.id];
    if (history != null && history.earnedPoints > 0) {
      return '+${formatRankingScore(history.earnedPoints)}pt';
    }

    final maxReward = _maxRewardBySpotId[spot.id];
    if (maxReward != null && maxReward > 0) {
      return '최대 ${formatRankingScore(maxReward)}pt';
    }

    return null;
  }

  Future<void> _loadSeasonScore() async {
    if (!mounted) return;

    setState(() => _isSeasonScoreLoading = true);

    try {
      final profileFuture =
          ref.read(rankingRepositoryProvider).fetchMyProfile();
      final seasonFuture =
          ref.read(seasonRepositoryProvider).fetchCurrentSeason();

      final profile = await profileFuture;
      SeasonOption? currentSeason;
      try {
        currentSeason = await seasonFuture;
      } catch (_) {
        currentSeason = null;
      }

      if (!mounted) return;
      setState(() {
        _seasonScore = profile.totalScore;
        _seasonLabel = currentSeason?.label ?? '현재 시즌';
        _isSeasonScoreLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _seasonScore = 0;
        _isSeasonScoreLoading = false;
      });
    }
  }

  Future<void> _loadAllSpotsForAdmin() async {
    final result = await ref.read(touristSpotRepositoryProvider).fetchAllSpots(
          onProgress: (loadedCount, totalElements) {
            if (!mounted) return;
            setState(() {
              _loadedSpotCount = loadedCount;
              if (totalElements != null) {
                _totalSpotCount = totalElements;
              }
            });
          },
        );

    if (!mounted) return;

    setState(() {
      _allSpots = result.spots
          .where((spot) => spot.latitude != 0 && spot.longitude != 0)
          .toList();
      _totalSpotCount = result.totalElements;
      _loadedSpotCount = result.spots.length;
    });
  }

  Future<void> _loadNearbySpots({bool recenter = false}) async {
    if (_userLocation == null) return;

    try {
      final radiusKm = double.parse(
        GeoUtils.radiusKmForZoom(_currentZoomLevel).toStringAsFixed(1),
      );
      final spots =
          await ref.read(touristSpotRepositoryProvider).fetchNearbySpots(
                latitude: _userLocation!.latitude,
                longitude: _userLocation!.longitude,
                radiusKm: radiusKm,
              );

      if (!mounted) return;

      final validSpots = spots
          .where((spot) => spot.latitude != 0 && spot.longitude != 0)
          .toList();

      setState(() {
        _allSpots = validSpots;
        _visibleRadiusKm = radiusKm;
        _markerCount = validSpots.length;
        _errorMessage = null;
      });

      await _applyMarkersFromSpots(validSpots, recenter: recenter);
      await Future.wait([
        _loadSpotPoints(),
        _loadSeasonScore(),
      ]);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _dioErrorMessage(e);
      });
    }
  }

  Future<void> _applyMarkersFromSpots(
    List<TouristSpot> spots, {
    bool recenter = false,
  }) async {
    final spotByMarkerId = <String, TouristSpot>{};
    final visibleMarkers = spots.map((spot) {
      final markerId = 'spot_${spot.id}';
      spotByMarkerId[markerId] = spot;
      return Marker(
        markerId: markerId,
        latLng: LatLng(spot.latitude, spot.longitude),
        infoWindowContent: spot.name,
      );
    }).toList();

    setState(() {
      _spotByMarkerId
        ..clear()
        ..addAll(spotByMarkerId);
      markers = visibleMarkers;
      _markerCount = visibleMarkers.length;
    });

    await _applyMarkersToMap(recenter: recenter);
  }

  Future<LocationPermission> _resolveLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationMessage = '위치 서비스가 꺼져 있습니다.';
          });
        }
        return LocationPermission.denied;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationMessage = '위치 권한이 필요합니다.';
          });
        }
        return permission;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationMessage = '설정에서 위치 권한을 허용해 주세요.';
          });
        }
        return permission;
      }

      return permission;
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _locationMessage = '위치 기능 초기화가 필요합니다. 앱을 완전히 재시작해 주세요.';
        });
      }
      return LocationPermission.denied;
    }
  }

  bool _canUseLocation(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void _startLocationStream() {
    if (_locationSubscription != null) return;

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      _onPositionUpdate,
      onError: (_) {},
    );
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;

    final location = LatLng(position.latitude, position.longitude);
    final inKorea = GeoUtils.isInKorea(position.latitude, position.longitude);

    setState(() {
      _userLocation = location;
      _locationMessage = inKorea
          ? null
          : '현재 위치가 한국 밖입니다. 에뮬레이터 GPS를 한국으로 설정해 주세요.';
    });

    if (!inKorea) return;

    unawaited(_refreshUserMarkerIfNeeded());
    if (!_isAdmin) {
      unawaited(_reloadNearbyIfNeeded(location));
    }
  }

  Future<void> _refreshUserMarkerIfNeeded() async {
    if (!_canShowUserMarkerOnMap || !_isMapReady) return;

    final now = DateTime.now();
    if (_lastMarkerRefreshAt != null &&
        now.difference(_lastMarkerRefreshAt!) < _markerRefreshInterval) {
      if (_followUserLocation) {
        mapController?.setCenter(_userLocation!);
      }
      return;
    }

    _lastMarkerRefreshAt = now;
    await _applyMarkersToMap(recenter: _followUserLocation);
  }

  Future<void> _reloadNearbyIfNeeded(LatLng location) async {
    final lastLoad = _lastNearbyLoadLocation;
    if (lastLoad != null) {
      final movedM = GeoUtils.distanceKm(
            lastLoad.latitude,
            lastLoad.longitude,
            location.latitude,
            location.longitude,
          ) *
          1000;
      if (movedM < _nearbyReloadDistanceM) return;
    }

    _lastNearbyLoadLocation = location;
    await _loadNearbySpots();
  }

  Future<LatLng?> _readCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _locationMessage = GeoUtils.isInKorea(
            position.latitude,
            position.longitude,
          )
              ? null
              : '현재 위치가 한국 밖입니다. 에뮬레이터 GPS를 한국으로 설정해 주세요.';
        });
      }
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationMessage = '현재 위치를 가져오지 못했습니다.';
        });
      }
      return null;
    }
  }

  Future<void> _updateVisibleMarkers({bool recenter = false}) async {
    if (!_isAdmin) {
      await _loadNearbySpots(recenter: recenter);
      return;
    }

    if (_allSpots.isEmpty) {
      setState(() {
        _spotByMarkerId.clear();
        markers = [];
        _markerCount = 0;
      });
      await _applyMarkersToMap(recenter: recenter);
      return;
    }

    await _applyMarkersFromSpots(_allSpots, recenter: recenter);
  }

  String _dioErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '서버 응답 시간이 초과되었습니다.';
      case DioExceptionType.connectionError:
        return '서버에 연결할 수 없습니다.\n서버 실행 후 다시 시도해 주세요.';
      default:
        return ApiErrorUtils.fromDioException(
          error,
          fallback: '관광지 목록을 불러오지 못했습니다.',
        );
    }
  }

  Future<void> _applyMarkersToMap({bool recenter = false}) async {
    final controller = mapController;
    if (!_isMapReady || controller == null) {
      return;
    }

    await controller.clearMarker();

    final markersToShow = [...markers];
    if (_canShowUserMarkerOnMap) {
      markersToShow.add(
        Marker(
          markerId: _userMarkerId,
          latLng: _userLocation!,
          width: 28,
          height: 28,
          infoWindowContent: '내 위치',
          zIndex: 10,
        ),
      );
    }

    if (markersToShow.isEmpty) {
      if (recenter) {
        controller.setCenter(_mapDisplayCenter);
      }
      return;
    }

    await controller.addMarker(markers: markersToShow);

    if (recenter) {
      if (_canShowUserMarkerOnMap) {
        controller.setCenter(_userLocation!);
      } else if (markers.length == 1) {
        controller.setCenter(markers.first.latLng);
      } else if (markers.isNotEmpty) {
        await controller.fitBounds(
          markers.map((marker) => marker.latLng).toList(),
        );
      } else {
        controller.setCenter(_mapDisplayCenter);
      }
    }
  }

  Future<void> _changeZoom(int delta) async {
    final controller = mapController;
    if (!_isMapReady || controller == null) return;

    final currentLevel = await controller.getLevel();
    final newLevel = (currentLevel + delta).clamp(_minZoomLevel, _maxZoomLevel);
    if (newLevel != currentLevel) {
      _currentZoomLevel = newLevel;
      controller.setLevel(newLevel);
      if (!_isAdmin) {
        await _loadNearbySpots();
      }
    }
  }

  Future<void> _moveToMyLocation() async {
    final permission = await _resolveLocationPermission();
    if (!_canUseLocation(permission)) return;

    _startLocationStream();

    final location = await _readCurrentPosition();
    if (!mounted || location == null) return;

    setState(() {
      _userLocation = location;
      _lastNearbyLoadLocation = location;
      _followUserLocation = true;
    });

    mapController?.setCenter(_mapDisplayCenter);

    if (_isAdmin) {
      await _applyMarkersToMap(recenter: true);
    } else {
      await _loadNearbySpots(recenter: true);
    }
  }

  String _distanceLabel(TouristSpot spot) {
    if (_userLocation == null) return '';
    final km = GeoUtils.distanceKm(
      _userLocation!.latitude,
      _userLocation!.longitude,
      spot.latitude,
      spot.longitude,
    );
    return GeoUtils.formatDistanceKm(km);
  }

  Future<void> _showSpotDetail(TouristSpot spot) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HeritageDetailScreen(spot: spot),
      ),
    );
    if (!mounted) return;
    await Future.wait([
      _loadSpotPoints(),
      _loadSeasonScore(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _mapDisplayCenter;
    final sheetHeight = _sheetExpanded ? 320.0 : 210.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                KakaoMap(
                  center: mapCenter,
                  currentLevel: _currentZoomLevel,
                  onMapCreated: (controller) async {
                    mapController = controller;
                    _isMapReady = true;
                    _currentZoomLevel = await controller.getLevel();
                    controller.setCenter(_mapDisplayCenter);
                    if (_isAdmin) {
                      await _updateVisibleMarkers(recenter: true);
                    } else if (_userLocation != null) {
                      await _loadNearbySpots(recenter: true);
                    } else {
                      await _applyMarkersToMap(recenter: true);
                    }
                  },
                  onMarkerTap: (markerId, latLng, zoomLevel) {
                    if (markerId == _userMarkerId) return;
                    final spot = _spotByMarkerId[markerId];
                    if (spot != null) {
                      _showSpotDetail(spot);
                    }
                  },
                  onZoomChangeCallback: (zoomLevel, zoomType) {
                    if (_isAdmin) return;
                    if (_currentZoomLevel == zoomLevel) return;
                    _currentZoomLevel = zoomLevel;
                    _loadNearbySpots();
                  },
                  minLevel: _minZoomLevel,
                  maxLevel: _maxZoomLevel,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SeasonHud(
                            isAdmin: _isAdmin,
                            isLoading: isLoading,
                            isScoreLoading: _isSeasonScoreLoading,
                            seasonScore: _seasonScore,
                            seasonLabel: _seasonLabel,
                            markerCount: _markerCount,
                            totalCount: _totalSpotCount,
                            loadedCount: _loadedSpotCount,
                          ),
                          const Spacer(),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _QuickActionButton(
                                emoji: '🏆',
                                onTap: () => widget.onNavigateToTab?.call(2),
                              ),
                              const SizedBox(height: 8),
                              _QuickActionButton(
                                emoji: '👤',
                                onTap: () => widget.onNavigateToTab?.call(3),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 16,
                  child: Column(
                    children: [
                      _MapControlButton(
                        child: const Text('📍', style: TextStyle(fontSize: 22)),
                        onPressed: _moveToMyLocation,
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        child: const Icon(Icons.add, color: _accentBlue),
                        onPressed: () => _changeZoom(-1),
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        child: const Icon(Icons.remove, color: _accentBlue),
                        onPressed: () => _changeZoom(1),
                      ),
                    ],
                  ),
                ),
                if (_locationMessage != null && !isLoading)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _InfoBanner(
                      message: _locationMessage!,
                      isError: false,
                    ),
                  ),
                if (_errorMessage != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _InfoBanner(
                      message: _errorMessage!,
                      isError: true,
                      onRetry: _initialize,
                    ),
                  ),
                if (isLoading)
                  const ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: sheetHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _sheetExpanded = !_sheetExpanded),
                          child: Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1D5DB),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _isAdmin ? null : _moveToMyLocation,
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isAdmin
                                          ? '🗺 관리자 전체 관광지'
                                          : '📍 내 주변 문화유산',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1D23),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isAdmin
                                          ? '전체 $_markerCount곳 표시 중'
                                          : '현재 위치 기준 · $_markerCount곳 발견',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_allSpots.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  if (_allSpots.isNotEmpty) {
                                    _showSpotDetail(_allSpots.first);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: _accentBlue,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '전체보기 →',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _allSpots.isEmpty
                      ? Center(
                          child: Text(
                            isLoading
                                ? '주변 장소를 불러오는 중...'
                                : (_locationMessage ?? '주변에 표시할 장소가 없습니다.'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                          itemCount: _allSpots.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final spot = _allSpots[index];
                            return Align(
                              alignment: Alignment.topCenter,
                              child: _NearbySpotCard(
                                spot: spot,
                                distance: _distanceLabel(spot),
                                pointsLabel: _pointsLabel(spot),
                                onTap: () => _showSpotDetail(spot),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonHud extends StatelessWidget {
  final bool isAdmin;
  final bool isLoading;
  final bool isScoreLoading;
  final int? seasonScore;
  final String seasonLabel;
  final int markerCount;
  final int totalCount;
  final int loadedCount;

  const _SeasonHud({
    required this.isAdmin,
    required this.isLoading,
    required this.isScoreLoading,
    required this.seasonScore,
    required this.seasonLabel,
    required this.markerCount,
    required this.totalCount,
    required this.loadedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _HomeScreenState._hudDark,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdmin ? '관리자 · 전체 지도' : seasonLabel,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.55),
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: '⭐ ',
                  style: TextStyle(fontSize: 16),
                ),
                TextSpan(
                  text: isAdmin
                      ? (isLoading ? '...' : '$markerCount')
                      : (isScoreLoading
                          ? '...'
                          : formatRankingScore(seasonScore ?? 0)),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _HomeScreenState._scoreGold,
                  ),
                ),
                TextSpan(
                  text: isAdmin ? '곳' : 'pt',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading && isAdmin && totalCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$loadedCount / $totalCount',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String emoji;
  final VoidCallback? onTap;

  const _QuickActionButton({required this.emoji, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.child,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(width: 46, height: 46, child: Center(child: child)),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  const _InfoBanner({
    required this.message,
    required this.isError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? Colors.red.shade700 : _HomeScreenState._accentBlue,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: isError ? Colors.red.shade900 : const Color(0xFF1E40AF),
                ),
              ),
            ),
            if (onRetry != null)
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

class _NearbySpotCard extends StatelessWidget {
  final TouristSpot spot;
  final String distance;
  final String? pointsLabel;
  final VoidCallback onTap;

  const _NearbySpotCard({
    required this.spot,
    required this.distance,
    required this.pointsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 136,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E8EF), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('🏛', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(height: 6),
              Text(
                spot.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D23),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      distance.isEmpty ? '거리 정보 없음' : distance,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  if (pointsLabel != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      pointsLabel!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _HomeScreenState._accentBlue,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}