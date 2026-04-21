import SwiftUI

/// 縦スクロールで月が続くカレンダー。予定のある日の下にタグ色の短いバーを並べる。
struct MonthlyCalendarView: View {
    private let viewModel: MonthCalendarViewModel

    /// 長押しで選択モードに入った直後の指離しで `Button` のトグルが走るのを1回だけ抑止する
    @State private var pendingIgnoreToggleDay: Date?

    /// 複数選択モード中に `multiSelectedDates` が一度でも変わったら true（空のままではモードを自動オフにしない）
    @State private var multiSelectedDatesChangedWhileInMode = false

    /// 内閣府CSVから取得した祝日（`Calendar.current` の startOfDay）
    @State private var holidayStartOfDays: Set<Date> = []

    var anchorMonth: Date
    /// `DayViewModel` の `calendarExtraPastMonths` と揃える（月グリッドと取得範囲を一致させる）
    var extraMonthsPast: Int
    var extraMonthsFuture: Int
    @Binding var selectedDate: Date
    var events: [Event]
    var tags: [Tag]
    var isLoading: Bool
    @Binding var isMultiSelectMode: Bool
    @Binding var multiSelectedDates: Set<Date>
    var onSelectDay: (Date) -> Void
    var onRefresh: () async -> Void
    /// 今月と同じ「月」のブロックが先頭付近で表示されたとき、過去1年分のデータ・グリッドを広げる
    var onNeedPastYear: () -> Void
    /// 末尾付近で同様に未来へ
    var onNeedFutureYear: () -> Void
    /// 親（`DayView`）の「今日」ボタンから `UUID` を渡すと、その月へスクロールする
    @Binding var scrollToTodayTrigger: UUID?

    init(
        viewModel: MonthCalendarViewModel,
        anchorMonth: Date,
        extraMonthsPast: Int = 0,
        extraMonthsFuture: Int = 0,
        selectedDate: Binding<Date>,
        events: [Event],
        tags: [Tag],
        isLoading: Bool,
        isMultiSelectMode: Binding<Bool> = .constant(false),
        multiSelectedDates: Binding<Set<Date>> = .constant([]),
        onSelectDay: @escaping (Date) -> Void,
        onRefresh: @escaping () async -> Void,
        onNeedPastYear: @escaping () -> Void = {},
        onNeedFutureYear: @escaping () -> Void = {},
        scrollToTodayTrigger: Binding<UUID?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        self.anchorMonth = anchorMonth
        self.extraMonthsPast = extraMonthsPast
        self.extraMonthsFuture = extraMonthsFuture
        self._selectedDate = selectedDate
        self.events = events
        self.tags = tags
        self.isLoading = isLoading
        self._isMultiSelectMode = isMultiSelectMode
        self._multiSelectedDates = multiSelectedDates
        self.onSelectDay = onSelectDay
        self.onRefresh = onRefresh
        self.onNeedPastYear = onNeedPastYear
        self.onNeedFutureYear = onNeedFutureYear
        self._scrollToTodayTrigger = scrollToTodayTrigger
    }

