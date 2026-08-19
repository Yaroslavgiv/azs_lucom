import '../database/app_database.dart';
import '../models/defect_act.dart';
import '../services/sync_change_publisher.dart';

class DefectActRepository {
  DefectActRepository(this._db, {SyncChangePublisher? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  Future<List<DefectAct>> listByStation(String stationNumber) async {
    final rows = await _db.db.query(
      'defect_acts',
      where: 'station_number = ?',
      whereArgs: [stationNumber],
      orderBy: 'datetime(created_at) DESC, id DESC',
    );
    return rows.map(DefectAct.fromMap).toList();
  }

  Future<List<DefectAct>> listAll() async {
    final rows = await _db.db.query(
      'defect_acts',
      orderBy: 'datetime(created_at) DESC, id DESC',
    );
    return rows.map(DefectAct.fromMap).toList();
  }

  Future<int> create({
    required String stationNumber,
    required DateTime createdAt,
    required String equipmentCategory,
    required String equipmentName,
    required String assessment,
    required String declaredFault,
    required String faulty,
    required String conclusion,
    required String renderedText,
  }) async {
    final act = DefectAct(
      id: 0,
      stationNumber: stationNumber,
      createdAt: createdAt,
      equipmentCategory: equipmentCategory,
      equipmentName: equipmentName,
      assessment: assessment,
      declaredFault: declaredFault,
      faulty: faulty,
      conclusion: conclusion,
      renderedText: renderedText,
    );
    final id = await _db.db.insert('defect_acts', act.toInsertMap());
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(entity: SyncEntity.defectActs, localPk: '$id');
    }
    return id;
  }

  Future<void> deleteById(int id) async {
    await _db.db.delete('defect_acts', where: 'id = ?', whereArgs: [id]);
    final sync = _sync;
    if (sync != null) {
      await sync.publishDelete(entity: SyncEntity.defectActs, localPk: '$id');
    }
  }

  Future<void> updateRenderedText({
    required int id,
    required String renderedText,
  }) async {
    await _db.db.update(
      'defect_acts',
      {'rendered_text': renderedText},
      where: 'id = ?',
      whereArgs: [id],
    );
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(entity: SyncEntity.defectActs, localPk: '$id');
    }
  }
}
