import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

import '../models/defect_act.dart';
import '../models/station.dart';

class DefectActDocxService {
  const DefectActDocxService();

  static const _templateAsset = 'assets/templates/defect_act_template.docx';

  /// Генерирует DOCX по шаблону и сохраняет по пути [outputPath].
  Future<void> saveToFile({
    required String outputPath,
    required Station station,
    required DefectAct act,
  }) async {
    final templateBytes = (await rootBundle.load(
      _templateAsset,
    )).buffer.asUint8List();
    final archive = ZipDecoder().decodeBytes(templateBytes);
    final values = _buildValues(station: station, act: act);
    var documentXml = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'word/document.xml').content
          as List<int>,
    );
    for (final entry in values.entries) {
      documentXml = documentXml.replaceAll(entry.key, _xmlEscape(entry.value));
    }
    final encodedXml = utf8.encode(documentXml);

    final outArchive = Archive();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final content = file.name == 'word/document.xml'
          ? encodedXml
          : file.content as List<int>;
      outArchive.addFile(ArchiveFile(file.name, content.length, content));
    }

    final outBytes = ZipEncoder().encode(outArchive);
    if (outBytes == null) {
      throw StateError('Не удалось собрать DOCX');
    }
    await File(outputPath).writeAsBytes(outBytes, flush: true);
  }

  Map<String, String> buildPlaceholderValues({
    required Station station,
    required DefectAct act,
  }) {
    return _buildValues(station: station, act: act);
  }

  Map<String, String> _buildValues({
    required Station station,
    required DefectAct act,
  }) {
    final createdAt = act.createdAt.toLocal();
    final day = createdAt.day.toString();
    final month = '${_monthGenitive(createdAt.month)} ';
    final year = createdAt.year.toString();

    final address = _joinNonEmpty([
      if (station.name.trim().isNotEmpty) station.name.trim(),
      station.address.trim(),
    ], separator: ', ');

    return {
      '{{ACT_DAY}}': day,
      '{{ACT_MONTH}}': month,
      '{{ACT_YEAR}}': year,
      '{{ACT_NUMBER}}': act.id.toString(),
      '{{ASSESSMENT}}': _leadingSpace(act.assessment),
      '{{STATION_NUMBER}}': station.number,
      '{{STATION_DAY}}': day,
      '{{STATION_MONTH}}': month,
      '{{STATION_YEAR}}': year,
      '{{STATION_ADDRESS}}': _leadingSpace(address.isNotEmpty ? address : '—'),
      '{{DECLARED_FAULT}}': _leadingSpace(act.declaredFault),
      '{{FAULTY}}': _leadingSpace(act.faulty),
      '{{CONCLUSION}}': _leadingSpace(act.conclusion),
    };
  }
}

String _leadingSpace(String v) {
  final text = v.trim();
  if (text.isEmpty) return ' —';
  return ' $text';
}

String _joinNonEmpty(List<String> parts, {required String separator}) {
  return parts.where((p) => p.isNotEmpty).join(separator);
}

String _monthGenitive(int month) {
  const names = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  return names[month - 1];
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;')
      .replaceAll('\r\n', '&#10;')
      .replaceAll('\n', '&#10;')
      .replaceAll('\r', '&#10;');
}
