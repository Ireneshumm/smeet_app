import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/core/services/game_share_service.dart';
import 'package:smeet_app/core/theme/theme.dart';

/// Post-game "recap" card that can be shared as an image.
///
/// Shown on game detail once the game has ended. The card is wrapped in a
/// [RepaintBoundary] so it can be rasterised to PNG for the share sheet;
/// on web (or if rasterising fails) a text recap is shared instead.
class GameRecapCard extends StatefulWidget {
  const GameRecapCard({
    super.key,
    required this.sport,
    required this.headline,
    required this.playedAt,
    this.location,
    this.players,
  });

  final String sport;
  final String headline;
  final DateTime playedAt;
  final String? location;
  final int? players;

  @override
  State<GameRecapCard> createState() => _GameRecapCardState();
}

class _GameRecapCardState extends State<GameRecapCard> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  String get _dateLabel =>
      DateFormat('EEE, MMM d, y').format(widget.playedAt.toLocal());

  String get _recapText {
    final parts = [
      'Just played "${widget.headline}" on Smeet',
      if (widget.players != null && widget.players! > 1)
        'with ${widget.players! - 1} others',
    ].join(' ');
    return '$parts 🎉 Find your next game: $kAppStoreUrl';
  }

  Future<Uint8List?> _capturePng() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _share(BuildContext btnContext) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final origin = GameShareService.shareOrigin(btnContext);
    try {
      final png = kIsWeb ? null : await _capturePng();
      if (png != null) {
        await Share.shareXFiles(
          [XFile.fromData(png, mimeType: 'image/png', name: 'smeet_recap.png')],
          text: _recapText,
          sharePositionOrigin: origin,
        );
      } else {
        await Share.share(_recapText, sharePositionOrigin: origin);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GameRecapCard] share failed: $e');
      await Share.share(_recapText, sharePositionOrigin: origin);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final loc = widget.location?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.deep, AppColors.mint],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GAME RECAP',
                  style: text.labelMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  sportEmojiForKey(widget.sport),
                  style: text.displayLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.headline,
                  style: text.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    _dateLabel,
                    if (loc.isNotEmpty) loc,
                  ].join(' · '),
                  style: text.bodyMedium?.copyWith(color: Colors.white),
                ),
                if (widget.players != null && widget.players! > 0) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${widget.players} players',
                    style: text.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Smeet · Meet people through premium sport',
                  style: text.labelSmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Builder(
          builder: (btnContext) => FilledButton.icon(
            onPressed: _sharing ? null : () => _share(btnContext),
            icon: const Icon(Icons.ios_share_rounded, size: AppIconSize.xs),
            label: const Text('Share recap'),
          ),
        ),
      ],
    );
  }
}
