import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_extra.dart';

/// Languages shown in Settings (native names).
const kLanguages = <(String, String)>[
  ('en', 'English'),
  ('bn', 'বাংলা'),
  ('hi', 'हिन्दी'),
  ('ar', 'العربية'),
  ('es', 'Español'),
  ('id', 'Bahasa Indonesia'),
];


/// App-wide settings: language, theme mode, accent colour, folders, notifications.
class AppSettings extends ChangeNotifier {
  String lang = 'en';
  String themeMode = 'light'; // system | light | dark
  int accent = 5; // cyan
  bool platformFolders = true;
  bool gridView = false;
  bool notifications = true;
  bool autoPaste = true;
  String engineChannel = 'nightly'; // engine updates itself silently

  bool get isRtl => lang == 'ar' || lang == 'ur';

  ThemeMode get mode => themeMode == 'light'
      ? ThemeMode.light
      : themeMode == 'dark'
          ? ThemeMode.dark
          : ThemeMode.system;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    lang = p.getString('app_lang') ?? 'en';
    themeMode = p.getString('theme_mode') ?? 'light';
    accent = p.getInt('accent') ?? 5;
    platformFolders = p.getBool('platform_folders') ?? true;
    gridView = p.getBool('grid_view') ?? false;
    notifications = p.getBool('notifications') ?? true;
    autoPaste = p.getBool('auto_paste') ?? true;
  }

  Future<void> _save(String k, Object v) async {
    final p = await SharedPreferences.getInstance();
    if (v is bool) {
      await p.setBool(k, v);
    } else if (v is int) {
      await p.setInt(k, v);
    } else {
      await p.setString(k, '$v');
    }
  }

  Future<void> setLang(String v) async {
    lang = v;
    notifyListeners();
    await _save('app_lang', v);
  }

  Future<void> setThemeMode(String v) async {
    themeMode = v;
    notifyListeners();
    await _save('theme_mode', v);
  }

  /// Top-bar button: flips between day and night.
  Future<void> toggleTheme(Brightness current) =>
      setThemeMode(current == Brightness.dark ? 'light' : 'dark');

  Future<void> setAccent(int v) async {
    accent = v;
    notifyListeners();
    await _save('accent', v);
  }

  Future<void> setPlatformFolders(bool v) async {
    platformFolders = v;
    notifyListeners();
    await _save('platform_folders', v);
  }

  Future<void> setGridView(bool v) async {
    gridView = v;
    notifyListeners();
    await _save('grid_view', v);
  }

  Future<void> setAutoPaste(bool v) async {
    autoPaste = v;
    notifyListeners();
    await _save('auto_paste', v);
  }

  Future<void> setNotifications(bool v) async {
    notifications = v;
    notifyListeners();
    await _save('notifications', v);
  }

  String t(String key, [List<Object> args = const []]) {
    var s = _all[lang]?[key] ?? _all['en']![key] ?? key;
    for (final a in args) {
      s = s.replaceFirst('%s', '$a');
    }
    return s;
  }
}

extension TrX on BuildContext {
  /// Use inside build() - rebuilds when the language changes.
  String tr(String key, [List<Object> args = const []]) =>
      Provider.of<AppSettings>(this).t(key, args);

  /// Use inside callbacks.
  String trr(String key, [List<Object> args = const []]) =>
      Provider.of<AppSettings>(this, listen: false).t(key, args);
}

final Map<String, Map<String, String>> _all = () {
  final m = <String, Map<String, String>>{};
  _strings.forEach((k, v) => m[k] = {...v});
  kExtraStrings.forEach((k, v) => (m[k] ??= {}).addAll(v));
  return m;
}();

