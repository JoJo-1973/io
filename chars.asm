; Conversione di caratteri tra varie codifiche

; Titolo:                 MACRO: Applicazione di una tabella di conversione ad un codice carattere
; Nome:                   ApplyConversionTable
; Descrizione:            La macro trasforma il codice carattere fornito in una codifica differente applicando la tabella di conversione specificata.
;
;                         La tabella contiene 8 valori, di cui solo i 3 bit più significativi sono utilizzati, i restanti bit devono essere settati a 0.
;                         La macro funziona estraendo i 3 bit più significativi del codice carattere da convertire trasformandoli in un indice compreso
;                         tra 0 e 7 che viene usato per estrarre il valore corrispondente dalla tabella di conversione, il quale viene poi sovrapposto al
;                         codice carattere originario mediante OR logico.
;
; Parametri di ingresso:  table:Indirizzo della tabella di conversione
;                         .A:   Codice carattere da convertire
;                         .X:   Copia del codice carattere da convertire
; Parametri di uscita:    .A:   Codice carattere convertito
; Alterazioni registri:   .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     ---
!macro ApplyConversionTable table {
  lsr a                         ; Muovi i bit 7-6-5 alle posizioni 2-1-0
  lsr a
  lsr a
  lsr a
  lsr a
  tay                           ; che ora diventano un valore compreso tra 0-7 da usare come indice nella tabella di conversione

  txa                           ; Ripristina il codice originario
  and #%00011111                ; maschera i bit 4-0
  ora table,y                   ; e sostituisci i bit 7-5 con i nuovi valori
}

!zone Scr2Pet
; Titolo:                 ROUTINE: Conversione da codifica Codice Schermo a PETSCII
; Nome:                   SCR2PET
; Descrizione:            La macro trasforma il codice carattere dalla codifica Codice Schermo a quella PETSCII.
;
;                         I codici 64-95 e 96-127 della codifica Codice Schermo sono associati a due intervalli nella codifica PETSCII:
;
;                               64-95 -> 96-127 e 192-223(*)
;                              96-127 -> 160-191(*) e 224-255
;
;                         Gli intervalli con (*) corrispondono ai codici sono generati dalla tastiera pertanto saranno questi ultimi
;                         ad essere restituiti come risultato della conversione.
;
;                         I codici con valore >127 corrispondo a caratteri in modalità inversa che non hanno un corrispettivo in codifica PETSCII:
;                         in tal caso il risultato della conversione dipende dal valore in ingresso del Carry.
;
;                          C = 0: I caratteri in modalità inversa 128-159 e 192-223 vengono convertiti nei caratteri di controllo 0-31 e 128-159
;                                 ossia quelli contraddistinti dalla medesima rappresentazione grafica in modalità "virgolette".
;                          C = 1: I caratteri in modalità inversa vengono convertiti nelle loro controparti in modalità normale ed elaborati come tali.
;
;                         In entrambi i casi all'uscita si pone C = 1 per segnalare che il codice originario era >127.
;
; Parametri di ingresso:  .A:   Codice carattere in codifica PETSCII
;                          C:   Selezione della modalità di conversione
; Parametri di uscita:    .A:   Codice carattere in codifica Codice Schermo
;                         .X:   Codice carattere in codifica PETSCII
;                          C:   Successo (0) o meno (1) della conversione
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     ---
SCR2PET:
  php                           ; Salva il valore del Carry sullo stack
  tax                           ; Salva una copia del codice originario in .X

  and #%01111111                ; Riduci il codice all'intervallo 0-127

.Check_5E:
  cmp #$5E                      ; Il codice 94 va gestito a parte
  bne .Convert

.Exit_PETSCR_5E:
  lda #$FF                      ; Restituisci la sua conversione (255)
  plp
  cpx #%10000000                ; Se il codice originario era >127 setta il Carry
  rts

.Convert:
  txa                           ; Riprendi il codice originario
  plp
  bcs .Table_1
  +ApplyConversionTable .SCR2PET_TABLE_0
  +Bra .Exit_SCR2PET

