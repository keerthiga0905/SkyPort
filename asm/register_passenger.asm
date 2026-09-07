; ============================================================
; MODULE : REGISTER_PASSENGER  (REAL EMU 8086 BACKEND)


.MODEL SMALL
.STACK 200H

.DATA

    INFILE  DB 'skyport_in.txt',   0
    OUTFILE DB 'register_out.txt', 0
    FH_IN   DW 0
    FH_OUT  DW 0

    BNR1 DB '========================================', 13, 10, '$'
    BNR2 DB '  REGISTER_PASSENGER (EMU 8086 REAL)   ', 13, 10, '$'
    BNR3 DB '========================================', 13, 10, '$'
    MS1  DB '[S1] Reading skyport_in.txt', 13, 10, '$'
    MS2  DB '[S2] VALIDATE_PHONE: CX=10 / 30H-39H', 13, 10, '$'
    MS3  DB '[S3] GENERATE_BOOKING_REF: AX=7*7919', 13, 10, '$'
    MS4  DB '[S4] GENERATE_PASSWORD: AX*FC+17 x6', 13, 10, '$'
    MS5  DB '[S5] Writing register_out.txt', 13, 10, '$'
    MOK  DB '[OK] register_out.txt written!', 13, 10, '$'
    MER  DB '[ER] File error!', 13, 10, '$'

    ; ---- input buffer (read whole file, max 512 bytes) ----
    INBUF   DB 512 DUP(?)
    INLEN   DW 0

    ; ---- parsed phone string ----
    PHONE_BUF  DB 16 DUP(0)
    VALID_FLAG DB 1            ; 1=ok, 0=validation failed

    ; ---- computed results ----
    ; "SKY" + 4 digits, null-terminated
    BOOK_REF   DB 'SKY', '0', '0', '0', '0', 0
    ; 6 digit chars, null-terminated
    PASS_BUF   DB '0', '0', '0', '0', '0', '0', 0

    FIELD_COUNT DW 9           ; constant for password algo

    ; ---- output key strings ----
    K_MOD  DB 'MODULE=REGISTER_PASSENGER', 13, 10, 0
    K_OK   DB 'STATUS=OK',    13, 10, 0
    K_ERR  DB 'STATUS=ERROR', 13, 10, 0
    K_REF  DB 'BOOKING_REF=', 0
    K_PWD  DB 'PASSWORD=',    0
    K_ALGO DB 'ALGO=AX*7919-MOD9000-ADD1000_PWD-AX*FC+17', 13, 10, 0
    E_PHN  DB 'ERROR=PHONE_NOT_10_DIGITS', 13, 10, 0
    E_RD   DB 'ERROR=CANNOT_READ_SKYPORT_IN', 13, 10, 0
    CRLF   DB 13, 10, 0

    ; ---- scratch ----
    TMPNUM DB 6 DUP(0)         ; number→ASCII scratch

.CODE

; ============================================================
MAIN PROC
    MOV  AX, @DATA
    MOV  DS, AX
    MOV  ES, AX

    MOV AH,09H & LEA DX,BNR1 & INT 21H
    MOV AH,09H
    LEA DX, BNR1
    INT 21H
    MOV AH,09H
    LEA DX, BNR2
    INT 21H
    MOV AH,09H
    LEA DX, BNR3
    INT 21H

    ; ── S1: open + read skyport_in.txt ──────────────────────
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

    ; ── S2: parse & validate PHONE= ─────────────────────────
    MOV AH,09H
    LEA DX, MS2
    INT 21H

    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, PHONE_BUF
    CALL FIND_PHONE

    LEA SI, PHONE_BUF
    CALL VALIDATE_PHONE        ; sets VALID_FLAG=0 if bad

    ; ── S3: GENERATE_BOOKING_REF ────────────────────────────
    ;   AX = 7 * 7919 = 55433
    ;   DX = 55433 MOD 9000 = 1433   → +1000 = 2433
    MOV AH,09H
    LEA DX, MS3
    INT 21H

    MOV  AX, 7
    MOV  BX, 7919
    MUL  BX                    ; DX:AX = 55433
    MOV  BX, 9000
    DIV  BX                    ; DX = remainder = 1433
    ADD  DX, 1000              ; DX = 2433

    ; write 4 decimal digits into BOOK_REF+3
    MOV  AX, DX
    LEA  DI, BOOK_REF
    ADD  DI, 3
    CALL W2_4DEC

    ; ── S4: GENERATE_PASSWORD ───────────────────────────────
    ;   AX=37, loop 6×: AX = (AX*FIELD_COUNT + 17), digit = AX MOD 10
    MOV AH,09H
    LEA DX, MS4
    INT 21H

    MOV  AX, 37
    MOV  CX, 6
    LEA  DI, PASS_BUF
