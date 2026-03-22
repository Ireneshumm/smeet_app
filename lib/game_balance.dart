/// Heuristic group balance label from [sport_levels] JSON maps (same shape as profiles).
String balanceLabelForGroup({
  required String sportKey,
  required List<Map<String, dynamic>?> playerProfiles,
}) {
  final key = sportKey.trim().toLowerCase();
  final levels = <double>[];

  for (final p in playerProfiles) {
    if (p == null) continue;
    final sl = p['sport_levels'];
    if (sl is! Map) continue;
    for (final e in sl.entries) {
      if (e.key.toString().toLowerCase() != key) continue;
      final v = e.value;
      final n = _parseLevel(v);
      if (n != null) levels.add(n);
    }
  }

  if (levels.length < 2) {
    return 'Mixed levels';
  }

  levels.sort();
  final min = levels.first;
  final max = levels.last;
  final span = max - min;

  if (span <= 0.75) return 'Well matched';
  if (span <= 1.75) return 'Mixed levels';
  if (max <= 2.5) return 'Beginner-friendly';
  if (min >= 3.5) return 'Advanced group';
  return 'Mixed levels';
}

/// Maps common level strings to a rough numeric scale (higher = stronger).
double? _parseLevel(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim().toLowerCase();
  final asNum = double.tryParse(s);
  if (asNum != null) return asNum;
  if (s.contains('begin')) return 1.5;
  if (s.contains('inter')) return 3.0;
  if (s.contains('adv')) return 4.5;
  return null;
}
