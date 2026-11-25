import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query private var words: [Word]
    @State private var search = ""
    private var favorites: [Word] {
        words.filter { $0.isFavorite && (search.isEmpty || $0.originalText.localizedCaseInsensitiveContains(search) || $0.summary.localizedCaseInsensitiveContains(search)) }
            .sorted { $0.originalText.localizedStandardCompare($1.originalText) == .orderedAscending }
    }
    var body: some View {
        List(favorites) { word in
            NavigationLink { WordDetailView(word: word) } label: { WordRow(word: word) }
                .listRowBackground(LexiTheme.surface)
                .listRowSeparatorTint(LexiTheme.border)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LexiTheme.background.ignoresSafeArea())
        .tint(LexiTheme.accent)
        .searchable(text: $search, prompt: "Search favorites")
        .navigationTitle("Favorites")
        .overlay {
            if favorites.isEmpty {
                ContentUnavailableView {
                    Label("No favorites found", systemImage: "star")
                        .foregroundStyle(LexiTheme.favorite)
                } description: {
                    Text("Mark words with a star to see them here.")
                        .foregroundStyle(LexiTheme.secondaryText)
                }
            }
        }
    }
}
