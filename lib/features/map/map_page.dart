import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/models/station.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/maintenance_repository.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/dialogs/station_marker_dialog.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';
import 'station_marker_style.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _mapController = MapController();
  bool _mapReady = false;
  bool _locating = false;
  bool _loadingMarkers = false;
  List<Station> _allStations = [];
  Map<String, MaintenanceStatus>? _statuses;
  String? _focusedRegion;
  int _spbCount = 0;
  int _novgorodCount = 0;
  LatLng? _currentPosition;
  double? _currentPositionAccuracy;

  List<Station> _stationsForRegion(String? region) {
    if (region == null) return _allStations;
    return _allStations.where((s) => s.region == region).toList();
  }

  void _showStations(List<Station> stations) {
    if (stations.isEmpty) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          stations
              .map((station) => LatLng(station.lat!, station.lon!))
              .toList(growable: false),
        ),
        padding: const EdgeInsets.all(48),
        maxZoom: 15,
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

      _showStations(_stationsForRegion(_focusedRegion));
    } finally {
      _loadingMarkers = false;
    }
  }

  void _focusRegion(String region) {
    if (!_mapReady || _loadingMarkers) return;
    setState(() {
      _focusedRegion = _focusedRegion == region ? null : region;
    });
    _showStations(_stationsForRegion(_focusedRegion));
  }

  Future<void> _goToMyLocation() async {
    if (!_mapReady || _locating) return;
    setState(() => _locating = true);
    try {
      final position = await LocationService.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      _mapController.move(point, 15);
      if (mounted) {
        setState(() {
          _currentPosition = point;
          _currentPositionAccuracy = position.accuracy;
        });
      }
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
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appInitProvider, (_, _) {
      if (_mapReady) _loadMarkers();
    });
    ref.listen(mapRefreshProvider, (_, _) {
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
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(
                      brigadeMapCenterLat,
                      brigadeMapCenterLon,
                    ),
                    initialZoom: brigadeMapDefaultZoom,
                    onMapReady: () async {
                      if (mounted) setState(() => _mapReady = true);
                      await ref.read(appInitProvider.future);
                      await _loadMarkers();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: mapTileUrl,
                      userAgentPackageName: mapTileUserAgentPackageName,
                    ),
                    if (_currentPosition != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _currentPosition!,
                            radius: _currentPositionAccuracy ?? 0,
                            useRadiusInMeter: true,
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderColor: AppColors.accent,
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _buildMarkers()),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
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

  List<Marker> _buildMarkers() {
    return _stationsForRegion(_focusedRegion)
        .map((station) {
          final point = LatLng(station.lat!, station.lon!);
          final markerTitle = station.name.isNotEmpty
              ? '${station.name} (№${station.number})'
              : '№${station.number}';

          return Marker(
            point: point,
            width: 150,
            height: 68,
            alignment: Alignment.bottomCenter,
            child: Semantics(
              button: true,
              label: markerTitle,
              child: GestureDetector(
                onTap: () => showStationMarkerDialog(context, station: station),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          markerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    Image.network(
                      _markerIconUrl(station),
                      width: 30,
                      height: 40,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.location_on,
                        size: 40,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  String _markerIconUrl(Station station) {
    return resolveStationMarkerStyle(
      maintenanceDone: _statuses?[station.number]?.isDone == true,
      highlighted: highlightedStationNumbers.contains(station.number),
    ).iconUrl;
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
