// ==============================================================================
// LIBRARY OF THINGS: FRONTEND APPLICATION (JS)
// ==============================================================================

let currentMembers = [];
let currentTools = [];
let currentCategories = [];

// ------------------------------------------------------------------------------
// INITIALIZATION
// ------------------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", async () => {
  await loadCategories();
  await loadMembers();
  await loadTools();
  await loadActiveLoans();
  await loadKits();
  await loadAnalytics();
});

// ------------------------------------------------------------------------------
// NAVIGATION TABS
// ------------------------------------------------------------------------------
function switchTab(tabId) {
  document.querySelectorAll(".nav-tab").forEach(tab => tab.classList.remove("active"));
  document.querySelectorAll(".view-section").forEach(sec => sec.classList.remove("active"));

  event.currentTarget.classList.add("active");
  const target = document.getElementById(`tab-${tabId}`);
  if (target) {
    target.classList.add("active");
  }

  // Refresh data on tab switch
  if (tabId === "staff") {
    loadActiveLoans();
    populateStaffSelects();
  } else if (tabId === "kits") {
    loadKits();
  } else if (tabId === "analytics") {
    loadAnalytics();
  } else if (tabId === "concurrency") {
    populateSimUnitSelect();
  }
}

// ------------------------------------------------------------------------------
// API FETCH HELPERS
// ------------------------------------------------------------------------------
async function fetchJSON(url, options = {}) {
  try {
    const res = await fetch(url, options);
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.detail || data.message || "Request failed");
    }
    return data;
  } catch (err) {
    alert(`Error: ${err.message}`);
    throw err;
  }
}

// ------------------------------------------------------------------------------
// 1. TOOL CATALOG & INVENTORY
// ------------------------------------------------------------------------------
async function loadCategories() {
  currentCategories = await fetchJSON("/api/categories");
  const select = document.getElementById("category-filter");
  select.innerHTML = `<option value="">All Categories</option>`;
  currentCategories.forEach(c => {
    select.innerHTML += `<option value="${c.category_id}">${c.name}</option>`;
  });
}

async function loadMembers() {
  currentMembers = await fetchJSON("/api/members");
  populateStaffSelects();
}

async function loadTools() {
  const catId = document.getElementById("category-filter").value;
  const url = catId ? `/api/tools?category_id=${catId}` : "/api/tools";
  currentTools = await fetchJSON(url);

  let totalAvailable = 0;
  let totalLoaned = 0;
  let totalRepair = 0;

  const container = document.getElementById("tools-container");
  container.innerHTML = "";

  currentTools.forEach(tool => {
    totalAvailable += parseInt(tool.available_units || 0);
    totalLoaned += parseInt(tool.loaned_units || 0);
    totalRepair += parseInt(tool.repair_units || 0);

    const card = document.createElement("div");
    card.className = "tool-card";
    card.innerHTML = `
      <div>
        <h3>${tool.name}</h3>
        <span class="category-tag">${tool.category_name}</span>
        <p class="desc">${tool.description || 'No description provided.'}</p>
        
        <div class="units-bar">
          <div><i class="fa-solid fa-layer-group"></i> Units: <strong>${tool.total_units}</strong></div>
          <div><span class="badge badge-available">${tool.available_units} Free</span></div>
          <div><span class="badge badge-loaned">${tool.loaned_units} Loaned</span></div>
          ${tool.repair_units > 0 ? `<div><span class="badge badge-repair">${tool.repair_units} In Repair</span></div>` : ''}
        </div>
      </div>

      <div style="display: flex; gap: 0.5rem; justify-content: space-between; align-items: center; border-top: 1px solid var(--border); padding-top: 0.75rem;">
        <span style="font-size: 0.85rem; font-weight: 600; color: #475569;">
          Deposit: <strong>$${parseFloat(tool.deposit_amount).toFixed(2)}</strong>
        </span>
        <div style="display: flex; gap: 0.4rem;">
          <button class="btn btn-secondary" style="padding: 0.4rem 0.6rem; font-size: 0.8rem;" onclick="openUnitModal(${tool.tool_id}, '${tool.name}')">
            <i class="fa-solid fa-list-ol"></i> View Units
          </button>
          ${tool.available_units > 0 ? `
            <button class="btn" style="padding: 0.4rem 0.6rem; font-size: 0.8rem;" onclick="quickReserve(${tool.tool_id})">
              <i class="fa-solid fa-bookmark"></i> Reserve
            </button>
          ` : `
            <button class="btn btn-danger" style="padding: 0.4rem 0.6rem; font-size: 0.8rem;" onclick="quickWaitlist(${tool.tool_id})">
              <i class="fa-solid fa-clock"></i> Join Waitlist
            </button>
          `}
        </div>
      </div>
    `;
    container.appendChild(card);
  });

  document.getElementById("stat-total-tools").innerText = currentTools.length;
  document.getElementById("stat-available-units").innerText = totalAvailable;
  document.getElementById("stat-loaned-units").innerText = totalLoaned;
  document.getElementById("stat-repair-units").innerText = totalRepair;
}

