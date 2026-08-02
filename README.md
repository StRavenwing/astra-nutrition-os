# Astra Nutrition OS

[![Astra CI/CD](https://github.com/StRavenwing/astra-nutrition-os/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/StRavenwing/astra-nutrition-os/actions/workflows/ci-cd.yml)

Локальный трекер питания и тренировок с Vue-интерфейсом, FastAPI backend, Peewee ORM и SQLite-базой.

Проект помогает хранить продукты и рецепты, автоматически считать КБЖУ и стоимость порций, вести дневник питания, замеры тела и журнал тренировок.

## Возможности

- Dashboard с ключевыми показателями.
- Регистрация и вход по email/паролю.
- Изоляция дневника, прогресса и тренировок по активному пользователю.
- Установка как отдельного приложения (PWA) с фирменной иконкой на ноутбук или экран телефона.
- Каталог продуктов с КБЖУ и ценами.
- Рецепты с категориями, версиями и статусами.
- Интерактивные карточки типов рецептов с мгновенной фильтрацией каталога.
- Плиточный каталог рецептов и фотокарточки категорий.
- Автоматический расчет КБЖУ и стоимости рецепта и одной порции.
- Карточка рецепта с составом и показателями каждого ингредиента.
- Редактирование рецепта и его состава прямо из карточки.
- Смена категории рецепта с автоматическим обновлением ID и связанных записей.
- Алфавитная сортировка продуктов в списке ингредиентов.
- Необязательная фиксированная цена за порцию для готовых продуктов; без неё цена рассчитывается по ингредиентам.
- Единая система ID: `B-`, `M-`, `W-`, `D-`, `G-`, `SA-`, `SN-`, `DR-`.
- Сортировка таблиц по каждому столбцу и сброс сортировки.
- Дневник питания, прогресс и журнал тренировок.
- Добавление нескольких блюд в дневник за одно сохранение и редактирование каждой записи.
- Календарь питания по месяцам и дням с группировкой приёмов пищи и итоговыми КБЖУ.
- Добавление новых продуктов, рецептов, записей дневника, замеров и тренировок.
- Удаление рецептов, записей дневника и замеров прогресса с подтверждением.
- Автоматическая генерация ID продуктов, рецептов и упражнений; внутренние ID записей создаёт SQLite.
- Готовые SQLite, SQL и Excel-версии данных.

## Быстрый запуск на Windows

1. Установите [Python 3](https://www.python.org/downloads/) и [Node.js LTS](https://nodejs.org/), если они ещё не установлены.
2. Создайте `.env` по примеру `.env.example` и задайте `ASTRA_ADMIN_EMAIL`, `ASTRA_ADMIN_PASSWORD`, `ASTRA_AUTH_SECRET`.
3. Дважды щёлкните `start.bat`.
4. Откройте <http://127.0.0.1:8787/>. Обычно страница откроется автоматически.
5. Чтобы остановить приложение, нажмите `Ctrl+C` в окне сервера.

`start.bat` устанавливает Python-зависимости из `requirements.txt`, устанавливает зависимости UI через `npm --prefix ui ci`, собирает Vue-приложение в `ui/dist`, затем запускает FastAPI backend.

При первом запуске новая версия автоматически переносит legacy SQLite-схему в нормализованную схему с внутренними числовыми ID и видимыми кодами `P-001`, `M-001`, `EX-001`. Все существующие записи дневника, прогресса и тренировок назначаются admin-пользователю из `.env`. Перед миграцией существующей базы создаётся backup в `ASTRA_BACKUP_DIR`.

## Авторизация

Обязательные переменные:

```bash
cp .env.example .env
```

После этого задайте реальные значения:

- `ASTRA_ADMIN_EMAIL` — email admin-пользователя.
- `ASTRA_ADMIN_PASSWORD` — пароль admin-пользователя, минимум 8 символов.
- `ASTRA_AUTH_SECRET` — длинный случайный секрет для подписи JWT.
- `ASTRA_ACCESS_TOKEN_MINUTES` — срок действия токена, по умолчанию 10080 минут.

Admin из `.env` может менять общие справочники продуктов, рецептов и упражнений. Обычные пользователи могут читать справочники и вести только свои дневник, прогресс и тренировки.

## Разработка Backend

Первичная установка зависимостей:

```bash
cp .env.example .env
python -m pip install -r requirements-dev.txt
```

Запуск API и собранного UI:

```bash
python server.py
```

Проверки backend:

```bash
python -m compileall server.py backend tests
python -m pytest tests/test_migration.py
python tests/smoke_test.py
```

## Разработка UI

Первичная установка зависимостей:

```bash
npm --prefix ui ci
```

Запуск Vite dev server с proxy на локальный FastAPI backend:

```bash
npm --prefix ui run dev
```

Production-сборка, которую отдаёт `server.py`:

```bash
npm --prefix ui run build
```

## Запуск через Docker Compose

```bash
docker compose -f ci/docker-compose.yml up --build -d
```

Перед запуском задайте `.env` по примеру `.env.example`. После запуска откройте <http://127.0.0.1:8787/>. Данные SQLite и резервные копии хранятся в локальной папке `.data/`.

Чтобы остановить контейнер без удаления данных:

```bash
docker compose -f ci/docker-compose.yml down
```

## Установка на рабочий стол

### Windows или macOS

1. Запустите Astra и откройте её в Chrome или Edge.
2. Нажмите кнопку **«Установить приложение»** в верхней части страницы.
3. Подтвердите установку. Astra появится в меню приложений и сможет создать ярлык на рабочем столе.

### Android

1. Откройте опубликованный HTTPS-адрес Astra в Chrome.
2. Выберите **«Установить приложение»** или **«Добавить на главный экран»**.

### iPhone или iPad

1. Откройте опубликованный HTTPS-адрес Astra в Safari.
2. Нажмите **«Поделиться»** → **«На экран Домой»**.

Локальный адрес `127.0.0.1` доступен только на том компьютере, где запущен сервер. Для установки на телефон приложение нужно отдельно опубликовать по HTTPS; простой GitHub Pages для текущей версии не подходит, потому что ей необходим Python API и SQLite.

## CI/CD через GitHub Actions

Workflow `.github/workflows/ci-cd.yml` автоматически выполняется при pull request, push в `main`, теге вида `v1.0.0` и ручном запуске:

1. Устанавливает Python-зависимости.
2. Проверяет синтаксис Python.
3. Проверяет миграцию legacy SQLite в нормализованную схему.
4. Устанавливает зависимости UI, запускает typecheck и собирает Vue/Vite frontend.
5. Проверяет API, PWA-манифест, service worker, root HTML и иконку через FastAPI smoke test.
6. Проверяет сборку Docker-контейнера.
7. После успешного push в `main` публикует контейнер в GitHub Container Registry с тегами `latest` и `sha-…`.

Личная SQLite-база в контейнер не попадает. При запуске опубликованного образа данные нужно хранить в отдельном Docker volume:

```bash
docker run -d --name astra -p 8787:8787 -v astra-data:/app/.data ghcr.io/stravenwing/astra-nutrition-os:latest
```

Для доступа из интернета контейнер необходимо разместить у хостинг-провайдера и закрыть HTTPS.

## Структура проекта

```text
.
├── server.py                         # совместимый entrypoint, запускает FastAPI/Uvicorn
├── backend/                          # FastAPI routers, Peewee models, services, migrations
├── requirements.txt                  # runtime Python dependencies
├── requirements-dev.txt              # test/development Python dependencies
├── ui/                               # Vue 3 + TypeScript + Vite интерфейс
│   ├── index.html                    # HTML entrypoint Vite
│   ├── package.json                  # зависимости и scripts UI
│   ├── public/
│   │   ├── manifest.webmanifest      # параметры установки PWA
│   │   ├── service-worker.js         # кэш интерфейса приложения
│   │   └── assets/                   # иконки и спрайты категорий
│   └── src/                          # компоненты, views, forms, API-клиент
├── Dockerfile                         # production-контейнер
├── ci/
│   └── docker-compose.yml             # локальный запуск через Docker Compose
├── tests/smoke_test.py                # проверка API и PWA
├── tests/test_migration.py            # проверка миграции SQLite
├── .github/workflows/ci-cd.yml        # CI/CD GitHub Actions
├── Astra_Nutrition_OS_v7.sqlite      # локальная SQLite-база (не публикуется в Git)
├── database/
│   └── Astra_Nutrition_OS_v7.sql     # SQL-дамп структуры и данных
├── docs/
│   └── Astra_Nutrition_OS_v7.xlsx    # Excel-книга
├── start.bat                         # запуск приложения
└── publish-to-github.bat             # первичная публикация репозитория
```

## API

| Метод | Адрес | Назначение |
|---|---|---|
| `GET` | `/api/health` | health check |
| `POST` | `/api/v1/auth/register` | регистрация пользователя |
| `POST` | `/api/v1/auth/login` | вход, возвращает Bearer JWT |
| `POST` | `/api/v1/auth/logout` | stateless logout |
| `GET` | `/api/v1/auth/me` | текущий пользователь |
| `GET` | `/api/v1/dashboard` | KPI для главной страницы |
| `GET/POST` | `/api/v1/products` | продукты с вложенными `measures` |
| `GET` | `/api/v1/product-measures` | плоский справочник мер продуктов |
| `GET/POST` | `/api/v1/recipes` | рецепты |
| `GET` | `/api/v1/recipes/{id}` | карточка рецепта и ингредиенты |
| `GET/POST` | `/api/v1/diary` | дневник питания |
| `GET/POST` | `/api/v1/progress` | замеры и прогресс |
| `GET/POST` | `/api/v1/workouts` | журнал тренировок |
| `GET/POST` | `/api/v1/exercises` | справочник упражнений |

Все `/api/v1/*`, кроме `auth/register` и `auth/login`, требуют заголовок `Authorization: Bearer <token>`. Изменение продуктов, рецептов и упражнений доступно только admin.

## ID рецептов

| Префикс | Категория |
|---|---|
| `B-` | Breakfast — завтраки |
| `M-` | Main — основные блюда |
| `W-` | Wrap — врапы |
| `D-` | Dessert — десерты |
| `G-` | Garnish — гарниры |
| `SA-` | Sauce — соусы |
| `SN-` | Snack — перекусы |
| `DR-` | Drink — напитки |

## Важно

Сервер по умолчанию слушает только `127.0.0.1`. SQLite-файл с персональными данными исключён из Git. Перед публикацией приложения для телефона потребуется защищённый сервер с HTTPS.
