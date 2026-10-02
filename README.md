# RoodAI

A simple iOS app: snap a photo of a meal or snack and get a full macro breakdown
(calories, protein, carbs, fat, fiber, sugar), per item and in total.

Photos are analyzed by Claude's vision model through the Anthropic Messages API,
using structured outputs so the response always matches a fixed JSON schema.

## Requirements

- Xcode 16 or later
- iOS 17+ device or simulator (the camera button only appears on a real device;
  the simulator can use the photo library)
- An Anthropic API key from https://console.anthropic.com

## Run it

1. Open `RoodAI/RoodAI.xcodeproj` in Xcode.
2. Select the **RoodAI** target → *Signing & Capabilities* → choose your Team
   (and change the bundle identifier if `com.example.roodai` is taken).
3. Build and run on your iPhone.
4. On first launch, paste your API key into Settings (it's stored in the Keychain).
5. Tap **Snap**, take a photo, and the breakdown appears a few seconds later.
   Add details like "cooked in butter" or "large portion" and tap **Re-analyze**
   to refine the estimate.
6. Pick the meal (breakfast, lunch, dinner or snack), adjust the time if needed,
   and tap **Add to diary**.

## Diary and goals

The **Diary** tab saves every logged meal on the device (SwiftData).

- A week strip at the top lets you jump between days and weeks. Each day's ring
  fills toward your calorie goal and turns into a green check when every goal is hit.
- The selected day shows how much calories, protein, carbs, fat, fiber and sugar
  you've had against each goal, what's left, and whether each goal is hit.
- Meals are grouped by breakfast, lunch, dinner and snack. Tap one to see its full
  breakdown or change its meal type or time. Swipe to delete.
- **This week** shows days logged, days with every goal hit, and for each nutrient
  how many days you hit it plus your daily average.

Set your targets with the **Goals** button (target icon). How a goal counts as hit:

| Nutrient | Hit when |
|---|---|
| Protein, fiber | you reach at least the goal |
| Sugar | you stay at or under the goal |
| Calories, carbs, fat | you're within 10% of the goal |

## Project layout

| File | Purpose |
|---|---|
| `MacroAnalyzer.swift` | Builds the API request (image + prompt + JSON schema) and decodes the result |
| `Models.swift` | `MealAnalysis` / `FoodItem` types and macro totals |
| `ContentView.swift` | Snap tab: capture, analyze, show results, add to diary |
| `DiaryView.swift` | Diary tab: week strip, daily goal progress, meals, weekly summary |
| `DiaryEntry.swift` | SwiftData model for a logged meal |
| `Goals.swift` / `GoalsView.swift` | Daily goals, how each one counts as hit, and the editor |
| `MealResultView.swift` | Calorie ring, macro rows and per-item breakdown |
| `CameraPicker.swift` | SwiftUI wrapper around the system camera |
| `SettingsView.swift` / `KeychainStore.swift` | API key entry and storage |

## Before shipping to the App Store

The app currently calls the Anthropic API directly with a key the user enters.
That's fine for personal use, but a public app should never ship an API key.
Put a small backend in between (it holds the key, authenticates your users and
rate-limits them) and point `MacroAnalyzer` at it instead.
