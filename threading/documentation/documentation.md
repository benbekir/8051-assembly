---
output: pdf_document
export_on_save:
  pandoc: true
---

# Anmerkungen

Beim Scheduler haben wir wie bei der Clock letztes mal mit Makros gearbeitet (`threading.a51`). Die Makros werden dann über einen in C# selbst geschriebenen pre-assembler (siehe [GitHub cross-platform releases (link)](https://github.com/benbekir/8051-assembly/releases)) aufgelöst (`threading-generated.a51`) und das programm kann anschließend wie gewohnt über `AS51 V4.exe` assembled werden.

Die im code verwendeten Makros werden dabei 1:1 durch die im Programm oben definierten Werte ersetzt.

# Scheduler

Der Scheduler läuft alle 10 ms und ruft die Funktion `TasksNofityAll()` auf. Dabei wird zu erst der aktuelle `ExecutionContext` durch aufrufen der `EXC_STORE` Funktion in den `SWAP` Bereich geschrieben.
anschließend wird der `Reaktions` task aufgerufen. Nachdem der `Reaktions` task beendet wurde wird weiterhin die `Clock` benachrichtigt, dass 10 ms vergangen sind. Abhängig von dem internen Clock-counter wird dann eine Sekunde inkrementiert, wobei dann weiterhin der `Temperatur` task benachrichtigt wird.

Nachdem alle Tasks benachrichtigt wurden wird der originale `ExecutionContext` wieder aus dem `SWAP` Bereich geladen (`EXC_RESTORE`) und der interrupt beeendet. Somit läuft der `Sort` task nach kurzer Unterbrechung des Schedulers weiter.

```text
INIT->SORT                                                     --> SORT
           \                                                  /
   Interrupt-->EXC_STORE->Reaction->Clock->EXC_RESTORE->reti -
```

**Memory layout**

| Region        | Start | End   | Size | Description                                 |
| --------------|-------|-------|------|---------------------------------------------|
| RESERVED      | 0x0   | 0x8   | 8    | register bank 0                             |
| STACK         | 0x8   | 0x2f  | 24   | stack                                       |
| RAM 1         | 0x30  | 0x3f  | 16   | RAM for Task 1: Scheduler                   |
| RAM 2         | -     | -     | 0    | RAM for Task 2: Reaction (allocation free)  |
| RAM 3         | 0x40  | 0x4f  | 16   | RAM for Task 3: Clock                       |
| RAM 3B        | 0x50  | 0x5f  | 16   | RAM for Task 3B: Temperature                |
| RAM 4         | 0x60  | 0x67  | 8    | RAM for Task 4: Sorting (not used)          |
| SWAP          | 0x68  | 0x7f  | 24   | swap area for execution context             |

## Reaction-Task (R-Task)

Der Reaction-Task liest alle 10 ms den Wert aus Port 1 aus und schreibt basierend auf der Größenordnung einen festgelegten Wert in Port 3.

|Speicheradresse|Information|
| --- | --- |
|Port 1|Der auszulesende Wert|
|Port 3|Der berechnete Wert|

Der Wert in Port 3 wird in den zwei least significant bits folgendermaßen gespeichert:

|Wertebereiche (Port 1)|Resultat (Port 3 / XH, XL)|
| --- | --- |
|100<x<200|0, 0|
|x $\geq$ 200|1, 0|
|x<100|0, 1|
|x=100 $\lor$ error|1, 1|

### Tests

Die Funktion des Reaktions-Tasks wird im folgenden durch Tests veranschaulicht und verifiziert:

| Wert Port 1 | Wert Port 3 |
|------|---|
| 0    | 0x1	   |
| 99    | 0x1 |
| 100    | 0x3 |
| 101    | 0x0 |
| 150    | 0x0 |
| 199    | 0x0 |
| 200    | 0x2 |
| 255    | 0x2 |

## Berechnungs-Task (C-Task)

Der Berechnungs-Task sortiert den gesamten externen RAM aufsteigend nach Größe.
Benutzt wird der Bubble-Sort Algorithmus.

### Tests

Um die Funktion nachzuweisen, wurde ein Array mit 256 Werten sortiert.
![](assets\xram-sorted.png)

## Thermometer

