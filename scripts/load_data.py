#!/usr/bin/env python3
"""Validate and atomically load every source CSV into the raw schema."""

from __future__ import annotations

import csv
import hashlib
import logging
import os
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path

import psycopg2
from psycopg2 import sql

from scripts.data_contract import DATASETS, DatasetSpec, dataset_path

LOG = logging.getLogger("load_data")
ADVISORY_LOCK_KEY = 0xCAB1BA2A
INIT_DIR = Path(__file__).resolve().parent / "init"


class DataContractError(RuntimeError):
    """A source file does not satisfy the declared input contract."""


@dataclass(frozen=True)
class PreflightResult:
    source_rows: int
    sha256: str


def inspect_csv(path: Path, spec: DatasetSpec) -> PreflightResult:
    """Check existence, UTF-8 encoding, exact header and rectangular rows."""
    if not path.is_file():
        raise DataContractError(f"Required file is missing: {path}")

    digest = hashlib.sha256()
    try:
        with path.open("rb") as raw_file:
            for chunk in iter(lambda: raw_file.read(1024 * 1024), b""):
                digest.update(chunk)

        with path.open(encoding="utf-8-sig", newline="") as source:
            reader = csv.reader(source, strict=True)
            try:
                header = next(reader)
            except StopIteration as exc:
                raise DataContractError(f"CSV is empty: {path}") from exc

            if tuple(header) != spec.columns:
                raise DataContractError(
                    f"Unexpected header in {path.name}.\n"
                    f"Expected: {','.join(spec.columns)}\n"
                    f"Actual:   {','.join(header)}"
                )

            source_rows = 0
            for source_rows, row in enumerate(reader, start=1):
                if len(row) != len(spec.columns):
                    raise DataContractError(
                        f"Malformed row in {path.name} at CSV line {reader.line_num}: "
                        f"expected {len(spec.columns)} columns, got {len(row)}"
                    )
    except (UnicodeDecodeError, csv.Error, OSError) as exc:
        raise DataContractError(f"Cannot read {path}: {exc}") from exc

    return PreflightResult(source_rows=source_rows, sha256=digest.hexdigest())


def preflight(data_dir: Path) -> dict[str, PreflightResult]:
    """Validate all files before opening a transaction that changes raw."""
    results: dict[str, PreflightResult] = {}
    for spec in DATASETS:
        result = inspect_csv(dataset_path(data_dir, spec), spec)
        results[spec.file_name] = result
        LOG.info(
            "Validated %s: %d rows, sha256=%s",
            spec.file_name,
            result.source_rows,
            result.sha256,
        )
    return results


def connect_with_retry():
    attempts = int(os.getenv("DB_CONNECT_RETRIES", "30"))
    delay_seconds = float(os.getenv("DB_CONNECT_RETRY_DELAY", "2"))
    for attempt in range(1, attempts + 1):
        try:
            return psycopg2.connect(
                host=os.getenv("PGHOST", "localhost"),
                port=int(os.getenv("PGPORT", "5432")),
                dbname=os.getenv("PGDATABASE", os.getenv("POSTGRES_DB", "marketplace")),
                user=os.getenv("PGUSER", os.getenv("POSTGRES_USER", "capibara")),
                password=os.getenv("PGPASSWORD", os.getenv("POSTGRES_PASSWORD")),
                connect_timeout=int(os.getenv("PGCONNECT_TIMEOUT", "5")),
                application_name="capibara-raw-loader",
            )
        except psycopg2.OperationalError:
            if attempt == attempts:
                raise
            LOG.warning("Database is unavailable; retry %d/%d", attempt, attempts)
            time.sleep(delay_seconds)
    raise AssertionError("unreachable")


def apply_raw_ddl(cursor) -> None:
    for name in ("01_init.sql", "02_raw_ddl.sql"):
        cursor.execute((INIT_DIR / name).read_text(encoding="utf-8"))


def load_all(data_dir: Path) -> str:
    checks = preflight(data_dir)
    run_id = str(uuid.uuid4())
    connection = connect_with_retry()
    current_file = "database initialization"
    try:
        # A single transaction covers DDL, truncation, all COPY commands and
        # validation. Any exception restores the previous successful raw state.
        with connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT pg_advisory_xact_lock(%s)", (ADVISORY_LOCK_KEY,))
                apply_raw_ddl(cursor)
                table_names = [spec.qualified_table for spec in DATASETS]
                table_names.extend(("raw.load_manifest", "raw.load_state"))
                cursor.execute(
                    sql.SQL("TRUNCATE TABLE {}").format(
                        sql.SQL(", ").join(sql.SQL(name) for name in table_names)
                    )
                )

                for spec in DATASETS:
                    current_file = spec.file_name
                    columns = sql.SQL(", ").join(sql.Identifier(name) for name in spec.columns)
                    copy_statement = sql.SQL(
                        "COPY {} ({}) FROM STDIN WITH "
                        "(FORMAT csv, HEADER true, ENCODING 'UTF8', NULL '')"
                    ).format(sql.Identifier("raw", spec.table_name), columns)
                    with dataset_path(data_dir, spec).open(
                        encoding="utf-8-sig", newline=""
                    ) as source:
                        cursor.copy_expert(copy_statement.as_string(connection), source)

                    cursor.execute(
                        sql.SQL("SELECT count(*) FROM {}").format(
                            sql.Identifier("raw", spec.table_name)
                        )
                    )
                    loaded_rows = cursor.fetchone()[0]
                    expected_rows = checks[spec.file_name].source_rows
                    if loaded_rows != expected_rows:
                        raise DataContractError(
                            f"Row-count mismatch for {spec.file_name}: "
                            f"source={expected_rows}, database={loaded_rows}"
                        )

                    cursor.execute(
                        """
                        INSERT INTO raw.load_manifest (
                            file_name, table_name, run_id, file_sha256,
                            source_rows, loaded_rows
                        ) VALUES (%s, %s, %s, %s, %s, %s)
                        """,
                        (
                            spec.file_name,
                            spec.qualified_table,
                            run_id,
                            checks[spec.file_name].sha256,
                            expected_rows,
                            loaded_rows,
                        ),
                    )
                    LOG.info("Loaded %s into %s", spec.file_name, spec.qualified_table)

                current_file = "load_state"
                cursor.execute(
                    "INSERT INTO raw.load_state (run_id, status) VALUES (%s, 'success')",
                    (run_id,),
                )
        LOG.info("Raw load committed successfully; run_id=%s", run_id)
        return run_id
    except Exception as exc:
        raise RuntimeError(
            f"Import failed at {current_file}: {exc}. "
            "Transaction rolled back; no partial load was committed."
        ) from exc
    finally:
        connection.close()


def main() -> int:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    data_dir = Path(os.getenv("DATA_DIR", "data")).resolve()
    try:
        load_all(data_dir)
    except (DataContractError, RuntimeError, psycopg2.Error) as exc:
        LOG.error("%s", exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
