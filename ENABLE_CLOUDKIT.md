# iCloud-Sync aktivieren

Schritt-für-Schritt-Anleitung für den Tag, an dem ein bezahltes Apple-Entwicklerkonto vorhanden ist (F-ARCH-07, SPEC 4.10). Stand: Phase 7, Schemaversion 3.

> **Nicht mit kostenlosem Account (Personal Team) ausführen.** Persönliche Teams unterstützen weder iCloud noch Push. Xcode bricht dann beim Signieren ab, und die App lässt sich nicht mehr aufs iPhone spielen. Zurück geht es mit Abschnitt 9.

## 0. Was schon vorbereitet ist

| Baustein | Ort | Zustand |
| --- | --- | --- |
| Feature-Flags | `EquiCore/Sources/EquiCore/FeatureFlags.swift` | alle `false` |
| Container-ID / App Group | ebenda: `iCloud.de.aylu.EquiHealth`, `group.de.aylu.EquiHealth` | Platzhalter, passend zur Bundle-ID `de.aylu.EquiHealth` |
| Entitlements | `Entitlements/EquiHealth.iCloud.entitlements`, `Entitlements/EquiHealth.AppGroup.entitlements` | vorhanden, **in keinem Target eingebunden** |
| Store-Konfiguration | `EquiModelContainer` | Hauptstore wählt bei `cloudSyncEnabled = true` automatisch `.private(<Container-ID>)`. Der Wetter-Cache ist ein eigener Store und bleibt immer lokal (F-SYNC-01). |
| Schema | `Model/V1` bis `Model/V3` | CloudKit-konform, geprüft durch `CloudKitComplianceTests` und `MigrationTests` (F-ARCH-08) |
| Schema-Initialisierung | `CloudKitSchemaInitializer` (EquiCore) | legt das CloudKit-Schema einmalig an, verweigert sich bei ausgeschaltetem Flag |
| Sync-Status | `CloudSyncMonitor` (App, `Features/Sync`) | fasst CloudKit nur bei eingeschaltetem Flag an, zeigt Konto und letzten Abgleich (F-SYNC-03) |
| Teilen | `HorseRecordGraph` (EquiCore), Menüpunkt „Pferd teilen“ hinter `sharingEnabled` | nur vorbereitet (F-TEIL-01 bis -04) |

## 1. Vorher: Backup sichern

1. In der App unter Einstellungen › Daten › Backup ein Backup erstellen und in iCloud Drive oder auf dem Mac sichern.
2. Das Backup ist die Rückfallebene, falls beim ersten Abgleich etwas schiefgeht (Abschnitt 6).

## 2. Konto und Kennungen

1. Im Apple-Developer-Konto anmelden und in Xcode unter *Settings › Accounts* das Team hinzufügen.
2. Kennungen festlegen. Die vorbereiteten Werte passen zur Bundle-ID `de.aylu.EquiHealth`:
   - CloudKit-Container: `iCloud.de.aylu.EquiHealth`
   - App Group (erst für Trainings-App und Widgets nötig): `group.de.aylu.EquiHealth`
3. Wenn sich die Bundle-ID ändert (Bundle-IDs sind pro Team eindeutig), an **drei** Stellen anpassen:
   - `PRODUCT_BUNDLE_IDENTIFIER` im Projekt (App, Tests, UI-Tests),
   - `FeatureFlags.cloudKitContainerIdentifier` und `FeatureFlags.appGroupIdentifier`,
   - beide Dateien in `Entitlements/`.
   - Zusätzlich `BGTaskSchedulerPermittedIdentifiers` in `Config/EquiHealth-Info.plist` und `NotificationIdentifiers.refreshTask`.
   - Außerdem die Backup-UTI `de.aylu.equihealth.backup` in `Config/EquiHealth-Info.plist` und `BackupPackage.typeIdentifier`. Ältere `.equibackup`-Dateien bleiben über die Endung lesbar.

## 3. Xcode-Projekt einrichten

Target **EquiHealth** › *Signing & Capabilities*:

1. *Team*: das bezahlte Team wählen, *Automatically manage signing* an.
2. Entitlements einbinden. Unter *Build Settings* › `CODE_SIGN_ENTITLEMENTS` = `Entitlements/EquiHealth.iCloud.entitlements` setzen, für Debug und Release.
3. *+ Capability › iCloud*: Xcode erkennt die Datei. Haken bei *CloudKit*, Container `iCloud.de.aylu.EquiHealth` auswählen oder mit „+“ anlegen. Xcode registriert ihn im Developer-Portal.
4. *+ Capability › Push Notifications*: CloudKit meldet Änderungen über stille Pushes. `aps-environment` steht schon in der Entitlement-Datei; Xcode setzt es für Release automatisch auf `production`.
5. *+ Capability › Background Modes*: *Remote notifications* anhaken. *Background fetch* ist schon an (Erinnerungen, F-ERIN-05). Ergebnis in `Config/EquiHealth-Info.plist`:

   ```xml
   <key>UIBackgroundModes</key>
   <array>
       <string>fetch</string>
       <string>remote-notification</string>
   </array>
   ```

