-- Convert messy data into clean format 

DROP TABLE IF EXISTS clean_shipment_pricing;

CREATE TABLE clean_shipment_pricing AS
WITH deduped AS (
    -- DISTINCT VALUE 
    SELECT DISTINCT ON (
        project_code, pq_number, po_so_number, item_description, line_item_value
    ) *
    FROM raw_shipment_pricing
    ORDER BY project_code, pq_number, po_so_number, item_description,
             line_item_value, id
),

standardized AS (
    SELECT
        id,
        NULLIF(TRIM(project_code), '')                         AS project_code,
        NULLIF(TRIM(pq_number), '')                             AS pq_number,
        NULLIF(TRIM(po_so_number), '')                          AS po_so_number,
        NULLIF(TRIM(asn_dn_number), '')                         AS asn_dn_number,

        -- Standization : Whitespaces, Case Fix 
        INITCAP(TRIM(country))                                  AS country,
        NULLIF(TRIM(managed_by), '')                            AS managed_by,
        NULLIF(TRIM(fulfill_via), '')                           AS fulfill_via,
        NULLIF(UPPER(TRIM(vendor_inco_term)), '')               AS vendor_inco_term,
        NULLIF(TRIM(shipment_mode), '')                         AS shipment_mode,

        -- Data Type Fix ,  Null Value Fix 
        NULLIF(TRIM(pq_first_sent_to_client_date), '')::DATE    AS pq_first_sent_to_client_date, --TRY_CAST(NULLIF(TRIM(line_item_value), '') AS NUMERIC(18, 2))
        NULLIF(TRIM(po_sent_to_vendor_date), '')::DATE          AS po_sent_to_vendor_date,
        NULLIF(TRIM(scheduled_delivery_date), '')::DATE         AS scheduled_delivery_date,
        NULLIF(TRIM(delivered_to_client_date), '')::DATE        AS delivered_to_client_date,
        NULLIF(TRIM(delivery_recorded_date), '')::DATE          AS delivery_recorded_date,

        NULLIF(TRIM(product_group), '')                         AS product_group,
        NULLIF(TRIM(sub_classification), '')                    AS sub_classification,
        INITCAP(TRIM(vendor))                                   AS vendor,  -- UPPER(LEFT(TRIM(vendor),1)) + LOWER(SUBSTRING(TRIM(vendor),2,LEN(vendor)))
        NULLIF(TRIM(item_description), '')                      AS item_description,
        NULLIF(TRIM(molecule_test_type), '')                    AS molecule_test_type,
        NULLIF(TRIM(brand), '')                                 AS brand,
        NULLIF(TRIM(dosage), '')                                AS dosage,
        NULLIF(TRIM(dosage_form), '')                            AS dosage_form,
        NULLIF(TRIM(unit_of_measure_per_pack), '')::INT          AS unit_of_measure_per_pack,

        -- Data Type Fix ,  Negative/Bad Data Fix
        CASE
            WHEN NULLIF(TRIM(line_item_quantity), '') ~ '^[0-9]+$'
                 AND line_item_quantity::NUMERIC > 0
            THEN line_item_quantity::NUMERIC
            ELSE NULL
        END                                                      AS line_item_quantity,

        NULLIF(TRIM(line_item_value), '')::NUMERIC                AS line_item_value,
        NULLIF(TRIM(pack_price), '')::NUMERIC                     AS pack_price,

        -- Negative/Bad Data Fix 
        CASE
            WHEN NULLIF(TRIM(unit_price), '')::NUMERIC = 0 THEN NULL
            ELSE NULLIF(TRIM(unit_price), '')::NUMERIC
        END                                                        AS unit_price,

        NULLIF(TRIM(manufacturing_site), '')                       AS manufacturing_site,
        NULLIF(TRIM(first_line_designation), '')                   AS first_line_designation,

        -- Bad Data Fix 
        CASE
            WHEN weight_kilograms ~ '^[0-9.]+$' THEN weight_kilograms::NUMERIC
            ELSE NULL
        END                                                        AS weight_kilograms,

        -- Bad Data Fix
        CASE
            WHEN freight_cost_usd ~ '^[0-9.]+$' THEN freight_cost_usd::NUMERIC
            ELSE NULL
        END 														AS freight_cost_usd,

        NULLIF(TRIM(line_item_insurance_usd), '')::NUMERIC          AS line_item_insurance_usd

    FROM deduped
)

SELECT
    *,
    -- Derived KPI-support columns 

    -- Planned lead time
    (scheduled_delivery_date - po_sent_to_vendor_date)            AS planned_lead_time_days,

    -- Actual lead time
    (delivered_to_client_date - po_sent_to_vendor_date)           AS actual_lead_time_days,

    -- On-time delivery flag
    CASE
        WHEN delivered_to_client_date IS NULL OR scheduled_delivery_date IS NULL THEN NULL
        WHEN delivered_to_client_date <= scheduled_delivery_date THEN 'YES'
        ELSE 'NO'
    END                                                             AS is_on_time,

    -- Freight cost as a % of shipment value 
    CASE
        WHEN line_item_value IS NULL OR line_item_value = 0 OR freight_cost_usd IS NULL THEN NULL
        ELSE ROUND((freight_cost_usd / line_item_value) * 100, 2)
    END                                                             AS freight_pct_of_value,

    -- Cost per kilogram shipped 
    CASE
        WHEN weight_kilograms IS NULL OR weight_kilograms = 0 OR freight_cost_usd IS NULL THEN NULL
        ELSE ROUND(freight_cost_usd / weight_kilograms, 2)
    END                                                             AS freight_cost_per_kg

FROM standardized;

-- Add Primary Key To Clean Data Table
 ALTER TABLE clean_shipment_pricing ADD PRIMARY KEY (id);


-- Data Quality Check 

SELECT 'raw_row_count' AS metric, COUNT(*) AS value FROM raw_shipment_pricing
UNION ALL
SELECT 'clean_row_count', COUNT(*) FROM clean_shipment_pricing
UNION ALL
SELECT 'null_weight_rows', COUNT(*) FROM clean_shipment_pricing WHERE weight_kilograms IS NULL
UNION ALL
SELECT 'nullpct_weights', ROUND(SUM(CASE WHEN weight_kilograms IS NULL THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) FROM clean_shipment_pricing
UNION ALL
SELECT 'null_freight_rows', COUNT(*) FROM clean_shipment_pricing WHERE freight_cost_usd IS NULL
UNION ALL
SELECT 'nullpct_freight', ROUND(SUM(CASE WHEN freight_cost_usd IS NULL THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) FROM clean_shipment_pricing
UNION ALL
SELECT 'null_price_rows', COUNT(*) FROM clean_shipment_pricing WHERE unit_price IS NULL
UNION ALL
SELECT 'nullpct_price', ROUND(SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) FROM clean_shipment_pricing
UNION ALL
SELECT 'null_qty_rows', COUNT(*) FROM clean_shipment_pricing WHERE line_item_quantity IS NULL
UNION ALL
SELECT 'nullpct_qty', ROUND(SUM(CASE WHEN line_item_quantity IS NULL THEN 1 ELSE 0 END)::NUMERIC / COUNT(*) * 100, 2) FROM clean_shipment_pricing
