import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import 'package:core_domain/core_domain.dart';

extension SampleDao on AppDatabase {
  Future<void> insertSample(Sample sample) async {
    await into(samples).insert(
      SamplesCompanion(
        id: Value(sample.id),
        type: Value(sample.type.name),
        startAt: Value(sample.startAt.millisecondsSinceEpoch),
        endAt: Value(sample.endAt.millisecondsSinceEpoch),
        value: Value(sample.value),
        metadata: Value(sample.metadata != null ? jsonEncode(sample.metadata) : null),
        sourceId: Value(sample.source.id),
        externalId: Value(sample.externalId),
        createdAt: Value(sample.createdAt.millisecondsSinceEpoch),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> insertSamples(List<Sample> samplesList) async {
    await batch((batch) {
      for (final sample in samplesList) {
        batch.insert(
          samples,
          SamplesCompanion(
            id: Value(sample.id),
            type: Value(sample.type.name),
            startAt: Value(sample.startAt.millisecondsSinceEpoch),
            endAt: Value(sample.endAt.millisecondsSinceEpoch),
            value: Value(sample.value),
            metadata: Value(sample.metadata != null ? jsonEncode(sample.metadata) : null),
            sourceId: Value(sample.source.id),
            externalId: Value(sample.externalId),
            createdAt: Value(sample.createdAt.millisecondsSinceEpoch),
          ),
          onConflict: DoNothing(),
        );
      }
    });
  }

  Future<List<Sample>> getSamplesForType(
    HealthDataType type, {
    DateTime? from,
    DateTime? to,
  }) async {
    final query = select(samples)
      ..where((tbl) => tbl.type.equals(type.name));
    if (from != null) {
      query.where((tbl) => tbl.startAt.isBiggerOrEqualValue(from.millisecondsSinceEpoch));
    }
    if (to != null) {
      query.where((tbl) => tbl.startAt.isSmallerOrEqualValue(to.millisecondsSinceEpoch));
    }
    final rows = await query.get();
    return rows.map(_mapRowToSample).toList();
  }

  Future<int> getTotalStepsForInterval(DateTime from, DateTime to) async {
    final query = select(samples)
      ..where((tbl) => tbl.type.equals('steps'))
      ..where((tbl) => tbl.startAt.isBiggerOrEqualValue(from.millisecondsSinceEpoch))
      ..where((tbl) => tbl.startAt.isSmallerOrEqualValue(to.millisecondsSinceEpoch));
    final rows = await query.get();
    int total = 0;
    for (final row in rows) {
      total += (row.value?.toInt() ?? 0);
    }
    return total;
  }

  Future<List<Sample>> getTodayLocalSamples() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final query = select(samples)
      ..where((tbl) => tbl.startAt.isBiggerOrEqualValue(startOfToday.millisecondsSinceEpoch))
      ..where((tbl) => tbl.sourceId.equals('local'));
    final rows = await query.get();
    return rows.map(_mapRowToSample).toList();
  }

  Sample _mapRowToSample(SampleRow row) {
    return Sample(
      id: row.id,
      type: HealthDataType.values.firstWhere((e) => e.name == row.type),
      startAt: DateTime.fromMillisecondsSinceEpoch(row.startAt),
      endAt: DateTime.fromMillisecondsSinceEpoch(row.endAt),
      value: row.value,
      metadata: row.metadata != null ? jsonDecode(row.metadata!) as Map<String, dynamic> : null,
      source: Source(id: row.sourceId, displayName: row.sourceId),
      externalId: row.externalId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }
}