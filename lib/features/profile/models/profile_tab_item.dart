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
  });

  final String id;
  final ProfileContentTab tab;
  final String title;
  final String subtitle;
}
