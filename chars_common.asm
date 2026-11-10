; ==============================================================================
; FILE:           chars_common.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Macro comuni alle routine di transcodifica dei caratteri
;                 (sotto-modulo di chars.asm): la ricerca di un codice nella
;                 tabella delle eccezioni e la sostituzione dei tre bit più
;                 significativi del codice con quelli della tabella dei blocchi.
; CONTENUTO:      m_Scan_Exceptions   Cerca nella tabella delle eccezioni
;                 m_Apply_Table       Sostituisce i 3 bit alti del codice
; DIPENDENZE:     Nessuna
; REQUISITI ZP:   Nessuno
; ==============================================================================

; ==============================================================================
; MACRO: m_Scan_Exceptions
; ------------------------------------------------------------------------------
; Descrizione:  Cerca il codice in .A nella tabella delle eccezioni. La tabella
;               è formata da coppie di byte (codice sorgente, codice
;               destinazione), una coppia per ogni eccezione, e la ricerca va
;               dall'ultima coppia alla prima.
;
;               Se trova il codice, carica in .A il codice di destinazione e
;               salta a .found_, con .Y che contiene la posizione della coppia
;               nella tabella (0 per la prima, 2 per la seconda, e così via). Se
;               non lo trova, prosegue con l'istruzione che segue la macro, con
;               .A invariato.
;
;               La tabella non può essere vuota e può contenere al massimo 65
;               coppie (130 byte).
;
; Input:
;   - .A (1 byte, CPU)         : Codice sorgente da cercare
;   - .table_ (2 byte, Macro)  : Indirizzo della tabella delle eccezioni
;   - .size_ (1 byte, Macro)   : Dimensione della tabella in byte (2 per
;                                coppia), da 2 a 130
;   - .found_ (2 byte, Macro)  : Indirizzo a cui saltare se il codice è nella
;                                tabella
;
; Output:
;   - .A (1 byte, CPU)         : Codice destinazione se trovato, altrimenti
;                                invariato
;   - .Y (1 byte, CPU)         : Posizione della coppia trovata. Indefinito se
;                                il codice non è nella tabella
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   Nessuna
; ==============================================================================
!macro m_Scan_Exceptions .table_, .size_, .found_ {
    ldy #.size_-2               ; FOR (Inizializzazione)

  .Loop_Scan_Table:
    cmp .table_,y               ; FOR (Corpo)
    bne .Next_Scan_Table

    lda .table_+1,y             ; Trovato: carica il codice destinazione.
    jmp .found_

  .Next_Scan_Table:
    dey                         ; NEXT: passa alla coppia precedente.
    dey
    bpl .Loop_Scan_Table        ; NEXT: finché .Y non diventa negativo.
}

; ==============================================================================
; MACRO: m_Apply_Table
; ------------------------------------------------------------------------------
; Descrizione:  Sostituisce i tre bit più significativi del codice (il suo
;               blocco, da 0 a 7) con quelli della tabella dei blocchi e lascia
;               invariati i cinque bit meno significativi.
;
;               La tabella ha 8 byte, uno per blocco: in ognuno contano solo i
;               tre bit più significativi, e gli altri cinque devono essere
;               zero.
;
; Input:
;   - .A (1 byte, CPU)         : Codice da convertire
;   - .X (1 byte, CPU)         : Copia del codice da convertire
;   - .table_ (2 byte, Macro)  : Indirizzo della tabella dei blocchi
;
; Output:
;   - .A (1 byte, CPU)         : Codice convertito
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .Y, .P (Negative, Zero, Carry)
; Dipendenze Esterne:   Nessuna
; ==============================================================================
!macro m_Apply_Table .table_ {
    lsr a                       ; Porta i bit #7-#5 nelle posizioni #2-#0:
    lsr a                       ; il blocco, da 0 a 7, diventa l'indice.
    lsr a
    lsr a
    lsr a
    tay

    txa                         ; Riprende il codice originale.
    and #%00011111              ; Tiene i bit #4-#0
    ora .table_,y               ; e sostituisce i bit #7-#5 con quelli nuovi.
}
