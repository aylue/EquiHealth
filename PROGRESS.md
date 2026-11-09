# Fortschritt

Stand: 10. November 2026 · Toolchain: Xcode 27.2, Swift 6.4.2, Deployment-Target iOS 27.0 · iPad vorerst ausgesetzt (Q-014)

## Aktuelle Phase

**Phase 6 – Export und Backup: abgeschlossen, wartet auf Freigabe.**

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

### Phase 4 – Erinnerungen ✅ (freigegeben)

- **Regeln (4.6):** pro Pferd mit frei wählbarem Intervall (Tage, Wochen, Monate, Jahre), Vorlaufzeit, Uhrzeit, erstem Termin und Aktiv-Schalter (F-ERIN-01, -02). Vorlagen für Influenza, Tetanus, Herpes, Zahnkontrolle, Hufschmied und Wurmkur liefern nur Startwerte (F-ERIN-03, Q-037). Erreichbar über „+“ › Erinnerung und den Tab „Termine“.
- **Fälligkeit:** letzte passende Behandlung + Intervall, sonst der erste Termin. Bei Impf-Regeln zählt nur ein Impfstoff gegen die jeweilige Krankheit (Q-038).
- **Termine-Tab:** alle Pferde, gruppiert in überfällig (rot mit Symbol), diesen Monat, später, ohne Termin und pausiert. Wischen › „Erledigt“ öffnet die vorbefüllte Behandlungs-Eingabe (F-ERIN-04). Die Übersicht zeigt „Demnächst fällig“ für das aktive Pferd (30 Tage).
- **Mitteilungen:** lokale Benachrichtigungen mit Vorlauf und am Fälligkeitstag. Es werden höchstens 64 geplant, die frühesten zuerst. Neu geplant wird beim Start, nach jeder Änderung, beim Wechsel in den Hintergrund und per `BGAppRefreshTask` (F-ERIN-05, Q-040). Die Aktionen „Erledigt“ (öffnet die Eingabe mit Art und Impfstoff vorbelegt) und „In 1 Woche erinnern“ funktionieren (F-ERIN-06, Q-039). Pro Gerät abschaltbar (F-ERIN-07).
- **Aus Phase 2 nachgeholt:** nächste Fälligkeit in der Impfübersicht (F-BEH-04), neu berechnete Fälligkeit im Behandlungsdetail (F-BEH-06), optionale Mitteilung bei Ende der Turnier-Karenzzeit (F-BEH-11).
- **Onboarding:** jetzt 3 Schritte, der dritte fragt optional nach Mitteilungen (F-UI-06).
- **Einstellungen:** Erinnerungen auf diesem Gerät, Karenzzeit-Mitteilung, Status der Mitteilungsfreigabe mit Erlauben bzw. Link in die iOS-Einstellungen.
- **Behoben während der Abnahme:** Die App stürzte beim Antippen einer Mitteilungsaktion ab, weil der Abschluss-Handler nicht auf dem Main Thread lief. Außerdem öffnete sich das Vorlagen-Menü im Formular nicht zuverlässig; es ist jetzt eine sichtbare Liste.
- **Logik in EquiCore:** `ReminderRule.nextDueDate`, `.isFulfilled(by:)`, `IntervalUnit.add`, `ReminderPlanner.plan` (64er-Limit).

### Phase 5 – Wetter ✅ (freigegeben)

