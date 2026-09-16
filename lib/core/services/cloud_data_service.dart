import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants.dart';
import '../domain/maintenance_lifecycle.dart';
import '../domain/request_status.dart';
import '../domain/time_period.dart';
import '../models/audit_event.dart';
import '../models/maintenance_report.dart';
import '../models/request_item.dart';
import '../models/station.dart';
import '../repositories/station_info_repository.dart';
import 'sync_change_publisher.dart';

class OverviewSnapshot {
  const OverviewSnapshot({
    required this.acceptedMaintenance,
    required this.remainingMaintenance,
    required this.openRequests,
    required this.overdueCount,
    required this.attention,
  });

  final int acceptedMaintenance;
  final int remainingMaintenance;
  final int openRequests;
  final int overdueCount;
  final List<AttentionItem> attention;
}

class AttentionItem {
  const AttentionItem({
    required this.stationNumber,
    required this.reason,
    required this.assigneeName,
    required this.dueDate,
  });

  final String stationNumber;
  final String reason;
  final String assigneeName;
  final String dueDate;
}

class CloudDataService {
  CloudDataService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<Station>> stations({String? region}) async {
    Query<Map<String, dynamic>> query = _firestore.collection(
      SyncEntity.stations,
    );
    if (region != null) {
      query = query.where('region', isEqualTo: region);
    }
    final snapshot = await query.get();
    final stations = snapshot.docs.map(_stationFrom).toList();
    stations.sort(
      (a, b) =>
          (int.tryParse(a.number) ?? 0).compareTo(int.tryParse(b.number) ?? 0),
    );
    return stations;
  }

  Future<Station?> station(String number) async {
    final snapshot = await _firestore
        .collection(SyncEntity.stations)
        .doc(number)
        .get();
    if (!snapshot.exists) return null;
    return _stationFrom(snapshot);
  }

  Future<List<RequestItem>> requests({
    String? region,
    String? status,
    String? assigneeId,
    bool activeOnly = false,
  }) async {
    final snapshot = await _firestore.collection(SyncEntity.requests).get();
    final stations = {
      for (final station in await this.stations()) station.number: station,
    };
    var items = snapshot.docs.map(_requestFrom).toList();
    if (region != null) {
      items = items
          .where((item) => stations[item.stationNumber]?.region == region)
          .toList();
    }
    if (status != null) {
      items = items.where((item) => item.status == status).toList();
    } else if (activeOnly) {
      items = items.where((item) => item.isActive).toList();
    }
    if (assigneeId != null) {
      items = items.where((item) => item.assigneeId == assigneeId).toList();
    }
    items.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    return items;
  }

  Future<void> createRequest({
    required String stationNumber,
    required String requestType,
    required String description,
    String? actorId,
  }) async {
    await _firestore.collection(SyncEntity.requests).add({
      'station_number': stationNumber,
      'type': 'НЗ',
      'request_type': requestType,
      'description': description,
      'date_created': currentDateIso(),
      'status': RequestStatus.created,
      'updated_by': actorId,
      'updated_at': FieldValue.serverTimestamp(),
      'version': 1,
    });
  }

