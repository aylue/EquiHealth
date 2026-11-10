# Schnittstelle EquiHealth ↔ Trainings-App

Vertrag zwischen EquiHealth und der geplanten Trainings-App (SPEC 4.11, F-TRAIN-01 bis -07). Schnittstellenversion **1** (`TrainingInterface.version`), Datenmodell Schemaversion 3.

Die Apps sprechen nie direkt miteinander über Daten. Sie lesen und schreiben dieselbe Datenbank und öffnen sich gegenseitig nur per Deep Link.

```
EquiHealth ──equitraining://start?horse=<uuid>──► Trainings-App
EquiHealth ◄──equihealth://horse/<uuid>────────── Trainings-App
     │                                                 │
     └── schreibt Horse, liest TrainingSession         └── schreibt TrainingSession, liest Horse
                  gemeinsamer Store (später iCloud-Container + App Group)
```

## 1. Gemeinsamer Code: `EquiCore`

Beide Apps binden das lokale Swift Package `EquiCore` ein (F-ARCH-01). Die Trainings-App nutzt daraus:

| Typ | Zweck |
| --- | --- |
| `CurrentSchema`, `EquiMigrationPlan`, `EquiModelContainer` | dasselbe SwiftData-Schema mit Migrationen. Nie ein eigenes Schema definieren. |
| `TrainingSession`, `Horse` | Modelle (Typaliase auf `EquiSchemaV3`) |
| `TrainingType`, `TrainingRoutePoint` | Werte |
| `TrainingInterface` | Version, URL-Schemata, Feldlisten, Bundle-IDs |
| `DeepLink` | Deep Links bauen und lesen |
| `TrainingWeekSummary`, `Horse.trainingWeeks(_:)` | Wochenauswertung, wie EquiHealth sie anzeigt |
| `TrainingSampleGenerator` | Beispiel-Einheiten für Tests (F-TRAIN-06) |

## 2. Datenhoheit (F-TRAIN-02)

| Entität | Schreibt | Liest |
| --- | --- | --- |
| `Horse` und alle Gesundheitsdaten, Stammdaten (`Stable`, `Feed`, `Contact`) | EquiHealth | Trainings-App: nur die Felder aus 3.1 |
| `TrainingSession` | Trainings-App | EquiHealth (nur Anzeige, CSV-Export, Backup) |

Regeln:

- Jede App ändert nur ihre eigenen Entitäten. EquiHealth legt `TrainingSession` nur im Debug-Menü (`sourceApp = de.aylu.EquiHealth.samples`) und beim Wiederherstellen eines Backups an.
- Die Trainings-App legt **keine** Pferde an und löscht keine. Fehlt ein Pferd, verweist sie per Deep Link auf EquiHealth.
- Wird ein Pferd in EquiHealth gelöscht, löscht die Kaskade auch seine Trainingseinheiten. Archivieren (`isArchived`) ist der Normalfall; archivierte Pferde bietet die Trainings-App nicht mehr zur Auswahl an.

## 3. Schema (F-TRAIN-03)

Alle Felder sind CloudKit-konform: optional oder mit Standardwert, keine Eindeutigkeitsregeln, Beziehungen optional mit Inverse (F-ARCH-08). Einheiten sind SI.

### 3.1 `Horse`: Felder, die die Trainings-App liest

`TrainingInterface.sharedHorseFields`

| Feld | Typ | Bedeutung |
| --- | --- | --- |
| `id` | `UUID` | stabile Kennung, auch in Deep Links |
| `name` | `String` | Name |
| `callName` | `String?` | Rufname |
| `photoData` | `Data?` (externer Speicher) | Foto, JPEG |
| `isArchived` | `Bool` | archiviert: nicht zur Auswahl anbieten |
| `sortIndex` | `Int` | Reihenfolge wie in EquiHealth |
| `trainingSessions` | `[TrainingSession]?` | Inverse von `TrainingSession.horse`, Löschregel Kaskade |

### 3.2 `TrainingSession`: von der Trainings-App geschrieben

`TrainingInterface.trainingSessionFields`