Das Thermometer liest alle 10 Sekunden einen Wert aus Port 2 aus.

|Speicheradresse|Information|
| --- | --- |
|0x50-59|Die 10 letzten Messungen (ausgelesen aus Port 2)|
|0x5A|Ticks|
|0x5B|Mittelwert|
|0x5C|Tendenz|
|0x5D|Pointer auf die aktuelle Adresse ausgehend von 0x50|
|0x5E-5F|High- und Low-Nibble der Summe für die Mittelwertberechnung|

Die Tendenz kann folgende Werte betragen:

|Wert|Bedeutung|
| --- | --- |
|0x0|Fallend|
|0x1|Steigend|
|0xFF|Keine Änderung|

### Tests

#### Tests für die Mittelwertberechnung

Es wurden 10 Messungen $M_1\dots M_{10}$ durchgeführt: 

| $M_1$ | $M_2$ | $M_3$ | $M_4$ | $M_5$ | $M_6$ | $M_7$ | $M_8$ | $M_9$ | $M_{10}$ |Mittelwert|
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|0|0|0|0|0|0|0|0|0|0|0|
|50d|0|0|0|0|0|0|0|0|0|5d|
|50d|50d|0|0|0|0|0|0|0|0|10d|
|50d|50d|50d|0|0|0|0|0|0|0|15d|
|50d|50d|50d|50d|0|0|0|0|0|0|20d|
|50d|50d|50d|50d|50d|0|0|0|0|0|25d|
|50d|50d|50d|50d|50d|50d|0|0|0|0|30d|
|50d|50d|50d|50d|50d|50d|50d|0|0|0|35d|
|50d|50d|50d|50d|50d|50d|50d|50d|0|0|40d|
|50d|50d|50d|50d|50d|50d|50d|50d|50d|0|45d|
|50d|50d|50d|50d|50d|50d|50d|50d|50d|50d|50d|

#### Tests für die Tendenzberechnung

Die Tests werden anhand von nur zwei Messungen veranschaulicht um die Übersichtlichkeit zu gewährleisten: 

|Mittelwert|$\Rightarrow$|Mittelwert||Tendenz|
| --- | --- | --- | --- | --- |
|0|$\Rightarrow$|0||0xFF|
|0|$\Rightarrow$|0xA||0x1|
|0xA|$\Rightarrow$|0||0|

## Clock

|Speicheradresse|Information|
| --- | --- |
|0x40|Stunden|
|0x41|Minuten|
|0x42|Sekunden|
|0x43|Max-Stunden|
|0x44|Max-Minuten|
|0x45|Max-Sekunden|

### Manuelles Stellen der Clock

Das lower nibble des Ports 0 wird genutzt um den Modus der Clock auszuwählen:
- Die niedrigeren 2 bit kontrollieren den Modus
- Die oberen 2 bit selektieren die zu setzenden Werte

| Modus | Beschreibung |
|------|-------------|
| 0    | normal	   |
| 1    | increment   |
| 2    | decrement   |
| 3    | invalid     |

| Selektion | Beschreibung |
|-----------|-------------|
| 0         | hours       |
| 1         | minutes     |
| 2         | seconds     |
| 3         | invalid     |

Port 0 wird jede Sekunde abgefragt und die jeweilige Operation wird anschließend ausgeführt.
Das Stellen der einzelnen Spalten geschieht unabhängig von den anderen. Es werden keine 'carries' erzeugt.

### Tests

Die Übergänge unserer Uhr wurden in folgenden Szenarien für den normalen Modus (die zwei least significant bits aus Port 0 = 00 ) geprüft:

BEACHTE: Auf der linken Seite von "$\Rightarrow$" sind Werte zum Zeitpunkt t angegeben.
Auf der rechten Seite von "$\Rightarrow$" sind Werte zum Zeitpunkt t+1 angegeben. 

|Stunden|Minuten|Sekunden|$\Rightarrow$|Stunden|Minuten|Sekunden|
--- | --- | ---| ---| ---| ---| --- |
|0|0|0|$\Rightarrow$|0|0|1|
|0|0|59|$\Rightarrow$|0|1|0|
|0|59|59|$\Rightarrow$|1|0|0|
|23|59|59|$\Rightarrow$|0|0|0|