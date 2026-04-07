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
    'Brisbane': (-27.4698, 153.0251),
    'Sydney': (-33.8688, 151.2093),
    'Melbourne': (-37.8136, 144.9631),
    'Perth': (-31.9505, 115.8605),
    'Adelaide': (-34.9285, 138.6007),
    'Gold Coast': (-28.0167, 153.4000),
  },
  'United States': {
    'New York': (40.7128, -74.0060),
    'Los Angeles': (34.0522, -118.2437),
    'Chicago': (41.8781, -87.6298),
    'Houston': (29.7604, -95.3698),
    'Miami': (25.7617, -80.1918),
    'San Francisco': (37.7749, -122.4194),
    'Las Vegas': (36.1699, -115.1398),
    'Seattle': (47.6062, -122.3321),
  },
  'United Kingdom': {
    'London': (51.5074, -0.1278),
    'Manchester': (53.4808, -2.2426),
    'Birmingham': (52.4862, -1.8904),
    'Edinburgh': (55.9533, -3.1883),
  },
  'Canada': {
    'Toronto': (43.6532, -79.3832),
    'Vancouver': (49.2827, -123.1207),
    'Montreal': (45.5017, -73.5673),
    'Calgary': (51.0447, -114.0719),
  },
  'China': {
    'Shanghai': (31.2304, 121.4737),
    'Beijing': (39.9042, 116.4074),
    'Shenzhen': (22.5431, 114.0579),
    'Guangzhou': (23.1291, 113.2644),
    'Chengdu': (30.5728, 104.0668),
    'Hangzhou': (30.2741, 120.1551),
  },
  'Japan': {
    'Tokyo': (35.6762, 139.6503),
    'Osaka': (34.6937, 135.5023),
    'Kyoto': (35.0116, 135.7681),
    'Fukuoka': (33.5902, 130.4017),
  },
  'South Korea': {
    'Seoul': (37.5665, 126.9780),
    'Busan': (35.1796, 129.0756),
  },
  'Singapore': {
    'Singapore': (1.3521, 103.8198),
  },
  'Hong Kong': {
    'Hong Kong': (22.3193, 114.1694),
  },
  'Taiwan': {
    'Taipei': (25.0330, 121.5654),
    'Kaohsiung': (22.6273, 120.3014),
  },
  'Thailand': {
    'Bangkok': (13.7563, 100.5018),
    'Chiang Mai': (18.7883, 98.9853),
    'Phuket': (7.8804, 98.3923),
  },
  'Malaysia': {
    'Kuala Lumpur': (3.1390, 101.6869),
    'Penang': (5.4141, 100.3288),
  },
  'Indonesia': {
    'Jakarta': (-6.2088, 106.8456),
    'Bali': (-8.3405, 115.0920),
  },
  'Philippines': {
    'Manila': (14.5995, 120.9842),
    'Cebu': (10.3157, 123.8854),
  },
  'Vietnam': {
    'Ho Chi Minh City': (10.8231, 106.6297),
    'Hanoi': (21.0285, 105.8542),
  },
  'India': {
    'Mumbai': (19.0760, 72.8777),
    'Delhi': (28.7041, 77.1025),
    'Bangalore': (12.9716, 77.5946),
    'Chennai': (13.0827, 80.2707),
  },
  'UAE': {
    'Dubai': (25.2048, 55.2708),
    'Abu Dhabi': (24.4539, 54.3773),
  },
  'Germany': {
    'Berlin': (52.5200, 13.4050),
    'Munich': (48.1351, 11.5820),
    'Hamburg': (53.5753, 10.0153),
  },
  'France': {
    'Paris': (48.8566, 2.3522),
    'Lyon': (45.7640, 4.8357),
    'Nice': (43.7102, 7.2620),
  },
  'Spain': {
    'Madrid': (40.4168, -3.7038),
    'Barcelona': (41.3851, 2.1734),
  },
  'Italy': {
    'Rome': (41.9028, 12.4964),
    'Milan': (45.4642, 9.1900),
  },
  'Netherlands': {
    'Amsterdam': (52.3676, 4.9041),
  },
  'Switzerland': {
    'Zurich': (47.3769, 8.5417),
    'Geneva': (46.2044, 6.1432),
  },
  'New Zealand': {
    'Auckland': (-36.8485, 174.7633),
    'Wellington': (-41.2865, 174.7762),
    'Christchurch': (-43.5321, 172.6362),
  },
  'Brazil': {
    'São Paulo': (-23.5505, -46.6333),
    'Rio de Janeiro': (-22.9068, -43.1729),
  },
  'Mexico': {
    'Mexico City': (19.4326, -99.1332),
    'Cancún': (21.1619, -86.8515),
  },
  'South Africa': {
    'Cape Town': (-33.9249, 18.4241),
    'Johannesburg': (-26.2041, 28.0473),
  },
};
