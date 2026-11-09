# Fortschritt

Stand: 9. November 2026 · Toolchain: Xcode 27.2, Swift 6.4.2, Deployment-Target iOS 27.0 · iPad vorerst ausgesetzt (Q-014)

## Aktuelle Phase

**Phase 1 – Pferde und Messwerte: abgeschlossen, wartet auf Freigabe.**

## Erledigt

### Phase 0 – Projektgerüst ✅ (freigegeben)

Xcode-Projekt, Swift Package `EquiCore` mit SwiftData-Schema V1 (CloudKit-konform, 16 Entitäten), `FeatureFlags` (alle `false`), lokaler Store plus eigener Wetter-Store, nicht eingebundene Entitlements, Privacy Manifest, String Catalog.

### Phase 1 – Pferde und Messwerte

- **Pferde (4.1):** anlegen, bearbeiten (inkl. Foto, Equidenpass-Status), archivieren, wiederherstellen, endgültig löschen mit Bestätigung (F-PFERD-01). Das aktive Pferd wechselt über das Menü in der Navigationsleiste, die Auswahl bleibt über einen Neustart erhalten (F-PFERD-02). Profilseite mit berechnetem Alter, aktuellem Stall und jüngsten Werten (F-PFERD-03). Ställe verwalten, Stall zuordnen, Umzug beendet die alte Zuordnung (F-PFERD-04). Reihenfolge per Drag-and-drop (F-PFERD-05).
- **Messwerte (4.2):** alle neun Messtypen, Schnelleingabe über „+“ › Messwert › Typ (F-MESS-01, -02, -06). Detailansicht mit Swift-Charts-Diagramm, Zeiträumen T/W/M/6M/J/Alle, Auswahl-Geste für Einzelwerte und Liste mit Bearbeiten und Wischen zum Löschen (F-MESS-03). Eigener Referenzbereich pro Pferd und Messtyp als Band; Werte außerhalb sind rot, größer und in der Liste mit Warnsymbol markiert (F-MESS-04). Gewichtsschätzung mit Skizze und Hinweis zur Genauigkeit (F-MESS-07, -08, -10). Geschätzte Werte erscheinen als hohle Punkte und mit dem Zusatz „geschätzt“ (F-MESS-09).
- **Grundgerüst UI (5):** Pferde-Umschalter, „+“-Menü und Profil-Menü (F-UI-01, -02), Übersicht mit angehefteten Messwerten samt Mini-Diagramm (anpassbar), Durchsuchen › Messwerte, leere Zustände (F-UI-05), Onboarding (F-UI-06), Einstellungen mit Sync-Status „Noch nicht verfügbar“ und Haftungshinweis (NF-11).
- **Logik in EquiCore:** `WeightEstimation`, `ChartTimeRange`, `ReferenceRange`, `HorseAge`, `DecimalInput`, `ActiveHorseSelection`, `Horse.move(to:on:in:)`.

## Prüfergebnisse Phase 1 (iPhone 18 Pro, iOS 27.2)

| Prüfung | Ergebnis |
| --- | --- |
| Build iPhone | ✅ ohne Compiler-Warnungen |
| Build iPad | ⏸ ausgesetzt (Q-014) |
| `swift test --package-path EquiCore` | ✅ 25 Tests grün |
| App-Unit-Tests | ✅ 7 Tests grün |
| UI-Test „App-Start und Onboarding“ | ✅ |
| UI-Test Abnahme: 2 Pferde, umschalten, je Gewicht und Temperatur, Diagramm mit Zeiträumen und Referenzband | ✅ |
| Diagramm visuell geprüft (Screenshot aus dem UI-Test) | ✅ |
| `swift format lint` | ✅ |

## Nächster Schritt

Phase 2 – Gesundheit (4.4, 4.5): Symptome, Krankheiten, Behandlungen, Medikamente, Kontakte, Zeitleiste.

## Bekannte Probleme

- Der erste App-Start nach dem Kaltstart eines Simulators dauert sehr lange. Ein Testlauf direkt danach kann mit „Test crashed with signal kill before establishing connection“ scheitern. Abhilfe: Simulator vorher booten (`xcrun simctl boot "iPhone 18 Pro"`) oder den Lauf wiederholen.
- Der UI-Abnahmetest dauert rund 90–110 Sekunden.
- Der Test auf einem echten Gerät steht noch aus (Q-012).
- Offene Entscheidung: Speicherort der Referenzbereiche (Q-015).
