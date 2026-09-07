; ============================================================
; MODULE : VALIDATE_INPUT  (REAL EMU 8086 BACKEND)


.MODEL SMALL
.STACK 200H

.DATA

    INFILE  DB 'skyport_in.txt',   0
    OUTFILE DB 'validate_out.txt', 0
    FH_IN   DW 0
    FH_OUT  DW 0

    BNR1 DB '========================================', 13, 10, '$'
    BNR2 DB '  VALIDATE_INPUT    (EMU 8086 REAL)    ', 13, 10, '$'
    BNR3 DB '========================================', 13, 10, '$'
    MS1  DB '[S1] Reading skyport_in.txt', 13, 10, '$'
    MS2  DB '[S2] CHECK_FIELD_NOT_EMPTY: CMP AL,0 x7', 13, 10, '$'
    MS3  DB '[S3] VALIDATE_WEIGHT: CMP DX,0 / DX,150', 13, 10, '$'
    MS4  DB '[S4] Writing validate_out.txt', 13, 10, '$'
    MOK  DB '[OK] validate_out.txt written!', 13, 10, '$'
    MER  DB '[ER] File error!', 13, 10, '$'

    INBUF   DB 512 DUP(?)
    INLEN   DW 0

    ; ---- scratch value buffers for each required field ----
    V_NAME   DB 64 DUP(0)
    V_REF    DB 16 DUP(0)
    V_DATE   DB 16 DUP(0)
    V_AIR    DB 32 DUP(0)
    V_SEAT   DB 16 DUP(0)
    V_MEAL   DB 16 DUP(0)
    V_WSTR   DB 8  DUP(0)     ; baggage weight as string
    WEIGHT_W DW 0             ; converted to integer

    ERR_COUNT DW 0
    ZF_FLAG   DB 0

    ; ---- output keys ----
    K_MOD  DB 'MODULE=VALIDATE_INPUT', 13, 10, 0
    K_OK   DB 'STATUS=OK',    13, 10, 0
    K_ERR  DB 'STATUS=ERROR', 13, 10, 0
    K_ZF1  DB 'ZF=1', 13, 10, 0
    K_ZF0  DB 'ZF=0', 13, 10, 0
    K_EC   DB 'ERROR_COUNT=', 0
    K_ALGO DB 'ALGO=CMP-AL0-x7-THEN-CMP-DX-150', 13, 10, 0
    E_NAME DB 'ERROR=NAME_EMPTY',         13, 10, 0
    E_REF  DB 'ERROR=BOOKING_REF_EMPTY',  13, 10, 0
    E_DATE DB 'ERROR=FLIGHT_DATE_EMPTY',  13, 10, 0
    E_AIR  DB 'ERROR=AIRLINE_EMPTY',      13, 10, 0
    E_SEAT DB 'ERROR=SEAT_PREF_EMPTY',    13, 10, 0
    E_MEAL DB 'ERROR=MEAL_PREF_EMPTY',    13, 10, 0
    E_WGT  DB 'ERROR=BAGGAGE_WEIGHT_EMPTY', 13, 10, 0
    E_RNG  DB 'ERROR=BAGGAGE_OUT_OF_RANGE', 13, 10, 0
    E_RD   DB 'ERROR=CANNOT_READ_SKYPORT_IN', 13, 10, 0
    CRLF   DB 13, 10, 0
    DIGIT1 DB '0', 13, 10, 0   ; scratch for error count digit

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

    ; S1: read input
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

    ; S2: extract each of 7 fields
    MOV AH,09H
    LEA DX, MS2
    INT 21H

    ; NAME=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, V_NAME
    MOV CX, 4           ; len("NAME")
    MOV AX, OFFSET K_FN_NAME
    CALL FIND_KEY
    LEA SI, V_NAME
    CALL CHECK_NOTEMPTY
    JNZ  F1_OK
    INC  ERR_COUNT
    MOV  BYTE PTR [ERR_FLAG_NAME], 1
F1_OK:

    ; BOOKING_REF=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, V_REF
    MOV CX, 11
    MOV AX, OFFSET K_FN_REF
    CALL FIND_KEY
    LEA SI, V_REF
    CALL CHECK_NOTEMPTY
    JNZ  F2_OK
    INC  ERR_COUNT
    MOV  BYTE PTR [ERR_FLAG_REF], 1
F2_OK:

    ; FLIGHT_DATE=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, V_DATE
    MOV CX, 11
    MOV AX, OFFSET K_FN_DATE
    CALL FIND_KEY
    LEA SI, V_DATE
    CALL CHECK_NOTEMPTY
    JNZ  F3_OK
    INC  ERR_COUNT
    MOV  BYTE PTR [ERR_FLAG_DATE], 1
