import SwiftUI

enum CreateItemKind: String, CaseIterable, Identifiable {
    case event = "イベント"
    case workShift = "勤務"

    var id: String { rawValue }
}

struct CreateItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    var initialDate: Date?
    /// 指定がある場合、イベント保存時にこの日付群へ個別に登録する（イベントのみ）
    var eventTargetDates: [Date]?
    /// true の場合、イベント作成フォームの日付選択（date）を隠して時刻のみ表示する
    var hidesEventDatePicker: Bool = false
    /// 勤務作成時に初期選択する会社（PayRateID）。指定時は会社・日付が入力済みの状態で開く
    var initialPayRateId: PayRateID?
    var onSaved: () -> Void

    @State private var kind: CreateItemKind = .event
    @State private var eventViewModel: CreateEventViewModel?
    @State private var workShiftViewModel: CreateWorkShiftViewModel?
    @State private var showErrorAlert = false
    @State private var showSettingsSheet = false
    @State private var showMultiDateSaveConfirmAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("種類") {
                    HStack(spacing: 8) {
                        ForEach(CreateItemKind.allCases) { k in
                            Button {
                                FeedBack().feedback(.light)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    kind = k
                                }
                            } label: {
                                Text(k.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        kind == k
                                            ? Color.accentColor
                                            : Color(.systemGray4),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                switch kind {
                case .event:
                    if let eventViewModel {
                        CreateEventForm(viewModel: eventViewModel, hidesDatePicker: hidesEventDatePicker)
                    }
                case .workShift:
                    if let workShiftViewModel {
                        Section("作成方法") {
                            HStack(spacing: 8) {
                                ForEach(WorkShiftCreateMode.allCases) { mode in
                                    Button {
                                        FeedBack().feedback(.light)
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            workShiftViewModel.workShiftCreateMode = mode
                                        }
                                    } label: {
                                        Text(mode.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                workShiftViewModel.workShiftCreateMode == mode
                                                    ? Color.accentColor
                                                    : Color(.systemGray4),
                                                in: RoundedRectangle(cornerRadius: 8)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                        if workShiftViewModel.workShiftCreateMode == .newEntry {
                            Section("給与") {
                                HStack(spacing: 8) {
                                    ForEach([WorkPayType.hourly, WorkPayType.fixed], id: \.self) { payType in
                                        Button {
                                            FeedBack().feedback(.light)
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                workShiftViewModel.payType = payType
                                            }
                                        } label: {
                                            Text(payType == .hourly ? "時給" : "固定給")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    workShiftViewModel.payType == payType
                                                        ? Color.accentColor
                                                        : Color(.systemGray4),
                                                    in: RoundedRectangle(cornerRadius: 8)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                            if workShiftViewModel.payType == .hourly {
                                Section("会社") {
                                    if workShiftViewModel.payRates.isEmpty {
                                        Text("会社がありません。設定から追加してください。")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(workShiftViewModel.payRates) { rate in
                                            Button {
                                                FeedBack().feedback(.light)
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    workShiftViewModel.selectedPayRateId = workShiftViewModel.selectedPayRateId == rate.id ? nil : rate.id
                                                    workShiftViewModel.selectedHourlyRateId = nil
                                                }
                                            } label: {
                                                HStack {
                                                    Text(rate.title)
                                                        .foregroundStyle(.primary)
                                                    Spacer()
                                                    if workShiftViewModel.selectedPayRateId == rate.id {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundStyle(.tint)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: workShiftViewModel.selectedPayRateId)
                                if workShiftViewModel.selectedPayRateId != nil {
                                    Section("時給") {
                                        if workShiftViewModel.hourlyRatesForSelectedCompany.isEmpty {
                                            Text("この会社に時給パターンがありません。設定で会社をタップして時給を追加してください。")
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                        } else {
                                            ForEach(workShiftViewModel.hourlyRatesForSelectedCompany) { rate in
                                                Button {
                                                    FeedBack().feedback(.light)
                                                    workShiftViewModel.selectedHourlyRateId = workShiftViewModel.selectedHourlyRateId == rate.id ? nil : rate.id
                                                } label: {
                                                    HStack {
                                                        Text(rate.displayLabel())
                                                            .foregroundStyle(.primary)
                                                        Spacer()
                                                        if workShiftViewModel.selectedHourlyRateId == rate.id {
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
                            if workShiftViewModel.payType == .fixed {
                                Section {
                                    TextField("会社名", text: Binding(
                                        get: { workShiftViewModel.companyNameText },
                                        set: { workShiftViewModel.companyNameText = $0 }
                                    ))
                                    .textContentType(.organizationName)
                                    TextField("金額", text: Binding(
                                        get: { workShiftViewModel.fixedPayText },
                                        set: { workShiftViewModel.fixedPayText = $0 }
                                    ))
                                    .keyboardType(.decimalPad)
                                }
                            }
                        }
                        CreateWorkShiftForm(viewModel: workShiftViewModel)
                    }
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
                        if kind == .event, let eventViewModel {
                            Button("保存") {
                                FeedBack().feedback(.medium)
                                if requiresMultiDateSaveConfirmation {
                                    showMultiDateSaveConfirmAlert = true
                                } else {
                                    Task {
                                        let success: Bool
                                        if let eventTargetDates {
                                            success = await eventViewModel.save(onDates: eventTargetDates)
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
                        if kind == .workShift, let workShiftViewModel {
                            Button("保存") {
                                FeedBack().feedback(.medium)
                                Task {
                                    let success = await workShiftViewModel.save()
                                    if success {
                                        dismiss()
                                        onSaved()
                                    } else {
                                        showErrorAlert = true
                                    }
                                }
                            }
                            .disabled(!workShiftViewModel.canSave || workShiftViewModel.isSaving)
                        }
                    }
                }
            }
            .navigationTitle("予定の追加")
            .onAppear {
                let date = initialDate ?? Date()
                // EmptyCell の「新規作成」から開いたときは勤務を選択し、ViewModel 側で「新規作成」モード・時給・会社をセットする
                if initialPayRateId != nil {
                    kind = .workShift
                }
                if eventViewModel == nil {
                    eventViewModel = CreateEventViewModel(initialDate: date)
                    eventViewModel?.loadTags()
                }
                if workShiftViewModel == nil {
                    workShiftViewModel = CreateWorkShiftViewModel(initialDate: date, initialPayRateId: initialPayRateId)
                    workShiftViewModel?.loadPayRates()
                    workShiftViewModel?.loadHourlyRates()
                    workShiftViewModel?.loadShiftTemplates()
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsSheet()
            }
            .onChange(of: showSettingsSheet) {
                if !showSettingsSheet {
                    eventViewModel?.loadTags()
                    workShiftViewModel?.loadPayRates()
                    workShiftViewModel?.loadHourlyRates()
                    workShiftViewModel?.loadShiftTemplates()
                }
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {
                    FeedBack().feedback(.light)
                    showErrorAlert = false
                    eventViewModel?.errorMessage = nil
                    workShiftViewModel?.errorMessage = nil
                }
            } message: {
                Text(eventViewModel?.errorMessage ?? workShiftViewModel?.errorMessage ?? "")
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
                        if let eventTargetDates {
                            success = await eventViewModel.save(onDates: eventTargetDates)
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
                SavingReturnArrowOverlay(
                    isSaving: kind == .event && (eventViewModel?.isSaving == true)
                )
                .padding(.leading, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var requiresMultiDateSaveConfirmation: Bool {
        guard kind == .event else { return false }
        guard let eventTargetDates else { return false }
        return !eventTargetDates.isEmpty
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
    }
}

private struct CreateWorkShiftForm: View {
    @Bindable var viewModel: CreateWorkShiftViewModel

    var body: some View {
        switch viewModel.workShiftCreateMode {
        case .fromTemplate:
            Section("会社") {
                if viewModel.payRatesWithTemplates.isEmpty {
                    Text("シフトテンプレートがありません。設定で会社をタップしてシフトを追加してください。")
                        .foregroundStyle(.secondary)
                } else if let selectedPayRateId = viewModel.selectedPayRateIdForTemplate,
                          let company = viewModel.payRatesWithTemplates.first(where: { $0.id == selectedPayRateId }) {
                    HStack {
                        Text(company.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button("会社を変更") {
                            FeedBack().feedback(.medium)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedPayRateIdForTemplate = nil
                                viewModel.selectedTemplateId = nil
                            }
                        }
                        .font(.subheadline)
                    }
                } else {
                    ForEach(viewModel.payRatesWithTemplates) { rate in
                        Button {
                            FeedBack().feedback(.light)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedPayRateIdForTemplate = rate.id
                                viewModel.selectedTemplateId = nil
                            }
                        } label: {
                            HStack {
                                Text(rate.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedPayRateIdForTemplate == rate.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            if viewModel.selectedPayRateIdForTemplate != nil {
                Section("シフト") {
                    if viewModel.shiftTemplatesForSelectedCompany.isEmpty {
                        Text("この会社にシフトがありません。設定でシフトを追加してください。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.shiftTemplatesForSelectedCompany) { template in
                            Button {
                                FeedBack().feedback(.light)
                                viewModel.selectedTemplateId = viewModel.selectedTemplateId == template.id ? nil : template.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.shiftName)
                                            .foregroundStyle(.primary)
                                        Text("\(template.startTime)〜\(template.endTime)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let earnings = viewModel.templateEarningsDisplay(template) {
                                            Text(earnings)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if viewModel.selectedTemplateId == template.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Section("日付") {
                DatePicker("勤務日", selection: $viewModel.workShiftDate, displayedComponents: .date)
            }
        case .newEntry:
            Section("勤務時間") {
                DatePicker("開始", selection: $viewModel.startAt, displayedComponents: [.date, .hourAndMinute])
                DatePicker("終了", selection: $viewModel.endAt, displayedComponents: [.date, .hourAndMinute])
                TextField("休憩時間（分）", text: $viewModel.breakMinutesText)
                    .keyboardType(.numberPad)
            }
        }
    }
}

#Preview {
    CreateItemSheet(initialDate: Date(), onSaved: {})
}
