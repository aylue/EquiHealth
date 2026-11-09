# Fortschritt

Stand: 9. November 2026 · Toolchain: Xcode 27.2, Swift 6.4.2, Deployment-Target iOS 27.0 · iPad vorerst ausgesetzt (Q-014)

## Aktuelle Phase

**Phase 4 – Erinnerungen: abgeschlossen, wartet auf Freigabe.**

## Erledigt

### Phase 0 – Projektgerüst ✅ (freigegeben)

Xcode-Projekt, Swift Package `EquiCore` mit SwiftData-Schema V1 (CloudKit-konform, 16 Entitäten), `FeatureFlags` (alle `false`), lokaler Store plus eigener Wetter-Store, nicht eingebundene Entitlements, Privacy Manifest, String Catalog.

### Phase 1 – Pferde und Messwerte ✅ (freigegeben)

- **Pferde (4.1):** anlegen, bearbeiten (inkl. Foto, Equidenpass-Status), archivieren, wiederherstellen, endgültig löschen mit Bestätigung (F-PFERD-01). Das aktive Pferd wechselt über das Menü in der Navigationsleiste, die Auswahl bleibt über einen Neustart erhalten (F-PFERD-02). Profilseite mit berechnetem Alter, aktuellem Stall und jüngsten Werten (F-PFERD-03). Ställe verwalten, Stall zuordnen, Umzug beendet die alte Zuordnung (F-PFERD-04). Reihenfolge per Drag-and-drop (F-PFERD-05).
- **Messwerte (4.2):** alle neun Messtypen, Schnelleingabe über „+“ › Messwert › Typ (F-MESS-01, -02, -06). Detailansicht mit Swift-Charts-Diagramm, Zeiträumen T/W/M/6M/J/Alle, Auswahl-Geste für Einzelwerte und Liste mit Bearbeiten und Wischen zum Löschen (F-MESS-03). Eigener Referenzbereich pro Pferd und Messtyp als Band; Werte außerhalb sind rot, größer und in der Liste mit Warnsymbol markiert (F-MESS-04). Gewichtsschätzung mit Skizze und Hinweis zur Genauigkeit (F-MESS-07, -08, -10). Geschätzte Werte erscheinen als hohle Punkte und mit dem Zusatz „geschätzt“ (F-MESS-09).
- **Grundgerüst UI (5):** Pferde-Umschalter, „+“-Menü und Profil-Menü (F-UI-01, -02), Übersicht mit angehefteten Messwerten samt Mini-Diagramm (anpassbar), Durchsuchen › Messwerte, leere Zustände (F-UI-05), Onboarding (F-UI-06), Einstellungen mit Sync-Status „Noch nicht verfügbar“ und Haftungshinweis (NF-11).
- **Schema V2 (Q-015):** Referenzbereiche liegen pro Pferd im Datenmodell (`ReferenceRangeSetting`). Schema V1 ist eingefroren (`Model/V1`), das aktuelle Modell liegt in `Model/V2`, `EquiMigrationPlan` migriert V1→V2 leichtgewichtig. Tests prüfen: V2 ist rein additiv, V1 bleibt CloudKit-konform, ein V1-Store auf der Platte wird ohne Datenverlust migriert.
- **Logik in EquiCore:** `WeightEstimation`, `ChartTimeRange`, `ReferenceRange`, `HorseAge`, `DecimalInput`, `ActiveHorseSelection`, `Horse.move(to:on:in:)`.

### Phase 2 – Gesundheit ✅ (freigegeben)

- **Symptome (4.4):** Kategorie inkl. eigener Kategorien mit Namensvorschlägen, Schweregrad, Beginn/Ende, typspezifische Details für Husten, Spannigkeit, Kolik und Augenentzündung, Fotos, Notiz (F-GESUND-01, -02). Laufende Symptome stehen oben in der Übersicht und lassen sich mit einem Tipp beenden (F-GESUND-03).
- **Krankheiten:** Diagnosen anlegen, Symptome und Behandlungen verknüpfen. Chronische, nicht ausgeheilte Erkrankungen erscheinen dauerhaft im Pferdeprofil (F-GESUND-04).
- **Zeitleiste:** Symptome, Krankheiten und Behandlungen pro Pferd, nach Tag gruppiert und nach Art filterbar. Erreichbar über Durchsuchen und das Pferdeprofil (F-GESUND-06).
- **Behandlungen (4.5):** Art inkl. freier Bezeichnung, Datum, Dienstleister, Beschreibung, Kosten, Krankheit, Fotos und PDFs (F-BEH-01, -02, -07). Beliebig viele Medikamente mit Wirkstoff, Dosis, Weg, Zeitraum, Häufigkeit und Charge (F-BEH-03). Bei Impfungen Impfstoff, Charge und Krankheiten; Impfübersicht mit letzter Impfung pro Krankheit (F-BEH-04).
- **Kontakte:** einmal anlegen, in Behandlungen wiederverwenden, Anrufen und E-Mail per Tipp, auch direkt aus dem Behandlungsformular anlegbar (F-BEH-05).
- **Warte- und Karenzzeiten:** als Datum oder als Tage ab letzter Gabe; die App berechnet das Enddatum (F-BEH-08). Laufende Zeiten erscheinen in Übersicht, Pferdeprofil und Medikamentenliste (F-BEH-09). Bei Schlachttieren wird die Lebensmittel-Wartezeit rot mit Hinweis hervorgehoben (F-BEH-10).
- **Menüs:** „+“ › Symptom, Behandlung, Krankheit; Profil › Kontakte; Durchsuchen › Symptome und Krankheiten, Behandlungen, Medikamente, Zeitleiste.
- **Logik in EquiCore:** `WithdrawalCalculator`, `Medication.withdrawalEnd`, `Horse.activeWithdrawals`, `.ongoingSymptoms`, `.chronicConditions`, `.timeline`, `.lastVaccinations`.

