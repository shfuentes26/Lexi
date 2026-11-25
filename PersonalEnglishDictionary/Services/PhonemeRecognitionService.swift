//
//  PhonemeRecognitionService.swift
//  PersonalEnglishDictionary
//
//  Created by Satur Hernandez Fuentes on 11/25/26.
//
// Model Wav2Vec 2.0 Phoneme CTC/Formato Core ML/Licencia Apache 2.0


import Foundation
import CoreML

/// Local inference for labphonlab/sp4ev-phoneme-ctc.
/// Keeps raw log probabilities for subsequent CTC alignment and scoring.
actor PhonemeRecognitionService {
    static let shared = PhonemeRecognitionService()
    private var model: MLModel?
    private var labels: [String] = []

    struct Result: Sendable {
        let labels: [String]
        let logProbabilities: [Float] // frame-major order
        let frameCount: Int
        let blankID: Int
        let frameDuration: Double = 0.020
        let leadingTrim: TimeInterval
        let audioDuration: TimeInterval

        func logProbability(frame: Int, label: Int) -> Float {
            logProbabilities[frame * labels.count + label]
        }

        /// Greedy CTC decoding, for diagnostics only, not a pronunciation score.
        var recognizedPhonemes: [String] {
            var result: [String] = []
            var previous = blankID
            for frame in 0..<frameCount {
                let offset = frame * labels.count
                var best = 0
                for id in 1..<labels.count {
                    if logProbabilities[offset + id] > logProbabilities[offset + best] { best = id }
                }
                if best != previous && best != blankID && !["<s>", "</s>", "<unk>"].contains(labels[best]) {
                    result.append(labels[best])
                }
                previous = best
            }
            return result
        }
    }

    enum RecognitionError: LocalizedError {
        case missingModel, missingVocabulary, invalidVocabulary, incompatibleModel, invalidAudio, invalidOutput
        var errorDescription: String? {
            switch self {
            case .missingModel: return "PhonemeCTC.mlmodelc is missing from the app bundle."
            case .missingVocabulary: return "vocab-by-id.json is missing from the app bundle."
            case .invalidVocabulary: return "The phoneme vocabulary is incompatible with the model."
            case .incompatibleModel: return "Unexpected Core ML model input or output schema."
            case .invalidAudio: return "Expected a valid mono 16 kHz recording."
            case .invalidOutput: return "The model returned invalid phoneme probabilities."
            }
        }
    }

    /// Loads the compiled model and vocabulary once, outside the UI actor.
    func prepareModel() throws {
        if model != nil { return }
        guard let modelURL = (Bundle.main.url(forResource: "PhonemeCTC", withExtension: "mlmodelc") ?? Bundle.main.url(forResource: "PhonemeCTC", withExtension: "mlmodelc", subdirectory: "Resources")) else {
            throw RecognitionError.missingModel
        }
        guard let vocabURL = (Bundle.main.url(forResource: "vocab-by-id", withExtension: "json") ?? Bundle.main.url(forResource: "vocab-by-id", withExtension: "json", subdirectory: "Resources")) else {
            throw RecognitionError.missingVocabulary
        }
        let ordered = try JSONDecoder().decode([String].self, from: Data(contentsOf: vocabURL))
        guard ordered.count == 392, ordered[0] == "<pad>",
              ordered.allSatisfy({ !$0.isEmpty }),
              Set(ordered.map { Data($0.utf8) }).count == 392 else {
            throw RecognitionError.invalidVocabulary
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndGPU
        let loaded = try MLModel(contentsOf: modelURL, configuration: configuration)
        let description = loaded.modelDescription
        guard let input = description.inputDescriptionsByName["audio"]?.multiArrayConstraint,
              input.shape.map({ $0.intValue }) == [1, 160_000], input.dataType == .float32,
              let output = description.outputDescriptionsByName["logp"]?.multiArrayConstraint,
              output.shape.map({ $0.intValue }) == [1, 499, 392], output.dataType == .float32 else {
            throw RecognitionError.incompatibleModel
        }
        labels = ordered
        model = loaded
        print("[Lexi Phonemes] Model loaded; \(labels.count) labels")
    }

    func recognize(_ audio: AudioPreprocessor.PreparedAudio) throws -> Result {
        try Task.checkCancellation()
        let samples = audio.samples
        guard audio.sampleRate == 16_000, samples.count >= 1_600,
              samples.count <= 160_000, samples.allSatisfy({ $0.isFinite }) else {
            throw RecognitionError.invalidAudio
        }
        let mean = samples.reduce(0.0) { $0 + Double($1) } / Double(samples.count)
        let variance = samples.reduce(0.0) { sum, sample in
            let delta = Double(sample) - mean
            return sum + delta * delta
        } / Double(samples.count)
        guard variance.isFinite, variance > 1e-12 else { throw RecognitionError.invalidAudio }
        let scale = sqrt(variance + 1e-7)
        try prepareModel()
        guard let model else { throw RecognitionError.missingModel }
        let input = try MLMultiArray(shape: [1, 160_000], dataType: .float32)
        let stride = input.strides[1].intValue
        let pointer = input.dataPointer.bindMemory(to: Float.self, capacity: (159_999 * stride) + 1)
        for index in 0..<160_000 {
            pointer[index * stride] = index < samples.count ? Float((Double(samples[index]) - mean) / scale) : 0
        }
        try Task.checkCancellation()
        let features = try MLDictionaryFeatureProvider(dictionary: ["audio": MLFeatureValue(multiArray: input)])
        let output = try model.prediction(from: features)
        try Task.checkCancellation()
        guard let logp = output.featureValue(for: "logp")?.multiArrayValue,
              logp.shape.map({ $0.intValue }) == [1, 499, 392], logp.dataType == .float32 else {
            throw RecognitionError.invalidOutput
        }
        // Wav2Vec2 convolutional receptive field: 400 samples, stride 320.
        // Exclude frames extending into artificial zero padding.
        let frameCount = min(499, (samples.count - 400) / 320 + 1)
        let frameStride = logp.strides[1].intValue
        let labelStride = logp.strides[2].intValue
        let values = logp.dataPointer.bindMemory(to: Float.self, capacity: 498 * frameStride + 391 * labelStride + 1)
        var probabilities = [Float]()
        probabilities.reserveCapacity(frameCount * labels.count)
        for frame in 0..<frameCount {
            for label in 0..<labels.count {
                let value = values[frame * frameStride + label * labelStride]
                // log(0) may legitimately be negative infinity.
                guard !value.isNaN, value != .infinity else { throw RecognitionError.invalidOutput }
                probabilities.append(value)
            }
        }
        let result = Result(labels: labels, logProbabilities: probabilities,
                            frameCount: frameCount, blankID: 0,
                            leadingTrim: audio.leadingTrim, audioDuration: audio.duration)
        print("[Lexi Phonemes] \(frameCount) frames; decoded: \(result.recognizedPhonemes.joined(separator: " "))")
        return result
    }
}
