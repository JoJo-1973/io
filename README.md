# io

Utilità di input/output per il Commodore 64: gestione delle unità disco e lettura diretta della tastiera. La libreria `io` fa parte della Libreria di Sistema (progetto `io.c64`) ed è scritta in assembly 6510 per C64Studio (sintassi ACME).

Questo documento deriva dai sorgenti. Per ogni dettaglio fanno fede i contratti d'interfaccia nelle intestazioni delle subroutine.

<a id="contenuto"></a>
## Contenuto

| Modulo | Utilità | Descrizione |
|---|---|---|
| [`disk_tools.asm`](#modulo-disk_tools) | [`DISK_STATUS`](#utilita-disk_status) | Legge lo stato dell'unità disco |
| | [`DECODE_DISK_STATUS`](#utilita-decode_disk_status) | Decodifica lo stato dell'unità disco |
| | [`DISK_DIRECTORY`](#utilita-disk_directory) | Stampa la directory del disco |
| | [`DISK_COMMAND`](#utilita-disk_command) | Invia un comando all'unità disco |
| [`keyboard_tools.asm`](#modulo-keyboard_tools) | [`KEYSCAN`](#utilita-keyscan) | Scansiona un tasto della matrice della tastiera |
| [`chars.asm`](#limiti-noti) | | In revisione, non ancora utilizzabile |

## Uso

### Inclusione

La cartella `io` sta nella cartella delle librerie di C64Studio, accanto alle altre librerie di sistema. Il sorgente principale del programma include i moduli che usa nella parte dedicata al codice:

```
!source <io/disk_tools.asm>, once
!source <io/keyboard_tools.asm>, once
```

I moduli non includono altri file: i simboli che usano arrivano dai file di simboli che il programma include prima, nella parte dedicata ai simboli.

| Modulo | Include da sé | File da includere prima |
|---|---|---|
| `disk_tools.asm` | Nessuno | `<c64/kernal.asm>`, `<c64/symbols.asm>` |
| `keyboard_tools.asm` | Nessuno | `<c64/keyboard.asm>`, `<c64/symbols.asm>`, `<chip/cia.asm>` |

### Configurazione

Ogni subroutine viene assemblata solo se il suo parametro vale `1` nella copia di `config.asm` della Soluzione. Nel template tutti i parametri valgono `0`.

| Parametro | Subroutine | Richiede anche |
|---|---|---|
| `__USE_DISK_STATUS` | `DISK_STATUS` | |
| `__USE_DECODE_DISK_STATUS` | `DECODE_DISK_STATUS` | |
| `__USE_DISK_DIRECTORY` | `DISK_DIRECTORY` | `__USE_DISK_STATUS` |
| `__USE_DISK_COMMAND` | `DISK_COMMAND` | `__USE_DISK_STATUS` |
| `__USE_KEYSCAN` | `KEYSCAN` | |

Punti di personalizzazione usati dalla libreria, definiti anch'essi in `config.asm`:

| Punto di personalizzazione | Usato da | Valore nel template | Significato |
|---|---|---|---|
| `__PUT_CHAR` | `DISK_DIRECTORY` | `$FFD2` (CHROUT) | Subroutine di stampa di un carattere |
| `__KBD_HISTORY` | `KEYSCAN` | `$05` | Cella in ZP: serie storica di `KEYSCAN`, da azzerare prima del primo uso |

<a id="modulo-disk_tools"></a>
## disk_tools.asm

Utilità per la gestione delle unità disco. Tutte ricevono il numero dell'unità disco in `.A`.

Il messaggio di stato dell'unità disco ha la forma `NN,MESSAGGIO,TT,SS`: `NN` è il codice dell'errore, `MESSAGGIO` una stringa descrittiva, `TT` e `SS` di norma la traccia e il settore in cui è avvenuto l'errore (in alcuni casi hanno un altro significato). Senza errori il messaggio è `00,OK,00,00`. Le subroutine che lo leggono lo scrivono in `STACK`, la base della pagina dello stack, terminato da `$00`: è sovrascritto a ogni chiamata, quindi il chiamante lo usa subito (per esempio con STROUT o con `DECODE_DISK_STATUS`).

Il flag di Carry dice se l'operazione è riuscita (0) o no (1), non se l'unità disco ha segnalato un errore: per saperlo si decodifica il messaggio di stato con `DECODE_DISK_STATUS`.

Le subroutine aprono e chiudono da sé i file logici che usano: il file logico 15 (`DISK_STATUS`) e il file logico 88 (`DISK_DIRECTORY` e `DISK_COMMAND`).

<a id="utilita-disk_status"></a>
### DISK_STATUS

Legge il messaggio di stato dell'unità disco dal canale comandi (file logico 15, indirizzo secondario 15) e lo scrive in `STACK`, terminato da `$00` al posto del ritorno a capo che lo chiude. Se il canale non si apre, `STACK` non viene scritto.

| Voce | Contenuto |
|---|---|
| Input | `.A`: numero dell'unità disco |
| Output | `STACK` (fino a 256 byte): messaggio di stato terminato da `$00`<br>Carry: 0 = messaggio letto; 1 = canale non aperto |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), `STACK` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-decode_disk_status"></a>
### DECODE_DISK_STATUS

Decodifica il messaggio di stato già presente in `STACK` (scritto da `DISK_STATUS`) e restituisce in binario, da 0 a 99, i tre numeri che contiene. Non legge dall'unità disco e non altera il messaggio. Il controllo del formato è minimo: la decodifica si ferma al primo carattere diverso da quello previsto, e in quel caso `.A`, `.X` e `.Y` sono indefiniti.

| Voce | Contenuto |
|---|---|
| Input | `STACK` (fino a 40 byte): messaggio di stato terminato da `$00` |
| Output | `.A`: codice dell'errore (`NN`; 0 = nessun errore)<br>`.X`: primo numero dopo il messaggio (`TT`)<br>`.Y`: secondo numero dopo il messaggio (`SS`)<br>Carry: 0 = messaggio decodificato; 1 = formato non valido |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-disk_directory"></a>
### DISK_DIRECTORY

Stampa la directory del disco, una voce per linea: la lunghezza in blocchi, uno spazio e il nome. I caratteri si stampano con `__PUT_CHAR`.

I file da elencare si scelgono con un pattern, una stringa terminata da `$00` puntata da `INDEX` (per esempio `"$0"`). Un pattern nullo o più lungo di 40 caratteri è un errore: la subroutine esce subito con il Carry a 1 senza stampare nulla. Altrimenti il pattern passa al sistema operativo dell'unità senza altri controlli, e un pattern non valido produce un errore dell'unità.

In caso di errore dell'unità la subroutine va a capo, stampa il messaggio di stato (letto con `DISK_STATUS`) ed esce con il Carry a 1. La stampa dei numeri e del messaggio usa LINPRT e STROUT del BASIC, che alterano proprie celle di lavoro (tra cui FAC): il loro contenuto non è garantito dopo la chiamata.

| Voce | Contenuto |
|---|---|
| Input | `.A`: numero dell'unità disco<br>`INDEX` (2 byte, ZP): puntatore al pattern, terminato da `$00` |
| Output | Carry: 0 = directory stampata; 1 = pattern errato, canale non aperto o errore dell'unità |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), `STACK` |
| Richiede | `__USE_DISK_STATUS = 1` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-disk_command"></a>
### DISK_COMMAND

Invia un comando DOS all'unità disco e ne legge la risposta con `DISK_STATUS`. Il comando è una stringa terminata da `$00` puntata da `INDEX`: non può essere vuoto né superare i 40 caratteri (il DOS dell'unità tronca un comando più lungo, con risultati imprevedibili). Un comando non valido non viene inviato e la subroutine esce con il Carry a 1.

Se il canale comandi non si apre, il comando non parte e `STACK` non viene scritto. Se invece non si riesce a leggere lo stato, il comando è comunque partito, ma il Carry vale 1 e `STACK` non viene scritto.

| Voce | Contenuto |
|---|---|
| Input | `.A`: numero dell'unità disco<br>`INDEX` (2 byte, ZP): puntatore al comando, terminato da `$00` |
| Output | `STACK` (fino a 256 byte): messaggio di stato terminato da `$00`, non scritto se il comando non è inviato<br>Carry: 0 = comando inviato; 1 = errore (comando vuoto o più lungo di 40 caratteri, canale non aperto o stato non letto) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), `STACK` |
| Richiede | `__USE_DISK_STATUS = 1` |

[↑ Torna al contenuto](#contenuto)

<a id="modulo-keyboard_tools"></a>
## keyboard_tools.asm

Lettura diretta della tastiera dalla matrice del CIA #1, senza passare dal Kernal. Deriva da quella del gioco Platoon, accorciata e con la serie storica integrata.

Requisiti di pagina zero: `__KBD_HISTORY`.

<a id="utilita-keyscan"></a>
### KEYSCAN

Verifica se un tasto, indicato dal suo codice tastiera, è stato appena premuto. Non cerca quale tasto sia premuto: il codice tastiera è un dato in ingresso ([Nota #01](#nota-keyboard_tools-01)). Il codice tastiera è la posizione del tasto nella matrice, cioè la riga per 8 più la colonna (simboli `KBD_*` di `c64/keyboard.asm`, da `$00` a `$3F`); un codice da `KBD_NO_KEY` in su non è valido.

Legge la matrice direttamente dal CIA #1 e presuppone che i registri di direzione dei suoi due porti abbiano i valori predefiniti (`$FF` e `$00`). La serie storica `__KBD_HISTORY` è un solo byte, condiviso da tutti i tasti ([Nota #02](#nota-keyboard_tools-02)): contiene la maschera della colonna finché il tasto resta premuto e vale zero dopo il rilascio. Il chiamante la azzera prima del primo uso.

Il Carry a 1 segnala un codice tastiera non valido o il falso tasto, cioè l'interferenza del joystick. Con il Carry a 0 il flag di Negative dice se il tasto è premuto e il flag di Zero se la pressione è nuova. Esempi d'uso nelle note [Nota #03](#nota-keyboard_tools-03), [Nota #04](#nota-keyboard_tools-04) e [Nota #05](#nota-keyboard_tools-05).

| Voce | Contenuto |
|---|---|
| Input | `.A`: codice tastiera del tasto da scansionare<br>`__KBD_HISTORY` (1 byte, ZP): serie storica, da azzerare prima del primo uso |
| Output | `__KBD_HISTORY`: serie storica aggiornata<br>Negative: 0 = tasto non premuto; 1 = tasto premuto (nuova pressione o tenuto). Indefinito se Carry = 1<br>Zero: 0 = nuova pressione; 1 = tasto non premuto o ancora tenuto. Indefinito se Carry = 1<br>Carry: 0 = lettura valida; 1 = falso tasto o codice tastiera non valido |
| Registri Modificati | `.A`, `.P` (Negative, Zero, Carry), `CIAPRA`, `CIAPRB`, `__KBD_HISTORY` |

[↑ Torna al contenuto](#contenuto)

### Note d'uso di `keyboard_tools.asm`

<a id="nota-keyboard_tools-01"></a>
#### Nota #01

`KEYSCAN` non cerca quale tasto sia premuto e non restituisce il codice tastiera di un tasto: fa l'inverso. Riceve il codice tastiera di un tasto e verifica se quel tasto è stato appena premuto. Non è adatta a scoprire quale tasto sia premuto tra tutti, perché non scansiona l'intera matrice.

`KEYSCAN` controlla un tasto per volta e va chiamata a ogni passaggio di lettura. Segnala una nuova pressione una sola volta: finché il tasto resta premuto, le chiamate successive non riportano niente di nuovo. Un codice tastiera non valido (da `KBD_NO_KEY` in su) è un errore, come il falso tasto. Con il Carry a 0, il flag di Negative dice se il tasto è premuto e il flag di Zero se la pressione è nuova. Gli esempi sono nelle note da [Nota #03](#nota-keyboard_tools-03) in poi.

<a id="nota-keyboard_tools-02"></a>
#### Nota #02

La serie storica, la cella in pagina zero `__KBD_HISTORY`, è un solo byte, condiviso da tutti i tasti: finché il tasto resta premuto contiene la sola colonna, non la riga, e al rilascio viene azzerata. Il chiamante la azzera prima del primo uso. Quindi si controlla un tasto per volta: se nello stesso passaggio si scansionano tasti diversi, le chiamate si disturbano a vicenda e `KEYSCAN` segnala una nuova pressione a ogni passaggio finché uno dei tasti resta premuto. Due tasti della stessa colonna, poi, non si distinguono tra loro.

<a id="nota-keyboard_tools-03"></a>
#### Nota #03

Uso base: una scansione a ogni passaggio, per esempio dentro un gestore IRQ. Il Carry a 1 segnala un errore, il flag di Zero a 0 una nuova pressione. Esempio:

```
  lda #KBD_SPACE                ; Tasto da scansionare.
  jsr KEYSCAN
  bcs .Exit_Handler             ; Falso tasto: ignora la lettura.

  beq .Exit_Handler             ; Nessuna nuova pressione.

  inc EXTCOL                    ; Nuova pressione: cambia il bordo.

.Exit_Handler:
  rts
```

<a id="nota-keyboard_tools-04"></a>
#### Nota #04

Debouncing. I contatti della tastiera rimbalzano per qualche millisecondo, sia premendo sia rilasciando il tasto. Il flag di Negative dice se il tasto è ancora premuto: una nuova pressione si conferma al passaggio successivo, e se il tasto non è più premuto era solo un rimbalzo. Lo snippet è per un gestore IRQ chiamato a ogni fotogramma, e `_CANDIDATE` è una cella di RAM del programma, azzerata all'avvio. Esempio:

```
  lda #KBD_SPACE                ; Tasto da scansionare.
  jsr KEYSCAN
  bcs .Exit_Handler             ; Falso tasto: ignora la lettura.

  bpl .Clear_Candidate          ; Il tasto non è premuto.

  beq .Check_Candidate          ; Il tasto è tenuto.

  lda #1                        ; Nuova pressione: la conferma
  sta _CANDIDATE                ; arriva al prossimo passaggio.
  rts

.Clear_Candidate:
  lda #0                        ; Rimbalzo o rilascio: annulla
  sta _CANDIDATE                ; la pressione in attesa.
  rts

.Check_Candidate:
  lda _CANDIDATE                ; C'è una pressione da confermare?

  beq .Exit_Handler             ; No: il tasto è tenuto da prima.

  lda #0                        ; Sì: la pressione è confermata.
  sta _CANDIDATE

  inc EXTCOL                    ; Cambia il bordo.

.Exit_Handler:
  rts
```

<a id="nota-keyboard_tools-05"></a>
#### Nota #05

Attesa della pressione e del rilascio. Il primo ciclo attende una nuova pressione, il secondo attende il rilascio: finché il tasto resta premuto il flag di Negative vale 1. Lo snippet è per il programma principale e non per un gestore IRQ, perché i cicli non cedono mai il controllo. Esempio:

```
.Loop_Scan_Press:
  lda #KBD_SPACE                ; REPEAT
  jsr KEYSCAN
  bcs .Loop_Scan_Press          ; Falso tasto: riprova.

.Loop_Check_Press:
  beq .Loop_Scan_Press          ; REPEAT UNTIL: nuova pressione

  inc EXTCOL                    ; Tasto premuto: cambia il bordo.

.Loop_Poll_Release:
  lda #KBD_SPACE                ; REPEAT
  jsr KEYSCAN
  bcs .Loop_Poll_Release        ; Falso tasto: riprova.

.Loop_Check_Release:
  bmi .Loop_Poll_Release        ; REPEAT UNTIL: tasto non premuto
```

[↑ Torna al contenuto](#contenuto)

<a id="limiti-noti"></a>
## Limiti noti

- `DISK_COMMAND` non è ancora stato provato con un'unità disco reale.
- `KEYSCAN` con `__C128_C64_MODE = 1`: `KBD_NO_KEY` vale `$58`, quindi i codici extra del C128 da `$40` a `$57` superano il controllo di validità e la lettura della matrice non ha senso. I tasti extra del C128 si leggono da altre porte e richiedono un ramo dedicato, non ancora scritto.
- `KEYSCAN` e il joystick nella porta 2: il controllo del falso tasto è costruito sul joystick nella porta 1. L'influenza del joystick nella porta 2, che si legge sulla porta usata per selezionare le righe, non è stata ancora verificata.
- `KEYSCAN` controlla un tasto per volta e non distingue due tasti della stessa colonna ([Nota #02](#nota-keyboard_tools-02)).
- `chars.asm` (conversione di caratteri tra codifiche) è in revisione e non è ancora nel formato delle altre librerie: non va usato.

[↑ Torna al contenuto](#contenuto)
