import Foundation
import UserNotifications

extension UNUserNotificationCenter {
    func pendingNotificationRequestsAsync() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { continuation.resume(returning: $0) }
        }
    }
}

/// 次の 0:00（翌日の始まり）に、その日の予定だけを本文にしたローカル通知を1件スケジュール（アプリ起動のたびに更新）
final class DailyScheduleNotificationScheduler: @unchecked Sendable {
    static let shared = DailyScheduleNotificationScheduler()

    private let notificationIdPrefix = "dailySchedule."
    /// 次の通知は1件だけ（識別子固定で差し替え）
    private let nextNotificationIdentifier = "dailySchedule.next"
    /// 設定の「テスト通知」用（本番のスケジュールとは別ID）
    private let testNotificationIdentifier = "dailySchedule.test"

    private init() {}

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Constants.appStorageDailyScheduleNotificationEnabled)
    }

    /// 通知権限のリクエストと、**次の 0:00** の1件だけ再スケジュール（取得はその日の予定のみ）
    /// - Note: `actor` リポジトリの既定値は非隔離のデフォルト引数で生成できないため、省略時は本体で生成する。
    func reschedule(
        authRepository: AuthRepositoryProtocol? = nil,
        eventRepository: EventRepositoryProtocol? = nil,
        workShiftRepository: WorkShiftRepositoryProtocol? = nil
    ) async throws {
        guard isEnabled else {
            await removeAllDailyNotifications()
            return
        }

        let authRepo: AuthRepositoryProtocol = if let authRepository {
            authRepository
        } else {
            FirebaseAuthRepository()
        }
        let eventRepo: EventRepositoryProtocol = if let eventRepository {
            eventRepository
        } else {
            FirestoreEventRepository()
        }
        let shiftRepo: WorkShiftRepositoryProtocol = if let workShiftRepository {
            workShiftRepository
        } else {
            FirestoreWorkShiftRepository()
        }

        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { return }

        let calendar = Calendar.current
        let now = Date()
        guard let targetDayStart = Self.nextNotificationDayStart(from: now, calendar: calendar) else { return }

        let dayEnd = targetDayStart.endOfDay(in: calendar)

        guard targetDayStart > now else { return }

        let uid = try await authRepo.ensureSignedInAnonymously()

        async let eventsTask = eventRepo.listActiveOverlapping(uid: uid, start: targetDayStart, end: dayEnd)
        async let shiftsTask = shiftRepo.listActiveOverlapping(uid: uid, start: targetDayStart, end: dayEnd)

        let (events, shifts) = try await (eventsTask, shiftsTask)

        center.removePendingNotificationRequests(withIdentifiers: [nextNotificationIdentifier])

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "H:mm"

        let title = "今日の予定"

        let body = Self.buildBody(events: events, shifts: shifts, timeFormatter: timeFormatter)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        var comps = calendar.dateComponents([.year, .month, .day], from: targetDayStart)
        comps.hour = 0
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(identifier: nextNotificationIdentifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    /// 確認用。呼び出し後すぐにスケジュールし、短い間隔で本番と同じタイトル・本文形式の通知を1件出す（遅延は呼び出し側で入れること。トグルOFFでも可）。
    func scheduleTestNotification(
        authRepository: AuthRepositoryProtocol? = nil,
        eventRepository: EventRepositoryProtocol? = nil,
        workShiftRepository: WorkShiftRepositoryProtocol? = nil
    ) async throws {
        let authRepo: AuthRepositoryProtocol = if let authRepository {
            authRepository
        } else {
            FirebaseAuthRepository()
        }
        let eventRepo: EventRepositoryProtocol = if let eventRepository {
            eventRepository
        } else {
            FirestoreEventRepository()
        }
        let shiftRepo: WorkShiftRepositoryProtocol = if let workShiftRepository {
            workShiftRepository
        } else {
            FirestoreWorkShiftRepository()
        }

        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { return }

        let calendar = Calendar.current
        let now = Date()
        guard let targetDayStart = Self.nextNotificationDayStart(from: now, calendar: calendar) else { return }
        let dayEnd = targetDayStart.endOfDay(in: calendar)
        guard targetDayStart > now else { return }

        let uid = try await authRepo.ensureSignedInAnonymously()
        async let eventsTask = eventRepo.listActiveOverlapping(uid: uid, start: targetDayStart, end: dayEnd)
        async let shiftsTask = shiftRepo.listActiveOverlapping(uid: uid, start: targetDayStart, end: dayEnd)
        let (events, shifts) = try await (eventsTask, shiftsTask)

        center.removePendingNotificationRequests(withIdentifiers: [testNotificationIdentifier])

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "H:mm"

        let content = UNMutableNotificationContent()
        content.title = "My Calender - 今日の予定"
        content.body = Self.buildBody(events: events, shifts: shifts, timeFormatter: timeFormatter)
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: testNotificationIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    /// 次の通知は「今より後の最初の 0:00」＝翌日の始まり（その日の予定を表示）
    private static func nextNotificationDayStart(from now: Date, calendar: Calendar) -> Date? {
        let todayStart = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: todayStart)
    }

    func removeAllDailyNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequestsAsync()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(notificationIdPrefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func buildBody(
        events: [Event],
        shifts: [WorkShift],
        timeFormatter: DateFormatter
    ) -> String {
        // 予定・勤務を1本のタイムラインに混ぜ、開始時刻順（同刻は終了時刻で安定ソート）
        var items: [ScheduleDetailItem] = events.map { .event($0) }
        items.append(contentsOf: shifts.map { .workShift($0) })
        items.sort {
            if $0.startAt != $1.startAt { return $0.startAt < $1.startAt }
            return $0.endAt < $1.endAt
        }

        var lines: [String] = []
        for item in items {
            let name: String
            switch item {
            case let .event(e):
                name = e.title
            case let .workShift(s):
                let company = s.companyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                name = company.isEmpty ? "勤務" : company
            }
            let range = "\(timeFormatter.string(from: item.startAt))〜\(timeFormatter.string(from: item.endAt))"
            lines.append("\(range) \(name)")
        }
        if lines.isEmpty {
            return "予定はありません"
        }
        let joined = lines.joined(separator: "\n")
        let maxLen = 400
        if joined.count > maxLen {
            return String(joined.prefix(maxLen - 1)) + "…"
        }
        return joined
    }
}
