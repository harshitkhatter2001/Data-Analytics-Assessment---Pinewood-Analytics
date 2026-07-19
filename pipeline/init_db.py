import duckdb
from config import DB_PATH

def initialize_database():
    conn = duckdb.connect(str(DB_PATH))

    print("=" * 60)
    print(" Pinewood Analytics Database Initialized")
    print("=" * 60)
    print(f"Database Location : {DB_PATH}")
    print("Status            : SUCCESS")
    print("=" * 60)

    conn.close()


if __name__ == "__main__":
    initialize_database()