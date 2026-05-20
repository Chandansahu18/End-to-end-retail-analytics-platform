## 1. Introduction

The staging layer is the first transformation layer in the warehouse. Every staging model maps one-to-one with a raw source table. No joins happen here. No business logic happens here.

What staging does, and only this:

- Cast VARCHAR timestamps to proper TIMESTAMP types
- Cast INT zip codes to VARCHAR and restore leading zeros
- Normalise text casing (city names, state codes)
- Rename columns with source typos (e.g. `product_name_lenght` → `product_name_length`)
- Add simple derived columns calculable from a single table (e.g. `delivery_delay_days`)
- Filter out rows that should never reach analytics (canceled orders, unknown payment types)
- Translate Portuguese category names to English via a lookup join (exception to no-join rule - it is a pure lookup, no business logic)

Staging models are materialized as **views** in DuckDB under the `staging` schema.
All downstream models (intermediate, marts) read from staging using `{{ ref() }}` - never from raw directly.

> Staging is the contract between your source systems and your analytics layer.
> If a source column changes, you fix it once in staging. Nothing downstream breaks.

---

## 2. Transformation Legend

Column entries in this dictionary use the following tags to explain what changed from raw:

| Tag | Meaning |
|---|---|
| `CAST` | Data type changed from raw (e.g. VARCHAR → TIMESTAMP) |
| `NORMALISED` | Text standardisation applied (lower, upper, trim) |
| `FIXED` | Source defect corrected (typo, leading zero, encoding) |
| `DERIVED` | New column calculated from existing columns in same table |
| `FILTERED` | Rows removed that should not reach analytics |
| `EXCLUDED` | Raw column intentionally dropped - reason documented |
| `RENAMED` | Column name changed for clarity or consistency |
| `UNCHANGED` | Passed through from raw with no modification |

---

## 3. Model Dictionary

### 3.1 Olist Staging Models

---

#### stg_orders

**dbt model:** `models/staging/stg_orders.sql`
**Source:** `{{ source('raw', 'orders') }}` → `raw.orders`
**Output rows:** ~96,000 *(from 99,441 raw - filtered)*
**Materialization:** view

**Row filter applied:**
```sql
WHERE order_status NOT IN ('canceled', 'unavailable')
```
Canceled and unavailable orders are excluded here permanently. No downstream model should ever see them. If you need to analyse cancellation rates specifically, query `raw.orders` directly with an explicit filter.

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `order_id` | VARCHAR | 0 | UNCHANGED | Primary key |
| `customer_id` | VARCHAR | 0 | UNCHANGED | FK → `stg_customers.customer_id` |
| `order_status` | VARCHAR | 0 | FILTERED | Only active statuses remain: `delivered`, `shipped`, `invoiced`, `processing`, `created`, `approved` |
| `order_purchase_timestamp` | TIMESTAMP | 0 | CAST | VARCHAR → TIMESTAMP |
| `order_approved_at` | TIMESTAMP | ~160 | CAST | VARCHAR → TIMESTAMP. Nulls expected — unprocessed orders |
| `order_delivered_carrier_date` | TIMESTAMP | ~1,783 | CAST | VARCHAR → TIMESTAMP. Nulls = not yet shipped |
| `order_delivered_customer_date` | TIMESTAMP | ~2,965 | CAST | VARCHAR → TIMESTAMP. Nulls = not yet delivered |
| `order_estimated_delivery_date` | TIMESTAMP | 0 | CAST | VARCHAR → TIMESTAMP |
| `delivery_delay_days` | INT | ~2,965 | DERIVED | `actual_delivery_date - estimated_delivery_date`. Positive = late. Negative = early. Null when `order_delivered_customer_date` is null |
| `is_late_delivery` | BOOLEAN | ~2,965 | DERIVED | `true` when `order_delivered_customer_date > order_estimated_delivery_date`. Null when delivery date is null |

**Columns excluded from raw:**
- None - all 8 raw columns are retained, 2 derived columns added

**dbt tests:**
- `order_id`: `not_null`, `unique`
- `customer_id`: `not_null`
- `order_status`: `not_null`, `accepted_values` → `[delivered, shipped, invoiced, processing, created, approved]`

---

#### stg_order_items

