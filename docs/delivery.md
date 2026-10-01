# Комплект поставки первой версии

- Мобильный клиент: `lib/main.dart`, навигация «Карта / Станции / Экспорт».
- Web-панель: `lib/main_web.dart`.
- Общие правила: `packages/azs_domain`.
- Сервисный слой: `functions/` (`applyWorkCommand` в регионе `europe-west1`).
- Правила доступа: `firestore.rules`, `storage.rules`.
- Контракты: [technical-design.md](technical-design.md), [roles.md](roles.md), [open-questions.md](open-questions.md).
- Отчёты: прежние книги для бота и `отчёт_выборки.xlsx`.
- Проверка: `flutter test`, `node --test functions/test/workflow.test.js`.
- Восстановление: [backup.md](backup.md).
- Пилот: [pilot.md](pilot.md).

Сборка мобильного клиента:

```bash
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

Сборка web-панели:

```bash
flutter build web -t lib/main_web.dart
```

Промышленный Firebase-проект должен быть отделён от тестового. Внешний источник заявок подключается через `RequestSource`, когда заказчик передаст контракт.
