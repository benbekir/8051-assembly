# Thermometer

### Speicher
|Adresse|Daten|
--- | --- |
|40h-49h|Die 10 aktuellsten Werte, die von Port 2 ausgelesen wurden|
|4Ah|Der aktuelle Mittelwert, der sich aus 40h-49h ergibt|
|4Dh|Die Tendenz, angegeben durch 0 und 1 (für fallend und steigend)|