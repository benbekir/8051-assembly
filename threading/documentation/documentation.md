---
output: pdf_document
export_on_save:
  pandoc: true
---

# Scheduler

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

|Messung 1|Messung 2|Messung 3|Messung 4|Messung 5|Messung 6|Messung 7|Messung 8|Messung 9|Messung 10||Mittelwert|
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|0|0|0|0|0|0|0|0|0|0||0|
|50d|0|0|0|0|0|0|0|0|0||5d|
|50d|50d|0|0|0|0|0|0|0|0||10d|
|50d|50d|50d|0|0|0|0|0|0|0||15d|
|50d|50d|50d|50d|0|0|0|0|0|0||20d|
|50d|50d|50d|50d|50d|0|0|0|0|0||25d|
|50d|50d|50d|50d|50d|50d|0|0|0|0||30d|
|50d|50d|50d|50d|50d|50d|50d|0|0|0||35d|
|50d|50d|50d|50d|50d|50d|50d|50d|0|0||40d|
|50d|50d|50d|50d|50d|50d|50d|50d|50d|0||45d|
|50d|50d|50d|50d|50d|50d|50d|50d|50d|50d||50d|

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