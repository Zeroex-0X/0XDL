import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/platform_util.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/option_builder.dart';
import 'thumb.dart';

Future<DownloadRequest?> showFormatSheet(BuildContext context, VideoMeta meta,
    List<MediaOption> options, String folderLabel) {
  return showModalBottomSheet<DownloadRequest>(
    context: context,
    isScrollControlled: true,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
    builder: (_) =>
        _FormatSheet(meta: meta, options: options, folderLabel: folderLabel),
  );
}

class _FormatSheet extends StatefulWidget {
  final VideoMeta meta;
  final List<MediaOption> options;
  final String folderLabel;
  const _FormatSheet(
      {required this.meta, required this.options, required this.folderLabel});
  @override
  State<_FormatSheet> createState() => _FormatSheetState();
}

class _FormatSheetState extends State<_FormatSheet> {
  MediaKind _tab = MediaKind.video;
  bool _subs = false;
  bool _thumb = true;
  bool _fast = false;
  String _container = 'mp4';

  String _dur(int s) {
    if (s <= 0) return '';
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  String _title(MediaOption o) {
    if (o.isBest) return context.tr('best_quality');
    if (o.kind == MediaKind.audio) return o.audioFormat!.toUpperCase();
    return o.label;
  }

  String _note(MediaOption o) {
    if (o.isBest) return context.tr('best_note');
    if (o.kind == MediaKind.audio) {
      return context.tr('a_${o.audioFormat}');
    }
    return context.tr(qualityNoteKey(o.tier ?? o.height ?? 0));
  }

  Widget _switch(AppPalette c, String title, String sub, bool v,
          ValueChanged<bool> onChanged) =>
      SwitchListTile(
        value: v,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(sub, style: TextStyle(color: c.textDim, fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final meta = widget.meta;
    final list = widget.options.where((o) => o.kind == _tab).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: ListView(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: c.textDim, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              VideoThumb(url: meta.thumbnail, w: 96, h: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        [meta.uploader, _dur(meta.duration)]
                            .where((e) => e.isNotEmpty)
                            .join(' · '),
                        style: TextStyle(color: c.textDim, fontSize: 12)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(context.tr('saving_to', [widget.folderLabel]),
                style: TextStyle(color: c.textDim, fontSize: 11)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<MediaKind>(
                segments: [
                  ButtonSegment(
                      value: MediaKind.video,
                      icon: const Icon(Icons.videocam_rounded),
                      label: Text(context.tr('video'))),
                  ButtonSegment(
                      value: MediaKind.audio,
                      icon: const Icon(Icons.music_note_rounded),
                      label: Text(context.tr('audio'))),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            const SizedBox(height: 12),
            for (final o in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => Navigator.pop(
                    context,
                    DownloadRequest(
                        option: o,
                        subtitles: _subs,
                        embedThumb: _thumb,
                        fastMode: _fast,
                        container: _container),
                  ),
                  tileColor: c.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  leading: Icon(
                      o.kind == MediaKind.audio
                          ? Icons.music_note_rounded
                          : Icons.videocam_rounded,
                      color: o.kind == MediaKind.audio ? c.accent2 : c.accent),
                  title: Text(_title(o),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_note(o),
                      style: TextStyle(color: c.textDim, fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (o.size != null)
                        Text('≈ ${formatBytes(o.size!)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: c.primary)),
                      Icon(Icons.download_rounded, size: 18, color: c.textDim),
                    ],
                  ),
                ),
              ),
            // Technical choices are tucked away and explained in plain words
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(context.tr('advanced'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                children: [
                  if (_tab == MediaKind.video) ...[
                    _switch(c, context.tr('adv_subs'), context.tr('adv_subs_sub'),
                        _subs, (v) => setState(() => _subs = v)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('adv_format'),
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'mp4', label: Text('MP4')),
                              ButtonSegment(value: 'mkv', label: Text('MKV')),
                            ],
                            selected: {_container},
                            onSelectionChanged: (v) =>
                                setState(() => _container = v.first),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              context.tr(_container == 'mp4'
                                  ? 'adv_mp4_sub'
                                  : 'adv_mkv_sub'),
                              style: TextStyle(color: c.textDim, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  _switch(c, context.tr('adv_thumb'), context.tr('adv_thumb_sub'),
                      _thumb, (v) => setState(() => _thumb = v)),
                  _switch(c, context.tr('adv_fast'), context.tr('adv_fast_sub'),
                      _fast, (v) => setState(() => _fast = v)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
