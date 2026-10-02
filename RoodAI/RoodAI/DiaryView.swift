import SwiftData
import SwiftUI

struct DiaryView: View {
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var showGoals = false

    var body: some View {
        NavigationStack {
            DiaryWeekContent(weekStart: Calendar.current.startOfWeek(for: selectedDay),
                             selectedDay: $selectedDay)
                .navigationTitle("Diary")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if !Calendar.current.isDateInToday(selectedDay) {
                            Button("Today") {
                                selectedDay = Calendar.current.startOfDay(for: .now)
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showGoals = true } label: {
                            Label("Goals", systemImage: "target")
                        }
                    }
                }
                .sheet(isPresented: $showGoals) { GoalsView() }
        }
    }
}

/// Everything for one week. Split out so the SwiftData query can depend on the week shown.
private struct DiaryWeekContent: View {
    @Environment(GoalStore.self) private var goals
    @Environment(\.modelContext) private var context
    @Query private var entries: [DiaryEntry]
    @Binding var selectedDay: Date
    let weekStart: Date

    init(weekStart: Date, selectedDay: Binding<Date>) {
        let start = weekStart
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        _entries = Query(filter: #Predicate<DiaryEntry> { $0.date >= start && $0.date < end },
                         sort: \.date)
        _selectedDay = selectedDay
        self.weekStart = weekStart
    }

    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var entriesByDay: [Date: [DiaryEntry]] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
    }

    var body: some View {
        let byDay = entriesByDay
        let dayEntries = byDay[selectedDay] ?? []
        let dayTotals = dayEntries.totals

        List {
            Section {
                WeekStrip(days: days, selectedDay: $selectedDay, totalsByDay: byDay.mapValues(\.totals))
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
            }

            Section {
                DayGoalsSummary(totals: dayTotals, day: selectedDay, hasEntries: !dayEntries.isEmpty)
            } header: {
                Text(selectedDay.dayTitle)
            }

            if dayEntries.isEmpty {
                Section {
                    Text("Nothing logged yet. Snap a meal and tap \u{201C}Add to diary\u{201D}.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(MealType.allCases) { type in
                    let meals = dayEntries.filter { $0.mealType == type }
                    if !meals.isEmpty {
                        Section {
                            ForEach(meals) { entry in
                                NavigationLink {
                                    EntryDetailView(entry: entry)
                                } label: {
                                    EntryRow(entry: entry)
                                }
                            }
                            .onDelete { offsets in
                                for i in offsets { context.delete(meals[i]) }
                            }
                        } header: {
                            HStack {
                                Text(type.title)
                                Spacer()
                                Text(Nutrient.calories.format(meals.totals.calories))
                            }
                        }
                    }
                }
            }

            Section("This week") {
                WeekSummary(days: days, totalsByDay: byDay.mapValues(\.totals))
            }
        }
    }
}

// MARK: - Week strip

private struct WeekStrip: View {
    let days: [Date]
    @Binding var selectedDay: Date
    let totalsByDay: [Date: MacroTotals]

    var body: some View {
        HStack(spacing: 2) {
            Button { shiftWeek(by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 24, height: 44)
            }
            ForEach(days, id: \.self) { day in
                DayCell(day: day,
                        totals: totalsByDay[day],
                        isSelected: day == selectedDay)
                    .onTapGesture { selectedDay = day }
            }
            Button { shiftWeek(by: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 24, height: 44)
            }
        }
        .buttonStyle(.borderless)
    }

    private func shiftWeek(by weeks: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: 7 * weeks, to: selectedDay) {
            selectedDay = d
        }
    }
}

private struct DayCell: View {
    @Environment(GoalStore.self) private var goals
    let day: Date
    let totals: MacroTotals?
    let isSelected: Bool

    var body: some View {
        let goal = goals.goal(for: .calories)
        let progress = min((totals?.calories ?? 0) / max(goal, 1), 1)
        let allHit = totals.map { goals.goalsHit(in: $0) == Nutrient.allCases.count } ?? false

        VStack(spacing: 4) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(allHit ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if allHit {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                } else {
                    Text(day.formatted(.dateTime.day()))
                        .font(.caption.weight(isSelected ? .bold : .regular))
                }
            }
            .frame(width: 32, height: 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear,
                    in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if Calendar.current.isDateInToday(day) {
                Circle().fill(Color.accentColor).frame(width: 4, height: 4).offset(y: -1)
            }
        }
    }
}

// MARK: - Day summary

