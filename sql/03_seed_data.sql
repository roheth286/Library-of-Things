-- ==============================================================================
-- REALISTIC SEED DATA: LIBRARY OF THINGS (BCSE302P)
-- ~50 Members, ~30 Tools, ~80 Physical Units, Realistic Loans & Kits
-- ==============================================================================

-- 1. CATEGORIES (6 Categories)
INSERT INTO categories (category_id, name) VALUES
(1, 'Power Tools'),
(2, 'Gardening & Landscaping'),
(3, 'Woodworking & Carpentry'),
(4, 'Automotive & Mechanical'),
(5, 'Painting & Decorating'),
(6, 'Cleaning & Home Maintenance')
ON CONFLICT (category_id) DO NOTHING;

-- 2. TOOLS (~30 Tools across 6 categories)
INSERT INTO tools (tool_id, name, category_id, description, deposit_amount) VALUES
-- Power Tools
(1, 'DeWalt 20V Cordless Drill', 1, 'Brushless compact drill/driver with 2-speed transmission', 30.00),
(2, 'Bosch Rotary Hammer Drill', 1, 'Heavy duty SDS-plus rotary hammer for masonry and concrete', 50.00),
(3, 'Makita Circular Saw 7-1/4"', 1, 'High precision 15-amp circular saw with electric brake', 40.00),
(4, 'Milwaukee M18 Cordless Jigsaw', 1, 'Variable speed orbital jigsaw with keyless blade clamp', 35.00),
(5, 'Dremel 4300 Rotary Tool Kit', 1, 'High performance rotary tool with LED light and accessories', 25.00),
(6, 'Ryobi Reciprocating Saw', 1, 'Heavy duty demolition saw with anti-vibration handle', 30.00),

-- Gardening & Landscaping
(7, 'Honda Gas Lawn Mower', 2, '21-inch self-propelled lawn mower with micro-cut twin blades', 80.00),
(8, 'Stihl Electric Hedge Trimmer', 2, '24-inch double-sided laser-cut hedge trimmer', 35.00),
(9, 'Husqvarna Leaf Blower 125B', 2, 'Handheld lightweight gas blower with smart start', 40.00),
(10, 'Fiskars Telescopic Pole Saw', 2, 'Extendable tree pruner up to 16 feet with rope-free action', 20.00),
(11, 'Post Hole Digger & Augers', 2, 'Heavy duty steel manual auger for fencing and post holes', 20.00),
(12, 'Wheelbarrow Heavy Duty 6 cu ft', 2, 'Dual wheel contractor grade poly wheelbarrow', 25.00),

-- Woodworking & Carpentry
(13, 'DeWalt 12" Sliding Compound Miter Saw', 3, 'Double bevel compound miter saw with cutline indicator', 90.00),
(14, 'Porter-Cable Plate Joiner (Biscuit)', 3, 'Heavy duty 7-amp biscuit joiner with 7-position depth stop', 30.00),
(15, 'Bosch Plunge & Fixed-Base Router', 3, '2.25 HP electronic variable speed router combo kit', 45.00),
(16, 'Ridgid Oscillating Belt/Spindle Sander', 3, 'Stationary sander for curves and straight edge sanding', 40.00),
(17, 'Bostitch Brad Nailer Kit 18GA', 3, 'Pneumatic brad nailer with tool-free depth adjustment', 25.00),
(18, 'Kreg Pocket Hole Jig K4', 3, 'Precision clamping jig for strong face-frame joints', 20.00),

-- Automotive & Mechanical
(19, '3-Ton Hydraulic Floor Jack & Stands', 4, 'Heavy duty steel hydraulic service jack with dual stands', 45.00),
(20, 'Tekton 1/2" Torque Wrench (10-150 ft-lb)', 4, 'Click torque wrench with reversible 72-tooth ratchet', 25.00),
(21, 'OBD2 Vehicle Diagnostic Scanner', 4, 'Full system Bluetooth code reader with live sensor data', 30.00),
(22, 'Battery Charger & Engine Starter', 4, '12V fully automatic smart battery maintainer and jump starter', 35.00),
(23, 'Brake Caliper Compression Tool Set', 4, 'Universal disc brake caliper pad piston compressor kit', 20.00),

