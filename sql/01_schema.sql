-- ==============================================================================
-- DATABASE SCHEMA: LIBRARY OF THINGS (BCSE302P)
-- TEAM:
--   PRASANTH S - 24BCE2023
--   ROHETH - 24BCT0277
-- ==============================================================================

-- Drop existing tables/types in reverse dependency order
DROP VIEW IF EXISTS v_kit_availability CASCADE;
DROP VIEW IF EXISTS v_fleet_status CASCADE;
DROP VIEW IF EXISTS v_loan_duration_analytics CASCADE;
DROP VIEW IF EXISTS v_waitlist_summary CASCADE;

DROP TABLE IF EXISTS kit_components CASCADE;
DROP TABLE IF EXISTS kits CASCADE;
DROP TABLE IF EXISTS deposits CASCADE;
DROP TABLE IF EXISTS damage_reports CASCADE;
DROP TABLE IF EXISTS waitlists CASCADE;
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS loans CASCADE;
DROP TABLE IF EXISTS tool_units CASCADE;
DROP TABLE IF EXISTS tools CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS members CASCADE;

-- 1. MEMBERS TABLE
CREATE TABLE members (
    member_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    contact VARCHAR(100) NOT NULL UNIQUE,
    join_date DATE NOT NULL DEFAULT CURRENT_DATE,
    active_loans_count INT NOT NULL DEFAULT 0 CHECK (active_loans_count >= 0)
);

-- 2. CATEGORIES TABLE
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- 3. TOOLS TABLE
CREATE TABLE tools (
    tool_id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    category_id INT NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    description TEXT,
    deposit_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (deposit_amount >= 0)
);

-- 4. TOOL_UNITS (Weak entity dependent on tools)
-- Condition status: 'Available', 'Reserved', 'Loaned', 'Repair'
CREATE TABLE tool_units (
    unit_id SERIAL PRIMARY KEY,
    tool_id INT NOT NULL REFERENCES tools(tool_id) ON DELETE CASCADE,
    condition_status VARCHAR(20) NOT NULL DEFAULT 'Available' 
        CHECK (condition_status IN ('Available', 'Reserved', 'Loaned', 'Repair')),
    serial_no VARCHAR(100) NOT NULL UNIQUE
);

-- 5. LOANS TABLE
-- Status: 'Active', 'Returned', 'Overdue'
CREATE TABLE loans (
    loan_id SERIAL PRIMARY KEY,
    unit_id INT NOT NULL REFERENCES tool_units(unit_id) ON DELETE RESTRICT,
    member_id INT NOT NULL REFERENCES members(member_id) ON DELETE RESTRICT,
    loan_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    return_date TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL DEFAULT 'Active'
        CHECK (status IN ('Active', 'Returned', 'Overdue'))
);

-- 6. RESERVATIONS TABLE
-- Status: 'Active', 'Fulfilled', 'Cancelled', 'Expired'
CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    unit_id INT NOT NULL REFERENCES tool_units(unit_id) ON DELETE CASCADE,
    member_id INT NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    reserved_for_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Active'
        CHECK (status IN ('Active', 'Fulfilled', 'Cancelled', 'Expired')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- 7. WAITLISTS TABLE
-- Position tracks queue order for a tool type
CREATE TABLE waitlists (
    waitlist_id SERIAL PRIMARY KEY,
    tool_id INT NOT NULL REFERENCES tools(tool_id) ON DELETE CASCADE,
    member_id INT NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    position INT NOT NULL CHECK (position > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'Waiting' 
        CHECK (status IN ('Waiting', 'Promoted', 'Cancelled')),
    CONSTRAINT uq_tool_member_active UNIQUE (tool_id, member_id, status)
);

-- 8. DAMAGE_REPORTS TABLE
-- Severity: 'Minor', 'Moderate', 'Severe'
CREATE TABLE damage_reports (
    report_id SERIAL PRIMARY KEY,
    unit_id INT NOT NULL REFERENCES tool_units(unit_id) ON DELETE RESTRICT,
    loan_id INT REFERENCES loans(loan_id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    reported_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('Minor', 'Moderate', 'Severe'))
);

-- 9. DEPOSITS TABLE
-- Status: 'Held', 'Released', 'Forfeited'
CREATE TABLE deposits (
    deposit_id SERIAL PRIMARY KEY,
    loan_id INT NOT NULL REFERENCES loans(loan_id) ON DELETE RESTRICT,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'Held'
        CHECK (status IN ('Held', 'Released', 'Forfeited'))
);

-- 10. KITS TABLE
CREATE TABLE kits (
    kit_id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE,
    description TEXT
);

-- 11. KIT_COMPONENTS (Bridge table)
CREATE TABLE kit_components (
    kit_id INT NOT NULL REFERENCES kits(kit_id) ON DELETE CASCADE,
    tool_id INT NOT NULL REFERENCES tools(tool_id) ON DELETE RESTRICT,
    quantity_required INT NOT NULL DEFAULT 1 CHECK (quantity_required > 0),
    PRIMARY KEY (kit_id, tool_id)
);

-- Create helpful indexes for performance & fast lookups
CREATE INDEX idx_tool_units_tool_id ON tool_units(tool_id);
CREATE INDEX idx_tool_units_status ON tool_units(condition_status);
CREATE INDEX idx_loans_active ON loans(unit_id, status);
CREATE INDEX idx_waitlists_tool_pos ON waitlists(tool_id, position) WHERE status = 'Waiting';
CREATE INDEX idx_reservations_unit ON reservations(unit_id, status);
