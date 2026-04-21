import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.appStorageDailyScheduleNotificationEnabled) private var dailyScheduleNotificationEnabled = true
    @State private var viewModel = SettingsViewModel()
    @State private var showTagForm = false
    @State private var editingTag: Tag?
    @State private var showEventTemplateForm = false
    @State private var editingEventTemplate: EventTemplate?

    var body: some View {
        NavigationStack {
            Form {
                Section("通知") {
                    Toggle("毎日0:00に予定を通知", isOn: $dailyScheduleNotificationEnabled)
                        .onChange(of: dailyScheduleNotificationEnabled) {
                            FeedBack().feedback(.light)
                            Task {
                                if dailyScheduleNotificationEnabled {
                                    try? await DailyScheduleNotificationScheduler.shared.reschedule()
                                } else {
                                    await DailyScheduleNotificationScheduler.shared.removeAllDailyNotifications()
                                }
                            }
                        }
                }
                Section("タグ") {
                    if viewModel.isLoading, viewModel.tags.isEmpty {
                        SavingReturnArrowOverlay(isSaving: true, clipsScrimToParentBounds: true)
                            .frame(height: 140)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    } else if viewModel.tags.isEmpty {
                        Text("タグがありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.tags) { tag in
                            Button {
                                FeedBack().feedback(.medium)
                                editingTag = tag
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.from(hex: tag.colorHex))
                                        .frame(width: 24, height: 24)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .onDelete(perform: deleteTags)
                    }
                    Button("タグを追加") {
                        FeedBack().feedback(.medium)
                        editingTag = nil
                        showTagForm = true
                    }
                }
                Section("予定テンプレート") {
                    if viewModel.isLoading, viewModel.eventTemplates.isEmpty {
                        SavingReturnArrowOverlay(isSaving: true, clipsScrimToParentBounds: true)
                            .frame(height: 140)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    } else if viewModel.eventTemplates.isEmpty {
                        Text("予定テンプレートがありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.eventTemplates) { template in
                            Button {
                                FeedBack().feedback(.medium)
                                editingEventTemplate = template
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.title)
                                        .foregroundStyle(.primary)
                                    Text("\(template.startTime)〜\(template.endTime)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteEventTemplates)
                    }
                    Button("予定テンプレートを追加") {
                        FeedBack().feedback(.medium)
                        editingEventTemplate = nil
                        showEventTemplateForm = true
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        FeedBack().feedback(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .onAppear { viewModel.loadAll() }
            .sheet(isPresented: $showTagForm) {
                TagFormSheet(
                    tag: editingTag,
                    onSave: { viewModel.loadTags() },
                    onDismiss: { showTagForm = false }
                )
            }
            .sheet(item: $editingTag) { tag in
                TagFormSheet(
                    tag: tag,
                    onSave: { viewModel.loadTags(); editingTag = nil },
                    onDismiss: { editingTag = nil }
                )
            }
            .sheet(isPresented: $showEventTemplateForm) {
                EventTemplateFormSheet(
                    template: nil,
                    tags: viewModel.tags,
                    onSave: { viewModel.loadEventTemplates(); showEventTemplateForm = false },
                    onDismiss: { showEventTemplateForm = false }
                )
            }
            .sheet(item: $editingEventTemplate) { template in
                EventTemplateFormSheet(
                    template: template,
                    tags: viewModel.tags,
                    onSave: { viewModel.loadEventTemplates(); editingEventTemplate = nil },
                    onDismiss: { editingEventTemplate = nil }
                )
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    FeedBack().feedback(.light)
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func deleteTags(at offsets: IndexSet) {
        Task { @MainActor in
            for index in offsets {
                let id = viewModel.tags[index].id
                _ = await viewModel.deactivateTag(id: id)
            }
            viewModel.loadTags()
        }
    }

    private func deleteEventTemplates(at offsets: IndexSet) {
        Task { @MainActor in
            for index in offsets {
                let id = viewModel.eventTemplates[index].id
                _ = await viewModel.deactivateEventTemplate(id: id)
            }
            viewModel.loadEventTemplates()
        }
    }
}

/// 追加用: tag == nil。編集用: tag != nil。
struct TagFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tag: Tag?
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var selectedColorHex: String = Constants.tagPresetColors[0]
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("タグ名", text: $name)
                }
                Section("色") {
                    let colorOptions: [String] = {
                        if let tag, !Constants.tagPresetColors.contains(tag.colorHex) {
                            return [tag.colorHex] + Constants.tagPresetColors
                        }
                        return Constants.tagPresetColors
                    }()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                FeedBack().feedback(.light)
                                selectedColorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color.from(hex: hex))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColorHex == hex ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if tag != nil {
                    Section {
                        Button(role: .destructive) {
                            FeedBack().feedback(.heavy)
                            showDeleteConfirm = true
                        } label: {
                            Text("このタグを削除")
                        }
                    }
                }
            }
            .navigationTitle(tag == nil ? "タグを追加" : "タグを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        FeedBack().feedback(.light)
                        onDismiss(); dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tag == nil ? "追加" : "更新") {
                        FeedBack().feedback(.medium)
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let tag {
                    name = tag.name
                    selectedColorHex = tag.colorHex
                } else {
                    name = ""
                    selectedColorHex = Constants.tagPresetColors[0]
                }
            }
            .alert("タグを削除", isPresented: $showDeleteConfirm) {
                Button("キャンセル", role: .cancel) { FeedBack().feedback(.light) }
                Button("削除", role: .destructive) {
                    FeedBack().feedback(.heavy)
                    Task { await deleteTag() }
                }
            } message: {
                Text("このタグを削除しますか？")
            }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    FeedBack().feedback(.light)
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay(alignment: .bottomLeading) {
                SavingReturnArrowOverlay(isSaving: isSaving)
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    private func save() async {
        let vm = SettingsViewModel()
        isSaving = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        defer { isSaving = false }
        if let tag {
            var t = tag
            t.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            t.colorHex = selectedColorHex
            let ok = await vm.updateTag(t)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        } else {
            let ok = await vm.addTag(name: name, colorHex: selectedColorHex)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        }
    }

    private func deleteTag() async {
        guard let tag else { return }
        let vm = SettingsViewModel()
        let ok = await vm.deactivateTag(id: tag.id)
        if ok { onSave(); dismiss() }
        else { errorMessage = vm.errorMessage }
    }
}

struct EventTemplateFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: EventTemplate?
    let tags: [Tag]
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var startTimeDate: Date = .init()
    @State private var endTimeDate: Date = .init()
    @State private var selectedTagIds: Set<TagID> = []
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    private var calendar: Calendar { .current }
    private var singleSelectedTagIds: [TagID] {
        guard let first = selectedTagIds.first else { return [] }
        return [first]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("予定") {
                    TextField("タイトル", text: $title)
                    DatePicker("開始", selection: $startTimeDate, displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: $endTimeDate, displayedComponents: .hourAndMinute)
                    TextField("内容", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("タグ") {
                    if tags.isEmpty {
                        Text("タグがありません。先にタグを追加してください。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tags) { tag in
                            Button {
                                FeedBack().feedback(.light)
                                if selectedTagIds.contains(tag.id) {
                                    selectedTagIds.remove(tag.id)
                                } else {
                                    selectedTagIds = [tag.id]
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color.from(hex: tag.colorHex))
                                        .frame(width: 20, height: 20)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTagIds.contains(tag.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
                if template != nil {
                    Section {
                        Button(role: .destructive) {
                            FeedBack().feedback(.heavy)
                            showDeleteConfirm = true
                        } label: {
                            Text("このテンプレートを削除")
                        }
                    }
                }
            }
            .navigationTitle(template == nil ? "予定テンプレートを追加" : "予定テンプレートを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        FeedBack().feedback(.light)
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(template == nil ? "追加" : "更新") {
                        FeedBack().feedback(.medium)
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                if let template {
                    title = template.title
                    note = template.note ?? ""
                    if let first = template.tagIds.first {
                        selectedTagIds = [first]
                    } else {
                        selectedTagIds = []
                    }
                    startTimeDate = Date.fromTimeString(template.startTime) ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                    endTimeDate = Date.fromTimeString(template.endTime) ?? calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
                } else {
                    title = ""
                    note = ""
                    selectedTagIds = []
                    startTimeDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                    endTimeDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
                }
            }
            .alert("テンプレートを削除", isPresented: $showDeleteConfirm) {
                Button("キャンセル", role: .cancel) { FeedBack().feedback(.light) }
                Button("削除", role: .destructive) {
                    FeedBack().feedback(.heavy)
                    Task { await deleteTemplate() }
                }
            } message: {
                Text("このテンプレートを削除しますか？")
            }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    FeedBack().feedback(.light)
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay(alignment: .bottomLeading) {
                SavingReturnArrowOverlay(isSaving: isSaving)
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        let vm = SettingsViewModel()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let startTime = startTimeDate.toTimeString(calendar: calendar)
        let endTime = endTimeDate.toTimeString(calendar: calendar)
        isSaving = true
        defer { isSaving = false }
        if let template {
            var updated = template
            updated.title = trimmedTitle
            updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            updated.startTime = startTime
            updated.endTime = endTime
            updated.tagIds = singleSelectedTagIds
            updated.updatedAt = Date()
            let ok = await vm.updateEventTemplate(updated)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        } else {
            let ok = await vm.addEventTemplate(
                title: trimmedTitle,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                startTime: startTime,
                endTime: endTime,
                tagIds: singleSelectedTagIds
            )
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        }
    }

    private func deleteTemplate() async {
        guard let template else { return }
        let vm = SettingsViewModel()
        let ok = await vm.deactivateEventTemplate(id: template.id)
        if ok { onSave(); dismiss() }
        else { errorMessage = vm.errorMessage }
    }
}

#Preview {
    SettingsSheet()
}
