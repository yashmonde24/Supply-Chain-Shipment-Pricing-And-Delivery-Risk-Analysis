## Supply Chain Shipment Pricing and Delivery Risk Analysis

## 1. Background & Overview
Health-commodity supply chains move pharmaceuticals and test kits across dozens of countries, through multiple vendors and shipment modes. When something goes wrong, it's rarely one big failure. It's usually a handful of specific vendor-country-mode combinations quietly underperforming while the aggregate numbers look fine.

This project analyzes shipment pricing and delivery data (structured after the real-world SCMS Supply Chain Shipment Pricing dataset) to answer three questions procurement and logistics leadership actually ask: Are we hitting delivery deadlines? Which vendors and shipment modes are worth the cost? Where is spend concentrated, and is it moving in the right direction?

Dataset reference: https://www.kaggle.com/datasets/divyeshardeshana/supply-chain-shipment-pricing-data

## 2. Data Structure Overview
Raw shipment data is loaded as-is into PostgreSQL, then cleaned into a single analysis-ready table. No star schema needed here — one fact table covers it.

Core entity: each row is one shipment line item, tied to a project code, PO/SO number, vendor, country, product group, and shipment mode.

Pipeline:
create_database_structure.sql — loads raw data into Postgres
data_cleaning_standardization.sql — dedupes, standardizes text, casts types
kpi_analysis_view.sql — builds reusable SQL views for reporting
data_exploration.py / kpi_analysis.py — Python EDA and KPI visualization
Dashboard.pbix — Power BI data model, DAX, and dashboard
ai_data_assistant.py — natural-language query layer on top of the same data

## 3. Executive Summary
On-time delivery is the weak point. 63% of shipments arrive on schedule, meaning over a third don't — the single biggest lever available for improvement. Cost tells a cleaner story: Ocean freight is the cheapest mode, but it's also one of the least reliable, so cheaper isn't automatically better. Delays aren't spread evenly across the business — they cluster in a specific set of country, vendor, and mode combinations, which makes this a targeted fix rather than an organization-wide overhaul. And there's no evidence bulk orders are earning better pricing, which is worth a direct conversation with procurement.

## 4. Insights Deep Dive
- Delivery performance
  On-time delivery sits at 63.02% overall. Zimbabwe and Cote d'Ivoire have the lowest on-time rates in the dataset. Ocean and Truck are the slowest, least           reliable  modes.

- Cost efficiency
  Ocean freight costs the least as a share of shipment value. Air Charter costs roughly twice as much per kilogram — a real trade-off between speed and cost, not    a straightforward "always choose the cheaper option" decision.

- Where delays actually come from
  Late shipments concentrate in specific combinations — a particular vendor, on a particular mode, into a particular country (Guyana via Air with certain vendors,   for example). This isn't a general reliability problem across the board.

- Vendor performance
  Spend is spread fairly evenly across the top five vendors — no single vendor dominates. On-time rates between them vary meaningfully, though, which is real        leverage in contract negotiations.

- Pricing behavior
  No bulk-discount pattern exists. The correlation between order quantity and unit price is 0.009 — effectively zero. Average unit price holds flat around $22–23    regardless of order size.

## 5. Recommendations
- Fix late deliveries where they actually happen. Delays cluster in specific vendor/mode/country combos — start there, not with a blanket policy change.
- Default to Ocean or Truck for non-urgent orders. Reserve Air Charter for shipments where the ~2x cost premium is actually justified.
- Weigh cost against reliability together. The cheapest mode isn't the most dependable one — build both into shipping decisions.
- Open a specific review into Zimbabwe and Cote d'Ivoire. Check whether it's a customs issue or a vendor/mode problem before assuming it can't be fixed.
- Use on-time rate as real leverage in vendor contract renewals, not just as a reporting metric.
- Compare bulk pricing agreements against what vendors are actually charging — the data shows no volume discount is happening in practice.
- Report delays as specific, not systemic. A handful of combinations drive most of the problem — say so plainly, so the response stays targeted.

## 6. Assumptions & Limitations
- Freight and weight fields contained placeholder text in the raw data (e.g. "Weight Captured Separately"); these were converted to nulls rather than guessed at,    so KPIs involving those fields are based on the subset of shipments with complete data.
- Lead time is measured from PO-sent-to-vendor date to actual delivery date — it does not include earlier steps like internal approval time before the PO is         placed.
- This analysis reflects one snapshot of the data. If the underlying dataset is updated or replaced, every number in this README needs to be re-verified against a   fresh pipeline run before being reused in reporting or presentations.
- The AI data assistant generates SQL from natural language — it's a convenience layer for ad hoc questions, not a replacement for the validated KPI views it sits   on top of.

## 7. Future Enhancements
- Extend the SQL views to support year-over-year comparison filters directly, rather than relying on the Power BI report for that slicing.
- Add a lightweight alerting layer that flags a shipment as at-risk once it passes its planned lead time without a delivery record.
- Expand the AI data assistant's schema awareness to cover the KPI views directly, so it can answer aggregate questions without regenerating logic already built     in SQL.

## 8. Deliverables

AI-powered layer

Lets a business user ask plain-English questions about the data and get an answer back, without writing SQL.

How it works: pull the real table schema from Postgres, send the question and schema to Gemini, get back a single SELECT statement, validate it before running anything (SELECT-only, hard block on DROP/DELETE/UPDATE/INSERT/ALTER — the model never gets write access, no exceptions), run it, then have Gemini summarize the result in plain English.

Why it's here at all: the SQL views already answer the core KPIs. This exists for the follow-up questions that don't have a pre-built view — "which vendor in Vietnam has the worst on-time rate," "what's total freight cost for Ocean shipments over $10k" — the kind of question a manager would otherwise have to ask an analyst to write SQL for.
