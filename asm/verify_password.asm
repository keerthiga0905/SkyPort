; ============================================================
; MODULE : VERIFY_PASSWORD  (REAL EMU 8086 BACKEND)

.MODEL SMALL
.STACK 200H

.DATA

    INFILE  DB 'skyport_in.txt',  0
    OUTFILE DB 'verify_out.txt',  0
    FH_IN   DW 0
    FH_OUT  DW 0

    BNR1 DB '========================================', 13, 10, '$'
    BNR2 DB '  VERIFY_PASSWORD   (EMU 8086 REAL)    ', 13, 10, '$'
    BNR3 DB '========================================', 13, 10, '$'
    MS1  DB '[S1] Reading skyport_in.txt', 13, 10, '$'
    MS2  DB '[S2] COMPUTE_HASH: AX=AX*31+char', 13, 10, '$'
    MS3  DB '[S3] CMP AX,BX  (hash compare)', 13, 10, '$'
    MS4  DB '[S4] CMPSB byte-by-byte string compare', 13, 10, '$'
    MS5  DB '[S5] Writing verify_out.txt', 13, 10, '$'
    MOK  DB '[OK] verify_out.txt written!', 13, 10, '$'
    MER  DB '[ER] File error!', 13, 10, '$'

    INBUF  DB 512 DUP(?)
    INLEN  DW 0

    ; parsed fields (null-terminated)
    PWD_BUF    DB 32 DUP(0)   ; user-entered password
    STORED_BUF DB 32 DUP(0)   ; stored password from DB

    HASH_PWD    DW 0
    HASH_STORED DW 0
    MATCH_FLAG  DB 0           ; 1=match, 0=no match

    ; output keys
    K_MOD   DB 'MODULE=VERIFY_PASSWORD', 13, 10, 0
    K_OK    DB 'STATUS=OK',    13, 10, 0
    K_ERR   DB 'STATUS=ERROR', 13, 10, 0
    K_MATCH DB 'RESULT=MATCH', 13, 10, 0
    K_NOMCH DB 'RESULT=NO_MATCH', 13, 10, 0
    K_AX1   DB 'AX_RESULT=1',  13, 10, 0
    K_AX0   DB 'AX_RESULT=0',  13, 10, 0
    K_ALGO  DB 'ALGO=HASH-AX*31+CHAR-CMPSB', 13, 10, 0
    E_RD    DB 'ERROR=CANNOT_READ_SKYPORT_IN', 13, 10, 0
    CRLF    DB 13, 10, 0

.CODE

MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

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

    ; S1: read input
    MOV AH,09H & LEA DX,MS1 & INT 21H
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

    ; Parse PASSWORD= and STORED_PASSWORD=
    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, PWD_BUF
    CALL FIND_PASSWORD

    LEA SI, INBUF
    MOV BX, INLEN
    LEA DI, STORED_BUF
    CALL FIND_STORED

    ; S2: COMPUTE_HASH of user password
    MOV AH,09H
    LEA DX, MS2
    INT 21H

    LEA SI, PWD_BUF
    CALL COMPUTE_HASH
    MOV HASH_PWD, AX

    ; hash of stored password
    LEA SI, STORED_BUF
    CALL COMPUTE_HASH
    MOV HASH_STORED, AX

    ; S3: CMP AX, BX
    MOV AH,09H
    LEA DX, MS3
    INT 21H

    MOV AX, HASH_PWD
    MOV BX, HASH_STORED
    CMP AX, BX
    JNE HASH_FAIL          ; hashes differ → no match

    ; S4: CMPSB byte-by-byte
    MOV AH,09H
    LEA DX, MS4
    INT 21H

    LEA SI, PWD_BUF
    LEA DI, STORED_BUF
    CALL COMPARE_STRINGS
    CMP AX, 1
    JNE HASH_FAIL

    MOV MATCH_FLAG, 1
    JMP WRITE_OUT

HASH_FAIL:
    MOV MATCH_FLAG, 0

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

    LEA SI, K_MOD & CALL WF
    LEA SI, K_MOD
    CALL WF

    CMP MATCH_FLAG, 1
    JNE WRITE_NOMATCH

    LEA SI, K_OK    & CALL WF
    LEA SI, K_MATCH & CALL WF
    LEA SI, K_AX1   & CALL WF
    LEA SI, K_ALGO  & CALL WF
    LEA SI, K_OK
    CALL WF
    LEA SI, K_MATCH
    CALL WF
    LEA SI, K_AX1
    CALL WF
    LEA SI, K_ALGO
    CALL WF
    JMP CLOSE_OUT

WRITE_NOMATCH:
    LEA SI, K_ERR   & CALL WF
    LEA SI, K_NOMCH & CALL WF
    LEA SI, K_AX0   & CALL WF
    LEA SI, K_ERR
    CALL WF
    LEA SI, K_NOMCH
    CALL WF
    LEA SI, K_AX0
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
    LEA SI, K_ERR & CALL WF
    LEA SI, E_RD  & CALL WF
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
; FIND_PASSWORD — find "PASSWORD=" (not "STORED") in INBUF
; ============================================================
FIND_PASSWORD PROC
    PUSH AX
    PUSH CX
