-- KPI 1: On-Time Delivery Rate (overall, and by country / shipment mode)
-- Use Case : Supply chain reliability metric.
-- ---------------------------------------------------------------------
SELECT
    ROUND(100.0 * SUM(CASE WHEN is_on_time = 'YES' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(is_on_time), 0), 2) AS on_time_delivery_rate_pct
FROM clean_shipment_pricing;

CREATE OR REPLACE VIEW vw_otd_by_country AS
SELECT
    country,
    COUNT(*)                                                   AS total_shipments,
    SUM(CASE WHEN is_on_time = 'YES' THEN 1 ELSE 0 END)        AS on_time_shipments,
    ROUND(100.0 * SUM(CASE WHEN is_on_time = 'YES' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(is_on_time), 0), 2)  AS on_time_delivery_rate_pct
FROM clean_shipment_pricing
GROUP BY country
ORDER BY on_time_delivery_rate_pct DESC;

CREATE OR REPLACE VIEW vw_otd_by_shipment_mode AS
SELECT
    shipment_mode,
    COUNT(*)                                                            AS total_shipments,
    ROUND(100.0 * SUM(CASE WHEN is_on_time = 'YES'  THEN 1 ELSE 0 END)
          / NULLIF(COUNT(is_on_time), 0), 2)                            AS on_time_delivery_rate_pct,
    ROUND(AVG(actual_lead_time_days), 1)                                AS avg_lead_time_days
FROM clean_shipment_pricing
GROUP BY shipment_mode
ORDER BY on_time_delivery_rate_pct DESC;

-- ---------------------------------------------------------------------
-- KPI 2: Average Order Lead Time (planned vs actual)
-- Why it matters: Shows forecasting accuracy and vendor reliability.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_lead_time_summary AS
SELECT
    ROUND(AVG(planned_lead_time_days), 1) AS avg_planned_lead_time_days,
    ROUND(AVG(actual_lead_time_days), 1)  AS avg_actual_lead_time_days,
    ROUND(AVG(actual_lead_time_days - planned_lead_time_days), 1) AS avg_schedule_variance_days
FROM clean_shipment_pricing
WHERE planned_lead_time_days IS NOT NULL
  AND actual_lead_time_days IS NOT NULL;

-- ---------------------------------------------------------------------
-- KPI 3: Freight Cost as % of Shipment Value (by shipment mode)
-- Usecase: Cost-efficient shipement  mode ; Air is fast but expensive.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_freight_efficiency_by_mode AS
SELECT
    shipment_mode,
    COUNT(*)                                    AS shipments,
    ROUND(AVG(freight_pct_of_value), 2)         AS avg_freight_pct_of_value,
    ROUND(AVG(freight_cost_per_kg), 2)          AS avg_freight_cost_per_kg,
    ROUND(SUM(freight_cost_usd), 2)             AS total_freight_cost
FROM clean_shipment_pricing
WHERE freight_pct_of_value IS NOT NULL
GROUP BY shipment_mode
ORDER BY avg_freight_pct_of_value DESC;

-- ---------------------------------------------------------------------
-- KPI 4: Vendor Performance Scorecard
-- Use Case : Ranks vendors on reliability + cost, standard procurement / vendor management.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_vendor_scorecard AS
SELECT
    vendor,
    COUNT(*)                                                            AS total_orders,
    ROUND(SUM(line_item_value), 2)                                      AS total_order_value_usd,
    ROUND(100.0 * SUM(CASE WHEN is_on_time = 'YES'  THEN 1 ELSE 0 END)
          / NULLIF(COUNT(is_on_time), 0), 2)                            AS on_time_delivery_rate_pct,
    ROUND(AVG(unit_price), 2)                                           AS avg_unit_price,
    ROUND(STDDEV(unit_price), 2)                                        AS unit_price_volatility
FROM clean_shipment_pricing
GROUP BY vendor
--HAVING COUNT(*) >= 10                       -- ignore vendors with too few orders to be meaningful
ORDER BY total_order_value_usd DESC;

