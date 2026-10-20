-- Create  Database structure 
-- Data Load from csv file 

DROP TABLE IF EXISTS raw_shipment_pricing;

CREATE TABLE raw_shipment_pricing (
    id                          INTEGER,
    project_code                TEXT,
    pq_number                   TEXT,
    po_so_number                TEXT,
    asn_dn_number                TEXT,
    country                      TEXT,
    managed_by                   TEXT,
    fulfill_via                  TEXT,
    vendor_inco_term             TEXT,
    shipment_mode                TEXT,
    pq_first_sent_to_client_date TEXT,   -- kept as TEXT: raw dates can be malformed
    po_sent_to_vendor_date       TEXT,
    scheduled_delivery_date      TEXT,
    delivered_to_client_date     TEXT,
    delivery_recorded_date       TEXT,
    product_group                TEXT,
    sub_classification           TEXT,
    vendor                       TEXT,
    item_description              TEXT,
    molecule_test_type           TEXT,
    brand                        TEXT,
    dosage                       TEXT,
    dosage_form                  TEXT,
    unit_of_measure_per_pack     TEXT,
    line_item_quantity           TEXT,   -- kept as TEXT: contains bad values (-1, etc.)
    line_item_value              TEXT,
    pack_price                   TEXT,
    unit_price                   TEXT,
    manufacturing_site           TEXT,
    first_line_designation       TEXT,
    weight_kilograms             TEXT,   -- kept as TEXT: contains "Weight Captured Separately"
    freight_cost_usd             TEXT,   -- kept as TEXT: contains "Freight Included in Commodity Cost"
    line_item_insurance_usd      TEXT
);

-- Loading the CSV 
--
COPY raw_shipment_pricing FROM 'data/raw_shipment_pricing_data.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');


-- Quick sanity check after load
SELECT COUNT(*) AS row_count FROM raw_shipment_pricing;
SELECT * FROM raw_shipment_pricing LIMIT 5;
