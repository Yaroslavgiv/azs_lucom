import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class ManagerReportsPage extends ConsumerStatefulWidget {
  const ManagerReportsPage({super.key});

  @override
  ConsumerState<ManagerReportsPage> createState() => _ManagerReportsPageState();
}

class _ManagerReportsPageState extends ConsumerState<ManagerReportsPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String label) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label — готово')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Text(
          'Отчёты по ТО и заявкам',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Выгрузка XLSX. Sync: ${_syncLabel(syncStatus)}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPrimaryButton(
                label: 'Скачать заявки.xlsx',
                icon: Icons.table_chart_outlined,
                loading: _busy,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final export = await ref.read(
                          exportServiceProvider.future,
                        );
                        await export.shareRequests();
                      }, 'Заявки'),
              ),
              const SizedBox(height: 10),
              AppSecondaryButton(
                label: 'Скачать ТО.xlsx',
                icon: Icons.build_circle_outlined,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final export = await ref.read(
                          exportServiceProvider.future,
                        );
                        await export.shareMaintenance();
                      }, 'ТО'),
              ),
              const SizedBox(height: 10),
              AppSecondaryButton(
                label: 'Скачать оборудование.xlsx',
                icon: Icons.memory_outlined,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final export = await ref.read(
                          exportServiceProvider.future,
                        );
                        await export.shareEquipment();
                      }, 'Оборудование'),
              ),
              const SizedBox(height: 10),
              AppSecondaryButton(
                label: 'Заказ оборудования · $regionLabelSpb',
                icon: Icons.shopping_cart_outlined,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final export = await ref.read(
                          exportServiceProvider.future,
                        );
                        await export.shareEquipmentOrders(regionSpb);
                      }, 'Заказ СПб'),
              ),
              const SizedBox(height: 10),
              AppSecondaryButton(
                label: 'Заказ оборудования · $regionLabelNovgorod',
                icon: Icons.shopping_cart_outlined,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final export = await ref.read(
                          exportServiceProvider.future,
                        );
                        await export.shareEquipmentOrders(regionNovgorod);
                      }, 'Заказ Новгород'),
              ),
              const SizedBox(height: 16),
              AppSecondaryButton(
                label: 'Синхронизировать сейчас',
                icon: Icons.sync,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await runManualSync(ref);
                      }, 'Синхронизация'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _syncLabel(SyncStatus status) {
    return switch (status) {
      SyncStatus.idle => 'ожидание',
      SyncStatus.syncing => 'синхронизация…',
      SyncStatus.offline => 'офлайн',
      SyncStatus.error => 'ошибка',
      SyncStatus.synced => 'актуально',
    };
  }
}
