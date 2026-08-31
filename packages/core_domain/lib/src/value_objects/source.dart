class Source {
  final String id;
  final String displayName;
  final String? platformKey;

  const Source({
    required this.id,
    required this.displayName,
    this.platformKey,
  });

  factory Source.local() => const Source(
    id: 'local',
    displayName: 'HealthOK',
  );

  factory Source.healthConnect() => const Source(
    id: 'health_connect',
    displayName: 'Health Connect',
    platformKey: 'com.google.android.apps.healthconnect',
  );

  factory Source.healthKit() => const Source(
    id: 'health_kit',
    displayName: 'HealthKit',
    platformKey: 'com.apple.health',
  );

  @override
  bool operator ==(Object other) =>
      other is Source && other.id == id;

  @override
  int get hashCode => id.hashCode;
}