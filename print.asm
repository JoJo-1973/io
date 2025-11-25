; Routine per l'output di caratteri e stringhe

!zone PrintChar
; Titolo:                 ROUTINE: Stampa un carattere sul canale corrente
; Nome:                   PRINTCHAR
; Descrizione:            Il carattere contenuto in .A viene inviato al canale corrente (solitamente lo schermo).
;                         I codici PETSCII 0-31 e 128-159 vengono sempre inviati così come sono
;                         Se l'Extended Color Mode è attivo i codici PETSCII 32-127 e 160-255 vengono mappati all'intervallo 32-95.
;                         I codici PETSCII 1-4 vengono assumono un nuovo significato: cambiano il colore di sfondo dat utilizzare qualora l'ECM sia attivo
; Parametri di ingresso:  .A: Codice PETSCII da inviare al canale di output
; Parametri di uscita:    ---
; Alterazioni registri:   .A
; Alterazioni pag. zero:  TEMP_1, RVS
; Dipendenze esterne:     symbols.asm, standard.asm, kernal.asm, vic_ii.asm, petscii.asm
PRINTCHAR:
  php
  stx ._TEMPX
  bit SCROLY                    ; Controlla se l'ECM è attivo oppure no
  bvc .Output                   ; Se no, vai subito alla stampa ed esci

.CheckNull:
  ora #0                        ; Resetta i flag, poi se il codice PETSCII è 0, passa all'output
  beq .Output

.CheckBGCodes:
  cmp #5                        ; Se non è uno dei codici PETSCII speciali per il cambio del colore di sfondo (1-4), passa oltre
  bcs .Convert                  ; altrimenti convertilo nell'intervallo 0-3 e salvalo in .BGCOL, poi finisci senza passare dall'output
  sta .BGCOL
  dec .BGCOL
  jmp .Finish

.Convert:
  tax                           ; Salva una copia di .A
  and #%01000000                ; Controlla il bit 6
  beq .CheckHiRange             ; Se è 0 passa oltre
  txa                           ; altrimenti recupera .A ed azzera il bit 5
  and #%11011111
  +Skip1                        ; e salta la prossima istruzione

.CheckHiRange:
  txa                           ; Recupera .A
  cmp #160                      ; Se il codice PETSCII è maggiore o uguale a 160 azzera il bit 7
  bcc .Apply128
  and #%01111111

.Apply128:
  ror .BGCOL                    ; Controlla se al codice carattere va aggiunto 128
  bcc .ApplyRVS
  ora #%10000000

.ApplyRVS:
  ror .BGCOL                    ; L'informazione riguardo la modalità RVS è contenuta nel bit 1 di .BGCOL
  bcc .ResetBGCOL
  ldx #$FF
  +Skip2

.ResetBGCOL:
  ldx #0
  stx RVS
  rol .BGCOL                    ; Rimetti a posto .BGCOL
  rol .BGCOL

.Output:
  jsr CHROUT

.Finish:
  ldx ._TEMPX
  plp
  rts

.BGCOL            = TEMP_1
._TEMPX           !byte 0


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

!zone PrintMsg
; Titolo:                 ROUTINE: Stampa una serie di messaggi
; Nome:                   PRINTMSG
; Descrizione:            Stampa i messaggi di testo contenuti in una tabella in memoria.
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
;                         I messaggi vengono stampati uno per chiamata della routine e non vi sono limitazioni alla lunghezza.
;                         Non è necessario aggiornare il puntatore in pagina zero tra una chiamata e l'altra, ma solo .A
;                         Giunti alla fine della tabella ulteriori chiamate non avranno effetto.
; Parametri di ingresso:  .A: Indirizzo del puntatore in pagina zero che contiene la posizione della tabella di messaggi
; Parametri di uscita:    C=0:  La tabella contiene ancora messaggi da stampare
;                         C=1:  La tabella è terminata
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     symbols.asm, standard.asm, kernal.asm, vic_ii.asm, petscii.asm
PRINTMSG:
  tax                           ; Trasferisci l'indirizzo del puntatore in .X

  lda (0,x)                     ; Carica il primo byte
  pha                           ; e salvalo sullo stack
  cmp #$FF                      ; Se è diverso da $FF allora è una coordinata
  bne .Coord

  inc 0,x                       ; Esamina il successivo
  bne .FetchChar
  inc 1,x

.FetchChar:
  lda (0,x)
  cmp #$FF                      ; E' il marcatore di fine messaggio?
  bne .PrintChars               ; No, allora stampa i caratteri che seguono nalla posizione corrente del cursore

.Exit_PRINTMSG_EoT:
  pla                           ; Pulisci lo stack e riporta il puntatore all'inizio del marcatore di fine tabella
  lda 0,x                       ; così che successive chiamate alla routine non avranno effetto
  bne .GetOut
  dec 1,x

