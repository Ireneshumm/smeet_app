import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smeet_app/features/venues/models/venue.dart';
import 'package:smeet_app/geo_utils.dart';

Future<void> launchVenueExternalUrl(String url) async {
  var uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) {
    uri = Uri.parse('https://${url.trim()}');
  }
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> launchVenuePhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  final uri = Uri(scheme: 'tel', path: cleaned);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

/// Full-screen venue / partner profile.
class VenueDetailPage extends StatelessWidget {
  const VenueDetailPage({super.key, required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  venue.coverImageUrl != null &&
                          venue.coverImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: venue.coverImageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                cs.primary.withValues(alpha: 0.8),
                                cs.primary.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              venue.categoryEmoji,
                              style: const TextStyle(fontSize: 80),
                            ),
                          ),
                        ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  blurRadius: 8,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (venue.isVerified)
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${venue.categoryEmoji} ${venue.categoryLabel}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (venue.distanceKm != null) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatDistanceKm(venue.distanceKm!),
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (venue.reviewCount > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ...List.generate(5, (i) {
                          final r = venue.rating;
                          final IconData icon;
                          if (i < r.floor()) {
                            icon = Icons.star_rounded;
                          } else if (i < r) {
                            icon = Icons.star_half_rounded;
                          } else {
                            icon = Icons.star_outline_rounded;
                          }
                          return Icon(
                            icon,
                            color: const Color(0xFFFBBF24),
                            size: 18,
                          );
                        }),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${venue.rating.toStringAsFixed(1)} '
                            '(${venue.reviewCount} reviews)',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (venue.priceRange != null &&
                      venue.priceDisplay.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${venue.priceRange} ${venue.priceDisplay}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  if (venue.address != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            venue.address!,
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (venue.openingHours != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            venue.openingHours!,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.7),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (venue.description != null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      venue.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurface.withValues(alpha: 0.75),
                        height: 1.6,
                      ),
                    ),
                  ],
                  if (venue.sport.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Sports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: venue.sport
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (venue.instagramUrl != null &&
                      venue.instagramUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          side: const BorderSide(
                            color: Color(0xFFE1306C),
                            width: 1.5,
                          ),
                          foregroundColor: const Color(0xFFE1306C),
                        ),
                        onPressed: () =>
                            launchVenueExternalUrl(venue.instagramUrl!),
                        icon: const Text('📸'),
                        label: const Text('Follow on Instagram'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (venue.bookingUrl != null &&
                      venue.bookingUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => launchVenueExternalUrl(venue.bookingUrl!),
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'Book Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (venue.websiteUrl != null &&
                      venue.websiteUrl!.isNotEmpty &&
                      venue.websiteUrl!.trim() !=
                          venue.bookingUrl?.trim()) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () =>
                            launchVenueExternalUrl(venue.websiteUrl!),
                        icon: const Icon(Icons.language_rounded),
                        label: const Text(
                          'Visit Website',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                  if (venue.phone != null && venue.phone!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => launchVenuePhone(venue.phone!),
                        icon: const Icon(Icons.phone_rounded),
                        label: const Text(
                          'Call',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
