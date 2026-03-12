import Foundation
import Observation

@Observable
final class SettingsViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol

    var tags: [Tag] = []
    var isLoading = false
    var errorMessage: String?

    init(
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository()
    ) {
        self.authRepository = authRepository
        self.tagRepository = tagRepository
    }

    func loadTags() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                tags = try await tagRepository.listActive(uid: uid)
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
            let uid = try await authRepository.ensureSignedInAnonymously()
            let tag = Tag(
                id: UUID().uuidString,
                name: trimmed,
                colorHex: colorHex,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await tagRepository.add(uid: uid, tag: tag)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updateTag(_ tag: Tag) async -> Bool {
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            var t = tag
            t.updatedAt = Date()
            try await tagRepository.update(uid: uid, tag: t)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivateTag(id: TagID) async -> Bool {
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            try await tagRepository.deactivate(uid: uid, tagId: id)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
