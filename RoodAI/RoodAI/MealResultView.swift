import SwiftUI

extension Color {
    static let protein = Color.red
    static let carbs = Color.orange
    static let fat = Color.blue
}

struct MealResultView: View {
    let analysis: MealAnalysis

    var body: some View {
        let totals = analysis.totals

        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(analysis.mealName)
                    .font(.title2.bold())
                Spacer()
                ConfidenceBadge(confidence: analysis.confidence)
            }

            HStack(spacing: 20) {
                MacroRing(totals: totals)
                    .frame(width: 130, height: 130)
                VStack(alignment: .leading, spacing: 10) {
                    MacroRow(name: "Protein", grams: totals.proteinG, color: .protein)
                    MacroRow(name: "Carbs", grams: totals.carbsG, color: .carbs)
                    MacroRow(name: "Fat", grams: totals.fatG, color: .fat)
                }
            }

            HStack {
                StatPill(label: "Fiber", value: "\(totals.fiberG.rounded1) g")
                StatPill(label: "Sugar", value: "\(totals.sugarG.rounded1) g")
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Breakdown")
                    .font(.headline)
                    .padding(.bottom, 8)
                ForEach(analysis.items) { item in
                    FoodItemRow(item: item)
                    if item.id != analysis.items.last?.id { Divider() }
                }
            }

            if !analysis.notes.isEmpty {
                Text(analysis.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("AI estimates from a photo. Actual values can vary.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct MacroRing: View {
    let totals: MacroTotals

    var body: some View {
        let split = totals.calorieSplit
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 14)
            arc(from: 0, to: split.protein, color: .protein)
            arc(from: split.protein, to: split.protein + split.carbs, color: .carbs)
            arc(from: split.protein + split.carbs, to: 1, color: .fat)
                .opacity(split.fat > 0 ? 1 : 0)
            VStack(spacing: 0) {
                Text("\(Int(totals.calories.rounded()))")
                    .font(.title.bold())
                    .monospacedDigit()
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func arc(from start: Double, to end: Double, color: Color) -> some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }
}

private struct MacroRow: View {
    let name: String
    let grams: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text("\(grams.rounded1) g")
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FoodItemRow: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name).font(.body.weight(.medium))
                Spacer()
                Text("\(Int(item.calories.rounded())) kcal")
                    .monospacedDigit()
            }
            Text(item.portion)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text("P \(item.proteinG.rounded1)g").foregroundStyle(Color.protein)
                Text("C \(item.carbsG.rounded1)g").foregroundStyle(Color.carbs)
                Text("F \(item.fatG.rounded1)g").foregroundStyle(Color.fat)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
        .padding(.vertical, 10)
    }
}

private struct ConfidenceBadge: View {
    let confidence: MealAnalysis.Confidence

    var body: some View {
        let color: Color = switch confidence {
        case .high: .green
        case .medium: .yellow
        case .low: .orange
        }
        Text("\(confidence.rawValue.capitalized) confidence")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
    }
}

extension Double {
    /// One decimal place, dropping a trailing ".0".
    var rounded1: String {
        let r = (self * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }
}

#Preview {
    ScrollView {
        MealResultView(analysis: MealAnalysis(
            isFood: true,
            mealName: "Grilled chicken bowl",
            items: [
                FoodItem(name: "Grilled chicken breast", portion: "~150 g", calories: 248, proteinG: 46.5, carbsG: 0, fatG: 5.4, fiberG: 0, sugarG: 0),
                FoodItem(name: "White rice", portion: "1 cup cooked", calories: 205, proteinG: 4.3, carbsG: 44.5, fatG: 0.4, fiberG: 0.6, sugarG: 0.1),
                FoodItem(name: "Avocado", portion: "1/2 medium", calories: 120, proteinG: 1.5, carbsG: 6.4, fatG: 11, fiberG: 5, sugarG: 0.3),
            ],
            confidence: .medium,
            notes: "Assumed chicken was grilled with minimal oil."
        ))
        .padding()
    }
}