// ------------------------------------------------------------------------------
// MODAL: VIEW PHYSICAL TOOL UNITS & ACTIONS
// ------------------------------------------------------------------------------
async function openUnitModal(toolId, toolName) {
  document.getElementById("modal-tool-title").innerText = `${toolName} - Tracked Physical Units`;
  const list = document.getElementById("modal-units-list");
  list.innerHTML = `<p style="text-align: center; color: var(--text-muted);"><i class="fa-solid fa-spinner fa-spin"></i> Loading units...</p>`;
  document.getElementById("unit-modal").style.display = "flex";

  const units = await fetchJSON(`/api/tools/${toolId}/units`);
  list.innerHTML = "";

  if (units.length === 0) {
    list.innerHTML = `<p>No registered physical units.</p>`;
    return;
  }

  units.forEach(u => {
    let badgeClass = "badge-available";
    if (u.condition_status === "Loaned") badgeClass = "badge-loaned";
    else if (u.condition_status === "Repair") badgeClass = "badge-repair";
    else if (u.condition_status === "Reserved") badgeClass = "badge-reserved";

    const item = document.createElement("div");
    item.style.padding = "0.75rem";
    item.style.borderBottom = "1px solid var(--border)";
    item.style.display = "flex";
    item.style.justifyContent = "space-between";
    item.style.alignItems = "center";

    item.innerHTML = `
      <div>
        <strong>Unit #${u.unit_id}</strong> &bull; <code>${u.serial_no}</code>
        <div style="font-size: 0.8rem; color: var(--text-muted);">
          ${u.active_borrower_name ? `Borrower: ${u.active_borrower_name}` : 'Not borrowed'}
        </div>
      </div>
      <div>
        <span class="badge ${badgeClass}">${u.condition_status}</span>
        ${u.condition_status === 'Available' ? `
          <button class="btn" style="padding: 0.2rem 0.5rem; font-size: 0.75rem; margin-left: 0.5rem;" onclick="reserveUnitDirect(${u.unit_id})">Reserve This</button>
        ` : ''}
        ${u.condition_status !== 'Repair' ? `
          <button class="btn btn-secondary" style="padding: 0.2rem 0.5rem; font-size: 0.75rem; margin-left: 0.3rem;" onclick="flagRepairDirect(${u.unit_id})">Report Damage</button>
        ` : ''}
      </div>
    `;
    list.appendChild(item);
  });
}

function closeModal() {
  document.getElementById("unit-modal").style.display = "none";
}

async function quickReserve(toolId) {
  const memberId = prompt("Enter Member ID for this reservation (1 to 50):", "1");
  if (!memberId) return;

  const res = await fetchJSON("/api/reservations", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool_id: parseInt(toolId), member_id: parseInt(memberId), use_locking: true })
  });

  alert(`Success: ${res.message}! Unit #${res.unit_id} reserved until ${new Date(res.expires_at).toLocaleString()}`);
  loadTools();
}

async function quickWaitlist(toolId) {
  const memberId = prompt("No free units! Enter Member ID to join the Waitlist (1 to 50):", "2");
  if (!memberId) return;

  const res = await fetchJSON("/api/waitlists", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool_id: parseInt(toolId), member_id: parseInt(memberId) })
  });

  alert(`Success: ${res.message}!`);
  loadAnalytics();
}

