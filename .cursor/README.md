# Cursor config — azs_app

Каталог конфигурации агента для Flutter-проекта учёта АЗС.

| Путь | Назначение |
|------|------------|
| `rules/` | Постоянные правила (архитектура, Excel, seed, UI, секреты) |
| `skills/` | Рабочие скиллы (вкл. `excel-export`) |
| `agents/` | Роли субагентов |
| `commands/` | Slash-команды (`/analyze`, `/excel-export`, …) |
| `hooks.json` + `hooks/` | Хуки сессии, shell, prompt, после edit |

См. корневой `AGENTS.md`.