.Table_1:
  +ApplyConversionTable .SCR2PET_TABLE_1

.Exit_SCR2PET:
  cpx #%10000000                ; Se il codice originario era >127 setta il Carry
  rts


.SCR2PET_TABLE_0:
  !byte %01000000               ;   0 -  31 ->  64 -  95
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %11000000               ;  64 -  95 -> 192 - 223
  !byte %10100000               ;  96 - 127 -> 160 - 191
  !byte %00000000               ; 128 - 159 ->   0 -  31    (Carry = 1)
  !byte %00100000               ; 160 - 191 ->  32 -  63    (Carry = 1)
  !byte %10000000               ; 192 - 223 -> 128 - 159    (Carry = 1)
  !byte %10100000               ; 224 - 255 -> 160 - 191    (Carry = 1)

.SCR2PET_TABLE_1:
  !byte %01000000               ;   0 -  31 ->  64 -  95
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %11000000               ;  64 -  95 -> 192 - 223
  !byte %10100000               ;  96 - 127 -> 160 - 191
  !byte %01000000               ; 128 - 159 ->  64 -  95    (Carry = 1, rappresentazione grafica del codice in modalità "virgolette")
  !byte %00100000               ; 160 - 191 ->  32 -  63    (Carry = 1)
  !byte %11000000               ; 192 - 223 -> 192 - 223    (Carry = 1, rappresentazione grafica del codice in modalità "virgolette")
  !byte %10100000               ; 224 - 255 -> 160 - 191    (Carry = 1)

                                ; Casi particolari:

                                ;  94       -> 255
                                ; 222       -> 255          (Carry = 1)
                                ;  64 -  95 ->  96 - 127    (alternativa scartata perchè questi codici non sono generabili da tastiera)
                                ;  96 - 127 -> 224 - 254    (alternativa scartata perchè questi codici non sono generabili da tastiera)

!zone Pet2Scr
; Titolo:                 ROUTINE: Conversione da codifica PETSCII a Codice Schermo
; Nome:                   PET2SCR
; Descrizione:            La macro trasforma il codice carattere dalla codifica PETSCII a quella Codice Schermo.
;
;                         I codici PETSCII 0-31 e 128-159 sono caratteri di controllo e non hanno un equivalente in Codice Schermo:
;                         a seconda del valore di C la routine fornisce una conversione differente.
;
;                          C = 0: la routine restituisce il codice originario e C = 1 per segnalare l'impossibilità della conversione
;                          C = 1: la routine restituisce il codice della rappresentazione grafica in modo "virgolette" del carattere di controllo
;                                 e pone C = 0 per segnalare l'avvenuta conversione
;
; Parametri di ingresso:  .A:   Codice carattere in codifica PETSCII
;                          C:   Selezione della modalità di conversione
; Parametri di uscita:    .A:   Codice carattere in codifica Codice Schermo
;                         .X:   Codice carattere in codifica PETSCII
;                          C:   Successo (0) o meno (1) della conversione
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     ---
PET2SCR:
  php                           ; Salva il valore del Carry sullo stack
  tax                           ; Salva una copia del codice originario in .X

.Check_FF:
  cmp #$FF                      ; Il codice 255 va gestito a parte
  bne .Check_Carry

.Exit_PET2SCR_FF:
  lda #$5E                      ; Restituisci la sua conversione (94)
  plp
  clc
  rts

.Check_Carry:
  plp                           ; Recupera il Carry
  bcs .Convert                  ; Se C=1 procedi direttamente alla conversione
  and #%01111111                ; altrimenti mappa il codice all'intervallo 0-127
  cmp #32                       ; e verifica che sia minore di 32
  bcs .Convert                  ; se sì procedi alla conversione

.Exit_PETSCR_NonExist:
  txa                           ; Rimetti in .A il codice originario
  sec
  rts

.Convert:
  txa                           ; Rimetti in .A il codice originario
  +ApplyConversionTable .PET2SCR_TABLE

