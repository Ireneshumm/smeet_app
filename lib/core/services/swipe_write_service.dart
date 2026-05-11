import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bulletproof swipe write — 优雅处理所有重复场景。
///
/// 策略：先尝试 UPDATE（如果没有现有 swipe 则影响 0 行）。
/// 0 行被更新时，INSERT 新行。
/// 如果 INSERT 因为 23505 race condition 失败，再次 fallback 到 UPDATE。
///
/// 不依赖 Supabase upsert + onConflict 行为（已观察到在某些 SDK 路径
/// 下不能正确传递 Prefer: merge-duplicates header）。
class SwipeWriteService {
  SwipeWriteService(this._client);
  final SupabaseClient _client;

  /// 记录一次滑卡。永远不向 UI 层抛异常。
  /// 成功返回 true，不可恢复的失败返回 false。
  Future<bool> recordSwipe({
    required String fromUserId,
    required String toUserId,
    required String action, // 'play' or 'skip'
  }) async {
    // 策略 1：先尝试 UPDATE
    try {
      final updated = await _client
          .from('swipes')
          .update({'action': action})
          .eq('from_user', fromUserId)
          .eq('to_user', toUserId)
          .select('id');

      if (updated is List && updated.isNotEmpty) {
        debugPrint('[SwipeWriteService] UPDATE succeeded $fromUserId→$toUserId action=$action');
        return true;
      }
    } catch (e) {
      debugPrint('[SwipeWriteService] UPDATE attempt failed (will try INSERT): $e');
    }

    // 策略 2：没有现有行，尝试 INSERT
    try {
      await _client.from('swipes').insert({
        'from_user': fromUserId,
        'to_user': toUserId,
        'action': action,
      });
      debugPrint('[SwipeWriteService] INSERT succeeded $fromUserId→$toUserId action=$action');
      return true;
    } on PostgrestException catch (e) {
      // 23505 = unique violation, race condition. Fallback 到 UPDATE。
      if (e.code == '23505' ||
          e.message.toLowerCase().contains('duplicate') ||
          e.message.toLowerCase().contains('unique')) {
        debugPrint('[SwipeWriteService] INSERT 撞 23505，fallback 到 UPDATE');
        try {
          await _client
              .from('swipes')
              .update({'action': action})
              .eq('from_user', fromUserId)
              .eq('to_user', toUserId);
          return true;
        } catch (e2) {
          debugPrint('[SwipeWriteService] 最终 UPDATE fallback 失败: $e2');
          return false;
        }
      }
      debugPrint('[SwipeWriteService] INSERT 失败 (非 duplicate 错误): $e');
      return false;
    } catch (e) {
      debugPrint('[SwipeWriteService] INSERT 失败 (非 PostgrestException): $e');
      return false;
    }
  }
}
