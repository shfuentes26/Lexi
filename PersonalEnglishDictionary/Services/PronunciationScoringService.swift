//
//  PronunciationScoringService.swift.swift
//  PersonalEnglishDictionary
//
//  Created by Satur Hernandez Fuentes on 11/25/26.
//

import Foundation

/// Experimental CTC-based pronunciation scoring. Not a calibrated accuracy percentage.
struct PronunciationScoringService: Sendable {
    enum EditKind: String, Sendable { case match, substitution, omission, insertion }
    struct Edit: Sendable {
        let kind: EditKind
        let expected: String?
        let detected: String?
    }
    struct PhonemeScore: Sendable {
        let phoneme: String
        let score: Int
        let startTime: Double
        let endTime: Double
    }
    struct Evaluation: Sendable {
        let score: Int
        let acousticScore: Int
        let sequenceScore: Int
        let reference: PhoneticDictionaryService.Pronunciation
        let recognizedPhonemes: [String]
        let phonemes: [PhonemeScore]
        let edits: [Edit]
    }
    enum ScoringError: LocalizedError {
        case invalidRecognition, noReference, unsupportedPhoneme(String), alignmentFailed
        var errorDescription: String? {
            switch self {
            case .invalidRecognition: return "Invalid or insufficient phoneme recognition data."
            case .noReference: return "No reference pronunciation available."
            case .unsupportedPhoneme(let p): return "Unsupported reference phoneme: \(p)."
            case .alignmentFailed: return "Unable to align this recording. Please try again."
            }
        }
    }

    func evaluate(_ recognition: PhonemeRecognitionService.Result,
                  references: [PhoneticDictionaryService.Pronunciation]) throws -> Evaluation {
        let n = recognition.labels.count
        let t = recognition.frameCount
        guard n > 1, n <= 4096, t > 0, t <= 499,
              recognition.labels.indices.contains(recognition.blankID),
              recognition.logProbabilities.count == t * n,
              recognition.logProbabilities.allSatisfy({ !$0.isNaN && $0 != .infinity }) else {
            throw ScoringError.invalidRecognition
        }
        guard !references.isEmpty else { throw ScoringError.noReference }
        // Blank-only output is insufficient evidence, not a pronunciation grade.
        let detected = recognition.recognizedPhonemes
        guard !detected.isEmpty else { throw ScoringError.invalidRecognition }
        var best: Evaluation?
        var lastError: Error = ScoringError.alignmentFailed
        for reference in references {
            try Task.checkCancellation()
            do {
                let candidate = try evaluateVariant(recognition, reference: reference, detected: detected)
                if best == nil || candidate.score > best!.score { best = candidate }
            } catch { lastError = error }
        }
        guard let best else { throw lastError }
        return best
    }

    private func evaluateVariant(_ r: PhonemeRecognitionService.Result,
                                 reference: PhoneticDictionaryService.Pronunciation,
                                 detected: [String]) throws -> Evaluation {
        guard !reference.phonemes.isEmpty else { throw ScoringError.noReference }
        // Preserve the exact output indices; never rebuild a String-keyed vocabulary.
        let ids = try reference.phonemes.map { phone -> Int in
            guard let id = r.labels.firstIndex(where: { $0.utf8.elementsEqual(phone.utf8) }), id != r.blankID else {
                throw ScoringError.unsupportedPhoneme(phone)
            }
            return id
        }
        let spans = try align(r, ids: ids)
        let phoneScores = zip(reference.phonemes, spans).map { phone, span -> PhonemeScore in
            let probability = exp(Double(min(0, span.peak)))
            return PhonemeScore(phoneme: phone, score: percent(probability),
                                startTime: r.leadingTrim + Double(span.first) * r.frameDuration,
                                endTime: r.leadingTrim + min(r.audioDuration, Double(span.last + 1) * r.frameDuration))
        }
        let acoustic = Double(phoneScores.map(\.score).reduce(0, +)) / Double(phoneScores.count)
        let edits = compare(reference.phonemes, detected)
        let errors = edits.filter { $0.kind != .match }.count
        let sequence = max(0, 1 - Double(errors) / Double(ids.count))
        let combined = percent(0.7 * acoustic / 100 + 0.3 * sequence)
        return Evaluation(score: combined, acousticScore: Int(acoustic.rounded()),
                          sequenceScore: percent(sequence), reference: reference,
                          recognizedPhonemes: detected, phonemes: phoneScores, edits: edits)
    }

