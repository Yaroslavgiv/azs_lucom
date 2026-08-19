# Testing strategy

## Test pyramid

### Unit tests

Проверяют детерминированную бизнес-логику без Flutter binding и внешней сети:

- валидацию и безопасное отображение ошибок авторизации;
- приоритеты статусов маркеров;
- преобразование persistence-моделей;
- правила формирования статусов, дат и экспортных моделей.

### Repository tests

Используют временную SQLite-базу и проверяют CRUD, транзакции, фильтры,
идемпотентный seed и постановку операций в очередь синхронизации.

### Widget tests

Проверяют критичные пользовательские состояния через overrides Riverpod:
loading, error, empty, offline и success. Firebase и сеть заменяются fakes.

### Integration tests

Минимальный smoke-сценарий для Android:

1. запуск приложения;
2. авторизация в тестовом Firebase-проекте;
3. открытие списка станций и карточки;
4. создание заявки offline;
5. восстановление сети и синхронизация;
6. экспорт отчёта.

## CI quality gate

Каждый pull request обязан пройти format, analyzer с `--fatal-infos`, unit/widget
tests и Android debug build. Merge запрещается при падении любого шага.

## Coverage policy

Покрытие оценивается по критичной логике, а не одной общей цифре. В первую
очередь покрываются repositories, sync conflict handling, seed migrations,
auth validation и export transformations. Generated Firebase/platform files
исключаются из содержательной оценки.
