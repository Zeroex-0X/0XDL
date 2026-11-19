import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/links.dart';
import '../core/theme.dart';
import '../providers/update_provider.dart';
import 'app_logo.dart';
import 'brand_icon.dart';
import 'common.dart';
import 'zeroex_logo.dart';

// ------------------------------------------------------------------ About app
void showAboutApp(BuildContext context) {
  final c = AppPalette.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const AppLogo(size: 60),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('0XDL',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text(ctx.tr('version', [kAppVersion]),
                        style: TextStyle(color: c.textDim, fontSize: 13)),
                  ],
                ),
              ]),
              const SizedBox(height: 16),
              Text(ctx.tr('about_desc'), style: const TextStyle(height: 1.5)),
              const SizedBox(height: 14),
              for (final k in ['ab1', 'ab10', 'ab2', 'ab5', 'ab6', 'ab7', 'ab8', 'ab9', 'ab3', 'ab4'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.check_circle_rounded, size: 18, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(ctx.tr(k), style: const TextStyle(height: 1.3))),
                  ]),
                ),
              if (Links.aboutApp.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Links.open(Links.aboutApp),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(ctx.tr('view_project')),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(child: Text(Links.tagline, style: TextStyle(color: c.textDim, fontSize: 12))),
            ],
          ),
        ),
      ),
    ),
  );
}

// -------------------------------------------------------------- About developer
void showAboutDeveloper(BuildContext context) {
  final c = AppPalette.of(context);
  Widget link(IconData icon, Color color, String title, String sub, String url) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => Links.open(url),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: c.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (sub.isNotEmpty)
                    Text(sub, style: TextStyle(color: c.textDim, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textDim),
          ]),
        ),
      );

  Widget social(String brand, String url) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Links.open(url),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(child: BrandIcon(brand, size: 28, color: c.primary)),
          ),
        ),
      );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ZeroexMark(height: 34),
              const SizedBox(height: 6),
              Text(Links.tagline, style: TextStyle(color: c.textDim, fontSize: 12)),
              const SizedBox(height: 20),
              link(Icons.language_rounded, c.primary, ctx.tr('website'), '', Links.website),
              link(Icons.favorite_rounded, c.primary, ctx.tr('support_dev'),
                  ctx.tr('support_sub'), Links.support),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  social('telegram', Links.telegram),
                  social('facebook', Links.facebook),
                  social('github', Links.github),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ App update
void showUpdateSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    builder: (_) => const _UpdateSheet(),
  );
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet();
  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  String? _msg;

  String _size(int b) => b <= 0 ? '' : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final u = context.watch<UpdateProvider>();
    final i = u.info;
    if (i == null) return const SizedBox(height: 120);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const AppLogo(size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('up_new', [i.version]),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    if (_size(i.size).isNotEmpty)
                      Text(_size(i.size), style: TextStyle(color: c.textDim, fontSize: 12)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text(context.tr('whats_new').toUpperCase(),
                style: TextStyle(
                    fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w600, color: c.textDim)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
              child: SingleChildScrollView(
                child: Text(i.notes.isEmpty ? context.tr('up_no_notes') : i.notes,
                    style: const TextStyle(height: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            if (u.downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: u.progress > 0 ? u.progress : null,
                    minHeight: 8,
                    color: c.primary,
                    backgroundColor: c.bg),
              ),
              const SizedBox(height: 8),
              Text('${context.tr('up_downloading')} ${(u.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: c.textDim, fontSize: 13)),
            ] else ...[
              if (_msg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(context.tr(_msg!),
                      style: TextStyle(
                          fontSize: 13,
                          color: _msg == 'up_fail' ? Colors.redAccent : c.textDim)),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('later')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final m = await u.downloadAndInstall();
                      if (mounted) setState(() => _msg = m);
                    },
                    child: Text(context.tr('up_now')),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Start-up popup for a new version: update now / remind me later / skip this version.
Future<void> showUpdatePrompt(BuildContext context) async {
  final u = context.read<UpdateProvider>();
  final i = u.info;
  if (i == null) return;
  final choice = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final c = AppPalette.of(ctx);
      return AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 64)),
            const SizedBox(height: 14),
            Text(ctx.tr('update_available'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(ctx.tr('up_new', [i.version]),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
            if (i.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(i.notes,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textDim, fontSize: 13, height: 1.4)),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, 'update'),
              child: Text(ctx.tr('up_now')),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.primary, width: 1.3),
              ),
              onPressed: () => Navigator.pop(ctx, 'later'),
              child: Text(ctx.tr('upd_remind')),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, 'skip'),
              child: Text(ctx.tr('upd_skip'), style: TextStyle(color: c.textDim)),
            ),
          ),
        ],
      );
    },
  );
  if (choice == 'update') {
    if (context.mounted) showUpdateSheet(context);
  } else if (choice == 'skip') {
    await u.skipVersion();
  } else {
    await u.remindLater();
  }
}

/// Top card on the Settings page: logo, name, a prominent version and a status badge.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  Color _ink(BuildContext context, Color base) =>
      Theme.of(context).brightness == Brightness.dark
          ? base
          : HSLColor.fromColor(base).withLightness(0.32).toColor();

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final u = context.watch<UpdateProvider>();
    final available = u.status == UpdateStatus.available && u.info != null;
    const green = Color(0xFF2E9E5B);

    Widget? badge;
    switch (u.status) {
      case UpdateStatus.checking:
        badge = const SizedBox(
            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
        break;
      case UpdateStatus.latest:
        badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: green.withAlpha(0x26), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_rounded, size: 16, color: green),
            const SizedBox(width: 5),
            Text(context.tr('latest_badge'),
                style: const TextStyle(
                    color: green, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        );
        break;
      case UpdateStatus.available:
        badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: c.primary, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.system_update_alt_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text('${context.tr('new_badge')} v${u.info!.version}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        );
        break;
      case UpdateStatus.unknown:
        badge = null; // stay quiet when we cannot check
        break;
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: available ? () => showUpdateSheet(context) : null,
      child: Row(children: [
        const AppLogo(size: 68),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('0XDL',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: c.primarySoft, borderRadius: BorderRadius.circular(12)),
                    child: Text('v$kAppVersion',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink(context, c.primary))),
                  ),
                  if (badge != null) badge,
                ],
              ),
            ],
          ),
        ),
        if (available) Icon(Icons.chevron_right_rounded, color: c.textDim),
      ]),
    );
  }
}
