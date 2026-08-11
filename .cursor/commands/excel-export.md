# Новый Excel-экспорт

Добавь или измени выгрузку xlsx в azs_app.

## Обязательно

1. Прочитай skill `.cursor/skills/excel-export/SKILL.md` и `schemas.md`
2. Меняй логику только в `lib/core/services/export_service.dart`
3. При UI — кнопка в `lib/features/export/export_page.dart`
4. Сохрани имена файлов совместимыми с ботом (`заявки.xlsx`, `ТО.xlsx`, …)
5. Используй `package:excel` + `_shareExcel` / `_shareGroupedExcel`
6. Empty-state с колонкой `Сообщение`

Спроси уточнение только если неясен тип экспорта / регион / колонки.
