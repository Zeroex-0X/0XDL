import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/download_provider.dart';
import 'common.dart';
import 'thumb.dart';

/// Tile for a download that is running (or failed / cancelled).
class DownloadTile extends StatelessWidget {
  final DownloadItem item;
  const DownloadTile({super.key, required this.item});

  String _eta(BuildContext c, int s) {
    if (s <= 0) return '';
    final t = s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '${s}s';
    return c.tr('left', [t]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final p = context.read<DownloadProvider>();
    final active = item.status == DownloadStatus.downloading;
    final processing = item.stage == DownloadStage.processing;
    final pct = (item.progress * 100).clamp(0, 100).toStringAsFixed(0);

    String status;
    switch (item.status) {
      case DownloadStatus.downloading:
        if (processing) {
          status = context.tr('processing');
        } else if (item.progress <= 0) {
          status = context.tr('starting');
        } else {
          status = [
            '$pct%',
            if (item.speed.isNotEmpty) item.speed,
            _eta(context, item.eta),
          ].where((e) => e.isNotEmpty).join(' · ');
        }
        break;
      case DownloadStatus.done:
        status = context.tr('completed');
        break;
      case DownloadStatus.failed:
        status = item.errorKey != null
            ? context.tr(item.errorKey!)
            : context.tr('failed');
        break;
      case DownloadStatus.cancelled:
        status = context.tr('cancelled');
        break;
    }
    final label = item.label.isEmpty ? context.tr('best_quality') : item.label;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoThumb(url: item.thumbnail),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: c.textDim, fontSize: 11)),
                const SizedBox(height: 8),
                if (active)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (!processing && item.progress > 0)
                          ? item.progress
                          : null,
                      minHeight: 7,
                      color: c.primary,
                      backgroundColor: c.bg,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(children: [
                  if (active && !processing && item.progress > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('$pct%',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.primary)),
                    ),
                  Expanded(
                    child: Text(
                        (active && !processing && item.progress > 0)
                            ? status.replaceFirst('$pct% · ', '').replaceFirst('$pct%', '')
                            : status,
                        style: TextStyle(
                            fontSize: 12,
                            color: item.status == DownloadStatus.failed
                                ? Colors.redAccent
                                : c.textDim)),
                  ),
                ]),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip:
                active ? context.tr('cancel_download') : context.tr('dismiss'),
            icon: Icon(active ? Icons.close_rounded : Icons.check_rounded),
            onPressed: () => active ? p.cancel(item) : p.dismiss(item),
          ),
        ],
      ),
    );
  }
}
