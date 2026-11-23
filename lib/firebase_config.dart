/// Firebase settings for linking the son's phone.
///
/// Leave them empty to use the app on one phone only (no linking).
/// See README.md for where to copy each value from.
class FirebaseConfig {
  static const apiKey = '';
  static const appId = '';
  static const messagingSenderId = '';
  static const projectId = '';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;
}