- **Bright Sky (4.7):** `WeatherProvider`-Protokoll (F-ARCH-03), `BrightSkyProvider` als einziger Netzwerkzugriff der App. Stundenwerte werden zu Tageswerten verdichtet: Temperatur min/mittel/max, Niederschlagssumme, mittlere Luftfeuchte, maximale Böe, vorherrschende Wetterlage, Station (F-WETTER-01). Koordinaten werden auf 2 Nachkommastellen gerundet (NF-01).
- **Standort:** Für Wetter gilt der Stall, an dem das Pferd am jeweiligen Tag stand. Ohne Stall erscheint „Stall hinterlegen“, ohne Standort ein eigener Hinweis (F-WETTER-02). Den Stall-Standort setzt man über den aktuellen Standort (einmalig), die Ortssuche oder Koordinaten (Q-017, Q-044). Die erste Stallzuordnung kann einen unbekannten Beginn haben (Q-042).
- **Cache:** lokaler Wetter-Store über einen `ModelActor`, also nicht auf dem Main Actor (NF-05). Vergangene Tage werden nicht erneut abgerufen, der aktuelle Tag höchstens stündlich. Verstreute Tage gehen in Blöcken von höchstens 31 Tagen raus (F-WETTER-03, Q-045).
- **Anzeige:** Symptom-Detail mit dem Wetter am Beginn und den 3 Tagen davor (F-GESUND-05). Körpertemperatur mit zuschaltbarer Lufttemperatur als zweite Linie in einem Diagramm darunter (F-MESS-05, Q-043). Wetterzeile pro Tag in der Zeitleiste (F-WETTER-04).
- **Quellenangabe:** „Wetterdaten: Deutscher Wetterdienst, über Bright Sky“ an jeder Wetteranzeige und unter Einstellungen › Impressum und Quellen (F-WETTER-05).
- **Offline/Fehler:** Es werden zwischengespeicherte Daten gezeigt, sonst ein dezenter Hinweis. Kein Dialog, kein Absturz (F-WETTER-06).
- **Nicht umgesetzt:** zweiter Anbieter (F-WETTER-07, KANN, Q-046).

### Phase 6 – Export und Backup

- **CSV-Export (4.8):** neun Dateien (Pferde, Messwerte, Fütterung mit Plan und Abweichungen, Symptome, Krankheiten, Behandlungen, Medikamente mit Warte-/Karenzzeit-Enddaten, Erinnerungen, Trainingseinheiten) (F-CSV-01, F-BEH-12). Filter nach Pferden, Zeitraum und Bereichen (F-CSV-02, Q-049). Formate „Excel (Deutsch)“ (Semikolon, Dezimalkomma) und „Standard“ (Komma, Dezimalpunkt), beide UTF-8 mit BOM, CRLF, ISO 8601 (F-CSV-03). Gesichert wird in einen Ordner über `fileExporter` (alle Dateien) oder über das Teilen-Menü (F-CSV-04). Maskierung nach RFC 4180 (F-CSV-05). Erreichbar unter Einstellungen › Daten › CSV-Export.
- **Backup (4.9):** `.equibackup`-Paket mit `backup.json` plus Fotos, Anhängen und Routen (F-BACKUP-01). Das Format mit `schemaVersion`, `appVersion` und `exportedAt` liegt in EquiCore und ist in `BACKUP_FORMAT.md` dokumentiert (F-BACKUP-02).
- **Wiederherstellen:** Vorschau, dann Zusammenführen (UUID entscheidet, nichts doppelt) oder Ersetzen (F-BACKUP-03). Ältere Schemaversionen lassen sich importieren (F-BACKUP-04). Der Import ist transaktional, ganz oder gar nicht (NF-06). „Letztes Backup“ steht in den Einstellungen (F-BACKUP-05).
- **Nicht auf dem Main Actor:** CSV-Export und Backup laufen in eigenen `ModelActor`s (NF-05).

## Prüfergebnisse Phase 6 (iPhone 18 Pro, iOS 27.2)

