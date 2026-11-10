import Charts
import EquiCore
import SwiftUI

/// "Training" of one horse: week overview, "Training starten" and the list of sessions (F-TRAIN-04,
/// F-TRAIN-05). Sessions are written by the training app and read-only here (F-TRAIN-02).
struct TrainingListView: View {
  @Environment(\.openURL) private var openURL
  /// Set when opening the training app failed; the button is then hidden on this device (F-TRAIN-05).
  @AppStorage("trainingAppMissing") private var trainingAppMissing = false
  let horse: Horse

  private static let weekCount = 8

  var body: some View {
    let sessions = horse.sortedTrainingSessions
    let weeks = horse.trainingWeeks(Self.weekCount)
    List {
      // ANNAHME: `canOpenURL` ist ab iOS 27 veraltet. Statt vorab zu prüfen, versucht der Button die
      // Trainings-App zu öffnen und blendet sich nach einem Fehlschlag auf diesem Gerät aus. Q-059.
      Section {
        if !trainingAppMissing {
          Button("Training starten", systemImage: "play.fill") {
            openURL(DeepLink.trainingStart(horseID: horse.id)) { accepted in
              if !accepted { trainingAppMissing = true }
            }
          }
          .accessibilityIdentifier("training.start")
        }
      } footer: {
        if trainingAppMissing {
          Text("Die Trainings-App ist auf diesem Gerät nicht installiert.")
            .accessibilityIdentifier("training.appMissing")
        }
      }

      if sessions.isEmpty {
        ContentUnavailableView {
          Label("Keine Trainingseinheiten", systemImage: "figure.equestrian.sports")
        } description: {
          Text("Einheiten zeichnet die geplante Trainings-App auf. Sie erscheinen dann hier.")
        }
      } else {
        if let current = weeks.last {
          Section {
            WeekSummaryView(summary: current)
          } header: {
            Text("Diese Woche")
          }
        }
        Section {
          WeeklyDurationChart(weeks: weeks)
        } header: {
          Text("Letzte \(Self.weekCount) Wochen")
        }
        Section("Einheiten") {
          ForEach(sessions) { session in
            NavigationLink {
              TrainingDetailView(session: session)
            } label: {
              TrainingSessionRow(session: session)
            }
            .accessibilityIdentifier("training.session")
          }
        }
      }
    }
    .navigationTitle("Training")
  }
}

/// Count, duration, distance, distribution by type and gait of one week (F-TRAIN-04).
struct WeekSummaryView: View {
  let summary: TrainingWeekSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        metric(String(summary.sessionCount), title: String(localized: "Einheiten"))
        Spacer()
        metric(TrainingFormat.duration(summary.totalDuration), title: String(localized: "Dauer"))
        Spacer()
        metric(
          summary.totalDistance > 0 ? TrainingFormat.distance(summary.totalDistance) : "–",
          title: String(localized: "Distanz"))
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("training.weekSummary")

      let types = summary.durationByType.sorted { $0.value > $1.value }
      if !types.isEmpty {
        Chart(types, id: \.key) { type, seconds in
          BarMark(x: .value("Minuten", seconds / 60), y: .value("Typ", type.title))
            .foregroundStyle(Color.categoryTraining)
            .annotation(position: .trailing) {
              Text(TrainingFormat.duration(seconds)).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
          AxisMarks { _ in AxisValueLabel() }
        }
        .frame(height: CGFloat(types.count) * 28)
        .accessibilityLabel(Text("Dauer nach Trainingsart"))
      }

      let gaits = summary.gaitShares
      if !gaits.isEmpty {
        Chart(gaits, id: \.gait) { item in
          BarMark(x: .value("Anteil", item.share), stacking: .normalized)
            .foregroundStyle(by: .value("Gangart", item.gait.title))
            .annotation(position: .overlay) {
              if item.share >= 0.12 {
                Text(item.share.formatted(.percent.precision(.fractionLength(0))))
                  .font(.caption2.bold())
                  .foregroundStyle(.white)
              }
            }
        }
        .chartForegroundStyleScale([
          Gait.walk.title: Color.categoryTraining.opacity(0.45),
          Gait.trot.title: Color.categoryTraining.opacity(0.75),
          Gait.canter.title: Color.categoryTraining,
        ])
        .chartXAxis(.hidden)
        .frame(height: 56)
        .accessibilityLabel(Text("Verteilung nach Gangart"))
        .accessibilityValue(
          Text(
            gaits.map { "\($0.gait.title) \($0.share.formatted(.percent.precision(.fractionLength(0))))" }
              .joined(separator: ", ")))
      }
    }
    .padding(.vertical, 4)
  }

  private func metric(_ value: String, title: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(.title3.bold()).monospacedDigit()
      Text(title).font(.caption).foregroundStyle(.secondary)
    }
  }
}

/// Training minutes per week, stacked by type.
struct WeeklyDurationChart: View {
  let weeks: [TrainingWeekSummary]

  private struct Bar: Identifiable {
    let week: Date
    let type: TrainingType
    let minutes: Double
    var id: String { "\(week.timeIntervalSince1970)-\(type.rawValue)" }
  }

  var body: some View {
    let bars = weeks.flatMap { week in
      week.durationByType.map { Bar(week: week.weekStart, type: $0.key, minutes: $0.value / 60) }
    }
    Chart(bars) { bar in
      BarMark(x: .value("Woche", bar.week, unit: .weekOfYear), y: .value("Minuten", bar.minutes))
        .foregroundStyle(by: .value("Typ", bar.type.title))
    }
    // Fixed domain: every training type keeps its colour, independent of the data shown.
    .chartForegroundStyleScale(domain: TrainingType.allCases.map(\.title))
    .chartYAxisLabel("min")
    .frame(height: 180)
    .accessibilityLabel(Text("Trainingsminuten pro Woche"))
    .accessibilityValue(
      Text(
        weeks.map {
          "\($0.weekStart.formatted(.dateTime.day().month())): \(TrainingFormat.duration($0.totalDuration))"
        }
        .joined(separator: ", ")))
  }
}

struct TrainingSessionRow: View {
  let session: TrainingSession

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: session.type.systemImage)
        .foregroundStyle(Color.categoryTraining)
        .frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(session.type.title)
        Text(session.start.formatted(date: .abbreviated, time: .shortened))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(TrainingFormat.duration(session.duration)).monospacedDigit()
        if let distance = session.distance {
          Text(TrainingFormat.distance(distance)).font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}
