import 'dart:math';

class GeoUtils {
  static const earthRadiusKm = 6371.0;

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double radiusKmForZoom(int zoomLevel) {
    return 2 * pow(1.35, zoomLevel).toDouble();
  }

  static bool isInKorea(double latitude, double longitude) {
    return latitude >= 33.0 &&
        latitude <= 38.7 &&
        longitude >= 124.5 &&
        longitude <= 132.0;
  }

  static String formatDistanceKm(double km) {
    if (km < 1) {
      return '${(km * 1000).round()}m';
    }
    return '${km.toStringAsFixed(1)}km';
  }

  static double _toRadians(double degree) => degree * pi / 180;
}
