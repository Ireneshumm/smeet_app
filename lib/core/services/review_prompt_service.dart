import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks for an App Store / Play rating once, after the user's 2nd successful
/// game sign-up on this device.
///
/// State lives in a single local key: the join count ("1") until the prompt
/// fires, then "done" forever. Stored via supabase_flutter's
/// [SharedPreferencesLocalStorage] (a plain key/value wrapper) so no extra
/// dependency is needed.
abstract final class ReviewPromptService {
  static const _storageKey = 'smeet_review_prompt';
  static const _doneValue = 'done';
  static const _joinsBeforePrompt = 2;

  /// Call after a sign-up succeeds. Never throws.
  static Future<void> recordSuccessfulJoin() async {
    if (kIsWeb) return;
    try {
      final store = SharedPreferencesLocalStorage(
        persistSessionKey: _storageKey,
      );
      await store.initialize();
      final state = await store.accessToken();
      if (state == _doneValue) return;

      final joins = (int.tryParse(state ?? '') ?? 0) + 1;
      if (joins < _joinsBeforePrompt) {
        await store.persistSession('$joins');
        return;
      }

      // Mark first so a crash or re-entry can never prompt twice.
      await store.persistSession(_doneValue);
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (e) {
      debugPrint('[ReviewPrompt] skipped: $e');
    }
  }
}
