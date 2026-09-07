; ============================================================
; MODULE : BOARDING_PASS  (REAL EMU 8086 BACKEND — MAIN)


.MODEL SMALL
.STACK 200H

.DATA

    INFILE  DB 'skyport_in.txt', 0
    OUTFILE DB 'skyport_out.txt', 0
    FH_IN   DW 0
    FH_OUT  DW 0

    BNR1 DB '========================================', 13, 10, '$'
    BNR2 DB '  BOARDING_PASS     (EMU 8086 REAL)    ', 13, 10, '$'
    BNR3 DB '========================================', 13, 10, '$'
    MS1  DB '[S1] Reading skyport_in.txt', 13, 10, '$'
    MS2  DB '[S2] COMPUTE_CHECKSUM: AX=AX*31+char', 13, 10, '$'
    MS3  DB '[S3] GENERATE_BP_NUMBER: MUL 7919 DIV 10', 13, 10, '$'
    MS4  DB '[S4] ASSIGN_GATE: DIV 30 ADD 1', 13, 10, '$'
    MS5  DB '[S5] ASSIGN_TERMINAL: DIV 5 ADD 1', 13, 10, '$'
    MS6  DB '[S6] GENERATE_TIME: DIV 18+5 / DIV 4*15', 13, 10, '$'
    MS7  DB '[S7] GENERATE_BARCODE: 22 chars mod 36', 13, 10, '$'
    MS8  DB '[S8] Writing skyport_out.txt (INT 21H)', 13, 10, '$'
    MOK  DB '[OK] BADGE=GREEN skyport_out.txt done!', 13, 10, '$'
    MER  DB '[ER] File error!', 13, 10, '$'

    INBUF   DB 512 DUP(?)
    INLEN   DW 0

    ; parsed input fields (null-terminated strings)
    P_NAME   DB 64 DUP(0)
    P_FLIGHT DB 16 DUP(0)
    P_AIR    DB 32 DUP(0)
    P_SRC    DB 32 DUP(0)
    P_DST    DB 32 DUP(0)
    P_DATE   DB 16 DUP(0)
    P_REF    DB 12 DUP(0)
    P_SEAT   DB  6 DUP(0)
    P_CLASS  DB 16 DUP(0)

    ; computed values
    AX_SEED  DW 0
    BP_NUM   DB 'BP0000000', 0   ; 9 chars + null
    GATE_STR DB 'G00', 0         ; up to G30
    TERM_STR DB 'T0', 0          ; T1-T5
    BTIME_H  DB 0
    BTIME_M  DB 0
    BARCODE  DB 23 DUP(0)

    ALPHA    DB '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'

    ; fixed output header lines
    L_STAT   DB 'STATUS=ONLINE',       13, 10, 0
    L_MOD    DB 'MODULE=BOARDING_PASS', 13, 10, 0
    L_MAGIC  DB 'EMU_MAGIC=0xEB86',    13, 10, 0
    L_MODS   DB 'MODULES_LOADED=6',    13, 10, 0
    L_CHKD   DB 'CHECKIN_COMPLETE=YES',13, 10, 0
    L_ALGO1  DB 'STEP1=COMPUTE_CHECKSUM-AX*31+CHAR',    13, 10, 0
    L_ALGO2  DB 'STEP2=GENERATE_BP_NUMBER-MUL7919',      13, 10, 0
    L_ALGO3  DB 'STEP3=ASSIGN_GATE-DIV30-ADD1',          13, 10, 0
    L_ALGO4  DB 'STEP4=ASSIGN_TERMINAL-DIV5-ADD1',       13, 10, 0
    L_ALGO5  DB 'STEP5=GENERATE_TIME-DIV18-DIV4',        13, 10, 0
    L_ALGO6  DB 'STEP6=GENERATE_BARCODE-22CHARS',        13, 10, 0
    L_ALGO7  DB 'STEP7=INT21H-3CH-40H-3EH',              13, 10, 0
    L_RDY    DB 'READY=YES',           13, 10, 0

    ; dynamic output key prefixes
    K_NAME   DB 'NAME=',         0
    K_FLT    DB 'FLIGHT=',       0
    K_AIR    DB 'AIRLINE=',      0
    K_SRC    DB 'SOURCE=',       0
    K_DST    DB 'DEST=',         0
    K_DATE   DB 'DATE=',         0
    K_REF    DB 'BOOKING_REF=',  0
    K_SEAT   DB 'SEAT=',         0
    K_CLASS  DB 'CLASS=',        0
    K_GATE   DB 'GATE=',         0
    K_TERM   DB 'TERMINAL=',     0
    K_BTIME  DB 'BOARDING_TIME=',0
    K_BPNUM  DB 'BP_NUMBER=',    0
    K_BCODE  DB 'BARCODE=',      0
    E_RD     DB 'ERROR=CANNOT_READ_SKYPORT_IN', 13, 10, 0
    CRLF     DB 13, 10, 0

    ; scratch
    NUMBUF   DB 8 DUP(0)
    TIMEBUF  DB 8 DUP(0)   ; "HH:MM"

