# Security and configuration

## Secrets

В Git запрещено добавлять:

- `.env` и реальные DaData credentials;
- Firebase Service Account JSON;
- Android keystore и пароли подписи;
- приватные ключи, access/refresh tokens и дампы production-базы.

Firebase client options идентифицируют проект, но не заменяют авторизацию и
server-side правила доступа.

## Firebase

- Firestore Rules требуют `request.auth != null` для чтения и записи.
- Email/password errors преобразуются в безопасные пользовательские сообщения.
- UI работает через `AuthRepository`, не через Firebase SDK напрямую.
- Для production используются отдельные Firebase projects по окружениям.

## Local data

SQLite хранит рабочие offline-данные приложения. Для устройств с повышенными
требованиями следует включить device encryption, запрет резервного копирования
и удаление локальной БД при отзыве доступа.

## Reporting vulnerabilities

Не публикуйте credentials или реальные рабочие данные в issue. Передавайте
уязвимости владельцу репозитория приватным каналом с шагами воспроизведения и
оценкой влияния.
