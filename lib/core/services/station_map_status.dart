import 'package:azs_domain/azs_domain.dart';

import '../database/app_database.dart';

class StationMapStatusService {
  const StationMapStatusService(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<Map<String, MapTone>> load() async {
    final current = moscowServiceMonth(_clock());
    final maintenance = await _db.db.query('maintenance');
    final requests = await _db.db.query('requests');
    final doneThisMonth = <String>{};
    final previousOverdue = <String>{};
    final contractualAttention = <String>{};
    final seen = <String>{};

    for (final row in maintenance) {
      final number = row['station_number'] as String;
      seen.add(number);
      final month = row['month'] as String? ?? '';
      final workflow = row['workflow_status'] as String?;
      final legacy = row['status'] as String?;
      if (month == current.key && maintenanceCountsAsDone(workflow, legacy)) {
        doneThisMonth.add(number);
      }
      if (isEarlierServiceMonth(month, current) &&
          !maintenanceCountsAsDone(workflow, legacy)) {
        previousOverdue.add(number);
      }
    }

    final now = _clock();
    for (final row in requests) {
      final number = row['station_number'] as String;
      seen.add(number);
      final workflow = (row['workflow_status'] as String?) ?? 'created';
      final open = legacyRequestStatus(workflow) != 'closed';
      if (!open) continue;
      if ((row['critical'] as int? ?? 0) == 1) {
        contractualAttention.add(number);
      }
      if (isOverdue(
        dueAt: DateTime.tryParse((row['due_at'] as String?) ?? ''),
        workflowStatus: workflow,
        now: now,
      )) {
        contractualAttention.add(number);
      }
    }

    return {
      for (final number in seen)
        number: resolveMapTone(
          MapStatusInput(
            maintenanceDoneThisMonth: doneThisMonth.contains(number),
            previousPeriodOverdue: previousOverdue.contains(number),
            contractualOverdueOrCritical: contractualAttention.contains(number),
          ),
        ),
    };
  }
}
