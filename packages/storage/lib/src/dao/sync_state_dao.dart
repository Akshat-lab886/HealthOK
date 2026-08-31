import 'package:drift/drift.dart';
import '../database.dart';
import 'package:core_domain/core_domain.dart';

extension SyncStateDao on AppDatabase {
  Future<SyncState?> getSyncState(HealthDataType type, Source source) async {
    final row = await (select(syncStates)
      ..where((tbl) => tbl.id.equals('${type.name}_${source.id}'))
    ).getSingleOrNull();
    if (row == null) return null;
    return SyncState(
      id: row.id,
      type: HealthDataType.values.firstWhere((e) => e.name == row.type),
      source: Source(id: row.sourceId, displayName: row.sourceId),
      anchor: row.anchor,
      lastPulledAt: DateTime.fromMillisecondsSinceEpoch(row.lastPulledAt),
    );
  }

  Future<void> upsertSyncState(SyncState state) async {
    await into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion(
        id: Value(state.id),
        type: Value(state.type.name),
        sourceId: Value(state.source.id),
        anchor: Value(state.anchor),
        lastPulledAt: Value(state.lastPulledAt.millisecondsSinceEpoch),
      ),
    );
  }
}