import json
import time
import traceback
from datetime import datetime
from pathlib import Path
import sys

import duckdb

sys.path.append(str(Path(__file__).resolve().parent.parent))

from config import DATABASE_PATH, SQL_PATH, RAW_DATA_PATH, LOG_PATH
from validation.run_validation import run_validation


# CONFIGURATION


TABLE_MAP = {
    "adp_shifts": "bronze_adp_shifts",
    "gbp_reviews": "bronze_gbp_reviews",
    "hubspot_leads": "bronze_hubspot_leads",
    "pcc_care_history": "bronze_pcc_care_history",
    "pcc_incidents": "bronze_pcc_incidents",
    "pcc_residents": "bronze_pcc_residents",
    "yardi_leases": "bronze_yardi_leases",
    "yardi_units": "bronze_yardi_units"
}


# START PIPELINE


start_time = time.time()

run_log = {
    "run_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "status": "SUCCESS",
    "files_processed": [],
    "files_skipped": [],
    "tables_loaded": {},
    "rows_loaded": {},
    "rows_rejected": {},
    "anomalies": [],
    "duration_seconds": None,
    "error": None
}

print("=" * 70)
print("STARTING PIPELINE")
print("=" * 70)

conn = duckdb.connect(str(DATABASE_PATH))

try:


    # METADATA TABLE
  
    
    conn.execute("""
    CREATE TABLE IF NOT EXISTS processed_files (
        file_name VARCHAR PRIMARY KEY,
        dataset VARCHAR,
        processed_at TIMESTAMP
    )
    """)

  
    # BRONZE INCREMENTAL LOAD


    for dataset, table in TABLE_MAP.items():

        csv_files = sorted(RAW_DATA_PATH.glob(f"{dataset}_*.csv"))

        if not csv_files:
            print(f"No files found for {dataset}")
            continue

        for csv in csv_files:

            already_loaded = conn.execute(
                """
                SELECT COUNT(*)
                FROM processed_files
                WHERE file_name = ?
                """,
                [csv.name]
            ).fetchone()[0]

            if already_loaded:
                print(f"Skipping already processed file : {csv.name}")
                run_log["files_skipped"].append(csv.name)
                continue

            print(f"Loading : {csv.name}")

          
            # Create Bronze table (first run only)
           

            conn.execute(f"""
            CREATE TABLE IF NOT EXISTS {table} AS
            SELECT *,
                   CURRENT_TIMESTAMP AS ingestion_timestamp
            FROM read_csv_auto(
                '{csv.as_posix()}',
                union_by_name = TRUE,
                filename = TRUE
            )
            LIMIT 0;
            """)

            before_count = conn.execute(
                f"SELECT COUNT(*) FROM {table}"
            ).fetchone()[0]

            # Incremental Insert
      

            conn.execute(f"""
INSERT INTO {table}
BY NAME

SELECT *,
       CURRENT_TIMESTAMP AS ingestion_timestamp

FROM read_csv_auto(
    '{csv.as_posix()}',
    union_by_name = TRUE,
    filename = TRUE
);
""")
            after_count = conn.execute(
                f"SELECT COUNT(*) FROM {table}"
            ).fetchone()[0]

            rows_inserted = after_count - before_count

            print(f"Inserted {rows_inserted} rows into {table}")

            # Update Run Log
        

            run_log["files_processed"].append(csv.name)
            run_log["tables_loaded"][table] = after_count
            run_log["rows_loaded"][table] = rows_inserted
            run_log["rows_rejected"][table] = 0

       
            # Mark File as Processed
      

            conn.execute("""
            INSERT INTO processed_files
            (file_name, dataset, processed_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            """, [csv.name, dataset])

             
    # BRONZE VALIDATION


    print("\n" + "=" * 70)
    print("VALIDATING BRONZE LAYER")
    print("=" * 70)

    validation_query = (SQL_PATH / "bronze.sql").read_text(encoding="utf-8")

    validation_results = conn.execute(validation_query).fetchall()

    print("\nBronze Tables:")

    for table_name, row_count in validation_results:
        print(f"{table_name:<35} {row_count:>10} rows")

    
    # SILVER LAYER
    

    print("\n" + "=" * 70)
    print("BUILDING SILVER LAYER")
    print("=" * 70)

    silver_query = (SQL_PATH / "silver.sql").read_text(encoding="utf-8")

    conn.execute(silver_query)

    print("Silver layer completed successfully.")

    
    # GOLD LAYER
    

    print("\n" + "=" * 70)
    print("BUILDING GOLD LAYER")
    print("=" * 70)

    gold_query = (SQL_PATH / "gold.sql").read_text(encoding="utf-8")

    conn.execute(gold_query)

    print("Gold layer completed successfully.")



# Build Gold Business Views


    print("\n" + "=" * 70)
    print("BUILDING GOLD BUSINESS VIEWS")
    print("=" * 70)

    gold_views_query = (
        SQL_PATH / "gold_views.sql" 
    ).read_text(encoding="utf-8")

    conn.execute(gold_views_query)

    print("Gold Business Views completed successfully.")


# validation

    run_validation()


# EXPORT GOLD LAYER FOR POWER BI


    print("\n" + "=" * 70)
    print("EXPORTING GOLD TABLES")
    print("=" * 70)

# Create export directory if it doesn't exist
    EXPORT_PATH = Path("exports/gold")
    EXPORT_PATH.mkdir(parents=True, exist_ok=True)

# Get all tables from DuckDB
    all_tables = conn.execute("SHOW TABLES").fetchall()




# Keep only Gold dimension and fact tables
    gold_tables = [
        table[0]
        for table in all_tables
        if table[0].startswith("dim_") or table[0].startswith("fact_")
    ]

    print(f"Found {len(gold_tables)} Gold tables:")

    for table in gold_tables:
        print(f"  - {table}")

    print()

# Export each table as Parquet

    for table in gold_tables:

        output_file = EXPORT_PATH / f"{table}.parquet"

        conn.execute(f"""
            COPY {table}
            TO '{output_file.as_posix()}'
            (FORMAT PARQUET);
        """)

        print(f" Exported {table} -> {output_file.name}")

    print("\nGold layer export completed successfully.")


    
    # PIPELINE SUMMARY
    

    print("\n" + "=" * 70)
    print("PIPELINE SUMMARY")
    print("=" * 70)

    print(f"Files Skipped  : {len(run_log['files_skipped'])}")

    if run_log["files_processed"]:
        print("\nProcessed Files:")

        for file in run_log["files_processed"]:
            print(f"  • {file}")

    print("\nRows Loaded:")

    for table in run_log["rows_loaded"]:
        print(f"  {table:<35} {run_log['rows_loaded'][table]}")


# ERROR HANDLING


except Exception as e:

    traceback.print_exc()

    run_log["status"] = "FAILED"
    run_log["error"] = str(e)


# WRITE RUN LOG


finally:

    run_log["duration_seconds"] = round(time.time() - start_time, 2)

    LOG_PATH.mkdir(exist_ok=True)

    with open(LOG_PATH / "pipeline_run.json", "w") as outfile:
        json.dump(run_log, outfile, indent=4)

    conn.close()


# END


print("\n" + "=" * 70)

if run_log["status"] == "SUCCESS":
    print("PIPELINE COMPLETED SUCCESSFULLY")
else:
    print("PIPELINE FAILED")

print(f"Execution Time : {run_log['duration_seconds']} seconds")

print("=" * 70)


