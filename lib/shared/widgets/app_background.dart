import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Градиентный фон как на макете.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.gradientBackground),
      child: child,
    );
  }
}
