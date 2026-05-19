## 1. Introduction

The raw schema stores an exact copy of all source data as ingested. No columns are renamed, no values are modified, no rows are filtered. If the source has a typo in a column name, the raw layer preserves that typo. The purpose of this layer is to be a permanent, reloadable source of truth.

All cleaning, type casting, and business logic happens in the staging layer. All analytics models are built in the marts layer.

> Future warehouse modeling in the marts layer will transform these raw tables into an analytics model with proper dimensional structure.

---

## 2. Source System Overview

| Source | Type | Tables | Description |
|---|---|---|---|
| Olist Brazilian E-Commerce | External vendor dataset | 9 tables | Orders, customers, products, sellers, payments, reviews, geolocation, category translations |
| RetailRocket | External vendor dataset | 1 table | Behavioural clickstream events (views, add-to-cart, transactions) |
| Synthetic generator | Internally generated | 1 table | Marketing campaign data - simulated to represent D2C channel patterns |

---

## 3. Table Dictionary

### 3.1 Olist Source Tables

---

#### raw.orders

**Source file:** `olist_orders_dataset.csv`
**Row count:** 99,441
**Description:** One row per order. The central transactional table of the Olist dataset. All other Olist tables link back to this one via `order_id`.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `order_id` | VARCHAR | 0 | Primary key. Unique 32-character hex order identifier. |
| `customer_id` | VARCHAR | 0 | Foreign key → `raw.customers`. Note: this is a per-order ID, not a true unique customer ID. One customer can have multiple `customer_id` values across separate orders. |
| `order_status` | VARCHAR | 0 | Current order status. Values: `delivered`, `shipped`, `canceled`, `invoiced`, `processing`, `unavailable`, `created`, `approved`. |
| `order_purchase_timestamp` | VARCHAR (TIMESTAMP) | 0 | When the customer placed the order. Primary time dimension for trend analysis. |
| `order_approved_at` | VARCHAR (TIMESTAMP) | 160 | When payment was approved. Nulls represent canceled or unprocessed orders. |
| `order_delivered_carrier_date` | VARCHAR (TIMESTAMP) | 1,783 | When the seller handed the order to the logistics carrier. Nulls represent unshipped or canceled orders. |
| `order_delivered_customer_date` | VARCHAR (TIMESTAMP) | 2,965 | Actual date of delivery to the customer. Nulls represent undelivered orders. Used alongside `order_estimated_delivery_date` to measure delivery performance. |
| `order_estimated_delivery_date` | VARCHAR (TIMESTAMP) | 0 | Estimated delivery date shown to the customer at time of purchase. No nulls - always populated at order creation. |

---

#### raw.order_items

**Source file:** `olist_order_items_dataset.csv`
**Row count:** 112,650
**Description:** One row per line item within an order. An order containing 3 products produces 3 rows. Row count exceeds `raw.orders` because of multi-item orders.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `order_id` | VARCHAR | 0 | Foreign key → `raw.orders`. |
| `order_item_id` | INT | 0 | Line item sequence number within an order. Starts at 1. An order with 3 items has values 1, 2, 3. Maximum observed value: 21. |
| `product_id` | VARCHAR | 0 | Foreign key → `raw.products`. |
| `seller_id` | VARCHAR | 0 | Foreign key → `raw.sellers`. |
| `shipping_limit_date` | VARCHAR (TIMESTAMP) | 0 | Deadline by which the seller must ship to the carrier. Internal seller logistics metric - not used in customer-facing analysis. |
| `price` | FLOAT | 0 | Unit product price in BRL. Excludes freight. |
| `freight_value` | FLOAT | 0 | Shipping cost for this line item in BRL. |

---

#### raw.customers

