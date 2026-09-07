/* ═══════════════════════════════════════════════
   SKYPORT — AIRPORT CHECK-IN FRONTEND LOGIC
   Enhanced with Class Selection, Seat Charges & Timetable
   ═══════════════════════════════════════════════ */

/* ── Live Clock ── */
setInterval(() => {
    const el = document.getElementById('clock');
    if (el) el.textContent = new Date().toLocaleTimeString('en-IN', { hour12: false });
}, 1000);

/* ── Live Stats ── */
async function refreshStats() {
    try {
        const r = await fetch('/stats');
        const d = await r.json();
        document.getElementById('livePax').textContent = d.total_passengers;
        document.getElementById('liveFlights').textContent = d.total_flights;
    } catch { }
}
refreshStats();
setInterval(refreshStats, 5000);

/* ── Particle Canvas ── */
(function initParticles() {
    const canvas = document.getElementById('bgCanvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let W, H, particles = [];

    function resize() {
        W = canvas.width = window.innerWidth;
        H = canvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    for (let i = 0; i < 60; i++) {
        particles.push({
            x: Math.random() * 2000,
            y: Math.random() * 1000,
            r: Math.random() * 1.5 + 0.4,
            dx: (Math.random() - 0.5) * 0.3,
            dy: (Math.random() - 0.5) * 0.3,
            o: Math.random() * 0.4 + 0.1
        });
    }

    function draw() {
        ctx.clearRect(0, 0, W, H);
        particles.forEach(p => {
            p.x += p.dx; p.y += p.dy;
            if (p.x < 0) p.x = W;
            if (p.x > W) p.x = 0;
            if (p.y < 0) p.y = H;
            if (p.y > H) p.y = 0;
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(239,83,80,${p.o})`;
            ctx.fill();
        });
        requestAnimationFrame(draw);
    }
    draw();
})();

/* ════════════════════════════════════════
   PANEL MANAGEMENT
   ════════════════════════════════════════ */
function showPanel(id) {
    document.getElementById('backdrop').classList.add('show');
    document.getElementById(id).classList.add('open');
    document.body.style.overflow = 'hidden';
}
function closePanel() {
    document.getElementById('backdrop').classList.remove('show');
    document.querySelectorAll('.side-panel').forEach(p => p.classList.remove('open'));
    document.body.style.overflow = '';
}

/* ════════════════════════════════════════
   PRICING CONFIGURATION
   ════════════════════════════════════════ */
const SEAT_PREF_CHARGES = {
    'window': 500,
    'aisle': 300,
    'extra_legroom': 800,
    'no_preference': 0
};

const CLASS_CHARGES = {
    'economy': 0,
    'business': 3500,
    'first': 8000
};

const CLASS_INFO = {
    'economy': { label: 'Economy', icon: '💺', desc: 'Standard comfortable seat with basic amenities', color: '#78909c' },
    'business': { label: 'Business', icon: '🛋️', desc: 'Extra wide seats, premium meals & priority boarding', color: '#ff8f00' },
    'first': { label: 'First', icon: '👑', desc: 'Luxury suite, gourmet dining & exclusive lounge access', color: '#e53935' }
};

/* ════════════════════════════════════════
   MODULE 0: REGISTER
   ════════════════════════════════════════ */
async function registerPassenger() {
    // Read flight + airline from the hidden inputs (auto-filled by dropdown)
    const flightNo  = document.getElementById('r_flight').value.trim();
    const airline   = document.getElementById('r_airline').value.trim();
    const source    = document.getElementById('r_source').value.trim();
    const dest      = document.getElementById('r_dest').value.trim();
    const bagLimit  = document.getElementById('r_blimit').value.trim();

    if (!flightNo || !airline) {
        const errEl = document.getElementById('reg_errors');
        errEl.innerHTML = '⚠ Please select a flight from the dropdown above.';
        errEl.style.display = 'block';
        return;
    }

    const payload = {
        name:          document.getElementById('r_name').value.trim(),
        email:         document.getElementById('r_email').value.trim(),
        phone:         document.getElementById('r_phone').value.trim(),
        flight_no:     flightNo,
        airline:       airline,
        source:        source,
        destination:   dest,
        flight_date:   document.getElementById('r_date').value,
        baggage_limit: bagLimit
    };

    setBtnLoad('regBtn', true);
    try {
        const res = await fetch('/register', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await res.json();

        const errEl = document.getElementById('reg_errors');
        const sucEl = document.getElementById('reg_success');
        errEl.style.display = 'none'; sucEl.style.display = 'none';

        if (data.success) {
            sucEl.innerHTML = `
        <div style="font-size:1.1rem;font-weight:800;color:#a5d6a7;margin-bottom:14px">🎉 Registration Successful!</div>
        <div style="background:rgba(0,0,0,.3);border-radius:10px;padding:16px;margin-bottom:12px">
          <div style="font-size:.72rem;color:rgba(255,255,255,.4);text-transform:uppercase;letter-spacing:1px;margin-bottom:4px">Booking Reference</div>
          <div style="font-size:2rem;font-weight:900;font-family:'JetBrains Mono',monospace;color:#ff8a80;letter-spacing:4px">${data.booking_ref}</div>
        </div>
        <div style="background:rgba(0,0,0,.3);border-radius:10px;padding:16px;margin-bottom:12px">
          <div style="font-size:.72rem;color:rgba(255,255,255,.4);text-transform:uppercase;letter-spacing:1px;margin-bottom:4px">Password</div>
          <div style="font-size:2rem;font-weight:900;font-family:'JetBrains Mono',monospace;color:#ffcdd2;letter-spacing:4px">${data.password}</div>
        </div>
        <div style="font-size:.82rem;color:rgba(255,255,255,.5);line-height:1.6">⚠️ <strong>Save these credentials</strong> — you will need them for check-in.</div>
        <button class="btn-main full-w" style="margin-top:16px" onclick="autoStartCheckin('${data.booking_ref}')">
          ✈️ Start Online Check-In →
        </button>
      `;
            sucEl.style.display = 'block';
            refreshStats();
        } else {
            errEl.innerHTML = data.errors.map(e => `⚠ ${e}`).join('<br>');
            errEl.style.display = 'block';
        }
    } catch (e) {
        document.getElementById('reg_errors').innerHTML = '❌ Server error. Is Flask running?';
        document.getElementById('reg_errors').style.display = 'block';
    }
    setBtnLoad('regBtn', false);
}

/* Auto-start check-in after registration */
async function autoStartCheckin(bookingRef) {
    closePanel();
    // Pre-fill the booking ref and start check-in
    document.getElementById('ci_ref').value = bookingRef;
    setBtnLoad('ciBtn', true);
    try {
        const res = await fetch('/get_eticket', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ booking_ref: bookingRef })
        });
        const data = await res.json();
        if (data.success) {
            C.bookingRef = bookingRef;
            C.ticket = data.ticket;
            closePanel();
            showCheckinMain();
            renderEticket(data.ticket);
            goStep(1);
        }
    } catch { }
    setBtnLoad('ciBtn', false);
}

/* ════════════════════════════════════════
   CHECK-IN FLOW STATE
   ════════════════════════════════════════ */
const C = {
    bookingRef: '',
    passenger: null,
    ticket: null,
    seat: '',
    seatPref: '',
    travelClass: 'economy',
    meal: '',
    bagWeight: 0,
    baggageCharge: 0,
    seatPrefCharge: 0,
    classCharge: 0,
    currentStep: 0,
    occupiedSeats: new Set()   // persistent across renders
};

// Steps: 1=Eticket, 2=Verify, 3=Details, 4=ClassSelect, 5=SeatMap, 6=Baggage, 7=Pass, 8=Timetable
const STEP_LABELS = ['E-Ticket', 'Verify', 'Details', 'Class', 'Seat', 'Baggage', 'Pass', 'Timetable'];
const CITY_CODES = {
    'Chennai': 'MAA', 'Mumbai': 'BOM', 'Delhi': 'DEL', 'Bangalore': 'BLR',
    'Hyderabad': 'HYD', 'Kolkata': 'CCU', 'Pune': 'PNQ', 'Ahmedabad': 'AMD',
    'Jaipur': 'JAI', 'Kochi': 'COK', 'Goa': 'GOI', 'Coimbatore': 'CJB',
    'Lucknow': 'LKO', 'Patna': 'PAT', 'Bhubaneswar': 'BBI', 'Indore': 'IDR',
    'Srinagar': 'SXR', 'Chandigarh': 'IXC', 'Guwahati': 'GAU', 'Nagpur': 'NAG'
};

function getCode(city) {
    const c = city ? city.trim() : '';
    return CITY_CODES[c] || c.substring(0, 3).toUpperCase() || '---';
}

function buildProgressBar() {
    const pb = document.getElementById('pbSteps');
    if (!pb) return;
    pb.innerHTML = '';
    STEP_LABELS.forEach((label, i) => {
        const step = i + 1;
        const div = document.createElement('div');
        div.className = 'pb-step';
        div.innerHTML = `<div class="pb-circle" id="pbc${step}">${step}</div><div class="pb-label">${label}</div>`;
        pb.appendChild(div);
        if (i < STEP_LABELS.length - 1) {
            const line = document.createElement('div');
            line.className = 'pb-line'; line.id = `pbl${step}`;
            pb.appendChild(line);
        }
    });
}

function updateProgress(step) {
    for (let i = 1; i <= 8; i++) {
        const circ = document.getElementById('pbc' + i);
        if (!circ) continue;
        circ.classList.remove('active', 'done');
        const line = document.getElementById('pbl' + i);
        if (line) { line.classList.remove('done'); }
        if (i < step) {
            circ.classList.add('done');
            if (line) line.classList.add('done');
        }
        if (i === step) circ.classList.add('active');
    }
    const ms = document.getElementById('miniSteps');
    if (ms) {
        ms.innerHTML = STEP_LABELS.map((_, i) => {
            const s = i + 1;
            return `<div class="ms-dot ${s < step ? 'done' : s === step ? 'active' : ''}"></div>`;
        }).join('');
    }
}

function goStep(n) {
    document.querySelectorAll('.step-page').forEach(p => p.style.display = 'none');
    const target = document.getElementById('sp' + n);
    if (target) {
        target.style.display = 'block';
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
    updateProgress(n);
    C.currentStep = n;

    if (n === 4) renderClassSelection();
    if (n === 5) renderSeatMap();
    if (n === 6) renderBaggageInit();
    if (n === 8) renderTimetable();
}

function showCheckinMain() {
    document.getElementById('landing').style.display = 'none';
    document.getElementById('checkinMain').style.display = 'block';
    document.getElementById('stepIndicatorNav').style.display = 'flex';
    buildProgressBar();
    window.scrollTo(0, 0);
}
function closeFull() {
    document.getElementById('landing').style.display = 'block';
    document.getElementById('checkinMain').style.display = 'none';
    document.getElementById('stepIndicatorNav').style.display = 'none';
    Object.assign(C, { bookingRef: '', passenger: null, seat: '', baggageCharge: 0, seatPrefCharge: 0, classCharge: 0, occupiedSeats: new Set() });
}

/* ════════════════════════════════════════
   MODULE 1: E-TICKET
   ════════════════════════════════════════ */
async function fetchEticket() {
    const ref = document.getElementById('ci_ref').value.trim().toUpperCase();
    if (!ref) { showRes('ci_result', '❌ Please enter a booking reference.', 'err'); return; }
    setBtnLoad('ciBtn', true);
    try {
        const res = await fetch('/get_eticket', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ booking_ref: ref })
        });
        const data = await res.json();
        if (data.success) {
            C.bookingRef = ref;
            C.ticket = data.ticket;
            closePanel();
            showCheckinMain();
            renderEticket(data.ticket);
            goStep(1);
        } else {
            showRes('ci_result', data.message, 'err');
        }
    } catch {
        showRes('ci_result', '❌ Server error. Is Flask running?', 'err');
    }
    setBtnLoad('ciBtn', false);
}

function renderEticket(t) {
    const src = getCode(t.source), dst = getCode(t.destination);
    document.getElementById('eticket_display').innerHTML = `
    <div class="eticket-view">
      <div class="et-airline">✈ ${t.airline}</div>
      <div class="et-route-big">
        <div>
          <div class="et-code">${src}</div>
          <div class="et-city">${t.source}</div>
        </div>
        <div class="et-arrow-wrap">
          <div class="et-plane-big">✈</div>
          <div class="et-dashed"></div>
        </div>
        <div style="text-align:right">
          <div class="et-code">${dst}</div>
          <div class="et-city">${t.destination}</div>
        </div>
      </div>
      <div class="et-field-grid">
        <div class="etf"><span>Passenger</span><strong>${t.name}</strong></div>
        <div class="etf"><span>Booking Ref</span><strong>${t.booking_ref}</strong></div>
        <div class="etf"><span>Flight</span><strong>${t.flight_no}</strong></div>
        <div class="etf"><span>Date</span><strong>${t.flight_date}</strong></div>
        <div class="etf"><span>Email</span><strong>${t.email}</strong></div>
        <div class="etf"><span>Phone</span><strong>${t.phone}</strong></div>
        <div class="etf"><span>Baggage Limit</span><strong>${t.baggage_limit} kg</strong></div>
        <div class="etf"><span>Status</span><strong>${t.status}</strong></div>
      </div>
      <div class="et-status-bar">✅ E-TICKET CONFIRMED — Registered: ${t.registered_at}</div>
    </div>`;
}

/* ════════════════════════════════════════
   MODULE 2: PASSWORD VERIFY
   ════════════════════════════════════════ */
async function verifyPw() {
    const pw = document.getElementById('pw_input').value.trim();
    if (!pw) { showRes('pw_result', '❌ Enter your password.', 'err'); return; }
    setBtnLoad('pwBtn', true);
    try {
        const res = await fetch('/verify_password', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ booking_ref: C.bookingRef, password: pw })
        });
        const data = await res.json();
        if (data.success) {
            document.getElementById('lockIcon').textContent = '🔓';
            C.passenger = data.passenger;
            showRes('pw_result', data.message, 'ok');
            fillPassengerForm(data.passenger);
            setTimeout(() => goStep(3), 1200);
        } else {
            document.getElementById('pw_input').value = '';
            showRes('pw_result', data.message, 'err');
        }
    } catch { showRes('pw_result', '❌ Server error.', 'err'); }
    setBtnLoad('pwBtn', false);
}

function togglePw(id, btn) {
    const inp = document.getElementById(id);
    inp.type = inp.type === 'password' ? 'text' : 'password';
    btn.textContent = inp.type === 'password' ? '👁' : '🙈';
}

/* ════════════════════════════════════════
   MODULE 3: PASSENGER INFO + VALIDATE
   ════════════════════════════════════════ */
function fillPassengerForm(p) {
    const grid = document.getElementById('passengerInfoGrid');
    const fields = [
        ['Name', p.name],
        ['Email', p.email],
        ['Phone', p.phone],
        ['Flight', p.flight_no],
        ['Airline', p.airline],
        ['From', p.source],
        ['To', p.destination],
        ['Date', p.flight_date],
        ['Baggage Allow', p.baggage_limit + ' kg']
    ];
    grid.innerHTML = fields.map(([l, v]) =>
        `<div class="ig-field"><span>${l}</span><strong>${v || '--'}</strong></div>`
    ).join('');
}

async function validateInfo() {
    const bagW = document.getElementById('actual_baggage').value.trim();
    const meal = document.getElementById('meal_pref').value;
    const seatP = document.getElementById('seat_pref').value;
    const p = C.passenger;

    const payload = {
        name: p?.name,
        booking_ref: C.bookingRef,
        flight_date: p?.flight_date,
        airline: p?.airline,
        seat_pref: seatP,
        meal_pref: meal,
        baggage_weight: bagW
    };

    setBtnLoad('infoBtn', true);
    try {
        const res = await fetch('/validate_input', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.success) {
            C.seatPref = seatP;
            C.meal = meal;
            C.bagWeight = parseFloat(bagW) || 0;
            C.seatPrefCharge = SEAT_PREF_CHARGES[seatP] || 0;
            document.getElementById('flightLabel').textContent = p?.flight_no || '---';

            // Show seat preference charge notification before proceeding
            if (C.seatPrefCharge > 0) {
                showChargeNotification(
                    'seat_pref_charge_notice',
                    `🪑 Seat Preference Charge`,
                    `You selected <strong>${seatP.replace('_', ' ')}</strong> seat — Extra charge: <strong>₹${C.seatPrefCharge}</strong>`,
                    () => { showRes('info_result', data.message, 'ok'); setTimeout(() => goStep(4), 400); }
                );
            } else {
                showRes('info_result', data.message, 'ok');
                setTimeout(() => goStep(4), 1100);
            }
        } else {
            showRes('info_result', data.errors.map(e => `⚠ ${e}`).join('<br>'), 'err');
        }
    } catch { showRes('info_result', '❌ Server error.', 'err'); }
    setBtnLoad('infoBtn', false);
}

/* ════════════════════════════════════════
   STEP 4: CLASS SELECTION
   ════════════════════════════════════════ */
function renderClassSelection() {
    const grid = document.getElementById('classGrid');
    if (!grid) return;
    grid.innerHTML = Object.entries(CLASS_INFO).map(([key, info]) => {
        const charge = CLASS_CHARGES[key];
        const isSelected = C.travelClass === key;
        return `
        <div class="class-card ${isSelected ? 'class-selected' : ''}" id="cls_${key}" onclick="selectClass('${key}')">
          <div class="cls-icon">${info.icon}</div>
          <div class="cls-name">${info.label}</div>
          <div class="cls-desc">${info.desc}</div>
          <div class="cls-price ${charge > 0 ? 'cls-extra' : 'cls-free'}">
            ${charge > 0 ? `+ ₹${charge.toLocaleString()}` : 'Included'}
          </div>
          ${isSelected ? '<div class="cls-check">✓ Selected</div>' : ''}
        </div>`;
    }).join('');
}

function selectClass(key) {
    C.travelClass = key;
    C.classCharge = CLASS_CHARGES[key] || 0;
    renderClassSelection();
}

function confirmClass() {
    const info = CLASS_INFO[C.travelClass];
    const charge = C.classCharge;

    if (charge > 0) {
        showChargeNotification(
            'class_charge_notice',
            `${info.icon} ${info.label} Class Selected`,
            `Upgrading to <strong>${info.label} Class</strong> — Extra charge: <strong>₹${charge.toLocaleString()}</strong>`,
            () => goStep(5)
        );
    } else {
        goStep(5);
    }
}

/* ════════════════════════════════════════
   CHARGE NOTIFICATION WITH COUNTDOWN
   ════════════════════════════════════════ */
function showChargeNotification(id, title, message, onContinue) {
    // Remove any existing notification
    const existing = document.getElementById('chargeModal');
    if (existing) existing.remove();

    const modal = document.createElement('div');
    modal.id = 'chargeModal';
    modal.className = 'charge-modal-overlay';
    modal.innerHTML = `
      <div class="charge-modal">
        <div class="cm-icon">💳</div>
        <div class="cm-title">${title}</div>
        <div class="cm-message">${message}</div>
        <div class="cm-countdown-wrap">
          <div class="cm-countdown-bar"><div class="cm-bar-fill" id="cmBarFill"></div></div>
          <div class="cm-timer">Continuing in <span id="cmTimer">5</span>s...</div>
        </div>
        <div class="cm-buttons">
          <button class="btn-ghost" onclick="document.getElementById('chargeModal').remove()">← Go Back</button>
          <button class="btn-main" onclick="cmProceed()">Continue ✓</button>
        </div>
      </div>`;
    document.body.appendChild(modal);

    let timeLeft = 5;
    const fill = document.getElementById('cmBarFill');
    const timerEl = document.getElementById('cmTimer');

    // Animate countdown bar
    setTimeout(() => { if (fill) fill.style.width = '0%'; }, 100);

    const interval = setInterval(() => {
        timeLeft--;
        if (timerEl) timerEl.textContent = timeLeft;
        if (timeLeft <= 0) {
            clearInterval(interval);
            cmProceed();
        }
    }, 1000);

    window.cmProceed = function () {
        clearInterval(interval);
        const m = document.getElementById('chargeModal');
        if (m) m.remove();
        if (onContinue) onContinue();
    };
}

/* ════════════════════════════════════════
   MODULE 5: SEAT MAP — FIXED
   ════════════════════════════════════════ */
// Static occupied demo seats — never changes between renders!
const DEMO_OCCUPIED = new Set(['2A', '3B', '5C', '7D', '1D', '4A', '8B', '10C', '12A', '15D', '11B', '6C']);

function renderSeatMap() {
    const grid = document.getElementById('seatGrid');
    if (!grid) return;
    grid.innerHTML = '';

    const pref = C.seatPref; // 'window' | 'aisle' | 'extra_legroom' | 'no_preference'

    // Update seat preference charge display
    const prefEl = document.getElementById('seatPrefChargeInfo');
    if (prefEl) {
        const charge = SEAT_PREF_CHARGES[pref] || 0;
        const prefNames = { window: '🪟 Window', aisle: '🚶 Aisle', extra_legroom: '🦵 Extra Legroom', no_preference: '🎲 No Preference' };
        prefEl.innerHTML = charge > 0
            ? `<span class="pref-tag">Preference: ${prefNames[pref] || pref}</span> <span class="charge-tag">+₹${charge} charge applies</span>`
            : `<span class="pref-tag">Preference: ${prefNames[pref] || pref}</span> <span class="free-tag">No extra charge</span>`;
    }

    // Helper: does this seat match the preference?
    function matchesPref(row, col) {
        if (pref === 'window')       return col === 'A' || col === 'D';
        if (pref === 'aisle')        return col === 'B' || col === 'C';
        if (pref === 'extra_legroom') return row >= 10;
        return true; // no_preference → all seats shown
    }

    for (let r = 1; r <= 20; r++) {
        ['A', 'B', 'C', 'D'].forEach(col => {
            const id = `${r}${col}`;
            const div = document.createElement('div');

            const isOc  = DEMO_OCCUPIED.has(id) || C.occupiedSeats.has(id);
            const isSel = C.seat === id;
            const fits  = matchesPref(r, col);

            let cls;
            if (isSel)      cls = 'seat-cell ss';
            else if (isOc)  cls = 'seat-cell so';
            else if (!fits) cls = 'seat-cell seat-dimmed'; // wrong type for this preference
            else            cls = 'seat-cell sa';

            div.className = cls;
            div.textContent = id;
            div.id = 'sc_' + id;

            if (!isOc && !isSel && fits) {
                div.style.cursor = 'pointer';
                div.title = `Click to select ${id}`;
                div.onclick = () => manualSelectSeat(id);
            } else if (!fits) {
                div.title = `Not a ${pref.replace('_',' ')} seat`;
                div.style.cursor = 'not-allowed';
            }
            grid.appendChild(div);
        });
    }
}

function manualSelectSeat(seatId) {
    // Allow manual click selection, highlight it
    document.querySelectorAll('.seat-cell').forEach(el => {
        if (el.classList.contains('ss')) el.className = `seat-cell sa`;
    });
    const el = document.getElementById('sc_' + seatId);
    if (el) {
        el.className = 'seat-cell ss';
        C.seat = seatId;
        showRes('seat_result', `✅ Seat ${seatId} selected. Click "Confirm Seat" to proceed.`, 'ok');
        document.getElementById('seatBtn').innerHTML = `💺 Confirm Seat ${seatId}`;
    }
}

async function allocateSeat() {
    // If user manually clicked a seat, use that; otherwise ask server
    if (C.seat) {
        // Confirm the manually selected seat
        C.occupiedSeats.add(C.seat);
        const seatType = ['A', 'D'].includes(C.seat.slice(-1)) ? 'Window' : 'Aisle';
        showRes('seat_result', `✅ Seat ${C.seat} confirmed! (${seatType} seat)`, 'ok');
        setTimeout(() => goStep(6), 1400);
        return;
    }

    setBtnLoad('seatBtn', true);
    try {
        const res = await fetch('/allocate_seat', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ seat_pref: C.seatPref, flight_no: C.passenger?.flight_no, booking_ref: C.bookingRef })
        });
        const data = await res.json();
        if (data.success) {
            C.seat = data.seat;
            C.occupiedSeats.add(data.seat);
            // Update seat map visually — stable
            document.querySelectorAll('.seat-cell').forEach(el => {
                const id = el.textContent;
                if (id === data.seat) {
                    el.className = 'seat-cell ss';
                    el.onclick = null;
                }
            });
            showRes('seat_result', `${data.message} — ${data.seat_type} seat`, 'ok');
            setTimeout(() => goStep(6), 1500);
        } else {
            showRes('seat_result', data.message, 'err');
        }
    } catch { showRes('seat_result', '❌ Server error.', 'err'); }
    setBtnLoad('seatBtn', false);
}

/* ════════════════════════════════════════
   MODULE 6: BAGGAGE
   ════════════════════════════════════════ */
function renderBaggageInit() {
    const limit = C.passenger?.baggage_limit || 20;
    document.getElementById('bv_weight').textContent = C.bagWeight + ' kg';
    document.getElementById('bv_limit').textContent = limit + ' kg';
    document.getElementById('bv_excess').textContent = '--';
    document.getElementById('bv_charge').textContent = '₹--';
    document.getElementById('meterLimit').textContent = limit + ' kg allowed';
    document.getElementById('meterBar').style.width = '0%';
}

async function calcBaggage() {
    setBtnLoad('bagBtn', true);
    try {
        const res = await fetch('/calculate_baggage', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ baggage_weight: C.bagWeight, booking_ref: C.bookingRef })
        });
        const data = await res.json();
        if (data.success) {
            C.baggageCharge = data.extra_charge;
            document.getElementById('bv_weight').textContent = data.weight + ' kg';
            document.getElementById('bv_limit').textContent = data.limit + ' kg';
            document.getElementById('bv_excess').textContent = data.excess > 0 ? data.excess.toFixed(1) + ' kg' : '0 kg';
            document.getElementById('bv_charge').textContent = data.extra_charge > 0 ? '₹' + data.extra_charge.toFixed(2) : '₹0 (Free)';
            const pct = Math.min((data.weight / data.limit) * 100, 100);
            document.getElementById('meterBar').style.width = pct + '%';
            if (data.excess > 0) {
                document.getElementById('bagAnim').textContent = '🚨';
                setTimeout(() => { document.getElementById('bagAnim').textContent = '🧳'; }, 1000);
            }
            showRes('bag_result', data.message, data.excess > 0 ? 'err' : 'ok');

            // Show total charges summary before proceeding
            const totalExtra = C.seatPrefCharge + C.classCharge + data.extra_charge;
            if (totalExtra > 0) {
                setTimeout(() => showTotalChargesSummary(data.extra_charge), 800);
            } else {
                setTimeout(() => goStep(7), 1600);
            }
        }
    } catch { showRes('bag_result', '❌ Server error.', 'err'); }
    setBtnLoad('bagBtn', false);
}

function showTotalChargesSummary(baggageCharge) {
    const existing = document.getElementById('chargeModal');
    if (existing) existing.remove();

    const seatCharge = C.seatPrefCharge;
    const clsCharge = C.classCharge;
    const bgCharge = baggageCharge;
    const total = seatCharge + clsCharge + bgCharge;
    const prefNames = { window: '🪟 Window', aisle: '🚶 Aisle', extra_legroom: '🦵 Extra Legroom', no_preference: 'No Pref' };
    const clsInfo = CLASS_INFO[C.travelClass];

    const modal = document.createElement('div');
    modal.id = 'chargeModal';
    modal.className = 'charge-modal-overlay';
    modal.innerHTML = `
      <div class="charge-modal wide-modal">
        <div class="cm-icon">🧾</div>
        <div class="cm-title">Extra Charges Summary</div>
        <div class="charges-table">
          ${seatCharge > 0 ? `<div class="ct-row"><span>${prefNames[C.seatPref]} Seat</span><span class="ct-amount">₹${seatCharge}</span></div>` : ''}
          ${clsCharge > 0 ? `<div class="ct-row"><span>${clsInfo.icon} ${clsInfo.label} Class Upgrade</span><span class="ct-amount">₹${clsCharge.toLocaleString()}</span></div>` : ''}
          ${bgCharge > 0 ? `<div class="ct-row"><span>🧳 Baggage Excess</span><span class="ct-amount">₹${bgCharge.toFixed(2)}</span></div>` : ''}
          <div class="ct-row ct-total"><span>Total Extra Charges</span><span class="ct-amount">₹${total.toLocaleString(undefined, { minimumFractionDigits: 2 })}</span></div>
        </div>
        <div class="cm-countdown-wrap">
          <div class="cm-countdown-bar"><div class="cm-bar-fill" id="cmBarFill"></div></div>
          <div class="cm-timer">Proceeding in <span id="cmTimer">5</span>s...</div>
        </div>
        <div class="cm-buttons">
          <button class="btn-ghost" onclick="document.getElementById('chargeModal').remove()">← Review</button>
          <button class="btn-main" onclick="cmProceed()">Proceed to Pass ✓</button>
        </div>
      </div>`;
    document.body.appendChild(modal);

    let timeLeft = 5;
    const fill = document.getElementById('cmBarFill');
    const timerEl = document.getElementById('cmTimer');
    setTimeout(() => { if (fill) fill.style.width = '0%'; }, 100);

    const interval = setInterval(() => {
        timeLeft--;
        if (timerEl) timerEl.textContent = timeLeft;
        if (timeLeft <= 0) { clearInterval(interval); cmProceed(); }
    }, 1000);

    window.cmProceed = function () {
        clearInterval(interval);
        const m = document.getElementById('chargeModal');
        if (m) m.remove();
        goStep(7);
    };
}

/* ════════════════════════════════════════
   MODULE 7: BOARDING PASS
   ════════════════════════════════════════ */
async function genBP() {
    const p = C.passenger;
    if (!p) { showRes('bp_result', '❌ No passenger data. Restart check-in.', 'err'); return; }
    setBtnLoad('bpBtn', true);
    const totalExtra = C.seatPrefCharge + C.classCharge + C.baggageCharge;
    try {
        const res = await fetch('/generate_boarding_pass', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: p.name, booking_ref: C.bookingRef,
                flight: p.flight_no, airline: p.airline,
                source: p.source, destination: p.destination,
                seat: C.seat, flight_date: p.flight_date,
                travel_class: C.travelClass,
                extra_charge: totalExtra
            })
        });
        const data = await res.json();
        if (data.success) {
            fillBoardingPass(data.boarding_pass);
            showRes('bp_result', data.message, 'ok');
            document.getElementById('bpNav1').style.display = 'none';
            document.getElementById('bpNav2').style.display = 'flex';
        }
    } catch { showRes('bp_result', '❌ Server error.', 'err'); }
    setBtnLoad('bpBtn', false);
}

function fillBoardingPass(bp) {
    const src = getCode(bp.source), dst = getCode(bp.destination);
    const clsInfo = CLASS_INFO[C.travelClass] || CLASS_INFO['economy'];
    set('bp_airline', bp.airline + ' ✈');
    set('bp_src', src);
    set('bp_src_name', bp.source);
    set('bp_dst', dst);
    set('bp_dst_name', bp.destination);
    set('bp_name', bp.name);
    set('bp_flight', bp.flight);
    set('bp_date', bp.flight_date);
    set('bp_boarding', bp.boarding_time);
    set('bp_terminal', bp.terminal);
    set('bp_class', clsInfo.icon + ' ' + clsInfo.label);
    set('bps_airline', bp.airline);
    set('bps_seat', bp.seat || '--');
    set('bps_gate', bp.gate);
    set('bps_terminal', bp.terminal);
    set('bp_number', bp.barcode);
    document.getElementById('boardingPassEl').style.display = 'block';
}

/* ════════════════════════════════════════
   MODULE 8: FLIGHT TIMETABLE
   ════════════════════════════════════════ */
function renderTimetable() {
    const p = C.passenger;
    if (!p) return;
    const tbl = document.getElementById('timetableBody');
    if (!tbl) return;

    const baseDate  = p.flight_date || new Date().toISOString().slice(0, 10);
    const src       = p.source      || 'Chennai';
    const dst       = p.destination || 'Delhi';
    const fno       = p.flight_no   || 'SK101';
    const airline   = p.airline     || 'SkyPort';

    // Use management flight list as the primary timetable source
    const MGMT_FLIGHTS_JS = [
      { flight_no: 'AI202',  airline: 'Air India',   source: 'Chennai',   destination: 'Delhi',      departure: '06:00', arrival: '08:30', baggage_limit: 25 },
      { flight_no: 'AI305',  airline: 'Air India',   source: 'Mumbai',    destination: 'Bangalore',  departure: '08:30', arrival: '10:45', baggage_limit: 25 },
      { flight_no: '6E101',  airline: 'IndiGo',      source: 'Delhi',     destination: 'Mumbai',     departure: '09:15', arrival: '11:30', baggage_limit: 20 },
      { flight_no: '6E215',  airline: 'IndiGo',      source: 'Hyderabad', destination: 'Chennai',    departure: '11:00', arrival: '12:15', baggage_limit: 20 },
      { flight_no: 'UK805',  airline: 'Vistara',     source: 'Bangalore', destination: 'Kolkata',    departure: '13:45', arrival: '16:30', baggage_limit: 30 },
      { flight_no: 'UK910',  airline: 'Vistara',     source: 'Delhi',     destination: 'Hyderabad',  departure: '07:20', arrival: '09:35', baggage_limit: 30 },
      { flight_no: 'SG321',  airline: 'SpiceJet',    source: 'Pune',      destination: 'Goa',        departure: '15:00', arrival: '16:10', baggage_limit: 15 },
      { flight_no: 'SG450',  airline: 'SpiceJet',    source: 'Ahmedabad', destination: 'Jaipur',     departure: '10:30', arrival: '11:40', baggage_limit: 15 },
      { flight_no: 'QP101',  airline: 'Akasa Air',   source: 'Mumbai',    destination: 'Goa',        departure: '17:00', arrival: '18:10', baggage_limit: 20 },
      { flight_no: 'AI0987', airline: 'Air India',   source: 'Chennai',   destination: 'Coimbatore', departure: '19:30', arrival: '20:30', baggage_limit: 25 },
    ];
    const aircraftTypes = ['Boeing 737', 'Airbus A320', 'Boeing 777', 'Airbus A380', 'ATR 72'];
    const statuses = [
        { key: 'ontime',   label: '✅ On Time' },
        { key: 'ontime',   label: '✅ On Time' },
        { key: 'delayed',  label: '⏳ Delayed' },
        { key: 'boarding', label: '🛫 Boarding' },
        { key: 'departed', label: '✈ Departed' }
    ];

    const flights = MGMT_FLIGHTS_JS.map((f, i) => {
        const isMain = f.flight_no === fno;
        const depParts = f.departure.split(':').map(Number);
        const arrParts = f.arrival.split(':').map(Number);
        const durMin   = (arrParts[0] - depParts[0]) * 60 + (arrParts[1] - depParts[1]);
        const durStr   = `${Math.floor(durMin / 60)}h ${durMin % 60}m`;
        const st = isMain ? { key: 'boarding', label: '🛫 Boarding' } : statuses[i % statuses.length];
        return {
            flight_no:   f.flight_no,
            airline:     f.airline,
            source:      f.source,
            destination: f.destination,
            departure:   f.departure,
            arrival:     f.arrival,
            duration:    durStr,
            status:      st.label,
            statusKey:   st.key,
            aircraft:    aircraftTypes[i % aircraftTypes.length],
            isMain
        };
    });

    tbl.innerHTML = flights.map(f => `
      <tr class="${f.isMain ? 'tt-main-row' : ''}">
        <td><span class="tt-fn ${f.isMain ? 'tt-fn-main' : ''}">${f.flight_no}</span></td>
        <td><strong>${f.airline}</strong></td>
        <td>${f.source}</td>
        <td>${f.destination}</td>
        <td>${f.departure}</td>
        <td>${f.arrival}</td>
        <td>${f.duration}</td>
        <td><span class="tt-status tt-status-${f.statusKey}">${f.status}</span></td>
        <td>${f.aircraft}</td>
      </tr>`).join('');

    const hdr = document.getElementById('ttHeader');
    if (hdr) hdr.innerHTML = `
      <span class="tt-route">${src} → ${dst}</span>
      <span class="tt-date">📅 ${baseDate}</span>
      <span class="tt-your-flight">✈ Your Flight: <strong>${fno}</strong> — ${airline}</span>
    `;
}

function generateTimetableFlights(src, dst, mainFno, airline, date) {
    const aircraftTypes = ['Boeing 737', 'Airbus A320', 'Boeing 777', 'Airbus A380', 'ATR 72'];
    const airlines = [airline, 'IndiGo', 'Vistara', 'Air India', 'SpiceJet', 'GoFirst'];
    const statuses = [
        { key: 'ontime', label: '✅ On Time' },
        { key: 'ontime', label: '✅ On Time' },
        { key: 'ontime', label: '✅ On Time' },
        { key: 'delayed', label: '⏳ Delayed' },
        { key: 'boarding', label: '🛫 Boarding' },
        { key: 'departed', label: '✈ Departed' }
    ];

    const flights = [];
    const baseTimes = [
        ['05:30', '07:50'], ['06:15', '08:30'], ['07:00', '09:20'],
        ['08:45', '11:00'], ['10:10', '12:25'], ['11:30', '13:45'],
        ['13:00', '15:15'], ['14:30', '16:45'], ['16:00', '18:15'],
        ['17:45', '20:00'], ['19:20', '21:35'], ['21:00', '23:10']
    ];

    baseTimes.forEach(([dep, arr], i) => {
        const isMain = i === 4; // highlight our passenger's flight in 5th row approx
        const al = isMain ? airline : airlines[i % airlines.length];
        const fno = isMain ? mainFno : `${al.substring(0, 2).toUpperCase()}${100 + i * 11}`;
        const st = isMain ? { key: 'boarding', label: '🛫 Boarding' } : statuses[i % statuses.length];
        const depH = parseInt(dep.split(':')[0]);
        const arrH = parseInt(arr.split(':')[0]);
        const durationMin = (arrH - depH) * 60 + (parseInt(arr.split(':')[1]) - parseInt(dep.split(':')[1]));
        const durStr = `${Math.floor(durationMin / 60)}h ${durationMin % 60}m`;

        flights.push({
            flight_no: fno,
            airline: al,
            source: src,
            destination: dst,
            departure: dep,
            arrival: arr,
            duration: durStr,
            status: st.label,
            statusKey: st.key,
            aircraft: aircraftTypes[i % aircraftTypes.length],
            isMain
        });
    });

    return flights;
}

function set(id, val) {
    const el = document.getElementById(id);
    if (el) el.textContent = val;
}

function restartFlow() {
    Object.assign(C, {
        bookingRef: '', passenger: null, ticket: null, seat: '',
        seatPref: '', travelClass: 'economy', meal: '',
        bagWeight: 0, baggageCharge: 0, seatPrefCharge: 0,
        classCharge: 0, currentStep: 0, occupiedSeats: new Set()
    });
    document.querySelectorAll('.result-box').forEach(e => { e.style.display = 'none'; e.innerHTML = ''; });
    const bpEl = document.getElementById('boardingPassEl');
    if (bpEl) bpEl.style.display = 'none';
    document.getElementById('bpNav1').style.display = 'flex';
    document.getElementById('bpNav2').style.display = 'none';
    document.getElementById('pw_input').value = '';
    document.getElementById('actual_baggage').value = '';
    document.getElementById('lockIcon').textContent = '🔒';
    closeFull();
}

/* ════════════════════════════════════════
   HELPERS
   ════════════════════════════════════════ */
function showRes(id, msg, type) {
    const el = document.getElementById(id);
    if (!el) return;
    el.style.display = 'block';
    el.className = 'result-box ' + (type === 'ok' ? 'res-ok' : type === 'err' ? 'res-err' : 'res-info');
    el.innerHTML = msg;
}

function setBtnLoad(id, loading) {
    const btn = document.getElementById(id);
    if (!btn) return;
    if (loading) {
        btn._orig = btn.innerHTML;
        btn.innerHTML = '<span class="spin"></span> Processing…';
        btn.disabled = true;
    } else {
        btn.innerHTML = btn._orig || btn.innerHTML;
        btn.disabled = false;
    }
}
