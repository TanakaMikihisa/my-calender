import SwiftUI

/// 1日まわりの表示（右下メニューで表示モードを選択）
private enum DayPanelKind: Equatable {
    /// 1時間おきの時間軸
    case hourlyTimeline
    case list
    case monthlyWorkShift
}

/// メイン画面の表示モード（`day` に時間軸・リスト・勤務をまとめ、`monthlyCalendar` を追加）
private enum DayViewMode: Equatable {
    case day(DayPanelKind)
    case monthlyCalendar
}

/// 右下メニュー／Picker 用（現在の `DayViewMode` と1対1）
private enum MainToolbarDisplayOption: Int, CaseIterable, Hashable {
    case hourlyTimeline = 0
    case list = 1
    case monthlyWorkShift = 2
    case monthlyCalendar = 3

    var title: String {
        switch self {
        case .hourlyTimeline: return "タイムライン"
        case .list: return "スタック"
        case .monthlyWorkShift: return "ワークシフト"
        case .monthlyCalendar: return "カレンダー"
        }
    }

    /// ツールバー上のピッカーに出す SF Symbol（従来の各ボタンと同じ）
    var symbolName: String {
        switch self {
        case .hourlyTimeline: return "list.dash"
        case .list: return "list.bullet.clipboard"
        case .monthlyWorkShift: return "rectangle.grid.1x2"
        case .monthlyCalendar: return "calendar"
        }
    }
}

struct DayView: View {
    /// 右下メニューで最後に選んだ表示（起動時に復元）
    @AppStorage(Constants.appStorageLastMainDisplayMode) private var lastMainDisplayModeRaw: Int = 0

    @State private var viewModel = DayViewModel(
        weatherRepository: WeatherKitWeatherRepository(locationRepository: DefaultLocationRepository())
    )
    @State private var isPresentingCreateSheet = false
    @State private var showErrorAlert = false
    @State private var selectedDetailItem: ScheduleDetailItem?
    /// 横スワイプの現在値（正=右方向=前日、負=左方向=翌日）。矢印表示に使用
    @State private var swipeTranslation: CGFloat = 0
    /// 「今日」ボタン用の巻き戻し風エフェクト（0=非表示、1=最大）。`swipeTranslation` とは独立
    @State private var goToTodayReturnEffectProgress: CGFloat = 0
    @State private var displayMode: DayViewMode = .day(.hourlyTimeline)
    @State private var hasSyncedDisplayModeFromStorage = false
    @State private var showWeatherSheet = false
    /// 月次勤務ビューで表示する月（任意の日付でよい）
    @State private var monthlyViewMonth = Date()
    /// 縦スクロール月カレンダーの基準月（初回スクロール位置）
    @State private var calendarAnchorMonth = Date()
    @State private var monthCalendarViewModel = MonthCalendarViewModel()
    @State private var monthlyWorkShiftViewModel = MonthlyWorkShiftViewModel(month: Date())
    /// 月カレンダー内を「今日」の月へスクロールさせる（`MonthlyCalendarView` が `onChange` で処理）
    @State private var monthCalendarScrollToTodayTrigger: UUID?
    /// 月カレンダーで日付を選んだときに開く「その日の時間軸」シート
    @State private var calendarDayTimelineSheetItem: CalendarDayTimelineSheetItem?
    @State private var sheetScheduleDetailItem: ScheduleDetailItem?
    @State private var isMonthCalendarSelectionMode = false
    @State private var monthCalendarSelectedDates: Set<Date> = []

