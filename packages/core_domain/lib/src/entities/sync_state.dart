import '../value_objects/health_data_type.dart';
import '../value_objects/source.dart';

/// Tracks the last sync token/cursor for a data type and source.
class SyncState {
  final String id;
  final HealthDataType type;
  final Source source;
  final String? anchor; // opaque token from platform
  final DateTime lastPulledAt;

  const SyncState({
    required this.id,
    required this.type,
    required this.source,
    this.anchor,
    required this.lastPulledAt,
  });

  factory SyncState.create({
    required HealthDataType type,
    required Source source,
    String? anchor,
  }) {
    return SyncState(
      id: '${type.name}_${source.id}',
      type: type,
      source: source,
      anchor: anchor,
      lastPulledAt: DateTime.now(),
    );
  }
}