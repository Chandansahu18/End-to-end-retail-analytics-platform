
## 1. Introduction

The mart layer contains analytics-ready business models built from staging and intermediate dbt models.

These marts are designed for:
- KPI reporting
- customer analytics
- cohort retention analysis
- funnel and conversion analysis
- marketing performance tracking
- RFM segmentation
- Power BI dashboards and reporting

All mart models are materialized as **tables** under the `marts` schema in DuckDB.

Unlike the staging layer, marts contain business-ready entities and aggregated reporting logic intended for direct analytical consumption.

---

## 2. Mart Layer Design Principles

The mart layer follows a dimensional modeling approach using:
- Fact tables for measurable business events
- Dimension tables for descriptive business attributes

The warehouse is structured to support:
- Star-schema analytics workflows
- Time-series reporting
- Customer and product analysis
- Dashboard-friendly aggregations
- Efficient BI querying in Power BI

---

## 3. Mart Relationship Overview

```text
fact_orders
├── dim_customer
├── dim_product
└── dim_date

fact_events
├── dim_product
└── dim_date

fact_marketing
└── dim_date
```

---

# 4. Fact Tables

---

## 4.1 fact_orders

**dbt model:** `models/marts/fact_orders.sql`

**Grain:** One row per order

**Purpose:**

Primary transactional fact table used for:
- revenue reporting
- customer analytics
- cohort retention analysis
- RFM segmentation
- operational KPI tracking
- Power BI reporting

### Key Business Metrics

- Total Revenue
- Total Orders
- Average Order Value (AOV)
- Revenue per Customer
- Average Order Frequency
- Late Delivery %
- Review Score Trends

### Columns

| Column | Description |
|---|---|
| `order_id` | Unique order identifier |
| `customer_unique_id` | Unique customer identifier |
| `order_date` | Order purchase date |
| `order_year` | Calendar year of order |
| `order_month` | Calendar month of order |
| `customer_state` | Customer state location |
| `total_order_value` | Final order revenue |
| `review_score` | Customer review rating |
| `is_late_delivery` | Delivery SLA breach flag |

### Downstream Usage

Used in:
- KPI reporting queries
- cohort retention analysis
- RFM segmentation
- revenue trend analysis
- operational performance dashboards

---

## 4.2 fact_events

**dbt model:** `models/marts/fact_events.sql`

**Grain:** One row per event reporting date

**Purpose:**

Behavioral analytics fact table used to measure:
- customer funnel behavior
- conversion performance
- event activity trends
- ecommerce engagement patterns

### Key Business Metrics

- View-to-Cart Conversion Rate
- Cart-to-Purchase Conversion Rate
- Overall Funnel Conversion %
- Funnel Drop-Off %
- Unique Visitors

### Columns

| Column | Description |
|---|---|
| `event_date` | Event reporting date |
| `unique_visitors` | Distinct daily visitors |
| `total_views` | Product page views |
| `total_addtocarts` | Add-to-cart events |
| `total_transactions` | Purchase events |
| `view_to_cart_rate` | Percentage of views converted to add-to-cart |
| `cart_to_purchase_rate` | Percentage of carts converted to purchases |
| `overall_conversion_rate` | Overall funnel conversion percentage |

### Downstream Usage

Used in:
- funnel analysis
- behavioral trend reporting
- conversion dashboards
- Power BI funnel visualizations

---

## 4.3 fact_marketing

**dbt model:** `models/marts/fact_marketing.sql`

**Grain:** One row per marketing channel per campaign month

**Purpose:**

Marketing analytics fact table used for:
- channel performance analysis
- campaign efficiency tracking
- ROAS reporting
- marketing trend analysis

### Key Business Metrics

- ROAS (Return on Ad Spend)
- CPA (Cost per Acquisition)
- CTR (Click Through Rate)
- Conversion Rate
- Channel Efficiency

### Columns

