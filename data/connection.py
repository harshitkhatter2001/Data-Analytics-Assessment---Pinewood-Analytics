import duckdb

DB_PATH = "../database/pinewood.duckdb"

def get_connection():
    return duckdb.connect(DB_PATH, read_only=True)