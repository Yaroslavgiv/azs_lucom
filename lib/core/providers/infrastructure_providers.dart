import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/attachment_repository.dart';
import '../repositories/defect_act_repository.dart';
import '../repositories/equipment_repository.dart';
import '../repositories/maintenance_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/request_repository.dart';
import '../repositories/station_info_repository.dart';
import '../repositories/station_repository.dart';
import '../services/export_service.dart';
import '../services/geocoder_service.dart';
import '../services/local_work_service.dart';
import '../services/station_creation_service.dart';
import '../services/sync_service.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  return AppDatabase.instance;
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
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
  final syncService = await ref.watch(syncServiceProvider.future);
  return EquipmentRepository(database, sync: syncService);
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

final localWorkServiceProvider = FutureProvider<LocalWorkService>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return LocalWorkService(database, sync: syncService);
});

final profileRepositoryProvider = FutureProvider<ProfileRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  return ProfileRepository(database);
});

final attachmentRepositoryProvider = FutureProvider<AttachmentRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return AttachmentRepository(database, sync: syncService);
});

final notificationRepositoryProvider = FutureProvider<NotificationRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  return NotificationRepository(database);
});

final stationCreationServiceProvider = FutureProvider<StationCreationService>((
  ref,
) async {
  final stations = await ref.watch(stationRepositoryProvider.future);
  final geocoder = await ref.watch(geocoderServiceProvider.future);
  return StationCreationService(stations, geocoder);
});

final exportServiceProvider = FutureProvider<ExportService>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  final syncService = await ref.watch(syncServiceProvider.future);
  return ExportService(database, sync: syncService);
});
