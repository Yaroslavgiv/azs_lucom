import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class CreateStationPage extends ConsumerStatefulWidget {
  const CreateStationPage({super.key});

  @override
  ConsumerState<CreateStationPage> createState() => _CreateStationPageState();
}

class _CreateStationPageState extends ConsumerState<CreateStationPage> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _crew = TextEditingController();
  String _region = regionSpb;
  String _method = 'address';
  String? _message;
  var _confirmDuplicate = false;

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _address.dispose();
    _lat.dispose();
    _lon.dispose();
    _crew.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    final service = await ref.read(stationCreationServiceProvider.future);
    final decision = await service.previewAddress(_address.text);
    setState(() {
      if (decision.preview?.success == true) {
        _lat.text = '${decision.preview!.lat}';
        _lon.text = '${decision.preview!.lon}';
        _address.text = decision.preview!.address ?? _address.text;
        _message = 'Точка найдена: ${_address.text}. Подтвердите сохранение.';
      } else {
        _message = decision.denial;
      }
    });
  }

  Future<void> _save() async {
    final actor = await ref.read(sessionProfileProvider.future);
    if (actor == null) {
      setState(() => _message = 'Профиль роли не загружен');
      return;
    }
    final service = await ref.read(stationCreationServiceProvider.future);
    final decision = await service.create(
      actor: actor,
      number: _number.text.trim(),
      name: _name.text.trim(),
      address: _address.text.trim(),
      region: _region,
      inputMethod: _method,
      lat: double.tryParse(_lat.text.replaceAll(',', '.')),
      lon: double.tryParse(_lon.text.replaceAll(',', '.')),
      crewId: _crew.text.trim().isEmpty ? null : _crew.text.trim(),
      confirmDuplicate: _confirmDuplicate,
    );
    if (!mounted) return;
    if (decision.saved) {
      ref.read(mapRefreshProvider.notifier).state++;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _message = decision.denial ?? decision.warnings.join('\n');
      if (decision.warnings.isNotEmpty) _confirmDuplicate = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Новая АЗС')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _number,
              decoration: const InputDecoration(labelText: 'Номер'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Адрес'),
            ),
            TextField(
              controller: _lat,
              decoration: const InputDecoration(labelText: 'Широта'),
            ),
            TextField(
              controller: _lon,
              decoration: const InputDecoration(labelText: 'Долгота'),
            ),
            TextField(
              controller: _crew,
              decoration: const InputDecoration(labelText: 'Бригада'),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _method,
              items: const [
                DropdownMenuItem(value: 'address', child: Text('По адресу')),
                DropdownMenuItem(
                  value: 'coordinates',
                  child: Text('По координатам'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _method = value);
              },
            ),
            DropdownButton<String>(
              value: _region,
              items: const [
                DropdownMenuItem(
                  value: regionSpb,
                  child: Text('Санкт-Петербург'),
                ),
                DropdownMenuItem(
                  value: regionNovgorod,
                  child: Text('Новгород'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _region = value);
              },
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              GlassCard(child: Text(_message!)),
            ],
            const SizedBox(height: 12),
            AppSecondaryButton(
              label: 'Найти адрес',
              icon: Icons.search,
              onPressed: _preview,
            ),
            const SizedBox(height: 8),
            AppPrimaryButton(
              label: _confirmDuplicate
                  ? 'Сохранить несмотря на дубль'
                  : 'Сохранить',
              icon: Icons.add_location_alt_outlined,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
            Text(
              'Без найденных координат станция не ставится в произвольную точку.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
