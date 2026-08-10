# Supply Chain Shipment Pricing and Delivery Risk Analysis

An end-to-end data analytics project analyzing pharmaceutical/health-commodity
shipment pricing and logistics data — the kind of dataset used by global
health supply chains (modeled on the real-world SCMS Supply Chain Shipment
Pricing dataset). Built to demonstrate SQL, Python, and BI skills together on
one realistic business problem.

**Real dataset reference:** https://www.kaggle.com/datasets/divyeshardeshana/supply-chain-shipment-pricing-data


## Business problem

A health-commodity supply chain organization ships pharmaceuticals and test
kits to dozens of countries through multiple vendors and shipment modes. Ops
and procurement leadership need to know:
1. Are we hitting delivery deadlines, and where are we failing?
2. Which shipment modes and vendors are cost-efficient vs. wasteful?
3. Where is spend concentrated, and is it trending up or down?

## Tech stack & pipeline

PostgreSQL :
-> create_database_structure.sql : Raw data loading.
-> data_cleaning_standardization.sql : Data Cleaning, Deduplication, Standization, Type - Casting.
-> kpi_analysis_view.sql : KPI views for reporting and analysis.
        
Python :   
-> data_exploration.py : Explore missing data, data distributions, outliers.
-> kpi_analysis.py : KPI charts, business insights.
        
Power BI : 
-> Dashboard.pbix : Data model, DAX, Dashboard creation.

AI-powered layer (adds natural-language capability):
      
Python -> ai_data_assistant.py  (text-to-SQL: ask questions in plain English, get validated SQL query + an answer).

## Data cleaning highlights 

- Removed 25 exact duplicate order submissions.
- Standardized inconsistent country/vendor casing and whitespace (`"  VIETNAM  "` → `"Vietnam"`).
- Converted placeholder text hiding inside numeric columns (`"Weight Captured
  Separately"`, `"Freight Included in Commodity Cost"`) into proper NULLs instead
  of breaking numeric aggregations.
- Nulled out impossible values (zero unit price, negative quantity) rather than
  letting them distort KPI averages.
- Cast all date fields to proper `DATE` type to support lead-time calculations

## Key KPIs Analyzed 

 (KPI + Business Question) : 

 1.  On-Time Delivery Rate :  Are shipments arriving by the scheduled date? 
 2.  Avg Lead Time (Planned vs Actual)  How accurate is our delivery forecasting? 
 3.  Freight Cost as % of Shipment Value : Which shipment modes are cost-efficient? 
 4.  Freight Cost per Kilogram : Logistics cost efficiency, normalized for shipment size 
 5.  Vendor Scorecard (spend, on-time rate, price volatility) : Which vendors are reliable and fairly priced? 
 6.  Vendor Cost vs Reliability : Are our cheapest vendors also our least reliable ones? 
 7.  Spend by Product Group / Country  : Where is budget concentrated ? 
 8.  Monthly Spend & Volume Trend :  Is demand/cost trending up or down? 
 9.  Late Shipment Root Cause : Which country + mode + vendor combos drive delays? 
 10. Quantity vs Unit Price : Does ordering in bulk actually earn a better price? 
 11. Correlation Matrix : How do cost, weight, and lead-time variables relate to each other? 

## Key Findings :

- **Overall on-time delivery rate: 63.02%** — roughly half of shipments miss
  their scheduled date, which is the single biggest opportunity area.

- **Ocean freight is the cheapest mode** by freight cost as % of shipment value,
  while Air Charter costs roughly 2x more per kg — a clear cost/speed trade-off
  for planners to weigh route-by-route.

- **Ocean and Truck freight are the slowest/least reliable modes**  

- Zimbabwe and Cote d'Ivoire have the lowest on-time delivery rates, worth a
  root-cause review with the logistics team.

- Vendor spend is fairly evenly distributed across the top 5 vendors (no
  single vendor dominates), but on-time rates vary meaningfully between
  them — useful leverage in vendor negotiations.

- **No bulk-discount pattern exists in this data** — correlation between order
  quantity and unit price is 0.009 (effectively zero). Average unit price is
  flat (~$22-23) regardless of order size. Worth flagging to procurement: if
  pricing is meant to scale with volume, it currently doesn't.

- Late deliveries aren't evenly spread — they concentrate in specific
  country/mode/vendor combinations (e.g. Guyana via Air with certain vendors),
  not a general reliability problem. That's a targeted fix, not a systemic one.

## AI-powered features

# Purpose : 
# Let a business user ask plain-English questions about the shipment data and get an answer back, without knowing SQL.

# Architecture (text-to-SQL, not a general chatbot):
# - Pull the real table schema from Postgres.
# - Send the question + schema to Gemini, asking for a single PostgreSQL SELECT statement
# - VALIDATE the generated SQL before running it - only SELECT is allowed, no DROP/DELETE/UPDATE/INSERT/ALTER/etc, regardless of
#   the model returns. This is the part that makes this safe to demo: the LLM never gets write access, ever.
# - Execute the validated query against Postgres.
# - Ask Gemini to summarize the result in plain English.

# Why integrated LLM model ?
# - SQL views already answer the core KPIs. 
# - This tool exists for the follow-up questions that don't have a pre-built view - 
#     - Which vendor in Vietnam has the worst on-time rate ?
#     - What's total freight cost for Ocean shipments over $10k?
# - Ad hoc questions a manager would otherwise have to ask an analyst to write SQL for.

**AI data assistant** (`ai_data_assistant.py`) — text-to-SQL interface
   for ad hoc questions that don't have a pre-built dashboard view. Full
   safety design (SELECT-only enforcement).

