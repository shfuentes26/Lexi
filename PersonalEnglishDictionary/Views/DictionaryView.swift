import SwiftUI
import SwiftData

struct DictionaryView: View {
    @Environment(\.modelContext) private var context
    @Query private var words: [Word]
    @State private var vm = DictionaryViewModel()
    @State private var errorMessage: String?

    var body: some View {
        List {
            Picker("Filter", selection: $vm.selectedFilter) {
                ForEach(DictionaryViewModel.DictionaryFilter.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            ForEach(vm.filtered(words)) { word in
                NavigationLink { WordDetailView(word: word) } label: { WordRow(word: word) }
                    .listRowBackground(LexiTheme.surface)
                    .listRowSeparatorTint(LexiTheme.border)
                    .swipeActions(edge: .leading) {
                        Button { do { try vm.toggleFavorite(word, in: context) } catch { errorMessage = error.localizedDescription } } label: {
                            Label("Favorite", systemImage: word.isFavorite ? "star.slash" : "star")
                        }.tint(LexiTheme.favorite)
                    }
            }
            .onDelete { offsets in
                let visible = vm.filtered(words)
                for index in offsets where visible.indices.contains(index) {
                    do { try vm.delete(visible[index], from: context) } catch { errorMessage = error.localizedDescription }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(LexiTheme.background.ignoresSafeArea())
        .tint(LexiTheme.accent)
        .toolbarBackground(LexiTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $vm.searchText, prompt: "Search words or translations")
        .navigationTitle("Dictionary")
        .overlay {
            if words.isEmpty { ContentUnavailableView("Your dictionary is empty", systemImage: "books.vertical", description: Text("Use Add Word to save your first word.")) }
            else if vm.filtered(words).isEmpty { ContentUnavailableView.search(text: vm.searchText) }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
