import duckdb
import logging
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

# Base project directory
BASE_DIR = Path(__file__).resolve().parent.parent

# Read environment variables
db_path_env = os.getenv("DB_PATH")

# Validate env variables
if db_path_env is None:
    raise ValueError("DB_PATH not found in .env")

# Create full path
DB_PATH = BASE_DIR / db_path_env

EXPECTED_COUNTS = {
    "raw.orders":         99_441,
    "raw.order_items":   112_650,
    "raw.customers":      99_441,
    "raw.products":       32_951,
    "raw.sellers":         3_095,
    "raw.order_payments": 103_886,
    "raw.order_reviews":  99_224,
    "raw.geolocation":  1_000_163,
    "raw.events":       2756_101,
    "raw.marketing":          100,
}

def verify():
    conn = duckdb.connect(str(DB_PATH))
    all_passed = True

    logger.info("--- Raw Layer Verification ---")

    for table, expected in EXPECTED_COUNTS.items():
        result = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()

        if result is None:
            logger.error(f"Could not fetch row count for {table}")
            all_passed = False
            continue

        actual = result[0]

        status = "PASS" if actual == expected else f"Warning - expected {expected:,}"
        logger.info(f"  {table}: {actual:,} rows [{status}]")

        if actual != expected:
            all_passed = False

    conn.close()

    if all_passed:
        logger.info("All tables verified.")
    else:
        logger.warning("Some tables have unexpected row counts. Re-run the relevant loader.")

if __name__ == "__main__":
    verify()