| Feld | Typ | Pflicht | Bedeutung |
| --- | --- | --- | --- |
| `id` | `UUID` | ja (Standard `UUID()`) | Kennung |
| `createdAt`, `updatedAt` | `Date` | ja | Anlage und letzte Änderung; bei jeder Änderung `updatedAt` setzen (`touch()`) |
| `createdBy`, `lastModifiedBy` | `String?` | nein | Anzeigename für das spätere Teilen (F-TEIL-02), vorerst leer |
| `interfaceVersion` | `Int` | ja | `TrainingInterface.version` der schreibenden App |
| `typeRaw` | `String` | ja | Rohwert von `TrainingType`: `riding`, `dressage`, `jumping`, `hacking`, `lunging`, `groundwork`, `other`. Unbekannte Werte zeigt EquiHealth als „Sonstiges“. |
| `start` | `Date` | ja | Beginn |
| `end` | `Date?` | nein | Ende |
| `duration` | `Double` | ja | Dauer in **Sekunden** (aktive Zeit, ohne Pausen) |
| `distance` | `Double?` | nein | Distanz in **Metern** |
| `walkDuration`, `trotDuration`, `canterDuration` | `Double?` | nein | Sekunden in Schritt, Trab, Galopp. Ihre Summe sollte `duration` ergeben. |
| `heartRateAverage`, `heartRateMax` | `Double?` | nein | Herzfrequenz des Pferdes in Schlägen pro Minute |
| `routeData` | `Data?` (externer Speicher) | nein | Route, siehe 3.3 |
| `sourceApp` | `String?` | ja (fachlich) | Bundle-ID der schreibenden App, `de.aylu.EquiTraining` |
| `note` | `String` | ja (Standard `""`) | Notiz |
| `horse` | `Horse?` | ja (fachlich) | Pferd; ohne Pferd zeigt EquiHealth die Einheit nicht an |

### 3.3 Route (`routeData`)

JSON-Array von `TrainingRoutePoint`, kodiert mit `TrainingRoutePoint.encode(_:)`:

```json
[
  {"latitude": 51.9540, "longitude": 7.9930, "altitude": 61.2, "timestamp": 1794300000},
  {"latitude": 51.9542, "longitude": 7.9936, "timestamp": 1794300060}
]
```

- `latitude`, `longitude`: Grad (WGS 84). `altitude`: Meter, optional. `timestamp`: Sekunden seit 1970.
- Punkte in zeitlicher Reihenfolge. Empfohlen: höchstens 1 Punkt pro 5 Sekunden, damit eine Stunde unter 100 KB bleibt.
- Die volle Route bleibt im privaten Store des Nutzers. Sie wird nie an einen Dienst übertragen (die Rundung aus NF-01 gilt nur für Wetterabfragen).
- Leere Route: `routeData = nil`. Unlesbare Daten zeigt EquiHealth als „keine Route“, ohne Fehler.

### 3.4 Anzeige in EquiHealth (F-TRAIN-04)

Durchsuchen › Training (pro aktivem Pferd):

- **Diese Woche:** Anzahl, Gesamtdauer, Distanz, Dauer nach Art, Verteilung nach Gangart.
- **Letzte 8 Wochen:** Minuten pro Woche, gestapelt nach Art.
- **Einheiten:** Liste, neueste zuerst. Die Detailansicht zeigt Werte, Gangarten und eine Karte der Route mit Startpunkt.
- **Übersicht:** Kachel „Letzte Trainingseinheit“.

Wochen beginnen mit dem ersten Wochentag der Region (in Deutschland Montag).

## 4. Deep Links (F-TRAIN-05)

| Richtung | URL | Wirkung |
| --- | --- | --- |
| → EquiHealth | `equihealth://horse/<uuid>` | macht das Pferd aktiv und zeigt seine Übersicht. Unbekannte UUIDs und andere Pfade werden ignoriert. |
| → Trainings-App | `equitraining://start?horse=<uuid>` | startet eine Aufzeichnung für das Pferd |

