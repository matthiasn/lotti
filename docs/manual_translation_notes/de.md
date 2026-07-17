# Hinweise zur deutschen Handbuchübersetzung

Hier sammeln wir verbleibende Beobachtungen, die beim Abgleich des deutschen
Handbuchs mit der produktiven App auffallen. Die Tabelle betrifft Texte, die
nicht über die deutschen ARB-Dateien gesteuert werden und deshalb eine
Code- oder Screenshot-Harness-Änderung brauchen.

## Vorgehen

- Den aktuellen Wortlaut, den betroffenen ARB-Schlüssel und die Oberfläche
  notieren.
- Kurz erklären, warum die Formulierung unklar, unnatürlich oder inkonsistent
  wirkt.
- Optional eine Richtung für eine spätere Korrektur festhalten.
- In diesem Dokument keine Änderung als bereits beschlossen behandeln.

## Beobachtungen

| Oberfläche | Aktueller Wortlaut | Beobachtung |
| --- | --- | --- |
| Audioaufnahme | `Speech Recognition` | Der Checkbox-Text ist im Widget fest auf Englisch hinterlegt und erscheint deshalb auch in der deutschen App-Variante Englisch. |
| Sync-Metriken | `Legend`, `Force Rescan`, `Retry Now`, `Copy Diagnostics`, `Refresh`, `Top KPIs`, `Processed` | Die Steuerungen und Diagrammbezeichnungen im Metrik-Widget sind fest auf Englisch hinterlegt. |
| Desktop-Navigation | `Tasks`, `Daily OS`, `Logbook`, `Manual`, `Settings` | Die Hauptnavigation bleibt in den deutschen Tagesansichten Englisch, während der Seiteninhalt lokalisiert ist. Produktnamen wie `Daily OS` können beabsichtigt sein; `Tasks` und `Settings` wirken dagegen inkonsistent. |
| Aufgabendetails | `Fällig: Jul 17, 2026` | Die Fälligkeitszeile kombiniert ein deutsches Label mit einem englisch formatierten Datum. |
| Messdiagramm | `Jun`, `Jul` | Die Datumsachse verwendet englische Monatskürzel, obwohl der umgebende Messeditor deutsch ist. |
| Agenten-Screenshots | `Admiral Pebble`, `Evolution #2` | Diese Demo-Instanznamen stammen aus dem Screenshot-Harness und durchbrechen die sonst deutsche Beispielwelt. |

Diese Punkte sind konkrete Ansatzpunkte für eine spätere Code- und
Screenshot-Harness-Runde.
