import SwiftUI
import SwiftData
import Translation

struct WordEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    private let existingWord: Word?
    @State private var vm: WordEditorViewModel
    @State private var configuration: TranslationSession.Configuration?
    @State private var pendingTranslation: String = ""
    @State private var pendingLanguage: WordLanguage = .english
    @State private var pendingExample: (meaning: Int, example: Int)?

    init(existingWord: Word? = nil) {
        self.existingWord = existingWord
        _vm = State(initialValue: WordEditorViewModel(word: existingWord))
    }

    var body: some View {
        Form {
            Section("Word") {
                TextField("Enter a word", text: $vm.originalText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Source language", selection: $vm.language) {
                    ForEach(WordLanguage.allCases) { language in Text("\(language.flag) \(language.rawValue)").tag(language) }
                }.pickerStyle(.segmented)
                Button { translateWord() } label: {
                    HStack {
                        Spacer()
                        if vm.isTranslating { ProgressView().tint(LexiTheme.onAccent) } else { Image(systemName: "sparkles") }
                        Text("Translate with Apple")
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundStyle(LexiTheme.onAccent)
                    .padding(.vertical, 12)
                    .background(LexiTheme.accent, in: RoundedRectangle(cornerRadius: LexiTheme.smallCornerRadius))
                    .opacity(vm.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isTranslating ? 0.55 : 1)
                }
                .disabled(vm.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isTranslating)
            }
            .listRowBackground(LexiTheme.surface)
            .listRowSeparatorTint(LexiTheme.border)
            ForEach(vm.meanings.indices, id: \.self) { meaningIndex in
                Section {
                    TextField("Translation", text: $vm.meanings[meaningIndex].translation)
                    TextField("Meaning / definition (optional)", text: $vm.meanings[meaningIndex].definition, axis: .vertical)
                    TextField("Part of speech (optional)", text: $vm.meanings[meaningIndex].partOfSpeech)
                    ForEach(vm.meanings[meaningIndex].examples.indices, id: \.self) { exampleIndex in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("Example \(exampleIndex + 1)").font(.subheadline.bold())
                                    .foregroundStyle(LexiTheme.accent)
                                Spacer()
                                Button(role: .destructive) { vm.meanings[meaningIndex].examples.remove(at: exampleIndex) } label: { Image(systemName: "trash") }
                            }
                            TextField("Sentence in source language", text: $vm.meanings[meaningIndex].examples[exampleIndex].originalText, axis: .vertical)
                            TextField("Translated sentence", text: $vm.meanings[meaningIndex].examples[exampleIndex].translatedText, axis: .vertical)
                            Button("Translate example with Apple") { translateExample(meaningIndex, exampleIndex) }
                                .font(.caption).disabled(vm.isTranslating || vm.meanings[meaningIndex].examples[exampleIndex].originalText.isEmpty)
                        }
                        .padding(.vertical, 5)
                    }
                    Button("Add Example", systemImage: "plus") { vm.meanings[meaningIndex].examples.append(ExampleDraft()) }
                    if vm.meanings.count > 1 {
                        Button("Remove Meaning", role: .destructive) { vm.meanings.remove(at: meaningIndex) }
                    }
                } header: { Text("Meaning \(meaningIndex + 1)").foregroundStyle(LexiTheme.secondaryText) }
                .listRowBackground(LexiTheme.surface)
                .listRowSeparatorTint(LexiTheme.border)
            }
            Section {
                Button("Add Meaning", systemImage: "plus.circle") { vm.meanings.append(MeaningDraft()) }
            }
            .listRowBackground(LexiTheme.surface)
            Section {
                Text("Apple Translation runs on the device. iOS may ask to download language packs. Enter examples yourself, then translate them with Apple; no third-party service is used.")
                    .font(.caption).foregroundStyle(LexiTheme.secondaryText)
            }
            .listRowBackground(LexiTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(LexiTheme.background.ignoresSafeArea())
        .tint(LexiTheme.accent)
        .toolbarBackground(LexiTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .navigationTitle(existingWord == nil ? "Add Word" : "Edit Word")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if vm.save(
                        existing: existingWord,
                        allWords: allWords,
                        context: context
                    ) {
                        if existingWord == nil {
                            resetForm()
                        } else {
                            dismiss()
                        }
                    }
                }
                .bold()
                .disabled(!vm.canSave)
            }
            if existingWord != nil { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .translationTask(configuration) { session in
            do {
                let response = try await session.translate(pendingTranslation)
                if let target = pendingExample {
                    if vm.meanings.indices.contains(target.meaning) && vm.meanings[target.meaning].examples.indices.contains(target.example) {
                        vm.meanings[target.meaning].examples[target.example].translatedText = response.targetText
                    }
                } else { vm.applyTranslation(response.targetText) }
            } catch {
                vm.errorMessage = "Apple Translation unavailable: \(error.localizedDescription). You can enter the translation manually."
            }
            vm.isTranslating = false
        }
        .alert("Notice", isPresented: Binding(get: { vm.errorMessage != nil || vm.duplicateMessage != nil }, set: { if !$0 { vm.errorMessage = nil; vm.duplicateMessage = nil } })) {
            Button("OK") { vm.errorMessage = nil; vm.duplicateMessage = nil }
        } message: { Text(vm.errorMessage ?? vm.duplicateMessage ?? "") }
    }

    private func translateWord() { pendingExample = nil; requestTranslation(vm.originalText) }
    private func translateExample(_ meaning: Int, _ example: Int) {
        pendingExample = (meaning, example)
        requestTranslation(vm.meanings[meaning].examples[example].originalText)
    }
    
    private func requestTranslation(_ text: String) {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty, !vm.isTranslating else {
            return
        }

        vm.isTranslating = true
        pendingTranslation = trimmed
        pendingLanguage = vm.language

        let source = Locale.Language(
            identifier: vm.language.code
        )

        let target = Locale.Language(
            identifier: vm.language.target.code
        )

        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: source,
                target: target
            )
        } else if configuration?.source != source ||
                  configuration?.target != target {
            configuration?.source = source
            configuration?.target = target
        } else {
            configuration?.invalidate()
        }
    }

    private func resetForm() {
        vm = WordEditorViewModel()
        pendingTranslation = ""
        pendingExample = nil
    }
}
