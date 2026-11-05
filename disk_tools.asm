; Gestione delle unità disco

!zone Disk_Status
DISK_STATUS:
  tax                           ; Copia il numero dell'unità in .X
  lda #15                       ; Numero del file
  tay                           ; Indirizzo secondario: canale comandi
  jsr SETLFS

  lda #0                        ; Nessun nome di file
  jsr SETNAM

  jsr OPEN                      ; Apri il file
  bcs .Exit_DISK_STATUS_Abort   ; se ci sono errori pulisci tutto ed esci

  ldx #15                       ; L'input proverrà dal file #15
  jsr CHKIN

  ldy #0

.Loop_GetChar:
  jsr READST                    ; Si è raggiunta la fine del file
  and #%01000000
  bne .Exit_DISK_STATUS         ; Sì, chiudi tutto ed esci

  jsr CHRIN                     ; Leggi il prossimo carattere e salvalo sullo stack
  sta STACK,y
  iny
  bne .Loop_GetChar

.Exit_DISK_STATUS:
  dey                           ; Torna indietro di una posizione e sovrascrivi l'ultimo carattere letto ($0D)
  lda #0                        ; con uno zero in modo che la stringa possa poi essere elaborata più facilmente
  sta STACK,y

.Exit_DISK_STATUS_Abort:
  lda #15                       ; chiudi il file #15
  jsr CLOSE
  jsr CLRCHN                    ; poi resetta i canali di I/O
  rts


; Titolo: DISK_DIRECTORY
!zone Disk_Directory
DISK_DIRECTORY:
  tax                           ; Copia il numero dell'unità in .X
  lda #88                       ; Numero del file
  ldy #0                        ; Indirizzo secondario: canale comandi
  jsr SETLFS

  lda #.DIR_PATTERN_END-.DIR_PATTERN
  ldx #<.DIR_PATTERN
  ldy #>.DIR_PATTERN
  jsr SETNAM

  jsr OPEN                      ; Apri il file
  bcs .Exit_DIRECTORY_Abort     ; se ci sono errori pulisci tutto ed esci

  ldx #88                       ; L'input proverrà dal file #88
  jsr CHKIN

  jsr CHRIN                     ; Scarta i primi due byte: contengono l'indirizzo al quale caricare la directory come se fosse un programma
  jsr CHRIN

.Loop_ReadLine:
  jsr READST                    ; Esci se c'è un errore
  bne .Exit_DIRECTORY_Abort

  jsr CHRIN                     ; Leggi i prossimi 2 byte
  sta ._TEMP                    ; e se entrambi valgono 0 la directory è terminata
  jsr CHRIN
  ora ._TEMP
  beq .Exit_DIRECTORY

  lda #13                       ; Comincia una nuova linea andando a capo
  jsr PUTCHAR

  jsr CHRIN                     ; Stampa i due byte successivi che indicano la lunghezza in blocchi del file
  tax
  jsr CHRIN
  jsr LINPRT

  lda #32                       ; Stampa uno spazio separatore
  jsr PUTCHAR

.Loop_PrintChar:
  jsr READST                    ; Esci se c'è un errore
  bne .Exit_DIRECTORY_Abort

  jsr CHRIN                     ; Altrimenti leggi il prossimo carattere e se è 0 passa alla prossima linea
  beq .Loop_ReadLine

  jsr PUTCHAR                    ; altrimenti stampalo e passa al prossimo
  bne .Loop_PrintChar

.Exit_DIRECTORY_Abort:
  lda #13                       ; Inizia una nuova linea
  jsr __PUTCHAR
  lda FA                        ; Leggi il messaggio d'errore e stampalo
  jsr DISK_STATUS
  lda #<STACK
  ldy #>STACK
  jsr STROUT

.Exit_DIRECTORY:
  lda #88
  jsr CLOSE
  jsr CLRCHN
  rts


.DIR_PATTERN:
  !text "$0"

._TEMP
  !byte 0       ; Variabile temporanea

!zone