const _strings = <String, Map<String, String>>{
  'en': {
    'nav_link': 'Link',
    'nav_downloads': 'Downloads',
    'nav_settings': 'Settings',
    'paste_title': 'Paste your video link',
    'hint_link': 'Paste link',
    'paste': 'Paste',
    'clear': 'Clear',
    'download_btn': 'Download',
    'checking': 'Checking…',
    'preparing': 'Getting ready…',
    'err_invalid_url': 'Please enter a valid link.',
    'err_unsupported': 'This link is not supported.',
    'err_private': 'This video is private or needs a login.',
    'err_network': 'No internet connection. Please try again.',
    'err_unavailable': 'This video is not available.',
    'err_storage': 'Not enough storage space.',
    'err_generic': 'Something went wrong. Please try again.',
    'err_engine': 'The app could not start. Please restart it.',
    'in_progress': 'IN PROGRESS',
    'completed_section': 'COMPLETED',
    'history_empty': 'No downloads yet',
    'sec_general': 'GENERAL',
    'sec_engine': 'ENGINE',
    'sec_about': 'ABOUT',
    'language': 'Language',
    'platform_folders': 'Separate folder for each platform',
    'platform_folders_sub': 'Saves into folders like YouTube, Pinterest, CapCut',
    'update_ytdlp': 'Update downloader engine',
    'updating': 'Updating…',
    'current': 'Current: %s',
    'updated': 'Engine updated (%s)',
    'up_to_date': 'Already up to date (%s)',
    'update_failed': 'Update failed',
    'support_dev': 'Support the Developer',
    'support_sub': 'Your support keeps this project alive',
    'facebook_profile': 'Facebook Profile',
    'telegram_channel': 'Telegram Channel',
    'version': 'Version %s',
    'theme_to_day': 'Switch to day mode',
    'theme_to_night': 'Switch to night mode',
    'perm_title': 'Welcome to 0XDL',
    'perm_body': 'To work properly, the app needs a couple of permissions:',
    'perm_storage': 'Storage access',
    'perm_storage_sub': 'To save videos in your Download folder',
    'perm_notif': 'Notifications',
    'perm_notif_sub': 'To show download progress',
    'perm_btn': 'Grant permissions',
    'tg_title': 'Join our Telegram',
    'tg_body':
        'Join our Telegram channel for more apps like this and project updates.',
    'tg_join': 'Join',
    'close': 'Close',
    'dont_show': "Don't show again",
    'video': 'Video',
    'audio': 'Audio',
    'subtitles': 'Subtitles',
    'thumbnail': 'Thumbnail',
    'fast_mode': 'Fast mode',
    'best_quality': 'Best available (auto)',
    'high_quality': 'High quality',
    'best_audio': 'Best quality',
    'saving_to': 'Saving to Download/%s',
    'starting': 'Starting…',
    'downloading': 'Downloading',
    'processing': 'Processing…',
    'completed': 'Completed',
    'failed': 'Failed',
    'cancelled': 'Cancelled',
    'left': '%s left',
    'cancel_download': 'Cancel download',
    'dismiss': 'Dismiss',
    'delete': 'Delete',
    'cancel': 'Cancel',
    'delete_title': 'Delete download?',
    'delete_body': 'This will remove it from your list.',
    'delete_also_file': 'Also delete the original file',
    'file_missing': 'File not found',
    'open_failed': 'Could not open the file',
    'n_downloading': 'Downloading',
    'n_processing': 'Processing…',
    'n_done': 'Download complete',
    'n_failed': 'Download failed',
    'n_multi': '%d downloads',
    'welcome_tagline': 'Download videos & audio from multiple platforms',
    'supports_hint': 'YouTube, Facebook, Instagram, TikTok, Pinterest and many more',
    'err_blocked': 'The site blocked the request. Open Settings, update the engine and try again.',
    'advanced': 'More options',
    'adv_subs': 'Subtitles',
    'adv_subs_sub': 'Add subtitles to the video, if the video has them',
    'adv_thumb': 'Cover image',
    'adv_thumb_sub': 'Save the video thumbnail inside the file',
    'adv_fast': 'Faster download',
    'adv_fast_sub': 'Uses several connections at once. May not work on every site',
    'adv_format': 'Video file type',
    'adv_mp4_sub': 'MP4 plays on almost every phone and player',
    'adv_mkv_sub': 'MKV is better for 4K / 8K if MP4 does not play',
    'q_8k': '8K · Extremely sharp, very large file',
    'q_4k': '4K Ultra HD · Best quality, large file',
    'q_2k': '2K · Very sharp, large file',
    'q_fhd': 'Full HD · Great for most screens',
    'q_hd': 'HD · Good quality, medium file',
    'q_sd': 'Standard · Saves data',
    'q_low': 'Low · Small file',
    'q_verylow': 'Very low · Smallest file',
    'best_note': 'Highest quality this video offers',
    'a_mp3': 'Plays everywhere',
    'a_m4a': 'Great quality, small file',
    'a_opus': 'Best quality for its size, some players may not support it',
    'filter_all': 'All',
    'filter_video': 'Video',
    'filter_audio': 'Audio',
    'view_list': 'List view',
    'view_grid': 'Grid view',
    'menu_details': 'Details',
    'menu_share': 'Share',
    'menu_source': 'Open source link',
    'details_title': 'Details',
    'd_quality': 'Quality',
    'd_size': 'Size',
    'd_date': 'Downloaded',
    'd_platform': 'Platform',
    'd_saved_to': 'Saved in',
    'd_source': 'Source link',
    'share_failed': 'Could not share the file',
    'engine_channel': 'Engine version',
    'channel_stable': 'Stable',
    'channel_nightly': 'Nightly',
    'channel_sub': 'Nightly gets YouTube fixes sooner (recommended)',
    'hero_title': 'Download media from multiple platforms',
    'chip_quality': 'Up to 8K quality',
    'chip_audio': 'MP3 / M4A audio',
    'chip_local': 'Runs on your phone',
    'splash_slogan': 'Download media from anywhere',
    'from_dev': 'From',
    'set_title': 'Settings',
    'app_language': 'App language',
    'themes': 'Themes',
    'theme_mode': 'Mode',
    'mode_system': 'System',
    'mode_light': 'Light',
    'mode_dark': 'Dark',
    'theme_color': 'Colour',
    'notifications': 'Notifications',
    'notifications_sub': 'Download status and app update alerts',
    'notif_blocked': 'Allow notifications for 0XDL in system settings, then turn this on again',
    'about_app': 'About App',
    'about_dev': 'About Developer',
    'website': 'Website',
    'about_desc': '0XDL downloads videos and audio from many platforms. Everything runs on your phone: no account and no server.',
    'ab1': 'Quality up to 8K, plus MP3 / M4A audio',
    'ab2': 'Separate folder for each platform',
    'ab3': 'Downloader engine updates itself',
    'ab4': 'Day and night themes in many colours',
    'view_project': 'View project page',
    'up_checking': 'Checking for updates…',
    'up_latest': 'You are on the latest version',
    'up_new': 'New version %s is available',
    'up_tap': 'Tap to see what is new',
    'whats_new': 'What is new',
    'up_now': 'Update now',
    'later': 'Later',
    'up_downloading': 'Downloading update…',
    'up_opening': 'Opening installer…',
    'up_perm': 'Allow 0XDL to install apps, then tap Update now again',
    'up_fail': 'Update failed. Please try again.',
    'up_no_notes': 'Bug fixes and improvements.',
    'nu_title': 'Update available',
    'nu_body': '0XDL %s is ready to install',
    'new_badge': 'NEW',
    'lang_en': 'English',
    'lang_bn': 'বাংলা',
    'q_best_short': 'Best',
    'menu_rename': 'Rename',
    'menu_open_with': 'Open with another app',
    'rename_title': 'Rename file',
    'rename_hint': 'File name',
    'rename_save': 'Save',
    'rename_done': 'Renamed',
    'rename_invalid': 'Please enter a name.',
    'rename_exists': 'A file with this name already exists.',
    'rename_failed': 'Could not rename the file.',
    'd_file': 'File name',
    'empty_video': 'No videos yet',
    'empty_audio': 'No audio yet',
    'player_error': 'This file could not be played here.',
    'player_speed': 'Speed',
    'lock_screen': 'Lock screen',
    'unlock_screen': 'Unlock',
    'restore_btn': 'Find my downloads',
    'restore_hint': 'Files already in Download/0XDL? Scan the folder to bring them back.',
    'restore_done': 'Restored %s downloads',
    'restore_none': 'No new files found',
    'auto_paste': 'Auto-paste link',
    'auto_paste_sub': 'Paste a copied link automatically when you open the app',
    'latest_badge': 'Latest',
    'upd_skip': 'Skip this version',
    'upd_remind': 'Remind me later',
  },
  'bn': {
    'nav_link': 'লিংক',
    'nav_downloads': 'ডাউনলোড',
    'nav_settings': 'সেটিংস',
    'paste_title': 'আপনার ভিডিওর লিংক পেস্ট করুন',
    'hint_link': 'লিংক পেস্ট করুন',
    'paste': 'পেস্ট',
    'clear': 'মুছুন',
    'download_btn': 'ডাউনলোড',
    'checking': 'যাচাই হচ্ছে…',
    'preparing': 'প্রস্তুত হচ্ছে…',
    'err_invalid_url': 'সঠিক একটি লিংক দিন।',
    'err_unsupported': 'এই লিংকটি সাপোর্ট করে না।',
    'err_private': 'ভিডিওটি প্রাইভেট অথবা লগইন প্রয়োজন।',
    'err_network': 'ইন্টারনেট সংযোগ নেই। আবার চেষ্টা করুন।',
    'err_unavailable': 'ভিডিওটি পাওয়া যাচ্ছে না।',
    'err_storage': 'ফোনে পর্যাপ্ত জায়গা নেই।',
    'err_generic': 'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।',
    'err_engine': 'অ্যাপ চালু করা যায়নি। অ্যাপটি আবার খুলুন।',
    'in_progress': 'চলছে',
    'completed_section': 'সম্পন্ন',
    'history_empty': 'এখনো কোনো ডাউনলোড নেই',
    'sec_general': 'সাধারণ',
    'sec_engine': 'ইঞ্জিন',
    'sec_about': 'সম্পর্কে',
    'language': 'ভাষা',
    'platform_folders': 'প্রতিটি প্ল্যাটফর্মের জন্য আলাদা ফোল্ডার',
    'platform_folders_sub': 'YouTube, Pinterest, CapCut-এর মতো ফোল্ডারে সেভ হবে',
    'update_ytdlp': 'ডাউনলোড ইঞ্জিন আপডেট',
    'updating': 'আপডেট হচ্ছে…',
    'current': 'বর্তমান: %s',
    'updated': 'ইঞ্জিন আপডেট হয়েছে (%s)',
    'up_to_date': 'সর্বশেষ সংস্করণই আছে (%s)',
    'update_failed': 'আপডেট ব্যর্থ হয়েছে',
    'support_dev': 'ডেভেলপারকে সাপোর্ট করুন',
    'support_sub': 'আপনার সহায়তা এই প্রজেক্টকে এগিয়ে নিয়ে যায়',
    'facebook_profile': 'ফেসবুক প্রোফাইল',
    'telegram_channel': 'টেলিগ্রাম চ্যানেল',
    'version': 'সংস্করণ %s',
    'theme_to_day': 'দিনের মোডে যান',
    'theme_to_night': 'রাতের মোডে যান',
    'perm_title': '0XDL-এ স্বাগতম',
    'perm_body': 'ঠিকমতো কাজ করার জন্য অ্যাপের কয়েকটি অনুমতি দরকার:',
    'perm_storage': 'স্টোরেজ অ্যাক্সেস',
    'perm_storage_sub': 'ভিডিও Download ফোল্ডারে সেভ করার জন্য',
    'perm_notif': 'নোটিফিকেশন',
    'perm_notif_sub': 'ডাউনলোডের অগ্রগতি দেখানোর জন্য',
    'perm_btn': 'অনুমতি দিন',
    'tg_title': 'আমাদের টেলিগ্রামে যোগ দিন',
    'tg_body':
        'এই ধরনের আরও অ্যাপ এবং প্রজেক্টের আপডেট পেতে আমাদের টেলিগ্রাম চ্যানেলে যোগ দিন।',
    'tg_join': 'যোগ দিন',
    'close': 'বন্ধ করুন',
    'dont_show': 'আর দেখাবেন না',
    'video': 'ভিডিও',
    'audio': 'অডিও',
    'subtitles': 'সাবটাইটেল',
    'thumbnail': 'থাম্বনেইল',
    'fast_mode': 'দ্রুত মোড',
    'best_quality': 'সর্বোচ্চ মান (স্বয়ংক্রিয়)',
    'high_quality': 'উচ্চ মান',
    'best_audio': 'সর্বোচ্চ মান',
    'saving_to': 'সেভ হবে Download/%s ফোল্ডারে',
    'starting': 'শুরু হচ্ছে…',
    'downloading': 'ডাউনলোড হচ্ছে',
    'processing': 'প্রসেস হচ্ছে…',
    'completed': 'সম্পন্ন',
    'failed': 'ব্যর্থ',
    'cancelled': 'বাতিল',
    'left': '%s বাকি',
    'cancel_download': 'ডাউনলোড বাতিল করুন',
    'dismiss': 'সরিয়ে দিন',
    'delete': 'মুছুন',
    'cancel': 'বাতিল',
    'delete_title': 'ডাউনলোড মুছবেন?',
    'delete_body': 'এটি আপনার তালিকা থেকে সরিয়ে দেওয়া হবে।',
    'delete_also_file': 'আসল ফাইলটিও মুছে ফেলুন',
    'file_missing': 'ফাইল পাওয়া যায়নি',
    'open_failed': 'ফাইলটি খোলা যায়নি',
    'n_downloading': 'ডাউনলোড হচ্ছে',
    'n_processing': 'প্রসেস হচ্ছে…',
    'n_done': 'ডাউনলোড সম্পন্ন',
    'n_failed': 'ডাউনলোড ব্যর্থ',
    'n_multi': '%dটি ডাউনলোড',
    'welcome_tagline': 'একাধিক প্ল্যাটফর্ম থেকে ভিডিও ও অডিও ডাউনলোড করুন',
    'supports_hint': 'YouTube, Facebook, Instagram, TikTok, Pinterest সহ আরও অনেক সাইট',
    'err_blocked': 'সাইটটি অনুরোধ আটকে দিয়েছে। সেটিংসে গিয়ে ইঞ্জিন আপডেট করে আবার চেষ্টা করুন।',
    'advanced': 'আরও অপশন',
    'adv_subs': 'সাবটাইটেল',
    'adv_subs_sub': 'ভিডিওতে সাবটাইটেল থাকলে সেটা যোগ হবে',
    'adv_thumb': 'কভার ছবি',
    'adv_thumb_sub': 'ভিডিওর থাম্বনেইল ফাইলের ভেতরে সেভ হবে',
    'adv_fast': 'দ্রুত ডাউনলোড',
    'adv_fast_sub': 'একসাথে কয়েকটি সংযোগ ব্যবহার করে। সব সাইটে কাজ নাও করতে পারে',
    'adv_format': 'ভিডিও ফাইলের ধরন',
    'adv_mp4_sub': 'MP4 প্রায় সব ফোন ও প্লেয়ারে চলে',
    'adv_mkv_sub': 'MP4 না চললে 4K / 8K এর জন্য MKV ভালো',
    'q_8k': '8K · অসম্ভব স্পষ্ট, ফাইল অনেক বড়',
    'q_4k': '4K আল্ট্রা HD · সেরা মান, ফাইল বড়',
    'q_2k': '2K · খুব স্পষ্ট, ফাইল বড়',
    'q_fhd': 'ফুল HD · বেশিরভাগ স্ক্রিনের জন্য দারুণ',
    'q_hd': 'HD · ভালো মান, মাঝারি ফাইল',
    'q_sd': 'স্ট্যান্ডার্ড · ডেটা সাশ্রয়ী',
    'q_low': 'কম মান · ছোট ফাইল',
    'q_verylow': 'খুব কম মান · সবচেয়ে ছোট ফাইল',
    'best_note': 'এই ভিডিওতে যে সর্বোচ্চ মান আছে',
    'a_mp3': 'সব জায়গায় চলে',
    'a_m4a': 'দারুণ মান, ছোট ফাইল',
    'a_opus': 'আকারের তুলনায় সেরা মান, কিছু প্লেয়ারে নাও চলতে পারে',
    'filter_all': 'সব',
    'filter_video': 'ভিডিও',
    'filter_audio': 'অডিও',
    'view_list': 'তালিকা দেখুন',
    'view_grid': 'গ্রিড দেখুন',
    'menu_details': 'বিস্তারিত',
    'menu_share': 'শেয়ার',
    'menu_source': 'মূল লিংক খুলুন',
    'details_title': 'বিস্তারিত',
    'd_quality': 'মান',
    'd_size': 'সাইজ',
    'd_date': 'ডাউনলোডের সময়',
    'd_platform': 'প্ল্যাটফর্ম',
    'd_saved_to': 'সেভ আছে',
    'd_source': 'মূল লিংক',
    'share_failed': 'ফাইলটি শেয়ার করা যায়নি',
    'engine_channel': 'ইঞ্জিনের ধরন',
    'channel_stable': 'স্টেবল',
    'channel_nightly': 'নাইটলি',
    'channel_sub': 'নাইটলিতে YouTube-এর সমস্যার সমাধান আগে আসে (প্রস্তাবিত)',
    'hero_title': 'একাধিক প্ল্যাটফর্ম থেকে মিডিয়া ডাউনলোড করুন',
    'chip_quality': '8K পর্যন্ত মান',
    'chip_audio': 'MP3 / M4A অডিও',
    'chip_local': 'সব কাজ আপনার ফোনেই',
    'splash_slogan': 'যেকোনো জায়গা থেকে মিডিয়া ডাউনলোড',
    'from_dev': 'From',
    'set_title': 'সেটিংস',
    'app_language': 'অ্যাপের ভাষা',
    'themes': 'থিম',
    'theme_mode': 'মোড',
    'mode_system': 'সিস্টেম',
    'mode_light': 'দিন',
    'mode_dark': 'রাত',
    'theme_color': 'রঙ',
    'notifications': 'নোটিফিকেশন',
    'notifications_sub': 'ডাউনলোডের অবস্থা ও অ্যাপ আপডেটের খবর',
    'notif_blocked': 'সিস্টেম সেটিংসে 0XDL-এর নোটিফিকেশন চালু করে এখানে আবার অন করুন',
    'about_app': 'অ্যাপ সম্পর্কে',
    'about_dev': 'ডেভেলপার সম্পর্কে',
    'website': 'ওয়েবসাইট',
    'about_desc': '0XDL অনেক প্ল্যাটফর্ম থেকে ভিডিও ও অডিও ডাউনলোড করে। সব কাজ আপনার ফোনেই হয়: অ্যাকাউন্ট বা সার্ভার লাগে না।',
    'ab1': '8K পর্যন্ত মান, সাথে MP3 / M4A অডিও',
    'ab2': 'প্রতিটি প্ল্যাটফর্মের জন্য আলাদা ফোল্ডার',
    'ab3': 'ডাউনলোড ইঞ্জিন নিজে থেকেই আপডেট হয়',
    'ab4': 'অনেক রঙের দিন ও রাতের থিম',
    'view_project': 'প্রজেক্ট পেজ দেখুন',
    'up_checking': 'আপডেট দেখা হচ্ছে…',
    'up_latest': 'আপনি সর্বশেষ সংস্করণেই আছেন',
    'up_new': 'নতুন সংস্করণ %s এসেছে',
    'up_tap': 'নতুন কী আছে দেখতে ট্যাপ করুন',
    'whats_new': 'নতুন কী আছে',
    'up_now': 'এখনই আপডেট করুন',
    'later': 'পরে',
    'up_downloading': 'আপডেট ডাউনলোড হচ্ছে…',
    'up_opening': 'ইনস্টলার খোলা হচ্ছে…',
    'up_perm': '0XDL-কে অ্যাপ ইনস্টলের অনুমতি দিন, তারপর আবার "এখনই আপডেট করুন" চাপুন',
    'up_fail': 'আপডেট হয়নি। আবার চেষ্টা করুন।',
    'up_no_notes': 'বাগ ফিক্স ও উন্নতি।',
    'nu_title': 'নতুন আপডেট এসেছে',
    'nu_body': '0XDL %s ইনস্টলের জন্য প্রস্তুত',
    'new_badge': 'নতুন',
    'lang_en': 'English',
    'lang_bn': 'বাংলা',
    'q_best_short': 'সেরা',
    'menu_rename': 'নাম বদলান',
    'menu_open_with': 'অন্য অ্যাপে খুলুন',
    'rename_title': 'ফাইলের নাম বদলান',
    'rename_hint': 'ফাইলের নাম',
    'rename_save': 'সেভ করুন',
    'rename_done': 'নাম বদলানো হয়েছে',
    'rename_invalid': 'একটি নাম লিখুন।',
    'rename_exists': 'এই নামে আরেকটি ফাইল আগে থেকেই আছে।',
    'rename_failed': 'ফাইলের নাম বদলানো যায়নি।',
    'd_file': 'ফাইলের নাম',
    'empty_video': 'এখনো কোনো ভিডিও নেই',
    'empty_audio': 'এখনো কোনো অডিও নেই',
    'player_error': 'এই ফাইলটি এখানে চালানো যায়নি।',
    'player_speed': 'গতি',
    'lock_screen': 'স্ক্রিন লক করুন',
    'unlock_screen': 'আনলক',
    'restore_btn': 'আমার ডাউনলোড খুঁজুন',
    'restore_hint': 'Download/0XDL ফোল্ডারে ফাইল আছে? ফোল্ডার স্ক্যান করে তালিকায় ফিরিয়ে আনুন।',
    'restore_done': '%sটি ডাউনলোড ফিরে এসেছে',
    'restore_none': 'নতুন কোনো ফাইল পাওয়া যায়নি',
    'auto_paste': 'অটো পেস্ট লিংক',
    'auto_paste_sub': 'অ্যাপ খুললে কপি করা লিংক নিজে থেকে বসে যাবে',
    'latest_badge': 'সর্বশেষ',
    'upd_skip': 'এই ভার্সন বাদ দিন',
    'upd_remind': 'পরে মনে করান',
  },
};
