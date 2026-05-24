import duckdb
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Base project directory
BASE_DIR = Path(__file__).resolve().parent.parent

db_path_env = os.getenv("DB_PATH")

if db_path_env is None:
    raise ValueError("DB_PATH not found in .env")

DB_PATH = BASE_DIR / db_path_env

# Export directory
EXPORT_DIR = BASE_DIR / "data" / "processed" / "marts"
EXPORT_DIR.mkdir(parents=True, exist_ok=True)

tables = [
    "marts.fact_orders",
    "marts.fact_events",
    "marts.fact_marketing",
    "marts.fact_rfm",
    "marts.dim_customer",
    "marts.dim_product",
    "marts.dim_date",
    "marts.fact_order_item"
]

conn = duckdb.connect(str(DB_PATH), read_only=True)

for table in tables:

    table_name = table.split(".")[1]

    out_path = EXPORT_DIR / f"{table_name}.parquet"

    conn.execute(
        f"COPY {table} TO '{str(out_path)}' (FORMAT PARQUET)"
    )

    result = conn.execute(
        f"SELECT COUNT(*) FROM {table}"
    ).fetchone()

    if result is not None:
        row_count = result[0]
        print(f"Exported {table_name}.parquet — {row_count:,} rows")
    else:
        print(f"Could not count rows for {table_name}")

conn.close()

print("\nAll exports done.")