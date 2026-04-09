import Foundation
import Observation

@Observable
final class CreateEventViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let eventRepository: EventRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol

    var title: String = ""
    var startAt: Date
    var endAt: Date
    var note: String = ""
    var tags: [Tag] = []
    var selectedTagIds: Set<TagID> = []

    var isSaving: Bool = false
    var errorMessage: String?

    init(
        initialDate: Date,
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        eventRepository: EventRepositoryProtocol = FirestoreEventRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository()
    ) {
        self.authRepository = authRepository
        self.eventRepository = eventRepository
        self.tagRepository = tagRepository
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        let end = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: initialDate) ?? initialDate.addingTimeInterval(3600)
        self.startAt = start
        self.endAt = end
    }

    func loadTags() {
        Task { @MainActor in
            do {
                tags = try await tagRepository.listActive()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleTag(_ id: TagID) {
        if selectedTagIds.contains(id) {
            selectedTagIds.remove(id)
        } else {
            selectedTagIds.insert(id)
        }
    }

    var canSave: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && startAt < endAt
    }

    /// タイトルに "H:mm-H:mm" または "H:mm〜H:mm" があれば開始・終了をその値に更新する
    func applyTimeRangeFromTitleIfNeeded() {
        guard let range = title.parsedTimeRange() else { return }
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: startAt)
        guard let newStart = calendar.date(bySettingHour: range.startHour, minute: range.startMinute, second: 0, of: baseDate),
              var newEnd = calendar.date(bySettingHour: range.endHour, minute: range.endMinute, second: 0, of: baseDate) else { return }
        if newEnd <= newStart {
            newEnd = calendar.date(byAdding: .day, value: 1, to: newEnd) ?? newEnd
        }
        startAt = newStart
        endAt = newEnd
    }

    /// 開始変更で終了が開始以下になった場合、終了を開始+1時間に補正する
    func normalizeEndAtAfterStartChanged() {
        guard endAt <= startAt else { return }
        endAt = startAt.addingTimeInterval(3600)
    }

    func save() async -> Bool {
        guard canSave else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        do {
            let now = Date()
            let event = Event(
                id: UUID().uuidString,
                type: .normal,
                title: trimmedTitle,
                startAt: startAt,
                endAt: endAt,
                note: note.isEmpty ? nil : note,
                tagIds: Array(selectedTagIds),
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
            try await eventRepository.upsert(event: event)
            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func save(onDates: [Date]) async -> Bool {
        let normalizedDates = Array(Set(onDates.map { $0.startOfDay() })).sorted()
        guard !normalizedDates.isEmpty else { return await save() }
        guard canSave else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current

        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        do {
            let now = Date()

            let baseStartHour = calendar.component(.hour, from: startAt)
            let baseStartMinute = calendar.component(.minute, from: startAt)
            let baseEndHour = calendar.component(.hour, from: endAt)
            let baseEndMinute = calendar.component(.minute, from: endAt)
            let wrapsToNextDay = endAt <= startAt

            for date in normalizedDates {
                guard let start = calendar.date(bySettingHour: baseStartHour, minute: baseStartMinute, second: 0, of: date),
                      var end = calendar.date(bySettingHour: baseEndHour, minute: baseEndMinute, second: 0, of: date)
                else { continue }
                if wrapsToNextDay || end <= start {
                    end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
                }

                let event = Event(
                    id: UUID().uuidString,
                    type: .normal,
                    title: trimmedTitle,
                    startAt: start,
                    endAt: end,
                    note: note.isEmpty ? nil : note,
                    tagIds: Array(selectedTagIds),
                    isActive: true,
                    createdAt: now,
                    updatedAt: now
                )
                try await eventRepository.upsert(event: event)
            }

            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
