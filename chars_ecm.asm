; ==============================================================================
; FILE:           chars_ecm.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Transcodifica dei caratteri dalla pseudo-codifica ECM alle
;                 altre codifiche (sotto-modulo di chars.asm).
; CONTENUTO:      ECM_SCR     Da ECM a Codice Schermo, senza controlli
;                 ECM_SCR_C   Da ECM a Codice Schermo, con controlli
;                 ECM_PET     Da ECM a PETSCII, senza controlli
;                 ECM_PET_C   Da ECM a PETSCII, con controlli
;                 ECM_ASC     Da ECM a ASCII, senza controlli
;                 ECM_ASC_C   Da ECM a ASCII, con controlli
; DIPENDENZE:     Nessuna
; REQUISITI ZP:   __BG_COL
; ==============================================================================
; ==============================================================================
; SUBROUTINE: ECM_SCR
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla pseudo-codifica ECM, cioè i codici come
;               si interpretano con il modo Colore di Sfondo Esteso attivo, alla
;               codifica Codice Schermo. In ingresso .A è il codice del glifo,
;               da 0 a 63, e __BG_COL il selettore del colore di sfondo, da 0 a
;               3: i due bit più significativi di .A e i sei più significativi
;               di __BG_COL sono ignorati. Il codice Schermo ha il glifo nei sei
;               bit meno significativi e il selettore nei due più significativi.
;               È la conversione inversa di SCR_ECM.
;
;               Nessuna informazione si perde e non ci sono eccezioni: il Carry
;               è sempre 0. Codice Schermo non ha codici di controllo: ECM_SCR_C
;               è identica a ECM_SCR.
;
; Input:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;   - .X (1 byte, CPU)       : Codice Schermo equivalente (glifo e sfondo)
;   - Flag Carry (1 bit, .P) : sempre 0
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   Nessuna
; ==============================================================================
!if (__USE_ECM_SCR = 1) {
  !zone Ecm_Scr

    ECM_SCR:
      and #%00111111              ; Codice del glifo, da 0 a 63.
      tax

      lda __BG_COL
      and #%00000011              ; Selettore del colore di sfondo.
      tay

      txa
      ora .BG_TABLE,y             ; Aggiunge i bit #7-#6 del codice Schermo.
      tax                         ; .X = codice Schermo.

    .Exit_ECM_SCR:
      clc                         ; Nessuna informazione persa.
      rts

    .BG_TABLE:
      !byte %00000000             ; 0 (BGCOL0) > 0-63
      !byte %01000000             ; 1 (BGCOL1) > 64-127
      !byte %10000000             ; 2 (BGCOL2) > 128-191 (inverso)
      !byte %11000000             ; 3 (BGCOL3) > 192-255 (inverso)

  !zone
}

; ==============================================================================
; SUBROUTINE: ECM_SCR_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla pseudo-codifica ECM alla codifica
;               Codice Schermo, riconoscendo i codici di controllo. Codice
;               Schermo non ha codici di controllo: ECM_SCR_C è identica a
;               ECM_SCR (vedi ECM_SCR per la descrizione).
;
; Input:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;   - .X (1 byte, CPU)       : Codice Schermo equivalente (glifo e sfondo)
;   - Flag Carry (1 bit, .P) : sempre 0
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   Nessuna
; ==============================================================================
!if (__USE_ECM_SCR_C = 1) {
  !zone Ecm_Scr_C

    ECM_SCR_C:
      and #%00111111              ; Codice del glifo, da 0 a 63.
      tax

      lda __BG_COL
      and #%00000011              ; Selettore del colore di sfondo.
      tay

      txa
      ora .BG_TABLE,y             ; Aggiunge i bit #7-#6 del codice Schermo.
      tax                         ; .X = codice Schermo.

    .Exit_ECM_SCR_C:
      clc                         ; Nessuna informazione persa.
      rts

    .BG_TABLE:
      !byte %00000000             ; 0 (BGCOL0) > 0-63
      !byte %01000000             ; 1 (BGCOL1) > 64-127
      !byte %10000000             ; 2 (BGCOL2) > 128-191 (inverso)
      !byte %11000000             ; 3 (BGCOL3) > 192-255 (inverso)

  !zone
}

