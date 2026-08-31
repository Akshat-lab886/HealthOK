import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_notifier.dart';

/// Persistent app settings (theme, notifications, onboarding state).
class AppSettings {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences? getPrefs() => _prefs;

  // ─── Theme ───────────────────────────────────────────────
  static const _kThemeMode = 'theme_mode';

  static ThemeMode getThemeMode() {
    final v = _prefs?.getString(_kThemeMode) ?? 'system';
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final v = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _prefs?.setString(_kThemeMode, v);
    AppSettingsNotifier.instance.themeMode.value = mode;
  }

  // ─── Onboarding ─────────────────────────────────────────
  static const _kOnboardingDone = 'onboarding_done';

  static bool isOnboardingDone() => _prefs?.getBool(_kOnboardingDone) ?? false;

  static Future<void> setOnboardingDone(bool v) async {
    await _prefs?.setBool(_kOnboardingDone, v);
  }

  // ─── Coach Personality ──────────────────────────────────
  static const _kPersonality = 'coach_personality';

  static String getCoachPersonality() => _prefs?.getString(_kPersonality) ?? 'motivational';

  static Future<void> setCoachPersonality(String v) async {
    await _prefs?.setString(_kPersonality, v);
  }

  // ─── Hydration notifications ────────────────────────────
  static const _kHydrationNotifs = 'hydration_notifs';

  static bool getHydrationNotifs() => _prefs?.getBool(_kHydrationNotifs) ?? true;

  static Future<void> setHydrationNotifs(bool v) async {
    await _prefs?.setBool(_kHydrationNotifs, v);
  }

  // ─── Streak-at-risk notifications ───────────────────────
  static const _kStreakNotifs = 'streak_notifs';

  static bool getStreakNotifs() => _prefs?.getBool(_kStreakNotifs) ?? true;

  static Future<void> setStreakNotifs(bool v) async {
    await _prefs?.setBool(_kStreakNotifs, v);
  }

  // ─── Voice input ────────────────────────────────────────
  static const _kVoiceEnabled = 'voice_enabled';

  static bool getVoiceEnabled() => _prefs?.getBool(_kVoiceEnabled) ?? false;

  static Future<void> setVoiceEnabled(bool v) async {
    await _prefs?.setBool(_kVoiceEnabled, v);
  }

  // ─── Morning briefing ───────────────────────────────────
  static const _kBriefingEnabled = 'briefing_enabled';

  static bool getBriefingEnabled() => _prefs?.getBool(_kBriefingEnabled) ?? true;

  static Future<void> setBriefingEnabled(bool v) async {
    await _prefs?.setBool(_kBriefingEnabled, v);
  }

  // ─── Gemini API Key ────────────────────────────────────
  static const _kGeminiApiKey = 'gemini_api_key';
  static const _kGeminiEnabled = 'gemini_enabled';

  static String getGeminiApiKey() => _prefs?.getString(_kGeminiApiKey) ?? '';
  static bool getGeminiEnabled() => _prefs?.getBool(_kGeminiEnabled) ?? false;

  static Future<void> setGeminiApiKey(String key) async {
    await _prefs?.setString(_kGeminiApiKey, key);
  }

  static Future<void> setGeminiEnabled(bool v) async {
    await _prefs?.setBool(_kGeminiEnabled, v);
  }
}
