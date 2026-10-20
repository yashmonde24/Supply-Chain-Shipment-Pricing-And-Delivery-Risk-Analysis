## Supply Chain Vendor & Delivery Performance Analysis

## 1. Background & Overview
A health-supply organization ships medicines and test kits to 15 countries through 11 vendors and 4 shipping modes (Air, Air Charter, Ocean, Truck). Leadership wants shipments to arrive on time without overspending on freight.

This project analyzes shipment pricing and delivery data (structured after the real-world SCMS Supply Chain Shipment Pricing dataset) to answer three questions procurement and logistics leadership actually ask: Are we hitting delivery deadlines? Which vendors and shipment modes are worth the cost? Where is spend concentrated, and is it moving in the right direction?

Problem statement :
 Only 63% of shipments arrive on time. It isn’t clear whether the delays and freight costs  come from particular countries, vendors or shipping modes or from how the whole operation  runs.

Objective :
 - Measure on-time delivery, freight cost, and vendor performance.
 - Find out whether delays are concentrated in a few places or spread everywhere.
 - Test whether the gaps between countries, vendors, and shipping modes are real or could     be chance.
 - Show the results in a dashboard, and let non-technical users ask questions in plain        English.

## 2. Data Structure Overview
Data layers (medallion pattern on PostgreSQL schemas):
 - Bronze is raw data loaded as-is.
 - Silver is the cleaned, into a single analysis-ready table. No star schema needed here  — one fact table covers it.
 - Gold is the KPI views for reporting and analysis.

Each row is one shipment line: country, vendor, product group, shipping mode, order and delivery dates, quantity, price, weight, and freight cost.

What the cleaning step fixed:
 - 25 duplicate orders removed (6,025 rows down to 6,000)
 - Inconsistent spelling and spacing in country and vendor names.
 - Text sitting in number fields (for example "Weight Captured Separately"), turned into      blanks.
 - Impossible values, such as a zero price or a negative quantity, turned into blanks.

Pipeline:
- create_database_structure.sql(Bronze Layer) — loads raw data into Postgres
- data_cleaning_standardization(Silver Layer).sql — dedupes, standardizes text, casts types
- kpi_analysis_view(Gold Layer).sql — builds reusable SQL views for reporting
- data_exploration.py / kpi_analysis.py — Python EDA and KPI visualization
- Dashboard.pbix — Power BI data model, DAX, and dashboard
- ai_data_assistant.py — answers plain-English questions about the data

## 3. Executive Summary
63% of shipments arrive on time (3,592 of the 5,700 that have a delivery date), so 2,108 were late. The delays are spread across the whole operation. No single country, vendor, or shipping mode explains them.

  - It takes 296 of 561 country, vendor, and mode combinations to account for 80% of late      shipments. The worst combination has only 14 late shipments, under 1% of the total.
  - Shipping mode barely changes the result. On-time rates run from 60.54% (Ocean) to          64.25% (Air), and freight cost runs from 9.67% to 10.15% of order value. A statistical     test says gaps this small could be chance.
  - Freight cost follows shipment size. Order quantity and weight together explain about       51% of it.
  - Ordering more does not earn a lower price. Order size and unit price are unrelated         (correlation 0.009)

## 4. Insights Deep Dive
- Delivery
  - On-time rate is 63.02% overall. Haiti is highest at 66.19% and Zimbabwe lowest at          60.21%, a six-point gap across 15 countries.
  - Air handles 55.0% of shipments and accounts for 53.1% of late ones, so Air is late         about as often as everything else.

- Where the delays come from
  - A concentration check (Pareto, the "80/20" test) asks how few combinations cause most      delays. Here the answer is many, not few: 296 of 561 combinations are needed to reach 80%. Fixing one vendor or one route would remove only a small slice.

