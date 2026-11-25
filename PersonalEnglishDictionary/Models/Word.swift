import Foundation
import SwiftData

enum WordLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "English"
    case spanish = "Spanish"
    var id: String { rawValue }
    var code: String { self == .english ? "en" : "es" }
    var flag: String { self == .english ? "🇬🇧" : "🇪🇸" }
    var target: WordLanguage { self == .english ? .spanish : .english }
}

@Model
final class Word {
    var id: UUID = UUID()
    var originalText: String = ""
    var sourceLanguageCode: String = "en"
    var dateAdded: Date = Date()
    var isFavorite: Bool = false
    @Relationship(deleteRule: .cascade) var meanings: [Meaning] = []
    @Relationship(deleteRule: .cascade) var learningProgress: LearningProgress? = nil

    init(originalText: String, sourceLanguage: WordLanguage) {
        self.originalText = originalText
        self.sourceLanguageCode = sourceLanguage.code
        self.dateAdded = .now
        self.learningProgress = LearningProgress()
    }
    var sourceLanguage: WordLanguage { sourceLanguageCode == "es" ? .spanish : .english }
    var summary: String { meanings.sorted { $0.order < $1.order }.map(\.translation).filter { !$0.isEmpty }.joined(separator: ", ") }
}

@Model
final class Meaning {
    var id: UUID = UUID()
    var translation: String = ""
    var definition: String = ""
    var partOfSpeech: String = ""
    var order: Int = 0
    @Relationship(deleteRule: .cascade) var examples: [WordExample] = []
    init(translation: String, definition: String = "", partOfSpeech: String = "", order: Int = 0) {
        self.translation = translation
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.order = order
    }
}

@Model
final class WordExample {
    var id: UUID = UUID()
    var originalText: String = ""
    var translatedText: String = ""
    var order: Int = 0
    init(originalText: String, translatedText: String, order: Int = 0) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.order = order
    }
}

@Model
final class LearningProgress {
    var id: UUID = UUID()
    var repetitions: Int = 0
    var interval: Double = 0
    var easeFactor: Double = 2.5
    var nextReviewDate: Date = Date()
    var lastReviewDate: Date? = nil
    var lastResult: String = ""
    init() {}
}