    private struct Span { var first: Int; var last: Int; var peak: Float }

    /// Viterbi CTC alignment with blank states and repeated-label constraints.
    private func align(_ r: PhonemeRecognitionService.Result, ids: [Int]) throws -> [Span] {
        let frames = r.frameCount
        let repeats = zip(ids, ids.dropFirst()).filter { $0.0 == $0.1 }.count
        guard frames >= ids.count + repeats else { throw ScoringError.alignmentFailed }
        var states = [r.blankID]
        for id in ids { states.append(id); states.append(r.blankID) }
        let width = states.count
        var previous = Array(repeating: -Double.infinity, count: width)
        var back = Array(repeating: -1, count: frames * width)
        previous[0] = Double(r.logProbability(frame: 0, label: states[0]))
        previous[1] = Double(r.logProbability(frame: 0, label: states[1]))
        for frame in 1..<frames {
            try Task.checkCancellation()
            var current = Array(repeating: -Double.infinity, count: width)
            for s in 0..<width {
                var from = s
                if s > 0 && previous[s - 1] > previous[from] { from = s - 1 }
                if s > 1 && states[s] != r.blankID && states[s] != states[s - 2]
                    && previous[s - 2] > previous[from] { from = s - 2 }
                if previous[from].isFinite {
                    current[s] = previous[from] + Double(r.logProbability(frame: frame, label: states[s]))
                    back[frame * width + s] = from
                }
            }
            previous = current
        }
        var state = previous[width - 1] > previous[width - 2] ? width - 1 : width - 2
        guard previous[state].isFinite else { throw ScoringError.alignmentFailed }
        var spans = Array<Span?>(repeating: nil, count: ids.count)
        for frame in stride(from: frames - 1, through: 0, by: -1) {
            if state % 2 == 1 {
                let i = state / 2
                let lp = r.logProbability(frame: frame, label: states[state])
                if var span = spans[i] {
                    span.first = frame; span.peak = max(span.peak, lp); spans[i] = span
                } else { spans[i] = Span(first: frame, last: frame, peak: lp) }
            }
            if frame > 0 {
                state = back[frame * width + state]
                guard state >= 0 else { throw ScoringError.alignmentFailed }
            }
        }
        let result = spans.compactMap { $0 }
        guard result.count == ids.count else { throw ScoringError.alignmentFailed }
        return result
    }

    /// Greedy-decoded edit distance: hypotheses, not definitive mispronunciations.
    private func compare(_ expected: [String], _ detected: [String]) -> [Edit] {
        let m = expected.count, n = detected.count, width = n + 1
        var d = Array(repeating: 0, count: (m + 1) * width)
        for i in 0...m { d[i * width] = i }
        for j in 0...n { d[j] = j }
        if m > 0 && n > 0 {
            for i in 1...m { for j in 1...n {
                let cost = expected[i - 1] == detected[j - 1] ? 0 : 1
                let diagonal = d[(i - 1) * width + j - 1] + cost
                let deletion = d[(i - 1) * width + j] + 1
                let insertion = d[i * width + j - 1] + 1
                d[i * width + j] = min(diagonal, min(deletion, insertion))
            } }
        }
        var i = m, j = n
        var edits: [Edit] = []
        while i > 0 || j > 0 {
            if i > 0 && j > 0 {
                let equal = expected[i - 1] == detected[j - 1]
                if d[i * width + j] == d[(i - 1) * width + j - 1] + (equal ? 0 : 1) {
                    edits.append(Edit(kind: equal ? .match : .substitution, expected: expected[i - 1], detected: detected[j - 1]))
                    i -= 1; j -= 1; continue
                }
            }
            if i > 0 && d[i * width + j] == d[(i - 1) * width + j] + 1 {
                edits.append(Edit(kind: .omission, expected: expected[i - 1], detected: nil)); i -= 1
            } else {
                edits.append(Edit(kind: .insertion, expected: nil, detected: detected[j - 1])); j -= 1
            }
        }
        return Array(edits.reversed())
    }

    private func percent(_ value: Double) -> Int {
        Int((min(1, max(0, value)) * 100).rounded())
    }
}
