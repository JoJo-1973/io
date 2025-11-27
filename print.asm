; Routine per l'output di caratteri e stringhe



!macro PlotChar {
!zone PlotChar
; Titolo:                 ROUTINE: Memorizza un carattere nella memoria schermo (PLOTCHAR) o cambiane il colore (COLCHAR)
; Nome:                   PLOTCHAR / COLCHAR
; Descrizione:            Memorizza un carattere dato il suo codice schermo (PLOTCHAR) o cambiane il colore (COLCHAR) alle coordinate specificate.
;                         Se l'Extended Color Mode è attivo i codici schermo 64-255 vengono mappati all'intervallo 0-63: ed il colore di sfondo
;                         viene scelto scrivendo un valore nell'intervallo 0-3 nel registro in pagina zero BGCOL.
; Parametri di ingresso:  .A: Codice schermo del carattere da visualizzare (PLOTCHAR) o colore (COLCHAR)
;                         .X: Colonna della cella della memoria schermo
;                         .Y: Riga della cella della memoria schermo
; Parametri di uscita:    ---
; Alterazioni registri:   ---
; Alterazioni pag. zero:  ZP_5, BGCOL
; Dipendenze esterne:     symbols.asm, standard.asm, kernal.asm, vic_ii.asm, petscii.asm
PLOTCHAR:
  sta ._TEMPA
  +PushAXY

  lda HIBASE                    ; Inizializza il puntatore alla memoria schermo
  sta ZP_5+1
  bit SCROLY                    ; Controlla se il modo colore esteso è attivo
  bvc .CalcCell

  lda BGCOL
  ror a
  ror a
  ror a
  and #%11000000
  sta ._ECM_MASK

  lda ._TEMPA                   ; Riprendi il codice schermo dallo stack
  and #%00111111                ; cancella i 2 bit più significativi
  ora ._ECM_MASK                ; ed applica i bit di selezione del registro di colore
  sta ._TEMPA
  +Bra .CalcCell                ; poi passa al calcolo della cella indicata da .X e .Y

COLCHAR:
  sta ._TEMPA
  +PushAXY
  lda #>COLRAM                  ; Inizializza il puntatore alla memoria colore
  sta ZP_5+1

.CalcCell:
  clc                           ; Somma il valore della colonna selezionata al byte basso dell'offset della posizione iniziale della riga scelta
  txa
  adc .ROW_OFFSET_LO,y
  sta ZP_5

  lda .ROW_OFFSET_HI,y          ; Fai la stessa cosa col byte alto, che viene sommato
  adc ZP_5+1                    ; assieme al Carry generato dalla somma precedente
  sta ZP_5+1                    ; al valore già presente in ZP_5+1

  lda ._TEMPA                   ; ed infine recupera il valore del codice schermo (o del colore)
  ldy #0                        ; e scrivilo in memoria alla posizione calcolata
  sta (ZP_5),y
  +PullAXY

  rts

._ECM_MASK        !byte 0
._TEMPA           !byte 0
._TEMPY           !byte 0

.ROW_OFFSET_LO:                 ; Byte basso degli offset della posizione iniziale di ciascuna riga dello schermo
  !byte $00,$28,$50,$78,$a0,$c8,$f0,$18
  !byte $40,$68,$90,$b8,$e0,$08,$30,$58
  !byte $80,$a8,$d0,$f8,$20,$48,$70,$98
  !byte $c0

.ROW_OFFSET_HI:                 ; Byte alto degli offset della posizione iniziale di ciascuna riga dello schermo
  !byte $00,$00,$00,$00,$00,$00,$00,$01
  !byte $01,$01,$01,$01,$01,$02,$02,$02
  !byte $02,$02,$02,$02,$03,$03,$03,$03
  !byte $03
  !zone
}
; Titolo:                 MACRO: Stampa una tabella di messaggi.
; Nome:                   Print_Msg
; Descrizione:            Stampa i messaggi di testo contenuti in una tabella in memoria.
;                         Un puntatore in pagina zero viene caricato con l'inizio della tabella e l'indirizzo del puntatore viene caricato in .A.
;                         Ciascun messaggio della tabella ha il seguente formato:
;
;                               !text yy,xx,"testo",0
;
;                         dove:
;                           yy: Riga alla quale stampare il messaggio
;                           xx: Colonna alla quale stampare il messaggio
;
;                         Se yyxx=$FFxx il messaggio successivo viene stampato alla posizione corrente del cursore.
;                            yyxx=$FFFF indica la fine della tabella.
;
;                         I messaggi vengono stampati uno per chiamata della routine e non vi sono limitazioni alla lunghezza.
;                         Non è necessario aggiornare il puntatore in pagina zero tra una chiamata e l'altra, ma solo .A
;                         Giunti alla fine della tabella ulteriori chiamate non avranno effetto.
; Parametri di ingresso:  .A: Indirizzo del puntatore in pagina zero che contiene la posizione della tabella di messaggi
; Parametri di uscita:    C=0:  La tabella contiene ancora messaggi da stampare
;                         C=1:  La tabella è terminata
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     symbols.asm, standard.asm, kernal.asm, vic_ii.asm, petscii.asm
!macro Print_Msg {
  !zone Print_Msg
  !ifndef __PUTCHAR {
    !set __PUTCHAR = CHROUT
  }
  PRINT_MSG:
    tax                         ; Trasferisci l'indirizzo del puntatore in .X.

    lda (0,x)                   ; Carica il primo byte
    pha                         ; e salvalo sullo stack.
    cmp #$FF                    ; Se è diverso da $FF allora è una coordinata.
    bne .Coord

    inc 0,x                     ; Esamina il byte successivo:
    bne .FetchChar
    inc 1,x

  .FetchChar:
    lda (0,x)
    cmp #$FF                    ; è il marcatore di fine messaggio?
    bne .PrintChars             ; No, allora stampa i caratteri che seguono nalla posizione corrente del cursore.

  .Exit_PRINT_MSG_EndTable:
    pla                         ; Pulisci lo stack e riporta il puntatore all'inizio del marcatore di fine tabella
    lda 0,x                     ; così che successive chiamate alla routine non abbiano effetto.
    bne .GetOut
    dec 1,x

  .GetOut:
    dec 0,x
    sec                         ; Setta C per segnalare la fine della tabella.
    rts

  .Coord:
    inc 0,x                     ; Recupera il byte con il numero di colonna alla quale muovere il cursore.
    bne .FetchColumn
    inc 1,x

  .FetchColumn:
    stx ._TEMPX                 ; Salva .X.
    lda (0,x)
    tay                         ; Il valore appena letto è la riga dove muovere il cursore.
    pla                         ; Recupera la colonna dallo stack
    tax

    clc                         ; e posiziona il cursore.
    jsr PLOT

    ldx ._TEMPX                 ; Ora recupera .X
    +Skip1                      ; e salta la prossima istruzione.

  .PrintChars:
    pla                         ; Pulisci lo stack.

  .Loop_PrintChar:
    inc 0,x                     ; Punta al carattere da stampare
    bne .FetchNext
    inc 1,x

  .FetchNext:
    lda (0,x)
    beq .Exit_PRINTMSG_EndMsg   ; ma se vale $00 finisci.
    jsr __PUTCHAR               ; In caso contrario stampalo.
    +Bra .Loop_PrintChar

  .Exit_PRINTMSG_EndMsg:
    inc 0,x
    bne .Finish
    inc 1,x

  .Finish:
    clc                         ; Pulisci C per indicare che ci sono ancora messaggi in tabella
    rts

  ._TEMPX           !byte 0
  !zone
}

