; ============================================================
; MODULE : SEAT_ALLOCATION  (REAL EMU 8086 BACKEND)


.MODEL SMALL
.STACK 200H

.DATA

    INFILE  DB 'skyport_in.txt',  0
    OUTFILE DB 'seat_out.txt',    0
    FH_IN   DW 0
    FH_OUT  DW 0

    BNR1 DB '========================================', 13, 10, '$'
    BNR2 DB '  SEAT_ALLOCATION   (EMU 8086 REAL)    ', 13, 10, '$'
    BNR3 DB '========================================', 13, 10, '$'
    MS1  DB '[S1] Reading skyport_in.txt', 13, 10, '$'
    MS2  DB '[S2] SEAT_MAP DB 80 DUP: scan rows/cols', 13, 10, '$'
    MS3  DB '[S3] PREFER_MATCH: window=A/D aisle=B/C', 13, 10, '$'
    MS4  DB '[S4] MOV [SEAT_MAP+BX],1: mark occupied', 13, 10, '$'
    MS5  DB '[S5] Writing seat_out.txt', 13, 10, '$'
    MOK  DB '[OK] seat_out.txt written!', 13, 10, '$'
    MER  DB '[ER] File error!', 13, 10, '$'

    INBUF   DB 512 DUP(?)
    INLEN   DW 0

    ; 80-byte seat map read from input
    SEAT_MAP   DB 80 DUP(0)

    ; preference: 0=window, 1=aisle, 2=extra_legroom, 3=any
    SEAT_PREF  DB 3

    ; result
    ALLOC_STAT DB 0
    ALLOC_ROW  DW 0        ; 1-based row number
    ALLOC_COL  DB 0        ; 0=A,1=B,2=C,3=D

    COL_LETTERS DB 'ABCD'

    ; output keys
    K_MOD  DB 'MODULE=SEAT_ALLOCATION', 13, 10, 0
    K_OK   DB 'STATUS=OK',    13, 10, 0
    K_ERR  DB 'STATUS=ERROR', 13, 10, 0
    K_ST1  DB 'ALLOC_STATUS=1', 13, 10, 0
    K_ST0  DB 'ALLOC_STATUS=0', 13, 10, 0
    K_SEAT DB 'SEAT=', 0
    K_ALGO DB 'ALGO=SEAT_MAP-80-BYTES-SCAN-PREFER', 13, 10, 0
    K_NONE DB 'ERROR=NO_SEAT_FOR_PREFERENCE', 13, 10, 0
    E_RD   DB 'ERROR=CANNOT_READ_SKYPORT_IN', 13, 10, 0
    CRLF   DB 13, 10, 0

    ; scratch for seat string "RowColLetter\r\n\0"
    SEAT_STR DB 5 DUP(0)

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

    ; Parse SEAT_PREF=
    LEA SI, INBUF
    MOV BX, INLEN
    CALL PARSE_PREF        ; sets SEAT_PREF

    ; Parse SEAT_MAP=  (80 chars of '0'/'1')
    LEA SI, INBUF
    MOV BX, INLEN
    CALL PARSE_SEAT_MAP    ; fills SEAT_MAP array

    ; S2: scan SEAT_MAP
    MOV AH,09H
    LEA DX, MS2
    INT 21H
    MOV AH,09H
    LEA DX, MS3
    INT 21H

    CALL SEARCH_SEAT_MAP   ; sets ALLOC_STAT, ALLOC_ROW, ALLOC_COL

    ; S4: if found, mark occupied in SEAT_MAP (already done in SEARCH)
    MOV AH,09H
    LEA DX, MS4
    INT 21H

    ; S5: write output
    MOV AH,09H
    LEA DX, MS5
    INT 21H

    MOV AH, 3CH
    MOV CX, 0
    LEA DX, OUTFILE
    INT 21H
    JC  ERR_WRITE
    MOV FH_OUT, AX

    LEA SI, K_MOD
    CALL WF

    CMP ALLOC_STAT, 1
    JNE WRITE_NOTFOUND

    ; OK path: build SEAT string e.g. "3B\r\n"
    LEA SI, K_OK
    CALL WF
    LEA SI, K_ST1
    CALL WF
    LEA SI, K_SEAT
    CALL WF

    ; write row number (1-based, up to 2 digits)
    MOV AX, ALLOC_ROW
    LEA DI, SEAT_STR
    CALL BYTE_TO_DEC       ; writes 1 or 2 chars at [DI], null-terminated
    LEA SI, SEAT_STR
    CALL WF

    ; write column letter
    MOV AL, ALLOC_COL
    MOV AH, 0
    LEA DI, COL_LETTERS
    ADD DI, AX
    MOV AL, [DI]
    MOV SEAT_STR, AL
    MOV BYTE PTR SEAT_STR+1, 0
    LEA SI, SEAT_STR
    CALL WF

    ; CRLF after seat value
    LEA SI, CRLF
    CALL WF

    LEA SI, K_ALGO
    CALL WF
    JMP CLOSE_OUT

