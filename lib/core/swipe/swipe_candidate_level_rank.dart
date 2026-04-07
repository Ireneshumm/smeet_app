import 'package:smeet_app/core/services/sport_definitions_service.dart';

/// Sort swipe candidates: closest skill tier first, then by minimum |Δsort_order| on shared sports.
void sortSwipeCandidatesByLevelProximity({
  required List<Map<String, dynamic>> candidates,
  required Map<String, dynamic>? mySportLevels,
  required Map<String, List<SportLevelDefinition>> definitionsBySport,
}) {
  if (mySportLevels == null) return;
  final myMap = Map<String, dynamic>.from(mySportLevels as Map);

  int? orderFor(String sport, String raw) {
    final defs = definitionsBySport[sport] ??
        definitionsBySport[_aliasSportKey(sport)];
    if (defs == null) return null;
    return sortOrderForStored(defs, raw);
  }

  (int, int) score(Map<String, dynamic> other) {
    final ot = other['sport_levels'];
    if (ot is! Map) return (2, 9999);

    final myKeys = myMap.keys.map((k) => k.toString()).toSet();
    final otKeys = ot.keys.map((k) => k.toString()).toSet();
    final common = myKeys.intersection(otKeys);
    if (common.isEmpty) return (2, 9999);

    var hasClose = false;
    var minDiff = 9999;

    for (final sport in common) {
      final myRaw = mySportLevels[sport]?.toString() ?? '';
      final otRaw = ot[sport]?.toString() ?? '';
      final myO = orderFor(sport, myRaw);
      final otO = orderFor(sport, otRaw);
      if (myO != null && otO != null) {
        final d = (myO - otO).abs();
        if (d < minDiff) minDiff = d;
        if (d <= 1) hasClose = true;
      }
    }

    final tier = hasClose ? 0 : 1;
    return (tier, minDiff);
  }

  candidates.sort((a, b) {
    final sa = score(a);
    final sb = score(b);
    final c = sa.$1.compareTo(sb.$1);
    if (c != 0) return c;
    return sa.$2.compareTo(sb.$2);
  });
}

/// Maps legacy profile keys (e.g. Gym) to [sport_level_definitions] sport column.
String _aliasSportKey(String sport) {
  switch (sport) {
    case 'Gym':
      return 'Fitness';
    default:
      return sport;
  }
}
