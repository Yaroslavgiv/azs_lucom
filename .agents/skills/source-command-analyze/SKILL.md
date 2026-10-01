---
name: "source-command-analyze"
description: "Migrated source command `analyze`"
---

# source-command-analyze

Use this skill when the user asks to run the migrated source command `analyze`.

## Command Template

# Анализ проекта azs_app

Кратко проверь текущее состояние и ответь по-русски:

1. Запусти `flutter analyze` (MCP dart или shell)
2. Перечисли незакоммиченные изменения (если git) без лишних деталей
3. Укажи риски: seed versions, Excel, секреты `.env`
4. Предложи следующий шаг (1–3 пункта)

Не создавай файлы без необходимости.