| Column | Description |
|---|---|
| `campaign_month` | Monthly reporting period |
| `channel` | Marketing acquisition channel |
| `spend` | Marketing spend amount |
| `impressions` | Total ad impressions |
| `clicks` | Total ad clicks |
| `conversions` | Total attributed conversions |
| `revenue_attributed` | Revenue attributed to marketing channel |
| `roas` | Return on ad spend |
| `cpa` | Cost per acquisition |
| `ctr` | Click-through rate |
| `performance_tier` | Channel performance classification |

### Downstream Usage

Used in:
- marketing performance analysis
- ROAS trend reporting
- budget efficiency analysis
- Power BI marketing dashboards

---

# 5. Dimension Tables

---

## 5.1 dim_customer

**dbt model:** `models/marts/dim_customer.sql`

**Grain:** One row per unique customer

**Purpose:**

Customer dimension table used for:
- customer segmentation
- geographic analysis
- retention analysis
- customer-level reporting

### Columns

| Column | Description |
|---|---|
| `customer_unique_id` | Stable unique customer identifier |
| `customer_city` | Customer city |
| `customer_state` | Customer state |
| `customer_zip_code_prefix` | Customer ZIP prefix |

### Downstream Usage

Used in:
- RFM segmentation
- retention analysis
- geographic revenue analysis
- customer dashboards

---

## 5.2 dim_product

**dbt model:** `models/marts/dim_product.sql`

**Grain:** One row per product

**Purpose:**

Product dimension table used for:
- product performance analysis
- category reporting
- funnel analysis
- revenue contribution analysis

### Columns

| Column | Description |
|---|---|
| `product_key` | Unique product identifier |
| `category_english` | Product category in English |
| `avg_price` | Average catalog price |
| `product_weight_g` | Product weight in grams |

### Downstream Usage

Used in:
- category revenue analysis
- top product reporting
- conversion analysis
- product performance dashboards

---

## 5.3 dim_date

**dbt model:** `models/marts/dim_date.sql`

**Grain:** One row per calendar date

**Purpose:**

Central calendar dimension used for:
- time-series reporting
- monthly trends
- cohort analysis
- dashboard filtering

### Columns

| Column | Description |
|---|---|
| `date_day` | Calendar date |
| `year` | Calendar year |
| `month` | Calendar month |
| `quarter` | Calendar quarter |
| `weekday` | Day name |
| `week_of_year` | Calendar week number |

### Downstream Usage

Used in:
- revenue trend analysis
- retention analysis
- marketing trend reporting
- Power BI date filtering

---

# 6. Analytical Coverage

The mart layer supports the following analytical workflows:

| Analytical Area | Supporting Models |
|---|---|
| KPI Reporting | `fact_orders` |
| Cohort Retention | `fact_orders`, `dim_date` |
| RFM Segmentation | `fact_orders`, `dim_customer` |
| Funnel Analysis | `fact_events` |
| Revenue Analysis | `fact_orders`, `dim_product` |
| Marketing Performance | `fact_marketing` |
| Geographic Analysis | `fact_orders`, `dim_customer` |

---

# 7. Power BI Usage

The marts layer is designed specifically for downstream BI consumption.

These models support:
- star schema relationships in Power BI
- KPI cards
- time-series visualizations
- customer segmentation visuals
- marketing dashboards
- funnel analysis pages

Fact tables act as the analytical core, while dimensions provide filtering and drill-down capability.

---

# 8. Validation and Quality

All mart models are validated through:
- dbt model testing
- upstream staging validations
- business logic verification
- analytical query validation in DBeaver

Mart models are built exclusively from:
- staging models
- intermediate models
- dbt `ref()` dependencies

No mart model reads directly from raw source tables.

---

# 9. Warehouse Architecture Summary

```text
Raw Sources
    ↓
Staging Models
    ↓
Intermediate Models
    ↓
Mart Layer
    ↓
SQL Analytics + Power BI Reporting
```

---

*Mart layer built using dbt Core + DuckDB*
*Warehouse designed for BI reporting workflows*
*All marts validated through `dbt build`**