# Capibara Analytics

Воспроизводимый контур PostgreSQL + Python для загрузки девяти CSV Olist, сборки SQL-модели и проверки результата. Исходные данные остаются в `raw`; бизнес-модель размещается в `core`, витрины — в `mart`.

## Структура

```text
.
├── .github/workflows/ci.yml     сборка, двойной запуск и тесты
├── data/                        CSV локально; содержимое не коммитится
├── docs/
│   ├── architecture.md          решения и оставшиеся риски
│   ├── data-contract.md         контракты CSV/raw/SQL/тестов
│   ├── handout.md               исходное задание
│   └── tasks.md                 вопросы аналитиков
├── model/                       SQL владельца модели, без изменений runner'ом
├── queries/                     аналитические SQL-запросы
├── scripts/
│   ├── init/                    схемы и DDL raw
│   ├── data_contract.py         девять контрактов CSV → таблица
│   ├── download_data.sh         идемпотентное скачивание отсутствующих CSV
│   ├── load_data.py             валидация и атомарная загрузка
│   └── run_sql.py               model, затем queries
├── tests/                       unit и PostgreSQL integration
├── docker-compose.yml
└── Dockerfile
```

## Требования

- Docker Engine/Desktop с Compose v2;
- место для примерно 1,55 млн строк и PostgreSQL volume;
- для unit-тестов без контейнеров — Python 3.12.

## Быстрый запуск

1. Создайте локальную конфигурацию и **замените placeholder пароля**:

   ```bash
   cp .env.example .env
   ```

   `.env` исключён из Git. Не используйте этот локальный пароль как общий или production-секрет.

2. Скачайте девять CSV либо скопируйте уже имеющиеся файлы в `data/`:

   ```bash
   bash scripts/download_data.sh
   ```

3. На чистом окружении запустите PostgreSQL и pipeline:

   ```bash
   docker compose down --volumes
   docker compose up -d --wait db
   docker compose run --rm loader
   ```

   `loader` сначала атомарно загружает raw, затем выполняет все SQL из `model/` и `queries/`. Повторная команда проверяет идемпотентность полного пути.

4. Запустите интеграционные тесты:

   ```bash
   docker compose run --rm --no-deps tests
   ```

Альтернатива одной командой после подготовки `.env` и CSV:

```bash
docker compose --profile test up --build --exit-code-from tests
```

## Подключение и проверка

По умолчанию БД доступна только на `127.0.0.1:5432`; имя, пользователь и пароль берутся из `.env`.

```bash
docker compose exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

Полезные проверки:

```sql
SELECT * FROM raw.load_state;
SELECT file_name, source_rows, loaded_rows, file_sha256
FROM raw.load_manifest ORDER BY file_name;
SELECT count(*) FROM raw.geolocation;
```

## Поведение при ошибках и повторном запуске

До изменения БД проверяются все файлы. Затем одна транзакция выполняет DDL, очищает старую raw-версию, копирует девять CSV и сверяет число строк. Любая ошибка откатывает всю операцию и возвращает ненулевой код; сообщение содержит файл/этап. Состояние `success` появляется только после полной загрузки.

Повторный запуск — полная замена, а не добавление дублей. Для удаления БД вместе с volume:

```bash
docker compose down --volumes
```

Это необратимо удаляет локальные данные PostgreSQL.

## Интеграция SQL других агентов

Добавляйте файлы в `model/` и `queries/`, используя числовые префиксы для порядка. Не меняйте `raw`; модель строится из него в `core`, витрины — в `mart`. SQL должен быть повторяемым. Runner не переписывает чужие запросы и откатывает весь SQL-шаг при ошибке. Подробный контракт: [docs/data-contract.md](docs/data-contract.md).

## Локальные unit-проверки

```bash
python -m pip install -r requirements-dev.txt
python -m pytest -q -m 'not integration'
```

CI дополнительно собирает образы, валидирует Compose, скачивает отсутствующие CSV, дважды запускает pipeline и выполняет интеграционные тесты.

## Статус проверки

В среде сборки выполнены: 6 unit-тестов, 4 интеграционных теста на PostgreSQL 15, чистая загрузка всех 1 550 922 строк, повторный запуск со сменой `run_id` и без дублей, проверка сохранения предыдущего состояния при отсутствующем CSV, принудительный сбой второго `COPY` с полным rollback, а также повторный SQL-runner и rollback его ошибки. YAML Compose и GitHub Actions провалидированы.

Сам Docker Compose в этой среде не запускался, потому что Docker daemon/CLI отсутствует; окончательная контейнерная проверка закреплена за GitHub Actions. Бизнес-SQL других агентов пока не передан, поэтому аналитические контрольные цифры не проверялись.

Это production-oriented минимальный каркас, а не заявление о production-ready эксплуатации. Архитектурные решения, границы и риски описаны в [docs/architecture.md](docs/architecture.md). Перед сдачей необходим зелёный CI с командными SQL и их бизнес-тестами.
