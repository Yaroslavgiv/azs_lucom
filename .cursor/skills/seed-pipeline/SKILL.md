---
name: seed-pipeline
description: >-
  Обновление JSON seed assets и Python scripts для станций, operational data
  и оборудования. Использовать при изменении stations_yandex.json,
  operational_data.json, station_equipment.json, scripts/export_*.py,
  bump версий seed, импорте из Excel/DOCX/SQLite.
---

# Seed-пайплайн

## В приложении

1. Обнови JSON в `assets/`
2. Подними константу версии в seed-сервисе:
   - stations → `StationSeedService._seedVersion`
   - operational → `OperationalDataSeedService._dataVersion`
   - equipment → `EquipmentSeedService._dataVersion`
3. Убедись, что asset указан в `pubspec.yaml` → `flutter.assets`

## Скрипты mobile

| Скрипт | Вход → выход |
|--------|----------------|
| `scripts/export_operational_data.py` | SQLite → `operational_data.json` |
| `scripts/export_station_equipment.py` | DOCX OOXML → `station_equipment.json` |

Upstream (вне mobile): `Распределение.xlsx`, Яндекс-закладки, бот `azs.db`.

## Правила

- Версию bumpать при любом содержательном изменении JSON
- Не коммитить абсолютные user-пути в скриптах
- Excel импорт **в рантайме Flutter нет** — только seed + export
