import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'sync_change_publisher.dart';
import 'sync_map_store.dart';

class FirestorePullService {
  const FirestorePullService(this._database, this._firestore, this._mapStore);

  final AppDatabase _database;
  final FirebaseFirestore _firestore;
  final SyncMapStore _mapStore;

  Future<void> pullAll() async {
    await _pullStations();
    await _pullStationInfo();
    await _pullMaintenance();
    await _replaceMappedCollections();
    await _database.setMeta('last_pull_at', DateTime.now().toIso8601String());
  }

  Future<void> _pullStations() async {
    final snapshot = await _firestore.collection(SyncEntity.stations).get();
    for (final document in snapshot.docs) {
      final data = document.data();
      await _database.db.insert('stations', {
        'number': document.id,
        'name': data['name'] ?? '',
        'address': data['address'] ?? '',
        'lat': data['lat'],
        'lon': data['lon'],
        'region': data['region'] ?? '',
        'geocode_status': (data['geocode_status'] as num?)?.toInt() ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _putMap(SyncEntity.stations, document.id, document.id);
    }
  }

  Future<void> _pullStationInfo() async {
    final snapshot = await _firestore.collection(SyncEntity.stationInfo).get();
    for (final document in snapshot.docs) {
      final data = document.data();
      await _database.db.insert('station_info', {
        'station_number': document.id,
        'manager_contact': data['manager_contact'] ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _putMap(SyncEntity.stationInfo, document.id, document.id);
    }
  }

  Future<void> _pullMaintenance() async {
    final snapshot = await _firestore.collection(SyncEntity.maintenance).get();
    if (snapshot.docs.isEmpty) return;

    await _database.db.delete('maintenance');
    await _mapStore.clearEntity(SyncEntity.maintenance);
    for (final document in snapshot.docs) {
      final data = document.data();
      final stationNumber =
          (data['station_number'] as String?) ?? document.id.split('_').first;
      final month =
          (data['month'] as String?) ??
          (document.id.contains('_')
              ? document.id.substring(document.id.indexOf('_') + 1)
              : '');
      if (stationNumber.isEmpty || month.isEmpty) continue;
      final localPk = '${stationNumber}_$month';
      await _database.db.insert('maintenance', {
        'station_number': stationNumber,
        'month': month,
        'status': data['status'] ?? 'pending',
        'date_done': data['date_done'],
        'to_type': data['to_type'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _putMap(SyncEntity.maintenance, localPk, document.id);
    }
  }

  Future<void> _replaceMappedCollections() async {
    await _replaceMappedCollection(
      entity: SyncEntity.requests,
      table: 'requests',
      buildRow: (_, data) => {
        'station_number': data['station_number'],
        'type': data['type'] ?? 'НЗ',
        'request_type': data['request_type'] ?? '',
        'description': data['description'] ?? '',
        'date_created': data['date_created'] ?? '',
        'status': data['status'] ?? 'open',
        'close_comment': data['close_comment'],
        'close_date': data['close_date'],
      },
    );
    await _replaceMappedCollection(
      entity: SyncEntity.stationEquipment,
      table: 'station_equipment',
      buildRow: (_, data) => {
        'station_number': data['station_number'],
        'category': data['category'] ?? '',
        'description': data['description'] ?? '',
      },
    );
    await _replaceMappedCollection(
      entity: SyncEntity.defectActs,
      table: 'defect_acts',
      buildRow: (_, data) => {
        'station_number': data['station_number'],
        'created_at': data['created_at'] ?? '',
        'equipment_category': data['equipment_category'] ?? '',
        'equipment_name': data['equipment_name'] ?? '',
        'assessment': data['assessment'] ?? '',
        'declared_fault': data['declared_fault'] ?? '',
        'faulty': data['faulty'] ?? '',
        'conclusion': data['conclusion'] ?? '',
        'rendered_text': data['rendered_text'] ?? '',
      },
    );
    await _replaceMappedCollection(
      entity: SyncEntity.equipmentOrderExports,
      table: 'equipment_order_exports',
      buildRow: (_, data) => {
        'region': data['region'] ?? '',
        'export_date': data['export_date'] ?? '',
        'request_id': data['request_id'] ?? 0,
      },
    );
  }

  Future<void> _replaceMappedCollection({
    required String entity,
    required String table,
    required Map<String, Object?> Function(
      String remoteId,
      Map<String, dynamic> data,
    )
    buildRow,
  }) async {
    final snapshot = await _firestore.collection(entity).get();
    if (snapshot.docs.isEmpty) return;

    await _database.db.delete(table);
    await _mapStore.clearEntity(entity);
    for (final document in snapshot.docs) {
      final row = buildRow(document.id, document.data());
      final localId = await _database.db.insert(table, row);
      await _putMap(entity, '$localId', document.id);
    }
  }

  Future<void> _putMap(String entity, String localId, String remoteId) {
    return _mapStore.put(
      entity: entity,
      localId: localId,
      remoteId: remoteId,
    );
  }
}
