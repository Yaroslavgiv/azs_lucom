import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/sync_status_banner.dart';
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

  static const _pages = [MapPage(), StationsListPage(), ExportPage()];

  @override
  Widget build(BuildContext context) {
    final banner = ref.watch(syncBannerProvider);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            banner.when(
              data: (model) => SyncStatusBanner(
                label: model.label,
                pending: model.pending,
                failed: model.failed,
                syncedAt: model.syncedAt,
              ),
              loading: () => const SizedBox(height: 8),
              error: (_, _) => const SyncStatusBanner(
                label: 'Не удалось прочитать состояние синхронизации',
                pending: 0,
                failed: 1,
              ),
            ),
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          index: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
