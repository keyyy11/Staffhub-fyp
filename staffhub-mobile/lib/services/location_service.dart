import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return null;
    }

    // Medium accuracy + time limit reduce emulator ANRs from long GPS fixes / permission stalls.
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 25),
    );
  }

  /// Distance in meters using the Haversine formula
  static double getDistanceInMeters(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double R = 6371000; // Earth radius in meters
    double dLat = _toRad(lat2 - lat1);
    double dLon = _toRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * (pi / 180);

  static bool isWithinRadius(
    double userLat, double userLng,
    double workplaceLat, double workplaceLng,
    int radiusMeters,
  ) {
    return getDistanceInMeters(userLat, userLng, workplaceLat, workplaceLng) <=
        radiusMeters;
  }
}
