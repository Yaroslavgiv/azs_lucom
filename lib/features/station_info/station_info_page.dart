import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/station_info_repository.dart';

final _managerProvider = FutureProvider.family<String, String>((
  ref,
  station,
) async {
  final repo = await ref.watch(stationInfoRepositoryProvider.future);
  return repo.getManagerContact(station);
});

final _equipmentProvider =
    FutureProvider.family<
      List<EquipmentItem>,
      ({String station, String category})
    >((ref, p) async {
      final repo = await ref.watch(stationInfoRepositoryProvider.future);
      return repo.getEquipment(p.station, p.category);
    });

class StationInfoPage extends ConsumerStatefulWidget {
  const StationInfoPage({super.key, required this.stationNumber});

  final String stationNumber;

  @override
  ConsumerState<StationInfoPage> createState() => _StationInfoPageState();
}

class _StationInfoPageState extends ConsumerState<StationInfoPage> {
  final _contactController = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    final repo = await ref.read(stationInfoRepositoryProvider.future);
    await repo.setManagerContact(
      widget.stationNumber,
      _contactController.text.trim(),
    );
    ref.invalidate(_managerProvider(widget.stationNumber));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Контакт сохранён')));
    }
  }

  Future<void> _addEquipment(String category) async {
    final desc = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text('Добавить — $category'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(labelText: 'Описание'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
    if (desc == null || desc.isEmpty) return;
    final repo = await ref.read(stationInfoRepositoryProvider.future);
    await repo.addEquipment(
      stationNumber: widget.stationNumber,
      category: category,
      description: desc,
    );
    ref.invalidate(
      _equipmentProvider((station: widget.stationNumber, category: category)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactAsync = ref.watch(_managerProvider(widget.stationNumber));

    contactAsync.whenData((v) {
      if (!_loaded) {
        _contactController.text = v;
        _loaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text('Информация — ${widget.stationNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(
              labelText: 'Контакт менеджера',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveContact,
            child: const Text('Сохранить контакт'),
          ),
          const SizedBox(height: 24),
          ...equipmentCategories.map(
            (cat) => _EquipmentSection(
              stationNumber: widget.stationNumber,
              category: cat,
              onAdd: () => _addEquipment(cat),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentSection extends ConsumerWidget {
  const _EquipmentSection({
    required this.stationNumber,
    required this.category,
    required this.onAdd,
  });

  final String stationNumber;
  final String category;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      _equipmentProvider((station: stationNumber, category: category)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(category, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(onPressed: onAdd, child: const Text('Добавить')),
          ],
        ),
        async.when(
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Нет записей'),
                )
              : Column(
                  children: items
                      .map(
                        (e) => ListTile(
                          title: Text(e.description),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final repo = await ref.read(
                                stationInfoRepositoryProvider.future,
                              );
                              await repo.deleteEquipment(e.id);
                              ref.invalidate(
                                _equipmentProvider((
                                  station: stationNumber,
                                  category: category,
                                )),
                              );
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const Divider(),
      ],
    );
  }
}
