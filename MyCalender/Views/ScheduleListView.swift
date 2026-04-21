import SwiftUI

/// 1日の予定を時間順のリストで表示
struct ScheduleListView: View {
    var dayStart: Date
    var dayEnd: Date
    var events: [Event]
    var tags: [Tag]
    @Binding var selectedDetailItem: Event?
    var onDeleteEvent: ((Event) -> Void)?
    var onRefresh: (() async -> Void)?

    private var sortedEvents: [Event] {
        events
            .filter { $0.startAt >= dayStart && $0.startAt < dayEnd }
            .sorted { $0.startAt < $1.startAt }
    }

    var body: some View {
        if sortedEvents.isEmpty {
            ContentUnavailableView(
                "予定がありません",
                systemImage: "calendar",
                description: Text("")
            )
        } else {
            List {
                ForEach(sortedEvents) { event in
                    NavigationLink(value: event) {
                        ScheduleRowView(event: event, tags: tags)
                    }
                    .contextMenu {
                        Button("詳細を開く") {
                            FeedBack().feedback(.medium)
                            selectedDetailItem = event
                        }
                        Button("削除", role: .destructive) {
                            FeedBack().feedback(.heavy)
                            withAnimation(.easeOut(duration: 0.25)) {
                                onDeleteEvent?(event)
                            }
                        }
                    } preview: {
                        ScheduleDetailView(event: event, tags: tags, onRefresh: {}, onDismiss: nil)
                            .frame(width: 320, height: 400)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .refreshable { await onRefresh?() }
        }
    }
}

private struct ScheduleRowView: View {
    let event: Event
    let tags: [Tag]

    private var tagColorHex: String? {
        for id in event.tagIds {
            if let tag = tags.first(where: { $0.id == id }) {
                return tag.colorHex
            }
        }
        return Constants.defaultBoxColorSentinel
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(scheduleBarColor(tagColorHex))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.black)
                Text("\(event.startAt.formatted(date: .omitted, time: .shortened)) 〜 \(event.endAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.black)
                if let note = event.note, !note.isEmpty {
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
