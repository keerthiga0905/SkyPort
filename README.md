# ✈️ SkyPort v9 — 8086 Assembly-Powered Airline Management System

[![Flask](https://img.shields.io/badge/Backend-Flask-blue.svg)](https://flask.palletsprojects.com/)
[![Architecture](https://img.shields.io/badge/Architecture-x86_16--bit_Assembly-orange.svg)](https://en.wikipedia.org/wiki/x86_assembly)
[![EMU8086](https://img.shields.io/badge/Emulator-EMU8086%20%7C%20Python%20Sim-green.svg)](https://emu8086.com/)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

**SkyPort v9** is an innovative hybrid airline reservation, passenger check-in, seat allocation, baggage handling, and boarding pass generation platform. The system uniquely leverages low-level **x86 16-bit Assembly algorithms** (run via **EMU8086** executable integration or fallback 8086 register-level Python emulation) integrated seamlessly with a modern **Flask** web application.

---

## 🌟 Key Features

- **Hybrid Execution Engine**: Automatically detects and invokes `emu8086.exe` on Windows systems. If EMU8086 is unavailable, it gracefully falls back to a 100% faithful 16-bit register simulator (`AX`, `BX`, `CX`, `DX`, `ZF`, `SF`).
- **Passenger Registration & Booking Ref Generation**: Validates contact numbers and computes unique booking references using 16-bit arithmetic algorithm (`AX*7919 MOD 9000 + 1000`).
- **Secure Password Verification & Hashing**: Employs a 16-bit Horner's method hashing (`AX = AX * 31 + char`) and `CMPSB` byte-by-byte comparisons.
- **Dynamic 80-Byte Seat Allocation**: Scans and parses 80-character seat maps (rows 1-20, seats A-D) matching passenger preferences (Window, Aisle, Extra Legroom).
- **Baggage Allowance & Excess Charge Calculation**: Computes excess weight using signed subtraction (`SUB DX, BX`) and flag checks (`JS`, `JZ`) at `₹200 / kg`.
- **Digital Boarding Pass Generator**: Synthesizes gate assignments (`G01-G30`), terminal numbers (`T1-T5`), boarding times, and 22-character checksum barcodes.
- **Interactive UI**: Responsive single-page web interface with real-time seat pickers, animated boarding pass rendering, and live EMU status indicator.

---

## 🏗️ 8086 Assembly Modules (`asm/`)

| Module File | Purpose | 8086 Assembly Instructions & Logic |
| :--- | :--- | :--- |
| `register_passenger.asm` | Passenger Registration & Password Generation | `CX` loop validation, 32-bit `MUL`/`DIV` operations for booking ref `SKYxxxx`, linear congruential generator for passwords. |
| `verify_password.asm` | Password Verification | 16-bit string hashing (`AX * 31 + char`), register comparison (`CMP AX, BX`), and string compare byte-by-byte (`CMPSB`). |
| `validate_input.asm` | Input Sanitization & Validation | Validates required fields (`NAME`, `BOOKING_REF`, `FLIGHT_DATE`, `AIRLINE`), setting zero flags (`ZF=1` if valid). |
| `seat_allocation.asm` | Seat Map Scanner & Preference Matcher | Scans 80-byte bitmap in memory, searching for unallocated seats matching window (`A/D`), aisle (`B/C`), or exit row preferences. |
| `baggage_calc.asm` | Excess Weight & Fee Computation | Performs signed subtraction (`SUB DX, BX`), evaluates Sign Flag (`SF`) and Zero Flag (`ZF`), multiplies excess weight by 200 (`MUL`). |
| `boarding_pass.asm` | Boarding Pass Synthesizer & File Output | Computes checksums via Horner hashing, calculates gate/terminal numbers via integer divisions, generates 22-char barcodes, and executes `INT 21h` file I/O operations (`3Ch`, `40h`, `3Eh`). |

---

## 📁 Directory Structure

```text
skyport_v9_fixed/
├── app.py                      # Flask Application Server & Python 8086 ASM Simulator Engine
├── LICENSE                     # Project License
├── .gitignore                  # Git Ignore Configuration
├── asm/                        # 8086 Assembly Source Code & I/O Exchange Files
│   ├── baggage_calc.asm        # Baggage excess fee 8086 algorithm
│   ├── boarding_pass.asm       # Boarding pass generator 8086 algorithm
│   ├── register_passenger.asm  # Registration & ref generator algorithm
│   ├── seat_allocation.asm     # Seat selection algorithm
│   ├── validate_input.asm      # Input validation algorithm
│   ├── verify_password.asm     # Password verification algorithm
│   ├── skyport_in.txt          # Shared input key-value exchange file
│   └── *_out.txt               # Assembly module execution output files
├── static/                     # Web Application Assets
│   ├── css/                    # Custom Stylesheets & Themes
│   └── js/                     # Client-Side Interactive Scripts
└── templates/
    └── index.html              # Main Interactive Web Dashboard
```

---

## 🚀 Getting Started

### Prerequisites

- **Python**: Version `3.8` or higher
- **Flask**: Installed via `pip`
- *(Optional)* **EMU8086 Emulator**: Installed on Windows (`C:\emu8086\emu8086.exe` or standard Program Files path) for hardware-level assembly execution.

### Installation & Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/skyport_v9_fixed.git
   cd skyport_v9_fixed/skyport_v9_fixed
   ```

2. **Create and Activate a Virtual Environment** *(Optional but recommended)*:
   ```bash
   # On Windows
   python -m venv .venv
   .venv\Scripts\activate

   # On macOS/Linux
   python3 -m venv .venv
   source .venv/bin/activate
   ```

3. **Install Dependencies**:
   ```bash
   pip install flask
   ```

4. **Launch the SkyPort Server**:
   ```bash
   python app.py
   ```

5. **Access the Application**:
   Open your browser and navigate to:
   ```text
   http://127.0.0.1:5000
   ```

---

## 📡 API Endpoints

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/` | `GET` | Renders the primary dashboard UI (`index.html`). |
| `/stats` | `GET` | Returns system statistics, total passengers/flights, and EMU8086 connection status. |
| `/emu_status` | `GET` | Queries execution engine status (EMU8086 executable vs. Python ASM Simulator). |
| `/register` | `POST` | Registers a passenger and triggers `register_passenger.asm`. |
| `/verify_password` | `POST` | Authenticates passenger login via `verify_password.asm`. |
| `/validate_input` | `POST` | Validates passenger and check-in details via `validate_input.asm`. |
| `/allocate_seat` | `POST` | Allocates a seat matching preference via `seat_allocation.asm`. |
| `/calculate_baggage`| `POST` | Computes excess baggage charges via `baggage_calc.asm`. |
| `/generate_boarding_pass` | `POST` | Synthesizes and returns full boarding pass metadata via `boarding_pass.asm`. |

---

## 🖥️ Execution Engines

SkyPort v9 supports dual-execution modes:

1. **Native EMU8086 Execution**:
   When EMU8086 is detected on the system, `app.py` writes parameters to `asm/skyport_in.txt`, spawns `emu8086.exe /r <asm_file>`, and reads output from `asm/*_out.txt`.
2. **Register-Level Python Simulator**:
   If EMU8086 is not present, `app.py` utilizes built-in simulator functions that mimic 16-bit 8086 register operations (`u16`, `u8`, bit shifts, modulus, and flag manipulation) ensuring 100% algorithm parity without requiring external emulators.

---

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
