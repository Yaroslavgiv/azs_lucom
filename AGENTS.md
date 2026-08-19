# AGENTS.md — azs_app (mobile)

Flutter-приложение учёта заявок и ТО по АЗС (СПб + Новгород) с offline-first кешем и синхронизацией через Firebase.

## Стек (обязательно соблюдать)

- Flutter / Dart `^3.11`, Material 3, тёмная glass-тема
- State: **flutter_riverpod**
- Локальный кеш: **sqflite** (`azs_app.db`)
- Облако: **Firebase** проект `my-home-chat-915a3` — Auth (email/password) + Cloud Firestore
- Sync: `lib/core/services/sync_service.dart` (pull/push + `sync_queue` / `sync_map`)
- Excel: пакет **`excel`** + **`share_plus`** (не Syncfusion, не csv)
- Карта: `flutter_map` + OpenStreetMap, без локальных path-зависимостей
- Сеть: DaData Suggest (геокодинг) + Firestore sync

## Архитектура

```
lib/
  core/          # DB, models, repositories, services, providers, theme, constants
  features/      # UI по фичам (auth, map, stations, station_detail, station_info, export, shell, geocode)
  shared/        # dialogs, widgets, navigation, utils
```

- Доступ к данным **только через repositories / services**, не из UI напрямую в `_db`
- UI пишет в sqflite; репозитории ставят задачи в `SyncService` → Firestore
- Перед Excel-экспортом при online — `pullAll()` из Firestore
- Новая фича → `lib/features/<name>/`
- Providers — в `lib/core/providers/app_providers.dart` (или рядом по согласованности)
- UI-тексты на **русском**, идентификаторы кода на **английском**
- Регионы в DB: `spb`, `novgorod`

## Firebase

- Конфиг: `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- Rules: `firestore.rules` (чтение/запись только для `request.auth != null`)
- Разовый seed в облако: `scripts/upload_seed_to_firestore.py` или `SyncService.seedCloudIfEmpty()` при первом входе
- Создайте пользователя Email/Password в Firebase Console → Authentication

## Excel (критично)

Вся генерация xlsx — только `lib/core/services/export_service.dart`.
Имена файлов и схемы — совместимы с Telegram-ботом `azs_bot` (`заявки.xlsx`, `ТО.xlsx`, …).
Подробности: skill `excel-export`.

## Seed / данные

JSON assets + bump версий в seed-сервисах при изменении (fallback без сети):

| Asset | Meta key | Версия в коде |
|-------|----------|---------------|
| `assets/stations_yandex.json` | `stations_seed_version` | `StationSeedService._seedVersion` |
| `assets/operational_data.json` | `operational_data_version` | `OperationalDataSeedService._dataVersion` |
| `assets/station_equipment.json` | `equipment_data_version` | `EquipmentSeedService._dataVersion` |

После успешного sync источник правды — Firestore.

## Роли субагентов

При делегировании через Task используй промпт из `.cursor/agents/` и тип ниже.

| Роль | Task type | Когда |
|------|-----------|--------|
| explore-azs | explore | Поиск по коду, «где X?», обзор фичи |
| flutter-implementer | generalPurpose | Реализация UI/фич/репозиториев |
| excel-export-agent | generalPurpose | Любые изменения xlsx / ExportService |
| data-pipeline-agent | generalPurpose | Seed JSON, scripts/, миграции schema |
| maps-geo-agent | generalPurpose | Карта, маркеры, DaData, geolocator, deep links |
| shell-runner | shell | flutter analyze / test / pub get |
| security-reviewer | security-review | Только по явной просьбе security review |
| bugbot-reviewer | bugbot | Только по явной просьбе Bugbot review |

Отвечай пользователю **по-русски**.

## Секреты

- `.env` содержит `DADATA_TOKEN` / `DADATA_SECRET` — не коммитить реальные ключи
- Не печатать секреты в чат и логи
- Не предлагать коммитить keystore / `local.properties` с паролями
- `google-services.json` / `firebase_options.dart` — клиентский конфиг Firebase (не класть service account JSON в репозиторий)
