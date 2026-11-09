import EquiCore
import PhotosUI
import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Editable copy of an attachment used by forms; written to the model on save.
struct AttachmentDraft: Identifiable, Equatable {
  let id: UUID
  /// Set when the draft represents an existing `Attachment`.
  var existingID: UUID?
  var data: Data
  var contentType: UTType
  var title: String

  init(data: Data, contentType: UTType, title: String = "") {
    id = UUID()
    self.data = data
    self.contentType = contentType
    self.title = title
  }

  init?(_ attachment: Attachment) {
    guard let data = attachment.fileData else { return nil }
    id = attachment.id
    existingID = attachment.id
    self.data = data
    contentType = UTType(attachment.contentType) ?? .data
    title = attachment.title
  }

  var isImage: Bool { contentType.conforms(to: .image) }

  /// Writes drafts to the model: updates kept attachments, inserts new ones, deletes removed ones.
  /// `link` connects a new attachment to its owner (symptom or treatment).
  static func apply(
    _ drafts: [AttachmentDraft], existing: [Attachment], in context: ModelContext,
    link: (Attachment) -> Void
  ) {
    let keptIDs = Set(drafts.compactMap(\.existingID))
    for attachment in existing where !keptIDs.contains(attachment.id) {
      context.delete(attachment)
    }
    for draft in drafts {
      if let existingID = draft.existingID, let attachment = existing.first(where: { $0.id == existingID }) {
        if attachment.title != draft.title {
          attachment.title = draft.title
          attachment.touch()
        }
      } else {
        let attachment = Attachment(
          fileData: draft.data, contentType: draft.contentType.identifier, title: draft.title)
        context.insert(attachment)
        link(attachment)
      }
    }
  }
}

/// Form section to add photos (and optionally PDFs) and remove them again.
struct AttachmentEditorSection: View {
  @Binding var drafts: [AttachmentDraft]
  var allowsDocuments = false

  @State private var photoItems: [PhotosPickerItem] = []
  @State private var showsFileImporter = false

  var body: some View {
    Section {
      if !drafts.isEmpty {
        ScrollView(.horizontal) {
          HStack(spacing: 12) {
            ForEach(drafts) { draft in
              AttachmentThumbnail(data: draft.data, isImage: draft.isImage, title: draft.title)
                .overlay(alignment: .topTrailing) {
                  Button("Entfernen", systemImage: "xmark.circle.fill") {
                    drafts.removeAll { $0.id == draft.id }
                  }
                  .labelStyle(.iconOnly)
                  .symbolRenderingMode(.palette)
                  .foregroundStyle(.white, .black.opacity(0.6))
                  .buttonStyle(.borderless)
                  .padding(4)
                }
            }
          }
          .padding(.vertical, 4)
        }
      }
      PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
        Label("Fotos hinzufügen", systemImage: "photo.badge.plus")
      }
      .accessibilityIdentifier("attachments.addPhotos")
      #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting) {
          // UI tests cannot drive the out-of-process photo picker reliably; this adds a generated
          // image through the same draft path instead.
          Button("Testfoto hinzufügen", systemImage: "photo") {
            if let data = Self.generatedTestPhoto() {
              drafts.append(AttachmentDraft(data: data, contentType: .jpeg))
            }
          }
          .accessibilityIdentifier("attachments.addTestPhoto")
        }
      #endif
      if allowsDocuments {
        Button("PDF hinzufügen", systemImage: "doc.badge.plus") { showsFileImporter = true }
      }
    } header: {
      Text(allowsDocuments ? "Anhänge" : "Fotos")
    }
    .onChange(of: photoItems) { _, items in
      guard !items.isEmpty else { return }
      Task {
        for item in items {
          if let data = try? await item.loadTransferable(type: Data.self),
            let jpeg = ImageDownscaler.jpegData(from: data, maxDimension: 2048)
          {
            drafts.append(AttachmentDraft(data: jpeg, contentType: .jpeg))
          }
        }
        photoItems = []
      }
    }
    .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) {
      result in
      guard case .success(let urls) = result else { return }
      for url in urls {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url) {
          drafts.append(
            AttachmentDraft(data: data, contentType: .pdf, title: url.deletingPathExtension().lastPathComponent))
        }
      }
    }
  }
}

#if DEBUG
  extension AttachmentEditorSection {
    /// Solid-colour JPEG used by UI tests.
    static func generatedTestPhoto() -> Data? {
      let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
      let image = renderer.image { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
      }
      return image.jpegData(compressionQuality: 0.8)
    }
  }
#endif

/// Square preview of an image or document.
struct AttachmentThumbnail: View {
  let data: Data
  let isImage: Bool
  let title: String
  var size: CGFloat = 80

  var body: some View {
    Group {
      if isImage, let image = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: size * 3, height: size * 3)) {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        VStack(spacing: 4) {
          Image(systemName: "doc.richtext").font(.title)
          Text(title.isEmpty ? String(localized: "PDF") : title).font(.caption2).lineLimit(2)
        }
        .padding(6)
        .foregroundStyle(.secondary)
      }
    }
    .frame(width: size, height: size)
    .background(.fill.tertiary)
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement()
    .accessibilityLabel(Text(isImage ? "Foto" : "Dokument \(title)"))
    .accessibilityIdentifier("attachment.thumbnail")
  }
}

/// Read-only gallery of stored attachments; tapping opens Quick Look.
struct AttachmentGallery: View {
  let attachments: [Attachment]
  @State private var previewURL: URL?

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 12) {
        ForEach(attachments.sorted { $0.createdAt < $1.createdAt }) { attachment in
          if let data = attachment.fileData {
            Button {
              previewURL = Self.temporaryFile(for: attachment, data: data)
            } label: {
              AttachmentThumbnail(
                data: data, isImage: UTType(attachment.contentType)?.conforms(to: .image) ?? false,
                title: attachment.title)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.vertical, 4)
    }
    .quickLookPreview($previewURL)
  }

  private static func temporaryFile(for attachment: Attachment, data: Data) -> URL? {
    let ext = UTType(attachment.contentType)?.preferredFilenameExtension ?? "dat"
    let url = FileManager.default.temporaryDirectory.appending(path: "\(attachment.id.uuidString).\(ext)")
    do {
      try data.write(to: url, options: .atomic)
      return url
    } catch {
      return nil
    }
  }
}
