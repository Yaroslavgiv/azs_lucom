import 'package:azs_domain/azs_domain.dart';

import '../database/app_database.dart';

class StationMapStatusService {
  const StationMapStatusService(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<Map<String, MapTone>> load() async {
    final now = _clock();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final maintenance = await _db.db.query(
      'maintenance',
      where: 'month = ?',
      whereArgs: [month],
    );
    final requests = await _db.db.query('requests');
    final accepted = <String>{};
    final overdueStations = <String>{};
    for (final row in maintenance) {
      final number = row['station_number'] as String;
      final workflow = (row['workflow_status'] as String?) ?? 'planned';
      final legacyDone = row['status'] == 'done';
      if (workflow == 'accepted' || legacyDone) accepted.add(number);
      if (isOverdue(
        dueAt: DateTime.tryParse((row['due_at'] as String?) ?? ''),
        workflowStatus: workflow,
        now: now,
      )) {
        overdueStations.add(number);
      }
    }
    final critical = <String>{};
    for (final row in requests) {
      final number = row['station_number'] as String;
      final workflow = (row['workflow_status'] as String?) ?? 'created';
      final open =
          row['status'] != 'closed' &&
          workflow != 'accepted' &&
          workflow != 'cancelled';
      if (!open) continue;
      if ((row['critical'] as int? ?? 0) == 1) critical.add(number);
      if (isOverdue(
        dueAt: DateTime.tryParse((row['due_at'] as String?) ?? ''),
        workflowStatus: workflow,
        now: now,
      )) {
        overdueStations.add(number);
      }
    }
    final numbers = {...accepted, ...overdueStations, ...critical};
    return {
      for (final number in numbers)
        number: resolveMapTone(
          MapStatusInput(
            maintenanceAccepted: accepted.contains(number),
            overdue: overdueStations.contains(number),
            criticalRequest: critical.contains(number),
          ),
        ),
    };
  }
}
