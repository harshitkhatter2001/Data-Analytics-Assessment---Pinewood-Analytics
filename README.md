# Pinewood Senior Living Data Engineering and Analytics Platform

Skypoint Cloud Software Development Engineer Assessment

## Overview

Pinewood Senior Living runs 14 communities across Oregon, Arizona, and Texas: Independent Living,
Assisted Living, and Memory Care. Right now their COO gets a picture of the business once a week, built
by hand in Excel from five separate systems. This project replaces that with one pipeline and one
dashboard. Raw exports go in, a validated star schema and a secured API come out, and the COO's team
gets a Power BI report where each regional director only sees their own numbers.

```
raw CSVs > Python ingestion > Bronze / Silver / Gold (DuckDB)
        > validation > FastAPI service
        > Power BI report with Row Level Security
```

## Source systems

| Source | Data | Used for |

| PointClickCare | residents, care levels, incidents | census, care quality |
| Yardi | units, leases, rent roll | occupancy, revenue |
| ADP | shifts, labor cost | labor cost per resident day |
| Google Business Profile | reviews | review and reputation metrics |
| HubSpot | leads, tours, deposits | sales funnel |

## Architecture

Bronze, Silver, Gold on DuckDB.

**Bronze.** Raw ingestion, untouched. Adds an ingestion timestamp so every row is traceable back to its
source file. Nothing gets transformed here.

**Silver.** Cleaning and standardization. Deduped, typed, care levels normalized to one canonical set
(IL, Independent, Independent Living all become Independent Living), resident identity reconciled across
PCC and Yardi.

**Gold.** The star schema. Facts and dimensions, SCD Type 2 on resident care level so a move from
Assisted Living to Memory Care shows up as history, not an overwrite.

Gold feeds a validation layer, a FastAPI service, and the Power BI report.

## Tech stack

Python 3.10+, DuckDB, SQL, FastAPI, Power BI Desktop, DAX.

## Repo layout

```
/pipeline        ingestion and orchestration
/sql             bronze.sql, silver.sql, gold.sql, gold_views.sql
/api             FastAPI service
/powerbi         Pinewood_Executive_Dashboard.pbix
/validation      validation module and latest run reports
/communication   client emails
README.md
```

## Running it

```bash
git clone <repo-url>
cd pinewood-analytics
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt

# drop the raw CSVs into data/raw/, then:
python -m pipeline/run_pipeline

# start the API
uvicorn api.main:app --reload
# docs at http://127.0.0.1:8000/docs
```

Open `powerbi/Pinewood_Executive_Dashboard.pbix` in Power BI Desktop for the report.

## Data model

**Dimensions**

`dim_community`: the 14 communities.
`dim_community_region`: community to region mapping (OR = Pacific Northwest, AZ = Southwest,
TX = South), drives Regional Director security.
`dim_resident` and `dim_resident_scd`: resident master plus Type 2 history of care level changes
(`effective_start_date`, `effective_end_date`, `current_flag`).
`dim_employee`, `dim_date`.

**Facts**

`fact_occupancy`: occupancy at the unit/day grain.
`fact_revenue`: one row per lease or billing event.
`fact_labor`: one row per shift.
`fact_incidents`: one row per incident.
`fact_reviews`: one row per review.
`fact_leads`: one row per lead.

**Key measures**

1. Current occupancy percent -  (01_Occupied Units = COUNTROWS(fact_occupancy)), (01_Total Units = DISTINCTCOUNT(fact_occupancy[unit_id])),
 01_Current Occupancy % = DIVIDE([01_Occupied Units], [01_Total Units]) 

2. Year-over-year revenue growth percent - 02_Total Revenue = SUM(fact_revenue[monthly_rate]), 02_Revenue LY = CALCULATE([02_Total Revenue],SAMEPERIODLASTYEAR(dim_date[date_key])), 
02_YoY Revenue Growth % = 
DIVIDE(
    [02_Total Revenue] - [02_Revenue LY],
    [02_Revenue LY]
)

