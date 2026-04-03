import SwiftUI

/// 空欄セルタップ時のポップオーバー用アンカー
private struct PopoverAnchor: Identifiable {
    let day: Date
    let columnId: String
    let columnTitle: String
    var id: String { "\(day.timeIntervalSince1970)-\(columnId)" }
}

/// 新規作成シート用コンテキスト（会社・日付を渡す）
private struct NewEntrySheetContext: Identifiable {
    let day: Date
    let companyId: String
    var id: String { "\(day.timeIntervalSince1970)-\(companyId)" }
}

/// 月次・勤務のみの時間軸風グリッド。1行=1日、列=会社、右端=日合計。先頭行=月合計。
struct MonthlyWorkShiftGridView: View {
    @Bindable var viewModel: MonthlyWorkShiftViewModel
    @Binding var selectedMonth: Date
    var onSelectWorkShift: ((WorkShift) -> Void)?

    @State private var popoverAnchor: PopoverAnchor?
    @State private var newEntrySheetContext: NewEntrySheetContext?

    // 勤務表グリッドの固定サイズ（横スクロール内の列幅・行の高さ）
    private let dateColumnWidth: CGFloat = 50 // 左端：日付ラベル・日番号・「月合計」
    private let columnWidth: CGFloat = 250 // 会社（列）ごとのシフト表示領域
    private let totalColumnWidth: CGFloat = 200 // 右端：日別合計・月合計の金額列
    private let rowHeight: CGFloat = 44 // 1日あたりのデータ行
    private let headerRowHeight: CGFloat = 40 // 先頭のヘッダー行と末尾の月合計行

    var body: some View {
        Group {
            if !viewModel.isLoading, viewModel.companyColumns.isEmpty {
                ContentUnavailableView(
                    "会社が登録されていません",
                    systemImage: "building.2",
                    description: Text("")
                )
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow
                        ForEach(viewModel.daysInMonth, id: \.self) { day in
                            dayRow(day: day)
                        }
                        footerRow
                    }
                    .padding(0)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .refreshable { await viewModel.refreshAsync() }
        .onAppear {
            viewModel.month = selectedMonth
            viewModel.refresh()
        }
        .onChange(of: selectedMonth) { _, new in
            viewModel.month = new
            viewModel.refresh()
        }
        .sheet(item: $popoverAnchor, onDismiss: { popoverAnchor = nil }) { anchor in
            EmptyCellShiftPopoverView(
                viewModel: viewModel,
                companyId: anchor.columnId,
                companyTitle: anchor.columnTitle,
                date: anchor.day,
                onDismiss: { popoverAnchor = nil },
                onRequestNewEntry: {
                    popoverAnchor = nil
                    newEntrySheetContext = NewEntrySheetContext(day: anchor.day, companyId: anchor.columnId)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $newEntrySheetContext, onDismiss: { newEntrySheetContext = nil }) { ctx in
            CreateItemSheet(
                initialDate: ctx.day,
                initialPayRateId: ctx.companyId == "fixed" ? nil : ctx.companyId,
                onSaved: {
                    viewModel.refresh()
                    newEntrySheetContext = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - ヘッダー行（会社名 | 合計）

    private var headerRow: some View {
        HStack(spacing: 0) {
            cell(content: Text("日付").fontWeight(.medium), width: dateColumnWidth, isHeader: true)
                .overlay(alignment: .trailing) { verticalDivider }
            ForEach(viewModel.companyColumns) { col in
                cell(content: Text(col.title).fontWeight(.medium).lineLimit(1), width: columnWidth, isHeader: true)
                    .overlay(alignment: .trailing) { verticalDivider }
            }
            cell(
                content: Text("合計").fontWeight(.medium).multilineTextAlignment(.center),
                width: totalColumnWidth,
                isHeader: true,
                alignment: .center
            )
        }
        .frame(height: headerRowHeight)
        .background(Color(.systemGray6))
        .overlay(alignment: .bottom) { horizontalDivider }
    }

    // MARK: - 日付行

    private func dayRow(day: Date) -> some View {
        let dayTotal = viewModel.dayTotal(on: day)
        let dayNum = Calendar.current.component(.day, from: day)
        return HStack(spacing: 0) {
            cell(
                content: Text("\(dayNum)")
                    .foregroundStyle(.secondary),
                width: dateColumnWidth,
                isHeader: false
            )
            .overlay(alignment: .trailing) { verticalDivider }

            ForEach(viewModel.companyColumns) { col in
                companyCell(day: day, column: col)
                    .overlay(alignment: .trailing) { verticalDivider }
            }

            cell(
                content: Text(formatMoney(dayTotal)),
                width: totalColumnWidth,
                isHeader: false
            )
        }
        .frame(height: rowHeight)
        .overlay(alignment: .bottom) { horizontalDivider }
    }

    private func companyCell(day: Date, column: MonthlyWorkShiftColumn) -> some View {
        let shifts = viewModel.shifts(on: day, columnId: column.id)
        let label = shifts.isEmpty ? "" : shifts.map { viewModel.shiftDisplayName(for: $0) }.joined(separator: " / ")
        return cell(
            content: Group {
                if shifts.isEmpty {
                    Button {
                        FeedBack().feedback(.medium)
                        popoverAnchor = PopoverAnchor(day: day, columnId: column.id, columnTitle: column.title)
                    } label: {
                        Text("")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        FeedBack().feedback(.medium)
                        if let first = shifts.first {
                            onSelectWorkShift?(first)
                        }
                    } label: {
                        Text(label)
                            .font(.subheadline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        ForEach(shifts) { shift in
                            Button("シフトを削除", role: .destructive) {
                                FeedBack().feedback(.heavy)
                                viewModel.deleteWorkShift(shift)
                            }
                        }
                    }
                }
            },
            width: columnWidth,
            isHeader: false
        )
    }

    // MARK: - フッター行（月合計）

    private var footerRow: some View {
        HStack(spacing: 0) {
            cell(content: Text("月合計").fontWeight(.semibold), width: dateColumnWidth, isHeader: true)
                .overlay(alignment: .trailing) { verticalDivider }
            ForEach(viewModel.companyColumns) { col in
                let total = viewModel.columnMonthTotal(columnId: col.id)
                cell(content: Text(formatMoney(total)).fontWeight(.medium), width: columnWidth, isHeader: true)
                    .overlay(alignment: .trailing) { verticalDivider }
            }
            cell(
                content: Text(formatMoney(viewModel.grandTotal)).fontWeight(.semibold),
                width: totalColumnWidth,
                isHeader: true
            )
        }
        .frame(height: headerRowHeight)
        .background(Color(.systemGray5))
    }

    private func cell<Content: View>(
        content: Content,
        width: CGFloat,
        isHeader: Bool,
        alignment: Alignment = .leading
    ) -> some View {
        content
            .frame(width: width, height: isHeader ? headerRowHeight : rowHeight, alignment: alignment)
            .padding(.horizontal, 8)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1)
    }

    private var horizontalDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
    }

    private func formatMoney(_ value: Decimal) -> String {
        if value == 0 { return "" }
        return "¥\(NSDecimalNumber(decimal: value).stringValue)"
    }
}

#Preview {
    NavigationStack {
        MonthlyWorkShiftGridView(viewModel: MonthlyWorkShiftViewModel(month: Date()), selectedMonth: .constant(Date()))
    }
}