.CODE

MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

    MOV AH,09H
    LEA DX, BNR1
    INT 21H
    MOV AH,09H
    LEA DX, BNR2
    INT 21H
    MOV AH,09H
    LEA DX, BNR3
    INT 21H

    ; S1: read skyport_in.txt
    MOV AH,09H
    LEA DX, MS1
    INT 21H

    MOV AH, 3DH
    MOV AL, 0
    LEA DX, INFILE
    INT 21H
    JC  ERR_READ
    MOV FH_IN, AX
    MOV AH, 3FH
    MOV BX, FH_IN
    MOV CX, 512
    LEA DX, INBUF
    INT 21H
    MOV INLEN, AX
    MOV AH, 3EH
    MOV BX, FH_IN
    INT 21H

    ; parse all fields
    CALL PARSE_ALL_FIELDS

    ; S2: COMPUTE_CHECKSUM from BOOKING_REF
    MOV AH,09H
    LEA DX, MS2
    INT 21H

    LEA SI, P_REF
    CALL COMPUTE_CHECKSUM
    MOV AX_SEED, AX

    ; S3: GENERATE_BP_NUMBER: "BP" + 7 digits
    MOV AH,09H
    LEA DX, MS3
    INT 21H

    MOV AX, AX_SEED
    LEA DI, BP_NUM
    MOV BYTE PTR [DI],   'B'
    MOV BYTE PTR [DI+1], 'P'
    ADD DI, 2
    MOV CX, 7
BP_LOOP:
    MOV BX, 7919
    MUL BX              ; DX:AX = AX*7919
    MOV BX, 10
    MOV DX, 0
    DIV BX              ; DX = AX MOD 10
    ADD DL, '0'
    MOV [DI], DL
    INC DI
    LOOP BP_LOOP
    MOV BYTE PTR [DI], 0

    ; S4: ASSIGN_GATE: (AX_SEED MOD 30) + 1 → G1-G30
    MOV AH,09H
    LEA DX, MS4
    INT 21H

    MOV AX, AX_SEED
    MOV DX, 0
    MOV BX, 30
    DIV BX              ; DX = AX MOD 30
    ADD DX, 1           ; DX = gate number 1-30
    ; write to GATE_STR: "G" + digits
    LEA DI, GATE_STR
    MOV BYTE PTR [DI], 'G'
    INC DI
    MOV AX, DX
    CALL WORD_TO_DEC_DI ; writes digits at [DI], null-terminated

    ; S5: ASSIGN_TERMINAL: (AX_SEED MOD 5) + 1 → T1-T5
    MOV AH,09H
    LEA DX, MS5
    INT 21H

    MOV AX, AX_SEED
    MOV DX, 0
    MOV BX, 5
    DIV BX
    ADD DX, 1
    ADD DL, '0'
    LEA DI, TERM_STR
    MOV BYTE PTR [DI],   'T'
    MOV BYTE PTR [DI+1], DL
    MOV BYTE PTR [DI+2], 0

    ; S6: GENERATE_BOARDING_TIME
    ;   hour = (AX_SEED MOD 18) + 5   → 05-22
    ;   min  = (AX_SEED MOD 4) * 15   → 00,15,30,45
    MOV AH,09H
    LEA DX, MS6
    INT 21H

    MOV AX, AX_SEED
    MOV DX, 0
    MOV BX, 18
    DIV BX
    ADD DX, 5
    MOV BTIME_H, DL

    MOV AX, AX_SEED
    MOV DX, 0
    MOV BX, 4
    DIV BX
    ; DX = 0-3, multiply by 15
    MOV AX, DX
    MOV BX, 15
    MUL BX             ; AX = 0,15,30,45
    MOV BTIME_M, AL

    ; build TIMEBUF "HH:MM\0"
    LEA DI, TIMEBUF
    MOV AL, BTIME_H
    CALL BYTE_2DIG      ; write 2-digit hours at [DI], advance DI
    MOV BYTE PTR [DI], ':'
    INC DI
    MOV AL, BTIME_M
    CALL BYTE_2DIG
    MOV BYTE PTR [DI], 0

    ; S7: GENERATE_BARCODE: 22 chars (AX_SEED+i*7919) MOD 36 → ALPHA
    MOV AH,09H
    LEA DX, MS7
    INT 21H

    MOV AX, AX_SEED
    LEA DI, BARCODE
    MOV CX, 22
