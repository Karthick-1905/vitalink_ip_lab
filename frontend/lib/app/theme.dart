import 'package:flutter/material.dart';

class AppColors {
	// Primary palette
	static const Color primary = Color(0xFF648FFF);
	static const Color secondary = Color(0xFF785EF0);
	static const Color accent = Color(0xFFDC267F);
	static const Color warning = Color(0xFFFE6100);
	static const Color info = Color(0xFFFFB000);

	// Backgrounds
	// Note: Flutter Color uses ARGB; #ffffff99 (CSS) becomes 0x99FFFFFF in ARGB.
	static const Color backgroundLight = Color(0x99FFFFFF);
	static const Color backgroundMissed = Colors.lightBlue;
	static const Color backgroundDark = Color(0xFF121212);

	// Status
	static const Color success = Color(0xFF2E7D32);
	static const Color error = Color(0xFFD32F2F);
}

class AppTheme {
	static ThemeData light = ThemeData(
		useMaterial3: true,
		colorScheme: ColorScheme.fromSeed(
			seedColor: AppColors.primary,
			brightness: Brightness.light,
			surface: AppColors.backgroundLight,
		).copyWith(
			primary: AppColors.primary,
			secondary: AppColors.secondary,
			tertiary: AppColors.accent,
			error: AppColors.error,
		),
		scaffoldBackgroundColor: AppColors.backgroundLight,
		snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
		inputDecorationTheme: const InputDecorationTheme(
			border: OutlineInputBorder(),
		),
		elevatedButtonTheme: ElevatedButtonThemeData(
			style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
		),
	);

	static ThemeData dark = ThemeData(
		useMaterial3: true,
		colorScheme: ColorScheme.fromSeed(
			seedColor: AppColors.primary,
			brightness: Brightness.dark,
			surface: AppColors.backgroundDark,
		).copyWith(
			primary: AppColors.primary,
			secondary: AppColors.secondary,
			tertiary: AppColors.accent,
			error: AppColors.error,
		),
		scaffoldBackgroundColor: AppColors.backgroundDark,
		snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
		inputDecorationTheme: const InputDecorationTheme(
			border: OutlineInputBorder(),
		),
		elevatedButtonTheme: ElevatedButtonThemeData(
			style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
		),
	);
}

