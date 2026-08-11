import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/geocoder_service.dart';
import '../shell/main_shell.dart';

class GeocodePage extends ConsumerStatefulWidget {
  const GeocodePage({super.key});

  @override
  ConsumerState<GeocodePage> createState() => _GeocodePageState();
}

class _GeocodePageState extends ConsumerState<GeocodePage> {
  bool _running = false;
  int _done = 0;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    await ref.read(appInitProvider.future);
    final stationsRepo = await ref.read(stationRepositoryProvider.future);
    final geocoder = await ref.read(geocoderServiceProvider.future);
    final pending = await stationsRepo.getNeedingGeocode();

    if (!geocoder.isConfigured || pending.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainShell()),
        );
      }
      return;
    }

    setState(() {
      _running = true;
      _total = pending.length;
      _done = 0;
    });

    for (final station in pending) {
      if (!mounted) break;
      final result = await geocoder.geocodeStation(station);
      if (!result.success) {
        await stationsRepo.markGeocodeFailed(station.number);
      }
      setState(() => _done++);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    if (mounted) {
      setState(() => _running = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MainShell()),
      );
    }
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geocoderAsync = ref.watch(geocoderServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Подготовка карты')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Определение координат станций через DaData.\n'
              'Для точных точек на карте запустите scripts/import_yandex_bookmarks.py '
              'при доступе к API Яндекс.Карт.',
            ),
            const SizedBox(height: 24),
            geocoderAsync.when(
              data: (GeocoderService g) => Text(
                g.isConfigured
                    ? 'Ключи DaData найдены'
                    : 'Ключи DaData не заданы (.env) — карта может быть пустой',
              ),
              loading: () => const Text('Загрузка...'),
              error: (e, _) => Text('Ошибка: $e'),
            ),
            const SizedBox(height: 16),
            if (_running && _total > 0)
              LinearProgressIndicator(value: _done / _total),
            const SizedBox(height: 8),
            Text(_running ? 'Обработано $_done из $_total' : 'Завершение...'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const Spacer(),
            OutlinedButton(onPressed: _skip, child: const Text('Пропустить')),
          ],
        ),
      ),
    );
  }
}
