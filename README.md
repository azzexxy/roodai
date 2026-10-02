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

## Project layout

| File | Purpose |
|---|---|
| `MacroAnalyzer.swift` | Builds the API request (image + prompt + JSON schema) and decodes the result |
| `Models.swift` | `MealAnalysis` / `FoodItem` types and macro totals |
| `ContentView.swift` | Main screen: capture, analyze, show results |
| `MealResultView.swift` | Calorie ring, macro rows and per-item breakdown |
| `CameraPicker.swift` | SwiftUI wrapper around the system camera |
| `SettingsView.swift` / `KeychainStore.swift` | API key entry and storage |

## Before shipping to the App Store

The app currently calls the Anthropic API directly with a key the user enters.
That's fine for personal use, but a public app should never ship an API key.
Put a small backend in between (it holds the key, authenticates your users and
rate-limits them) and point `MacroAnalyzer` at it instead.
