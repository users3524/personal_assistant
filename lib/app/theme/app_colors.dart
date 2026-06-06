/// 应用色彩常量。
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ---- 主色----
  static const Color primary = Color(0xFF6750A4); // Material3 紫色
  static const Color primaryLight = Color(0xFFD0BCFF);
  static const Color primaryDark = Color(0xFF381E72);

  // ---- 功能色----
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // ---- 分类色（生活/工作）----
  static const Color lifeColor = Color(0xFF4CAF50); // 绿色 - 生活
  static const Color workColor = Color(0xFF2196F3); // 蓝色 - 工作

  // ---- 优先级色----
  static const List<Color> priorityColors = [
    Color(0xFF9E9E9E), // 1 - 灰色
    Color(0xFF4CAF50), // 2 - 绿色
    Color(0xFFFF9800), // 3 - 橙色
    Color(0xFFE53935), // 4 - 红色
    Color(0xFFD50000), // 5 - 深红
  ];

  // ---- 情绪色----
  static const Color moodHighEnergy = Color(0xFFFF6B35); // 高效
  static const Color moodCalm = Color(0xFF4CAF50);        // 平稳
  static const Color moodAnxious = Color(0xFFFF9800);     // 焦虑
  static const Color moodTired = Color(0xFF9E9E9E);       // 疲惫

  // ---- 通用----
  static const Color surface = Color(0xFFFFFBFE);
  static const Color surfaceDark = Color(0xFF1C1B1F);
  static const Color card = Color(0xFFFFFBFE);
  static const Color cardDark = Color(0xFF2B2930);
}
