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

def setup_warehouse():
    conn = duckdb.connect(DB_PATH)

    conn.execute("CREATE SCHEMA IF NOT EXISTS raw")
    conn.execute("CREATE SCHEMA IF NOT EXISTS staging")
    conn.execute("CREATE SCHEMA IF NOT EXISTS marts")

    logger.info("Schemas created: raw, staging, marts")

    schemas = conn.execute(
        "SELECT schema_name FROM information_schema.schemata"
    ).fetchall()
    logger.info(f"Warehouse schemas: {[s[0] for s in schemas]}")

    conn.close()
    logger.info(f"Warehouse ready at: {DB_PATH}")

if __name__ == "__main__":
    setup_warehouse()