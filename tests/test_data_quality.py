import pytest
import duckdb
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
db_path_env = os.getenv("DB_PATH")

if db_path_env is None:
    raise ValueError("DB_PATH not found in .env")

DB_PATH = BASE_DIR / db_path_env


@pytest.fixture(scope="session")
def conn():
    """Single DuckDB connection shared across all tests in session."""
    connection = duckdb.connect(str(DB_PATH))
    yield connection
    connection.close()


# ─────────────────────────────────────────────
# RAW LAYER — Row count validation
# ─────────────────────────────────────────────

class TestRawLayer:

    def test_raw_orders_row_count(self, conn):
        """Raw orders must have at least 99,000 rows."""
        count = conn.execute("SELECT COUNT(*) FROM raw.orders").fetchone()[0]
        assert count >= 99000, f"raw.orders has only {count} rows — expected ~99,441"

    def test_raw_events_row_count(self, conn):
        """Raw events must have at least 2.7M rows."""
        count = conn.execute("SELECT COUNT(*) FROM raw.events").fetchone()[0]
        assert count >= 2700000, f"raw.events has only {count} rows — expected ~2,756,101"

    def test_raw_customers_row_count(self, conn):
        """Raw customers must match raw orders count."""
        count = conn.execute("SELECT COUNT(*) FROM raw.customers").fetchone()[0]
        assert count >= 99000, f"raw.customers has only {count} rows"

    def test_raw_marketing_row_count(self, conn):
        """Raw marketing must have exactly 100 rows."""
        count = conn.execute("SELECT COUNT(*) FROM raw.marketing").fetchone()[0]
        assert count == 100, f"raw.marketing has {count} rows — expected exactly 100"


# ─────────────────────────────────────────────
# MART LAYER — Null checks on key columns
# ─────────────────────────────────────────────

class TestFactOrdersNulls:

    def test_order_id_not_null(self, conn):
        """fact_orders must have no null order_id values."""
        nulls = conn.execute(
            "SELECT COUNT(*) FROM marts.fact_orders WHERE order_id IS NULL"
        ).fetchone()[0]
        assert nulls == 0, f"fact_orders has {nulls} null order_id values"

    def test_customer_unique_id_not_null(self, conn):
        """fact_orders must have no null customer_unique_id values."""
        nulls = conn.execute(
            "SELECT COUNT(*) FROM marts.fact_orders WHERE customer_unique_id IS NULL"
        ).fetchone()[0]
        assert nulls == 0, f"fact_orders has {nulls} null customer_unique_id values"

    def test_order_date_not_null(self, conn):
        """fact_orders must have no null order_date values."""
        nulls = conn.execute(
            "SELECT COUNT(*) FROM marts.fact_orders WHERE order_date IS NULL"
        ).fetchone()[0]
        assert nulls == 0, f"fact_orders has {nulls} null order_date values"

    def test_total_order_value_not_null(self, conn):
        """fact_orders must have no null total_order_value."""
        nulls = conn.execute(
            "SELECT COUNT(*) FROM marts.fact_orders WHERE total_order_value IS NULL"
        ).fetchone()[0]
        assert nulls == 0, f"fact_orders has {nulls} null total_order_value rows"


# ─────────────────────────────────────────────
# MART LAYER — Range and business logic checks
# ─────────────────────────────────────────────

class TestFactOrdersRanges:

    def test_no_negative_order_values(self, conn):
        """No order should have negative total value."""
        negatives = conn.execute(
            "SELECT COUNT(*) FROM marts.fact_orders WHERE total_order_value < 0"
        ).fetchone()[0]
        assert negatives == 0, f"fact_orders has {negatives} rows with negative total_order_value"

    def test_fact_orders_minimum_row_count(self, conn):
        """fact_orders must have at least 50,000 rows after filtering."""
        count = conn.execute("SELECT COUNT(*) FROM marts.fact_orders").fetchone()[0]
        assert count >= 50000, f"fact_orders has only {count} rows — pipeline may have filtered too aggressively"

    def test_review_scores_valid_range(self, conn):
        """All review scores must be between 1 and 5."""
        invalid = conn.execute("""
            SELECT COUNT(*) FROM marts.fact_orders
            WHERE review_score IS NOT NULL
            AND (review_score < 1 OR review_score > 5)
        """).fetchone()[0]
        assert invalid == 0, f"fact_orders has {invalid} rows with invalid review_score"

    def test_order_date_range_valid(self, conn):
        """All order dates must be between 2016 and 2019."""
        invalid = conn.execute("""
            SELECT COUNT(*) FROM marts.fact_orders
            WHERE YEAR(order_date) < 2016 OR YEAR(order_date) > 2019
        """).fetchone()[0]
        assert invalid == 0, f"fact_orders has {invalid} rows with out-of-range order_date"

    def test_no_future_order_dates(self, conn):
        """No order date should be in the future."""
        future = conn.execute("""
            SELECT COUNT(*) FROM marts.fact_orders
            WHERE order_date > CURRENT_DATE
        """).fetchone()[0]
        assert future == 0, f"fact_orders has {future} rows with future order_date"


