import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Outcome of [AccountDeletionService.submitDeletionRequest].
enum AccountDeletionSubmissionKind {
  /// New row inserted, or existing row re-opened to `pending` from completed/cancelled.
  recorded,

  /// A `pending` or `processing` request already exists — no DB change.
  alreadyActive,
}

/// Result of submitting (or attempting) a deletion request — always includes [requestId] when known.
class AccountDeletionSubmission {
  const AccountDeletionSubmission({
    required this.kind,
    this.requestId,
    this.requestedAt,
  });

  final AccountDeletionSubmissionKind kind;

  /// Server row id — use as human-facing reference (e.g. support tickets).
  final String? requestId;

  /// When the request row was first created (if returned by API).
  final DateTime? requestedAt;

  bool get isAlreadyActive => kind == AccountDeletionSubmissionKind.alreadyActive;
}

/// Snapshot of an in-flight deletion request the user may still have open.
class ActiveDeletionRequest {
  const ActiveDeletionRequest({
    required this.requestId,
    required this.status,
    required this.createdAt,
  });

  final String requestId;
  final String status;
  final DateTime? createdAt;
}

class AccountDeletionException implements Exception {
  AccountDeletionException(this.userMessage);
  final String userMessage;

  @override
  String toString() => userMessage;
}

/// Records rows in [public.account_deletion_requests] (RLS: user_id = auth.uid()).
/// This is a **deletion request workflow** — it does not delete the Auth user or app data from the client.
class AccountDeletionService {
  AccountDeletionService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Returns a **pending** or **processing** request for the signed-in user, if any.
  static Future<ActiveDeletionRequest?> fetchActiveDeletionRequest() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    try {
      final row = await _client
          .from('account_deletion_requests')
          .select('id, status, created_at')
          .eq('user_id', uid)
          .maybeSingle();

      if (row == null) return null;
      final st = (row['status'] ?? '').toString();
      if (st != 'pending' && st != 'processing') return null;

      final id = row['id']?.toString();
      if (id == null || id.isEmpty) return null;

      final ca = row['created_at']?.toString();
      return ActiveDeletionRequest(
        requestId: id,
        status: st,
        createdAt: ca != null ? DateTime.tryParse(ca) : null,
      );
    } catch (e, st) {
      debugPrint('[AccountDeletion] fetchActiveDeletionRequest: $e\n$st');
      return null;
    }
  }

  /// Inserts or updates `account_deletion_requests` and returns the **request id** for user reference.
  static Future<AccountDeletionSubmission> submitDeletionRequest() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw AccountDeletionException(
        'You need to be signed in to submit a deletion request.',
      );
    }

    try {
      final existing = await _client
          .from('account_deletion_requests')
          .select('id, status, created_at')
          .eq('user_id', uid)
          .maybeSingle();

      if (existing != null) {
        final st = (existing['status'] ?? 'pending').toString();
        final rid = existing['id']?.toString();
        final ca = existing['created_at']?.toString();

        if (st == 'pending' || st == 'processing') {
          return AccountDeletionSubmission(
            kind: AccountDeletionSubmissionKind.alreadyActive,
            requestId: rid,
            requestedAt: ca != null ? DateTime.tryParse(ca) : null,
          );
        }

        final updated = await _client
            .from('account_deletion_requests')
            .update({'status': 'pending'})
            .eq('user_id', uid)
            .select('id, created_at')
            .single();

        final newId = updated['id']?.toString();
        final nca = updated['created_at']?.toString();
        return AccountDeletionSubmission(
          kind: AccountDeletionSubmissionKind.recorded,
          requestId: newId ?? rid,
          requestedAt: nca != null ? DateTime.tryParse(nca) : null,
        );
      }

      final inserted = await _client.from('account_deletion_requests').insert({
        'user_id': uid,
        'status': 'pending',
      }).select('id, created_at').single();

      final iid = inserted['id']?.toString();
      final ica = inserted['created_at']?.toString();
      return AccountDeletionSubmission(
        kind: AccountDeletionSubmissionKind.recorded,
        requestId: iid,
        requestedAt: ica != null ? DateTime.tryParse(ica) : null,
      );
    } catch (e, st) {
      debugPrint('[AccountDeletion] submit failed: $e\n$st');
      final raw = e.toString().toLowerCase();
      if (raw.contains('unique') || raw.contains('duplicate')) {
        final again = await _client
            .from('account_deletion_requests')
            .select('id, created_at')
            .eq('user_id', uid)
            .maybeSingle();
        final rid = again?['id']?.toString();
        final ca = again?['created_at']?.toString();
        return AccountDeletionSubmission(
          kind: AccountDeletionSubmissionKind.alreadyActive,
          requestId: rid,
          requestedAt: ca != null ? DateTime.tryParse(ca) : null,
        );
      }
      if (raw.contains('row-level security') || raw.contains('permission')) {
        throw AccountDeletionException(
          'We couldn’t submit your request. Please try again or contact support.',
        );
      }
      throw AccountDeletionException(
        'Something went wrong. Check your connection and try again.',
      );
    }
  }

  /// Short reference for UI (first 8 chars of UUID).
  static String formatRequestReference(String? uuid) {
    if (uuid == null || uuid.length < 8) return '—';
    return uuid.substring(0, 8).toUpperCase();
  }
}