.Exit_PET2SCR:
  clc
  rts

.PET2SCR_TABLE:
  !byte %10000000               ;   0 -  31 -> 128 - 159    (rappresentazione grafica del codice in modalità "virgolette")
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %00000000               ;  64 -  95 ->   0 -  31
  !byte %01000000               ;  96 - 127 ->  64 -  95
  !byte %11000000               ; 128 - 159 -> 192 - 223    (rappresentazione grafica del codice in modalità "virgolette")
  !byte %01100000               ; 160 - 191 ->  96 - 127
  !byte %01000000               ; 192 - 223 ->  64 -  95
  !byte %01100000               ; 224 - 255 ->  96 - 127

                                ; Casi particolari:

                                ; 255       ->  94

!zone Scr2Asc
; Titolo:                 ROUTINE: Conversione da codifica Codice Schermo ad ASCII (7 bit)
; Nome:                   SCR2ASC
; Descrizione:            La macro trasforma il codice carattere dalla codifica Codice Schermo a quella ASCII (7 bit).
;
;                         I codici con valore >127 corrispondo a caratteri in modalità inversa che non hanno un corrispettivo in codifica ASCII (7 bit):
;                         in tal caso il risultato della conversione dipende dal valore in ingresso del Carry.
;
;                          C = 0: I caratteri in modalità inversa 128-159 vengono convertiti nei caratteri di controllo 0-31.
;                          C = 1: I caratteri in modalità inversa 128-159 vengono convertiti nelle loro controparti in modalità normale ed elaborati come tali.
;
;                         In entrambi i casi all'uscita si pone C = 1 per segnalare che il codice originario era >127.
;                         I codici 96-127 e 224-255 non hanno corrispettivo nel codice ASCII (7 bit) e vengono convertiti nel codice 255.
;
; Parametri di ingresso:  .A:   Codice carattere in codifica Codice Schermo
;                          C:   Selezione della modalità di conversione
; Parametri di uscita:    .A:   Codice carattere in codifica ASCII (7 bit)
;                         .X:   Codice carattere in codifica Codice Schermo
;                          C:   Successo (0) o meno (1) della conversione
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     ---
SCR2ASC:
.NUM_SPECIALS     = (.SCR2ASC_SPECIALS_END - .SCR2ASC_SPECIALS) / 2

  php                           ; Salva il valore del Carry sullo stack
  tax                           ; Salva una copia del codice originario in .X

.Check_Specials:
  ldy #(.NUM_SPECIALS-1)        ; Carica .Y con il numero di caratteri che dev'essere trattato in maniera particolare (meno 1)
  and #%01111111                ; e mappa il codice originario all'intervallo 0-127

.Loop_Specials:
  cmp .SCR2ASC_SPECIALS,y       ; Verifica se è uno dei codici speciali
  beq .Exit_SCR2ASC_Special     ; Sì? elabora la conversione
  dey                           ; altrimenti passa al successivo
  bpl .Loop_Specials
  +Bra .Convert

.Exit_SCR2ASC_Special:
  lda .SCR2ASC_SPECIALS+.NUM_SPECIALS,y
                                ; Estrai il codice ASCII (7 bit) dalla tabella di conversione
  plp
  cpx #%10000000                ; Se il codice originario era >127 setta il Carry
  rts

.Convert:
  txa                           ; Riprendi il codice originario
  plp
  bcs .Table_1
  +ApplyConversionTable .SCR2ASC_TABLE_0
  +Bra .Exit_SCR2ASC

.Table_1:
  +ApplyConversionTable .SCR2ASC_TABLE_1

.Exit_SCR2ASC:
  cpx #%10000000                ; Se il codice originario era >127 setta il Carry
  rts

