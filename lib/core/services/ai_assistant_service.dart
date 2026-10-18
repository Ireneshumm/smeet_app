import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smeet_app/services/block_service.dart';

/// UI-safe error for AI requests.
class AiAssistantException implements Exception {
  AiAssistantException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One player suggested by "AI find players".
class AiPlayerMatch {
  AiPlayerMatch({
    required this.id,
    required this.displayName,
    required this.reason,
    this.avatarUrl,
    this.city,
    this.sportLevels = const {},
    this.distanceKm,
  });

  final String id;
  final String displayName;
  final String reason;
  final String? avatarUrl;
  final String? city;
  final Map<String, dynamic> sportLevels;
  final double? distanceKm;

  factory AiPlayerMatch.fromJson(Map<String, dynamic> j) => AiPlayerMatch(
        id: j['id'].toString(),
        displayName: (j['display_name'] ?? 'Player').toString(),
        reason: (j['reason'] ?? '').toString(),
        avatarUrl: j['avatar_url']?.toString(),
        city: j['city']?.toString(),
        sportLevels: j['sport_levels'] is Map
            ? Map<String, dynamic>.from(j['sport_levels'] as Map)
            : const {},
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
      );
}

/// Chat coach modes, matching the `ai-assistant` Edge Function.
enum ChatCoachMode { opener, reply, polish }

/// Talks to the `ai-assistant` Edge Function (Claude on the server; the API
/// key never ships in the app). Requires a signed-in user.
abstract final class AiAssistantService {
  static const _function = 'ai-assistant';
  static const _consentKey = 'smeet_ai_chat_consent';

  static SupabaseClient get _client => Supabase.instance.client;

  /// Describe who you're looking for in plain words; optionally search around
  /// a picked place.
  static Future<({String summary, List<AiPlayerMatch> results})> findPlayers(
    String query, {
    ({double lat, double lng, String label})? near,
  }) async {
    final data = await _invoke({
      'action': 'find_players',
      'query': query,
      if (near != null)
        'near': {'lat': near.lat, 'lng': near.lng, 'label': near.label},
    });
    final blocks = await BlockService.fetchMyBlockSets();
    final results = ((data['results'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => AiPlayerMatch.fromJson(Map<String, dynamic>.from(m)))
        .where((p) =>
            !blocks.iBlocked.contains(p.id) && !blocks.blockedMe.contains(p.id))
        .toList();
    return (summary: (data['summary'] ?? '').toString(), results: results);
  }

  /// Suggested messages for a 1:1 chat. [messages] are the most recent turns
  /// as `(isMe, text)`; only sent for [ChatCoachMode.reply].
  static Future<({List<String> suggestions, String tip})> coach({
    required ChatCoachMode mode,
    required String otherUserId,
    List<(bool isMe, String text)> messages = const [],
    String? draft,
  }) async {
    final data = await _invoke({
      'action': 'chat_coach',
      'mode': mode.name,
      'otherUserId': otherUserId,
      if (mode == ChatCoachMode.reply)
        'messages': [
          for (final m in messages) {'from': m.$1 ? 'me' : 'them', 'text': m.$2},
        ],
      if (mode == ChatCoachMode.polish) 'draft': draft ?? '',
    });
    return (
      suggestions: ((data['suggestions'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList(),
      tip: (data['tip'] ?? '').toString(),
    );
  }

  /// Whether the user already accepted the chat-coach privacy notice.
  static Future<bool> hasChatConsent() async {
    try {
      final store = SharedPreferencesLocalStorage(persistSessionKey: _consentKey);
      await store.initialize();
      return await store.accessToken() == 'yes';
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveChatConsent() async {
    try {
      final store = SharedPreferencesLocalStorage(persistSessionKey: _consentKey);
      await store.initialize();
      await store.persistSession('yes');
    } catch (e) {
      debugPrint('[AiAssistant] consent not saved: $e');
    }
  }

  static Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    if (_client.auth.currentUser == null) {
      throw AiAssistantException('Please sign in to use AI features.');
    }
    try {
      final res = await _client.functions.invoke(_function, body: body);
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AiAssistantException('Unexpected AI response.');
    } on FunctionException catch (e) {
      debugPrint('[AiAssistant] ${e.status}: ${e.details}');
      final code = e.details is Map ? (e.details as Map)['error'] : null;
      throw AiAssistantException(
        code == 'ai_not_configured'
            ? 'AI features are coming soon.'
            : 'AI is busy right now. Please try again.',
      );
    } on AiAssistantException {
      rethrow;
    } catch (e) {
      debugPrint('[AiAssistant] failed: $e');
      throw AiAssistantException('Could not reach AI. Check your connection.');
    }
  }
}
