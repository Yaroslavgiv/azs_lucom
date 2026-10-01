import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.outlinedIcon,
    required this.filledIcon,
    required this.label,
  });

  final IconData outlinedIcon;
  final IconData filledIcon;
  final String label;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    this.items = defaultItems,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<AppBottomNavItem> items;

  static const defaultItems = [
    AppBottomNavItem(
      outlinedIcon: Icons.map_outlined,
      filledIcon: Icons.map,
      label: 'Карта',
    ),
    AppBottomNavItem(
      outlinedIcon: Icons.local_gas_station_outlined,
      filledIcon: Icons.local_gas_station,
      label: 'Станции',
    ),
    AppBottomNavItem(
      outlinedIcon: Icons.upload_file_outlined,
      filledIcon: Icons.upload_file,
      label: 'Экспорт',
    ),
  ];

  static const managerItems = [
    ...defaultItems,
    AppBottomNavItem(
      outlinedIcon: Icons.admin_panel_settings_outlined,
      filledIcon: Icons.admin_panel_settings,
      label: 'Панель',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == index;
              return Expanded(
                child: _NavItem(
                  selected: selected,
                  icon: selected ? item.filledIcon : item.outlinedIcon,
                  label: item.label,
                  onTap: () => onChanged(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.gradientAccent : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
