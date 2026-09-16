import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/maintenance_report.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class MaintenanceReportPage extends ConsumerStatefulWidget {
  const MaintenanceReportPage({super.key, required this.stationNumber});

  final String stationNumber;

  @override
  ConsumerState<MaintenanceReportPage> createState() =>
      _MaintenanceReportPageState();
}

class _MaintenanceReportPageState extends ConsumerState<MaintenanceReportPage> {
  final _comment = TextEditingController();
  final _items = <MaintenanceChecklistItem>[];
  final _photos = <String>[];
  bool _loading = true;
  bool _saving = false;
  String? _reviewComment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final equipmentRepo = await ref.read(equipmentRepositoryProvider.future);
    final maint = await ref.read(maintenanceRepositoryProvider.future);
    final equipment = await equipmentRepo.listForStation(widget.stationNumber);
    final existing = await maint.getRecord(widget.stationNumber);
    if (!mounted) return;
    setState(() {
      _reviewComment = existing?.reviewComment;
      _comment.text = existing?.comment ?? '';
      _photos
        ..clear()
        ..addAll(existing?.photoUrls ?? const []);
      if (existing != null && existing.checklist.isNotEmpty) {
        _items
          ..clear()
          ..addAll(existing.checklist);
      } else {
        _items
          ..clear()
          ..addAll(
            equipment.map(
              (item) => MaintenanceChecklistItem(
                equipmentId: '${item.id}',
                title: item.description,
                ok: true,
              ),
            ),
          );
      }
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _photos.add(file.path));
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final profile = ref.read(currentUserProfileProvider).value;
      final maint = await ref.read(maintenanceRepositoryProvider.future);
      await maint.submitForReview(
        widget.stationNumber,
        comment: _comment.text.trim(),
        checklist: List.of(_items),
        photoUrls: List.of(_photos),
        actorId: profile?.id,
        actorName: profile?.shortName,
      );
      ref.read(mapRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отчёт отправлен на приёмку')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('Отчёт ТО · ${widget.stationNumber}')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_reviewComment != null && _reviewComment!.isNotEmpty)
                    GlassCard(
                      child: Text(
                        'Возврат: $_reviewComment',
                        style: const TextStyle(color: AppColors.warning),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Чек-лист оборудования',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const GlassCard(
                      child: Text('На станции нет оборудования в справочнике'),
                    )
                  else
                    for (var i = 0; i < _items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_items[i].title),
                            subtitle: const Text('Исправно'),
                            value: _items[i].ok,
                            onChanged: (value) {
                              setState(() {
                                _items[i] = MaintenanceChecklistItem(
                                  equipmentId: _items[i].equipmentId,
                                  title: _items[i].title,
                                  ok: value,
                                  comment: _items[i].comment,
                                );
                              });
                            },
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _comment,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий к работам',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppSecondaryButton(
                    label: 'Добавить фото',
                    icon: Icons.photo_outlined,
                    onPressed: _pickPhoto,
                  ),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Фото: ${_photos.length}'),
                  ],
                  const SizedBox(height: 16),
                  AppPrimaryButton(
                    label: 'Отправить на приёмку',
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
      ),
    );
  }
}
