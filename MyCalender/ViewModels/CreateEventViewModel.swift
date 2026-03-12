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
                let uid = try await authRepository.ensureSignedInAnonymously()
                tags = try await tagRepository.listActive(uid: uid)
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

    func save() async -> Bool {
        guard canSave else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
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
            try await eventRepository.upsert(uid: uid, event: event)
            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
