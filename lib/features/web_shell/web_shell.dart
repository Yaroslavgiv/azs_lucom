import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';
import 'web_equipment_page.dart';
import 'web_overview_page.dart';
import 'web_reports_page.dart';
import 'web_requests_page.dart';
import 'web_stations_page.dart';
import 'web_users_page.dart';

class WebShell extends ConsumerStatefulWidget {
  const WebShell({super.key});

  @override
  ConsumerState<WebShell> createState() => _WebShellState();
}

class _WebShellState extends ConsumerState<WebShell> {
  int _index = 0;

  static const _titles = [
    'Обзор',
    'Заявки',
    'Станции',
    'Оборудование',
    'Отчёты',
    'Пользователи',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = const [
      WebOverviewPage(),
      WebRequestsPage(),
      WebStationsPage(),
      WebEquipmentPage(),
      WebReportsPage(),
      WebUsersPage(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                backgroundColor: AppColors.surface.withValues(alpha: 0.9),
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  child: Text(
                    'АЗС',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Обзор'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: Text('Заявки'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.local_gas_station_outlined),
                    selectedIcon: Icon(Icons.local_gas_station),
                    label: Text('Станции'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.memory_outlined),
                    selectedIcon: Icon(Icons.memory),
                    label: Text('Оборудование'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.table_chart_outlined),
                    selectedIcon: Icon(Icons.table_chart),
                    label: Text('Отчёты'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: Text('Пользователи'),
                  ),
                ],
              ),
            Expanded(
              child: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                      child: Row(
                        children: [
                          if (!wide)
                            IconButton(
                              onPressed: () => _showMenu(context),
                              icon: const Icon(Icons.menu),
                            ),
                          Expanded(
                            child: Text(
                              _titles[_index],
                              style: Theme.of(context).textTheme.headlineSmall,
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
                  Expanded(child: pages[_index]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _titles.length; i++)
              ListTile(
                title: Text(_titles[i]),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _index = selected);
  }
}

class WebFilterBar extends StatelessWidget {
  const WebFilterBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GlassCard(child: child),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.accent = AppColors.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class WebEmpty extends StatelessWidget {
  const WebEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}

class WebPrimaryAction extends StatelessWidget {
  const WebPrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(label: label, expand: false, onPressed: onPressed);
  }
}
