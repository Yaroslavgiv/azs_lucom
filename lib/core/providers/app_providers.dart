import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/station.dart';
import '../repositories/maintenance_repository.dart';
import '../services/equipment_seed_service.dart';
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

  final sync = await ref.watch(syncServiceProvider.future);
  ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
  try {
    await sync.seedCloudIfEmpty();
    final status = await sync.pullAll();
    ref.read(syncStatusProvider.notifier).state = status;
  } catch (_) {
    ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
  }
});

final stationsByRegionProvider = FutureProvider.family<List<Station>, String>((
  ref,
  region,
) async {
  await ref.watch(appInitProvider.future);
  final repo = await ref.watch(stationRepositoryProvider.future);
  return repo.getByRegion(region);
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
