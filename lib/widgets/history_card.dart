import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/l10n.dart';
import '../core/links.dart';
import '../core/platform_util.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/download_provider.dart';
import '../screens/player_page.dart';
import 'common.dart';
import 'delete_dialog.dart';
import 'rename_dialog.dart';
import 'thumb.dart';

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String t(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${t(d.month)}-${t(d.day)} ${t(d.hour)}:${t(d.minute)}';
}

bool _missing(HistoryEntry e) => e.path.isEmpty || !File(e.path).existsSync();

void _snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Color _ink(BuildContext context, Color base) =>
    Theme.of(context).brightness == Brightness.dark
        ? base
        : HSLColor.fromColor(base).withLightness(0.32).toColor();

// ---------------------------------------------------------------- actions
void _play(BuildContext context, HistoryEntry e) {
  if (_missing(e)) {
    _snack(context, context.trr('file_missing'));
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(entry: e)));
}

Future<void> _onMenu(BuildContext context, String action, HistoryEntry e) async {
  final p = context.read<DownloadProvider>();
  switch (action) {
    case 'open_with':
      if (!await p.openFile(e) && context.mounted) {
        _snack(context, context.trr('open_failed'));
      }
      break;
    case 'details':
      _showDetails(context, e);
      break;
    case 'rename':
      final name = await showRenameDialog(context, e);
      if (name == null) return;
      final r = await p.renameHistory(e, name);
      if (context.mounted) _snack(context, context.trr(r == 'ok' ? 'rename_done' : r));
      break;
    case 'share':
      try {
        await Share.shareXFiles([XFile(e.path)], text: e.title);
      } catch (_) {
        if (context.mounted) _snack(context, context.trr('share_failed'));
      }
      break;
    case 'source':
      Links.open(e.url);
      break;
    case 'delete':
      final also = await showDeleteDialog(context);
      if (also == null) return;
      final ok = await p.removeHistory(e, deleteFile: also);
      if (!ok && context.mounted) _snack(context, context.trr('file_missing'));
      break;
  }
}

void _showDetails(BuildContext context, HistoryEntry e) {
  final c = AppPalette.of(context);
  Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(k, style: TextStyle(color: c.textDim, fontSize: 13))),
          Expanded(child: SelectableText(v, style: const TextStyle(fontSize: 13))),
        ]),
      );
  final platform = e.url.isEmpty ? '' : platformFolderName(e.url, '');
  final slash = e.path.lastIndexOf('/');
  final folder = slash > 0 ? e.path.substring(0, slash) : '';
  final fileName = slash >= 0 ? e.path.substring(slash + 1) : '';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                VideoThumb(url: e.thumbnail, w: 96, h: 60),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ]),
              const SizedBox(height: 10),
              if (fileName.isNotEmpty) row(ctx.tr('d_file'), fileName),
              row(ctx.tr('d_quality'), e.label.isEmpty ? ctx.tr('best_quality') : e.label),
              if (e.size > 0) row(ctx.tr('d_size'), formatBytes(e.size)),
              row(ctx.tr('d_date'), _date(e.date)),
              if (platform.isNotEmpty) row(ctx.tr('d_platform'), platform),
              if (folder.isNotEmpty) row(ctx.tr('d_saved_to'), folder),
              if (e.url.isNotEmpty) row(ctx.tr('d_source'), e.url),
            ],
          ),
        ),
      ),
    ),
  );
}

PopupMenuButton<String> _menu(BuildContext context, HistoryEntry e, {Color? iconColor}) {
  final c = AppPalette.of(context);
  PopupMenuItem<String> item(String v, IconData i, String t) => PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(i, size: 20, color: c.textDim),
          const SizedBox(width: 12),
          Flexible(child: Text(t)),
        ]),
      );
  return PopupMenuButton<String>(
    icon: Icon(Icons.more_vert_rounded, color: iconColor),
    color: c.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    onSelected: (a) => _onMenu(context, a, e),
    itemBuilder: (ctx) => [
      item('details', Icons.info_outline_rounded, ctx.tr('menu_details')),
      item('rename', Icons.drive_file_rename_outline_rounded, ctx.tr('menu_rename')),
      item('share', Icons.share_rounded, ctx.tr('menu_share')),
      item('open_with', Icons.open_in_new_rounded, ctx.tr('menu_open_with')),
      if (e.url.isNotEmpty) item('source', Icons.link_rounded, ctx.tr('menu_source')),
      item('delete', Icons.delete_outline_rounded, ctx.tr('delete')),
    ],
  );
}

