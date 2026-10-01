import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/station.dart';
import '../repositories/maintenance_repository.dart';
import '../services/equipment_seed_service.dart';
import '../services/manager_overview_service.dart';
import '../services/operational_data_seed_service.dart';
import '../services/station_seed_service.dart';
import '../services/sync_service.dart';
import 'auth_providers.dart';
import 'infrastructure_providers.dart';

export 'auth_providers.dart';
export 'infrastructure_providers.dart';

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

/// Инкремент для перезагрузки маркеров на карте (например, после отметки ТО).
final mapRefreshProvider = StateProvider<int>((ref) => 0);

final appInitProvider = FutureProvider<void>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final stations = await ref.watch(stationRepositoryProvider.future);
  await StationSeedService(db, stations).seedIfNeeded();
  await OperationalDataSeedService(db).seedIfNeeded();
  await EquipmentSeedService(db).seedIfNeeded();

  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return;

  // Sync must not block first frame — Firestore often hangs on emulators.
  final sync = await ref.watch(syncServiceProvider.future);
  unawaited(_runBackgroundSync(ref, sync));
});

Future<void> _runBackgroundSync(Ref ref, SyncService sync) async {
  ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
  try {
    await sync
        .seedCloudIfEmpty()
        .timeout(const Duration(seconds: 8), onTimeout: () => false);
    final status = await sync.pullAll();
    ref.read(syncStatusProvider.notifier).state = status;
  } catch (_) {
    ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
  }
}

final stationsByRegionProvider = FutureProvider.family<List<Station>, String>((
  ref,
  region,
) async {
  await ref.watch(appInitProvider.future);
  final repo = await ref.watch(stationRepositoryProvider.future);
  return repo.getByRegion(region);
});

final managerOverviewProvider = FutureProvider<ManagerOverviewStats>((
  ref,
) async {
  await ref.watch(appInitProvider.future);
  final stations = await ref.watch(stationRepositoryProvider.future);
  final maintenance = await ref.watch(maintenanceRepositoryProvider.future);
  final requests = await ref.watch(requestRepositoryProvider.future);
  return ManagerOverviewService(
    loadStations: stations.getAll,
    loadStatuses: maintenance.getAllStatusesForCurrentMonth,
    loadOpenRequests: () => requests.getAll(status: 'open'),
  ).load();
});

final managerOpenRequestsProvider = FutureProvider((ref) async {
  await ref.watch(appInitProvider.future);
  final requests = await ref.watch(requestRepositoryProvider.future);
  return requests.getAll(status: 'open');
});

final managerStationsProvider = FutureProvider((ref) async {
  await ref.watch(appInitProvider.future);
  final stations = await ref.watch(stationRepositoryProvider.future);
  final maintenance = await ref.watch(maintenanceRepositoryProvider.future);
  final list = await stations.getAll();
  final statuses = await maintenance.getAllStatusesForCurrentMonth();
  return (stations: list, statuses: statuses);
});

class MaintenanceListFilter {
  const MaintenanceListFilter({required this.region, required this.done});

  final String region;
  final bool done;

  @override
  bool operator ==(Object other) =>
      other is MaintenanceListFilter &&
      other.region == region &&
      other.done == done;

  @override
  int get hashCode => Object.hash(region, done);
}

final maintenanceListProvider =
    FutureProvider.family<List<StationMaintenanceItem>, MaintenanceListFilter>((
      ref,
      filter,
    ) async {
      await ref.watch(appInitProvider.future);
      final repo = await ref.watch(maintenanceRepositoryProvider.future);
      return repo.getStationsByRegion(region: filter.region, done: filter.done);
    });

Future<SyncStatus> runManualSync(WidgetRef ref) async {
  ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
  final sync = await ref.read(syncServiceProvider.future);
  try {
    await sync.seedCloudIfEmpty();
    final status = await sync.pullAll();
    ref.read(syncStatusProvider.notifier).state = status;
    return status;
  } catch (_) {
    ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    return SyncStatus.error;
  }
}
