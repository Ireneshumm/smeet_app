/// Per-row unread pill (compact) — same rule as legacy Chat list badges.
String unreadLabelForChatRow(int n) {
  if (n <= 0) return '';
  if (n > 9) return '9+';
  return '$n';
}
