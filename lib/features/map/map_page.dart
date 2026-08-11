import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntk_map_view/ntk_map_view.dart';

import '../../core/constants.dart';
import '../../core/models/station.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/maintenance_repository.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/dialogs/station_marker_dialog.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _controller = NtkMapController.init(null);
  bool _mapReady = false;
  bool _locating = false;
  bool _loadingMarkers = false;
  List<Station> _allStations = [];
  Map<String, MaintenanceStatus>? _statuses;
  String? _focusedRegion;
  int _spbCount = 0;
  int _novgorodCount = 0;

  static const _greenIcon =
      'https://storage.yandexcloud.net/eg-small-backet/markers/greenMarker-min.png';
  static const _yellowIcon =
      'https://storage.yandexcloud.net/eg-small-backet/markers/yellowMarker-min.png';
  static const _redIcon =
      'https://storage.yandexcloud.net/eg-small-backet/markers/redMarker-min.png';

  List<Station> _stationsForRegion(String? region) {
    if (region == null) return _allStations;
    return _allStations.where((s) => s.region == region).toList();
  }

  Future<void> _showStations(List<Station> stations) async {
    await _controller.removeAllMarkers();
    _controller.markers.clear();

    final markers = <MapMarker>[];
    for (final station in stations) {
      final lat = station.lat!;
      final lon = station.lon!;
      final point = LatLng(lat, lon);

      final status = _statuses?[station.number];
      final String iconUrl;
      if (status?.isDone == true) {
        iconUrl = _greenIcon;
      } else if (highlightedStationNumbers.contains(station.number)) {
        iconUrl = _redIcon;
      } else {
        iconUrl = _yellowIcon;
      }

      final markerTitle = station.name.isNotEmpty
          ? '${station.name} (№${station.number})'
          : '№${station.number}';

      markers.add(
        MapMarker(
          id: 'station_${station.number}',
          point: point,
          popup: MapMarkerPopup(title: markerTitle),
          icon: MapMarkerIconModel(iconUrl: iconUrl, width: 30, height: 40),
        ),
      );

      _controller.markers[point] = (_) {
        if (mounted) {
          showStationMarkerDialog(context, station: station);
        }
      };
    }

    for (final marker in markers) {
      await _controller.addMarker(marker: marker, noCluster: true);
    }

    if (stations.isEmpty) return;

    await _controller.goToBounds(
      MapBounds(
        points: stations
            .map((s) => LatLng(s.lat!, s.lon!))
            .toList(growable: false),
      ),
    );
  }

  Future<void> _loadMarkers() async {
    if (!_mapReady || _loadingMarkers) return;
    _loadingMarkers = true;
    try {
      final stationsRepo = await ref.read(stationRepositoryProvider.future);
      final maintRepo = await ref.read(maintenanceRepositoryProvider.future);
      final stations = await stationsRepo.getAllWithCoordinates();
      final statuses = await maintRepo.getAllStatusesForCurrentMonth();

      if (mounted) {
        setState(() {
          _allStations = stations;
          _statuses = statuses;
          _spbCount = stations.where((s) => s.region == regionSpb).length;
          _novgorodCount = stations
              .where((s) => s.region == regionNovgorod)
              .length;
        });
      }

      await _showStations(_stationsForRegion(_focusedRegion));
    } finally {
      _loadingMarkers = false;
    }
  }

  Future<void> _focusRegion(String region) async {
    if (!_mapReady || _loadingMarkers) return;
    setState(() {
      _focusedRegion = _focusedRegion == region ? null : region;
    });
    await _showStations(_stationsForRegion(_focusedRegion));
  }

  Future<void> _goToMyLocation() async {
    if (!_mapReady || _locating) return;
    setState(() => _locating = true);
    try {
      final position = await LocationService.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      await _controller.goToPointThenZoom(point, 15);
      await _controller.updateCurrentPosition(point, position.accuracy / 1000);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appInitProvider, (_, __) {
      if (_mapReady) _loadMarkers();
    });
    ref.listen(mapRefreshProvider, (_, __) {
      if (_mapReady) _loadMarkers();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Карта АЗС',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_mapReady && (_spbCount > 0 || _novgorodCount > 0))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_spbCount > 0) ...[
                        _RegionCountChip(
                          label: 'СПб',
                          count: _spbCount,
                          selected: _focusedRegion == regionSpb,
                          onTap: () => _focusRegion(regionSpb),
                        ),
                        if (_novgorodCount > 0) const SizedBox(width: 8),
                      ],
                      if (_novgorodCount > 0)
                        _RegionCountChip(
                          label: regionLabelNovgorod,
                          count: _novgorodCount,
                          selected: _focusedRegion == regionNovgorod,
                          onTap: () => _focusRegion(regionNovgorod),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: NtkMapView(
                  mapController: _controller,
                  mapPath: 'packages/ntk_map_view/lib/assets/map_mobile.html',
                  styleUrl: mapStyleLight,
                  onCreateEnd: (c) async {
                    if (mounted) setState(() => _mapReady = true);
                    await _controller.goToPointThenZoom(
                      LatLng(brigadeMapCenterLat, brigadeMapCenterLon),
                      brigadeMapDefaultZoom,
                    );
                    await ref.read(appInitProvider.future);
                    await _loadMarkers();
                  },
                ),
              ),
              if (!_mapReady)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                ),
              if (_mapReady && _allStations.isEmpty && !_loadingMarkers)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: GlassCard(
                    child: Text(
                      'Нет станций с координатами в базе.\n'
                      'Переустановите приложение или очистите данные, '
                      'чтобы заново загрузить справочник станций.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              if (_mapReady)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppGlassFab(
                        tooltip: 'Моё местоположение',
                        icon: Icons.my_location,
                        loading: _locating,
                        onPressed: _goToMyLocation,
                      ),
                      const SizedBox(height: 10),
                      AppGlassFab(
                        tooltip: 'Обновить маркеры',
                        icon: Icons.refresh,
                        onPressed: _loadMarkers,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegionCountChip extends StatelessWidget {
  const _RegionCountChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            '$label: $count',
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
