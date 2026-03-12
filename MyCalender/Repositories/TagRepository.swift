import Foundation
import FirebaseFirestore

protocol TagRepositoryProtocol: Sendable {
    func listActive(uid: String) async throws -> [Tag]
    func add(uid: String, tag: Tag) async throws
    func update(uid: String, tag: Tag) async throws
    func deactivate(uid: String, tagId: TagID) async throws
}

actor FirestoreTagRepository: TagRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActive(uid: String) async throws -> [Tag] {
        let snapshot = try await db
            .collection(FirestorePaths.tags(uid: uid))
            .whereField("isActive", isEqualTo: true)
            .order(by: "name")
            .getDocuments()
        return try snapshot.documents.map { try mapTag(doc: $0) }
    }

    func add(uid: String, tag: Tag) async throws {
        let ref = await db.collection(FirestorePaths.tags(uid: uid)).document(tag.id)
        try await ref.setData(tag.toFirestoreData())
    }

    func update(uid: String, tag: Tag) async throws {
        let ref = await db.collection(FirestorePaths.tags(uid: uid)).document(tag.id)
        var data = await tag.toFirestoreData()
        data.removeValue(forKey: "createdAt")
        try await ref.setData(data, merge: true)
    }

    func deactivate(uid: String, tagId: TagID) async throws {
        let ref = await db.collection(FirestorePaths.tags(uid: uid)).document(tagId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    private func mapTag(doc: QueryDocumentSnapshot) throws -> Tag {
        let data = doc.data()
        return Tag(
            id: doc.documentID,
            name: try FirestoreMappers.string(data["name"], key: "name"),
            colorHex: (data["color"] as? String) ?? "#8E8E93",
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? .distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? .distantPast
        )
    }
}

private extension Tag {
    func toFirestoreData() -> [String: Any] {
        [
            "name": name,
            "color": colorHex,
            "isActive": isActive,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
    }
}