3. Average daily census for a selected date range - 03_Average Daily Census = 
AVERAGEX(
    VALUES(dim_date[date_key]),
    DISTINCTCOUNT(fact_revenue[resident_key])
)

4. Move-out rate percent for the trailing 90 days - 04_Resident Count = 
DISTINCTCOUNT(dim_resident[resident_id]),
04_Move Outs (90 Days) = 
CALCULATE(
    COUNTROWS(dim_resident),
    DATESINPERIOD(
        dim_date[date_key],
        MAX(dim_date[date_key]),
        -90,
        DAY
    ),
    NOT(ISBLANK(dim_resident[discharge_date]))
),
04_Move-out Rate % = 
DIVIDE(
    [04_Move Outs (90 Days)],
    [04_Resident Count]
)

5. Incident rate per 100 resident-days - 05_Incident Count = 
COUNTROWS(fact_incidents), 
05_Resident Days = 
DISTINCTCOUNT(fact_revenue[resident_key])
*
DISTINCTCOUNT(dim_date[date_key]),
05_Incident Rate per 100 Resident Days = 
DIVIDE(
    [05_Incident Count] * 100,
    [05_Resident Days]
)

6. At least one time-intelligence measure beyond YoY (MTD, rolling 90, prior period, your choice) 
06_Rolling 90 Day Revenue = 
CALCULATE(
    [02_Total Revenue],
    DATESINPERIOD(
        dim_date[date_key],
        MAX(dim_date[date_key]),
        -90,
        DAY
    )
)

7. At least one measure that uses CALCULATE with context transition - 
07_Community Revenue = 
SUMX(
    VALUES(dim_community[community_key]),
    CALCULATE(SUM(fact_revenue[monthly_rate]))
)

 ----- Why Context Transition Is Needed

In the Community Revenue measure, SUMX iterates VALUES(dim_community[community_key]), giving row context only. A bare SUM(fact_revenue[monthly_rate]) inside that loop would ignore this entirely, since SUM only listens to filter context, it would return the same total for every community.
Wrapping the SUM in CALCULATE triggers context transition, it converts the current row's community_key into an equivalent filter context, which then propagates through the relationship to fact_revenue. Only then does the SUM correctly total revenue for that one community. Without CALCULATE, the measure would silently return the grand total for every row, a bug that's easy to miss because the report still renders, just with the wrong numbers.


Two things I caught and fixed while building the model. The occupancy trend chart was originally
summing `occupancy_key`, a surrogate key with no business meaning, fixed by setting it to don't
summarize and using the actual occupancy measure instead. And the review rating KPI card was summing
ratings instead of averaging them, which rewards volume over quality, switched to `AVERAGE`.

## Power BI report

**Overview page.** Community, Month, Region, Year slicers. Six KPI cards for occupancy, revenue, labor
cost, incident rate, review rating, average daily census. Trends for occupancy, revenue, census, and
incidents. Revenue by region, lead source and lead status, labor cost by role, incident severity,
resident count by region.

**Revenue and Performance page.** Monthly rent, revenue and lease metrics by region and month, lease
duration buckets.

**Row Level Security.** Two roles: Regional Director sees their region only, Community Executive
Director sees their own community only. Enforced in the model, verified by switching users with View As.

## API

```
GET /occupancy?community_id=&start=&end=
GET /labor-cost?community_id=&period=
GET /incidents/summary?community_id=&period=
GET /reviews/summary?community_id=&start=&end=
GET /resident-care-level-changes?current_flag=true
GET /move-outs/reasons?community_id=&period=
```

Every request needs an `X-API-Key` header. Authorization happens server side through a shared
`apply_authorization()` helper. Corporate Admin sees everything, Regional Director is filtered by
`dim_community_region`, Executive Director is filtered to one community. Swagger docs are exposed
automatically by FastAPI at `/docs`.

**Test keys used for the RBAC demo**


| Corporate Admin | `corp-admin-key` | all communities, including C001 to C014 and additional codes C905, C934, C936, C951, C969 |
| Regional Director | `region-east-key` | C001, C002, C003, C004 only (this key is mapped to the Pacific Northwest region, not literally "east", the name is just a label) |
| Executive Director | `community-c001-key` | C001 only |

