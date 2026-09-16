import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/defect_act_repository.dart';
import '../repositories/equipment_repository.dart';
import '../repositories/maintenance_repository.dart';
import '../repositories/request_repository.dart';
import '../repositories/station_info_repository.dart';
import '../repositories/station_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../services/cloud_data_service.dart';
import '../services/export_service.dart';
import '../services/geocoder_service.dart';
import '../services/maintenance_workflow_service.dart';
import '../services/sync_service.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  if (kIsWeb) {
    throw UnsupportedError('SQLite недоступен в web-панели');
  }
  return AppDatabase.instance;
});

final syncServiceProvider = FutureProvider<SyncService?>((ref) async {
  if (kIsWeb) return null;
  final database = await ref.watch(databaseProvider.future);
  return SyncService(database);
});

final stationRepositoryProvider = FutureProvider<StationRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return StationRepository(database, sync: syncService);
});

final requestRepositoryProvider = FutureProvider<RequestRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return RequestRepository(database, sync: syncService);
});

final maintenanceRepositoryProvider = FutureProvider<MaintenanceRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return MaintenanceRepository(database, sync: syncService);
});

final stationInfoRepositoryProvider = FutureProvider<StationInfoRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return StationInfoRepository(database, sync: syncService);
});

final equipmentRepositoryProvider = FutureProvider<EquipmentRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  return EquipmentRepository(database);
});

final defectActRepositoryProvider = FutureProvider<DefectActRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return DefectActRepository(database, sync: syncService);
});

final geocoderServiceProvider = FutureProvider<GeocoderService>((ref) async {
  final stationRepository = await ref.watch(stationRepositoryProvider.future);
  return GeocoderService(stationRepository);
});

final exportServiceProvider = FutureProvider<ExportService>((ref) async {
  if (kIsWeb) {
    return ExportService();
  }
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return ExportService(db: database, sync: syncService);
});

final cloudDataServiceProvider = Provider<CloudDataService>((ref) {
  return CloudDataService(FirebaseFirestore.instance);
});

final userProfileRepositoryProvider = FutureProvider<UserProfileRepository>((
  ref,
) async {
  AppDatabase? cache;
  if (!kIsWeb) {
    cache = await ref.watch(databaseProvider.future);
  }
  return UserProfileRepository(cache: cache);
});

final maintenanceWorkflowProvider = Provider<MaintenanceWorkflowService>((ref) {
  return MaintenanceWorkflowService(
    functions: FirebaseFunctions.instanceFor(region: 'europe-west1'),
  );
});