-- Painting & Decorating
(24, 'Graco Magnum X5 Airless Paint Sprayer', 5, 'High-pressure airless sprayer for walls, fences, and ceilings', 70.00),
(25, 'Wagner Heat Gun 1200W', 5, 'Dual temperature heat gun for paint stripping and vinyl wraps', 15.00),
(26, 'Werner 6-ft Fiberglass Stepladder', 5, 'Type IA 300-lb duty rating multi-use stepladder', 25.00),
(27, 'Wallpaper Steamer & Scraper Kit', 5, 'Electric wallpaper stripper with extra-large steam plate', 20.00),

-- Cleaning & Maintenance
(28, 'Karcher 2000 PSI Pressure Washer', 6, 'Electric cold water pressure washer with dirt blaster spray wand', 50.00),
(29, 'Bissell Little Green Carpet Cleaner', 6, 'Portable deep cleaner for spots, stairs, and upholstery', 30.00),
(30, 'Rigid 12-Gallon Wet/Dry Shop Vacuum', 6, 'High-power shop vac with blower port and fine dust filter', 30.00)
ON CONFLICT (tool_id) DO NOTHING;

-- Reset sequences
SELECT setval('categories_category_id_seq', (SELECT MAX(category_id) FROM categories));
SELECT setval('tools_tool_id_seq', (SELECT MAX(tool_id) FROM tools));

-- 3. MEMBERS (50 Realistic Members)
INSERT INTO members (member_id, name, contact, join_date) VALUES
(1, 'Aarav Sharma', 'aarav.sharma@example.com', '2025-01-15'),
(2, 'Aditi Patel', 'aditi.patel@example.com', '2025-01-20'),
(3, 'Akash Verma', 'akash.verma@example.com', '2025-02-01'),
(4, 'Ananya Iyer', 'ananya.iyer@example.com', '2025-02-05'),
(5, 'Arjun Reddy', 'arjun.reddy@example.com', '2025-02-12'),
(6, 'Bhavna Joshi', 'bhavna.joshi@example.com', '2025-02-18'),
(7, 'Chetan Desai', 'chetan.desai@example.com', '2025-03-01'),
(8, 'Deepak Nair', 'deepak.nair@example.com', '2025-03-05'),
(9, 'Divya Pillai', 'divya.pillai@example.com', '2025-03-10'),
(10, 'Gautam Menon', 'gautam.menon@example.com', '2025-03-15'),
(11, 'Harish Kulkarni', 'harish.k@example.com', '2025-03-22'),
(12, 'Ishita Sen', 'ishita.sen@example.com', '2025-04-01'),
(13, 'Jatin Malhotra', 'jatin.m@example.com', '2025-04-05'),
(14, 'Kavita Rao', 'kavita.rao@example.com', '2025-04-12'),
(15, 'Kunal Kapoor', 'kunal.k@example.com', '2025-04-18'),
(16, 'Lakshmi Narayanan', 'lakshmi.n@example.com', '2025-05-01'),
(17, 'Manish Chawla', 'manish.c@example.com', '2025-05-08'),
(18, 'Meera Nambiar', 'meera.n@example.com', '2025-05-15'),
(19, 'Naveen Kumar', 'naveen.k@example.com', '2025-05-20'),
(20, 'Neha Singhania', 'neha.s@example.com', '2025-05-28'),
(21, 'Nikhil Bhatt', 'nikhil.b@example.com', '2025-06-02'),
(22, 'Pallavi Swaminathan', 'pallavi.s@example.com', '2025-06-10'),
(23, 'Pooja Hegde', 'pooja.h@example.com', '2025-06-14'),
(24, 'Pranav Venkatesh', 'pranav.v@example.com', '2025-06-20'),
(25, 'Priyanka Mukherjee', 'priyanka.m@example.com', '2025-07-01'),
(26, 'Rahul Ganguly', 'rahul.g@example.com', '2025-07-08'),
(27, 'Rakesh Tiwari', 'rakesh.t@example.com', '2025-07-15'),
(28, 'Rani George', 'rani.george@example.com', '2025-07-22'),
(29, 'Rohan Bansal', 'rohan.bansal@example.com', '2025-08-01'),
(30, 'Rupa Sundaram', 'rupa.s@example.com', '2025-08-09'),
(31, 'Sachin Tendulkar', 'sachin.t@example.com', '2025-08-14'),
(32, 'Samir Dutta', 'samir.dutta@example.com', '2025-08-20'),
(33, 'Sangeeta Das', 'sangeeta.das@example.com', '2025-08-27'),
(34, 'Sanjay Saxena', 'sanjay.s@example.com', '2025-09-02'),
(35, 'Shalini Mishra', 'shalini.m@example.com', '2025-09-10'),
(36, 'Shashank Prabhu', 'shashank.p@example.com', '2025-09-18'),
(37, 'Shreya Ghoshal', 'shreya.g@example.com', '2025-09-24'),
(38, 'Siddharth Roy', 'siddharth.r@example.com', '2025-10-01'),
(39, 'Sneha Krishnan', 'sneha.k@example.com', '2025-10-05'),
(40, 'Sourabh Jain', 'sourabh.j@example.com', '2025-10-12'),
(41, 'Sudhir Agarwal', 'sudhir.a@example.com', '2025-10-20'),
(42, 'Sunita Bhattacharya', 'sunita.b@example.com', '2025-10-28'),
(43, 'Suresh Raina', 'suresh.r@example.com', '2025-11-03'),
(44, 'Swati Deshmukh', 'swati.d@example.com', '2025-11-10'),
(45, 'Tanvi Sethi', 'tanvi.sethi@example.com', '2025-11-18'),
(46, 'Tarun Mohan', 'tarun.m@example.com', '2025-11-25'),
(47, 'Uma Maheshwari', 'uma.m@example.com', '2025-12-02'),
(48, 'Varun Dhawan', 'varun.d@example.com', '2025-12-10'),
(49, 'Vidya Balan', 'vidya.b@example.com', '2025-12-18'),
(50, 'Vikram Sarabhai', 'vikram.s@example.com', '2025-12-25')
ON CONFLICT (member_id) DO NOTHING;