; Titolo:                 MACRO: Stampa un singolo messaggio estratto da una tabella.
; Nome:                   Print_Nth
; Descrizione:            Stampa un messaggio di testo contenuto in una tabella in memoria, dato un indice.
;                         Un puntatore in pagina zero viene caricato con l'inizio della tabella e l'indirizzo del puntatore viene caricato in .A:
;                         Ciascun messaggio della tabella ha il seguente formato:
;
;                               !text yy,xx,"testo",0
;
;                         dove:
;                           yy: Riga alla quale stampare il messaggio
;                           xx: Colonna alla quale stampare il messaggio
;
;                         Se yyxx=$FFxx il messaggio successivo viene stampato alla posizione corrente del cursore.
;                            yyxx=$FFFF indica la fine della tabella.
;
;                         Il messaggio il cui indice è contenuto in .Y viene selezionato e stampato.
;                         Il primo messaggio della tabella ha indice 0.
; Parametri di ingresso:  .A: Indirizzo del puntatore in pagina zero che contiene la posizione della tabella di messaggi
;                         .Y: Numero del messaggio da stampare
; Parametri di uscita:    C=0:  Nessun errore
;                         C=1:  L'indice è superiore al numero di messaggi contenuti nella tabella
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     symbols.asm, standard.asm, kernal.asm, vic_ii.asm, petscii.asm
!macro Print_Nth
  !zone Print_Nth
  !ifndef __PUTCHAR {
    !set __PUTCHAR = CHROUT
  }
  PRINT_NTH:
    tax                         ; Sposta l'indirizzo del puntatore in .X
    lda 0,x                     ; e salva l'indirizzo puntato sullo stack.
    pha
    lda 1,x
    pha

    cpy #0                      ; Se .Y vale 0 stampa subito ed esci.
    beq .Print

  .Loop_Scan_Table:
    lda (0,x)                   ; Leggi il primo byte
    inc 0,x                     ; ed incrementa il puntatore al byte precedente il corpo del messaggio.
    bne .Check_2nd_Byte
    inc 1,x

  .Check_2nd_Byte:
    and (0,x)                   ; Fai AND con il secondo byte:
    cmp #$FF                    ; se il risultato è $FF vuol dire che entrambi erano $FF
    beq .Exit_PRINT_NTH_Too_Large ; quindi siamo alla fine della tabella quindi esci con C=1 per segnalare l'errore.


  .Loop_Scan_Null:
    inc 0,x                     ; Incrementa il puntatore al primo carattere del messaggio vero e proprio
    bne .Read_Char
    inc 1,x

  .Read_Char:
    lda (0,x)                   ; e continua a leggere caratteri finché non trovi uno 0.
    bne .Loop_Scan_Null

    inc 0,x                     ; Una volta trovatolo, posiziona il puntatore all'inizio del messaggio successivo
    bne .Next_Scan_Table
    inc 1,x

  .Next_Scan_Table:
    dey                         ; e decrementa il contatore dei messaggi:
    bne .Loop_Scan_Table        ; quando diventa 0 siamo giunti nal messaggio desiderato

  .Print:
    txa                         ; Sposta l'indirizzo del puntatore in .A
    jsr PRINT_MSG               ; poi stampa il messaggio ed esci
    +Skip1

  .Exit_PRINT_NTH_Too_Large:
    sec

  .Exit_PRINT_NTH:
    pla                         ; Ripristina il contenuto originario del puntatore.
    sta 1,x
    pla
    sta 0,x

    rts
  !zone
}

