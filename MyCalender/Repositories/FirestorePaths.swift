import Foundation

enum FirestorePaths {
    static func userRoot(uid: String) -> String { "users/\(uid)" }
    static func events(uid: String) -> String { "\(userRoot(uid: uid))/events" }
    static func workShifts(uid: String) -> String { "\(userRoot(uid: uid))/workShifts" }
    static func shiftTemplates(uid: String) -> String { "\(userRoot(uid: uid))/shiftTemplates" }
    static func payRates(uid: String) -> String { "\(userRoot(uid: uid))/payRates" }
    static func tags(uid: String) -> String { "\(userRoot(uid: uid))/tags" }
}

