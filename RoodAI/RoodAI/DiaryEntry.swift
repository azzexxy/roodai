import Foundation
import SwiftData
import UIKit

enum MealType: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// Best guess based on the time of day.
    static func suggested(for date: Date) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: .breakfast
        case 11..<15: .lunch
        case 17..<22: .dinner
        default: .snack
        }
    }
}

/// One logged meal or snack, persisted with SwiftData.
@Model
final class DiaryEntry {
    var date: Date
    var mealTypeRaw: String
    var mealName: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var sugarG: Double
    /// The full analysis, so the per-item breakdown can be shown again later.
    var analysisData: Data?
    @Attribute(.externalStorage) var photo: Data?

    init(date: Date, mealType: MealType, analysis: MealAnalysis, image: UIImage?) {
        let totals = analysis.totals
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.mealName = analysis.mealName
        self.calories = totals.calories
        self.proteinG = totals.proteinG
        self.carbsG = totals.carbsG
        self.fatG = totals.fatG
        self.fiberG = totals.fiberG
        self.sugarG = totals.sugarG
        self.analysisData = try? JSONEncoder().encode(analysis)
        self.photo = image?.resized(maxDimension: 400).jpegData(compressionQuality: 0.7)
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var analysis: MealAnalysis? {
        analysisData.flatMap { try? JSONDecoder().decode(MealAnalysis.self, from: $0) }
    }

    var thumbnail: UIImage? {
        photo.flatMap(UIImage.init(data:))
    }

    var totals: MacroTotals {
        MacroTotals(calories: calories, proteinG: proteinG, carbsG: carbsG,
                    fatG: fatG, fiberG: fiberG, sugarG: sugarG)
    }
}

extension Sequence where Element == DiaryEntry {
    var totals: MacroTotals {
        reduce(into: MacroTotals()) { t, e in
            t.calories += e.calories
            t.proteinG += e.proteinG
            t.carbsG += e.carbsG
            t.fatG += e.fatG
            t.fiberG += e.fiberG
            t.sugarG += e.sugarG
        }
    }
}
