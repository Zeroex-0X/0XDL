import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// The list lives in app storage. After a reinstall it is rebuilt from the media files
/// in Download/0XDL (the source link is read from the tag stored inside each file).
class HistoryService {
  static const _k = 'download_history';
  static const _kIgnored = 'history_ignored';
  static const root = '/storage/emulated/0/Download/0XDL';
  static const _exts = {
    'mp4', 'mkv', 'webm', 'mov', 'm4v', 'mp3', 'm4a', 'opus', 'ogg', 'flac', 'wav', 'aac'
  };

  // ------------------------------------------------------------ app storage
  static Future<List<HistoryEntry>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_k);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<HistoryEntry> list) async {
    await (await SharedPreferences.getInstance())
        .setString(_k, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  /// Files the user removed from the list but kept on the phone (not restored again).
  static Future<Set<String>> ignored() async =>
      ((await SharedPreferences.getInstance()).getStringList(_kIgnored) ?? []).toSet();

  static Future<void> addIgnored(String path) async {
    final p = await SharedPreferences.getInstance();
    final s = (p.getStringList(_kIgnored) ?? []).toSet()..add(path);
    await p.setStringList(_kIgnored, s.toList());
  }

  /// Returns false if the file did not exist.
  static Future<bool> deleteFile(String path) async {
    if (path.isEmpty) return false;
    final f = File(path);
    if (!await f.exists()) return false;
    await f.delete();
    return true;
  }

  /// Every media file inside Download/0XDL (all platform folders).
  static Future<List<File>> scanFiles() async {
    final out = <File>[];
    try {
      final d = Directory(root);
      if (!await d.exists()) return out;
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final n = e.path.toLowerCase();
        final i = n.lastIndexOf('.');
        if (i > 0 && _exts.contains(n.substring(i + 1)) && !n.contains('/.')) out.add(e);
      }
    } catch (_) {}
    return out;
  }
}