PWD_LP:
    MUL  FIELD_COUNT           ; DX:AX = AX*9
    ADD  AX, 17
    MOV  BX, 10
    MOV  DX, 0
    DIV  BX                    ; DX = AX MOD 10
    ADD  DL, '0'
    MOV  [DI], DL
    INC  DI
    LOOP PWD_LP
    MOV  BYTE PTR [DI], 0

    ; ── S5: write register_out.txt ──────────────────────────
    MOV AH,09H
    LEA DX, MS5
    INT 21H

    MOV AH, 3CH
    MOV CX, 0
    LEA DX, OUTFILE
    INT 21H
    JC  ERR_WRITE
    MOV FH_OUT, AX

    LEA SI, K_MOD  & CALL WF

    LEA SI, K_MOD
    CALL WF

    CMP  VALID_FLAG, 0
    JE   WRITE_ERR_LINES

    ; OK path
    LEA SI, K_OK
    CALL WF
    LEA SI, K_REF
    CALL WF
    LEA SI, BOOK_REF
    CALL WFCRLF
    LEA SI, K_PWD
    CALL WF
    LEA SI, PASS_BUF
    CALL WFCRLF
    LEA SI, K_ALGO
    CALL WF
    JMP  CLOSE_OUT

WRITE_ERR_LINES:
    LEA SI, K_ERR
    CALL WF
    LEA SI, E_PHN
    CALL WF
    JMP  CLOSE_OUT

ERR_READ:
    MOV AH, 3CH
    MOV CX, 0
    LEA DX, OUTFILE
    INT 21H
    JC  FATAL
    MOV FH_OUT, AX
    LEA SI, K_ERR & CALL WF
    LEA SI, K_ERR
    CALL WF
    LEA SI, E_RD
    CALL WF

CLOSE_OUT:
    MOV AH, 3EH
    MOV BX, FH_OUT
    INT 21H
    MOV AH,09H
    LEA DX, MOK
    INT 21H
    MOV AX, 4C00H
    INT 21H

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
; FIND_PHONE  — scan INBUF for "PHONE=" and copy value to DI
; SI=INBUF start, BX=byte count, DI=destination
; ============================================================
FIND_PHONE PROC
    PUSH AX
    PUSH CX
FP_SCAN:
    CMP  BX, 6
    JL   FP_NOTFOUND
    MOV  AL, [SI]
    CMP  AL, 'P'
    JNE  FP_SKIP
    CMP  BYTE PTR [SI+1], 'H'
    JNE  FP_SKIP
    CMP  BYTE PTR [SI+2], 'O'
    JNE  FP_SKIP
    CMP  BYTE PTR [SI+3], 'N'
    JNE  FP_SKIP
    CMP  BYTE PTR [SI+4], 'E'
    JNE  FP_SKIP
    CMP  BYTE PTR [SI+5], '='
    JNE  FP_SKIP
    ADD  SI, 6
    MOV  CX, 15
FP_COPY:
    MOV  AL, [SI]
    CMP  AL, 13
    JE   FP_END
    CMP  AL, 10
    JE   FP_END
    CMP  AL, 0
    JE   FP_END
    MOV  [DI], AL
    INC  SI
    INC  DI
    LOOP FP_COPY
FP_END:
    MOV  BYTE PTR [DI], 0
    JMP  FP_DONE
FP_SKIP:
    INC  SI
    DEC  BX
    JMP  FP_SCAN
FP_NOTFOUND:
    MOV  BYTE PTR [DI], 0
FP_DONE:
    POP  CX
    POP  AX
    RET
FIND_PHONE ENDP

; ============================================================
; VALIDATE_PHONE  —  SI = null-terminated string
; Sets VALID_FLAG=0 if not exactly 10 ASCII digits 30H-39H
; ============================================================
VALIDATE_PHONE PROC
    PUSH AX
    PUSH CX
    MOV  CX, 0
VP_LOOP:
    MOV  AL, [SI]
    CMP  AL, 0
    JE   VP_CHKLEN
    CMP  AL, '0'
    JB   VP_FAIL
    CMP  AL, '9'
    JA   VP_FAIL
    INC  CX
    INC  SI
    JMP  VP_LOOP
VP_CHKLEN:
    CMP  CX, 10
    JNE  VP_FAIL
    JMP  VP_OK
VP_FAIL:
    MOV  VALID_FLAG, 0
VP_OK:
    POP  CX
    POP  AX
    RET
VALIDATE_PHONE ENDP

; ============================================================
; W2_4DEC  —  AX → 4 ASCII decimal digits written at [DI]
; ============================================================
W2_4DEC PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, 10
    MOV  DX, 0
    DIV  BX          ; AX=quotient(3 digits), DX=units
    PUSH DX
    MOV  DX, 0
    DIV  BX          ; AX=quotient(2 digits), DX=tens
    PUSH DX
    MOV  DX, 0
    DIV  BX          ; AX=hundreds digit,     DX=hundreds
    PUSH DX
    ; AX = thousands digit
    ADD  AL, '0'
    MOV  [DI],   AL
    POP  DX
    ADD  DL, '0'
    MOV  [DI+1], DL
    POP  DX
    ADD  DL, '0'
    MOV  [DI+2], DL
    POP  DX
    ADD  DL, '0'
    MOV  [DI+3], DL
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
W2_4DEC ENDP

; ============================================================
; WF  — write null-terminated string at SI to FH_OUT
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
; WFCRLF — write null-terminated string then CRLF
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