; ==============================================================================
; SUBROUTINE: ECM_PET
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla pseudo-codifica ECM alla codifica
;               PETSCII, senza produrre codici di controllo. In ingresso .A è il
;               codice del glifo, da 0 a 63, e __BG_COL il selettore del colore
;               di sfondo, da 0 a 3: i due bit più significativi di .A e i sei
;               più significativi di __BG_COL sono ignorati. Equivale a ECM_SCR
;               seguita da SCR_PET ed è la conversione inversa di PET_ECM.
;
;               BGCOL0 dà i codici da 32 a 95 e BGCOL1 i codici da 160 a 223,
;               quelli generati dalla tastiera. BGCOL2 e BGCOL3 sono i caratteri
;               inversi, che PETSCII non ha: si restituisce il carattere normale
;               con Carry a 1, che significa che il carattere in .A va stampato
;               in modalità inversa. Il pigreco (glifo 30 con BGCOL1 o BGCOL3)
;               diventa 255, come in SCR_PET.
;
; Input:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;   - .X (1 byte, CPU)       : Codice Schermo equivalente (glifo e sfondo)
;   - Flag Carry (1 bit, .P) : 0 = conversione perfetta; 1 = il carattere va
;                              stampato in modalità inversa
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ECM_PET = 1) {
  !zone Ecm_Pet

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    ECM_PET:
      and #%00111111              ; Codice del glifo, da 0 a 63.
      tax

      lda __BG_COL
      and #%00000011              ; Selettore del colore di sfondo.
      tay

      txa
      ora .BG_TABLE,y             ; Aggiunge i bit #7-#6 del codice Schermo.
      tax                         ; .X = codice Schermo.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_ECM_PET_Exception

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_ECM_PET:
      cpx #%10000000              ; Se il carattere era inverso,
      rts                         ; Carry = 1.

    .Exit_ECM_PET_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .BG_TABLE:
      !byte %00000000             ; 0 (BGCOL0) > 0-63
      !byte %01000000             ; 1 (BGCOL1) > 64-127
      !byte %10000000             ; 2 (BGCOL2) > 128-191 (inverso)
      !byte %11000000             ; 3 (BGCOL3) > 192-255 (inverso)

    .BLOCK_TABLE:
      !byte %01000000             ; 0-31    > 64-95
      !byte %00100000             ; 32-63   > 32-63
      !byte %11000000             ; 64-95   > 192-223
      !byte %10100000             ; 96-127  > 160-191
      !byte %01000000             ; 128-159 > 64-95 (inverso)
      !byte %00100000             ; 160-191 > 32-63 (inverso)
      !byte %11000000             ; 192-223 > 192-223 (inverso)
      !byte %10100000             ; 224-255 > 160-191 (inverso)

    .EXCEPTIONS:
      !byte $5E, $FF              ; 94 > 255 (pigreco)

    .EXCEPTIONS_IMPERFECT:
      !byte $DE, $FF              ; 222 > 255 (pigreco inverso)

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: ECM_PET_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla pseudo-codifica ECM alla codifica
;               PETSCII, producendo codici di controllo. In ingresso .A è il
;               codice del glifo, da 0 a 63, e __BG_COL il selettore del colore
;               di sfondo, da 0 a 3: i due bit più significativi di .A e i sei
;               più significativi di __BG_COL sono ignorati. Equivale a
;               ECM_SCR_C seguita da SCR_PET_C. Come in ECM_PET, BGCOL0 dà i
;               codici da 32 a 95 e BGCOL1 i codici da 160 a 223.
;
;               I glifi da 0 a 31 con BGCOL2 e con BGCOL3 sono i caratteri
;               inversi che in modo Virgolette rappresentano i codici di
;               controllo da 0 a 31 e da 128 a 159, e diventano quei codici (il
;               pigreco con BGCOL3 diventa 158, il codice di YELLOW). I glifi da
;               32 a 63 con BGCOL2 e BGCOL3 diventano, come in ECM_PET, il
;               carattere normale da stampare in modalità inversa.
;
;               Il Carry a 0 dice che la conversione è perfetta. Con il Carry a
;               1 la conversione è imperfetta in uno di due modi, e si
;               distinguono con un test su .A: se i bit #6 e #5 di .A sono
;               entrambi zero (and #%01100000 dà zero), .A è un codice di
;               controllo; altrimenti .A è un carattere stampabile, che va
;               stampato in modalità inversa.
;
; Input:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;   - .X (1 byte, CPU)       : Codice Schermo equivalente (glifo e sfondo)
;   - Flag Carry (1 bit, .P) : 0 = conversione perfetta; 1 = conversione
;                              imperfetta: .A è un codice di controllo o un
;                              carattere da stampare in modalità inversa
;                              (vedi la Descrizione)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ECM_PET_C = 1) {
  !zone Ecm_Pet_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    ECM_PET_C:
      and #%00111111              ; Codice del glifo, da 0 a 63.
      tax

      lda __BG_COL
      and #%00000011              ; Selettore del colore di sfondo.
      tay

      txa
      ora .BG_TABLE,y             ; Aggiunge i bit #7-#6 del codice Schermo.
      tax                         ; .X = codice Schermo.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_ECM_PET_C_Exception

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_ECM_PET_C:
      cpx #%10000000              ; Se il carattere era inverso,
      rts                         ; Carry = 1.

    .Exit_ECM_PET_C_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .BG_TABLE:
      !byte %00000000             ; 0 (BGCOL0) > 0-63
      !byte %01000000             ; 1 (BGCOL1) > 64-127
      !byte %10000000             ; 2 (BGCOL2) > 128-191 (inverso)
      !byte %11000000             ; 3 (BGCOL3) > 192-255 (inverso)

    .BLOCK_TABLE:
      !byte %01000000             ; 0-31    > 64-95
      !byte %00100000             ; 32-63   > 32-63
      !byte %11000000             ; 64-95   > 192-223
      !byte %10100000             ; 96-127  > 160-191
      !byte %00000000             ; 128-159 > 0-31 (inverso, controllo)
      !byte %00100000             ; 160-191 > 32-63 (inverso)
      !byte %10000000             ; 192-223 > 128-159 (inverso, controllo)
      !byte %10100000             ; 224-255 > 160-191 (inverso)

    .EXCEPTIONS:
      !byte $5E, $FF              ; 94 > 255 (pigreco)

    .EXCEPTIONS_IMPERFECT:

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: ECM_ASC
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla pseudo-codifica ECM alla codifica ASCII
;               a 7 bit, senza produrre codici di controllo. In ingresso .A è il
;               codice del glifo, da 0 a 63, e __BG_COL il selettore del colore
;               di sfondo, da 0 a 3: i due bit più significativi di .A e i sei
;               più significativi di __BG_COL sono ignorati. Equivale a ECM_SCR
;               seguita da SCR_ASC.
;
;               Valgono le regole di SCR_ASC: i glifi con BGCOL0 e BGCOL1 si
;               convertono nel carattere ASCII che ha lo stesso aspetto, anche
;               con le sostituzioni di glifo (vedi [NOTA #03 in
;               <io/chars.asm>]). BGCOL2 e BGCOL3 sono i caratteri inversi, che
;               ASCII non ha: la conversione è impossibile, come per i grafici
;               che non somigliano a nessun carattere ASCII. In quel caso il
;               Carry è a 1 e .A vale $FF, che non è un codice ASCII valido.
;
; Input:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice Schermo equivalente (glifo e sfondo)
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile, con .A = $FF
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ECM_ASC = 1) {
  !zone Ecm_Asc

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    ECM_ASC:
      and #%00111111              ; Codice del glifo, da 0 a 63.
      tax

      lda __BG_COL
      and #%00000011              ; Selettore del colore di sfondo.
      tay

      txa
      ora .BG_TABLE,y             ; Aggiunge i bit #7-#6 del codice Schermo.
      tax                         ; .X = codice Schermo.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_ECM_ASC_Exception

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

      bmi .Exit_ECM_ASC_Impossible

    .Exit_ECM_ASC:
      clc
      rts

    .Exit_ECM_ASC_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_ECM_ASC_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BG_TABLE:
      !byte %00000000             ; 0 (BGCOL0) > 0-63
      !byte %01000000             ; 1 (BGCOL1) > 64-127
      !byte %10000000             ; 2 (BGCOL2) > 128-191 (inverso)
      !byte %11000000             ; 3 (BGCOL3) > 192-255 (inverso)

    .BLOCK_TABLE:
      !byte %01100000             ; 0-31    > 96-127
      !byte %00100000             ; 32-63   > 32-63
      !byte %01000000             ; 64-95   > 64-95
      !byte %11100000             ; 96-127  impossibile
      !byte %11100000             ; 128-159 impossibile
      !byte %11100000             ; 160-191 impossibile
      !byte %11100000             ; 192-223 impossibile
      !byte %11100000             ; 224-255 impossibile

    .EXCEPTIONS:
      !byte $00, $40              ; 0 > 64 (@)
      !byte $1B, $5B              ; 27 > 91 ([)
      !byte $1D, $5D              ; 29 > 93 (])
      !byte $1E, $5E              ; 30 > 94 (^)
      !byte $40, $7E              ; 64 > 126 (~)
      !byte $5D, $7C              ; 93 > 124 (|)
      !byte $60, $20              ; 96 > 32 (spazio)
      !byte $64, $5F              ; 100 > 95 (_)
      !byte $6B, $7D              ; 107 > 125 (})
      !byte $6D, $60              ; 109 > 96 (`)
      !byte $73, $7B              ; 115 > 123 ({)
      !byte $7F, $5C              ; 127 > 92 (\)

    .EXCEPTIONS_IMPERFECT:
      !byte $1C, $FF              ; 28 > impossibile
      !byte $1F, $FF              ; 31 > impossibile
      !byte $5B, $FF              ; 91 > impossibile
      !byte $5C, $FF              ; 92 > impossibile
      !byte $5E, $FF              ; 94 > impossibile
      !byte $5F, $FF              ; 95 > impossibile
      !byte $66, $FF              ; 102 > impossibile

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: ECM_ASC_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla pseudo-codifica ECM alla codifica ASCII
;               a 7 bit, producendo codici di controllo. In ingresso .A è il
;               codice del glifo, da 0 a 63, e __BG_COL il selettore del colore
;               di sfondo, da 0 a 3: i due bit più significativi di .A e i sei
;               più significativi di __BG_COL sono ignorati. Equivale a
;               ECM_SCR_C seguita da SCR_ASC_C. Come in ECM_ASC, ma i glifi da 0
;               a 31 con BGCOL2, che sono i caratteri inversi da 128 a 159 di
;               Codice Schermo, diventano i codici di controllo da 0 a 31, e il
;               glifo 38 con BGCOL1, che somiglia a una cancellazione, diventa
;               il DEL (127).
;
;               Il Carry a 0 dice che la conversione è riuscita. Con il Carry a
;               1 la conversione è impossibile o cambia la semantica, e si
;               distinguono con un test su .A: se vale $FF la conversione è
;               impossibile; altrimenti .A è un codice di controllo (da 0 a 31
;               oppure 127).
;
; Input:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice Schermo equivalente (glifo e sfondo)
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile (.A = $FF) o codice di controllo
;                              (vedi la Descrizione)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ECM_ASC_C = 1) {
  !zone Ecm_Asc_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    ECM_ASC_C:
      and #%00111111              ; Codice del glifo, da 0 a 63.
      tax

      lda __BG_COL
      and #%00000011              ; Selettore del colore di sfondo.
      tay

      txa
      ora .BG_TABLE,y             ; Aggiunge i bit #7-#6 del codice Schermo.
      tax                         ; .X = codice Schermo.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_ECM_ASC_C_Exception

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

      bmi .Exit_ECM_ASC_C_Impossible

    .Exit_ECM_ASC_C:
      cpx #%10000000              ; Se il carattere era inverso,
      rts                         ; Carry = 1.

    .Exit_ECM_ASC_C_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_ECM_ASC_C_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BG_TABLE:
      !byte %00000000             ; 0 (BGCOL0) > 0-63
      !byte %01000000             ; 1 (BGCOL1) > 64-127
      !byte %10000000             ; 2 (BGCOL2) > 128-191 (inverso)
      !byte %11000000             ; 3 (BGCOL3) > 192-255 (inverso)

    .BLOCK_TABLE:
      !byte %01100000             ; 0-31    > 96-127
      !byte %00100000             ; 32-63   > 32-63
      !byte %01000000             ; 64-95   > 64-95
      !byte %11100000             ; 96-127  impossibile
      !byte %00000000             ; 128-159 > 0-31 (controllo)
      !byte %11100000             ; 160-191 impossibile
      !byte %11100000             ; 192-223 impossibile
      !byte %11100000             ; 224-255 impossibile

    .EXCEPTIONS:
      !byte $00, $40              ; 0 > 64 (@)
      !byte $1B, $5B              ; 27 > 91 ([)
      !byte $1D, $5D              ; 29 > 93 (])
      !byte $1E, $5E              ; 30 > 94 (^)
      !byte $40, $7E              ; 64 > 126 (~)
      !byte $5D, $7C              ; 93 > 124 (|)
      !byte $60, $20              ; 96 > 32 (spazio)
      !byte $64, $5F              ; 100 > 95 (_)
      !byte $6B, $7D              ; 107 > 125 (})
      !byte $6D, $60              ; 109 > 96 (`)
      !byte $73, $7B              ; 115 > 123 ({)
      !byte $7F, $5C              ; 127 > 92 (\)

    .EXCEPTIONS_IMPERFECT:
      !byte $66, $7F              ; 102 > 127 (DEL, controllo)
      !byte $1C, $FF              ; 28 > impossibile
      !byte $1F, $FF              ; 31 > impossibile
      !byte $5B, $FF              ; 91 > impossibile
      !byte $5C, $FF              ; 92 > impossibile
      !byte $5E, $FF              ; 94 > impossibile
      !byte $5F, $FF              ; 95 > impossibile

    .EXCEPTIONS_END:

  !zone
}
