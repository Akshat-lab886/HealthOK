import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BodyMeasurement {
  final DateTime date;
  final double weightKg;
  final double? bodyFatPct;
  final double? muscleKg;
  final double? waistCm;
  final double? chestCm;

  BodyMeasurement({
    required this.date,
    required this.weightKg,
    this.bodyFatPct,
    this.muscleKg,
    this.waistCm,
    this.chestCm,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weightKg,
        'fat': bodyFatPct,
        'muscle': muscleKg,
        'waist': waistCm,
        'chest': chestCm,
      };

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
        date: DateTime.parse(j['date'] as String),
        weightKg: (j['weight'] as num).toDouble(),
        bodyFatPct: j['fat'] == null ? null : (j['fat'] as num).toDouble(),
        muscleKg: j['muscle'] == null ? null : (j['muscle'] as num).toDouble(),
        waistCm: j['waist'] == null ? null : (j['waist'] as num).toDouble(),
        chestCm: j['chest'] == null ? null : (j['chest'] as num).toDouble(),
      );
}

class BodyService {
  static const _key = 'body_log_v1';
  static const _profileKey = 'body_profile_v1';

  static Future<List<BodyMeasurement>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(BodyMeasurement m) async {
    final list = await getAll();
    list.add(m);
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<void> delete(DateTime date) async {
    final list = await getAll();
    list.removeWhere((e) =>
        e.date.year == date.year && e.date.month == date.month && e.date.day == date.day);
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<BodyMeasurement?> getLatest() async {
    final list = await getAll();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.date.compareTo(a.date));
    return list.first;
  }

  // ─── User profile (personalization inputs) ────────────────────────

  /// Saves the personal profile used to personalize calories, hydration
  /// targets, stride-based distance estimates and quest difficulty.
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, json.encode(profile.toJson()));
  }

  static Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return const UserProfile();
    try {
      return UserProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  /// Latest known weight (falls back to profile weight, then 70 kg).
  static Future<double> effectiveWeightKg() async {
    final latest = await getLatest();
    if (latest != null) return latest.weightKg;
    final profile = await getProfile();
    return profile.weightKg ?? 70;
  }
}

/// Personal profile driving all per-user calculations.
class UserProfile {
  final double? weightKg;   // fallback when no measurement logged
  final double? heightCm;   // drives stride length + BMR
  final int? ageYears;      // drives BMR
  final String? sex;        // 'male' | 'female' | 'other'
  final String? activityLevel; // 'sedentary' | 'light' | 'moderate' | 'active' | 'athlete'

  const UserProfile({
    this.weightKg,
    this.heightCm,
    this.ageYears,
    this.sex,
    this.activityLevel,
  });

  UserProfile copyWith({
    double? weightKg,
    double? heightCm,
    int? ageYears,
    String? sex,
    String? activityLevel,
  }) =>
      UserProfile(
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        ageYears: ageYears ?? this.ageYears,
        sex: sex ?? this.sex,
        activityLevel: activityLevel ?? this.activityLevel,
      );

  Map<String, dynamic> toJson() => {
        'weightKg': weightKg,
        'heightCm': heightCm,
        'ageYears': ageYears,
        'sex': sex,
        'activityLevel': activityLevel,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        weightKg: j['weightKg'] == null ? null : (j['weightKg'] as num).toDouble(),
        heightCm: j['heightCm'] == null ? null : (j['heightCm'] as num).toDouble(),
        ageYears: j['ageYears'] == null ? null : (j['ageYears'] as num).toInt(),
        sex: j['sex'] as String?,
        activityLevel: j['activityLevel'] as String?,
      );

  /// Walking stride length in meters (height × 0.415; default 0.71 m).
  double strideLengthM() {
    final h = heightCm;
    if (h == null || h < 100 || h > 230) return 0.71;
    return h * 0.415 / 100.0;
  }

  /// Mifflin-St Jeor BMR (kcal/day). Falls back to weight-only estimate.
  double bmrKcal() {
    final w = weightKg ?? 70;
    final h = heightCm ?? 170;
    final a = ageYears ?? 30;
    if (sex == 'female') {
      return 10 * w + 6.25 * h - 5 * a - 161;
    }
    return 10 * w + 6.25 * h - 5 * a + 5;
  }

  /// TDEE estimate from BMR × activity multiplier.
  double tdeeKcal() {
    const mult = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'athlete': 1.9,
    };
    final m = mult[activityLevel] ?? 1.375;
    return bmrKcal() * m;
  }
}