# io

Utilità di input/output per il Commodore 64: gestione delle unità disco, lettura diretta della tastiera, stampa di caratteri e messaggi e transcodifica dei caratteri tra le codifiche Codice Schermo, PETSCII, ASCII a 7 bit ed ECM. La libreria `io` fa parte della Libreria di Sistema (progetto `io.c64`) ed è scritta in assembly 6510 per C64Studio (sintassi ACME).

Questo documento deriva dai sorgenti. Per ogni dettaglio fanno fede i contratti d'interfaccia nelle intestazioni delle macro e delle subroutine.

<a id="contenuto"></a>
## Contenuto

| Modulo | Utilità | Descrizione |
|---|---|---|
| [`chars.asm`](#modulo-chars) | [`m_Scan_Exceptions`](#utilita-m_scan_exceptions) | Cerca nella tabella delle eccezioni |
| | [`m_Apply_Table`](#utilita-m_apply_table) | Sostituisce i 3 bit alti del codice |
| | [`ASC_SCR`](#utilita-asc_scr) | Da ASCII a Codice Schermo, senza controlli |
| | [`ASC_SCR_C`](#utilita-asc_scr_c) | Da ASCII a Codice Schermo, con controlli |
| | [`ASC_PET`](#utilita-asc_pet) | Da ASCII a PETSCII, senza controlli |
| | [`ASC_PET_C`](#utilita-asc_pet_c) | Da ASCII a PETSCII, con controlli |
| | [`ASC_ECM`](#utilita-asc_ecm) | Da ASCII a ECM, senza controlli |
| | [`ASC_ECM_C`](#utilita-asc_ecm_c) | Da ASCII a ECM, con controlli |
| | [`ECM_SCR`](#utilita-ecm_scr) | Da ECM a Codice Schermo, senza controlli |
| | [`ECM_SCR_C`](#utilita-ecm_scr_c) | Da ECM a Codice Schermo, con controlli |
| | [`ECM_PET`](#utilita-ecm_pet) | Da ECM a PETSCII, senza controlli |
| | [`ECM_PET_C`](#utilita-ecm_pet_c) | Da ECM a PETSCII, con controlli |
| | [`ECM_ASC`](#utilita-ecm_asc) | Da ECM a ASCII, senza controlli |
| | [`ECM_ASC_C`](#utilita-ecm_asc_c) | Da ECM a ASCII, con controlli |
| | [`PET_SCR`](#utilita-pet_scr) | Da PETSCII a Codice Schermo, senza controlli |
| | [`PET_SCR_C`](#utilita-pet_scr_c) | Da PETSCII a Codice Schermo, con controlli |
| | [`PET_ASC`](#utilita-pet_asc) | Da PETSCII a ASCII, senza controlli |
| | [`PET_ASC_C`](#utilita-pet_asc_c) | Da PETSCII a ASCII, con controlli |
| | [`PET_ECM`](#utilita-pet_ecm) | Da PETSCII a ECM, senza controlli |
| | [`PET_ECM_C`](#utilita-pet_ecm_c) | Da PETSCII a ECM, con controlli |
| | [`SCR_PET`](#utilita-scr_pet) | Da Codice Schermo a PETSCII, senza controlli |
| | [`SCR_PET_C`](#utilita-scr_pet_c) | Da Codice Schermo a PETSCII, con controlli |
| | [`SCR_ASC`](#utilita-scr_asc) | Da Codice Schermo a ASCII, senza controlli |
| | [`SCR_ASC_C`](#utilita-scr_asc_c) | Da Codice Schermo a ASCII, con controlli |
| | [`SCR_ECM`](#utilita-scr_ecm) | Da Codice Schermo a ECM, senza controlli |
| | [`SCR_ECM_C`](#utilita-scr_ecm_c) | Da Codice Schermo a ECM, con controlli |
| [`disk_tools.asm`](#modulo-disk_tools) | [`DISK_STATUS`](#utilita-disk_status) | Legge lo stato dell'unità disco |
| | [`DECODE_DISK_STATUS`](#utilita-decode_disk_status) | Decodifica lo stato dell'unità disco |
| | [`DISK_DIRECTORY`](#utilita-disk_directory) | Stampa la directory del disco |
| | [`DISK_COMMAND`](#utilita-disk_command) | Invia un comando all'unità disco |
| [`keyboard_tools.asm`](#modulo-keyboard_tools) | [`KEYSCAN`](#utilita-keyscan) | Scansiona un tasto della matrice della tastiera |
| [`print_tools.asm`](#modulo-print_tools) | [`m_At`](#utilita-m_at) | Posiziona il cursore sullo schermo |
| | [`PLOT_CHAR`](#utilita-plot_char) | Memorizza un carattere nella memoria schermo |
| | [`COLOR_CHAR`](#utilita-color_char) | Cambia il colore di un carattere |
| | [`PRINT_MSG`](#utilita-print_msg) | Stampa una tabella di messaggi |
| | [`PRINT_NTH`](#utilita-print_nth) | Stampa un messaggio estratto da una tabella |
| | [`PRINT_RAW`](#utilita-print_raw) | Stampa un messaggio puntato da .A / .Y |
| | [`PRINT_IMM`](#utilita-print_imm) | Stampa il messaggio che segue la chiamata |
| | [`m_Put_ECM_Char`](#utilita-m_put_ecm_char) | Invia un carattere gestendo il modo ECM |

## Uso

### Inclusione

La cartella `io` sta nella cartella delle librerie di C64Studio, accanto alle altre librerie di sistema. Il sorgente principale del programma include i moduli che usa nella parte dedicata al codice:

```
!source <io/chars.asm>, once
!source <io/disk_tools.asm>, once
!source <io/keyboard_tools.asm>, once
!source <io/print_tools.asm>, once
```

`disk_tools.asm` e `keyboard_tools.asm` non includono altri file. `print_tools.asm` include a sua volta `vic_ii_tools.asm` della libreria `chip`. `chars.asm` è il modulo principale di un modulo spezzato e include da sé i suoi sotto-moduli (`chars_common.asm`, `chars_asc.asm`, `chars_ecm.asm`, `chars_pet.asm` e `chars_scr.asm`): il programma non li include direttamente. I simboli che i moduli usano arrivano da altri file, che il programma include prima, nella parte dedicata ai simboli (ultima colonna):

| Modulo | Include da sé | File da includere prima |
|---|---|---|
| `chars.asm` | `<io/chars_common.asm>`, `<io/chars_asc.asm>`, `<io/chars_ecm.asm>`, `<io/chars_pet.asm>`, `<io/chars_scr.asm>` | `<system/ascii_7bit.asm>`, `<system/petscii.asm>`, `<system/screencodes.asm>` |
| `disk_tools.asm` | Nessuno | `<c64/kernal.asm>`, `<c64/symbols.asm>`, `<system/petscii.asm>` |
| `keyboard_tools.asm` | Nessuno | `<c64/symbols.asm>`, `<chip/cia.asm>`, `<system/keycodes.asm>` |
| `print_tools.asm` | `<chip/vic_ii_tools.asm>` | `<c64/kernal.asm>`, `<c64/symbols.asm>`, `<chip/vic_ii.asm>`, `<io/chars.asm>`, `<mem/mem16.asm>`, `<system/branch.asm>`, `<system/petscii.asm>`, `<system/standard.asm>` |

### Configurazione

Le macro si assemblano quando vengono invocate. Ogni subroutine viene assemblata solo se il suo parametro vale `1` nella copia di `config.asm` della Soluzione. Nel template tutti i parametri valgono `0`.

| Parametro | Subroutine | Richiede anche |
|---|---|---|
| `__USE_ASC_SCR` | `ASC_SCR` | |
| `__USE_ASC_SCR_C` | `ASC_SCR_C` | |
| `__USE_ASC_PET` | `ASC_PET` | |
| `__USE_ASC_PET_C` | `ASC_PET_C` | |
| `__USE_ASC_ECM` | `ASC_ECM` | |
| `__USE_ASC_ECM_C` | `ASC_ECM_C` | |
| `__USE_ECM_SCR` | `ECM_SCR` | |
| `__USE_ECM_SCR_C` | `ECM_SCR_C` | |
| `__USE_ECM_PET` | `ECM_PET` | |
| `__USE_ECM_PET_C` | `ECM_PET_C` | |
| `__USE_ECM_ASC` | `ECM_ASC` | |
| `__USE_ECM_ASC_C` | `ECM_ASC_C` | |
| `__USE_PET_SCR` | `PET_SCR` | |
| `__USE_PET_SCR_C` | `PET_SCR_C` | |
| `__USE_PET_ASC` | `PET_ASC` | |
| `__USE_PET_ASC_C` | `PET_ASC_C` | |
| `__USE_PET_ECM` | `PET_ECM` | |
| `__USE_PET_ECM_C` | `PET_ECM_C` | |
| `__USE_SCR_PET` | `SCR_PET` | |
| `__USE_SCR_PET_C` | `SCR_PET_C` | |
| `__USE_SCR_ASC` | `SCR_ASC` | |
| `__USE_SCR_ASC_C` | `SCR_ASC_C` | |
| `__USE_SCR_ECM` | `SCR_ECM` | |
| `__USE_SCR_ECM_C` | `SCR_ECM_C` | |
| `__USE_DISK_STATUS` | `DISK_STATUS` |  |
| `__USE_DECODE_DISK_STATUS` | `DECODE_DISK_STATUS` |  |
| `__USE_DISK_DIRECTORY` | `DISK_DIRECTORY` | `__USE_DISK_STATUS` |
| `__USE_DISK_COMMAND` | `DISK_COMMAND` | `__USE_DISK_STATUS` |
| `__USE_KEYSCAN` | `KEYSCAN` |  |
| `__USE_PLOT_CHAR` | `PLOT_CHAR` | `__USE_COMPUTE_CELL_ADDRESS` |
| `__USE_COLOR_CHAR` | `COLOR_CHAR` | `__USE_COMPUTE_CELL_ADDRESS` |
| `__USE_PRINT_MSG` | `PRINT_MSG` |  |
| `__USE_PRINT_NTH` | `PRINT_NTH` | `__USE_PRINT_MSG` |
| `__USE_PRINT_RAW` | `PRINT_RAW` |  |
| `__USE_PRINT_IMM` | `PRINT_IMM` |  |

Punti di personalizzazione usati dalla libreria, definiti anch'essi in `config.asm`:

| Punto di personalizzazione | Usato da | Valore nel template | Significato |
|---|---|---|---|
| `__C128_C64_MODE` | `KEYSCAN` | `0` | Registri e codici extra del C128 (1: da includere) |
| `__BG_COL` | `ASC_ECM`, `ASC_ECM_C`, `ECM_SCR`, `ECM_SCR_C`, `ECM_PET`, `ECM_PET_C`, `ECM_ASC`, `ECM_ASC_C`, `PET_ECM`, `PET_ECM_C`, `SCR_ECM`, `SCR_ECM_C`, `PLOT_CHAR`, `m_Put_ECM_Char` | `$03` | Cella in ZP: selettore del colore di sfondo ECM (0-3) |
| `__KBD_HISTORY` | `KEYSCAN` | `$05` | Cella in ZP: serie storica di KEYSCAN |
| `__PUT_CHAR` | `DISK_DIRECTORY`, `PRINT_MSG`, `PRINT_NTH`, `PRINT_RAW`, `PRINT_IMM`, `m_Put_ECM_Char` | `$FFD2` | Subroutine di stampa di un carattere (CHROUT) |

<a id="modulo-chars"></a>
## chars.asm

Transcodifica dei caratteri tra le codifiche Codice Schermo, PETSCII, ASCII a 7 bit ed ECM (modulo principale).

Requisiti di pagina zero: `__BG_COL`.

Note d'uso del modulo: [Nota #01](#nota-chars-01), [Nota #02](#nota-chars-02), [Nota #03](#nota-chars-03).

### chars_common.asm

Macro comuni alle routine di transcodifica dei caratteri (sotto-modulo di chars.asm): la ricerca di un codice nella tabella delle eccezioni e la sostituzione dei tre bit più significativi del codice con quelli della tabella dei blocchi.

<a id="utilita-m_scan_exceptions"></a>
#### m_Scan_Exceptions

Chiamata: `+m_Scan_Exceptions .table_, .size_, .found_`

Cerca il codice in `.A` nella tabella delle eccezioni. La tabella è formata da coppie di byte (codice sorgente, codice destinazione), una coppia per ogni eccezione, e la ricerca va dall'ultima coppia alla prima.

Se trova il codice, carica in `.A` il codice di destinazione e salta a `.found_`, con `.Y` che contiene la posizione della coppia nella tabella (0 per la prima, 2 per la seconda, e così via). Se non lo trova, prosegue con l'istruzione che segue la macro, con `.A` invariato.

La tabella non può essere vuota e può contenere al massimo 65 coppie (130 byte).

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice sorgente da cercare<br>`.table_` (2 byte, Macro): Indirizzo della tabella delle eccezioni<br>`.size_` (1 byte, Macro): Dimensione della tabella in byte (2 per coppia), da 2 a 130<br>`.found_` (2 byte, Macro): Indirizzo a cui saltare se il codice è nella tabella |
| Output | `.A` (1 byte, CPU): Codice destinazione se trovato, altrimenti invariato<br>`.Y` (1 byte, CPU): Posizione della coppia trovata. Indefinito se il codice non è nella tabella |
| Registri Modificati | `.A`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-m_apply_table"></a>
#### m_Apply_Table

Chiamata: `+m_Apply_Table .table_`

Sostituisce i tre bit più significativi del codice (il suo blocco, da 0 a 7) con quelli della tabella dei blocchi e lascia invariati i cinque bit meno significativi.

La tabella ha 8 byte, uno per blocco: in ognuno contano solo i tre bit più significativi, e gli altri cinque devono essere zero.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice da convertire<br>`.X` (1 byte, CPU): Copia del codice da convertire<br>`.table_` (2 byte, Macro): Indirizzo della tabella dei blocchi |
| Output | `.A` (1 byte, CPU): Codice convertito |
| Registri Modificati | `.A`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

### chars_asc.asm

Transcodifica dei caratteri dalla codifica ASCII a 7 bit alle altre codifiche (sotto-modulo di chars.asm).

<a id="utilita-asc_scr"></a>
#### ASC_SCR

Converte un codice dalla codifica ASCII a 7 bit alla codifica Codice Schermo, senza produrre codici di controllo. La conversione è "glifo per glifo", con i codici ASCII letti come li mostra il set di caratteri #2: da 65 a 90 le lettere maiuscole (i codici da 65 a 90 di Codice Schermo), da 97 a 122 le minuscole (da 1 a 26), da 32 a 63 gli stessi caratteri.

I caratteri ASCII che il Commodore non ha sono sostituiti da caratteri grafici: vedi [Nota #03 di `io/chars.asm`](#nota-chars-03).

I codici di controllo ASCII (da 0 a 31) e il DEL (127) non hanno un glifo: i controlli diventano il glifo inverso del carattere con il codice più 64 (da 128 a 159), e il DEL il codice 102, che somiglia a una cancellazione. La conversione è perfetta: Codice Schermo ha i caratteri inversi.

I codici da 128 a 255, che non sono ASCII a 7 bit, non hanno equivalente: la conversione è impossibile, con il Carry a 1 e `.A` = `$FF`. Nessun codice ASCII ha `$FF` come equivalente, e il Carry a 1 ha solo questo significato.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-asc_scr_c"></a>
#### ASC_SCR_C

Converte un codice dalla codifica ASCII a 7 bit alla codifica Codice Schermo, riconoscendo i codici di controllo. Come `ASC_SCR`, ma i codici di controllo ASCII (da 0 a 31 e il DEL, 127) non hanno un equivalente in Codice Schermo, che non ha codici di controllo: la conversione è impossibile.

Sono impossibili allo stesso modo i codici da 128 a 255, che non sono ASCII a 7 bit. Il Carry a 0 dice che la conversione è riuscita, con la sostituzione del glifo quando serve. Il Carry a 1 dice che è impossibile, con `.A` = `$FF`: nessun codice ASCII ha `$FF` come equivalente.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-asc_pet"></a>
#### ASC_PET

Converte un codice dalla codifica ASCII a 7 bit alla codifica PETSCII, senza produrre codici di controllo. La conversione è "glifo per glifo", con i codici ASCII letti come li mostra il set di caratteri #2: le lettere maiuscole (da 65 a 90) diventano i codici da 193 a 218 e le minuscole (da 97 a 122) i codici da 65 a 90.

I caratteri ASCII che il Commodore non ha sono sostituiti da caratteri grafici: vedi [Nota #03 di `io/chars.asm`](#nota-chars-03). Tra i codici duplicati di PETSCII la routine produce sempre quelli dei blocchi originali (da 160 a 191 e da 192 a 223), mai i duplicati (da 96 a 127 e da 224 a 255).

I codici di controllo ASCII (da 0 a 31) diventano i glifi che Codice Schermo ha con lo stesso codice (i codici da 64 a 95 in PETSCII): il 28 diventa la sterlina e il 31 la freccia a sinistra: PETSCII non ha caratteri inversi, quindi il Carry è a 1 e il carattere va stampato in modalità inversa. Il DEL (127) diventa il codice 166, il glifo che somiglia a una cancellazione, con il Carry a 0.

I codici da 128 a 255, che non sono ASCII a 7 bit, non hanno equivalente: la conversione è impossibile, con il Carry a 1 e `.A` = `$FF`. Il Carry a 1 ha dunque due significati, che si distinguono con un test su `.A`: se vale `$FF` la conversione è impossibile; altrimenti `.A` è un carattere da stampare in modalità inversa (il codice originale in `.X` è minore di 32).

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) o carattere da stampare in modalità inversa |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-asc_pet_c"></a>
#### ASC_PET_C

Converte un codice dalla codifica ASCII a 7 bit alla codifica PETSCII, riconoscendo i codici di controllo. Come `ASC_PET`, ma i codici di controllo ASCII da 0 a 31 restano codici di controllo con lo stesso codice (la conversione è perfetta; il significato dei controlli non viene convertito).

Il DEL (127) non ha un controllo equivalente in PETSCII: diventa il codice 166, il glifo che somiglia a una cancellazione, ma essendo un controllo che diventa stampabile la conversione è imperfetta, con il Carry a 1. I codici da 128 a 255, che non sono ASCII a 7 bit, sono impossibili: Carry a 1 e `.A` = `$FF`. Il Carry a 1 si distingue quindi con un test su `.A`: `$FF` è impossibile, 166 è il DEL.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) o DEL convertito in carattere (`.A` = 166) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-asc_ecm"></a>
#### ASC_ECM

Converte un codice dalla codifica ASCII a 7 bit alla pseudo- codifica ECM, cioè i codici come si interpretano con il modo Colore di Sfondo Esteso attivo, senza produrre codici di controllo. La conversione separa le due informazioni: `.A` riceve il codice del glifo, da 0 a 63, e il selettore del colore di sfondo, da 0 a 3, va in `__BG_COL`. È il risultato di `ASC_SCR` seguita da `SCR_ECM`: le tabelle hanno i codici Schermo.

Il colore di sfondo segue le regole di `PET_ECM`: `BGCOL0` per i codici da 32 a 63, per le lettere minuscole e per @, [, ] e ^; `BGCOL1` per le lettere maiuscole, per i grafici che sostituiscono i caratteri ASCII che il Commodore non ha, tranne ^ (vedi [Nota #03 di `io/chars.asm`](#nota-chars-03)), e per il DEL; `BGCOL2` per i codici di controllo da 0 a 31, che hanno il glifo inverso del carattere con lo stesso codice di Codice Schermo.

I codici da 128 a 255, che non sono ASCII a 7 bit, non hanno equivalente: la conversione è impossibile, con il Carry a 1 e `.A` = `$FF`, e `__BG_COL` non viene modificato. Altrimenti la conversione è sempre perfetta, con il Carry a 0.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit |
| Output | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63) (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3)<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry), `__BG_COL` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-asc_ecm_c"></a>
#### ASC_ECM_C

Converte un codice dalla codifica ASCII a 7 bit alla pseudo- codifica ECM, riconoscendo i codici di controllo. Come `ASC_ECM`, ma ECM, come Codice Schermo, non ha codici di controllo: i codici di controllo ASCII (da 0 a 31 e il DEL, 127) sono impossibili, come lo sono i codici da 128 a 255, che non sono ASCII a 7 bit.

Se la conversione è impossibile il Carry è a 1, `.A` vale `$FF` e `__BG_COL` non viene modificato. Altrimenti il Carry è a 0.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit |
| Output | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63) (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3)<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry), `__BG_COL` |

[↑ Torna al contenuto](#contenuto)

### chars_ecm.asm

Transcodifica dei caratteri dalla pseudo-codifica ECM alle altre codifiche (sotto-modulo di chars.asm).

<a id="utilita-ecm_scr"></a>
#### ECM_SCR

Converte un codice dalla pseudo-codifica ECM, cioè i codici come si interpretano con il modo Colore di Sfondo Esteso attivo, alla codifica Codice Schermo. In ingresso `.A` è il codice del glifo, da 0 a 63, e `__BG_COL` il selettore del colore di sfondo, da 0 a 3: i due bit più significativi di `.A` e i sei più significativi di `__BG_COL` sono ignorati. Il codice Schermo ha il glifo nei sei bit meno significativi e il selettore nei due più significativi. È la conversione inversa di `SCR_ECM`.

Nessuna informazione si perde e non ci sono eccezioni: il Carry è sempre 0. Codice Schermo non ha codici di controllo: `ECM_SCR_C` è identica a `ECM_SCR`.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3) |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo<br>`.X` (1 byte, CPU): Codice Schermo equivalente (glifo e sfondo)<br>Carry (1 bit, .P): sempre 0 |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-ecm_scr_c"></a>
#### ECM_SCR_C

Converte un codice dalla pseudo-codifica ECM alla codifica Codice Schermo, riconoscendo i codici di controllo. Codice Schermo non ha codici di controllo: `ECM_SCR_C` è identica a `ECM_SCR` (vedi `ECM_SCR` per la descrizione).

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3) |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo<br>`.X` (1 byte, CPU): Codice Schermo equivalente (glifo e sfondo)<br>Carry (1 bit, .P): sempre 0 |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-ecm_pet"></a>
#### ECM_PET

Converte un codice dalla pseudo-codifica ECM alla codifica PETSCII, senza produrre codici di controllo. In ingresso `.A` è il codice del glifo, da 0 a 63, e `__BG_COL` il selettore del colore di sfondo, da 0 a 3: i due bit più significativi di `.A` e i sei più significativi di `__BG_COL` sono ignorati. Equivale a `ECM_SCR` seguita da `SCR_PET` ed è la conversione inversa di `PET_ECM`.

`BGCOL0` dà i codici da 32 a 95 e `BGCOL1` i codici da 160 a 223, quelli generati dalla tastiera. `BGCOL2` e `BGCOL3` sono i caratteri inversi, che PETSCII non ha: si restituisce il carattere normale con Carry a 1, che significa che il carattere in `.A` va stampato in modalità inversa. Il glifo 30 con `BGCOL1` o `BGCOL3` è l'aspetto che in ECM ha il pigreco (codice Schermo 94 o 222, di cui il VIC-II ignora i due bit più significativi): diventa 255, come in `SCR_PET`, e non 94 come con `BGCOL0` o `BGCOL2`.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3) |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII<br>`.X` (1 byte, CPU): Codice Schermo equivalente (glifo e sfondo)<br>Carry (1 bit, .P): 0 = conversione perfetta; 1 = il carattere va stampato in modalità inversa |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-ecm_pet_c"></a>
#### ECM_PET_C

Converte un codice dalla pseudo-codifica ECM alla codifica PETSCII, producendo codici di controllo. In ingresso `.A` è il codice del glifo, da 0 a 63, e `__BG_COL` il selettore del colore di sfondo, da 0 a 3: i due bit più significativi di `.A` e i sei più significativi di `__BG_COL` sono ignorati. Equivale a `ECM_SCR_C` seguita da `SCR_PET_C`. Come in `ECM_PET`, `BGCOL0` dà i codici da 32 a 95 e `BGCOL1` i codici da 160 a 223.

I glifi da 0 a 31 con `BGCOL2` e con `BGCOL3` sono i caratteri inversi che in modo Virgolette rappresentano i codici di controllo da 0 a 31 e da 128 a 159, e diventano quei codici (il glifo 30 con `BGCOL3`, che in ECM è l'aspetto del pigreco inverso, diventa 158, il codice di YELLOW). I glifi da 32 a 63 con `BGCOL2` e `BGCOL3` diventano, come in `ECM_PET`, il carattere normale da stampare in modalità inversa.

Il Carry a 0 dice che la conversione è perfetta. Con il Carry a 1 la conversione è imperfetta in uno di due modi, e si distinguono con un test su `.A`: se i bit #6 e #5 di `.A` sono entrambi zero (and #`%01100000` dà zero), `.A` è un codice di controllo; altrimenti `.A` è un carattere stampabile, che va stampato in modalità inversa.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3) |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII<br>`.X` (1 byte, CPU): Codice Schermo equivalente (glifo e sfondo)<br>Carry (1 bit, .P): 0 = conversione perfetta; 1 = conversione imperfetta: `.A` è un codice di controllo o un carattere da stampare in modalità inversa (vedi la Descrizione) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-ecm_asc"></a>
#### ECM_ASC

Converte un codice dalla pseudo-codifica ECM alla codifica ASCII a 7 bit, senza produrre codici di controllo. In ingresso `.A` è il codice del glifo, da 0 a 63, e `__BG_COL` il selettore del colore di sfondo, da 0 a 3: i due bit più significativi di `.A` e i sei più significativi di `__BG_COL` sono ignorati. Equivale a `ECM_SCR` seguita da `SCR_ASC`.

Valgono le regole di `SCR_ASC`: i glifi con `BGCOL0` e `BGCOL1` si convertono nel carattere ASCII che ha lo stesso aspetto, anche con le sostituzioni di glifo (vedi [Nota #03 di `io/chars.asm`](#nota-chars-03)). `BGCOL2` e `BGCOL3` sono i caratteri inversi, che ASCII non ha: la conversione è impossibile, come per i grafici che non somigliano a nessun carattere ASCII. In quel caso il Carry è a 1 e `.A` vale `$FF`, che non è un codice ASCII valido.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3) |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice Schermo equivalente (glifo e sfondo)<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile, con `.A` = `$FF` |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-ecm_asc_c"></a>
#### ECM_ASC_C

Converte un codice dalla pseudo-codifica ECM alla codifica ASCII a 7 bit, producendo codici di controllo. In ingresso `.A` è il codice del glifo, da 0 a 63, e `__BG_COL` il selettore del colore di sfondo, da 0 a 3: i due bit più significativi di `.A` e i sei più significativi di `__BG_COL` sono ignorati. Equivale a `ECM_SCR_C` seguita da `SCR_ASC_C`. Come in `ECM_ASC`, ma i glifi da 0 a 31 con `BGCOL2`, che sono i caratteri inversi da 128 a 159 di Codice Schermo, diventano i codici di controllo da 0 a 31, e il glifo 38 con `BGCOL1`, che somiglia a una cancellazione, diventa il DEL (127).

Il Carry a 0 dice che la conversione è riuscita. Con il Carry a 1 la conversione è impossibile o cambia la semantica, e si distinguono con un test su `.A`: se vale `$FF` la conversione è impossibile; altrimenti `.A` è un codice di controllo (da 0 a 31 oppure 127).

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3) |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice Schermo equivalente (glifo e sfondo)<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) o codice di controllo (vedi la Descrizione) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

### chars_pet.asm

Transcodifica dei caratteri dalla codifica PETSCII alle altre codifiche (sotto-modulo di chars.asm).

<a id="utilita-pet_scr"></a>
#### PET_SCR

Converte un codice dalla codifica PETSCII alla codifica Codice Schermo, senza distinguere i codici di controllo. La conversione è "glifo per glifo": il carattere stampato con il codice di arrivo ha lo stesso aspetto di quello di partenza.

I codici da 32 a 127 e da 160 a 255 sono caratteri normali. Quelli da 96 a 127 e da 192 a 223 sono due codici per lo stesso glifo, come lo sono quelli da 160 a 191 e da 224 a 255. Il pigreco ha due codici (126 e 255): il 255 va nel codice 94 come il 126.

I codici di controllo (da 0 a 31 e da 128 a 159) non hanno un equivalente in Codice Schermo. Si restituisce il glifo che mostrano in modo Virgolette, cioè il carattere inverso (da 128 a 159 e da 192 a 223), e la conversione è perfetta. Per distinguere i codici di controllo si usa `PET_SCR_C`.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione perfetta (sempre); 1 = non si verifica |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-pet_scr_c"></a>
#### PET_SCR_C

Converte un codice dalla codifica PETSCII alla codifica Codice Schermo, riconoscendo i codici di controllo. Come `PET_SCR`, ma i codici di controllo (da 0 a 31 e da 128 a 159) non hanno un equivalente in Codice Schermo, che non ha codici di controllo: la conversione è impossibile.

Il Carry a 0 dice che la conversione è perfetta. Il Carry a 1 dice che la conversione è impossibile, perché il codice è un codice di controllo, e in questo caso `.A` vale `$FF`. Il valore di `.A` non basta a distinguere i due casi, perché `$FF` è anche un Codice Schermo valido (il pigreco inverso): si guarda il Carry.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione perfetta; 1 = conversione impossibile (codice di controllo) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-pet_asc"></a>
#### PET_ASC

Converte un codice dalla codifica PETSCII alla codifica ASCII a 7 bit, senza produrre codici di controllo. La conversione è "glifo per glifo", con i codici ASCII letti come li mostra il set di caratteri #2: le lettere minuscole stanno in 65-90 di PETSCII (e in 1-26 di Codice Schermo) e le maiuscole in 193-218.

I caratteri ASCII che il Commodore non ha sono sostituiti da caratteri grafici: la routine li riconverte nel carattere ASCII che sostituiscono (vedi [Nota #03 di `io/chars.asm`](#nota-chars-03)). I codici duplicati di PETSCII (da 96 a 127 e da 192 a 223, da 160 a 191 e da 224 a 255) danno lo stesso risultato. risultato.

I codici di controllo da 0 a 31 sono trattati come i caratteri di Codice Schermo con lo stesso codice: ASCII ha il glifo corrispondente, ma PETSCII lo mostra inverso in modo Virgolette. Il Carry è quindi a 1 e il carattere in `.A` va stampato in modalità inversa. Non hanno equivalente, con il Carry a 1 e `.A` = `$FF` (non è un codice ASCII valido), i codici da 128 a 159, i grafici che non somigliano a nessun carattere ASCII e i controlli 28 e 31, i cui glifi (sterlina e freccia a sinistra) ASCII non ha.

Il Carry a 1 ha dunque due significati, che si distinguono con un test su `.A`: se vale `$FF` la conversione è impossibile; altrimenti `.A` è un carattere da stampare in modalità inversa (il codice originale in `.X` è minore di 32).

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) o carattere da stampare in modalità inversa |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-pet_asc_c"></a>
#### PET_ASC_C

Converte un codice dalla codifica PETSCII alla codifica ASCII a 7 bit, riconoscendo i codici di controllo. Come `PET_ASC`, ma i codici di controllo da 0 a 31 diventano i codici di controllo ASCII con lo stesso codice, senza convertirne il significato (che in molti casi è diverso), e la conversione è perfetta.

Il codice 166 e il suo duplicato 230, che somigliano a una cancellazione, diventano il DEL (127), un codice di controllo: la conversione è imperfetta, perché ASCII esegue un controllo invece di mostrare il glifo di partenza. In `PET_ASC` sono impossibili.

I codici da 128 a 159, i grafici che non somigliano a nessun carattere ASCII e quelli da 160 a 191 e da 224 a 255 senza equivalente non hanno una conversione: il Carry è a 1 e `.A` vale `$FF`, che non è un codice ASCII valido.

Il Carry a 1 ha dunque due significati, che si distinguono con un test su `.A`: se vale `$FF` la conversione è impossibile; se vale 127 è il codice di controllo DEL.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) o codice di controllo DEL (`.A` = 127) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-pet_ecm"></a>
#### PET_ECM

Converte un codice dalla codifica PETSCII alla pseudo-codifica ECM, cioè i codici come si interpretano con il modo Colore di Sfondo Esteso attivo. La conversione separa le due informazioni: `.A` riceve il codice del glifo, da 0 a 63, e il selettore del colore di sfondo, da 0 a 3, va in `__BG_COL`. È il risultato di `PET_SCR` seguita da `SCR_ECM`.

Il colore di sfondo dipende solo dal blocco di partenza: `BGCOL0` per i codici da 32 a 95, `BGCOL1` per i codici da 96 a 127 e da 160 a 255 (i caratteri ottenuti con SHIFT e i loro duplicati), `BGCOL2` per i codici di controllo da 0 a 31 e `BGCOL3` per quelli da 128 a 159, che il Kernal mostra come caratteri inversi in modo Virgolette. Il glifo è dato dai sei bit meno significativi del codice Schermo: in ECM i grafici non esistono, e i codici da 160 a 191 e da 224 a 255 hanno i glifi da 32 a 63.

Il pigreco ha due codici, 126 e 255. In ECM il VIC-II ignora i due bit più significativi del codice Schermo e quindi mostra il pigreco (codice Schermo 94) come la freccia in su, cioè il glifo 30 con `BGCOL1`: è ciò che si vede sull'hardware reale, non una sostituzione di glifo, e perciò non è una transcodifica nel senso di `<io/chars.asm>`. Il 126 è nella tabella dei blocchi, il 255 è l'unica eccezione. Il Carry è sempre a 0, perché ECM è l'interpretazione dei codici e la routine ne dà l'aspetto. La modalità inversa non è nel codice PETSCII: chi stampa in modalità inversa fa l'OR di `__BG_COL` con `%10`.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII |
| Output | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`.X` (1 byte, CPU): Codice carattere originale<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3)<br>Carry (1 bit, .P): 0 = conversione perfetta (sempre); 1 = non si verifica |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry), `__BG_COL` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-pet_ecm_c"></a>
#### PET_ECM_C

Converte un codice dalla codifica PETSCII alla pseudo-codifica ECM, riconoscendo i codici di controllo. Come `PET_ECM`, ma i codici di controllo (da 0 a 31 e da 128 a 159) non hanno un equivalente in ECM, che come Codice Schermo non ha codici di controllo: la conversione è impossibile.

Il Carry a 0 dice che la conversione è perfetta. Il Carry a 1 dice che è impossibile, perché il codice è un codice di controllo: `.A` vale `$FF` e `__BG_COL` non viene modificato. Il valore di `.A` non basta a distinguere i due casi, perché `$FF` è anche un codice ECM valido: si guarda il Carry.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII |
| Output | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63) (`$FF` se la conversione è impossibile)<br>`.X` (1 byte, CPU): Codice carattere originale<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3)<br>Carry (1 bit, .P): 0 = conversione perfetta; 1 = conversione impossibile (codice di controllo) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry), `__BG_COL` |

[↑ Torna al contenuto](#contenuto)

### chars_scr.asm

Transcodifica dei caratteri dalla codifica Codice Schermo alle altre codifiche (sotto-modulo di chars.asm).

<a id="utilita-scr_pet"></a>
#### SCR_PET

Converte un codice dalla codifica Codice Schermo alla codifica PETSCII, senza produrre codici di controllo. La conversione è "glifo per glifo": il carattere stampato con il codice di arrivo ha lo stesso aspetto di quello di partenza.

I codici da 0 a 127 sono i caratteri normali. Quelli da 64 a 127 hanno in PETSCII due codici, e si restituisce quello generato dalla tastiera (192-223 e 160-191).

I codici da 128 a 255 sono i caratteri inversi, che PETSCII non ha: si restituisce il carattere normale con Carry a 1, che significa che il carattere in `.A` va stampato in modalità inversa.

Il pigreco è un'eccezione: il codice 94 e il codice 222 (il pigreco inverso) diventano 255, il codice che genera la tastiera.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione perfetta; 1 = il carattere va stampato in modalità inversa |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-scr_pet_c"></a>
#### SCR_PET_C

Converte un codice dalla codifica Codice Schermo alla codifica PETSCII, producendo codici di controllo per i caratteri inversi che li rappresentano. La conversione è "glifo per glifo", con i codici di controllo mostrati in modo Virgolette.

I codici da 0 a 127 si convertono come in `SCR_PET`, compreso il pigreco (94 diventa 255). I caratteri inversi da 128 a 159 e da 192 a 223 diventano i codici di controllo da 0 a 31 e da 128 a 159, che in modo Virgolette si vedono con quel glifo inverso; il pigreco inverso (222) diventa quindi 158 (il codice di YELLOW). L'alternativa, che è anche la scelta del Kernal nella lettura dello schermo, sarebbe 255 con il Carry a 1, cioè il pigreco da stampare in modalità inversa: non è adottata. I caratteri inversi da 160 a 191 e da 224 a 255 diventano, come in `SCR_PET`, il carattere normale da stampare in modalità inversa.

Il Carry a 0 dice che la conversione è perfetta. Con il Carry a 1 la conversione è imperfetta in uno di due modi, e si distinguono con un test su `.A`: se i bit #6 e #5 di `.A` sono entrambi zero (and #`%01100000` dà zero), `.A` è un codice di controllo, che mostra il glifo inverso solo se viene stampato in modo Virgolette e fuori dalle virgolette esegue il controllo; altrimenti `.A` è un carattere stampabile, che va stampato in modalità inversa. In ogni caso il bit #7 di `.X` dice che il carattere originale era inverso.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica PETSCII<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione perfetta; 1 = conversione imperfetta: `.A` è un codice di controllo o un carattere da stampare in modalità inversa (vedi la Descrizione) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-scr_asc"></a>
#### SCR_ASC

Converte un codice dalla codifica Codice Schermo alla codifica ASCII a 7 bit, senza produrre codici di controllo. La conversione è "glifo per glifo", con i codici letti come li mostra il set di caratteri #2: da 1 a 26 le lettere minuscole, da 65 a 90 le maiuscole, da 32 a 63 gli stessi caratteri che ha ASCII con quei codici.

I caratteri ASCII che il Commodore non ha sono sostituiti da caratteri grafici: la routine li riconverte nel carattere ASCII che sostituiscono (vedi [Nota #03 di `io/chars.asm`](#nota-chars-03)).

Gli altri codici, cioè i caratteri inversi e i grafici che non somigliano a nessun carattere ASCII, non hanno equivalente: il Carry è a 1 e `.A` vale `$FF`, che non è un codice ASCII valido. Il codice 102, che somiglia a una cancellazione, in questa variante è impossibile, perché il suo equivalente sarebbe il DEL (127), un codice di controllo: lo produce `SCR_ASC_C`.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile, con `.A` = `$FF` |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-scr_asc_c"></a>
#### SCR_ASC_C

Converte un codice dalla codifica Codice Schermo alla codifica ASCII a 7 bit, producendo codici di controllo. Come `SCR_ASC`, con in più due conversioni verso codici di controllo ASCII: i caratteri inversi da 128 a 159 diventano i codici da 0 a 31, e il codice 102, che somiglia a una cancellazione, diventa il DEL, cioè il codice 127.

Il Carry a 0 dice che la conversione è riuscita, con la sostituzione del glifo quando serve. Con il Carry a 1 la conversione è impossibile o cambia la semantica, e si distinguono con un test su `.A`: se vale `$FF` la conversione è impossibile e non ha equivalente ASCII; altrimenti `.A` è un codice di controllo (da 0 a 31 oppure 127), che esegue il controllo invece di mostrare il glifo di partenza.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo |
| Output | `.A` (1 byte, CPU): Codice carattere in codifica ASCII a 7 bit<br>`.X` (1 byte, CPU): Codice carattere originale<br>Carry (1 bit, .P): 0 = conversione riuscita; 1 = conversione impossibile (`.A` = `$FF`) o codice di controllo (vedi la Descrizione) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-scr_ecm"></a>
#### SCR_ECM

Converte un codice dalla codifica Codice Schermo alla pseudo- codifica ECM, cioè i codici come si interpretano con il modo Colore di Sfondo Esteso attivo. In ECM i due bit più significativi del codice scelgono il registro del colore di sfondo (`BGCOL0`-`BGCOL3`) e i sei bit restanti il glifo, da 0 a 63.

La conversione separa le due informazioni: `.A` riceve il codice del glifo, cioè il codice con i due bit più significativi azzerati, e il selettore del colore di sfondo, da 0 a 3, va in `__BG_COL`. Nessuna informazione si perde e non ci sono eccezioni: il Carry è sempre 0.

Codice Schermo non ha codici di controllo: `SCR_ECM_C` è identica a `SCR_ECM`.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo |
| Output | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`.X` (1 byte, CPU): Codice carattere originale<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3)<br>Carry (1 bit, .P): sempre 0 |
| Registri Modificati | `.A`, `.X`, `.P` (Negative, Zero, Carry), `__BG_COL` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-scr_ecm_c"></a>
#### SCR_ECM_C

Converte un codice dalla codifica Codice Schermo alla pseudo- codifica ECM, trattando i codici di controllo. Codice Schermo non ha codici di controllo, quindi la routine è identica a `SCR_ECM` e c'è solo per completare la famiglia di routine: la conversione separa il codice del glifo (i sei bit meno significativi, in `.A`) dal selettore del colore di sfondo (i due bit più significativi, da 0 a 3, in `__BG_COL`). Nessuna informazione si perde: il Carry è sempre 0.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice carattere in codifica Codice Schermo |
| Output | `.A` (1 byte, CPU): Codice del glifo in codifica ECM (da 0 a 63)<br>`.X` (1 byte, CPU): Codice carattere originale<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (da 0 a 3)<br>Carry (1 bit, .P): sempre 0 |
| Registri Modificati | `.A`, `.X`, `.P` (Negative, Zero, Carry), `__BG_COL` |

[↑ Torna al contenuto](#contenuto)

### Note d'uso di `chars.asm`

<a id="nota-chars-01"></a>
#### Nota #01

Un Commodore a 8 bit riconosce 256 codici carattere. Un codice diventa visibile quando il chip video lo associa a un glifo, cioè a un disegno del set di caratteri: i set sono due, il #1 "Maiuscolo/Grafici" e il #2 "Minuscolo/Maiuscolo". L'aspetto del glifo non cambia il significato del codice, che dipende soltanto dalla codifica.

I codici sono di due tipi: stampabili, che producono un glifo, e di controllo, che eseguono un'azione. In modo Virgolette e in modo Inserimento i codici di controllo perdono l'azione e mostrano un glifo.

**Le codifiche**

La libreria converte tra quattro codifiche:

- Codice Schermo: la codifica più vicina all'hardware, quella in cui sono scritti i 40x25 caratteri della memoria video. Tutti i codici sono stampabili, non esistono codici di controllo e a ogni codice corrisponde un solo glifo. I codici da 0 a 127 sono i caratteri normali, quelli da 128 a 255 gli stessi caratteri in modalità inversa.

- PETSCII: la codifica del BASIC e del Kernal (funzioni `ASC` e `CHR$`). Ha i codici di controllo, e non ha i caratteri inversi: in modo Virgolette il Kernal mostra i controlli con un glifo inverso, senza ambiguità con i glifi stampabili. Alcuni codici sono duplicati: il BASIC normalizza i codici da 96 a 127 in quelli da 192 a 223 e i codici da 224 a 255 in quelli da 160 a 191, quindi i duplicati condividono i glifi.

- ASCII a 7 bit: non è nativa del Commodore, ma serve per lo scambio con altre architetture. Ha solo 128 codici, con i controlli da 0 a 31 e il 127 (DEL), e non ha né i caratteri inversi né i grafici del Commodore.

- ECM: non è una codifica in senso stretto, ma l'interpretazione del Codice Schermo quando è attivo il modo Colore di Sfondo Esteso. I due bit più significativi scelgono il registro del colore di sfondo (`BGCOL0`-`BGCOL3`) e gli altri sei il glifo, da 0 a 63: il glifo è nel codice, lo sfondo in `__BG_COL`. Si tratta come una codifica perché il suo codice contiene un'informazione di colore che le altre non hanno. Poiché il VIC-II ignora i due bit più significativi, i glifi oltre il 63 non esistono: il pigreco (codice Schermo 94) appare come la freccia in su (glifo 30), come sull'hardware reale.

**I blocchi**

I 256 codici si dividono in otto blocchi da 32, numerati da 0 a 7 (0 = 0-31, 1 = 32-63 e così via): il blocco è nei tre bit più significativi del codice, e le regole di transcodifica si esprimono meglio con i blocchi.

| Blocco | Codici | Codice Schermo | PETSCII | ASCII |
|---|---|---|---|---|
| 0 | 0-31 | normali | controlli | controlli |
| 1 | 32-63 | normali | stampabili | stampabili |
| 2 | 64-95 | normali | stampabili | stampabili |
| 3 | 96-127 | normali | duplicati del 6 | stampabili |
| 4 | 128-159 | inversi | controlli | inesistenti |
| 5 | 160-191 | inversi | stampabili | inesistenti |
| 6 | 192-223 | inversi | stampabili | inesistenti |
| 7 | 224-255 | inversi | duplicati del 5 | inesistenti |

In ASCII anche il codice 127 è di controllo. In ECM il blocco dice il registro di sfondo: 0 e 1 `BGCOL0`, 2 e 3 `BGCOL1`, 4 e 5 `BGCOL2`, 6 e 7 `BGCOL3`, con gli stessi glifi nei blocchi pari e nei dispari.

<a id="nota-chars-02"></a>
#### Nota #02

Una transcodifica non può mai essere senza perdite: Codice Schermo non ha i controlli, PETSCII e ASCII non hanno i caratteri inversi, ASCII non ha molti glifi del Commodore, ECM porta nel codice un colore che le altre codifiche non hanno. Ciò che il codice di arrivo non può conservare si conserva altrove, in `__BG_COL`, oppure si segnala con il Carry. Le routine seguono cinque criteri, in quest'ordine.

1. Glifo per glifo.

Una conversione conserva l'aspetto del carattere, non il codice né il significato: il codice di arrivo è quello che rappresenta lo stesso glifo di quello di partenza. I codici di controllo non si traducono nel loro effetto: si convertono nel glifo che mostrano.

2. Un solo codice per glifo.

Quando più codici hanno lo stesso glifo si sceglie sempre quello primario, mai il duplicato: in arrivo su PETSCII i blocchi 5 e 6, non i blocchi 7 e 3 (il pigreco è l'unica eccezione dichiarata).

3. Le transcodifiche si compongono.

Convertire in due passi, passando per una terza codifica, dà lo stesso risultato della conversione diretta. Vale per i caratteri stampabili; i codici di controllo seguono il criterio 5.

4. Andata e ritorno.

Convertire un codice e riconvertire il risultato nella codifica di partenza restituisce il codice originale a tre condizioni: le due conversioni sono perfette (Carry a 0), usano la stessa variante (entrambe senza controlli o entrambe con) e il codice di partenza è un codice primario. I duplicati di PETSCII tornano come il codice primario con lo stesso glifo (il pigreco, 126 o 255, torna sempre come 255). Con ECM il colore di sfondo, che è in `__BG_COL`, deve restare intatto tra le due chiamate.

5. Ciò che non si conserva si dichiara.

Con il Carry a 0 il carattere di arrivo ha l'aspetto di quello di partenza, o del sostituto grafico previsto per i caratteri ASCII che il Commodore non ha. Altrimenti il Carry è a 1: la conversione è imperfetta e si restituisce il meglio possibile (per esempio il glifo normale da stampare in modalità inversa), oppure è impossibile e `.A` vale `$FF`. Nei contratti ogni routine dice come leggere il Carry a 1.

<a id="nota-chars-03"></a>
#### Nota #03

Otto caratteri ASCII non hanno un glifo uguale nei set di caratteri del C64: la barra inversa, il circonflesso, il carattere di sottolineatura, l'accento grave, le due graffe, la barra verticale e la tilde. Le routine li sostituiscono con grafici che somigliano all'originale e che hanno lo stesso glifo nel set #1 e nel set #2 (con lo stesso codice), in modo che la conversione non dipenda dal set attivo né da un set personalizzato. La sostituzione è reversibile: nel verso opposto il grafico torna a essere il carattere che sostituisce, e la conversione è perfetta (Carry a 0).

| ASCII | Carattere | Codice Schermo | PETSCII | Grafico che lo sostituisce |
|---|---|---|---|---|
| 92 | barra inversa | 127 | 191 | due quarti di blocco opposti |
| 94 | circonflesso | 30 | 94 | freccia in su |
| 95 | sottolineato | 100 | 164 | linea in basso |
| 96 | accento grave | 109 | 173 | angolo in basso a sinistra |
| 123 | graffa aperta | 115 | 179 | tratto con ramo a sinistra |
| 124 | barra verticale | 93 | 221 | tratto verticale |
| 125 | graffa chiusa | 107 | 171 | tratto con ramo a destra |
| 126 | tilde | 64 | 192 | linea a metà altezza |

I controlli ASCII da 0 a 31 e il DEL (127) non hanno un glifo, e anche qui la scelta è di progetto, non una sostituzione: ASCII non ha una convenzione. I controlli sono rappresentati dai caratteri inversi di Codice Schermo da 128 a 159 e il DEL dal codice 102, una trama a scacchiera.

[↑ Torna al contenuto](#contenuto)

<a id="modulo-disk_tools"></a>
## disk_tools.asm

Utilità per la gestione delle unità disco.

<a id="utilita-disk_status"></a>
### DISK_STATUS

Legge il messaggio di stato dell'unità disco dal canale comandi (file logico 15, indirizzo secondario 15) e lo scrive in `STACK`, la base della pagina dello stack, terminato da `$00`: il carattere di ritorno a capo (`$0D`) che chiude il messaggio è sostituito dallo zero finale. Il messaggio occupa al massimo 256 byte ed è sovrascritto a ogni chiamata, quindi il chiamante lo usa subito (per esempio con `STROUT`). Se il canale non si apre il buffer non viene scritto.

Il flag di Carry dice solo se il messaggio è stato letto, non se il disco ha segnalato un errore: per estrarne il codice si usa `DECODE_DISK_STATUS`.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Numero dell'unità disco |
| Output | `STACK` (fino a 256 byte, RAM): Messaggio di stato terminato da `$00`<br>Carry (1 bit, .P): 0 = messaggio letto; 1 = canale non aperto |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), `STACK` (fino a 256 byte) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-decode_disk_status"></a>
### DECODE_DISK_STATUS

Decodifica il messaggio di stato dell'unità disco contenuto in `STACK` (scritto da `DISK_STATUS`) e restituisce il codice dell'errore e gli altri due numeri del messaggio. Il messaggio ha la forma "NN,`MESSAGGIO`,TT,SS", dove le virgole fanno parte del messaggio e le virgolette no: NN è il codice dell'errore, `MESSAGGIO` una stringa descrittiva, TT e SS di norma la traccia e il settore in cui è avvenuto l'errore (in alcuni casi hanno un altro significato). Senza errori il messaggio è "00,OK,00,00". I tre numeri hanno due cifre e si restituiscono in binario, da 0 a 99. Il messaggio non viene alterato e non supera i 40 caratteri: la ricerca della virgola che precede TT si ferma alla quarantesima posizione.

Il controllo del formato è minimo: la decodifica si ferma al primo carattere diverso da quello previsto e in quel caso `.A`, `.X` e `.Y` sono indefiniti. Il flag di Carry dice solo se il messaggio è stato decodificato, non se il disco ha segnalato un errore: per saperlo il chiamante guarda `.A` (0 = nessun errore).

| Voce | Contenuto |
|---|---|
| Input | `STACK` (fino a 40 byte, RAM): Messaggio di stato terminato da `$00` |
| Output | `.A` (1 byte, CPU): Codice dell'errore (NN)<br>`.X` (1 byte, CPU): Primo numero dopo il messaggio (TT)<br>`.Y` (1 byte, CPU): Secondo numero dopo il messaggio (SS)<br>Carry (1 bit, .P): 0 = messaggio decodificato; 1 = formato non valido |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry) |
| Assembla anche | `DISK_GET_NUMBER` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-disk_directory"></a>
### DISK_DIRECTORY

Stampa la directory del disco dell'unità indicata, una voce per linea: la lunghezza in blocchi, uno spazio e il nome. Apre un canale dati (file logico 88, indirizzo secondario 0), legge la directory come un programma e stampa ogni linea con `__PUT_CHAR`.

I file da elencare si scelgono con un pattern: una stringa terminata da `$00` puntata da `INDEX` (per esempio "`$0`"). La subroutine ne calcola la lunghezza e lo passa al sistema operativo dell'unità senza altri controlli: un pattern nullo o più lungo di 40 caratteri è un errore, e la subroutine esce subito con il Carry a 1 senza stampare nulla. Un pattern non valido per l'unità produce invece un errore dell'unità, trattato come ogni altro.

Il flag di Carry è l'esito: se si verifica un errore dell'unità la subroutine va a capo, stampa il messaggio di stato dell'unità (letto con `DISK_STATUS`) ed esce con il Carry a 1. La stampa dei numeri e del messaggio usa `LINPRT` e `STROUT` del BASIC, che alterano proprie celle di lavoro (tra cui `FAC`): il loro contenuto non è garantito dopo la chiamata.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Numero dell'unità disco<br>`INDEX` (2 byte, ZP): Puntatore al pattern, terminato da `$00` |
| Output | Carry (1 bit, .P): 0 = directory stampata; 1 = pattern errato, canale non aperto o errore dell'unità |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), `STACK` (fino a 256 byte) |
| Richiede | `__USE_DISK_STATUS = 1` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-disk_command"></a>
### DISK_COMMAND

Invia un comando `DOS` all'unità disco indicata. Il comando è una stringa terminata da `$00` puntata da `INDEX` e non può essere vuoto né superare i 40 caratteri: il `DOS` dell'unità tronca un comando più lungo, con risultati imprevedibili. La subroutine rifiuta un comando non valido senza inviarlo ed esce con il Carry a 1.

Il comando si invia aprendo il canale comandi (indirizzo secondario 15) con la stringa come nome del file: l'`OPEN` è tutto ciò che serve. Il file logico non può essere il 15, perché `DISK_STATUS` apre per conto suo il file logico 15 e l'`OPEN` fallirebbe se fosse già aperto: la subroutine usa il file logico 88, lo stesso di `DISK_DIRECTORY`, e lo chiude dopo la lettura dello stato.

Il messaggio di stato con cui il `DOS` risponde al comando si legge con `DISK_STATUS` e si scrive in `STACK`, terminato da `$00`: occupa al massimo 256 byte e il chiamante lo usa subito (per esempio con `STROUT`, o con `DECODE_DISK_STATUS` per ricavarne il codice dell'errore). Il flag di Carry dice solo se il comando è stato inviato e lo stato letto, non se l'unità ha segnalato un errore. Se il canale comandi non si apre il comando non parte e `STACK` non viene scritto. Se invece non si riesce a leggere lo stato, il comando è comunque partito ma il Carry vale 1 e `STACK` non viene scritto.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Numero dell'unità disco<br>`INDEX` (2 byte, ZP): Puntatore al comando, terminato da `$00` |
| Output | `STACK` (fino a 256 byte, RAM): Messaggio di stato terminato da `$00`, non scritto se il comando non è inviato<br>Carry (1 bit, .P): 0 = comando inviato; 1 = errore (comando vuoto o più lungo di 40 caratteri, canale non aperto o stato non letto) |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), `STACK` (fino a 256 byte) |
| Richiede | `__USE_DISK_STATUS = 1` |

[↑ Torna al contenuto](#contenuto)

<a id="modulo-keyboard_tools"></a>
## keyboard_tools.asm

Lettura diretta della tastiera dalla matrice del CIA #1, senza passare dal Kernal. Deriva da quella del gioco Platoon, accorciata e con la serie storica integrata.

Requisiti di pagina zero: `__KBD_HISTORY`.

Note d'uso del modulo: [Nota #01](#nota-keyboard_tools-01), [Nota #02](#nota-keyboard_tools-02), [Nota #03](#nota-keyboard_tools-03), [Nota #04](#nota-keyboard_tools-04), [Nota #05](#nota-keyboard_tools-05).

<a id="utilita-keyscan"></a>
### KEYSCAN

Verifica se un tasto, indicato dal suo codice tastiera, è stato appena premuto. Legge la matrice della tastiera direttamente dal CIA #1 e presuppone che i registri di direzione delle sue due porte abbiano i valori predefiniti (`$FF` e `$00`).

Non cerca il tasto premuto e non ne restituisce il codice tastiera: il codice tastiera è un dato in ingresso.

Un codice tastiera da `KEYCODE_NO_KEY` in su non è valido: la subroutine esce subito con il Carry a 1, senza toccare le porte.

Il codice tastiera è la posizione del tasto nella matrice, cioè la riga per 8 più la colonna (`KEYCODE_*`, da `$00` a `$3F`). La serie storica, `__KBD_HISTORY`, è un solo byte: contiene la maschera della colonna finché il tasto resta premuto e vale zero dopo il rilascio.

Il Carry segnala il falso tasto: la colonna risulta bassa anche senza nessuna riga selezionata, quindi la causa è l'interferenza del joystick e non la tastiera. Con il Carry a 0 il flag di Negative dice se il tasto è premuto e il flag di Zero se la pressione è nuova.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice tastiera del tasto da scansionare<br>`__KBD_HISTORY` (1 byte, ZP): Serie storica, da azzerare prima del primo uso |
| Output | `__KBD_HISTORY` (1 byte, ZP): Serie storica aggiornata<br>Negative (1 bit, .P): 0 = tasto non premuto; 1 = tasto premuto (nuova pressione o tenuto). Indefinito se Carry = 1<br>Zero (1 bit, .P): 0 = nuova pressione; 1 = tasto non premuto o ancora tenuto. Indefinito se Carry = 1<br>Carry (1 bit, .P): 0 = lettura valida; 1 = falso tasto o codice tastiera non valido |
| Registri Modificati | `.A`, `.P` (Negative, Zero, Carry), `CIAPRA`, `CIAPRB`, `__KBD_HISTORY` |

[↑ Torna al contenuto](#contenuto)

### Note d'uso di `keyboard_tools.asm`

<a id="nota-keyboard_tools-01"></a>
#### Nota #01

`KEYSCAN` non cerca quale tasto sia premuto e non restituisce il codice tastiera di un tasto: fa l'inverso. Riceve il codice tastiera di un tasto e verifica se quel tasto è stato appena premuto. Non è adatta a scoprire quale tasto sia premuto tra tutti, perché non scansiona l'intera matrice.

`KEYSCAN` controlla un tasto per volta e va chiamata a ogni passaggio di lettura. Segnala una nuova pressione una sola volta: finché il tasto resta premuto, le chiamate successive non riportano niente di nuovo. Un codice tastiera non valido (da `KEYCODE_NO_KEY` in su) è un errore, come il falso tasto. Con il Carry a 0, il flag di Negative dice se il tasto è premuto e il flag di Zero se la pressione è nuova. Gli esempi sono nelle note da [Nota #03](#nota-keyboard_tools-03) in poi.

<a id="nota-keyboard_tools-02"></a>
#### Nota #02

La serie storica, la cella in pagina zero `__KBD_HISTORY`, è un solo byte, condiviso da tutti i tasti: finché il tasto resta premuto contiene la sola colonna, non la riga, e al rilascio viene azzerata. Il chiamante la azzera prima del primo uso. Quindi si controlla un tasto per volta: se nello stesso passaggio si scansionano tasti diversi, le chiamate si disturbano a vicenda e `KEYSCAN` segnala una nuova pressione a ogni passaggio finché uno dei tasti resta premuto. Due tasti della stessa colonna, poi, non si distinguono tra loro.

<a id="nota-keyboard_tools-03"></a>
#### Nota #03

Uso base: una scansione a ogni passaggio, per esempio dentro un gestore IRQ. Il Carry a 1 segnala un errore, il flag di Zero a 0 una nuova pressione.

```
Esempio:

  lda #KEYCODE_SPACE            ; Tasto da scansionare.
  jsr KEYSCAN
  bcs .Exit_Handler             ; Falso tasto: ignora la lettura.

  beq .Exit_Handler             ; Nessuna nuova pressione.

  inc EXTCOL                    ; Nuova pressione: cambia il bordo.

.Exit_Handler:
  rts
```

<a id="nota-keyboard_tools-04"></a>
#### Nota #04

Debouncing. I contatti della tastiera rimbalzano per qualche millisecondo, sia premendo sia rilasciando il tasto. Il flag di Negative dice se il tasto è ancora premuto: una nuova pressione si conferma al passaggio successivo, e se il tasto non è più premuto era solo un rimbalzo. Lo snippet è per un gestore IRQ chiamato a ogni fotogramma, e _CANDIDATE è una cella di RAM del programma, azzerata all'avvio. Esempio:

```
  lda #KEYCODE_SPACE            ; Tasto da scansionare.
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
  lda #KEYCODE_SPACE            ; REPEAT
  jsr KEYSCAN
  bcs .Loop_Scan_Press          ; Falso tasto: riprova.

.Loop_Check_Press:
  beq .Loop_Scan_Press          ; REPEAT UNTIL: nuova pressione

  inc EXTCOL                    ; Tasto premuto: cambia il bordo.

.Loop_Poll_Release:
  lda #KEYCODE_SPACE            ; REPEAT
  jsr KEYSCAN
  bcs .Loop_Poll_Release        ; Falso tasto: riprova.

.Loop_Check_Release:
  bmi .Loop_Poll_Release        ; REPEAT UNTIL: tasto non premuto
```

[↑ Torna al contenuto](#contenuto)

<a id="modulo-print_tools"></a>
## print_tools.asm

Utilità per la stampa di caratteri, messaggi e tabelle di messaggi con supporto per il modo a Colore di Sfondo Esteso.

Requisiti di pagina zero: `__BG_COL`.

Note d'uso del modulo: [Nota #01](#nota-print_tools-01), [Nota #02](#nota-print_tools-02), [Nota #03](#nota-print_tools-03).

<a id="utilita-m_at"></a>
### m_At

Chiamata: `+m_At .row_, .col_`

Posiziona il cursore sulla riga e sulla colonna specificata dello schermo corrente, usando la chiamata `PLOT` del Kernal.

| Voce | Contenuto |
|---|---|
| Input | `.row_` (1 byte, Macro): Riga (0-24)<br>`.col_` (1 byte, Macro): Colonna (0-39) |
| Output | Nessuno |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry) |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-plot_char"></a>
### PLOT_CHAR

Scrive un carattere sullo schermo alla riga e colonna specificate e supporta in modo trasparente il modo Colore di Sfondo Esteso. Se questo modo è attivo il codice Schermo del carattere è automaticamente riportato all'intervallo 0-63 e viene scritto utilizzando il registro colore che è codificato in `__BG_COL`:

```
__BG_COL = 0: Usa il colore memorizzato in BGCOL0
__BG_COL = 1: Usa il colore memorizzato in BGCOL1
__BG_COL = 2: Usa il colore memorizzato in BGCOL2
__BG_COL = 3: Usa il colore memorizzato in BGCOL3
```

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice Schermo del carattere<br>`.X` (1 byte, CPU): Colonna della cella (0-39)<br>`.Y` (1 byte, CPU): Riga della cella (0-24)<br>`__BG_COL` (1 byte, ZP): Selettore del registro di sfondo (0-3), solo in ECM |
| Output | `Cella` (1 byte, RAM): Cella dello schermo alla riga e colonna indicate |
| Registri Modificati | `.P` (Negative, oVerflow, Zero, Carry), `INDEX2` |
| Richiede | `__USE_COMPUTE_CELL_ADDRESS = 1` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-color_char"></a>
### COLOR_CHAR

Imposta il colore di primo piano del carattere localizzato alla colonna ed alla riga specificati.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice del colore (0-15)<br>`.X` (1 byte, CPU): Colonna della cella (0-39)<br>`.Y` (1 byte, CPU): Riga della cella (0-24) |
| Output | `Cella` (1 byte, RAM): Cella della memoria colore indicata da `.X` e `.Y` |
| Registri Modificati | `.P` (Negative, oVerflow, Zero, Carry), `INDEX2` |
| Richiede | `__USE_COMPUTE_CELL_ADDRESS = 1` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-print_msg"></a>
### PRINT_MSG

`PRINT_MSG` percorre attraverso chiamate successive una tavola di messaggi [Nota #01](#nota-print_tools-01). L'indirizzo iniziale della tavola è dato da un puntatore in ZP e l'indirizzo del puntatore è fornito in `.A`: alla prima chiamata viene stampato il primo messaggio: in caso di successo il flag di Carry è uguale a zero ed il puntatore in ZP incrementato all'inizio del messaggio successivo. Il raggiungimento della fine della tavola è segnalato da Carry = 1: successive chiamate non avranno effetto finché il puntatore non viene reinizializzato all'indirizzo iniziale della tavola.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Indirizzo in ZP del puntatore alla tavola<br>`Puntatore` (2 byte, ZP): Indirizzo del prossimo messaggio da stampare |
| Output | `Puntatore` (2 byte, ZP): Messaggio successivo o marcatore di fine tavola<br>Carry (1 bit, .P): 0 = messaggio stampato; 1 = tavola terminata |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), puntatore in ZP |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-print_nth"></a>
### PRINT_NTH

`PRINT_NTH` stampa un messaggio singolo estraendolo da una tavola di messaggi [Nota #01](#nota-print_tools-01). L'indirizzo iniziale della tavola è dato da un puntatore in ZP e l'indirizzo del puntatore è fornito in `.A` mentre il numero d'ordine del messaggio è fornito in `.Y` (il primo messaggio ha indice 0).

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Indirizzo in ZP del puntatore alla tavola<br>`.Y` (1 byte, CPU): Indice del messaggio (0 = il primo)<br>`Puntatore` (2 byte, ZP): Indirizzo iniziale della tavola |
| Output | Carry (1 bit, .P): 0 = messaggio stampato; 1 = indice oltre la fine |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry) |
| Richiede | `__USE_PRINT_MSG = 1` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-print_raw"></a>
### PRINT_RAW

La subroutine `PRINT_RAW` stampa una stringa di testo il cui indirizzo è puntato da `.YA`: è pensata come sostituto della subroutine di sistema `STROUT` in quanto non altera il contenuto di `FAC` o `ARG`. Per mantenere la compatibilità con `STROUT` questa è l'unica subroutine di stampa che non supporta i due byte di posizionamento sullo schermo che precedono il messaggio.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Byte basso dell'indirizzo della stringa<br>`.Y` (1 byte, CPU): Byte alto dell'indirizzo della stringa |
| Output | Nessuno |
| Registri Modificati | `.A`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), `INDEX2` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-print_imm"></a>
### PRINT_IMM

La subroutine `PRINT_IMM` stampa un messaggio (formattato come un elemento di una tavola di messaggi [Nota #01](#nota-print_tools-01)) inserito nel codice sorgente immediatamente dopo la sua chiamata:

```
jsr PRINT_IMM
!text $FF, $00, "Hello, world!", $0D, $00
```

| Voce | Contenuto |
|---|---|
| Input | `Messaggio` (n byte, RAM): Dati dopo la chiamata (vedi [Nota #01](#nota-print_tools-01)) |
| Output | Nessuno |
| Registri Modificati | `.A`, `.X`, `.Y`, `.P` (Negative, oVerflow, Zero, Carry), `INDEX2` |

[↑ Torna al contenuto](#contenuto)

<a id="utilita-m_put_ecm_char"></a>
### m_Put_ECM_Char

Questa macro non è pensata per essere usata a sé stante, ma come mattone da costruzione per un proprio driver di stampa da utilizzare nel punto di configurazione `__PUT_CHAR` [Nota #02](#nota-print_tools-02): infatti la macro non termina con un RTS ma con un salto alla fine del suo codice in modo da poter essere concatenata con altre istruzioni [Nota #02](#nota-print_tools-02). Nello specifico questa macro implementa la logica per stampare a schermo un carattere PETSCII in modo ECM con il colore di sfondo desiderato. La macro si aspetta in `.A` il codice PETSCII del carattere da stampare e restituisce `.A`, `.X` e `.Y` invariati.

I codici di controllo (0-31 e 128-159) sono trattati così: 0, 18 (`{RVS}` ON) e 146 (`{RVS}` OFF) sono ignorati, perché il modo reverse è deciso da `__BG_COL`; quattro codici PETSCII non utilizzati dal sistema operativo (1-4) sono reinterpretati come codici di controllo che, come gli altri, hanno effetto fino al loro cambiamento: essi sono `ECM_BG`[0-3] e selezionano il registro del VIC-II contenente il colore di sfondo da utilizzare, senza stampare nulla [Nota #03](#nota-print_tools-03); tutti gli altri sono inviati a `CHROUT` senza modifiche.

Gli altri codici PETSCII sono stampabili. Il codice è normalizzato, cioè portato nell'intervallo 32-95 in cui il modo ECM ha i suoi glifi, sostituendo i 3 bit più significativi secondo la tabella `.NORM_TABLE` (con la macro `m_Apply_Table` di `<io/chars.asm>`). Non è una transcodifica nel senso di `<io/chars.asm>`, che conserva il glifo: in modo ECM il VIC-II ignora i due bit più significativi del codice Schermo, quindi la normalizzazione dà il codice il cui glifo è quello che l'hardware mostrerebbe comunque. Per esempio il pigreco (255) è stampato come la freccia in su: il suo codice 255 diventa 94, e questo caso, che la tabella non copre, è trattato a parte con la macro `m_Scan_Exceptions`. Poi il bit #0 di `__BG_COL` è copiato nel bit #7 del codice normalizzato e il bit #1 di `__BG_COL` decide il modo reverse (`RVS` = 0 normale, 1 inverso); il codice è infine inviato a `CHROUT`. `__BG_COL` non cambia.

| Voce | Contenuto |
|---|---|
| Input | `.A` (1 byte, CPU): Codice PETSCII da stampare<br>`__BG_COL` (1 byte, ZP): Selettore del colore di sfondo (0-3) |
| Output | `__BG_COL` (1 byte, ZP): Nuovo selettore (se il codice è `ECM_BG`[0-3])<br>`RVS` (1 byte, ZP): Modo reverse (bit #1 di `__BG_COL`), se il codice è stampabile |
| Registri Modificati | `.P` (Negative, oVerflow, Zero, Carry), `__BG_COL`, `RVS` |

[↑ Torna al contenuto](#contenuto)

### Note d'uso di `print_tools.asm`

<a id="nota-print_tools-01"></a>
#### Nota #01

Le subroutine `PRINT_MSG` e `PRINT_NTH` lavorano su elenchi di messaggi organizzati in tavole. Ciascun messaggio è organizzato nel seguente formato:

```
  !text <riga>, <colonna>, "messaggio", $00
```

`<riga>` e `<colonna>` sono due byte che indicano la posizione sullo schermo alla quale andrà stampato il messaggio.

Se `<riga>` == `$FF` e `<colonna>` != `$FF` il messaggio è stampato alla posizione corrente del cursore.

Se `<riga>` == `$FF` e `<colonna>` == `$FF` la tavola è terminata.

<a id="nota-print_tools-02"></a>
#### Nota #02

Le subroutine `PRINT_*` possono essere personalizzate con una propria subroutine di stampa (il driver), assegnando la sua etichetta al punto di personalizzazione `__PUT_CHAR` in config.asm, per esempio `__PUT_CHAR` = `PUT_CHAR_ECM`.

Esempio 1: Driver di stampa in modo ECM.

```
PUT_CHAR_ECM:
  +m_Put_ECM_Char               ; Stampa il carattere in modo ECM

.Exit_PUT_CHAR_ECM:
  rts
```

Esempio 2: Driver di stampa in modo ECM a doppia spaziatura.

```
PUT_CHAR_ECM_WIDE:
  +m_Put_ECM_Char               ; Stampa il carattere in modo ECM
  lda #PETSCII_CURSOR_RIGHT     ; Codice PETSCII per spostare il cursore
                                ; a destra di una posizione
  jsr CHROUT

.Exit_PUT_CHAR_ECM_WIDE:
  rts
```

Esempio 3: Driver di stampa in verticale.

```
PUT_CHAR_VERTICAL:
  jsr CHROUT                    ; Stampa il carattere

  lda #PETSCII_CURSOR_DOWN      ; Codice PETSCII per spostare il cursore
                                ; in basso di una posizione
  jsr CHROUT
  lda #PETSCII_CURSOR_LEFT      ; Codice PETSCII per spostare il cursore
                                ; a sinistra di una posizione
  jsr CHROUT

.Exit_PUT_CHAR_VERTICAL:
  rts
```

<a id="nota-print_tools-03"></a>
#### Nota #03

Esempio di messaggio che utilizza i codici `ECM_BG`[0-3]:

```
  !text $FF, $00, ECM_BG0, "Hello, ", ECM_BG1, "world!", ECM_BG0, $00
```

L'ultimo `ECM_BG0` serve a ripristinare il colore di sfondo iniziale altrimenti eventuali messaggi seguenti sarebbero stampati con il colore di sfondo `ECM_BG1`.

[↑ Torna al contenuto](#contenuto)

<a id="limiti-noti"></a>
## Limiti noti

- `DISK_COMMAND` non è ancora stato provato con un'unità disco reale.
- `KEYSCAN` con `__C128_C64_MODE = 1`: `KEYCODE_NO_KEY` vale `$58`, quindi i codici extra del C128 da `$40` a `$57` superano il controllo di validità e la lettura della matrice non ha senso. I tasti extra del C128 si leggono da altre porte e richiedono un ramo dedicato, non ancora scritto.
- `KEYSCAN` e il joystick nella porta 2: il controllo del falso tasto è costruito sul joystick nella porta 1. L'influenza del joystick nella porta 2, che si legge sulla porta usata per selezionare le righe, non è stata ancora verificata.
- `KEYSCAN` controlla un tasto per volta e non distingue due tasti della stessa colonna ([Nota #02](#nota-keyboard_tools-02)).

- `PRINT_MSG`, `PRINT_RAW` e `PRINT_IMM` dipendono dai registri di `__PUT_CHAR` (B15): `PRINT_MSG` si aspetta il registro `.X` invariato dopo ogni `jsr __PUT_CHAR`, `PRINT_RAW` e `PRINT_IMM` il registro `.Y`. `CHROUT` li preserva, ma una subroutine di stampa personalizzata no: in quel caso il puntatore in pagina zero (indicizzato con `.X`) o l'indice del loop (`.Y`, che vale 0) verrebbero alterati e la subroutine leggerebbe o scriverebbe nella locazione sbagliata. `PRINT_NTH` dipende da `.X` in modo indiretto, tramite `PRINT_MSG`. Finché non è corretto, la subroutine usata come `__PUT_CHAR` deve preservare `.X` e `.Y` ([Nota #02](#nota-print_tools-02)).

[↑ Torna al contenuto](#contenuto)
