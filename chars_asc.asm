; ==============================================================================
; FILE:           chars_asc.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Transcodifica dei caratteri dalla codifica ASCII a 7 bit alle
;                 altre codifiche (sotto-modulo di chars.asm).
; CONTENUTO:      ASC_SCR     Da ASCII a Codice Schermo, senza controlli
;                 ASC_SCR_C   Da ASCII a Codice Schermo, con controlli
;                 ASC_PET     Da ASCII a PETSCII, senza controlli
;                 ASC_PET_C   Da ASCII a PETSCII, con controlli
;                 ASC_ECM     Da ASCII a ECM, senza controlli
;                 ASC_ECM_C   Da ASCII a ECM, con controlli
; DIPENDENZE:     Nessuna
; REQUISITI ZP:   __BG_COL
; ==============================================================================

; ==============================================================================
; SUBROUTINE: ASC_SCR
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica ASCII a 7 bit alla codifica
;               Codice Schermo, senza produrre codici di controllo. La
;               conversione è "glifo per glifo", con i codici ASCII letti come
;               li mostra il set di caratteri #2: da 65 a 90 le lettere
;               maiuscole (i codici da 65 a 90 di Codice Schermo), da 97 a 122
;               le minuscole (da 1 a 26), da 32 a 63 gli stessi caratteri.
;
;               I caratteri ASCII che il Commodore non ha sono rappresentati da
;               caratteri grafici che somigliano all'originale e che sono uguali
;               nel set #1 e nel set #2, in modo che la conversione non dipenda
;               da un set di caratteri personalizzato: per esempio la barra
;               verticale (124) diventa il codice 93.
;
;               I codici di controllo ASCII (da 0 a 31) e il DEL (127) non hanno
;               un glifo: i controlli diventano il glifo inverso del carattere
;               con il codice più 64 (da 128 a 159), e il DEL il codice 102, che
;               somiglia a una cancellazione. La conversione è perfetta: Codice
;               Schermo ha i caratteri inversi.
;
;               I codici da 128 a 255, che non sono ASCII a 7 bit, non hanno
;               equivalente: la conversione è impossibile, con il Carry a 1 e .A
;               = $FF. Nessun codice ASCII ha $FF come equivalente, e il Carry a
;               1 ha solo questo significato.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile (.A = $FF)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ASC_SCR = 1) {
  !zone Asc_Scr

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    ASC_SCR:
      tax                         ; Salva il codice originale in .X.
      bmi .Exit_ASC_SCR_Impossible

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_ASC_SCR_Exception

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_ASC_SCR:
      clc
      rts

    .Exit_ASC_SCR_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_ASC_SCR_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %10000000             ; 0-31    > 128-159 (inverso)
      !byte %00100000             ; 32-63   > 32-63
      !byte %01000000             ; 64-95   > 64-95
      !byte %00000000             ; 96-127  > 0-31

    .EXCEPTIONS:
      !byte $40, $00              ; 64 > 0 (@)
      !byte $5B, $1B              ; 91 > 27 ([)
      !byte $5C, $7F              ; 92 > 127 (\)
      !byte $5D, $1D              ; 93 > 29 (])
      !byte $5E, $1E              ; 94 > 30 (^)
      !byte $5F, $64              ; 95 > 100 (_)
      !byte $60, $6D              ; 96 > 109 (`)
      !byte $7B, $73              ; 123 > 115 ({)
      !byte $7C, $5D              ; 124 > 93 (|)
      !byte $7D, $6B              ; 125 > 107 (})
      !byte $7E, $40              ; 126 > 64 (~)
      !byte $7F, $66              ; 127 > 102 (DEL, trama)

    .EXCEPTIONS_IMPERFECT:

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: ASC_SCR_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica ASCII a 7 bit alla codifica
;               Codice Schermo, riconoscendo i codici di controllo. Come
;               ASC_SCR, ma i codici di controllo ASCII (da 0 a 31 e il DEL,
;               127) non hanno un equivalente in Codice Schermo, che non ha
;               codici di controllo: la conversione è impossibile.
;
;               Sono impossibili allo stesso modo i codici da 128 a 255, che non
;               sono ASCII a 7 bit. Il Carry a 0 dice che la conversione è
;               riuscita, con la sostituzione del glifo quando serve. Il Carry a
;               1 dice che è impossibile, con .A = $FF: nessun codice ASCII ha
;               $FF come equivalente.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica Codice Schermo
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile (.A = $FF)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ASC_SCR_C = 1) {
  !zone Asc_Scr_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    ASC_SCR_C:
      tax                         ; Salva il codice originale in .X.
      bmi .Exit_ASC_SCR_C_Impossible

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_ASC_SCR_C_Exception

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

      bmi .Exit_ASC_SCR_C_Impossible

    .Exit_ASC_SCR_C:
      clc
      rts

    .Exit_ASC_SCR_C_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_ASC_SCR_C_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %11100000             ; 0-31    impossibile
      !byte %00100000             ; 32-63   > 32-63
      !byte %01000000             ; 64-95   > 64-95
      !byte %00000000             ; 96-127  > 0-31

    .EXCEPTIONS:
      !byte $40, $00              ; 64 > 0 (@)
      !byte $5B, $1B              ; 91 > 27 ([)
      !byte $5C, $7F              ; 92 > 127 (\)
      !byte $5D, $1D              ; 93 > 29 (])
      !byte $5E, $1E              ; 94 > 30 (^)
      !byte $5F, $64              ; 95 > 100 (_)
      !byte $60, $6D              ; 96 > 109 (`)
      !byte $7B, $73              ; 123 > 115 ({)
      !byte $7C, $5D              ; 124 > 93 (|)
      !byte $7D, $6B              ; 125 > 107 (})
      !byte $7E, $40              ; 126 > 64 (~)

    .EXCEPTIONS_IMPERFECT:
      !byte $7F, $FF              ; 127 > impossibile

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: ASC_PET
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica ASCII a 7 bit alla codifica
;               PETSCII, senza produrre codici di controllo. La conversione è
;               "glifo per glifo", con i codici ASCII letti come li mostra il
;               set di caratteri #2: le lettere maiuscole (da 65 a 90) diventano
;               i codici da 193 a 218 e le minuscole (da 97 a 122) i codici da
;               65 a 90.
;
;               I caratteri ASCII che il Commodore non ha sono rappresentati da
;               caratteri grafici che somigliano all'originale e che sono uguali
;               nel set #1 e nel set #2: per esempio la barra verticale (124)
;               diventa il codice 221. Tra i codici duplicati di PETSCII la
;               routine produce sempre quelli dei blocchi originali (da 160 a
;               191 e da 192 a 223), mai i duplicati (da 96 a 127 e da 224 a
;               255).
;
;               I codici di controllo ASCII (da 0 a 31) diventano i glifi che
;               Codice Schermo ha con lo stesso codice (i codici da 64 a 95 in
;               PETSCII): il 28 diventa la sterlina e il 31 la freccia a
;               sinistra: PETSCII non ha caratteri inversi, quindi il Carry è a
;               1 e il carattere va stampato in modalità inversa. Il DEL (127)
;               diventa il codice 166, il glifo che somiglia a una
;               cancellazione, con il Carry a 0.
;
;               I codici da 128 a 255, che non sono ASCII a 7 bit, non hanno
;               equivalente: la conversione è impossibile, con il Carry a 1 e .A
;               = $FF. Il Carry a 1 ha dunque due significati, che si
;               distinguono con un test su .A: se vale $FF la conversione è
;               impossibile; altrimenti .A è un carattere da stampare in
;               modalità inversa (il codice originale in .X è minore di 32).
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
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
!if (__USE_ASC_PET = 1) {
  !zone Asc_Pet

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    ASC_PET:
      tax                         ; Salva il codice originale in .X.
      bmi .Exit_ASC_PET_Impossible

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_ASC_PET_Exception

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

      cpx #%00100000              ; Se il codice originale era minore di 32
      bcc .Exit_ASC_PET_Inverse   ; il glifo va stampato inverso.

    .Exit_ASC_PET:
      clc
      rts

    .Exit_ASC_PET_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_ASC_PET_Inverse:
      sec                         ; Carattere da stampare inverso.
      rts

    .Exit_ASC_PET_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %01000000             ; 0-31    > 64-95 (inverso)
      !byte %00100000             ; 32-63   > 32-63
      !byte %11000000             ; 64-95   > 192-223
      !byte %01000000             ; 96-127  > 64-95

    .EXCEPTIONS:
      !byte $40, $40              ; 64 > 64 (@)
      !byte $5B, $5B              ; 91 > 91 ([)
      !byte $5C, $BF              ; 92 > 191 (\)
      !byte $5D, $5D              ; 93 > 93 (])
      !byte $5E, $5E              ; 94 > 94 (^)
      !byte $5F, $A4              ; 95 > 164 (_)
      !byte $60, $AD              ; 96 > 173 (`)
      !byte $7B, $B3              ; 123 > 179 ({)
      !byte $7C, $DD              ; 124 > 221 (|)
      !byte $7D, $AB              ; 125 > 171 (})
      !byte $7E, $C0              ; 126 > 192 (~)
      !byte $7F, $A6              ; 127 > 166 (DEL, trama)

    .EXCEPTIONS_IMPERFECT:

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: ASC_PET_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica ASCII a 7 bit alla codifica
;               PETSCII, riconoscendo i codici di controllo. Come ASC_PET, ma i
;               codici di controllo ASCII da 0 a 31 restano codici di controllo
;               con lo stesso codice (la conversione è perfetta; il significato
;               dei controlli non viene convertito).
;
;               Il DEL (127) non ha un controllo equivalente in PETSCII: diventa
;               il codice 166, il glifo che somiglia a una cancellazione, ma
;               essendo un controllo che diventa stampabile la conversione è
;               imperfetta, con il Carry a 1. I codici da 128 a 255, che non
;               sono ASCII a 7 bit, sono impossibili: Carry a 1 e .A = $FF. Il
;               Carry a 1 si distingue quindi con un test su .A: $FF è
;               impossibile, 166 è il DEL.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;
; Output:
;   - .A (1 byte, CPU)       : Codice carattere in codifica PETSCII
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile (.A = $FF) o DEL
;                              convertito in carattere (.A = 166)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ASC_PET_C = 1) {
  !zone Asc_Pet_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS
    .PERFECT_SIZE   = .EXCEPTIONS_IMPERFECT-.EXCEPTIONS

    ASC_PET_C:
      tax                         ; Salva il codice originale in .X.
      bmi .Exit_ASC_PET_C_Impossible

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Exit_ASC_PET_C_Exception

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Exit_ASC_PET_C:
      clc
      rts

    .Exit_ASC_PET_C_Exception:
      cpy #.PERFECT_SIZE          ; Carry = 1 se l'eccezione è imperfetta.
      rts

    .Exit_ASC_PET_C_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %00000000             ; 0-31    > 0-31 (controlli)
      !byte %00100000             ; 32-63   > 32-63
      !byte %11000000             ; 64-95   > 192-223
      !byte %01000000             ; 96-127  > 64-95

    .EXCEPTIONS:
      !byte $40, $40              ; 64 > 64 (@)
      !byte $5B, $5B              ; 91 > 91 ([)
      !byte $5C, $BF              ; 92 > 191 (\)
      !byte $5D, $5D              ; 93 > 93 (])
      !byte $5E, $5E              ; 94 > 94 (^)
      !byte $5F, $A4              ; 95 > 164 (_)
      !byte $60, $AD              ; 96 > 173 (`)
      !byte $7B, $B3              ; 123 > 179 ({)
      !byte $7C, $DD              ; 124 > 221 (|)
      !byte $7D, $AB              ; 125 > 171 (})
      !byte $7E, $C0              ; 126 > 192 (~)

    .EXCEPTIONS_IMPERFECT:
      !byte $7F, $A6              ; 127 > 166 (DEL, trama)

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: ASC_ECM
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica ASCII a 7 bit alla pseudo-
;               codifica ECM, cioè i codici come si interpretano con il modo
;               Colore di Sfondo Esteso attivo, senza produrre codici di
;               controllo. La conversione separa le due informazioni: .A riceve
;               il codice del glifo, da 0 a 63, e il selettore del colore di
;               sfondo, da 0 a 3, va in __BG_COL. È il risultato di ASC_SCR
;               seguita da SCR_ECM: le tabelle hanno i codici schermo.
;
;               Il colore di sfondo segue le regole di PET_ECM: BGCOL0 per i
;               codici da 32 a 63, per le lettere minuscole e per @, [, ] e ^;
;               BGCOL1 per le lettere maiuscole e per i grafici che
;               sostituiscono i caratteri ASCII che il Commodore non ha (\, _,
;               `, {, |, }, ~ e il DEL); BGCOL2 per i codici di controllo da 0 a
;               31, che hanno il glifo inverso del carattere con lo stesso
;               codice di Codice Schermo.
;
;               I codici da 128 a 255, che non sono ASCII a 7 bit, non hanno
;               equivalente: la conversione è impossibile, con il Carry a 1 e .A
;               = $FF, e __BG_COL non viene modificato. Altrimenti la
;               conversione è sempre perfetta, con il Carry a 0.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;
; Output:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile (.A = $FF)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry), __BG_COL
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ASC_ECM = 1) {
  !zone Asc_Ecm

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS

    ASC_ECM:
      tax                         ; Salva il codice originale in .X.
      bmi .Exit_ASC_ECM_Impossible

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Split_Glyph_Background

      +m_Apply_Table .BLOCK_TABLE ; Codice regolare: sostituisce il blocco.

    .Split_Glyph_Background:
      tay                         ; Salva il codice schermo in .Y.
      asl a                       ; Porta i bit #7-#6 nelle posizioni #1-#0
      rol a                       ; con tre rotazioni a sinistra
      rol a                       ; attraverso il Carry.
      and #%00000011
      sta __BG_COL                ; Selettore del colore di sfondo.

      tya
      and #%00111111              ; Codice del glifo, da 0 a 63.

    .Exit_ASC_ECM:
      clc                         ; Nessuna informazione persa.
      rts

    .Exit_ASC_ECM_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %10000000             ; 0-31    > 128-159 (inverso)
      !byte %00100000             ; 32-63   > 32-63
      !byte %01000000             ; 64-95   > 64-95
      !byte %00000000             ; 96-127  > 0-31

    .EXCEPTIONS:
      !byte $40, $00              ; 64 > 0 (@)
      !byte $5B, $1B              ; 91 > 27 ([)
      !byte $5C, $7F              ; 92 > 127 (\)
      !byte $5D, $1D              ; 93 > 29 (])
      !byte $5E, $1E              ; 94 > 30 (^)
      !byte $5F, $64              ; 95 > 100 (_)
      !byte $60, $6D              ; 96 > 109 (`)
      !byte $7B, $73              ; 123 > 115 ({)
      !byte $7C, $5D              ; 124 > 93 (|)
      !byte $7D, $6B              ; 125 > 107 (})
      !byte $7E, $40              ; 126 > 64 (~)
      !byte $7F, $66              ; 127 > 102 (DEL, trama)

    .EXCEPTIONS_END:

  !zone
}

; ==============================================================================
; SUBROUTINE: ASC_ECM_C
; ------------------------------------------------------------------------------
; Descrizione:  Converte un codice dalla codifica ASCII a 7 bit alla pseudo-
;               codifica ECM, riconoscendo i codici di controllo. Come ASC_ECM,
;               ma ECM, come Codice Schermo, non ha codici di controllo: i
;               codici di controllo ASCII (da 0 a 31 e il DEL, 127) sono
;               impossibili, come lo sono i codici da 128 a 255, che non sono
;               ASCII a 7 bit.
;
;               Se la conversione è impossibile il Carry è a 1, .A vale $FF e
;               __BG_COL non viene modificato. Altrimenti il Carry è a 0.
;
; Input:
;   - .A (1 byte, CPU)       : Codice carattere in codifica ASCII a 7 bit
;
; Output:
;   - .A (1 byte, CPU)       : Codice del glifo in codifica ECM (da 0 a 63)
;                              ($FF se la conversione è impossibile)
;   - .X (1 byte, CPU)       : Codice carattere originale
;   - __BG_COL (1 byte, ZP)  : Selettore del colore di sfondo (da 0 a 3)
;   - Flag Carry (1 bit, .P) : 0 = conversione riuscita; 1 = conversione
;                              impossibile (.A = $FF)
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, Zero, Carry), __BG_COL
; Dipendenze Esterne:   <io/chars_common.asm>
; ==============================================================================
!if (__USE_ASC_ECM_C = 1) {
  !zone Asc_Ecm_C

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS

    ASC_ECM_C:
      tax                         ; Salva il codice originale in .X.
      bmi .Exit_ASC_ECM_C_Impossible

      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Check_Impossible

      +m_Apply_Table .BLOCK_TABLE ; Sostituisce il blocco ($E0: inesistente).

    .Check_Impossible:
      bmi .Exit_ASC_ECM_C_Impossible

      tay                         ; Salva il codice schermo in .Y.
      asl a                       ; Porta i bit #7-#6 nelle posizioni #1-#0
      rol a                       ; con tre rotazioni a sinistra
      rol a                       ; attraverso il Carry.
      and #%00000011
      sta __BG_COL                ; Selettore del colore di sfondo.

      tya
      and #%00111111              ; Codice del glifo, da 0 a 63.

    .Exit_ASC_ECM_C:
      clc                         ; Nessuna informazione persa.
      rts

    .Exit_ASC_ECM_C_Impossible:
      lda #$FF                    ; Conversione impossibile: .A = $FF
      sec                         ; e Carry = 1.
      rts

    .BLOCK_TABLE:
      !byte %11100000             ; 0-31    impossibile
      !byte %00100000             ; 32-63   > 32-63
      !byte %01000000             ; 64-95   > 64-95
      !byte %00000000             ; 96-127  > 0-31

    .EXCEPTIONS:
      !byte $40, $00              ; 64 > 0 (@)
      !byte $5B, $1B              ; 91 > 27 ([)
      !byte $5C, $7F              ; 92 > 127 (\)
      !byte $5D, $1D              ; 93 > 29 (])
      !byte $5E, $1E              ; 94 > 30 (^)
      !byte $5F, $64              ; 95 > 100 (_)
      !byte $60, $6D              ; 96 > 109 (`)
      !byte $7B, $73              ; 123 > 115 ({)
      !byte $7C, $5D              ; 124 > 93 (|)
      !byte $7D, $6B              ; 125 > 107 (})
      !byte $7E, $40              ; 126 > 64 (~)
      !byte $7F, $FF              ; 127 > impossibile

    .EXCEPTIONS_END:

  !zone
}