.SCR2ASC_TABLE_0:
  !byte %01100000               ;   0 -  31 ->  96 - 127
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %01000000               ;  64 -  95 ->  64 -  95
  !byte %11111111               ;  96 - 127 -> Inesistente
  !byte %00000000               ; 128 - 159 ->   0 -  31    (Carry = 1)
  !byte %00100000               ; 160 - 191 ->  32 -  63    (Carry = 1)
  !byte %01000000               ; 192 - 223 ->  64 -  95    (Carry = 1)
  !byte %11111111               ; 224 - 255 -> Inesistente  (Carry = 1)

.SCR2ASC_TABLE_1:
  !byte %01100000               ;   0 -  31 ->  96 - 127
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %01000000               ;  64 -  95 ->  64 -  95
  !byte %11111111               ;  96 - 127 -> Inesistente
  !byte %00000000               ; 128 - 159 ->  96 - 127    (Carry = 1, rappresentazione grafica del codice in modalità "virgolette")
  !byte %00100000               ; 160 - 191 ->  32 -  63    (Carry = 1)
  !byte %01000000               ; 192 - 223 ->  64 -  95    (Carry = 1)
  !byte %11111111               ; 224 - 255 -> Inesistente  (Carry = 1)

                                ; Casi particolari:

                                ;   0, 128  ->  64          ( @ ) (Carry = 1 quando il Codice Schermo è >127)
                                ;  27, 155  ->  91          ( [ ) (Carry = 1 quando il Codice Schermo è >127)
                                ;  29, 157  ->  93          ( ] ) (Carry = 1 quando il Codice Schermo è >127)
                                ;  30, 158  ->  94          ( ^ ) (Carry = 1 quando il Codice Schermo è >127)
                                ;  64, 192  -> 126          ( ~ ) (Carry = 1 quando il Codice Schermo è >127)
                                ;  93, 221  -> 124          ( | ) (Carry = 1 quando il Codice Schermo è >127)
                                ;  96, 224  ->  32          (   ) (Carry = 1 quando il Codice Schermo è >127)
                                ; 100, 228  ->  95          ( _ ) (Carry = 1 quando il Codice Schermo è >127)
                                ; 102, 230  -> 127          <DEL> (Carry = 1 quando il Codice Schermo è >127)
                                ; 107, 235  -> 125          ( } ) (Carry = 1 quando il Codice Schermo è >127)
                                ; 109, 237  ->  96          ( ` ) (Carry = 1 quando il Codice Schermo è >127)
                                ; 115, 243  -> 123          ( { ) (Carry = 1 quando il Codice Schermo è >127)
                                ; 127, 255  ->  92          ( \ ) (Carry = 1 quando il Codice Schermo è >127)
.SCR2ASC_SPECIALS:
  !byte   0, 27, 29, 30, 64, 93, 96,100,102,107,115,109,127
  !byte  64, 91, 93, 94,126,124, 32, 95,127,125,123, 96, 92
.SCR2ASC_SPECIALS_END:

!zone Asc2Scr
; Titolo:                 ROUTINE: Conversione da codifica ASCII (7 bit) a Codice Schermo
; Nome:                   ASC2SCR
; Descrizione:            La macro trasforma il codice carattere dalla codifica ASCII (7 bit) a quella Codice Schermo.
;
;                         I codici con valore >127 non sono definiti nella codifica ASCII (7 bit):
;
;                         I codici ASCII (7 bit) 0-31 sono caratteri di controllo e non hanno un equivalente in Codice Schermo:
;                         a seconda del valore di C la routine fornisce una conversione differente.
;
;                          C = 0: la routine restituisce il codice originario e C = 1 per segnalare l'impossibilità della conversione
;                          C = 1: la routine restituisce il codice della rappresentazione grafica in modo "virgolette" del carattere di controllo
;                                 e pone C = 0 per segnalare l'avvenuta conversione

; Parametri di ingresso:  .A:   Codice carattere in codifica Codice Schermo
;                          C:   Selezione della modalità di conversione
; Parametri di uscita:    .A:   Codice carattere in codifica ASCII (7 bit)
;                         .X:   Codice carattere in codifica Codice Schermo
;                          C:   Successo (0) o meno (1) della conversione
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     ---
ASC2SCR:
.NUM_SPECIALS     = (.ASC2SCR_SPECIALS_END - .ASC2SCR_SPECIALS) / 2

  php                           ; Salva il valore del Carry sullo stack
  tax                           ; Salva una copia del codice originario in .X

.Check_NonExist:
  cmp #128                      ; I codici >127 non esistono nella codifica ASCII (7 bit)
  bcc .Check_Specials

.Exit_Check_NonExist:
  lda #255
  plp
  sec
  rts

.Check_Control_Code:
  cmp #32                       ; I codici <32 vengono convertiti differentemente in funzione del Carry
  bcs .Check_Specials

  plp                           ; Recupera il Carry
  php                           ; e ripristina lo stack
  bcs .Check_Specials           ; Se C=1 procedi oltre

.Exit_ASC2SCR_Control_Code:
  plp                           ; altrimenti non convertire il codice ed esci con C=1
  sec
  rts

.Check_Specials:
  ldy #(.NUM_SPECIALS-1)        ; Carica .Y con il numero di caratteri che dev'essere trattato in maniera particolare (meno 1)

.Loop_Specials:
  cmp .ASC2SCR_SPECIALS,y       ; Verifica se è uno dei codici speciali
  beq .Exit_ASC2SCR_Special     ; Sì? elabora la conversione
  dey                           ; altrimenti passa al successivo
  bpl .Loop_Specials
  +Bra .Convert

.Exit_ASC2SCR_Special:
  lda .ASC2SCR_SPECIALS+.NUM_SPECIALS,y
                                ; Estrai il codice ASCII (7 bit) dalla tabella di conversione
  plp
  clc
  rts

.Convert:
  txa                           ; Riprendi il codice originario
  +ApplyConversionTable .ASC2SCR_TABLE

.Exit_ASC2SCR:
  plp
  clc
  rts


.ASC2SCR_TABLE:
  !byte %10000000               ;   0 -  31 -> 128 - 159    (rappresentazione grafica del codice in modalità "virgolette")
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %01000000               ;  64 -  95 ->  64 -  95
  !byte %00000000               ;  96 - 127 ->   0 -  31
  !byte %11111111               ; 128 - 159 -> Inesistente
  !byte %11111111               ; 160 - 191 -> Inesistente
  !byte %11111111               ; 192 - 223 -> Inesistente
  !byte %11111111               ; 224 - 255 -> Inesistente

                                ; Casi particolari:

                                ;  64       ->   0          ( @ )
                                ;  91       ->  27          ( [ )
                                ;  92       -> 127          ( \ )
                                ;  93       ->  29          ( ] )
                                ;  94       ->  30          ( ^ )
                                ;  95       -> 100          ( _ )
                                ;  96       -> 109          ( ` )
                                ; 123       -> 115          ( { )
                                ; 124       ->  93          ( | )
                                ; 125       -> 107          ( } )
                                ; 126       ->  64          ( ~ )
                                ; 127       -> 102          <DEL>

