import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var words: [Word]
    @Binding var selectedTab: Int
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    (Text("Lexi").foregroundColor(LexiTheme.primaryText) +
                     Text(".").foregroundColor(LexiTheme.accent))
                        .font(LexiTheme.brandFont)
                        .accessibilityLabel("Lexi")
                    Text("Your personal dictionary")
                        .font(.subheadline)
                        .foregroundStyle(LexiTheme.secondaryText)
                }
                .padding(.top, 18)

                VStack(spacing: 10) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(LexiTheme.accent)
                        .accessibilityHidden(true)
                    Text("\(words.count)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(LexiTheme.primaryText)
                        .monospacedDigit()
                    Text("Words in your dictionary")
                        .font(.subheadline)
                        .foregroundStyle(LexiTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(26)
                .background(LexiTheme.brandGradient, in: RoundedRectangle(cornerRadius: LexiTheme.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: LexiTheme.cornerRadius)
                        .strokeBorder(LexiTheme.border, lineWidth: 1)
                }
                .accessibilityElement(children: .combine)

                LazyVGrid(columns: columns, spacing: 14) {
                    shortcut("Dictionary", subtitle: "Browse all words", icon: "books.vertical.fill", tab: 1)
                    shortcut("Favorites", subtitle: "Your favorites", icon: "star.fill", tab: 3)
                    shortcut("Add Word", subtitle: "Expand your vocabulary", icon: "plus.circle.fill", tab: 2)
                    shortcut("Practice", subtitle: "Study & review", icon: "bolt.fill", tab: 4)
                }
                Spacer(minLength: 20)
            }
            .padding(LexiTheme.screenPadding)
        }
        .background(LexiTheme.background.ignoresSafeArea())
        .toolbarBackground(LexiTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .task {
            await Task.detached(priority: .userInitiated) {
                PhonemeModelTest.run()
            }.value
        }
    }

    private func shortcut(_ title: String, subtitle: String, icon: String, tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundStyle(tab == 3 ? LexiTheme.favorite : LexiTheme.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(LexiTheme.cardTitleFont)
                    .foregroundStyle(LexiTheme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LexiTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 125)
            .background(LexiTheme.surface, in: RoundedRectangle(cornerRadius: LexiTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LexiTheme.cornerRadius)
                    .strokeBorder(LexiTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
