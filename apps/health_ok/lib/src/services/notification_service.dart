import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages local notifications for daily reminders, streak alerts, etc.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize the notification plugin and request permissions.
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Request notification permission on Android 13+
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Schedule the daily quest reminder (default: 8 AM every day).
  static Future<void> scheduleDailyQuestReminder() async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'daily_quest',
      'Daily Quest',
      channelDescription: 'Reminders for your daily quest',
      importance: Importance.high,
      priority: Priority.high,
    );

    final scheduled = _nextInstanceOfTime(8, 0);

    try {
      await _plugin.zonedSchedule(
        1,
        '⚔️ Daily Quest Awaits',
        'The System has prepared your daily quest. Tap to view.',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
    }
  }

  /// Schedule the briefing reminder for 7:00 AM (repeats daily).
  static Future<void> scheduleBriefingReminder() async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'daily_briefing',
      'Morning Briefing',
      channelDescription: 'Your daily AI System briefing',
      importance: Importance.high,
      priority: Priority.high,
    );

    final scheduled = _nextInstanceOfTime(7, 0);

    try {
      await _plugin.zonedSchedule(
        7,
        '📡 System Briefing Awaits',
        'Your daily briefing from The System is ready. Tap to read.',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {}
  }

  /// Cancel only the briefing reminder (id 7).
  static Future<void> cancelBriefingReminder() async {
    if (!_initialized) await init();
    await _plugin.cancel(7);
  }

  /// Show a streak protection alert (1 hour before midnight if streak at risk).
  static Future<void> showStreakAlert(int currentStreak) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'streak_alert',
      'Streak Alert',
      channelDescription: 'Alerts when your streak is at risk',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      2,
      '🔥 Streak at Risk!',
      'Your $currentStreak-day streak will break at midnight. Complete a quest now!',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Show a quest objective completed notification.
  static Future<void> showObjectiveCompleted(String label, int xp) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'quest_progress',
      'Quest Progress',
      channelDescription: 'Notifications for quest completions',
      importance: Importance.defaultImportance,
    );

    await _plugin.show(
      3,
      '⚡ Objective Complete!',
      '$label — +$xp XP earned',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Show a perfect day bonus notification.
  static Future<void> showPerfectDay() async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'quest_progress',
      'Quest Progress',
      channelDescription: 'Notifications for quest completions',
      importance: Importance.high,
    );

    await _plugin.show(
      4,
      '⭐ Perfect Day!',
      'All objectives cleared. +10 bonus XP. The System acknowledges your resolve.',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Show a level-up notification.
  static Future<void> showLevelUp(int newLevel) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'level_up',
      'Level Up',
      channelDescription: 'Notifications when you level up',
      importance: Importance.high,
    );

    await _plugin.show(
      5,
      '🎉 LEVEL UP!',
      'You are now Level $newLevel. +3 stat points available.',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Schedule periodic hydration reminders (default: every 2 hours from 8 AM to 8 PM).
  static Future<void> scheduleHydrationReminders({int intervalHours = 2}) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'hydration_reminder',
      'Hydration Reminder',
      channelDescription: 'Periodic reminders to drink water',
      importance: Importance.defaultImportance,
    );

    final now = DateTime.now();
    int id = 10;
    for (int hour = 8; hour <= 20; hour += intervalHours) {
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      try {
        await _plugin.zonedSchedule(
          id++,
          '💧 Time to hydrate',
          'A small sip keeps the system running. Stay sharp, hunter.',
          scheduled,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
      }
    }
  }

  /// Schedule a streak-at-risk notification for tonight at 10 PM if streak is at risk.
  static Future<void> scheduleStreakAtRisk(int currentStreak) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'streak_alert',
      'Streak Alert',
      channelDescription: 'Alerts when your streak is at risk',
      importance: Importance.high,
      priority: Priority.high,
    );

    final now = DateTime.now();
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 22, 0);
    if (scheduled.isBefore(now)) {
      return; // Too late today, no point scheduling
    }

    try {
      await _plugin.zonedSchedule(
        20,
        '🔥 Streak at Risk!',
        'Your $currentStreak-day streak breaks at midnight. Complete a quest now!',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
    }
  }

  /// Cancel all scheduled notifications.
  static Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
