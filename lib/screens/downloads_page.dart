import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../providers/download_provider.dart';
import '../widgets/common.dart';
import '../widgets/download_tile.dart';
import '../widgets/history_card.dart';

/// Running downloads on top, finished downloads below (All / Video / Audio, list or grid).
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  int _filter = 0; // 0 all, 1 video, 2 audio
  bool _scanning = false;

  Future<void> _restore() async {
    final p = context.read<DownloadProvider>();
    final done = context.trr('restore_done');
    final none = context.trr('restore_none');
    setState(() => _scanning = true);
    final n = await p.restoreHistory();
    if (!mounted) return;
    setState(() => _scanning = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n > 0 ? done.replaceFirst('%s', '$n') : none)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final p = context.watch<DownloadProvider>();
    final s = Provider.of<AppSettings>(context);

    if (p.items.isEmpty && p.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_for_offline_rounded, size: 56, color: c.textDim),
            const SizedBox(height: 10),
            Text(context.tr('history_empty'), style: TextStyle(color: c.textDim)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(context.tr('restore_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textDim, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: _scanning ? null : _restore,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search_rounded),
              label: Text(context.tr('restore_btn')),
            ),
          ],
        ),
      );
    }

    final list = p.history.where((e) {
      if (_filter == 1) return !e.isAudio;
      if (_filter == 2) return e.isAudio;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _restore,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        if (p.items.isNotEmpty) ...[
          SectionLabel(context.tr('in_progress')),
          for (final i in p.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DownloadTile(item: i),
            ),
        ],
        if (p.history.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(context.tr('filter_all'))),
                  ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.videocam_rounded, size: 18),
                      label: Text(context.tr('filter_video'))),
                  ButtonSegment(
                      value: 2,
                      icon: const Icon(Icons.music_note_rounded, size: 18),
                      label: Text(context.tr('filter_audio'))),
                ],
                selected: {_filter},
                onSelectionChanged: (v) => setState(() => _filter = v.first),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: s.gridView ? context.tr('view_list') : context.tr('view_grid'),
              icon: Icon(s.gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
              onPressed: () => s.setGridView(!s.gridView),
            ),
          ]),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(children: [
                Icon(_filter == 2 ? Icons.music_off_rounded : Icons.videocam_off_rounded,
                    size: 44, color: c.textDim),
                const SizedBox(height: 8),
                Text(context.tr(_filter == 2 ? 'empty_audio' : 'empty_video'),
                    style: TextStyle(color: c.textDim)),
              ]),
            )
          else if (s.gridView)
            LayoutBuilder(builder: (ctx, cons) {
              // card height follows its content, so there is no empty space at the bottom
              const gap = 8.0;
              final w = (cons.maxWidth - gap) / 2;
              final h = w / 1.6 + 92;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: w / h,
                ),
                itemBuilder: (_, i) => HistoryGridCard(list[i]),
              );
            })
          else
            for (final e in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HistoryListCard(e),
              ),
        ],
      ],
    ),
    );
  }
}