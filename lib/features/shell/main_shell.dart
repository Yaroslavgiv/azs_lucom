import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../admin/manager_admin_page.dart';
import '../export/export_page.dart';
import '../map/map_page.dart';
import '../stations/stations_list_page.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final canManage = profile?.canManageUsers == true;
    final pages = <Widget>[
      const MapPage(),
      const StationsListPage(),
      const ExportPage(),
      if (canManage) const ManagerAdminPage(),
    ];
    final navItems = canManage
        ? AppBottomNav.managerItems
        : AppBottomNav.defaultItems;
    final safeIndex = _index.clamp(0, pages.length - 1);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: safeIndex, children: pages),
        bottomNavigationBar: AppBottomNav(
          index: safeIndex,
          items: navItems,
          onChanged: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