### Phase 3 – Fütterung ✅ (freigegeben)

- **Futtermittel (4.3):** Stammdaten für alle Pferde mit Kategorie, Hersteller und Standardeinheit; anlegen, bearbeiten, archivieren. Erreichbar über Profil › Futtermittel und Durchsuchen › Fütterung (F-FUTTER-01).
- **Futterplan:** pro Mahlzeit (morgens, mittags, abends, ad libitum) Futtermittel, Menge und Einheit (kg, g, Liter, Messbecher, Scheiben) (F-FUTTER-02).
- **Planversionen:** Jede Änderung gilt ab einem wählbaren Datum und legt eine neue Version an. Unveränderte Positionen laufen weiter. Die Versionsliste und ein Hinweis auf künftig geltende Pläne sind sichtbar (F-FUTTER-03).
- **Abweichungen und Zusatzgaben:** Zusatzgaben über „+“ › Fütterung oder in der Tagesansicht. Planpositionen lassen sich dort für einen Tag auslassen oder mit anderer Menge erfassen (Tippen oder Wischen an der Position); die Tagesmenge zählt die tatsächliche Menge (F-FUTTER-04, Q-033).
- **Fütterung an Tag X:** Plan des Tages, Zusatzgaben und Tagesmenge pro Kategorie; Tage mit Pfeilen oder Datumsauswahl wechseln (F-FUTTER-05).
- **Tagesmengen im Verlauf:** gestapeltes Balkendiagramm in kg pro Kategorie über 30 Tage, 90 Tage oder 1 Jahr (F-FUTTER-06).
- **Schema V3 (Q-033):** `FeedingLog.kindRaw` und `.mealRaw`. V2 ist eingefroren (`Model/V2`), das aktuelle Modell liegt in `Model/V3`, die Migration läuft V1→V2→V3. Tests prüfen jede Versionsstufe auf „nur additiv“ und CloudKit-Konformität.
- **Logik in EquiCore:** `Horse.feedingDay(_:)`, `.setFeedingDeviation`, `.clearFeedingDeviation`, `.extraFeedingLogs(onDayOf:)`, `Horse.feedingPlan(at:)`, `.applyFeedingPlan(_:from:feeds:in:)`, `.feedingLogs(onDayOf:)`, `.feedingPlanVersionDates`, `.dailyFeedTotals(from:through:)`.

### Phase 4 – Erinnerungen

- **Regeln (4.6):** pro Pferd mit frei wählbarem Intervall (Tage, Wochen, Monate, Jahre), Vorlaufzeit, Uhrzeit, erstem Termin und Aktiv-Schalter (F-ERIN-01, -02). Vorlagen für Influenza, Tetanus, Herpes, Zahnkontrolle, Hufschmied und Wurmkur liefern nur Startwerte (F-ERIN-03, Q-037). Erreichbar über „+“ › Erinnerung und den Tab „Termine“.
- **Fälligkeit:** letzte passende Behandlung + Intervall, sonst der erste Termin. Bei Impf-Regeln zählt nur ein Impfstoff gegen die jeweilige Krankheit (Q-038).
- **Termine-Tab:** alle Pferde, gruppiert in überfällig (rot mit Symbol), diesen Monat, später, ohne Termin und pausiert. Wischen › „Erledigt“ öffnet die vorbefüllte Behandlungs-Eingabe (F-ERIN-04). Die Übersicht zeigt „Demnächst fällig“ für das aktive Pferd (30 Tage).
- **Mitteilungen:** lokale Benachrichtigungen mit Vorlauf und am Fälligkeitstag. Es werden höchstens 64 geplant, die frühesten zuerst. Neu geplant wird beim Start, nach jeder Änderung, beim Wechsel in den Hintergrund und per `BGAppRefreshTask` (F-ERIN-05, Q-040). Die Aktionen „Erledigt“ (öffnet die Eingabe mit Art und Impfstoff vorbelegt) und „In 1 Woche erinnern“ funktionieren (F-ERIN-06, Q-039). Pro Gerät abschaltbar (F-ERIN-07).
- **Aus Phase 2 nachgeholt:** nächste Fälligkeit in der Impfübersicht (F-BEH-04), neu berechnete Fälligkeit im Behandlungsdetail (F-BEH-06), optionale Mitteilung bei Ende der Turnier-Karenzzeit (F-BEH-11).
- **Onboarding:** jetzt 3 Schritte, der dritte fragt optional nach Mitteilungen (F-UI-06).
- **Einstellungen:** Erinnerungen auf diesem Gerät, Karenzzeit-Mitteilung, Status der Mitteilungsfreigabe mit Erlauben bzw. Link in die iOS-Einstellungen.
- **Behoben während der Abnahme:** Die App stürzte beim Antippen einer Mitteilungsaktion ab, weil der Abschluss-Handler nicht auf dem Main Thread lief. Außerdem öffnete sich das Vorlagen-Menü im Formular nicht zuverlässig; es ist jetzt eine sichtbare Liste.
- **Logik in EquiCore:** `ReminderRule.nextDueDate`, `.isFulfilled(by:)`, `IntervalUnit.add`, `ReminderPlanner.plan` (64er-Limit).

