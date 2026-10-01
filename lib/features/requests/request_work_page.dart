import 'package:azs_domain/azs_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/local_work_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class RequestWorkPage extends ConsumerStatefulWidget {
  const RequestWorkPage({super.key, required this.requestId});

  final int requestId;

  @override
  ConsumerState<RequestWorkPage> createState() => _RequestWorkPageState();
}

class _RequestWorkPageState extends ConsumerState<RequestWorkPage> {
  final _comment = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(WorkAction action) async {
    setState(() => _busy = true);
    try {
      final actor = await ref.read(sessionProfileProvider.future);
      if (actor == null) {
        _show('Профиль роли не загружен');
        return;
      }
      final work = await ref.read(localWorkServiceProvider.future);
      final result = await work.applyRequest(
        actor: actor,
        requestId: widget.requestId,
        action: action,
        comment: _comment.text,
      );
      _show(requestWorkflowLabel(result.nextStatus ?? action.name));
    } on WorkDenied catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('Заявка ${widget.requestId}')),
        body: _busy
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const GlassCard(
                    child: Text(
                      'Исполнитель берётся со станции. Комментарий сохраняется без вложений. Проверка руководителя нужна только если это задано правилом договора.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Комментарий'),
                  ),
                  const SizedBox(height: 12),
                  AppSecondaryButton(
                    label: 'Начать',
                    icon: Icons.play_arrow,
                    onPressed: () => _run(WorkAction.start),
                  ),
                  const SizedBox(height: 8),
                  AppPrimaryButton(
                    label: 'Завершить',
                    icon: Icons.task_alt,
                    onPressed: () => _run(WorkAction.complete),
                  ),
                  const SizedBox(height: 8),
                  AppSecondaryButton(
                    label: 'На проверку',
                    icon: Icons.fact_check_outlined,
                    onPressed: () => _run(WorkAction.submit),
                  ),
                  const SizedBox(height: 8),
                  AppSecondaryButton(
                    label: 'Принять',
                    icon: Icons.verified_outlined,
                    onPressed: () => _run(WorkAction.accept),
                  ),
                  const SizedBox(height: 8),
                  AppSecondaryButton(
                    label: 'Вернуть',
                    icon: Icons.undo,
                    onPressed: () => _run(WorkAction.returnForRework),
                  ),
                ],
              ),
      ),
    );
  }
}
