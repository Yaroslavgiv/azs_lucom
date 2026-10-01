import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/station.dart';
import '../repositories/station_repository.dart';

class GeocodeResult {
  GeocodeResult({
    required this.success,
    this.name,
    this.address,
    this.lat,
    this.lon,
  });

  final bool success;
  final String? name;
  final String? address;
  final double? lat;
  final double? lon;
}

class GeocoderService {
  GeocoderService(this._stations);

  final StationRepository _stations;

  String? get _token =>
      dotenv.isInitialized ? dotenv.env['DADATA_TOKEN'] : null;
  String? get _secret =>
      dotenv.isInitialized ? dotenv.env['DADATA_SECRET'] : null;

  bool get isConfigured =>
      _token != null &&
      _token!.isNotEmpty &&
      _secret != null &&
      _secret!.isNotEmpty;

  Future<GeocodeResult> geocodeStation(Station station) async {
    final city = cityForRegion(station.region);
    final query = station.address.isNotEmpty
        ? station.address
        : 'АЗС Лукойл ${station.number}, $city';
    final result = await lookupAddress(query);
    if (!result.success || result.lat == null || result.lon == null) {
      return result;
    }
    final name = result.name ?? 'АЗС ${station.number}';
    await _stations.updateGeocode(
      number: station.number,
      name: name,
      address: result.address ?? query,
      lat: result.lat!,
      lon: result.lon!,
    );
    return GeocodeResult(
      success: true,
      name: name,
      address: result.address,
      lat: result.lat,
      lon: result.lon,
    );
  }

  /// Подсказка адреса без записи в справочник. Пустой ответ не подставляет координаты.
  Future<GeocodeResult> lookupAddress(String query) async {
    if (!isConfigured || query.trim().isEmpty) {
      return GeocodeResult(success: false);
    }
    try {
      final response = await http.post(
        Uri.parse(
          'https://suggestions.dadata.ru/suggestions/api/4_1/rs/suggest/address',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Token $_token',
          'X-Secret': _secret!,
        },
        body: json.encode({'query': query, 'count': 1}),
      );
      if (response.statusCode != 200) return GeocodeResult(success: false);

      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List<dynamic>?;
      if (suggestions == null || suggestions.isEmpty) {
        return GeocodeResult(success: false);
      }

      final first = suggestions.first as Map<String, dynamic>;
      final d = first['data'] as Map<String, dynamic>?;
      final latStr = d?['geo_lat'] as String?;
      final lonStr = d?['geo_lon'] as String?;
      if (latStr == null || lonStr == null) {
        return GeocodeResult(success: false);
      }
      return GeocodeResult(
        success: true,
        name: first['value'] as String?,
        address: first['value'] as String? ?? query,
        lat: double.parse(latStr),
        lon: double.parse(lonStr),
      );
    } catch (_) {
      return GeocodeResult(success: false);
    }
  }
}