**dbt model:** `models/staging/stg_order_items.sql`
**Source:** `{{ source('raw', 'order_items') }}` → `raw.order_items`
**Output rows:** 112,650 *(unchanged - no filter)*
**Materialization:** view

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `order_id` | VARCHAR | 0 | UNCHANGED | FK → `stg_orders.order_id` |
| `order_item_id` | INT | 0 | UNCHANGED | Line item sequence within order |
| `product_id` | VARCHAR | 0 | UNCHANGED | FK → `stg_products.product_id` |
| `seller_id` | VARCHAR | 0 | UNCHANGED | FK → `stg_sellers.seller_id` |
| `shipping_limit_date` | TIMESTAMP | 0 | CAST | VARCHAR → TIMESTAMP |
| `price` | FLOAT | 0 | UNCHANGED | Unit price in BRL |
| `freight_value` | FLOAT | 0 | UNCHANGED | Freight cost in BRL |
| `item_total_value` | FLOAT | 0 | DERIVED | `price + freight_value` - total cost of this line item |

**dbt tests:**
- `order_id`: `not_null`
- `product_id`: `not_null`
- `seller_id`: `not_null`
- `price`: `not_null`

---

#### stg_customers

**dbt model:** `models/staging/stg_customers.sql`
**Source:** `{{ source('raw', 'customers') }}` → `raw.customers`
**Output rows:** 99,441 *(unchanged - no filter)*
**Materialization:** view

> **Critical note:** `customer_id` is a per-order identifier, not a person identifier.
> One customer who placed 3 orders has 3 different `customer_id` values.
> Always use `customer_unique_id` for customer-level analysis, repeat purchase rates,
> and as the primary key in `dim_customer`.

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `customer_id` | VARCHAR | 0 | UNCHANGED | Per-order customer identifier. PK in this table only. Not a stable person identity. |
| `customer_unique_id` | VARCHAR | 0 | UNCHANGED | True unique person identifier. 96,096 distinct values across 99,441 rows. Use this for all customer analysis. |
| `customer_zip_code_prefix` | VARCHAR | 0 | FIXED | Raw stores as INT - leading zeros lost. Fixed: cast to VARCHAR and `lpad(..., 5, '0')` applied. |
| `customer_city` | VARCHAR | 0 | NORMALISED | `lower(trim(...))` applied. Reduces encoding variant duplicates. |
| `customer_state` | VARCHAR | 0 | NORMALISED | `upper(trim(...))` applied. 27 distinct states. |

**dbt tests:**
- `customer_id`: `not_null`, `unique`
- `customer_unique_id`: `not_null`
- `customer_state`: `not_null`

---

#### stg_sellers

**dbt model:** `models/staging/stg_sellers.sql`
**Source:** `{{ source('raw', 'sellers') }}` → `raw.sellers`
**Output rows:** 3,095 *(unchanged - no filter)*
**Materialization:** view

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `seller_id` | VARCHAR | 0 | UNCHANGED | Primary key |
| `seller_zip_code_prefix` | VARCHAR | 0 | FIXED | Same leading-zero fix as customers - cast to VARCHAR + `lpad` |
| `seller_city` | VARCHAR | 0 | NORMALISED | `lower(trim(...))` applied |
| `seller_state` | VARCHAR | 0 | NORMALISED | `upper(trim(...))` applied. 23 distinct seller states |

---

#### stg_products

**dbt model:** `models/staging/stg_products.sql`
**Source:** `{{ source('raw', 'products') }}` + `{{ source('raw', 'product_category_translation') }}`
**Output rows:** 32,951 *(unchanged - no filter)*
**Materialization:** view

> **Join note:** This is the one staging model that joins two sources. The translation join is a pure reference lookup - Portuguese category name → English equivalent. No business logic is applied. This is an acceptable exception to the no-join rule in staging.

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `product_id` | VARCHAR | 0 | UNCHANGED | Primary key |
| `product_category_name_pt` | VARCHAR | ~610 | NORMALISED | Portuguese category name. `coalesce(..., 'uncategorized')` applied — nulls replaced with `'uncategorized'` |
| `product_category_name_en` | VARCHAR | ~610 | DERIVED | English translation from `raw.product_category_translation` via left join. Nulls (uncategorised products) filled with `'uncategorized'` |
| `product_name_length` | INT | ~610 | FIXED | Renamed from `product_name_lenght` - source typo corrected |
| `product_description_length` | INT | ~610 | FIXED | Renamed from `product_description_lenght` - source typo corrected |
| `product_photos_qty` | INT | ~610 | UNCHANGED | Number of listing photos |
| `product_weight_g` | INT | 2 | UNCHANGED | Weight in grams |
| `product_length_cm` | INT | 2 | UNCHANGED | Length in cm |
| `product_height_cm` | INT | 2 | UNCHANGED | Height in cm |
| `product_width_cm` | INT | 2 | UNCHANGED | Width in cm |

---

#### stg_order_payments

