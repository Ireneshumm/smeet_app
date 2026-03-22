import 'package:flutter/material.dart';

import '../services/report_service.dart';

/// Preset reasons stored in [reports.reason] (plain text).
const List<({String label, String value})> kReportReasonOptions = [
  (label: 'Spam', value: 'Spam'),
  (label: 'Harassment', value: 'Harassment'),
  (label: 'Inappropriate content', value: 'Inappropriate content'),
  (label: 'Fake account', value: 'Fake account'),
  (label: 'Other', value: 'Other'),
];

/// Bottom sheet: choose reason + optional details → [ReportService.submit].
///
/// Provide [targetUserId] for user reports, and/or [messageId] (+ author) for message reports.
Future<void> showReportBottomSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? targetUserId,
  String? messageId,
}) async {
  assert(
    targetUserId != null || messageId != null,
    'Need targetUserId and/or messageId',
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return _ReportSheetBody(
        title: title,
        subtitle: subtitle,
        targetUserId: targetUserId,
        messageId: messageId,
      );
    },
  );
}

class _ReportSheetBody extends StatefulWidget {
  const _ReportSheetBody({
    required this.title,
    this.subtitle,
    this.targetUserId,
    this.messageId,
  });

  final String title;
  final String? subtitle;
  final String? targetUserId;
  final String? messageId;

  @override
  State<_ReportSheetBody> createState() => _ReportSheetBodyState();
}

class _ReportSheetBodyState extends State<_ReportSheetBody> {
  int _selected = 0;
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final reason = kReportReasonOptions[_selected].value;
    try {
      await ReportService.submit(
        reason: reason,
        details: _detailsCtrl.text,
        targetUserId: widget.targetUserId,
        messageId: widget.messageId,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Report submitted')),
      );
    } on ReportSubmissionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      height: 1.35,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Reason',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ...List.generate(kReportReasonOptions.length, (i) {
              final o = kReportReasonOptions[i];
              return RadioListTile<int>(
                value: i,
                groupValue: _selected,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _selected = v ?? 0),
                title: Text(o.label),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsCtrl,
              enabled: !_submitting,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                hintText: 'Help us understand what happened…',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}
