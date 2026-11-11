; ==============================================================================
; FILE:           chars_pet.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Transcodifica dei caratteri dalla codifica PETSCII alle altre
;                 codifiche (sotto-modulo di chars.asm).
; CONTENUTO:      PET_SCR     Da PETSCII a Codice Schermo, senza controlli
;                 PET_SCR_C   Da PETSCII a Codice Schermo, con controlli
;                 PET_ASC     Da PETSCII a ASCII, senza controlli
;                 PET_ASC_C   Da PETSCII a ASCII, con controlli
;                 PET_ECM     Da PETSCII a ECM, senza controlli
;                 PET_ECM_C   Da PETSCII a ECM, con controlli
; DIPENDENZE:     Nessuna
; REQUISITI ZP:   __BG_COL
; ==============================================================================

; ==============================================================================
; SUBROUTINE: PET_SCR
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica PETSCII alla codifica Codice
;               Schermo, senza distinguere i codici di controllo. La conversione
;               è "glifo per glifo": il carattere stampato con il codice di
;               arrivo ha lo stesso aspetto di quello di partenza.
;
;               I codici da 32 a 127 e da 160 a 255 sono caratteri
;               normali. Quelli da 96 a 127 e da 192 a 223 sono due
;               codici per lo stesso glifo, come lo sono quelli da 160
;               a 191 e da 224 a 255. Il pigreco ha due codici (126 e
;               255): il 255 va nel codice 94 come il 126.
;
;               I codici di controllo (da 0 a 31 e da 128 a 159) non hanno un
;               equivalente in Codice Schermo. Si restituisce il glifo che
;               mostrano in modalità virgolette, cioè il carattere inverso
;               (da 128 a 159 e da 192 a 223), e la conversione è perfetta.
;               Per distinguere i codici di controllo si usa PET_SCR_C.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione perfetta (sempre); 1 = non
;                              si verifica
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_PET_SCR = 1) {
  !zone Pet_Scr

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    PET_SCR:
      tax                         ; Salva il codice originale in .X.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_PET_SCR_Exception

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_PET_SCR:
      clc
      rts

    .Exit_PET_SCR_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .BLOCK_TABLE:
      !byte %10000000             ; 0-31    > 128-159 (controllo)
      !byte %00100000             ; 32-63   > 32-63
      !byte %00000000             ; 64-95   > 0-31
      !byte %01000000             ; 96-127  > 64-95
      !byte %11000000             ; 128-159 > 192-223 (controllo)
      !byte %01100000             ; 160-191 > 96-127
      !byte %01000000             ; 192-223 > 64-95
      !byte %01100000             ; 224-255 > 96-127

    .EXCEPTIONS:
      !byte $FF, $5E              ; 255 > 94 (pigreco)

    .EXCEPTIONS_IMPERFECT:

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: PET_SCR_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica PETSCII alla codifica Codice
;               Schermo, riconoscendo i codici di controllo. Come PET_SCR, ma i
;               codici di controllo (da 0 a 31 e da 128 a 159) non hanno un
;               equivalente in Codice Schermo, che non ha codici di controllo:
;               la conversione è impossibile.
;
;               Il Carry a 0 dice che la conversione è perfetta. Il Carry a 1
;               dice che la conversione è impossibile, perché il codice è un
;               codice di controllo, e in questo caso .A vale $FF. Il valore di
;               .A non basta a distinguere i due casi, perché $FF è anche un
;               Codice Schermo valido (il pigreco inverso): si guarda il Carry.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione perfetta; 1 = conversione
;                              impossibile (codice di controllo)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_PET_SCR_C = 1) {
  !zone Pet_Scr_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    PET_SCR_C:
      tax                         ; Salva il codice originale in .X.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_PET_SCR_C_Exception

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

      bmi .Exit_PET_SCR_C_Impossible

    .Exit_PET_SCR_C:
      clc
      rts

    .Exit_PET_SCR_C_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_PET_SCR_C_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %11100000             ; 0-31    impossibile
      !byte %00100000             ; 32-63   > 32-63
      !byte %00000000             ; 64-95   > 0-31
      !byte %01000000             ; 96-127  > 64-95
      !byte %11100000             ; 128-159 impossibile
      !byte %01100000             ; 160-191 > 96-127
      !byte %01000000             ; 192-223 > 64-95
      !byte %01100000             ; 224-255 > 96-127

    .EXCEPTIONS:
      !byte $FF, $5E              ; 255 > 94 (pigreco)

    .EXCEPTIONS_IMPERFECT:

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: PET_ASC
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica PETSCII alla codifica ASCII a
;               7 bit, senza produrre codici di controllo. La conversione è
;               "glifo per glifo", con i codici ASCII letti come li mostra il
;               set di caratteri #2: le lettere minuscole stanno in 65-90 di
;               PETSCII (e in 1-26 di Codice Schermo) e le maiuscole in 193-218.
;
;               I caratteri ASCII che il Commodore non ha sono rappresentati da
;               caratteri grafici che somigliano all'originale e che sono uguali
;               nel set #1 e nel set #2, e la routine li riconverte nel
;               carattere ASCII che sostituiscono: per esempio il 125 diventa
;               124, la barra verticale. I codici duplicati di PETSCII (da 96 a
;               127 e da 192 a 223, da 160 a 191 e da 224 a 255) danno lo stesso
;               risultato.
;
;               I codici di controllo da 0 a 31 sono trattati come i caratteri
;               di Codice Schermo con lo stesso codice: ASCII ha il glifo
;               corrispondente, ma PETSCII lo mostra inverso in modalità
;               virgolette. Il Carry è quindi a 1 e il carattere in .A va
;               stampato in modalità inversa. Non hanno equivalente, con il
;               Carry a 1 e .A = $FF (non è un codice ASCII valido), i codici da
;               128 a 159, i grafici che non somigliano a nessun carattere ASCII
;               e i controlli 28 e 31, i cui glifi (sterlina e freccia a
;               sinistra) ASCII non ha.
;
;               Il Carry a 1 ha dunque due significati, che si distinguono con
;               un test su .A: se vale $FF la conversione è impossibile;
;               altrimenti .A è un carattere da stampare in modalità inversa (il
;               codice originale in .X è minore di 32).
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile (.A = $FF) o carattere da
;                              stampare in modalità inversa
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_PET_ASC = 1) {
  !zone Pet_Asc

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    PET_ASC:
      tax                         ; Salva il codice originale in .X.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_PET_ASC_Exception

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

      bmi .Exit_PET_ASC_Impossible

      cpx #%00100000              ; Se il codice originale era minore di 32
      bcc .Exit_PET_ASC_Inverse   ; il glifo va stampato inverso.

    .Exit_PET_ASC:
      clc
      rts

    .Exit_PET_ASC_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_PET_ASC_Inverse:
      sec                         ; Carattere da stampare inverso.
      rts

    .Exit_PET_ASC_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %01100000             ; 0-31    > 96-127 (inverso)
      !byte %00100000             ; 32-63   > 32-63
      !byte %01100000             ; 64-95   > 96-127
      !byte %01000000             ; 96-127  > 64-95
      !byte %11100000             ; 128-159 impossibile
      !byte %11100000             ; 160-191 impossibile
      !byte %01000000             ; 192-223 > 64-95
      !byte %11100000             ; 224-255 impossibile

    .EXCEPTIONS:
      !byte $40, $40              ; 64 > 64 (@)
      !byte $5B, $5B              ; 91 > 91 ([)
      !byte $5D, $5D              ; 93 > 93 (])
      !byte $5E, $5E              ; 94 > 94 (^)
      !byte $60, $7E              ; 96 > 126 (~)
      !byte $7D, $7C              ; 125 > 124 (|)
      !byte $A0, $20              ; 160 > 32 (spazio)
      !byte $A4, $5F              ; 164 > 95 (_)
      !byte $AB, $7D              ; 171 > 125 (})
      !byte $AD, $60              ; 173 > 96 (`)
      !byte $B3, $7B              ; 179 > 123 ({)
      !byte $BF, $5C              ; 191 > 92 (\)
      !byte $C0, $7E              ; 192 > 126 (~)
      !byte $DD, $7C              ; 221 > 124 (|)
      !byte $E0, $20              ; 224 > 32 (spazio)
      !byte $E4, $5F              ; 228 > 95 (_)
      !byte $EB, $7D              ; 235 > 125 (})
      !byte $ED, $60              ; 237 > 96 (`)
      !byte $F3, $7B              ; 243 > 123 ({)

    .EXCEPTIONS_IMPERFECT:
      !byte $00, $40              ; 0 > 64 (@, inverso)
      !byte $1B, $5B              ; 27 > 91 ([, inverso)
      !byte $1C, $FF              ; 28 > impossibile
      !byte $1D, $5D              ; 29 > 93 (], inverso)
      !byte $1E, $5E              ; 30 > 94 (^, inverso)
      !byte $1F, $FF              ; 31 > impossibile
      !byte $5C, $FF              ; 92 > impossibile
      !byte $5F, $FF              ; 95 > impossibile
      !byte $7B, $FF              ; 123 > impossibile
      !byte $7C, $FF              ; 124 > impossibile
      !byte $7E, $FF              ; 126 > impossibile
      !byte $7F, $FF              ; 127 > impossibile
      !byte $DB, $FF              ; 219 > impossibile
      !byte $DC, $FF              ; 220 > impossibile
      !byte $DE, $FF              ; 222 > impossibile
      !byte $DF, $FF              ; 223 > impossibile

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: PET_ASC_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica PETSCII alla codifica ASCII a
;               7 bit, riconoscendo i codici di controllo. Come PET_ASC, ma i
;               codici di controllo da 0 a 31 diventano i codici di controllo
;               ASCII con lo stesso codice, senza convertirne il significato
;               (che in molti casi è diverso), e la conversione è perfetta.
;
;               Il codice 166 e il suo duplicato 230, che somigliano a una
;               cancellazione, diventano il DEL (127), un codice di controllo:
;               la conversione è imperfetta, perché ASCII esegue un controllo
;               invece di mostrare il glifo di partenza. In PET_ASC sono
;               impossibili.
;
;               I codici da 128 a 159, i grafici che non somigliano a nessun
;               carattere ASCII e quelli da 160 a 191 e da 224 a 255 senza
;               equivalente non hanno una conversione: il Carry è a 1 e .A vale
;               $FF, che non è un codice ASCII valido.
;
;               Il Carry a 1 ha dunque due significati, che si distinguono con
;               un test su .A: se vale $FF la conversione è impossibile; se vale
;               127 è il codice di controllo DEL.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile (.A = $FF) o codice di
;                              controllo DEL (.A = 127)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_PET_ASC_C = 1) {
  !zone Pet_Asc_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    PET_ASC_C:
      tax                         ; Salva il codice originale in .X.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_PET_ASC_C_Exception

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

      bmi .Exit_PET_ASC_C_Impossible

    .Exit_PET_ASC_C:
      clc
      rts

    .Exit_PET_ASC_C_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_PET_ASC_C_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %00000000             ; 0-31    > 0-31 (controllo)
      !byte %00100000             ; 32-63   > 32-63
      !byte %01100000             ; 64-95   > 96-127
      !byte %01000000             ; 96-127  > 64-95
      !byte %11100000             ; 128-159 impossibile
      !byte %11100000             ; 160-191 impossibile
      !byte %01000000             ; 192-223 > 64-95
      !byte %11100000             ; 224-255 impossibile

    .EXCEPTIONS:
      !byte $40, $40              ; 64 > 64 (@)
      !byte $5B, $5B              ; 91 > 91 ([)
      !byte $5D, $5D              ; 93 > 93 (])
      !byte $5E, $5E              ; 94 > 94 (^)
      !byte $60, $7E              ; 96 > 126 (~)
      !byte $7D, $7C              ; 125 > 124 (|)
      !byte $A0, $20              ; 160 > 32 (spazio)
      !byte $A4, $5F              ; 164 > 95 (_)
      !byte $AB, $7D              ; 171 > 125 (})
      !byte $AD, $60              ; 173 > 96 (`)
      !byte $B3, $7B              ; 179 > 123 ({)
      !byte $BF, $5C              ; 191 > 92 (\)
      !byte $C0, $7E              ; 192 > 126 (~)
      !byte $DD, $7C              ; 221 > 124 (|)
      !byte $E0, $20              ; 224 > 32 (spazio)
      !byte $E4, $5F              ; 228 > 95 (_)
      !byte $EB, $7D              ; 235 > 125 (})
      !byte $ED, $60              ; 237 > 96 (`)
      !byte $F3, $7B              ; 243 > 123 ({)

    .EXCEPTIONS_IMPERFECT:
      !byte $5C, $FF              ; 92 > impossibile
      !byte $5F, $FF              ; 95 > impossibile
      !byte $7B, $FF              ; 123 > impossibile
      !byte $7C, $FF              ; 124 > impossibile
      !byte $7E, $FF              ; 126 > impossibile
      !byte $7F, $FF              ; 127 > impossibile
      !byte $A6, $7F              ; 166 > 127 (DEL, controllo)
      !byte $DB, $FF              ; 219 > impossibile
      !byte $DC, $FF              ; 220 > impossibile
      !byte $DE, $FF              ; 222 > impossibile
      !byte $DF, $FF              ; 223 > impossibile
      !byte $E6, $7F              ; 230 > 127 (DEL, controllo)

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: PET_ECM
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica PETSCII alla pseudo-codifica
;               ECM, cioè i codici come si interpretano con il modo Colore di
;               Sfondo Esteso attivo. La conversione separa le due informazioni:
;               .A riceve il codice del glifo, da 0 a 63, e il selettore del
;               colore di sfondo, da 0 a 3, va in __BG_COL. È il risultato di
;               PET_SCR seguita da SCR_ECM.
;
;               Il colore di sfondo dipende solo dal blocco di partenza: BGCOL0
;               per i codici da 32 a 95, BGCOL1 per i codici da 96 a 127 e da
;               160 a 255 (i caratteri ottenuti con SHIFT e i loro duplicati),
;               BGCOL2 per i codici di controllo da 0 a 31 e BGCOL3 per quelli
;               da 128 a 159, che il Kernal mostra come caratteri inversi in
;               modalità virgolette. Il glifo è dato dai sei bit meno
;               significativi del codice schermo: in ECM i grafici non esistono,
;               e i codici da 160 a 191 e da 224 a 255 hanno i glifi da 32 a 63.
;
;               Il pigreco ha due codici, 126 e 255, e ha il glifo 30 con
;               BGCOL1: il 255 è l'unica eccezione. La conversione è sempre
;               perfetta, il Carry è a 0. La modalità inversa non è nel codice
;               PETSCII: chi stampa in modalità inversa fa l'OR di __BG_COL con
;               %10.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;
; Output:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;   - Flag Carry (1 bit, .P) : 0 = conversione perfetta (sempre); 1 = non
;                              si verifica
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry), __BG_COL
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_PET_ECM = 1) {
  !zone Pet_Ecm

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS

    PET_ECM:
      tax                         ; Salva il codice originale in .X.

      txa
      lsr a                       ; Indice del blocco di partenza (0-7):
      lsr a                       ; tre bit più significativi del codice.
      lsr a
      lsr a
      lsr a
      tay
      lda .BG_TABLE,y
      sta __BG_COL                ; Selettore del colore di sfondo.

      txa
      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_PET_ECM

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_PET_ECM:
      clc                         ; Nessuna informazione persa.
      rts

    .BLOCK_TABLE:
      !byte %00000000             ; 0-31    > 0-31
      !byte %00100000             ; 32-63   > 32-63
      !byte %00000000             ; 64-95   > 0-31
      !byte %00000000             ; 96-127  > 0-31
      !byte %00000000             ; 128-159 > 0-31
      !byte %00100000             ; 160-191 > 32-63
      !byte %00000000             ; 192-223 > 0-31
      !byte %00100000             ; 224-255 > 32-63

    .BG_TABLE:
      !byte %00000010             ; 0-31    > BGCOL2
      !byte %00000000             ; 32-63   > BGCOL0
      !byte %00000000             ; 64-95   > BGCOL0
      !byte %00000001             ; 96-127  > BGCOL1
      !byte %00000011             ; 128-159 > BGCOL3
      !byte %00000001             ; 160-191 > BGCOL1
      !byte %00000001             ; 192-223 > BGCOL1
      !byte %00000001             ; 224-255 > BGCOL1

    .EXCEPTIONS:
      !byte $FF, $1E              ; 255 > 30 (pigreco)

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: PET_ECM_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica PETSCII alla pseudo-codifica
;               ECM, riconoscendo i codici di controllo. Come PET_ECM, ma i
;               codici di controllo (da 0 a 31 e da 128 a 159) non hanno un
;               equivalente in ECM, che come Codice Schermo non ha codici di
;               controllo: la conversione è impossibile.
;
;               Il Carry a 0 dice che la conversione è perfetta. Il Carry a 1
;               dice che è impossibile, perché il codice è un codice di
;               controllo: .A vale $FF e __BG_COL non viene modificato. Il
;               valore di .A non basta a distinguere i due casi, perché $FF è
;               anche un codice ECM valido: si guarda il Carry.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;
; Output:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;   - Flag Carry (1 bit, .P) : 0 = conversione perfetta; 1 = conversione
;                              impossibile (codice di controllo)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry), __BG_COL
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_PET_ECM_C = 1) {
  !zone Pet_Ecm_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS

    PET_ECM_C:
      tax                         ; Salva il codice originale in .X.

      and #%01100000              ; Zero se è un controllo (blocchi 0 e 4).
      beq .Exit_PET_ECM_C_Impossible

      txa
      lsr a                       ; Indice del blocco di partenza (0-7):
      lsr a                       ; tre bit più significativi del codice.
      lsr a
      lsr a
      lsr a
      tay
      lda .BG_TABLE,y
      sta __BG_COL                ; Selettore del colore di sfondo.

      txa
      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_PET_ECM_C

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_PET_ECM_C:
      clc                         ; Nessuna informazione persa.
      rts

    .Exit_PET_ECM_C_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %00000000             ; 0-31    impossibile
      !byte %00100000             ; 32-63   > 32-63
      !byte %00000000             ; 64-95   > 0-31
      !byte %00000000             ; 96-127  > 0-31
      !byte %00000000             ; 128-159 impossibile
      !byte %00100000             ; 160-191 > 32-63
      !byte %00000000             ; 192-223 > 0-31
      !byte %00100000             ; 224-255 > 32-63

    .BG_TABLE:
      !byte %00000000             ; 0-31    impossibile
      !byte %00000000             ; 32-63   > BGCOL0
      !byte %00000000             ; 64-95   > BGCOL0
      !byte %00000001             ; 96-127  > BGCOL1
      !byte %00000000             ; 128-159 impossibile
      !byte %00000001             ; 160-191 > BGCOL1
      !byte %00000001             ; 192-223 > BGCOL1
      !byte %00000001             ; 224-255 > BGCOL1

    .EXCEPTIONS:
      !byte $FF, $1E              ; 255 > 30 (pigreco)

    .EXCEPTIONS_END:

  !zone
}