SELECT setval('members_member_id_seq', (SELECT MAX(member_id) FROM members));

-- 4. TOOL_UNITS (~85 Units across 30 tools)
INSERT INTO tool_units (unit_id, tool_id, condition_status, serial_no) VALUES
-- Drill #1
(1, 1, 'Available', 'SN-DWT-CD-001'),
(2, 1, 'Available', 'SN-DWT-CD-002'),
(3, 1, 'Loaned',    'SN-DWT-CD-003'),
(4, 1, 'Repair',    'SN-DWT-CD-004'),
-- Hammer Drill #2
(5, 2, 'Available', 'SN-BOS-RH-001'),
(6, 2, 'Available', 'SN-BOS-RH-002'),
(7, 2, 'Loaned',    'SN-BOS-RH-003'),
-- Circular Saw #3
(8, 3, 'Available', 'SN-MAK-CS-001'),
(9, 3, 'Loaned',    'SN-MAK-CS-002'),
(10, 3, 'Repair',   'SN-MAK-CS-003'),
-- Jigsaw #4
(11, 4, 'Available', 'SN-MIL-JS-001'),
(12, 4, 'Available', 'SN-MIL-JS-002'),
(13, 4, 'Loaned',    'SN-MIL-JS-003'),
-- Rotary Tool #5
(14, 5, 'Available', 'SN-DRE-RT-001'),
(15, 5, 'Available', 'SN-DRE-RT-002'),
(16, 5, 'Available', 'SN-DRE-RT-003'),
-- Reciprocating Saw #6
(17, 6, 'Available', 'SN-RYO-RS-001'),
(18, 6, 'Loaned',    'SN-RYO-RS-002'),
-- Lawn Mower #7
(19, 7, 'Available', 'SN-HON-LM-001'),
(20, 7, 'Loaned',    'SN-HON-LM-002'),
-- Hedge Trimmer #8
(21, 8, 'Available', 'SN-STI-HT-001'),
(22, 8, 'Available', 'SN-STI-HT-002'),
(23, 8, 'Loaned',    'SN-STI-HT-003'),
-- Leaf Blower #9
(24, 9, 'Available', 'SN-HUS-LB-001'),
(25, 9, 'Available', 'SN-HUS-LB-002'),
(26, 9, 'Loaned',    'SN-HUS-LB-003'),
-- Pole Saw #10
(27, 10, 'Available', 'SN-FIS-PS-001'),
(28, 10, 'Available', 'SN-FIS-PS-002'),
-- Post Hole Digger #11
(29, 11, 'Available', 'SN-AUG-PH-001'),
(30, 11, 'Loaned',    'SN-AUG-PH-002'),
-- Wheelbarrow #12
(31, 12, 'Available', 'SN-WB-HD-001'),
(32, 12, 'Available', 'SN-WB-HD-002'),
(33, 12, 'Loaned',    'SN-WB-HD-003'),
-- Miter Saw #13
(34, 13, 'Available', 'SN-DWT-MS-001'),
(35, 13, 'Loaned',    'SN-DWT-MS-002'),
(36, 13, 'Repair',    'SN-DWT-MS-003'),
-- Biscuit Joiner #14
(37, 14, 'Available', 'SN-POR-BJ-001'),
(38, 14, 'Available', 'SN-POR-BJ-002'),
-- Plunge Router #15
(39, 15, 'Available', 'SN-BOS-PR-001'),
(40, 15, 'Loaned',    'SN-BOS-PR-002'),
-- Belt/Spindle Sander #16
(41, 16, 'Available', 'SN-RID-BS-001'),
(42, 16, 'Available', 'SN-RID-BS-002'),
(43, 16, 'Loaned',    'SN-RID-BS-003'),
-- Brad Nailer #17
(44, 17, 'Available', 'SN-BOS-BN-001'),
(45, 17, 'Available', 'SN-BOS-BN-002'),
(46, 17, 'Loaned',    'SN-BOS-BN-003'),
-- Pocket Hole Jig #18
(47, 18, 'Available', 'SN-KRG-PH-001'),
(48, 18, 'Available', 'SN-KRG-PH-002'),
(49, 18, 'Available', 'SN-KRG-PH-003'),
-- Hydraulic Floor Jack #19
(50, 19, 'Available', 'SN-JAK-3T-001'),
(51, 19, 'Available', 'SN-JAK-3T-002'),
(52, 19, 'Loaned',    'SN-JAK-3T-003'),
-- Torque Wrench #20
(53, 20, 'Available', 'SN-TEK-TW-001'),
(54, 20, 'Available', 'SN-TEK-TW-002'),
(55, 20, 'Loaned',    'SN-TEK-TW-003'),
-- OBD2 Scanner #21
(56, 21, 'Available', 'SN-OBD-SC-001'),
(57, 21, 'Available', 'SN-OBD-SC-002'),
(58, 21, 'Loaned',    'SN-OBD-SC-003'),
-- Battery Charger #22
(59, 22, 'Available', 'SN-BAT-CH-001'),
(60, 22, 'Available', 'SN-BAT-CH-002'),
-- Brake Caliper Compressor #23
(61, 23, 'Available', 'SN-BRK-CP-001'),
(62, 23, 'Available', 'SN-BRK-CP-002'),
-- Paint Sprayer #24
(63, 24, 'Available', 'SN-GRA-PS-001'),
(64, 24, 'Loaned',    'SN-GRA-PS-002'),
(65, 24, 'Repair',    'SN-GRA-PS-003'),
-- Heat Gun #25
(66, 25, 'Available', 'SN-WAG-HG-001'),
(67, 25, 'Available', 'SN-WAG-HG-002'),
(68, 25, 'Loaned',    'SN-WAG-HG-003'),
-- Stepladder #26
(69, 26, 'Available', 'SN-WER-SL-001'),
(70, 26, 'Available', 'SN-WER-SL-002'),
(71, 26, 'Loaned',    'SN-WER-SL-003'),
-- Wallpaper Steamer #27
(72, 27, 'Available', 'SN-WAL-ST-001'),
(73, 27, 'Available', 'SN-WAL-ST-002'),
-- Pressure Washer #28
(74, 28, 'Available', 'SN-KAR-PW-001'),
(75, 28, 'Available', 'SN-KAR-PW-002'),
(76, 28, 'Loaned',    'SN-KAR-PW-003'),
-- Carpet Cleaner #29
(77, 29, 'Available', 'SN-BIS-CC-001'),
(78, 29, 'Loaned',    'SN-BIS-CC-002'),
-- Shop Vacuum #30
(79, 30, 'Available', 'SN-RIG-SV-001'),
(80, 30, 'Available', 'SN-RIG-SV-002'),
(81, 30, 'Loaned',    'SN-RIG-SV-003')
ON CONFLICT (unit_id) DO NOTHING;