WRITE_NOTFOUND:
    LEA SI, K_ERR
    CALL WF
    LEA SI, K_ST0
    CALL WF
    LEA SI, K_NONE
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


PARSE_PREF PROC
    PUSH AX
    PUSH CX
PP_SCAN:
    CMP  BX, 9
    JL   PP_NF
    CMP  BYTE PTR [SI],   'S'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+1], 'E'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+2], 'A'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+3], 'T'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+4], '_'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+5], 'P'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+6], 'R'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+7], 'E'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+8], 'F'
    JNE  PP_SKIP
    CMP  BYTE PTR [SI+9], '='
    JNE  PP_SKIP
    ADD  SI, 10
    ; check first char of value
    MOV  AL, [SI]
    CMP  AL, 'w'
    JE   PP_WINDOW
    CMP  AL, 'W'
    JE   PP_WINDOW
    CMP  AL, 'a'
    JE   PP_AISLE
    CMP  AL, 'A'
    JE   PP_AISLE
    ; extra_legroom starts with 'e' or 'E'
    CMP  AL, 'e'
    JE   PP_LEGROOM
    CMP  AL, 'E'
    JE   PP_LEGROOM
    ; default: any
    MOV  SEAT_PREF, 3
    JMP  PP_DONE
PP_WINDOW:
    MOV  SEAT_PREF, 0
    JMP  PP_DONE
PP_AISLE:
    MOV  SEAT_PREF, 1
    JMP  PP_DONE
PP_LEGROOM:
    MOV  SEAT_PREF, 2
    JMP  PP_DONE
PP_SKIP:
    INC  SI
    DEC  BX
    JMP  PP_SCAN
PP_NF:
    MOV  SEAT_PREF, 3    ; default any
PP_DONE:
    POP  CX
    POP  AX
    RET
PARSE_PREF ENDP

PARSE_SEAT_MAP PROC
    PUSH AX
    PUSH CX
    PUSH DI
PSM_SCAN:
    CMP  BX, 9
    JL   PSM_NF
    CMP  BYTE PTR [SI],   'S'
    JNE  PSM_SKIP
    CMP  BYTE PTR [SI+1], 'E'
    JNE  PSM_SKIP
    CMP  BYTE PTR [SI+2], 'A'
    JNE  PSM_SKIP
    CMP  BYTE PTR [SI+3], 'T'
    JNE  PSM_SKIP
    CMP  BYTE PTR [SI+4], '_'
    JNE  PSM_SKIP
    CMP  BYTE PTR [SI+5], 'M'
    JNE  PSM_SKIP
    CMP  BYTE PTR [SI+6], 'A'
    JNE  PSM_SKIP
    CMP  BYTE PTR [SI+7], 'P'
    JNE  PSM_SKIP
    CMP  BYTE PTR [SI+8], '='
    JNE  PSM_SKIP
    ADD  SI, 9
    LEA  DI, SEAT_MAP
    MOV  CX, 80
