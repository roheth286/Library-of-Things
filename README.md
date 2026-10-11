# Library of Things - Database-Driven Lending & Reservation System
**Database Systems Lab (BCSE302P)**

### Team Members
- **PRASANTH S** - 24BCE2023
- **ROHETH** - 24BCT0277

---

## 1. Tech Stack
- **Database:** PostgreSQL 16 (Running on Docker, Port 5433)
- **Backend:** FastAPI (Python 3.13)
- **Frontend:** Responsive Vanilla HTML5, CSS3, JavaScript (Dashboard + Staff Circulation + Live Expo Concurrency Simulation)

---

## 3. Innovation Proposal and Societal Impact
### 3.1 Proposed Solution
**CircuLend** combines a lightweight web interface with a high-integrity PostgreSQL database. The database is the authoritative source for availability and lending state; the application is a thin layer for user actions and staff workflows.

### 3.2 Novelty and Differentiating Features
- **Unit-level inventory:** Each physical item has its own unit record, status, serial number, and condition.
- **Kit-aware availability:** A kit is available only when every required component has a free unit.
- **Transactional waitlist cascade:** A returned unit triggers promotion of the next eligible member within a single ACID transaction.
- **Damage-triggered repair flag:** Inserting a sufficiently severe damage report automatically marks the unit for repair via a PostgreSQL trigger without application code.
- **Rule-based deposit release:** Release is allowed only after the return-condition check passes and the loan is closed.
- **Concurrency demonstration:** Simultaneous reservation attempts are tested and the safe implementation uses row locking (`SELECT ... FOR UPDATE`) or `SERIALIZABLE` isolation.
- **Operational analytics:** Category-level fleet status, deposit holds, waitlist lengths, and average loan duration.

---

## 4. Software Requirements
### 4.1 Functional Requirements Matrix
| ID | Requirement | Implementation in CircuLend |
|---|---|---|
| **FR-01** | Users can browse tools by category and view unit-level availability | `GET /api/tools?category_id=...` & `GET /api/tools/{id}/units` |
| **FR-02** | A member can reserve a specific eligible unit or request next available unit | `POST /api/reservations` with row-lock check |
| **FR-03** | Staff can check out an available unit, creating loan record & changing state | `POST /api/loans/checkout` (`condition_status = 'Loaned'`) |
| **FR-04** | Staff can process a return, close active loan, and record condition checks | `POST /api/loans/checkin` executing `sp_return_unit_and_cascade` |
| **FR-05** | Members can join waitlist for a tool type; system maintains ordered queue | `POST /api/waitlists` with sequential position numbering |
| **FR-06** | Staff can record damage against a unit/loan; severe damage auto-flags repair | `POST /api/damage-reports` firing `trg_damage_repair_flag` |
| **FR-07** | System records deposits and applies defined release conditions | `POST /api/deposits/release` executing `sp_release_deposit` |
| **FR-08** | System reports kit availability only when all required components are available | SQL View `v_kit_availability` |
| **FR-09** | Dashboard reports fleet status, deposit holds, waitlist length, analytics | SQL Views `v_fleet_status`, `v_waitlist_summary`, `v_loan_duration_analytics` |
| **FR-10** | Concurrent reservation requests cannot allocate the same unit twice | Pessimistic Locking (`SELECT ... FOR UPDATE`) |
| **FR-11** | Role-based access distinguishes member actions from staff/admin actions | Role check middleware enforcing `X-User-Role: staff` on circulation routes |

---

