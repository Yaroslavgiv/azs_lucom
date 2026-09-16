# Домен первой версии

Общий контракт мобильного клиента и Flutter Web. Источник правды после
синхронизации — Cloud Firestore.

## Роли

| Роль | Firestore `users.role` | Доступ |
|------|------------------------|--------|
| Специалист | `specialist` | Назначенные работы, свои черновики offline, отчёт ТО |
| Руководитель | `manager` | Сеть/регионы из профиля, назначения, приёмка, отчёты |
| Администратор | `admin` | Пользователи, справочники, история, все регионы |

Документ профиля: `users/{uid}` — `email`, `display_name`, `role`, `regions`, `disabled`.

## Заявки (`requests`)

`new → assigned → in_progress → done | overdue`

Совместимость: `open` = активная, `closed` = выполненная.

Поля назначения: `assignee_id`, `assignee_name`, `due_date`, `updated_by`,
`updated_at`, `version`.

## ТО (`maintenance`)

Ключ: `{stationNumber}_{month}` (месяц `YYYY-MM`).

`planned → in_review → accepted | returned`

Совместимость: `pending` = запланировано, `done` = принято.

Отчёт: чек-лист в `report_json`, фото в Storage / `photo_paths`, комментарий,
`submitted_at`. Приёмка пишет `reviewed_by`, `review_comment`.

Приёмка и возврат — Cloud Functions `acceptMaintenance` / `returnMaintenance`.
Клиент руководителя не ставит `accepted` напрямую, если доступны Functions.

## Аудит

Коллекция `audit_log`: кто, когда, сущность, действие, краткое описание.

## Карта

- зелёный — ТО принято (`accepted` / legacy `done`);
- жёлтый — запланировано / на проверке;
- красный — просроченный срок или критическая (срочная) открытая заявка.
