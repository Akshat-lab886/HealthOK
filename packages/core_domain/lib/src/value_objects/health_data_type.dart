enum HealthDataType {
  steps,
  distance,
  activeEnergy,
  heartRate,
  hrvSdnn,
  hrvRmssd,
  sleep,
  // ... more as needed
}

extension HealthDataTypeExt on HealthDataType {
  String get displayName {
    switch (this) {
      case HealthDataType.steps:
        return 'Steps';
      case HealthDataType.distance:
        return 'Distance';
      case HealthDataType.activeEnergy:
        return 'Active Energy';
      case HealthDataType.heartRate:
        return 'Heart Rate';
      case HealthDataType.hrvSdnn:
        return 'HRV (SDNN)';
      case HealthDataType.hrvRmssd:
        return 'HRV (RMSSD)';
      case HealthDataType.sleep:
        return 'Sleep';
    }
  }
}