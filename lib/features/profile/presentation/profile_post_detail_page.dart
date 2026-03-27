import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smeet_app/core/services/posts_service.dart';
import 'package:smeet_app/features/profile/models/profile_tab_item.dart';
import 'package:smeet_app/widgets/post_media_display.dart';

/// Minimal real post detail for Profile MVP **Posts** tab (by [ProfileTabItem.id]).
class ProfileMvpPostDetailPage extends StatefulWidget {
  const ProfileMvpPostDetailPage({super.key, required this.item});

  final ProfileTabItem item;

  @override
  State<ProfileMvpPostDetailPage> createState() =>
      _ProfileMvpPostDetailPageState();
}

class _ProfileMvpPostDetailPageState extends State<ProfileMvpPostDetailPage> {
  late final PostsService _posts = PostsService();
  late final Future<Map<String, dynamic>?> _future =
      _posts.fetchPostById(widget.item.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final row = snapshot.data;
          if (row == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Post not found or unavailable.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _PostDetailBody(row: row);
        },
      ),
    );
  }
}

class _PostDetailBody extends StatelessWidget {
  const _PostDetailBody({required this.row});

  final Map<String, dynamic> row;

  static List<String> _urls(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static String? _mediaType(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static DateTime? _createdAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  static String _humanMediaKind(String raw) {
    final t = raw.trim().toLowerCase();
    if (t == 'video') return 'Video';
    if (t == 'image') return 'Photo';
    if (t.isEmpty || t == '—') return 'Post';
    return raw.trim().isEmpty ? 'Post' : raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final caption = (row['caption'] as String?)?.trim() ?? '';
    final mediaTypeRaw = _mediaType(row['media_type']) ?? '';
    final urls = _urls(row['media_urls']);
    final created = _createdAt(row['created_at']);
    final when = created != null
        ? DateFormat.yMMMd().add_jm().format(created.toLocal())
        : '—';
    final kindLabel = _humanMediaKind(mediaTypeRaw.isEmpty ? '—' : mediaTypeRaw);
    final t = mediaTypeRaw.toLowerCase();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          if (urls.isNotEmpty) ...[
            if (t == 'video')
              PostMediaDetailVideo(url: urls.first)
            else
              PostMediaDetailImages(urls: urls),
            const SizedBox(height: 22),
          ] else ...[
            Text(
              'No media attached to this post.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
          ],
          Text(
            'Caption',
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (caption.isEmpty)
            Text(
              'No caption for this post.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            )
          else
            Text(
              caption,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          const SizedBox(height: 22),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posted',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    when,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(kindLabel),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