-- ---------------------------------------------------------------------
-- KPI 5: Spend by Product Group / Country (where is the money going)
-- Use Case : Budget allocation and category-management.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_spend_by_product_country AS
SELECT
    product_group,
    country,
    COUNT(*)                          AS total_shipments,
    ROUND(SUM(line_item_value), 2)    AS total_spend,
    ROUND(AVG(unit_price), 2)         AS avg_unit_price
FROM clean_shipment_pricing
GROUP BY product_group, country
ORDER BY total_spend DESC;

-- ---------------------------------------------------------------------
-- KPI 6: Monthly Spend & Shipment Volume Trend
-- Use Case : Trend line for demand planning and budget forecasting.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_trend AS
SELECT
    DATE_TRUNC('month', po_sent_to_vendor_date)::DATE AS order_month,
    COUNT(*)                                          AS shipment_count,
    ROUND(SUM(line_item_value), 2)                    AS total_value_usd,
    ROUND(AVG(actual_lead_time_days), 1)              AS avg_lead_time_days
FROM clean_shipment_pricing
WHERE po_sent_to_vendor_date IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- ---------------------------------------------------------------------
-- KPI 7: Late Shipment Root Cause View
-- Use Case : Pinpoints which country + mode + vendor combos drive late deliveries, directly actionable for operation teams.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_late_shipment_drivers AS
SELECT
    country,
    shipment_mode,
    vendor,
    COUNT(*)  AS late_shipments,
    ROUND(AVG(actual_lead_time_days - planned_lead_time_days), 1) AS avg_days_late
FROM clean_shipment_pricing
WHERE is_on_time = 'NO'
GROUP BY country, shipment_mode, vendor
ORDER BY late_shipments DESC;
-- LIMIT 20;

-- ---------------------------------------------------------------------
-- KPI 8: Order Quantity vs Unit Price (bulk discount check)
-- Use Case: Tells procurement whether ordering in bulk actually
-- earns a better price, or whether pricing is flat regardless of volume.
-- Buckets quantity into tiers rather than using raw scatter, since raw
-- unit price is noisy across many different products.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_quantity_vs_price AS
SELECT
    CASE
        WHEN line_item_quantity < 1000 THEN 'Under 1,000'
        WHEN line_item_quantity < 5000 THEN '1,000 - 4,999'
        WHEN line_item_quantity < 10000 THEN '5,000 - 9,999'
        WHEN line_item_quantity < 25000 THEN '10,000 -24,999'
        ELSE '25,000+'
    END  AS quantity_tier,
    COUNT(*) AS total_shipments,
    ROUND(AVG(unit_price), 2) AS avg_unit_price,
    ROUND(STDDEV(unit_price),2)  AS unit_price_stddev
FROM clean_shipment_pricing
WHERE line_item_quantity IS NOT NULL AND unit_price IS NOT NULL
GROUP BY quantity_tier
ORDER BY quantity_tier;

-- Correlation coefficient : quantity vs unit price
SELECT
    ROUND(CORR(line_item_quantity, unit_price)::NUMERIC, 3) AS quantity_price_correlation
FROM clean_shipment_pricing
WHERE line_item_quantity IS NOT NULL AND unit_price IS NOT NULL;


-- SELECT * FROM vw_quantity_vs_price;
-- SELECT * FROM vw_freight_efficiency_by_mode;
-- SELECT * FROM vw_lead_time_summary;
-- SELECT * FROM vw_monthly_trend;
-- SELECT * FROM vw_otd_by_country;
--SELECT * FROM vw_otd_by_shipment_mode;
--SELECT country ,product_group, SUM(total_spend) as total_spend FROM vw_spend_by_product_country group by country,product_group order by total_spend DESc;
--SELECT product_group ,SUM(total_spend) as total_spend FROM vw_spend_by_product_country group by product_group order by total_spend DESc;
 --SELECT * FROM vw_vendor_scorecard;
 --SELECT vendor,CoUNT(late_shipments)  FROM vw_late_shipment_drivers group by vendor ORder by CoUNT(late_shipments) DESc 

