import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

/// Talks to the native yt-dlp + ffmpeg + aria2c engine (see android_overrides/MainActivity.kt).
class YtDlpService {
  static const _method = MethodChannel('oxdl/ytdlp');
  static const _events = EventChannel('oxdl/progress');

  // one shared stream: several listeners (downloads, app update) must not replace each other
  static final Stream<Map<dynamic, dynamic>> _shared =
      _events.receiveBroadcastStream().map((e) => e as Map);

  Stream<Map<dynamic, dynamic>> get events => _shared;

  Future<void> init() => _method.invokeMethod('init');

  Future<VideoMeta> getInfo(String url) async {
    try {
      final raw = await _method.invokeMethod<String>('info', {'url': url});
      final j = jsonDecode(raw!) as Map;
      return VideoMeta(
        url: url,
        title: '${j['title']}',
        thumbnail: '${j['thumbnail']}',
        duration: ((j['duration'] as num?) ?? 0).toInt(),
        uploader: '${j['uploader']}',
        extractor: '${j['extractor'] ?? ''}',
        domain: '${j['domain'] ?? ''}',
        formats: [
          for (final f in (j['formats'] as List)) FormatInfo.fromJson(f as Map)
        ],
      );
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Failed to read link');
    }
  }

  Future<String> download({
    required String id,
    required String url,
    required String dir,
    required String title,
    required String thumb,
    required bool notify,
    required Map<String, String> strings,
    required List<List<String>> args,
  }) async {
    try {
      final r = await _method.invokeMethod<String>('download', {
        'id': id,
        'url': url,
        'dir': dir,
        'title': title,
        'thumb': thumb,
        'notify': notify,
        'strings': strings,
        'args': args,
      });
      return r ?? '';
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Download failed');
    }
  }

  Future<void> cancel(String id) => _method.invokeMethod('cancel', {'id': id});

  Future<String> updateEngine(String channel) async {
    try {
      return (await _method
              .invokeMethod<String>('update', {'channel': channel})) ??
          'UNKNOWN';
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Update failed');
    }
  }

  Future<String> version() async =>
      (await _method.invokeMethod<String>('version')) ?? '';

  /// CPU type of this phone (arm64-v8a, armeabi-v7a, x86_64) - used to pick the right APK.
  Future<String> abi() async =>
      (await _method.invokeMethod<String>('abi')) ?? '';

  /// Background check for new app versions (shows a notification when one is found).
  Future<void> scheduleUpdate({
    required bool enabled,
    required String repo,
    required String version,
    required String title,
    required String body,
    String skipped = '',
  }) =>
      _method.invokeMethod('scheduleUpdate', {
        'skipped': skipped,
        'enabled': enabled,
        'repo': repo,
        'version': version,
        'title': title,
        'body': body,
      });

  /// Tells Gallery / file managers about added, renamed or deleted files.
  Future<void> scan(List<String> paths) async {
    try {
      await _method.invokeMethod('scan', {'paths': paths});
    } catch (_) {}
  }

  /// Cover / video frame saved as a local JPEG (empty string if it cannot be made).
  Future<String> thumbnail(String path) async {
    try {
      return (await _method.invokeMethod<String>('thumbnail', {'path': path})) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Downloads the new APK natively (a foreground service keeps it alive with the screen off).
  Future<String> downloadApk({
    required String url,
    required String path,
    required String title,
    required Map<String, String> strings,
  }) async {
    try {
      return (await _method.invokeMethod<String>('downloadApk', {
            'url': url,
            'path': path,
            'title': title,
            'strings': strings,
          })) ??
          path;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Download failed');
    }
  }
}
