import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/links.dart';
import '../core/theme.dart';
import '../services/permission_service.dart';
import '../services/prefs_service.dart';
import 'app_logo.dart';
import 'brand_icon.dart';
import 'zeroex_logo.dart';
import '../services/support_prompt.dart';

/// 1) Welcome + required permissions. No "don't show again": it appears on every launch
///    until the permissions are granted.
Future<void> showPermissionDialog(BuildContext context) => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PermissionDialog(),
    );

class _PermissionDialog extends StatelessWidget {
  const _PermissionDialog();

  Widget _row(BuildContext context, IconData icon, String title, String sub) {
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
          child: Icon(icon, color: c.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(sub, style: TextStyle(color: c.textDim, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: AppLogo(size: 64)),
          const SizedBox(height: 12),
          Center(
            child: Text(context.tr('perm_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(context.tr('welcome_tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.primary, fontWeight: FontWeight.w600, height: 1.3)),
          ),
          const SizedBox(height: 14),
          Text(context.tr('perm_body'),
              style: TextStyle(color: c.textDim, height: 1.4)),
          _row(context, Icons.folder_rounded, context.tr('perm_storage'),
              context.tr('perm_storage_sub')),
          _row(context, Icons.notifications_rounded, context.tr('perm_notif'),
              context.tr('perm_notif_sub')),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              await PermissionService.requestAll();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(context.tr('perm_btn')),
          ),
        ),
      ],
    );
  }
}

/// 2) Telegram invitation, shown after the permission step. Has a "don't show again" switch.
Future<void> showTelegramDialog(BuildContext context) => showDialog(
      context: context,
      builder: (_) => const _TelegramDialog(),
    );

class _TelegramDialog extends StatefulWidget {
  const _TelegramDialog();
  @override
  State<_TelegramDialog> createState() => _TelegramDialogState();
}

class _TelegramDialogState extends State<_TelegramDialog> {
  bool _dontShow = false;

  Future<void> _close() async {
    if (_dontShow) await PrefsService.setHideTelegram(true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
            child: Center(child: BrandIcon('telegram', size: 40, color: c.primary)),
          ),
          const SizedBox(height: 16),
          Text(context.tr('tg_title'),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(context.tr('tg_body'),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textDim, height: 1.4)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Expanded(
                child: Text(context.tr('dont_show'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Switch(value: _dontShow, onChanged: (v) => setState(() => _dontShow = v)),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.primary, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _close,
                child: Text(context.tr('close')),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Links.open(Links.telegram);
                  _close();
                },
                icon: const Icon(Icons.north_east_rounded, size: 18),
                label: Text(context.tr('tg_join')),
              ),
            ),
          ),
        ]),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

/// 3) Friendly support request (see SupportPrompt for how rarely it appears).
Future<void> showSupportDialog(BuildContext context) async {
  final support = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = AppPalette.of(ctx);
      return AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const ZeroexMark(height: 40),
            ),
            const SizedBox(height: 18),
            Text(ctx.tr('sp_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(ctx.tr('sp_body'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textDim, height: 1.45)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.primary, width: 1.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(ctx.tr('sp_later')),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.favorite_rounded, size: 18),
                    label: Text(ctx.tr('sp_support')),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 22),
          ],
        ),
      );
    },
  );
  if (support == true) {
    await SupportPrompt.supported();
    Links.open(Links.support);
  } else {
    await SupportPrompt.later();
  }
}
