# Zeit stellen in der Clock

- [ ] over + underflow handling

Port 0 Inkrementieren, Dekrementieren und normaler clock operation aus.
Port 1 gibt an, welches element betroffen ist (Sekunden, Minuten, Stunden).

|Port 0|Mode|Port 1|Resultat|
| --- | --- | --- | --- |
|00|Normal|00|Seconds|
|01|Increment|01|Minutes|
|10|Decrement|10|Hours|
|11|Invalid|11|Invalid|