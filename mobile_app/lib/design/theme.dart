import 'package:flutter/material.dart';
import 'tokens/app_colors.dart';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.lightBackground,
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed, brightness: Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.darkBackground,
  );
}