| Prüfung | Ergebnis |
| --- | --- |
| Build iPhone | ✅ ohne Compiler-Warnungen |
| Build iPad | ⏸ ausgesetzt (Q-014) |
| `swift test --package-path EquiCore` | ✅ 76 Tests grün (u. a. RFC-4180-Maskierung, beide Formate mit BOM/CRLF, Filter; Backup-Roundtrip über alle 16 Entitäten mit Datei-Paket; Zusammenführen ohne Dubletten; Ersetzen; Import Schemaversion 1; Ablehnung ohne Datenänderung) |
| App-Unit-Tests | ✅ 13 Tests grün |
| UI-Test Export (NF-10): CSV in beiden Formaten (9 Dateien), Backup erstellen | ✅ |
| UI-Tests Phase 0–5 | ✅ |
| CSV mit unabhängigem Parser geprüft (Spaltenzahl, Umlaute, Maskierung, Dezimaltrennzeichen) | ✅ |
| CSV in Numbers geöffnet (beide Formate: Spalten, Umlaute, Zeilenumbruch in Zelle) | ✅ |
| CSV in Excel geöffnet | ⏳ Excel nicht installiert (Q-053) |
| `swift format lint` | ✅ |

Behoben während der Prüfung: `ModelContext.didSave` von Hintergrund-Kontexten (Wetter-Cache, Backup) wurde ohne Umweg über den Main Thread an die Oberfläche weitergereicht (Laufzeitwarnung „Publishing changes from background threads“).

## Nächster Schritt

Phase 7 – iCloud-Sync und Teilen vorbereiten (4.10, 4.12) mit vollständiger `ENABLE_CLOUDKIT.md`. Die Volltextsuche bleibt für Phase 9 vorgemerkt (Q-029).

## Bekannte Probleme

- Im Gesamtlauf blieb ein UI-Test einmal beim ersten Antippen hängen. Es gab keine fehlgeschlagene Prüfung, und das Ergebnispaket war unvollständig („result: unknown“). Bei der Wiederholung war er grün. Ursache ist die Simulator-Infrastruktur, nicht die App. Abhilfe: betroffene Testklasse mit `-only-testing:` wiederholen.
- Der erste App-Start nach dem Kaltstart eines Simulators dauert sehr lange. Ein Testlauf direkt danach kann mit „Test crashed with signal kill before establishing connection“ scheitern. Abhilfe: Simulator vorher booten (`xcrun simctl boot "iPhone 18 Pro"`) oder den Lauf wiederholen.
- Die UI-Tests dauern zusammen rund 18 bis 25 Minuten.
- CSV-Beispieldateien für eine Prüfung in Excel/Numbers erzeugt `EQUI_CSV_SAMPLE_DIR=build/csv-samples swift test --package-path EquiCore --filter CSVSampleFiles`.
- UI-Tests nutzen nie das Netz: Mit `-uiTesting` liefert ein fester Test-Anbieter das Wetter, mit `-weatherOffline` scheitert er absichtlich (Q-047).
- Der Erinnerungs-Test braucht die Mitteilungsfreigabe im Simulator. Beim ersten Lauf bestätigt er den Systemdialog selbst; danach bleibt die Freigabe im Simulator gespeichert. Texteingaben warten auf den Tastaturfokus, Schalter werden nach dem Umlegen geprüft.
- Die Fotoauswahl des Systems läuft in einem eigenen Prozess und lässt sich im UI-Test nicht zuverlässig bedienen. Nur in Debug-Builds mit `-uiTesting` gibt es deshalb den Knopf „Testfoto hinzufügen“; er nutzt denselben Speicherweg wie echte Fotos.
- Für den Fototest liegt ein Testbild in der Simulator-Mediathek (`xcrun simctl addmedia`). Für den aktuellen UI-Test ist es nicht mehr nötig.
- Der Test auf einem echten Gerät steht noch aus (Q-012).

## Hinweise

- Neue Schemaversion anlegen (zuletzt V3): Ordner `Model/V3` nach `Model/V4` kopieren, die Kopie anpassen, `V3` einfrieren (Dateisuffix `V3`, Kommentar FROZEN), Typaliase und `CurrentSchema` in die neue Schemadatei verschieben, Stage in `EquiMigrationPlan` ergänzen, `MigrationTests.versions` erweitern.
- Der Mac hatte zwischenzeitlich keinen freien Speicher mehr. Builds und UI-Tests brauchen mehrere GB. `build/` im Projekt lässt sich jederzeit löschen.
