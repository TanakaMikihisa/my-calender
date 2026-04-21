import FirebaseFirestore
import Foundation

enum EventType: String, Sendable, Codable {
    case normal
}

struct Event: Identifiable, Sendable, Hashable {
    var id: EventID
    var type: EventType
    var title: String
    var startAt: Date
    var endAt: Date
    var note: String?
    var tagIds: [TagID]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct EventTemplate: Identifiable, Sendable, Hashable {
    var id: EventTemplateID
    var title: String
    var note: String?
    /// "HH:mm"
    var startTime: String
    /// "HH:mm"
    var endTime: String
    var tagIds: [TagID]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct Tag: Identifiable, Sendable, Hashable {
    var id: TagID
    var name: String
    var colorHex: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

/// 表示用の集約モデル（Firestoreの正とは別）
struct Day: Sendable, Hashable {
    var date: Date
    var events: [Event]
    var memo: String?
    var condition: String?
}
