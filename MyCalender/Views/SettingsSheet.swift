import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.appStorageDailyScheduleNotificationEnabled) private var dailyScheduleNotificationEnabled = true
    @State private var viewModel = SettingsViewModel()
    @State private var showTagForm = false
    @State private var editingTag: Tag?
    @State private var showPayRateForm = false
    @State private var selectedCompany: PayRate?

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
                Section("会社") {
                    if viewModel.isLoading, viewModel.payRates.isEmpty {
                        SavingReturnArrowOverlay(isSaving: true, clipsScrimToParentBounds: true)
                            .frame(height: 140)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    } else if viewModel.payRates.isEmpty {
                        Text("会社がありません。追加して時給・シフトを設定できます。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.payRates) { payRate in
                            Button {
                                FeedBack().feedback(.medium)
                                selectedCompany = payRate
                            } label: {
                                Text(payRate.title)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .onDelete(perform: deletePayRates)
                    }
                    Button("会社を追加") {
                        FeedBack().feedback(.medium)
                        showPayRateForm = true
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
            .sheet(isPresented: $showPayRateForm) {
                PayRateFormSheet(
                    payRate: nil,
                    onSave: { viewModel.loadPayRates(); showPayRateForm = false },
                    onDismiss: { showPayRateForm = false }
                )
            }
            .sheet(item: $selectedCompany) { company in
                CompanyDetailSheet(
                    company: company,
                    shiftTemplates: viewModel.shiftTemplates.filter { $0.payRateId == company.id },
                    hourlyRates: viewModel.hourlyRates.filter { $0.payRateId == company.id },
                    payRates: viewModel.payRates,
                    onSave: {
                        viewModel.loadPayRates()
                        viewModel.loadHourlyRates()
                        viewModel.loadShiftTemplates()
                    },
                    onDismiss: { selectedCompany = nil }
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

    private func deletePayRates(at offsets: IndexSet) {
        Task { @MainActor in
            for index in offsets {
                let id = viewModel.payRates[index].id
                _ = await viewModel.deactivatePayRate(id: id)
            }
            viewModel.loadPayRates()
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

// MARK: - 会社追加（名前のみ。時給・シフトは会社詳細で設定）

struct PayRateFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let payRate: PayRate?
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var hourlyWageText: String = ""
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("会社名") {
                    TextField("例: コンビニA", text: $title)
                        .textContentType(.organizationName)
                }
                if payRate != nil {
                    Section("時給（円）") {
                        TextField("0", text: $hourlyWageText)
                            .keyboardType(.decimalPad)
                    }
                    Section {
                        Button(role: .destructive) {
                            FeedBack().feedback(.heavy)
                            showDeleteConfirm = true
                        } label: {
                            Text("この会社を削除")
                        }
                    }
                }
            }
            .navigationTitle(payRate == nil ? "会社を追加" : "会社を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        FeedBack().feedback(.light)
                        onDismiss(); dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(payRate == nil ? "追加" : "更新") {
                        FeedBack().feedback(.medium)
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                if let payRate {
                    title = payRate.title
                    hourlyWageText = payRate.hourlyWage == 0 ? "" : "\(payRate.hourlyWage)"
                } else {
                    title = ""
                    hourlyWageText = ""
                }
            }
            .alert("会社を削除", isPresented: $showDeleteConfirm) {
                Button("キャンセル", role: .cancel) { FeedBack().feedback(.light) }
                Button("削除", role: .destructive) {
                    FeedBack().feedback(.heavy)
                    Task { await deletePayRate() }
                }
            } message: {
                Text("この会社を削除しますか？")
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
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if payRate != nil {
            return parsedHourlyWage != nil
        }
        return true
    }

    private var parsedHourlyWage: Decimal? {
        let trimmed = hourlyWageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let d = Decimal(string: trimmed), d >= 0 else { return nil }
        return d
    }

    private func save() async {
        let vm = SettingsViewModel()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        defer { isSaving = false }
        if let payRate {
            guard let wage = parsedHourlyWage else { return }
            var p = payRate
            p.title = trimmedTitle
            p.hourlyWage = wage
            let ok = await vm.updatePayRate(p)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        } else {
            let wage = parsedHourlyWage ?? 0
            let ok = await vm.addPayRate(title: trimmedTitle, hourlyWage: wage)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        }
    }

    private func deletePayRate() async {
        guard let payRate else { return }
        let vm = SettingsViewModel()
        let ok = await vm.deactivatePayRate(id: payRate.id)
        if ok { onSave(); dismiss() }
        else { errorMessage = vm.errorMessage }
    }
}

// MARK: - 会社詳細（会社名 ＋ 時給パターン一覧 ＋ シフト一覧）

struct CompanyDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let company: PayRate
    let shiftTemplates: [ShiftTemplate]
    let hourlyRates: [HourlyRate]
    let payRates: [PayRate]
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var companyName: String = ""
    @State private var isSaving = false
    @State private var showDeleteCompanyConfirm = false
    @State private var showShiftTemplateForm = false
    @State private var editingShiftTemplate: ShiftTemplate?
    @State private var showHourlyRateForm = false
    @State private var editingHourlyRate: HourlyRate?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("会社") {
                    TextField("会社名", text: $companyName)
                        .textContentType(.organizationName)
                        .onSubmit {
                            if companyFormCanSave { Task { await saveCompany() } }
                        }
                }
                Section("時給") {
                    if hourlyRates.isEmpty {
                        Text("時給パターンがありません。追加すると勤務・シフトで選べます。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(hourlyRates) { rate in
                            Button {
                                FeedBack().feedback(.medium)
                                editingHourlyRate = rate
                                showHourlyRateForm = true
                            } label: {
                                Text(rate.displayLabel())
                                    .foregroundStyle(.primary)
                            }
                        }
                        .onDelete(perform: deleteHourlyRates)
                    }
                    Button("時給を追加") {
                        FeedBack().feedback(.medium)
                        editingHourlyRate = nil
                        showHourlyRateForm = true
                    }
                }
                Section("シフト") {
                    if shiftTemplates.isEmpty {
                        Text("シフトがありません。追加して勤務登録時に利用できます。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(shiftTemplates) { template in
                            Button {
                                FeedBack().feedback(.medium)
                                editingShiftTemplate = template
                                showShiftTemplateForm = true
                            } label: {
                                HStack {
                                    Text(template.shiftName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if let earnings = template.earningsDisplay(hourlyRates: hourlyRates) {
                                        Text(earnings)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteShiftTemplates)
                    }
                    Button("シフトを追加") {
                        FeedBack().feedback(.medium)
                        editingShiftTemplate = nil
                        showShiftTemplateForm = true
                    }
                }
                Section {
                    Button(role: .destructive) {
                        FeedBack().feedback(.heavy)
                        showDeleteCompanyConfirm = true
                    } label: {
                        Text("この会社を削除")
                    }
                }
            }
            .navigationTitle(companyName.isEmpty ? company.title : companyName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        FeedBack().feedback(.light)
                        Task {
                            let trimmed = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if companyFormCanSave, trimmed != company.title {
                                await saveCompany()
                            } else {
                                await MainActor.run { onDismiss(); dismiss() }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .onAppear {
                companyName = company.title
            }
            .sheet(isPresented: $showHourlyRateForm) {
                HourlyRateFormSheet(
                    payRateId: company.id,
                    hourlyRate: editingHourlyRate,
                    onSave: {
                        onSave()
                        showHourlyRateForm = false
                        editingHourlyRate = nil
                    },
                    onDismiss: { showHourlyRateForm = false; editingHourlyRate = nil }
                )
            }
            .sheet(isPresented: $showShiftTemplateForm) {
                ShiftTemplateFormSheet(
                    template: editingShiftTemplate,
                    payRates: payRates,
                    hourlyRates: hourlyRates,
                    fixedPayRateId: editingShiftTemplate == nil ? company.id : nil,
                    onSave: {
                        onSave()
                        showShiftTemplateForm = false
                        editingShiftTemplate = nil
                    },
                    onDismiss: { showShiftTemplateForm = false; editingShiftTemplate = nil }
                )
            }
            .alert("この会社を削除", isPresented: $showDeleteCompanyConfirm) {
                Button("キャンセル", role: .cancel) { FeedBack().feedback(.light) }
                Button("削除", role: .destructive) {
                    FeedBack().feedback(.heavy)
                    Task { await deleteCompany() }
                }
            } message: {
                Text("会社とそのシフト設定が削除されます。")
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

    private var companyFormCanSave: Bool {
        !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveCompany() async {
        let vm = SettingsViewModel()
        isSaving = true
        defer { isSaving = false }
        var updated = company
        updated.title = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = Date()
        let ok = await vm.updatePayRate(updated)
        if ok {
            onSave()
            dismiss()
            onDismiss()
        } else {
            errorMessage = vm.errorMessage
        }
    }

    private func deleteCompany() async {
        let vm = SettingsViewModel()
        let ok = await vm.deactivatePayRate(id: company.id)
        if ok {
            onSave()
            dismiss()
            onDismiss()
        } else {
            errorMessage = vm.errorMessage
        }
    }

    private func deleteShiftTemplates(at offsets: IndexSet) {
        Task { @MainActor in
            let vm = SettingsViewModel()
            for index in offsets {
                let id = shiftTemplates[index].id
                _ = await vm.deactivateShiftTemplate(id: id)
            }
            onSave()
        }
    }

    private func deleteHourlyRates(at offsets: IndexSet) {
        Task { @MainActor in
            let vm = SettingsViewModel()
            for index in offsets {
                let id = hourlyRates[index].id
                _ = await vm.deactivateHourlyRate(id: id)
            }
            onSave()
        }
    }
}

// MARK: - 時給パターン追加・編集（金額のみ、名前なし）

struct HourlyRateFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let payRateId: PayRateID
    let hourlyRate: HourlyRate?
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var amountText: String = ""
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("金額（円/時）") {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                }
                if hourlyRate != nil {
                    Section {
                        Button(role: .destructive) {
                            FeedBack().feedback(.heavy)
                            showDeleteConfirm = true
                        } label: {
                            Text("この時給を削除")
                        }
                    }
                }
            }
            .navigationTitle(hourlyRate == nil ? "時給を追加" : "時給を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        FeedBack().feedback(.light)
                        onDismiss(); dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(hourlyRate == nil ? "追加" : "更新") {
                        FeedBack().feedback(.medium)
                        Task { await save() }
                    }
                    .disabled(parsedAmount == nil || isSaving)
                }
            }
            .onAppear {
                amountText = hourlyRate.map { "\($0.amount)" } ?? ""
            }
            .alert("この時給を削除", isPresented: $showDeleteConfirm) {
                Button("キャンセル", role: .cancel) { FeedBack().feedback(.light) }
                Button("削除", role: .destructive) {
                    FeedBack().feedback(.heavy)
                    Task { await deleteRate() }
                }
            } message: {
                Text("この時給を参照している勤務・シフトは、時給が未設定になります。")
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

    private var parsedAmount: Decimal? {
        let t = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let d = Decimal(string: t), d >= 0 else { return nil }
        return d
    }

    private func save() async {
        guard let amount = parsedAmount else { return }
        let vm = SettingsViewModel()
        isSaving = true
        defer { isSaving = false }
        if let rate = hourlyRate {
            var r = rate
            r.amount = amount
            r.updatedAt = Date()
            let ok = await vm.updateHourlyRate(r)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        } else {
            let ok = await vm.addHourlyRate(payRateId: payRateId, amount: amount)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        }
    }

    private func deleteRate() async {
        guard let rate = hourlyRate else { return }
        let vm = SettingsViewModel()
        let ok = await vm.deactivateHourlyRate(id: rate.id)
        if ok { onSave(); dismiss() }
        else { errorMessage = vm.errorMessage }
    }
}

// MARK: - シフトテンプレート追加・編集（1会社に複数シフト・時給パターン）

struct ShiftTemplateFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: ShiftTemplate?
    let payRates: [PayRate]
    /// この会社の時給パターン（会社詳細から開くとき用）
    let hourlyRates: [HourlyRate]
    /// 指定時は会社を固定（会社選択UIを出さない）
    var fixedPayRateId: PayRateID?
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var selectedPayRateId: PayRateID = ""
    @State private var selectedHourlyRateId: HourlyRateID = ""
    @State private var shiftName: String = ""
    @State private var startTimeDate: Date = .init()
    @State private var endTimeDate: Date = .init()
    @State private var breakMinutesText: String = ""
    @State private var payType: WorkPayType = .hourly
    @State private var fixedPayText: String = ""
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @FocusState private var isShiftNameFocused: Bool

    private var calendar: Calendar { .current }

    private func applyTimeRangeFromShiftName() {
        guard let range = shiftName.parsedTimeRange() else { return }
        let base = Date()
        if let start = calendar.date(bySettingHour: range.startHour, minute: range.startMinute, second: 0, of: base) {
            startTimeDate = start
        }
        if var end = calendar.date(bySettingHour: range.endHour, minute: range.endMinute, second: 0, of: base) {
            if end <= startTimeDate {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            endTimeDate = end
        }
    }

    /// 実際に使う会社ID（固定時は fixedPayRateId、それ以外は選択値）
    private var effectivePayRateId: PayRateID {
        fixedPayRateId ?? selectedPayRateId
    }

    /// この会社の時給パターン（固定時は渡された hourlyRates）
    private var effectiveHourlyRates: [HourlyRate] {
        hourlyRates.filter { $0.payRateId == effectivePayRateId }
    }

    /// 選択中の時給金額（表示用）
    private var selectedWage: Decimal? {
        effectiveHourlyRates.first(where: { $0.id == selectedHourlyRateId })?.amount
    }

    var body: some View {
        NavigationStack {
            Form {
                if fixedPayRateId == nil {
                    Section("会社") {
                        if payRates.isEmpty {
                            Text("会社がありません。設定で会社を追加してください。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(payRates) { rate in
                                Button {
                                    FeedBack().feedback(.light)
                                    selectedPayRateId = rate.id
                                    selectedHourlyRateId = ""
                                } label: {
                                    HStack {
                                        Text(rate.title)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedPayRateId == rate.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Section("シフト") {
                    TextField("例: 週末夜 9:00-17:00", text: $shiftName)
                        .focused($isShiftNameFocused)
                        .onSubmit { applyTimeRangeFromShiftName() }
                }
                .onChange(of: isShiftNameFocused) {
                    if !isShiftNameFocused { applyTimeRangeFromShiftName() }
                }
                Section("勤務時間") {
                    DatePicker("開始", selection: $startTimeDate, displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: $endTimeDate, displayedComponents: .hourAndMinute)
                    TextField("休憩時間（分）", text: $breakMinutesText)
                        .keyboardType(.numberPad)
                }
                Section("給与") {
                    Picker("種別", selection: $payType) {
                        Text("時給").tag(WorkPayType.hourly)
                        Text("固定給").tag(WorkPayType.fixed)
                    }
                    .pickerStyle(.segmented)
                    if payType == .hourly {
                        if effectiveHourlyRates.isEmpty {
                            Text("この会社に時給パターンがありません。会社詳細で追加してください。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(effectiveHourlyRates) { rate in
                                Button {
                                    FeedBack().feedback(.light)
                                    selectedHourlyRateId = selectedHourlyRateId == rate.id ? "" : rate.id
                                } label: {
                                    HStack {
                                        Text(rate.displayLabel())
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedHourlyRateId == rate.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if payType == .fixed {
                        TextField("金額（円）", text: $fixedPayText)
                            .keyboardType(.decimalPad)
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
            .navigationTitle(template == nil ? "テンプレートを追加" : "テンプレートを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        FeedBack().feedback(.light)
                        onDismiss(); dismiss()
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
                if let t = template {
                    selectedPayRateId = t.payRateId
                    selectedHourlyRateId = t.hourlyRateId ?? ""
                    shiftName = t.shiftName
                    startTimeDate = Date.fromTimeString(t.startTime) ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                    endTimeDate = Date.fromTimeString(t.endTime) ?? calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
                    breakMinutesText = t.breakMinutes > 0 ? "\(t.breakMinutes)" : ""
                    payType = t.payType
                    fixedPayText = t.fixedPay.map { "\($0)" } ?? ""
                } else {
                    selectedPayRateId = fixedPayRateId ?? payRates.first?.id ?? ""
                    selectedHourlyRateId = ""
                    shiftName = ""
                    startTimeDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                    endTimeDate = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
                    breakMinutesText = ""
                    payType = .hourly
                    fixedPayText = ""
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
        let s = shiftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !effectivePayRateId.isEmpty else { return false }
        if payType == .fixed {
            return parsedFixedPay != nil
        }
        if payType == .hourly {
            return !selectedHourlyRateId.isEmpty
        }
        return true
    }

    private var parsedFixedPay: Decimal? {
        let t = fixedPayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let d = Decimal(string: t), d >= 0 else { return nil }
        return d
    }

    /// 休憩時間（分）。未入力・不正値は 0。
    private var parsedBreakMinutes: Int {
        let t = breakMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let n = Int(t), n >= 0 else { return 0 }
        return n
    }

    private func save() async {
        let vm = SettingsViewModel()
        let s = shiftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let startTime = startTimeDate.toTimeString(calendar: calendar)
        let endTime = endTimeDate.toTimeString(calendar: calendar)
        isSaving = true
        defer { isSaving = false }
        if let t = template {
            var updated = t
            updated.payRateId = effectivePayRateId
            updated.hourlyRateId = payType == .hourly ? (selectedHourlyRateId.isEmpty ? nil : selectedHourlyRateId) : nil
            updated.shiftName = s
            updated.startTime = startTime
            updated.endTime = endTime
            updated.breakMinutes = parsedBreakMinutes
            updated.payType = payType
            updated.fixedPay = payType == .fixed ? parsedFixedPay : nil
            updated.updatedAt = Date()
            let ok = await vm.updateShiftTemplate(updated)
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        } else {
            let ok = await vm.addShiftTemplate(
                payRateId: effectivePayRateId,
                shiftName: s,
                startTime: startTime,
                endTime: endTime,
                breakMinutes: parsedBreakMinutes,
                payType: payType,
                hourlyRateId: payType == .hourly ? (selectedHourlyRateId.isEmpty ? nil : selectedHourlyRateId) : nil,
                fixedPay: payType == .fixed ? parsedFixedPay : nil
            )
            if ok { onSave(); dismiss() }
            else { errorMessage = vm.errorMessage }
        }
    }

    private func deleteTemplate() async {
        guard let t = template else { return }
        let vm = SettingsViewModel()
        let ok = await vm.deactivateShiftTemplate(id: t.id)
        if ok { onSave(); dismiss() }
        else { errorMessage = vm.errorMessage }
    }
}

#Preview {
    SettingsSheet()
}
