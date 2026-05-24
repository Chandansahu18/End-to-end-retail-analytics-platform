# KPI Definitions

## Revenue Metrics

| KPI | Definition | Formula | Source table |
|---|---|---|---|
| **Total Revenue** | Sum of all order payment values for delivered orders | `SUM(total_order_value)` | `marts.fact_orders` |
| **AOV (Average Order Value)** | Average revenue per completed order | `Total Revenue / Total Orders` | `marts.fact_orders` |
| **Revenue Per Customer** | Average lifetime spend per unique customer | `Total Revenue / Unique Customers` | `marts.fact_orders` |
| **MoM Revenue Growth %** | Month-over-month percentage change in revenue | `(Current Month Revenue - Prior Month Revenue) / Prior Month Revenue` | `marts.fact_orders` + `dim_date` |
| **Product Revenue** | Revenue attributed at item level including freight | `SUM(price + freight_value)` per item | `marts.fact_order_item` |

---

## Customer Metrics

| KPI | Definition | Formula | Source table |
|---|---|---|---|
| **Unique Customers** | Count of distinct true customer identifiers | `DISTINCTCOUNT(customer_unique_id)` | `marts.fact_orders` |
| **Repeat Customer Rate** | Percentage of customers with more than one order | `Customers with orders > 1 / Total Customers` | `marts.dim_customer` |
| **Avg Lifetime Value** | Average total spend per customer across all orders | `AVERAGE(lifetime_value)` | `marts.dim_customer` |
| **Churn Risk Rate** | Percentage of customers with no order in 90+ days relative to dataset max date | `Customers inactive 90+ days / Total Customers` | `marts.dim_customer` |
| **Customer Lifespan** | Days between first and last order for a customer | `last_order_date - first_order_date` in days | `marts.dim_customer` |

---

## RFM Metrics

| KPI | Definition | Formula | Source table |
|---|---|---|---|
| **Recency Score (R)** | NTILE(5) bucket on days since last order — higher score = more recent | `NTILE(5) ORDER BY recency_days DESC` | `marts.fact_rfm` |
| **Frequency Score (F)** | NTILE(5) bucket on distinct order count — higher score = more orders | `NTILE(5) ORDER BY frequency ASC` | `marts.fact_rfm` |
| **Monetary Score (M)** | NTILE(5) bucket on total spend — higher score = higher spend | `NTILE(5) ORDER BY monetary ASC` | `marts.fact_rfm` |
| **RFM Score** | Composite three-digit score combining R, F, M | Concatenation of R + F + M scores (e.g. "555" = Champion) | `marts.fact_rfm` |
| **Champions** | Customers with R ≥ 4 and F ≥ 4 | CASE logic on R and F scores | `marts.fact_rfm` |
| **At Risk** | Customers with R ≤ 2 and F ≥ 3 and M ≥ 3 | CASE logic on R, F, M scores | `marts.fact_rfm` |
| **Lost** | Customers with R ≤ 2 and F ≤ 2 | CASE logic on R and F scores | `marts.fact_rfm` |

---

## Delivery Metrics

| KPI | Definition | Formula | Source table |
|---|---|---|---|
| **Late Delivery Rate** | Percentage of delivered orders that arrived after estimated date | `Late orders / Total delivered orders × 100` | `marts.fact_orders` |
| **Delivery Delay Days** | Signed integer of days difference between actual and estimated delivery | `order_delivered_customer_date - order_estimated_delivery_date` | `marts.fact_orders` |
| **Is Late Delivery** | Boolean flag - TRUE if actual delivery date exceeds estimated date | `order_delivered_customer_date > order_estimated_delivery_date` | `marts.fact_orders` |

---

## Funnel Metrics

| KPI | Definition | Formula | Source table |
|---|---|---|---|
| **Total Views** | Total product page view events | `SUM(total_views)` | `marts.fact_events` |
| **Total Add to Carts** | Total add-to-cart events | `SUM(total_addtocarts)` | `marts.fact_events` |
| **Total Transactions** | Total completed purchase events | `SUM(total_transactions)` | `marts.fact_events` |
| **View to Cart Rate** | Percentage of views that result in add-to-cart | `Add to Carts / Views × 100` | `marts.fact_events` |
| **Cart to Purchase Rate** | Percentage of cart additions that result in purchase | `Transactions / Add to Carts × 100` | `marts.fact_events` |
| **Overall Conversion Rate** | Percentage of views that result in completed purchase | `Transactions / Views × 100` | `marts.fact_events` |

---

## Marketing Metrics

| KPI | Definition | Formula | Source table |
|---|---|---|---|
| **ROAS (Return on Ad Spend)** | Revenue generated per unit of ad spend | `Revenue Attributed / Ad Spend` | `marts.fact_marketing` |
| **CPA (Cost Per Acquisition)** | Ad spend required to generate one conversion | `Ad Spend / Conversions` | `marts.fact_marketing` |
| **CTR (Click-Through Rate)** | Percentage of impressions that result in a click | `Clicks / Impressions × 100` | `marts.fact_marketing` |
| **Blended ROAS** | ROAS calculated across all channels combined | `Total Revenue Attributed / Total Ad Spend` | `marts.fact_marketing` |
| **Efficiency Delta** | Difference between revenue share and budget share per channel | `Revenue Share % - Budget Share %` | `marts.fact_marketing` |
| **Budget Share %** | Channel's spend as percentage of total marketing spend | `Channel Spend / Total Spend × 100` | `marts.fact_marketing` |

---

## Cohort Metrics

| KPI | Definition | Formula | Source table |
|---|---|---|---|
| **Cohort Month** | Month of a customer's first purchase | `DATE_TRUNC('month', MIN(order_date))` per customer | `marts.fact_orders` |
| **Months Since First Purchase** | Integer months elapsed between cohort month and any subsequent order month | `DATEDIFF('month', cohort_month, order_month)` | Derived in SQL |
| **Cohort Retention %** | Percentage of cohort active in a given month offset | `Active customers in month N / Cohort size × 100` | `sql/cohort_retention.sql` |
| **Cohort Size** | Number of customers who made their first purchase in a given month | `COUNT(DISTINCT customer_unique_id)` at months_since_first = 0 | `sql/cohort_retention.sql` |