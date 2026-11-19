import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';

/// Returns null if cancelled, otherwise whether the original file should be deleted too.
Future<bool?> showDeleteDialog(BuildContext context) {
  var alsoFile = false;
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = AppPalette.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(ctx.tr('delete_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('delete_body'), style: TextStyle(color: c.textDim)),
              CheckboxListTile(
                value: alsoFile,
                onChanged: (v) => setState(() => alsoFile = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(ctx.tr('delete_also_file'),
                    style: const TextStyle(fontSize: 14)),
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.tr('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, alsoFile),
                child: Text(ctx.tr('delete'))),
          ],
        ),
      );
    },
  );
}