// ------------------------------------------------------------ small pieces
/// Quality label, highlighted: filled for Full HD and above, soft for the rest.
class QualityPill extends StatelessWidget {
  final HistoryEntry e;
  const QualityPill(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final label = e.label.isEmpty ? context.tr('q_best_short') : e.label;
    var bg = c.primarySoft;
    var fg = _ink(context, c.primary);
    if (e.isAudio) {
      bg = c.accent2.withAlpha(0x38);
      fg = _ink(context, c.accent2);
    } else {
      final m = RegExp(r'(\d{3,4})p').firstMatch(label);
      final h = m == null ? 0 : int.parse(m.group(1)!);
      if (h >= 1080) {
        bg = c.primary;
        fg = Colors.white;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _MissingPill extends StatelessWidget {
  const _MissingPill();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(0x28),
            borderRadius: BorderRadius.circular(8)),
        child: Text(context.tr('file_missing'),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent)),
      );
}

/// File type badge on the thumbnail: icon + extension (MP4, MP3 ...).
class _TypeBadge extends StatelessWidget {
  final HistoryEntry e;
  const _TypeBadge(this.e);
  @override
  Widget build(BuildContext context) {
    final ext = e.ext.isEmpty ? (e.isAudio ? 'AUDIO' : 'VIDEO') : e.ext.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xB3000000), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(e.isAudio ? Icons.music_note_rounded : Icons.videocam_rounded,
            size: 11, color: Colors.white),
        const SizedBox(width: 3),
        Text(ext,
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    );
  }
}

Widget _playOverlay(HistoryEntry e, double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0x73000000), shape: BoxShape.circle),
      child: Icon(e.isAudio ? Icons.headphones_rounded : Icons.play_arrow_rounded,
          size: size * 0.66, color: Colors.white),
    );

Widget _metaRow(BuildContext context, HistoryEntry e, bool missing) {
  final c = AppPalette.of(context);
  return Row(children: [
    missing ? const _MissingPill() : QualityPill(e),
    if (!missing && e.size > 0) ...[
      const SizedBox(width: 8),
      Text(formatBytes(e.size), style: TextStyle(color: c.textDim, fontSize: 12)),
    ],
  ]);
}

// -------------------------------------------------------------- list layout
class HistoryListCard extends StatelessWidget {
  final HistoryEntry e;
  const HistoryListCard(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final missing = _missing(e);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
      onTap: () => _play(context, e),
      child: Opacity(
        opacity: missing ? 0.6 : 1,
        child: Row(children: [
          SizedBox(
            width: 92,
            height: 60,
            child: Stack(fit: StackFit.expand, children: [
              VideoThumb(url: e.thumbnail, w: 92, h: 60),
              Center(child: _playOverlay(e, 28)),
              Positioned(left: 4, bottom: 4, child: _TypeBadge(e)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                _metaRow(context, e, missing),
                const SizedBox(height: 4),
                Text(_date(e.date), style: TextStyle(color: c.textDim, fontSize: 11)),
              ],
            ),
          ),
          _menu(context, e),
        ]),
      ),
    );
  }
}

// -------------------------------------------------------------- grid layout
class HistoryGridCard extends StatelessWidget {
  final HistoryEntry e;
  const HistoryGridCard(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final missing = _missing(e);
    final ph = Container(
        color: c.bg, child: Icon(Icons.movie_rounded, color: c.textDim));
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => _play(context, e),
      child: Opacity(
        opacity: missing ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(fit: StackFit.expand, children: [
                  e.thumbnail.isEmpty
                      ? ph
                      : thumbImage(e.thumbnail, ph),
                  Center(child: _playOverlay(e, 40)),
                  Positioned(left: 6, bottom: 6, child: _TypeBadge(e)),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: Color(0x80000000), shape: BoxShape.circle),
                      child: _menu(context, e, iconColor: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    _metaRow(context, e, missing),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
