import 'package:azs_domain/azs_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/local_work_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class MaintenanceChecklistPage extends ConsumerStatefulWidget {
  const MaintenanceChecklistPage({
    super.key,
    required this.stationNumber,
    required this.month,
  });

  final String stationNumber;
  final String month;

  @override
  ConsumerState<MaintenanceChecklistPage> createState() =>
      _MaintenanceChecklistPageState();
}

class _MaintenanceChecklistPageState
    extends ConsumerState<MaintenanceChecklistPage> {
  final _results = <String, String>{};
  List<Map<String, Object?>> _items = const [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final work = await ref.read(localWorkServiceProvider.future);
    final items = await work.checklistTemplateItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    try {
      final actor = await ref.read(sessionProfileProvider.future);
      if (actor == null) return;
      final work = await ref.read(localWorkServiceProvider.future);
      final key = '${widget.stationNumber}_${widget.month}';
      for (final item in _items) {
        final id = item['id'] as String? ?? '';
        final value = _results[id];
        if (value == null) continue;
        await work.saveChecklistResult(
          actor: actor,
          maintenanceKey: key,
          itemId: id,
          result: value,
        );
      }
      await work.applyMaintenance(
        actor: actor,
        stationNumber: widget.stationNumber,
        month: widget.month,
        action: WorkAction.submit,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ТО отправлено на проверку')),
        );
      }
    } on WorkDenied catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('Чек-лист ${widget.stationNumber}')),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['title'] ?? item['id']}'
                              '${item['required'] == true ? ' *' : ''}',
                            ),
                            DropdownButton<String>(
                              value: _results[item['id'] as String? ?? ''],
                              hint: const Text('Результат'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ok',
                                  child: Text('Исправно'),
                                ),
                                DropdownMenuItem(
                                  value: 'fail',
                                  child: Text('Замечание'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _results[item['id'] as String] = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  AppPrimaryButton(
                    label: 'Отправить на проверку',
                    icon: Icons.fact_check_outlined,
                    onPressed: _submit,
                  ),
                ],
              ),
      ),
    );
  }
}
