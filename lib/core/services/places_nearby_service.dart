import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/features/venues/models/venue.dart';
import 'package:smeet_app/geo_utils.dart';

/// Live venue discovery via the `google-places` edge function (`nearby`).
///
/// Turns Google Places Nearby Search results into [Venue]s so the Explore >
/// Venues tab can list real venues anywhere in the world — sorted by distance
/// from the user, with Google ratings and price level. Results are cached
/// server-side (see `places_nearby_cache`), so repeat browsing is free.
class PlacesNearbyService {
  PlacesNearbyService(this._supabase);

  final SupabaseClient _supabase;

  /// Keyword search matches a place's whole Google profile (reviews included),
  /// so obviously-unrelated place types leak in (schools, childcare, churches,
  /// real estate...). Filter them out by Google `types`...
  static const Set<String> _excludedTypes = {
    'school',
    'primary_school',
    'secondary_school',
    'preschool',
    'university',
    'child_care',
    'place_of_worship',
    'church',
    'mosque',
    'synagogue',
    'hindu_temple',
    'cemetery',
    'funeral_home',
    'lodging',
    'real_estate_agency',
    'travel_agency',
    'car_dealer',
    'car_repair',
    'car_wash',
    'gas_station',
    'bank',
    'atm',
    'lawyer',
    'accounting',
    'insurance_agency',
    'local_government_office',
    'embassy',
    'courthouse',
    'police',
    'fire_station',
    'post_office',
    'storage',
    'moving_company',
    'plumber',
    'electrician',
    'locksmith',
    'roofing_contractor',
  };

  /// ...and by tell-tale name fragments (e.g. "Early Learning Centre").
  static const List<String> _excludedNameWords = [
    'early learning',
    'childcare',
    'child care',
    'kindergarten',
    'kindy',
    'daycare',
    'day care',
    'preschool',
    'primary school',
    'high school',
    'state school',
    'real estate',
    'church',
    'funeral',
  ];

