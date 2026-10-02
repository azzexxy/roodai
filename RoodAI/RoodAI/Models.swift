import Foundation

/// Nutrition estimate for a single food item visible in the photo.
struct FoodItem: Codable, Identifiable, Hashable {
    var id = UUID()
    let name: String
    let portion: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let sugarG: Double

    enum CodingKeys: String, CodingKey {
        case name, portion, calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
    }
}

/// The full analysis Claude returns for one photo.
struct MealAnalysis: Codable, Hashable {
    let isFood: Bool
    let mealName: String
    let items: [FoodItem]
    let confidence: Confidence
    let notes: String

    enum Confidence: String, Codable {
        case low, medium, high
    }

    enum CodingKeys: String, CodingKey {
        case isFood = "is_food"
        case mealName = "meal_name"
        case items, confidence, notes
    }

    var totals: MacroTotals {
        items.reduce(into: MacroTotals()) { t, item in
            t.calories += item.calories
            t.proteinG += item.proteinG
            t.carbsG += item.carbsG
            t.fatG += item.fatG
            t.fiberG += item.fiberG
            t.sugarG += item.sugarG
        }
    }
}

struct MacroTotals: Hashable {
    var calories = 0.0
    var proteinG = 0.0
    var carbsG = 0.0
    var fatG = 0.0
    var fiberG = 0.0
    var sugarG = 0.0

    /// Share of calories from each macro (4/4/9 kcal per gram).
    var calorieSplit: (protein: Double, carbs: Double, fat: Double) {
        let p = proteinG * 4, c = carbsG * 4, f = fatG * 9
        let sum = p + c + f
        guard sum > 0 else { return (0, 0, 0) }
        return (p / sum, c / sum, f / sum)
    }
}
