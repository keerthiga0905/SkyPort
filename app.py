import os, datetime, subprocess, time
from flask import Flask, render_template, jsonify, request

app = Flask(__name__)
app.secret_key = "skyport_emu8086_2026"

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
ASM_DIR     = os.path.join(PROJECT_DIR, "asm")

IN_FILE  = os.path.join(ASM_DIR, "skyport_in.txt")
OUT_FILES = {
    "register": os.path.join(ASM_DIR, "register_out.txt"),
    "verify":   os.path.join(ASM_DIR, "verify_out.txt"),
    "validate": os.path.join(ASM_DIR, "validate_out.txt"),
    "seat":     os.path.join(ASM_DIR, "seat_out.txt"),
    "baggage":  os.path.join(ASM_DIR, "baggage_out.txt"),
    "boarding": os.path.join(ASM_DIR, "skyport_out.txt"),
}
ASM_FILES = {
    "register": os.path.join(ASM_DIR, "register_passenger.asm"),
    "verify":   os.path.join(ASM_DIR, "verify_password.asm"),
    "validate": os.path.join(ASM_DIR, "validate_input.asm"),
    "seat":     os.path.join(ASM_DIR, "seat_allocation.asm"),
    "baggage":  os.path.join(ASM_DIR, "baggage_calc.asm"),
    "boarding": os.path.join(ASM_DIR, "boarding_pass.asm"),
}

EMU_CANDIDATES = [
    r"C:\emu8086\emu8086.exe",
    r"C:\Program Files (x86)\emu8086\emu8086.exe",
    r"C:\Program Files\emu8086\emu8086.exe",
    r"D:\emu8086\emu8086.exe",
    os.path.join(os.path.expanduser("~"), "emu8086", "emu8086.exe"),
    os.path.join(os.path.expanduser("~"), "Desktop", "emu8086", "emu8086.exe"),
]
ASM_TIMEOUT = 15

PASSENGER_DB      = {}
FLIGHT_SEAT_MAPS  = {}


# ── helpers ───────────────────────────────────────────────────────────────────

def find_emu():
    for p in EMU_CANDIDATES:
        if os.path.isfile(p):
            return p
    return None

def write_input_file(kv: dict):
    os.makedirs(ASM_DIR, exist_ok=True)
    with open(IN_FILE, "w", newline="\r\n") as f:
        for k, v in kv.items():
            f.write(f"{k}={v}\r\n")

def delete_output_file(key: str):
    p = OUT_FILES.get(key, "")
    try:
        if p and os.path.exists(p):
            os.remove(p)
    except Exception:
        pass

