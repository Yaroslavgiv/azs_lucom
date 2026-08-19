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

Каталог `core/providers/` — composition root приложения. Auth и infrastructure
bindings разделены по отдельным файлам; `app_providers.dart` содержит только
application orchestration и производные состояния.

### Data and integrations

Repositories инкапсулируют чтение и запись предметных данных. `SyncService`
отвечает за Firestore и очередь синхронизации. Auth выделен в отдельный
`AuthRepository`, поэтому Firebase-модели не протекают в presentation.

Repositories публикуют локальные изменения через `SyncChangePublisher` и не
зависят от реализации `SyncService`, Firestore SDK или устройства очереди.
Это позволяет тестировать бизнес-операции с in-memory fake и заменять облачный
transport без изменений в data layer.

`SyncPayloadResolver` формирует облачные снимки из SQLite независимо от сетевого
transport. `SyncService` оркестрирует очередь и Firestore, но больше не содержит
SQL-запросы для построения payload.

`SyncMapStore` владеет сопоставлением локальных и удалённых идентификаторов.
Остальной sync-контур использует типизированные операции поиска, записи и очистки
вместо прямых SQL-запросов к `sync_map`.

Push pipeline разделён на `SyncQueueFlusher` и `SyncPushTransport`. Flusher
отвечает только за порядок, acknowledgement и failure policy, а Firestore
transport — за облачные upsert/delete и remote ID. Неуспешный элемент остаётся
в очереди, последующие элементы не отправляются до следующего запуска.

## Offline-first invariant

Локальная операция считается успешной после транзакции SQLite. Отправка в
Firestore выполняется отдельно. Неотправленные изменения сохраняются в
`sync_queue`; сопоставление локальных и облачных идентификаторов находится в
`sync_map`.

Ошибки background-синхронизации сохраняют операцию в очереди и передаются в
`SyncLogger` вместе со stack trace, поэтому сбой не теряется и не запускает
бесконечный retry-loop.

Повторные изменения одной локальной записи объединяются по `(entity, local_pk)`.
Очередь не растёт из-за промежуточных состояний, а в Firestore отправляется
последняя актуальная операция и payload.

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
