import SwiftUI

/// 1日の時間軸＋イベント/シフトをボックスで表示。単位(15/30/60/180分)と現在時刻の水辺線に対応。
struct TimeAxisDayView: View {
    var dayStart: Date
    var unitMinutes: Int
    var events: [Event]
    var workShifts: [WorkShift]
    var tags: [Tag]
    var onSelectEvent: ((Event) -> Void)?
    var onSelectWorkShift: ((WorkShift) -> Void)?
    var onDeleteEvent: ((Event) -> Void)?
    var onDeleteWorkShift: ((WorkShift) -> Void)?

    private var calendar: Calendar { .current }
    private var dayEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
    }
    private var blocksPerDay: Int { 24 * 60 / unitMinutes }
    /// 1ブロックあたりの縦幅（pt）。1時間単位のときは少し広くする。
    private var pointsPerBlock: CGFloat { unitMinutes == 60 ? 56 : 48 }
    private var timelineTotalHeight: CGFloat { CGFloat(blocksPerDay) * pointsPerBlock }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                timeRuler
                eventAndShiftBlocks
                currentTimeLine
            }
            .frame(height: timelineTotalHeight)
            .padding(.leading, 20)
        }
    }

    private var timeRuler: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                ForEach(0..<blocksPerDay, id: \.self) { index in
                    Text(timeLabel(blockIndex: index))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: pointsPerBlock, alignment: .topLeading)
                }
            }
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .frame(height: timelineTotalHeight)
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: timelineTotalHeight)
                .allowsHitTesting(false)
        }
    }

    private var eventAndShiftBlocks: some View {
        let eventBlocks = events.map { event in
            BlockInfo(
                id: event.id,
                start: clamp(event.startAt, min: dayStart, max: dayEnd),
                end: clamp(event.endAt, min: dayStart, max: dayEnd),
                title: event.title,
                note: event.note,
                colorHex: tagColorHex(for: event),
                event: event,
                workShift: nil,
                columnIndex: 0,
                totalColumns: 1
            )
        }
        let shiftBlocks = workShifts.map { shift in
            BlockInfo(
                id: shift.id,
                start: clamp(shift.startAt, min: dayStart, max: dayEnd),
                end: clamp(shift.endAt, min: dayStart, max: dayEnd),
                title: "勤務",
                note: nil,
                colorHex: "#F97316",
                event: nil,
                workShift: shift,
                columnIndex: 0,
                totalColumns: 1
            )
        }
        let raw = (eventBlocks + shiftBlocks).filter { $0.start < $0.end }
        let all = assignColumns(raw)
        return GeometryReader { geometry in
            let contentWidth = geometry.size.width
            ZStack(alignment: .topLeading) {
                ForEach(all) { block in
                    let y = offsetY(from: block.start)
                    let h = max(24, height(from: block.start, to: block.end))
                    let w = contentWidth / CGFloat(block.totalColumns)
                    let x = contentWidth * CGFloat(block.columnIndex) / CGFloat(block.totalColumns)
                    Button {
                        if let e = block.event { onSelectEvent?(e) }
                        else if let s = block.workShift { onSelectWorkShift?(s) }
                    } label: {
                        timelineBlockContent(block, height: h)
                    }
                    .buttonStyle(.plain)
                    .frame(width: w, height: h)
                    .contentShape(Rectangle())
                    .offset(x: x, y: y)
                    .contextMenu {
                        if let e = block.event {
                            Button("詳細を開く") { onSelectEvent?(e) }
                            Button("削除", role: .destructive) { onDeleteEvent?(e) }
                        } else if let s = block.workShift {
                            Button("詳細を開く") { onSelectWorkShift?(s) }
                            Button("削除", role: .destructive) { onDeleteWorkShift?(s) }
                        }
                    } preview: {
                        if let e = block.event {
                            ScheduleDetailView(item: .event(e), tags: tags, onRefresh: {}, onDismiss: nil)
                                .frame(width: 320, height: 400)
                        } else if let s = block.workShift {
                            ScheduleDetailView(item: .workShift(s), tags: tags, onRefresh: {}, onDismiss: nil)
                                .frame(width: 320, height: 400)
                        }
                    }
                }
            }
        }
        .padding(.leading, 52)
    }

    /// 重なっているブロックに列インデックスを割り当て（横並びで幅分割するため）
    private func assignColumns(_ blocks: [BlockInfo]) -> [BlockInfo] {
        let sorted = blocks.sorted { $0.start < $1.start }
        var columnEndTimes: [Date] = []
        var columnIndices: [Int] = []
        for block in sorted {
            var col = 0
            while col < columnEndTimes.count, block.start < columnEndTimes[col] {
                col += 1
            }
            if col >= columnEndTimes.count {
                columnEndTimes.append(block.end)
            } else {
                columnEndTimes[col] = block.end
            }
            columnIndices.append(col)
        }
        let totalCols = max(1, columnEndTimes.count)
        return sorted.enumerated().map { index, block in
            BlockInfo(
                id: block.id,
                start: block.start,
                end: block.end,
                title: block.title,
                note: block.note,
                colorHex: block.colorHex,
                event: block.event,
                workShift: block.workShift,
                columnIndex: columnIndices[index],
                totalColumns: totalCols
            )
        }
    }

    /// 現在時刻の水辺線（表示日が「今日」のときだけ表示し、1分ごとに位置を更新）
    private var currentTimeLine: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let now = context.date
            if now >= dayStart && now < dayEnd {
                let y = offsetY(from: now)
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .offset(y: y)
                    .padding(.leading, 52)
            }
        }
        .allowsHitTesting(false)
    }

    /// タイトルを表示する最小の高さ（これ未満は枠のみ）
    private let minHeightToShowTitle: CGFloat = 35
    /// タイトル＋メモを表示する最小の高さ（これ未満はタイトルのみ）
    private let minHeightToShowTitleAndMemo: CGFloat = 48

    private func timelineBlockContent(_ block: BlockInfo, height: CGFloat) -> some View {
        let showTitle = height >= minHeightToShowTitle
        let showMemo = height >= minHeightToShowTitleAndMemo

        return RoundedRectangle(cornerRadius: 6)
            .fill(blockFillColor(block.colorHex))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if showTitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundStyle(.black)
                        if showMemo, let note = block.note, !note.isEmpty {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.black.opacity(0.85))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(6)
                }
            }
            .padding(5)
    }

    /// 1分あたりの縦幅（ブロック単位でなく分単位で統一し、微妙な時刻でもずれないようにする）
    private var pointsPerMinute: CGFloat {
        pointsPerBlock / CGFloat(unitMinutes)
    }

    private func offsetY(from date: Date) -> CGFloat {
        let minutesFromStart = date.timeIntervalSince(dayStart) / 60
        return CGFloat(minutesFromStart) * pointsPerMinute
    }

    private func height(from start: Date, to end: Date) -> CGFloat {
        let durationMinutes = end.timeIntervalSince(start) / 60
        return CGFloat(durationMinutes) * pointsPerMinute
    }

    private func timeLabel(blockIndex: Int) -> String {
        let totalMinutes = blockIndex * unitMinutes
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if m == 0 { return "\(h):00" }
        return String(format: "%d:%02d", h, m)
    }

    private func tagColorHex(for event: Event) -> String {
        for id in event.tagIds {
            if let tag = tags.first(where: { $0.id == id }) {
                return tag.colorHex
            }
        }
        return Constants.defaultBoxColorSentinel
    }

    private func blockFillColor(_ colorHex: String) -> some ShapeStyle {
        if colorHex == Constants.defaultBoxColorSentinel {
            return AnyShapeStyle(Color(.systemGray5).opacity(0.5))
        }
        return AnyShapeStyle(Color.from(hex: colorHex).opacity(0.45))
    }

    private func clamp(_ date: Date, min lo: Date, max hi: Date) -> Date {
        if date < lo { return lo }
        if date > hi { return hi }
        return date
    }
}

