import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

class FileUtils {
  static Future<String> _getAppDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final idImagesPath = Directory('${directory.path}/ID_IMAGES');
    if (!await idImagesPath.exists()) {
      await idImagesPath.create();
    }
    return idImagesPath.path;
  }

  static Future<void> saveImage(XFile image) async {
    final appDirPath = await _getAppDirectoryPath();
    final savedImagePath = '$appDirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(image.path).copy(savedImagePath);
  }

  static Future<List<File>> getSavedImages() async {
    final appDirPath = await _getAppDirectoryPath();
    final idImagesDir = Directory(appDirPath);
    if (await idImagesDir.exists()) {
      return idImagesDir.listSync().whereType<File>().toList();
    }
    return [];
  }
}
