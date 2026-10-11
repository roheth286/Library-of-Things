-- ==============================================================================
-- DATABASE TRIGGERS, PROCEDURES & VIEWS: LIBRARY OF THINGS
-- BCSE302P - DATABASE SYSTEMS LAB
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TRIGGER: Damage-Triggered Repair Flag
-- Evaluates severity and auto-updates tool_units.condition_status to 'Repair'
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_damage_repair()
RETURNS TRIGGER AS $$
BEGIN
    -- For Moderate or Severe damages, immediately flag unit condition as Repair
    IF NEW.severity IN ('Moderate', 'Severe') THEN
        UPDATE tool_units
        SET condition_status = 'Repair'
        WHERE unit_id = NEW.unit_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_damage_repair_flag ON damage_reports;
CREATE TRIGGER trg_damage_repair_flag
AFTER INSERT ON damage_reports
FOR EACH ROW
EXECUTE FUNCTION fn_trg_damage_repair();

-- ------------------------------------------------------------------------------
-- 2. TRIGGER: Active Loans Count Maintenance
-- Automatically increments/decrements active_loans_count in members table
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_maintain_member_loans()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'Active' THEN
        UPDATE members
        SET active_loans_count = active_loans_count + 1
        WHERE member_id = NEW.member_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status = 'Active' AND NEW.status != 'Active' THEN
            UPDATE members
            SET active_loans_count = GREATEST(0, active_loans_count - 1)
            WHERE member_id = NEW.member_id;
        ELSIF OLD.status != 'Active' AND NEW.status = 'Active' THEN
            UPDATE members
            SET active_loans_count = active_loans_count + 1
            WHERE member_id = NEW.member_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_maintain_member_loans ON loans;
CREATE TRIGGER trg_maintain_member_loans
AFTER INSERT OR UPDATE ON loans
FOR EACH ROW
EXECUTE FUNCTION fn_trg_maintain_member_loans();

