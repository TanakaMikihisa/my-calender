import SwiftUI

struct EditWorkShiftSheet: View {
    @Environment(\.dismiss) private var dismiss
    var shift: WorkShift
    var tags: [Tag]
    var onSaved: () -> Void

    @State private var viewModel: EditWorkShiftViewModel
    @State private var showErrorAlert = false

    init(shift: WorkShift, tags: [Tag], onSaved: @escaping () -> Void) {
        self.shift = shift
        self.tags = tags
        self.onSaved = onSaved
        _viewModel = State(initialValue: EditWorkShiftViewModel(shift: shift))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("勤務時間") {
                    DatePicker("開始", selection: $viewModel.startAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("終了", selection: $viewModel.endAt, displayedComponents: [.date, .hourAndMinute])
                }
                Section("給与") {
                    Picker("種別", selection: $viewModel.payType) {
                        Text("時給").tag(WorkPayType.hourly)
                        Text("固定給").tag(WorkPayType.fixed)
                    }
                    .pickerStyle(.segmented)
                    if viewModel.payType == .fixed {
                        TextField("金額", text: $viewModel.fixedPayText)
                            .keyboardType(.decimalPad)
                    }
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
            .navigationTitle("勤務を編集")
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
    let end = cal.date(bySettingHour: 17, minute: 0, second: 0, of: today)!
    let shift = WorkShift(id: "ps1", startAt: start, endAt: end, payType: .hourly, payRateId: nil, fixedPay: nil, templateId: nil, tagIds: [], isActive: true, createdAt: .distantPast, updatedAt: .distantPast)
    let tags: [Tag] = []
    return EditWorkShiftSheet(shift: shift, tags: tags) {}
}
