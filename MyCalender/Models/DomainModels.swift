import Foundation
import FirebaseFirestore

enum EventType: String, Sendable, Codable {
    case normal
}

enum WorkPayType: String, Sendable, Codable {
    case hourly
    case fixed
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

struct WorkShift: Identifiable, Sendable, Hashable {
    var id: WorkShiftID
    var startAt: Date
    var endAt: Date
    var payType: WorkPayType
    var payRateId: PayRateID?
    var fixedPay: Decimal?
    var templateId: ShiftTemplateID?
    var tagIds: [TagID]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct ShiftTemplate: Identifiable, Sendable, Hashable {
    var id: ShiftTemplateID
    var title: String
    /// "HH:mm"
    var startTime: String
    /// "HH:mm"（日跨ぎ可）
    var endTime: String
    var payType: WorkPayType
    var payRateId: PayRateID?
    var fixedPay: Decimal?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct PayRate: Identifiable, Sendable, Hashable {
    var id: PayRateID
    var title: String
    var hourlyWage: Decimal
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
    var workShifts: [WorkShift]
    var memo: String?
    var condition: String?
}

