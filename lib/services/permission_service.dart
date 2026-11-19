import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// True when everything the app must have is already granted.
  static Future<bool> hasRequired() async {
    final storage = await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;
    final notif = await Permission.notification.isGranted;
    return storage && notif;
  }

  /// Asks for the required permissions. Returns true if storage access was granted.
  static Future<bool> requestAll() async {
    await Permission.notification.request();
    final manage = await Permission.manageExternalStorage.request();
    var storage = manage.isGranted;
    if (!storage) storage = (await Permission.storage.request()).isGranted;
    return storage;
  }
}
