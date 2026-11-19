import 'package:url_launcher/url_launcher.dart';

/// Both values are injected by CI (tag v1.0.4 -> 1.0.4, and the repo that built the APK),
/// so the same code works in the testing repo and later in the main repo.
const kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
const kUpdateRepo =
    String.fromEnvironment('UPDATE_REPO', defaultValue: 'Zeroex-0X/0XDL');

class Links {
  static const tagline = 'Made With Love By Zeroex';

  // Same developer links as the Annua app
  static const website = 'https://zeroex-0x.github.io/';
  static const support = 'https://zeroex-0x.github.io/support.html';
  static const telegram = 'https://t.me/zeroex_0x';
  static const facebook = 'https://www.facebook.com/zeroex.0X';
  static const github = 'https://github.com/Zeroex-0X';

  /// "About App" link - put the main repo / page link here before publishing.
  /// While it is empty the button is hidden.
  static const aboutApp = 'https://zeroex-0x.github.io/0xdl';

  static Future<void> open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
