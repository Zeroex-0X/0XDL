import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n.dart';
import '../core/platform_util.dart';
import '../models/models.dart';
import '../services/history_service.dart';
import '../services/meta_reader.dart';
import '../services/option_builder.dart';
import '../services/permission_service.dart';
import '../services/support_prompt.dart';
import '../services/ytdlp_service.dart';

class DownloadProvider extends ChangeNotifier {
  static const downloadDir = '/storage/emulated/0/Download/0XDL';

  final AppSettings settings;
  final _svc = YtDlpService();
  final urlController = TextEditingController();
  StreamSubscription? _sub;
  late final Future<void> _initFuture;

  bool engineReady = false;
  bool engineFailed = false;
  bool analyzing = false;
  String? errorKey;
  VideoMeta? meta;
  List<MediaOption> options = [];
  final List<DownloadItem> items = []; // in progress / failed / cancelled
  bool _restoring = false;
  int doneCount = 0; // finished downloads in this session (the UI listens to it)
  List<HistoryEntry> history = [];
  String engineVersion = '';
  bool updating = false;

  // pre-fetch: the link is analysed in the background while the user is still on the screen
  Timer? _debounce;
  VideoMeta? _cache;
  String? _cacheUrl;
  Future<VideoMeta>? _inflight;
  String? _inflightUrl;

  DownloadProvider(this.settings) {
    _sub = _svc.events.listen(_onEvent, onError: (_) {});
    HistoryService.load().then((h) {
      history = h;
      notifyListeners();
      restoreHistory(); // brings back downloads after a reinstall
    });
    _initFuture = _initEngine();
  }

  Future<void> _initEngine() async {
    try {
      await _svc.init();
      engineReady = true;
      engineVersion = await _svc.version();
    } catch (_) {
      engineFailed = true;
    }
    notifyListeners();
    if (engineReady) _autoUpdate();
  }

  Future<void> _silentEngineUpdate() async {
    try {
      await _svc.updateEngine(settings.engineChannel);
      engineVersion = await _svc.version();
      (await SharedPreferences.getInstance())
          .setInt('engine_last_update', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Keeps the downloader engine fresh (YouTube breaks often). At most every 12 hours.
  Future<void> _autoUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('engine_last_update') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < 12 * 3600 * 1000) return;
      await _svc.updateEngine(settings.engineChannel);
      engineVersion = await _svc.version();
      await prefs.setInt('engine_last_update', now);
      notifyListeners();
    } catch (_) {}
  }

  // ------------------------------------------------------------ link input
  void setUrl(String v) {
    if (urlController.text != v) urlController.text = v;
    onUrlChanged(v);
  }

  void onUrlChanged(String text) {
    errorKey = null;
    notifyListeners();
    _debounce?.cancel();
    final u = text.trim();
    if (!isValidUrl(u)) return;
    _debounce = Timer(const Duration(milliseconds: 500), () => _prefetch(u));
  }

  void clear() {
    _debounce?.cancel();
    urlController.clear();
    meta = null;
    errorKey = null;
    notifyListeners();
  }

  Future<VideoMeta> _load(String url) async {
    await _initFuture;
    if (engineFailed) throw Exception('engine');
    final m = await _svc.getInfo(url);
    _cache = m;
    _cacheUrl = url;
    return m;
  }

