import EquiCore
import MapKit
import SwiftUI

/// One training session with its route on a map (F-TRAIN-04). Read-only (F-TRAIN-02).
struct TrainingDetailView: View {
  let session: TrainingSession

  var body: some View {
    let route = session.route
    List {
      if route.count >= 2 {
        Section {
          RouteMap(points: route)
            .frame(height: 260)
            .listRowInsets(EdgeInsets())
        }
      }

      Section {
        LabeledContent("Art") {
          HStack(spacing: 6) {
            Image(systemName: session.type.systemImage)
              .foregroundStyle(Color.categoryTraining)
              .accessibilityHidden(true)
            Text(session.type.title)
          }
        }
        LabeledContent("Beginn", value: session.start.formatted(date: .long, time: .shortened))
        LabeledContent("Dauer", value: TrainingFormat.duration(session.duration))
        if let distance = session.distance {
          LabeledContent("Distanz", value: TrainingFormat.distance(distance))
        }
        if let average = session.heartRateAverage {
          LabeledContent("Herzfrequenz Ø", value: TrainingFormat.heartRate(average))
        }
        if let maximum = session.heartRateMax {
          LabeledContent("Herzfrequenz max.", value: TrainingFormat.heartRate(maximum))
        }
      }

      let gaits: [(Gait, Double?)] = [
        (.walk, session.walkDuration), (.trot, session.trotDuration), (.canter, session.canterDuration),
      ]
      if gaits.contains(where: { $0.1 != nil }) {
        Section("Gangarten") {
          ForEach(gaits, id: \.0) { gait, seconds in
            LabeledContent(gait.title, value: seconds.map(TrainingFormat.duration) ?? "–")
              .accessibilityIdentifier("training.gait.\(gait.rawValue)")
          }
        }
      }

      if !session.note.isEmpty {
        Section("Notiz") { Text(session.note) }
      }

      Section {
      } footer: {
        Text(sourceText)
      }
    }
    .navigationTitle(session.type.title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var sourceText: String {
    switch session.sourceApp {
    case TrainingInterface.sampleSourceApp?: String(localized: "Beispiel-Einheit aus dem Entwickler-Menü.")
    case let source?: String(localized: "Aufgezeichnet von \(source).")
    case nil: String(localized: "Quelle unbekannt.")
    }
  }
}

/// Route as a line with start marker.
struct RouteMap: View {
  let points: [TrainingRoutePoint]

  var body: some View {
    let coordinates = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    Map(initialPosition: .rect(Self.boundingRect(coordinates))) {
      MapPolyline(coordinates: coordinates)
        .stroke(Color.categoryTraining, lineWidth: 4)
      if let start = coordinates.first {
        Marker(String(localized: "Start"), systemImage: "flag", coordinate: start)
          .tint(.green)
      }
    }
    .mapStyle(.standard(elevation: .flat))
    .accessibilityLabel(Text("Karte der Route"))
    .accessibilityIdentifier("training.map")
  }

  static func boundingRect(_ coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
    let rect = coordinates.map { MKMapPoint($0) }.reduce(MKMapRect.null) {
      $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 1, height: 1)))
    }
    return rect.insetBy(dx: -rect.size.width * 0.2 - 200, dy: -rect.size.height * 0.2 - 200)
  }
}
