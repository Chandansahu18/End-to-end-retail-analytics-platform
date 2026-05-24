# Executive Summary
**Period covered:** September 2016 - August 2018
**Prepared by:** Chandan Sahu
**Data sources:** Olist Brazilian E-Commerce · RetailRocket · Marketing Attribution

---

## Key Findings

**1. Revenue grew consistently but is dangerously concentrated.**
Total revenue reached R$ 15.74M across 98,000 orders. However, the top 3 product categories (health_beauty, watches_gifts, bed_bath_table) account for 35% of all revenue. A single bad quarter in any of these categories would materially impact
the business. Revenue spiked 34% above average in November 2017 - driven entirely by the Black Friday period - confirming that the business has not yet built
year-round demand.

**2. The customer base is not retained - it is constantly replaced.**
Repeat purchase rate stands at 3.04%, meaning 97 out of every 100 customers never
return after their first order. The Lost customer segment (34,013 customers) is the
single largest group in the base. Champions - the most valuable customers -
number only 15,398 but generate disproportionate revenue. At Risk customers show
the highest average spend (R$ 310) of any segment, making them the highest-priority
re-engagement target.

**3. 97% of website visitors never reach the cart.**
Of 2.55 million product page views, only 69,332 visitors (2.7%) added an item to
their cart. Only 22,457 completed a purchase - an overall conversion rate of 0.88%.
The largest drop-off occurs before any purchase intent is established, indicating
a product discovery and consideration experience that is failing to engage visitors.

**4. Delivery reliability is a retention risk in key categories.**
The platform-wide late delivery rate is 6.65%. Furniture and home comfort categories
show rates above 10% - significantly above average. Late deliveries correlate
directly with lower review scores (average 3.8 vs 4.2 for on-time deliveries),
creating a compounding retention risk in the platform's highest-volume categories.

**5. Marketing spend does not match channel performance.**
Organic search delivers a 5.0x return on ad spend - the highest of all channels.
Email marketing maintains the lowest cost per acquisition consistently across all
periods. Instagram delivers only 2.2x ROAS - the weakest channel - yet receives
substantial budget allocation. Current spend distribution reflects channel familiarity
rather than performance data.

---

## Recommendations

**Immediate (0–30 days)**
- Launch win-back email campaign targeting At Risk segment (34K customers,
  avg spend R$310). Even a 5% re-engagement rate generates R$530K incremental revenue
  at near-zero acquisition cost.
- Reallocate 15-20% of Instagram budget to Email and Organic amplification.
  This shift alone improves blended ROAS from approximately 3.2x to 3.8x.

**Short-term (30–90 days)**
- Conduct product page audit focused on the view-to-cart conversion gap.
  Improving view-to-cart rate by 1 percentage point on 2.55M views generates
  approximately 25,500 additional cart sessions.
- Introduce category-specific delivery SLA commitments for furniture and
  home comfort categories. Accurate delivery expectations reduce review score
  damage even when delays occur.

**Strategic (90+ days)**
- Build a mid-year promotional calendar to reduce dependence on the November
  peak. The underlying monthly demand exists - it is not being activated.
- Invest in retention infrastructure: loyalty programme, post-purchase
  communication sequences, and personalised replenishment triggers for
  health_beauty (the highest-frequency category).

---

## Methodology

**Data sources:** Olist Brazilian E-Commerce dataset (99,441 orders, 2016-2018),
RetailRocket clickstream dataset (2.75M events, May-Sep 2015), and synthetically
generated marketing attribution data (100 rows, 20 months × 5 channels).

**Pipeline:** Raw CSV files ingested into DuckDB via Python. Transformed through
a three-layer warehouse (raw → staging → marts) using dbt Core with 28 automated
data quality tests. Seven advanced SQL analyses covering cohort retention, RFM
segmentation, funnel analysis, and marketing efficiency. Visualised in a five-page
Power BI dashboard connected directly to mart tables.

**Analytical methods used:** Cohort retention analysis (12-month window),
RFM segmentation (NTILE(5) scoring), conversion funnel analysis, month-over-month
revenue trending, and marketing channel efficiency comparison (ROAS, CPA, CTR).

**Limitations:** Olist data is historical (2016-2018) and Brazilian-market specific.
Marketing data is simulated. RetailRocket funnel data is from a separate platform
and is not directly comparable to Olist order volumes. All figures are in BRL
unless otherwise stated.