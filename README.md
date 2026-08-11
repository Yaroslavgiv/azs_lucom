# AZS App (Flutter)

Офлайн-приложение для учёта заявок и ТО по АЗС бригады **Новгород** + **Краснухин** (Санкт-Петербург).

## Запуск

```bash
cd mobile
flutter pub get
# Опционально: ключи DaData в mobile/.env (см. .env.example)
flutter run
```

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

- Вкладка **Карта** — `ntk_map_view`, маркеры с номером в popup
- Вкладка **Станции** — табы Новгород / СПб
- Вкладка **Экспорт** — xlsx + «Поделиться»
