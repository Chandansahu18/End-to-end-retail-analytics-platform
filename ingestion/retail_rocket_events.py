import duckdb
import pandas as pd
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

DB_PATH = r"C:\VS Code Files\major-projects\retail-analytics-platform\warehouse\retail_warehouse.db"
EVENTS_PATH = Path(r"C:\VS Code Files\major-projects\retail-analytics-platform\data\raw\retail_rocket\events.csv")

def run():
    if not EVENTS_PATH.exists():
        logger.error(f"events.csv not found at: {EVENTS_PATH}")
        return

    logger.info("Reading events.csv")

    df = pd.read_csv(EVENTS_PATH)

    # Keep only needed columns — reduces RAM footprint
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