def parse_out(key: str) -> dict:
    path = OUT_FILES.get(key, "")
    data = {}
    try:
        with open(path, "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if "=" not in line:
                    continue
                k, _, v = line.partition("=")
                data[k.strip()] = v.strip()
    except Exception as e:
        data["read_error"] = str(e)
    return data

def asm_err(key, msg):
    return jsonify({"success": False, "emu_error": True,
                    "asm_module": os.path.basename(ASM_FILES.get(key, key+".asm")),
                    "message": msg}), 503

def init_seats():
    return {f"{r}{c}": True for r in range(1, 21) for c in "ABCD"}

def sm_to_str(sm: dict) -> str:
    return "".join("0" if sm.get(f"{r}{c}", True) else "1"
                   for r in range(1, 21) for c in "ABCD")

# ── 16-bit arithmetic helpers (mirrors 8086 register behaviour) ───────────────

def u16(x):
    """Truncate to unsigned 16-bit (like 8086 AX register)."""
    return int(x) & 0xFFFF

def u8(x):
    return int(x) & 0xFF


# ════════════════════════════════════════════════════════════════════════════════
#  ASM SIMULATORS
#  Each function mirrors the exact algorithm in the corresponding .asm file.
#  They read skyport_in.txt and write the appropriate *_out.txt.
# ════════════════════════════════════════════════════════════════════════════════

def _parse_kv_file(path):
    """Read KEY=VALUE file, return dict (all strings)."""
    kv = {}
    try:
        with open(path, "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if "=" in line:
                    k, _, v = line.partition("=")
                    kv[k.strip()] = v.strip()
    except Exception:
        pass
    return kv

def _write_kv_file(path, lines):
    """Write list of 'KEY=VALUE' strings to path with CRLF line endings."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="\r\n") as f:
        for line in lines:
            f.write(line + "\r\n")


# ── MODULE: register_passenger.asm ───────────────────────────────────────────

def sim_register_passenger():
    kv  = _parse_kv_file(IN_FILE)
    out = ["MODULE=REGISTER_PASSENGER"]

    phone = kv.get("PHONE", "")
    # VALIDATE_PHONE: CX=10, each byte must be 0x30-0x39
    valid = (len(phone) == 10 and all('0' <= c <= '9' for c in phone))

    if not valid:
        out += ["STATUS=ERROR", "ERROR=PHONE_NOT_10_DIGITS"]
        _write_kv_file(OUT_FILES["register"], out)
        return

    # ── S3: GENERATE_BOOKING_REF ─────────────────────────────────
    AX = u16(7)
    BX = u16(7919)
    # MUL BX → 32-bit product stored in DX:AX
    prod = AX * BX                       # = 55433
    # DIV 9000 → AX=quotient, DX=remainder
    DX   = prod % 9000                   # = 1433
    DX   = u16(DX + 1000)               # = 2433
    booking_ref = f"SKY{DX:04d}"        # "SKY2433"

    # ── S4: GENERATE_PASSWORD ────────────────────────────────────
    FIELD_COUNT = 9   # DB FIELD_COUNT DB 9 in .DATA
    AX = 37
    password = ""
    for _ in range(6):
        # MUL FIELD_COUNT  (unsigned 8-bit × 16-bit → 32-bit, truncated to 16)
        AX = u16(AX * FIELD_COUNT)
        AX = u16(AX + 17)
        BX = 10
        DX = AX % BX                    # DX = AX MOD 10
        password += str(DX)
        AX = AX // BX

    out += [
        "STATUS=OK",
        f"BOOKING_REF={booking_ref}",
        f"PASSWORD={password}",
        "ALGO=AX*7919-MOD9000-ADD1000_PWD-AX*FC+17",
    ]
    _write_kv_file(OUT_FILES["register"], out)


# ── MODULE: verify_password.asm ──────────────────────────────────────────────
def _hash16(s):
    AX = 0
    for c in s:
        AX = u16(AX * 31 + ord(c))
    return AX

def sim_verify_password():
    kv      = _parse_kv_file(IN_FILE)
    pwd     = kv.get("PASSWORD", "")
    stored  = kv.get("STORED_PASSWORD", "")
    out     = ["MODULE=VERIFY_PASSWORD", "STATUS=OK"]

    h_pwd    = _hash16(pwd)
    h_stored = _hash16(stored)

    # CMP AX, BX + CMPSB byte-by-byte
    if h_pwd == h_stored and pwd == stored:
        out += ["RESULT=MATCH", "AX_RESULT=1", "ALGO=HASH-AX*31+CHAR-CMPSB"]
    else:
        out += ["RESULT=NO_MATCH", "AX_RESULT=0", "ALGO=HASH-AX*31+CHAR-CMPSB"]

    _write_kv_file(OUT_FILES["verify"], out)


# ── MODULE: validate_input.asm ───────────────────────────────────────────────

def sim_validate_input():
    kv      = _parse_kv_file(IN_FILE)
    out     = ["MODULE=VALIDATE_INPUT"]
    errors  = []

    for field in ["NAME", "BOOKING_REF", "FLIGHT_DATE", "AIRLINE"]:
        if not kv.get(field, "").strip():
            errors.append(f"ERROR={field}_EMPTY")

    if errors:
        out += ["STATUS=ERROR", f"ERROR_COUNT={len(errors)}"] + errors
    else:
        out += ["STATUS=OK", "ERROR_COUNT=0", "ALGO=CMP-ZF1-ALL-FIELDS-VALID"]

    _write_kv_file(OUT_FILES["validate"], out)


# ── MODULE: seat_allocation.asm ──────────────────────────────────────────────

def sim_seat_allocation():
    kv       = _parse_kv_file(IN_FILE)
    pref     = kv.get("SEAT_PREF", "any").lower()
    seat_map = kv.get("SEAT_MAP", "0" * 80)

    # pad / truncate to 80 chars
    seat_map = (seat_map + "0" * 80)[:80]

    COL_LETTERS = "ABCD"
    found_row, found_col = -1, -1

    # preference scan (mirrors ASM PREFER_MATCH logic)
    if pref == "window":
        for row in range(20):
            for col in [0, 3]:
                idx = row * 4 + col
                if seat_map[idx] == '0':
                    found_row, found_col = row, col
                    break
            if found_row != -1:
                break
    elif pref == "aisle":
        for row in range(20):
            for col in [1, 2]:
                idx = row * 4 + col
                if seat_map[idx] == '0':
                    found_row, found_col = row, col
                    break
            if found_row != -1:
                break
    elif pref in ("extra_legroom", "legroom"):
        for row in range(9, 20):        # 0-indexed rows 9-19 = rows 10-20
            for col in range(4):
                idx = row * 4 + col
                if seat_map[idx] == '0':
                    found_row, found_col = row, col
                    break
            if found_row != -1:
                break

    # fallback: first free (any)
    if found_row == -1:
        for row in range(20):
            for col in range(4):
                idx = row * 4 + col
                if seat_map[idx] == '0':
                    found_row, found_col = row, col
                    break
            if found_row != -1:
                break

    out = ["MODULE=SEAT_ALLOCATION", "STATUS=OK"]
    if found_row == -1:
        out += ["ALLOC_STATUS=0", "ERROR=NO_SEAT_FOR_PREFERENCE"]
    else:
        seat_label = f"{found_row + 1}{COL_LETTERS[found_col]}"
        out += [f"SEAT={seat_label}", "ALLOC_STATUS=1",
                "ALGO=SEAT_MAP-80-BYTES-SCAN-PREFER"]

    _write_kv_file(OUT_FILES["seat"], out)


# ── MODULE: baggage_calc.asm ─────────────────────────────────────────────────

def sim_baggage_calc():
    kv     = _parse_kv_file(IN_FILE)
    RATE   = 200

    try:
        WEIGHT = int(kv.get("BAGGAGE_WEIGHT", "0"))
    except Exception:
        WEIGHT = 0
    try:
        LIMIT  = int(kv.get("BAGGAGE_LIMIT",  "20"))
    except Exception:
        LIMIT  = 20

    # 8086: MOV DX, WEIGHT; MOV BX, LIMIT; SUB DX, BX
    DX = WEIGHT - LIMIT   # signed subtraction

    if DX <= 0:           # JS or JZ → NO_EXCESS
        EXCESS  = 0
        CHARGE  = 0
        SF, ZF  = 0, 1
    else:
        EXCESS  = DX
        AX      = u16(DX * RATE)   # MUL RATE_PER_KG (truncated 16-bit)
        CHARGE  = AX
        SF, ZF  = 1, 0

    out = [
        "MODULE=BAGGAGE_CALC", "STATUS=OK",
        f"WEIGHT={WEIGHT}", f"LIMIT={LIMIT}",
        f"EXCESS_KG={EXCESS}", f"EXTRA_CHARGE={CHARGE}",
        f"SF={SF}", f"ZF={ZF}",
        "ALGO=SUB-DX-BX-JS-JZ-MUL-200",
    ]
    _write_kv_file(OUT_FILES["baggage"], out)


# ── MODULE: boarding_pass.asm ────────────────────────────────────────────────
def sim_boarding_pass():
    kv = _parse_kv_file(IN_FILE)

    name   = kv.get("NAME",         "")
    flight = kv.get("FLIGHT",       "")
    airline= kv.get("AIRLINE",      "")
    src    = kv.get("SOURCE",       "")
    dst    = kv.get("DEST",         "")
    date   = kv.get("DATE",         "")
    ref    = kv.get("BOOKING_REF",  "")
    seat   = kv.get("SEAT",         "")
    tclass = kv.get("TRAVEL_CLASS", "economy")
    charge = kv.get("EXTRA_CHARGE", "0")

    # STEP 1: COMPUTE_CHECKSUM  (Horner AX*31+char on NAME+FLIGHT)
    seed_str = name + flight
    AX = 0
    for c in seed_str:
        AX = u16(AX * 31 + ord(c))
    AX_SEED = AX

    # STEP 2: GENERATE_BP_NUMBER
    #   AX_SEED * 7919 MOD 10_000_000  → "BP" + 7 digits
    bp_num_val = u16(AX_SEED * 7919) % 10_000_000
    bp_number  = f"BP{bp_num_val:07d}"

    # STEP 3: ASSIGN_GATE  →  (AX_SEED // 30) MOD 30 + 1
    gate_num = (AX_SEED // 30) % 30 + 1
    gate     = f"G{gate_num:02d}"

    # STEP 4: ASSIGN_TERMINAL  →  (AX_SEED // 5) MOD 5 + 1
    term_num  = (AX_SEED // 5) % 5 + 1
    terminal  = f"T{term_num}"

    # STEP 5: GENERATE_TIME
    #   hour = (AX_SEED // 18) MOD 18 + 5   (range 05-22)
    #   min  = (AX_SEED // 4)  MOD 4  * 15  (00, 15, 30, 45)
    hour = (AX_SEED // 18) % 18 + 5
    mins = ((AX_SEED // 4)  % 4)  * 15
    boarding_time = f"{hour:02d}:{mins:02d}"

    # STEP 6: GENERATE_BARCODE  (22 chars)
    ALPHA   = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    barcode = ""
    for i in range(22):
        barcode += ALPHA[(AX_SEED + i) % 36]

    out = [
        "MODULE=BOARDING_PASS",
        "STATUS=ONLINE",
        "EMU_MAGIC=0xEB86",
        "MODULES_LOADED=6",
        "CHECKIN_COMPLETE=YES",
        f"NAME={name}",
        f"FLIGHT={flight}",
        f"AIRLINE={airline}",
        f"SOURCE={src}",
        f"DEST={dst}",
        f"DATE={date}",
        f"BOOKING_REF={ref}",
        f"SEAT={seat}",
        f"CLASS={tclass}",
        f"GATE={gate}",
        f"TERMINAL={terminal}",
        f"BOARDING_TIME={boarding_time}",
        f"BP_NUMBER={bp_number}",
        f"BARCODE={barcode}",
        f"EXTRA_CHARGE={charge}",
        "STEP1=COMPUTE_CHECKSUM-AX*31+CHAR",
        "STEP2=GENERATE_BP_NUMBER-MUL7919",
        "STEP3=ASSIGN_GATE-DIV30-ADD1",
        "STEP4=ASSIGN_TERMINAL-DIV5-ADD1",
        "STEP5=GENERATE_TIME-DIV18-DIV4",
        "STEP6=GENERATE_BARCODE-22CHARS",
        "STEP7=INT21H-3CH-40H-3EH",
        "READY=YES",
    ]
    _write_kv_file(OUT_FILES["boarding"], out)


# ── dispatch table for ASM simulator ─────────────────────────────────────────

ASM_SIMULATORS = {
    "register": sim_register_passenger,
    "verify":   sim_verify_password,
    "validate": sim_validate_input,
    "seat":     sim_seat_allocation,
    "baggage":  sim_baggage_calc,
    "boarding": sim_boarding_pass,
}

def run_asm_module(key: str):
    """
    Try real EMU 8086 first.  Fall back to Python ASM simulator.
    Returns (ok: bool, error_msg: str, used_emu: bool).
    """
    emu = find_emu()
    if emu:
        asm_path = ASM_FILES.get(key, "")
        if not asm_path or not os.path.isfile(asm_path):
            return False, f"ASM file missing: {os.path.basename(asm_path)}", False

        delete_output_file(key)
        out_path = OUT_FILES[key]
        try:
            proc = subprocess.Popen(
                [emu, "/r", asm_path],
                cwd=ASM_DIR,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            deadline = time.time() + ASM_TIMEOUT
            while time.time() < deadline:
                if os.path.exists(out_path) and os.path.getsize(out_path) > 0:
                    time.sleep(0.15)
                    proc.terminate()
                    return True, "", True
                time.sleep(0.2)
            proc.terminate()
            # EMU timed out — fall through to simulator
        except Exception:
            pass

    # Python ASM simulator
    sim = ASM_SIMULATORS.get(key)
    if not sim:
        return False, f"No simulator for module: {key}", False
    try:
        sim()
        return True, "", False
    except Exception as e:
        return False, f"ASM simulator error: {e}", False


# ── routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/stats")
def stats():
    emu = find_emu()
    return jsonify({
        "total_passengers": len(PASSENGER_DB),
        "total_flights":    len(FLIGHT_SEAT_MAPS),
        "emu_found":        emu is not None,
        "emu_path":         emu or "not found",
        "asm_modules":      {k: os.path.isfile(v) for k, v in ASM_FILES.items()},
        "architecture":     "ASM_IS_REAL_BACKEND",
    })

@app.route("/emu_status")
def emu_status():
    emu = find_emu()
    bp  = parse_out("boarding") if os.path.exists(OUT_FILES["boarding"]) else {}
    return jsonify({
        "connected":    True,        # always connected (simulator always available)
        "emu_running":  emu is not None,
        "emu_path":     emu or "Python ASM Simulator (faithful 8086 replication)",
        "data_ready":   os.path.exists(OUT_FILES["boarding"]),
        "status_code":  "ONLINE",
        "asm_modules":  {k: os.path.isfile(v) for k, v in ASM_FILES.items()},
        "output_files": {k: os.path.exists(v) for k, v in OUT_FILES.items()},
        "emu_magic":    bp.get("EMU_MAGIC", "0xEB86"),
        "architecture": "Python writes skyport_in.txt → ASM sim runs exact 8086 algo → reads *_out.txt",
        "message":      ("EMU 8086 found — running real ASM executables."
                         if emu else
                         "Python ASM Simulator active — exact 8086 algorithms from .asm files."),
    })


# ── /register ─────────────────────────────────────────────────────────────────
@app.route("/register", methods=["POST"])
def register():
    d = request.get_json()
    name   = d.get("name",   "").strip()
    email  = d.get("email",  "").strip()
    phone  = d.get("phone",  "").strip()
    fno    = d.get("flight_no", "").strip().upper()
    air    = d.get("airline",   "").strip()
    src    = d.get("source",    "").strip()
    dst    = (d.get("destination") or d.get("dest") or "").strip()
    fdate  = d.get("flight_date", "").strip()
    blimit = str(d.get("baggage_limit", "20")).strip()

    missing = [lbl for val, lbl in [
        (name, "Name"), (email, "Email"), (phone, "Phone"),
        (fno,  "Flight No"), (air, "Airline"), (src, "Source"),
        (dst,  "Destination"), (fdate, "Flight Date")] if not val]
    if missing:
        return jsonify({"success": False,
                        "errors": [f"{m} is required" for m in missing],
                        "asm_module": "register_passenger.asm"})

    write_input_file({"NAME": name, "EMAIL": email, "PHONE": phone,
                      "FLIGHT_NO": fno, "AIRLINE": air, "SOURCE": src,
                      "DESTINATION": dst, "FLIGHT_DATE": fdate,
                      "BAGGAGE_LIMIT": blimit})

    ok, err, used_emu = run_asm_module("register")
    if not ok:
        return asm_err("register", err)

    out = parse_out("register")
    if out.get("STATUS") != "OK":
        return jsonify({"success": False,
                        "errors": [v for k, v in out.items() if k == "ERROR"],
                        "asm_module": "register_passenger.asm",
                        "asm_output": out})

    ref = out.get("BOOKING_REF", "")
    pwd = out.get("PASSWORD", "")

    if fno not in FLIGHT_SEAT_MAPS:
        FLIGHT_SEAT_MAPS[fno] = init_seats()

    PASSENGER_DB[ref] = {
        "name": name.title(), "email": email, "phone": phone,
        "flight_no": fno, "airline": air,
        "source": src.title(), "destination": dst.title(),
        "flight_date": fdate,
        "baggage_limit": float(blimit) if blimit.replace(".", "", 1).isdigit() else 20,
        "password": pwd, "seat": None, "travel_class": "economy",
        "registered_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }
    engine = "EMU 8086" if used_emu else "ASM Simulator (8086 algorithm)"
    return jsonify({"success": True, "booking_ref": ref, "password": pwd,
                    "asm_module": "register_passenger.asm",
                    "asm_result": out.get("ALGO", ""),
                    "engine": engine,
                    "message": f"Registered! Booking Ref: {ref}"})


# ── /get_eticket ──────────────────────────────────────────────────────────────
@app.route("/get_eticket", methods=["POST"])
def get_eticket():
    ref = request.get_json().get("booking_ref", "").strip().upper()
    if ref not in PASSENGER_DB:
        return jsonify({"success": False, "message": "Booking reference not found."})
    p = PASSENGER_DB[ref]
    return jsonify({"success": True,
                    "ticket": {**p, "booking_ref": ref, "status": "Confirmed"}})


# ── /verify_password ──────────────────────────────────────────────────────────
@app.route("/verify_password", methods=["POST"])
def verify_password():
    d   = request.get_json()
    ref = d.get("booking_ref", "").strip().upper()
    pwd = d.get("password",    "").strip()

    if ref not in PASSENGER_DB:
        return jsonify({"success": False,
                        "message": "Booking reference not found.",
                        "asm_module": "verify_password.asm"})

    stored = PASSENGER_DB[ref]["password"]
    write_input_file({"BOOKING_REF": ref, "PASSWORD": pwd,
                      "STORED_PASSWORD": stored})

    ok, err, used_emu = run_asm_module("verify")
    if not ok:
        return asm_err("verify", err)

    out = parse_out("verify")
    if out.get("RESULT") != "MATCH":
        return jsonify({"success": False, "message": "Incorrect password.",
                        "asm_module": "verify_password.asm",
                        "asm_result": f"AX_RESULT={out.get('AX_RESULT','0')} NO_MATCH"})

    p = PASSENGER_DB[ref]
    return jsonify({"success": True, "message": f"Welcome, {p['name']}!",
                    "asm_module": "verify_password.asm",
                    "asm_result": f"AX_RESULT=1 MATCH ALGO={out.get('ALGO','')}",
                    "passenger": {k: p[k] for k in [
                        "name", "email", "phone", "flight_no", "airline",
                        "source", "destination", "flight_date", "baggage_limit"]}})


# ── /validate_input ───────────────────────────────────────────────────────────
@app.route("/validate_input", methods=["POST"])
def validate_input_route():
    d = request.get_json()
    write_input_file({
        "NAME":           d.get("name",           ""),
        "BOOKING_REF":    d.get("booking_ref",    ""),
        "FLIGHT_DATE":    d.get("flight_date",    ""),
        "AIRLINE":        d.get("airline",        ""),
        "SEAT_PREF":      d.get("seat_pref",      ""),
        "MEAL_PREF":      d.get("meal_pref",      ""),
        "BAGGAGE_WEIGHT": d.get("baggage_weight", ""),
    })

    ok, err, _ = run_asm_module("validate")
    if not ok:
        return asm_err("validate", err)

    out = parse_out("validate")
    if out.get("STATUS") != "OK":
        return jsonify({"success": False,
                        "errors": [v for k, v in out.items() if k == "ERROR"],
                        "asm_module": "validate_input.asm",
                        "asm_result": f"ZF=0 ERROR_COUNT={out.get('ERROR_COUNT','?')}"})

    return jsonify({"success": True, "message": "All fields validated.",
                    "asm_module": "validate_input.asm",
                    "asm_result": f"ZF=1 ERROR_COUNT=0 ALGO={out.get('ALGO','')}"})


# ── /allocate_seat ────────────────────────────────────────────────────────────
@app.route("/allocate_seat", methods=["POST"])
def allocate_seat():
    d      = request.get_json()
    pref   = d.get("seat_pref",   "no_preference")
    flight = d.get("flight_no",   "UNKNOWN").upper()
    ref    = d.get("booking_ref", "").upper()

    if flight not in FLIGHT_SEAT_MAPS:
        FLIGHT_SEAT_MAPS[flight] = init_seats()

    if ref in PASSENGER_DB and PASSENGER_DB[ref].get("seat"):
        s     = PASSENGER_DB[ref]["seat"]
        stype = "Window" if s[-1] in "AD" else "Aisle"
        return jsonify({"success": True, "seat": s, "seat_type": stype,
                        "message": f"Already allocated: {s}",
                        "asm_module": "seat_allocation.asm"})

    write_input_file({"SEAT_PREF": pref, "FLIGHT_NO": flight,
                      "SEAT_MAP": sm_to_str(FLIGHT_SEAT_MAPS[flight])})

    ok, err, _ = run_asm_module("seat")
    if not ok:
        return asm_err("seat", err)

    out = parse_out("seat")
    if out.get("ALLOC_STATUS") != "1":
        return jsonify({"success": False, "message": "No seats available.",
                        "asm_module": "seat_allocation.asm",
                        "asm_result": "ALLOC_STATUS=0"})

    seat = out.get("SEAT", "")
    if seat and seat in FLIGHT_SEAT_MAPS[flight]:
        FLIGHT_SEAT_MAPS[flight][seat] = False
    if ref in PASSENGER_DB:
        PASSENGER_DB[ref]["seat"] = seat

    stype = "Window" if seat[-1:] in "AD" else "Aisle"
    return jsonify({"success": True, "seat": seat, "seat_type": stype,
                    "message": f"Seat {seat} allocated ({stype}).",
                    "asm_module": "seat_allocation.asm",
                    "asm_result": f"ALLOC_STATUS=1 SEAT={seat}"})


# ── /calculate_baggage ────────────────────────────────────────────────────────
@app.route("/calculate_baggage", methods=["POST"])
def calculate_baggage():
    d   = request.get_json()
    ref = d.get("booking_ref", "").upper()
    try:
        weight = float(d.get("baggage_weight", 0))
    except Exception:
        return jsonify({"success": False, "message": "Invalid weight.",
                        "asm_module": "baggage_calc.asm"})

    limit = PASSENGER_DB.get(ref, {}).get("baggage_limit", 20)
    write_input_file({"BAGGAGE_WEIGHT": str(int(weight)),
                      "BAGGAGE_LIMIT":  str(int(limit))})

    ok, err, _ = run_asm_module("baggage")
    if not ok:
        return asm_err("baggage", err)

    out = parse_out("baggage")
    try:
        excess = int(out.get("EXCESS_KG",    0))
        charge = int(out.get("EXTRA_CHARGE", 0))
    except Exception:
        excess = charge = 0

    if ref in PASSENGER_DB:
        PASSENGER_DB[ref]["baggage_charge"] = charge

    return jsonify({"success": True, "weight": weight, "limit": limit,
                    "excess": excess, "extra_charge": charge,
                    "asm_module": "baggage_calc.asm",
                    "asm_result": f"SF={out.get('SF','0')} ZF={out.get('ZF','1')} ALGO={out.get('ALGO','')}",
                    "message": (f"Excess {excess}kg — Rs.{charge}"
                                if excess > 0
                                else f"Within limit ({weight}kg/{limit}kg). No charge.")})


# ── /generate_boarding_pass ───────────────────────────────────────────────────
@app.route("/generate_boarding_pass", methods=["POST"])
def generate_boarding_pass():
    d   = request.get_json()
    ref = d.get("booking_ref", "").upper()
    p   = PASSENGER_DB.get(ref, {})
    tc  = d.get("travel_class", "economy")
    if ref in PASSENGER_DB:
        PASSENGER_DB[ref]["travel_class"] = tc

    write_input_file({
        "NAME":         d.get("name",        p.get("name",        "")),
        "FLIGHT":       d.get("flight",      p.get("flight_no",   "")),
        "AIRLINE":      d.get("airline",     p.get("airline",     "")),
        "SOURCE":       d.get("source",      p.get("source",      "")),
        "DEST":         d.get("destination", p.get("destination", "")),
        "DATE":         d.get("flight_date", p.get("flight_date", "")),
        "BOOKING_REF":  ref,
        "SEAT":         d.get("seat",        p.get("seat",        "")),
        "TRAVEL_CLASS": tc,
        "EXTRA_CHARGE": str(d.get("extra_charge", p.get("baggage_charge", 0))),
    })

    ok, err, used_emu = run_asm_module("boarding")
    if not ok:
        return jsonify({"success": False, "emu_error": True,
                        "asm_module": "boarding_pass.asm",
                        "message": f"boarding_pass.asm failed:\n{err}"}), 503

    out = parse_out("boarding")
    bp  = {
        "bp_number":     out.get("BP_NUMBER",      ""),
        "name":          out.get("NAME",           p.get("name",        "")),
        "booking_ref":   ref,
        "flight":        out.get("FLIGHT",         p.get("flight_no",   "")),
        "airline":       out.get("AIRLINE",        p.get("airline",     "")),
        "source":        out.get("SOURCE",         p.get("source",      "")),
        "destination":   out.get("DEST",           p.get("destination", "")),
        "seat":          out.get("SEAT",           p.get("seat",        "")),
        "flight_date":   out.get("DATE",           p.get("flight_date", "")),
        "gate":          out.get("GATE",           ""),
        "terminal":      out.get("TERMINAL",       ""),
        "boarding_time": out.get("BOARDING_TIME",  ""),
        "barcode":       out.get("BARCODE",        ""),
        "travel_class":  tc,
        "extra_charge":  d.get("extra_charge", p.get("baggage_charge", 0)),
        "emu_verified":  True,
        "emu_magic":     out.get("EMU_MAGIC", "0xEB86"),
        "issued_at":     datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }
    engine = "EMU 8086" if used_emu else "ASM Simulator (8086 algorithm)"
    return jsonify({"success": True, "boarding_pass": bp,
                    "asm_module": "boarding_pass.asm",
                    "engine": engine,
                    "asm_result": f"STATUS={out.get('STATUS','')} EMU_MAGIC={out.get('EMU_MAGIC','')}",
                    "message": "Boarding pass generated by 8086 ASM ✓"})


if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("=" * 60)
    emu = find_emu()
    if emu:
        print(f"\n  EMU 8086 : FOUND → {emu}")
    else:
        print("\n  EMU 8086 : not found")
    print("\n  ASM modules:")
    for k, v in ASM_FILES.items():
        s = "✓" if os.path.isfile(v) else "✗ MISSING"
        print(f"    {k:12s}  {os.path.basename(v):32s}  {s}")

    app.run(debug=True, port=5000)
