import Foundation

/// Type-specific details of a symptom (SPEC section 3). Persisted JSON-encoded in
/// `SymptomEntry.detailsData`. Only add optional fields so that older data keeps decoding.
public struct SymptomDetails: Codable, Equatable, Sendable {
  public var cough: Cough?
  public var muscleStiffness: MuscleStiffness?
  public var colic: Colic?
  public var eyeInflammation: EyeInflammation?

  public init(
    cough: Cough? = nil,
    muscleStiffness: MuscleStiffness? = nil,
    colic: Colic? = nil,
    eyeInflammation: EyeInflammation? = nil
  ) {
    self.cough = cough
    self.muscleStiffness = muscleStiffness
    self.colic = colic
    self.eyeInflammation = eyeInflammation
  }

  public struct Cough: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable { case dry, wet }
    public enum Situation: String, Codable, Sendable, CaseIterable { case rest, work, feeding }

    public var kind: Kind?
    public var hasNasalDischarge: Bool?
    public var nasalDischargeColor: String?
    public var situations: [Situation]?

    public init(
      kind: Kind? = nil, hasNasalDischarge: Bool? = nil, nasalDischargeColor: String? = nil,
      situations: [Situation]? = nil
    ) {
      self.kind = kind
      self.hasNasalDischarge = hasNasalDischarge
      self.nasalDischargeColor = nasalDischargeColor
      self.situations = situations
    }
  }

  public struct MuscleStiffness: Codable, Equatable, Sendable {
    public var affectedRegion: String?
    public var afterWork: Bool?
    public var musclesHard: Bool?

    public init(affectedRegion: String? = nil, afterWork: Bool? = nil, musclesHard: Bool? = nil) {
      self.affectedRegion = affectedRegion
      self.afterWork = afterWork
      self.musclesHard = musclesHard
    }
  }

  public struct Colic: Codable, Equatable, Sendable {
    public enum Sign: String, Codable, Sendable, CaseIterable {
      case pawing, rolling, sweating, noManure
    }

    /// Duration in seconds.
    public var duration: TimeInterval?
    public var signs: [Sign]?
    public var veterinarianCalled: Bool?

    public init(duration: TimeInterval? = nil, signs: [Sign]? = nil, veterinarianCalled: Bool? = nil) {
      self.duration = duration
      self.signs = signs
      self.veterinarianCalled = veterinarianCalled
    }
  }

  public struct EyeInflammation: Codable, Equatable, Sendable {
    public enum Eye: String, Codable, Sendable, CaseIterable { case left, right, both }

    public var eye: Eye?
    public var tearing: Bool?
    public var swelling: Bool?
    public var photosensitivity: Bool?

    public init(eye: Eye? = nil, tearing: Bool? = nil, swelling: Bool? = nil, photosensitivity: Bool? = nil) {
      self.eye = eye
      self.tearing = tearing
      self.swelling = swelling
      self.photosensitivity = photosensitivity
    }
  }
}
