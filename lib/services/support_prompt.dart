import 'package:shared_preferences/shared_preferences.dart';

/// Asks for support based on how much the app was used (finished downloads), not on time:
///  - first request after 3 finished downloads,
///  - "Maybe later" -> again after 10 more downloads, then 20, then every 40,
///  - after tapping "Support" -> not again for 100 downloads.
/// It is shown only on a calm screen (no other dialog, no running download).
class SupportPrompt {
  static const _kDone = 'support_done_count';
  static const _kNext = 'support_next_at';
  static const _kLater = 'support_later_count';
  static const firstAfter = 3;

  static Future<int> _done(SharedPreferences p) async => p.getInt(_kDone) ?? 0;

  static Future<void> onDownloadDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kDone, (await _done(p)) + 1);
  }

  static Future<bool> due() async {
    final p = await SharedPreferences.getInstance();
    return (await _done(p)) >= (p.getInt(_kNext) ?? firstAfter);
  }

  static Future<void> later() async {
    final p = await SharedPreferences.getInstance();
    final n = (p.getInt(_kLater) ?? 0) + 1;
    final step = n == 1 ? 10 : (n == 2 ? 20 : 40);
    await p.setInt(_kLater, n);
    await p.setInt(_kNext, (await _done(p)) + step);
  }

  static Future<void> supported() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kNext, (await _done(p)) + 100);
  }
}
