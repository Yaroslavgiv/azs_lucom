import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/maintenance_repository.dart';
import '../repositories/defect_act_repository.dart';
import '../repositories/equipment_repository.dart';
import '../repositories/request_repository.dart';
import '../repositories/station_info_repository.dart';
import '../repositories/station_repository.dart';
import '../services/export_service.dart';
import '../services/geocoder_service.dart';
import '../models/station.dart';
import '../services/equipment_seed_service.dart';
import '../services/operational_data_seed_service.dart';
import '../services/station_seed_service.dart';
import '../services/sync_service.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  return AppDatabase.instance;
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SyncService(db);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

final stationRepositoryProvider = FutureProvider<StationRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncServiceProvider.future);
  return StationRepository(db, sync: sync);
});

final requestRepositoryProvider = FutureProvider<RequestRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncServiceProvider.future);
  return RequestRepository(db, sync: sync);
});

final maintenanceRepositoryProvider = FutureProvider<MaintenanceRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncServiceProvider.future);
  return MaintenanceRepository(db, sync: sync);
});

final stationInfoRepositoryProvider = FutureProvider<StationInfoRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncServiceProvider.future);
  return StationInfoRepository(db, sync: sync);
});

final equipmentRepositoryProvider = FutureProvider<EquipmentRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return EquipmentRepository(db);
});

final defectActRepositoryProvider = FutureProvider<DefectActRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncServiceProvider.future);
  return DefectActRepository(db, sync: sync);
});

final geocoderServiceProvider = FutureProvider<GeocoderService>((ref) async {
  final stations = await ref.watch(stationRepositoryProvider.future);
  return GeocoderService(stations);
});

final exportServiceProvider = FutureProvider<ExportService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncServiceProvider.future);
  return ExportService(db, sync: sync);
});

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
