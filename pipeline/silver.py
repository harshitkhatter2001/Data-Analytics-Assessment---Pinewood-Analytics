import sys
from pathlib import Path
import duckdb
import pandas as pd

# Show all columns
pd.set_option("display.max_columns", None)
pd.set_option("display.width", None)

# Add project root to Python path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.append(str(PROJECT_ROOT))

from config import DATABASE_PATH

# Connect
conn = duckdb.connect(str(DATABASE_PATH))

# ==========================================================
# BRONZE TABLE
# ==========================================================

print("\n===================== BRONZE SCHEMA =====================")
print(conn.execute("""
DESCRIBE bronze_adp_shifts;
""").fetchdf().to_string(index=False))

print("\n===================== BRONZE SAMPLE =====================")
print(conn.execute("""
SELECT *
FROM bronze_adp_shifts
LIMIT 5;
""").fetchdf().to_string(index=False))

# ==========================================================
# SILVER TABLE
# ==========================================================

print("\n===================== SILVER SCHEMA =====================")
print(conn.execute("""
DESCRIBE silver_adp_shifts;
""").fetchdf().to_string(index=False))

print("\n===================== SILVER SAMPLE =====================")
print(conn.execute("""
SELECT *
FROM silver_adp_shifts
LIMIT 5;
""").fetchdf().to_string(index=False))

print("\n===================== DISTINCT HOURLY RATE =====================")
print(conn.execute("""
SELECT DISTINCT hourly_rate
FROM silver_adp_shifts;
""").fetchdf().to_string(index=False))

conn.close()