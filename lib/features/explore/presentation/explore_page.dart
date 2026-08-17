import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/app/smeet_app.dart';
import 'package:smeet_app/core/services/location_service.dart';
import 'package:smeet_app/core/theme/theme.dart';
import 'package:smeet_app/core/services/places_nearby_service.dart';
import 'package:smeet_app/features/venues/models/venue.dart';
import 'package:smeet_app/features/venues/presentation/venue_detail_page.dart';
import 'package:smeet_app/geo_utils.dart';

/// Explore: Smeet ([smeetTab], usually [SwipePage]) / Venues / Events. Injected from [SmeetShell].
class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    required this.smeetTab,
    required this.eventsTab,
  });

  /// First tab — typically [SwipePage] from `main.dart` (shell `part`).
  final Widget smeetTab;
  final Widget eventsTab;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: cs.primary,
            indicatorWeight: 3,
            labelColor: cs.primary,
            unselectedLabelColor: Colors.grey.shade400,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: '🤝 Smeet'),
              Tab(text: '🏟️ Venues'),
              Tab(text: '🎯 Events'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              widget.smeetTab,
              const _VenuesTab(),
              _EventsTab(eventsTab: widget.eventsTab),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventsTab extends StatefulWidget {
  const _EventsTab({required this.eventsTab});

  final Widget eventsTab;

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.eventsTab;
  }
}

class _VenuesTab extends StatefulWidget {
  const _VenuesTab();

  @override
  State<_VenuesTab> createState() => _VenuesTabState();
}

