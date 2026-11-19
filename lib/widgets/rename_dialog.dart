import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Asks for a new file name (without the extension). Returns null when cancelled.
Future<String?> showRenameDialog(BuildContext context, HistoryEntry e) {
  final slash = e.path.lastIndexOf('/');
  var base = slash >= 0 ? e.path.substring(slash + 1) : e.title;
  final dot = base.lastIndexOf('.');
  if (dot > 0) base = base.substring(0, dot);
  if (base.isEmpty) base = e.title;
  final ctl = TextEditingController(text: base);
  ctl.selection = TextSelection(baseOffset: 0, extentOffset: base.length);
  final ext = e.ext.isEmpty ? '' : '.${e.ext}';

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final c = AppPalette.of(ctx);
      return AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(ctx.tr('rename_title')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            labelText: ctx.tr('rename_hint'),
            suffixText: ext,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: Text(ctx.tr('rename_save'))),
        ],
      );
    },
  );
}
