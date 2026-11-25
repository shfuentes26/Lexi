import Foundation
import Observation
import SwiftData

@MainActor @Observable
final class PracticeViewModel {
    var queue: [Word] = []
    var currentIndex = 0
    var revealed = false
    var reviewedCount = 0
    var saveError: String?
    var current: Word? { queue.indices.contains(currentIndex) ? queue[currentIndex] : nil }

    func start(words: [Word], now: Date = .now) {
        queue = words.filter { ($0.learningProgress?.nextReviewDate ?? .distantPast) <= now }
            .sorted { ($0.learningProgress?.nextReviewDate ?? .distantPast) < ($1.learningProgress?.nextReviewDate ?? .distantPast) }
        currentIndex = 0
        reviewedCount = 0
        revealed = false
    }

    func rate(_ rating: ReviewRating, context: ModelContext) {
        guard let word = current else { return }
        let progress: LearningProgress
        if let existing = word.learningProgress { progress = existing }
        else { progress = LearningProgress(); word.learningProgress = progress }
        SpacedRepetitionService.review(progress, rating: rating)
        do {
            try context.save()
            reviewedCount += 1
            currentIndex += 1
            revealed = false
        } catch { saveError = error.localizedDescription }
    }
}
