import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/models/request_item.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/app_buttons.dart';

final _stationRefreshProvider = StateProvider.family<int, String>(
  (ref, _) => 0,
);

void refreshStationRequests(WidgetRef ref, String stationNumber) {
  ref.read(_stationRefreshProvider(stationNumber).notifier).state++;
}

final stationRequestsProvider =
    FutureProvider.family<List<RequestItem>, String>((
      ref,
      stationNumber,
    ) async {
      ref.watch(_stationRefreshProvider(stationNumber));
      final repo = await ref.watch(requestRepositoryProvider.future);
      return repo.getOpenByStation(stationNumber);
    });

Future<void> showNewRequestDialog(
  BuildContext context,
  WidgetRef ref,
  String stationNumber,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _NewRequestDialog(stationNumber: stationNumber),
  );
}

class _NewRequestDialog extends ConsumerStatefulWidget {
  const _NewRequestDialog({required this.stationNumber});

  final String stationNumber;

  @override
  ConsumerState<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends ConsumerState<_NewRequestDialog> {
  String? _category;
  final _descController = TextEditingController();
  bool _saving = false;

  bool get _canSave =>
      !_saving && _category != null && _descController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _descController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _descController.removeListener(_onFormChanged);
    _descController.dispose();
    super.dispose();
  }

  void _onFormChanged() => setState(() {});

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(requestRepositoryProvider.future);
      await repo.add(
        stationNumber: widget.stationNumber,
        requestType: _category!,
        description: _descController.text.trim(),
      );
      refreshStationRequests(ref, widget.stationNumber);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryMissing = _category == null;
    final descriptionMissing = _descController.text.trim().isEmpty;

    return AlertDialog(
      title: const Text('Новая заявка'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Категория', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ...requestCategories.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  selected: _category == c,
                  selectedColor: AppColors.accent.withValues(alpha: 0.25),
                  checkmarkColor: AppColors.accent,
                  onSelected: (selected) {
                    setState(() => _category = selected ? c : null);
                  },
                ),
              ),
            ),
            if (categoryMissing)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Выберите категорию',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            if (descriptionMissing)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Заполните описание заявки',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        AppPrimaryButton(
          label: 'Сохранить',
          expand: false,
          loading: _saving,
          onPressed: _canSave ? _save : null,
        ),
      ],
    );
  }
}

Future<void> showEditRequestDialog(
  BuildContext context,
  WidgetRef ref,
  RequestItem item,
) async {
  final descController = TextEditingController(text: item.description);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(item.requestType),
      content: TextField(
        controller: descController,
        decoration: const InputDecoration(labelText: 'Корректировка заявки'),
        maxLines: 4,
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: ctx,
              builder: (c) => AlertDialog(
                title: const Text('Удалить заявку?'),
                content: const Text('Заявка будет закрыта.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              final repo = await ref.read(requestRepositoryProvider.future);
              await repo.close(item.id);
              refreshStationRequests(ref, item.stationNumber);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
          child: const Text(
            'Удалить заявку',
            style: TextStyle(color: Colors.red),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () async {
            final repo = await ref.read(requestRepositoryProvider.future);
            await repo.updateDescription(item.id, descController.text.trim());
            refreshStationRequests(ref, item.stationNumber);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  descController.dispose();
}