.GetOut:
  dec 0,x
  sec                           ; Setta C per segnalare la fine della tabella
  rts

.Coord:
  inc 0,x                       ; Recupera il byte con il numero di colonna alla quale muovere il cursore
  bne .FetchColumn
  inc 1,x

.FetchColumn:
  stx ._TEMPX                   ; Salva .X
  lda (0,x)
  tay                           ; Il valore appena letto è la riga dove muovere il cursore
  pla                           ; Recupera la colonna
  tax
  clc                           ; e sposta il cursore
  jsr PLOT

  ldx ._TEMPX                   ; ora recupera .X
  +Skip1                        ; e salta la prossima istruzione

.PrintChars:
  pla                           ; Pulisci lo stack

.Loop_Print:
  inc 0,x                       ; Punta al carattere da stampare
  bne .FetchNext
  inc 1,x

.FetchNext:
  lda (0,x)
  beq .Exit_PRINTMSG_EoM        ; ma se vale 0 finisci
  jsr __PUTCHAR                 ; in caso contrario stampalo
  +Bra .Loop_Print

.Exit_PRINTMSG_EoM:
  inc 0,x
  bne .Finish
  inc 1,x

.Finish:
  clc                           ; Pulisci C per indicare che ci sono ancora messaggi in tabella

  rts

._TEMPX           !byte 0

!zone PrImm
; Titolo:                 ROUTINE: Stampa un messaggio immerso nel codice
; Nome:                   PRIMM
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
PRIMM:
  pla                           ; Rimuovi l'indirizzo di ritorno dallo stack e memorizzalo in ZP_5
  sta ZP_5
  pla
  sta ZP_5+1

  ldy #0
  +Inc16 ZP_5                   ; Recupera la riga alla quale posizionare il cursore
  lda (ZP_5),y
  cmp #$FF                      ; E' il marcatore di "posizione attuale"?
  bne .Coord                    ; No, estrai le coordinate
  +Inc16 ZP_5                   ; altrimenti scarta il byte successivo
  +Bra .PrintChar

.Coord:
  pha
  iny                           ; Recupera anche la colonna
  lda (ZP_5),y
  tay
  pla                           ; Sposta il valore della riga in .X
  tax
  clc                           ; e posiziona il cursore
  jsr PLOT
  +Inc16 ZP_5

.PrintChar:
  ldy #0

.Loop_PrintChar:
  +Inc16 ZP_5
  lda (ZP_5),y
  beq .Finish
  jsr __PUTCHAR
  +Bra .Loop_PrintChar

.Finish:
  lda ZP_5+1                    ; Rimetti l'indirizzo di ritorno sullo stack ed esci
  pha
  lda ZP_5
  pha

  rts

!zone Print_Nth
; Titolo:                 ROUTINE: Stampa un singolo messaggio appartenente ad una serie.
; Nome:                   PRINT_NTH
; Descrizione:            Stampa un messaggio di testo contenuto in una tabella in memoria dato un indice.
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
PRINT_NTH:
  tax                           ; Sposta l'indirizzo del puntatore in .X
  cpy #0                        ; Se .Y vale 0 stampa subito ed esci
  beq .Print

.Loop_Scan_Table:
  lda (0,x)                     ; Leggi il primo byte
  inc 0,x                       ; Altrimenti incrementa il puntatore al byte precedente il corpo del messaggio
  bne .Check_Next
  inc 1,x

.Check_Next:
  and (0,x)                     ; fai AND con il secondo
  cmp #$FF                      ; Se il risultato è $FF vuol dire che entrambi erano $FF
  beq .Exit_PRINT_NTH_Too_Large ; quindi siamo alla fine della tabella ed esci con C=1 per segnalare l'errore


.Loop_Scan_Null:
  inc 0,x                       ; Punta al primo carattere del messaggio
  bne .Read_Char
  inc 1,x

.Read_Char:
  lda (0,x)                     ; e continua a leggere caratteri finché non trovi uno 0
  bne .Loop_Scan_Null

  inc 0,x                       ; Una volta trovato posiziona il puntatore all'inizio del messaggio successivo
  bne .Next_Msg
  inc 1,x

.Next_Msg:
  dey                           ; Decrementa il contatore dei messaggi:
  bne .Loop_Scan_Table          ; quando diventa 0 siamo giunti nal messaggio desiderato

.Print:
  txa                           ; Sposta l'indirizzo del puntatore in .A
  jmp PRINTMSG                  ; poi stampa il messaggio ed esci
  +Bra .Exit_PRINT_NTH

.Exit_PRINT_NTH_Too_Large:
  sec
  +Skip1

.Exit_PRINT_NTH:
  clc
  rts

!zone