# iCloud-Sync aktivieren (vorgemerkt)

> Stand Phase 0: Platzhalter. Die vollständige Schritt-für-Schritt-Anleitung entsteht in Phase 7 (F-ARCH-07, SPEC 4.10).

Voraussetzung: bezahltes Apple-Entwicklerkonto.

Vorbereitet ist bisher:

- `EquiCore/Sources/EquiCore/FeatureFlags.swift` – alle Flags `false`, Container-ID `iCloud.de.aylu.EquiHealth`, App Group `group.de.aylu.EquiHealth`.
- `Entitlements/EquiHealth.iCloud.entitlements` und `Entitlements/EquiHealth.AppGroup.entitlements` – in **keinem** Target eingebunden.
- `EquiModelContainer` wählt bei `cloudSyncEnabled = true` automatisch `.private(<Container-ID>)` für den Hauptstore. Der Wetter-Cache bleibt immer lokal.
- Das Schema V1 ist CloudKit-konform (geprüft durch `CloudKitComplianceTests`).
