#!/usr/bin/env python3
"""Execute model and analytical SQL files without rewriting their contents."""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

import psycopg2

LOG = logging.getLogger("run_sql")


def sql_files(directory: Path) -> list[Path]:
    if not directory.is_dir():
        return []
    return sorted(
        (path for path in directory.rglob("*.sql") if path.is_file()),
        key=lambda path: path.relative_to(directory).as_posix(),
    )


def connect():
    return psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=int(os.getenv("PGPORT", "5432")),
        dbname=os.getenv("PGDATABASE", os.getenv("POSTGRES_DB", "marketplace")),
        user=os.getenv("PGUSER", os.getenv("POSTGRES_USER", "capibara")),
        password=os.getenv("PGPASSWORD", os.getenv("POSTGRES_PASSWORD")),
        connect_timeout=int(os.getenv("PGCONNECT_TIMEOUT", "5")),
        application_name="capibara-sql-runner",
    )


def run_directories(directories: tuple[Path, ...]) -> None:
    files = [(directory, path) for directory in directories for path in sql_files(directory)]
    if not files:
        LOG.info("No model or query SQL files found; SQL step is a no-op")
        return

    connection = connect()
    current_file = Path("unknown")
    try:
        # One transaction prevents a half-applied model from looking successful.
        with connection:
            with connection.cursor() as cursor:
                cursor.execute("SET LOCAL search_path TO core, raw, mart")
                timeout_ms = int(os.getenv("SQL_STATEMENT_TIMEOUT_MS", "120000"))
                cursor.execute("SET LOCAL statement_timeout = %s", (timeout_ms,))
                for directory, current_file in files:
                    LOG.info("Executing %s", current_file)
                    cursor.execute(current_file.read_text(encoding="utf-8"))
                    LOG.info(
                        "Completed %s",
                        current_file.relative_to(directory).as_posix(),
                    )
        LOG.info("All SQL files committed successfully")
    except Exception as exc:
        raise RuntimeError(
            f"SQL execution failed in {current_file}: {exc}. "
            "The SQL transaction was rolled back."
        ) from exc
    finally:
        connection.close()


def main() -> int:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    model_dir = Path(os.getenv("MODEL_DIR", "model")).resolve()
    query_dir = Path(os.getenv("QUERY_DIR", "queries")).resolve()
    try:
        run_directories((model_dir, query_dir))
    except (OSError, RuntimeError, psycopg2.Error) as exc:
        LOG.error("%s", exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
