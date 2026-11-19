import 'package:flutter/material.dart';

/// Real brand icons (telegram / facebook / github) as tintable images.
class BrandIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const BrandIcon(this.name, {super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) => Image.asset('assets/icon/brand_$name.png',
      width: size, height: size, color: color, colorBlendMode: BlendMode.srcIn);
}
