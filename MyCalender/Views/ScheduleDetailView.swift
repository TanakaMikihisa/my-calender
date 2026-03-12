import SwiftUI

struct ScheduleDetailView: View {
    var item: ScheduleDetailItem
    var tags: [Tag]
    var onRefresh: () -> Void
    var onDismiss: (() -> Void)?

    @State private var showEditSheet = false

    private var itemTags: [Tag] {
        switch item {
        case .event(let e):
            return e.tagIds.compactMap { id in tags.first(where: { $0.id == id }) }
        case .workShift(let s):
            return s.tagIds.compactMap { id in tags.first(where: { $0.id == id }) }
        }
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
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            Section {
                LabeledContent("タイトル", value: item.title)
                LabeledContent("開始", value: item.startAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("終了", value: item.endAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let note = item.note, !note.isEmpty {
                Section("メモ") {
                    Text(note)
                }
            }
            if case .workShift(let shift) = item {
                Section("給与") {
                    LabeledContent("種別", value: shift.payType == .hourly ? "時給" : "固定給")
                    if let fixed = shift.fixedPay {
                        LabeledContent("金額", value: "\(fixed)")
                    }
                }
            }
        }
        .navigationTitle("予定の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            switch item {
            case .event(let event):
                EditEventSheet(event: event, tags: tags) {
                    onRefresh()
                    showEditSheet = false
                }
            case .workShift(let shift):
                EditWorkShiftSheet(shift: shift, tags: tags) {
                    onRefresh()
                    showEditSheet = false
                }
            }
        }
        .onDisappear { onDismiss?() }
    }

    /// メイン画面（時間軸・リスト）のタグ色と同一の透明度で表示
    private func tagFillColor(_ colorHex: String) -> some ShapeStyle {
        if colorHex == Constants.defaultBoxColorSentinel {
            return AnyShapeStyle(Color(.systemGray5).opacity(0.5))
        }
        return AnyShapeStyle(Color.from(hex: colorHex).opacity(0.45))
    }
}

// MARK: - Preview
private extension ScheduleDetailView {
    static var previewItem: ScheduleDetailItem {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
        let end = cal.date(bySettingHour: 10, minute: 30, second: 0, of: today)!
        let event = Event(id: "preview-e1", type: .normal, title: "プレビュー予定", startAt: start, endAt: end, note: "メモです", tagIds: ["preview-tag1"], isActive: true, createdAt: .distantPast, updatedAt: .distantPast)
        return .event(event)
    }
    static var previewTags: [Tag] {
        [Tag(id: "preview-tag1", name: "仕事", colorHex: "#34C759", isActive: true, createdAt: .distantPast, updatedAt: .distantPast)]
    }
}

#Preview {
    NavigationStack {
        ScheduleDetailView(item: ScheduleDetailView.previewItem, tags: ScheduleDetailView.previewTags, onRefresh: {}, onDismiss: nil)
    }
}
