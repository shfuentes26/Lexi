import Foundation
import Observation
import SwiftData

@MainActor @Observable
final class DictionaryViewModel {
    var searchText = ""
    var selectedFilter: DictionaryFilter = .all
    enum DictionaryFilter: String, CaseIterable, Identifiable {
        case all = "All", favorites = "Favorites", recent = "Recent"
        var id: String { rawValue }
    }

    func filtered(_ words: [Word]) -> [Word] {
        var results = words
        if selectedFilter == .favorites { results = results.filter(\.isFavorite) }
        if !searchText.isEmpty {
            results = results.filter { $0.originalText.localizedCaseInsensitiveContains(searchText) || $0.summary.localizedCaseInsensitiveContains(searchText) }
        }
        if selectedFilter == .recent { return results.sorted { $0.dateAdded > $1.dateAdded } }
        return results.sorted { $0.originalText.localizedStandardCompare($1.originalText) == .orderedAscending }
    }

    func delete(_ word: Word, from context: ModelContext) throws {
        context.delete(word)
        try context.save()
    }
    func toggleFavorite(_ word: Word, in context: ModelContext) throws {
        word.isFavorite.toggle()
        try context.save()
    }
}
