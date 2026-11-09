import Charts
import EquiCore
import SwiftUI

/// "Fütterung" in Durchsuchen: plan, day view, history and feeds.
struct FeedingOverviewView: View {
  let horse: Horse

  var body: some View {
    let plan = horse.feedingPlan(at: .now)
    List {
      Section {
        NavigationLink {
          FeedingPlanView(horse: horse)
        } label: {
          LabeledContent {
            Text(plan.isEmpty ? String(localized: "nicht angelegt") : String(localized: "\(plan.count) Positionen"))
          } label: {
            Label("Futterplan", systemImage: "list.clipboard")
          }
        }
        .accessibilityIdentifier("feeding.plan")
        NavigationLink {
          FeedingDayView(horse: horse)
        } label: {
          Label("Fütterung an Tag X", systemImage: "calendar.day.timeline.left")
        }
        .accessibilityIdentifier("feeding.day")
        NavigationLink {
          FeedingHistoryView(horse: horse)
        } label: {
          Label("Tagesmengen im Verlauf", systemImage: "chart.bar")
        }
        .accessibilityIdentifier("feeding.history")
      }
      Section {
        NavigationLink {
          FeedsView()
        } label: {
          Label("Futtermittel", systemImage: "leaf")
        }
      }
    }
    .navigationTitle("Fütterung")
  }
}

/// Daily amount per category over time (F-FUTTER-06).
struct FeedingHistoryView: View {
  let horse: Horse
  @State private var days = 30

  var body: some View {
    let end = Date.now
    let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) ?? end
    let totals = horse.dailyFeedTotals(from: start, through: end)

    List {
      Section {
        Picker("Zeitraum", selection: $days) {
          Text("30 Tage").tag(30)
          Text("90 Tage").tag(90)
          Text("1 Jahr").tag(365)
        }
        .pickerStyle(.segmented)

        if totals.isEmpty {
          Text("Keine Mengen in kg für diesen Zeitraum.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
          Chart(Array(totals.enumerated()), id: \.offset) { _, total in
            BarMark(
              x: .value("Tag", total.day, unit: .day),
              y: .value("Menge in kg", total.kilograms)
            )
            .foregroundStyle(by: .value("Kategorie", total.category.title))
            .accessibilityLabel(Text(total.day.formatted(date: .abbreviated, time: .omitted)))
            .accessibilityValue(Text("\(total.category.title): \(FeedUnit.kilogram.format(total.kilograms))"))
          }
          .chartYAxisLabel("kg")
          .frame(height: 260)
        }
      } footer: {
        Text("Aus Futterplan und Zusatzgaben. Nur Mengen in kg und g werden berücksichtigt.")
      }
    }
    .navigationTitle("Tagesmengen")
  }
}