  Future<void> assignRequest({
    required String requestId,
    required String assigneeId,
    required String assigneeName,
    required String dueDate,
    String? actorId,
    String? actorName,
  }) async {
    await _firestore.collection(SyncEntity.requests).doc(requestId).set({
      'assignee_id': assigneeId,
      'assignee_name': assigneeName,
      'due_date': dueDate,
      'status': RequestStatus.assigned,
      'updated_by': actorId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _audit(
      action: AuditAction.assignRequest,
      entity: SyncEntity.requests,
      entityId: requestId,
      actorId: actorId ?? '',
      actorName: actorName ?? '',
      summary: 'Назначен $assigneeName, срок $dueDate',
    );
  }

  Future<List<MaintenanceRecord>> maintenanceForMonth(String month) async {
    final snapshot = await _firestore
        .collection(SyncEntity.maintenance)
        .where('month', isEqualTo: month)
        .get();
    return snapshot.docs.map(_maintenanceFrom).toList();
  }

  Future<void> assignMaintenance({
    required String stationNumber,
    required String month,
    required String assigneeId,
    required String assigneeName,
    String? dueDate,
    String? actorId,
  }) async {
    await _firestore
        .collection(SyncEntity.maintenance)
        .doc('${stationNumber}_$month')
        .set({
          'station_number': stationNumber,
          'month': month,
          'status': MaintenanceLifecycle.planned,
          'assignee_id': assigneeId,
          'assignee_name': assigneeName,
          'due_date': dueDate,
          'updated_by': actorId,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<List<EquipmentItem>> equipmentForStation(String stationNumber) async {
    final snapshot = await _firestore
        .collection(SyncEntity.stationEquipment)
        .where('station_number', isEqualTo: stationNumber)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id.hashCode;
      return EquipmentItem.fromMap(data.cast<String, Object?>());
    }).toList();
  }

  Future<void> addEquipment({
    required String stationNumber,
    required String category,
    required String description,
    int quantity = 1,
    String serialNumber = '',
    String condition = 'Исправно',
    String? actorId,
    String? actorName,
  }) async {
    await _firestore.collection(SyncEntity.stationEquipment).add({
      'station_number': stationNumber,
      'category': category,
      'description': description,
      'quantity': quantity,
      'serial_number': serialNumber,
      'condition': condition,
      'updated_by': actorId,
      'updated_at': FieldValue.serverTimestamp(),
    });
    await _audit(
      action: AuditAction.updateCatalog,
      entity: SyncEntity.stationEquipment,
      entityId: stationNumber,
      actorId: actorId ?? '',
      actorName: actorName ?? '',
      summary: 'Добавлено оборудование: $description',
    );
  }

  Future<List<AuditEvent>> historyForStation(String stationNumber) async {
    final snapshot = await _firestore
        .collection(SyncEntity.auditLog)
        .where('entity_id', isGreaterThanOrEqualTo: stationNumber)
        .limit(50)
        .get();
    final events = snapshot.docs
        .map((doc) => AuditEvent.fromMap(doc.data().cast<String, Object?>()))
        .where(
          (event) =>
              event.entityId == stationNumber ||
              event.entityId.startsWith('${stationNumber}_'),
        )
        .toList();
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return events;
  }

  Future<OverviewSnapshot> overview({String? region}) async {
    final month = currentMonthIso();
    final stations = await this.stations(region: region);
    final maintenance = await maintenanceForMonth(month);
    final byStation = {
      for (final item in maintenance) item.stationNumber: item,
    };
    final requestItems = await requests(region: region, activeOnly: true);
    var accepted = 0;
    var remaining = 0;
    var overdue = 0;
    final attention = <AttentionItem>[];
    for (final station in stations) {
      final record = byStation[station.number];
      if (record != null && record.isAccepted) {
        accepted++;
      } else {
        remaining++;
      }
      final stationRequests = requestItems
          .where((item) => item.stationNumber == station.number)
          .toList();
      final overdueRequest = stationRequests.any(
        (item) =>
            item.status == RequestStatus.overdue ||
            isDueDateOverdue(item.dueDate),
      );
      if (record?.status == MaintenanceLifecycle.returned ||
          (record?.dueDate != null && isDueDateOverdue(record!.dueDate))) {
        overdue++;
        attention.add(
          AttentionItem(
            stationNumber: station.number,
            reason: record?.status == MaintenanceLifecycle.returned
                ? 'Возвращено ТО'
                : 'Просрочено ТО',
            assigneeName: record?.assigneeName ?? '—',
            dueDate: record?.dueDate ?? '—',
          ),
        );
      } else if (record?.status == MaintenanceLifecycle.inReview) {
        attention.add(
          AttentionItem(
            stationNumber: station.number,
            reason: 'ТО на проверке',
            assigneeName: record?.assigneeName ?? '—',
            dueDate: record?.dueDate ?? '—',
          ),
        );
      } else if (overdueRequest ||
          stationRequests.any((item) => item.isCritical)) {
        overdue++;
        final item = stationRequests.first;
        attention.add(
          AttentionItem(
            stationNumber: station.number,
            reason: item.isCritical ? 'Неисправность' : 'Просрочена заявка',
            assigneeName: item.assigneeName ?? 'Не назначен',
            dueDate: item.dueDate ?? '—',
          ),
        );
      }
    }
    return OverviewSnapshot(
      acceptedMaintenance: accepted,
      remainingMaintenance: remaining,
      openRequests: requestItems.length,
      overdueCount: overdue,
      attention: attention.take(12).toList(),
    );
  }

  Future<List<Map<String, Object?>>> requestExportRows({
    String? region,
    String? status,
    String? assigneeId,
  }) async {
    final items = await requests(
      region: region,
      status: status,
      assigneeId: assigneeId,
      activeOnly: status == null,
    );
    final stations = {
      for (final station in await this.stations()) station.number: station,
    };
    return [
      for (final item in items)
        {
          'region': stations[item.stationNumber]?.region ?? '',
          'station_number': item.stationNumber,
          'type': item.type,
          'request_type': item.requestType,
          'description': item.description,
          'date_created': item.dateCreated,
          'status': RequestStatus.label(item.status),
          'assignee_name': item.assigneeName ?? '',
          'due_date': item.dueDate ?? '',
        },
    ];
  }

  Future<List<Map<String, Object?>>> maintenanceExportRows({
    String? region,
    String? status,
  }) async {
    final month = currentMonthIso();
    final stations = await this.stations(region: region);
    final records = {
      for (final item in await maintenanceForMonth(month))
        item.stationNumber: item,
    };
    return [
      for (final station in stations)
        if (status == null ||
            MaintenanceLifecycle.normalize(records[station.number]?.status) ==
                status)
          {
            'region': station.region,
            'station_number': station.number,
            'name': station.name,
            'address': station.address,
            'status': records[station.number]?.isAccepted == true
                ? 'выполнено $month'
                : MaintenanceLifecycle.label(records[station.number]?.status),
            'date_done': records[station.number]?.dateDone ?? '',
            'assignee_name': records[station.number]?.assigneeName ?? '',
            'result': records[station.number]?.isAccepted == true
                ? 'Принято'
                : MaintenanceLifecycle.label(records[station.number]?.status),
          },
    ];
  }

  Station _stationFrom(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Station(
      number: doc.id,
      name: (data['name'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      region: (data['region'] as String?) ?? regionSpb,
      lat: (data['lat'] as num?)?.toDouble(),
      lon: (data['lon'] as num?)?.toDouble(),
      geocodeStatus: (data['geocode_status'] as num?)?.toInt() ?? 0,
    );
  }

  RequestItem _requestFrom(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, Object?>.from(doc.data());
    data['id'] = doc.id.hashCode;
    data['remote_id'] = doc.id;
    return RequestItem.fromMap(data);
  }

  MaintenanceRecord _maintenanceFrom(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, Object?>.from(doc.data());
    return MaintenanceRecord.fromMap(data);
  }

  Future<void> _audit({
    required String action,
    required String entity,
    required String entityId,
    required String actorId,
    required String actorName,
    required String summary,
  }) async {
    await _firestore.collection(SyncEntity.auditLog).add({
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'actor_id': actorId,
      'actor_name': actorName,
      'created_at': DateTime.now().toIso8601String(),
      'summary': summary,
      'payload': <String, Object?>{},
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
