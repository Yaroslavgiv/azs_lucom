import 'package:flutter/material.dart';

import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../export/export_page.dart';
import '../map/map_page.dart';
import '../stations/stations_list_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [MapPage(), StationsListPage(), ExportPage()];

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: AppBottomNav(
          index: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
