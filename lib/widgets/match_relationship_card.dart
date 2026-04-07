import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/widgets/circular_network_avatar.dart';

/// Copy and widgets shared by standalone [MatchesPage] and Inbox **Matches** tab.
class MatchRelationshipPresentation {
  MatchRelationshipPresentation._();

  static const String emptyTitle = 'No matches yet';

  static const String emptySubtitle =
      'Swipe on people you’d like to meet. When you both like each other, they’ll '
      'appear here. This list is only for mutual matches — your conversations live under Chat.';

  static const String dialogNoChatBody =
      'There isn’t a message thread with them yet. New matches from Swipe usually '
      'open a chat right away — or check Chat in case it’s already there.';
}

/// Single-column mutual-match row: relationship context, not a DM preview.
class MatchRelationshipCard extends StatelessWidget {
  const MatchRelationshipCard({
    super.key,
    required this.displayName,
    required this.cityLabel,
    required this.avatarUrl,
    required this.matchedAt,
    required this.onTap,
  });

  final String displayName;
  final String cityLabel;
  final String avatarUrl;
  final DateTime matchedAt;
  final VoidCallback onTap;

  static String _matchedLine(DateTime at) {
    if (at.millisecondsSinceEpoch <= 0) {
      return 'Matched recently';
    }
    final formatted =
        DateFormat.MMMd().add_jm().format(at.toLocal());
    return 'Matched $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final trimmedAvatar = avatarUrl.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.tertiary.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircularNetworkAvatar(
                    size: 68,
                    imageUrl: trimmedAvatar.isEmpty ? null : trimmedAvatar,
                    backgroundColor: cs.tertiary.withValues(alpha: 0.2),
                    placeholder: Icon(
                      Icons.favorite_rounded,
                      size: 32,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: cs.tertiary.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'MATCH',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: cs.tertiary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Mutual match',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cityLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _matchedLine(matchedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.outline,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cs.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// When no direct chat exists yet — honest copy, no fake “Message” action.
Future<void> showMatchRelationshipNoChatDialog(
  BuildContext context, {
  required String displayName,
  required String intro,
  required String avatarUrl,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final trimmed = intro.trim();
  final av = avatarUrl.trim();

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titlePadding: EdgeInsets.zero,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              CircularNetworkAvatar(
                size: 80,
                imageUrl: av.isEmpty ? null : av,
                backgroundColor: cs.tertiary.withValues(alpha: 0.2),
                placeholder: Icon(Icons.favorite_rounded, color: cs.tertiary, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mutual match',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.tertiary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trimmed.isEmpty ? 'No bio yet.' : trimmed,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 14),
              Text(
                MatchRelationshipPresentation.dialogNoChatBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}
