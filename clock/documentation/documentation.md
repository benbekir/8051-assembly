# Dokumentation

> Die Clock Operationen funktionieren nur wenn definierte Werte an Port 0 und 1 angelegt werden (siehe Tabelle unten).


Die `clocktest.a51` benutzt selbst definierte Macros für Konstanten die erst mit dem selbstgeschriebenen Pre-Assembler aufgelöst werden müssen! 
`macros.exe <filename>`
Die `clocktest-generated.a51` ist die Assembler-Datei mit aufgelösten Macros.

## Speicheraufteilung

|Speicheradresse|Information|
| --- | --- |
|0x30|Stunden|
|0x31|Minuten|
|0x32|Sekunden|
|0x33|Max-Stunden|
|0x34|Max-Minuten|
|0x35|Max-Sekunden|
|0x36-0x37|Clock-Ticks (16 Bit LE)|
|0x3D|Push- und Pop-Buffer 2|
|0x3E|Push- und Pop-Buffer|
|0x3F|Register Bank Index|
|0x40-0x80|Stack|

## Zeit stellen in der Clock

Port 0 Inkrementieren, Dekrementieren und normaler clock operation aus.
Port 1 gibt an, welches element betroffen ist (Sekunden, Minuten, Stunden).

|Port 0|Modus|
| --- | --- |
|0|Normal|
|1|Inkrementieren|
|2|Dekrementieren|
|$\geq$3|Invalid|

|Port 1|Auswahl|
| --- | --- |
|0|Seconds|
|1|Minutes|
|2|Hours|
|$\geq$3|Invalid|

Die Ports werden jede Sekunde abgefragt und die jeweilige Operation wird anschließend ausgeführt.
Das Stellen der einzelnen Spalten geschieht unabhängig von den anderen. Es werden keine 'carries' erzeugt.

## Testfälle

Die Übergänge unserer Uhr wurden in folgenden Szenarien für den normalen Modus (Port 0 = 0) geprüft:

|Stunden|Minuten|Sekunden|$\Rightarrow$|Stunden+1|Minuten+1|Sekunden+1|
--- | --- | ---| ---| ---| ---| --- |
|0|0|0|$\Rightarrow$|0|0|1|
|0|0|59|$\Rightarrow$|0|1|0|
|0|59|59|$\Rightarrow$|1|0|0|
|23|59|59|$\Rightarrow$|0|0|0|