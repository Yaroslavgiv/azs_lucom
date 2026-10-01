import 'package:azs_domain/azs_domain.dart';

import 'station.dart';

OrgStation orgStationOf(Station station) {
  return OrgStation(
    number: station.number,
    managementId: station.managementId,
    departmentId: station.departmentId,
    crewId: station.crewId,
    region: station.region,
    specialistId: station.specialistId,
  );
}

/// Без профиля список остаётся полным: иначе обновление скроет справочник
/// до загрузки ролей. Неактивный профиль не видит станции.
List<Station> stationsVisibleTo(
  AccessSubject? actor,
  Iterable<Station> stations,
) {
  if (actor == null) return stations.toList();
  return [
    for (final station in stations)
      if (canReadStation(actor, orgStationOf(station))) station,
  ];
}
