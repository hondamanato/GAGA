import SwiftUI

struct CalendarRangePickerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tempStart: Date?
    @State private var tempEnd: Date?

    private let initialStart: Date?
    private let initialEnd: Date?
    private let onSave: (Date?, Date?) -> Void

    private let calendar = Calendar.current
    private let today = Calendar.current.startOfDay(for: .now)
    private let pastMonthCount = 6
    private let futureMonthCount = 12
    private let weekdays = Calendar.current.veryShortWeekdaySymbols

    init(startDate: Date?, endDate: Date?, onSave: @escaping (Date?, Date?) -> Void) {
        self.initialStart = startDate
        self.initialEnd = endDate
        self.onSave = onSave
        _tempStart = State(initialValue: startDate)
        _tempEnd = State(initialValue: endDate)
    }

    private var months: [Date] {
        (-pastMonthCount..<futureMonthCount).compactMap {
            calendar.date(byAdding: .month, value: $0, to: firstOfCurrentMonth)
        }
    }

    private var firstOfCurrentMonth: Date {
        let comps = calendar.dateComponents([.year, .month], from: today)
        return calendar.date(from: comps) ?? today
    }

    /// スクロール先の月ID
    private var scrollTargetId: Date {
        if let s = tempStart {
            let comps = calendar.dateComponents([.year, .month], from: s)
            return calendar.date(from: comps) ?? firstOfCurrentMonth
        }
        return firstOfCurrentMonth
    }

    private var nightsCount: Int? {
        guard let s = tempStart, let e = tempEnd else { return nil }
        return calendar.dateComponents([.day], from: s, to: e).day
    }

    private var canSave: Bool {
        tempStart != nil && tempEnd != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date header
                dateHeader
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()

                // Weekday headers
                weekdayHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Divider()
                    .padding(.top, 4)

                // Calendar grid
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(months, id: \.self) { month in
                                monthView(for: month)
                                    .id(month)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        proxy.scrollTo(scrollTargetId, anchor: .top)
                    }
                }

                Divider()

                // Footer
                footer
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("日程を選択")
                        .font(GAGATheme.headlineFont)
                }
            }
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("出発日")
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.secondary)
                Text(tempStart.map { formatDate($0) } ?? "—")
                    .font(GAGATheme.headlineFont)
            }
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("帰国日")
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.secondary)
                Text(tempEnd.map { formatDate($0) } ?? "—")
                    .font(GAGATheme.headlineFont)
            }
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month View

    private func monthView(for month: Date) -> some View {
        let comps = calendar.dateComponents([.year, .month], from: month)
        let year = comps.year ?? calendar.component(.year, from: month)
        let monthNum = comps.month ?? calendar.component(.month, from: month)
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: month)

        return VStack(alignment: .leading, spacing: 8) {
            Text(monthLabel(year: year, month: monthNum))
                .font(GAGATheme.headlineFont)
                .padding(.bottom, 4)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    if let date = calendar.date(from: DateComponents(year: year, month: monthNum, day: day)) {
                        dayCellView(date: date, day: day)
                    }
                }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCellView(date: Date, day: Int) -> some View {
        let state = dayState(for: date)

        return Button {
            handleTap(date)
        } label: {
            Text("\(day)")
                .font(.system(size: 16, weight: state == .normal ? .regular : .bold))
                .foregroundStyle(dayForeground(state: state))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(dayBackground(state: state))
        }
    }

    // MARK: - Day State

    private enum DayState {
        case normal, start, end, inRange
    }

    private func dayState(for date: Date) -> DayState {
        let d = calendar.startOfDay(for: date)
        if let s = tempStart, calendar.isDate(d, inSameDayAs: s) { return .start }
        if let e = tempEnd, calendar.isDate(d, inSameDayAs: e) { return .end }
        if let s = tempStart, let e = tempEnd, d > s && d < e { return .inRange }
        return .normal
    }

    private func dayForeground(state: DayState) -> Color {
        switch state {
        case .start, .end: return .white
        case .inRange, .normal: return .primary
        }
    }

    @ViewBuilder
    private func dayBackground(state: DayState) -> some View {
        switch state {
        case .start, .end:
            Circle()
                .fill(GAGATheme.deepNavy)
        case .inRange:
            Rectangle()
                .fill(GAGATheme.deepNavy.opacity(0.08))
        case .normal:
            Color.clear
        }
    }

    // MARK: - Tap Logic

    private func handleTap(_ date: Date) {
        let d = calendar.startOfDay(for: date)

        if tempStart == nil {
            tempStart = d
            tempEnd = nil
        } else if tempEnd == nil {
            if let s = tempStart, d > s {
                tempEnd = d
            } else {
                tempStart = d
                tempEnd = nil
            }
        } else {
            tempStart = d
            tempEnd = nil
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            HStack {
                Button("日付をクリア") {
                    tempStart = nil
                    tempEnd = nil
                }
                .font(GAGATheme.bodyFont)
                .fontWeight(.semibold)
                .foregroundStyle(tempStart != nil ? .primary : .secondary)
                .disabled(tempStart == nil)

                Spacer()

                if let n = nightsCount {
                    Text("\(n)泊")
                        .font(GAGATheme.bodyFont)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onSave(tempStart, tempEnd)
                dismiss()
            } label: {
                Text("保存")
                    .font(GAGATheme.headlineFont)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        if canSave {
                            GAGATheme.accentGradient
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .foregroundStyle(canSave ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: GAGATheme.buttonRadius))
            }
            .disabled(!canSave)
        }
    }

    // MARK: - Formatting

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: date)
    }

    private func monthLabel(year: Int, month: Int) -> String {
        let components = DateComponents(year: year, month: month)
        guard let date = Calendar.current.date(from: components) else { return "" }
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return f.string(from: date)
    }
}
