
-- VIEW 1 : Monthly Occupancy Rate by Community


CREATE OR REPLACE VIEW vw_monthly_occupancy_rate AS

SELECT

    d.year,
    d.month,
    d.month_name,

    c.community_id,

    COUNT(*) AS total_units,

    SUM(f.occupied_flag) AS occupied_units,

    ROUND(
        100.0 * SUM(f.occupied_flag) / COUNT(*),
        2
    ) AS occupancy_rate_pct

FROM fact_occupancy f

JOIN dim_date d
    ON f.date_key = d.date_key

JOIN dim_community c
    ON f.community_key = c.community_key

GROUP BY
    d.year,
    d.month,
    d.month_name,
    c.community_id;


-- VIEW 2 : Average Length of Stay by Care Level
-- Residents discharged in the last 12 months


CREATE OR REPLACE VIEW vw_avg_length_of_stay AS

WITH latest_dataset_date AS (

    SELECT MAX(move_out_date) AS max_move_out_date
    FROM silver_yardi_leases

)

SELECT

    r.care_level,

    COUNT(*) AS discharged_residents,

    ROUND(

        AVG(

            DATEDIFF(
                'day',
                l.move_in_date,
                l.move_out_date
            )

        ),

        2

    ) AS avg_length_of_stay_days

FROM silver_yardi_leases l

JOIN dim_resident r
ON l.resident_id = r.resident_id

CROSS JOIN latest_dataset_date x

WHERE

    l.move_out_date IS NOT NULL

    AND l.move_out_date >= x.max_move_out_date - INTERVAL 12 MONTH

GROUP BY

    r.care_level;




    
-- View 3 : Top 3 Move-out Reasons by Community
-- Trailing 12 Months

CREATE OR REPLACE VIEW vw_top3_moveout_reasons AS

WITH latest_dataset_date AS (

    SELECT
        MAX(move_out_date) AS max_move_out_date
    FROM silver_yardi_leases

),
move_outs AS (

    SELECT

        l.community_id,

        strftime(l.move_out_date, '%Y-%m') AS period,

        COALESCE(TRIM(l.move_out_reason), 'Unknown') AS move_out_reason

    FROM silver_yardi_leases l

    CROSS JOIN latest_dataset_date d

    WHERE l.move_out_date IS NOT NULL

      AND l.move_out_date >= d.max_move_out_date - INTERVAL 12 MONTH

),
reason_counts AS (
    SELECT
        community_id,
        period,
        move_out_reason,
        COUNT(*) AS move_out_count
    FROM move_outs
    GROUP BY
        community_id,
        period,
        move_out_reason
),
community_totals AS (
    SELECT
        community_id,
        period,
        SUM(move_out_count) AS total_move_outs
    FROM reason_counts
    GROUP BY
        community_id,
        period
),

ranked AS (

    SELECT

        rc.community_id,

        rc.period,

        rc.move_out_reason,

        rc.move_out_count,

        ct.total_move_outs,

        ROUND(
            100.0 * rc.move_out_count / ct.total_move_outs,
            2
        ) AS pct_of_total_moveouts,

        ROW_NUMBER() OVER (

            PARTITION BY
                rc.community_id,
                rc.period

            ORDER BY
                rc.move_out_count DESC,
                rc.move_out_reason

        ) AS reason_rank

    FROM reason_counts rc

    INNER JOIN community_totals ct

        ON rc.community_id = ct.community_id
       AND rc.period = ct.period

)

SELECT

    dc.community_id,

    r.period,

    r.move_out_reason,

    r.move_out_count,

    r.total_move_outs,

    r.pct_of_total_moveouts,

    r.reason_rank

FROM ranked r

INNER JOIN dim_community dc

    ON r.community_id = dc.community_id

WHERE r.reason_rank <= 3

ORDER BY

    dc.community_id,
    r.period,
    r.reason_rank;


    
-- View 4 : Labor Cost per Resident-Day


CREATE OR REPLACE VIEW vw_labor_cost_per_resident_day AS

