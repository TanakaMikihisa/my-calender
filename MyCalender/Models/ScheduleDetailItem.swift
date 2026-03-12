import Foundation

/// 予定詳細・編集で使う共通の型（Event または WorkShift）
enum ScheduleDetailItem: Hashable {
    case event(Event)
    case workShift(WorkShift)

    var title: String {
        switch self {
        case .event(let e): return e.title
        case .workShift: return "勤務"
        }
    }

    var startAt: Date {
        switch self {
        case .event(let e): return e.startAt
        case .workShift(let s): return s.startAt
        }
    }

    var endAt: Date {
        switch self {
        case .event(let e): return e.endAt
        case .workShift(let s): return s.endAt
        }
    }

    var note: String? {
        switch self {
        case .event(let e): return e.note
        case .workShift: return nil
        }
    }
}