; Titolo:                 MACRO: Stampa un messaggio puntato da .A /.Y.
; Nome:                   Print_Raw
; Descrizione:            Stampa un messaggio di testo la cui definizione è puntata da .A / .Y.
;                         Questa routine può sostituire la routine del BASIC STROUT in quanto non altera FAC o ARG.
;                         Il messaggio da stampare deve terminare con $00 e non supporta i due byte per posizionare
;                         il cursore come le altre routines.
; Parametri di ingresso:  .A, .Y
; Parametri di uscita:    ---
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ZP_5
; Dipendenze esterne:     symbols.asm, standard.asm, kernal.asm, vic_ii.asm, petscii.asm
!macro Print_Raw {
  !zone Print_Raw
  !ifndef __PUTCHAR {
    !set __PUTCHAR = CHROUT
  }
  PRINT_RAW:
    sta ZP_5                    ; Inizializza il puntatore al messaggio
    sty ZP_5+1

    ldy #0

 .Loop_PrintChar:
    lda (ZP_5),y                ; Carica il prossimo carattere da stampare in .A
    beq .Exit_PRINT_RAW         ; ed esci se $00

    jsr __PUTCHAR               ; altrimenti stampalo ed itera.
    +Inc16 ZP_5
    +Bra .Loop_PrintChar

  .Exit_PRINT_RAW:
    rts
  !zone
}

