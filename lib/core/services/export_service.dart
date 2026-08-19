import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../database/app_database.dart';
import 'sync_change_publisher.dart';
import 'sync_service.dart';

class ExportService {
  ExportService(this._db, {SyncService? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncService? _sync;

  /// Pull from Firestore when online. Returns true if used cache only.
  Future<bool> ensureFreshData() async {
    final sync = _sync;
    if (sync == null) return true;
    if (!await sync.isOnline()) return true;
    await sync.pullAll();
    return false;
  }

  String _currentMonth() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> shareRequests() async {
    await ensureFreshData();
    final rows = await _db.db.rawQuery('''
      SELECT s.region, r.station_number, r.type, r.request_type, r.description, r.date_created
      FROM requests r
      JOIN stations s ON s.number = r.station_number
      WHERE r.status = 'open' AND s.region IN ('novgorod', 'spb')
      ORDER BY s.region, r.station_number, r.date_created
    ''');
    await _shareExcel(
      filename: 'заявки.xlsx',
      sheetName: 'Заявки',
      headers: [
        'region',
        'station_number',
        'type',
        'request_type',
        'description',
        'date_created',
      ],
      rows: rows.isEmpty
          ? [
              {'Сообщение': 'Нет открытых заявок'},
            ]
          : rows,
    );
  }

  Future<void> shareMaintenance() async {
    await ensureFreshData();
    final month = _currentMonth();
    final rows = await _db.db.rawQuery(
      '''
      SELECT s.region, s.number AS station_number, s.name, s.address,
        CASE WHEN m.status = 'done' THEN 'выполнено ' || m.month ELSE 'не выполнено' END AS status,
        m.date_done
      FROM stations s
      LEFT JOIN maintenance m ON s.number = m.station_number AND m.month = ?
      WHERE s.region IN ('novgorod', 'spb')
      ORDER BY s.region, s.number
    ''',
      [month],
    );
    await _shareExcel(
      filename: 'ТО.xlsx',
      sheetName: 'ТО',
      headers: [
        'region',
        'station_number',
        'name',
        'address',
        'status',
        'date_done',
      ],
      rows: rows.isEmpty
          ? [
              {'Сообщение': 'Нет данных по ТО'},
            ]
          : rows,
    );
  }

  /// Все оборудование по всем станциям, сгруппировано по станциям.
  Future<void> shareEquipment() async {
    await ensureFreshData();
    final rows = await _db.db.rawQuery('''
      SELECT s.region, s.number AS station_number, s.name, s.address,
        e.category, e.description
      FROM station_equipment e
      JOIN stations s ON s.number = e.station_number
      WHERE s.region IN ('novgorod', 'spb')
      ORDER BY s.region, CAST(s.number AS INTEGER), e.category, e.id
    ''');

    final grouped = _groupEquipmentByStation(rows);
    await _shareGroupedExcel(
      filename: 'оборудование.xlsx',
      sheetName: 'Оборудование',
      headers: ['Категория', 'Описание'],
      groups: grouped,
      emptyMessage: 'Нет оборудования',
    );
  }

  /// Полная выгрузка заявок с заказом оборудования по региону.
  Future<void> shareEquipmentOrders(String region) async {
    await ensureFreshData();
    final rows = await _queryEquipmentOrderRequests(region);
    final grouped = _groupRequestsByStation(rows);
    final exportDate = _today();
    final regionLabel = _regionLabel(region);

    await _shareGroupedExcel(
      filename: 'заказ_оборудования_$regionLabel.xlsx',
      sheetName: 'Заказ оборудования',
      headers: ['Дата создания', 'Описание'],
      groups: grouped,
      emptyMessage: 'Нет заявок с заказом оборудования',
      subtitle: 'Дата выгрузки: $exportDate',
    );

    if (rows.isNotEmpty) {
      await _recordEquipmentOrderExport(region, exportDate, rows);
    }
  }

  /// Свежие заявки с заказом оборудования с даты последней выгрузки.
  Future<void> shareFreshEquipmentOrders(String region) async {
    await ensureFreshData();
    final lastExportDate = await _db.getMeta(
      equipmentOrdersExportDateMetaKey(region),
    );
    final rows = await _queryEquipmentOrderRequests(
      region,
      sinceDate: lastExportDate,
    );
    final grouped = _groupRequestsByStation(rows);
    final regionLabel = _regionLabel(region);
    final subtitle = lastExportDate != null
        ? 'С даты последней выгрузки: $lastExportDate'
        : 'Полная выгрузка ещё не выполнялась — показаны все открытые заявки';

    await _shareGroupedExcel(
      filename: 'свежие_заказы_оборудования_$regionLabel.xlsx',
      sheetName: 'Свежие заявки',
      headers: ['Дата создания', 'Описание'],
      groups: grouped,
      emptyMessage: 'Нет свежих заявок с заказом оборудования',
      subtitle: subtitle,
    );
  }

  Future<List<Map<String, Object?>>> _queryEquipmentOrderRequests(
    String region, {
    String? sinceDate,
  }) async {
    final args = <Object>[requestTypeEquipmentOrder, region];
    var dateFilter = '';
    if (sinceDate != null) {
      dateFilter = 'AND r.date_created > ?';
      args.add(sinceDate);
    }

    return _db.db.rawQuery('''
      SELECT r.id, s.number AS station_number, s.name, s.address,
        r.description, r.date_created
      FROM requests r
      JOIN stations s ON s.number = r.station_number
      WHERE r.status = 'open'
        AND r.request_type = ?
        AND s.region = ?
        $dateFilter
      ORDER BY CAST(s.number AS INTEGER), r.date_created, r.id
    ''', args);
  }

  Future<void> _recordEquipmentOrderExport(
    String region,
    String exportDate,
    List<Map<String, Object?>> rows,
  ) async {
    final sync = _sync;
    for (final row in rows) {
      final id = await _db.db.insert('equipment_order_exports', {
        'region': region,
        'export_date': exportDate,
        'request_id': row['id'],
      });
      if (sync != null) {
        await sync.publishUpsertPayload(
          entity: SyncEntity.equipmentOrderExports,
          localPk: '$id',
          payload: {
            'region': region,
            'export_date': exportDate,
            'request_id': row['id'],
          },
        );
      }
    }
    await _db.setMeta(equipmentOrdersExportDateMetaKey(region), exportDate);
  }

  List<_ExportGroup> _groupEquipmentByStation(List<Map<String, Object?>> rows) {
    final groups = <_ExportGroup>[];
    String? currentStation;
    _ExportGroup? currentGroup;

    for (final row in rows) {
      final stationKey = '${row['station_number']}|${row['name']}';
      if (stationKey != currentStation) {
        currentStation = stationKey;
        currentGroup = _ExportGroup(
          title: '№ ${row['station_number']} — ${row['name']}',
          subtitle:
              '${_regionLabel(row['region'] as String?)}, ${row['address']}',
        );
        groups.add(currentGroup);
      }
      currentGroup!.items.add({
        'Категория': row['category'],
        'Описание': row['description'],
      });
    }
    return groups;
  }

  List<_ExportGroup> _groupRequestsByStation(List<Map<String, Object?>> rows) {
    final groups = <_ExportGroup>[];
    String? currentStation;
    _ExportGroup? currentGroup;

    for (final row in rows) {
      final stationKey = '${row['station_number']}|${row['name']}';
      if (stationKey != currentStation) {
        currentStation = stationKey;
        currentGroup = _ExportGroup(
          title: '№ ${row['station_number']} — ${row['name']}',
          subtitle: row['address']?.toString() ?? '',
        );
        groups.add(currentGroup);
      }
      currentGroup!.items.add({
        'Дата создания': row['date_created'],
        'Описание': row['description'],
      });
    }
    return groups;
  }

  String _regionLabel(String? region) {
    switch (region) {
      case regionSpb:
        return regionLabelSpb;
      case regionNovgorod:
        return regionLabelNovgorod;
      default:
        return region ?? '';
    }
  }

  Future<void> _shareGroupedExcel({
    required String filename,
    required String sheetName,
    required List<String> headers,
    required List<_ExportGroup> groups,
    required String emptyMessage,
    String? subtitle,
  }) async {
    if (groups.isEmpty) {
      await _shareExcel(
        filename: filename,
        sheetName: sheetName,
        headers: ['Сообщение'],
        rows: [
          {'Сообщение': emptyMessage},
        ],
      );
      return;
    }

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) excel.delete(defaultSheet);
    final sheet = excel[sheetName];

    var rowIndex = 0;
    if (subtitle != null) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        subtitle,
      );
      rowIndex++;
      rowIndex++;
    }

    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        group.title,
      );
      if (group.subtitle.isNotEmpty) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          group.subtitle,
        );
      }
      rowIndex++;

      for (var c = 0; c < headers.length; c++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          headers[c],
        );
      }
      rowIndex++;

      for (final item in group.items) {
        for (var c = 0; c < headers.length; c++) {
          final v = item[headers[c]];
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
              )
              .value = TextCellValue(
            v?.toString() ?? '',
          );
        }
        rowIndex++;
      }

      if (g < groups.length - 1) rowIndex++;
    }

    await _writeAndShare(excel, filename);
  }

  Future<void> _shareExcel({
    required String filename,
    required String sheetName,
    required List<String> headers,
    required List<Map<String, Object?>> rows,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) excel.delete(defaultSheet);
    final sheet = excel[sheetName];

    final keys = rows.first.keys.toList();
    for (var c = 0; c < keys.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(
        keys[c].toString(),
      );
    }
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < keys.length; c++) {
        final v = row[keys[c]];
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
            .value = TextCellValue(
          v?.toString() ?? '',
        );
      }
    }

    await _writeAndShare(excel, filename);
  }

  Future<void> _writeAndShare(Excel excel, String filename) async {
    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    await File(path).writeAsBytes(bytes);
    await Share.shareXFiles([XFile(path)], text: filename);
  }
}

class _ExportGroup {
  _ExportGroup({required this.title, this.subtitle = ''});

  final String title;
  final String subtitle;
  final List<Map<String, Object?>> items = [];
}
