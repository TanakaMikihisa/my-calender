import Foundation
import FirebaseFirestore

protocol WorkShiftRepositoryProtocol: Sendable {
    func listActiveOverlapping(uid: String, start: Date, end: Date) async throws -> [WorkShift]
    func upsert(uid: String, shift: WorkShift) async throws
    func deactivate(uid: String, shiftId: WorkShiftID) async throws
}

actor FirestoreWorkShiftRepository: WorkShiftRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActiveOverlapping(uid: String, start: Date, end: Date) async throws -> [WorkShift] {
        let snapshot = try await db
            .collection(FirestorePaths.workShifts(uid: uid))
            .whereField("isActive", isEqualTo: true)
            .whereField("startAt", isLessThan: end)
            .order(by: "startAt")
            .getDocuments()

        return try snapshot.documents
            .compactMap { doc in try mapShift(doc: doc) }
            .filter { $0.endAt > start }
    }

    func upsert(uid: String, shift: WorkShift) async throws {
        let ref = await db.collection(FirestorePaths.workShifts(uid: uid)).document(shift.id)
        var data = await shift.toFirestoreData()
        let snapshot = try await ref.getDocument()
        if snapshot.exists {
            data.removeValue(forKey: "createdAt")
        }
        try await ref.setData(data, merge: true)
    }

    func deactivate(uid: String, shiftId: WorkShiftID) async throws {
        let ref = await db.collection(FirestorePaths.workShifts(uid: uid)).document(shiftId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    private func mapShift(doc: QueryDocumentSnapshot) throws -> WorkShift {
        let data = doc.data()
        let payTypeRaw = (data["payType"] as? String) ?? "hourly"
        let payType = WorkPayType(rawValue: payTypeRaw) ?? .hourly

        return WorkShift(
            id: doc.documentID,
            startAt: try FirestoreMappers.date(data["startAt"], key: "startAt"),
            endAt: try FirestoreMappers.date(data["endAt"], key: "endAt"),
            payType: payType,
            payRateId: data["payRateId"] as? String,
            fixedPay: try FirestoreMappers.decimal(data["fixedPay"], key: "fixedPay"),
            templateId: data["templateId"] as? String,
            tagIds: try FirestoreMappers.stringArray(data["tagIds"], key: "tagIds"),
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? Date.distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? Date.distantPast
        )
    }
}

private extension WorkShift {
    func toFirestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "startAt": Timestamp(date: startAt),
            "endAt": Timestamp(date: endAt),
            "payType": payType.rawValue,
            "tagIds": tagIds,
            "isActive": isActive,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp(),
        ]

        if let payRateId { dict["payRateId"] = payRateId }
        if let templateId { dict["templateId"] = templateId }
        if let fixedPay { dict["fixedPay"] = (fixedPay as NSDecimalNumber) }

        return dict
    }
}

