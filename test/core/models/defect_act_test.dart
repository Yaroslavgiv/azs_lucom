import 'package:azs_app/core/models/defect_act.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefectAct', () {
    test('round-trips persistence fields', () {
      final createdAt = DateTime.utc(2026, 8, 19, 10, 30);
      final source = DefectAct(
        id: 7,
        stationNumber: '78001',
        createdAt: createdAt,
        equipmentCategory: 'Пожарка',
        equipmentName: 'Извещатель',
        assessment: 'Требует замены',
        declaredFault: 'Нет связи',
        faulty: 'Да',
        conclusion: 'Заменить',
        renderedText: 'Акт',
      );

      final restored = DefectAct.fromMap({
        'id': source.id,
        ...source.toInsertMap(),
      });

      expect(restored.id, source.id);
      expect(restored.stationNumber, source.stationNumber);
      expect(restored.createdAt, createdAt);
      expect(restored.conclusion, source.conclusion);
    });

    test('uses safe defaults for an incomplete database row', () {
      final defectAct = DefectAct.fromMap(const {});

      expect(defectAct.id, 0);
      expect(defectAct.stationNumber, isEmpty);
      expect(defectAct.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });
}
