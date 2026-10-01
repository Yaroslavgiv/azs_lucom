import '../models/request_item.dart';
import '../models/station.dart';
import '../repositories/maintenance_repository.dart';

class ManagerAttentionItem {
  const ManagerAttentionItem({
    required this.stationNumber,
    required this.reason,
    this.stationName = '',
  });

  final String stationNumber;
  final String reason;
  final String stationName;
}

class ManagerOverviewStats {
  const ManagerOverviewStats({
    required this.stationCount,
    required this.maintenanceDone,
    required this.maintenancePending,
    required this.openRequests,
    required this.attentionItems,
    required this.openRequestItems,
  });

  final int stationCount;
  final int maintenanceDone;
  final int maintenancePending;
  final int openRequests;
  final List<ManagerAttentionItem> attentionItems;
  final List<RequestItem> openRequestItems;
}

class ManagerOverviewService {
  const ManagerOverviewService({
    required this.loadStations,
    required this.loadStatuses,
    required this.loadOpenRequests,
  });

  final Future<List<Station>> Function() loadStations;
  final Future<Map<String, MaintenanceStatus>> Function() loadStatuses;
  final Future<List<RequestItem>> Function() loadOpenRequests;

  Future<ManagerOverviewStats> load() async {
    final allStations = await loadStations();
    final statuses = await loadStatuses();
    final open = await loadOpenRequests();

    final done = allStations
        .where((station) => statuses[station.number]?.isDone == true)
        .length;
    final pending = allStations.length - done;

    final attention = <ManagerAttentionItem>[];
    for (final request in open.take(8)) {
      attention.add(
        ManagerAttentionItem(
          stationNumber: request.stationNumber,
          stationName: request.requestType,
          reason: 'Открытая заявка',
        ),
      );
    }
    for (final station in allStations) {
      if (attention.length >= 12) break;
      if (statuses[station.number]?.isDone == true) continue;
      if (attention.any((item) => item.stationNumber == station.number)) {
        continue;
      }
      attention.add(
        ManagerAttentionItem(
          stationNumber: station.number,
          stationName: station.name,
          reason: 'ТО не принято в этом месяце',
        ),
      );
    }

    return ManagerOverviewStats(
      stationCount: allStations.length,
      maintenanceDone: done,
      maintenancePending: pending < 0 ? 0 : pending,
      openRequests: open.length,
      attentionItems: attention,
      openRequestItems: open,
    );
  }
}
