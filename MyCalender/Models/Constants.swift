import Foundation

// MARK: - メイン画面の表示モード（AppStorage キーとデフォルト）

enum Constants {
    /// 右下メニューで最後に選んだ表示（`MainToolbarDisplayOption` の rawValue と一致）
    static let appStorageLastMainDisplayMode = "lastMainDisplayMode"

    /// 毎日0:00の予定通知（デフォルト ON）
    static let appStorageDailyScheduleNotificationEnabled = "dailyScheduleNotificationEnabled"

    /// タグなし時のボックス色（システム色を使うための sentinel）
    static let defaultBoxColorSentinel = "systemGray6"

    /// タグで選べるプリセット色（hex）
    static let tagPresetColors: [String] = [
        "#EF4444", "#F97316", "#EAB308", "#22C55E",
        "#14B8A6", "#3B82F6", "#8B5CF6", "#EC4899",
        "#64748B", "#84CC16", "#06B6D4", "#F43F5E"
    ]
}