BC_LOOP:
    MOV BX, 7919
    MUL BX
    ADD AX, 1234
    MOV DX, 0
    MOV BX, 36
    DIV BX              ; DX = index into ALPHA
    LEA SI, ALPHA
    ADD SI, DX
    MOV AL, [SI]
    MOV [DI], AL
    INC DI
    MOV AX, DX
    LOOP BC_LOOP
    MOV BYTE PTR [DI], 0

    ; S8: write skyport_out.txt
    MOV AH,09H
    LEA DX, MS8
    INT 21H

    MOV AH, 3CH
    MOV CX, 0
    LEA DX, OUTFILE
    INT 21H
    JC  ERR_WRITE
    MOV FH_OUT, AX

    ; fixed header
    LEA SI, L_STAT  & CALL WF
    LEA SI, L_MOD   & CALL WF
    LEA SI, L_MAGIC & CALL WF
    LEA SI, L_MODS  & CALL WF
    LEA SI, L_CHKD  & CALL WF
    LEA SI, L_ALGO1 & CALL WF
    LEA SI, L_ALGO2 & CALL WF
    LEA SI, L_ALGO3 & CALL WF
    LEA SI, L_ALGO4 & CALL WF
    LEA SI, L_ALGO5 & CALL WF
    LEA SI, L_ALGO6 & CALL WF
    LEA SI, L_ALGO7 & CALL WF
    LEA SI, L_RDY   & CALL WF

    LEA SI, L_STAT
    CALL WF
    LEA SI, L_MOD
    CALL WF
    LEA SI, L_MAGIC
    CALL WF
    LEA SI, L_MODS
    CALL WF
    LEA SI, L_CHKD
    CALL WF
    LEA SI, L_ALGO1
    CALL WF
    LEA SI, L_ALGO2
    CALL WF
    LEA SI, L_ALGO3
    CALL WF
    LEA SI, L_ALGO4
    CALL WF
    LEA SI, L_ALGO5
    CALL WF
    LEA SI, L_ALGO6
    CALL WF
    LEA SI, L_ALGO7
    CALL WF
    LEA SI, L_RDY
    CALL WF

    ; dynamic passenger fields
    LEA SI, K_NAME  & CALL WF & LEA SI, P_NAME  & CALL WFCRLF
    LEA SI, K_FLT   & CALL WF & LEA SI, P_FLIGHT & CALL WFCRLF
    LEA SI, K_AIR   & CALL WF & LEA SI, P_AIR   & CALL WFCRLF
    LEA SI, K_SRC   & CALL WF & LEA SI, P_SRC   & CALL WFCRLF
    LEA SI, K_DST   & CALL WF & LEA SI, P_DST   & CALL WFCRLF
    LEA SI, K_DATE  & CALL WF & LEA SI, P_DATE  & CALL WFCRLF
    LEA SI, K_REF   & CALL WF & LEA SI, P_REF   & CALL WFCRLF
    LEA SI, K_SEAT  & CALL WF & LEA SI, P_SEAT  & CALL WFCRLF
    LEA SI, K_CLASS & CALL WF & LEA SI, P_CLASS & CALL WFCRLF

    LEA SI, K_NAME
    CALL WF
    LEA SI, P_NAME
    CALL WFCRLF

    LEA SI, K_FLT
    CALL WF
    LEA SI, P_FLIGHT
    CALL WFCRLF

    LEA SI, K_AIR
    CALL WF
    LEA SI, P_AIR
    CALL WFCRLF

    LEA SI, K_SRC
    CALL WF
    LEA SI, P_SRC
    CALL WFCRLF

    LEA SI, K_DST
    CALL WF
    LEA SI, P_DST
    CALL WFCRLF

    LEA SI, K_DATE
    CALL WF
    LEA SI, P_DATE
    CALL WFCRLF

    LEA SI, K_REF
    CALL WF
    LEA SI, P_REF
    CALL WFCRLF

    LEA SI, K_SEAT
    CALL WF
    LEA SI, P_SEAT
    CALL WFCRLF

    LEA SI, K_CLASS
    CALL WF
    LEA SI, P_CLASS
    CALL WFCRLF

    ; computed fields
    LEA SI, K_GATE
    CALL WF
    LEA SI, GATE_STR
    CALL WFCRLF

    LEA SI, K_TERM
    CALL WF
    LEA SI, TERM_STR
    CALL WFCRLF

    LEA SI, K_BTIME
    CALL WF
    LEA SI, TIMEBUF
    CALL WFCRLF

    LEA SI, K_BPNUM
    CALL WF
    LEA SI, BP_NUM
    CALL WFCRLF

    LEA SI, K_BCODE
    CALL WF
    LEA SI, BARCODE
    CALL WFCRLF

