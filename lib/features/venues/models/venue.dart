/// Canonical category keys for `venues.category` (text column).
abstract final class VenueCategory {
  static const sportsCourt = 'sports_court';
  static const gym = 'gym';
  static const pool = 'pool';
  static const golf = 'golf';
  static const ski = 'ski';
  // Per-sport venue categories (live Google Places discovery).
  static const tennis = 'tennis';
  static const badminton = 'badminton';
  static const basketball = 'basketball';
  static const football = 'football';
  static const pickleball = 'pickleball';
  static const tableTennis = 'table_tennis';
  static const volleyball = 'volleyball';
  static const squash = 'squash';
  static const climbing = 'climbing';
  static const yoga = 'yoga';
  static const running = 'running';
  static const rugby = 'rugby';
  static const hockey = 'hockey';
  static const baseball = 'baseball';
  // Health & beauty.
  static const massage = 'massage';
  static const physio = 'physio';
  static const clinic = 'clinic';
  static const skincare = 'skincare';
  static const sauna = 'sauna';
  static const recovery = 'recovery';
  static const chiro = 'chiro';
  static const nutrition = 'nutrition';
  // Shop — per-sport gear stores.
  static const apparel = 'apparel';
  static const equipment = 'equipment';
  static const retail = 'retail';
  static const shopTennis = 'shop_tennis';
  static const shopGolf = 'shop_golf';
  static const shopSki = 'shop_ski';
  static const shopFootball = 'shop_football';
  static const shopBasketball = 'shop_basketball';
  static const shopRacquet = 'shop_racquet';
  static const shopSwim = 'shop_swim';
  static const shopBike = 'shop_bike';
  static const shopRunning = 'shop_running';
  static const shopSkincare = 'shop_skincare';
  static const shopOutdoor = 'shop_outdoor';
}

/// Display strings keyed by [Venue.category].
const kVenueCategoryInfo = <String, ({String emoji, String label})>{
  VenueCategory.sportsCourt: (emoji: '🏟️', label: 'Courts'),
  VenueCategory.tennis: (emoji: '🎾', label: 'Tennis Court'),
  VenueCategory.badminton: (emoji: '🏸', label: 'Badminton'),
  VenueCategory.basketball: (emoji: '🏀', label: 'Basketball Court'),
  VenueCategory.football: (emoji: '⚽', label: 'Football Field'),
  VenueCategory.pickleball: (emoji: '🥎', label: 'Pickleball'),
  VenueCategory.tableTennis: (emoji: '🏓', label: 'Table Tennis'),
  VenueCategory.volleyball: (emoji: '🏐', label: 'Volleyball'),
  VenueCategory.squash: (emoji: '🎯', label: 'Squash'),
  VenueCategory.climbing: (emoji: '🧗', label: 'Climbing'),
  VenueCategory.yoga: (emoji: '🧘', label: 'Yoga'),
  VenueCategory.running: (emoji: '🏃', label: 'Athletics Track'),
  VenueCategory.rugby: (emoji: '🏉', label: 'Rugby Field'),
  VenueCategory.hockey: (emoji: '🏑', label: 'Hockey'),
  VenueCategory.baseball: (emoji: '⚾', label: 'Baseball Field'),
  VenueCategory.gym: (emoji: '💪', label: 'Gym'),
  VenueCategory.pool: (emoji: '🏊', label: 'Swimming Pool'),
  VenueCategory.golf: (emoji: '⛳', label: 'Golf Course'),
  VenueCategory.ski: (emoji: '🎿', label: 'Ski Area'),
  VenueCategory.massage: (emoji: '💆', label: 'Massage'),
  VenueCategory.physio: (emoji: '🩺', label: 'Physio'),
  VenueCategory.clinic: (emoji: '✨', label: 'Cosmetic Clinic'),
  VenueCategory.skincare: (emoji: '🧴', label: 'Skincare & Facial'),
  VenueCategory.sauna: (emoji: '🧖', label: 'Sauna'),
  VenueCategory.recovery: (emoji: '🧊', label: 'Recovery & Ice Bath'),
  VenueCategory.chiro: (emoji: '🦴', label: 'Chiropractor'),
  VenueCategory.nutrition: (emoji: '🥤', label: 'Nutrition'),
  VenueCategory.apparel: (emoji: '👟', label: 'Sportswear'),
  VenueCategory.equipment: (emoji: '🎽', label: 'All Sports Gear'),
  VenueCategory.retail: (emoji: '🏪', label: 'Retail'),
  VenueCategory.shopTennis: (emoji: '🎾', label: 'Tennis Gear'),
  VenueCategory.shopGolf: (emoji: '⛳', label: 'Golf Gear'),
  VenueCategory.shopSki: (emoji: '🎿', label: 'Ski Gear'),
  VenueCategory.shopFootball: (emoji: '⚽', label: 'Football Gear'),
  VenueCategory.shopBasketball: (emoji: '🏀', label: 'Basketball Gear'),
  VenueCategory.shopRacquet: (emoji: '🏸', label: 'Racquet Shop'),
  VenueCategory.shopSwim: (emoji: '🩱', label: 'Swim Gear'),
  VenueCategory.shopBike: (emoji: '🚴', label: 'Bike Shop'),
  VenueCategory.shopRunning: (emoji: '🏃', label: 'Running Shoes'),
  VenueCategory.shopSkincare: (emoji: '🧴', label: 'Skincare Products'),
  VenueCategory.shopOutdoor: (emoji: '🏕️', label: 'Outdoor Gear'),
};

