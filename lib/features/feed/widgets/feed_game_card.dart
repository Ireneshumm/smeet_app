import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/features/feed/models/feed_item.dart';
import 'package:smeet_app/geo_utils.dart';

/// Full-width upcoming game row with Join + optional tap to open detail.
class FeedGameCard extends StatefulWidget {
  const FeedGameCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onRefresh,
    this.onEnsureLoggedIn,
    this.onOpenMyGame,
  });

  final FeedItem item;
  final VoidCallback onTap;

  /// After successful join (reload feed, joined count, etc.).
  final VoidCallback? onRefresh;

  /// When null, unauthenticated Join shows a SnackBar (e.g. tests).
  final Future<bool> Function(BuildContext context)? onEnsureLoggedIn;

  /// SnackBar "My Game" action — wired from shell.
  final void Function(BuildContext context)? onOpenMyGame;

  @override
  State<FeedGameCard> createState() => _FeedGameCardState();
}

class _FeedGameCardState extends State<FeedGameCard> {
  bool _joining = false;
  bool _joined = false;

  FeedItem get item => widget.item;

  Future<void> _join() async {
    debugPrint('[FeedGameCard] joining game id=${widget.item.id}');
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) {
      if (widget.onEnsureLoggedIn != null) {
        await widget.onEnsureLoggedIn!(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to join a game.')),
        );
      }
      return;
    }

    setState(() => _joining = true);
    try {
      await Supabase.instance.client.rpc(
        'join_game',
        params: {'p_game_id': widget.item.id},
      );
      if (!mounted) return;
      setState(() {
        _joined = true;
        _joining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("You're in! 🎉"),
          action: SnackBarAction(
            label: 'My Game',
            onPressed: () => widget.onOpenMyGame?.call(context),
          ),
        ),
      );
      widget.onRefresh?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      final msg = e.toString().toLowerCase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('full')
                ? 'This game is full.'
                : msg.contains('already')
                    ? "You're already in this game."
                    : "Couldn't join. Please try again.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sportKey = item.sport.trim().isNotEmpty
        ? item.sport
        : item.title.split('·').first.trim();
    final sportLabel = sportLabelForKey(sportKey);

    final start = item.publishedAt.toLocal();
    final end = item.gameEndsAt?.toLocal();
    final datePart = DateFormat('EEE, MMM d').format(start);
    final startTime = DateFormat.jm().format(start);
    final timeLine = end != null
        ? '$datePart · $startTime – ${DateFormat.jm().format(end)}'
        : '$datePart · $startTime';

    final rawVenue = item.gameVenue?.trim() ?? '';
    final locationText =
        rawVenue.isEmpty ? '' : rawVenue.split(',').first.trim();
    final dk = item.distanceKm;

    final filled = item.gameSpotsFilled;
    final total = item.gameTotalSpots;
    final lastSpot = total != null &&
        filled != null &&
        total > 0 &&
        (total - filled) <= 1 &&
        filled < total;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 8,
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      sportEmojiForKey(sportKey),
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              sportLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastSpot) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                'Last spot!',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeLine,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      if (locationText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                dk != null
                                    ? '$locationText · ${formatDistanceKm(dk)}'
                                    : locationText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        '${filled ?? 0}/${total ?? '?'} joined'
                        '${item.gamePerPerson != null && item.gamePerPerson! > 0 ? ' · \$${item.gamePerPerson!.toStringAsFixed(0)}/pp' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _joined
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'Joined ✓',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade700,
                          ),
                        ),
                      )
                    : FilledButton(
                        onPressed: _joining ? null : _join,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _joining
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Join',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