private struct BlockInfo: Identifiable {
    let id: String
    let start: Date
    let end: Date
    let title: String
    let note: String?
    let colorHex: String
    let event: Event?
    let workShift: WorkShift?
    var columnIndex: Int
    var totalColumns: Int
}

// MARK: - Preview
#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let start1 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
    let end1 = cal.date(bySettingHour: 10, minute: 30, second: 0, of: today)!
    let start2 = cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)!
    let end2 = cal.date(bySettingHour: 17, minute: 0, second: 0, of: today)!
    let events = [
        Event(id: "pe1", type: .normal, title: "ミーティング", startAt: start1, endAt: end1, note: "会議メモ", tagIds: ["pt1"], isActive: true, createdAt: .distantPast, updatedAt: .distantPast),
        Event(id: "pe2", type: .normal, title: "作業", startAt: start2, endAt: end2, note: nil, tagIds: [], isActive: true, createdAt: .distantPast, updatedAt: .distantPast)
    ]
    let workShifts: [WorkShift] = []
    let tags = [Tag(id: "pt1", name: "仕事", colorHex: "#34C759", isActive: true, createdAt: .distantPast, updatedAt: .distantPast)]
    return TimeAxisDayView(dayStart: today, unitMinutes: 60, events: events, workShifts: workShifts, tags: tags, onSelectEvent: nil, onSelectWorkShift: nil, onDeleteEvent: nil, onDeleteWorkShift: nil)
}
