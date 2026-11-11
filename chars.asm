; ==============================================================================
; FILE:           chars.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Transcodifica dei caratteri tra le codifiche Codice Schermo,
;                 PETSCII, ASCII a 7 bit ed ECM (modulo principale).
; DIPENDENZE:     <io/chars_common.asm>
;                 <io/chars_asc.asm>
;                 <io/chars_ecm.asm>
;                 <io/chars_pet.asm>
;                 <io/chars_scr.asm>
; REQUISITI ZP:   __BG_COL
; ==============================================================================

; ******************************************************************************
; NOTE D'USO
; ******************************************************************************
;
; NOTA #01
; --------
; Un Commodore a 8 bit riconosce 256 codici carattere. Un codice diventa
; visibile quando il chip video lo associa a un glifo, cioè a un disegno del
; set di caratteri: i set sono due, il #1 "Maiuscolo/Grafici" e il #2
; "Minuscolo/Maiuscolo". L'aspetto del glifo non cambia il significato del
; codice, che dipende soltanto dalla codifica.
;
; I codici sono di due tipi: stampabili, che producono un glifo, e di
; controllo, che eseguono un'azione. In modalità Virgolette e in modalità
; Inserimento i codici di controllo perdono l'azione e mostrano un glifo.
;
; Le codifiche
; ------------
;
; La libreria converte tra quattro codifiche:
;
; - Codice Schermo: la codifica più vicina all'hardware, quella in cui sono
;   scritti i 40x25 caratteri della memoria video. Tutti i codici sono
;   stampabili, non esistono codici di controllo e a ogni codice corrisponde
;   un solo glifo. I codici da 0 a 127 sono i caratteri normali, quelli da 128
;   a 255 gli stessi caratteri in modalità inversa.
;
; - PETSCII: la codifica del BASIC e del Kernal (funzioni ASC e CHR$). Ha i
;   codici di controllo, e non ha i caratteri inversi: in modalità Virgolette
;   il Kernal mostra i controlli con un glifo inverso, senza ambiguità con i
;   glifi stampabili. Alcuni codici sono duplicati: il BASIC normalizza i
;   codici da 96 a 127 in quelli da 192 a 223 e i codici da 224 a 255 in
;   quelli da 160 a 191, quindi i duplicati condividono i glifi.
;
; - ASCII a 7 bit: non è nativa del Commodore, ma serve per lo scambio con
;   altre architetture. Ha solo 128 codici, con i controlli da 0 a 31 e il 127
;   (DEL), e non ha né i caratteri inversi né i grafici del Commodore.
;
; - ECM: non è una codifica in senso stretto, ma l'interpretazione del Codice
;   Schermo quando è attivo il modo Colore di Sfondo Esteso. I due bit più
;   significativi scelgono il registro del colore di sfondo (BGCOL0-BGCOL3) e
;   gli altri sei il glifo, da 0 a 63: il glifo è nel codice, lo sfondo in
;   __BG_COL. Si tratta come una codifica perché il suo codice contiene
;   un'informazione di colore che le altre non hanno.
;
; I blocchi
; ---------
;
; I 256 codici si dividono in otto blocchi da 32, numerati da 0 a 7 (0 = 0-31,
; 1 = 32-63 e così via): il blocco è nei tre bit più significativi del codice,
; e le regole di transcodifica si esprimono meglio con i blocchi.
;
; Blocco  Codici    Codice Schermo  PETSCII          ASCII
; ------  --------  --------------  ---------------  -----------
;   0     0-31      normali         controlli        controlli
;   1     32-63     normali         stampabili       stampabili
;   2     64-95     normali         stampabili       stampabili
;   3     96-127    normali         duplicati del 6  stampabili
;   4     128-159   inversi         controlli        inesistenti
;   5     160-191   inversi         stampabili       inesistenti
;   6     192-223   inversi         stampabili       inesistenti
;   7     224-255   inversi         duplicati del 5  inesistenti
;
; In ASCII anche il codice 127 è di controllo. In ECM il blocco dice il
; registro di sfondo: 0 e 1 BGCOL0, 2 e 3 BGCOL1, 4 e 5 BGCOL2, 6 e 7 BGCOL3,
; con gli stessi glifi nei blocchi pari e nei dispari.
;
;
; NOTA #02
; --------
; Una transcodifica non può mai essere senza perdite: Codice Schermo non ha i
; controlli, PETSCII e ASCII non hanno i caratteri inversi, ASCII non ha molti
; glifi del Commodore, ECM porta nel codice un colore che le altre codifiche
; non hanno. Ciò che il codice di arrivo non può conservare si conserva
; altrove, in __BG_COL, oppure si segnala con il Carry. Le routine seguono
; cinque criteri, in quest'ordine.
;
; 1. Glifo per glifo.
;
; Una conversione conserva l'aspetto del carattere, non il codice né il
; significato: il codice di arrivo è quello che rappresenta lo stesso glifo di
; quello di partenza. I codici di controllo non si traducono nel loro effetto:
; si convertono nel glifo che mostrano.
;
; 2. Un solo codice per glifo.
;
; Quando più codici hanno lo stesso glifo si sceglie sempre quello primario,
; mai il duplicato: in arrivo su PETSCII i blocchi 5 e 6, non i blocchi 7 e 3
; (il pigreco è l'unica eccezione dichiarata).
;
; 3. Le transcodifiche si compongono.
;
; Convertire in due passi, passando per una terza codifica, dà lo stesso
; risultato della conversione diretta. Vale per i caratteri stampabili; i
; codici di controllo seguono il criterio 5.
;
; 4. Andata e ritorno.
;
; Convertire un codice e riconvertire il risultato nella codifica di partenza
; restituisce il codice originale a tre condizioni: le due conversioni sono
; perfette (Carry a 0), usano la stessa variante (entrambe senza controlli o
; entrambe con) e il codice di partenza è un codice primario. I duplicati di
; PETSCII tornano come il codice primario con lo stesso glifo (il pigreco, 126
; o 255, torna sempre come 255). Con ECM il colore di sfondo, che è in
; __BG_COL, deve restare intatto tra le due chiamate.
;
; 5. Ciò che non si conserva si dichiara.
;
; Con il Carry a 0 il carattere di arrivo ha l'aspetto di quello di partenza,
; o del sostituto grafico previsto per i caratteri ASCII che il Commodore non
; ha. Altrimenti il Carry è a 1: la conversione è imperfetta e si restituisce
; il meglio possibile (per esempio il glifo normale da stampare in modalità
; inversa), oppure è impossibile e .A vale $FF. Nei contratti ogni routine
; dice come leggere il Carry a 1.
;
;
; NOTA #03
; --------
; Otto caratteri ASCII non hanno un glifo uguale nei set di caratteri del C64:
; la barra inversa, il circonflesso, il carattere di sottolineatura, l'accento
; grave, le due graffe, la barra verticale e la tilde. Le routine li
; sostituiscono con grafici che somigliano all'originale e che hanno lo stesso
; glifo nel set #1 e nel set #2 (con lo stesso codice), in modo che la
; conversione non dipenda dal set attivo né da un set personalizzato. La
; sostituzione è reversibile: nel verso opposto il grafico torna a essere il
; carattere che sostituisce, e la conversione è perfetta (Carry a 0).
;
; ASCII  Carattere        Codice Schermo  PETSCII  Grafico che lo sostituisce
; -----  ---------------  --------------  -------  --------------------------
;  92    barra inversa    127             191      due quarti di blocco opposti
;  94    circonflesso     30              94       freccia in su
;  95    sottolineato     100             164      linea in basso
;  96    accento grave    109             173      angolo in basso a sinistra
;  123   graffa aperta    115             179      tratto con ramo a sinistra
;  124   barra verticale  93              221      tratto verticale
;  125   graffa chiusa    107             171      tratto con ramo a destra
;  126   tilde            64              192      linea a metà altezza
;
; I controlli ASCII da 0 a 31 e il DEL (127) non hanno un glifo, e anche qui
; la scelta è di progetto, non una sostituzione: ASCII non ha una convenzione.
; I controlli sono rappresentati dai caratteri inversi di Codice Schermo da
; 128 a 159 e il DEL dal codice 102, una trama a scacchiera.
; ******************************************************************************

!source "chars_common.asm", once
!source "chars_asc.asm", once
!source "chars_ecm.asm", once
!source "chars_pet.asm", once
!source "chars_scr.asm", once
