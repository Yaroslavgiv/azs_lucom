import 'package:azs_domain/azs_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../services/ids.dart';
import '../services/sync_change_publisher.dart';

class ContractRuleDenied implements Exception {
  ContractRuleDenied(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContractRuleRepository {
  const ContractRuleRepository(this._db, {SyncChangePublisher? sync})
    : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  Future<List<ContractRule>> activeRules() async {
    final rows = await _db.db.query(
      'contract_rules',
      where: 'active = 1',
      orderBy: 'category',
    );
    return rows.map(_rule).toList();
  }

  Future<ContractRule> publishVersion({
    required AccessSubject actor,
    required String category,
    int? durationHours,
    required bool requiresReview,
    DateTime? effectiveFrom,
  }) async {
    if (!actor.active || actor.role != AppRole.admin) {
      throw ContractRuleDenied('Правила договора меняет администратор');
    }
    final denial = validateContractRule(
      category: category,
      durationHours: durationHours,
    );
    if (denial != null) throw ContractRuleDenied(denial);
    final normalized = category.trim();
    final existing = await _db.db.query(
      'contract_rules',
      where: 'category = ?',
      whereArgs: [normalized],
    );
    final version = nextContractRuleVersion(
      existing.map((row) => (row['version'] as int?) ?? 1),
    );
    final now = (effectiveFrom ?? DateTime.now()).toUtc().toIso8601String();
    final id = '$normalized:$version';
    await _db.db.update(
      'contract_rules',
      {'active': 0},
      where: 'category = ? AND active = 1',
      whereArgs: [normalized],
    );
    for (final row in existing) {
      if ((row['active'] as int? ?? 0) == 1) {
        await _publish('${row['id']}');
      }
    }
    await _db.db.insert('contract_rules', {
      'id': id,
      'category': normalized,
      'duration_hours': durationHours,
      'requires_review': requiresReview ? 1 : 0,
      'effective_from': now,
      'version': version,
      'active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.db.insert('audit_events', {
      'id': newUuid(),
      'actor_id': actor.userId,
      'entity_type': 'contract_rule',
      'entity_id': id,
      'action': 'publish',
      'new_value': durationHours?.toString() ?? '',
      'created_at': now,
    });
    await _publish(id);
    return ContractRule(
      category: normalized,
      version: version,
      durationHours: durationHours,
      requiresReview: requiresReview,
    );
  }

  Future<void> _publish(String id) async {
    final sync = _sync;
    if (sync == null) return;
    await sync.publishUpsert(entity: SyncEntity.contractRules, localPk: id);
  }

  ContractRule _rule(Map<String, Object?> row) {
    return ContractRule(
      category: row['category'] as String? ?? '',
      version: (row['version'] as int?) ?? 1,
      durationHours: row['duration_hours'] as int?,
      requiresReview: (row['requires_review'] as int? ?? 0) == 1,
      active: (row['active'] as int? ?? 0) == 1,
    );
  }
}
