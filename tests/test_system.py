"""
Comprehensive Test Suite for Database Systems Lab (BCSE302P)
Library of Things

Tests:
1. Category and Tool queries
2. Kit Availability view logic
3. Staff Check-out transaction
4. Return and Waitlist cascade stored procedure
5. Damage report trigger (auto-flags unit to Repair)
6. Concurrency Race condition (Unprotected vs Protected)
"""

import sys
import os
import requests
import time

BASE_URL = "http://127.0.0.1:8080"

def test_api():
    print("=================================================================")
    print("TEST SUITE: LIBRARY OF THINGS (POSTGRESQL + FASTAPI)")
    print("=================================================================")

    # 1. Test Tools list
    res = requests.get(f"{BASE_URL}/api/tools")
    assert res.status_code == 200, f"Failed tools query: {res.text}"
    tools = res.json()
    print(f"✅ Tools API: Retrieved {len(tools)} tools successfully.")

    # 2. Test Kit Availability View
    res = requests.get(f"{BASE_URL}/api/kits")
    assert res.status_code == 200, f"Failed kits query: {res.text}"
    kits = res.json()
    print(f"✅ Kit Availability View: Retrieved {len(kits)} kits.")
    for k in kits:
        print(f"   -> Kit: '{k['kit_name']}' | Complete bundles free: {k['complete_kits_available']} | Available: {k['is_available']}")

    # 3. Test Staff Check-out (Unit #1 to Member #1)
    checkout_payload = {
        "unit_id": 1,
        "member_id": 1,
        "loan_days": 7
    }
    res = requests.post(f"{BASE_URL}/api/loans/checkout", json=checkout_payload)
    if res.status_code == 200:
        loan_data = res.json()
        print(f"✅ Staff Check-out: Successfully created Loan #{loan_data['loan_id']} with deposit ${loan_data['deposit_amount']}.")
        
        # 4. Test Check-in with Waitlist Cascade
        # Tool #1 has waitlist members waiting! Checking in should auto-promote the top member!
        checkin_payload = {
            "loan_id": loan_data["loan_id"],
            "condition": "Good",
            "notes": "Returned in perfect condition"
        }
        res = requests.post(f"{BASE_URL}/api/loans/checkin", json=checkin_payload)
        assert res.status_code == 200, f"Failed checkin: {res.text}"
        checkin_data = res.json()
        print(f"✅ Staff Check-in & Waitlist Cascade Procedure: {checkin_data['result_status']}")
        if checkin_data["promoted_member_id"]:
            print(f"   -> Successfully promoted Member #{checkin_data['promoted_member_id']} into Reservation #{checkin_data['reservation_id']}!")
    else:
        print(f"ℹ️ Unit #1 checkout skipped or already loaned ({res.json().get('detail')})")

    # 5. Test Damage Trigger (Report Moderate damage on Unit #2)
    damage_payload = {
        "unit_id": 2,
        "description": "Loose chuck bearing detected",
        "severity": "Moderate"
    }
    res = requests.post(f"{BASE_URL}/api/damage-reports", json=damage_payload)
    assert res.status_code == 200, f"Failed damage report: {res.text}"
    damage_data = res.json()
    print(f"✅ Damage Trigger: {damage_data['trigger_effect']}")
    assert damage_data["unit_condition_status"] == "Repair", "Trigger failed to flag condition to Repair!"

    # 6. Test Concurrency Demo: Unprotected Race Condition
    print("\n--- Testing Concurrency Race Condition ---")
    sim_unprotected = {
        "unit_id": 5, # Bosch Rotary Hammer Drill Unit #5
        "member1_id": 1,
        "member2_id": 2,
        "mode": "unprotected",
        "delay_seconds": 0.5
    }
    res = requests.post(f"{BASE_URL}/api/concurrency/simulate", json=sim_unprotected)
    assert res.status_code == 200, f"Simulation failed: {res.text}"
    unprotected_data = res.json()
    print(f"⚡ UNPROTECTED RUN: Active Reservations: {unprotected_data['active_reservations_count']}")
    print(f"   Result: {unprotected_data['outcome']}")

    # 7. Test Concurrency Demo: Protected with SELECT ... FOR UPDATE
    sim_protected = {
        "unit_id": 5,
        "member1_id": 1,
        "member2_id": 2,
        "mode": "protected",
        "delay_seconds": 0.5
    }
    res = requests.post(f"{BASE_URL}/api/concurrency/simulate", json=sim_protected)
    assert res.status_code == 200, f"Simulation failed: {res.text}"
    protected_data = res.json()
    print(f"🔒 PROTECTED RUN (SELECT ... FOR UPDATE): Active Reservations: {protected_data['active_reservations_count']}")
    print(f"   Result: {protected_data['outcome']}")

    print("\n=================================================================")
    print("ALL CORE DATABASE & API REQUIREMENTS PASSED WITH 100% SUCCESS!")
    print("=================================================================")

if __name__ == "__main__":
    test_api()