**Source file:** `olist_customers_dataset.csv`
**Row count:** 99,441
**Description:** One row per order-customer mapping. Contains customer location data. Important: `customer_id` is generated per order, not per person. Use `customer_unique_id` to identify returning customers across multiple orders.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `customer_id` | VARCHAR | 0 | Primary key in this table. Per-order customer identifier. Joins to `raw.orders.customer_id`. Not a stable customer identity across orders. |
| `customer_unique_id` | VARCHAR | 0 | True unique customer identifier. 99,441 rows but only 96,096 unique values - approximately 3,345 customers placed more than one order. Use this for repeat purchase analysis. |
| `customer_zip_code_prefix` | INT | 0 | First 5 digits of the customer's Brazilian postal code. Stored as INT - leading zeros are lost. Join key to `raw.geolocation`. |
| `customer_city` | VARCHAR | 0 | Customer city name. Lower-case. Contains encoding inconsistencies - same city may appear with and without accent characters as separate entries. |
| `customer_state` | VARCHAR | 0 | Brazilian state abbreviation (e.g. SP, RJ, MG). 27 distinct states. |

---

#### raw.sellers

**Source file:** `olist_sellers_dataset.csv`
**Row count:** 3,095
**Description:** One row per seller registered on the Olist marketplace.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `seller_id` | VARCHAR | 0 | Primary key. Joins to `raw.order_items.seller_id`. |
| `seller_zip_code_prefix` | INT | 0 | First 5 digits of seller's postal code. Stored as INT - same leading-zero issue as customers. |
| `seller_city` | VARCHAR | 0 | Seller city name. Subject to same encoding inconsistencies as customer city. |
| `seller_state` | VARCHAR | 0 | Brazilian state abbreviation. Only 23 distinct states have sellers vs 27 states with customers - some states are buyer-only markets. |

---

#### raw.products

**Source file:** `olist_products_dataset.csv`
**Row count:** 32,951
**Description:** One row per product listed on Olist. Category names are in Portuguese. Use `raw.product_category_translation` to map to English equivalents.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `product_id` | VARCHAR | 0 | Primary key. |
| `product_category_name` | VARCHAR | 610 | Product category in Portuguese (e.g. `perfumaria`, `esporte_lazer`). 610 nulls represent uncategorised listings. 73 distinct categories. Join to `raw.product_category_translation` for English names. |
| `product_name_lenght` | INT | 610 | Character count of the product listing name. Note: column name has a typo in source - `lenght` instead of `length`. Preserved as-is in raw. Fix spelling in staging. |
| `product_description_lenght` | INT | 610 | Character count of the product description. Same typo as above. |
| `product_photos_qty` | INT | 610 | Number of product photos in the listing. Range: 1-19. |
| `product_weight_g` | INT | 2 | Product weight in grams. |
| `product_length_cm` | INT | 2 | Product length in centimetres. |
| `product_height_cm` | INT | 2 | Product height in centimetres. |
| `product_width_cm` | INT | 2 | Product width in centimetres. |

---

#### raw.order_payments

**Source file:** `olist_order_payments_dataset.csv`
**Row count:** 103,886
**Description:** One row per payment record. Row count exceeds `raw.orders` because customers can split payment across multiple methods. Each method produces a separate row.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `order_id` | VARCHAR | 0 | Foreign key → `raw.orders`. |
| `payment_sequential` | INT | 0 | Sequence number for split payments. If an order uses 2 payment methods, one row has value 1 and the other has value 2. Maximum observed: 29. |
| `payment_type` | VARCHAR | 0 | Payment method used. Values: `credit_card`, `boleto`, `voucher`, `debit_card`, `not_defined`. |
| `payment_installments` | INT | 0 | Number of installments chosen. Range: 0-24. Value 0 applies to boleto and voucher payments which do not support installments. |
| `payment_value` | FLOAT | 0 | Payment amount in BRL for this row. To get total order payment value, sum across all rows with the same `order_id`. |

---

#### raw.order_reviews

**Source file:** `olist_order_reviews_dataset.csv`
**Row count:** 99,224
**Description:** Customer reviews submitted after delivery. Every review has a numeric score, but most customers do not write a text comment - null rates on text columns are high.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `review_id` | VARCHAR | 0 | Primary key. |
| `order_id` | VARCHAR | 0 | Foreign key → `raw.orders`. |
| `review_score` | INT | 0 | Star rating 1-5. No nulls - every review record has a score. |
| `review_comment_title` | VARCHAR | 87,656 | Short review title written by the customer. 88% null rate - most customers skip this field. Text is in Portuguese. |
| `review_comment_message` | VARCHAR | 58,247 | Full review text written by the customer. 59% null rate. Text is in Portuguese. Usable for sentiment analysis on the ~41% that have content. |
| `review_creation_date` | VARCHAR (TIMESTAMP) | 0 | When Olist sent the review request to the customer. Internal operations timestamp. |
| `review_answer_timestamp` | VARCHAR (TIMESTAMP) | 0 | When the customer submitted the review. |

