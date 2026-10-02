import SwiftData
import SwiftUI

@main
struct RoodAIApp: App {
    @State private var goals = GoalStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Snap", systemImage: "camera.fill") }
                DiaryView()
                    .tabItem { Label("Diary", systemImage: "book.fill") }
            }
            .environment(goals)
        }
        .modelContainer(for: DiaryEntry.self)
    }
}
