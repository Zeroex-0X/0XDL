class FormatInfo {
  final String id;
  final String ext;
  final int? height;
  final int? width;
  final double? fps;
  final double? tbr; // kbit/s
  final int? size;
  final bool hasVideo;
  final bool hasAudio;

  FormatInfo({
    required this.id,
    required this.ext,
    this.height,
    this.width,
    this.fps,
    this.tbr,
    this.size,
    required this.hasVideo,
    required this.hasAudio,
  });

  factory FormatInfo.fromJson(Map j) {
    final vc = j['vc'] as String?;
    final ac = j['ac'] as String?;
    final h = (j['h'] as num?)?.toInt();
    return FormatInfo(
      id: '${j['id']}',
      ext: '${j['ext']}',
      height: h,
      width: (j['w'] as num?)?.toInt(),
      fps: (j['fps'] as num?)?.toDouble(),
      tbr: (j['tbr'] as num?)?.toDouble(),
      size: (j['size'] as num?)?.toInt(),
      hasVideo: vc != 'none' && (vc != null || h != null),
      hasAudio: ac != 'none' && ac != null,
    );
  }
}

class VideoMeta {
  final String url;
  final String title;
  final String thumbnail;
  final int duration; // seconds
  final String uploader;
  final String extractor;
  final String domain;
  final List<FormatInfo> formats;

  VideoMeta({
    required this.url,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.uploader,
    required this.extractor,
    required this.domain,
    required this.formats,
  });
}

enum MediaKind { video, audio }

class MediaOption {
  final String label;
  final MediaKind kind;
  final int? size;
  final String selector; // yt-dlp -f expression
  final bool isBest;
  final int? tier; // short side in px (720 for 1280x720 / 720x1280)
  final String? audioFormat; // mp3 / m4a / opus
  final int? height;

  const MediaOption({
    required this.label,
    required this.kind,
    required this.selector,
    this.size,
    this.audioFormat,
    this.height,
    this.isBest = false,
    this.tier,
  });

  /// Language-neutral label saved in history ('' = best available).
  String get plainLabel => isBest
      ? ''
      : (kind == MediaKind.audio ? (audioFormat ?? '').toUpperCase() : label);
}

class DownloadRequest {
  final MediaOption option;
  final bool subtitles;
  final bool embedThumb;
  final bool fastMode;
  final String container; // mp4 / mkv

  const DownloadRequest({
    required this.option,
    this.subtitles = false,
    this.embedThumb = true,
    this.fastMode = false,
    this.container = 'mp4',
  });
}

enum DownloadStatus { downloading, done, failed, cancelled }

enum DownloadStage { starting, downloading, processing }

class DownloadItem {
  final String id;
  final String url;
  final String title;
  final String thumbnail;
  final String label; // '' = best available
  DownloadStatus status = DownloadStatus.downloading;
  DownloadStage stage = DownloadStage.starting;
  double progress = 0;
  String speed = '';
  int eta = 0;
  String? path;
  String? errorKey;
  bool cancelRequested = false;

  DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnail,
    required this.label,
  });
}

class HistoryEntry {
  final String id;
  final String url;
  final String title;
  final String thumbnail;
  final String label;
  final String path;
  final int size;
  final int date; // ms since epoch

  const HistoryEntry({
    required this.id,
    this.url = '',
    required this.title,
    required this.thumbnail,
    required this.label,
    required this.path,
    required this.size,
    required this.date,
  });

  String get ext {
    final i = path.lastIndexOf('.');
    return (i > path.lastIndexOf('/') && i >= 0) ? path.substring(i + 1).toLowerCase() : '';
  }

  HistoryEntry copyWith({String? title, String? path, String? thumbnail}) => HistoryEntry(
        id: id,
        url: url,
        title: title ?? this.title,
        thumbnail: thumbnail ?? this.thumbnail,
        label: label,
        path: path ?? this.path,
        size: size,
        date: date,
      );

  bool get isAudio {
    final e = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return const {'mp3', 'm4a', 'opus', 'ogg', 'flac', 'wav', 'aac'}.contains(e);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'thumb': thumbnail,
        'label': label,
        'path': path,
        'size': size,
        'date': date,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: '${j['id']}',
        url: '${j['url'] ?? ''}',
        title: '${j['title']}',
        thumbnail: '${j['thumb'] ?? ''}',
        label: '${j['label'] ?? ''}',
        path: '${j['path'] ?? ''}',
        size: (j['size'] as num?)?.toInt() ?? 0,
        date: (j['date'] as num?)?.toInt() ?? 0,
      );
}
