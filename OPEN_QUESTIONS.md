# Offene Fragen und Annahmen

Annahmen sind im Code mit `// ANNAHME:` markiert. Status: **offen** = Entscheidung erwünscht, **angenommen** = so umgesetzt, Änderung möglich.

| ID | Phase | Thema | Annahme / Frage | Status |
| --- | --- | --- | --- | --- |
| Q-001 | 0 | Swift-/Xcode-Version, Mindestversion | Ursprünglich war Xcode 26.1.1 / Swift 6.2.1 installiert, daher vorübergehend iOS 26.0. Am 9.11.2026 hast du auf Xcode 27.2 / Swift 6.4.2 aktualisiert. Jetzt gilt: Deployment-Target iOS 27.0, `swift-tools-version: 6.4`, `.iOS(.v27)`. | erledigt |
| Q-002 | 0 | Name der Entität `Measurement` | Swift-Klasse heißt `BodyMeasurement`, um `Foundation.Measurement` (Einheitenanzeige, F-ARCH-04) nicht zu verdecken. Im Export heißt der Bereich weiterhin „Messwerte“. | angenommen |
| Q-003 | 0 | Bundle-ID | `de.aylu.EquiHealth`. Mit kostenlosem Account muss die ID weltweit frei sein; falls Xcode beim Signieren meckert, Präfix ändern (Target › Signing & Capabilities). CloudKit-Container- und App-Group-IDs in `FeatureFlags` und `Entitlements/` folgen demselben Präfix. | angenommen |
| Q-004 | 0 | Futtermengen-Einheit | Futtermengen werden in der gewählten Einheit (kg, g, l, Messbecher, Scheiben) gespeichert, nicht in SI, da Messbecher und Scheiben nicht umrechenbar sind. Ausnahme zu F-ARCH-04. | angenommen |
| Q-005 | 0 | Speicherung der Symptom-Details | Typspezifische Details sind ein Codable-Struct (`SymptomDetails`), gespeichert als JSON in `SymptomEntry.detailsData` statt als SwiftData-Composite-Attribut. Grund: verschachtelte optionale Structs sind so CloudKit-sicher und migrationsstabil. Klein, daher ohne `.externalStorage`. | angenommen |
| Q-006 | 0 | Eigene Symptom-Kategorien (F-GESUND-02) | Schema V1 speichert sie als `category = custom` plus `customCategoryName`. Falls Phase 2 Farben/Symbole pro eigener Kategorie braucht, kommt eine eigene Entität additiv dazu. | angenommen |
| Q-007 | 0 | Messmethode | Zusätzlich zu Waage, Maßband, Schätzformel, Thermometer gibt es `other` für Puls, Atemfrequenz und BCS. | angenommen |
| Q-008 | 0 | Löschregeln | Pferd löscht alle Einträge (cascade). Stammdaten (Futtermittel, Kontakte, Ställe) werden beim Löschen nur entkoppelt (nullify); Stall löscht seine Zuordnungen. Kein `.deny` (CloudKit). | angenommen |
| Q-009 | 0 | Tab-Ordner | Zusätzlich zu den Feature-Ordnern aus F-ARCH-02 gibt es `Overview`, `Browse` und `Search` für die Tabs aus SPEC 5. „Termine“ liegt in `Reminders`. | angenommen |
| Q-010 | 0 | Fehler beim Öffnen der Datenbank | Phase 0 bricht mit `fatalError` ab. Eine Fehleransicht mit Backup-Hinweis folgt mit Phase 6. | angenommen |
| Q-011 | 0 | Trainingseinheit, Zeit pro Gangart | Als drei Felder `walkDuration`, `trotDuration`, `canterDuration` (Sekunden), damit die Trainings-App ohne JSON-Format auskommt. Tölt/Pass bei Bedarf additiv. | angenommen |
| Q-012 | 0 | Test auf echtem Gerät | Konnte ich nicht selbst prüfen. Schritte: Projekt in Xcode öffnen, Target EquiHealth › Signing & Capabilities › Team = „(Personal Team)“, iPhone wählen, Run. | **offen** – bitte einmal durchführen |
| Q-013 | 0 | XCTest im Simulator hing | Mit Xcode 26.1.1 auf macOS 27.2 kam keine Verbindung zum Testrunner zustande. Mit Xcode 27.2 laufen die Tests. | erledigt |
| Q-014 | 0 | iPad vorerst ausgesetzt | Nach deiner Anweisung vom 9.11.2026 bauen und testen wir vorerst nur für das iPhone (iPhone 18 Pro, iOS 27.2). Das Target bleibt Universal (`TARGETED_DEVICE_FAMILY = 1,2`), damit wir später nichts umbauen müssen. Das iPad kommt wieder dazu, sobald du es freigibst. | angenommen |
| Q-015 | 1 | Speicherort der Referenzbereiche (F-MESS-04) | Pro Pferd und Messtyp in den Geräte-Einstellungen (UserDefaults), nicht im synchronisierten Datenmodell. Folge: Sie werden später nicht zwischen iPhone und iPad abgeglichen und sind nicht im Backup enthalten. Falls das gewünscht ist, kommt in Phase 6/7 eine additive Entität `ReferenceRangeSetting` dazu. | **offen** – reicht das so? |
| Q-016 | 1 | Einheiten bei Eingabe und Anzeige | Eingabe und Anzeige metrisch (kg, cm, °C) über `Foundation.Measurement` mit `usage: .asProvided`, auch in Regionen mit anderen Einheiten. Regionsabhängige Umrechnung, etwa lb/°F, folgt bei der Lokalisierung in Phase 9. | angenommen |
| Q-017 | 1 | Stall-Koordinaten | Ställe haben in Phase 1 nur Name und Ort. Standortbestimmung über CoreLocation und MapKit-Suche kommt mit dem Wetter in Phase 5. | angenommen |
| Q-018 | 1 | Onboarding-Schritt „Benachrichtigungen“ (F-UI-06) | Das Onboarding hat vorerst 2 Schritte (Pferd, Stall optional) plus Haftungshinweis. Der Schritt „Benachrichtigungen erlauben“ kommt mit den Erinnerungen in Phase 4. | angenommen |
| Q-019 | 1 | Lufttemperatur im Temperaturdiagramm (F-MESS-05) | Braucht Wetterdaten, daher erst in Phase 5. | angenommen |
| Q-020 | 1 | Menüs „Durchsuchen“, „+“ und Profil | Es erscheinen nur Bereiche, die schon umgesetzt sind. Symptom, Behandlung, Krankheit, Kontakte (Phase 2) und Fütterung, Futtermittel (Phase 3) kommen mit ihrer Phase dazu, statt vorher als deaktivierte Platzhalter zu erscheinen. | angenommen |
| Q-021 | 1 | Neues Pferd wird aktiv | Ein neu angelegtes Pferd wird automatisch zum aktiven Pferd. | angenommen |
| Q-022 | 1 | Gewichtsschätzung speichert Maße mit | Beim Speichern einer Schätzung werden Brustumfang und Körperlänge standardmäßig als eigene Messwerte mitgespeichert (abschaltbar). | angenommen |
| Q-023 | 1 | Englische Texte | Neue UI-Texte stehen auf Deutsch im Code. Der String Catalog wird beim Xcode-Build befüllt. Die englischen Übersetzungen kommen gesammelt in Phase 9. | angenommen |
