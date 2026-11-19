import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/platform_util.dart';
import '../core/theme.dart';
import '../providers/download_provider.dart';
import '../widgets/common.dart';
import '../widgets/download_tile.dart';
import '../widgets/format_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String? _lastClip;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  /// Auto-paste a valid link from the clipboard (on launch / when the app comes back).
  Future<void> _checkClipboard() async {
    if (!mounted || !context.read<AppSettings>().autoPaste) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text == _lastClip || !isValidUrl(text)) return;
    _lastClip = text;
    if (mounted) context.read<DownloadProvider>().setUrl(text);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      context.read<DownloadProvider>().setUrl(data!.text!.trim());
    }
  }

  Future<void> _analyze() async {
    final p = context.read<DownloadProvider>();
    FocusScope.of(context).unfocus();
    if (!await p.analyze() || !mounted) return;
    final req = await showFormatSheet(
        context, p.meta!, p.options, p.folderLabelFor(p.meta!));
    if (req != null) p.start(req);
  }

  Widget _chip(AppPalette c, IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: c.card.withAlpha(0xCC), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: c.primary),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final p = context.watch<DownloadProvider>();
    final notReady = !p.engineReady && !p.engineFailed;
    final busy = p.analyzing || notReady;
    final hasText = p.urlController.text.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        // intro text box
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.primarySoft, c.primarySoft.withAlpha(0x12)],
            ),
            border: Border.all(color: c.border),
          ),
          child: Stack(children: [
            Positioned(right: -4, bottom: -4, child: _HeroArt(c)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('hero_title'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, height: 1.25)),
              const SizedBox(height: 8),
              Text(context.tr('supports_hint'),
                  style: TextStyle(color: c.textDim, fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip(c, Icons.hd_rounded, context.tr('chip_quality')),
                _chip(c, Icons.music_note_rounded, context.tr('chip_audio')),
                _chip(c, Icons.phone_android_rounded, context.tr('chip_local')),
              ]),
            ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // link paste box
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: TextField(
            controller: p.urlController,
            keyboardType: TextInputType.url,
            onChanged: p.onUrlChanged,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: context.tr('hint_link'),
              hintStyle: TextStyle(color: c.textDim, fontSize: 15),
              contentPadding: const EdgeInsets.symmetric(vertical: 17),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.link_rounded, color: c.textDim),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasText)
                    IconButton(
                        tooltip: context.tr('clear'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: p.clear),
                  IconButton(
                      tooltip: context.tr('paste'),
                      icon: Icon(Icons.content_paste_rounded, color: c.primary),
                      onPressed: _paste),
                ],
              ),
            ),
          ),
        ),
        if (p.errorKey != null || p.engineFailed) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.tr(p.engineFailed ? 'err_engine' : p.errorKey!),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          ]),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: (busy || p.engineFailed) ? null : _analyze,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            label: Text(notReady
                ? context.tr('preparing')
                : (p.analyzing ? context.tr('checking') : context.tr('download_btn'))),
          ),
        ),
        if (p.items.isNotEmpty) ...[
          SectionLabel(context.tr('in_progress')),
          for (final i in p.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DownloadTile(item: i),
            ),
        ],
      ],
    );
  }
}

/// Decorative media icons on the intro card that float and sway gently.
class _HeroArt extends StatefulWidget {
  final AppPalette c;
  const _HeroArt(this.c);
  @override
  State<_HeroArt> createState() => _HeroArtState();
}

class _HeroArtState extends State<_HeroArt> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Widget _tile(IconData icon, double size, Color bg, Color fg) => Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, color: fg, size: size * 0.56),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = _ctl.value * 2 * math.pi;

        Widget item({
          required double right,
          required double bottom,
          required double size,
          required IconData icon,
          required Color bg,
          required Color fg,
          required double angle,
          required double phase,
        }) {
          final dx = math.sin(t + phase) * 5;
          final dy = math.cos(t * 2 + phase) * 7;
          final turn = angle + math.sin(t + phase) * 0.08;
          final scale = 1 + math.sin(t * 2 + phase) * 0.05;
          return Positioned(
            right: right - dx,
            bottom: bottom - dy,
            child: Transform.rotate(
              angle: turn,
              child: Transform.scale(scale: scale, child: _tile(icon, size, bg, fg)),
            ),
          );
        }

        return SizedBox(
          width: 150,
          height: 112,
          child: Stack(clipBehavior: Clip.none, children: [
            item(
                right: 0,
                bottom: 0,
                size: 74,
                icon: Icons.play_arrow_rounded,
                bg: c.primary.withAlpha(0x40),
                fg: c.primary.withAlpha(0xB0),
                angle: 0.12,
                phase: 0),
            item(
                right: 78,
                bottom: 10,
                size: 50,
                icon: Icons.music_note_rounded,
                bg: c.accent2.withAlpha(0x40),
                fg: c.accent2.withAlpha(0xC0),
                angle: -0.16,
                phase: 2.1),
            item(
                right: 54,
                bottom: 64,
                size: 38,
                icon: Icons.download_rounded,
                bg: c.accent.withAlpha(0x3A),
                fg: c.accent.withAlpha(0xC0),
                angle: 0.2,
                phase: 4.2),
          ]),
        );
      },
    );
  }
}
