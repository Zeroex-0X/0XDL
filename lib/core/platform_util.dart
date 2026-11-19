bool isValidUrl(String text) {
  final u = Uri.tryParse(text.trim());
  return u != null &&
      (u.scheme == 'http' || u.scheme == 'https') &&
      u.host.contains('.');
}

String formatBytes(num b) {
  if (b < 1024) return '${b.toStringAsFixed(0)} B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

const _known = <String, String>{
  'youtube': 'YouTube',
  'youtu': 'YouTube',
  'tiktok': 'TikTok',
  'capcut': 'CapCut',
  'facebook': 'Facebook',
  'fb': 'Facebook',
  'instagram': 'Instagram',
  'instagr': 'Instagram',
  'pinterest': 'Pinterest',
  'pin': 'Pinterest',
  'twitter': 'Twitter',
  'x': 'X',
  'vimeo': 'Vimeo',
  'dailymotion': 'Dailymotion',
  'soundcloud': 'SoundCloud',
  'reddit': 'Reddit',
  'snapchat': 'Snapchat',
  'linkedin': 'LinkedIn',
  'twitch': 'Twitch',
  'bilibili': 'Bilibili',
  'likee': 'Likee',
  'threads': 'Threads',
  'telegram': 'Telegram',
  'tumblr': 'Tumblr',
  'rumble': 'Rumble',
  'imgur': 'Imgur',
  'vk': 'VK',
};

String _siteName(String host) {
  final parts = host.toLowerCase().split('.').where((e) => e.isNotEmpty).toList();
  if (parts.length < 2) return '';
  const second = {'co', 'com', 'org', 'net', 'gov', 'ac', 'edu'};
  var i = parts.length - 2;
  if (i >= 1 && second.contains(parts[i]) && parts.last.length == 2) i--;
  return parts[i];
}

/// Folder name for a download: Pinterest -> "Pinterest", CapCut -> "CapCut",
/// unknown / generic sites -> "Other".
String platformFolderName(String domainOrUrl, String extractor) {
  if (extractor.toLowerCase() == 'generic') return 'Other';
  var host = domainOrUrl.trim();
  if (host.contains('/')) host = Uri.tryParse(host)?.host ?? '';
  final name = _siteName(host).replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (name.isEmpty) return 'Other';
  return _known[name] ?? '${name[0].toUpperCase()}${name.substring(1)}';
}

/// Turns a raw engine error into a short, friendly message key.
String friendlyErrorKey(String raw) {
  final s = raw.toLowerCase();
  bool has(List<String> k) => k.any(s.contains);
  if (has(['unsupported url'])) return 'err_unsupported';
  if (has(['not a bot', '403', 'forbidden', 'challenge', 'po token'])) {
    return 'err_blocked';
  }
  if (has(['no space left', 'enospc'])) return 'err_storage';
  if (has(['private', 'sign in', 'log in', 'login', 'cookies', 'members-only',
      'confirm your age', 'age-restricted', 'authentication'])) {
    return 'err_private';
  }
  if (has(['timed out', 'timeout', 'connection', 'network is unreachable',
      'name or service', 'resolve', 'urlopen error', 'temporary failure',
      'unable to download webpage'])) {
    return 'err_network';
  }
  if (has(['unavailable', 'removed', 'not available', 'does not exist',
      'deleted', 'no video formats', 'http error 404'])) {
    return 'err_unavailable';
  }
  return 'err_generic';
}
