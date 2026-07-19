from pathlib import Path

# Root directory
BASE_DIR = Path(__file__).resolve().parent

# Database
DATABASE_PATH = BASE_DIR / "pinewood.duckdb"

# Data folders
RAW_DATA_PATH = BASE_DIR / "data" / "raw"

# SQL folder
SQL_PATH = BASE_DIR / "sql"

# Logs
LOG_PATH = BASE_DIR / "logs"
LOG_PATH.mkdir(exist_ok=True)

# Validation Reports
VALIDATION_PATH = BASE_DIR / "validation"
VALIDATION_PATH.mkdir(exist_ok=True)

# Pipeline Run Logs
RUN_LOG_PATH = VALIDATION_PATH / "latest_run.json"