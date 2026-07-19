from pathlib import Path
import duckdb


BASE_DIR = Path(__file__).resolve().parent.parent

DB_PATH = BASE_DIR / "pinewood.duckdb"

SQL_PATH = BASE_DIR / "sql" / "gold.sql"


def run():

    conn = duckdb.connect(str(DB_PATH))

    with open(SQL_PATH, "r", encoding="utf-8") as f:
        sql = f.read()

    conn.execute(sql)

    conn.close()

    print("Gold Layer Completed")


if __name__ == "__main__":
    run()


    