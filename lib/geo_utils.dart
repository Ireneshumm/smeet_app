import 'dart:math' as math;

/// Great-circle distance in kilometers (WGS84 approximation).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _rad(double d) => d * math.pi / 180.0;

String formatDistanceKm(double km) {
  if (km < 1) {
    return '${(km * 1000).round()} m away';
  }
  return '${km.toStringAsFixed(1)} km away';
}

/// Preset search centers (country → city label → lat, lng).
const Map<String, Map<String, (double lat, double lng)>> kPresetCityCenters = {
  'Australia': {
    'Brisbane': (-27.4705, 153.0260),
    'Sydney': (-33.8688, 151.2093),
    'Melbourne': (-37.8136, 144.9631),
    'Perth': (-31.9505, 115.8605),
    'Adelaide': (-34.9285, 138.6007),
  },
};
