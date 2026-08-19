import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/app_database.dart';
import 'sync_change_publisher.dart';
import 'sync_map_store.dart';

class FirestoreCloudSeeder {
  const FirestoreCloudSeeder(this._database, this._firestore, this._mapStore);

  final AppDatabase _database;
  final FirebaseFirestore _firestore;
  final SyncMapStore _mapStore;

  Future<bool> seedEmptyCollections() async {
    final results = await Future.wait([
      _seedStations(),
      _seedStationInfo(),
      _seedMaintenance(),
      _seedMappedCollection(SyncEntity.requests, 'requests'),
      _seedMappedCollection(SyncEntity.stationEquipment, 'station_equipment'),
      _seedMappedCollection(SyncEntity.defectActs, 'defect_acts'),
      _seedMappedCollection(
        SyncEntity.equipmentOrderExports,
        'equipment_order_exports',
      ),
    ]);
    final uploaded = results.any((result) => result);
    if (uploaded) await _database.setMeta('cloud_seeded', '1');
    return uploaded;
  }

  Future<bool> _seedStations() async {
    if (!await _isCollectionEmpty(SyncEntity.stations)) return false;
    final rows = await _database.db.query('stations');
    for (final row in rows) {
      final number = row['number'] as String;
      await _firestore.collection(SyncEntity.stations).doc(number).set({
        'name': row['name'] ?? '',
        'address': row['address'] ?? '',
        'lat': row['lat'],
        'lon': row['lon'],
        'region': row['region'] ?? '',
        'geocode_status': row['geocode_status'] ?? 0,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _putMap(SyncEntity.stations, number, number);
    }
    return rows.isNotEmpty;
  }

  Future<bool> _seedStationInfo() async {
    if (!await _isCollectionEmpty(SyncEntity.stationInfo)) return false;
    final rows = await _database.db.query('station_info');
    for (final row in rows) {
      final stationNumber = row['station_number'] as String;
      await _firestore
          .collection(SyncEntity.stationInfo)
          .doc(stationNumber)
          .set({
            'manager_contact': row['manager_contact'] ?? '',
            'updated_at': FieldValue.serverTimestamp(),
          });
      await _putMap(SyncEntity.stationInfo, stationNumber, stationNumber);
    }
    return rows.isNotEmpty;
  }

  Future<bool> _seedMaintenance() async {
    if (!await _isCollectionEmpty(SyncEntity.maintenance)) return false;
    final rows = await _database.db.query('maintenance');
    for (final row in rows) {
      final stationNumber = row['station_number'] as String;
      final month = row['month'] as String;
      final id = '${stationNumber}_$month';
      await _firestore.collection(SyncEntity.maintenance).doc(id).set({
        'station_number': stationNumber,
        'month': month,
        'status': row['status'] ?? 'pending',
        'date_done': row['date_done'],
        'to_type': row['to_type'],
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _putMap(SyncEntity.maintenance, id, id);
    }
    return rows.isNotEmpty;
  }

  Future<bool> _seedMappedCollection(String entity, String table) async {
    if (!await _isCollectionEmpty(entity)) return false;
    final rows = await _database.db.query(table);
    for (final row in rows) {
      final localId = '${row['id']}';
      final data = Map<String, Object?>.from(row)..remove('id');
      data['updated_at'] = FieldValue.serverTimestamp();
      final document = await _firestore.collection(entity).add(data);
      await _putMap(entity, localId, document.id);
    }
    return rows.isNotEmpty;
  }

  Future<bool> _isCollectionEmpty(String entity) async {
    final snapshot = await _firestore.collection(entity).limit(1).get();
    return snapshot.docs.isEmpty;
  }

  Future<void> _putMap(String entity, String localId, String remoteId) {
    return _mapStore.put(entity: entity, localId: localId, remoteId: remoteId);
  }
}
