# FunChat

Реал-тайм чат-сервер на **Phoenix Framework** (Elixir) с использованием WebSockets (Phoenix Channels).

## Возможности

- Регистрация и авторизация пользователей (Argon2)
- Личные сообщения 1:1 со статусами доставки, прочтения, редактирования и удаления
- Реал-тайм статусы онлайн/оффлайн (Phoenix Presence)
- История переписки с курсорной пагинацией
- Ограничение скорости запросов и количества соединений по IP
- Структурированное логирование с защитой PII
- Подготовлен к запуску в Docker

## Быстрый старт

```bash
# 1. Запуск базы данных
docker-compose up -d db

# 2. Установка зависимостей и настройка БД
mix setup

# 3. Запуск сервера
mix phx.server

```

WebSocket endpoint: ws://localhost:4000/socket
**Структура проекта**

├── config/                  # Конфигурация (dev, prod, test, runtime)
├── lib/
│   ├── fun_chat/            # Контексты бизнес-логики (Accounts, Chat)
│   ├── fun_chat_web/        # Web-слой (каналы, обработчики, сокеты)
│   ├── fun_chat.ex
│   └── fun_chat_web.ex
├── priv/
│   ├── repo/                # Миграции Ecto
│   ├── gettext/             # Локализация
│   └── static/              # Статические файлы
├── test/
│   ├── fun_chat/            # Тесты контекстов
│   ├── fun_chat_web/        # Тесты веб-слоя
│   └── support/             # Вспомогательные модули для тестов
├── mix.exs
├── mix.lock
├── Dockerfile
├── docker-compose.yaml
└── AGENTS.md                # Правила разработки

## Технологии

Phoenix 1.8 + Bandit (сервер)
Ecto + PostgreSQL
Phoenix Presence + PubSub
Hammer — rate limiting
Argon2 — хэширование паролей

## Контракт протокола (API)

Все сообщения — JSON-объекты в формате:

### Общая структура
Запрос (от клиента):

```JSON
{
  "id": "unique-request-id",     // опционально, для сопоставления ответа
  "type": "MSG_SEND",
  "payload": { ... }
}
```

Успешный ответ:
```JSON
{
  "id": "unique-request-id",
  "type": "MSG_SEND",
  "payload": { ... }
}
```

Ошибка:
```JSON
  "id": "unique-request-id",
  "type": "ERROR",
  "payload": {
    "error": "описание ошибки"
  }
}
```

Push-сообщения от сервера (без id):
```JSON
{
  "id": null,
  "type": "MSG_SEND",
  "payload": { ... }
}
```

### Основные команды

Авторизация

- USER_LOGIN
Payload: { "user": { "login": "...", "password": "..." } }

- USER_LOGOUT

Сообщения

- MSG_SEND
Payload: { "from": "alice", "to": "bob", "text": "Привет!" }

- MSG_FROM_USER
Payload: { "user": "alice", "limit": 50, "cursor": { "datetime": 1234567890, "id": "uuid" } }

- MSG_READ, MSG_DELETE, MSG_EDIT
Payload: { "id": "message-uuid" } (для edit — + "text": "новый текст")


Пользователи

- USER_ACTIVE — получить список онлайн пользователей
- USER_INACTIVE — получить список оффлайн пользователей
- MSG_COUNT_NOT_READED_FROM_USER — количество непрочитанных от конкретного пользователя

Push-события (от сервера)

- MSG_SEND — новое сообщение
- MSG_DELIVER — сообщение доставлено
- MSG_READ — сообщение прочитано
- MSG_DELETE, MSG_EDIT
- USER_EXTERNAL_LOGIN / USER_EXTERNAL_LOGOUT

Статусы сообщения

```JSON
"status": {
  "isDelivered": true,
  "isReaded": true,
  "isEdited": false,
  "isDeleted": false
}
```

Подробное описание всех полей и edge-кейсов смотрите в модуле FunChatWeb.Protocol.
