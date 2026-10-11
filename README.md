# Library of Things - Database-Driven Lending & Reservation System
**Database Systems Lab (BCSE302P)**

### Team Members
- **PRASANTH S** - 24BCE2023
- **ARNADEEP SAHA** - 24BCE0760
- **ROHETH** - 24BCT0277

---

## 1. Tech Stack
- **Database:** PostgreSQL 16 (Running on Docker, Port 5433)
- **Backend:** FastAPI (Python 3.13)
- **Frontend:** Responsive Vanilla HTML5, CSS3, JavaScript (Dashboard + Staff Circulation + Live Expo Concurrency Simulation)

---

## 2. Relational Schema & Normalization (3NF)
- **`members`**: Member profile, join date, contact, and dynamically maintained `active_loans_count`.
- **`categories`**: Tool classification categories (Power Tools, Gardening, Woodworking, Automotive, Painting, Cleaning).
- **`tools`**: Conceptual tool entity with deposit requirements and descriptions.
- **`tool_units`**: Weak entity dependent on `tools`. Models physical, individually trackable units with `serial_no` and `condition_status` (`Available`, `Reserved`, `Loaned`, `Repair`).
- **`loans`**: Checkout records with `loan_date`, `due_date`, `return_date`, and status tracking.
- **`reservations`**: Unit-level time-bound reservations with automatic 48-hour expiration.
- **`waitlists`**: Priority queue (`position` ASC) per tool when all physical units are exhausted.
- **`damage_reports`**: Damage incident tracking that automatically fires triggers.
- **`deposits`**: Security deposit lifecycle (`Held`, `Released`, `Forfeited`).
- **`kits` & `kit_components`**: Bundles requiring complete physical tool availability.

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
