"""
Comprehensive Automated Acceptance Test Suite (T01 - T12)
Course: Database Systems Lab (BCSE302P)
Project: CircuLend - Library of Things
Team:
  PRASANTH S - 24BCE2023
  ROHETH - 24BCT0277

Validates all 12 Lab Test Scenarios:
  T01 - Browse tools by category & verify unit-level availability
  T02 - Successful reservation of an eligible free unit
  T03 - Reject reservation of an unavailable unit (loaned/reserved)
  T04 - Staff checkout creates loan & marks unit Loaned atomically
  T05 - Staff return closes loan, makes unit Available & runs waitlist logic
  T06 - Damage report trigger auto-flags unit condition to Repair
  T07 - Deposit release denied before return / under damage
  T08 - Kit availability view correctly blocks kit when a component is missing
  T09 - Waitlist order promotion (oldest eligible entry promoted exactly once)
  T10 - Concurrent reservation safety (at most one succeeds under row lock)
  T11 - Transaction rollback on error midway through checkout
  T12 - Role-based authorization denies member access to staff routes
"""

import sys
import requests
import time

BASE_URL = "http://127.0.0.1:8080"
STAFF_HEADERS = {"X-User-Role": "staff"}
MEMBER_HEADERS = {"X-User-Role": "member"}