-- ------------------------------------------------------------------------------
-- 3. STORED PROCEDURE: Waitlist Cascade on Unit Return
-- On return of a unit:
-- - Checks if any member is waiting for this tool
-- - If found, atomically promotes the top member (position 1)
-- - Creates an active reservation for that member for 48 hours
-- - Flips unit status to 'Reserved' (or 'Available' if no waitlist)
-- - Re-indexes remaining waitlist queue positions
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_return_unit_and_cascade(
    p_loan_id INT,
    p_condition VARCHAR(20),
    p_notes TEXT,
    INOUT p_result_status VARCHAR(50) DEFAULT '',
    INOUT p_promoted_member_id INT DEFAULT NULL,
    INOUT p_new_reservation_id INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_unit_id INT;
    v_tool_id INT;
    v_member_id INT;
    v_waitlist_id INT;
    v_next_member_id INT;
    v_deposit_id INT;
BEGIN
    -- 1. Fetch loan details
    SELECT unit_id, member_id INTO v_unit_id, v_member_id
    FROM loans
    WHERE loan_id = p_loan_id AND status = 'Active';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active loan with ID % not found', p_loan_id;
    END IF;

    SELECT tool_id INTO v_tool_id
    FROM tool_units
    WHERE unit_id = v_unit_id;

    -- 2. Mark loan as Returned
    UPDATE loans
    SET return_date = CURRENT_TIMESTAMP,
        status = 'Returned'
    WHERE loan_id = p_loan_id;

    -- 3. Handle damage report if condition is damaged/repair
    IF p_condition IN ('Moderate', 'Severe', 'Minor') THEN
        INSERT INTO damage_reports(unit_id, loan_id, description, severity)
        VALUES (v_unit_id, p_loan_id, COALESCE(p_notes, 'Reported during return check-in'), p_condition);
        
        -- If Moderate or Severe, the trigger automatically set condition_status to 'Repair'
        IF p_condition IN ('Moderate', 'Severe') THEN
            p_result_status := 'Returned - Unit Flagged For Repair';
            RETURN;
        END IF;
    END IF;

    -- 4. Check Waitlist for this tool
    SELECT waitlist_id, member_id INTO v_waitlist_id, v_next_member_id
    FROM waitlists
    WHERE tool_id = v_tool_id AND status = 'Waiting'
    ORDER BY position ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF v_next_member_id IS NOT NULL THEN
        -- Promote member
        UPDATE waitlists
        SET status = 'Promoted'
        WHERE waitlist_id = v_waitlist_id;

        -- Create 48-hour reservation
        INSERT INTO reservations(unit_id, member_id, reserved_for_date, status, expires_at)
        VALUES (v_unit_id, v_next_member_id, CURRENT_DATE, 'Active', CURRENT_TIMESTAMP + INTERVAL '48 hours')
        RETURNING reservation_id INTO p_new_reservation_id;

        -- Set unit to Reserved
        UPDATE tool_units
        SET condition_status = 'Reserved'
        WHERE unit_id = v_unit_id;

        -- Re-index remaining positions
        UPDATE waitlists w
        SET position = sub.new_pos
        FROM (
            SELECT waitlist_id, ROW_NUMBER() OVER (ORDER BY position ASC) AS new_pos
            FROM waitlists
            WHERE tool_id = v_tool_id AND status = 'Waiting'
        ) sub
        WHERE w.waitlist_id = sub.waitlist_id;

        p_promoted_member_id := v_next_member_id;
        p_result_status := 'Returned - Promoted Member ' || v_next_member_id || ' from Waitlist';
    ELSE
        -- No waitlist; make unit available
        UPDATE tool_units
        SET condition_status = 'Available'
        WHERE unit_id = v_unit_id;

        p_result_status := 'Returned - Unit Now Available';
    END IF;

    -- 5. Auto release deposit if condition is Good / Minor
    IF p_condition NOT IN ('Moderate', 'Severe') THEN
        UPDATE deposits
        SET status = 'Released'
        WHERE loan_id = p_loan_id AND status = 'Held';
    ELSE
        UPDATE deposits
        SET status = 'Forfeited'
        WHERE loan_id = p_loan_id AND status = 'Held';
    END IF;

END;
$$;

-- ------------------------------------------------------------------------------
-- 4. STORED PROCEDURE: Deposit Release Procedure
-- Explicit release check
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_release_deposit(
    p_loan_id INT,
    INOUT p_success BOOLEAN DEFAULT FALSE,
    INOUT p_message TEXT DEFAULT ''
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_has_damage INT;
    v_loan_status VARCHAR(20);
BEGIN
    SELECT status INTO v_loan_status FROM loans WHERE loan_id = p_loan_id;

    IF v_loan_status IS NULL THEN
        p_success := FALSE;
        p_message := 'Loan not found';
        RETURN;
    END IF;

    IF v_loan_status != 'Returned' THEN
        p_success := FALSE;
        p_message := 'Deposit cannot be released: Loan is not yet returned';
        RETURN;
    END IF;

    -- Check if severe/moderate damage exists
    SELECT COUNT(*) INTO v_has_damage
    FROM damage_reports
    WHERE loan_id = p_loan_id AND severity IN ('Moderate', 'Severe');

    IF v_has_damage > 0 THEN
        UPDATE deposits SET status = 'Forfeited' WHERE loan_id = p_loan_id AND status = 'Held';
        p_success := FALSE;
        p_message := 'Deposit forfeited due to recorded damage reports';
    ELSE
        UPDATE deposits SET status = 'Released' WHERE loan_id = p_loan_id AND status = 'Held';
        p_success := TRUE;
        p_message := 'Deposit successfully released';
    END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. DATABASE VIEWS
-- ------------------------------------------------------------------------------

-- View 1: Kit Availability
-- Kit components -> Tools -> Tool units
-- Returns kit as available ONLY if EVERY required component has at least one free unit ('Available')
CREATE OR REPLACE VIEW v_kit_availability AS
WITH component_status AS (
    SELECT 
        kc.kit_id,
        kc.tool_id,
        kc.quantity_required,
        COUNT(tu.unit_id) FILTER (WHERE tu.condition_status = 'Available') AS free_units_count
    FROM kit_components kc
    JOIN tools t ON kc.tool_id = t.tool_id
    LEFT JOIN tool_units tu ON tu.tool_id = t.tool_id
    GROUP BY kc.kit_id, kc.tool_id, kc.quantity_required
),
kit_summary AS (
    SELECT 
        k.kit_id,
        k.name AS kit_name,
        k.description,
        COUNT(cs.tool_id) AS total_components,
        COUNT(CASE WHEN cs.free_units_count >= cs.quantity_required THEN 1 END) AS available_components,
        MIN(cs.free_units_count / cs.quantity_required) AS complete_kits_available
    FROM kits k
    LEFT JOIN component_status cs ON k.kit_id = cs.kit_id
    GROUP BY k.kit_id, k.name, k.description
)
SELECT 
    kit_id,
    kit_name,
    description,
    total_components,
    available_components,
    COALESCE(complete_kits_available, 0) AS complete_kits_available,
    CASE 
        WHEN total_components > 0 AND total_components = available_components THEN TRUE 
        ELSE FALSE 
    END AS is_available
FROM kit_summary;

-- View 2: Live Fleet Status
-- Breakdown per category: total, available, loaned, repair, reserved
CREATE OR REPLACE VIEW v_fleet_status AS
SELECT 
    c.category_id,
    c.name AS category_name,
    COUNT(tu.unit_id) AS total_units,
    COUNT(CASE WHEN tu.condition_status = 'Available' THEN 1 END) AS available_count,
    COUNT(CASE WHEN tu.condition_status = 'Loaned' THEN 1 END) AS loaned_count,
    COUNT(CASE WHEN tu.condition_status = 'Repair' THEN 1 END) AS repair_count,
    COUNT(CASE WHEN tu.condition_status = 'Reserved' THEN 1 END) AS reserved_count
FROM categories c
JOIN tools t ON c.category_id = t.category_id
LEFT JOIN tool_units tu ON t.tool_id = tu.tool_id
GROUP BY c.category_id, c.name
ORDER BY c.name;

-- View 3: Loan Duration Analytics
-- Average loan duration and counts by category
CREATE OR REPLACE VIEW v_loan_duration_analytics AS
SELECT 
    c.category_id,
    c.name AS category_name,
    COUNT(l.loan_id) AS total_loans,
    ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(l.return_date, CURRENT_TIMESTAMP) - l.loan_date)) / 86400)::numeric, 2) AS avg_duration_days
FROM categories c
JOIN tools t ON c.category_id = t.category_id
JOIN tool_units tu ON t.tool_id = tu.tool_id
JOIN loans l ON tu.unit_id = l.unit_id
GROUP BY c.category_id, c.name;

-- View 4: Waitlist Summary
CREATE OR REPLACE VIEW v_waitlist_summary AS
SELECT 
    t.tool_id,
    t.name AS tool_name,
    c.name AS category_name,
    COUNT(w.waitlist_id) AS waiting_members_count
FROM tools t
JOIN categories c ON t.category_id = c.category_id
LEFT JOIN waitlists w ON t.tool_id = w.tool_id AND w.status = 'Waiting'
GROUP BY t.tool_id, t.name, c.name
ORDER BY waiting_members_count DESC, t.name;
