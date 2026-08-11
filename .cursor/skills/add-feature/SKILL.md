---
name: add-feature
description: >-
  Добавление новой feature-папки Flutter в azs_app с Riverpod, репозиторием
  и подключением к MainShell или навигации. Использовать когда нужна новая
  вкладка, экран, CRUD-фича или модуль UI.
---

# Добавление фичи

## Структура

```
lib/features/<name>/
  <name>_page.dart
lib/core/repositories/   # если нужен доступ к данным
lib/core/services/       # если бизнес-логика вне UI
```

## Шаги

1. Определи: только UI или нужны repo/service/миграция DB
2. Создай page как `ConsumerWidget` / `ConsumerStatefulWidget`
3. Данные — через существующие или новые providers в `app_providers.dart`
4. Стили: `AppBackground`, `GlassCard`, shared buttons
5. Подключи: таб в `MainShell` / `AppBottomNav` **или** `Navigator.push` + `AppPageRoute`
6. Строки UI на русском
7. Запусти анализ: `flutter analyze` (через MCP dart или shell)

## Не делать

- Не класть raw SQL в widget
- Не создавать go_router/Bloc без запроса
- Не дублировать тему новыми color-hardcodes — используй `AppColors`