class _VenuesTabState extends State<_VenuesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Venue> _venues = [];
  List<Venue> _filtered = [];
  bool _loading = true;
  String _selectedCategory = 'all';
  ({double lat, double lng})? _userPos;

  /// Live worldwide venues from Google Places, per category chip. Fetched
  /// lazily on selection and kept for the session (server also caches).
  final PlacesNearbyService _nearbyService =
      PlacesNearbyService(Supabase.instance.client);
  final Map<String, List<Venue>> _nearbyByCategory = {};

  // Ordered by worldwide participation (football #1, basketball #2, gym =
  // most-used venue type, then swimming / racket sports / yoga...).
  static const _sportsCategories = <(String, String)>[
    ('all', '🏃 All'),
    ('football', '⚽ Football Field'),
    ('basketball', '🏀 Basketball Court'),
    ('gym', '💪 Gym'),
    ('pool', '🏊 Swimming Pool'),
    ('tennis', '🎾 Tennis Court'),
    ('badminton', '🏸 Badminton'),
    ('volleyball', '🏐 Volleyball'),
    ('table_tennis', '🏓 Table Tennis'),
    ('yoga', '🧘 Yoga'),
    ('running', '🏃 Athletics Track'),
    ('golf', '⛳ Golf Course'),
    ('pickleball', '🥎 Pickleball'),
    ('baseball', '⚾ Baseball Field'),
    ('hockey', '🏑 Hockey'),
    ('rugby', '🏉 Rugby Field'),
    ('squash', '🎯 Squash'),
    ('climbing', '🧗 Climbing'),
    ('ski', '🎿 Ski Area'),
    ('sports_court', '🏟️ Other Courts'),
  ];

  // Ordered by demand (massage & skincare are the biggest wellness spends).
  static const _wellnessCategories = <(String, String)>[
    ('massage', '💆 Massage'),
    ('skincare', '🧴 Skincare & Facial'),
    ('clinic', '✨ Cosmetic Clinic'),
    ('physio', '🩺 Physio'),
    ('sauna', '🧖 Sauna'),
    ('chiro', '🦴 Chiropractor'),
    ('recovery', '🧊 Recovery & Ice Bath'),
    ('nutrition', '🥤 Nutrition'),
  ];

  // Ordered by what people buy most (footwear & sportswear lead global
  // sporting-goods sales, then big-participation sports gear).
  static const _shopCategories = <(String, String)>[
    ('equipment', '🎽 All Sports Gear'),
    ('shop_running', '🏃 Running Shoes'),
    ('apparel', '👟 Sportswear'),
    ('shop_football', '⚽ Football Gear'),
    ('shop_basketball', '🏀 Basketball Gear'),
    ('shop_swim', '🩱 Swim Gear'),
    ('shop_tennis', '🎾 Tennis Gear'),
    ('shop_bike', '🚴 Bike Shop'),
    ('shop_golf', '⛳ Golf Gear'),
    ('shop_skincare', '🧴 Skincare Products'),
    ('shop_racquet', '🏸 Racquet Shop'),
    ('shop_outdoor', '🏕️ Outdoor Gear'),
    ('shop_ski', '🎿 Ski Gear'),
    ('retail', '🏪 Retail'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _userPos = await SmeetLocationService.getCurrentPosition();

      final rows = await Supabase.instance.client
          .from('venues')
          .select()
          .order('is_featured', ascending: false)
          .order('name');

      final list = (rows as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final v = Venue.fromRow(m);
        if (_userPos != null &&
            v.locationLat != null &&
            v.locationLng != null) {
          v.distanceKm = haversineKm(
            _userPos!.lat,
            _userPos!.lng,
            v.locationLat!,
            v.locationLng!,
          );
        }
        return v;
      }).toList();

      list.sort((a, b) {
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        return (a.distanceKm ?? 9999).compareTo(b.distanceKm ?? 9999);
      });

      if (mounted) {
        setState(() {
          _venues = list;
          _filtered = list;
          _loading = false;
        });
        _fetchNearby(_selectedCategory);
      }
    } catch (e) {
      debugPrint('[VenuesTab] load failed: $e');
      if (mounted) {
        setState(() {
          _venues = [];
          _filtered = [];
          _loading = false;
        });
      }
    }
  }

  void _filter(String cat) {
    setState(() {
      _selectedCategory = cat;
      _filtered = cat == 'all'
          ? List<Venue>.from(_venues)
          : _venues.where((v) => v.category == cat).toList();
    });
    _fetchNearby(cat);
  }

  /// Fetch live worldwide venues for [cat] (once per category per session).
  /// Silent no-op without a user location — the curated list still shows.
  Future<void> _fetchNearby(String cat) async {
    final pos = _userPos;
    if (pos == null || _nearbyByCategory.containsKey(cat)) return;
    _nearbyByCategory[cat] = const []; // guard against duplicate fetches
    final list = await _nearbyService.fetchNearby(
      lat: pos.lat,
      lng: pos.lng,
      category: cat,
    );
    if (!mounted || list.isEmpty) return;
    setState(() => _nearbyByCategory[cat] = list);
  }

  void _openDetail(Venue venue) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VenueDetailPage(venue: venue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    // Curated partner venues + live Google Places results for the selected
    // category, deduped by name and sorted nearest-first.
    final curatedNames =
        _filtered.map((v) => v.name.toLowerCase().trim()).toSet();
    final nearby = (_nearbyByCategory[_selectedCategory] ?? const <Venue>[])
        .where((v) => !curatedNames.contains(v.name.toLowerCase().trim()));
    final nonFeatured = [
      ..._filtered.where((v) => !v.isFeatured),
      ...nearby,
    ]..sort(
        (a, b) => (a.distanceKm ?? double.infinity)
            .compareTo(b.distanceKm ?? double.infinity),
      );

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryRow(
                  title: 'Sport',
                  accent: SmeetApp.smeetMint,
                  selectedBg: SmeetApp.smeetMintLight,
                  selectedText: SmeetApp.smeetDeep,
                  categories: _sportsCategories,
                  selected: _selectedCategory,
                  onSelect: _filter,
                ),
                const _VenueSectionDivider(),
                _CategoryRow(
                  title: 'Health & Beauty',
                  accent: SmeetApp.smeetCoral,
                  selectedBg: SmeetApp.smeetCoralLight,
                  selectedText: SmeetApp.smeetCoral,
                  categories: _wellnessCategories,
                  selected: _selectedCategory,
                  onSelect: _filter,
                ),
                const _VenueSectionDivider(),
                _CategoryRow(
                  title: 'Shop',
                  accent: SmeetApp.smeetIndigo,
                  selectedBg: SmeetApp.smeetIndigoLight,
                  selectedText: SmeetApp.smeetIndigo,
                  categories: _shopCategories,
                  selected: _selectedCategory,
                  onSelect: _filter,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (!_loading)
            SliverToBoxAdapter(
              child: _buildFeaturedBanner(cs),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty && nonFeatured.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🏟️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'No venues yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back soon',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    return _VenueCard(
                      venue: nonFeatured[i],
                      onTap: () => _openDetail(nonFeatured[i]),
                    );
                  },
                  childCount: nonFeatured.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBanner(ColorScheme cs) {
    final featured = _filtered.where((v) => v.isFeatured).toList();
    if (featured.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Text(
                '⭐ Featured',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: featured.length,
            itemBuilder: (context, i) => _FeaturedVenueCard(
              venue: featured[i],
              onTap: () => _openDetail(featured[i]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'All Venues',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FeaturedVenueCard extends StatelessWidget {
  const _FeaturedVenueCard({
    required this.venue,
    required this.onTap,
  });

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 8,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: venue.coverImageUrl != null &&
                      venue.coverImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: venue.coverImageUrl!,
                      width: 260,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 260,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withValues(alpha: 0.7),
                            cs.primary.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          venue.categoryEmoji,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (venue.isVerified)
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: cs.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${venue.categoryEmoji} ${venue.categoryLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      if (venue.distanceKm != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatDistanceKm(venue.distanceKm!),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.onTap,
  });

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 8,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
              child: venue.coverImageUrl != null &&
                      venue.coverImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: venue.coverImageUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: cs.primary.withValues(alpha: 0.1),
                      child: Center(
                        child: Text(
                          venue.categoryEmoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (venue.isVerified)
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: cs.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${venue.categoryEmoji} ${venue.categoryLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    if (venue.address != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              venue.distanceKm != null
                                  ? '${venue.address!.split(',').first} · '
                                      '${formatDistanceKm(venue.distanceKm!)}'
                                  : venue.address!.split(',').first,
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
                    if (venue.rating > 0 ||
                        venue.priceRange != null ||
                        venue.openingHours == 'Open now') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (venue.rating > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF5A623),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              venue.reviewCount > 0
                                  ? '${venue.rating.toStringAsFixed(1)} '
                                      '(${venue.reviewCount})'
                                  : venue.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                          if (venue.priceRange != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              venue.priceRange!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                          if (venue.openingHours == 'Open now') ...[
                            const SizedBox(width: 6),
                            Text(
                              '· Open now',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (venue.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        venue.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.65),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueSectionDivider extends StatelessWidget {
  const _VenueSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 1,
      color: SmeetApp.smeetGreyLight,
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.accent,
    required this.selectedBg,
    required this.selectedText,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final Color accent;
  final Color selectedBg;
  final Color selectedText;
  final List<(String, String)> categories;
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: SmeetApp.smeetInk,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: categories.map((cat) {
              final isSelected = selected == cat.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelect(cat.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? selectedBg : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: isSelected
                          ? null
                          : Border.all(color: SmeetApp.smeetGreyLight),
                    ),
                    child: Text(
                      cat.$2,
                      style: TextStyle(
                        color: isSelected
                            ? selectedText
                            : SmeetApp.smeetGrey,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