---

#### raw.geolocation

**Source file:** `olist_geolocation_dataset.csv`
**Row count:** 1,000,163
**Description:** Latitude and longitude coordinates mapped to Brazilian zip code prefixes. Not a unique-key table - each zip prefix has multiple coordinate entries. Must be aggregated before joining to customers or sellers.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `geolocation_zip_code_prefix` | INT | 0 | 5-digit zip code prefix. Join key to `raw.customers.customer_zip_code_prefix` and `raw.sellers.seller_zip_code_prefix`. Not unique - approximately 52 coordinate entries per zip on average. |
| `geolocation_lat` | FLOAT | 0 | Latitude coordinate. |
| `geolocation_lng` | FLOAT | 0 | Longitude coordinate. |
| `geolocation_city` | VARCHAR | 0 | City name for this zip entry. 8,011 distinct values due to encoding variants. |
| `geolocation_state` | VARCHAR | 0 | State abbreviation. 27 distinct values. |

---

#### raw.product_category_translation

**Source file:** `product_category_name_translation.csv`
**Row count:** 71
**Description:** Maps Portuguese product category names from `raw.products` to their English equivalents. Required for producing readable reports and dashboards.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `product_category_name` | VARCHAR | 0 | Portuguese category name. Join key → `raw.products.product_category_name`. |
| `product_category_name_english` | VARCHAR | 0 | English translation of the category name. |

**Sample mappings:**

| Portuguese | English |
|---|---|
| `beleza_saude` | health_beauty |
| `esporte_lazer` | sports_leisure |
| `informatica_acessorios` | computers_accessories |
| `cama_mesa_banho` | bed_bath_table |
| `brinquedos` | toys |

---

### 3.2 RetailRocket Source Tables

---

#### raw.events

**Source file:** `events.csv` - Retailrocket Recommender System Dataset (Roman Zykov, Kaggle)
**Row count:** 2,756,101
**Description:** Clickstream behavioural events from a real e-commerce platform. Captures the complete user funnel from product page views through to completed purchases. Analysed independently from Olist - no join between the two datasets.

| Column | Type | Nulls | Description |
|---|---|---|---|
| `timestamp` | INT (Unix ms) | 0 | Unix timestamp in milliseconds. Date range: May 2015 - Sep 2015. Convert to datetime using `unit='ms'` - not `unit='s'` which produces incorrect dates. |
| `visitorid` | INT | 0 | Anonymous visitor identifier. 1,407,580 distinct visitors. Not linked to any user account. |
| `event` | VARCHAR | 0 | Type of behavioural event. Three values: `view`, `addtocart`, `transaction`. |
| `itemid` | INT | 0 | Product identifier within the RetailRocket catalogue. 235,061 distinct products. No join to Olist product data - separate company, separate catalogue. |
| `transactionid` | FLOAT | 2,733,644 | Transaction identifier. Populated only for `event = 'transaction'` rows. 2,733,644 nulls is expected and correct - view and addtocart events carry no transaction ID. |

**Event volume breakdown:**

| Event | Row Count | Share |
|---|---|---|
| `view` | 2,551,374 | 92.6% |
| `addtocart` | 69,332 | 2.5% |
| `transaction` | 22,457 | 0.8% |

---

### 3.3 Synthetic / Generated Sources

---

#### raw.marketing

**Source:** `ingestion/marketing_generator.py` - internally generated
**Row count:** 100
**Description:** Synthetically generated marketing campaign performance data. Created to enable channel analysis alongside Olist transactional data. Date range aligns with Olist's 2017–2018 order window. ROAS and CTR values benchmarked to industry averages per channel.

> **Disclosure note:** *"Marketing data was synthetically generated to represent realistic D2C campaign patterns. In a production environment this table would be populated via the Google Ads API or a marketing attribution platform."*

