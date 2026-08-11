import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/defect_act.dart';
import '../../core/models/station.dart';
import '../../core/models/station_equipment_item.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/defect_act_docx_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';
import 'defect_act_template.dart';

final _defectActsProvider =
    FutureProvider.family<List<DefectAct>, String>((ref, stationNumber) async {
  await ref.watch(appInitProvider.future);
  final repo = await ref.watch(defectActRepositoryProvider.future);
  return repo.listByStation(stationNumber);
});

final _stationProvider = FutureProvider.family<Station?, String>((ref, number) async {
  await ref.watch(appInitProvider.future);
  final repo = await ref.watch(stationRepositoryProvider.future);
  return repo.getByNumber(number);
});

class DefectActsPage extends ConsumerWidget {
  const DefectActsPage({super.key, required this.stationNumber});

  final String stationNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationAsync = ref.watch(_stationProvider(stationNumber));
    final actsAsync = ref.watch(_defectActsProvider(stationNumber));

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Акты дефектации — №$stationNumber'),
          actions: [
            IconButton(
              tooltip: 'Выгрузить все акты',
              onPressed: () async {
                final station = await ref.read(_stationProvider(stationNumber).future);
                if (station == null) return;
                final acts = await ref.read(_defectActsProvider(stationNumber).future);
                if (!context.mounted) return;
                await _shareActs(context, station: station, acts: acts);
              },
              icon: const Icon(Icons.upload_file),
            ),
          ],
        ),
        body: stationAsync.when(
          data: (station) {
            if (station == null) {
              return const Center(child: Text('Станция не найдена'));
            }
            return actsAsync.when(
              data: (acts) => _Body(
                station: station,
                acts: acts,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (e, _) => Center(
                child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.error)),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.station, required this.acts});

  final Station station;
  final List<DefectAct> acts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (acts.isEmpty)
          const GlassCard(
            child: Text(
              'Актов пока нет',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...acts.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            a.equipmentName.isNotEmpty
                                ? a.equipmentName
                                : 'Оборудование не указано',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Выгрузить акт (.docx)',
                          onPressed: () async {
                            await _shareSingleAct(
                              context,
                              station: station,
                              act: a,
                            );
                          },
                          icon: const Icon(Icons.ios_share),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Акт №${a.id} от ${_formatDate(a.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppSecondaryButton(
                            label: 'Открыть',
                            icon: Icons.description_outlined,
                            onPressed: () => _showActPreview(context, a),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppSecondaryButton(
                            label: 'Удалить',
                            icon: Icons.delete_outline,
                            onPressed: () async {
                              final ok = await _confirmDelete(context);
                              if (!ok) return;
                              final repo = await ref.read(defectActRepositoryProvider.future);
                              await repo.deleteById(a.id);
                              ref.invalidate(_defectActsProvider(station.number));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        AppPrimaryButton(
          label: 'Составить акт',
          icon: Icons.add_circle_outline,
          onPressed: () async {
            await _createActFlow(context, ref, station: station);
          },
        ),
      ],
    );
  }
}

Future<void> _shareSingleAct(
  BuildContext context, {
  required Station station,
  required DefectAct act,
}) async {
  final dir = await getTemporaryDirectory();
  final docxService = const DefectActDocxService();
  final docxName = 'акт_дефектации_${station.number}_${act.id}.docx';
  final docxFile = File('${dir.path}/$docxName');

  XFile toShare;
  try {
    await docxService.saveToFile(
      outputPath: docxFile.path,
      station: station,
      act: act,
    );
    toShare = XFile(docxFile.path);
  } catch (_) {
    final txtName = 'акт_дефектации_${station.number}_${act.id}.txt';
    final txtFile = File('${dir.path}/$txtName');
    await txtFile.writeAsString(
      act.renderedText.isNotEmpty ? act.renderedText : _fallbackText(act, station),
      flush: true,
    );
    toShare = XFile(txtFile.path);
  }

  if (!context.mounted) return;
  await Share.shareXFiles(
    [toShare],
    text: 'Акт дефектации №${act.id} — АЗС №${station.number}',
  );
}

Future<void> _createActFlow(
  BuildContext context,
  WidgetRef ref, {
  required Station station,
}) async {
  final equipmentRepo = await ref.read(equipmentRepositoryProvider.future);
  final equipment = await equipmentRepo.listForStation(station.number);
  if (!context.mounted) return;

  final equipmentChoice =
      await _askEquipmentName(context, equipment: equipment);
  if (equipmentChoice == null) return;
  if (!context.mounted) return;

  final result = await showModalBottomSheet<_WizardResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _DefectActWizardDialog(equipmentName: equipmentChoice.name),
  );
  if (result == null) return;

  final createdAt = DateTime.now();
  final repo = await ref.read(defectActRepositoryProvider.future);
  final actId = await repo.create(
    stationNumber: station.number,
    createdAt: createdAt,
    equipmentCategory: equipmentChoice.category,
    equipmentName: equipmentChoice.name,
    assessment: result.assessment,
    declaredFault: result.declaredFault,
    faulty: result.faulty,
    conclusion: result.conclusion,
    renderedText: '',
  );

  final rendered = renderDefectActText(
    actNumber: actId,
    createdAt: createdAt,
    station: station,
    equipmentName: equipmentChoice.name,
    assessment: result.assessment,
    declaredFault: result.declaredFault,
    faulty: result.faulty,
    conclusion: result.conclusion,
  );

  await repo.updateRenderedText(id: actId, renderedText: rendered);

  ref.invalidate(_defectActsProvider(station.number));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Акт сохранён')),
    );
  }
}

Future<void> _shareActs(
  BuildContext context, {
  required Station station,
  required List<DefectAct> acts,
}) async {
  if (acts.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Актов нет')),
    );
    return;
  }

  final dir = await getTemporaryDirectory();
  final files = <XFile>[];
  final docxService = const DefectActDocxService();
  for (final a in acts) {
    final fileName = 'акт_дефектации_${station.number}_${a.id}.docx';
    final file = File('${dir.path}/$fileName');
    try {
      await docxService.saveToFile(
        outputPath: file.path,
        station: station,
        act: a,
      );
      files.add(XFile(file.path));
    } catch (_) {
      // Фоллбек: если что-то пошло не так с docx — отдаём текст.
      final txtName = 'акт_дефектации_${station.number}_${a.id}.txt';
      final txtFile = File('${dir.path}/$txtName');
      await txtFile.writeAsString(
        a.renderedText.isNotEmpty ? a.renderedText : _fallbackText(a, station),
        flush: true,
      );
      files.add(XFile(txtFile.path));
    }
  }

  if (!context.mounted) return;
  await Share.shareXFiles(
    files,
    text: 'Акты дефектации — АЗС №${station.number}',
  );
}

