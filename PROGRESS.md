# Fortschritt

Stand: 9. November 2026

## Aktuelle Phase

**Phase 0 – Projektgerüst: umgesetzt, wartet auf Freigabe.** Einschränkung: siehe „Bekannte Probleme“.

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

## Prüfergebnisse Phase 0

| Prüfung | Ergebnis |
| --- | --- |
| Build iPhone 17 Pro (Simulator) | ✅ ohne Compiler-Warnungen |
| Build iPad Pro 11-inch M5 (Simulator) | ✅ ohne Compiler-Warnungen |
| `swift test --package-path EquiCore` | ✅ 13/13 grün, inkl. CloudKit-Regeltest |
| `xcodebuild test` (App-Unit-Tests, UI-Test) | ❌ nicht ausführbar – Testrunner verbindet sich nicht (Q-013) |
| App-Start iPhone-/iPad-Simulator mit leerer Tab-Struktur | ✅ manuell per `simctl` geprüft |
| App-Start auf echtem Gerät (Personal Team) | ⏳ durch Nutzer zu prüfen (Q-012) |
| `swift format lint` | ✅ |

Hinweis: Das Build-Log enthält die Zeile `appintentsmetadataprocessor … warning: Metadata extraction skipped`. Das ist eine Tool-Meldung, keine Compiler-Warnung; sie verschwindet, sobald App Intents genutzt werden (F-UI-09).

## Nächster Schritt

Phase 1 – Pferde und Messwerte (SPEC 4.1, 4.2, Grundgerüst von 5).

## Bekannte Probleme

- Installiert ist Xcode 26.1.1 / Swift 6.2.1 statt Xcode 27 / Swift 6.4; Deployment-Target daher iOS 26.0 (Q-001).
- XCTest-Läufe im Simulator hängen mit dieser Xcode-Version auf macOS 27.2 (Q-013).
