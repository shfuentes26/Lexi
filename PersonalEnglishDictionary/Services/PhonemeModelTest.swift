//
//  PhonemeModelTest.swift
//  PersonalEnglishDictionary
//
//  Created by Satur Hernandez Fuentes on 11/25/26.
//

import Foundation
import CoreML

enum PhonemeModelTest {

    static func run() {
        do {
            print("[Lexi AI] Starting model test")

            guard let modelURL = resource(
                "PhonemeCTC", "mlmodelc"
            ) else {
                print("[Lexi AI] ERROR: Model not found")
                return
            }

            print("[Lexi AI] Model found")

            guard let vocabURL = resource(
                "vocab-by-id", "json"
            ) else {
                print("[Lexi AI] ERROR: Vocabulary not found")
                return
            }

            let data = try Data(contentsOf: vocabURL)
            let vocab = try JSONDecoder().decode(
                [String].self,
                from: data
            )

            print("[Lexi AI] Vocabulary: \(vocab.count) labels")

            guard resource("cmudict", "txt") != nil else {
                print("[Lexi AI] ERROR: Dictionary not found")
                return
            }

            print("[Lexi AI] Dictionary found")

            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU

            let loadStart = Date()

            let model = try MLModel(
                contentsOf: modelURL,
                configuration: config
            )

            print("[Lexi AI] Model loaded in \(Date().timeIntervalSince(loadStart)) seconds")

            let input = try MLMultiArray(
                shape: [1, 160000],
                dataType: .float32
            )

            for i in 0..<input.count {
                input[i] = NSNumber(value: Float.zero)
            }

            let provider = try MLDictionaryFeatureProvider(
                dictionary: ["audio": MLFeatureValue(multiArray: input)]
            )

            let inferenceStart = Date()

            let prediction = try model.prediction(from: provider)

            guard let output = prediction
                .featureValue(for: "logp")?
                .multiArrayValue else {
                print("[Lexi AI] ERROR: Invalid output")
                return
            }

            print("[Lexi AI] Output shape: \(output.shape)")
            print("[Lexi AI] Inference time: \(Date().timeIntervalSince(inferenceStart)) seconds")
            print("[Lexi AI] TEST PASSED")

        } catch {
            print("[Lexi AI] ERROR: \(error)")
        }
    }

    private static func resource(
        _ name: String,
        _ ext: String
    ) -> URL? {
        Bundle.main.url(
            forResource: name,
            withExtension: ext
        ) ?? Bundle.main.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Resources"
        )
    }
}
