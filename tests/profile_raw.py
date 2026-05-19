import duckdb
import os
import logging
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent.parent
db_path_env = os.getenv("DB_PATH")

if db_path_env is None:
    raise ValueError("DB_PATH not found in .env")
DB_PATH = BASE_DIR / db_path_env

TABLES = [
    "raw.orders", "raw.order_items", "raw.customers",
    "raw.sellers", "raw.products", "raw.order_payments",
    "raw.order_reviews", "raw.geolocation", "raw.events", "raw.marketing"
]

def profile_table(conn, table: str):
    logger.info(f"\n--- {table} ---")

    row_count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    logger.info(f"  Row count : {row_count:,}")

    columns = conn.execute(f"""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = '{table.split('.')[0]}'
        AND table_name = '{table.split('.')[1]}'
    """).fetchall()

    for (col,) in columns:
        null_count = conn.execute(
            f"SELECT COUNT(*) FROM {table} WHERE \"{col}\" IS NULL"
        ).fetchone()[0]
        distinct_count = conn.execute(
            f"SELECT COUNT(DISTINCT \"{col}\") FROM {table}"
        ).fetchone()[0]
        null_pct = round(null_count / row_count * 100, 1) if row_count > 0 else 0
        logger.info(f"  {col:<45} nulls: {null_count:>7,} ({null_pct}%)  distinct: {distinct_count:,}")

def run():
    conn = duckdb.connect(DB_PATH)
    for table in TABLES:
        profile_table(conn, table)
    conn.close()
    logger.info("\nProfiling complete.")

if __name__ == "__main__":
    run()