import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import Optional
from fastapi import FastAPI, HTTPException, Query, Body
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor

from backend.database import get_db_connection, execute_query
from backend.concurrency_demo import simulate_unprotected_reservation, simulate_protected_reservation

app = FastAPI(
    title="Library of Things - Database Systems Lab",
    version="1.0.0",
    description="BCSE302P DBMS Lab Project - PostgreSQL, FastAPI, Triggers, Procedures, Concurrency Demo"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

thread_pool = ThreadPoolExecutor(max_workers=10)

# ------------------------------------------------------------------------------
# Pydantic Request Models
# ------------------------------------------------------------------------------
class CheckOutRequest(BaseModel):
    unit_id: int
    member_id: int
    loan_days: int = 7

class CheckInRequest(BaseModel):
    loan_id: int
    condition: str = "Good"  # Good, Minor, Moderate, Severe
    notes: Optional[str] = "Standard return inspection"

class ReserveRequest(BaseModel):
    tool_id: Optional[int] = None
    unit_id: Optional[int] = None
    member_id: int
    use_locking: bool = True

class WaitlistRequest(BaseModel):
    tool_id: int
    member_id: int

class DamageReportRequest(BaseModel):
    unit_id: int
    loan_id: Optional[int] = None
    description: str
    severity: str  # Minor, Moderate, Severe

class DepositReleaseRequest(BaseModel):
    loan_id: int

# ------------------------------------------------------------------------------
# 1. CATALOG & INVENTORY ENDPOINTS
# ------------------------------------------------------------------------------
@app.get("/api/categories")
def get_categories():
    return execute_query("SELECT * FROM categories ORDER BY name;")

@app.get("/api/tools")
def get_tools(category_id: Optional[int] = None):
    query = """
        SELECT 
            t.tool_id,
            t.name,
            t.category_id,
            c.name AS category_name,
            t.description,
            t.deposit_amount,
            COUNT(tu.unit_id) AS total_units,
            COUNT(CASE WHEN tu.condition_status = 'Available' THEN 1 END) AS available_units,
            COUNT(CASE WHEN tu.condition_status = 'Loaned' THEN 1 END) AS loaned_units,
            COUNT(CASE WHEN tu.condition_status = 'Repair' THEN 1 END) AS repair_units
        FROM tools t
        JOIN categories c ON t.category_id = c.category_id
        LEFT JOIN tool_units tu ON t.tool_id = tu.tool_id
        WHERE (%s IS NULL OR t.category_id = %s)
        GROUP BY t.tool_id, t.name, t.category_id, c.name, t.description, t.deposit_amount
        ORDER BY t.tool_id;
    """
    return execute_query(query, (category_id, category_id))

@app.get("/api/tools/{tool_id}/units")
def get_tool_units(tool_id: int):
    query = """
        SELECT 
            tu.unit_id,
            tu.tool_id,
            tu.condition_status,
            tu.serial_no,
            l.loan_id AS active_loan_id,
            m.name AS active_borrower_name
        FROM tool_units tu
        LEFT JOIN loans l ON tu.unit_id = l.unit_id AND l.status = 'Active'
        LEFT JOIN members m ON l.member_id = m.member_id
        WHERE tu.tool_id = %s
        ORDER BY tu.unit_id;
    """
    return execute_query(query, (tool_id,))

@app.get("/api/members")
def get_members():
    return execute_query("SELECT * FROM members ORDER BY member_id ASC;")

# ------------------------------------------------------------------------------
# 2. CORE LENDING FLOW (CHECK-OUT & CHECK-IN)
# ------------------------------------------------------------------------------
@app.post("/api/loans/checkout")
def checkout_tool(req: CheckOutRequest):
    """
    Staff Check-out:
    - Atomically verifies unit availability with SELECT ... FOR UPDATE
    - Creates a new active loan row
    - Updates unit condition_status to 'Loaned'
    - Creates corresponding deposit record
    - Triggers maintain_member_loans trigger to update active_loans_count
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # 1. Lock unit
            cur.execute("""
                SELECT tu.unit_id, tu.condition_status, t.deposit_amount, t.name AS tool_name
                FROM tool_units tu
                JOIN tools t ON tu.tool_id = t.tool_id
                WHERE tu.unit_id = %s
                FOR UPDATE;
            """, (req.unit_id,))
            unit = cur.fetchone()

            if not unit:
                raise HTTPException(status_code=404, detail="Unit not found")

            if unit["condition_status"] not in ("Available", "Reserved"):
                raise HTTPException(
                    status_code=400,
                    detail=f"Unit is currently '{unit['condition_status']}' and cannot be checked out"
                )

            # 2. Insert loan
            cur.execute("""
                INSERT INTO loans (unit_id, member_id, loan_date, due_date, status)
                VALUES (%s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '%s days', 'Active')
                RETURNING loan_id, due_date;
            """, (req.unit_id, req.member_id, req.loan_days))
            loan = cur.fetchone()

            # 3. Flip unit status to 'Loaned'
            cur.execute("""
                UPDATE tool_units
                SET condition_status = 'Loaned'
                WHERE unit_id = %s;
            """, (req.unit_id,))

            # 4. Create deposit record
            cur.execute("""
                INSERT INTO deposits (loan_id, amount, status)
                VALUES (%s, %s, 'Held')
                RETURNING deposit_id;
            """, (loan["loan_id"], unit["deposit_amount"]))
            deposit = cur.fetchone()

            # 5. Clear any active reservation for this unit & member
            cur.execute("""
                UPDATE reservations
                SET status = 'Fulfilled'
                WHERE unit_id = %s AND member_id = %s AND status = 'Active';
            """, (req.unit_id, req.member_id))

            conn.commit()
            return {
                "message": f"Successfully checked out {unit['tool_name']}",
                "loan_id": loan["loan_id"],
                "due_date": loan["due_date"],
                "deposit_id": deposit["deposit_id"],
                "deposit_amount": unit["deposit_amount"]
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/api/loans/checkin")
def checkin_tool(req: CheckInRequest):
    """
    Staff Check-in / Return:
    Executes PostgreSQL Stored Procedure `sp_return_unit_and_cascade`:
    - Closes loan with return_date
    - If damaged (Moderate/Severe), inserts damage_reports which fires trigger to flag unit to Repair
    - If undamaged, checks waitlist, auto-promotes top member, creates 48h reservation, sets unit to 'Reserved'
    - Otherwise sets unit to 'Available'
    - Automatically updates deposits table (Released or Forfeited)
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CALL sp_return_unit_and_cascade(
                    %s, %s, %s, '', NULL, NULL
                );
            """, (req.loan_id, req.condition, req.notes))
            row = cur.fetchone()
            conn.commit()
            
            result_status = row[0] if row else "Processed"
            promoted_member = row[1] if row and len(row) > 1 else None
            new_res_id = row[2] if row and len(row) > 2 else None

            return {
                "message": "Check-in completed successfully",
                "result_status": result_status,
                "promoted_member_id": promoted_member,
                "reservation_id": new_res_id
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

@app.get("/api/loans/active")
def get_active_loans():
    query = """
        SELECT 
            l.loan_id,
            l.unit_id,
            tu.serial_no,
            t.name AS tool_name,
            m.member_id,
            m.name AS member_name,
            l.loan_date,
            l.due_date,
            d.amount AS deposit_amount,
            d.status AS deposit_status
        FROM loans l
        JOIN tool_units tu ON l.unit_id = tu.unit_id
        JOIN tools t ON tu.tool_id = t.tool_id
        JOIN members m ON l.member_id = m.member_id
        LEFT JOIN deposits d ON l.loan_id = d.loan_id
        WHERE l.status = 'Active'
        ORDER BY l.due_date ASC;
    """
    return execute_query(query)

# ------------------------------------------------------------------------------
# 3. RESERVATIONS & WAITLISTS
# ------------------------------------------------------------------------------
@app.post("/api/reservations")
def create_reservation(req: ReserveRequest):
    """
    Reserve a specific unit or next available unit of a tool.
    Uses pessimistic locking if requested.
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            target_unit_id = req.unit_id

            # If tool_id was passed instead of specific unit, pick next available unit
            if not target_unit_id and req.tool_id:
                cur.execute("""
                    SELECT unit_id FROM tool_units 
                    WHERE tool_id = %s AND condition_status = 'Available'
                    LIMIT 1
                    FOR UPDATE SKIP LOCKED;
                """, (req.tool_id,))
                found = cur.fetchone()
                if not found:
                    raise HTTPException(
                        status_code=400, 
                        detail="No units currently available for this tool. Please join the waitlist."
                    )
                target_unit_id = found["unit_id"]

            if not target_unit_id:
                raise HTTPException(status_code=400, detail="Must provide either unit_id or tool_id")

            # Check / Lock unit
            if req.use_locking:
                cur.execute("""
                    SELECT unit_id, condition_status FROM tool_units 
                    WHERE unit_id = %s FOR UPDATE;
                """, (target_unit_id,))
            else:
                cur.execute("""
                    SELECT unit_id, condition_status FROM tool_units 
                    WHERE unit_id = %s;
                """, (target_unit_id,))
                
            unit = cur.fetchone()
            if not unit or unit["condition_status"] != "Available":
                raise HTTPException(status_code=400, detail="Selected unit is not available for reservation")

            # Insert reservation
            cur.execute("""
                INSERT INTO reservations (unit_id, member_id, reserved_for_date, status, expires_at)
                VALUES (%s, %s, CURRENT_DATE, 'Active', CURRENT_TIMESTAMP + INTERVAL '48 hours')
                RETURNING reservation_id, expires_at;
            """, (target_unit_id, req.member_id))
            res = cur.fetchone()

            # Set unit status to 'Reserved'
            cur.execute("""
                UPDATE tool_units
                SET condition_status = 'Reserved'
                WHERE unit_id = %s;
            """, (target_unit_id,))

            conn.commit()
            return {
                "message": "Reservation confirmed",
                "reservation_id": res["reservation_id"],
                "unit_id": target_unit_id,
                "expires_at": res["expires_at"]
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/api/waitlists")
def join_waitlist(req: WaitlistRequest):
    """Adds a member to the waiting queue for a tool."""
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Check existing active waitlist entry
            cur.execute("""
                SELECT waitlist_id FROM waitlists 
                WHERE tool_id = %s AND member_id = %s AND status = 'Waiting';
            """, (req.tool_id, req.member_id))
            if cur.fetchone():
                raise HTTPException(status_code=400, detail="Member is already on waitlist for this tool")

            # Next position
            cur.execute("""
                SELECT COALESCE(MAX(position), 0) + 1 AS next_pos
                FROM waitlists
                WHERE tool_id = %s AND status = 'Waiting';
            """, (req.tool_id,))
            pos = cur.fetchone()["next_pos"]

            cur.execute("""
                INSERT INTO waitlists (tool_id, member_id, position, status)
                VALUES (%s, %s, %s, 'Waiting')
                RETURNING waitlist_id, position;
            """, (req.tool_id, req.member_id, pos))
            entry = cur.fetchone()

            conn.commit()
            return {
                "message": f"Successfully joined waitlist at position #{entry['position']}",
                "waitlist_id": entry["waitlist_id"],
                "position": entry["position"]
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# ------------------------------------------------------------------------------
# 4. DAMAGE REPORTS & TRIGGERS
# ------------------------------------------------------------------------------
@app.post("/api/damage-reports")
def report_damage(req: DamageReportRequest):
    """
    Submits a damage report.
    Directly exercises database trigger `trg_damage_repair_flag`:
    If severity is 'Moderate' or 'Severe', the trigger will automatically set
    tool_units.condition_status to 'Repair' without application code doing it!
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO damage_reports (unit_id, loan_id, description, severity)
                VALUES (%s, %s, %s, %s)
                RETURNING report_id, reported_at;
            """, (req.unit_id, req.loan_id, req.description, req.severity))
            report = cur.fetchone()

            # Read back the unit status to prove the database trigger fired!
            cur.execute("""
                SELECT condition_status FROM tool_units WHERE unit_id = %s;
            """, (req.unit_id,))
            updated_unit = cur.fetchone()

            conn.commit()
            return {
                "message": "Damage report registered",
                "report_id": report["report_id"],
                "trigger_effect": f"Unit condition is now '{updated_unit['condition_status']}' (updated via trigger)",
                "unit_condition_status": updated_unit["condition_status"]
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# ------------------------------------------------------------------------------
# 5. KITS (VIEW DEMONSTRATION)
# ------------------------------------------------------------------------------
@app.get("/api/kits")
def get_kits():
    """Queries the database view v_kit_availability."""
    return execute_query("SELECT * FROM v_kit_availability ORDER BY kit_id;")

@app.get("/api/kits/{kit_id}/components")
def get_kit_components(kit_id: int):
    query = """
        SELECT 
            kc.kit_id,
            kc.tool_id,
            t.name AS tool_name,
            kc.quantity_required,
            COUNT(tu.unit_id) FILTER (WHERE tu.condition_status = 'Available') AS free_units_count
        FROM kit_components kc
        JOIN tools t ON kc.tool_id = t.tool_id
        LEFT JOIN tool_units tu ON tu.tool_id = t.tool_id
        WHERE kc.kit_id = %s
        GROUP BY kc.kit_id, kc.tool_id, t.name, kc.quantity_required;
    """
    return execute_query(query, (kit_id,))

# ------------------------------------------------------------------------------
# 6. DASHBOARD & ANALYTICS VIEWS
# ------------------------------------------------------------------------------
@app.get("/api/analytics/fleet-status")
def get_fleet_status():
    return execute_query("SELECT * FROM v_fleet_status;")

@app.get("/api/analytics/waitlists")
def get_waitlist_analytics():
    return execute_query("SELECT * FROM v_waitlist_summary WHERE waiting_members_count > 0;")

@app.get("/api/analytics/loan-durations")
def get_loan_durations():
    return execute_query("SELECT * FROM v_loan_duration_analytics;")

@app.get("/api/analytics/deposits")
def get_deposits_report():
    query = """
        SELECT 
            d.deposit_id,
            d.loan_id,
            d.amount,
            d.status,
            m.name AS member_name,
            t.name AS tool_name,
            l.status AS loan_status
        FROM deposits d
        JOIN loans l ON d.loan_id = l.loan_id
        JOIN tool_units tu ON l.unit_id = tu.unit_id
        JOIN tools t ON tu.tool_id = t.tool_id
        JOIN members m ON l.member_id = m.member_id
        ORDER BY d.deposit_id DESC
        LIMIT 20;
    """
    return execute_query(query)

# ------------------------------------------------------------------------------
# 7. PHASE 3: CONCURRENCY RACE CONDITION SIMULATION
# ------------------------------------------------------------------------------
class ConcurrencySimulationRequest(BaseModel):
    unit_id: int
    member1_id: int
    member2_id: int
    mode: str = "unprotected"  # "unprotected" or "protected"
    delay_seconds: float = 1.5

@app.post("/api/concurrency/simulate")
async def simulate_concurrency(req: ConcurrencySimulationRequest):
    """
    Simulates two simultaneous reservation attempts on the exact same unit.
    - If mode == 'unprotected': runs without row locking.
      Both transactions read the unit as 'Available' before either commits.
      Both succeed in inserting reservations, demonstrating a race condition!
    - If mode == 'protected': runs with SELECT ... FOR UPDATE.
      The second transaction waits on the lock, sees updated status, and gets cleanly rejected.
    """
    # Verify unit is currently Available (or reset it to Available for demo purposes)
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT unit_id, tool_id, condition_status FROM tool_units WHERE unit_id = %s;", (req.unit_id,))
            unit = cur.fetchone()
            if not unit:
                raise HTTPException(status_code=404, detail="Unit not found")
            
            # Reset unit and clear active reservations for clean demo measurement
            cur.execute("DELETE FROM reservations WHERE unit_id = %s;", (req.unit_id,))
            cur.execute("UPDATE tool_units SET condition_status = 'Available' WHERE unit_id = %s;", (req.unit_id,))
            conn.commit()
    finally:
        conn.close()

    loop = asyncio.get_event_loop()

    if req.mode == "unprotected":
        # Launch two simultaneous tasks without locks
        task1 = loop.run_in_executor(
            thread_pool,
            simulate_unprotected_reservation,
            req.unit_id,
            req.member1_id,
            req.delay_seconds
        )
        task2 = loop.run_in_executor(
            thread_pool,
            simulate_unprotected_reservation,
            req.unit_id,
            req.member2_id,
            req.delay_seconds
        )
    else:
        # Launch two simultaneous tasks with SELECT ... FOR UPDATE
        task1 = loop.run_in_executor(
            thread_pool,
            simulate_protected_reservation,
            req.unit_id,
            req.member1_id,
            req.delay_seconds
        )
        task2 = loop.run_in_executor(
            thread_pool,
            simulate_protected_reservation,
            req.unit_id,
            req.member2_id,
            req.delay_seconds
        )

    result1, result2 = await asyncio.gather(task1, task2)

    # Check database state after both finished
    post_res = execute_query(
        "SELECT reservation_id, member_id, status FROM reservations WHERE unit_id = %s AND status = 'Active';",
        (req.unit_id,)
    )

    return {
        "mode": req.mode.upper(),
        "unit_id": req.unit_id,
        "transaction_1": result1,
        "transaction_2": result2,
        "active_reservations_count": len(post_res),
        "active_reservations": post_res,
        "outcome": (
            "⚠️ DATA CORRUPTION / RACE CONDITION DETECTED! Multiple members reserved the same unit simultaneously!"
            if len(post_res) > 1 else
            "✅ CONCURRENCY PROTECTED! Only one reservation was granted, duplicate reservation was cleanly prevented by row locking."
        )
    }

# ------------------------------------------------------------------------------
# STATIC FILES FOR FRONTEND
# ------------------------------------------------------------------------------
app.mount("/", StaticFiles(directory="frontend", html=True), name="frontend")
