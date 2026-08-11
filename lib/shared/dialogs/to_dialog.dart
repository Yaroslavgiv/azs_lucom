import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webviewimage/webviewimage.dart';

import '../../core/providers/app_providers.dart';
import '../utils/date_format.dart';

Future<void> showToDialog(BuildContext context, {required String stationNumber}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => WebViewAware(
      child: Consumer(
        builder: (context, ref, _) => _ToDialogBody(
          stationNumber: stationNumber,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    ),
  );
}

class _ToDialogBody extends ConsumerStatefulWidget {
  const _ToDialogBody({required this.stationNumber, required this.onClose});

  final String stationNumber;
  final VoidCallback onClose;

  @override
  ConsumerState<_ToDialogBody> createState() => _ToDialogBodyState();
}

class _ToDialogBodyState extends ConsumerState<_ToDialogBody> {
  bool _loading = true;
  bool _doneThisMonth = false;
  String? _dateDone;
  String? _toType;
  String? _lastToText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final maint = await ref.read(maintenanceRepositoryProvider.future);
    final status = await maint.getStatus(widget.stationNumber);
    final last = await maint.getLastDone(widget.stationNumber);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _doneThisMonth = status.isDone;
      _dateDone = status.dateDone;
      _toType = status.toType;
      if (last != null) {
        final td = last['to_type'];
        _lastToText =
            'Последнее ТО: ${formatMaintenanceDate(last['date_done'])}${td != null && td.isNotEmpty ? ' ($td)' : ''}';
      } else {
        _lastToText = 'ТО ещё не выполнялось.';
      }
    });
  }

  Future<void> _markDone() async {
    final maint = await ref.read(maintenanceRepositoryProvider.future);
    await maint.markDone(widget.stationNumber);
    ref.invalidate(stationsByRegionProvider);
    ref.invalidate(maintenanceListProvider);
    ref.read(mapRefreshProvider.notifier).state++;
    widget.onClose();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ТО по станции ${widget.stationNumber} отмечено')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(content: Center(child: CircularProgressIndicator()));
    }

    if (_doneThisMonth) {
      final info = 'ТО в этом месяце уже выполнено: ${formatMaintenanceDate(_dateDone)}'
          '${_toType != null && _toType!.isNotEmpty ? ' ($_toType)' : ''}';
      return AlertDialog(
        title: Text('ТО — АЗС ${widget.stationNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info),
            const SizedBox(height: 12),
            Text(_lastToText ?? ''),
          ],
        ),
        actions: [
          TextButton(onPressed: widget.onClose, child: const Text('Закрыть')),
        ],
      );
    }

    return AlertDialog(
      title: Text('ТО — АЗС ${widget.stationNumber}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Отметить выполнение ТО в текущем месяце?'),
          const SizedBox(height: 12),
          Text(_lastToText ?? ''),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onClose, child: const Text('Отмена')),
        FilledButton(onPressed: _markDone, child: const Text('Отметить ТО')),
      ],
    );
  }
}