  static bool _isIrrelevant(Map<String, dynamic> place) {
    final types = (place['types'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        const <String>{};
    if (types.intersection(_excludedTypes).isNotEmpty) return true;
    final name = (place['name'] ?? '').toString().toLowerCase();
    for (final w in _excludedNameWords) {
      if (name.contains(w)) return true;
    }
    return false;
  }

  /// Google Places (type, keyword) per venue category chip.
  static const Map<String, ({String type, String keyword})> _categoryQuery = {
    'all': (type: '', keyword: 'sports centre'),
    VenueCategory.sportsCourt: (type: '', keyword: 'sports court'),
    // Per-sport venues.
    VenueCategory.tennis: (type: '', keyword: 'tennis court'),
    VenueCategory.badminton: (type: '', keyword: 'badminton court'),
    VenueCategory.basketball: (type: '', keyword: 'basketball court'),
    VenueCategory.football: (type: '', keyword: 'soccer field'),
    VenueCategory.pickleball: (type: '', keyword: 'pickleball court'),
    VenueCategory.tableTennis: (type: '', keyword: 'table tennis'),
    VenueCategory.volleyball: (type: '', keyword: 'volleyball court'),
    VenueCategory.squash: (type: '', keyword: 'squash court'),
    VenueCategory.climbing: (type: '', keyword: 'climbing gym'),
    VenueCategory.yoga: (type: '', keyword: 'yoga studio'),
    VenueCategory.running: (type: '', keyword: 'athletics track'),
    VenueCategory.rugby: (type: '', keyword: 'rugby field'),
    VenueCategory.hockey: (type: '', keyword: 'hockey field'),
    VenueCategory.baseball: (type: '', keyword: 'baseball field'),
    VenueCategory.gym: (type: 'gym', keyword: ''),
    VenueCategory.pool: (type: '', keyword: 'swimming pool'),
    VenueCategory.golf: (type: 'golf_course', keyword: ''),
    VenueCategory.ski: (type: '', keyword: 'ski resort'),
    // Health & beauty.
    VenueCategory.massage: (type: 'spa', keyword: 'massage'),
    VenueCategory.physio: (type: 'physiotherapist', keyword: ''),
    VenueCategory.clinic: (type: '', keyword: 'cosmetic clinic'),
    VenueCategory.skincare: (type: 'beauty_salon', keyword: 'facial skincare'),
    VenueCategory.sauna: (type: '', keyword: 'sauna'),
    VenueCategory.recovery: (type: '', keyword: 'recovery ice bath'),
    VenueCategory.chiro: (type: '', keyword: 'chiropractor'),
    VenueCategory.nutrition: (type: '', keyword: 'sports nutrition store'),
    // Shop — per-sport gear stores.
    VenueCategory.apparel: (type: 'clothing_store', keyword: 'sports apparel'),
    VenueCategory.equipment: (type: 'sporting_goods_store', keyword: ''),
    VenueCategory.retail: (type: '', keyword: 'sports store'),
    VenueCategory.shopTennis: (type: '', keyword: 'tennis shop'),
    VenueCategory.shopGolf: (type: '', keyword: 'golf shop'),
    VenueCategory.shopSki: (type: '', keyword: 'ski snowboard shop'),
    VenueCategory.shopFootball: (type: '', keyword: 'football soccer store'),
    VenueCategory.shopBasketball: (type: '', keyword: 'basketball store'),
    VenueCategory.shopRacquet: (type: '', keyword: 'racquet sports shop'),
    VenueCategory.shopSwim: (type: '', keyword: 'swimwear shop'),
    VenueCategory.shopBike: (type: 'bicycle_store', keyword: ''),
    VenueCategory.shopRunning: (type: 'shoe_store', keyword: 'running shoes'),
    VenueCategory.shopSkincare: (type: '', keyword: 'skincare cosmetics store'),
    VenueCategory.shopOutdoor: (type: '', keyword: 'outdoor sports gear store'),
  };

  /// Nearby venues for [category], sorted nearest-first from (lat, lng).
  /// Returns an empty list on any failure — callers fall back to the
  /// curated `venues` table.
  Future<List<Venue>> fetchNearby({
    required double lat,
    required double lng,
    required String category,
    int radiusMeters = 10000,
  }) async {
    final q = _categoryQuery[category] ?? _categoryQuery['all']!;
    try {
      final res = await _supabase.functions.invoke(
        'google-places',
        body: {
          'action': 'nearby',
          'lat': lat,
          'lng': lng,
          'radius': radiusMeters,
          if (q.type.isNotEmpty) 'type': q.type,
          if (q.keyword.isNotEmpty) 'keyword': q.keyword,
        },
      );
      if (res.status != 200) {
        debugPrint('[PlacesNearby] status ${res.status} for $category');
        return const [];
      }
      final body = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : jsonDecode(jsonEncode(res.data)) as Map<String, dynamic>;
      final status = (body['status'] ?? '').toString();
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        debugPrint(
          '[PlacesNearby] $status ${body['error_message'] ?? ''} for $category',
        );
        return const [];
      }

      final results = (body['results'] as List?) ?? const [];
      final venues = <Venue>[];
      for (final raw in results) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        if (_isIrrelevant(m)) continue;
        final v = _venueFromPlace(m, category);
        if (v == null) continue;
        if (v.locationLat != null && v.locationLng != null) {
          v.distanceKm =
              haversineKm(lat, lng, v.locationLat!, v.locationLng!);
        }
        venues.add(v);
      }
      venues.sort(
        (a, b) => (a.distanceKm ?? double.infinity)
            .compareTo(b.distanceKm ?? double.infinity),
      );
      debugPrint(
        '[PlacesNearby] $category → ${venues.length} venues (nearest '
        '${venues.isEmpty ? '-' : venues.first.name})',
      );
      return venues;
    } catch (e) {
      debugPrint('[PlacesNearby] fetch failed for $category: $e');
      return const [];
    }
  }

  Venue? _venueFromPlace(Map<String, dynamic> place, String category) {
    final placeId = (place['place_id'] ?? '').toString();
    final name = (place['name'] ?? '').toString().trim();
    if (placeId.isEmpty || name.isEmpty) return null;

    double? plat;
    double? plng;
    final geometry = place['geometry'];
    if (geometry is Map) {
      final loc = geometry['location'];
      if (loc is Map) {
        plat = (loc['lat'] as num?)?.toDouble();
        plng = (loc['lng'] as num?)?.toDouble();
      }
    }

    // Google price_level 0–4 → the app's `$`/`$$`/`$$$` scale.
    String? priceRange;
    final priceLevel = place['price_level'];
    if (priceLevel is num) {
      if (priceLevel <= 1) {
        priceRange = r'$';
      } else if (priceLevel == 2) {
        priceRange = r'$$';
      } else {
        priceRange = r'$$$';
      }
    }

    String? openingHours;
    final oh = place['opening_hours'];
    if (oh is Map && oh['open_now'] is bool) {
      openingHours = (oh['open_now'] as bool) ? 'Open now' : 'Closed now';
    }

    return Venue(
      id: 'gplace_$placeId',
      name: name,
      category: category == 'all' ? VenueCategory.sportsCourt : category,
      address: (place['vicinity'] ?? place['formatted_address'])?.toString(),
      locationLat: plat,
      locationLng: plng,
      // Deep link to the place on Google Maps (name + place_id is the
      // documented universal URL form).
      websiteUrl: 'https://www.google.com/maps/search/?api=1'
          '&query=${Uri.encodeComponent(name)}'
          '&query_place_id=$placeId',
      openingHours: openingHours,
      priceRange: priceRange,
      rating: (place['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (place['user_ratings_total'] as num?)?.toInt() ?? 0,
    );
  }
}
