import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../admin/manager_admin_page.dart';
import '../map/map_page.dart';
import 'manager_overview_page.dart';
import 'manager_reports_page.dart';
import 'manager_requests_page.dart';
import 'manager_stations_page.dart';

/// Web workplace for manager/admin — sections from the proposal mockups.
class ManagerWebShell extends ConsumerStatefulWidget {
  const ManagerWebShell({super.key});

  @override
  ConsumerState<ManagerWebShell> createState() => _ManagerWebShellState();
}

class _ManagerWebShellState extends ConsumerState<ManagerWebShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Обзор'),
    (Icons.map_outlined, Icons.map, 'Карта'),
    (Icons.assignment_outlined, Icons.assignment, 'Заявки'),
    (Icons.local_gas_station_outlined, Icons.local_gas_station, 'Станции'),
    (Icons.assessment_outlined, Icons.assessment, 'Отчёты'),
    (Icons.group_outlined, Icons.group, 'Пользователи'),
  ];

  static const _pages = [
    ManagerOverviewPage(),
    MapPage(),
    ManagerRequestsPage(),
    ManagerStationsPage(),
    ManagerReportsPage(),
    ManagerAdminPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                extended: MediaQuery.sizeOf(context).width >= 1180,
                backgroundColor: AppColors.surface.withValues(alpha: 0.72),
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.local_gas_station,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'АЗС',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?.role.labelRu ?? 'Руководитель',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        tooltip: 'Выйти',
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        icon: const Icon(Icons.logout),
                      ),
                    ),
                  ),
                ),
                destinations: [
                  for (final item in _destinations)
                    NavigationRailDestination(
                      icon: Icon(item.$1),
                      selectedIcon: Icon(item.$2),
                      label: Text(item.$3),
                    ),
                ],
              ),
            Expanded(
              child: Column(
                children: [
                  if (!wide)
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (var i = 0;
                                        i < _destinations.length;
                                        i++) ...[
                                      ChoiceChip(
                                        label: Text(_destinations[i].$3),
                                        selected: _index == i,
                                        onSelected: (_) =>
                                            setState(() => _index = i),
                                        selectedColor: AppColors.accent
                                            .withValues(alpha: 0.25),
                                        labelStyle: TextStyle(
                                          color: _index == i
                                              ? AppColors.accent
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Выйти',
                              onPressed: () =>
                                  ref.read(authRepositoryProvider).signOut(),
                              icon: const Icon(Icons.logout),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: IndexedStack(index: _index, children: _pages),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
