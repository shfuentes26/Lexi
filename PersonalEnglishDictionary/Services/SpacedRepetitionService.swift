import Foundation

enum ReviewRating: String, CaseIterable, Identifiable {
    case again = "Again", hard = "Hard", good = "Good", easy = "Easy"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .again: "arrow.counterclockwise"
        case .hard: "exclamationmark.circle.fill"
        case .good: "checkmark"
        case .easy: "star.fill"
        }
    }
}

struct SpacedRepetitionService {
    // SM-2-inspired scheduling, at word level. "Again" retries after ten minutes.
    static func review(_ progress: LearningProgress, rating: ReviewRating, now: Date = .now) {
        let days: Double
        switch rating {
        case .again:
            progress.repetitions = 0
            progress.interval = 0
            progress.easeFactor = max(1.3, progress.easeFactor - 0.2)
            days = 10.0 / 1440.0
        case .hard:
            progress.repetitions += 1
            progress.easeFactor = max(1.3, progress.easeFactor - 0.15)
            days = max(1, progress.interval * 1.2)
        case .good:
            progress.repetitions += 1
            days = progress.repetitions == 1 ? 1 : progress.repetitions == 2 ? 3 : max(1, progress.interval * progress.easeFactor)
        case .easy:
            progress.repetitions += 1
            progress.easeFactor += 0.15
            days = progress.repetitions == 1 ? 4 : max(4, progress.interval * progress.easeFactor * 1.3)
        }
        progress.interval = days
        progress.lastReviewDate = now
        progress.nextReviewDate = now.addingTimeInterval(days * 86400)
        progress.lastResult = rating.rawValue
    }
}
