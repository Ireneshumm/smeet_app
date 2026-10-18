import 'package:flutter/material.dart';

import 'package:smeet_app/core/services/ai_assistant_service.dart';
import 'package:smeet_app/core/theme/theme.dart';

/// Opens the AI chat coach for a 1:1 chat. Returns the suggestion the user
/// picked (to drop into the composer — never sent automatically), or `null`.
///
/// [recent] are the latest messages as `(isMe, text)`, oldest first.
Future<String?> showChatCoachSheet(
  BuildContext context, {
  required String otherUserId,
  required List<(bool isMe, String text)> recent,
  String draft = '',
}) async {
  if (!await AiAssistantService.hasChatConsent()) {
    if (!context.mounted) return null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI chat helper'),
        content: const Text(
          'AI can suggest openers, replies, or polish your draft.\n\n'
          'When you tap a helper, your last few messages in this chat and '
          'both public profiles are sent to our AI provider to create '
          'suggestions. Nothing is saved, and nothing is sent unless you '
          'choose it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    await AiAssistantService.saveChatConsent();
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ChatCoachSheet(
      otherUserId: otherUserId,
      recent: recent,
      draft: draft.trim(),
    ),
  );
}

class _ChatCoachSheet extends StatefulWidget {
  const _ChatCoachSheet({
    required this.otherUserId,
    required this.recent,
    required this.draft,
  });

  final String otherUserId;
  final List<(bool isMe, String text)> recent;
  final String draft;

  @override
  State<_ChatCoachSheet> createState() => _ChatCoachSheetState();
}

class _ChatCoachSheetState extends State<_ChatCoachSheet> {
  late ChatCoachMode _mode = widget.draft.isNotEmpty
      ? ChatCoachMode.polish
      : widget.recent.isEmpty
          ? ChatCoachMode.opener
          : ChatCoachMode.reply;
  bool _loading = false;
  String? _error;
  List<String> _suggestions = const [];
  String _tip = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _enabled(ChatCoachMode m) => switch (m) {
        ChatCoachMode.opener => true,
        ChatCoachMode.reply => widget.recent.isNotEmpty,
        ChatCoachMode.polish => widget.draft.isNotEmpty,
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = const [];
      _tip = '';
    });
    try {
      final out = await AiAssistantService.coach(
        mode: _mode,
        otherUserId: widget.otherUserId,
        messages: widget.recent,
        draft: widget.draft,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = out.suggestions;
        _tip = out.tip;
      });
    } on AiAssistantException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI chat helper',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<ChatCoachMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ChatCoachMode.opener,
                  label: const Text('Start'),
                  enabled: _enabled(ChatCoachMode.opener),
                ),
                ButtonSegment(
                  value: ChatCoachMode.reply,
                  label: const Text('Reply'),
                  enabled: _enabled(ChatCoachMode.reply),
                ),
                ButtonSegment(
                  value: ChatCoachMode.polish,
                  label: const Text('Polish draft'),
                  enabled: _enabled(ChatCoachMode.polish),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _loading
                  ? null
                  : (s) {
                      setState(() => _mode = s.first);
                      _load();
                    },
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              )
            else ...[
              for (final s in _suggestions) ...[
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: ListTile(
                    title: Text(s),
                    trailing: const Icon(Icons.north_west_rounded,
                        size: AppIconSize.sm),
                    onTap: () => Navigator.pop(context, s),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              if (_tip.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '💡 $_tip',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tap one to edit it before sending.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: AppIconSize.xs),
                    label: const Text('More ideas'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
