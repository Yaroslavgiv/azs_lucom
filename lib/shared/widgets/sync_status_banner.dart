import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    super.key,
    required this.label,
    required this.pending,
    required this.failed,
    this.syncedAt,
  });

  final String label;
  final int pending;
  final int failed;
  final String? syncedAt;

  @override
  Widget build(BuildContext context) {
    final color = failed > 0 ? AppColors.error : AppColors.textSecondary;
    final synced = syncedAt == null || syncedAt!.isEmpty
        ? 'ещё не было успешной синхронизации'
        : 'последняя синхронизация $syncedAt';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        '$label. Ожидают отправки: $pending. Ошибки: $failed. $synced',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}
