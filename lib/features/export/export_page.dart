import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool _busy = false;

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Ожидание';
      case SyncStatus.syncing:
        return 'Синхронизация…';
      case SyncStatus.offline:
        return 'Офлайн';
      case SyncStatus.error:
        return 'Ошибка sync';
      case SyncStatus.synced:
        return 'Синхронизировано';
    }
  }

  Color _syncColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return AppColors.accent;
      case SyncStatus.offline:
        return AppColors.textSecondary;
      case SyncStatus.error:
        return AppColors.error;
      case SyncStatus.syncing:
      case SyncStatus.idle:
        return AppColors.textSecondary;
    }
  }

  Future<void> _run(Future<void> Function() fn, String label) async {
    setState(() => _busy = true);
    try {
      final sync = await ref.read(syncServiceProvider.future);
      final usedCacheOnly = !await sync.isOnline();
      await fn();
      if (mounted) {
        final msg = usedCacheOnly
            ? '$label — файл отправлен (нет сети, данные из локального кеша)'
            : '$label — файл отправлен';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      final status = await runManualSync(ref);
      if (!mounted) return;
      final msg = switch (status) {
        SyncStatus.synced => 'Данные обновлены из облака',
        SyncStatus.offline => 'Нет сети — используется локальный кеш',
        SyncStatus.error => 'Не удалось синхронизировать',
        _ => 'Синхронизация завершена',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final userEmail = ref.watch(authStateProvider).value?.email ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Экспорт Excel',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Выйти',
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _busy
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Выгрузка данных по бригаде (Новгород + Санкт-Петербург). '
                            'При наличии сети перед отчётом подтягиваются данные из Firebase.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_sync,
                                size: 18,
                                color: _syncColor(syncStatus),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_syncLabel(syncStatus)}${userEmail.isNotEmpty ? ' · $userEmail' : ''}',
                                  style: TextStyle(
                                    color: _syncColor(syncStatus),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          AppSecondaryButton(
                            label: 'Синхронизировать',
                            icon: Icons.sync,
                            onPressed: _syncNow,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      label: 'Заявки (заявки.xlsx)',
                      icon: Icons.description_outlined,
                      onPressed: () async {
                        final s = await ref.read(exportServiceProvider.future);
                        await _run(s.shareRequests, 'Заявки');
                      },
                    ),
                    const SizedBox(height: 10),
                    AppPrimaryButton(
                      label: 'ТО — все станции (ТО.xlsx)',
                      icon: Icons.build_outlined,
                      onPressed: () async {
                        final s = await ref.read(exportServiceProvider.future);
                        await _run(s.shareMaintenance, 'ТО');
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Заказ оборудования',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    AppPrimaryButton(
                      label: 'Выгрузка для заказа — СПБ',
                      icon: Icons.shopping_cart_outlined,
                      onPressed: () async {
                        final s = await ref.read(exportServiceProvider.future);
                        await _run(
                          () => s.shareEquipmentOrders(regionSpb),
                          'Выгрузка для заказа СПБ',
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    AppPrimaryButton(
                      label: 'Выгрузка для заказа — Новгород',
                      icon: Icons.shopping_cart_outlined,
                      onPressed: () async {
                        final s = await ref.read(exportServiceProvider.future);
                        await _run(
                          () => s.shareEquipmentOrders(regionNovgorod),
                          'Выгрузка для заказа Новгород',
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    AppSecondaryButton(
                      label: 'Свежие заявки — СПБ',
                      icon: Icons.new_releases_outlined,
                      onPressed: () async {
                        final s = await ref.read(exportServiceProvider.future);
                        await _run(
                          () => s.shareFreshEquipmentOrders(regionSpb),
                          'Свежие заявки СПБ',
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    AppSecondaryButton(
                      label: 'Свежие заявки — Новгород',
                      icon: Icons.new_releases_outlined,
                      onPressed: () async {
                        final s = await ref.read(exportServiceProvider.future);
                        await _run(
                          () => s.shareFreshEquipmentOrders(regionNovgorod),
                          'Свежие заявки Новгород',
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    AppPrimaryButton(
                      label: 'Оборудование — все станции (оборудование.xlsx)',
                      icon: Icons.inventory_2_outlined,
                      onPressed: () async {
                        final s = await ref.read(exportServiceProvider.future);
                        await _run(s.shareEquipment, 'Оборудование');
                      },
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
