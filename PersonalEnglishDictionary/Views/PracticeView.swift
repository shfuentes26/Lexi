import SwiftUI
import SwiftData

struct PracticeView: View {
    @Environment(\.modelContext) private var context
    @Query private var words: [Word]
    @State private var vm = PracticeViewModel()

    var body: some View {
        VStack(spacing: 22) {
            if let word = vm.current {
                HStack {
                    Text("\(vm.currentIndex + 1) / \(vm.queue.count)").font(.subheadline).foregroundStyle(LexiTheme.secondaryText)
                    Spacer()
                    Text("Due for review").font(.caption).foregroundStyle(LexiTheme.accent)
                }
                Spacer()
                VStack(spacing: 18) {
                    Text(word.originalText).font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(LexiTheme.primaryText)
                        .multilineTextAlignment(.center)
                    Text("Do you remember the meaning?").font(.subheadline)
                        .foregroundStyle(LexiTheme.secondaryText)
                    if vm.revealed {
                        Divider().overlay(LexiTheme.border)
                        Text(word.summary).font(.title3.bold()).foregroundStyle(LexiTheme.accent).multilineTextAlignment(.center)
                        ForEach(word.meanings.sorted { $0.order < $1.order }) { meaning in
                            ForEach(meaning.examples.sorted { $0.order < $1.order }) { example in
                                Text(example.originalText).italic().foregroundStyle(LexiTheme.primaryText).multilineTextAlignment(.center)
                                if !example.translatedText.isEmpty { Text(example.translatedText).font(.caption).foregroundStyle(LexiTheme.secondaryText).multilineTextAlignment(.center) }
                            }
                        }
                    } else {
                        Button("Show Answer") { withAnimation { vm.revealed = true } }
                            .buttonStyle(.borderedProminent)
                            .tint(LexiTheme.accent)
                            .foregroundStyle(LexiTheme.onAccent)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(LexiTheme.surface, in: RoundedRectangle(cornerRadius: LexiTheme.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: LexiTheme.cornerRadius)
                        .strokeBorder(LexiTheme.border, lineWidth: 1)
                }
                Spacer()
                if vm.revealed {
                    HStack(spacing: 8) {
                        rateButton(.again, color: LexiTheme.destructive)
                        rateButton(.hard, color: LexiTheme.favorite)
                        rateButton(.good, color: LexiTheme.accent)
                        rateButton(.easy, color: Color(red: 0.48, green: 0.72, blue: 1.0))
                    }
                }
            } else {
                Spacer()
                ContentUnavailableView("All caught up!", systemImage: "checkmark.seal", description: Text("You reviewed \(vm.reviewedCount) words. Come back when more are due."))
                Button("Refresh reviews") { vm.start(words: words) }
                    .buttonStyle(.borderedProminent)
                    .tint(LexiTheme.accent)
                    .foregroundStyle(LexiTheme.onAccent)
                Spacer()
            }
        }
        .padding()
        .background(LexiTheme.background.ignoresSafeArea())
        .tint(LexiTheme.accent)
        .navigationTitle("Practice")
        .onAppear { vm.start(words: words) }
        .alert("Couldn't save progress", isPresented: Binding(get: { vm.saveError != nil }, set: { if !$0 { vm.saveError = nil } })) {
            Button("OK") { vm.saveError = nil }
        } message: { Text(vm.saveError ?? "") }
    }

    private func rateButton(_ rating: ReviewRating, color: Color) -> some View {
        Button { vm.rate(rating, context: context) } label: {
            VStack(spacing: 6) { Image(systemName: rating.symbol).font(.title3); Text(rating.rawValue).font(.caption.bold()) }
                .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .background(LexiTheme.surface, in: RoundedRectangle(cornerRadius: LexiTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: LexiTheme.smallCornerRadius)
                .strokeBorder(color.opacity(0.5), lineWidth: 1)
        }
    }
}
