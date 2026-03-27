/// Which sub-tab on Profile MVP lists this row.
enum ProfileContentTab {
  posts,
  hosted,
  joined,
}

class ProfileTabItem {
  ProfileTabItem({
    required this.id,
    required this.tab,
    required this.title,
    required this.subtitle,
    this.previewMediaUrl,
    this.previewMediaType,
  });

  final String id;
  final ProfileContentTab tab;
  final String title;
  final String subtitle;

  /// First URL from `media_urls` when mapping live posts (UI only).
  final String? previewMediaUrl;

  /// Lowercase `media_type` from row when present (`image` / `video` / …).
  final String? previewMediaType;
}
