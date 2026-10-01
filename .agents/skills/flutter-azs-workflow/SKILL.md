---
name: flutter-azs-workflow
description: >-
  Стандартный цикл разработки azs_app: analyze, hot reload, тесты, соглашения
  Riverpod/sqflite. Использовать при старте задач, рефакторинге, debug UI,
  проверке качества перед сдачей.
---

# Workflow разработки

## Предпочтения инструментов

1. MCP `user-dart` — analyze, hot_reload, devices, logs (если доступен)
2. Иначе shell: `flutter analyze`, `flutter test`, `flutter pub get`

## Перед сдачей изменения

- [ ] `flutter analyze` без новых ошибок
- [ ] UI-тексты на русском
- [ ] Данные через repository/service
- [ ] Excel только через ExportService
- [ ] Seed version bump если трогали JSON assets
- [ ] Нет секретов в диффе

## Паттерн UI refresh

После мутаций инвалидируй/обновляй providers так же, как в существующих экранах (`mapRefreshProvider`, локальные счётчики refresh).

## Тесты

Сейчас почти нет покрытий (`test/widget_test.dart` placeholder). Новые тесты — приветствуются для ExportService/repos; не раздувать без запроса.
