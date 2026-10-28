import csv
from pathlib import Path

import pytest

from scripts.data_contract import DATASETS
from scripts.load_data import DataContractError, inspect_csv


def test_contract_contains_exactly_nine_unique_datasets():
    assert len(DATASETS) == 9
    assert len({spec.file_name for spec in DATASETS}) == 9
    assert len({spec.table_name for spec in DATASETS}) == 9
    assert "olist_geolocation_dataset.csv" in {spec.file_name for spec in DATASETS}


def test_every_table_has_a_unique_nonempty_column_list():
    for spec in DATASETS:
        assert spec.columns
        assert len(spec.columns) == len(set(spec.columns))
        assert all(column.isidentifier() for column in spec.columns)


def test_preflight_accepts_utf8_bom_and_counts_rows(tmp_path: Path):
    spec = DATASETS[-1]
    path = tmp_path / spec.file_name
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(spec.columns)
        writer.writerow(("beleza_saude", "health_beauty"))

    result = inspect_csv(path, spec)
    assert result.source_rows == 1
    assert len(result.sha256) == 64


def test_preflight_rejects_missing_file(tmp_path: Path):
    spec = DATASETS[0]
    with pytest.raises(DataContractError, match="Required file is missing"):
        inspect_csv(tmp_path / spec.file_name, spec)


def test_preflight_rejects_changed_header(tmp_path: Path):
    spec = DATASETS[-1]
    path = tmp_path / spec.file_name
    path.write_text("wrong,header\na,b\n", encoding="utf-8")
    with pytest.raises(DataContractError, match="Unexpected header"):
        inspect_csv(path, spec)


def test_preflight_rejects_malformed_row(tmp_path: Path):
    spec = DATASETS[-1]
    path = tmp_path / spec.file_name
    path.write_text(
        "product_category_name,product_category_name_english\nonly_one_column\n",
        encoding="utf-8",
    )
    with pytest.raises(DataContractError, match="Malformed row"):
        inspect_csv(path, spec)
