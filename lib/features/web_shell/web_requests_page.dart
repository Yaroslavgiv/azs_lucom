import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/domain/request_status.dart';
import '../../core/domain/time_period.dart';
import '../../core/models/request_item.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class WebRequestsPage extends ConsumerStatefulWidget {
  const WebRequestsPage({super.key});

  @override
  ConsumerState<WebRequestsPage> createState() => _WebRequestsPageState();
}

class _WebRequestsPageState extends ConsumerState<WebRequestsPage> {
  String? _region;
  String? _status = RequestStatus.created;
  int _refresh = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        ref
            .read(cloudDataServiceProvider)
            .requests(
              region: _region,
              status: _status,
              activeOnly: _status == null,
            ),
        ref
            .read(userProfileRepositoryProvider.future)
            .then((repo) => repo.listSpecialists()),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data![0] as List<RequestItem>;
        final specialists = snapshot.data![1] as List<UserProfile>;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: GlassCard(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String?>(
                      value: _region,
                      hint: const Text('Регион: все'),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Все регионы'),
                        ),
                        DropdownMenuItem(
                          value: regionSpb,
                          child: Text(regionLabelSpb),
                        ),
                        DropdownMenuItem(
                          value: regionNovgorod,
                          child: Text(regionLabelNovgorod),
                        ),
                      ],
                      onChanged: (value) => setState(() => _region = value),
                    ),
                    DropdownButton<String?>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Все статусы'),
                        ),
                        DropdownMenuItem(
                          value: RequestStatus.created,
                          child: Text('Новые'),
                        ),
                        DropdownMenuItem(
                          value: RequestStatus.assigned,
                          child: Text('Назначены'),
                        ),
                        DropdownMenuItem(
                          value: RequestStatus.inProgress,
                          child: Text('В работе'),
                        ),
                        DropdownMenuItem(
                          value: RequestStatus.overdue,
                          child: Text('Просрочены'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _status = value),
                    ),
                    Text('Показано: ${requests.length}'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = requests[index];
                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '№ ${item.remoteId ?? item.id} / ${item.stationNumber}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(item.requestType),
                        Text(item.description),
                        const SizedBox(height: 6),
                        Text(
                          '${item.statusLabel} · ${item.assigneeName ?? 'Не назначен'} · срок ${item.dueDate ?? '—'}',
                        ),
                        const SizedBox(height: 10),
                        AppPrimaryButton(
                          label: 'Назначить',
                          expand: false,
                          onPressed: specialists.isEmpty
                              ? null
                              : () => _assign(item, specialists),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assign(RequestItem item, List<UserProfile> specialists) async {
    var selected = specialists.first;
    var due = DateTime.now().add(const Duration(days: 2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Заявка ${item.stationNumber}: назначить'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<UserProfile>(
                    value: selected,
                    isExpanded: true,
                    items: [
                      for (final user in specialists)
                        DropdownMenuItem(
                          value: user,
                          child: Text(user.shortName),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setLocal(() => selected = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: due,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => due = picked);
                    },
                    child: Text('Срок: ${currentDateIso(due)}'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    final profile = ref.read(currentUserProfileProvider).value;
    await ref
        .read(cloudDataServiceProvider)
        .assignRequest(
          requestId: item.remoteId ?? '${item.id}',
          assigneeId: selected.id,
          assigneeName: selected.shortName,
          dueDate: currentDateIso(due),
          actorId: profile?.id,
          actorName: profile?.shortName,
        );
    setState(() => _refresh++);
  }
}
