# Fortschritt

Stand: 9. November 2026

## Aktuelle Phase

**Phase 0 – Projektgerüst: abgeschlossen, wartet auf Freigabe.** Toolchain: Xcode 27.2, Swift 6.4.2, Deployment-Target iOS 27.0. iPad vorerst ausgesetzt (Q-014).

## Erledigt (Phase 0)

- Xcode-Projekt `EquiHealth.xcodeproj` (Universal App iPhone/iPad, Ordner-synchronisierte Gruppen), geteiltes Scheme `EquiHealth` mit Unit- und UI-Test-Target.
- Swift Package `EquiCore` (F-ARCH-01):
  - `FeatureFlags` – alle vier Flags `false` (F-ARCH-06).
  - SwiftData-Schema `EquiSchemaV1` mit allen 16 Entitäten aus SPEC Abschnitt 3, CloudKit-konform (F-ARCH-08), `EquiMigrationPlan`.
  - `EquiModelContainer`: Hauptstore lokal (`cloudKitDatabase: .none`), Wetter-Cache in eigenem, immer lokalem Store.
  - Vorbereitungsfelder `createdBy`/`lastModifiedBy` an allen Entitäten (F-TEIL-02), Pferd als Wurzel (F-TEIL-01).
  - `TrainingInterface` (Version, URL-Schemes) und `TrainingRoutePoint`.
- App: leere Tab-Struktur Übersicht / Durchsuchen / Termine / Suche mit `.sidebarAdaptable` und `ContentUnavailableView`.
- String Catalog (Deutsch, Englisch vorbereitet), Asset-Katalog mit Akzentfarbe, `PrivacyInfo.xcprivacy` (NF-02).
- Entitlements für iCloud und App Group in `Entitlements/`, **nicht** eingebunden (F-ARCH-07); `ENABLE_CLOUDKIT.md` als Platzhalter (vollständig in Phase 7).
- `.swift-format` (Zeilenlänge 120), Lint ohne Befund.

## Prüfergebnisse Phase 0 (Xcode 27.2)

| Prüfung | Ergebnis |
| --- | --- |
| Build iPhone 18 Pro (Simulator, iOS 27.2) | ✅ ohne Compiler-Warnungen |
| Build iPad | ⏸ vorerst ausgesetzt (Q-014); mit Xcode 26.1.1 lief er ohne Warnungen |
| `swift test --package-path EquiCore` | ✅ 13/13 grün, inkl. CloudKit-Regeltest |
| App-Unit-Tests (`EquiHealthTests`) | ✅ 2/2 grün |
| UI-Test App-Start mit leerer Tab-Struktur | ✅ grün |
| App-Start auf echtem Gerät (Personal Team) | ⏳ musst du selbst prüfen (Q-012) |
| `swift format lint` | ✅ |

Hinweis: Das Build-Log enthält die Zeile `appintentsmetadataprocessor … warning: Metadata extraction skipped`. Das ist eine Tool-Meldung, keine Compiler-Warnung; sie verschwindet, sobald App Intents genutzt werden (F-UI-09).

## Nächster Schritt

Phase 1 – Pferde und Messwerte (SPEC 4.1, 4.2, Grundgerüst von 5).

## Bekannte Probleme

- Der erste Testlauf nach einem Simulator-Kaltstart braucht mehrere Minuten. Bei einem Timeout im Zweifel nur die UI-Tests mit `-only-testing:EquiHealthUITests test-without-building` erneut starten.
- Der Test auf einem echten Gerät steht noch aus (Q-012).
