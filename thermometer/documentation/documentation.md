---
export_on_save:
  pandoc: true
---

# Thermometer

## Speicheraufteilung
|Adresse|Daten|
--- | --- |
|40h-49h|Die 10 aktuellsten Werte, die von Port 2 ausgelesen wurden|
|4Ah|Der aktuelle Mittelwert, der sich aus 40h-49h ergibt|
|4Bh|Pointer der auf die Speicheradresse zeigt, in die der nächste Temperaturwert geschrieben werden soll.|
|4Ch|Der Rest, der sich aus der Integer Division ergibt und zwischengespeichert wird, um am Ende den finalen Mittelwert zu berechnen.|
|4Dh|Loop variable die für die Mittelwertberechnung benutzt wird.|
|4Eh|Die Tendenz für kommende Temperaturwerte, angegeben durch 0 (fallend) und 1 (steigend oder gleich).|

## Temperaturberechnung

Damit ein neuer Wert alle 10 Sekunden abgelesen wird, wird über den Timer 0 Interrupt der 16-Bit Wert 40000d dekrementiert. Die 10 aktuellsten Messwerte werden in den Speicheradressen 40h-49h gespeichert. Mithilfe des Pointers an Speicheradresse 4Bh wird die Position im Speicher für den kommenden Messwert bestimmt. Wenn ein neuer Wert aus Port 2 in eine der Speicheradressen geschrieben wird, wird eine neue Durchschnittstemperatur berechnet:

##### Berechnung der Durchschnittstemperatur

Die loop variable in 4Dh wird mit 0 initialisiert. Dann wird auf den Wert 40h die loop variable addiert um dadurch über die Adressen 40h-49h zu iterieren. Bei jeder Speicheradresse wird der Wert ausgelesen, auf einen Durchschnittswert in Register 2 addiert und die loop variable inkrementiert. Bevor der ausgelesene Wert auf den Durchschnittswert in Register 2 addiert wird, wird er durch 10d dividiert. Dadurch wird ein Overflow des Durchschnittswertes vermieden. Bei der Division durch 10 entsteht ein Rest, welcher auf Adresse 4Ch addiert wird. Sobald die loop variable den Wert 10 beträgt, wird der bisher berechnete Durchschnitt in die Adresse 4Ah geschrieben. Der aufsummierte Rest aus der Adresse 4Ch durch 10d dividiert und dann auf den Durchschnittswert in 4Ah addiert. Dadurch wird in der Durchschnittstemperatur der Rest, der bei der Division entsteht, berücksichtigt. Die loop variable wird danach zurückgesetzt, um damit die Schleife zu beenden. Die Schleife wird nach jedem Ablesen eines neuen Temperaturwertes ausgeführt.

##### Bestimmung der Tendenz

Nachdem die Durchschnittstemperatur berechnet wurde, wird anhand der zuvorigen - und der neu berechneten Durchschnittstemperatur eine Tendenz gebildet. Dafür wird die neue Durchschnittstemperatur in den Akkumulator - und die alte in das B-Register geladen. Dann wird A durch B dividiert und man erhält somit:
- 0 für den Fall A < B,
- 1 oder größer für den Fall A $\geq$ B

Das Ergebnis der Division wird dann in die Adresse 4Eh geschrieben und kann dort abgelesen werden.

##### Abschluss der Temperaturberechnung

Zeigt der Pointer aus Adresse 4Bh auf die Adresse 49h, so muss er nach Auslesen des nächsten Temperaturwertes auf 40h zurückgesetzt werden.

## Anmerkungen

- Die Berechnung der Durchnschnittstemperatur hat eine Abweichung von 1. Leider konnten wir nicht genauer erörtern, wodurch diese Ungenauigkeit ausgelöst wird.
    - Testfall: Alle 10 Temperaturen betragen den Wert 16d, Durchnschnittswert sollte dadurch ebenfalls 16d betragen, beträgt jedoch 17d.
- Während der Berechnung der Durchschnittstemperatur, werden die Register 1 bis 5 benutzt. (Genaue Dokumentation im Code)
- Für das Thermometer wird nur die Sekunden Logik der Clock genutzt, nicht die gesamte Clock. 