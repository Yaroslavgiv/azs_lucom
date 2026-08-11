---
name: maps-geo
description: >-
  Работа с картой АЗС (ntk_map_view / MapLibre), маркерами ТО, geolocator,
  DaData Suggest, deep links Яндекс/2ГИС. Использовать при багах карты,
  геокодинге, внешним маршрутам, стилях Yandex Object Storage.
---

# Карта и гео

## Ключевые файлы

- `lib/features/map/map_page.dart`
- `lib/core/services/geocoder_service.dart` — DaData
- `lib/core/services/location_service.dart`
- `lib/core/services/external_maps_service.dart`
- `lib/features/geocode/geocode_page.dart` (может быть не в стартовом flow)
- Константы карты: `lib/core/constants.dart` (`mapStyleLight`, centers, zoom)

## Правила

- Стиль карты: Yandex Cloud URL из constants — не ломай без причины
- Маркеры статуса ТО: зелёный/жёлтый — сохраняй семантику
- Токены DaData только из `.env`
- Path-пакет `ntk_map_view` — внешний; правки там согласовывать отдельно
- Навигация наружу: `url_launcher` deep links, не WebView-хаки без нужды
