import Foundation
import Observation
import SwiftData

struct ExampleDraft: Identifiable {
    var id = UUID()
    var originalText: String = ""
    var translatedText: String = ""
}
struct MeaningDraft: Identifiable {
    var id = UUID()
    var translation: String = ""
    var definition: String = ""
    var partOfSpeech: String = ""
    var examples: [ExampleDraft] = []
}

@MainActor @Observable
final class WordEditorViewModel {
    var originalText: String = ""
    var language: WordLanguage = .english
    var meanings: [MeaningDraft] = [MeaningDraft()]
    var isTranslating = false
    var errorMessage: String?
    var duplicateMessage: String?

    init(word: Word? = nil) {
        if let word {
            originalText = word.originalText
            language = word.sourceLanguage
            meanings = word.meanings.sorted { $0.order < $1.order }.map { meaning in
                MeaningDraft(translation: meaning.translation, definition: meaning.definition,
                             partOfSpeech: meaning.partOfSpeech,
                             examples: meaning.examples.sorted { $0.order < $1.order }.map {
                                 ExampleDraft(originalText: $0.originalText, translatedText: $0.translatedText)
                             })
            }
            if meanings.isEmpty { meanings = [MeaningDraft()] }
        }
    }

    var canSave: Bool {
        !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        meanings.contains { !$0.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func applyTranslation(_ translation: String) {
        if meanings.isEmpty { meanings = [MeaningDraft()] }
        meanings[0].translation = translation
    }

    func save(existing: Word?, allWords: [Word], context: ModelContext) -> Bool {
        let normalized = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSave else {
            errorMessage = "Enter a word and at least one translation."
            return false
        }
        let duplicate = allWords.contains {
            $0.id != existing?.id && $0.sourceLanguageCode == language.code &&
            $0.originalText.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if duplicate {
            duplicateMessage = "This word is already in your dictionary in the same language."
            return false
        }

        let word = existing ?? Word(originalText: normalized, sourceLanguage: language)
        word.originalText = normalized
        word.sourceLanguageCode = language.code
        if existing == nil { context.insert(word) }
        for meaning in word.meanings { context.delete(meaning) }
        word.meanings = meanings.enumerated().compactMap { index, draft -> Meaning? in
            let translation = draft.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !translation.isEmpty else { return nil }
            let meaning = Meaning(translation: translation, definition: draft.definition,
                                  partOfSpeech: draft.partOfSpeech, order: index)
            meaning.examples = draft.examples.enumerated().compactMap { n, example in
                guard !example.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return WordExample(originalText: example.originalText, translatedText: example.translatedText, order: n)
            }
            return meaning
        }
        do { try context.save(); return true }
        catch { errorMessage = "Couldn't save the word: \(error.localizedDescription)"; return false }
    }
}