## Prüfergebnisse Phase 4 (iPhone 18 Pro, iOS 27.2)

| Prüfung | Ergebnis |
| --- | --- |
| Build iPhone | ✅ ohne Compiler-Warnungen |
| Build iPad | ⏸ ausgesetzt (Q-014) |
| `swift test --package-path EquiCore` | ✅ 52 Tests grün (u. a. Abnahmefall Influenza: Impfung 9.11.2026 → fällig 9.5.2027, Vorlauf 25.4.2027 9:00; 64er-Limit; Verschieben) |
| App-Unit-Tests | ✅ 11 Tests grün (u. a. Mitteilungsaktionen „Erledigt“ und „In 1 Woche erinnern“) |
| UI-Test Abnahme Phase 4: Regel aus Vorlage „Influenza, 6 Monate, 14 Tage Vorlauf“, Impfung erfassen → richtiges Fälligkeitsdatum; echte Mitteilung erscheint mit beiden Aktionen; „Erledigt“ öffnet die vorbefüllte Eingabe, die sich mit einem Tipp speichern lässt | ✅ |
| UI-Tests Phase 0–3 | ✅ |
| Ansichten visuell geprüft (Screenshots aus dem UI-Test) | ✅ |
| `swift format lint` | ✅ |

## Nächster Schritt

Phase 5 – Wetter (4.7), inklusive Stall-Standort (Q-017), Wetter im Symptom-Detail (Q-025) und Lufttemperatur im Temperaturdiagramm (Q-019). Die Volltextsuche bleibt für Phase 9 vorgemerkt (Q-029).

## Bekannte Probleme

- Im Gesamtlauf blieb ein UI-Test einmal beim ersten Antippen hängen. Es gab keine fehlgeschlagene Prüfung, und das Ergebnispaket war unvollständig („result: unknown“). Bei der Wiederholung war er grün. Ursache ist die Simulator-Infrastruktur, nicht die App. Abhilfe: betroffene Testklasse mit `-only-testing:` wiederholen.
- Der erste App-Start nach dem Kaltstart eines Simulators dauert sehr lange. Ein Testlauf direkt danach kann mit „Test crashed with signal kill before establishing connection“ scheitern. Abhilfe: Simulator vorher booten (`xcrun simctl boot "iPhone 18 Pro"`) oder den Lauf wiederholen.
- Die UI-Tests dauern zusammen rund 12 bis 18 Minuten.
- Der Erinnerungs-Test braucht die Mitteilungsfreigabe im Simulator. Beim ersten Lauf bestätigt er den Systemdialog selbst; danach bleibt die Freigabe im Simulator gespeichert. Texteingaben warten auf den Tastaturfokus, Schalter werden nach dem Umlegen geprüft.
- Die Fotoauswahl des Systems läuft in einem eigenen Prozess und lässt sich im UI-Test nicht zuverlässig bedienen. Nur in Debug-Builds mit `-uiTesting` gibt es deshalb den Knopf „Testfoto hinzufügen“; er nutzt denselben Speicherweg wie echte Fotos.
- Für den Fototest liegt ein Testbild in der Simulator-Mediathek (`xcrun simctl addmedia`). Für den aktuellen UI-Test ist es nicht mehr nötig.
- Der Test auf einem echten Gerät steht noch aus (Q-012).

## Hinweise

- Neue Schemaversion anlegen (zuletzt V3): Ordner `Model/V3` nach `Model/V4` kopieren, die Kopie anpassen, `V3` einfrieren (Dateisuffix `V3`, Kommentar FROZEN), Typaliase und `CurrentSchema` in die neue Schemadatei verschieben, Stage in `EquiMigrationPlan` ergänzen, `MigrationTests.versions` erweitern.
- Der Mac hatte zwischenzeitlich keinen freien Speicher mehr. Builds und UI-Tests brauchen mehrere GB. `build/` im Projekt lässt sich jederzeit löschen.
