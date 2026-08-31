import 'package:flutter/material.dart';

/// Global app settings notifier.
class AppSettingsNotifier {
  static final AppSettingsNotifier instance = AppSettingsNotifier._();
  AppSettingsNotifier._();

  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
}