# ─────────────────────────────────────────────
# MART LAYER — dim_customer & fact_rfm checks
# ─────────────────────────────────────────────

class TestDimCustomer:

    def test_customer_key_not_null(self, conn):
        """dim_customer must have no null customer_key."""
        nulls = conn.execute(
            "SELECT COUNT(*) FROM marts.dim_customer WHERE customer_key IS NULL"
        ).fetchone()[0]
        assert nulls == 0, f"dim_customer has {nulls} null customer_key values"

    def test_customer_key_unique(self, conn):
        """customer_key must be unique in dim_customer."""
        total = conn.execute("SELECT COUNT(*) FROM marts.dim_customer").fetchone()[0]
        distinct = conn.execute(
            "SELECT COUNT(DISTINCT customer_key) FROM marts.dim_customer"
        ).fetchone()[0]
        assert total == distinct, f"dim_customer has duplicate customer_key values — {total} rows, {distinct} distinct"

    def test_customer_segment_valid_values(self, conn):
        """All customer segments must be from the defined set."""
        valid_segments = (
    "'low_value', 'mid_value', 'high_value'"
        )
        invalid = conn.execute(f"""
            SELECT COUNT(*) FROM marts.dim_customer
            WHERE customer_segment NOT IN ({valid_segments})
        """).fetchone()[0]
        assert invalid == 0, f"dim_customer has {invalid} rows with invalid customer_segment"
    
    def test_rfm_segment_valid_values(self, conn):
        """RFM segments must be from the defined set."""
        valid_segments = "'Champions', 'Loyal', 'Potential', 'At Risk', 'Lost'"

        invalid = conn.execute(f"""
            SELECT COUNT(*)
            FROM marts.fact_rfm
            WHERE segment NOT IN ({valid_segments})
        """).fetchone()[0]

        assert invalid == 0, f"fact_rfm has {invalid} rows with invalid segment"

# ─────────────────────────────────────────────
# MART LAYER — fact_events checks
# ─────────────────────────────────────────────

class TestFactEvents:

    def test_event_date_not_null(self, conn):
        """fact_events must have no null event_date."""
        nulls = conn.execute(
            "SELECT COUNT(*) FROM marts.fact_events WHERE event_date IS NULL"
        ).fetchone()[0]
        assert nulls == 0, f"fact_events has {nulls} null event_date values"

    def test_conversion_rate_not_negative(self, conn):
        """Overall conversion rate must never be negative."""
        negatives = conn.execute("""
            SELECT COUNT(*) FROM marts.fact_events
            WHERE overall_conversion_rate < 0
        """).fetchone()[0]
        assert negatives == 0, f"fact_events has {negatives} rows with negative conversion rate"

    def test_transactions_not_exceed_views(self, conn):
        """Total transactions must never exceed total views on any day."""
        invalid = conn.execute("""
            SELECT COUNT(*) FROM marts.fact_events
            WHERE total_transactions > total_views
        """).fetchone()[0]
        assert invalid == 0, f"fact_events has {invalid} days where transactions exceed views"


# ─────────────────────────────────────────────
# MART LAYER — fact_marketing checks
# ─────────────────────────────────────────────

class TestFactMarketing:

    def test_marketing_row_count(self, conn):
        """fact_marketing must have exactly 100 rows."""
        count = conn.execute("SELECT COUNT(*) FROM marts.fact_marketing").fetchone()[0]
        assert count == 100, f"fact_marketing has {count} rows — expected 100"

    def test_roas_positive(self, conn):
        """All ROAS values must be positive."""
        non_positive = conn.execute("""
            SELECT COUNT(*) FROM marts.fact_marketing WHERE roas <= 0
        """).fetchone()[0]
        assert non_positive == 0, f"fact_marketing has {non_positive} rows with non-positive ROAS"

    def test_spend_positive(self, conn):
        """All spend values must be positive."""
        non_positive = conn.execute("""
            SELECT COUNT(*) FROM marts.fact_marketing WHERE spend <= 0
        """).fetchone()[0]
        assert non_positive == 0, f"fact_marketing has {non_positive} rows with non-positive spend"

    def test_valid_channels(self, conn):
        """All channels must be from the defined set."""
        invalid = conn.execute("""
            SELECT COUNT(*) FROM marts.fact_marketing
            WHERE channel NOT IN (
                'Google Search', 'Instagram', 'Facebook', 'Email', 'Organic'
            )
        """).fetchone()[0]
        assert invalid == 0, f"fact_marketing has {invalid} rows with invalid channel"