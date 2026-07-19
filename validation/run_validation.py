import duckdb
import pandas as pd
import json
import os
from datetime import datetime

DB_PATH = "pinewood.duckdb"

con = duckdb.connect(DB_PATH)

results = []


def add_result(check, status, severity, recommendation, details=""):
    results.append({
        "Check": check,
        "Status": status,
        "Severity": severity,
        "Recommendation": recommendation,
        "Details": details
    })


def validate_row_counts():

    tables = [
        ("bronze_adp_shifts", "silver_adp_shifts", "fact_labor"),
        ("bronze_gbp_reviews", "silver_gbp_reviews", "fact_reviews"),
        ("bronze_hubspot_leads", "silver_hubspot_leads", "fact_leads"),
        ("bronze_pcc_incidents", "silver_pcc_incidents", "fact_incidents"),
        ("bronze_yardi_units", "silver_yardi_units", "fact_occupancy"),
        ("bronze_yardi_leases", "silver_yardi_leases", "fact_revenue"),
        ("bronze_pcc_residents", "silver_pcc_residents", "dim_resident")
    ]

    for bronze, silver, gold in tables:

        bronze_count = con.execute(
            f"SELECT COUNT(*) FROM {bronze}"
        ).fetchone()[0]

        silver_count = con.execute(
            f"SELECT COUNT(*) FROM {silver}"
        ).fetchone()[0]

        gold_count = con.execute(
            f"SELECT COUNT(*) FROM {gold}"
        ).fetchone()[0]

        if bronze_count == silver_count == gold_count:

            add_result(
                f"Row Count - {gold}",
                "PASS",
                "Low",
                "None",
                f"Bronze={bronze_count}, Silver={silver_count}, Gold={gold_count}"
            )

        else:

            add_result(
                f"Row Count - {gold}",
                "FAIL",
                "High",
                "Investigate ETL",
                f"Bronze={bronze_count}, Silver={silver_count}, Gold={gold_count}"
            )


def validate_revenue():

    silver = con.execute("""
    SELECT SUM(monthly_rate)
    FROM silver_yardi_leases
    """).fetchone()[0] or 0

    gold = con.execute("""
    SELECT SUM(monthly_rate)
    FROM fact_revenue
    """).fetchone()[0] or 0

    if abs(silver-gold) < 0.01:

        add_result(
            "Revenue Reconciliation",
            "PASS",
            "Low",
            "None"
        )

    else:

        add_result(
            "Revenue Reconciliation",
            "FAIL",
            "High",
            "Check Revenue Transformation",
            f"{silver} vs {gold}"
        )


def validate_shift_hours():

    bronze = con.execute("""
        SELECT SUM(hours_worked)
        FROM bronze_adp_shifts
    """).fetchone()[0] or 0

    gold = con.execute("""
        SELECT SUM(hours_worked)
        FROM fact_labor
    """).fetchone()[0] or 0

    if abs(bronze - gold) < 0.1:

        add_result(
            "Shift Hours",
            "PASS",
            "Low",
            "None"
        )

    else:

        add_result(
            "Shift Hours",
            "FAIL",
            "Medium",
            "Check Pipeline"
        )


def validate_discharge():

    count = con.execute("""
        SELECT COUNT(*)
        FROM dim_resident
        WHERE discharge_date < admit_date
    """).fetchone()[0]

    if count == 0:

        add_result(
            "Discharge Before Admit",
            "PASS",
            "Low",
            "None"
        )

    else:

        add_result(
            "Discharge Before Admit",
            "FAIL",
            "High",
            "Raise to Client",
            f"{count} residents"
        )


def validate_acuity():

    count = con.execute("""
        SELECT COUNT(*)
        FROM dim_resident
        WHERE acuity_score NOT BETWEEN 1 AND 5
    """).fetchone()[0]

    if count == 0:

        add_result(
            "Acuity Range",
            "PASS",
            "Low",
            "None"
        )

    else:

        add_result(
            "Acuity Range",
            "FAIL",
            "Medium",
            "Quarantine Records"
        )


def validate_hours():

    count = con.execute("""
        SELECT COUNT(*)
        FROM fact_labor
        WHERE hours_worked < 0
    """).fetchone()[0]

    if count == 0:

        add_result(
            "Negative Hours",
            "PASS",
            "Low",
            "None"
        )

    else:

        add_result(
            "Negative Hours",
            "FAIL",
            "Medium",
            "Fix Pipeline"
        )


def validate_reviews():

    count = con.execute("""
        SELECT COUNT(*)
        FROM fact_reviews
        WHERE rating < 1
           OR rating > 5
    """).fetchone()[0]

    if count == 0:

        add_result(
            "Invalid Rating",
            "PASS",
            "Low",
            "None"
        )

    else:

        add_result(
            "Invalid Rating",
            "FAIL",
            "Medium",
            "Raise to Client"
        )

def validate_future_dates():

    count = con.execute("""
        SELECT COUNT(*)
        FROM silver_pcc_incidents
        WHERE incident_date > CURRENT_DATE
    """).fetchone()[0]

    if count == 0:

        add_result(
            "Future Dated Incidents",
            "PASS",
            "Low",
            "None"
        )

    else:

        add_result(
            "Future Dated Incidents",
            "FAIL",
            "Medium",
            "Raise to Client",
            f"{count} future records"
        )

def export_report():

    os.makedirs("reports", exist_ok=True)

    df = pd.DataFrame(results)

    df.to_csv(
        "reports/validation_summary.csv",
        index=False
    )

    with open(
        "reports/validation_report.json",
        "w"
    ) as f:
        json.dump(results, f, indent=4)

    summary = {
        "Total Checks": len(results),
        "Passed": len([r for r in results if r["Status"] == "PASS"]),
        "Failed": len([r for r in results if r["Status"] == "FAIL"])
    }

    with open(
        "reports/validation_summary.json",
        "w"
    ) as f:
        json.dump(summary, f, indent=4)

def run_validation():

    print("Running Validation Framework...")

    validate_row_counts()

    validate_revenue()

    validate_shift_hours()

    validate_discharge()

    validate_future_dates()

    validate_acuity()

    validate_hours()

    validate_reviews()

    export_report()

    print("Validation Completed.")


if __name__ == "__main__":
    run_validation()