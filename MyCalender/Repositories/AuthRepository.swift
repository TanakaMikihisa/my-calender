import Foundation
import FirebaseAuth

protocol AuthRepositoryProtocol: Sendable {
    func ensureSignedInAnonymously() async throws -> String
    func currentUserId() -> String?
}

actor FirebaseAuthRepository: AuthRepositoryProtocol {
    func ensureSignedInAnonymously() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }

        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let uid = result?.user.uid else {
                    continuation.resume(throwing: NSError(
                        domain: "Auth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "匿名認証に失敗しました"]
                    ))
                    return
                }
                continuation.resume(returning: uid)
            }
        }
    }

    nonisolated func currentUserId() -> String? {
        Auth.auth().currentUser?.uid
    }
}

