import '../../core_domain.dart';

/// A single health data point.
class Sample {
  final String id;
  final HealthDataType type;
  final DateTime startAt;
  final DateTime endAt;
  final double? value;
  final Map<String, dynamic>? metadata;
  final Source source;
  final String? externalId;
  final DateTime createdAt;

  const Sample({
    required this.id,
    required this.type,
    required this.startAt,
    required this.endAt,
    this.value,
    this.metadata,
    required this.source,
    this.externalId,
    required this.createdAt,
  });

  /// Creates a sample with a generated UUID.
  factory Sample.create({
    required HealthDataType type,
    required DateTime startAt,
    required DateTime endAt,
    double? value,
    Map<String, dynamic>? metadata,
    required Source source,
    String? externalId,
  }) {
    return Sample(
      id: '${DateTime.now().millisecondsSinceEpoch}_${type.name}_${source.id}_${startAt.millisecondsSinceEpoch}',
      type: type,
      startAt: startAt,
      endAt: endAt,
      value: value,
      metadata: metadata,
      source: source,
      externalId: externalId,
      createdAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Sample &&
      other.id == id;

  @override
  int get hashCode => id.hashCode;
}