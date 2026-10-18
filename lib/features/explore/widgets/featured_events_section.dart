import 'package:flutter/material.dart';

import 'package:smeet_app/core/constants/sports.dart';
import 'package:smeet_app/core/theme/theme.dart';

/// A curated Smeet trip / event (watch party, ski trip, dive trip...).
///
/// Built-in placeholders for now; [comingSoon] events show a badge and
/// can't be opened. Swap [kFeaturedEvents] for a backend source later.
class FeaturedEvent {
  const FeaturedEvent({
    required this.title,
    required this.sportKey,
    required this.location,
    required this.when,
    required this.blurb,
    required this.gradient,
    this.comingSoon = true,
  });

  final String title;

  /// Canonical sport key from [kSupportedSports].
  final String sportKey;
  final String location;
  final String when;
  final String blurb;
  final List<Color> gradient;
  final bool comingSoon;
}

const List<FeaturedEvent> kFeaturedEvents = [
  FeaturedEvent(
    title: 'Australian Open Watch Party',
    sportKey: 'Tennis',
    location: 'Melbourne Park',
    when: 'January 2027',
    blurb: 'Courtside sessions and a members’ hit before the night match.',
    gradient: [AppColors.deep, AppColors.mint],
  ),
  FeaturedEvent(
    title: 'Niseko Snow Season Trip',
    sportKey: 'Ski',
    location: 'Niseko, Hokkaido',
    when: 'Feb 2027 · 5 nights',
    blurb: 'Powder days, onsen evenings and a small group to ride with.',
    gradient: [AppColors.indigo, AppColors.mint],
  ),
  FeaturedEvent(
    title: 'Great Barrier Reef Dive Trip',
    sportKey: 'Diving',
    location: 'Cairns, QLD',
    when: 'Mid 2027 · liveaboard',
    blurb: 'Outer-reef dives with certified divers from the community.',
    gradient: [AppColors.ink, AppColors.deep],
  ),
];

/// Horizontal "Featured Events" carousel for the Events tab.
class FeaturedEventsSection extends StatelessWidget {
  const FeaturedEventsSection({super.key, this.events = kFeaturedEvents});

  final List<FeaturedEvent> events;

  static const double _cardWidth = 260;
  static const double _cardHeight = 168;

  void _onTap(BuildContext context, FeaturedEvent e) {
    if (!e.comingSoon) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${e.title} is coming soon — stay tuned!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✨ Featured Events',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => _FeaturedEventCard(
              event: events[i],
              width: _cardWidth,
              onTap: () => _onTap(context, events[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedEventCard extends StatelessWidget {
  const _FeaturedEventCard({
    required this.event,
    required this.width,
    required this.onTap,
  });

  final FeaturedEvent event;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const onCard = Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Ink(
          width: width,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: event.gradient,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${sportEmojiForKey(event.sportKey)} '
                    '${sportLabelForKey(event.sportKey)}',
                    style: textTheme.labelMedium?.copyWith(
                      color: onCard.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (event.comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: onCard.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Coming soon',
                        style: textTheme.labelSmall?.copyWith(
                          color: onCard,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: onCard,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${event.location} · ${event.when}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: onCard.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                event.blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: onCard.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