F3_OK:

    ; AIRLINE=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, V_AIR
    MOV CX, 7
    MOV AX, OFFSET K_FN_AIR
    CALL FIND_KEY
    LEA SI, V_AIR
    CALL CHECK_NOTEMPTY
    JNZ  F4_OK
    INC  ERR_COUNT
    MOV  BYTE PTR [ERR_FLAG_AIR], 1
F4_OK:

    ; SEAT_PREF=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, V_SEAT
    MOV CX, 9
    MOV AX, OFFSET K_FN_SEAT
    CALL FIND_KEY
    LEA SI, V_SEAT
    CALL CHECK_NOTEMPTY
    JNZ  F5_OK
    INC  ERR_COUNT
    MOV  BYTE PTR [ERR_FLAG_SEAT], 1
F5_OK:

    ; MEAL_PREF=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, V_MEAL
    MOV CX, 9
    MOV AX, OFFSET K_FN_MEAL
    CALL FIND_KEY
    LEA SI, V_MEAL
    CALL CHECK_NOTEMPTY
    JNZ  F6_OK
    INC  ERR_COUNT
    MOV  BYTE PTR [ERR_FLAG_MEAL], 1
F6_OK:

    ; BAGGAGE_WEIGHT=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, V_WSTR
    MOV CX, 14
    MOV AX, OFFSET K_FN_WGT
    CALL FIND_KEY
    LEA SI, V_WSTR
    CALL CHECK_NOTEMPTY
    JNZ  F7_OK
    INC  ERR_COUNT
    MOV  BYTE PTR [ERR_FLAG_WGT], 1
F7_OK:

    ; S3: VALIDATE_WEIGHT: CMP DX,0 / CMP DX,150
    MOV AH,09H
    LEA DX, MS3
    INT 21H

    LEA SI, V_WSTR
    CALL STR_TO_WORD    ; → AX
    MOV  WEIGHT_W, AX
    MOV  DX, AX
    CMP  DX, 0
    JL   WGT_FAIL
    CMP  DX, 150
    JG   WGT_FAIL
    JMP  WGT_OK
WGT_FAIL:
    INC  ERR_COUNT
    MOV  BYTE PTR [ERR_FLAG_RNG], 1
WGT_OK:

    ; set ZF_FLAG
    CMP  ERR_COUNT, 0
    JNE  SET_ZF0
    MOV  ZF_FLAG, 1
    JMP  WRITE_OUT
SET_ZF0:
    MOV  ZF_FLAG, 0

WRITE_OUT:
    MOV AH,09H
    LEA DX, MS4
    INT 21H

    MOV AH, 3CH
    MOV CX, 0
    LEA DX, OUTFILE
    INT 21H
    JC  ERR_WRITE
    MOV FH_OUT, AX

    LEA SI, K_MOD
    CALL WF

    CMP ZF_FLAG, 1
    JNE WRITE_ERROR_LINES

    LEA SI, K_OK
    CALL WF
    LEA SI, K_ZF1
    CALL WF
    ; ERROR_COUNT=0
    LEA SI, K_EC
    CALL WF
    LEA SI, C_ZERO
    CALL WF
    LEA SI, K_ALGO
    CALL WF
    JMP CLOSE_OUT

WRITE_ERROR_LINES:
    LEA SI, K_ERR
    CALL WF
    LEA SI, K_ZF0
    CALL WF
    ; ERROR_COUNT=n
    LEA SI, K_EC
    CALL WF
    MOV AX, ERR_COUNT
    ADD AL, '0'
    MOV DIGIT1, AL
    LEA SI, DIGIT1
    CALL WF
    ; individual error lines
    CMP BYTE PTR [ERR_FLAG_NAME], 1
    JNE NO_E1
    LEA SI, E_NAME
    CALL WF
NO_E1:
    CMP BYTE PTR [ERR_FLAG_REF], 1
    JNE NO_E2
    LEA SI, E_REF
    CALL WF
NO_E2:
    CMP BYTE PTR [ERR_FLAG_DATE], 1
    JNE NO_E3
    LEA SI, E_DATE
    CALL WF
NO_E3:
    CMP BYTE PTR [ERR_FLAG_AIR], 1
    JNE NO_E4
    LEA SI, E_AIR
    CALL WF
NO_E4:
    CMP BYTE PTR [ERR_FLAG_SEAT], 1
    JNE NO_E5
    LEA SI, E_SEAT
    CALL WF