  Future<VideoMeta> _start(String url) {
    final f = _load(url);
    _inflight = f;
    _inflightUrl = url;
    f.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_inflight, f)) {
        _inflight = null;
        _inflightUrl = null;
      }
    });
    return f;
  }

  void _prefetch(String url) {
    if (_cacheUrl == url || _inflightUrl == url) return;
    _start(url).then<void>((_) {}, onError: (_) {});
  }

  Future<bool> analyze() async {
    final url = urlController.text.trim();
    if (!isValidUrl(url)) {
      errorKey = 'err_invalid_url';
      notifyListeners();
      return false;
    }
    analyzing = true;
    errorKey = null;
    meta = null;
    notifyListeners();
    try {
      VideoMeta m;
      try {
        if (_cacheUrl == url && _cache != null) {
          m = _cache!;
        } else if (_inflightUrl == url && _inflight != null) {
          m = await _inflight!;
        } else {
          m = await _start(url);
        }
      } catch (e) {
        // Blocked by the site: refresh the downloader engine silently and try once more.
        if (friendlyErrorKey(e.toString().replaceFirst('Exception: ', '')) ==
            'err_blocked') {
          await _silentEngineUpdate();
          m = await _start(url);
        } else {
          rethrow;
        }
      }
      meta = m;
      options = buildOptions(m);
      return true;
    } catch (e) {
      errorKey = engineFailed
          ? 'err_engine'
          : friendlyErrorKey(e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      analyzing = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------- folders
  /// '' = save straight into Download/0XDL
  String subFolderFor(VideoMeta m) {
    if (!settings.platformFolders) return '';
    return platformFolderName(
        m.domain.isNotEmpty ? m.domain : m.url, m.extractor);
  }

  String folderLabelFor(VideoMeta m) {
    final s = subFolderFor(m);
    return s.isEmpty ? '0XDL' : '0XDL/$s';
  }

  // ------------------------------------------------------------- downloads
  Future<void> start(DownloadRequest req) async {
    final m = meta;
    if (m == null) return;
    await PermissionService.requestAll();

    final item = DownloadItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: m.url,
      title: m.title,
      thumbnail: m.thumbnail,
      label: req.option.plainLabel,
    );
    items.insert(0, item);
    notifyListeners();

    final sub = subFolderFor(m);
    final dir = sub.isEmpty ? downloadDir : '$downloadDir/$sub';
    final strings = {
      'downloading': settings.t('n_downloading'),
      'processing': settings.t('n_processing'),
      'done': settings.t('n_done'),
      'failed': settings.t('n_failed'),
      'multi': settings.t('n_multi'),
    };

    try {
      item.path = await _svc.download(
        id: item.id,
        url: m.url,
        dir: dir,
        title: m.title,
        thumb: m.thumbnail,
        notify: settings.notifications,
        strings: strings,
        args: buildArgs(req),
      );
      item.status = DownloadStatus.done;
      await _addToHistory(item);
      items.remove(item);
      await SupportPrompt.onDownloadDone();
      doneCount++;
    } catch (e) {
      if (item.cancelRequested) {
        item.status = DownloadStatus.cancelled;
      } else {
        item.status = DownloadStatus.failed;
        item.errorKey =
            friendlyErrorKey(e.toString().replaceFirst('Exception: ', ''));
      }
    }
    item.speed = '';
    notifyListeners();
  }

  Future<void> _persist() => HistoryService.save(history);

  Future<void> _addToHistory(DownloadItem item) async {
    var size = 0;
    final path = item.path ?? '';
    try {
      if (path.isNotEmpty) size = await File(path).length();
    } catch (_) {}
    history.insert(
      0,
      HistoryEntry(
        id: item.id,
        url: item.url,
        title: item.title,
        thumbnail: item.thumbnail,
        label: item.label,
        path: path,
        size: size,
        date: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _persist();
  }

  void _onEvent(Map e) {
    final id = e['id'] as String?;
    final idx = items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final item = items[idx];
    final line = (e['line'] as String?) ?? '';
    var p = (e['progress'] as num?)?.toDouble() ?? -1;
    if (p < 0) {
      final m = RegExp(r'(\d{1,3}(?:\.\d+)?)%').firstMatch(line);
      if (m != null && line.contains('[download]')) p = double.parse(m.group(1)!);
    }
    if (p >= 0) item.progress = (p / 100).clamp(0.0, 1.0);
    item.eta = ((e['eta'] as num?) ?? 0).toInt();

    final sp = RegExp(r'at\s+([\d.]+\s?[KMG]?i?B/s)').firstMatch(line);
    if (sp != null) item.speed = sp.group(1)!;

    if (line.contains('[Merger]') ||
        line.contains('[ExtractAudio]') ||
        line.contains('[VideoRemuxer]') ||
        line.contains('[EmbedThumbnail]') ||
        line.contains('[EmbedSubtitle]')) {
      item.stage = DownloadStage.processing;
      item.speed = '';
    } else if (p >= 0 || line.contains('[download]')) {
      item.stage = DownloadStage.downloading;
    }
    notifyListeners();
  }

  void cancel(DownloadItem i) {
    i.cancelRequested = true;
    _svc.cancel(i.id);
  }

  void dismiss(DownloadItem i) {
    items.remove(i);
    notifyListeners();
  }

  /// Returns false only when a file delete was requested but the file was missing.
  Future<bool> removeHistory(HistoryEntry e, {required bool deleteFile}) async {
    var ok = true;
    if (deleteFile) {
      try {
        ok = await HistoryService.deleteFile(e.path);
      } catch (_) {
        ok = false;
      }
    }
    history.removeWhere((h) => h.id == e.id);
    if (!deleteFile && e.path.isNotEmpty) await HistoryService.addIgnored(e.path);
    await _persist();
    if (deleteFile && e.path.isNotEmpty) _svc.scan([e.path]);
    notifyListeners();
    return ok;
  }

  /// Rebuilds the list from the files in Download/0XDL
  /// (after a reinstall, or when files were copied back; the source link comes from the tag inside each file). Returns how many were added.
  Future<int> restoreHistory() async {
    if (_restoring) return 0;
    _restoring = true;
    try {
      final ignored = await HistoryService.ignored();
      final known = history.map((h) => h.path).toSet();
      final added = <HistoryEntry>[];

      for (final f in await HistoryService.scanFiles()) {
        if (known.contains(f.path) || ignored.contains(f.path)) continue;
        added.add(await _entryFromFile(f));
        known.add(f.path);
      }
      if (added.isEmpty) return 0;

      history.addAll(added);
      history.sort((a, b) => b.date.compareTo(a.date));
      await _persist();
      notifyListeners();

      // pictures for restored files (embedded cover or a video frame)
      for (final e in added) {
        if (e.thumbnail.isNotEmpty) continue;
        final t = await _svc.thumbnail(e.path);
        if (t.isEmpty) continue;
        final i = history.indexWhere((h) => h.id == e.id);
        if (i >= 0) {
          history[i] = history[i].copyWith(thumbnail: t);
          notifyListeners();
        }
      }
      await HistoryService.save(history);
      return added.length;
    } catch (_) {
      return 0;
    } finally {
      _restoring = false;
    }
  }

  Future<HistoryEntry> _entryFromFile(File f) async {
    final path = f.path;
    final slash = path.lastIndexOf('/');
    var name = path.substring(slash + 1);
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
    if (dot > 0) name = name.substring(0, dot);
    var label = '';
    final q = RegExp(r'\s*\[(\d{3,4})p\]\s*$').firstMatch(name);
    if (q != null) {
      label = '${q.group(1)}p';
      name = name.substring(0, q.start);
    }
    if (const {'mp3', 'm4a', 'opus', 'ogg', 'flac', 'wav', 'aac'}.contains(ext)) {
      label = ext.toUpperCase();
    }
    final st = await f.stat();
    final url = await MetaReader.sourceUrl(path);
    return HistoryEntry(
      id: 'r${st.modified.millisecondsSinceEpoch}_${st.size}',
      url: url,
      title: name.isEmpty ? path.substring(slash + 1) : name,
      thumbnail: '',
      label: label,
      path: path,
      size: st.size,
      date: st.modified.millisecondsSinceEpoch,
    );
  }

  /// Renames the file on disk and in the list. Returns 'ok' or a message key.
  Future<String> renameHistory(HistoryEntry e, String raw) async {
    final name = raw.trim().replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_');
    if (name.isEmpty) return 'rename_invalid';
    final f = File(e.path);
    if (e.path.isEmpty || !await f.exists()) return 'file_missing';
    final dot = e.path.lastIndexOf('.');
    final ext = dot > e.path.lastIndexOf('/') ? e.path.substring(dot) : '';
    final newPath = '${f.parent.path}/$name$ext';
    if (newPath == e.path) return 'ok';
    if (await File(newPath).exists()) return 'rename_exists';
    try {
      await f.rename(newPath);
    } catch (_) {
      return 'rename_failed';
    }
    final i = history.indexWhere((h) => h.id == e.id);
    if (i >= 0) history[i] = e.copyWith(title: name, path: newPath);
    await _persist();
    _svc.scan([e.path, newPath]);
    notifyListeners();
    return 'ok';
  }

  Future<bool> openFile(HistoryEntry e) async {
    if (e.path.isEmpty || !await File(e.path).exists()) return false;
    final r = await OpenFilex.open(e.path);
    return r.type == ResultType.done;
  }

  Future<String> updateEngine() async {
    updating = true;
    notifyListeners();
    try {
      final st = await _svc.updateEngine(settings.engineChannel);
      engineVersion = await _svc.version();
      (await SharedPreferences.getInstance())
          .setInt('engine_last_update', DateTime.now().millisecondsSinceEpoch);
      return st == 'DONE'
          ? settings.t('updated', [engineVersion])
          : settings.t('up_to_date', [engineVersion]);
    } catch (_) {
      return settings.t('update_failed');
    } finally {
      updating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    urlController.dispose();
    super.dispose();
  }
}
