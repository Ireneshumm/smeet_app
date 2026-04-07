import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import 'package:smeet_app/geo_utils.dart';

class SmeetLocationService {
  /// Request permission and return current coordinates. Returns null on failure (silent).
  static Future<({double lat, double lng})?> getCurrentPosition() async {
    if (kIsWeb) return null;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Pick the nearest preset city label for [presets] (country → city → lat/lng).
  static String? nearestPresetCity(
    double lat,
    double lng,
    Map<String, Map<String, (double, double)>> presets,
  ) {
    String? bestCity;
    double bestDist = double.infinity;

    for (final country in presets.entries) {
      for (final city in country.value.entries) {
        final d = haversineKm(lat, lng, city.value.$1, city.value.$2);
        if (d < bestDist) {
          bestDist = d;
          bestCity = city.key;
        }
      }
    }
    return bestCity;
  }
}