- Shipping modes

  - On-time rate: Air 64.25%, Air Charter 63.11%, Truck 62.15%, Ocean 60.54%.
  - Freight cost as a share of order value: Air Charter 10.15%, Air 9.93%, Truck 9.78%,        Ocean 9.67%.
  - Two significance tests (chi-square for on-time rate, ANOVA for freight cost) both came  back "not significant" (p = 0.12 and p = 0.14). The gaps are too small to call real.

- Cost

  - Each extra unit ordered adds about $2.23 to freight cost, and each extra kilogram adds about $11.19. Quantity is the stronger and more certain driver (linear regression,         5,175 shipments).
  - Unit price averages $22.54 and stays flat as order size grows.

- Vendors and spend

  - The 11 vendors each receive between $145M and $182M of the $1.83B total. Their average  prices sit between $21.82 and $23.40, and their on-time rates between 60.00% and           66.26%.
  - Vendors were sorted into four groups (K-means clustering): Best Value (3 vendors),         Premium (2), Budget Risk (2), and Avoid (4). The gaps behind these groups are small,       so the groups are a starting point for conversations, not a verdict.
  - Spend is also evenly spread across the five product groups, 19% to 21% each..

## 5. Recommendations
- Treat late delivery as a company-wide process issue. Look for causes shared across every country, vendor and mode, such as how delivery dates are set and tracked, before replacing any one vendor. Track the on-time rate monthly.
- Choose the shipping mode by urgency, not by assumed cost or reliability. In this data the modes differ too little in either to justify a rule.
- Plan freight budgets from order quantity and shipment weight, and negotiate rates on that basis.
- Do not count on bulk discounts. Compare contracts with the prices actually paid, and ask vendors for volume pricing.
- Use the four vendor groups as a starting list for contract reviews.

## 6. Assumptions & Limitations
- The data is synthetic. If it is replaced with the real SCMS dataset, rerun everything. Every number here will change.
- The 63% on-time rate covers 5,700 of 6,000 shipments. The other 300 have no delivery date and are left out.
- Weight or freight cost is missing for about 14% of shipments, so the cost analysis uses the 5,175 shipments with complete data.
- Lead time counts from the day the order is sent to the vendor to the day of delivery.
- "Not significant" means the data cannot show a difference, not that none exists. - -Differences between vendors and between countries were not tested.
- Weight and quantity rise together, so their separate effects on freight cost are hard to pull apart.
- The AI assistant writes SQL from plain-English questions. Check important answers against the KPI views.

## 7. Future Enhancements
- Extend the SQL views to support year-over-year comparison filters directly, rather than relying on the Power BI report for that slicing.
- Add a lightweight alerting layer that flags a shipment as at-risk once it passes its planned lead time without a delivery record.
- Expand the AI data assistant's schema awareness to cover the KPI views directly, so it can answer aggregate questions without regenerating logic already built     in SQL.

## 8. Deliverables

AI-powered layer

Lets a business user ask plain-English questions about the data and get an answer back, without writing SQL.

How it works: pull the real table schema from Postgres, send the question and schema to Gemini, get back a single SELECT statement, validate it before running anything (SELECT-only, hard block on DROP/DELETE/UPDATE/INSERT/ALTER — the model never gets write access, no exceptions), run it, then have Gemini summarize the result in plain English.

Why it's here at all: the SQL views already answer the core KPIs. This exists for the follow-up questions that don't have a pre-built view — "which vendor in Vietnam has the worst on-time rate," "what's total freight cost for Ocean shipments over $10k" — the kind of question a manager would otherwise have to ask an analyst to write SQL for.

## 9. Outcomes Preview :
- Dashboard : https://github.com/yashmonde24/Supply-Chain-Shipment-Pricing-And-Delivery-Risk-Analysis/blob/main/output/Dashboard.pdf
- LLM Interaction : https://github.com/yashmonde24/Supply-Chain-Shipment-Pricing-And-Delivery-Risk-Analysis/blob/main/output/LLM%20working%20with%20DB.mp4
- EDA Visualization : https://github.com/yashmonde24/Supply-Chain-Shipment-Pricing-And-Delivery-Risk-Analysis/tree/main/output
