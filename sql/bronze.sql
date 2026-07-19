
-- BRONZE LAYER VALIDATION
-- Raw data is loaded incrementally by run_pipeline.py


PRAGMA threads=4;

SELECT 'bronze_adp_shifts' AS table_name, COUNT(*) AS row_count
FROM bronze_adp_shifts

UNION ALL

SELECT 'bronze_gbp_reviews', COUNT(*)
FROM bronze_gbp_reviews

UNION ALL

SELECT 'bronze_hubspot_leads', COUNT(*)
FROM bronze_hubspot_leads

UNION ALL

SELECT 'bronze_pcc_care_history', COUNT(*)
FROM bronze_pcc_care_history

UNION ALL

SELECT 'bronze_pcc_incidents', COUNT(*)
FROM bronze_pcc_incidents

UNION ALL

SELECT 'bronze_pcc_residents', COUNT(*)
FROM bronze_pcc_residents

UNION ALL

SELECT 'bronze_yardi_leases', COUNT(*)
FROM bronze_yardi_leases

UNION ALL

SELECT 'bronze_yardi_units', COUNT(*)
FROM bronze_yardi_units

ORDER BY table_name;