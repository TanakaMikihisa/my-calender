import Foundation
import Observation

@Observable
final class CreateWorkShiftViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let workShiftRepository: WorkShiftRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol

    var startAt: Date
    var endAt: Date
    var payType: WorkPayType
    /// 固定給のときの金額（入力用文字列）
    var fixedPayText: String = ""
    var tags: [Tag] = []
    var selectedTagIds: Set<TagID> = []

    var isSaving: Bool = false
    var errorMessage: String?

    init(
        initialDate: Date,
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        workShiftRepository: WorkShiftRepositoryProtocol = FirestoreWorkShiftRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository()
    ) {
        self.authRepository = authRepository
        self.workShiftRepository = workShiftRepository
        self.tagRepository = tagRepository
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        let end = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: initialDate) ?? start.addingTimeInterval(3600 * 8)
        self.startAt = start
        self.endAt = end
        self.payType = .hourly
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
        guard startAt < endAt else { return false }
        if payType == .fixed {
            return parsedFixedPay != nil
        }
        return true
    }

    private var parsedFixedPay: Decimal? {
        let trimmed = fixedPayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }

    func save() async -> Bool {
        guard canSave else { return false }

        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            let now = Date()
            let shift = WorkShift(
                id: UUID().uuidString,
                startAt: startAt,
                endAt: endAt,
                payType: payType,
                payRateId: nil,
                fixedPay: payType == .fixed ? parsedFixedPay : nil,
                templateId: nil,
                tagIds: Array(selectedTagIds),
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
            try await workShiftRepository.upsert(uid: uid, shift: shift)
            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
