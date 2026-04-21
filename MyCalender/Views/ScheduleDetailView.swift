import SwiftUI

struct ScheduleDetailView: View {
    var event: Event
    var tags: [Tag]
    var onRefresh: () -> Void
    var onDismiss: (() -> Void)?

    @State private var showEditSheet = false

    private var itemTags: [Tag] {
        event.tagIds.compactMap { id in tags.first(where: { $0.id == id }) }
    }

    var body: some View {
        List {
            if !itemTags.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        ForEach(itemTags) { tag in
                            Text(tag.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    tagFillColor(tag.colorHex),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            Section {
                LabeledContent("タイトル", value: event.title)
                LabeledContent("開始", value: event.startAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("終了", value: event.endAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let note = event.note, !note.isEmpty {
                Section("メモ") {
                    Text(note)
                }
            }
        }
        .navigationTitle("予定の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") {
                    FeedBack().feedback(.medium)
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditEventSheet(event: event, tags: tags, onSaved: {
                onRefresh()
                showEditSheet = false
            }, onDeleted: {
                onRefresh()
                showEditSheet = false
                onDismiss?()
            })
        }
        .onDisappear { onDismiss?() }
    }

    private func tagFillColor(_ colorHex: String) -> some ShapeStyle {
        if colorHex == Constants.defaultBoxColorSentinel {
            return AnyShapeStyle(Color(.systemGray5).opacity(0.5))
        }
        return AnyShapeStyle(Color.from(hex: colorHex).opacity(0.45))
    }
}

// MARK: - Preview

#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
    let end = cal.date(bySettingHour: 10, minute: 30, second: 0, of: today)!
    let event = Event(id: "preview-e1", type: .normal, title: "プレビュー予定", startAt: start, endAt: end, note: "メモです", tagIds: ["preview-tag1"], isActive: true, createdAt: .distantPast, updatedAt: .distantPast)
    let previewTags = [Tag(id: "preview-tag1", name: "仕事", colorHex: "#34C759", isActive: true, createdAt: .distantPast, updatedAt: .distantPast)]
    NavigationStack {
        ScheduleDetailView(event: event, tags: previewTags, onRefresh: {}, onDismiss: nil)
    }
}
