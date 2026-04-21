import Foundation

enum FirestorePaths {
    /// Firestore のユーザードキュメントは `Environment.userID` 固定（認証 UID とは別）。
    private static var userRoot: String { "users/\(EnvironmentValue.userID)" }

    static var events: String { "\(userRoot)/events" }
    static var eventTemplates: String { "\(userRoot)/eventTemplates" }
    static var tags: String { "\(userRoot)/tags" }
}
