; ==============================================================================
; FILE:           chars_scr.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Transcodifica dei caratteri dalla codifica Codice Schermo alle
;                 altre codifiche (sotto-modulo di chars.asm).
; CONTENUTO:      SCR_PET     Da Codice Schermo a PETSCII, senza controlli
;                 SCR_PET_C   Da Codice Schermo a PETSCII, con controlli
;                 SCR_ASC     Da Codice Schermo a ASCII, senza controlli
;                 SCR_ASC_C   Da Codice Schermo a ASCII, con controlli
;                 SCR_ECM     Da Codice Schermo a ECM, senza controlli
;                 SCR_ECM_C   Da Codice Schermo a ECM, con controlli
; DIPENDENZE:     Nessuna
; REQUISITI ZP:   __BG_COL
; ==============================================================================

; ==============================================================================
; SUBROUTINE: SCR_PET
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica Codice Schermo alla codifica
;               PETSCII, senza produrre codici di controllo. La conversione è
;               "glifo per glifo": il carattere stampato con il codice di arrivo
;               ha lo stesso aspetto di quello di partenza.
;
;               I codici da 0 a 127 sono i caratteri normali. Quelli da 64 a 127
;               hanno in PETSCII due codici, e si restituisce quello generato
;               dalla tastiera (192-223 e 160-191).
;
;               I codici da 128 a 255 sono i caratteri inversi, che PETSCII non
;               ha: si restituisce il carattere normale con Carry a 1, che
;               significa che il carattere in .A va stampato in modalità
;               inversa.
;
;               Il pigreco è un'eccezione: il codice 94 e il codice 222 (il
;               pigreco inverso) diventano 255, il codice che genera la
;               tastiera.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione perfetta; 1 = il carattere va
;                              stampato in modalità inversa
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_SCR_PET = 1) {
  !zone Scr_Pet

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    SCR_PET:
      tax                         ; Salva il codice originale in .X.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_SCR_PET_Exception

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_SCR_PET:
      cpx #%10000000              ; Se il codice originale era inverso,
      rts                         ; Carry = 1.

    .Exit_SCR_PET_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

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
; SUBROUTINE: SCR_PET_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica Codice Schermo alla codifica
;               PETSCII, producendo codici di controllo per i caratteri inversi
;               che li rappresentano. La conversione è "glifo per glifo", con i
;               codici di controllo mostrati in modo Virgolette.
;
;               I codici da 0 a 127 si convertono come in SCR_PET, compreso il
;               pigreco (94 diventa 255). I caratteri inversi da 128 a 159 e da
;               192 a 223 diventano i codici di controllo da 0 a 31 e da 128 a
;               159, che in modo Virgolette si vedono con quel glifo
;               inverso; il pigreco inverso (222) diventa quindi 158 (il codice
;               di YELLOW). L'alternativa, che è anche la scelta del Kernal
;               nella lettura dello schermo, sarebbe 255 con il Carry a 1, cioè
;               il pigreco da stampare in modalità inversa: non è adottata. I
;               caratteri inversi da 160 a 191 e da 224 a 255 diventano, come in
;               SCR_PET, il carattere normale da stampare in modalità inversa.
;
;               Il Carry a 0 dice che la conversione è perfetta. Con il Carry
;               a 1 la conversione è imperfetta in uno di due modi, e si
;               distinguono con un test su .A: se i bit #6 e #5 di .A sono
;               entrambi zero (and #%01100000 dà zero), .A è un codice di
;               controllo, che mostra il glifo inverso solo se viene stampato
;               in modo Virgolette e fuori dalle virgolette esegue il
;               controllo; altrimenti .A è un carattere stampabile, che va
;               stampato in modalità inversa. In ogni caso il bit #7 di .X
;               dice che il carattere originale era inverso.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione perfetta; 1 = conversione
;                              imperfetta: .A è un codice di controllo o un
;                              carattere da stampare in modalità inversa (vedi
;                              la Descrizione)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_SCR_PET_C = 1) {
  !zone Scr_Pet_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    SCR_PET_C:
      tax                         ; Salva il codice originale in .X.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_SCR_PET_C_Exception

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_SCR_PET_C:
      cpx #%10000000              ; Se il codice originale era inverso,
      rts                         ; Carry = 1.

    .Exit_SCR_PET_C_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

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
; SUBROUTINE: SCR_ASC
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica Codice Schermo alla codifica
;               ASCII a 7 bit, senza produrre codici di controllo. La
;               conversione è "glifo per glifo", con i codici letti come li
;               mostra il set di caratteri #2: da 1 a 26 le lettere minuscole,
;               da 65 a 90 le maiuscole, da 32 a 63 gli stessi caratteri che ha
;               ASCII con quei codici.
;
;               I caratteri ASCII che il Commodore non ha sono sostituiti da
;               caratteri grafici: la routine li riconverte nel carattere ASCII
;               che sostituiscono (vedi [NOTA #03 in <io/chars.asm>]).
;
;               Gli altri codici, cioè i caratteri inversi e i grafici che non
;               somigliano a nessun carattere ASCII, non hanno equivalente: il
;               Carry è a 1 e .A vale $FF, che non è un codice ASCII valido. Il
;               codice 102, che somiglia a una cancellazione, in questa variante
;               è impossibile, perché il suo equivalente sarebbe il DEL (127),
;               un codice di controllo: lo produce SCR_ASC_C.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile, con .A = $FF
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_SCR_ASC = 1) {
  !zone Scr_Asc

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    SCR_ASC:
      tax                         ; Salva il codice originale in .X.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_SCR_ASC_Exception

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

      bmi .Exit_SCR_ASC_Impossible

    .Exit_SCR_ASC:
      clc
      rts

    .Exit_SCR_ASC_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_SCR_ASC_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

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
; SUBROUTINE: SCR_ASC_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica Codice Schermo alla codifica
;               ASCII a 7 bit, producendo codici di controllo. Come SCR_ASC, con
;               in più due conversioni verso codici di controllo ASCII: i
;               caratteri inversi da 128 a 159 diventano i codici da 0 a 31, e
;               il codice 102, che somiglia a una cancellazione, diventa il DEL,
;               cioè il codice 127.
;
;               Il Carry a 0 dice che la conversione è riuscita, con la
;               sostituzione del glifo quando serve. Con il Carry a 1 la
;               conversione è impossibile o cambia la semantica, e si
;               distinguono con un test su .A: se vale $FF la conversione è
;               impossibile e non ha equivalente ASCII; altrimenti .A è un
;               codice di controllo (da 0 a 31 oppure 127), che esegue il
;               controllo invece di mostrare il glifo di partenza.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;   - .X (1 byte, CPU)       : Codice carattere originale
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
!if (__USE_SCR_ASC_C = 1) {
  !zone Scr_Asc_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    SCR_ASC_C:
      tax                         ; Salva il codice originale in .X.

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_SCR_ASC_C_Exception

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

      bmi .Exit_SCR_ASC_C_Impossible

    .Exit_SCR_ASC_C:
      cpx #%10000000              ; Se il codice originale era inverso,
      rts                         ; Carry = 1.

    .Exit_SCR_ASC_C_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_SCR_ASC_C_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

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

; ==============================================================================
; SUBROUTINE: SCR_ECM
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica Codice Schermo alla pseudo-
;               codifica ECM, cioè i codici come si interpretano con il modo
;               Colore di Sfondo Esteso attivo. In ECM i due bit più
;               significativi del codice scelgono il registro del colore di
;               sfondo (BGCOL0-BGCOL3) e i sei bit restanti il glifo, da 0 a 63.
;
;               La conversione separa le due informazioni: .A riceve il codice
;               del glifo, cioè il codice con i due bit più significativi
;               azzerati, e il selettore del colore di sfondo, da 0 a 3, va in
;               __BG_COL. Nessuna informazione si perde e non ci sono eccezioni:
;               il Carry è sempre 0.
;
;               Codice Schermo non ha codici di controllo: SCR_ECM_C è identica
;               a SCR_ECM.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;
; Output:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;   - Flag Carry (1 bit, .P) : sempre 0
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .P (Negative, Zero, Carry), __BG_COL
; Dipendenze Esterne:   Nessuna
; ==============================================================================
!if (__USE_SCR_ECM = 1) {
  !zone Scr_Ecm

    SCR_ECM:
      tax                         ; Salva il codice originale in .X.

      asl a                       ; Porta i bit #7-#6 nelle posizioni #1-#0
      rol a                       ; con tre rotazioni a sinistra
      rol a                       ; attraverso il Carry.
      and #%00000011
      sta __BG_COL                ; Selettore del colore di sfondo.

      txa
      and #%00111111              ; Codice del glifo, da 0 a 63.

    .Exit_SCR_ECM:
      clc                         ; Nessuna informazione persa.
      rts

  !zone
}

; ==============================================================================
; SUBROUTINE: SCR_ECM_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica Codice Schermo alla pseudo-
;               codifica ECM, trattando i codici di controllo. Codice Schermo
;               non ha codici di controllo, quindi la routine è identica a
;               SCR_ECM e c'è solo per completare la famiglia di routine: la
;               conversione separa il codice del glifo (i sei bit meno
;               significativi, in .A) dal selettore del colore di sfondo (i due
;               bit più significativi, da 0 a 3, in __BG_COL). Nessuna
;               informazione si perde: il Carry è sempre 0.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;
; Output:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;   - Flag Carry (1 bit, .P) : sempre 0
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .P (Negative, Zero, Carry), __BG_COL
; Dipendenze Esterne:   Nessuna
; ==============================================================================
!if (__USE_SCR_ECM_C = 1) {
  !zone Scr_Ecm_C

    SCR_ECM_C:
      tax                         ; Salva il codice originale in .X.

      asl a                       ; Porta i bit #7-#6 nelle posizioni #1-#0
      rol a                       ; con tre rotazioni a sinistra
      rol a                       ; attraverso il Carry.
      and #%00000011
      sta __BG_COL                ; Selettore del colore di sfondo.

      txa
      and #%00111111              ; Codice del glifo, da 0 a 63.

    .Exit_SCR_ECM_C:
      clc                         ; Nessuna informazione persa.
      rts

  !zone
}
