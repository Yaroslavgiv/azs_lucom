import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class WebEquipmentPage extends ConsumerStatefulWidget {
  const WebEquipmentPage({super.key});

  @override
  ConsumerState<WebEquipmentPage> createState() => _WebEquipmentPageState();
}

class _WebEquipmentPageState extends ConsumerState<WebEquipmentPage> {
  String? _stationNumber;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref.read(cloudDataServiceProvider).stations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stations = snapshot.data!;
        _stationNumber ??= stations.isEmpty ? null : stations.first.number;
        if (_stationNumber == null) {
          return const Center(child: Text('Нет станций'));
        }
        return FutureBuilder(
          future: ref
              .read(cloudDataServiceProvider)
              .equipmentForStation(_stationNumber!),
          builder: (context, equipmentSnap) {
            final items = equipmentSnap.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _stationNumber,
                          items: [
                            for (final station in stations)
                              DropdownMenuItem(
                                value: station.number,
                                child: Text(
                                  '№${station.number} ${station.name}',
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _stationNumber = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppPrimaryButton(
                        label: 'Добавить',
                        expand: false,
                        onPressed: _add,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      child: Text(
                        '${item.category} · ${item.description}\n'
                        '${item.quantity} шт. · ${item.condition}'
                        '${item.serialNumber.isEmpty ? '' : ' · с/н ${item.serialNumber}'}'
                        '${item.updatedBy == null ? '' : '\nИзменил: ${item.updatedBy} ${item.updatedAt ?? ''}'}',
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _add() async {
    final desc = TextEditingController();
    var category = equipmentCategories.first;
    var quantity = 1;
    final serial = TextEditingController();
    var condition = equipmentConditions.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавление оборудования'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: category,
                items: [
                  for (final value in equipmentCategories)
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) => category = value ?? category,
              ),
              TextField(
                controller: desc,
                decoration: const InputDecoration(
                  labelText: 'Модель / описание',
                ),
              ),
              TextField(
                controller: serial,
                decoration: const InputDecoration(labelText: 'Серийный номер'),
              ),
              DropdownButton<String>(
                value: condition,
                items: [
                  for (final value in equipmentConditions)
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) => condition = value ?? condition,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true || desc.text.trim().isEmpty || _stationNumber == null) {
      return;
    }
    final profile = ref.read(currentUserProfileProvider).value;
    await ref
        .read(cloudDataServiceProvider)
        .addEquipment(
          stationNumber: _stationNumber!,
          category: category,
          description: desc.text.trim(),
          quantity: quantity,
          serialNumber: serial.text.trim(),
          condition: condition,
          actorId: profile?.id,
          actorName: profile?.shortName,
        );
    setState(() {});
  }
}
