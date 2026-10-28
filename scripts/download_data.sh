#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${DATA_DIR:-data}"
BASE_URL="https://raw.githubusercontent.com/olist/work-at-olist-data/master/datasets"
mkdir -p "$DATA_DIR"

files=(
  olist_customers_dataset.csv
  olist_geolocation_dataset.csv
  olist_order_items_dataset.csv
  olist_order_payments_dataset.csv
  olist_order_reviews_dataset.csv
  olist_orders_dataset.csv
  olist_products_dataset.csv
  olist_sellers_dataset.csv
  product_category_name_translation.csv
)

for file in "${files[@]}"; do
  if [[ -s "$DATA_DIR/$file" ]]; then
    echo "Exists: $DATA_DIR/$file"
    continue
  fi
  echo "Downloading: $file"
  temporary="$DATA_DIR/.$file.tmp"
  rm -f "$temporary"
  curl --fail --location --retry 4 --retry-delay 2 \
    "$BASE_URL/$file" --output "$temporary"
  mv "$temporary" "$DATA_DIR/$file"
done

echo "All nine source files are present. The loader will validate their contents."
