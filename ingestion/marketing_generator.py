import duckdb
import os
import pandas as pd
import numpy as np
import logging
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


# Output CSV path — sits alongside the other raw source files
RAW_CSV_PATH = BASE_DIR / "data" / "raw" / "marketing_data.csv"

np.random.seed(42)  # Fixed seed — same data every run, reproducible

def generate_marketing_data():
    channels = ['Google Search', 'Instagram', 'Facebook', 'Email', 'Organic']
    months = pd.date_range(start='2017-01-01', end='2018-08-01', freq='MS')

    # ROAS benchmarks per channel based on industry averages
    roas_base = {
        'Google Search': 3.5,
        'Instagram': 2.2,
        'Facebook': 2.8,
        'Email': 4.1,
        'Organic': 5.0
    }

    records = []
    for month in months:
        for channel in channels:
            spend = round(np.random.uniform(500, 8000), 2)
            impressions = int(np.random.uniform(10000, 200000))
            clicks = int(impressions * np.random.uniform(0.01, 0.05))
            conversions = int(clicks * np.random.uniform(0.02, 0.08))
            revenue = round(spend * roas_base[channel] * np.random.uniform(0.85, 1.15), 2)

            records.append({
                'campaign_month': month.date(),
                'channel': channel,
                'spend': spend,
                'impressions': impressions,
                'clicks': clicks,
                'conversions': conversions,
                'revenue_attributed': revenue,
                'roas': round(revenue / spend, 2),
                'cpa': round(spend / max(conversions, 1), 2),
                'ctr': round(clicks / impressions * 100, 2),
            })

    df = pd.DataFrame(records)
    logger.info(f"Generated {len(df)} rows across {df['channel'].nunique()} channels")
    return df

def save_to_csv(df: pd.DataFrame):
    RAW_CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(RAW_CSV_PATH, index=False)
    logger.info(f"Saved raw CSV → {RAW_CSV_PATH}")

def load_to_duckdb():

    if not RAW_CSV_PATH.exists():
        raise FileNotFoundError(f"marketing_data.csv not found at {RAW_CSV_PATH}. Run generator first.")

    df = pd.read_csv(RAW_CSV_PATH)
    conn = duckdb.connect(DB_PATH)
    conn.register("marketing_df", df)
    conn.execute("DROP TABLE IF EXISTS raw.marketing")
    conn.execute("CREATE TABLE raw.marketing AS SELECT * FROM df")

    result = conn.execute("SELECT COUNT(*) FROM raw.marketing").fetchone()
    if result is None:
            raise RuntimeError(
                "Failed to count rows from raw.marketing"
            )
    row_count = result[0]
    logger.info(f"raw.marketing loaded: {row_count} rows")
    conn.close()

def run():
    df = generate_marketing_data()
    save_to_csv(df)
    load_to_duckdb()

if __name__ == "__main__":
    run()