async function reserveUnitDirect(unitId) {
  const memberId = prompt(`Enter Member ID to reserve Unit #${unitId}:`, "1");
  if (!memberId) return;

  const res = await fetchJSON("/api/reservations", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ unit_id: parseInt(unitId), member_id: parseInt(memberId), use_locking: true })
  });

  alert(`Success: Reserved Unit #${res.unit_id}!`);
  closeModal();
  loadTools();
}

async function flagRepairDirect(unitId) {
  const severity = prompt("Select damage severity: 'Minor', 'Moderate', or 'Severe'", "Moderate");
  if (!severity) return;
  const description = prompt("Describe damage or issue:", "Defective motor during inspection");

  const res = await fetchJSON("/api/damage-reports", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ unit_id: parseInt(unitId), severity, description: description || "Defective condition" })
  });

  alert(`Database Trigger Result:\n${res.trigger_effect}`);
  closeModal();
  loadTools();
}

// ------------------------------------------------------------------------------
// 2. STAFF CIRCULATION
// ------------------------------------------------------------------------------
async function populateStaffSelects() {
  const memberSelect = document.getElementById("checkout-member-select");
  if (memberSelect) {
    memberSelect.innerHTML = `<option value="">-- Select Member --</option>`;
    currentMembers.forEach(m => {
      memberSelect.innerHTML += `<option value="${m.member_id}">#${m.member_id} - ${m.name} (${m.active_loans_count} active loans)</option>`;
    });
  }

  // Populate available units for checkout
  const unitSelect = document.getElementById("checkout-unit-select");
  if (unitSelect) {
    unitSelect.innerHTML = `<option value="">-- Select Available Unit --</option>`;
    // Fetch all tools' units
    for (const tool of currentTools) {
      if (tool.available_units > 0) {
        const units = await fetchJSON(`/api/tools/${tool.tool_id}/units`);
        units.filter(u => u.condition_status === "Available").forEach(u => {
          unitSelect.innerHTML += `<option value="${u.unit_id}">${tool.name} (Unit #${u.unit_id} - ${u.serial_no})</option>`;
        });
      }
    }
  }
}

async function loadActiveLoans() {
  const loans = await fetchJSON("/api/loans/active");
  const tbody = document.getElementById("active-loans-tbody");
  const checkinSelect = document.getElementById("checkin-loan-select");

  tbody.innerHTML = "";
  checkinSelect.innerHTML = `<option value="">-- Select Active Loan To Return --</option>`;

  if (loans.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-muted);">No active loans found.</td></tr>`;
    return;
  }

  loans.forEach(l => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>#${l.loan_id}</strong></td>
      <td>${l.tool_name} <br><small><code>${l.serial_no}</code></small></td>
      <td>${l.member_name} (ID: ${l.member_id})</td>
      <td>${new Date(l.loan_date).toLocaleDateString()}</td>
      <td>${new Date(l.due_date).toLocaleDateString()}</td>
      <td>$${parseFloat(l.deposit_amount || 0).toFixed(2)} (${l.deposit_status})</td>
      <td>
        <button class="btn btn-secondary" style="padding: 0.3rem 0.6rem; font-size: 0.8rem;" onclick="selectForCheckin(${l.loan_id})">
          <i class="fa-solid fa-arrow-right-to-bracket"></i> Check-in
        </button>
      </td>
    `;
    tbody.appendChild(tr);

    checkinSelect.innerHTML += `<option value="${l.loan_id}">Loan #${l.loan_id}: ${l.tool_name} (${l.member_name})</option>`;
  });
}

