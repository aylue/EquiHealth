import SwiftUI

extension Binding where Value == Bool? {
  /// Treats `nil` as `false` for toggles.
  var orFalse: Binding<Bool> {
    Binding<Bool>(get: { wrappedValue ?? false }, set: { wrappedValue = $0 })
  }
}

extension Binding {
  /// Toggle binding for membership of `element` in an optional array; empty arrays become `nil`.
  func contains<Element: Equatable>(_ element: Element) -> Binding<Bool> where Value == [Element]? {
    Binding<Bool>(
      get: { wrappedValue?.contains(element) ?? false },
      set: { isOn in
        var array = wrappedValue ?? []
        if isOn {
          if !array.contains(element) { array.append(element) }
        } else {
          array.removeAll { $0 == element }
        }
        wrappedValue = array.isEmpty ? nil : array
      })
  }
}