.ASC2SCR_SPECIALS:
  !byte  64, 91, 92, 93, 94, 95, 96,123,124,125,126,127
  !byte   0, 27,127, 29, 30,100,109,115, 93,107, 64,102
.ASC2SCR_SPECIALS_END:



!zone Pet2Asc
; Titolo:                 ROUTINE: Conversione da codifica PETSCII ad ASCII (7 bit)
; Nome:                   PET2ASC
; Descrizione:            La macro trasforma il codice carattere dalla codifica PETSCII a quella ASCII (7 bit).
;
;                         I codici PETSCII 128-191 e 224-255 (salvo casi speciali) non hanno un equivalente in ASCII (7 bit)
;                         e vengono segnalati come inesistenti: viene restituito il codice 255 ed il Carry viene settato.
;
; Parametri di ingresso:  .A:   Codice carattere in codifica PETSCII
; Parametri di uscita:    .A:   Codice carattere in codifica ASCII (7 bit)
;                         .X:   Codice carattere in codifica PETSCII
;                          C:   Successo (0) o meno (1) della conversione
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     ---
PET2ASC:
.NUM_SPECIALS     = (.PET2ASC_SPECIALS_END - .PET2ASC_SPECIALS) / 2

  php                           ; Salva il valore del Carry sullo stack
  tax                           ; Salva una copia del codice originario in .X

