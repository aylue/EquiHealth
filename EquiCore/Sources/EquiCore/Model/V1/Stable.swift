import Foundation
import SwiftData

extension EquiSchemaV1 {
  /// A location used for weather lookups (F-WETTER-02). Not owned by a single user (F-TEIL-01).
  @Model
  public final class Stable: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var name: String = ""
    public var locality: String?
    /// Full-precision coordinates; rounded to 2 decimals only when sent to the weather API (NF-01).
    public var latitude: Double?
    public var longitude: Double?

    @Relationship(deleteRule: .cascade, inverse: \StableAssignment.stable)
    public var assignments: [StableAssignment]? = []

    public init(name: String, latitude: Double? = nil, longitude: Double? = nil) {
      self.name = name
      self.latitude = latitude
      self.longitude = longitude
    }
  }

  /// Which horse stood at which stable during which period (F-PFERD-04).
  @Model
  public final class StableAssignment: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var validFrom: Date = Date()
    /// `nil` = current assignment.
    public var validUntil: Date?

    public var horse: Horse?
    public var stable: Stable?

    public init(horse: Horse?, stable: Stable?, validFrom: Date, validUntil: Date? = nil) {
      self.horse = horse
      self.stable = stable
      self.validFrom = validFrom
      self.validUntil = validUntil
    }
  }
}
