import 'package:azs_domain/azs_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/local_work_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class MaintenanceRecordPage extends ConsumerStatefulWidget {
  const MaintenanceRecordPage({
    super.key,
    required this.stationNumber,
    required this.month,
  });

  final String stationNumber;
  final String month;

  @override
  ConsumerState<MaintenanceRecordPage> createState() =>
      _MaintenanceRecordPageState();
}

class _MaintenanceRecordPageState extends ConsumerState<MaintenanceRecordPage> {
  final _comment = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    setState(() => _busy = true);
    try {
      final actor = await ref.read(sessionProfileProvider.future);
      if (actor == null) {
        _show('Профиль роли не загружен');
        return;
      }
      final work = await ref.read(localWorkServiceProvider.future);
      await work.rollMaintenanceMonths();
      await work.applyMaintenance(
        actor: actor,
        stationNumber: widget.stationNumber,
        month: widget.month,
        action: WorkAction.complete,
        comment: _comment.text,
      );
      _show('ТО зафиксировано');
    } on WorkDenied catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('ТО ${widget.stationNumber}')),
        body: _busy
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GlassCard(
                    child: Text(
                      'Месяц ${widget.month}. Одно действие фиксирует выполнение с датой и временем. Чек-лист, фото и приёмка руководителя не требуются.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий, если нужен',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppPrimaryButton(
                    label: 'Зафиксировать ТО',
                    icon: Icons.event_available,
                    onPressed: _record,
                  ),
                ],
              ),
      ),
    );
  }
}
