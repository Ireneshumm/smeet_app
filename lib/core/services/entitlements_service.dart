import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Future paywall hook: empty [user_entitlements] ⇒ all features on.
class EntitlementsService {
  EntitlementsService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String canSeeLikes = 'can_see_likes';
  static const String priorityExposure = 'priority_exposure';
  static const String advancedFilters = 'advanced_filters';
  static const String organizerTools = 'organizer_tools';
  static const String merchantTools = 'merchant_tools';

  Future<Map<String, dynamic>> fetchEntitlements() async {
    final u = _client.auth.currentUser;
    if (u == null) return {};
    try {
      final rows = await _client
          .from('user_entitlements')
          .select()
          .eq('user_id', u.id);
      final map = <String, dynamic>{};
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final k = m['entitlement_key']?.toString();
        if (k != null) map[k] = m['value'];
      }
      return map;
    } catch (e) {
      debugPrint('[EntitlementsService] fetchEntitlements: $e');
      return {};
    }
  }

  /// No row ⇒ true (MVP everything enabled).
  Future<bool> can(String key) async {
    final all = await fetchEntitlements();
    if (all.isEmpty) return true;
    final v = all[key];
    if (v == null) return true;
    if (v is bool) return v;
    if (v is Map && v['enabled'] is bool) return v['enabled'] as bool;
    return true;
  }
}
