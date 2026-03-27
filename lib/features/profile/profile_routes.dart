abstract final class ProfileRoutes {
  static const String list = '/smeet/mvp/profile';

  /// Debug-only: standalone [LegacyProfileSetupSection] (MVP launcher).
  static const String setupDemo = '/smeet/debug/profile-setup';
}

/// `Navigator.pushNamed(..., ProfileRoutes.list, arguments: index)` — tab order on [ProfileMvpPage].
abstract final class ProfileMvpInitialTabIndex {
  ProfileMvpInitialTabIndex._();

  static const int posts = 0;
  static const int hosted = 1;
  static const int joined = 2;
}
