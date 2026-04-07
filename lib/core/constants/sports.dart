import 'package:flutter/material.dart';

/// Canonical sport keys, emoji, and English UI label — use everywhere (Home, profile, feed).
const List<(String key, String emoji, String label)> kSupportedSports = [
  ('Tennis', '🎾', 'Tennis'),
  ('Badminton', '🏸', 'Badminton'),
  ('Pickleball', '🏓', 'Pickleball'),
  ('TableTennis', '🏓', 'Table Tennis'),
  ('Golf', '⛳', 'Golf'),
  ('Basketball', '🏀', 'Basketball'),
  ('Football', '⚽', 'Football / Soccer'),
  ('Swimming', '🏊', 'Swimming'),
  ('Running', '🏃', 'Running'),
  ('Cycling', '🚴', 'Cycling'),
  ('Ski', '🎿', 'Skiing'),
  ('Snowboard', '🏂', 'Snowboarding'),
  ('Yoga', '🧘', 'Yoga'),
  ('Fitness', '💪', 'Fitness / CrossFit'),
  ('Climbing', '🧗', 'Rock Climbing'),
  ('Volleyball', '🏐', 'Volleyball'),
  ('Baseball', '⚾', 'Baseball / Softball'),
  ('Rugby', '🏉', 'Rugby'),
  ('Squash', '🎯', 'Squash'),
  ('Hockey', '🏒', 'Hockey'),
];

String sportEmojiForKey(String sportKey) {
  for (final e in kSupportedSports) {
    if (e.$1 == sportKey) return e.$2;
  }
  return '🏅';
}

String sportLabelForKey(String sportKey) {
  for (final e in kSupportedSports) {
    if (e.$1 == sportKey) return e.$3;
  }
  return sportKey;
}

/// Canonical sport key for DB/API (matches [kSupportedSports].$1 and `sport_level_definitions.sport`).
String canonicalSportKey(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  for (final e in kSupportedSports) {
    if (e.$1.toLowerCase() == t.toLowerCase()) return e.$1;
  }
  switch (t.toLowerCase()) {
    case 'gym':
      return 'Fitness';
    default:
      return t;
  }
}

// --- Availability (profiles.availability JSON; shared by edit / display / swipe) ---

const kAvailabilityDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const kAvailabilityDaysShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const kAvailabilitySlots = ['Morning', 'Afternoon', 'Evening'];

const kAvailabilitySlotIcons = [
  Icons.wb_sunny_outlined,
  Icons.wb_cloudy_outlined,
  Icons.nights_stay_outlined,
];

const kAvailabilitySlotColors = [
  Color(0xFFF59E0B),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
];

String availabilitySlotShort(String slot) {
  switch (slot) {
    case 'Morning':
      return 'AM';
    case 'Afternoon':
      return 'PM';
    case 'Evening':
      return 'Eve';
    default:
      return slot;
  }
}

String availabilitySlotEmoji(String slot) {
  switch (slot) {
    case 'Morning':
      return '🌅';
    case 'Afternoon':
      return '☀️';
    case 'Evening':
      return '🌆';
    default:
      return '⏰';
  }
}

/// Slots for [dayFull] from a profile row map (supports `Monday` or legacy `Mon` keys).
dynamic availabilityRawForDay(Map<dynamic, dynamic> av, String dayFull) {
  final i = kAvailabilityDays.indexOf(dayFull);
  if (i < 0) return null;
  return av[dayFull] ?? av[kAvailabilityDaysShort[i]];
}

/// Normalizes DB map to full day keys, canonical slot names, Mon–Sun order.
/// Maps legacy `Night` → `Evening`; drops unknown slots.
Map<String, List<String>> normalizeAvailabilityMap(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, List<String>>{};
  for (var i = 0; i < kAvailabilityDays.length; i++) {
    final full = kAvailabilityDays[i];
    final short = kAvailabilityDaysShort[i];
    final v = raw[full] ?? raw[short];
    if (v is! List || v.isEmpty) continue;
    final slots = <String>{};
    for (final e in v) {
      var s = e.toString();
      if (s == 'Night') s = 'Evening';
      if (kAvailabilitySlots.contains(s)) slots.add(s);
    }
    if (slots.isEmpty) continue;
    out[full] =
        kAvailabilitySlots.where((s) => slots.contains(s)).toList(growable: false);
  }
  return out;
}
