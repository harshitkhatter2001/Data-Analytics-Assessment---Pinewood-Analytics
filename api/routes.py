from datetime import datetime

from fastapi import APIRouter, Query, HTTPException, Depends

from .database import get_connection
from .auth import get_current_user

router = APIRouter(tags=["Analytics"])



# Occupancy

@router.get("/occupancy")
def get_occupancy(
     user=Depends(get_current_user),
    community_id: str | None = Query(None),
    start: str |None = Query(None, description="Format: YYYY-MM"),
    end: str | None = Query(None, description="Format: YYYY-MM"),
):

    conn = get_connection()

    try:

        query = """
            SELECT
                year,
                month,
                month_name,
                community_id,
                total_units,
                occupied_units,
                occupancy_rate_pct
            FROM vw_monthly_occupancy_rate
            WHERE 1=1
        """

        params = []

        if community_id:
            query += " AND UPPER(community_id)=UPPER(?)"
            params.append(community_id)

        if start:
            try:
                start_year, start_month = map(int, start.split("-"))
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid start format. Use YYYY-MM."
                )

            query += """
                AND (
                    year > ?
                    OR (year = ? AND month >= ?)
                )
            """
            params.extend([start_year, start_year, start_month])

        if end:
            try:
                end_year, end_month = map(int, end.split("-"))
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid end format. Use YYYY-MM."
                )

            query += """
                AND (
                    year < ?
                    OR (year = ? AND month <= ?)
                )
            """
            params.extend([end_year, end_year, end_month])
        query, params = apply_authorization(query, params, user)
        query += """
            ORDER BY
                year,
                month
        """
        
        df = conn.execute(query, params).fetchdf()

        return df.to_dict(orient="records")

    finally:
        conn.close()


# Labor Cost


@router.get("/labor-cost")
def get_labor_cost(
    user=Depends(get_current_user),
    community_id: str | None = Query(None),
    period: str | None = Query(
        None,
        description="Format: YYYY-MM"
    ),
):

    conn = get_connection()

    try:

        query = """
            SELECT
                community_id,
                year,
                month,
                total_labor_cost,
                resident_days,
                labor_cost_per_resident_day
            FROM vw_labor_cost_per_resident_day
            WHERE 1=1
        """

        params = []

        if community_id:
            query += " AND UPPER(community_id)=UPPER(?)"
            params.append(community_id)

        if period:

            try:
                dt = datetime.strptime(period, "%Y-%m")
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="Period must be YYYY-MM."
                )

            query += " AND year=? AND month=?"
            params.extend([dt.year, dt.month])
        query, params = apply_authorization(query, params, user)
        query += """
            ORDER BY
                community_id,
                year,
                month
        """

        df = conn.execute(query, params).fetchdf()

        return df.to_dict(orient="records")

    finally:
        conn.close()



# Incident Summary


@router.get("/incidents/summary")
def get_incident_summary(
    user=Depends(get_current_user),
    community_id: str | None = Query(None),
    period: str | None = Query(
        None,
        description="Format: YYYY-MM"
    ),
):

    conn = get_connection()

    try:

        query = """
            SELECT
                community_id,
                year,
                month,
                total_incidents,
                resident_days,
                incident_rate_per_100_resident_days
            FROM vw_incident_rate_per_100_resident_days
            WHERE 1=1
        """

        params = []

        if community_id:
            query += " AND UPPER(community_id)=UPPER(?)"
            params.append(community_id)

        if period:

            try:
                dt = datetime.strptime(period, "%Y-%m")
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="Period must be in YYYY-MM format."
                )

            query += " AND year=? AND month=?"
            params.extend([dt.year, dt.month])
        query, params = apply_authorization(query, params, user)
        query += """
            ORDER BY
                community_id,
                year,
                month
        """

        df = conn.execute(query, params).fetchdf()

        return df.to_dict(orient="records")

    finally:
        conn.close()



# Reviews


@router.get("/reviews/summary")
def get_reviews(
    user=Depends(get_current_user),
    community_id: str | None = Query(None),
    start: str | None = Query(None),
    end: str | None = Query(None),
):

    conn = get_connection()

    try:

        query = """
            SELECT *
            FROM fact_reviews
            WHERE (? IS NULL OR UPPER(community_id)=UPPER(?))
              AND (? IS NULL OR review_date >= ?)
              AND (? IS NULL OR review_date <= ?)
        """

        params = [
            community_id,
            community_id,
            start,
            start,
            end,
            end,
        ]

        query, params = apply_authorization(query, params, user)

        df = conn.execute(query, params).fetchdf()

        return df.to_dict(orient="records")

    finally:
        conn.close()


# Resident Care Level Changes (SCD Type 2)


@router.get("/resident-care-level-changes")
def get_resident_care_level_changes(
        user=Depends(get_current_user),
    resident_id: str | None = Query(None),
    current_flag: bool | None = Query(None),
):

    conn = get_connection()

    try:

        query = """
            SELECT
                resident_id,
                previous_care_level,
                current_care_level,
                previous_change_date,
                current_change_date,
                days_between_changes,
                current_flag
            FROM vw_resident_care_level_changes_90_days
            WHERE 1=1
        """

        params = []

        if resident_id:
            query += " AND UPPER(resident_id)=UPPER(?)"
            params.append(resident_id)

        if current_flag is not None:
            query += " AND current_flag=?"
            params.append(current_flag)
        query, params = apply_authorization(query, params, user)
        query += """
            ORDER BY
                resident_id,
                current_change_date
        """

        df = conn.execute(query, params).fetchdf()

        return df.to_dict(orient="records")

    finally:
        conn.close()


# Move-out Reasons


@router.get("/move-outs/reasons")
def get_move_out_reasons(
    user=Depends(get_current_user),
    community_id: str | None = Query(None),
    period: str | None = Query(
        None,
        description="Format: YYYY-MM"
    ),
):

    conn = get_connection()

    try:

        query = """
            SELECT
                community_id,
                period,
                move_out_reason,
                move_out_count,
                total_move_outs,
                pct_of_total_moveouts,
                reason_rank
            FROM vw_top3_moveout_reasons
            WHERE 1=1
        """

        params = []

        if community_id:
            query += " AND UPPER(community_id) = UPPER(?)"
            params.append(community_id)

        if period:
            try:
                datetime.strptime(period, "%Y-%m")
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="Period must be in YYYY-MM format."
                )

            query += " AND period = ?"
            params.append(period)
        query, params = apply_authorization(query, params, user)
        query += """
            ORDER BY
                community_id,
                period,
                reason_rank
        """

        df = conn.execute(query, params).fetchdf()

        return df.to_dict(orient="records")

    finally:
        conn.close()

def apply_authorization(query: str, params: list, user: dict):

    if user["role"] == "corporate_admin":
        return query, params

    elif user["role"] == "regional_director":

        query += """
        AND community_id IN (
            SELECT community_id
            FROM dim_community_region
            WHERE region = ?
        )
        """

        params.append(user["region"])

    elif user["role"] == "executive_director":

        query += """
        AND community_id = ?
        """

        params.append(user["community_id"])

    return query, params