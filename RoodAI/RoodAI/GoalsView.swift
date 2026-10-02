import SwiftUI

struct GoalsView: View {
    @Environment(GoalStore.self) private var goals
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Nutrient.allCases) { nutrient in
                        HStack {
                            Circle().fill(nutrient.color).frame(width: 10, height: 10)
                            Text(nutrient.title)
                            Spacer()
                            TextField("Goal", value: binding(for: nutrient), format: .number.precision(.fractionLength(0)))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text(nutrient.unit)
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .leading)
                        }
                    }
                } header: {
                    Text("Daily goals")
                } footer: {
                    Text("Protein and fiber count as hit once you reach them. Sugar counts as hit if you stay under it. Calories, carbs and fat count as hit within 10% of the goal.")
                }

                Section {
                    Button("Reset to defaults", role: .destructive) { goals.resetToDefaults() }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func binding(for nutrient: Nutrient) -> Binding<Double> {
        Binding(
            get: { goals.goal(for: nutrient) },
            set: { if $0 > 0 { goals.set($0, for: nutrient) } }
        )
    }
}
