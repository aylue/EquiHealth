import Foundation
import SwiftData

extension EquiSchemaV3 {
  /// A photo or PDF (finding, invoice, passport page). Belongs to a symptom, a treatment or
  /// directly to a horse.
  @Model
  public final class Attachment: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    @Attribute(.externalStorage) public var fileData: Data?
    /// Uniform Type Identifier, e.g. `public.jpeg` or `com.adobe.pdf`.
    public var contentType: String = "public.data"
    public var title: String = ""
    public var fileName: String?

    public var horse: Horse?
    public var symptom: SymptomEntry?
    public var treatment: Treatment?

    public init(fileData: Data?, contentType: String, title: String = "") {
      self.fileData = fileData
      self.contentType = contentType
      self.title = title
    }
  }
}
