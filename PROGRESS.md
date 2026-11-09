# Fortschritt

Stand: 9. November 2026 · Toolchain: Xcode 27.2, Swift 6.4.2, Deployment-Target iOS 27.0 · iPad vorerst ausgesetzt (Q-014)

## Aktuelle Phase

**Phase 2 – Gesundheit: abgeschlossen, wartet auf Freigabe.**

## Erledigt

### Phase 0 – Projektgerüst ✅ (freigegeben)

Xcode-Projekt, Swift Package `EquiCore` mit SwiftData-Schema V1 (CloudKit-konform, 16 Entitäten), `FeatureFlags` (alle `false`), lokaler Store plus eigener Wetter-Store, nicht eingebundene Entitlements, Privacy Manifest, String Catalog.

### Phase 1 – Pferde und Messwerte ✅ (freigegeben)

- **Pferde (4.1):** anlegen, bearbeiten (inkl. Foto, Equidenpass-Status), archivieren, wiederherstellen, endgültig löschen mit Bestätigung (F-PFERD-01). Das aktive Pferd wechselt über das Menü in der Navigationsleiste, die Auswahl bleibt über einen Neustart erhalten (F-PFERD-02). Profilseite mit berechnetem Alter, aktuellem Stall und jüngsten Werten (F-PFERD-03). Ställe verwalten, Stall zuordnen, Umzug beendet die alte Zuordnung (F-PFERD-04). Reihenfolge per Drag-and-drop (F-PFERD-05).
- **Messwerte (4.2):** alle neun Messtypen, Schnelleingabe über „+“ › Messwert › Typ (F-MESS-01, -02, -06). Detailansicht mit Swift-Charts-Diagramm, Zeiträumen T/W/M/6M/J/Alle, Auswahl-Geste für Einzelwerte und Liste mit Bearbeiten und Wischen zum Löschen (F-MESS-03). Eigener Referenzbereich pro Pferd und Messtyp als Band; Werte außerhalb sind rot, größer und in der Liste mit Warnsymbol markiert (F-MESS-04). Gewichtsschätzung mit Skizze und Hinweis zur Genauigkeit (F-MESS-07, -08, -10). Geschätzte Werte erscheinen als hohle Punkte und mit dem Zusatz „geschätzt“ (F-MESS-09).
- **Grundgerüst UI (5):** Pferde-Umschalter, „+“-Menü und Profil-Menü (F-UI-01, -02), Übersicht mit angehefteten Messwerten samt Mini-Diagramm (anpassbar), Durchsuchen › Messwerte, leere Zustände (F-UI-05), Onboarding (F-UI-06), Einstellungen mit Sync-Status „Noch nicht verfügbar“ und Haftungshinweis (NF-11).
- **Schema V2 (Q-015):** Referenzbereiche liegen pro Pferd im Datenmodell (`ReferenceRangeSetting`). Schema V1 ist eingefroren (`Model/V1`), das aktuelle Modell liegt in `Model/V2`, `EquiMigrationPlan` migriert V1→V2 leichtgewichtig. Tests prüfen: V2 ist rein additiv, V1 bleibt CloudKit-konform, ein V1-Store auf der Platte wird ohne Datenverlust migriert.
- **Logik in EquiCore:** `WeightEstimation`, `ChartTimeRange`, `ReferenceRange`, `HorseAge`, `DecimalInput`, `ActiveHorseSelection`, `Horse.move(to:on:in:)`.

### Phase 2 – Gesundheit