- Groß-/Kleinschreibung von Schema und Host ist egal; die UUID im üblichen Format mit Bindestrichen.
- Bauen und Lesen ausschließlich über `DeepLink` (EquiCore), nicht von Hand.
- EquiHealth registriert `equihealth` (`CFBundleURLTypes`) und darf `equitraining` abfragen (`LSApplicationQueriesSchemes`), beides in `Config/EquiHealth-Info.plist`.
- Die Trainings-App registriert `equitraining` und trägt `equihealth` in ihre `LSApplicationQueriesSchemes` ein.
- „Training starten“ in EquiHealth versucht, die Trainings-App zu öffnen. Schlägt das fehl (nicht installiert), blendet sich der Button auf diesem Gerät aus und erklärt warum (Q-059; `canOpenURL` ist ab iOS 27 veraltet).
- Deep Links funktionieren auch ohne Entwicklerkonto.

## 5. Speicherort heute und später (F-TRAIN-01)

### Heute (`sharedTrainingContainerEnabled = false`)

- Trainingseinheiten liegen im lokalen Store von EquiHealth. Die Trainings-App gibt es noch nicht.
- Beispiel-Einheiten erzeugt das Entwickler-Menü (nur Debug-Build: Einstellungen › Entwickler).

### Später (Entwicklerkonto, beide Apps im selben Team)

1. Beide Apps nutzen **denselben** CloudKit-Container `iCloud.de.aylu.EquiHealth` und dieselbe App Group `group.de.aylu.EquiHealth` (`FeatureFlags.cloudKitContainerIdentifier`, `FeatureFlags.appGroupIdentifier`).
2. Der Store liegt im App-Group-Container. Beide Apps erzeugen ihren `ModelContainer` mit `EquiModelContainer.make(storeDirectory: <App-Group-URL>/Library/Application Support)`:
   - Auf einem Gerät teilen sie sich die Datei.
   - Über Geräte hinweg gleicht CloudKit ab.
3. Umzug der bestehenden Daten in den App-Group-Container:
   - Vorher Backup erstellen.
   - Beim ersten Start mit eingeschaltetem Flag die Store-Dateien von `Application Support` in den App-Group-Ordner verschieben, nur wenn dort noch keine liegen.
   - Danach `sharedTrainingContainerEnabled = true`.
   - Schritte zu Capabilities und Entitlements: `ENABLE_CLOUDKIT.md`, Abschnitt 8.
4. Beide Apps müssen dieselbe oder eine neuere Version von `EquiCore` mit **demselben** Migrationsplan ausliefern. Eine ältere App darf einen neueren Store nicht öffnen.
   - Darum zuerst EquiHealth aktualisieren, dann die Trainings-App.
   - Die Trainings-App prüft beim Start `EquiMigrationPlan.schemas.count` gegen den Store und weist auf eine fällige Aktualisierung hin.
5. Konflikte: Die letzte Änderung gewinnt (F-SYNC-04). Da jede App nur ihre eigenen Entitäten schreibt, gibt es zwischen den Apps keine Schreibkonflikte.

## 6. Versionierung

- `TrainingInterface.version` steigt bei jeder Änderung an `TrainingSession`, den Feldern aus 3.1 oder den Deep Links. Die Version des Datenmodells (`schemaVersion`) steigt unabhängig davon bei jeder Schemaänderung.
- Nur additive Änderungen, wie beim Schema (F-ARCH-08): neue optionale Felder, neue `TrainingType`-Werte, neue Deep-Link-Parameter. Nie umbenennen oder entfernen.
- Beim Lesen ist jede App tolerant: Sie ignoriert unbekannte Typen und Felder, zeigt Einheiten mit höherer `interfaceVersion` an und nutzt dabei nur die bekannten Felder.
- Der Test `TrainingInterfaceTests.fieldListMatchesModel` stellt sicher, dass `TrainingInterface.trainingSessionFields` und das Modell übereinstimmen.

| Version | Änderung |
| --- | --- |
| 1 | Erste Fassung: Felder aus 3.2, Route nach 3.3, Deep Links aus 4 |

## 7. Später (KANN)

- `F-TRAIN-07`: Einheiten in EquiHealth manuell erfassen oder aus einer GPX-Datei importieren. Dann schreibt auch EquiHealth `TrainingSession`, mit `sourceApp = de.aylu.EquiHealth`. Die Datenhoheit aus 2 gilt dann pro Einheit: Jede App ändert nur Einheiten mit ihrer eigenen `sourceApp`.
