import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n.dart';
import '../core/links.dart';
import '../services/update_service.dart';
import '../services/ytdlp_service.dart';

enum UpdateStatus { checking, latest, available, unknown }

/// App update state: Settings card, start-up popup, in-app download + install.
class UpdateProvider extends ChangeNotifier {
  final AppSettings settings;
  final _svc = YtDlpService();

  UpdateStatus status = UpdateStatus.checking;
  UpdateInfo? info;
  bool downloading = false;
  double progress = 0;
  String? errorKey;

  String skipped = ''; // version the user chose not to install
  int remindAt = 0; // ms - do not show the popup before this time
  String _sig = '';

  /// Completes when the first check is done (the start-up popup waits for it).
  late final Future<void> ready;

  UpdateProvider(this.settings) {
    ready = _init();
    _sig = '${settings.lang}|${settings.notifications}';
    settings.addListener(() {
      final s = '${settings.lang}|${settings.notifications}';
      if (s != _sig) {
        _sig = s;
        applySchedule();
      }
    });
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    skipped = p.getString('update_skipped') ?? '';
    remindAt = p.getInt('update_remind_at') ?? 0;
    await UpdateService.cleanup(kAppVersion); // remove the old installer file
    await applySchedule();
    await check();
  }

  bool get shouldPrompt =>
      status == UpdateStatus.available &&
      info != null &&
      info!.version != skipped &&
      DateTime.now().millisecondsSinceEpoch >= remindAt;

  Future<void> remindLater() async {
    remindAt = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
    (await SharedPreferences.getInstance()).setInt('update_remind_at', remindAt);
  }

  Future<void> skipVersion() async {
    skipped = info?.version ?? '';
    (await SharedPreferences.getInstance()).setString('update_skipped', skipped);
    await applySchedule();
    notifyListeners();
  }

  Future<void> check() async {
    try {
      final abi = await _svc.abi();
      final i = await UpdateService.latest(kUpdateRepo, abi);
      if (i == null) {
        status = UpdateStatus.unknown;
      } else if (UpdateService.isNewer(i.version, kAppVersion)) {
        info = i;
        status = UpdateStatus.available;
      } else {
        status = UpdateStatus.latest;
      }
    } catch (_) {
      status = UpdateStatus.unknown;
    }
    notifyListeners();
  }

  /// Background version check + notification (only while notifications are on).
  Future<void> applySchedule() async {
    try {
      await _svc.scheduleUpdate(
        enabled: settings.notifications,
        repo: kUpdateRepo,
        version: kAppVersion,
        title: settings.t('nu_title'),
        body: settings.t('nu_body'),
        skipped: skipped,
      );
    } catch (_) {}
  }

  /// Downloads the new APK (natively, survives screen-off), then opens the installer.
  /// Returns a message key when something needs the user's attention.
  Future<String?> downloadAndInstall() async {
    final i = info;
    if (i == null || downloading) return null;
    errorKey = null;
    downloading = true;
    progress = 0;
    notifyListeners();

    final sub = _svc.events.where((e) => e['id'] == '__update__').listen((e) {
      progress = ((((e['progress'] as num?) ?? 0).toDouble()) / 100).clamp(0.0, 1.0);
      notifyListeners();
    });
    try {
      final dir = (await getExternalStorageDirectory()) ?? await getTemporaryDirectory();
      final file = File('${dir.path}/0XDL-${i.version}.apk');
      if (await file.exists()) await file.delete();

      await _svc.downloadApk(
        url: i.apkUrl,
        path: file.path,
        title: '0XDL ${i.version}',
        strings: {
          'downloading': settings.t('up_downloading'),
          'processing': settings.t('up_opening'),
          'done': settings.t('n_done'),
          'failed': settings.t('n_failed'),
          'multi': settings.t('n_multi'),
        },
      );
      downloading = false;
      notifyListeners();

      var st = await Permission.requestInstallPackages.status;
      if (!st.isGranted) st = await Permission.requestInstallPackages.request();
      if (!st.isGranted) return 'up_perm';

      await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      return 'up_opening';
    } catch (_) {
      errorKey = 'up_fail';
      return 'up_fail';
    } finally {
      await sub.cancel();
      downloading = false;
      notifyListeners();
    }
  }
}