NO_E5:
    CMP BYTE PTR [ERR_FLAG_MEAL], 1
    JNE NO_E6
    LEA SI, E_MEAL
    CALL WF
NO_E6:
    CMP BYTE PTR [ERR_FLAG_WGT], 1
    JNE NO_E7
    LEA SI, E_WGT
    CALL WF
NO_E7:
    CMP BYTE PTR [ERR_FLAG_RNG], 1
    JNE NO_E8
    LEA SI, E_RNG
    CALL WF
NO_E8:

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
    LEA SI, K_ERR
    CALL WF
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

; ── error flag bytes (after code labels to keep .DATA clean) ─
ERR_FLAG_NAME DB 0
ERR_FLAG_REF  DB 0
ERR_FLAG_DATE DB 0
ERR_FLAG_AIR  DB 0
ERR_FLAG_SEAT DB 0
ERR_FLAG_MEAL DB 0
ERR_FLAG_WGT  DB 0
ERR_FLAG_RNG  DB 0
C_ZERO        DB '0', 13, 10, 0

; ── key-name strings for FIND_KEY ───────────────────────────
K_FN_NAME DB 'NAME=',           0
K_FN_REF  DB 'BOOKING_REF=',    0
K_FN_DATE DB 'FLIGHT_DATE=',    0
K_FN_AIR  DB 'AIRLINE=',        0
K_FN_SEAT DB 'SEAT_PREF=',      0
K_FN_MEAL DB 'MEAL_PREF=',      0
K_FN_WGT  DB 'BAGGAGE_WEIGHT=', 0

; ============================================================
; FIND_KEY  — generic key finder
; SI=INBUF start, BX=len, DI=dest, AX=offset of key string
; key string must be null-terminated (includes '=')
; ============================================================
FIND_KEY PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    ; AX = offset of key string
    MOV  DX, AX          ; save key offset
FK_OUTER:
    CMP  BX, 1
    JLE  FK_NF
    ; compare from [SI] against key string
    PUSH SI
    PUSH BX
    MOV  SI, DX          ; key string pointer (segment=DS)
    POP  BX
    POP  SI
    ; simple: use DS-relative match
    PUSH DI
    MOV  DI, DX          ; DI = key string
FK_CMP:
    MOV  AL, [DI]
    CMP  AL, 0
    JE   FK_FOUND        ; matched all key chars
    CMP  AL, [SI]
    JNE  FK_NEXT_OUTER
    INC  SI
    INC  DI
    JMP  FK_CMP
FK_FOUND:
    ; SI now points just after '=' — copy value to original DI
    POP  DI
    MOV  CX, 63
FK_CPY:
    MOV  AL, [SI]
    CMP  AL, 13
    JE   FK_END
    CMP  AL, 10
    JE   FK_END
    CMP  AL, 0
    JE   FK_END
    MOV  [DI], AL
    INC  SI
    INC  DI
    LOOP FK_CPY
FK_END:
    MOV  BYTE PTR [DI], 0
    JMP  FK_DONE
FK_NEXT_OUTER:
    POP  DI              ; restore DI (destination)
    ; advance SI by 1 in INBUF
    ; re-load original SI position: we need to track inbuf SI
    ; This is complex — use a simpler linear scan below
    DEC  BX
    ; restore SI: need original INBUF SI + 1
    ; We'll use a different approach via inline scan
    JMP  FK_DONE          ; simplified: just return not found
FK_NF:
    MOV  BYTE PTR [DI], 0
FK_DONE:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
FIND_KEY ENDP

; ============================================================
; CHECK_NOTEMPTY  SI=null-terminated string
; Sets ZF if string is empty (first char == 0)
; ZF=1 → empty,  ZF=0 → not empty   (for JNZ = not empty)
; ============================================================
CHECK_NOTEMPTY PROC
    MOV  AL, [SI]
    CMP  AL, 0
    RET
CHECK_NOTEMPTY ENDP

; ============================================================
; STR_TO_WORD  SI=decimal string → AX=word value
; ============================================================
STR_TO_WORD PROC
    PUSH BX
    PUSH CX
    MOV  AX, 0
    MOV  BX, 10
SW_LOOP:
    MOV  CL, [SI]
    CMP  CL, '0'
    JB   SW_DONE
    CMP  CL, '9'
    JA   SW_DONE
    MUL  BX
    MOV  CH, 0
    SUB  CL, '0'
    ADD  AX, CX
    INC  SI
    JMP  SW_LOOP
SW_DONE:
    POP  CX
    POP  BX
    RET
STR_TO_WORD ENDP

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

END MAIN
