import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../providers/update_provider.dart';
import '../widgets/about_sheets.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _icon(AppPalette c, IconData icon) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: c.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: c.primary, size: 20),
      );

  Widget _row(BuildContext context,
      {required IconData icon,
      required String title,
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap}) {
    final c = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          _icon(c, icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(color: c.textDim, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }

  Widget _group(BuildContext context, List<Widget> children) {
    final c = AppPalette.of(context);
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(Divider(height: 1, indent: 68, endIndent: 14, color: c.border));
      }
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: out),
    );
  }

  void _pickLanguage(BuildContext context) {
    final s = context.read<AppSettings>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          for (final e in kLanguages)
            ListTile(
              title: Text(e.$2),
              trailing: s.lang == e.$1
                  ? Icon(Icons.check_rounded, color: AppPalette.of(ctx).primary)
                  : null,
              onTap: () {
                s.setLang(e.$1);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }

  Future<void> _toggleNotifications(BuildContext context, bool v) async {
    final s = context.read<AppSettings>();
    final u = context.read<UpdateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final msg = context.trr('notif_blocked');
    if (v) {
      var st = await Permission.notification.status;
      if (!st.isGranted) st = await Permission.notification.request();
      if (!st.isGranted) {
        messenger.showSnackBar(SnackBar(content: Text(msg)));
        await openAppSettings();
        return;
      }
    }
    await s.setNotifications(v);
    await u.applySchedule();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final s = Provider.of<AppSettings>(context);

    final modeNames = {
      'system': context.tr('mode_system'),
      'light': context.tr('mode_light'),
      'dark': context.tr('mode_dark'),
    };

    final themeTile = Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: _icon(c, Icons.palette_rounded),
        title: Text(context.tr('themes'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(modeNames[s.themeMode] ?? '',
            style: TextStyle(color: c.textDim, fontSize: 12)),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('theme_mode'),
              style: TextStyle(color: c.textDim, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: 'system',
                    icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                    label: Text(modeNames['system']!)),
                ButtonSegment(
                    value: 'light',
                    icon: const Icon(Icons.light_mode_rounded, size: 18),
                    label: Text(modeNames['light']!)),
                ButtonSegment(
                    value: 'dark',
                    icon: const Icon(Icons.dark_mode_rounded, size: 18),
                    label: Text(modeNames['dark']!)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
          ),
          const SizedBox(height: 16),
          Text(context.tr('theme_color'),
              style: TextStyle(color: c.textDim, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 12, children: [
            for (var i = 0; i < kAccentHues.length; i++)
              GestureDetector(
                onTap: () => s.setAccent(i),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppPalette.generate(kAccentHues[i], Brightness.dark).primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: s.accent == i ? c.textDim : Colors.transparent,
                        width: 3),
                  ),
                  child: s.accent == i
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : null,
                ),
              ),
          ]),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const UpdateCard(),
        const SizedBox(height: 16),
        _group(context, [
          _row(
            context,
            icon: Icons.translate_rounded,
            title: context.tr('app_language'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(kLanguages.firstWhere((l) => l.$1 == s.lang, orElse: () => kLanguages.first).$2,
                  style: TextStyle(color: c.textDim)),
              Icon(Icons.chevron_right_rounded, color: c.textDim),
            ]),
            onTap: () => _pickLanguage(context),
          ),
          themeTile,
          _row(
            context,
            icon: Icons.folder_copy_rounded,
            title: context.tr('platform_folders'),
            subtitle: context.tr('platform_folders_sub'),
            trailing: Switch(
                value: s.platformFolders, onChanged: s.setPlatformFolders),
            onTap: () => s.setPlatformFolders(!s.platformFolders),
          ),
          _row(
            context,
            icon: Icons.content_paste_go_rounded,
            title: context.tr('auto_paste'),
            subtitle: context.tr('auto_paste_sub'),
            trailing: Switch(value: s.autoPaste, onChanged: s.setAutoPaste),
            onTap: () => s.setAutoPaste(!s.autoPaste),
          ),
          _row(
            context,
            icon: Icons.notifications_rounded,
            title: context.tr('notifications'),
            subtitle: context.tr('notifications_sub'),
            trailing: Switch(
                value: s.notifications,
                onChanged: (v) => _toggleNotifications(context, v)),
            onTap: () => _toggleNotifications(context, !s.notifications),
          ),
        ]),
        const SizedBox(height: 16),
        _group(context, [
          _row(
            context,
            icon: Icons.info_outline_rounded,
            title: context.tr('about_app'),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textDim),
            onTap: () => showAboutApp(context),
          ),
          _row(
            context,
            icon: Icons.code_rounded,
            title: context.tr('about_dev'),
            trailing: Icon(Icons.chevron_right_rounded, color: c.textDim),
            onTap: () => showAboutDeveloper(context),
          ),
        ]),
      ],
    );
  }
}
