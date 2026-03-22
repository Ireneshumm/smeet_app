import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when a report cannot be submitted; [message] is safe for UI.
class ReportSubmissionException implements Exception {
  ReportSubmissionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Submits rows to [public.reports] (RLS: reporter must be auth.uid()).
class ReportService {
  ReportService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// User report: set [targetUserId]; [messageId] null.
  /// Message report: set [messageId] and [targetUserId] (message author).
  static Future<void> submit({
    required String reason,
    String? details,
    String? targetUserId,
    String? messageId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw ReportSubmissionException('Please sign in to submit a report.');
    }
    if (targetUserId == null && messageId == null) {
      throw ReportSubmissionException(
        'This report is missing required information.',
      );
    }

    final trimmed = details?.trim();
    final payload = <String, dynamic>{
      'reporter_id': uid,
      'target_user_id': targetUserId,
      'message_id': messageId,
      'reason': reason,
      if (trimmed != null && trimmed.isNotEmpty) 'details': trimmed,
    };

    try {
      await _client.from('reports').insert(payload);
    } catch (e, st) {
      debugPrint('[Report] insert failed: $e\n$st');
      throw ReportSubmissionException(_friendlyError(e));
    }
  }

  static String _friendlyError(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('row-level security') ||
        raw.contains('permission denied') ||
        raw.contains('42501')) {
      return 'You don’t have permission to submit this report.';
    }
    if (raw.contains('foreign key') ||
        raw.contains('23503') ||
        raw.contains('violates foreign key')) {
      return 'That content is no longer available to report.';
    }
    if (raw.contains('check constraint') ||
        raw.contains('23514')) {
      return 'This report couldn’t be saved. Please try again.';
    }
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network')) {
      return 'Network error. Check your connection and try again.';
    }
    return 'We couldn’t send your report. Please try again in a moment.';
  }
}
