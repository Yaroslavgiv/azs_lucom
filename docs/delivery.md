# Комплект поставки

- Мобильный клиент: `lib/main.dart`.
- Web-панель: `lib/main_web.dart`.
- Общие правила: `packages/azs_domain`.
- Сервисный слой: `functions/` (`applyWorkCommand`, регион `europe-west1`).
- Правила доступа: `firestore.rules`.
- Контракты: [technical-design.md](technical-design.md), [roles.md](roles.md), [implementation-plan-v1.3.md](implementation-plan-v1.3.md).
- Отчёты: прежние книги для бота и `отчёт_выборки.xlsx`.
- Проверка: `flutter test`, `node --test functions/test/workflow.test.js`.
- Смена backend: [firebase-migration.md](firebase-migration.md).
- Восстановление: [backup.md](backup.md).
- Пилот: [pilot.md](pilot.md).

## Сборка

```bash
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
flutter build web -t lib/main_web.dart
```

## Обязанности заказчика

Учётная запись Apple Developer, сертификаты и публикация iOS-сборки принадлежат заказчику. Репозиторий не содержит паролей подписи и service account. Промышленный Firebase-проект отделён от тестового. Перенос на другой backend выполняется по [firebase-migration.md](firebase-migration.md) и в эту поставку не входит.
