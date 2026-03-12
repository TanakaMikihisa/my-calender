import Foundation
import Observation

@Observable
final class EditEventViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let eventRepository: EventRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol

    let eventId: String
    var title: String
    var startAt: Date
    var endAt: Date
    var note: String
    var tags: [Tag] = []
    var selectedTagIds: Set<TagID>
    let createdAt: Date

    var isSaving: Bool = false
    var errorMessage: String?

    init(
        event: Event,
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        eventRepository: EventRepositoryProtocol = FirestoreEventRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository()
    ) {
        self.authRepository = authRepository
        self.eventRepository = eventRepository
        self.tagRepository = tagRepository
        self.eventId = event.id
        self.title = event.title
        self.startAt = event.startAt
        self.endAt = event.endAt
        self.note = event.note ?? ""
        self.selectedTagIds = Set(event.tagIds)
        self.createdAt = event.createdAt
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
                id: eventId,
                type: .normal,
                title: trimmedTitle,
                startAt: startAt,
                endAt: endAt,
                note: note.isEmpty ? nil : note,
                tagIds: Array(selectedTagIds),
                isActive: true,
                createdAt: createdAt,
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
