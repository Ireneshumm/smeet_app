import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

/// Read-only profile for another user: basics + recent posts / media (Phase 4).
class OtherProfilePage extends StatelessWidget {
  final String userId;

  const OtherProfilePage({super.key, required this.userId});

  Future<Map<String, dynamic>?> _loadProfile() {
    return Supabase.instance.client
        .from('profiles')
        .select(
          'display_name, city, intro, avatar_url, sport_levels, availability',
        )
        .eq('id', userId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> _loadPosts() async {
    final data = await Supabase.instance.client
        .from('posts')
        .select('id, caption, media_type, media_urls, created_at, author_id')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(24);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Player profile')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadProfile(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final p = snap.data;
          if (p == null) {
            return const Center(child: Text('Profile not found'));
          }

          final name = (p['display_name'] ?? '').toString();
          final city = (p['city'] ?? '').toString();
          final intro = (p['intro'] ?? '').toString();
          final avatar = (p['avatar_url'] ?? '').toString();
          final sportLevels = p['sport_levels'] as Map? ?? {};
          final availability = p['availability'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.primary.withValues(alpha: 0.15),
                  backgroundImage:
                      avatar.isEmpty ? null : NetworkImage(avatar),
                  child: avatar.isEmpty
                      ? Icon(Icons.person, size: 40, color: cs.primary)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? 'Unnamed' : name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(city, textAlign: TextAlign.center),
                ],
                if (intro.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(intro),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sports & level',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                if (sportLevels.isEmpty)
                  const Text('No sports info')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sportLevels.entries.map<Widget>((e) {
                      return Chip(label: Text('${e.key}: ${e.value}'));
                    }).toList(),
                  ),
                if (availability != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Availability',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(availability.toString()),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Posts & media',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recent clips and photos — get a feel for level and style.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadPosts(),
                  builder: (context, postSnap) {
                    if (postSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (postSnap.hasError) {
                      return Text('Could not load posts: ${postSnap.error}');
                    }
                    final posts = postSnap.data ?? [];
                    if (posts.isEmpty) {
                      return const Text('No posts yet.');
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: posts.length,
                      itemBuilder: (context, i) {
                        final post = posts[i];
                        final urls = (post['media_urls'] as List?) ?? [];
                        final first = urls.isEmpty ? '' : urls.first.toString();
                        final type =
                            (post['media_type'] ?? 'image').toString();
                        final cap = (post['caption'] ?? '').toString();
                        return _PostPreviewTile(
                          imageUrl: first,
                          mediaType: type,
                          caption: cap,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostPreviewTile extends StatefulWidget {
  const _PostPreviewTile({
    required this.imageUrl,
    required this.mediaType,
    required this.caption,
  });

  final String imageUrl;
  final String mediaType;
  final String caption;

  @override
  State<_PostPreviewTile> createState() => _PostPreviewTileState();
}

class _PostPreviewTileState extends State<_PostPreviewTile> {
  VideoPlayerController? _vc;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video' && widget.imageUrl.isNotEmpty) {
      _vc = VideoPlayerController.networkUrl(Uri.parse(widget.imageUrl))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.caption.isNotEmpty) Text(widget.caption),
                    if (widget.caption.isNotEmpty) const SizedBox(height: 12),
                    if (widget.mediaType == 'video' &&
                        _vc != null &&
                        _vc!.value.isInitialized)
                      AspectRatio(
                        aspectRatio: _vc!.value.aspectRatio,
                        child: VideoPlayer(_vc!),
                      )
                    else if (widget.imageUrl.isNotEmpty)
                      Image.network(widget.imageUrl),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: widget.mediaType == 'video' &&
                      _vc != null &&
                      _vc!.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _vc!.value.size.width,
                        height: _vc!.value.size.height,
                        child: VideoPlayer(_vc!),
                      ),
                    )
                  : widget.imageUrl.isEmpty
                      ? Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported),
                        )
                      : Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                        ),
            ),
            if (widget.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  widget.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
