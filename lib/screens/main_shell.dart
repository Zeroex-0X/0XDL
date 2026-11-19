import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/download_provider.dart';
import '../providers/update_provider.dart';
import '../widgets/about_sheets.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/permission_service.dart';
import '../services/support_prompt.dart';
import '../services/prefs_service.dart';
import '../widgets/startup_dialogs.dart';
import 'downloads_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

/// Curved bottom bar: Downloads (left) | Home (round centre button) | Settings (right).
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 1; // 0 downloads, 1 home, 2 settings
  bool _busy = true; // start-up dialogs are running
  bool _dialogOpen = false;
  late final DownloadProvider _dl;
  int _lastDone = 0;

  @override
  void initState() {
    super.initState();
    _dl = context.read<DownloadProvider>();
    _lastDone = _dl.doneCount;
    _dl.addListener(_onDownloads);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  @override
  void dispose() {
    _dl.removeListener(_onDownloads);
    super.dispose();
  }

  bool get _onTop => mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  Future<void> _startup() async {
    try {
      // 1) welcome + required permissions (asked on every launch until granted)
      if (!await PermissionService.hasRequired() && mounted) {
        await showPermissionDialog(context);
        // storage access is granted now: bring back downloads from before a reinstall
        if (mounted) context.read<DownloadProvider>().restoreHistory();
      }
      // 2) Telegram invitation (can be hidden for good)
      if (mounted && !await PrefsService.hideTelegram()) {
        await showTelegramDialog(context);
      }
      // 3) new app version: update now / remind me later / skip
      if (!mounted) return;
      final u = context.read<UpdateProvider>();
      await u.ready;
      if (mounted && u.shouldPrompt) await showUpdatePrompt(context);
    } finally {
      _busy = false;
    }
    // 4) support request, only when it is due (finished downloads) and nothing else was shown
    if (mounted) _maybeSupport(delay: const Duration(seconds: 4));
  }

  /// A download just finished: maybe ask for support (a happy moment).
  void _onDownloads() {
    if (_dl.doneCount == _lastDone) return;
    _lastDone = _dl.doneCount;
    _maybeSupport(delay: const Duration(seconds: 2));
  }

  Future<void> _maybeSupport({required Duration delay}) async {
    if (!_onTop || _busy || _dialogOpen) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    if (!await SupportPrompt.due()) return;
    _dialogOpen = true;
    try {
      await Future.delayed(delay);
      if (_onTop && _dl.items.isEmpty) await showSupportDialog(context);
    } finally {
      _dialogOpen = false;
    }
  }

  Widget _navItem(AppPalette c, IconData icon, String label, int i) {
    final selected = _index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? c.primary : c.textDim),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? c.primary : c.textDim)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, AppPalette c) {
    final s = Provider.of<AppSettings>(context);
    final brightness = Theme.of(context).brightness;
    final toggle = IconButton(
      tooltip: brightness == Brightness.dark
          ? context.tr('theme_to_day')
          : context.tr('theme_to_night'),
      icon: Icon(brightness == Brightness.dark
          ? Icons.light_mode_rounded
          : Icons.dark_mode_rounded),
      onPressed: () => s.toggleTheme(brightness),
    );
    if (_index == 1) {
      return AppBar(
        centerTitle: false,
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Row(children: [
          Image.asset('assets/icon/app_icon.png', width: 46, height: 46),
          const SizedBox(width: 10),
          const Text('0XDL',
              style: TextStyle(
                  fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ]),
        actions: [toggle, const SizedBox(width: 6)],
      );
    }
    return AppBar(
      title: Text(_index == 0 ? context.tr('nav_downloads') : context.tr('set_title'),
          style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Scaffold(
      appBar: _appBar(context, c),
      body: IndexedStack(
        index: _index,
        children: const [DownloadsPage(), HomePage(), SettingsPage()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _index = 1),
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_link_rounded, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          children: [
            _navItem(c, Icons.download_done_rounded, context.tr('nav_downloads'), 0),
            const SizedBox(width: 76),
            _navItem(c, Icons.settings_rounded, context.tr('nav_settings'), 2),
          ],
        ),
      ),
    );
  }
}
