import Foundation
import FirebaseFirestore

enum FirestoreMappingError: LocalizedError {
    case missingField(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let key):
            return "Firestoreのフィールドが不足しています: \(key)"
        case .invalidField(let key):
            return "Firestoreのフィールド型が不正です: \(key)"
        }
    }
}

enum FirestoreMappers {
    /// Timestamp を dateValue() ではなく seconds/nanoseconds から Date を構築し、MainActor 隔離を避ける。
    static nonisolated func date(_ value: Any?, key: String) throws -> Date {
        if let ts = value as? Timestamp {
            let interval = TimeInterval(ts.seconds) + Double(ts.nanoseconds) / 1_000_000_000
            return Date(timeIntervalSince1970: interval)
        }
        if let date = value as? Date { return date }
        throw FirestoreMappingError.invalidField(key)
    }

    static nonisolated func string(_ value: Any?, key: String) throws -> String {
        guard let s = value as? String else { throw FirestoreMappingError.invalidField(key) }
        return s
    }

    static nonisolated func bool(_ value: Any?, key: String) throws -> Bool {
        guard let b = value as? Bool else { throw FirestoreMappingError.invalidField(key) }
        return b
    }

    static nonisolated func stringArray(_ value: Any?, key: String) throws -> [String] {
        if value == nil { return [] }
        guard let arr = value as? [String] else { throw FirestoreMappingError.invalidField(key) }
        return arr
    }

    static nonisolated func decimal(_ value: Any?, key: String) throws -> Decimal? {
        guard let value else { return nil }
        if let n = value as? NSNumber { return n.decimalValue }
        if let d = value as? Double { return Decimal(d) }
        if let i = value as? Int { return Decimal(i) }
        throw FirestoreMappingError.invalidField(key)
    }
}

