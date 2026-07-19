
-- SILVER LAYER
-- Purpose: Clean, standardize, deduplicate and typecast Bronze tables


PRAGMA threads=4;


-- ADP SHIFTS


CREATE OR REPLACE TABLE silver_adp_shifts AS
SELECT DISTINCT
    TRIM(shift_id) AS shift_id,
    TRIM(community_id) AS community_id,
    TRIM(employee_id) AS employee_id,
    UPPER(TRIM(role)) AS role,
    TRY_CAST(shift_date AS DATE) AS shift_date,
    CAST(hours_worked AS DOUBLE) AS hours_worked,

    CAST(
        json_extract_string(
            replace(replace(hourly_rate, '''', '"'), 'None', 'null')::JSON,
            '$.' ||
            CASE
                WHEN UPPER(TRIM(role)) = 'MED TECH' THEN 'Med Tech'
                WHEN UPPER(TRIM(role)) = 'MAINTENANCE' THEN 'Maintenance'
                WHEN UPPER(TRIM(role)) = 'CAREGIVER' THEN 'Caregiver'
                WHEN UPPER(TRIM(role)) = 'DINING' THEN 'Dining'
                WHEN UPPER(TRIM(role)) = 'ADMIN' THEN 'Admin'
                WHEN UPPER(TRIM(role)) = 'RN' THEN 'RN'
                WHEN UPPER(TRIM(role)) = 'LPN' THEN 'LPN'
            END
        ) AS DOUBLE
    ) AS hourly_rate,

    filename,
    ingestion_timestamp

FROM bronze_adp_shifts
WHERE shift_id IS NOT NULL;


-- GBP REVIEWS


CREATE OR REPLACE TABLE silver_gbp_reviews AS
SELECT DISTINCT
    TRIM(review_id) AS review_id,
    TRIM(community_id) AS community_id,
    TRY_CAST(review_date AS DATE) AS review_date,
    CAST(rating AS INTEGER) AS rating,
    TRIM(review_text) AS review_text,
    TRIM(response_text) AS response_text,
    TRY_CAST(responded_at AS DATE) AS responded_at,
    CASE
        WHEN responded_at IS NULL THEN 0
        ELSE 1
    END AS responded_flag,
    filename,
    ingestion_timestamp
FROM bronze_gbp_reviews
WHERE review_id IS NOT NULL;


-- HUBSPOT LEADS


CREATE OR REPLACE TABLE silver_hubspot_leads AS
SELECT DISTINCT
    TRIM(lead_id) AS lead_id,
    TRIM(community_id) AS community_id,
    UPPER(TRIM(lead_source)) AS lead_source,
    TRY_CAST(created_date AS DATE) AS created_date,
    TRY_CAST(tour_date AS DATE) AS tour_date,
    TRY_CAST(deposit_date AS DATE) AS deposit_date,
    TRY_CAST(move_in_date AS DATE) AS move_in_date,
    UPPER(TRIM(status)) AS status,
    TRIM(lost_reason) AS lost_reason,
    filename,
    ingestion_timestamp
FROM bronze_hubspot_leads
WHERE lead_id IS NOT NULL;


-- PCC CARE HISTORY


CREATE OR REPLACE TABLE silver_pcc_care_history AS
SELECT DISTINCT
    TRIM(resident_id) AS resident_id,
    TRY_CAST(change_date AS DATE) AS change_date,
    (TRIM(previous_level)) AS previous_level,
    (TRIM(new_level)) AS new_level,
    TRIM(reason) AS reason,
    filename,
    ingestion_timestamp
FROM bronze_pcc_care_history
WHERE resident_id IS NOT NULL;


-- PCC INCIDENTS


CREATE OR REPLACE TABLE silver_pcc_incidents AS
SELECT DISTINCT
    TRIM(incident_id) AS incident_id,
    TRIM(resident_id) AS resident_id,
    TRIM(community_id) AS community_id,
    TRY_CAST(incident_date AS DATE) AS incident_date,
    (TRIM(incident_type)) AS incident_type,
    CAST(severity AS INTEGER) AS severity,
    TRIM(reported_by) AS reported_by,
    filename,
    ingestion_timestamp
FROM bronze_pcc_incidents
WHERE incident_id IS NOT NULL;


-- PCC RESIDENTS


CREATE OR REPLACE TABLE silver_pcc_residents AS

WITH ranked AS (

    SELECT

        TRIM(resident_id) AS resident_id,
        TRIM(community_id) AS community_id,
        TRIM(first_name) AS first_name,
        TRIM(last_name) AS last_name,
        TRY_CAST(dob AS DATE) AS dob,
        UPPER(TRIM(gender)) AS gender,
        TRY_CAST(admit_date AS DATE) AS admit_date,
        TRY_CAST(discharge_date AS DATE) AS discharge_date,

        CASE
            WHEN UPPER(TRIM(care_level)) IN (
                'IL',
                'INDEPENDENT',
                'INDEPENDENT LIVING'
            )
            THEN 'Independent Living'

            WHEN UPPER(TRIM(care_level)) IN (
                'AL',
                'ASSISTED',
                'ASSISTED LIVING'
            )
            THEN 'Assisted Living'

            WHEN UPPER(TRIM(care_level)) IN (
                'MC',
                'MEMORY',
                'MEMORY CARE'
            )
            THEN 'Memory Care'

            ELSE TRIM(care_level)
        END AS care_level,

        CAST(acuity_score AS INTEGER) AS acuity_score,
        mobility_status,
        filename,
        ingestion_timestamp,

        ROW_NUMBER() OVER (
            PARTITION BY TRIM(resident_id)
            ORDER BY ingestion_timestamp DESC
        ) AS rn

    FROM bronze_pcc_residents

    WHERE resident_id IS NOT NULL

)

SELECT
    resident_id,
    community_id,
    first_name,
    last_name,
    dob,
    gender,
    admit_date,
    discharge_date,
    care_level,
    acuity_score,
    mobility_status,
    filename,
    ingestion_timestamp

FROM ranked

WHERE rn = 1;





-- YARDI LEASES


CREATE OR REPLACE TABLE silver_yardi_leases AS
SELECT DISTINCT
    TRIM(lease_id) AS lease_id,
    TRIM(resident_id) AS resident_id,
    TRIM(unit_id) AS unit_id,
    TRIM(community_id) AS community_id,
    TRY_CAST(move_in_date AS DATE) AS move_in_date,
    TRY_CAST(move_out_date AS DATE) AS move_out_date,
    TRIM(move_out_reason) AS move_out_reason,
    CAST(monthly_rate AS DOUBLE) AS monthly_rate,
    filename,
    ingestion_timestamp
FROM bronze_yardi_leases
WHERE lease_id IS NOT NULL;


-- YARDI UNITS


CREATE OR REPLACE TABLE silver_yardi_units AS
SELECT DISTINCT
    TRIM(unit_id) AS unit_id,
    TRIM(community_id) AS community_id,
    (TRIM(unit_type)) AS unit_type,
    CAST(monthly_rent AS DOUBLE) AS monthly_rent,
    TRY_CAST(snapshot_date AS DATE) AS snapshot_date,
    filename,
    ingestion_timestamp
FROM bronze_yardi_units
WHERE unit_id IS NOT NULL;


-- OPTIONAL VALIDATION


SELECT 'silver_adp_shifts' AS table_name, COUNT(*) FROM silver_adp_shifts
UNION ALL
SELECT 'silver_gbp_reviews', COUNT(*) FROM silver_gbp_reviews
UNION ALL
SELECT 'silver_hubspot_leads', COUNT(*) FROM silver_hubspot_leads
UNION ALL
SELECT 'silver_pcc_care_history', COUNT(*) FROM silver_pcc_care_history
UNION ALL
SELECT 'silver_pcc_incidents', COUNT(*) FROM silver_pcc_incidents
UNION ALL
SELECT 'silver_pcc_residents', COUNT(*) FROM silver_pcc_residents
UNION ALL
SELECT 'silver_yardi_leases', COUNT(*) FROM silver_yardi_leases
UNION ALL
SELECT 'silver_yardi_units', COUNT(*) FROM silver_yardi_units;




