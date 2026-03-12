import SwiftUI

struct DayView: View {
    /// true = 時間軸, false = リスト
    @AppStorage(Constants.appStorageIsTimeAxisMode) private var isTimeAxisMode = true
    /// true = 1時間単位, false = 30分単位
    @AppStorage(Constants.appStorageIsOneHourUnit) private var isOneHourUnit = true

    @State private var viewModel = DayViewModel()
    @State private var isPresentingCreateSheet = false
    @State private var showErrorAlert = false
    @State private var selectedDetailItem: ScheduleDetailItem?

    private var dayStart: Date { viewModel.date.startOfDay() }
    private var dayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $viewModel.date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .padding(.horizontal)
                .onChange(of: viewModel.date) { _, _ in
                    viewModel.refresh()
                }

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if isTimeAxisMode {
                        TimeAxisDayView(
                            dayStart: dayStart,
                            unitMinutes: isOneHourUnit ? 60 : 30,
                            events: viewModel.events,
                            workShifts: viewModel.workShifts,
                            tags: viewModel.tags,
                            onSelectEvent: { selectedDetailItem = .event($0) },
                            onSelectWorkShift: { selectedDetailItem = .workShift($0) },
                            onDeleteEvent: { viewModel.deleteEvent($0) },
                            onDeleteWorkShift: { viewModel.deleteWorkShift($0) }
                        )
                    } else {
                        ScheduleListView(
                            dayStart: dayStart,
                            dayEnd: dayEnd,
                            events: viewModel.events,
                            workShifts: viewModel.workShifts,
                            tags: viewModel.tags,
                            selectedDetailItem: $selectedDetailItem,
                            onDeleteEvent: { viewModel.deleteEvent($0) },
                            onDeleteWorkShift: { viewModel.deleteWorkShift($0) }
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.linear) {
                            isTimeAxisMode.toggle()
                        }
                    } label: {
                        Image(systemName: isTimeAxisMode ? "calendar" : "list.bullet")
                    }
                }
                if isTimeAxisMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                isOneHourUnit.toggle()
                            }
                        } label: {
                            Image(systemName: isOneHourUnit ? "plus.magnifyingglass" : "minus.magnifyingglass")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: ScheduleDetailItem.self) { item in
                ScheduleDetailView(item: item, tags: viewModel.tags, onRefresh: { viewModel.refresh() }, onDismiss: nil)
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                ScheduleDetailView(item: item, tags: viewModel.tags, onRefresh: { viewModel.refresh() }, onDismiss: { selectedDetailItem = nil })
            }
            .sheet(isPresented: $isPresentingCreateSheet) {
                CreateItemSheet(initialDate: viewModel.date, onSaved: { viewModel.refresh() })
            }
            .onChange(of: viewModel.errorMessage) { _, new in
                if new != nil { showErrorAlert = true }
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.refresh()
            }
        }
    }
}

#Preview {
    DayView()
}
