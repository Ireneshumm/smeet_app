import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/core/services/location_service.dart';
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
              fontSize: 15,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
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

  static const _sportsCategories = <(String, String)>[
    ('all', '🏃 All'),
    ('sports_court', '🏟️ Courts'),
    ('gym', '💪 Gym'),
    ('pool', '🏊 Pool'),
    ('golf', '⛳ Golf'),
    ('ski', '🎿 Ski'),
  ];

  static const _wellnessCategories = <(String, String)>[
    ('massage', '💆 Massage'),
    ('physio', '🩺 Physio'),
    ('clinic', '✨ Clinic'),
    ('skincare', '🧴 Skincare'),
    ('nutrition', '🥤 Nutrition'),
  ];

  static const _shopCategories = <(String, String)>[
    ('apparel', '👟 Apparel'),
    ('equipment', '🎽 Equipment'),
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
    final nonFeatured = _filtered.where((v) => !v.isFeatured).toList();

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
                  categories: _sportsCategories,
                  selected: _selectedCategory,
                  onSelect: _filter,
                ),
                _CategoryRow(
                  title: 'Health & Beauty',
                  categories: _wellnessCategories,
                  selected: _selectedCategory,
                  onSelect: _filter,
                ),
                _CategoryRow(
                  title: 'Shop',
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
          else if (_filtered.isEmpty)
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back soon',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
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
          borderRadius: BorderRadius.circular(18),
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
                            fontSize: 10,
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
          borderRadius: BorderRadius.circular(18),
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
                              fontSize: 15,
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
                          fontSize: 10,
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<(String, String)> categories;
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.45),
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: categories.map((cat) {
              final isSelected = selected == cat.$1;
              return GestureDetector(
                onTap: () => onSelect(cat.$1),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    cat.$2,
                    style: TextStyle(
                      color: isSelected ? Colors.white : cs.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
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