; Titolo:                 MACRO: Stampa un messaggio immediatamente seguente la chiamata.
; Nome:                   Print_Imm
; Descrizione:            Stampa un messaggio di testo la cui definizione segue immediatamente la chiamata alla routine.
;                         Il messaggio ha il seguente formato:
;
;                               !text yy,xx,"testo",0
;
;                         dove:
;                           yy: Riga alla quale stampare il messaggio
;                           xx: Colonna alla quale stampare il messaggio
;
;                         Se yyxx=$FFxx il messaggio successivo viene stampato alla posizione corrente del cursore.
; Parametri di ingresso:  ---
; Parametri di uscita:    ---
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ZP_5
; Dipendenze esterne:     symbols.asm, standard.asm, kernal.asm, vic_ii.asm, petscii.asm
!macro Print_Imm {
  !zone Print_Imm
  !ifndef __PUTCHAR {
    !set __PUTCHAR = CHROUT
  }
  PRINT_IMM:
    pla                         ; Rimuovi l'indirizzo di ritorno dallo stack e memorizzalo in ZP_5.
    sta ZP_5
    pla
    sta ZP_5+1

    ldy #0
    +Inc16 ZP_5                 ; Recupera la riga alla quale posizionare il cursore.
    lda (ZP_5),y
    cmp #$FF                    ; E' il marcatore di "posizione attuale"?
    bne .Coord                  ; No, estrai le coordinate

    +Inc16 ZP_5                 ; altrimenti scarta il byte successivo.
    +Bra .PrintChar

  .Coord:
    pha
    iny                         ; Recupera anche la colonna.
    lda (ZP_5),y
    tay
    pla                         ; Sposta il valore della riga in .X
    tax
    clc                         ; e posiziona il cursore alle coordinate indicate.
    jsr PLOT
    +Inc16 ZP_5

  .PrintChar:
    ldy #0

  .Loop_PrintChar:
    +Inc16 ZP_5
    lda (ZP_5),y
    beq .Exit_PRINT_IMM
    jsr __PUTCHAR
    +Bra .Loop_PrintChar

  .Exit_PRINT_IMM:
    lda ZP_5+1                  ; Rimetti l'indirizzo di ritorno sullo stack ed esci.
    pha
    lda ZP_5
    pha

    rts
  !zone
}

; Titolo:                 MACRO: Invia un carattere sul canale corrente gestendo la modalità Colore di Sfondo Esteso (ECM).
; Nome:                   Put_ECM_Char
; Descrizione:            Il carattere contenuto in .A viene inviato al canale corrente (solitamente lo schermo).
;                         I codici PETSCII 0-31 e 128-159 vengono sempre inviati così come sono, con l'eccezione di {RVS} e {OFF}
;                         (rispettivamente codice 18 e 146) perché interferirebbero col funzionamento dei codici 1-4 (vedi sotto).
;                         Per lo stesso motivo i codici PETSCII 32-127 e 160-255 vengono mappati all'intervallo 32-95.
;                         I codici PETSCII 1-4 vengono assumono un nuovo significato: essi selezionano il colore di sfondo da utilizzare:
;                         1 = BGCOL0, 2 = BGCOL1, 3 = BGCOL2 e 4 = BGCOL3.
;
;                         ATTENZIONE: la macro non contiene un "rts" finale!
; Parametri di ingresso:  .A: Codice PETSCII da inviare al canale di output
; Parametri di uscita:    ---
; Alterazioni registri:   ---
; Alterazioni pag. zero:  TEMP_1, RVS
; Dipendenze esterne:     symbols.asm, standard.asm, kernal.asm, vic_ii.asm, petscii.asm

