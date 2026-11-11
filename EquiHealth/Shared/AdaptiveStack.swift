import SwiftUI

/// Side by side normally, stacked at accessibility text sizes, so labels are not squeezed into
/// single letters (F-UI-07, NF-07).
struct AdaptiveStack<Content: View>: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  var horizontalAlignment: VerticalAlignment = .center
  var spacing: CGFloat? = nil
  @ViewBuilder let content: () -> Content

  var body: some View {
    let layout =
      dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
      : AnyLayout(HStackLayout(alignment: horizontalAlignment, spacing: spacing))
    layout(content)
  }
}

/// `Spacer` only when laid out side by side.
struct AdaptiveSpacer: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
  }
}