private struct DayGoalsSummary: View {
    @Environment(GoalStore.self) private var goals
    let totals: MacroTotals
    let day: Date
    let hasEntries: Bool

    private var isPast: Bool {
        day < Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        let hit = goals.goalsHit(in: totals)
        let total = Nutrient.allCases.count

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(totals.calories.rounded()))")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                Text("/ \(Int(goals.goal(for: .calories))) kcal")
                    .foregroundStyle(.secondary)
                Spacer()
                if hasEntries {
                    Label("\(hit)/\(total) goals", systemImage: hit == total ? "checkmark.seal.fill" : "target")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(hit == total ? .green : .secondary)
                }
            }

            ForEach(Nutrient.allCases) { nutrient in
                NutrientProgressRow(nutrient: nutrient,
                                    value: nutrient.value(in: totals),
                                    goal: goals.goal(for: nutrient),
                                    isPast: isPast)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NutrientProgressRow: View {
    let nutrient: Nutrient
    let value: Double
    let goal: Double
    let isPast: Bool

    var body: some View {
        let status = nutrient.status(value: value, goal: goal)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(nutrient.title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(nutrient.format(value)) / \(nutrient.format(goal))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: min(value / max(goal, 1), 1))
                .tint(status == .over ? .red : nutrient.color)
            statusLabel(status)
                .font(.caption2.weight(.semibold))
        }
    }

    @ViewBuilder
    private func statusLabel(_ status: GoalStatus) -> some View {
        switch status {
        case .met:
            Label("Goal hit", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .over:
            Label("\(nutrient.format(value - goal)) over", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        case .under:
            // For a "within 10%" target you only need to reach 90% of the goal.
            let needed = nutrient.kind == .target ? goal * (1 - GoalKind.targetTolerance) : goal
            let remaining = nutrient.format(max(needed - value, 0))
            if isPast {
                Label("Missed by \(remaining)", systemImage: "xmark.circle.fill").foregroundStyle(.orange)
            } else {
                Text("\(remaining) to go").foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Week summary

private struct WeekSummary: View {
    @Environment(GoalStore.self) private var goals
    let days: [Date]
    let totalsByDay: [Date: MacroTotals]

    var body: some View {
        let logged = days.compactMap { totalsByDay[$0] }

        if logged.isEmpty {
            Text("No meals logged this week.")
                .foregroundStyle(.secondary)
        } else {
            let perfectDays = logged.filter { goals.goalsHit(in: $0) == Nutrient.allCases.count }.count
            HStack {
                StatBlock(value: "\(logged.count)/7", label: "days logged")
                StatBlock(value: "\(perfectDays)", label: "all goals hit")
            }
            ForEach(Nutrient.allCases) { nutrient in
                let average = logged.map { nutrient.value(in: $0) }.reduce(0, +) / Double(logged.count)
                let hitDays = logged.filter { goals.status(of: nutrient, in: $0) == .met }.count
                HStack {
                    Circle().fill(nutrient.color).frame(width: 8, height: 8)
                    Text(nutrient.title)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Hit \(hitDays) of \(logged.count) days")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(hitDays == logged.count ? .green : .primary)
                        Text("avg \(nutrient.format(average))/day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Entries

private struct EntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumb = entry.thumbnail {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.1))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.mealName).font(.body.weight(.medium)).lineLimit(1)
                HStack(spacing: 8) {
                    Text("P \(entry.proteinG.rounded1)g").foregroundStyle(Color.protein)
                    Text("C \(entry.carbsG.rounded1)g").foregroundStyle(Color.carbs)
                    Text("F \(entry.fatG.rounded1)g").foregroundStyle(Color.fat)
                }
                .font(.caption.weight(.semibold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(entry.calories.rounded()))").font(.headline).monospacedDigit()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: DiaryEntry

    var body: some View {
        Form {
            if let thumb = entry.thumbnail {
                Section {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                }
            }

            Section {
                Picker("Meal", selection: $entry.mealType) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
                DatePicker("When", selection: $entry.date)
            }

            Section {
                if let analysis = entry.analysis {
                    MealResultView(analysis: analysis)
                        .padding(.vertical, 8)
                } else {
                    Text(entry.mealName)
                }
            }

            Section {
                Button("Delete entry", role: .destructive) {
                    context.delete(entry)
                    dismiss()
                }
            }
        }
        .navigationTitle(entry.mealName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helpers

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
    }
}

extension Date {
    var dayTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        return formatted(.dateTime.weekday(.wide).month().day())
    }
}
