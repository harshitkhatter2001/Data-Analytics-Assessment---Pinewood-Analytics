import duckdb
from .db_config import DB_PATH

def get_connection():
    print("DB PATH:", DB_PATH)

    conn = duckdb.connect(str(DB_PATH), read_only=True)

    return conn