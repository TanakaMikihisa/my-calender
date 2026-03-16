import SwiftUI

/// メイン画面の表示モード（イベント時間軸 / リスト / 月次勤務）
private enum DayViewMode {
    case eventTimeline
    case list
    case monthlyWorkShift
}

struct DayView: View {
    /// 時間軸 vs リストの選択（天気以外で永続化）
    @AppStorage(Constants.appStorageIsTimeAxisMode) private var isTimeAxisMode = true
    /// true = 1時間単位, false = 30分単位
    @AppStorage(Constants.appStorageIsOneHourUnit) private var isOneHourUnit = true

    @State private var viewModel = DayViewModel(
        weatherRepository: WeatherKitWeatherRepository(locationRepository: DefaultLocationRepository())
    )
    @State private var isPresentingCreateSheet = false
    @State private var showErrorAlert = false
    @State private var selectedDetailItem: ScheduleDetailItem?
    /// 横スワイプの現在値（正=右方向=前日、負=左方向=翌日）。矢印表示に使用
    @State private var swipeTranslation: CGFloat = 0
    @State private var displayMode: DayViewMode = .eventTimeline
    @State private var hasSyncedDisplayModeFromStorage = false
    @State private var showWeatherSheet = false
    /// 月次勤務ビューで表示する月（任意の日付でよい）
    @State private var monthlyViewMonth = Date()
    @State private var monthlyWorkShiftViewModel = MonthlyWorkShiftViewModel(month: Date())

    private var dayStart: Date { viewModel.date.startOfDay() }
    private var dayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
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
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                            .frame(minWidth: 150)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if displayMode == .monthlyWorkShift {
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
                .onChange(of: viewModel.date) { _, _ in
                    if displayMode != .monthlyWorkShift {
                        viewModel.refresh()
                    }
                }
                .onChange(of: displayMode) { _, newMode in
                    switch newMode {
                    case .eventTimeline, .list:
                        viewModel.refresh()
                    case .monthlyWorkShift:
                        monthlyWorkShiftViewModel.month = monthlyViewMonth
                        monthlyWorkShiftViewModel.refresh()
                    }
                }

                ZStack {
                    Group {
                        switch displayMode {
                        case .eventTimeline:
                            TimeAxisDayView(
                                dayStart: dayStart,
                                unitMinutes: isOneHourUnit ? 60 : 30,
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
                        case .list:
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
                        case .monthlyWorkShift:
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
                }
                .onAppear {
                    if !hasSyncedDisplayModeFromStorage {
                        hasSyncedDisplayModeFromStorage = true
                        displayMode = isTimeAxisMode ? .eventTimeline : .list
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            guard displayMode != .monthlyWorkShift else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // 横方向が優位なときだけ矢印用の値を更新
                            if abs(dx) > abs(dy) {
                                let cap: CGFloat = 120
                                swipeTranslation = min(cap, max(-cap, dx))
                            }
                        }
                        .onEnded { value in
                            guard displayMode != .monthlyWorkShift else {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if displayMode == .monthlyWorkShift {
                        Button {
                            FeedBack().feedback(.medium)
                            withAnimation(.linear) {
                                displayMode = isTimeAxisMode ? .eventTimeline : .list
                            }
                        } label: {
                            Image(systemName: "calendar.day.timeline.left")
                        }
                    } else {
                        Button {
                            FeedBack().feedback(.medium)
                            withAnimation(.linear) {
                                displayMode = .monthlyWorkShift
                                monthlyViewMonth = viewModel.date
                            }
                        } label: {
                            Image(systemName: "rectangle.grid.1x2")
                        }
                    }
                }
                if displayMode != .monthlyWorkShift {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            FeedBack().feedback(.medium)
                            withAnimation(.linear) {
                                switch displayMode {
                                case .eventTimeline:
                                    displayMode = .list
                                    isTimeAxisMode = false
                                case .list:
                                    displayMode = .eventTimeline
                                    isTimeAxisMode = true
                                case .monthlyWorkShift:
                                    break
                                }
                            }
                        } label: {
                            Image(systemName: displayMode == .list ? "list.bullet" : "calendar")
                        }
                    }
                }
                if displayMode == .eventTimeline {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            FeedBack().feedback(.light)
                            withAnimation {
                                isOneHourUnit.toggle()
                            }
                        } label: {
                            Image(systemName: isOneHourUnit ? "plus.magnifyingglass" : "minus.magnifyingglass")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        FeedBack().feedback(.medium)
                        isPresentingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: ScheduleDetailItem.self) { item in
                ScheduleDetailView(item: item, tags: viewModel.tags, payRates: viewModel.payRates, hourlyRates: viewModel.hourlyRates, shiftTemplates: viewModel.shiftTemplates, onRefresh: { viewModel.refresh() }, onDismiss: nil)
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                ScheduleDetailView(item: item, tags: viewModel.tags, payRates: viewModel.payRates, hourlyRates: viewModel.hourlyRates, shiftTemplates: viewModel.shiftTemplates, onRefresh: { viewModel.refresh() }, onDismiss: { selectedDetailItem = nil })
            }
            .sheet(isPresented: $isPresentingCreateSheet) {
                CreateItemSheet(initialDate: viewModel.date, onSaved: { viewModel.refresh() })
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
            .onChange(of: viewModel.errorMessage) { _, new in
                if new != nil {
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
                viewModel.refresh()
            }
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