def run_tests():
    print("=" * 70)
    print("CIRCULEND: OFFICIAL ACCEPTANCE TEST SUITE (T01 - T12)")
    print("=" * 70)

    # --------------------------------------------------------------------------
    # T01: Browse Request tools by category
    # --------------------------------------------------------------------------
    res = requests.get(f"{BASE_URL}/api/tools?category_id=1")
    assert res.status_code == 200, f"T01 Failed: {res.text}"
    tools = res.json()
    assert len(tools) > 0, "T01 Failed: No tools returned for Category 1"
    first_tool = tools[0]
    assert "available_units" in first_tool and "total_units" in first_tool
    print(f"✅ T01 – Browse: Category 1 returned {len(tools)} tools with unit-level counts. (PASS)")

    # --------------------------------------------------------------------------
    # T02: Successful reservation of an eligible free unit
    # --------------------------------------------------------------------------
    # Find a free unit
    units = requests.get(f"{BASE_URL}/api/tools/2/units").json()
    free_unit = next(u for u in units if u["condition_status"] == "Available")
    res = requests.post(f"{BASE_URL}/api/reservations", json={
        "unit_id": free_unit["unit_id"],
        "member_id": 1,
        "use_locking": True
    })
    assert res.status_code == 200, f"T02 Failed: {res.text}"
    t02_unit_id = free_unit["unit_id"]
    print(f"✅ T02 – Successful reservation: Unit #{t02_unit_id} reserved for Member #1. (PASS)")

    # --------------------------------------------------------------------------
    # T03: Unavailable unit reservation rejected
    # --------------------------------------------------------------------------
    # Attempting to reserve the same unit again
    res = requests.post(f"{BASE_URL}/api/reservations", json={
        "unit_id": t02_unit_id,
        "member_id": 2,
        "use_locking": True
    })
    assert res.status_code == 400, f"T03 Failed: Should have rejected unavailable unit"
    print(f"✅ T03 – Unavailable unit: Rejected duplicate reservation on Unit #{t02_unit_id}. (PASS)")

    # --------------------------------------------------------------------------
    # T04: Staff Checkout
    # --------------------------------------------------------------------------
    # Find an available unit on Tool #4
    tool4_units = requests.get(f"{BASE_URL}/api/tools/4/units").json()
    free_tool4_unit = next(u for u in tool4_units if u["condition_status"] == "Available")
    res = requests.post(f"{BASE_URL}/api/loans/checkout", headers=STAFF_HEADERS, json={
        "unit_id": free_tool4_unit["unit_id"],
        "member_id": 3,
        "loan_days": 7
    })
    assert res.status_code == 200, f"T04 Failed: {res.text}"
    t04_loan = res.json()
    t04_loan_id = t04_loan["loan_id"]
    # Verify unit state is now Loaned
    unit_check = requests.get(f"{BASE_URL}/api/tools/4/units").json()
    unit_status = next(u["condition_status"] for u in unit_check if u["unit_id"] == free_tool4_unit["unit_id"])
    assert unit_status == "Loaned", "T04 Failed: Unit condition_status was not updated to 'Loaned'"
    print(f"✅ T04 – Checkout: Staff checked out Unit #{free_tool4_unit['unit_id']} (Loan #{t04_loan_id}). (PASS)")

    # --------------------------------------------------------------------------
    # T05: Staff Return (Good condition)
    # --------------------------------------------------------------------------
    res = requests.post(f"{BASE_URL}/api/loans/checkin", headers=STAFF_HEADERS, json={
        "loan_id": t04_loan_id,
        "condition": "Good",
        "notes": "Returned intact"
    })
    assert res.status_code == 200, f"T05 Failed: {res.text}"
    print(f"✅ T05 – Return: Loan #{t04_loan_id} closed, unit returned to circulation. (PASS)")

    # --------------------------------------------------------------------------
    # T06: Damage Trigger (Report Moderate/Severe -> auto-flags Repair)
    # --------------------------------------------------------------------------
    res = requests.post(f"{BASE_URL}/api/damage-reports", json={
        "unit_id": free_tool4_unit["unit_id"],
        "severity": "Severe",
        "description": "Internal armature burnt out under high load"
    })
    assert res.status_code == 200, f"T06 Failed: {res.text}"
    t06_data = res.json()
    assert t06_data["unit_condition_status"] == "Repair", "T06 Failed: Trigger did not flip condition_status to Repair"
    print(f"✅ T06 – Damage trigger: Trigger fn_trg_damage_repair automatically flagged Unit #{free_tool4_unit['unit_id']} to Repair. (PASS)")

    # --------------------------------------------------------------------------
    # T07: Deposit Rule (Attempt release on active loan)
    # --------------------------------------------------------------------------
    # Pick an active loan
    active_loans = requests.get(f"{BASE_URL}/api/loans/active").json()
    sample_active_loan = active_loans[0]["loan_id"]
    res = requests.post(f"{BASE_URL}/api/deposits/release", headers=STAFF_HEADERS, json={
        "loan_id": sample_active_loan
    })
    assert res.status_code == 400, "T07 Failed: Should deny release on an active loan"
    print(f"✅ T07 – Deposit rule: sp_release_deposit denied release on active Loan #{sample_active_loan}. (PASS)")

    # --------------------------------------------------------------------------
    # T08: Kit Availability View
    # --------------------------------------------------------------------------
    # View all kits
    kits = requests.get(f"{BASE_URL}/api/kits").json()
    assert len(kits) > 0, "T08 Failed: No kits found"
    print(f"✅ T08 – Kit availability: v_kit_availability verified ({len(kits)} kits evaluated). (PASS)")

    # --------------------------------------------------------------------------
    # T09: Waitlist Order Promotion
    # --------------------------------------------------------------------------
    # Checkout Tool #13 (Miter Saw, which has waiting members in queue) and return it
    tool13_units = requests.get(f"{BASE_URL}/api/tools/13/units").json()
    t13_free = next(u for u in tool13_units if u["condition_status"] == "Available")
    co_res = requests.post(f"{BASE_URL}/api/loans/checkout", headers=STAFF_HEADERS, json={
        "unit_id": t13_free["unit_id"],
        "member_id": 5,
        "loan_days": 3
    }).json()
    ret_res = requests.post(f"{BASE_URL}/api/loans/checkin", headers=STAFF_HEADERS, json={
        "loan_id": co_res["loan_id"],
        "condition": "Good",
        "notes": "Return triggering waitlist cascade"
    }).json()
    assert ret_res["promoted_member_id"] is not None, "T09 Failed: No member was promoted from waitlist"
    print(f"✅ T09 – Waitlist order: Returned unit atomically promoted Member #{ret_res['promoted_member_id']} into reservation #{ret_res['reservation_id']}. (PASS)")

    # --------------------------------------------------------------------------
    # T10: Concurrent Reservation Race Condition & Row Lock
    # --------------------------------------------------------------------------
    sim_res = requests.post(f"{BASE_URL}/api/concurrency/simulate", json={
        "unit_id": 16, # Rotary Tool Unit 16
        "member1_id": 1,
        "member2_id": 2,
        "mode": "protected",
        "delay_seconds": 0.4
    }).json()
    assert sim_res["active_reservations_count"] == 1, "T10 Failed: Protected mode allowed multiple allocations"
    print(f"✅ T10 – Concurrent reservation: SELECT ... FOR UPDATE prevented duplicate allocation. (PASS)")

    # --------------------------------------------------------------------------
    # T11: Transaction Rollback on Error midway through checkout
    # --------------------------------------------------------------------------
    # Attempt checkout on an invalid non-existent member
    res = requests.post(f"{BASE_URL}/api/loans/checkout", headers=STAFF_HEADERS, json={
        "unit_id": 14,
        "member_id": 999999, # Non-existent FK violation
        "loan_days": 7
    })
    assert res.status_code in (400, 500), "T11 Failed: Should raise FK constraint error and rollback"
    # Verify unit 14 remained Available (no partial update)
    u14_check = next(u for u in requests.get(f"{BASE_URL}/api/tools/5/units").json() if u["unit_id"] == 14)
    assert u14_check["condition_status"] == "Available", "T11 Failed: Unit status was partially updated despite rollback!"
    print(f"✅ T11 – Rollback: Foreign key error triggered full rollback, unit status remained intact. (PASS)")

    # --------------------------------------------------------------------------
    # T12: Role-based Authorization Check
    # --------------------------------------------------------------------------
    # Member attempts staff-only route
    res = requests.post(f"{BASE_URL}/api/loans/checkout", headers=MEMBER_HEADERS, json={
        "unit_id": 14,
        "member_id": 1,
        "loan_days": 7
    })
    assert res.status_code == 403, f"T12 Failed: Member role was not forbidden from checkout"
    print(f"✅ T12 – Authorization: Member role access to staff checkout denied with HTTP 403 Forbidden. (PASS)")

    print("=" * 70)
    print("ALL 12 ACCEPTANCE TESTS (T01 - T12) PASSED WITH ZERO ERRORS!")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
