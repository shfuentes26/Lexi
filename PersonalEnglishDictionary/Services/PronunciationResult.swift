//
//  PronunciationResult.swift
//  PersonalEnglishDictionary
//
//  Created by Satur Hernandez Fuentes on 11/25/26.
//

import Foundation

/// One completed, in-memory pronunciation attempt. Scores are experimental,
/// not calibrated percentages of phonetic accuracy.
struct PronunciationResult: Identifiable, Sendable {
    let id: UUID
    let word: String
    let date: Date
    let evaluation: PronunciationScoringService.Evaluation

    /// Time of analysis (preprocessing, inference and scoring), if measured.
    let analysisDuration: TimeInterval?

    init(word: String,
         evaluation: PronunciationScoringService.Evaluation,
         analysisDuration: TimeInterval? = nil,
         date: Date = .now,
         id: UUID = UUID()) {
        self.id = id
        self.word = word
        self.date = date
        self.evaluation = evaluation
        self.analysisDuration = analysisDuration
    }

    var localeIdentifier: String { "en-US" }
    var score: Int { evaluation.score }
    var acousticScore: Int { evaluation.acousticScore }
    var sequenceScore: Int { evaluation.sequenceScore }
    var referenceIPA: String { evaluation.reference.ipa }
    var expectedPhonemes: [String] { evaluation.reference.phonemes }
    var recognizedPhonemes: [String] { evaluation.recognizedPhonemes }
    var recognizedIPA: String { recognizedPhonemes.joined(separator: " ") }

    /// Position-based IDs distinguish repeated phonemes in the same word.
    struct PhonemeResult: Identifiable, Sendable {
        let id: Int
        let phoneme: String
        let score: Int
        let startTime: TimeInterval
        let endTime: TimeInterval
    }

    var phonemes: [PhonemeResult] {
        evaluation.phonemes.enumerated().map { index, item in
            PhonemeResult(id: index, phoneme: item.phoneme, score: item.score,
                          startTime: item.startTime, endTime: item.endTime)
        }
    }

    /// Differences are recognition hypotheses, not confirmed speech errors.
    struct PhonemeDifference: Identifiable, Sendable {
        let id: Int
        let kind: PronunciationScoringService.EditKind
        let expected: String?
        let detected: String?
    }

    var differences: [PhonemeDifference] {
        evaluation.edits.enumerated().compactMap { index, edit in
            guard edit.kind != .match else { return nil }
            return PhonemeDifference(id: index, kind: edit.kind,
                                     expected: edit.expected, detected: edit.detected)
        }
    }

    var weakestPhoneme: PhonemeResult? {
        phonemes.min { $0.score < $1.score }
    }
}
