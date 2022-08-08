# Zeit stellen in der Clock

Port 0 wählt zwischen Minuten, Stunden, Inkrementieren und dem Dekrementieren aus.
Port 1  gibt an, ob das Stellen der Zeit ein oder ausgeschaltet ist.

|Port 0|Port 1|Resultat|
| --- | --- | --- |
|00|00|Nichts|
|01|00|Nichts|
|10|00|Nichts|
|11|00|Nichts|
|00|!=0|Minuten werden inkrementiert|
|01|!=0|Minuten werden dekrementiert|
|10|!=0|Stunden werden inkrementiert|
|11|!=0|Stunden werden dekrementiert|