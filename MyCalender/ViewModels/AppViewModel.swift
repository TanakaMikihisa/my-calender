import Foundation
import Observation

@Observable
final class AppViewModel {
    private let authRepository: AuthRepositoryProtocol

    var isReady: Bool = false
    var userId: String?
    var errorMessage: String?

    init(authRepository: AuthRepositoryProtocol = FirebaseAuthRepository()) {
        self.authRepository = authRepository
    }

    func bootstrap() {
        guard !isReady else { return }
        Task { @MainActor in
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                self.userId = uid
                self.isReady = true
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

