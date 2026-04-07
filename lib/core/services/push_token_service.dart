import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushTokenService {
  PushTokenService(this._db);

  final SupabaseClient _db;

  /// 在用户登录后调用一次（非 Web）。
  Future<void> registerCurrentToken() async {
    if (kIsWeb) return;

    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

      await _db.from('user_push_tokens').upsert(
        {
          'user_id': uid,
          'fcm_token': token,
          'platform': platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,fcm_token',
      );
      debugPrint('[Push] token registered platform=$platform');
    } catch (e) {
      debugPrint('[Push] registerCurrentToken failed: $e');
    }
  }

  /// Token 刷新时调用；整个 App 生命周期内只应 [listen] 一次。
  void listenTokenRefresh() {
    if (kIsWeb) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      registerCurrentToken();
    });
  }
}
