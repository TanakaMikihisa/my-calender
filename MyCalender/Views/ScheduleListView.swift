import SwiftUI

/// 1日の予定を時間順のリストで表示（イベント＋バイトを開始時刻でソート）
struct ScheduleListView: View {
    var dayStart: Date
    var dayEnd: Date
    var events: [Event]
    var workShifts: [WorkShift]
    var tags: [Tag]
    @Binding var selectedDetailItem: ScheduleDetailItem?
    var onDeleteEvent: ((Event) -> Void)?
    var onDeleteWorkShift: ((WorkShift) -> Void)?

    private var sortedItems: [ScheduleItem] {
        let eventItems = events.map { ScheduleItem.event($0) }
        let shiftItems = workShifts.map { ScheduleItem.workShift($0) }
        return (eventItems + shiftItems)
            .filter { $0.startAt >= dayStart && $0.startAt < dayEnd }
            .sorted { $0.startAt < $1.startAt }
    }

    private func detailItem(for item: ScheduleItem) -> ScheduleDetailItem {
        switch item {
        case .event(let e): return .event(e)
        case .workShift(let s): return .workShift(s)
        }
    }

    var body: some View {
        List {
            if sortedItems.isEmpty {
                ContentUnavailableView(
                    "予定がありません",
                    systemImage: "calendar",
                    description: Text("")
                )
            } else {
                ForEach(sortedItems) { item in
                    NavigationLink(value: detailItem(for: item)) {
                        ScheduleRowView(item: item, tags: tags)
                    }
                    .contextMenu {
                        Button("詳細を開く") {
                            selectedDetailItem = detailItem(for: item)
                        }
                        Button("削除", role: .destructive) {
                            switch item {
                            case .event(let e): onDeleteEvent?(e)
                            case .workShift(let s): onDeleteWorkShift?(s)
                            }
                        }
                    } preview: {
                        ScheduleDetailView(item: detailItem(for: item), tags: tags, onRefresh: {}, onDismiss: nil)
                            .frame(width: 320, height: 400)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.white)
    }
}

private enum ScheduleItem: Identifiable {
    case event(Event)
    case workShift(WorkShift)

    var id: String {
        switch self {
        case .event(let e): return "e-\(e.id)"
        case .workShift(let s): return "s-\(s.id)"
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
    var title: String {
        switch self {
        case .event(let e): return e.title
        case .workShift: return "勤務"
        }
    }
    var note: String? {
        switch self {
        case .event(let e): return e.note
        case .workShift: return nil
        }
    }
    var colorHex: String? {
        switch self {
        case .event: return nil
        case .workShift: return "#F97316"
        }
    }
}

private struct ScheduleRowView: View {
    let item: ScheduleItem
    let tags: [Tag]

    private var tagColorHex: String? {
        switch item {
        case .event(let e):
            for id in e.tagIds {
                if let tag = tags.first(where: { $0.id == id }) {
                    return tag.colorHex
                }
            }
            return Constants.defaultBoxColorSentinel
        case .workShift:
            return "#F97316"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(scheduleBarColor(tagColorHex))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.black)
                Text("\(item.startAt.formatted(date: .omitted, time: .shortened)) 〜 \(item.endAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.black)
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func scheduleBarColor(_ colorHex: String?) -> some ShapeStyle {
        guard let hex = colorHex, hex != Constants.defaultBoxColorSentinel else {
            return AnyShapeStyle(Color(.systemGray5).opacity(0.5))
        }
        return AnyShapeStyle(Color.from(hex: hex).opacity(0.45))
    }
}

// MARK: - Preview
#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let dayEnd = cal.date(byAdding: .day, value: 1, to: today)!
    let start1 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
    let end1 = cal.date(bySettingHour: 10, minute: 30, second: 0, of: today)!
    let events = [
        Event(id: "pe1", type: .normal, title: "プレビュー予定", startAt: start1, endAt: end1, note: "メモ", tagIds: ["pt1"], isActive: true, createdAt: .distantPast, updatedAt: .distantPast)
    ]
    let workShifts: [WorkShift] = []
    let tags = [Tag(id: "pt1", name: "仕事", colorHex: "#34C759", isActive: true, createdAt: .distantPast, updatedAt: .distantPast)]
    return NavigationStack {
        ScheduleListView(dayStart: today, dayEnd: dayEnd, events: events, workShifts: workShifts, tags: tags, selectedDetailItem: .constant(nil), onDeleteEvent: nil, onDeleteWorkShift: nil)
    }
}
