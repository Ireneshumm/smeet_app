/// Live countdown labels for upcoming games (UI refresh ~1 min).
String formatGameCountdownToStart(DateTime? startsAt, DateTime now) {
  if (startsAt == null) return '';
  final start = startsAt.toLocal();
  final n = now.toLocal();
  if (start.isBefore(n)) {
    return 'Started';
  }
  final diff = start.difference(n);
  if (diff.inMinutes <= 0) {
    return 'Starting soon';
  }
  if (diff.inHours >= 24) {
    final d = diff.inDays;
    final h = diff.inHours % 24;
    return 'Starts in ${d}d ${h}h';
  }
  if (diff.inHours >= 1) {
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return 'Starts in ${h}h ${m}m';
  }
  return 'Starts in ${diff.inMinutes}m';
}

/// After [endsAt], show ended state.
String formatGameCountdownLine({
  required DateTime? startsAt,
  required DateTime? endsAt,
  DateTime? now,
}) {
  final n = (now ?? DateTime.now()).toLocal();
  if (endsAt != null && endsAt.toLocal().isBefore(n)) {
    return 'Ended';
  }
  if (startsAt != null && startsAt.toLocal().isBefore(n)) {
    if (endsAt == null || endsAt.toLocal().isAfter(n)) {
      return 'In progress';
    }
  }
  return formatGameCountdownToStart(startsAt, n);
}