6. Die Test-Targets brauchen keine Entitlements.

## 4. Flag einschalten

In `EquiCore/Sources/EquiCore/FeatureFlags.swift`:

```swift
public static let cloudSyncEnabled = true
```

Die anderen Flags bleiben `false` (Abschnitt 8). Mehr ist am Code nicht nötig:

- `EquiModelContainer` nutzt jetzt `.private(FeatureFlags.cloudKitContainerIdentifier)` für den Hauptstore. Der Wetter-Cache bleibt bei `.none`.
- `CloudSyncMonitor` fragt den iCloud-Kontostatus ab und zeigt in den Einstellungen Status und letzten Abgleich.

### Tests, die danach bewusst rot werden

Sie sichern den Zustand „ohne Entwicklerkonto“ ab und müssen angepasst werden:

| Test | Anpassung |
| --- | --- |
| `CloudKitComplianceTests.featureFlagsAreOff` (EquiCore) | `cloudSyncEnabled` aus der Prüfung nehmen |
| `AppScaffoldTests.appRunsWithoutDeveloperAccount` (App) | Zeile mit `cloudSyncEnabled` entfernen |
| `SyncPreparationTests.storesAreLocal` (EquiCore) | erwarten: Hauptstore mit Container-ID, Wetter-Cache ohne |
| `SyncPreparationTests.schemaInitializerRefusesWhileDisabled` (EquiCore) | löschen |
| `SyncPreparationAppTests.entitlementsAreNotLinked` (App) | umkehren: Hauptziel bindet `EquiHealth.iCloud.entitlements` ein |
| `SyncPreparationAppTests.monitorStaysOff` und `LaunchUITests` (Sync-Status) | im Simulator ohne iCloud-Anmeldung „Kein iCloud-Konto“ erwarten |

Alle anderen Tests nutzen In-Memory-Stores und bleiben grün. `EquiModelContainer.make(inMemory: true)` legt auch bei eingeschaltetem Flag keinen Sync an (Test `SyncPreparationTests.containerSelection`), damit Tests und UI-Tests (`-uiTesting`) nie gegen CloudKit laufen.

## 5. Schema in CloudKit anlegen

SwiftData legt Record-Typen beim ersten Speichern in der **Development**-Umgebung selbst an. Sicherer ist, das ganze Schema einmal vorab zu erzeugen, damit auch selten genutzte Felder existieren.

1. Vorübergehend in einen Debug-Pfad einbauen, etwa einen Button in den Einstellungen unter `#if DEBUG`:

   ```swift
   Button("CloudKit-Schema anlegen") {
     let folder = FileManager.default.temporaryDirectory.appending(path: "ck-schema")
     try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
     do {
       try CloudKitSchemaInitializer.initializeDevelopmentSchema(storeDirectory: folder)
     } catch {
       print("Schema-Init fehlgeschlagen: \(error)")
     }
   }
   ```

