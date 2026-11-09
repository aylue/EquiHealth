import CoreLocation
import EquiCore
import MapKit
import SwiftUI

/// Location of a stable for weather lookups (F-WETTER-02): current location once (CoreLocation),
/// place search (MapKit) or manual coordinates. Only the rounded coordinates leave the device (NF-01).
struct StableLocationSection: View {
  @Binding var coordinate: CLLocationCoordinate2D?
  @Binding var locality: String

  @State private var query = ""
  @State private var results: [SearchResult] = []
  @State private var isSearching = false
  @State private var isLocating = false
  @State private var message: String?
  @State private var latitudeText = ""
  @State private var longitudeText = ""
  @State private var showsManualEntry = false

  struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
  }

  var body: some View {
    Section {
      if let coordinate {
        Map(
          initialPosition: .region(
            MKCoordinateRegion(center: coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000))
        ) {
          Marker(locality.isEmpty ? String(localized: "Stall") : locality, coordinate: coordinate)
        }
        .frame(height: 160)
        .allowsHitTesting(false)
        .id("\(coordinate.latitude),\(coordinate.longitude)")
        .listRowInsets(EdgeInsets())
        .accessibilityLabel(Text("Karte mit dem Standort des Stalls"))
        LabeledContent("Für Wetterdaten") {
          Text(
            "\(CoordinateRounding.rounded(coordinate.latitude).formatted(.number.precision(.fractionLength(2)))), \(CoordinateRounding.rounded(coordinate.longitude).formatted(.number.precision(.fractionLength(2))))"
          )
          .monospacedDigit()
        }
        .accessibilityIdentifier("stable.roundedCoordinate")
        Button("Standort entfernen", role: .destructive) { self.coordinate = nil }
      }

      Button {
        Task { await useCurrentLocation() }
      } label: {
        HStack {
          Label("Aktuellen Standort verwenden", systemImage: "location")
          if isLocating {
            Spacer()
            ProgressView()
          }
        }
      }
      .disabled(isLocating)

      HStack {
        TextField("Ort oder Adresse suchen", text: $query)
          .textContentType(.fullStreetAddress)
          .submitLabel(.search)
          .onSubmit { Task { await search() } }
        if isSearching {
          ProgressView()
        } else {
          Button("Suchen", systemImage: "magnifyingglass") { Task { await search() } }
            .labelStyle(.iconOnly)
            .disabled(query.nilIfBlank == nil)
        }
      }
      ForEach(results) { result in
        Button {
          coordinate = result.coordinate
          if locality.isEmpty { locality = result.title }
          results = []
          query = ""
        } label: {
          VStack(alignment: .leading) {
            Text(result.title).foregroundStyle(.primary)
            if !result.subtitle.isEmpty {
              Text(result.subtitle).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }

      DisclosureGroup("Koordinaten eingeben", isExpanded: $showsManualEntry) {
        TextField("Breitengrad, z. B. 51,96", text: $latitudeText)
          .keyboardType(.numbersAndPunctuation)
          .accessibilityIdentifier("stable.latitude")
        TextField("Längengrad, z. B. 7,63", text: $longitudeText)
          .keyboardType(.numbersAndPunctuation)
          .accessibilityIdentifier("stable.longitude")
        Button("Koordinaten übernehmen") { applyManualCoordinates() }
          .disabled(manualCoordinate == nil)
          .accessibilityIdentifier("stable.applyCoordinates")
      }
      .accessibilityIdentifier("stable.manualCoordinates")

      if let message {
        Text(message).font(.footnote).foregroundStyle(.secondary)
      }
    } header: {
      Text("Standort für Wetterdaten")
    } footer: {
      Text(
        "Der Standort bleibt auf dem Gerät. Für Wetterabfragen werden nur auf 2 Nachkommastellen gerundete Koordinaten (ca. 1 km) an Bright Sky übertragen."
      )
    }
  }

  private var manualCoordinate: CLLocationCoordinate2D? {
    guard let latitude = DecimalInput.parse(latitudeText), let longitude = DecimalInput.parse(longitudeText),
      (-90...90).contains(latitude), (-180...180).contains(longitude)
    else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  private func applyManualCoordinates() {
    guard let manualCoordinate else { return }
    coordinate = manualCoordinate
    showsManualEntry = false
    message = nil
  }

  private func search() async {
    guard let text = query.nilIfBlank else { return }
    isSearching = true
    defer { isSearching = false }
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = text
    request.resultTypes = [.address, .pointOfInterest]
    do {
      let response = try await MKLocalSearch(request: request).start()
      results = response.mapItems.prefix(5).map { item in
        SearchResult(
          title: item.name ?? text, subtitle: item.address?.shortAddress ?? "",
          coordinate: item.location.coordinate)
      }
      message = results.isEmpty ? String(localized: "Keine Treffer.") : nil
    } catch {
      results = []
      message = String(localized: "Die Suche ist gerade nicht möglich. Du kannst die Koordinaten auch eingeben.")
    }
  }

  /// Uses the current location once (SPEC 2: CoreLocation once when creating a stable).
  private func useCurrentLocation() async {
    isLocating = true
    defer { isLocating = false }
    let session = CLServiceSession(authorization: .whenInUse)
    defer { session.invalidate() }
    do {
      for try await update in CLLocationUpdate.liveUpdates() {
        if let location = update.location {
          coordinate = location.coordinate
          message = nil
          return
        }
        if update.authorizationDenied || update.authorizationDeniedGlobally {
          message = String(localized: "Standortzugriff ist nicht erlaubt. Suche den Ort stattdessen.")
          return
        }
      }
    } catch {
      message = String(localized: "Der Standort konnte nicht ermittelt werden.")
    }
  }
}
