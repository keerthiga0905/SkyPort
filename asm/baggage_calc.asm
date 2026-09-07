; ============================================================
; MODULE : BAGGAGE_CALC  (REAL EMU 8086 BACKEND)


.MODEL SMALL
.STACK 200H

.DATA

    INFILE  DB 'skyport_in.txt',  0
    OUTFILE DB 'baggage_out.txt', 0
    FH_IN   DW 0
    FH_OUT  DW 0

    BNR1 DB '========================================', 13, 10, '$'
    BNR2 DB '  BAGGAGE_CALC      (EMU 8086 REAL)    ', 13, 10, '$'
    BNR3 DB '========================================', 13, 10, '$'
    MS1  DB '[S1] Reading skyport_in.txt', 13, 10, '$'
    MS2  DB '[S2] MOV DX,WEIGHT / MOV BX,LIMIT', 13, 10, '$'
    MS3  DB '[S3] SUB DX,BX -> excess kg', 13, 10, '$'
    MS4  DB '[S4] JS/JZ NO_EXCESS / MUL RATE(200)', 13, 10, '$'
    MS5  DB '[S5] Writing baggage_out.txt', 13, 10, '$'
    MOK  DB '[OK] baggage_out.txt written!', 13, 10, '$'
    MER  DB '[ER] File error!', 13, 10, '$'

    INBUF   DB 512 DUP(?)
    INLEN   DW 0

    WEIGHT_W    DW 0
    LIMIT_W     DW 20       ; default 20 kg
    RATE_PER_KG DW 200
    EXCESS_W    DW 0
    CHARGE_W    DW 0
    SF_FLAG     DB 0
    ZF_FLAG     DB 0

    K_MOD   DB 'MODULE=BAGGAGE_CALC', 13, 10, 0
    K_OK    DB 'STATUS=OK',    13, 10, 0
    K_ERR   DB 'STATUS=ERROR', 13, 10, 0
    K_WKEY  DB 'WEIGHT=',      0
    K_LKEY  DB 'LIMIT=',       0
    K_EXKEY DB 'EXCESS_KG=',   0
    K_CHKEY DB 'EXTRA_CHARGE=',0
    K_SF1   DB 'SF=1', 13, 10, 0
    K_SF0   DB 'SF=0', 13, 10, 0
    K_ZF1   DB 'ZF=1', 13, 10, 0
    K_ZF0   DB 'ZF=0', 13, 10, 0
    K_ALGO  DB 'ALGO=SUB-DX-BX-JS-JZ-MUL-200', 13, 10, 0
    E_RD    DB 'ERROR=CANNOT_READ_SKYPORT_IN', 13, 10, 0
    CRLF    DB 13, 10, 0

    NUMBUF  DB 8 DUP(0)     ; scratch for word→decimal

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

    ; Parse BAGGAGE_WEIGHT=
    LEA SI, INBUF
    MOV BX, INLEN
    CALL PARSE_WEIGHT      ; → WEIGHT_W

    ; Parse BAGGAGE_LIMIT=
    LEA SI, INBUF
    MOV BX, INLEN
    CALL PARSE_LIMIT       ; → LIMIT_W

    ; S2: load registers
    MOV AH,09H
    LEA DX, MS2
    INT 21H

    MOV DX, WEIGHT_W
    MOV BX, LIMIT_W

    ; S3: SUB DX, BX  → excess = weight - limit
    MOV AH,09H
    LEA DX, MS3
    INT 21H

    MOV DX, WEIGHT_W
    MOV BX, LIMIT_W
    SUB DX, BX             ; DX = weight - limit

    ; S4: JS/JZ → no excess, else MUL rate
    MOV AH,09H
    LEA DX, MS4
    INT 21H

    MOV DX, WEIGHT_W
    MOV BX, LIMIT_W
    SUB DX, BX
    JS  NO_EXCESS
    JZ  NO_EXCESS

    ; excess exists
    MOV EXCESS_W, DX
    MOV AX, DX
    MUL RATE_PER_KG        ; AX = excess * 200
    MOV CHARGE_W, AX
    MOV SF_FLAG, 1
    MOV ZF_FLAG, 0
    JMP WRITE_OUT

NO_EXCESS:
    MOV EXCESS_W, 0
    MOV CHARGE_W, 0
    MOV SF_FLAG, 0
    MOV ZF_FLAG, 1