String _fallbackText(DefectAct a, Station station) {
  return renderDefectActText(
    actNumber: a.id,
    createdAt: a.createdAt,
    station: station,
    equipmentName: a.equipmentName,
    assessment: a.assessment,
    declaredFault: a.declaredFault,
    faulty: a.faulty,
    conclusion: a.conclusion,
  );
}

Future<bool> _confirmDelete(BuildContext context) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удалить акт?'),
      content: const Text('Действие необратимо.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  return res ?? false;
}

void _showActPreview(BuildContext context, DefectAct act) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Акт №${act.id}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: SelectableText(act.renderedText.isNotEmpty ? act.renderedText : 'Нет текста'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

String _formatDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

Future<_EquipmentChoice?> _askEquipmentName(
  BuildContext context, {
  required List<StationEquipmentItem> equipment,
}) async {
  final controller = TextEditingController();
  _EquipmentChoice? selected;

  final res = await showModalBottomSheet<_EquipmentChoice?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        const fieldLabel = 'Название оборудования';
        return _KeyboardSafeFormSheet(
          title: 'Оборудование',
          fieldLabel: fieldLabel,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final v = controller.text.trim();
                if (v.isEmpty) {
                  Navigator.of(ctx).pop(null);
                  return;
                }
                Navigator.of(ctx).pop(
                  _EquipmentChoice(name: v, category: selected?.category ?? ''),
                );
              },
              child: const Text('Далее'),
            ),
          ],
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (equipment.isNotEmpty) ...[
                Text(
                  'Выберите из списка или введите вручную:',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: equipment.length,
                    itemBuilder: (_, i) {
                      final e = equipment[i];
                      final name = e.description.trim().isNotEmpty
                          ? e.description.trim()
                          : e.category.trim();
                      final choice = _EquipmentChoice(
                        name: name,
                        category: e.category.trim(),
                      );
                      final isSelected = selected == choice;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(name),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.accent)
                            : const Icon(Icons.circle_outlined, color: AppColors.textSecondary),
                        onTap: () {
                          setState(() {
                            selected = choice;
                            controller.text = choice.name;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: equipment.isEmpty,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: fieldLabel,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return res;
}

class _EquipmentChoice {
  const _EquipmentChoice({required this.name, required this.category});

  final String name;
  final String category;

  @override
  bool operator ==(Object other) =>
      other is _EquipmentChoice && other.name == name && other.category == category;

  @override
  int get hashCode => Object.hash(name, category);
}

class _WizardResult {
  const _WizardResult({
    required this.assessment,
    required this.declaredFault,
    required this.faulty,
    required this.conclusion,
  });

  final String assessment;
  final String declaredFault;
  final String faulty;
  final String conclusion;
}

class _DefectActWizardDialog extends StatefulWidget {
  const _DefectActWizardDialog({required this.equipmentName});

  final String equipmentName;

  @override
  State<_DefectActWizardDialog> createState() => _DefectActWizardDialogState();
}

class _DefectActWizardDialogState extends State<_DefectActWizardDialog> {
  int step = 0;

  final assessmentCtrl = TextEditingController();
  final declaredFaultCtrl = TextEditingController();
  final faultyCtrl = TextEditingController();
  final conclusionCtrl = TextEditingController();

  @override
  void dispose() {
    assessmentCtrl.dispose();
    declaredFaultCtrl.dispose();
    faultyCtrl.dispose();
    conclusionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (step) {
      0 => 'Оценка исправности и ремонтопригодности',
      1 => 'Заявленная неисправность',
      2 => 'Неисправны',
      _ => 'Заключение',
    };

    final ctrl = switch (step) {
      0 => assessmentCtrl,
      1 => declaredFaultCtrl,
      2 => faultyCtrl,
      _ => conclusionCtrl,
    };

    return _KeyboardSafeFormSheet(
      title: 'Шаг ${step + 1} из 4',
      fieldLabel: title,
      subtitle: 'Оборудование: ${widget.equipmentName}',
      actions: [
        TextButton(
          onPressed: step == 0
              ? null
              : () => setState(() {
                    step -= 1;
                  }),
          child: const Text('Назад'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            if (step < 3) {
              setState(() => step += 1);
              return;
            }
            Navigator.of(context).pop(
              _WizardResult(
                assessment: assessmentCtrl.text.trim(),
                declaredFault: declaredFaultCtrl.text.trim(),
                faulty: faultyCtrl.text.trim(),
                conclusion: conclusionCtrl.text.trim(),
              ),
            );
          },
          child: Text(step < 3 ? 'Далее' : 'Сохранить'),
        ),
      ],
      body: TextField(
        key: ValueKey('defect_act_step_$step'),
        controller: ctrl,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          labelText: title,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
          hintText: 'Введите текст',
        ),
      ),
    );
  }
}

/// Нижний лист ввода: всегда над клавиатурой, без уезда за верх экрана.
class _KeyboardSafeFormSheet extends StatelessWidget {
  const _KeyboardSafeFormSheet({
    required this.title,
    required this.fieldLabel,
    required this.body,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String fieldLabel;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final maxSheetHeight = mq.size.height - keyboard - mq.padding.top - 8;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Material(
            color: AppColors.surfaceRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      fieldLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    body,
                    const SizedBox(height: 8),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 8,
                      children: actions,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

