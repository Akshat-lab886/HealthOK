import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:core_domain/core_domain.dart';

part 'database.g.dart';

/// Drift table for health samples.
@DataClassName('SampleRow')
class Samples extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // HealthDataType name
  IntColumn get startAt => integer()();
  IntColumn get endAt => integer()();
  RealColumn get value => real().nullable()();
  TextColumn get metadata => text().nullable()();
  TextColumn get sourceId => text()(); // Source.id
  TextColumn get externalId => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {type, startAt, endAt, sourceId, value}
      ];
}

/// Drift table for sync state (anchors/cursors).
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  TextColumn get id => text()(); // composite key
  TextColumn get type => text()(); // HealthDataType name
  TextColumn get sourceId => text()(); // Source.id
  TextColumn get anchor => text().nullable()();
  IntColumn get lastPulledAt => integer()();

  @override
  Set<Column>? get primaryKey => {id};
}

@DriftDatabase(
  tables: [Samples, SyncStates],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // V1→V2: recreate samples table with correct constraints
          if (from < 2) {
            await m.deleteTable('samples');
            await m.createTable(samples);
          }
        },
      );

  /// Opens (or creates) the on-device database using drift_flutter,
  /// which wires sqlite3 and the native libraries automatically.
  static AppDatabase? _cache;

  static Future<AppDatabase> open() async {
    if (_cache != null) return _cache!;
    _cache = AppDatabase(driftDatabase(name: 'healthok'));
    return _cache!;
  }
}