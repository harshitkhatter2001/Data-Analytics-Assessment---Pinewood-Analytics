
import os
import re
from pathlib import Path
from datetime import datetime

import duckdb
import pandas as pd


BASE_DIR = Path(__file__).resolve().parent.parent

RAW_DATA_PATH = BASE_DIR / "data" / "raw"

DB_PATH = BASE_DIR / "pinewood.duckdb"



DATASETS = {
    "adp_shifts": "bronze_adp_shifts",
    "gbp_reviews": "bronze_gbp_reviews",
    "hubspot_leads": "bronze_hubspot_leads",
    "pcc_residents": "bronze_pcc_residents",
    "pcc_incidents": "bronze_pcc_incidents",
    "pcc_care_history": "bronze_pcc_care_history",
    "yardi_units": "bronze_yardi_units",
    "yardi_leases": "bronze_yardi_leases",
}



def standardize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """
    Standardize column names.
    """

    df.columns = (
        df.columns
        .str.strip()
        .str.lower()
        .str.replace(" ", "_", regex=False)
        .str.replace("-", "_", regex=False)
    )

    return df


def discover_files():

    csv_files = list(RAW_DATA_PATH.glob("*.csv"))

    grouped = {}

    for file in csv_files:

        matched = False

        for dataset in DATASETS.keys():

            if file.name.startswith(dataset):

                grouped.setdefault(dataset, []).append(file)

                matched = True
                break

        if not matched:
            print(f"Skipped: {file.name}")

    return grouped




def load_dataset(files):

    frames = []

    for file in sorted(files):

        print(f"Reading {file.name}")

        df = pd.read_csv(file)

        df = standardize_columns(df)

        df["source_file"] = file.name

        df["ingestion_timestamp"] = datetime.now()

        frames.append(df)

    return pd.concat(frames, ignore_index=True, sort=False)



def write_table(conn, table_name, df):

    conn.register("temp_df", df)

    conn.execute(f"""
        CREATE OR REPLACE TABLE {table_name} AS
        SELECT *
        FROM temp_df
    """)

    conn.unregister("temp_df")


def run():

    print("=" * 60)
    print("BRONZE LAYER STARTED")
    print("=" * 60)

    conn = duckdb.connect(str(DB_PATH))

    grouped_files = discover_files()

    for dataset, files in grouped_files.items():

        table = DATASETS[dataset]

        print("\n--------------------------------------------")
        print(f"Dataset : {dataset}")
        print(f"Table   : {table}")
        print("--------------------------------------------")

        bronze_df = load_dataset(files)

        write_table(conn, table, bronze_df)

        print(f"Rows Loaded : {len(bronze_df):,}")

    conn.close()

    print("\nBronze Layer Completed Successfully.")



if __name__ == "__main__":
    run()