| Column | Type | Nulls | Description |
|---|---|---|---|
| `campaign_month` | DATE | 0 | First day of the campaign month. 20 months × 5 channels = 100 rows. Range: Jan 2017 - Aug 2018. |
| `channel` | VARCHAR | 0 | Marketing channel. Values: `Google Search`, `Instagram`, `Facebook`, `Email`, `Organic`. |
| `spend` | FLOAT | 0 | Ad spend in USD. Range: 500-8,000 per month per channel. |
| `impressions` | INT | 0 | Total impressions served. |
| `clicks` | INT | 0 | Total clicks. Derived as impressions × CTR (1–5%). |
| `conversions` | INT | 0 | Completed purchases attributed to this channel. |
| `revenue_attributed` | FLOAT | 0 | Revenue credited to this channel. Derived from spend × channel ROAS benchmark. |
| `roas` | FLOAT | 0 | Return on ad spend = `revenue_attributed / spend`. |
| `cpa` | FLOAT | 0 | Cost per acquisition = `spend / conversions`. |
| `ctr` | FLOAT | 0 | Click-through rate = `clicks / impressions × 100`. Expressed as a percentage. |

---

## 4. Schema Relationship Map

```
raw.customers ──► raw.orders ──► raw.order_items ──► raw.products ──► raw.product_category_translation
                      │
                      ├──► raw.order_payments
                      │
                      └──► raw.order_reviews

raw.order_items ──► raw.sellers

raw.customers ──► raw.geolocation (aggregate zip before joining)
raw.sellers   ──► raw.geolocation (aggregate zip before joining)

--- Standalone (no join to Olist) ---
raw.events    - RetailRocket
raw.marketing - Synthetic
```

**Join notes:**
- `raw.geolocation` is not unique on zip prefix. Use `AVG(lat), AVG(lng) GROUP BY zip_code_prefix` before joining.
- `raw.order_payments` has multiple rows per `order_id` for split payments. Use `SUM(payment_value) GROUP BY order_id` for order-level totals.
- `raw.events` and `raw.marketing` have no join path to Olist tables. Analysed independently.

---

## 5. Centralised Data Quality Notes

| Table | Column | Issue | Action in Staging |
|---|---|---|---|
| `raw.orders` | `order_approved_at` | 160 nulls - canceled or unprocessed orders | Retain nulls, exclude from approval-lag calculations |
| `raw.orders` | `order_delivered_carrier_date` | 1,783 nulls - unshipped orders | Filter to non-null when computing dispatch timelines |
| `raw.orders` | `order_delivered_customer_date` | 2,965 nulls - undelivered orders | Filter to non-null when computing delivery performance |
| `raw.customers` | `customer_zip_code_prefix` | Stored as INT - leading zeros lost | Cast to VARCHAR, left-pad to 5 digits |
| `raw.customers` | `customer_city` | Inconsistent accent encoding | Normalise to ASCII |
| `raw.sellers` | `seller_zip_code_prefix` | Same INT / leading-zero issue | Same fix as customer zip |
| `raw.sellers` | `seller_city` | Same encoding inconsistency | Same normalisation |
| `raw.products` | `product_category_name` | 610 nulls - uncategorised products | Label as `uncategorized` |
| `raw.products` | `product_name_lenght` | Typo in source column name | Rename to `product_name_length` |
| `raw.products` | `product_description_lenght` | Same typo | Rename to `product_description_length` |
| `raw.geolocation` | `geolocation_zip_code_prefix` | ~52 coordinate entries per zip — not unique | Aggregate with `AVG(lat/lng) GROUP BY zip` |
| `raw.order_reviews` | `review_comment_title` | 88% null | Treat as optional; not a primary analysis column |
| `raw.order_reviews` | `review_comment_message` | 59% null | Usable for sentiment analysis on populated rows only |
| `raw.events` | `transactionid` | 2,733,644 nulls - expected, not a defect | Nulls on view/addtocart rows are correct by design |

---

*Raw table availability and row counts verified via `tests/verify_raw.py`. Column-level null counts, distinct counts, and data quality were documented via `tests/profile_raw.`*