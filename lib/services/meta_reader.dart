import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/platform_util.dart';

/// Reads the source link that the downloader stored inside a media file
/// (the "comment" tag: MP4/M4A, MP3, Opus, MKV). Used to rebuild the list after a reinstall.
class MetaReader {
  static const _win = 600 * 1024;

  static Future<String> sourceUrl(String path) async {
    try {
      final f = File(path);
      final len = await f.length();
      final raf = await f.open();
      try {
        final head = await raf.read(len < _win ? len : _win);
        var tail = Uint8List(0);
        if (len > _win) {
          await raf.setPosition(len - _win);
          tail = await raf.read(_win);
        }
        for (final buf in [tail, head]) {
          if (buf.isEmpty) continue;
          final u = _fromBuffer(buf);
          if (u.isNotEmpty) return u;
        }
      } finally {
        await raf.close();
      }
    } catch (_) {}
    return '';
  }

  static String _fromBuffer(Uint8List b) {
    // MP4 / M4A: "(c)cmt" atom -> size, 'data', flags, locale, text
    final i = _indexOf(b, const [0xA9, 0x63, 0x6D, 0x74]);
    if (i >= 0 && i + 20 <= b.length) {
      final size = ByteData.sublistView(b).getUint32(i + 4);
      final end = (i + 4 + size).clamp(i + 20, b.length);
      final text = utf8.decode(b.sublist(i + 20, end), allowMalformed: true).trim();
      if (isValidUrl(text)) return text;
    }
    final s = latin1.decode(b, allowInvalid: true);
    final patterns = [
      RegExp(r'COMMENT=(https?://[\x21-\x7e]+)', caseSensitive: false), // Opus / Ogg
      RegExp(r'COMM[\s\S]{0,30}?(https?://[\x21-\x7e]+)'), // MP3 (ID3)
      RegExp(r'COMMENT[\s\S]{0,16}?(https?://[\x21-\x7e]+)'), // MKV
    ];
    for (final r in patterns) {
      final m = r.firstMatch(s);
      if (m != null && isValidUrl(m.group(1)!)) return m.group(1)!;
    }
    return '';
  }

  static int _indexOf(Uint8List b, List<int> key) {
    for (var i = 0; i <= b.length - key.length; i++) {
      var ok = true;
      for (var j = 0; j < key.length; j++) {
        if (b[i + j] != key[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }
}
