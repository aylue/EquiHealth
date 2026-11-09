# EquiHealth-Backupformat (`.equibackup`)

Definiert in `EquiCore/Sources/EquiCore/Backup` (F-BACKUP-01, F-BACKUP-02). Diese Beschreibung gilt ab Schemaversion 3.

## Aufbau

Ein Backup ist ein Paket (Ordner mit der Endung `.equibackup`, UTI `de.aylu.equihealth.backup`, konform zu `com.apple.package`):

```
EquiHealth-Backup-2026-11-10.equibackup/
  backup.json            alle Datensätze
  photos/<pferd-id>.jpg  Pferdefotos
  attachments/<id>.<ext> Fotos und PDFs von Symptomen und Behandlungen
  routes/<id>.json       Routen von Trainingseinheiten
```

Der Wetter-Cache ist nicht enthalten; er wird bei Bedarf neu geladen.

## `backup.json`

UTF-8, JSON. Datumswerte sind ISO 8601 mit Millisekunden in UTC (`2026-11-10T09:40:00.000Z`); beim Lesen werden auch Werte ohne Nachkommastellen akzeptiert.

| Feld | Inhalt |
| --- | --- |
| `schemaVersion` | Version des Datenmodells, mit dem das Backup erstellt wurde (aktuell 3) |
| `appVersion` | App-Version, z. B. `0.1 (1)` |
| `exportedAt` | Zeitpunkt der Erstellung |
| `horses`, `stables`, `stableAssignments`, `measurements`, `referenceRanges`, `feeds`, `feedingPlanItems`, `feedingLogs`, `symptoms`, `conditions`, `treatments`, `medications`, `contacts`, `reminderRules`, `attachments`, `trainingSessions` | Listen der Datensätze |

Jeder Datensatz hat ein Objekt `meta` mit `id` (UUID), `createdAt`, `updatedAt`, `createdBy`, `lastModifiedBy`. Beziehungen stehen als UUID-Felder (`horseID`, `feedID`, `treatmentID` …). Felder mit festen Auswahlwerten (`typeRaw`, `kindRaw` …) enthalten die englischen Rohwerte der Swift-Enums in `EquiCore/Model/ValueTypes.swift`. Binärdaten stehen nicht im JSON, sondern als Pfad (`photoFile`, `file`, `routeFile`) auf eine Datei im Paket. Ausnahme: `symptoms[].detailsData` (kleines JSON, Base64).

## Versionen und Kompatibilität (F-BACKUP-04)

| schemaVersion | Neu gegenüber der Vorversion |
| --- | --- |
| 1 | Grundmodell |
| 2 | `referenceRanges` (Referenzbereiche pro Pferd und Messtyp) |
| 3 | `feedingLogs[].kindRaw` (`extra`, `replacement`, `omission`) und `feedingLogs[].mealRaw` |

Regeln:

- Felder und Listen werden nur ergänzt, nie umbenannt oder entfernt. Spätere Ergänzungen sind optional, damit ältere Backups lesbar bleiben (fehlendes `kindRaw` bedeutet `extra`).
- Ein Backup mit höherer `schemaVersion` als die App kennt wird abgelehnt („bitte App aktualisieren“).

## Wiederherstellen (F-BACKUP-03, NF-06)

- **Vorschau** vor dem Import: Erstellungsdatum, App- und Schemaversion, Pferde, Anzahl der Einträge und Dateien.
- **Zusammenführen:** Datensätze, deren UUID bereits existiert, werden übersprungen; nichts wird doppelt angelegt. Vorhandene Einträge werden nicht überschrieben.
- **Ersetzen:** Alle Daten auf dem Gerät werden gelöscht und durch das Backup ersetzt.
- Der Import ist eine Transaktion: Erst werden Version und alle referenzierten Dateien geprüft. Dann werden Löschen (bei „Ersetzen“) und Einfügen mit einem einzigen Speichervorgang übernommen oder bei einem Fehler vollständig zurückgerollt.
