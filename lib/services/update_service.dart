import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String notes;
  final String pageUrl;
  final String apkUrl;
  final int size;
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.apkUrl,
    required this.size,
  });
}

/// Checks the GitHub releases of the repo that built this APK and downloads the update.
class UpdateService {
  static Future<UpdateInfo?> latest(String repo, String abi) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req =
          await c.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers.set('User-Agent', '0XDL');
      req.headers.set('Accept', 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null; // private repo / no release yet
      final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      final assets = [
        for (final a in (j['assets'] as List? ?? []))
          if ('${(a as Map)['name']}'.toLowerCase().endsWith('.apk')) a
      ];
      if (assets.isEmpty) return null;
      Map pick = assets.firstWhere(
          (a) => abi.isNotEmpty && '${(a as Map)['name']}'.contains(abi),
          orElse: () => assets.firstWhere(
              (a) => '${(a as Map)['name']}'.contains('arm64'),
              orElse: () => assets.first)) as Map;
      return UpdateInfo(
        version: '${j['tag_name']}'.replaceFirst(RegExp(r'^[vV]'), ''),
        notes: _clean('${j['body'] ?? ''}'),
        pageUrl: '${j['html_url']}',
        apkUrl: '${pick['browser_download_url']}',
        size: (pick['size'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  static String _clean(String md) {
    var t = md
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'\r'), '')
        .trim();
    if (t.length > 900) t = '${t.substring(0, 900)}…';
    return t;
  }

  static bool isNewer(String latest, String current) {
    List<int> parse(String v) =>
        v.split(RegExp(r'[.+\-]')).map((e) => int.tryParse(e) ?? 0).toList();
    final a = parse(latest), b = parse(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Deletes downloaded update files that are no longer needed
  /// (their version is not newer than the installed one).
  static Future<void> cleanup(String current) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      for (final f in dir.listSync()) {
        if (f is! File || !f.path.endsWith('.apk')) continue;
        final m = RegExp(r'0XDL-(.+)\.apk$').firstMatch(f.path.split('/').last);
        final v = m?.group(1) ?? '';
        if (v.isEmpty || !isNewer(v, current)) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
