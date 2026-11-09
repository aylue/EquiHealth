import EquiCore
import SwiftUI

/// "Übersicht" tab, like "Summary" in Apple Health: pinned measurements with a mini chart.
/// Shows ongoing symptoms (F-GESUND-03) and running withdrawal periods (F-BEH-09) on top.
/// Also shows reminders due within 30 days. Training follows in a later phase.
struct OverviewView: View {
  @Environment(AppState.self) private var appState
  @State private var showsPinEditor = false

  var body: some View {
    NavigationStack {
      ActiveHorseReader { horse in
        if let horse {
          List {
            if !horse.ongoingSymptoms.isEmpty {
              Section("Laufende Symptome") {
                ForEach(horse.ongoingSymptoms) { symptom in
                  OngoingSymptomRow(symptom: symptom)
                }
              }
            }
            let upcoming = upcomingReminders(of: horse)
            if !upcoming.isEmpty {
              Section("Demnächst fällig") {
                ForEach(upcoming) { rule in
                  Button {
                    appState.sheet = .editReminder(rule.id)
                  } label: {
                    ReminderRow(rule: rule, showsHorse: false)
                  }
                  .foregroundStyle(.primary)
                }
              }
            }
            if !horse.activeWithdrawals().isEmpty {
              Section("Warte- und Karenzzeiten") {
                WithdrawalNoticeRows(horse: horse)
              }
            }
            Section("Angeheftet") {
              if appState.pinnedMeasurementTypes.isEmpty {
                Text("Keine Messwerte angeheftet").foregroundStyle(.secondary)
              }
              ForEach(appState.pinnedMeasurementTypes) { type in
                NavigationLink {
                  MeasurementDetailView(horse: horse, type: type)
                } label: {
                  PinnedMeasurementCard(horse: horse, type: type)
                }
                .accessibilityIdentifier("pinned.\(type.rawValue)")
              }
            }
            Section {
              Button("Angeheftete Werte bearbeiten", systemImage: "pin") { showsPinEditor = true }
            }
          }
        } else {
          NoHorseView()
        }
      }
      .navigationTitle("Übersicht")
      .appToolbar()
      .sheet(isPresented: $showsPinEditor) {
        PinEditor()
      }
    }
  }
}

extension OverviewView {
  /// Overdue reminders and those due within 30 days, soonest first, at most three.
  fileprivate func upcomingReminders(of horse: Horse) -> [ReminderRule] {
    let limit = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    return (horse.reminderRules ?? [])
      .filter(\.isActive)
      .compactMap { rule in rule.nextDueDate().map { (rule, $0) } }
      .filter { $0.1 <= limit }
      .sorted { $0.1 < $1.1 }
      .prefix(3)
      .map(\.0)
  }
}

/// Card with latest value and a 30-day sparkline.
private struct PinnedMeasurementCard: View {
  let horse: Horse
  let type: MeasurementType

  var body: some View {
    let all = (horse.measurements ?? []).filter { $0.typeRaw == type.rawValue }
    let latest = all.max { $0.timestamp < $1.timestamp }
    let since = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    let recent = all.filter { $0.timestamp >= since }.sorted { $0.timestamp < $1.timestamp }

    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(type.title, systemImage: type.systemImage)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.categoryMeasurements)
        Spacer()
        if let latest {
          Text(latest.timestamp.formatted(.relative(presentation: .named)))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      HStack(alignment: .bottom) {
        if let latest {
          VStack(alignment: .leading) {
            Text(type.format(latest.value)).font(.title2.bold().monospacedDigit())
            if latest.isEstimated {
              Text("geschätzt").font(.caption).foregroundStyle(.secondary)
            }
          }
        } else {
          Text("Keine Daten").foregroundStyle(.secondary)
        }
        Spacer()
        if recent.count > 1 {
          MeasurementSparkline(type: type, measurements: recent)
            .frame(width: 110, height: 40)
        }
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }
}

/// Choose which measurement types are pinned to the overview.
private struct PinEditor: View {
  @Environment(AppState.self) private var appState
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List(MeasurementType.allCases) { type in
        Toggle(
          isOn: Binding(
            get: { appState.pinnedMeasurementTypes.contains(type) },
            set: { isOn in
              if isOn {
                appState.pinnedMeasurementTypes = MeasurementType.allCases.filter {
                  $0 == type || appState.pinnedMeasurementTypes.contains($0)
                }
              } else {
                appState.pinnedMeasurementTypes.removeAll { $0 == type }
              }
            })
        ) {
          Label(type.title, systemImage: type.systemImage)
        }
      }
      .navigationTitle("Angeheftet")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") { dismiss() }
        }
      }
    }
  }
}
