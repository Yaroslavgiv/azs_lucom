# AZS App (Flutter)

Офлайн-приложение для учёта заявок и ТО по АЗС бригады **Новгород** + **Краснухин** (Санкт-Петербург).

## Запуск

```bash
git clone https://github.com/Yaroslavgiv/azs_lucom.git
cd azs_lucom
cp .env.example .env # необязательно: ключи нужны только для DaData
flutter pub get
flutter run
```

Проект не использует локальные path-зависимости и собирается независимо от
других репозиториев. Карта реализована на `flutter_map` и публичных тайлах
OpenStreetMap.

Без файла `.env` приложение также запускается: недоступным останется только
поиск координат через DaData. Firebase-конфигурация уже находится в проекте.

## Проверка качества

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage
flutter build apk --debug
```

Эти же проверки автоматически выполняются в GitHub Actions для каждого PR.

## Станции и координаты

Списки закладок Яндекс.Карт:

- СПб: https://yandex.ru/maps/?bookmarks%5BpublicId%5D=q6DYkOiJ
- Новгород: https://yandex.ru/maps/?bookmarks%5BpublicId%5D=83p1HWzN

Импорт из Яндекс (когда API доступен):

```bash
python scripts/import_yandex_bookmarks.py
```

Заполнение координат через Nominatim (если Яндекс отвечает 429):

```bash
python scripts/geocode_stations_nominatim.py
```

Базовый список номеров — из `Распределение.xlsx` (колонки Krasnukhin / Новгород).

## Структура

- Вкладка **Карта** — `flutter_map`, маркеры с номером АЗС
- Вкладка **Станции** — табы Новгород / СПб
- Вкладка **Экспорт** — xlsx + «Поделиться»
