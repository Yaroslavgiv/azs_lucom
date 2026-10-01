class PanelWorkItem {
  const PanelWorkItem({
    required this.id,
    required this.kind,
    required this.stationNumber,
    required this.status,
    required this.overdue,
    required this.critical,
    this.region,
    this.managementId,
    this.departmentId,
    this.crewId,
    this.assigneeId,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String stationNumber;
  final String status;
  final bool overdue;
  final bool critical;
  final String? region;
  final String? managementId;
  final String? departmentId;
  final String? crewId;
  final String? assigneeId;
  final DateTime? createdAt;
}

class PanelFilter {
  const PanelFilter({
    this.periodFrom,
    this.periodTo,
    this.region,
    this.assigneeId,
    this.status,
    this.managementId,
    this.departmentId,
    this.crewId,
  });

  final DateTime? periodFrom;
  final DateTime? periodTo;
  final String? region;
  final String? assigneeId;
  final String? status;
  final String? managementId;
  final String? departmentId;
  final String? crewId;

  bool matches(PanelWorkItem item) {
    if (region != null && region!.isNotEmpty && item.region != region) {
      return false;
    }
    if (assigneeId != null &&
        assigneeId!.isNotEmpty &&
        item.assigneeId != assigneeId) {
      return false;
    }
    if (status != null && status!.isNotEmpty && item.status != status) {
      return false;
    }
    if (managementId != null &&
        managementId!.isNotEmpty &&
        item.managementId != managementId) {
      return false;
    }
    if (departmentId != null &&
        departmentId!.isNotEmpty &&
        item.departmentId != departmentId) {
      return false;
    }
    if (crewId != null && crewId!.isNotEmpty && item.crewId != crewId) {
      return false;
    }
    if (item.createdAt != null && periodFrom != null) {
      if (item.createdAt!.isBefore(periodFrom!)) return false;
    }
    if (item.createdAt != null && periodTo != null) {
      if (item.createdAt!.isAfter(periodTo!)) return false;
    }
    return true;
  }
}

class PanelMetrics {
  const PanelMetrics({
    required this.openRequests,
    required this.overdueRequests,
    required this.attentionStations,
    required this.maintenanceWaitingAcceptance,
    required this.maintenanceAccepted,
  });

  final int openRequests;
  final int overdueRequests;
  final int attentionStations;
  final int maintenanceWaitingAcceptance;
  final int maintenanceAccepted;
}

PanelMetrics summarizePanel(Iterable<PanelWorkItem> items) {
  final openRequests = <String>{};
  final overdueRequests = <String>{};
  final attentionStations = <String>{};
  var waiting = 0;
  var accepted = 0;
  for (final item in items) {
    if (item.kind == 'request' &&
        item.status != 'accepted' &&
        item.status != 'cancelled') {
      openRequests.add(item.id);
      if (item.overdue || item.critical) {
        overdueRequests.add(item.id);
        attentionStations.add(item.stationNumber);
      }
    }
    if (item.kind == 'maintenance' && item.status == 'on_review') waiting += 1;
    if (item.kind == 'maintenance' && item.status == 'accepted') accepted += 1;
    if (item.kind == 'maintenance' && item.overdue) {
      attentionStations.add(item.stationNumber);
    }
  }
  return PanelMetrics(
    openRequests: openRequests.length,
    overdueRequests: overdueRequests.length,
    attentionStations: attentionStations.length,
    maintenanceWaitingAcceptance: waiting,
    maintenanceAccepted: accepted,
  );
}