    private var monthStarts: [Date] {
        viewModel.monthStarts(anchorMonth: anchorMonth, extraMonthsPast: extraMonthsPast, extraMonthsFuture: extraMonthsFuture)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(Array(monthStarts.enumerated()), id: \.element) { index, monthStart in
                        monthSection(monthStart: monthStart, index: index)
                            .id(viewModel.monthId(for: monthStart))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 72)
            }
            .refreshable { await onRefresh() }
            .overlay {
                if isLoading, events.isEmpty {
                    SavingReturnArrowOverlay(isSaving: true)
                }
            }
            .onAppear {
                let initial = anchorMonth.startOfMonth()
                let id = viewModel.monthId(for: initial)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
            .onChange(of: anchorMonth) {
                let m = anchorMonth.startOfMonth()
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(viewModel.monthId(for: m), anchor: .top)
                }
            }
            .onChange(of: scrollToTodayTrigger) {
                guard scrollToTodayTrigger != nil else { return }
                let today = viewModel.todayStartOfDay()
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(viewModel.monthId(for: today.startOfMonth()), anchor: .top)
                }
                DispatchQueue.main.async {
                    scrollToTodayTrigger = nil
                }
            }
            .onChange(of: isMultiSelectMode) {
                if !isMultiSelectMode {
                    multiSelectedDatesChangedWhileInMode = false
                } else {
                    // 「選択」で空のまま入ったときは false のまま。長押しで日付が入る場合は true 相当。
                    multiSelectedDatesChangedWhileInMode = !multiSelectedDates.isEmpty
                }
            }
            .onChange(of: multiSelectedDates) { old, new in
                guard isMultiSelectMode else { return }
                if old != new {
                    multiSelectedDatesChangedWhileInMode = true
                }
                if new.isEmpty, multiSelectedDatesChangedWhileInMode {
                    multiSelectedDatesChangedWhileInMode = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMultiSelectMode = false
                    }
                }
            }
            .task {
                do {
                    holidayStartOfDays = try await JapaneseHolidayCSVFetcher.fetchHolidayStartOfDays()
                } catch {
                    holidayStartOfDays = []
                }
            }
        }
    }

    private func monthSection(monthStart: Date, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.monthTitle(for: monthStart))
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(viewModel.weekdayLabels[i])
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let weeks = viewModel.weeks(for: monthStart)
            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week: week)
                    Rectangle()
                        .fill(Color(.separator).opacity(0.35))
                        .frame(height: 0.5)
                }
            }
        }
        .onAppear {
            let cal = Calendar.current
            let thisMonth = cal.component(.month, from: Date())
            guard cal.component(.month, from: monthStart) == thisMonth else { return }
            let n = monthStarts.count
            // 先頭／末尾付近の「今月と同じ月」が見えたら親へ通知（親＋VM のクールダウンで連打を抑止）
            if index < 6 {
                onNeedPastYear()
            }
            if n >= 12, index >= n - 6 {
                onNeedFutureYear()
            }
        }
    }

    private func weekRow(week: [Date?]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<7, id: \.self) { ix in
                if let day = week[ix] {
                    dayCell(day: day)
                        .frame(maxWidth: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dayCell(day: Date) -> some View {
        let state = viewModel.dayCellState(
            for: day,
            selectedDate: selectedDate,
            multiSelectedDates: multiSelectedDates,
            isMultiSelectMode: isMultiSelectMode,
            events: events,
            tags: tags,
            holidayStartOfDays: holidayStartOfDays
        )
        let dayStart = day.startOfDay()
        let barCount = min(state.barColorHexes.count, 4)
        let barStackHeight = barCount == 0 ? CGFloat(0) : CGFloat(barCount * 5 - 2)

        return Button {
            if pendingIgnoreToggleDay == dayStart {
                pendingIgnoreToggleDay = nil
                return
            }
            FeedBack().feedback(.medium)
            if isMultiSelectMode {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if multiSelectedDates.contains(dayStart) {
                        multiSelectedDates.remove(dayStart)
                    } else {
                        multiSelectedDates.insert(dayStart)
                    }
                }
            } else {
                selectedDate = dayStart
                onSelectDay(dayStart)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if state.isSelected {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                    } else if state.isToday {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                    }
                    Text("\(state.dayNumber)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(
                            state.isSelected
                                ? Color.accentColor
                                : (state.isToday
                                    ? Color.white
                                    : ((state.isWeekend || state.isHoliday) ? Color.secondary : Color.primary))
                        )
                }
                .frame(height: 34)

                VStack(spacing: 2) {
                    ForEach(Array(state.barColorHexes.prefix(4).enumerated()), id: \.offset) { _, hex in
                        Capsule()
                            .fill(barFillColor(hex: hex))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 6)
                    }
                }
                .frame(height: barStackHeight)
                .opacity(state.barColorHexes.isEmpty ? 0 : 1)
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    guard !isMultiSelectMode else { return }
                    pendingIgnoreToggleDay = dayStart
                    FeedBack().feedback(.medium)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMultiSelectMode = true
                        multiSelectedDates.insert(dayStart)
                    }
                }
        )
    }

    private func barFillColor(hex: String) -> Color {
        if hex == Constants.defaultBoxColorSentinel {
            return Color(.systemGray5).opacity(0.5)
        }
        return Color.from(hex: hex).opacity(0.85)
    }
}

#Preview {
    MonthlyCalendarView(
        viewModel: MonthCalendarViewModel(),
        anchorMonth: Date(),
        selectedDate: .constant(Date()),
        events: [],
        tags: [],
        isLoading: false,
        isMultiSelectMode: .constant(false),
        onSelectDay: { _ in },
        onRefresh: {}
    )
}
