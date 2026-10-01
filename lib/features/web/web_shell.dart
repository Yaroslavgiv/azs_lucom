import 'package:azs_domain/azs_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';

class WebShell extends ConsumerStatefulWidget {
  const WebShell({super.key});

  @override
  ConsumerState<WebShell> createState() => _WebShellState();
}

class _WebShellState extends ConsumerState<WebShell> {
  int _section = 0;

  static const _sections = [
    'Обзор',
    'Заявки',
    'Станции',
    'Оборудование',
    'Отчёты',
    'Пользователи',
  ];

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(panelSnapshotProvider);
    final filter = ref.watch(panelFilterProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _section,
            onDestinationSelected: (index) => setState(() => _section = index),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final title in _sections)
                NavigationRailDestination(
                  icon: const Icon(Icons.circle_outlined),
                  label: Text(title),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: snapshot.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Ошибка панели: $error')),
              data: (data) => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    _sections[_section],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Все бригады',
                        selected: filter.crewId == null,
                        onSelected: () =>
                            ref.read(panelFilterProvider.notifier).state =
                                PanelFilter(region: filter.region),
                      ),
                      _FilterChip(
                        label: 'Только выбранный регион СПб',
                        selected: filter.region == 'spb',
                        onSelected: () =>
                            ref
                                .read(panelFilterProvider.notifier)
                                .state = PanelFilter(
                              region: 'spb',
                              crewId: filter.crewId,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_section == 0) _Overview(metrics: data.metrics),
                  if (_section == 1)
                    for (final item in data.work.where(
                      (item) => item.kind == 'request',
                    ))
                      _WorkTile(item: item),
                  if (_section == 2)
                    for (final station in data.stations)
                      ListTile(
                        title: Text('АЗС ${station.number}'),
                        subtitle: Text(
                          'Бригада: ${station.crewId ?? 'не закреплена'} · ${station.region ?? ''}',
                        ),
                      ),
                  if (_section == 3)
                    const Text(
                      'Паспорта оборудования открываются из карточки АЗС. Складской учёт не входит в первую версию.',
                    ),
                  if (_section == 4)
                    Text(
                      'В выборке ${data.work.length} строк. Файл отчёта повторяет этот фильтр.',
                    ),
                  if (_section == 5) ...[
                    for (final user in data.users)
                      ListTile(
                        title: Text(user.userId),
                        subtitle: Text(
                          user.scope == null
                              ? appRoleLabel(user.role)
                              : '${appRoleLabel(user.role)} · ${managerScopeLabel(user.scope!)}',
                        ),
                      ),
                    const Divider(),
                    const Text('Журнал аудита'),
                    for (final event in data.audit)
                      ListTile(
                        title: Text('${event.action} · ${event.entityType}'),
                        subtitle: Text(
                          '${event.entityId} · ${event.createdAt}',
                        ),
                      ),
                    const Divider(),
                    const Text('Справочники'),
                    for (final entry in data.directories)
                      ListTile(
                        title: Text(entry.name),
                        subtitle: Text(
                          entry.active ? entry.kind : '${entry.kind} · архив',
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.metrics});

  final PanelMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Открытые заявки', '${metrics.openRequests}'),
      ('Просроченные', '${metrics.overdueRequests}'),
      ('Требуют внимания', '${metrics.attentionStations}'),
      ('ТО на проверке', '${metrics.maintenanceWaitingAcceptance}'),
      ('ТО выполнено', '${metrics.maintenanceAccepted}'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final card in cards)
          SizedBox(
            width: 180,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.$2,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(card.$1),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.item});

  final PanelWorkItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Заявка ${item.id} · АЗС ${item.stationNumber}'),
      subtitle: Text(
        '${requestWorkflowLabel(item.status)}'
        '${item.overdue ? ' · просрочена' : ''}'
        '${item.assigneeId == null || item.assigneeId!.isEmpty ? '' : ' · ${item.assigneeId}'}',
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