WRITE_OUT:
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
    LEA SI, K_OK
    CALL WF

    ; WEIGHT=<n>
    LEA SI, K_WKEY
    CALL WF
    MOV AX, WEIGHT_W
    LEA DI, NUMBUF
    CALL WORD_TO_DEC
    LEA SI, NUMBUF
    CALL WF
    LEA SI, CRLF
    CALL WF

    ; LIMIT=<n>
    LEA SI, K_LKEY
    CALL WF
    MOV AX, LIMIT_W
    LEA DI, NUMBUF
    CALL WORD_TO_DEC
    LEA SI, NUMBUF
    CALL WF
    LEA SI, CRLF
    CALL WF

    ; EXCESS_KG=<n>
    LEA SI, K_EXKEY
    CALL WF
    MOV AX, EXCESS_W
    LEA DI, NUMBUF
    CALL WORD_TO_DEC
    LEA SI, NUMBUF
    CALL WF
    LEA SI, CRLF
    CALL WF

    ; EXTRA_CHARGE=<n>
    LEA SI, K_CHKEY
    CALL WF
    MOV AX, CHARGE_W
    LEA DI, NUMBUF
    CALL WORD_TO_DEC
    LEA SI, NUMBUF
    CALL WF
    LEA SI, CRLF
    CALL WF

    ; SF= and ZF=
    CMP SF_FLAG, 1
    JNE WRITE_SF0
    LEA SI, K_SF1
    CALL WF
    JMP WRITE_ZF
WRITE_SF0:
    LEA SI, K_SF0
    CALL WF
WRITE_ZF:
    CMP ZF_FLAG, 1
    JNE WRITE_ZF0
    LEA SI, K_ZF1
    CALL WF
    JMP WRITE_ALGO
WRITE_ZF0:
    LEA SI, K_ZF0
    CALL WF
WRITE_ALGO:
    LEA SI, K_ALGO
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

; ============================================================
; PARSE_WEIGHT  SI=INBUF, BX=len → WEIGHT_W
; ============================================================
PARSE_WEIGHT PROC
    PUSH AX
    PUSH CX
PW_SCAN:
    CMP  BX, 15
    JL   PW_NF
    CMP  BYTE PTR [SI],    'B'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+1],  'A'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+2],  'G'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+3],  'G'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+4],  'A'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+5],  'G'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+6],  'E'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+7],  '_'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+8],  'W'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+9],  'E'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+10], 'I'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+11], 'G'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+12], 'H'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+13], 'T'
    JNE  PW_SKIP
    CMP  BYTE PTR [SI+14], '='
    JNE  PW_SKIP
    ADD  SI, 15
    CALL STR_TO_WORD
    MOV  WEIGHT_W, AX
    JMP  PW_DONE
PW_SKIP:
    INC  SI
    DEC  BX
    JMP  PW_SCAN
PW_NF:
PW_DONE:
    POP  CX
    POP  AX
    RET
PARSE_WEIGHT ENDP

; ============================================================
; PARSE_LIMIT  SI=INBUF, BX=len → LIMIT_W
; ============================================================
PARSE_LIMIT PROC
    PUSH AX
    PUSH CX
    LEA  SI, INBUF
    MOV  BX, INLEN
PL_SCAN:
    CMP  BX, 14
    JL   PL_NF
    CMP  BYTE PTR [SI],    'B'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+1],  'A'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+2],  'G'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+3],  'G'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+4],  'A'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+5],  'G'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+6],  'E'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+7],  '_'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+8],  'L'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+9],  'I'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+10], 'M'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+11], 'I'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+12], 'T'
    JNE  PL_SKIP
    CMP  BYTE PTR [SI+13], '='
    JNE  PL_SKIP
    ADD  SI, 14
    CALL STR_TO_WORD
    MOV  LIMIT_W, AX
    JMP  PL_DONE
PL_SKIP:
    INC  SI
    DEC  BX
    JMP  PL_SCAN
PL_NF:
PL_DONE:
    POP  CX
    POP  AX
    RET
PARSE_LIMIT ENDP

; ============================================================
; STR_TO_WORD  SI=decimal ASCII string → AX
; ============================================================
STR_TO_WORD PROC
    PUSH BX
    PUSH CX
    MOV  AX, 0
    MOV  BX, 10
SW_LP:
    MOV  CL, [SI]
    CMP  CL, '0'
    JB   SW_DN
    CMP  CL, '9'
    JA   SW_DN
    MUL  BX
    MOV  CH, 0
    SUB  CL, '0'
    ADD  AX, CX
    INC  SI
    JMP  SW_LP
SW_DN:
    POP  CX
    POP  BX
    RET
STR_TO_WORD ENDP

; ============================================================
; WORD_TO_DEC  AX=value → null-terminated decimal at [DI]
; ============================================================
WORD_TO_DEC PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    ; push digits in reverse order
    MOV  BX, 10
    MOV  CX, 0
WD_SPLIT:
    MOV  DX, 0
    DIV  BX
    PUSH DX
    INC  CX
    CMP  AX, 0
    JNE  WD_SPLIT
    ; pop digits into [DI]
WD_WRITE:
    POP  DX
    ADD  DL, '0'
    MOV  [DI], DL
    INC  DI
    LOOP WD_WRITE
    MOV  BYTE PTR [DI], 0
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
WORD_TO_DEC ENDP

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
