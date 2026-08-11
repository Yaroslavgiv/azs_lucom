---
name: excel-export
description: >-
  Генерация и изменение Excel (.xlsx) экспорта в azs_app через package excel
  и ExportService. Использовать при работе с заявки.xlsx, ТО.xlsx,
  оборудование.xlsx, заказ оборудования, свежие заказы, share_plus,
  схемами колонок или ExportPage.
---

# Excel-экспорт azs_app

## Когда применять

- Любое изменение выгрузки xlsx
- Новые типы экспорта / колонки / имена файлов
- Баги «пустой файл», «не та группировка», «свежие заказы не фильтруются»

## Единая точка кода

`lib/core/services/export_service.dart` + UI `lib/features/export/export_page.dart`

Библиотека: `package:excel` (`Excel.createExcel`, `TextCellValue`, `CellIndex`) + запись во temp + `Share.shareXFiles`.

## Workflow

1. Прочитай текущие методы `share*` в `ExportService`
2. Сверь схему с [schemas.md](schemas.md)
3. Плоская таблица → `_shareExcel`; группировка по станции → `_shareGroupedExcel`
4. Сохрани русские имена файлов (совместимость с Telegram-ботом)
5. Для полной выгрузки заказов — не забудь `_recordEquipmentOrderExport` + meta key
6. UI-кнопка в `ExportPage` при новом типе экспорта

## Чеклист нового экспорта

- [ ] Метод в `ExportService`
- [ ] Имя файла и листа согласованы
- [ ] Empty-state с `Сообщение`
- [ ] Кнопка на `ExportPage`
- [ ] Регион `spb`/`novgorod` и лейблы `Санкт-Петербург`/`Новгород` через `_regionLabel`
- [ ] Не добавить Syncfusion/csv без явного запроса

## Дополнительно

- Схемы колонок: [schemas.md](schemas.md)
