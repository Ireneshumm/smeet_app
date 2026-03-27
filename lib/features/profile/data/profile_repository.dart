import 'package:smeet_app/features/profile/models/profile_summary.dart';

/// Loads the Profile MVP header only (tabs use [MockProfileRepository] for now).
abstract interface class ProfileRepository {
  Future<ProfileSummary> fetchSummary();
}
