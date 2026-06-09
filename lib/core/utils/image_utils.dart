/// 图片路径解析工具。
///
/// 新存储的图片使用相对路径（如 `antique_images/xxx.jpg`），
/// 旧图片使用绝对路径。此函数统一解析两者。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 将存储路径解析为 File 对象
/// 自动兼容相对路径和绝对路径
Future<File> resolveImageFile(String storedPath) async {
  // 已经是绝对路径
  if (storedPath.startsWith('/') || storedPath.contains(':\\')) {
    return File(storedPath);
  }
  // 相对路径：拼接文档目录
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$storedPath');
}

/// 检查图片文件是否存在（兼容相对路径）
Future<bool> imageExists(String storedPath) async {
  final file = await resolveImageFile(storedPath);
  return file.existsSync();
}
