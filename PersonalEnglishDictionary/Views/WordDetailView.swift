import SwiftUI
import SwiftData

struct WordDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var word: Word
    @State private var editing = false
    @State private var practicingPronunciation = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(word.originalText)
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundStyle(LexiTheme.primaryText)
                HStack(spacing: 18) {
                    Label(word.sourceLanguage.rawValue, systemImage: "globe").foregroundStyle(LexiTheme.secondaryText)
                    if word.sourceLanguage == .english {
                        speech("US", locale: "en-US")
                        speech("UK", locale: "en-GB")
                    } else { speech("ES", locale: "es-ES") }
                }
                if word.sourceLanguage == .english {
                    Button {
                        practicingPronunciation = true
                    } label: {
                        Label("Practice Pronunciation", systemImage: "mic.fill")
                            .font(.headline)
                            .foregroundStyle(LexiTheme.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LexiTheme.accent, in: RoundedRectangle(cornerRadius: LexiTheme.smallCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
                Text("Added \(word.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(LexiTheme.secondaryText)
                ForEach(word.meanings.sorted { $0.order < $1.order }) { meaning in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Text(meaning.translation)
                                .font(.title3.bold())
                                .foregroundStyle(LexiTheme.accent)
                            Spacer()
                            if !meaning.partOfSpeech.isEmpty { Text(meaning.partOfSpeech)
                                    .font(.caption)
                                    .foregroundStyle(LexiTheme.secondaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(LexiTheme.background, in: Capsule()) }
                        }
                        if !meaning.definition.isEmpty { Text(meaning.definition).foregroundStyle(LexiTheme.secondaryText) }
                        ForEach(meaning.examples.sorted { $0.order < $1.order }) { example in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(example.originalText).italic()
                                        .foregroundStyle(LexiTheme.primaryText)
                                    if !example.translatedText.isEmpty { Text(example.translatedText).font(.subheadline).foregroundStyle(LexiTheme.secondaryText) }
                                }
                                Spacer(minLength: 8)
                                Button { SpeechService.shared.speak(example.originalText, language: word.sourceLanguage == .english ? "en-US" : "es-ES") } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                }
                                .foregroundStyle(LexiTheme.accent)
                                .accessibilityLabel("Read example aloud")
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LexiTheme.surface, in: RoundedRectangle(cornerRadius: LexiTheme.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: LexiTheme.cornerRadius)
                            .strokeBorder(LexiTheme.border, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(LexiTheme.screenPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(LexiTheme.background.ignoresSafeArea())
        .tint(LexiTheme.accent)
        .toolbarBackground(LexiTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Word Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { word.isFavorite.toggle(); persist() } label: {
                    Image(systemName: word.isFavorite ? "star.fill" : "star").foregroundStyle(word.isFavorite ? LexiTheme.favorite : LexiTheme.accent)
                }
                Button("Edit") { editing = true }
                Menu {
                    Button("Delete Word", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { WordEditorView(existingWord: word) } }
        .sheet(isPresented: $practicingPronunciation) {
            NavigationStack {
                PronunciationView(word: word.originalText)
            }
        }
        .confirmationDialog("Delete this word permanently?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { context.delete(word); persist(); dismiss() }
        }
        .alert("Save Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func speech(_ title: String, locale: String) -> some View {
        Button { SpeechService.shared.speak(word.originalText, language: locale) } label: {
            Label(title, systemImage: "speaker.wave.2")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LexiTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(LexiTheme.surface, in: Capsule())
        }
    }
    private func persist() { do { try context.save() } catch { errorMessage = error.localizedDescription } }
}
