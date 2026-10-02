import Foundation
import Observation
import SwiftUI

enum Nutrient: String, CaseIterable, Identifiable {
    case calories, protein, carbs, fat, fiber, sugar

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var unit: String { self == .calories ? "kcal" : "g" }

    var color: Color {
        switch self {
        case .calories: .green
        case .protein: .protein
        case .carbs: .carbs
        case .fat: .fat
        case .fiber: .brown
        case .sugar: .pink
        }
    }

    /// How a day's total is judged against the goal.
    var kind: GoalKind {
        switch self {
        case .protein, .fiber: .atLeast
        case .sugar: .atMost
        case .calories, .carbs, .fat: .target
        }
    }

    var defaultGoal: Double {
        switch self {
        case .calories: 2000
        case .protein: 150
        case .carbs: 200
        case .fat: 65
        case .fiber: 30
        case .sugar: 50
        }
    }

    func value(in totals: MacroTotals) -> Double {
        switch self {
        case .calories: totals.calories
        case .protein: totals.proteinG
        case .carbs: totals.carbsG
        case .fat: totals.fatG
        case .fiber: totals.fiberG
        case .sugar: totals.sugarG
        }
    }

    func format(_ value: Double) -> String {
        self == .calories ? "\(Int(value.rounded())) kcal" : "\(value.rounded1) g"
    }
}

enum GoalKind {
    /// Reach at least the goal (protein, fiber).
    case atLeast
    /// Stay at or below the goal (sugar).
    case atMost
    /// Land within ±10% of the goal (calories, carbs, fat).
    case target

    static let targetTolerance = 0.10

    var explanation: String {
        switch self {
        case .atLeast: "Hit when you reach at least this much."
        case .atMost: "Hit when you stay at or under this."
        case .target: "Hit when you're within 10% of this."
        }
    }
}

enum GoalStatus {
    case met, under, over
}

extension Nutrient {
    func status(value: Double, goal: Double) -> GoalStatus {
        guard goal > 0 else { return .met }
        switch kind {
        case .atLeast:
            return value >= goal ? .met : .under
        case .atMost:
            return value <= goal ? .met : .over
        case .target:
            let t = GoalKind.targetTolerance
            if value < goal * (1 - t) { return .under }
            if value > goal * (1 + t) { return .over }
            return .met
        }
    }
}

/// Daily goals, persisted in UserDefaults.
@Observable
final class GoalStore {
    @ObservationIgnored private let defaults: UserDefaults
    private var goals: [Nutrient: Double] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for n in Nutrient.allCases {
            let stored = defaults.double(forKey: Self.key(n))
            goals[n] = stored > 0 ? stored : n.defaultGoal
        }
    }

    func goal(for nutrient: Nutrient) -> Double {
        goals[nutrient] ?? nutrient.defaultGoal
    }

    func set(_ value: Double, for nutrient: Nutrient) {
        goals[nutrient] = value
        defaults.set(value, forKey: Self.key(nutrient))
    }

    func resetToDefaults() {
        for n in Nutrient.allCases { set(n.defaultGoal, for: n) }
    }

    func status(of nutrient: Nutrient, in totals: MacroTotals) -> GoalStatus {
        nutrient.status(value: nutrient.value(in: totals), goal: goal(for: nutrient))
    }

    func goalsHit(in totals: MacroTotals) -> Int {
        Nutrient.allCases.filter { status(of: $0, in: totals) == .met }.count
    }

    private static func key(_ n: Nutrient) -> String { "goal.\(n.rawValue)" }
}
