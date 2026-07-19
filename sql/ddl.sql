
-- STAR SCHEMA DESIGN
-- Gold Layer Logical Data Model 



-- DIM_COMMUNITY


CREATE TABLE dim_community (
    community_key INTEGER PRIMARY KEY,
    community_id VARCHAR NOT NULL
);

COMMENT ON TABLE dim_community IS
'Community dimension shared across all fact tables.';


-- DIM_RESIDENT


CREATE TABLE dim_resident (
    resident_key INTEGER PRIMARY KEY,
    resident_id VARCHAR NOT NULL,
    first_name VARCHAR,
    last_name VARCHAR,
    gender VARCHAR,
    dob DATE,
    admit_date DATE,
    discharge_date DATE,
    care_level VARCHAR,
    acuity_score INTEGER,
    mobility_status VARCHAR
);

COMMENT ON TABLE dim_resident IS
'Current resident dimension.';

-- DIM_RESIDENT_SCD

CREATE TABLE dim_resident_scd (
    resident_history_key INTEGER PRIMARY KEY,
    resident_id VARCHAR,
    care_level VARCHAR,
    effective_start_date DATE,
    effective_end_date DATE,
    current_flag BOOLEAN
);

COMMENT ON TABLE dim_resident_scd IS
'Slowly Changing Dimension Type 2 for resident care levels.';

-- DIM_DATE

CREATE TABLE dim_date (
    date_key DATE PRIMARY KEY,
    year INTEGER,
    quarter INTEGER,
    month INTEGER,
    month_name VARCHAR,
    day INTEGER,
    weekday VARCHAR,
    week_number INTEGER,
    is_weekend BOOLEAN
);

-- DIM_EMPLOYEE

CREATE TABLE dim_employee (
    employee_key INTEGER PRIMARY KEY,
    employee_id VARCHAR,
    role VARCHAR
);

-- FACT_LABOR

CREATE TABLE fact_labor (
    labor_key INTEGER PRIMARY KEY,

    date_key DATE,
    community_key INTEGER,
    employee_key INTEGER,

    hours_worked DOUBLE,
    hourly_rate DOUBLE,
    labor_cost DOUBLE,

    FOREIGN KEY(date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY(community_key)
        REFERENCES dim_community(community_key),

    FOREIGN KEY(employee_key)
        REFERENCES dim_employee(employee_key)
);

-- FACT_OCCUPANCY

CREATE TABLE fact_occupancy (

    occupancy_key INTEGER PRIMARY KEY,

    date_key DATE,
    community_key INTEGER,

    unit_id VARCHAR,
    unit_type VARCHAR,

    monthly_rent DOUBLE,
    occupied_flag INTEGER,

    FOREIGN KEY(date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY(community_key)
        REFERENCES dim_community(community_key)
);

-- FACT_REVENUE

CREATE TABLE fact_revenue (

    revenue_key INTEGER PRIMARY KEY,

    date_key DATE,
    community_key INTEGER,
    resident_key INTEGER,

    lease_id VARCHAR,
    monthly_rate DOUBLE,
    lease_duration_days INTEGER,

    FOREIGN KEY(date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY(community_key)
        REFERENCES dim_community(community_key),

    FOREIGN KEY(resident_key)
        REFERENCES dim_resident(resident_key)
);


-- FACT_INCIDENTS


CREATE TABLE fact_incidents (

    incident_key INTEGER PRIMARY KEY,

    date_key DATE,
    community_key INTEGER,
    resident_key INTEGER,

    incident_id VARCHAR,
    incident_type VARCHAR,
    severity INTEGER,

    FOREIGN KEY(date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY(community_key)
        REFERENCES dim_community(community_key),

    FOREIGN KEY(resident_key)
        REFERENCES dim_resident(resident_key)
);


-- FACT_REVIEWS


CREATE TABLE fact_reviews (

    review_key INTEGER PRIMARY KEY,

    date_key DATE,
    community_key INTEGER,

    review_id VARCHAR,
    rating INTEGER,
    responded_flag BOOLEAN,

    FOREIGN KEY(date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY(community_key)
        REFERENCES dim_community(community_key)
);


-- FACT_LEADS


CREATE TABLE fact_leads (

    lead_key INTEGER PRIMARY KEY,

    date_key DATE,
    community_key INTEGER,

    lead_id VARCHAR,
    lead_source VARCHAR,
    status VARCHAR,

    converted_flag INTEGER,
    lost_flag INTEGER,

    FOREIGN KEY(date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY(community_key)
        REFERENCES dim_community(community_key)
);