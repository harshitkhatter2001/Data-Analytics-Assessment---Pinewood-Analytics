import duckdb

conn = duckdb.connect("pinewood.duckdb")

tables = [
    "silver_adp_shifts",
    "silver_gbp_reviews",
    "silver_hubspot_leads",
    "silver_pcc_residents",
    "silver_pcc_incidents",
    "silver_pcc_care_history",
    "silver_yardi_units",
    "silver_yardi_leases"
]

for table in tables:
    print(f"\n===== {table} =====")
    print(conn.execute(f"DESCRIBE {table}").fetchdf())