- **Symptome (4.4):** Kategorie inkl. eigener Kategorien mit Namensvorschlägen, Schweregrad, Beginn/Ende, typspezifische Details für Husten, Spannigkeit, Kolik und Augenentzündung, Fotos, Notiz (F-GESUND-01, -02). Laufende Symptome stehen oben in der Übersicht und lassen sich mit einem Tipp beenden (F-GESUND-03).
- **Krankheiten:** Diagnosen anlegen, Symptome und Behandlungen verknüpfen. Chronische, nicht ausgeheilte Erkrankungen erscheinen dauerhaft im Pferdeprofil (F-GESUND-04).
- **Zeitleiste:** Symptome, Krankheiten und Behandlungen pro Pferd, nach Tag gruppiert und nach Art filterbar. Erreichbar über Durchsuchen und das Pferdeprofil (F-GESUND-06).
- **Behandlungen (4.5):** Art inkl. freier Bezeichnung, Datum, Dienstleister, Beschreibung, Kosten, Krankheit, Fotos und PDFs (F-BEH-01, -02, -07). Beliebig viele Medikamente mit Wirkstoff, Dosis, Weg, Zeitraum, Häufigkeit und Charge (F-BEH-03). Bei Impfungen Impfstoff, Charge und Krankheiten; Impfübersicht mit letzter Impfung pro Krankheit (F-BEH-04).
- **Kontakte:** einmal anlegen, in Behandlungen wiederverwenden, Anrufen und E-Mail per Tipp, auch direkt aus dem Behandlungsformular anlegbar (F-BEH-05).
- **Warte- und Karenzzeiten:** als Datum oder als Tage ab letzter Gabe; die App berechnet das Enddatum (F-BEH-08). Laufende Zeiten erscheinen in Übersicht, Pferdeprofil und Medikamentenliste (F-BEH-09). Bei Schlachttieren wird die Lebensmittel-Wartezeit rot mit Hinweis hervorgehoben (F-BEH-10).
- **Menüs:** „+“ › Symptom, Behandlung, Krankheit; Profil › Kontakte; Durchsuchen › Symptome und Krankheiten, Behandlungen, Medikamente, Zeitleiste.
- **Logik in EquiCore:** `WithdrawalCalculator`, `Medication.withdrawalEnd`, `Horse.activeWithdrawals`, `.ongoingSymptoms`, `.chronicConditions`, `.timeline`, `.lastVaccinations`.

## Prüfergebnisse Phase 2 (iPhone 18 Pro, iOS 27.2)

| Prüfung | Ergebnis |
| --- | --- |
| Build iPhone | ✅ ohne Compiler-Warnungen |
| Build iPad | ⏸ ausgesetzt (Q-014) |
| `swift test --package-path EquiCore` | ✅ 37 Tests grün |
| App-Unit-Tests | ✅ 7 Tests grün |
| UI-Test Abnahme Phase 2: Kolik mit Details und Foto, mit Tierarztbesuch und Medikament verknüpft, erscheint in der Zeitleiste; laufendes Symptom und Wartezeit in der Übersicht | ✅ |
| UI-Tests Phase 0/1 (App-Start, 2 Pferde mit Messwerten) | ✅ |
| Ansichten visuell geprüft (Screenshots aus dem UI-Test) | ✅ |
| `swift format lint` | ✅ |

## Nächster Schritt

Phase 3 – Fütterung (4.3). Danach bleibt die Volltextsuche für Phase 9 vorgemerkt (Q-029).

## Bekannte Probleme

- Der erste App-Start nach dem Kaltstart eines Simulators dauert sehr lange. Ein Testlauf direkt danach kann mit „Test crashed with signal kill before establishing connection“ scheitern. Abhilfe: Simulator vorher booten (`xcrun simctl boot "iPhone 18 Pro"`) oder den Lauf wiederholen.
- Die UI-Tests dauern zusammen rund 8 bis 12 Minuten. Texteingaben warten auf den Tastaturfokus, Schalter werden nach dem Umlegen geprüft.
- Die Fotoauswahl des Systems läuft in einem eigenen Prozess und lässt sich im UI-Test nicht zuverlässig bedienen. Nur in Debug-Builds mit `-uiTesting` gibt es deshalb den Knopf „Testfoto hinzufügen“; er nutzt denselben Speicherweg wie echte Fotos.
- Für den Fototest liegt ein Testbild in der Simulator-Mediathek (`xcrun simctl addmedia`). Für den aktuellen UI-Test ist es nicht mehr nötig.
- Der Test auf einem echten Gerät steht noch aus (Q-012).

## Hinweise

- Neue Schemaversion anlegen: Ordner `Model/V2` nach `Model/V3` kopieren, die Kopie anpassen, `V2` einfrieren (Dateisuffix `V2`, Kommentar FROZEN), `CurrentSchema` umstellen, Stage in `EquiMigrationPlan` ergänzen, Additiv-Test erweitern.
