# Миграция sqflite

Нужна миграция `AppDatabase`:

1. Прочитай `lib/core/database/app_database.dart`
2. Увеличь `version`
3. Добавь `onUpgrade` ветку `oldVersion < N`
4. Обнови `_createSchema` для чистых установок
5. Обнови repositories/models при необходимости
6. Не удаляй данные пользователей без явного согласия

Опиши SQL и влияние на существующие установки.
