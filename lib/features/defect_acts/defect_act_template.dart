import '../../core/models/station.dart';

String renderDefectActText({
  required int actNumber,
  required DateTime createdAt,
  required Station station,
  required String equipmentName,
  required String assessment,
  required String declaredFault,
  required String faulty,
  required String conclusion,
}) {
  final day = createdAt.day.toString();
  final month = _monthGenitive(createdAt.month);
  final year = createdAt.year.toString();

  final assessmentText = assessment.trim().isNotEmpty ? assessment.trim() : '—';

  final address = [
    if (station.name.trim().isNotEmpty) station.name.trim(),
    if (station.address.trim().isNotEmpty) station.address.trim(),
  ].join(', ');

  return '''
ООО Техцентр "ЛУКОМ-А"

"$day" $month $year г.

АКТ ДЕФЕКТАЦИИ ОБОРУДОВАНИЯ № $actNumber

Настоящий акт составлен в том, что специалистами технического отдела ООО Техцентр "ЛУКОМ-А" была проведена оценка исправности и ремонтопригодности следующего оборудования ООО «ЛУКОЙЛ-Северо-Западнефтепродукт»: $assessmentText

Оборудование демонтировано и находится на АЗС № $station.number "$day" $month $year г.

Адрес объекта: ${address.isNotEmpty ? address : '—'}

Заявленная неисправность: ${_textOrDash(declaredFault)}

Неисправны: ${_textOrDash(faulty)}

Заключение: ${_textOrDash(conclusion)}

Все неисправное оборудование, которое подлежит замене, оставлено на объекте.
'''.trim();
}

String _textOrDash(String v) => v.trim().isEmpty ? '—' : v.trim();

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