/// Partner venue / merchant row from `venues` (Supabase).
class Venue {
  Venue({
    required this.id,
    required this.name,
    required this.category,
    this.coverImageUrl,
    this.locationLat,
    this.locationLng,
    this.address,
    this.description,
    this.bookingUrl,
    this.websiteUrl,
    this.phone,
    this.isFeatured = false,
    this.isVerified = false,
    this.sport = const [],
    this.tags = const [],
    this.images = const [],
    this.openingHours,
    this.instagramUrl,
    this.priceRange,
    this.rating = 0,
    this.reviewCount = 0,
    this.distanceKm,
  });

  final String id;
  final String name;

  /// Lowercase key, e.g. [VenueCategory.gym].
  final String category;
  final String? coverImageUrl;
  final double? locationLat;
  final double? locationLng;
  final String? address;
  final String? description;
  final String? bookingUrl;
  final String? websiteUrl;
  final String? phone;
  final bool isFeatured;
  final bool isVerified;
  final List<String> sport;
  final List<String> tags;
  final List<String> images;
  final String? openingHours;
  final String? instagramUrl;

  /// Google Maps–style: `'$'`, `'$$'`, `'$$$'`.
  final String? priceRange;
  final double rating;
  final int reviewCount;

  /// Set after [haversineKm] from user location.
  double? distanceKm;

  String get categoryLabel =>
      kVenueCategoryInfo[category]?.label ?? 'Venue';

  String get categoryEmoji =>
      kVenueCategoryInfo[category]?.emoji ?? '🏪';

  String get priceDisplay {
    switch (priceRange) {
      case r'$':
        return '· Budget-friendly';
      case r'$$':
        return '· Mid-range';
      case r'$$$':
        return '· Premium';
      default:
        return '';
    }
  }

  factory Venue.fromRow(Map<String, dynamic> row) {
    var sports = <String>[];
    final rawSports = row['sports'] ?? row['sport'];
    if (rawSports is List) {
      sports = rawSports
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (rawSports is String && rawSports.trim().isNotEmpty) {
      sports = [rawSports.trim()];
    }

    var tagList = <String>[];
    final rawTags = row['tags'];
    if (rawTags is List) {
      tagList = rawTags
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    var imageList = <String>[];
    final rawImages = row['images'];
    if (rawImages is List) {
      imageList = rawImages
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    var featured = false;
    final f = row['is_featured'];
    if (f is bool) {
      featured = f;
    } else if (f is num) {
      featured = f != 0;
    }

    var verified = false;
    final v = row['is_verified'];
    if (v is bool) {
      verified = v;
    } else if (v is num) {
      verified = v != 0;
    }

    double? lat;
    double? lng;
    final la = row['location_lat'];
    final ln = row['location_lng'];
    if (la is num) lat = la.toDouble();
    if (ln is num) lng = ln.toDouble();

    var cat =
        (row['category'] ?? VenueCategory.sportsCourt).toString().toLowerCase().trim();
    if (cat == 'sports') cat = VenueCategory.sportsCourt;
    if (cat == 'store') cat = VenueCategory.retail;

    final r = row['rating'];
    final ratingVal = r is num ? r.toDouble() : 0.0;
    final rc = row['review_count'];
    final reviewVal = rc is num ? rc.toInt() : 0;

    return Venue(
      id: row['id']?.toString() ?? '',
      name: (row['name'] ?? '').toString().trim(),
      category: cat,
      coverImageUrl: _trimOrNull(row['cover_image_url']),
      locationLat: lat,
      locationLng: lng,
      address: _trimOrNull(row['address']),
      description: _trimOrNull(row['description']),
      bookingUrl: _trimOrNull(row['booking_url']),
      websiteUrl: _trimOrNull(row['website_url']),
      phone: _trimOrNull(row['phone']),
      isFeatured: featured,
      isVerified: verified,
      sport: sports,
      tags: tagList,
      images: imageList,
      openingHours: _trimOrNull(row['opening_hours']),
      instagramUrl: _trimOrNull(row['instagram_url']),
      priceRange: _trimOrNull(row['price_range']),
      rating: ratingVal,
      reviewCount: reviewVal,
    );
  }

  static String? _trimOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
