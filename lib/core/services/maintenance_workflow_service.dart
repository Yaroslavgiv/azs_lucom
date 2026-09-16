import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/maintenance_lifecycle.dart';
import '../models/audit_event.dart';
import '../services/sync_change_publisher.dart';

class MaintenanceWorkflowService {
  MaintenanceWorkflowService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<void> accept({
    required String stationNumber,
    required String month,
    String comment = '',
    String? actorId,
    String? actorName,
  }) {
    return _review(
      callable: 'acceptMaintenance',
      status: MaintenanceLifecycle.accepted,
      action: AuditAction.acceptMaintenance,
      stationNumber: stationNumber,
      month: month,
      comment: comment,
      actorId: actorId,
      actorName: actorName,
    );
  }

  Future<void> returnForRevision({
    required String stationNumber,
    required String month,
    String comment = '',
    String? actorId,
    String? actorName,
  }) {
    return _review(
      callable: 'returnMaintenance',
      status: MaintenanceLifecycle.returned,
      action: AuditAction.returnMaintenance,
      stationNumber: stationNumber,
      month: month,
      comment: comment,
      actorId: actorId,
      actorName: actorName,
    );
  }

  Future<void> _review({
    required String callable,
    required String status,
    required String action,
    required String stationNumber,
    required String month,
    required String comment,
    String? actorId,
    String? actorName,
  }) async {
    try {
      await _functions.httpsCallable(callable).call({
        'stationNumber': stationNumber,
        'month': month,
        'comment': comment,
      });
      return;
    } catch (_) {
      await _writeDirect(
        stationNumber: stationNumber,
        month: month,
        status: status,
        comment: comment,
        actorId: actorId,
        actorName: actorName,
        action: action,
      );
    }
  }

  Future<void> _writeDirect({
    required String stationNumber,
    required String month,
    required String status,
    required String comment,
    required String action,
    String? actorId,
    String? actorName,
  }) async {
    final id = '${stationNumber}_$month';
    await _firestore.collection(SyncEntity.maintenance).doc(id).set({
      'station_number': stationNumber,
      'month': month,
      'status': status,
      'reviewed_by': actorId,
      'review_comment': comment,
      'updated_by': actorId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection(SyncEntity.auditLog).add({
      'action': action,
      'entity': SyncEntity.maintenance,
      'entity_id': id,
      'actor_id': actorId ?? '',
      'actor_name': actorName ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'summary': 'ТО АЗС $stationNumber за $month: $status',
      'payload': {'comment': comment},
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
