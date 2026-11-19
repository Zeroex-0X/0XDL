import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'providers/download_provider.dart';
import 'providers/update_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(
            lazy: false, create: (_) => DownloadProvider(settings)),
        ChangeNotifierProvider(
            lazy: false, create: (_) => UpdateProvider(settings)),
      ],
      child: const OxdlApp(),
    ),
  );
}

class OxdlApp extends StatelessWidget {
  const OxdlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Provider.of<AppSettings>(context);
    return MaterialApp(
      title: '0XDL',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, s.accent),
      darkTheme: buildTheme(Brightness.dark, s.accent),
      themeMode: s.mode,
      builder: (context, child) {
        final sysDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final dark = s.themeMode == 'dark' || (s.themeMode == 'system' && sysDark);
        final p = AppPalette.generate(kAccentHues[s.accent.clamp(0, kAccentHues.length - 1)],
            dark ? Brightness.dark : Brightness.light);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: p.card,
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
        ));
        return Directionality(
          textDirection: s.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