WITH labor_monthly AS (

    SELECT

        dc.community_id,

        dd.year,

        dd.month,

        SUM(fl.labor_cost) AS total_labor_cost

    FROM fact_labor fl

    JOIN dim_date dd
        ON fl.date_key = dd.date_key

    JOIN dim_community dc
        ON fl.community_key = dc.community_key

    GROUP BY
        dc.community_id,
        dd.year,
        dd.month

),

occupancy_monthly AS (

    SELECT

        dc.community_id,

        dd.year,

        dd.month,

        SUM(fo.occupied_flag) AS resident_days

    FROM fact_occupancy fo

    JOIN dim_date dd
        ON fo.date_key = dd.date_key

    JOIN dim_community dc
        ON fo.community_key = dc.community_key

    GROUP BY
        dc.community_id,
        dd.year,
        dd.month

)

SELECT

    l.community_id,

    l.year,

    l.month,

    l.total_labor_cost,

    o.resident_days,

    ROUND(
        l.total_labor_cost /
        NULLIF(o.resident_days,0),
        2
    ) AS labor_cost_per_resident_day

FROM labor_monthly l

JOIN occupancy_monthly o

ON l.community_id = o.community_id
AND l.year = o.year
AND l.month = o.month

ORDER BY

    l.community_id,
    l.year,
    l.month;





-- View 5 : Incident Rate per 100 Resident-Days


CREATE OR REPLACE VIEW vw_incident_rate_per_100_resident_days AS

WITH incident_monthly AS (

    SELECT

        dc.community_id,

        dd.year,

        dd.month,

        COUNT(*) AS total_incidents

    FROM fact_incidents fi

    JOIN dim_date dd
        ON fi.date_key = dd.date_key

    JOIN dim_community dc
        ON fi.community_key = dc.community_key

    GROUP BY
        dc.community_id,
        dd.year,
        dd.month

),

occupancy_monthly AS (

    SELECT

        dc.community_id,

        dd.year,

        dd.month,

        SUM(fo.occupied_flag) AS resident_days

    FROM fact_occupancy fo

    JOIN dim_date dd
        ON fo.date_key = dd.date_key

    JOIN dim_community dc
        ON fo.community_key = dc.community_key

    GROUP BY
        dc.community_id,
        dd.year,
        dd.month

)

SELECT

    i.community_id,

    i.year,

    i.month,

    i.total_incidents,

    o.resident_days,

    ROUND(
        (100.0 * i.total_incidents) /
        NULLIF(o.resident_days, 0),
        2
    ) AS incident_rate_per_100_resident_days

FROM incident_monthly i

JOIN occupancy_monthly o

ON i.community_id = o.community_id
AND i.year = o.year
AND i.month = o.month

ORDER BY

    i.community_id,
    i.year,
    i.month;






-- View 6 : Residents with Care Level Changes Within 90 Days
-- (SCD Type 2 Analysis)


CREATE OR REPLACE VIEW vw_resident_care_level_changes_90_days AS

WITH resident_history AS (

    SELECT

        s.resident_id,

        c.community_id,

        s.care_level,

        s.effective_start_date,

        s.effective_end_date,

        s.current_flag,

        LAG(s.care_level) OVER (
            PARTITION BY s.resident_id
            ORDER BY s.effective_start_date
        ) AS previous_care_level,

        LAG(s.effective_start_date) OVER (
            PARTITION BY s.resident_id
            ORDER BY s.effective_start_date
        ) AS previous_change_date

    FROM dim_resident_scd s

    LEFT JOIN dim_resident r
        ON s.resident_id = r.resident_id

    LEFT JOIN dim_community c
        ON r.community_key = c.community_key

)

SELECT

    community_id,

    resident_id,

    previous_care_level,

    care_level AS current_care_level,

    previous_change_date,

    effective_start_date AS current_change_date,

    DATE_DIFF(
        'day',
        previous_change_date,
        effective_start_date
    ) AS days_between_changes,

    current_flag

FROM resident_history

WHERE previous_care_level IS NOT NULL
  AND previous_care_level <> care_level
  AND DATE_DIFF(
        'day',
        previous_change_date,
        effective_start_date
      ) <= 90

ORDER BY
    community_id,
    resident_id,
    current_change_date;