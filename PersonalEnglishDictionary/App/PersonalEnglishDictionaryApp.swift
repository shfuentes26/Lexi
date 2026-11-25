import SwiftUI
import SwiftData

@main
struct PersonalEnglishDictionaryApp: App {
    var body: some Scene {
        WindowGroup { RootTabView() }
            .modelContainer(for: [Word.self, Meaning.self, WordExample.self, LearningProgress.self])
    }
}
