import Foundation

/// 縦スクロール月カレンダー用の表示ロジック（データは呼び出し元から渡す）
final class MonthCalendarViewModel {
    private let calendar = Calendar.current

    /// 曜日ヘッダー用（日曜始まり）
    let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    /// 月のスクロール用 ID（`ScrollViewReader`）
    func monthId(for monthStart: Date) -> String {
        let y = calendar.component(.year, from: monthStart)
        let m = calendar.component(.month, from: monthStart)
        return "\(y)-\(m)"
    }

    /// 見出し文言（今年なら「4月」、それ以外は「2026年4月」）
    func monthTitle(for monthStart: Date, referenceNow: Date = Date()) -> String {
        let y = calendar.component(.year, from: monthStart)
        let mo = calendar.component(.month, from: monthStart)
        let thisYear = calendar.component(.year, from: referenceNow)
        if y == thisYear { return "\(mo)月" }
        return "\(y)年\(mo)月"
    }

    /// 基準月の前後24か月＋追加分の各月1日 0:00（縦スクロール用）。追加は親がデータ取得範囲と揃える。
    func monthStarts(anchorMonth: Date, extraMonthsPast: Int = 0, extraMonthsFuture: Int = 0) -> [Date] {
        let anchor = anchorMonth.startOfMonth()
        guard let start = calendar.date(byAdding: .month, value: -(24 + extraMonthsPast), to: anchor),
              let endExclusive = calendar.date(byAdding: .month, value: 25 + extraMonthsFuture, to: anchor)
        else { return [] }
        var months: [Date] = []
        var m = start
        while m < endExclusive {
            months.append(m)
            guard let next = calendar.date(byAdding: .month, value: 1, to: m) else { break }
            m = next
        }
        return months
    }

    /// 1か月分を週ごとの7列（パディングは nil）
    func weeks(for monthStart: Date) -> [[Date?]] {
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        var cells: [Date?] = []
        let pad = firstWeekday - 1
        for _ in 0..<pad {
            cells.append(nil)
        }
        for day in 1...daysInMonth {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(d)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return stride(from: 0, to: cells.count, by: 7).map { i in
            Array(cells[i..<min(i + 7, cells.count)])
        }
    }

    func dayCellState(
        for day: Date,
        selectedDate: Date,
        multiSelectedDates: Set<Date>,
        isMultiSelectMode: Bool,
        events: [Event],
        workShifts: [WorkShift],
        tags: [Tag],
        holidayStartOfDays: Set<Date>
    ) -> MonthCalendarDayCellState {
        let dayStart = day.startOfDay()
        let dayEnd = day.endOfDay()
        let isToday = calendar.isDateInToday(day)
        let isSelected: Bool
        if isMultiSelectMode {
            isSelected = multiSelectedDates.contains(dayStart)
        } else {
            isSelected = calendar.isDate(selectedDate, inSameDayAs: day) && !isToday
        }
        let weekday = calendar.component(.weekday, from: day)
        let isWeekend = weekday == 1 || weekday == 7
        let isHoliday = holidayStartOfDays.contains(dayStart)
        let barHexes = barColorHexes(dayStart: dayStart, dayEnd: dayEnd, events: events, workShifts: workShifts, tags: tags)
        return MonthCalendarDayCellState(
            dayNumber: calendar.component(.day, from: day),
            isToday: isToday,
            isSelected: isSelected,
            isWeekend: isWeekend,
            isHoliday: isHoliday,
            barColorHexes: barHexes
        )
    }

    func todayStartOfDay() -> Date {
        calendar.startOfDay(for: Date())
    }

    // MARK: - Private

    private func barColorHexes(
        dayStart: Date,
        dayEnd: Date,
        events: [Event],
        workShifts: [WorkShift],
        tags: [Tag]
    ) -> [String] {
        var list: [String] = []
        for e in events where e.startAt < dayEnd && e.endAt > dayStart {
            list.append(tagColorHex(for: e, tags: tags))
        }
        for s in workShifts where s.startAt < dayEnd && s.endAt > dayStart {
            list.append(shiftColorHex(for: s, tags: tags))
        }
        return list
    }

    private func tagColorHex(for event: Event, tags: [Tag]) -> String {
        for id in event.tagIds {
            if let tag = tags.first(where: { $0.id == id }) {
                return tag.colorHex
            }
        }
        return Constants.defaultBoxColorSentinel
    }

    private func shiftColorHex(for shift: WorkShift, tags: [Tag]) -> String {
        for id in shift.tagIds {
            if let tag = tags.first(where: { $0.id == id }) {
                return tag.colorHex
            }
        }
        return "#F97316"
    }
}

/// 1日セルの表示に必要な値（View はこれを描画するだけ）
struct MonthCalendarDayCellState: Equatable {
    let dayNumber: Int
    let isToday: Bool
    let isSelected: Bool
    let isWeekend: Bool
    let isHoliday: Bool
    let barColorHexes: [String]
}
