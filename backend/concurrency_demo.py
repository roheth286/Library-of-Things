import time
import psycopg2
from psycopg2.extensions import (
    ISOLATION_LEVEL_READ_COMMITTED,
    ISOLATION_LEVEL_SERIALIZABLE
)
from psycopg2.extras import RealDictCursor
from backend.database import get_db_connection

def simulate_unprotected_reservation(unit_id: int, member_id: int, delay_seconds: float = 2.0):
    """
    Demonstrates the RACE CONDITION / DOUBLE-BOOKING vulnerability:
    1. Checks if the unit is 'Available' without row locking (SELECT ...).
    2. Simulates network/processing delay (time.sleep).
    3. Meanwhile, another transaction concurrently reads the same unit as 'Available'.
    4. Both execute INSERT into reservations and UPDATE tool_units, corrupting data.
    """
    conn = get_db_connection(isolation_level=ISOLATION_LEVEL_READ_COMMITTED)
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Step 1: Naive check without SELECT ... FOR UPDATE
            cur.execute("""
                SELECT unit_id, condition_status 
                FROM tool_units 
                WHERE unit_id = %s;
            """, (unit_id,))
            unit = cur.fetchone()

            if not unit:
                return {"success": False, "error": "Unit not found"}

            if unit["condition_status"] != "Available":
                return {
                    "success": False,
                    "error": f"Unit status was already '{unit['condition_status']}'"
                }

            # Step 2: Artificial latency window (allows concurrent request to slip in)
            time.sleep(delay_seconds)

            # Step 3: Insert reservation
            cur.execute("""
                INSERT INTO reservations (unit_id, member_id, reserved_for_date, status, expires_at)
                VALUES (%s, %s, CURRENT_DATE, 'Active', CURRENT_TIMESTAMP + INTERVAL '48 hours')
                RETURNING reservation_id;
            """, (unit_id, member_id))
            res = cur.fetchone()

            # Step 4: Flip unit status
            cur.execute("""
                UPDATE tool_units
                SET condition_status = 'Reserved'
                WHERE unit_id = %s;
            """, (unit_id,))

            conn.commit()
            return {
                "success": True,
                "reservation_id": res["reservation_id"],
                "member_id": member_id,
                "unit_id": unit_id,
                "mode": "UNPROTECTED (Vulnerable to Race Conditions)"
            }
    except Exception as e:
        conn.rollback()
        return {"success": False, "error": str(e)}
    finally:
        conn.close()

def simulate_protected_reservation(unit_id: int, member_id: int, delay_seconds: float = 1.0):
    """
    Demonstrates the PESSIMISTIC LOCKING FIX:
    Uses SELECT ... FOR UPDATE within a transaction.
    The second concurrent transaction is forced to wait until the first commits,
    then upon reading the updated row sees it is already 'Reserved' and cleanly rejects.
    """
    conn = get_db_connection(isolation_level=ISOLATION_LEVEL_READ_COMMITTED)
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Step 1: Pessimistic Row Lock (Acquires Exclusive Row Lock)
            cur.execute("""
                SELECT unit_id, condition_status 
                FROM tool_units 
                WHERE unit_id = %s 
                FOR UPDATE;
            """, (unit_id,))
            unit = cur.fetchone()

            if not unit:
                conn.rollback()
                return {"success": False, "error": "Unit not found"}

            if unit["condition_status"] != "Available":
                conn.rollback()
                return {
                    "success": False,
                    "error": f"Unit is already {unit['condition_status']}. Reservation rejected by row lock."
                }

            # Simulate processing delay while holding lock
            time.sleep(delay_seconds)

            # Insert reservation
            cur.execute("""
                INSERT INTO reservations (unit_id, member_id, reserved_for_date, status, expires_at)
                VALUES (%s, %s, CURRENT_DATE, 'Active', CURRENT_TIMESTAMP + INTERVAL '48 hours')
                RETURNING reservation_id;
            """, (unit_id, member_id))
            res = cur.fetchone()

            # Flip unit status
            cur.execute("""
                UPDATE tool_units
                SET condition_status = 'Reserved'
                WHERE unit_id = %s;
            """, (unit_id,))

            conn.commit()
            return {
                "success": True,
                "reservation_id": res["reservation_id"],
                "member_id": member_id,
                "unit_id": unit_id,
                "mode": "PROTECTED (Pessimistic Lock: SELECT ... FOR UPDATE)"
            }
    except Exception as e:
        conn.rollback()
        return {"success": False, "error": str(e)}
    finally:
        conn.close()
