;64tass format
;with default $dc02 - $dc03 values ($ff and $00)
;taken from Platoon game, shortened and key history integrated.
;code to key conversion table below, from c64-wiki.com

;to use inside irq, below code is enough :
; lda #$keycode
; jsr KEYSCAN
; bcc +
; inc $d020
;+  rts



  * = $1000

!zone KeyScan
; Titolo:                 ROUTINE: Scansione della tastiera (tasto singolo)
; Nome:                   KEYSCAN
; Descrizione:            Scansiona la tastiera per verificare la pressione di un tasto specificato
;                         senza passare per il KERNAL ma accedendo direttamente all'hardware. La locazione
;                         di memoria _KBD_HISTORY mantiene una serie storica degli eventi di I/O.
;
;                         Il tasto da scansionare è in formato keycode ed in seguito alla scansione si possono verificare i seguenti casi:
;                          C = 0 e _KBD_HISTORY = 0: Falso tasto dovuto all'interferenza del joystick
;                          C = 1:
; Parametri di ingresso:  .A : keycode da scansionare
; Parametri di uscita:    ---
; Alterazioni registri:   .A
; Alterazioni pag. zero:  ---
; Dipendenze esterne:     vic.asm, cia.asm
KEYSCAN:
  sty .Backup_Y+1               ; ATTENZIONE: codice automodificante per il salvataggio e ripristino di .Y. Vedi (**)


  pha                           ; Salva il codice da scansionare sullo stack

  lsr a                         ; Il codice diviso 8 indica la riga da selezionare
  lsr a
  lsr a
  tay


  lda .KBD_ROW,y
  sta CIAPRA
  pla                           ; Riprendi il codice dallo stack
  and #%00000111                ; I 3 bit meno significativi indicano la colonna da scansionare
  tay


  lda CIAPRB
  and .KBD_COLUMN,y


  bne .No_Key                   ; Un risultato diverso da zero indica che il tasto non è stato premuto

  lda #%11111111                ; Se invece il risultato è zero rileggi l'intera colonna
  sta CIAPRA                    ; per essere certi che i joystick #1 e #2 non stiano interferendo
  lda CIAPRB
  and .KBD_COLUMN,y


  beq .No_Key

  cmp ._HISTORY                 ; Confronta il valore letto con la serie storica
  bne .No_Hold                  ; Se differiscono allora il tasto è stato premuto e rilasciato
  clc                           ; (caso 3) in caso contrario non aggiornare la serie storica ed esci con C=0
  bcc .Backup_Y

.No_Key:
  asl a                         ; (caso 1) Tasto non premuto (o interferenza del joystick): fai scorrere a sx la serie storica ed esci con C=0
  clc
  +Skip1

.No_Hold:
  sec                           ; (caso 2) Tasto premuto e rilasciato: aggiornare la serie storica ed esci con C=1
  sta ._HISTORY


.Backup_Y:
  ldy #$00                      ; (**) Ripristina .Y

.Exit_KEYSCAN:

  lda #%11111111                ; Rimetti le porte di lettura in stato di attesa
  sta CIAPRA
  lda #%01111111
  sta CIAPRB

  rts

.KBD_ROW:
  !byte %11111110               ; Maschere di selezione della riga della matrice della tastiera
  !byte %11111101
  !byte %11111011
  !byte %11110111
  !byte %11101111
  !byte %11011111
  !byte %10111111
  !byte %01111111

.KBD_COLUMN:
  !byte %00000001               ; Maschere di selezione della colonna della matrice della tastiera
  !byte %00000010
  !byte %00000100
  !byte %00001000
  !byte %00010000
  !byte %00100000
  !byte %01000000
  !byte %10000000


._HISTORY:
  !byte 0

!zone