!macro Put_ECM_Char {
  !zone Put_ECM_Char
  PUT_ECM_CHAR:
    sta ._TEMPA                 ; Preserva il contenuto dei registri.
    stx ._TEMPX
    sty ._TEMPY

    tax                         ; Salva una copia del codice PETSCII originale
    and #%01111111              ; ed azzera il bit più significativo.

  .CheckInvalid:
    cpx #0                      ; Se il codice PETSCII è 0, esci senza stampare.
    beq .Exit_PUT_ECM_CHAR_Silent

    cpx #5                      ; Se non è uno dei codici PETSCII speciali per il cambio del colore di sfondo (1-4), passa oltre
    bcs .CheckControl           ; altrimenti convertilo nell'intervallo 0-3 e salvalo in .BGCOL, poi finisci senza passare dall'output.
    dex
    stx BGCOL
    jmp .Exit_PUT_ECM_CHAR_Silent

  .CheckControl:
    cmp #18                     ; Se il codice PETSCII è {RVS} oppure {OFF}, esci senza stampare.
    beq .Exit_PUT_ECM_CHAR_Silent

    cmp #32                     ; Se il codice PETSCII è un rimanente codice di controllo stampalo ed esci.
    bcc .Output

  .Convert:
    cpx #255                    ; Il codice PETSCII 255 va trattato a parte:
    bne .Normalize
    lda #94                     ; il suo valore normalizzato è 94.
    bne .ApplyBGCOL

  .Normalize:
    txa                         ; Recupera il codice PETSCII originale.
    lsr a                       ; Qualunque codice che non sia stato intercettato in precedenza
    lsr a                       ; viene normalizzato sostituendo i 3 bit più significativi
    lsr a                       ; secondo le definizioni date dalla tabella .NORM_TABLE.
    lsr a                       ; I 3 bit più significativi vengono trasformati in un indice
    lsr a                       ; compreso tra 0 e 7.

    tay                         ; Sposta l'indice in .Y,
    txa                         ; recupera .A
    and #%00011111              ; e sostituisci i 3 bit più significativi.
    ora .NORM_TABLE,y

  .ApplyBGCOL:
    tax                         ; Salva una copia di .A.
    lda #0                      ; Disattiva la modalità reverse.
    sta RVS

    lda BGCOL                   ; Carica il registro colore in .A
    cmp #2                      ; Se è > 1 allora attiva la modalità reverse.
    bcc .Check_Shift
    inc RVS

  .Check_Shift:
    and #%00000001              ; Se il registro colore è pari allora stampa il codice PETSCII
    beq .Output
    txa                         ; altrimenti setta il bit più significativo prima di stamparlo.
    ora #%10000000
    +Skip1

  .Output:
    txa
    jsr CHROUT

  .Exit_PUT_ECM_CHAR_Silent:
    lda ._TEMPA                 ; Ripristina il contenuto dei registri
    ldx ._TEMPX
    ldy ._TEMPY

    +Bra .Skip_Table            ; Salta oltre le tabella dei dati al codice che segue la macro:
                                ; in tal modo è possibile costruire una routine __PUTCHAR
                                ; concatenando questa macro con altro codice.
                                ; Ad esempio:
                                ;
                                ; __PUTCHAR:
                                ;   +PUT_ECM_CHAR
                                ;   lda #29
                                ;   jsr CHROUT
                                ;   rts

                                ; definisce una routine di stampa a doppia spaziatura.

  .NORM_TABLE:
    !byte %00000000             ; 0-31    > 0-31    %000 > %000
    !byte %00100000             ; 32-63   > 32-63   %001 > %001
    !byte %01000000             ; 64-95   > 64-95   %010 > %010
    !byte %01000000             ; 96-127  > 64-95   %011 > %010
    !byte %10000000             ; 128-159 > 128-159 %100 > %100
    !byte %00100000             ; 160-191 > 32-63   %101 > %001
    !byte %01000000             ; 192-223 > 64-95   %110 > %010
    !byte %00100000             ; 224-255 > 32-63   %111 > %001

  ._TEMPA           !byte 0
  ._TEMPX           !byte 0
  ._TEMPY           !byte 0

  .Skip_Table:
  !zone
}
