import SwiftUI

struct RootTabView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(selectedTab: $selectedTab)
                    .toolbarBackground(LexiTheme.background, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
                .toolbarBackground(LexiTheme.tabBar, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack {
                DictionaryView()
                    .toolbarBackground(LexiTheme.background, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
                .toolbarBackground(LexiTheme.tabBar, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Dictionary", systemImage: "books.vertical") }.tag(1)
            NavigationStack {
                WordEditorView()
                    .toolbarBackground(LexiTheme.background, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
                .toolbarBackground(LexiTheme.tabBar, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Add Word", systemImage: "plus") }.tag(2)
            NavigationStack {
                FavoritesView()
                    .toolbarBackground(LexiTheme.background, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
                .toolbarBackground(LexiTheme.tabBar, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Favorites", systemImage: "star") }.tag(3)
            NavigationStack {
                PracticeView()
                    .toolbarBackground(LexiTheme.background, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
                .toolbarBackground(LexiTheme.tabBar, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .tabItem { Label("Practice", systemImage: "graduationcap") }.tag(4)
        }
        .tint(LexiTheme.accent)
        .preferredColorScheme(.dark)
        .background(LexiTheme.background.ignoresSafeArea())
    }
}