**dbt model:** `models/staging/stg_order_payments.sql`
**Source:** `{{ source('raw', 'order_payments') }}` → `raw.order_payments`
**Output rows:** ~103,800 *(slightly under 103,886 - `not_defined` rows filtered)*
**Materialization:** view

**Row filter applied:**
```sql
WHERE payment_type != 'not_defined'
```

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `order_id` | VARCHAR | 0 | UNCHANGED | FK → `stg_orders.order_id` |
| `payment_sequential` | INT | 0 | UNCHANGED | Sequence number for split payments |
| `payment_type` | VARCHAR | 0 | FILTERED | `not_defined` rows removed. Remaining values: `credit_card`, `boleto`, `voucher`, `debit_card` |
| `payment_installments` | INT | 0 | UNCHANGED | Number of installments. 0 = boleto/voucher |
| `payment_value` | FLOAT | 0 | UNCHANGED | Payment amount in BRL for this row |

> **Aggregation reminder:** This table still has multiple rows per `order_id` for split payments.
> Do not join directly to `stg_orders` without aggregating first.
> The intermediate model `int_order_payments_agg` handles this aggregation.

**dbt tests:**
- `order_id`: `not_null`
- `payment_type`: `not_null`, `accepted_values` → `[credit_card, boleto, voucher, debit_card]`

---

#### stg_order_reviews

**dbt model:** `models/staging/stg_order_reviews.sql`
**Source:** `{{ source('raw', 'order_reviews') }}` → `raw.order_reviews`
**Output rows:** 99,224 *(unchanged - no filter)*
**Materialization:** view

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `review_id` | VARCHAR | 0 | UNCHANGED | Primary key |
| `order_id` | VARCHAR | 0 | UNCHANGED | FK → `stg_orders.order_id` |
| `review_score` | INT | 0 | UNCHANGED | Star rating 1-5. No nulls. |
| `review_comment_message` | VARCHAR | ~58,247 | UNCHANGED | Full review text in Portuguese. 59% null. |
| `review_answer_timestamp` | TIMESTAMP | 0 | CAST | VARCHAR → TIMESTAMP |

**Columns excluded from raw:**
- `review_comment_title` - EXCLUDED. 88% null rate. Not used in any analysis. Removing it reduces noise.
- `review_creation_date` - EXCLUDED. Internal Olist operations timestamp. No analytical value.

---

#### stg_geolocation

**dbt model:** `models/staging/stg_geolocation.sql`
**Source:** `{{ source('raw', 'geolocation') }}` → `raw.geolocation`
**Output rows:** ~19,015 *(aggregated from 1,000,163 raw rows)*
**Materialization:** view

> **Key transformation:** Raw geolocation has ~52 coordinate entries per zip prefix.
> This model aggregates to one row per zip using `AVG(lat)` and `AVG(lng)`.
> Without this, joining to customers or sellers produces a 52x row explosion.

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `zip_code_prefix` | VARCHAR | 0 | FIXED + RENAMED | Aggregated from `geolocation_zip_code_prefix`. Cast to VARCHAR, `lpad` applied. Renamed to remove `geolocation_` prefix for cleaner joins. |
| `latitude` | FLOAT | 0 | DERIVED | `AVG(geolocation_lat)` per zip. Rounded to 6 decimal places. |
| `longitude` | FLOAT | 0 | DERIVED | `AVG(geolocation_lng)` per zip. Rounded to 6 decimal places. |

**Columns excluded from raw:**
- `geolocation_city` - EXCLUDED. Redundant - customer/seller city comes from their own tables.
- `geolocation_state` - EXCLUDED. Same reason.

---

### 3.2 RetailRocket Staging Models

---

#### stg_events

**dbt model:** `models/staging/stg_events.sql`
**Source:** `{{ source('raw', 'events') }}` → `raw.events`
**Output rows:** 2,756,101 *(unchanged - no filter)*
**Materialization:** view

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `visitor_id` | INT | 0 | RENAMED | `visitorid` → `visitor_id`. Snake_case convention. |
| `event_type` | VARCHAR | 0 | RENAMED | `event` → `event_type`. More descriptive. Values: `view`, `addtocart`, `transaction` |
| `item_id` | INT | 0 | RENAMED | `itemid` → `item_id`. Snake_case convention. |
| `event_datetime` | TIMESTAMP | 0 | CAST + RENAMED | `epoch_ms(timestamp)` — Unix milliseconds → TIMESTAMP. Column renamed from `timestamp`. |
| `event_date` | DATE | 0 | DERIVED | `cast(event_datetime as date)` - date portion only, for daily aggregations |
| `transaction_id` | FLOAT | ~2,733,644 | RENAMED | `transactionid` → `transaction_id`. Nulls on non-transaction rows are correct and expected. |