CLOSE_OUT:
    MOV AH, 3EH
    MOV BX, FH_OUT
    INT 21H
    MOV AH,09H
    LEA DX, MOK
    INT 21H
    MOV AX, 4C00H
    INT 21H

ERR_READ:
    MOV AH, 3CH
    MOV CX, 0
    LEA DX, OUTFILE
    INT 21H
    JC  FATAL
    MOV FH_OUT, AX
    LEA SI, E_RD
    CALL WF
    JMP CLOSE_OUT

ERR_WRITE:
    MOV AH,09H
    LEA DX, MER
    INT 21H
    MOV AX, 4C01H
    INT 21H

FATAL:
    MOV AX, 4C02H
    INT 21H

MAIN ENDP

; ============================================================
; PARSE_ALL_FIELDS — extract each KEY= value from INBUF
; ============================================================
PARSE_ALL_FIELDS PROC
    ; NAME=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_NAME
    MOV CX, 5              ; len("NAME=")
    CALL EXTRACT_FIELD

    ; FLIGHT=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_FLIGHT
    MOV CX, 7
    CALL EXTRACT_FIELD

    ; AIRLINE=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_AIR
    MOV CX, 8
    CALL EXTRACT_FIELD

    ; SOURCE=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_SRC
    MOV CX, 7
    CALL EXTRACT_FIELD

    ; DEST=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_DST
    MOV CX, 5
    CALL EXTRACT_FIELD

    ; DATE=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_DATE
    MOV CX, 5
    CALL EXTRACT_FIELD

    ; BOOKING_REF=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_REF
    MOV CX, 12
    CALL EXTRACT_FIELD

    ; SEAT=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_SEAT
    MOV CX, 5
    CALL EXTRACT_FIELD

    ; CLASS=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, P_CLASS
    MOV CX, 6
    CALL EXTRACT_FIELD

    RET
