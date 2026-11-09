import SwiftUI
import UIKit

/// Round horse photo, or a placeholder symbol without photo.
struct HorseAvatar: View {
  let photoData: Data?
  var size: CGFloat = 32

  var body: some View {
    Group {
      if let photoData, let image = UIImage(data: photoData) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Image(systemName: "figure.equestrian.sports")
          .resizable()
          .scaledToFit()
          .padding(size * 0.2)
          .foregroundStyle(.tint)
          .background(.fill.tertiary)
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .accessibilityHidden(true)
  }
}

enum ImageDownscaler {
  /// Shrinks a picked photo to at most `maxDimension` points and re-encodes it as JPEG.
  static func jpegData(from data: Data, maxDimension: CGFloat = 1024) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let longest = max(image.size.width, image.size.height)
    let scale = min(1, maxDimension / longest)
    let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let resized = image.preparingThumbnail(of: target) ?? image
    return resized.jpegData(compressionQuality: 0.8)
  }
}