**dbt tests:**
- `visitor_id`: `not_null`
- `event_type`: `not_null`, `accepted_values` → `[view, addtocart, transaction]`
- `item_id`: `not_null`

---

### 3.3 Synthetic Source Staging Models

---

#### stg_marketing

**dbt model:** `models/staging/stg_marketing.sql`
**Source:** `{{ source('raw', 'marketing') }}` → `raw.marketing`
**Output rows:** 100 *(unchanged - no filter)*
**Materialization:** view

> Source note: `raw.marketing` is loaded from `data/raw/marketing_data.csv` which is
> synthetically generated to simulate D2C channel patterns. In production this would
> be replaced by a Google Ads API export or marketing attribution platform data.

| Column | Type | Nulls | Tag | Description |
|---|---|---|---|---|
| `campaign_month` | DATE | 0 | CAST | VARCHAR → DATE |
| `channel` | VARCHAR | 0 | UNCHANGED | Marketing channel. Values: `Google Search`, `Instagram`, `Facebook`, `Email`, `Organic` |
| `spend` | FLOAT | 0 | UNCHANGED | Ad spend in USD |
| `impressions` | INT | 0 | UNCHANGED | Total impressions |
| `clicks` | INT | 0 | UNCHANGED | Total clicks |
| `conversions` | INT | 0 | UNCHANGED | Attributed purchases |
| `revenue_attributed` | FLOAT | 0 | UNCHANGED | Revenue credited to channel |
| `roas` | FLOAT | 0 | UNCHANGED | Return on ad spend |
| `cpa` | FLOAT | 0 | UNCHANGED | Cost per acquisition |
| `ctr` | FLOAT | 0 | UNCHANGED | Click-through rate as percentage |

**dbt tests:**
- `campaign_month`: `not_null`
- `channel`: `not_null`, `accepted_values` → `[Google Search, Instagram, Facebook, Email, Organic]`
- `spend`: `not_null`
- `roas`: `not_null`

---

## 4. Staging Layer Relationship Map

```
stg_customers ──► stg_orders ──► stg_order_items ──► stg_products
                      │
                      ├──► stg_order_payments  (aggregate before joining - see int_order_payments_agg)
                      │
                      └──► stg_order_reviews

stg_order_items ──► stg_sellers

stg_customers.customer_zip_code_prefix ──► stg_geolocation
stg_sellers.seller_zip_code_prefix     ──► stg_geolocation

── Standalone ──────────────────────────────────────────────────
stg_events      (no join to Olist models)
stg_marketing   (no join to Olist models)
```

---

## 5. What Changed from Raw - Summary

| Raw Table | Key Changes in Staging |
|---|---|
| `raw.orders` | Timestamps cast · canceled/unavailable filtered · `delivery_delay_days` and `is_late_delivery` derived |
| `raw.order_items` | Timestamps cast · `item_total_value` derived |
| `raw.customers` | Zip cast to VARCHAR + leading zero fix · city lowercased · state uppercased |
| `raw.sellers` | Same zip and city/state normalisation as customers |
| `raw.products` | Portuguese → English category join · typos fixed · nulls filled with `'uncategorized'` |
| `raw.order_payments` | `not_defined` payment type filtered |
| `raw.order_reviews` | Timestamp cast · `review_comment_title` and `review_creation_date` excluded |
| `raw.geolocation` | 1,000,163 rows → ~19,015 rows via `AVG(lat/lng) GROUP BY zip` · city and state excluded |
| `raw.product_category_translation` | Not staged separately - used only as a lookup in `stg_products` |
| `raw.events` | Unix ms → TIMESTAMP cast · columns renamed to snake_case · `event_date` derived |
| `raw.marketing` | `campaign_month` cast to DATE |

---

## 6. dbt Test Coverage

| Model | not_null tests | unique tests | accepted_values tests |
|---|---|---|---|
| `stg_orders` | order_id, customer_id, order_status | order_id | order_status |
| `stg_order_items` | order_id, product_id, seller_id, price | - | - |
| `stg_customers` | customer_id, customer_unique_id, customer_state | customer_id | - |
| `stg_sellers` | seller_id | seller_id | - |
| `stg_events` | visitor_id, event_type, item_id | - | event_type |
| `stg_marketing` | campaign_month, channel, spend, roas | - | channel |

---

*Staging layer built with dbt Core + DuckDB adapter*
*All models verified via `dbt build` — zero test failures*
*Lineage graph available via `dbt docs serve`*