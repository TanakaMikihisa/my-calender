import Foundation
import Observation
import SwiftUI

@Observable
final class DayViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let eventRepository: EventRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol
    private let weatherRepository: WeatherRepositoryProtocol

    var date: Date
    var events: [Event] = []
    var tags: [Tag] = []
    /// 当日の天気（アプリ起動時に1回取得し、日付切り替えでもそのまま表示）
    var todayWeather: Weather?
    /// 当日の時間別天気（0〜23時）。todayWeather と同時に取得
    var todayHourlyWeather: [HourlyWeatherItem] = []
    var isLoading: Bool = false
    /// 月カレンダー（縦スクロール）用。単日の `events` とは別に保持する。
    var calendarRangeEvents: [Event] = []
    var isLoadingCalendarRange: Bool = false
    /// 月カレンダー縦スクロールの基準±24か月に足す過去分（12か月単位で増やす）
    var calendarExtraPastMonths: Int = 0
    /// 同上・未来側
    var calendarExtraFutureMonths: Int = 0
    private var lastCalendarExpandPastAt: Date?
    private var lastCalendarExpandFutureAt: Date?
    var errorMessage: String?

    init(
        date: Date = Date(),
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        eventRepository: EventRepositoryProtocol = FirestoreEventRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository(),
        weatherRepository: WeatherRepositoryProtocol
    ) {
        self.date = date
        self.authRepository = authRepository
        self.eventRepository = eventRepository
        self.tagRepository = tagRepository
        self.weatherRepository = weatherRepository
    }

    /// メイン画面用：その日の予定だけ await し、isLoading を終了。tags / 天気はバックグラウンドで取得。
    func refresh() {
        Task { @MainActor in await refreshAsync() }
    }

    /// プルで更新・表示切替時の再読み込み用。完了まで await できる。
    func refreshAsync() async {
        await MainActor.run { isLoading = true }
        do {
            let start = date.startOfDay()
            let end = date.endOfDay()

            let fetchedEvents = try await eventRepository.listActiveOverlapping(start: start, end: end)
            await MainActor.run {
                self.events = fetchedEvents
                self.errorMessage = nil
            }
            await MainActor.run { loadTagsAndWeatherInBackground() }
            rescheduleDailyNotificationsIfNeeded()
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    /// 毎日0:00のローカル通知を、最新の予定で再スケジュール
    private func rescheduleDailyNotificationsIfNeeded() {
        Task.detached { [authRepository, eventRepository] in
            try? await DailyScheduleNotificationScheduler.shared.reschedule(
                authRepository: authRepository,
                eventRepository: eventRepository
            )
        }
    }

    /// tags / 天気は予定追加画面でも使うが、メイン表示用にバックグラウンドで取得（isLoading は立てない）
    private func loadTagsAndWeatherInBackground() {
        Task { @MainActor in
            do {
                self.tags = try await tagRepository.listActive()
            } catch {
                // メインの予定表示には不要なのでエラーは握りつぶす
            }

            // 天気は当日分をアプリ起動時のみ取得（未取得のときだけ）
            if self.todayWeather == nil, self.todayHourlyWeather.isEmpty,
               let (w, hourly) = try? await weatherRepository.fetchTodayWeatherWithHourly() {
                self.todayWeather = w
                self.todayHourlyWeather = hourly
            }
        }
    }

    func deleteEvent(_ event: Event) {
        Task { @MainActor in
            do {
                try await eventRepository.deactivate(eventId: event.id)
                self.errorMessage = nil
                withAnimation(.easeOut(duration: 0.25)) { refresh() }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// 月カレンダー表示用：指定月を中心に前後24か月＋拡張分の予定を読み込む（単日表示の配列は上書きしない）。
    func refreshCalendarRangeAsync(around center: Date) async {
        await MainActor.run { isLoadingCalendarRange = true }
        do {
            let cal = Calendar.current
            let monthStart = center.startOfMonth()
            let past = 24 + calendarExtraPastMonths
            let futureExclusive = 25 + calendarExtraFutureMonths
            guard let fetchStart = cal.date(byAdding: .month, value: -past, to: monthStart),
                  let fetchEnd = cal.date(byAdding: .month, value: futureExclusive, to: monthStart)
            else {
                await MainActor.run { isLoadingCalendarRange = false }
                return
            }
            let fetchedEvents = try await eventRepository.listActiveOverlapping(start: fetchStart, end: fetchEnd)
            await MainActor.run {
                self.calendarRangeEvents = fetchedEvents
                self.errorMessage = nil
            }
            await MainActor.run { loadTagsAndWeatherInBackground() }
            rescheduleDailyNotificationsIfNeeded()
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoadingCalendarRange = false }
    }

    func refreshCalendarRange(around center: Date) {
        Task { await refreshCalendarRangeAsync(around: center) }
    }

    /// 月カレンダーモードに入り直したときなど、表示範囲の拡張を初期化する
    func resetCalendarRangeExpansion() {
        calendarExtraPastMonths = 0
        calendarExtraFutureMonths = 0
        lastCalendarExpandPastAt = nil
        lastCalendarExpandFutureAt = nil
    }

    /// 「今月」と同じ月のブロックが一覧の手前に見えたら過去へ1年分広げる（連打・連続レイアウト用に短いクールダウン）
    func requestExpandCalendarRangePastOneYear(around center: Date) {
        guard calendarExtraPastMonths < 120 else { return }
        let now = Date()
        if let t = lastCalendarExpandPastAt, now.timeIntervalSince(t) < 0.25 { return }
        lastCalendarExpandPastAt = now
        calendarExtraPastMonths += 12
        refreshCalendarRange(around: center)
    }

    /// 同様に未来側へ1年分
    func requestExpandCalendarRangeFutureOneYear(around center: Date) {
        guard calendarExtraFutureMonths < 120 else { return }
        let now = Date()
        if let t = lastCalendarExpandFutureAt, now.timeIntervalSince(t) < 0.25 { return }
        lastCalendarExpandFutureAt = now
        calendarExtraFutureMonths += 12
        refreshCalendarRange(around: center)
    }

    /// ローカル日の「今日」0:00
    func todayStartOfDay() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// メインの選択日を今日にする（単日ビューでは `date` 変更に伴う `refresh` は View 側の `onChange` に任せる）
    func selectToday() {
        date = todayStartOfDay()
    }

    /// 選択日を今日にし、月カレンダー用の範囲データを再取得する
    func selectTodayAndRefreshCalendarRange() {
        selectToday()
        refreshCalendarRange(around: date)
    }
}
