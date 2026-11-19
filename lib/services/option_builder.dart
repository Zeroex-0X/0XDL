import '../models/models.dart';

/// Quality text key for a video whose shorter side is [short] px (720 for 1280x720 or 720x1280).
String qualityNoteKey(int short) {
  if (short >= 4320) return 'q_8k';
  if (short >= 2160) return 'q_4k';
  if (short >= 1440) return 'q_2k';
  if (short >= 1080) return 'q_fhd';
  if (short >= 720) return 'q_hd';
  if (short >= 480) return 'q_sd';
  if (short >= 360) return 'q_low';
  return 'q_verylow';
}

String resolutionLabel(int short, double fps) {
  String base;
  if (short >= 4320) {
    base = '8K · ${short}p';
  } else if (short >= 2160) {
    base = '4K · ${short}p';
  } else if (short >= 1440) {
    base = '2K · ${short}p';
  } else {
    base = '${short}p';
  }
  return fps >= 50 ? '$base · ${fps.round()}fps' : base;
}

/// File size: exact if the site tells us, otherwise bitrate x duration.
int? _estimate(FormatInfo f, int duration) {
  if (f.size != null) return f.size;
  if (f.tbr != null && duration > 0) return (f.tbr! * 1000 / 8 * duration).round();
  return null;
}

/// Builds every option the video actually offers: all available qualities + audio.
List<MediaOption> buildOptions(VideoMeta m) {
  final dur = m.duration;
  final opts = <MediaOption>[];
  final videoFmts = m.formats.where((f) => f.hasVideo && f.height != null).toList();
  final audioOnly = m.formats.where((f) => f.hasAudio && !f.hasVideo).toList();
  final bestAudio = audioOnly
      .map((f) => _estimate(f, dur) ?? 0)
      .fold<int>(0, (a, b) => a > b ? a : b);

  int? sizeOf(FormatInfo f) {
    final e = _estimate(f, dur);
    if (e == null) return null;
    return f.hasAudio ? e : e + bestAudio;
  }

  int shortSide(FormatInfo f) {
    final h = f.height!, w = f.width;
    return (w != null && w > 0) ? (w < h ? w : h) : h;
  }

  final heights = videoFmts.map((f) => f.height!).toSet().toList()
    ..sort((a, b) => b.compareTo(a));

  // Best overall
  int? bestSize;
  if (heights.isNotEmpty) {
    final top = videoFmts.where((f) => f.height == heights.first).toList();
    bestSize = top.map(sizeOf).whereType<int>().fold<int?>(
        null, (a, b) => a == null || b > a ? b : a);
  }
  opts.add(MediaOption(
    label: '',
    isBest: true,
    kind: MediaKind.video,
    selector: 'bv*+ba/b',
    size: bestSize,
  ));

  for (final h in heights) {
    final atH = videoFmts.where((f) => f.height == h).toList();
    final fps = atH.map((f) => f.fps ?? 0).fold<double>(0, (a, b) => a > b ? a : b);
    final sizes = atH.map(sizeOf).whereType<int>().toList();
    final size = sizes.isEmpty ? null : sizes.reduce((a, b) => a > b ? a : b);
    final short = shortSide(atH.first);
    opts.add(MediaOption(
      label: resolutionLabel(short, fps),
      kind: MediaKind.video,
      height: h,
      tier: short,
      size: size,
      selector:
          'bv*[height=$h]+ba/b[height=$h]/bv*[height<=$h]+ba/b[height<=$h]',
    ));
  }

  int? audioSize(int bytesPerSecond) {
    if (bestAudio > 0) return bestAudio;
    return dur > 0 ? bytesPerSecond * dur : null;
  }

  opts.addAll([
    MediaOption(
        label: 'MP3',
        kind: MediaKind.audio,
        selector: 'ba/b',
        audioFormat: 'mp3',
        size: dur > 0 ? (245000 / 8 * dur).round() : null),
    MediaOption(
        label: 'M4A',
        kind: MediaKind.audio,
        selector: 'ba/b',
        audioFormat: 'm4a',
        size: audioSize(16000)),
    MediaOption(
        label: 'OPUS',
        kind: MediaKind.audio,
        selector: 'ba/b',
        audioFormat: 'opus',
        size: audioSize(16000)),
  ]);
  return opts;
}

/// yt-dlp arguments. Each inner list is either [flag] or [flag, value].
List<List<String>> buildArgs(DownloadRequest r) {
  final o = r.option;
  final a = <List<String>>[
    ['--no-playlist'],
    ['--newline'],
    // --print makes yt-dlp quiet, which hides the progress lines; turn them back on
    ['--no-quiet'],
    ['--progress'],
    ['--no-mtime'],
    ['--no-simulate'],
    ['--print', 'after_move:filepath'],
    // network drops: wait with growing pauses (up to ~20s) and keep resuming the same file
    ['--retries', '30'],
    ['--fragment-retries', '30'],
    ['--retry-sleep', 'exp=1:20'],
    ['--socket-timeout', '30'],
    ['--concurrent-fragments', '4'],
    ['--embed-metadata'],
  ];

  if (r.fastMode) {
    a.add(['--downloader', 'http,https,ftp,ftps:libaria2c.so']);
    a.add([
      '--external-downloader-args',
      'aria2c:-x 8 -s 8 -k 1M --file-allocation=none --max-tries=5 --retry-wait=2 --console-log-level=warn'
    ]);
  }

  a.add(['-f', o.selector]);

  if (o.kind == MediaKind.audio) {
    a.add(['-o', '%(title).150B.%(ext)s']);
    a.add(['-x']);
    a.add(['--audio-format', o.audioFormat ?? 'mp3']);
    a.add(['--audio-quality', '0']);
    if (r.embedThumb) {
      a.add(['--embed-thumbnail']);
      a.add(['--convert-thumbnails', 'jpg']);
    }
  } else {
    a.add(['-o', '%(title).150B [%(height)sp].%(ext)s']);
    a.add(['--merge-output-format', r.container]);
    a.add(['--remux-video', r.container]);
    if (r.embedThumb) a.add(['--embed-thumbnail']);
    if (r.subtitles) {
      a.add(['--write-subs']);
      a.add(['--write-auto-subs']);
      a.add(['--sub-langs', 'en.*,bn.*']);
      a.add(['--embed-subs']);
    }
  }
  return a;
}
