import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/station_equipment_item.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';

class EquipmentEditPage extends ConsumerStatefulWidget {
  const EquipmentEditPage({super.key, required this.item});

  final StationEquipmentItem item;

  @override
  ConsumerState<EquipmentEditPage> createState() => _EquipmentEditPageState();
}

class _EquipmentEditPageState extends ConsumerState<EquipmentEditPage> {
  late final TextEditingController _model;
  late final TextEditingController _quantity;
  late final TextEditingController _serial;
  late final TextEditingController _condition;

  @override
  void initState() {
    super.initState();
    _model = TextEditingController(text: widget.item.model);
    _quantity = TextEditingController(text: '${widget.item.quantity}');
    _serial = TextEditingController(text: widget.item.serialNumber ?? '');
    _condition = TextEditingController(text: widget.item.condition);
  }

  @override
  void dispose() {
    _model.dispose();
    _quantity.dispose();
    _serial.dispose();
    _condition.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = await ref.read(equipmentRepositoryProvider.future);
    final actor = await ref.read(sessionProfileProvider.future);
    await repo.updatePassport(
      id: widget.item.id,
      model: _model.text.trim(),
      quantity: int.tryParse(_quantity.text.trim()) ?? 1,
      serialNumber: _serial.text.trim(),
      condition: _condition.text.trim(),
      authorId: actor?.userId,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Паспорт оборудования')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.item.category,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Модель'),
            ),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Количество'),
            ),
            TextField(
              controller: _serial,
              decoration: const InputDecoration(labelText: 'Серийный номер'),
            ),
            TextField(
              controller: _condition,
              decoration: const InputDecoration(labelText: 'Состояние'),
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Сохранить',
              icon: Icons.save_outlined,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
            Text(
              'Складские остатки в этой версии не ведутся.',
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
