# Схемы Excel-экспорта

Совместимость с Telegram-ботом `azs_bot` (openpyxl) — сохранять имена файлов.

## заявки.xlsx — лист «Заявки»

Метод: `shareRequests()`

| Колонка | Источник |
|---------|----------|
| region | stations.region |
| station_number | requests.station_number |
| type | requests.type |
| request_type | requests.request_type |
| description | requests.description |
| date_created | requests.date_created |

Фильтр: `status='open'`, регион in (`novgorod`,`spb`). Плоская таблица.

## ТО.xlsx — лист «ТО»

Метод: `shareMaintenance()`

| Колонка | Значение |
|---------|----------|
| region | stations.region |
| station_number | stations.number |
| name | stations.name |
| address | stations.address |
| status | `выполнено YYYY-MM` или `не выполнено` |
| date_done | maintenance.date_done |

Месяц: текущий `YYYY-MM`. LEFT JOIN maintenance.

## оборудование.xlsx — лист «Оборудование»

Метод: `shareEquipment()` — **группировка**

- Заголовок группы: `№ {number} — {name}`
- Subtitle: `{регион}, {address}`
- Колонки строк: `Категория`, `Описание`
- Категории: `Пожарка`, `КТСБ`

## заказ_оборудования_{Регион}.xlsx — «Заказ оборудования»

Метод: `shareEquipmentOrders(region)`

- Subtitle листа: `Дата выгрузки: YYYY-MM-DD`
- Группы: `№ N — name` + address
- Колонки: `Дата создания`, `Описание`
- Фильтр: open + `request_type = 'Заявки с заказом оборудования'` + region
- После успеха: insert `equipment_order_exports`, meta `equipment_orders_export_date_$region`

Регион в имени: `Санкт-Петербург` | `Новгород`.

## свежие_заказы_оборудования_{Регион}.xlsx — «Свежие заявки»

Метод: `shareFreshEquipmentOrders(region)`

- Как заказ, но `date_created > lastExportDate` (если meta есть)
- Без записи в `equipment_order_exports`

## Реализация билдеров

### `_shareExcel`

Заголовки = ключи **первой** строки map (параметр `headers` сейчас фактически не управляет колонками). Учитывай это при empty-state и порядке ключей в SQL alias.

### `_shareGroupedExcel`

Опциональный subtitle → для каждой группы: title(+subtitle) → header row → items → пустая строка между группами.