.Check_Specials:
  ldy #(.NUM_SPECIALS-1)        ; Carica .Y con il numero di caratteri che dev'essere trattato in maniera particolare (meno 1)

.Loop_Specials:
  cmp .PET2ASC_SPECIALS,y       ; Verifica se è uno dei codici speciali
  beq .Exit_PET2ASC_Special     ; Sì? elabora la conversione
  dey                           ; altrimenti passa al successivo
  bpl .Loop_Specials
  +Bra .Convert

.Exit_PET2ASC_Special:
  lda .PET2ASC_SPECIALS+.NUM_SPECIALS,y
                                ; Estrai il codice ASCII (7 bit) dalla tabella di conversione
  plp
  clc
  rts

.Convert:
  txa                           ; Riprendi il codice originario
  +ApplyConversionTable .PET2ASC_TABLE

.Check_NonExist:
  cmp #255
  bne .Exit_PET2ASC
  plp
  sec
  rts

.Exit_PET2ASC:
  plp
  clc
  rts


.PET2ASC_TABLE:
  !byte %00000000               ;   0 -  31 ->   0 -  31
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %01100000               ;  64 -  95 ->  96 - 127
  !byte %01000000               ;  96 - 127 ->  64 -  95
  !byte %11111111               ; 128 - 159 -> Inesistente
  !byte %11111111               ; 160 - 191 -> Inesistente
  !byte %01000000               ; 192 - 223 ->  64 -  95
  !byte %11111111               ; 224 - 255 -> Inesistente

                                ; Casi particolari:

                                ;  64       ->  64          ( @ )
                                ;  91       ->  91          ( [ )
                                ;  92       ->  92          ( \ )
                                ;  93       ->  93          ( ] )
                                ;  94       ->  94          ( ^ )
                                ;  95       ->  95          ( _ )
                                ;  96       -> 126          ( ~ )
                                ; 125       -> 124          ( | )
                                ; 160       ->  32          (   )
                                ; 166       -> 127          <DEL>
                                ; 171       -> 125          ( } )
                                ; 173       ->  96          ( ` )
                                ; 179       -> 123          ( { )
                                ; 192       -> 126          ( ~ )
                                ; 221       -> 124          ( | )
                                ; 224       ->  32          (   )
                                ; 230       -> 127          <DEL>
                                ; 235       -> 125          ( } )
                                ; 237       ->  96          ( ` )
                                ; 243       -> 123          ( { )

.PET2ASC_SPECIALS:
  !byte  64, 91, 92, 93, 94, 95, 96,125,160,166,171,173,179,192,221,224,230,235,237,243
  !byte  64, 91, 92, 93, 94, 95,126,124, 32,127,125, 96,123,126,124, 32,127,125, 96,123
.PET2ASC_SPECIALS_END:

!zone Asc2Pet
; Titolo:                 ROUTINE: Conversione da codifica ASCII (7 bit) a PETSCII
; Nome:                   ASC2PET
; Descrizione:            La macro trasforma il codice carattere dalla codifica ASCII (7 bit) a quella PETSCII.
;
;                         I codici con valore >127 non sono definiti nella codifica ASCII (7 bit):
;
;                          C = 0: la routine restituisce il codice originario e C = 1 per segnalare l'impossibilità della conversione
;                          C = 1: la routine restituisce il codice della rappresentazione grafica in modo "virgolette" del carattere di controllo
;                                 e pone C = 0 per segnalare l'avvenuta conversione

; Parametri di ingresso:  .A:   Codice carattere in codifica ASCII (7 bit)
;                          C:   Selezione della modalità di conversione
; Parametri di uscita:    .A:   Codice carattere in codifica PETSCII
;                         .X:   Codice carattere in codifica ASCII (7 bit)
;                          C:   Successo (0) o meno (1) della conversione
; Alterazioni registri:   .A, .X, .Y
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     ---
ASC2PET:
.NUM_SPECIALS     = (.ASC2PET_SPECIALS_END - .ASC2PET_SPECIALS) / 2

  php                           ; Salva il valore del Carry sullo stack
  tax                           ; Salva una copia del codice originario in .X

.Check_NonExist:
  bpl .Check_Specials           ; La codifica ASCII (7 bit) non ammette codici >127

.Exit_ASC2PET_NonExist:
  lda #255
  plp
  sec
  rts

.Check_Specials:
  ldy #(.NUM_SPECIALS-1)        ; Carica .Y con il numero di caratteri che dev'essere trattato in maniera particolare (meno 1)

.Loop_Specials:
  cmp .ASC2PET_SPECIALS,y       ; Verifica se è uno dei codici speciali
  beq .Exit_ASC2PET_Special     ; Sì? elabora la conversione
  dey                           ; altrimenti passa al successivo
  bpl .Loop_Specials
  +Bra .Convert

.Exit_ASC2PET_Special:
  lda .ASC2PET_SPECIALS+.NUM_SPECIALS,y
                                ; Estrai il codice PETSCII dalla tabella di conversione
  plp
  clc
  rts

.Convert:
  txa                           ; Riprendi il codice originario
  plp
  bcs .Table1
  +ApplyConversionTable .ASC2PET_TABLE_0
  +Bra .Exit_ASC2PET

.Table1:
  +ApplyConversionTable .ASC2PET_TABLE_1
  cpx #32                       ; Se il codice originario è >31 allora C=1
  +CCf                          ; ma noi vogliamo l'opposto, quindi invertiamo C
  +Skip1

.Exit_ASC2PET:
  clc
  rts



.ASC2PET_TABLE_0:
  !byte %00000000               ;   0 -  31 ->   0 -  31
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %01100000               ;  64 -  95 ->  96 - 127
  !byte %01000000               ;  96 - 127 ->  64 -  95
  !byte %11111111               ; 128 - 159 -> Inesistente
  !byte %11111111               ; 160 - 191 -> Inesistente
  !byte %01000000               ; 192 - 223 -> Inesistente
  !byte %11111111               ; 224 - 255 -> Inesistente

.ASC2PET_TABLE_1:
  !byte %00000000               ;   0 -  31 ->  64 -  95    (Carry = 1, rappresentazione grafica del codice in modalità "virgolette")
  !byte %00100000               ;  32 -  63 ->  32 -  63
  !byte %01100000               ;  64 -  95 ->  96 - 127
  !byte %01000000               ;  96 - 127 ->  64 -  95
  !byte %11111111               ; 128 - 159 -> Inesistente
  !byte %11111111               ; 160 - 191 -> Inesistente
  !byte %01000000               ; 192 - 223 -> Inesistente
  !byte %11111111               ; 224 - 255 -> Inesistente

                                ; Casi particolari:

                                ;  64       ->  64          ( @ )
                                ;  91       ->  91          ( [ )
                                ;  92       -> 191          ( \ )
                                ;  93       ->  93          ( ] )
                                ;  94       ->  94          ( ^ )
                                ;  95       -> 164          ( _ )
                                ;  96       -> 173          ( ` )
                                ; 123       -> 179          ( { )
                                ; 124       -> 125          ( | )
                                ; 125       -> 171          ( } )
                                ; 126       ->  96          ( ~ )
                                ; 127       -> 166          <DEL>

.ASC2PET_SPECIALS:
  !byte  64, 91, 92, 93, 94, 95, 96,123,124,125,126,127
  !byte  64, 91,191, 93, 94,164,173,179,125,171, 96,166
.ASC2PET_SPECIALS_END:

!zone