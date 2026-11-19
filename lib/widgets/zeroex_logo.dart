import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Zeroex mark (a tintable image) with the "Zeroex" wordmark next to it.
class ZeroexMark extends StatelessWidget {
  final double height;
  final Color? color;
  final bool withName;
  const ZeroexMark({super.key, this.height = 22, this.color, this.withName = true});

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final tint = color ?? c.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icon/zeroex_logo.png',
            height: height, color: tint, colorBlendMode: BlendMode.srcIn),
        if (withName) ...[
          SizedBox(width: height * 0.35),
          Text('Zeroex',
              style: TextStyle(
                  fontSize: height * 0.8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: tint)),
        ],
      ],
    );
  }
}
