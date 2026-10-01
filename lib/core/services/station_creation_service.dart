import 'package:azs_domain/azs_domain.dart';

import '../models/station.dart';
import '../repositories/station_repository.dart';
import 'geocoder_service.dart';

class StationCreateDecision {
  const StationCreateDecision({
    required this.saved,
    this.denial,
    this.warnings = const [],
    this.preview,
  });

  final bool saved;
  final String? denial;
  final List<String> warnings;
  final GeocodeResult? preview;
}

class StationCreationService {
  StationCreationService(this._stations, this._geocoder);

  final StationRepository _stations;
  final GeocoderService _geocoder;

  Future<StationCreateDecision> previewAddress(String address) async {
    final result = await _geocoder.lookupAddress(address);
    if (!result.success) {
      return const StationCreateDecision(
        saved: false,
        denial:
            'Адрес не найден. Уточните формулировку или введите координаты вручную.',
      );
    }
    return StationCreateDecision(saved: false, preview: result);
  }

  Future<StationCreateDecision> create({
    required AccessSubject actor,
    required String number,
    required String name,
    required String address,
    required String region,
    required String inputMethod,
    double? lat,
    double? lon,
    String? managementId,
    String? departmentId,
    String? crewId,
    bool confirmDuplicate = false,
  }) async {
    if (!canCreateStation(actor)) {
      return const StationCreateDecision(
        saved: false,
        denial: 'Недостаточно прав для создания АЗС',
      );
    }
    if (inputMethod == 'coordinates') {
      final error = validateCoordinates(lat, lon);
      if (error != null) {
        return StationCreateDecision(saved: false, denial: error);
      }
    }
    if (inputMethod == 'address' && (lat == null || lon == null)) {
      return const StationCreateDecision(
        saved: false,
        denial:
            'Сначала подтвердите точку на карте. Без координат станция не создаётся.',
      );
    }
    final existing = await _stations.getByRegion(region);
    final all = await _stations.getAllWithCoordinates();
    final known = <String, Station>{
      for (final station in [...existing, ...all]) station.number: station,
    };
    final warnings = findDuplicateWarnings(
      draft: StationIdentity(
        number: number,
        address: address,
        lat: lat,
        lon: lon,
      ),
      existing: known.values
          .map(
            (station) => StationIdentity(
              number: station.number,
              address: station.address,
              lat: station.lat,
              lon: station.lon,
            ),
          )
          .toList(),
    );
    if (warnings.isNotEmpty && !confirmDuplicate) {
      return StationCreateDecision(
        saved: false,
        warnings: warnings.map((warning) => warning.reason).toList(),
      );
    }
    final now = DateTime.now().toIso8601String();
    await _stations.upsert(
      Station(
        number: number,
        name: name.isEmpty ? 'АЗС $number' : name,
        address: address,
        region: region,
        lat: lat,
        lon: lon,
        geocodeStatus: lat == null ? 0 : 1,
        managementId: managementId,
        departmentId: departmentId,
        crewId: crewId,
        createdBy: actor.userId,
        createdAt: now,
        inputMethod: inputMethod,
      ),
    );
    return const StationCreateDecision(saved: true);
  }
}
