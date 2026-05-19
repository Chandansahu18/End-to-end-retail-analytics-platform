import duckdb
import os
import pandas as pd
import logging
from pathlib import Path
from dotenv import load_dotenv

# Load .env variables
load_dotenv()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

# Base project directory
BASE_DIR = Path(__file__).resolve().parent.parent

db_path_env = os.getenv("DB_PATH")
events_path_env = os.getenv("EVENTS_PATH")

if db_path_env is None:
    raise ValueError("DB_PATH not found in .env")

if events_path_env is None:
    raise ValueError("EVENTS_PATH not found in .env")

DB_PATH = BASE_DIR / db_path_env
EVENTS_PATH = BASE_DIR / events_path_env

def run():
    if not EVENTS_PATH.exists():
        logger.error(f"events.csv not found at: {EVENTS_PATH}")
        return

    logger.info("Reading events.csv")

    df = pd.read_csv(EVENTS_PATH)

    # Keep only needed columns
    df = df[['visitorid', 'event', 'itemid', 'timestamp']].copy()

    # Convert Unix timestamp (milliseconds) to readable datetime
    df['event_datetime'] = pd.to_datetime(df['timestamp'], unit='ms')
    df.drop(columns=['timestamp'], inplace=True)

    # Standardise event labels
    df['event'] = df['event'].str.lower().str.strip()

    logger.info(f"Rows loaded: {len(df):,}")
    logger.info(f"Event types: {df['event'].value_counts().to_dict()}")

    conn = duckdb.connect(DB_PATH)
    conn.execute("DROP TABLE IF EXISTS raw.events")
    conn.execute("CREATE TABLE raw.events AS SELECT * FROM df")

    result = conn.execute("SELECT COUNT(*) FROM raw.events").fetchone()
    if result is None:
            raise RuntimeError(
                "Failed to count rows from raw.events"
            )
    row_count = result[0]

    logger.info(f"raw.events loaded: {row_count:,} rows")
    conn.close()

if __name__ == "__main__":
    run()