## 5. Acceptance Test Matrix (T01 – T12)
All 12 official test scenarios are codified and automated in [`tests/test_acceptance_t01_t12.py`](file:///c:/Users/tanvi/Downloads/DBMS_LAB_PROJECT/tests/test_acceptance_t01_t12.py):

| ID / Scenario | Test Action | Expected Result | Actual Result | Status |
|---|---|---|---|---|
| **T01 – Browse** | Request tools by category | Correct tools and current unit availability returned | Returned 6 tools with unit counts | **PASS** |
| **T02 – Successful reservation** | Reserve an eligible free unit | One active reservation created; unit state consistent | Created reservation; unit marked Reserved | **PASS** |
| **T03 – Unavailable unit** | Reserve unit already loaned/reserved | Request is rejected; no duplicate allocation | Rejected with HTTP 400 Bad Request | **PASS** |
| **T04 – Checkout** | Staff checks out available unit | Loan row created; unit becomes Loaned atomically | Loan created; unit condition_status = 'Loaned' | **PASS** |
| **T05 – Return** | Staff returns active loan in good condition | Loan closes; unit becomes Available | Loan closed; return timestamp recorded | **PASS** |
| **T06 – Damage trigger** | Insert report above repair threshold | Unit condition_status becomes Repair automatically | Trigger set unit status to Repair | **PASS** |
| **T07 – Deposit rule** | Attempt release before checks/return | Release is denied; deposit remains held | Denied by `sp_release_deposit` | **PASS** |
| **T08 – Kit availability** | Verify kit component query | Kit reported unavailable if component missing | `v_kit_availability` verified accurately | **PASS** |
| **T09 – Waitlist order** | Return unit with multiple queued members | Oldest eligible entry promoted exactly once | Member promoted into active reservation | **PASS** |
| **T10 – Concurrent reservation** | Send two simultaneous requests for same unit | At most one succeeds under row locking | Exactly 1 succeeded; 2nd cleanly rejected | **PASS** |
| **T11 – Rollback** | Force error midway through checkout | No partial loan/status update remains | DB rolled back completely | **PASS** |
| **T12 – Authorization** | Member attempts staff-only checkout | Request denied; DB remains unchanged | Denied with HTTP 403 Forbidden | **PASS** |

---

## 3. Database Features Implemented

### Triggers (`sql/02_triggers_procedures.sql`)
1. **`trg_damage_repair_flag` (Damage-Triggered Repair):**
   - Automatically fired on `INSERT` into `damage_reports`.
   - If `severity IN ('Moderate', 'Severe')`, it automatically executes `UPDATE tool_units SET condition_status = 'Repair'`.
2. **`trg_maintain_member_loans` (Active Loan Count):**
   - Automatically maintains `members.active_loans_count` upon loan creation or return.

### Stored Procedures
1. **`sp_return_unit_and_cascade` (Atomic Return & Waitlist Cascade):**
   - Atomically closes active loan and sets return timestamp.
   - Evaluates damage conditions and updates deposit status.
   - Checks `waitlists` queue for the returned tool.
   - If a member is waiting, atomically promotes position #1, creates a 48-hour reservation, sets unit to `Reserved`, and re-indexes remaining queue positions.
2. **`sp_release_deposit`:**
   - Validates return status and damage logs before releasing deposit.

### Analytical SQL Views
1. **`v_kit_availability`**: Joins `kits` → `kit_components` → `tools` → `tool_units` and calculates complete kits available, marking `is_available` true ONLY if every component has at least one free unit.
2. **`v_fleet_status`**: Real-time breakdown of units (`Available`, `Loaned`, `Repair`, `Reserved`) by category.
3. **`v_loan_duration_analytics`**: Average loan duration by tool category.
4. **`v_waitlist_summary`**: Waiting queue counts per tool.

---

## 4. Concurrency & Transaction Isolation (Phase 3 Expo Demonstration)
- **Unprotected Mode:** Demonstrates race condition / double-booking vulnerability under concurrent requests when checking status without locks. Both transactions read `Available`, insert active reservations, and corrupt data (2 active reservations for 1 physical unit).
- **Protected Mode:** Demonstrates the fix using **pessimistic row locking (`SELECT ... FOR UPDATE`)**. The second transaction blocks until the first transaction completes, detects that the unit status changed to `Reserved`, and safely rejects the duplicate reservation.

---

## 5. How to Run the Project

### Prerequisites
- Docker (already running PostgreSQL container `library_of_things_db` on port 5433)
- Python 3.10+

### Starting the Server
```powershell
python -m uvicorn backend.main:app --host 127.0.0.1 --port 8080
```
Open your browser at: **`http://localhost:8080`**

### Running the Test Suite
```powershell
python tests/test_system.py
```
