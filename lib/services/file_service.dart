import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class FileService {
  static const _ch = MethodChannel('com.fotosort/files');

  static bool _permissionsGranted = false;

  static Future<void> ensurePermissions() async {
    if (_permissionsGranted) return;
    await Permission.storage.request();
    await Permission.photos.request();
    _permissionsGranted = true;
  }

  static Future<String> getRootPath() async {
    return await _ch.invokeMethod<String>('getRootPath') ?? '/storage/emulated/0';
  }

  static Future<List<Map<String, String>>> listDirs(String? path) async {
    final raw = await _ch.invokeListMethod('listDirs', {'path': path});
    return raw?.map((e) => Map<String, String>.from(e as Map)).toList() ?? [];
  }

  static Future<List<String>> scanFolder(String path) async {
    return await _ch.invokeListMethod<String>('scanFolder', {'path': path}) ?? [];
  }

  static Future<void> moveFile(String src, String destDir) async {
    await _ch.invokeMethod('moveFile', {'src': src, 'destDir': destDir});
  }
}
