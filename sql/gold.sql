-- dim_community

CREATE OR REPLACE TABLE dim_community AS
SELECT
    ROW_NUMBER() OVER (ORDER BY community_id) AS community_key,
    community_id
FROM (
    SELECT DISTINCT community_id FROM silver_adp_shifts
    UNION
    SELECT DISTINCT community_id FROM silver_gbp_reviews
    UNION
    SELECT DISTINCT community_id FROM silver_hubspot_leads
    UNION
    SELECT DISTINCT community_id FROM silver_pcc_residents
    UNION
    SELECT DISTINCT community_id FROM silver_pcc_incidents
    UNION
    SELECT DISTINCT community_id FROM silver_yardi_units
    UNION
    SELECT DISTINCT community_id FROM silver_yardi_leases
);




-- DIM_RESIDENT (Current Resident Dimension)
-- One row per resident (latest record)


CREATE OR REPLACE TABLE dim_resident AS

SELECT
    ROW_NUMBER() OVER (ORDER BY r.resident_id) AS resident_key,

    r.resident_id,

    c.community_key,

    r.first_name,
    r.last_name,
    r.gender,
    r.dob,
    r.admit_date,
    r.discharge_date,
    r.care_level,
    r.acuity_score,
    r.mobility_status

FROM silver_pcc_residents r

LEFT JOIN dim_community c
ON r.community_id = c.community_id;

-- DIM_RESIDENT_SCD (Slowly Changing Dimension Type 2)
-- Tracks historical care level changes


    CREATE OR REPLACE TABLE dim_resident_scd AS

    WITH history AS (

        SELECT
            resident_id,
            previous_level,
            new_level,
            change_date
        FROM silver_pcc_care_history

    ),

    scd AS (

        SELECT

            resident_id,

            new_level AS care_level,

            change_date AS effective_start_date,

            COALESCE(

                LEAD(change_date) OVER
                (
                    PARTITION BY resident_id
                    ORDER BY change_date
                ) - INTERVAL 1 DAY,

                DATE '9999-12-31'

            ) AS effective_end_date,

            CASE

                WHEN LEAD(change_date) OVER
                (
                    PARTITION BY resident_id
                    ORDER BY change_date
                ) IS NULL

                THEN TRUE

                ELSE FALSE

            END AS current_flag

        FROM history

    )

    SELECT

    ROW_NUMBER() OVER(
    ORDER BY resident_id,effective_start_date
    ) AS resident_history_key,

    *

    FROM scd;
    -- 3. dim_date


    CREATE OR REPLACE TABLE dim_date AS

    SELECT DISTINCT

    date_key,

    YEAR(date_key) AS year,

    QUARTER(date_key) AS quarter,

    MONTH(date_key) AS month,

    MONTHNAME(date_key) AS month_name,

    DAY(date_key) AS day,

    DAYNAME(date_key) AS weekday,

    WEEK(date_key) AS week_number,

    CASE
    WHEN DAYOFWEEK(date_key) IN (1,7)
    THEN TRUE
    ELSE FALSE
    END AS is_weekend

    FROM (

    SELECT shift_date AS date_key FROM silver_adp_shifts

    UNION

    SELECT review_date FROM silver_gbp_reviews

    UNION

    SELECT created_date FROM silver_hubspot_leads

    UNION

    SELECT incident_date FROM silver_pcc_incidents

    UNION

    SELECT snapshot_date FROM silver_yardi_units

    UNION

    SELECT move_in_date FROM silver_yardi_leases

    ) d

    WHERE date_key IS NOT NULL;


-- dim employee
CREATE OR REPLACE TABLE dim_employee AS
SELECT
    ROW_NUMBER() OVER (ORDER BY employee_id) AS employee_key,
    employee_id,
    role
FROM (
    SELECT DISTINCT employee_id, role
    FROM silver_adp_shifts
);






-- Fact Tables
-- fact_labor
CREATE OR REPLACE TABLE fact_labor AS

SELECT

ROW_NUMBER() OVER() AS labor_key,

d.date_key,

c.community_key,

e.employee_key,

s.hours_worked,

CAST(s.hourly_rate AS DOUBLE) AS hourly_rate,

hours_worked * hourly_rate AS labor_cost

FROM silver_adp_shifts s

LEFT JOIN dim_community c
ON s.community_id=c.community_id

