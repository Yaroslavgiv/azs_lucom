import 'dart:math' as math;

const duplicateDistanceMeters = 50.0;

class StationIdentity {
  const StationIdentity({
    required this.number,
    required this.address,
    this.lat,
    this.lon,
  });

  final String number;
  final String address;
  final double? lat;
  final double? lon;
}

class DuplicateWarning {
  const DuplicateWarning(this.reason);

  final String reason;
}

String? validateCoordinates(double? lat, double? lon) {
  if (lat == null || lon == null) {
    return 'Укажите широту и долготу';
  }
  if (lat < -90 || lat > 90) {
    return 'Широта должна быть в диапазоне от -90 до 90';
  }
  if (lon < -180 || lon > 180) {
    return 'Долгота должна быть в диапазоне от -180 до 180';
  }
  return null;
}

String normalizeAddress(String address) {
  return address.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

List<DuplicateWarning> findDuplicateWarnings({
  required StationIdentity draft,
  required List<StationIdentity> existing,
}) {
  final warnings = <DuplicateWarning>[];
  final draftAddress = normalizeAddress(draft.address);
  for (final station in existing) {
    if (station.number == draft.number) {
      warnings.add(
        DuplicateWarning('Номер ${draft.number} уже есть в справочнике'),
      );
    }
    if (draftAddress.isNotEmpty &&
        draftAddress == normalizeAddress(station.address)) {
      warnings.add(
        DuplicateWarning('Адрес совпадает со станцией ${station.number}'),
      );
    }
    final distance = _distanceMeters(draft, station);
    if (distance != null && distance <= duplicateDistanceMeters) {
      warnings.add(
        DuplicateWarning(
          'Координаты ближе $duplicateDistanceMeters м к станции ${station.number}',
        ),
      );
    }
  }
  return warnings;
}

double? _distanceMeters(StationIdentity left, StationIdentity right) {
  if (left.lat == null ||
      left.lon == null ||
      right.lat == null ||
      right.lon == null) {
    return null;
  }
  const earthRadius = 6371000.0;
  final lat1 = _rad(left.lat!);
  final lat2 = _rad(right.lat!);
  final dLat = _rad(right.lat! - left.lat!);
  final dLon = _rad(right.lon! - left.lon!);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double degree) => degree * math.pi / 180;