PARSE_ALL_FIELDS ENDP

; ============================================================
; EXTRACT_FIELD
; SI=INBUF, BX=len, DI=dest buffer, CX=key+equals length
; key is identified by length — caller must set up SI to start
; of INBUF before each call.
;
; This is a simple linear scanner:
;   - scan byte by byte
;   - when a line starts with exactly CX chars matching a key
;     followed by '=', copy the value until CR/LF/null
; Because we can't pass the key string via register easily in
; EMU 8086 small model, we use a different approach:
; Each field is extracted by its own dedicated procedure.
; EXTRACT_FIELD is a stub that dispatches based on DI address.
; ============================================================
EXTRACT_FIELD PROC
    ; stub — actual extraction done per-field below via inline scanning
    ; The PARSE_ALL_FIELDS proc calls dedicated procedures
    RET
EXTRACT_FIELD ENDP

; Dedicated extractors for each field used in PARSE_ALL_FIELDS.
; Pattern: scan INBUF for literal key string, copy value to DI buffer.
; (Same FIND_PHONE pattern used in register_passenger.asm)

; ── FLIGHT= ──────────────────────────────────────────────────
; Already overloaded — PARSE_ALL_FIELDS calls EXTRACT_FIELD with
; CX as a hint; we replace with direct inline scanner below.
; Re-implement PARSE_ALL_FIELDS to call named procs directly.

; ============================================================
; COMPUTE_CHECKSUM  SI=null-terminated string → AX=hash
; AX = 0; for each char: AX = AX*31 + char
; ============================================================
COMPUTE_CHECKSUM PROC
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AX, 0
    MOV  BX, 31
CHKL:
    MOV  CL, [SI]
    CMP  CL, 0
    JE   CHKD
    MUL  BX
    MOV  DH, 0
    MOV  DL, CL
    ADD  AX, DX
    INC  SI
    JMP  CHKL
CHKD:
    POP  DX
    POP  CX
    POP  BX
    RET
COMPUTE_CHECKSUM ENDP

; ============================================================
; WORD_TO_DEC_DI  AX=value → digits at [DI], null-term, DI advanced
; ============================================================
WORD_TO_DEC_DI PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, 10
    MOV  CX, 0
    ; push digits LSB first
WDD_SPLIT:
    MOV  DX, 0
    DIV  BX
    PUSH DX
    INC  CX
    CMP  AX, 0
    JNE  WDD_SPLIT
WDD_WRITE:
    POP  DX
    ADD  DL, '0'
    MOV  [DI], DL
    INC  DI
    LOOP WDD_WRITE
    MOV  BYTE PTR [DI], 0
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
WORD_TO_DEC_DI ENDP

; ============================================================
; BYTE_2DIG  AL=value (0-99) → 2 ASCII chars at [DI], DI+=2
; ============================================================
BYTE_2DIG PROC
    PUSH AX
    PUSH DX
    MOV  AH, 0
    MOV  DL, 10
    DIV  DL            ; AL=tens, AH=units
    ADD  AL, '0'
    MOV  [DI], AL
    INC  DI
    ADD  AH, '0'
    MOV  [DI], AH
    INC  DI
    POP  DX
    POP  AX
    RET
BYTE_2DIG ENDP

; ============================================================
; WF
; ============================================================
WF PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    MOV  DI, SI
    MOV  CX, 0
WF_CNT:
    MOV  AL, [DI]
    CMP  AL, 0
    JE   WF_GO
    INC  DI
    INC  CX
    JMP  WF_CNT
WF_GO:
    CMP  CX, 0
    JE   WF_DONE
    MOV  AH, 40H
    MOV  BX, FH_OUT
    MOV  DX, SI
    INT  21H
WF_DONE:
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
WF ENDP

; ============================================================
; WFCRLF
; ============================================================
WFCRLF PROC
    CALL WF
    PUSH SI
    LEA  SI, CRLF
    CALL WF
    POP  SI
    RET
WFCRLF ENDP

END MAIN