    private var dayStart: Date { viewModel.date.startOfDay() }
    private var dayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
    }

    /// 横スワイプで日付変更できるのは時間軸・リストのみ
    private var allowsDaySwipeNavigation: Bool {
        if case let .day(k) = displayMode, k == .hourlyTimeline || k == .list { return true }
        return false
    }

    /// 月次勤務時：< ○月 > で月を切り替え（グレーの丸・グレー文字）
    private var monthNavigationView: some View {
        let cal = Calendar.current
        let monthInt = cal.component(.month, from: monthlyViewMonth)
        return HStack(spacing: 16) {
            Button {
                FeedBack().feedback(.medium)
                if let prev = cal.date(byAdding: .month, value: -1, to: monthlyViewMonth) {
                    monthlyViewMonth = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(.systemGray))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            Text("\(monthInt)月")
                .font(.title2.weight(.medium))
            Button {
                FeedBack().feedback(.medium)
                if let next = cal.date(byAdding: .month, value: 1, to: monthlyViewMonth) {
                    monthlyViewMonth = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(.systemGray))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(.systemGray5)))
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 上バー：左に天気、右に日付 or 月ナビ（< ○月 >）
                ZStack(alignment: .topLeading) {
                    if case .day(.monthlyWorkShift) = displayMode {
                        HStack {
                            dayWeatherView
                                .onTapGesture {
                                    FeedBack().feedback(.medium)
                                    showWeatherSheet = true
                                }
                            Spacer(minLength: 0)
                            monthNavigationView
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    } else if displayMode == .monthlyCalendar {
                        HStack {
                            dayWeatherView
                                .onTapGesture {
                                    FeedBack().feedback(.medium)
                                    showWeatherSheet = true
                                }
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    } else {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                                .frame(minWidth: 150)
                            DatePicker(
                                "",
                                selection: $viewModel.date,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        dayWeatherView
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                            .onTapGesture {
                                FeedBack().feedback(.medium)
                                showWeatherSheet = true
                            }
                    }
                }
                .frame(height: isRainMode ? 112 : 64)
                .padding(.top, 16)
                .onChange(of: viewModel.date) {
                    switch displayMode {
                    case .monthlyCalendar:
                        break
                    case let .day(kind) where kind == .monthlyWorkShift:
                        break
                    default:
                        viewModel.refresh()
                    }
                }
                .onChange(of: displayMode) {
                    switch displayMode {
                    case let .day(kind):
                        switch kind {
                        case .hourlyTimeline, .list:
                            viewModel.refresh()
                        case .monthlyWorkShift:
                            monthlyWorkShiftViewModel.month = monthlyViewMonth
                            monthlyWorkShiftViewModel.refresh()
                        }
                    case .monthlyCalendar:
                        calendarAnchorMonth = viewModel.date
                        viewModel.resetCalendarRangeExpansion()
                        viewModel.refreshCalendarRange(around: viewModel.date)
                    }
                }

                ZStack {
                    Group {
                        switch displayMode {
                        case .day(.hourlyTimeline):
                            TimeAxisDayView(
                                dayStart: dayStart,
                                unitMinutes: 60,
                                events: viewModel.events,
                                workShifts: viewModel.workShifts,
                                tags: viewModel.tags,
                                payRates: viewModel.payRates,
                                hourlyRates: viewModel.hourlyRates,
                                shiftTemplates: viewModel.shiftTemplates,
                                onSelectEvent: { selectedDetailItem = .event($0) },
                                onSelectWorkShift: { selectedDetailItem = .workShift($0) },
                                onDeleteEvent: { viewModel.deleteEvent($0) },
                                onDeleteWorkShift: { viewModel.deleteWorkShift($0) },
                                onRefresh: { await viewModel.refreshAsync() }
                            )
                        case .day(.list):
                            ScheduleListView(
                                dayStart: dayStart,
                                dayEnd: dayEnd,
                                events: viewModel.events,
                                workShifts: viewModel.workShifts,
                                tags: viewModel.tags,
                                payRates: viewModel.payRates,
                                hourlyRates: viewModel.hourlyRates,
                                shiftTemplates: viewModel.shiftTemplates,
                                selectedDetailItem: $selectedDetailItem,
                                onDeleteEvent: { viewModel.deleteEvent($0) },
                                onDeleteWorkShift: { viewModel.deleteWorkShift($0) },
                                onRefresh: { await viewModel.refreshAsync() }
                            )
                        case .monthlyCalendar:
                            MonthlyCalendarView(
                                viewModel: monthCalendarViewModel,
                                anchorMonth: calendarAnchorMonth,
                                extraMonthsPast: viewModel.calendarExtraPastMonths,
                                extraMonthsFuture: viewModel.calendarExtraFutureMonths,
                                selectedDate: Binding(
                                    get: { viewModel.date },
                                    set: { viewModel.date = $0 }
                                ),
                                events: viewModel.calendarRangeEvents,
                                workShifts: viewModel.calendarRangeWorkShifts,
                                tags: viewModel.tags,
                                isLoading: viewModel.isLoadingCalendarRange,
                                isMultiSelectMode: $isMonthCalendarSelectionMode,
                                multiSelectedDates: $monthCalendarSelectedDates,
                                onSelectDay: { day in
                                    let d = day.startOfDay()
                                    viewModel.date = d
                                    viewModel.refresh()
                                    calendarDayTimelineSheetItem = CalendarDayTimelineSheetItem(dayStart: d)
                                },
                                onRefresh: {
                                    await viewModel.refreshCalendarRangeAsync(around: calendarAnchorMonth)
                                },
                                onNeedPastYear: {
                                    viewModel.requestExpandCalendarRangePastOneYear(around: calendarAnchorMonth)
                                },
                                onNeedFutureYear: {
                                    viewModel.requestExpandCalendarRangeFutureOneYear(around: calendarAnchorMonth)
                                },
                                scrollToTodayTrigger: $monthCalendarScrollToTodayTrigger
                            )
                        case .day(.monthlyWorkShift):
                            MonthlyWorkShiftGridView(
                                viewModel: monthlyWorkShiftViewModel,
                                selectedMonth: $monthlyViewMonth,
                                onSelectWorkShift: { selectedDetailItem = .workShift($0) }
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.top, 16)

                    // スワイプ方向の矢印インジケータ（横スワイプ中に表示）
                    swipeArrowOverlay
                    // 「今日」ボタン専用：左右スワイプとは別の return / 巻き戻し風
                    goToTodayReturnOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // 月カレンダーは子の LazyVStack で下余白済み。他モードは右下 FAB・左下「今日」と干渉しないよう確保する
                    if displayMode != .monthlyCalendar {
                        Color.clear.frame(height: 72)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Button {
                        goToToday()
                    } label: {
                        Image(systemName: "eject.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            .background(
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("今日に移動")
                    .padding(.leading, 16)
                    .padding(.bottom, 8)
                }
                .overlay(alignment: .bottomTrailing) {
                    VStack(alignment: .trailing, spacing: 8) {
                        if displayMode == .monthlyCalendar {
                            Button {
                                FeedBack().feedback(.medium)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isMonthCalendarSelectionMode {
                                        clearMonthCalendarMultiSelection()
                                    } else {
                                        isMonthCalendarSelectionMode = true
                                    }
                                }
                            } label: {
                                Text("選択")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(isMonthCalendarSelectionMode ? Color.white : Color.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(isMonthCalendarSelectionMode ? Color.accentColor : Color(.systemBackground))
                                            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("複数日選択モード")
                        }

                        HStack(spacing: 25) {
                            Menu {
                                Picker("表示", selection: toolbarDisplayPickerBinding) {
                                    ForEach(MainToolbarDisplayOption.allCases, id: \.self) { option in
                                        Label(option.title, systemImage: option.symbolName)
                                            .tag(option)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.inline)
                            } label: {
                                Image(systemName: toolbarDisplayOption(from: displayMode).symbolName)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("表示を切り替え")
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    clearMonthCalendarMultiSelection()
                                }
                            )

                            Button {
                                FeedBack().feedback(.medium)
                                isPresentingCreateSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                        )
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            guard allowsDaySwipeNavigation else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // 横方向が優位なときだけ矢印用の値を更新
                            if abs(dx) > abs(dy) {
                                let cap: CGFloat = 120
                                swipeTranslation = min(cap, max(-cap, dx))
                            }
                        }
                        .onEnded { value in
                            guard allowsDaySwipeNavigation else {
                                swipeTranslation = 0
                                return
                            }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            withAnimation(.easeOut(duration: 0.25)) {
                                if abs(dx) > abs(dy), abs(dx) > 60 {
                                    if dx < 0 {
                                        if let next = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.date) {
                                            FeedBack().feedback(.medium)
                                            viewModel.date = next
                                        }
                                    } else {
                                        if let prev = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.date) {
                                            FeedBack().feedback(.medium)
                                            viewModel.date = prev
                                        }
                                    }
                                }
                                swipeTranslation = 0
                            }
                        }
                )
            }
            .navigationDestination(for: ScheduleDetailItem.self) { item in
                ScheduleDetailView(item: item, tags: viewModel.tags, payRates: viewModel.payRates, hourlyRates: viewModel.hourlyRates, shiftTemplates: viewModel.shiftTemplates, onRefresh: { viewModel.refresh() }, onDismiss: nil)
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                ScheduleDetailView(item: item, tags: viewModel.tags, payRates: viewModel.payRates, hourlyRates: viewModel.hourlyRates, shiftTemplates: viewModel.shiftTemplates, onRefresh: { viewModel.refresh() }, onDismiss: { selectedDetailItem = nil })
            }
            .sheet(isPresented: $isPresentingCreateSheet) {
                CreateItemSheet(
                    initialDate: viewModel.date,
                    eventTargetDates: selectedDatesForCreateEvent,
                    hidesEventDatePicker: selectedDatesForCreateEvent != nil,
                    onSaved: {
                        viewModel.refresh()
                        if displayMode == .monthlyCalendar {
                            viewModel.refreshCalendarRange(around: calendarAnchorMonth)
                        }
                        if selectedDatesForCreateEvent != nil {
                            clearMonthCalendarMultiSelection()
                        }
                    }
                )
            }
            .sheet(isPresented: $showWeatherSheet) {
                WeatherTimelineView(
                    dayStart: dayStart,
                    weather: viewModel.todayWeather,
                    hourlyWeather: viewModel.todayHourlyWeather
                )
                .presentationDetents([.fraction(0.2)])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $calendarDayTimelineSheetItem, onDismiss: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sheetScheduleDetailItem = nil
                    // 月カレンダー上の「選択」ハイライトを消すため、選択日を今日に戻す
                    viewModel.date = viewModel.todayStartOfDay()
                }
            }) { item in
                CalendarDayTimelineSheetHost(
                    dayStart: item.dayStart,
                    viewModel: viewModel,
                    sheetDetail: $sheetScheduleDetailItem,
                    displayMode: displayMode,
                    calendarAnchorMonth: calendarAnchorMonth,
                    onDismissSheet: {
                        calendarDayTimelineSheetItem = nil
                    }
                )
            }
            .onChange(of: viewModel.errorMessage) {
                if viewModel.errorMessage != nil {
                    showErrorAlert = true
                }
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                if !hasSyncedDisplayModeFromStorage {
                    hasSyncedDisplayModeFromStorage = true
                    // 新キー未設定の既存ユーザーは旧 `isTimeAxisMode` から 1 回だけ移行
                    if UserDefaults.standard.object(forKey: Constants.appStorageLastMainDisplayMode) == nil {
                        let legacyIsTimeAxis = UserDefaults.standard.object(forKey: "isTimeAxisMode") as? Bool ?? true
                        lastMainDisplayModeRaw = legacyIsTimeAxis
                            ? MainToolbarDisplayOption.hourlyTimeline.rawValue
                            : MainToolbarDisplayOption.list.rawValue
                    }
                    let option = MainToolbarDisplayOption(rawValue: lastMainDisplayModeRaw) ?? .hourlyTimeline
                    if option != toolbarDisplayOption(from: displayMode) {
                        applyMainDisplayMode(option, animated: false, persistToAppStorage: false)
                    }
                }
                viewModel.refresh()
            }
            .onChange(of: displayMode) {
                if displayMode != .monthlyCalendar {
                    clearMonthCalendarMultiSelection()
                }
            }
        }
    }

    private var selectedDatesForCreateEvent: [Date]? {
        guard displayMode == .monthlyCalendar, isMonthCalendarSelectionMode else { return nil }
        let dates = monthCalendarSelectedDates.sorted()
        return dates.isEmpty ? nil : dates
    }

    private func toolbarDisplayOption(from mode: DayViewMode) -> MainToolbarDisplayOption {
        switch mode {
        case .monthlyCalendar: return .monthlyCalendar
        case let .day(kind):
            switch kind {
            case .hourlyTimeline: return .hourlyTimeline
            case .list: return .list
            case .monthlyWorkShift: return .monthlyWorkShift
            }
        }
    }

    private var toolbarDisplayPickerBinding: Binding<MainToolbarDisplayOption> {
        Binding(
            get: { toolbarDisplayOption(from: displayMode) },
            set: { applyToolbarDisplay($0) }
        )
    }

    private func applyToolbarDisplay(_ option: MainToolbarDisplayOption) {
        clearMonthCalendarMultiSelection()
        guard option != toolbarDisplayOption(from: displayMode) else { return }
        FeedBack().feedback(.medium)
        applyMainDisplayMode(option, animated: true, persistToAppStorage: true)
    }

    /// 月カレンダーの複数日選択を解除（表示切り替え操作と連動）
    private func clearMonthCalendarMultiSelection() {
        isMonthCalendarSelectionMode = false
        monthCalendarSelectedDates.removeAll()
    }

    /// 表示モードを適用。`persistToAppStorage` が true のとき右下で選んだ内容を `lastMainDisplayModeRaw` に保存する。
    private func applyMainDisplayMode(_ option: MainToolbarDisplayOption, animated: Bool, persistToAppStorage: Bool) {
        if persistToAppStorage {
            lastMainDisplayModeRaw = option.rawValue
        }
        let apply = {
            switch option {
            case .hourlyTimeline:
                displayMode = .day(.hourlyTimeline)
            case .list:
                displayMode = .day(.list)
            case .monthlyWorkShift:
                displayMode = .day(.monthlyWorkShift)
                monthlyViewMonth = viewModel.date
                monthlyWorkShiftViewModel.month = monthlyViewMonth
                monthlyWorkShiftViewModel.refresh()
            case .monthlyCalendar:
                calendarAnchorMonth = viewModel.date
                displayMode = .monthlyCalendar
            }
        }
        if animated {
            withAnimation(.linear) { apply() }
        } else {
            apply()
        }
    }

    /// 日付を今日にし、月カレンダーでは該当月へスクロール。勤務表では表示月を今日の月に合わせる。
    private func goToToday() {
        FeedBack().feedback(.medium)
        playGoToTodayReturnEffect()
        switch displayMode {
        case .monthlyCalendar:
            viewModel.selectTodayAndRefreshCalendarRange()
            calendarAnchorMonth = viewModel.date
            monthCalendarScrollToTodayTrigger = UUID()
        case .day(.monthlyWorkShift):
            viewModel.selectToday()
            monthlyViewMonth = viewModel.date
            monthlyWorkShiftViewModel.month = monthlyViewMonth
            monthlyWorkShiftViewModel.refresh()
        case .day(.hourlyTimeline), .day(.list):
            viewModel.selectToday()
        }
    }

    // MARK: - その日の天気（ZStack + position で左上スペースを最大利用）

    private var dayWeatherView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今日の天気")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
            if isRainMode {
                weatherRowMarqueeView
                    .frame(width: 320)
            } else {
                weatherRowStaticView
            }
        }
        .frame(alignment: .leading)
    }

    /// 通常時：天気・温度のみの HStack（静止）
    private var weatherRowStaticView: some View {
        HStack(spacing: 12) {
            if let w = viewModel.todayWeather {
                ColoredWeatherSymbolView(symbolName: w.symbolName, fontSize: 48)
                    .frame(width: 48, height: 48)
                if let temp = w.temperatureCelsius {
                    Text("\(Int(round(temp)))℃")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "cloud")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .frame(width: 48, height: 48)
                Text("—")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 傘モード時：天気・温度・「傘が必要です」の HStack 全体を横スクロール（マーキー）
    private var weatherRowMarqueeView: some View {
        WeatherRowMarqueeView(
            symbolName: "cloud.rain.fill",
            temperatureText: viewModel.todayWeather?.temperatureCelsius.map { "\(Int(round($0)))℃" } ?? "—",
            showUmbrellaText: true
        )
    }

    /// 傘が必要な天気かどうか。時間別データがあれば24時間分のシンボルを map してどれかが該当するかで判定
    private var isRainMode: Bool {
        if !viewModel.todayHourlyWeather.isEmpty {
            return viewModel.todayHourlyWeather.contains { symbolNeedsUmbrella($0.symbolName) }
        }
        guard let w = viewModel.todayWeather else { return false }
        if let chance = w.precipitationChance, chance >= 0.5 { return true }
        return symbolNeedsUmbrella(w.symbolName)
    }

    /// シンボル名が雨・雪・雷など傘が必要な天気かどうか
    private func symbolNeedsUmbrella(_ symbolName: String) -> Bool {
        let s = symbolName.lowercased()
        return s.contains("rain")
            || s.contains("snow")
            || s.contains("sleet")
            || s.contains("hail")
            || s.contains("drizzle")
            || s.contains("bolt")
    }

    // MARK: - スワイプ矢印オーバーレイ

    /// 「今日」専用：中央付近に return（Uターン）アイコンを一瞬出す（スワイプ矢印とは別レイヤー）
    private func playGoToTodayReturnEffect() {
        goToTodayReturnEffectProgress = 0
        withAnimation(.easeOut(duration: 0.22)) {
            goToTodayReturnEffectProgress = 1
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.easeIn(duration: 0.38)) {
                goToTodayReturnEffectProgress = 0
            }
        }
    }

    private var goToTodayReturnOverlay: some View {
        let p = goToTodayReturnEffectProgress
        let opacity = Double(p * 0.92)
        let scale = 0.58 + 0.42 * p

        return ZStack {
            if p > 0.001 {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(.black.opacity(0.5)))
                    .scaleEffect(scale)
                    .opacity(opacity)
                    // 中央付近だけ戻る方向に傾く（フェードアウト端で変な回転にならないよう sin）
                    .rotationEffect(.degrees(-26 * sin(Double(p) * .pi)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var swipeArrowOverlay: some View {
        let progress = min(1, abs(swipeTranslation) / 100)
        let opacity = Double(progress * 0.9)
        let scale = 0.6 + 0.4 * progress

        return ZStack {
            // 右スワイプ → 前日（左矢印）
            if swipeTranslation > 20 {
                HStack {
                    swipeArrowCircle(icon: "chevron.left")
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .offset(x: -20 + swipeTranslation * 0.15)
                    Spacer()
                }
                .padding(.leading, 24)
            }
            // 左スワイプ → 翌日（右矢印）
            if swipeTranslation < -20 {
                HStack {
                    Spacer()
                    swipeArrowCircle(icon: "chevron.right")
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .offset(x: 20 + swipeTranslation * 0.15)
                }
                .padding(.trailing, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private func swipeArrowCircle(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Circle().fill(.black.opacity(0.5)))
    }
}

// MARK: - 月カレンダーから開く 1 日タイムラインシート

private struct CalendarDayTimelineSheetItem: Identifiable, Hashable {
    let dayStart: Date
    var id: Date { dayStart }
}

private struct CalendarDayTimelineSheetHost: View {
    let dayStart: Date
    @Bindable var viewModel: DayViewModel
    @Binding var sheetDetail: ScheduleDetailItem?
    let displayMode: DayViewMode
    let calendarAnchorMonth: Date
    let onDismissSheet: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(Self.title(for: dayStart))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                TimeAxisDayView(
                    dayStart: dayStart,
                    unitMinutes: 60,
                    events: viewModel.events,
                    workShifts: viewModel.workShifts,
                    tags: viewModel.tags,
                    payRates: viewModel.payRates,
                    hourlyRates: viewModel.hourlyRates,
                    shiftTemplates: viewModel.shiftTemplates,
                    onSelectEvent: { sheetDetail = .event($0) },
                    onSelectWorkShift: { sheetDetail = .workShift($0) },
                    onDeleteEvent: { viewModel.deleteEvent($0) },
                    onDeleteWorkShift: { viewModel.deleteWorkShift($0) },
                    onRefresh: { await viewModel.refreshAsync() }
                )
                .navigationDestination(item: $sheetDetail) { item in
                    ScheduleDetailView(
                        item: item,
                        tags: viewModel.tags,
                        payRates: viewModel.payRates,
                        hourlyRates: viewModel.hourlyRates,
                        shiftTemplates: viewModel.shiftTemplates,
                        onRefresh: {
                            viewModel.refresh()
                            if displayMode == .monthlyCalendar {
                                viewModel.refreshCalendarRange(around: calendarAnchorMonth)
                            }
                        },
                        onDismiss: { sheetDetail = nil }
                    )
                }
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
    }

    private static func title(for day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: day)
    }
}

// MARK: - 天気・温度・傘テキストの HStack 全体を横スクロール（マーキー）

private struct WeatherRowMarqueeView: View {
    var symbolName: String
    var temperatureText: String
    var showUmbrellaText: Bool

    private let unitWidth: CGFloat = 320
    private let scrollSpeed: CGFloat = 25

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.03)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let x = CGFloat(elapsed * Double(scrollSpeed)).truncatingRemainder(dividingBy: unitWidth)
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 12) {
                        ColoredWeatherSymbolView(symbolName: symbolName, fontSize: 48)
                            .frame(width: 48, height: 48)
                        Text(temperatureText)
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        if showUmbrellaText {
                            Text("傘が必要です！")
                                .font(.custom("DotGothic16-Regular", size: 20))
                                .foregroundStyle(Color.yellow)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(width: unitWidth, alignment: .leading)
                }
            }
            .offset(x: -x)
        }
        .frame(height: 80)
    }
}

#Preview {
    DayView()
}
