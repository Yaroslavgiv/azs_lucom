# Architecture

## Goals

- приложение остаётся работоспособным без сети;
- UI не зависит от Firebase и SQLite SDK;
- синхронизация не блокирует локальные пользовательские операции;
- внешние интеграции можно заменять и тестировать через abstraction boundaries;
- feature-модули не получают неограниченный доступ к базе данных.

## Layers

### Presentation

Каталог `features/` содержит экраны и локальное UI-состояние. Виджеты получают
зависимости через Riverpod и вызывают repositories/services, не SDK и не SQL.

### Application composition

`core/providers/app_providers.dart` — composition root приложения. Здесь
создаются database, repositories и services, а также описываются производные
асинхронные состояния.

### Data and integrations

Repositories инкапсулируют чтение и запись предметных данных. `SyncService`
отвечает за Firestore и очередь синхронизации. Auth выделен в отдельный
`AuthRepository`, поэтому Firebase-модели не протекают в presentation.

## Offline-first invariant

Локальная операция считается успешной после транзакции SQLite. Отправка в
Firestore выполняется отдельно. Неотправленные изменения сохраняются в
`sync_queue`; сопоставление локальных и облачных идентификаторов находится в
`sync_map`.

## Dependency rule

Допустимое направление зависимостей:

```text
features/shared -> providers -> repositories/services -> SDK adapters
```

Обратные зависимости и прямой доступ UI к `FirebaseAuth.instance`,
`FirebaseFirestore.instance` или `AppDatabase.db` запрещены.

## Trade-offs

- Riverpod используется одновременно как DI-контейнер и state management,
  что уменьшает boilerplate для приложения этого масштаба.
- SQLite остаётся источником данных для UI, поэтому интерфейс не зависит от
  задержек Firestore.
- Конфликты разрешаются текущей sync-политикой; для multi-user production
  потребуется документированная стратегия версионирования записей.