PSM_COPY:
    MOV  AL, [SI]
    CMP  AL, '0'
    JE   PSM_STORE
    CMP  AL, '1'
    JNE  PSM_END
PSM_STORE:
    SUB  AL, '0'         ; '0'→0, '1'→1
    MOV  [DI], AL
    INC  SI
    INC  DI
    LOOP PSM_COPY
PSM_END:
    JMP  PSM_DONE
PSM_SKIP:
    INC  SI
    DEC  BX
    JMP  PSM_SCAN
PSM_NF:
PSM_DONE:
    POP  DI
    POP  CX
    POP  AX
    RET
PARSE_SEAT_MAP ENDP


SEARCH_SEAT_MAP PROC
    PUSH AX
    PUSH CX
    PUSH DX
    MOV  CX, 20            ; 20 rows
    MOV  BX, 0             ; SEAT_MAP index
SSM_ROW:
    MOV  DX, 0             ; col index 0-3
SSM_COL:
    MOV  AL, SEAT_MAP[BX]
    CMP  AL, 1
    JE   SSM_OCCUPIED
    ; seat is free — check preference
    MOV  AL, SEAT_PREF
    CMP  AL, 0             ; window: col 0 or 3
    JNE  CHK_AISLE
    CMP  DX, 0
    JE   SSM_FOUND
    CMP  DX, 3
    JE   SSM_FOUND
    JMP  SSM_OCCUPIED
CHK_AISLE:
    CMP  AL, 1             ; aisle: col 1 or 2
    JNE  CHK_LEGROOM
    CMP  DX, 1
    JE   SSM_FOUND
    CMP  DX, 2
    JE   SSM_FOUND
    JMP  SSM_OCCUPIED
CHK_LEGROOM:
    CMP  AL, 2             ; extra_legroom: rows 10-19 (0-indexed)
    JNE  SSM_FOUND         ; 'any' → take it
    ; row index = 20 - CX  (CX counts down from 20)
    PUSH AX
    MOV  AX, 20
    SUB  AX, CX            ; 0-based row index
    CMP  AX, 10
    POP  AX
    JL   SSM_OCCUPIED      ; row < 10 → skip
    JMP  SSM_FOUND
SSM_OCCUPIED:
    INC  BX
    INC  DX
    CMP  DX, 4
    JL   SSM_COL
    LOOP SSM_ROW
    ; no seat found
    MOV  ALLOC_STAT, 0
    JMP  SSM_DONE
SSM_FOUND:
    ; mark seat occupied
    MOV  BYTE PTR SEAT_MAP[BX], 1
    ; store row (1-based): row_idx = 20 - CX, so row_num = 21 - CX
    PUSH AX
    MOV  AX, 21
    SUB  AX, CX
    MOV  ALLOC_ROW, AX
    POP  AX
    ; store col
    MOV  AL, DL
    MOV  ALLOC_COL, AL
    MOV  ALLOC_STAT, 1
SSM_DONE:
    POP  DX
    POP  CX
    POP  AX
    RET
SEARCH_SEAT_MAP ENDP

; ============================================================
; BYTE_TO_DEC  AX=value (1-20) → write decimal at [DI], null-term
; ============================================================
BYTE_TO_DEC PROC
    PUSH AX
    PUSH BX
    PUSH DX
    MOV  BX, 10
    MOV  DX, 0
    DIV  BX              ; AX=tens, DX=units
    CMP  AX, 0
    JE   BD_UNITS        ; single digit
    ADD  AL, '0'
    MOV  [DI], AL
    INC  DI
BD_UNITS:
    ADD  DL, '0'
    MOV  [DI], DL
    INC  DI
    MOV  BYTE PTR [DI], 0
    POP  DX
    POP  BX
    POP  AX
    RET
BYTE_TO_DEC ENDP

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
