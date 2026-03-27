import 'package:smeet_app/features/profile/data/profile_repository.dart';
import 'package:smeet_app/features/profile/models/profile_summary.dart';
import 'package:smeet_app/features/profile/models/profile_tab_item.dart';

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository();

  @override
  Future<ProfileSummary> fetchSummary({
    Duration delay = const Duration(milliseconds: 200),
  }) async {
    await Future<void>.delayed(delay);
    return _summary;
  }

  Future<List<ProfileTabItem>> fetchTabItems(
    ProfileContentTab tab, {
    Duration delay = const Duration(milliseconds: 200),
  }) async {
    await Future<void>.delayed(delay);
    switch (tab) {
      case ProfileContentTab.posts:
        return List<ProfileTabItem>.unmodifiable(_posts);
      case ProfileContentTab.hosted:
        return List<ProfileTabItem>.unmodifiable(_hosted);
      case ProfileContentTab.joined:
        return List<ProfileTabItem>.unmodifiable(_joined);
    }
  }

  static final ProfileSummary _summary = ProfileSummary(
    displayName: 'Alex Morgan (mock)',
    city: 'Brisbane, Australia',
    sportsSummary: 'Pickleball · Intermediate · Tennis · Beginner',
    avatarUrl: null,
    isGuest: false,
  );

  static final List<ProfileTabItem> _posts = <ProfileTabItem>[
    ProfileTabItem(
      id: 'mvp-post-1',
      tab: ProfileContentTab.posts,
      title: 'Weekend ladder signup open',
      subtitle: 'Posted 2d ago · 24 reactions',
    ),
    ProfileTabItem(
      id: 'mvp-post-2',
      tab: ProfileContentTab.posts,
      title: 'Court lights at North Park',
      subtitle: 'Posted 1w ago · Community',
    ),
  ];

  static final List<ProfileTabItem> _hosted = <ProfileTabItem>[
    ProfileTabItem(
      id: 'mvp-host-1',
      tab: ProfileContentTab.hosted,
      title: 'Open play · Sat 10am',
      subtitle: '4/6 players · Riverside Courts',
    ),
    ProfileTabItem(
      id: 'mvp-host-2',
      tab: ProfileContentTab.hosted,
      title: 'Doubles mixer',
      subtitle: 'Sun 6pm · Union Gym',
    ),
  ];

  static final List<ProfileTabItem> _joined = <ProfileTabItem>[
    ProfileTabItem(
      id: 'mvp-join-1',
      tab: ProfileContentTab.joined,
      title: 'Ladder Week 4',
      subtitle: 'Joined · Next match Tue',
    ),
    ProfileTabItem(
      id: 'mvp-join-2',
      tab: ProfileContentTab.joined,
      title: 'Skills clinic',
      subtitle: 'Completed · Mar 12',
    ),
  ];
}