SELECT setval('tool_units_unit_id_seq', (SELECT MAX(unit_id) FROM tool_units));

-- 5. KITS & KIT COMPONENTS
INSERT INTO kits (kit_id, name, description) VALUES
(1, 'Master Woodworking Kit', 'Complete package for fine carpentry and joint making'),
(2, 'Automotive Brake & Service Kit', 'Essential tools for brake changes, tire service, and diagnostics'),
(3, 'Exterior House & Yard Care Kit', 'Power equipment bundle for yard cleanup and exterior pressure washing'),
(4, 'Complete Room Painting Kit', 'Everything needed for professional wall prep and spray painting')
ON CONFLICT (kit_id) DO NOTHING;

INSERT INTO kit_components (kit_id, tool_id, quantity_required) VALUES
-- Master Woodworking Kit: Miter Saw (#13), Plunge Router (#15), Pocket Hole Jig (#18), Brad Nailer (#17)
(1, 13, 1),
(1, 15, 1),
(1, 18, 1),
(1, 17, 1),

-- Automotive Kit: Floor Jack (#19), Torque Wrench (#20), Brake Caliper Kit (#23), OBD2 Scanner (#21)
(2, 19, 1),
(2, 20, 1),
(2, 23, 1),
(2, 21, 1),

-- Yard Care Kit: Lawn Mower (#7), Leaf Blower (#9), Hedge Trimmer (#8), Pressure Washer (#28)
(3, 7, 1),
(3, 9, 1),
(3, 8, 1),
(3, 28, 1),

-- Painting Kit: Airless Sprayer (#24), Stepladder (#26), Heat Gun (#25)
(4, 24, 1),
(4, 26, 1),
(4, 25, 1)
ON CONFLICT (kit_id, tool_id) DO NOTHING;

SELECT setval('kits_kit_id_seq', (SELECT MAX(kit_id) FROM kits));

-- 6. PAST AND ACTIVE LOANS & DEPOSITS
-- Past returned loans
INSERT INTO loans (loan_id, unit_id, member_id, loan_date, due_date, return_date, status) VALUES
(1, 1, 1, CURRENT_TIMESTAMP - INTERVAL '20 days', CURRENT_TIMESTAMP - INTERVAL '13 days', CURRENT_TIMESTAMP - INTERVAL '14 days', 'Returned'),
(2, 5, 2, CURRENT_TIMESTAMP - INTERVAL '18 days', CURRENT_TIMESTAMP - INTERVAL '11 days', CURRENT_TIMESTAMP - INTERVAL '11 days', 'Returned'),
(3, 8, 3, CURRENT_TIMESTAMP - INTERVAL '15 days', CURRENT_TIMESTAMP - INTERVAL '8 days',  CURRENT_TIMESTAMP - INTERVAL '9 days',  'Returned'),
(4, 14, 4, CURRENT_TIMESTAMP - INTERVAL '12 days', CURRENT_TIMESTAMP - INTERVAL '5 days',  CURRENT_TIMESTAMP - INTERVAL '6 days',  'Returned'),
(5, 21, 5, CURRENT_TIMESTAMP - INTERVAL '10 days', CURRENT_TIMESTAMP - INTERVAL '3 days',  CURRENT_TIMESTAMP - INTERVAL '4 days',  'Returned');

-- Active loans matching our 'Loaned' unit statuses above
INSERT INTO loans (loan_id, unit_id, member_id, loan_date, due_date, return_date, status) VALUES
(6,  3,  6,  CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP + INTERVAL '4 days', NULL, 'Active'),
(7,  7,  7,  CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP + INTERVAL '5 days', NULL, 'Active'),
(8,  9,  8,  CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP + INTERVAL '3 days', NULL, 'Active'),
(9,  13, 9,  CURRENT_TIMESTAMP - INTERVAL '1 day',  CURRENT_TIMESTAMP + INTERVAL '6 days', NULL, 'Active'),
(10, 18, 10, CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_TIMESTAMP + INTERVAL '2 days', NULL, 'Active'),
(11, 20, 11, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP + INTERVAL '5 days', NULL, 'Active'),
(12, 23, 12, CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP + INTERVAL '4 days', NULL, 'Active'),
(13, 26, 13, CURRENT_TIMESTAMP - INTERVAL '1 day',  CURRENT_TIMESTAMP + INTERVAL '6 days', NULL, 'Active'),
(14, 30, 14, CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP + INTERVAL '3 days', NULL, 'Active'),
(15, 33, 15, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP + INTERVAL '5 days', NULL, 'Active'),
(16, 35, 16, CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP + INTERVAL '4 days', NULL, 'Active'),
(17, 40, 17, CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_TIMESTAMP + INTERVAL '2 days', NULL, 'Active'),
(18, 43, 18, CURRENT_TIMESTAMP - INTERVAL '1 day',  CURRENT_TIMESTAMP + INTERVAL '6 days', NULL, 'Active'),
(19, 46, 19, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP + INTERVAL '5 days', NULL, 'Active'),
(20, 52, 20, CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP + INTERVAL '4 days', NULL, 'Active'),
(21, 55, 21, CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP + INTERVAL '3 days', NULL, 'Active'),
(22, 58, 22, CURRENT_TIMESTAMP - INTERVAL '1 day',  CURRENT_TIMESTAMP + INTERVAL '6 days', NULL, 'Active'),
(23, 64, 23, CURRENT_TIMESTAMP - INTERVAL '6 days', CURRENT_TIMESTAMP + INTERVAL '1 day',  NULL, 'Active'),
(24, 68, 24, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP + INTERVAL '5 days', NULL, 'Active'),
(25, 71, 25, CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP + INTERVAL '4 days', NULL, 'Active'),
(26, 76, 26, CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP + INTERVAL '3 days', NULL, 'Active'),
(27, 78, 27, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP + INTERVAL '5 days', NULL, 'Active'),
(28, 81, 28, CURRENT_TIMESTAMP - INTERVAL '1 day',  CURRENT_TIMESTAMP + INTERVAL '6 days', NULL, 'Active');

SELECT setval('loans_loan_id_seq', (SELECT MAX(loan_id) FROM loans));

-- Deposits for loans
INSERT INTO deposits (deposit_id, loan_id, amount, status) VALUES
(1, 1, 30.00, 'Released'),
(2, 2, 50.00, 'Released'),
(3, 3, 40.00, 'Released'),
(4, 4, 25.00, 'Released'),
(5, 5, 35.00, 'Released'),
(6, 6, 30.00, 'Held'),
(7, 7, 50.00, 'Held'),
(8, 8, 40.00, 'Held'),
(9, 9, 35.00, 'Held'),
(10, 10, 30.00, 'Held'),
(11, 11, 80.00, 'Held'),
(12, 12, 35.00, 'Held'),
(13, 13, 40.00, 'Held'),
(14, 14, 20.00, 'Held'),
(15, 15, 25.00, 'Held'),
(16, 16, 90.00, 'Held'),
(17, 17, 45.00, 'Held'),
(18, 18, 40.00, 'Held'),
(19, 19, 25.00, 'Held'),
(20, 20, 45.00, 'Held'),
(21, 21, 25.00, 'Held'),
(22, 22, 30.00, 'Held'),
(23, 23, 70.00, 'Held'),
(24, 24, 15.00, 'Held'),
(25, 25, 25.00, 'Held'),
(26, 26, 50.00, 'Held'),
(27, 27, 30.00, 'Held'),
(28, 28, 30.00, 'Held')
ON CONFLICT (deposit_id) DO NOTHING;

SELECT setval('deposits_deposit_id_seq', (SELECT MAX(deposit_id) FROM deposits));

-- 7. DAMAGE REPORTS (Some past damage reports that auto-flagged units #4, #10, #36, #65)
INSERT INTO damage_reports (report_id, unit_id, loan_id, description, severity) VALUES
(1, 4,  1, 'Chuck wobbles severely and internal motor brushes are worn out', 'Severe'),
(2, 10, 3, 'Blade guard jammed and safety brake mechanism failed', 'Moderate'),
(3, 36, NULL, 'Bevel adjustment lock broken after workshop fall', 'Severe'),
(4, 65, NULL, 'Pump pressure valve cracked and leaking hydraulic fluid', 'Severe')
ON CONFLICT (report_id) DO NOTHING;

SELECT setval('damage_reports_report_id_seq', (SELECT MAX(report_id) FROM damage_reports));

-- 8. WAITLISTS (Realistic waiting queues on popular tools)
INSERT INTO waitlists (waitlist_id, tool_id, member_id, position, status) VALUES
-- Drill (#1) has high demand
(1, 1, 29, 1, 'Waiting'),
(2, 1, 30, 2, 'Waiting'),
(3, 1, 31, 3, 'Waiting'),

-- Miter Saw (#13)
(4, 13, 32, 1, 'Waiting'),
(5, 13, 33, 2, 'Waiting'),

-- Lawn Mower (#7)
(6, 7, 34, 1, 'Waiting'),
(7, 7, 35, 2, 'Waiting'),

-- Pressure Washer (#28)
(8, 28, 36, 1, 'Waiting'),
(9, 28, 37, 2, 'Waiting'),

-- Floor Jack (#19)
(10, 19, 38, 1, 'Waiting')
ON CONFLICT (waitlist_id) DO NOTHING;

SELECT setval('waitlists_waitlist_id_seq', (SELECT MAX(waitlist_id) FROM waitlists));

-- Update member active loan counts accurately
UPDATE members m
SET active_loans_count = (
    SELECT COUNT(*) 
    FROM loans l 
    WHERE l.member_id = m.member_id AND l.status = 'Active'
);
