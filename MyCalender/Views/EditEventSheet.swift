import SwiftUI

struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    var event: Event
    var tags: [Tag]
    var onSaved: () -> Void

    @State private var viewModel: EditEventViewModel
    @State private var showErrorAlert = false

    init(event: Event, tags: [Tag], onSaved: @escaping () -> Void) {
        self.event = event
        self.tags = tags
        self.onSaved = onSaved
        _viewModel = State(initialValue: EditEventViewModel(event: event))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("イベント") {
                    TextField("タイトル", text: $viewModel.title)
                    DatePicker("開始", selection: $viewModel.startAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("終了", selection: $viewModel.endAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("メモ（任意）", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("タグ") {
                    if viewModel.tags.isEmpty {
                        Text("タグがありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.tags) { tag in
                            Button {
                                viewModel.toggleTag(tag.id)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color.from(hex: tag.colorHex))
                                        .frame(width: 20, height: 20)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.selectedTagIds.contains(tag.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("イベントを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let success = await viewModel.save()
                            if success {
                                onSaved()
                                dismiss()
                            } else {
                                showErrorAlert = true
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
            .onAppear {
                viewModel.loadTags()
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
    let end = cal.date(bySettingHour: 10, minute: 30, second: 0, of: today)!
    let event = Event(id: "pe1", type: .normal, title: "編集プレビュー", startAt: start, endAt: end, note: "メモ", tagIds: ["pt1"], isActive: true, createdAt: .distantPast, updatedAt: .distantPast)
    let tags = [Tag(id: "pt1", name: "仕事", colorHex: "#34C759", isActive: true, createdAt: .distantPast, updatedAt: .distantPast)]
    return EditEventSheet(event: event, tags: tags) {}
}
