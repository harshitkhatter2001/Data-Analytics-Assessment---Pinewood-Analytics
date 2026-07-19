from pathlib import Path
import pandas as pd

RAW_DIR = Path("data/raw")

for csv in sorted(RAW_DIR.glob("*.csv")):
    print("\n" + "=" * 100)
    print(csv.stem.upper())
    print("=" * 100)

    try:
        df = pd.read_csv(csv, nrows=5)
        print(df.dtypes)
    except Exception as e:
        print(f"Error: {e}")