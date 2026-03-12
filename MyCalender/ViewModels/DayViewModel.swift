import Foundation
import Observation

@Observable
final class DayViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let eventRepository: EventRepositoryProtocol
    private let workShiftRepository: WorkShiftRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol

    var date: Date
    var events: [Event] = []
    var workShifts: [WorkShift] = []
    var tags: [Tag] = []
    var isLoading: Bool = false
    var errorMessage: String?

    init(
        date: Date = Date(),
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        eventRepository: EventRepositoryProtocol = FirestoreEventRepository(),
        workShiftRepository: WorkShiftRepositoryProtocol = FirestoreWorkShiftRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository()
    ) {
        self.date = date
        self.authRepository = authRepository
        self.eventRepository = eventRepository
        self.workShiftRepository = workShiftRepository
        self.tagRepository = tagRepository
    }

    func refresh() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                let start = date.startOfDay()
                let end = date.endOfDay()

                async let eventsTask = eventRepository.listActiveOverlapping(uid: uid, start: start, end: end)
                async let shiftsTask = workShiftRepository.listActiveOverlapping(uid: uid, start: start, end: end)
                async let tagsTask = tagRepository.listActive(uid: uid)

                self.events = try await eventsTask
                self.workShifts = try await shiftsTask
                self.tags = try await tagsTask
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deleteEvent(_ event: Event) {
        Task { @MainActor in
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                try await eventRepository.deactivate(uid: uid, eventId: event.id)
                self.errorMessage = nil
                refresh()
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
                refresh()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

