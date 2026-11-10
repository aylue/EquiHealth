import EquiCore
import Foundation
import Testing

@testable import EquiHealth

@Suite("Phase 7: ohne iCloud-Entitlement lauffähig (F-ARCH-05, F-ARCH-07, SPEC 4.10)")
@MainActor
struct SyncPreparationAppTests {
  /// Project file next to the test sources (the simulator shares the host file system).
  private var projectFile: URL {
    URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .appending(path: "EquiHealth.xcodeproj/project.pbxproj")
  }

  @Test("F-ARCH-07: Kein Target bindet Entitlements ein; die vorbereiteten Dateien existieren")
  func entitlementsAreNotLinked() throws {
    let project = try String(contentsOf: projectFile, encoding: .utf8)
    #expect(!project.contains("CODE_SIGN_ENTITLEMENTS"))
    #expect(!project.contains("com.apple.developer.icloud"))
    let entitlements = projectFile.deletingLastPathComponent().deletingLastPathComponent().appending(
      path: "Entitlements")
    for name in ["EquiHealth.iCloud.entitlements", "EquiHealth.AppGroup.entitlements"] {
      #expect(FileManager.default.fileExists(atPath: entitlements.appending(path: name).path()), "\(name) fehlt")
    }
  }

  @Test("SPEC 4.10: Sync-Monitor meldet „noch nicht verfügbar“ und fasst CloudKit nicht an")
  func monitorStaysOff() async {
    let monitor = CloudSyncMonitor()
    await monitor.start()
    await monitor.refreshAccount()
    #expect(monitor.status == .notAvailable)
    #expect(monitor.status.title == "Noch nicht verfügbar")
    #expect(monitor.status.explanation?.contains("Backup") == true)
  }
}