2. App auf einem **echten Gerät**, das bei iCloud angemeldet ist, im Debug-Build starten und den Button einmal tippen. Das dauert einige Sekunden.
3. In der [CloudKit Console](https://icloud.developer.apple.com) › Container › *Development* › *Schema* prüfen:
   - Record-Typen `CD_Horse`, `CD_BodyMeasurement`, `CD_SymptomEntry` … existieren, je einer pro synchronisiertem Modell.
   - **Kein** `CD_WeatherDay`.
4. Den Debug-Button wieder entfernen.
5. Vor TestFlight oder App Store: *Deploy Schema Changes…* nach **Production**.
   - Production kennt danach diese Felder für immer; man kann sie nicht mehr löschen.
   - Darum gilt weiter: nur additive Schemaänderungen über neue `VersionedSchema`-Versionen (F-ARCH-08). Nach jeder neuen Schemaversion die Schritte 1 bis 5 wiederholen.

## 6. Bestehende Daten und erster Abgleich

Der Hauptstore behält Name und Ort. Schon erfasste Daten bleiben also erhalten, wenn der Sync eingeschaltet wird.

1. Zuerst das Gerät mit den meisten Daten aktualisieren und die App öffnen. SwiftData lädt die vorhandenen Einträge hoch. Das kann bei vielen Fotos dauern; die App dabei offen und im WLAN lassen.
2. Danach das zweite Gerät (iPad) mit derselben Apple-ID installieren und öffnen.
3. Wenn Einträge nach einer Weile fehlen (ältere Einträge werden nicht immer hochgeladen):
   - auf dem ersten Gerät das Backup aus Abschnitt 1 mit **Zusammenführen** einspielen.
   - Fehlende Einträge entstehen dadurch neu und werden synchronisiert. Vorhandene werden über die UUID erkannt und nicht doppelt angelegt.
4. **Nicht** auf beiden Geräten „Ersetzen“ benutzen: Das löscht synchronisiert auch auf dem anderen Gerät.
5. Erinnerungen gelten weiter pro Gerät (F-ERIN-07). Auf dem iPad bei Bedarf unter Einstellungen „Erinnerungen auf diesem Gerät“ ausschalten, damit Hinweise nicht doppelt kommen.

## 7. Prüfen (Abnahme F-SYNC-01 bis -04)

| Prüfung | Erwartung |
| --- | --- |
| iPhone: Pferd anlegen, Gewicht eintragen | erscheint nach kurzer Zeit auf dem iPad (F-SYNC-01) |
| Foto an ein Symptom hängen | Foto erscheint auf dem iPad (externer Speicher wird als CKAsset übertragen) |
| Wetter beim Symptom öffnen | auf beiden Geräten getrennt geladen, kein Wetter-Record in der CloudKit Console |
| Flugmodus an, Einträge erfassen, Flugmodus aus | App arbeitet normal weiter, Abgleich läuft nach (F-SYNC-02) |
| Einstellungen › iCloud-Synchronisierung | „Aktiv“ mit Zeitpunkt des letzten Abgleichs (F-SYNC-03) |
| Gerät ohne iCloud-Anmeldung | „Kein iCloud-Konto“ mit Hinweis, App voll nutzbar |
| Gleichen Eintrag auf beiden Geräten offline ändern, dann online | letzte Änderung gewinnt (F-SYNC-04), kein Absturz |

Prüfen, ob „Letzter Abgleich“ sich aktualisiert. Die App liest dafür die Benachrichtigung `NSPersistentCloudKitContainer.eventChangedNotification` (Q-054). Bleibt der Wert leer, obwohl Daten ankommen, liefert SwiftData diese Ereignisse nicht. Dann zeigt die App nur den Kontostatus; als Folgeaufgabe notieren.

## 8. Die anderen Flags (später)

### `sharedTrainingContainerEnabled`: gemeinsamer Container mit der Trainings-App (F-TRAIN-01)

Details folgen mit Phase 8 in `INTERFACE.md`. Kurz:

1. Trainings-App mit demselben Team, Bundle-ID z. B. `de.aylu.EquiTraining`.
2. Beide Apps: iCloud-Capability mit **demselben** Container `iCloud.de.aylu.EquiHealth` und App-Group-Capability mit `group.de.aylu.EquiHealth`.
3. In EquiHealth zusätzlich `Entitlements/EquiHealth.AppGroup.entitlements` einbinden. Das geht nicht als zweite Datei: Die Schlüssel in die iCloud-Entitlement-Datei übernehmen, weil ein Target nur eine Entitlement-Datei hat.
4. Flag auf `true`.

### `sharingEnabled`: Pferd mit anderen Apple-Accounts teilen (F-TEIL-03)

1. Prüfen, ob SwiftData in der dann aktuellen Version Freigaben (`CKShare`, gemeinsame Datenbank) direkt unterstützt.
2. Falls nicht, für diesen Teil Core Data mit `NSPersistentCloudKitContainer` und einem zweiten Store für die geteilte Datenbank (SPEC 4.12).
3. Was geteilt wird, liefert schon `HorseRecordGraph(horse:)`: das Pferd mit allen eigenen Einträgen, Stammdaten (Ställe, Futtermittel, Kontakte) nur als Verweise.
4. Rollen „Nur lesen“ und „Bearbeiten“ entsprechen den `CKShare`-Berechtigungen.
5. `createdBy` und `lastModifiedBy` an allen Einträgen sind dafür angelegt (F-TEIL-02) und müssen dann beim Speichern gefüllt werden.
6. Mit `sharingEnabled = true` erscheint im Pferdeprofil „Pferd teilen“ (F-TEIL-04). Der Platzhalter `HorseSharingPlaceholderView` wird durch die echte Freigabe-Ansicht ersetzt (`UICloudSharingController` bzw. `ShareLink` mit `CKShare`).

### `widgetsEnabled` (F-UI-08)

Braucht die App Group: Widget-Extension mit derselben App Group. Der Store muss dann im App-Group-Container liegen; dafür `storeDirectory` in `EquiModelContainer.make` nutzen. Vorher Daten per Backup sichern, weil sich der Speicherort ändert.

## 9. Zurück auf „ohne Entwicklerkonto“

1. `cloudSyncEnabled = false`.
2. `CODE_SIGN_ENTITLEMENTS` leeren, Capabilities iCloud und Push Notifications entfernen, `remote-notification` aus `UIBackgroundModes` nehmen.
3. Team wieder auf das Personal Team stellen.
4. Die lokalen Daten bleiben auf dem Gerät. Sie werden nur nicht mehr abgeglichen.
