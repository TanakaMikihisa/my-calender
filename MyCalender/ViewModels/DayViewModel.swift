import Foundation
import Observation
import SwiftUI

@Observable
final class DayViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let eventRepository: EventRepositoryProtocol
    private let workShiftRepository: WorkShiftRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol
    private let payRateRepository: PayRateRepositoryProtocol
    private let hourlyRateRepository: HourlyRateRepositoryProtocol
    private let shiftTemplateRepository: ShiftTemplateRepositoryProtocol
    private let weatherRepository: WeatherRepositoryProtocol

    var date: Date
    var events: [Event] = []
    var workShifts: [WorkShift] = []
    var tags: [Tag] = []
    var payRates: [PayRate] = []
    var hourlyRates: [HourlyRate] = []
    var shiftTemplates: [ShiftTemplate] = []
    /// 当日の天気（アプリ起動時に1回取得し、日付切り替えでもそのまま表示）
    var todayWeather: Weather?
    /// 当日の時間別天気（0〜23時）。todayWeather と同時に取得
    var todayHourlyWeather: [HourlyWeatherItem] = []
    var isLoading: Bool = false
    /// 月カレンダー（縦スクロール）用。単日の `events` / `workShifts` とは別に保持する。
    var calendarRangeEvents: [Event] = []
    var calendarRangeWorkShifts: [WorkShift] = []
    var isLoadingCalendarRange: Bool = false
    var errorMessage: String?

    init(
        date: Date = Date(),
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        eventRepository: EventRepositoryProtocol = FirestoreEventRepository(),
        workShiftRepository: WorkShiftRepositoryProtocol = FirestoreWorkShiftRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository(),
        payRateRepository: PayRateRepositoryProtocol = FirestorePayRateRepository(),
        hourlyRateRepository: HourlyRateRepositoryProtocol = FirestoreHourlyRateRepository(),
        shiftTemplateRepository: ShiftTemplateRepositoryProtocol = FirestoreShiftTemplateRepository(),
        weatherRepository: WeatherRepositoryProtocol
    ) {
        self.date = date
        self.authRepository = authRepository
        self.eventRepository = eventRepository
        self.workShiftRepository = workShiftRepository
        self.tagRepository = tagRepository
        self.payRateRepository = payRateRepository
        self.hourlyRateRepository = hourlyRateRepository
        self.shiftTemplateRepository = shiftTemplateRepository
        self.weatherRepository = weatherRepository
    }

    /// メイン画面用：その日の予定（イベント・シフト）だけ await し、isLoading を終了。tags / payRates / 天気はバックグラウンドで取得。
    func refresh() {
        Task { @MainActor in await refreshAsync() }
    }

    /// プルで更新・表示切替時の再読み込み用。完了まで await できる。
    func refreshAsync() async {
        await MainActor.run { isLoading = true }
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            let start = date.startOfDay()
            let end = date.endOfDay()

            async let eventsTask = eventRepository.listActiveOverlapping(uid: uid, start: start, end: end)
            async let shiftsTask = workShiftRepository.listActiveOverlapping(uid: uid, start: start, end: end)

            let (fetchedEvents, fetchedShifts) = try await (eventsTask, shiftsTask)
            await MainActor.run {
                self.events = fetchedEvents
                self.workShifts = fetchedShifts
                self.errorMessage = nil
            }
            await MainActor.run { loadTagsPayRatesAndWeatherInBackground() }
            rescheduleDailyNotificationsIfNeeded()
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    /// 毎日0:00のローカル通知を、最新の予定で再スケジュール
    private func rescheduleDailyNotificationsIfNeeded() {
        Task.detached { [authRepository, eventRepository, workShiftRepository] in
            try? await DailyScheduleNotificationScheduler.shared.reschedule(
                authRepository: authRepository,
                eventRepository: eventRepository,
                workShiftRepository: workShiftRepository
            )
        }
    }

    /// tags / payRates / 天気は予定追加画面でも使うが、メイン表示用にバックグラウンドで取得（isLoading は立てない）
    private func loadTagsPayRatesAndWeatherInBackground() {
        Task { @MainActor in
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                async let tagsTask = tagRepository.listActive(uid: uid)
                async let payRatesTask = payRateRepository.listActive(uid: uid)
                async let hourlyRatesTask = hourlyRateRepository.listActive(uid: uid)
                async let templatesTask = shiftTemplateRepository.listActive(uid: uid)
                self.tags = try await tagsTask
                self.payRates = try await payRatesTask
                self.hourlyRates = try await hourlyRatesTask
                self.shiftTemplates = try await templatesTask
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
                let uid = try await authRepository.ensureSignedInAnonymously()
                try await eventRepository.deactivate(uid: uid, eventId: event.id)
                self.errorMessage = nil
                withAnimation(.easeOut(duration: 0.25)) { refresh() }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deleteWorkShift(_ shift: WorkShift) {
        Task { @MainActor in
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                try await workShiftRepository.deactivate(uid: uid, shiftId: shift.id)
                self.errorMessage = nil
                withAnimation(.easeOut(duration: 0.25)) { refresh() }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// 月カレンダー表示用：指定月を中心に前後12か月ぶんの予定を読み込む（単日表示の配列は上書きしない）。
    func refreshCalendarRangeAsync(around center: Date) async {
        await MainActor.run { isLoadingCalendarRange = true }
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            let cal = Calendar.current
            let monthStart = center.startOfMonth()
            guard let fetchStart = cal.date(byAdding: .month, value: -12, to: monthStart),
                  let fetchEnd = cal.date(byAdding: .month, value: 13, to: monthStart)
            else {
                await MainActor.run { isLoadingCalendarRange = false }
                return
            }
            async let evTask = eventRepository.listActiveOverlapping(uid: uid, start: fetchStart, end: fetchEnd)
            async let wsTask = workShiftRepository.listActiveOverlapping(uid: uid, start: fetchStart, end: fetchEnd)
            let (fetchedEvents, fetchedShifts) = try await (evTask, wsTask)
            await MainActor.run {
                self.calendarRangeEvents = fetchedEvents
                self.calendarRangeWorkShifts = fetchedShifts
                self.errorMessage = nil
            }
            await MainActor.run { loadTagsPayRatesAndWeatherInBackground() }
            rescheduleDailyNotificationsIfNeeded()
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoadingCalendarRange = false }
    }

    func refreshCalendarRange(around center: Date) {
        Task { await refreshCalendarRangeAsync(around: center) }
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
