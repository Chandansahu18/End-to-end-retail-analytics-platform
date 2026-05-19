import duckdb
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

DB_PATH = r"C:\VS Code Files\major-projects\retail-analytics-platform\warehouse\retail_warehouse.db"

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