---
name: "source-command-review"
description: "Migrated source command `review`"
---

# source-command-review

Use this skill when the user asks to run the migrated source command `review`.

## Command Template

# Ревью изменений

Просмотри локальный diff проекта azs_app:

1. Архитектура: UI → providers → repos/services
2. Excel только через ExportService
3. Seed version bump при JSON
4. Секреты не в диффе
5. Русский UI

Формат замечаний:
- Critical — обязать исправить
- Suggestion — желательно
- Nice — по желанию

Не коммить и не пушь.
