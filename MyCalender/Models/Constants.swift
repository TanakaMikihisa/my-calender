import Foundation

// MARK: - メイン画面の表示モード・時間軸単位（AppStorage キーとデフォルト）

enum Constants {
    /// true = 時間軸, false = リスト
    static let appStorageIsTimeAxisMode = "isTimeAxisMode"
    /// true = 1時間単位, false = 30分単位（時間軸表示時のみ有効）
    static let appStorageIsOneHourUnit = "isOneHourUnit"

    /// タグなし時のボックス色（システム色を使うための sentinel）
    static let defaultBoxColorSentinel = "systemGray6"

    /// タグで選べるプリセット色（hex）
    static let tagPresetColors: [String] = [
        "#EF4444", "#F97316", "#EAB308", "#22C55E",
        "#14B8A6", "#3B82F6", "#8B5CF6", "#EC4899",
        "#64748B", "#84CC16", "#06B6D4", "#F43F5E",
    ]
}
