import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/icon/app_icon.png', width: size, height: size);
}
