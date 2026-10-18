import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Public App Store listing used in every outbound share.
const String kAppStoreUrl = 'https://apps.apple.com/app/id6790128004';

/// Opens the system share sheet with an invite to a game.
class GameShareService {
  const GameShareService._();

  /// [headline] is the game's display name (e.g. `Tennis · Intermediate`).
  static Future<void> shareInvite(
    BuildContext context, {
    required String headline,
    DateTime? startsAt,
    String? location,
  }) {
    final details = [
      if (startsAt != null)
        DateFormat('EEE, MMM d · h:mm a').format(startsAt.toLocal()),
      if (location != null && location.trim().isNotEmpty) location.trim(),
    ].join(' · ');
    final text = StringBuffer('Join me for "$headline" on Smeet!');
    if (details.isNotEmpty) text.write(' $details.');
    text.write(' Download the app: $kAppStoreUrl');
    return Share.share(
      text.toString(),
      subject: 'Join me on Smeet',
      sharePositionOrigin: shareOrigin(context),
    );
  }

  /// Anchor rect for the iPad share popover; harmless elsewhere.
  static Rect? shareOrigin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
