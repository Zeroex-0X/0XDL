import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/zeroex_logo.dart';
import 'main_shell.dart';

/// Logo, name and slogan in the centre, "From Zeroex" at the very bottom.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final fade = CurvedAnimation(parent: _ctl, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: fade,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1).animate(fade),
                        child: const AppLogo(size: 116),
                      ),
                      const SizedBox(height: 26),
                      Text('0XDL',
                          style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: c.primary)),
                      const SizedBox(height: 12),
                      Text(context.tr('splash_slogan'),
                          style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 1,
                              color: c.primary.withAlpha(0xCC))),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr('from_dev'),
                        style: TextStyle(
                            fontSize: 12, letterSpacing: 2, color: c.textDim)),
                    const SizedBox(height: 6),
                    const ZeroexMark(height: 26),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
