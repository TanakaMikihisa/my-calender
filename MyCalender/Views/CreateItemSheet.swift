import SwiftUI

struct CreateItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    var initialDate: Date?
    /// 月カレンダー複数選択時など。保存時に各日へ個別登録し、日付ピッカーは時刻のみにする
    var bulkTargetDates: [Date]?
    var onSaved: () -> Void

    @State private var eventViewModel: CreateEventViewModel?
    @State private var showErrorAlert = false
    @State private var showSettingsSheet = false
    @State private var showMultiDateSaveConfirmAlert = false

    var body: some View {
        NavigationStack {
            Form {
                if let eventViewModel {
                    CreateEventForm(viewModel: eventViewModel, hidesDatePicker: hasBulkTargetDates)
                }
            }
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        FeedBack().feedback(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            FeedBack().feedback(.medium)
                            showSettingsSheet = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        if let eventViewModel {
                            Button("保存") {
                                FeedBack().feedback(.medium)
                                if requiresMultiDateSaveConfirmation {
                                    showMultiDateSaveConfirmAlert = true
                                } else {
                                    Task {
                                        let success: Bool
                                        if let bulkTargetDates, hasBulkTargetDates {
                                            success = await eventViewModel.save(onDates: bulkTargetDates)
                                        } else {
                                            success = await eventViewModel.save()
                                        }
                                        if success {
                                            dismiss()
                                            onSaved()
                                        } else {
                                            showErrorAlert = true
                                        }
                                    }
                                }
                            }
                            .disabled(!eventViewModel.canSave || eventViewModel.isSaving)
                        }
                    }
                }
            }
            .navigationTitle("予定の追加")
            .onAppear {
                let date = initialDate ?? Date()
                if eventViewModel == nil {
                    eventViewModel = CreateEventViewModel(initialDate: date)
                    eventViewModel?.loadTags()
                    eventViewModel?.loadEventTemplates()
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsSheet()
            }
            .onChange(of: showSettingsSheet) {
                if !showSettingsSheet {
                    eventViewModel?.loadTags()
                    eventViewModel?.loadEventTemplates()
                }
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {
                    FeedBack().feedback(.light)
                    showErrorAlert = false
                    eventViewModel?.errorMessage = nil
                }
            } message: {
                Text(eventViewModel?.errorMessage ?? "")
            }
            .alert("複数日に同じ予定を登録します", isPresented: $showMultiDateSaveConfirmAlert) {
                Button("キャンセル", role: .cancel) {
                    FeedBack().feedback(.light)
                }
                Button("登録") {
                    FeedBack().feedback(.medium)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    Task {
                        guard let eventViewModel else { return }
                        let success: Bool
                        if let bulkTargetDates, hasBulkTargetDates {
                            success = await eventViewModel.save(onDates: bulkTargetDates)
                        } else {
                            success = await eventViewModel.save()
                        }
                        if success {
                            dismiss()
                            onSaved()
                        } else {
                            showErrorAlert = true
                        }
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                SavingReturnArrowOverlay(isSaving: eventViewModel?.isSaving == true)
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    private var hasBulkTargetDates: Bool {
        guard let dates = bulkTargetDates else { return false }
        return !dates.isEmpty
    }

    private var requiresMultiDateSaveConfirmation: Bool {
        hasBulkTargetDates
    }
}

private struct CreateEventForm: View {
    @Bindable var viewModel: CreateEventViewModel
    var hidesDatePicker: Bool
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        Section("イベント") {
            TextField("タイトル", text: $viewModel.title)
                .focused($isTitleFocused)
                .onSubmit { viewModel.applyTimeRangeFromTitleIfNeeded() }
            DatePicker(
                "開始",
                selection: $viewModel.startAt,
                displayedComponents: hidesDatePicker ? [.hourAndMinute] : [.date, .hourAndMinute]
            )
            DatePicker(
                "終了",
                selection: $viewModel.endAt,
                displayedComponents: hidesDatePicker ? [.hourAndMinute] : [.date, .hourAndMinute]
            )
            TextField("メモ", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
        }
        .onChange(of: isTitleFocused) {
            if !isTitleFocused { viewModel.applyTimeRangeFromTitleIfNeeded() }
        }
        .onChange(of: viewModel.startAt) {
            viewModel.normalizeEndAtAfterStartChanged()
        }
        Section("タグ") {
            if viewModel.tags.isEmpty {
                Text("タグがありません。右上の設定から追加できます。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.tags) { tag in
                    Button {
                        FeedBack().feedback(.light)
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
        Section("テンプレートから登録") {
            if viewModel.eventTemplates.isEmpty {
                Text("テンプレートがありません。設定から追加できます。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.eventTemplates) { template in
                    Button {
                        FeedBack().feedback(.light)
                        viewModel.applyEventTemplate(id: template.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.title)
                                    .foregroundStyle(.primary)
                                Text("\(template.startTime)〜\(template.endTime)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.selectedEventTemplateId == template.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CreateItemSheet(initialDate: Date(), onSaved: {})
}
