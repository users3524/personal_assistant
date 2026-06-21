/// Shared app color tokens.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF9A6A43);
  static const Color primaryLight = Color(0xFFE9D8C5);
  static const Color primaryDark = Color(0xFF5F3E26);

  static const Color wood = Color(0xFF9A6A43);
  static const Color gold = Color(0xFFC9A24D);
  static const Color blue = Color(0xFF4F7CAC);
  static const Color green = Color(0xFF4F8F67);
  static const Color orange = Color(0xFFE19A3B);
  static const Color red = Color(0xFFD85C4A);

  static const Color ink = Color(0xFF1F1B16);
  static const Color muted = Color(0xFF8B857B);
  static const Color line = Color(0xFFEEE8DD);
  static const Color surface = Color(0xFFF8F5EF);
  static const Color surfaceDark = Color(0xFF1C1B1F);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2B2930);

  static const Color success = green;
  static const Color warning = orange;
  static const Color error = red;
  static const Color info = blue;

  static const Color lifeColor = green;
  static const Color workColor = blue;

  static const List<Color> priorityColors = [
    Color(0xFF9E9E9E),
    green,
    orange,
    red,
    Color(0xFFD50000),
  ];

  static const Color moodHighEnergy = Color(0xFFFF6B35);
  static const Color moodCalm = green;
  static const Color moodAnxious = orange;
  static const Color moodTired = Color(0xFF9E9E9E);
}
