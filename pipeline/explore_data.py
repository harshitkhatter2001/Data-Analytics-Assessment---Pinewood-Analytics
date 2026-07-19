from pathlib import Path
import pandas as pd

RAW_PATH = Path("data/raw")

print("=" * 80)
print("PINEWOOD DATASET EXPLORATION")
print("=" * 80)

csv_files = list(RAW_PATH.glob("*.csv"))

print(f"\nTotal CSV Files Found: {len(csv_files)}\n")

for file in csv_files:
    print("=" * 80)
    print(f"FILE : {file.name}")

    try:
        df = pd.read_csv(file)

        print(f"Rows    : {len(df)}")
        print(f"Columns : {len(df.columns)}")

        print("\nColumn Names:")
        print(list(df.columns))

        print("\nSample Data:")
        print(df.head(3))

    except Exception as e:
        print(f"Error reading {file.name}")
        print(e)

    print()