function selectForCheckin(loanId) {
  document.getElementById("checkin-loan-select").value = loanId;
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

async function handleCheckout(e) {
  e.preventDefault();
  const unitId = document.getElementById("checkout-unit-select").value;
  const memberId = document.getElementById("checkout-member-select").value;
  const days = document.getElementById("checkout-days").value;

  if (!unitId || !memberId) {
    alert("Please select both a member and an available unit.");
    return;
  }

  const res = await fetchJSON("/api/loans/checkout", {
    method: "POST",
    headers: { 
      "Content-Type": "application/json",
      "X-User-Role": "staff"
    },
    body: JSON.stringify({ unit_id: parseInt(unitId), member_id: parseInt(memberId), loan_days: parseInt(days) })
  });

  alert(`Loan Created Successfully!\nLoan ID: #${res.loan_id}\nDeposit Held: $${res.deposit_amount}`);
  await loadTools();
  await loadActiveLoans();
  await populateStaffSelects();
}

async function handleCheckin(e) {
  e.preventDefault();
  const loanId = document.getElementById("checkin-loan-select").value;
  const condition = document.getElementById("checkin-condition").value;
  const notes = document.getElementById("checkin-notes").value;

  if (!loanId) {
    alert("Please select an active loan to check in.");
    return;
  }

  const res = await fetchJSON("/api/loans/checkin", {
    method: "POST",
    headers: { 
      "Content-Type": "application/json",
      "X-User-Role": "staff"
    },
    body: JSON.stringify({ loan_id: parseInt(loanId), condition, notes })
  });

  alert(`Stored Procedure Output:\n${res.result_status}\n${res.promoted_member_id ? `Promoted Member ID: ${res.promoted_member_id}` : ''}`);
  await loadTools();
  await loadActiveLoans();
  await populateStaffSelects();
  await loadAnalytics();
}

// ------------------------------------------------------------------------------
// 3. KITS (DATABASE VIEW DEMONSTRATION)
// ------------------------------------------------------------------------------
async function loadKits() {
  const kits = await fetchJSON("/api/kits");
  const container = document.getElementById("kits-container");
  container.innerHTML = "";

  for (const kit of kits) {
    const components = await fetchJSON(`/api/kits/${kit.kit_id}/components`);
    const card = document.createElement("div");
    card.className = "stat-card";
    card.style.borderLeft = kit.is_available ? "5px solid var(--success)" : "5px solid var(--danger)";

    let componentsHTML = "";
    components.forEach(c => {
      const isOk = c.free_units_count >= c.quantity_required;
      componentsHTML += `
        <li style="display: flex; justify-content: space-between; margin-bottom: 0.3rem; font-size: 0.85rem;">
          <span>${c.tool_name}</span>
          <span style="color: ${isOk ? 'var(--success)' : 'var(--danger)'}; font-weight: 600;">
            ${c.free_units_count} available (req: ${c.quantity_required})
          </span>
        </li>
      `;
    });

    card.innerHTML = `
      <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.5rem;">
        <h3>${kit.kit_name}</h3>
        <span class="badge ${kit.is_available ? 'badge-available' : 'badge-repair'}">
          ${kit.is_available ? 'Ready for Checkout' : 'Blocked (Missing Units)'}
        </span>
      </div>
      <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 1rem;">${kit.description}</p>
      
      <div style="background: #f8fafc; padding: 0.75rem; border-radius: 6px; margin-bottom: 1rem;">
        <div style="font-size: 0.8rem; font-weight: 600; text-transform: uppercase; color: var(--text-muted); margin-bottom: 0.5rem;">
          Component Availability Check:
        </div>
        <ul style="list-style: none;">
          ${componentsHTML}
        </ul>
      </div>

      <div style="font-size: 0.85rem; color: #475569;">
        Complete Bundles Available: <strong>${kit.complete_kits_available}</strong>
      </div>
    `;
    container.appendChild(card);
  }
}

// ------------------------------------------------------------------------------
// 4. ANALYTICS & DASHBOARD
// ------------------------------------------------------------------------------
async function loadAnalytics() {
  // Fleet Status
  const fleet = await fetchJSON("/api/analytics/fleet-status");
  const fleetTbody = document.getElementById("fleet-status-tbody");
  fleetTbody.innerHTML = "";
  fleet.forEach(f => {
    fleetTbody.innerHTML += `
      <tr>
        <td><strong>${f.category_name}</strong></td>
        <td>${f.total_units}</td>
        <td><span class="badge badge-available">${f.available_count}</span></td>
        <td><span class="badge badge-loaned">${f.loaned_count}</span></td>
        <td><span class="badge badge-repair">${f.repair_count}</span></td>
      </tr>
    `;
  });

  // Waitlists
  const waitlists = await fetchJSON("/api/analytics/waitlists");
  const waitlistTbody = document.getElementById("waitlist-summary-tbody");
  waitlistTbody.innerHTML = "";
  if (waitlists.length === 0) {
    waitlistTbody.innerHTML = `<tr><td colspan="3" style="text-align: center; color: var(--text-muted);">No members currently waiting.</td></tr>`;
  } else {
    waitlists.forEach(w => {
      waitlistTbody.innerHTML += `
        <tr>
          <td><strong>${w.tool_name}</strong></td>
          <td>${w.category_name}</td>
          <td><span class="badge badge-repair">${w.waiting_members_count} waiting</span></td>
        </tr>
      `;
    });
  }

  // Deposits
  const deposits = await fetchJSON("/api/analytics/deposits");
  const depTbody = document.getElementById("deposits-tbody");
  depTbody.innerHTML = "";
  deposits.forEach(d => {
    let badgeClass = "badge-available";
    if (d.status === "Held") badgeClass = "badge-loaned";
    if (d.status === "Forfeited") badgeClass = "badge-repair";

    depTbody.innerHTML += `
      <tr>
        <td>#${d.deposit_id}</td>
        <td>Loan #${d.loan_id}</td>
        <td>${d.tool_name}</td>
        <td>${d.member_name}</td>
        <td>$${parseFloat(d.amount).toFixed(2)}</td>
        <td><span class="badge ${badgeClass}">${d.status}</span></td>
      </tr>
    `;
  });
}

// ------------------------------------------------------------------------------
// 5. PHASE 3: CONCURRENCY RACE CONDITION EXPO SIMULATION
// ------------------------------------------------------------------------------
async function populateSimUnitSelect() {
  const select = document.getElementById("sim-unit-select");
  select.innerHTML = "";
  // Fetch units for Tool #1 (DeWalt Cordless Drill) or any available unit
  const units = await fetchJSON("/api/tools/1/units");
  units.forEach(u => {
    select.innerHTML += `<option value="${u.unit_id}">Unit #${u.unit_id} (${u.serial_no}) - Status: ${u.condition_status}</option>`;
  });
}

async function runSimulation(mode) {
  const unitId = document.getElementById("sim-unit-select").value;
  const consoleBox = document.getElementById("sim-results");
  const btnUnprotected = document.getElementById("btn-sim-unprotected");
  const btnProtected = document.getElementById("btn-sim-protected");

  btnUnprotected.disabled = true;
  btnProtected.disabled = true;

  consoleBox.innerHTML = `⚡ [CONCURRENCY SIMULATOR] Spawning two simultaneous asynchronous worker threads...\nTarget Unit: #${unitId}\nMember 1: Aarav Sharma (ID #1)\nMember 2: Aditi Patel (ID #2)\nMode: ${mode.toUpperCase()}\n\nPlease wait for threads to complete transaction execution...\n`;

  try {
    const res = await fetchJSON("/api/concurrency/simulate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        unit_id: parseInt(unitId),
        member1_id: 1,
        member2_id: 2,
        mode: mode,
        delay_seconds: 1.5
      })
    });

    let log = `\n================== SIMULATION COMPLETE ==================\n`;
    log += `MODE: ${res.mode}\n`;
    log += `OUTCOME: ${res.outcome}\n\n`;
    log += `[THREAD 1 RESULT (Member #1)]:\n` + JSON.stringify(res.transaction_1, null, 2) + "\n\n";
    log += `[THREAD 2 RESULT (Member #2)]:\n` + JSON.stringify(res.transaction_2, null, 2) + "\n\n";
    log += `[POST-EXECUTION DATABASE STATE]:\n`;
    log += `Total Active Reservations Created: ${res.active_reservations_count}\n`;
    log += JSON.stringify(res.active_reservations, null, 2) + "\n";

    consoleBox.innerHTML = log;
    await populateSimUnitSelect();
    await loadTools();
  } catch (err) {
    consoleBox.innerHTML += `\nError during execution: ${err.message}`;
  } finally {
    btnUnprotected.disabled = false;
    btnProtected.disabled = false;
  }
}
