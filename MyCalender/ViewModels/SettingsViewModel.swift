import Foundation
import Observation

@Observable
final class SettingsViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol
    private let eventTemplateRepository: EventTemplateRepositoryProtocol

    var tags: [Tag] = []
    var eventTemplates: [EventTemplate] = []
    var isLoading = false
    var errorMessage: String?

    init(
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository(),
        eventTemplateRepository: EventTemplateRepositoryProtocol = FirestoreEventTemplateRepository()
    ) {
        self.authRepository = authRepository
        self.tagRepository = tagRepository
        self.eventTemplateRepository = eventTemplateRepository
    }

    func loadTags() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                tags = try await tagRepository.listActive()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadAll() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                async let tagsTask = tagRepository.listActive()
                async let eventTemplatesTask = eventTemplateRepository.listActive()
                tags = try await tagsTask
                eventTemplates = try await eventTemplatesTask
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addTag(name: String, colorHex: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            let tag = Tag(
                id: UUID().uuidString,
                name: trimmed,
                colorHex: colorHex,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await tagRepository.add(tag: tag)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updateTag(_ tag: Tag) async -> Bool {
        do {
            var t = tag
            t.updatedAt = Date()
            try await tagRepository.update(tag: t)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivateTag(id: TagID) async -> Bool {
        do {
            try await tagRepository.deactivate(tagId: id)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    // MARK: - EventTemplate

    func loadEventTemplates() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                eventTemplates = try await eventTemplateRepository.listActive()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addEventTemplate(title: String, note: String?, startTime: String, endTime: String, tagIds: [TagID]) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        do {
            let template = EventTemplate(
                id: UUID().uuidString,
                title: trimmedTitle,
                note: note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : note,
                startTime: startTime,
                endTime: endTime,
                tagIds: tagIds,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await eventTemplateRepository.add(template: template)
            await MainActor.run { loadEventTemplates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updateEventTemplate(_ template: EventTemplate) async -> Bool {
        do {
            var t = template
            t.updatedAt = Date()
            try await eventTemplateRepository.update(template: t)
            await MainActor.run { loadEventTemplates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivateEventTemplate(id: EventTemplateID) async -> Bool {
        do {
            try await eventTemplateRepository.deactivate(templateId: id)
            await MainActor.run { loadEventTemplates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
