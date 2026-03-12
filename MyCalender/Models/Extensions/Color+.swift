import SwiftUI

extension Color {
    /// "#RRGGBB" または "RRGGBB" から Color を生成。無効な場合はグレーを返す。
    static func from(hex: String) -> Color {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = UInt64(str, radix: 16) else {
            return Color(.systemGray)
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
