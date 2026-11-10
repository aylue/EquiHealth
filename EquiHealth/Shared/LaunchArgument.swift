/// Launch arguments understood by the app.
enum LaunchArgument {
  /// Uses an in-memory store so UI tests start from a clean state.
  static let uiTesting = "-uiTesting"
  /// Debug builds only: pretend the database cannot be opened (Q-010).
  static let simulateStoreFailure = "-simulateStoreFailure"
}