FPW_SCAN:
    CMP  BX, 9
    JL   FPW_NF
    ; avoid matching "STORED_PASSWORD="
    CMP  BYTE PTR [SI], 'S'
    JE   FPW_SKIP
    CMP  BYTE PTR [SI], 'P'
    JNE  FPW_SKIP
    CMP  BYTE PTR [SI+1], 'A'
    JNE  FPW_SKIP
    CMP  BYTE PTR [SI+2], 'S'
    JNE  FPW_SKIP
    CMP  BYTE PTR [SI+3], 'S'
    JNE  FPW_SKIP
    CMP  BYTE PTR [SI+4], 'W'
    JNE  FPW_SKIP
    CMP  BYTE PTR [SI+5], 'O'
    JNE  FPW_SKIP
    CMP  BYTE PTR [SI+6], 'R'
    JNE  FPW_SKIP
    CMP  BYTE PTR [SI+7], 'D'
    JNE  FPW_SKIP
    CMP  BYTE PTR [SI+8], '='
    JNE  FPW_SKIP
    ADD  SI, 9
    MOV  CX, 31
FPW_COPY:
    MOV  AL, [SI]
    CMP  AL, 13
    JE   FPW_END
    CMP  AL, 10
    JE   FPW_END
    CMP  AL, 0
    JE   FPW_END
    MOV  [DI], AL
    INC  SI
    INC  DI
    LOOP FPW_COPY
FPW_END:
    MOV  BYTE PTR [DI], 0
    JMP  FPW_DONE
FPW_SKIP:
    INC  SI
    DEC  BX
    JMP  FPW_SCAN
FPW_NF:
    MOV  BYTE PTR [DI], 0
FPW_DONE:
    POP  CX
    POP  AX
    RET
FIND_PASSWORD ENDP

; ============================================================
; FIND_STORED — find "STORED_PASSWORD=" in INBUF
; ============================================================
FIND_STORED PROC
    PUSH AX
    PUSH CX
    ; reset SI to INBUF start
    LEA  SI, INBUF
    MOV  BX, INLEN
FS_SCAN:
    CMP  BX, 16
    JL   FS_NF
    CMP  BYTE PTR [SI],    'S'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+1],  'T'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+2],  'O'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+3],  'R'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+4],  'E'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+5],  'D'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+6],  '_'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+7],  'P'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+8],  'A'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+9],  'S'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+10], 'S'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+11], 'W'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+12], 'O'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+13], 'R'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+14], 'D'
    JNE  FS_SKIP
    CMP  BYTE PTR [SI+15], '='
    JNE  FS_SKIP
    ADD  SI, 16
    MOV  CX, 31
FS_COPY:
    MOV  AL, [SI]
    CMP  AL, 13
    JE   FS_END
    CMP  AL, 10
    JE   FS_END
    CMP  AL, 0
    JE   FS_END
    MOV  [DI], AL
    INC  SI
    INC  DI
    LOOP FS_COPY
FS_END:
    MOV  BYTE PTR [DI], 0
    JMP  FS_DONE
FS_SKIP:
    INC  SI
    DEC  BX
    JMP  FS_SCAN
FS_NF:
    MOV  BYTE PTR [DI], 0
FS_DONE:
    POP  CX
    POP  AX
    RET
FIND_STORED ENDP

; ============================================================
; COMPUTE_HASH  SI=null-terminated string → AX = hash
; AX = 0; loop: AX = AX*31 + char
; ============================================================
COMPUTE_HASH PROC
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AX, 0
    MOV  BX, 31
CH_LOOP:
    MOV  CL, [SI]
    CMP  CL, 0
    JE   CH_DONE
    MUL  BX
    MOV  DH, 0
    MOV  DL, CL
    ADD  AX, DX
    INC  SI
    JMP  CH_LOOP
CH_DONE:
    POP  DX
    POP  CX
    POP  BX
    RET
COMPUTE_HASH ENDP

; ============================================================
; COMPARE_STRINGS  SI=str1, DI=str2 → AX=1 if equal, AX=0 if not
; ============================================================
COMPARE_STRINGS PROC
    PUSH BX
CS_LOOP:
    MOV  AL, [SI]
    MOV  BL, [DI]
    CMP  AL, BL
    JNE  CS_MISS
    CMP  AL, 0
    JE   CS_MATCH
    INC  SI
    INC  DI
    JMP  CS_LOOP
CS_MATCH:
    MOV  AX, 1
    POP  BX
    RET
CS_MISS:
    MOV  AX, 0
    POP  BX
    RET
COMPARE_STRINGS ENDP

; ============================================================
; WF / WFCRLF
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

WFCRLF PROC
    CALL WF
    PUSH SI
    LEA  SI, CRLF
    CALL WF
    POP  SI
    RET
WFCRLF ENDP

END MAIN