Example calls:

```bash
curl -H "X-API-Key: corp-admin-key" "http://127.0.0.1:8000/occupancy"
curl -H "X-API-Key: region-east-key" "http://127.0.0.1:8000/occupancy"
curl -H "X-API-Key: community-c001-key" "http://127.0.0.1:8000/occupancy"
curl -H "X-API-Key: community-c001-key" "http://127.0.0.1:8000/occupancy?community_id=C001&start=2025-01&end=2025-06"
curl -H "X-API-Key: community-c001-key" "http://127.0.0.1:8000/labor-cost?community_id=C001&period=2025-06"
curl -H "X-API-Key: community-c001-key" "http://127.0.0.1:8000/incidents/summary?community_id=C001&period=2025-03"
curl -H "X-API-Key: community-c001-key" "http://127.0.0.1:8000/reviews/summary?community_id=C001"
curl -H "X-API-Key: community-c001-key" "http://127.0.0.1:8000/resident-care-level-changes?current_flag=true"
curl -H "X-API-Key: community-c001-key" "http://127.0.0.1:8000/move-outs/reasons?community_id=C001&period=2025-06"
```

## Validation framework

Runs automatically after every pipeline execution. Reconciles row counts and aggregates across Bronze,
Silver, and Gold, and checks business rules: no discharge before admit, no negative hours, acuity in
range, valid review ratings. Output goes to `validation/validation_summary.csv` and
`validation/validation_report.json`, each finding scored with a severity and a recommended action.

**What the last run found**


1. Labor row count | Bronze 295,250, Silver 295,250, Gold 297,046. Gold has 1,796 extra rows - Investigate joins in fact_labor for one to many matches, most likely duplicate employee_id values in dim_employee, enforce uniqueness on dimension keys before Gold 

2. Resident count | Bronze 12,456, Silver 823, Gold 823 - Expected. Silver deduplicates to the latest version of each resident, full history is preserved separately in dim_resident_scd 

3. Shift hours reconciliation | Totals differ between Bronze and Gold - Same root cause as the labor row count issue, duplicated rows inflate summed hours 

4. Acuity scores | A small number of residents had scores outside the 1 to 5 range - Quarantine these records and notify the business owner before they reach reporting 

5. Revenue reconciliation | Passed, Silver and Gold totals match - Continue running this check after every execution 

6. Future dated incidents | None found - Continue validating incoming records 

7. Review ratings | None invalid | Continue validating incoming records 

## Anomalies found in the data

**ADP hourly_rate.** The data dictionary says this should be a numeric pay rate. What actually came
through was a full role to rate dictionary embedded in every row, for example
`{'Caregiver':16, 'RN':46, 'Maintenance':23}`, instead of a single number. Bronze keeps the raw value
untouched. Silver pulls out the rate matching that employee's own role, so a future pay change doesn't
need a code change.

**Communities missing from the region mapping.** The Gold data contains community codes beyond the
14 expected ones (C905, C934, C936, C951, C969 show up for Corporate Admin). These are not present in
`dim_community_region`, so Regional Director users cannot see them until a mapping is added. This is a
reference data gap, not a pipeline bug, worth raising with Pinewood so the master community list gets
kept current.

**Resident count drop from Bronze to Silver.** 12,456 rows down to 823. Not an error on its own, this
is deduplication doing its job, but it is worth calling out explicitly since a reviewer seeing that
number without context would assume data loss.

## Assumptions

Bronze is raw and untouched. All cleansing happens in Silver. Gold only holds analytics ready tables.
Care level is standardized to Independent Living, Assisted Living, Memory Care in Silver.

## With more time

Automated schema validation before ingestion, metadata driven business rules instead of hardcoded
checks, alerting on top of the validation report instead of a static file, uniqueness constraints on
dimension keys enforced before Gold builds, and a direct DuckDB connection for Power BI once the ODBC
driver issues are sorted out.

## Client communication

`/communication/` has the email to Pinewood IT requesting access to the five source systems, and the
incident response email replying to the CFO's occupancy discrepancy report.

## Walkthrough


