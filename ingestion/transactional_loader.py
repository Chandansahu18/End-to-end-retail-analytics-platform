import duckdb
import pandas as pd
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

DB_PATH = r"C:\VS Code Files\major-projects\retail-analytics-platform\warehouse\retail_warehouse.db"
OLIST_PATH = Path(r"C:\VS Code Files\major-projects\retail-analytics-platform\data\raw\olist")

OLIST_FILES = {
    "olist_orders_dataset.csv":         "raw.orders",
    "olist_order_items_dataset.csv":    "raw.order_items",
    "olist_customers_dataset.csv":      "raw.customers",
    "olist_products_dataset.csv":       "raw.products",
    "olist_sellers_dataset.csv":        "raw.sellers",
    "olist_order_payments_dataset.csv": "raw.order_payments",
    "olist_order_reviews_dataset.csv":  "raw.order_reviews",
    "olist_geolocation_dataset.csv":    "raw.geolocation",
}

def load_table(conn, file_path: Path, table_name: str):
    # Idempotency — drop and reload so re-runs never create duplicates
    conn.execute(f"DROP TABLE IF EXISTS {table_name}")

    df = pd.read_csv(file_path, low_memory=False)

    conn.execute(f"CREATE TABLE {table_name} AS SELECT * FROM df")

    row_count = conn.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0]
    logger.info(f"Loaded {table_name}: {row_count:,} rows")

def run():
    conn = duckdb.connect(DB_PATH)

    for filename, table_name in OLIST_FILES.items():
        file_path = OLIST_PATH / filename

        if not file_path.exists():
            logger.warning(f"File not found, skipping: {filename}")
            continue

        load_table(conn, file_path, table_name)

    logger.info("Olist transactional load complete.")
    conn.close()

if __name__ == "__main__":
    run()