LEFT JOIN dim_employee e
ON s.employee_id=e.employee_id

LEFT JOIN dim_date d
ON s.shift_date=d.date_key;



-- fact_reviews
CREATE OR REPLACE TABLE fact_reviews AS

SELECT
    ROW_NUMBER() OVER() AS review_key,
    d.date_key,
    c.community_key,
    review_id,
    rating,
    CASE
        WHEN response_text IS NULL
             OR TRIM(response_text) = ''
        THEN FALSE
        ELSE TRUE
    END AS responded_flag
FROM silver_gbp_reviews r

LEFT JOIN dim_community c
    ON r.community_id = c.community_id

LEFT JOIN dim_date d
    ON r.review_date = d.date_key;

-- fact_leads
CREATE OR REPLACE TABLE fact_leads AS

SELECT

ROW_NUMBER() OVER() AS lead_key,

d.date_key,

c.community_key,

lead_id,

lead_source,

status,

CASE

WHEN move_in_date IS NULL

THEN 0

ELSE 1

END AS converted_flag,

CASE

WHEN LOWER(status)='lost'

THEN 1

ELSE 0

END AS lost_flag

FROM silver_hubspot_leads h

LEFT JOIN dim_community c

ON h.community_id=c.community_id

LEFT JOIN dim_date d

ON h.created_date=d.date_key;

-- fact_revenue
CREATE OR REPLACE TABLE fact_revenue AS

SELECT

ROW_NUMBER() OVER() AS revenue_key,

d.date_key,

c.community_key,

r.resident_key,

lease_id,

monthly_rate,

DATEDIFF(
'day',
move_in_date,
COALESCE(move_out_date,CURRENT_DATE)
) AS lease_duration_days

FROM silver_yardi_leases l

LEFT JOIN dim_resident r

ON l.resident_id=r.resident_id

LEFT JOIN dim_community c

ON l.community_id=c.community_id

LEFT JOIN dim_date d

ON l.move_in_date=d.date_key;

-- fact_occupancy
CREATE OR REPLACE TABLE fact_occupancy AS

SELECT

ROW_NUMBER() OVER() AS occupancy_key,

d.date_key,

c.community_key,

unit_id,

unit_type,

monthly_rent,

CASE
WHEN monthly_rent>0
THEN 1
ELSE 0
END AS occupied_flag

FROM silver_yardi_units u

LEFT JOIN dim_community c

ON u.community_id=c.community_id

LEFT JOIN dim_date d

ON u.snapshot_date=d.date_key;



-- FACT_INCIDENT
CREATE OR REPLACE TABLE fact_incidents AS

SELECT

ROW_NUMBER() OVER() AS incident_key,

d.date_key,

c.community_key,

r.resident_key,

incident_id,

incident_type,

severity

FROM silver_pcc_incidents i

LEFT JOIN dim_resident r

ON i.resident_id=r.resident_id

LEFT JOIN dim_community c

ON i.community_id=c.community_id

LEFT JOIN dim_date d

ON i.incident_date=d.date_key;




SELECT COUNT(*) FROM dim_community;

SELECT COUNT(*) FROM dim_resident;

SELECT COUNT(*) FROM dim_date;

SELECT COUNT(*) FROM fact_labor;

SELECT COUNT(*) FROM fact_reviews;

SELECT COUNT(*) FROM fact_leads;

SELECT COUNT(*) FROM fact_incidents;

SELECT COUNT(*) FROM fact_revenue;

SELECT COUNT(*) FROM fact_occupancy;


SELECT COUNT(*) FROM dim_resident_scd;




CREATE OR REPLACE TABLE dim_community_region AS
SELECT *
FROM (
    VALUES
        ('C001','OR','Pacific Northwest'),
        ('C002','OR','Pacific Northwest'),
        ('C003','OR','Pacific Northwest'),
        ('C004','OR','Pacific Northwest'),

        ('C005','AZ','Southwest'),
        ('C006','AZ','Southwest'),
        ('C007','AZ','Southwest'),
        ('C008','AZ','Southwest'),

        ('C009','TX','South'),
        ('C010','TX','South'),
        ('C011','TX','South'),
        ('C012','TX','South'),
        ('C013','TX','South'),
        ('C014','TX','South')
) AS t(community_id,state,region);