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

/// After [endsAt], show ended state. [chinese] uses emotional copy for Feed-style UI.
String formatGameCountdownLine({
  required DateTime? startsAt,
  required DateTime? endsAt,
  required DateTime now,
  bool chinese = false,
}) {
  final n = now.toLocal();

  if (chinese) {
    return _formatGameCountdownLineChinese(
      startsAt: startsAt,
      endsAt: endsAt,
      nowLocal: n,
    );
  }

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

String _formatGameCountdownLineChinese({
  required DateTime? startsAt,
  required DateTime? endsAt,
  required DateTime nowLocal,
}) {
  final s = startsAt?.toLocal();
  final e = endsAt?.toLocal();

  if (e != null && !e.isAfter(nowLocal)) {
    return '';
  }

  if (s != null &&
      !nowLocal.isBefore(s) &&
      (e == null || nowLocal.isBefore(e))) {
    return '正在进行中 🏃';
  }

  if (s == null) {
    return '';
  }

  final diff = s.difference(nowLocal);
  if (diff <= Duration.zero) {
    return '';
  }

  if (diff < const Duration(hours: 1)) {
    final mins = diff.inMinutes.clamp(1, 59);
    return '还有 $mins 分钟开球 🔥';
  }

  if (diff < const Duration(hours: 3)) {
    final hrs = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (mins > 0) {
      return '还有 ${hrs}h${mins}m 开球 ⚡️';
    }
    return '还有 ${hrs}h 开球 ⚡️';
  }

  if (diff < const Duration(hours: 24)) {
    final hrs = diff.inHours;
    return '今天 ${hrs}h 后开球';
  }

  if (diff < const Duration(hours: 48)) {
    return '明天开球';
  }

  final days = diff.inDays;
  return '$days 天后开球';
}
