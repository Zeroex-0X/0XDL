import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Network picture, or a local file when the value is a path.
Widget thumbImage(String url, Widget placeholder, {double? w, double? h}) {
  if (url.startsWith('/')) {
    return Image.file(File(url),
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder);
  }
  return Image.network(url,
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder);
}

class VideoThumb extends StatelessWidget {
  final String url;
  final double w, h;
  const VideoThumb({super.key, required this.url, this.w = 88, this.h = 56});

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final ph = Container(
      width: w,
      height: h,
      color: c.bg,
      child: Icon(Icons.movie_rounded, color: c.textDim),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url.isEmpty ? ph : thumbImage(url, ph, w: w, h: h),
    );
  }
}
