# Hinweise zur deutschen Handbuchübersetzung

Hier sammeln wir Beobachtungen, die beim Abgleich des deutschen Handbuchs mit
der produktiven App auffallen. Sie sind bewusst nur informativ: Die
Handbucharbeit ändert keine App-Übersetzungen ohne eine separate
Lokalisierungsänderung.

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
| Was gibt's Neues | `NEW` | Die Kennzeichnung der neuesten Version ist im Hero-Banner fest auf Englisch hinterlegt; die vorhandene deutsche Bezeichnung `NEU` wird dort nicht verwendet. |
| Sync-Metriken | `Top KPIs`, `Processed` | Beide Diagrammbezeichnungen sind im Metrik-Widget fest auf Englisch hinterlegt. |
| Labels bearbeiten | `Edit label` | Der deutsche ARB-Wert für `settingsLabelsEditTitle` ist noch Englisch. |
| Onboarding-Metriken | `Reached real aha` | Die interne Ereignisbezeichnung erscheint in der deutschen Ansicht weiterhin Englisch. |
| Desktop-Navigation | `Tasks`, `Daily OS`, `Logbook`, `Manual`, `Settings` | Die Hauptnavigation bleibt in den deutschen Tagesansichten Englisch, während der Seiteninhalt lokalisiert ist. Produktnamen wie `Daily OS` können beabsichtigt sein; `Tasks` und `Settings` wirken dagegen inkonsistent. |
| Aufgabendetails | `Fällig: Jul 17, 2026` | Die Fälligkeitszeile kombiniert ein deutsches Label mit einem englisch formatierten Datum. |
| Messdiagramm | `Jun`, `Jul` | Die Datumsachse verwendet englische Monatskürzel, obwohl der umgebende Messeditor deutsch ist. |

Diese Punkte werden in diesem Handbuch-PR nicht an der App-Lokalisierung
geändert. Sie dienen als konkrete Grundlage für eine spätere, separate
Lokalisierungsrunde.
