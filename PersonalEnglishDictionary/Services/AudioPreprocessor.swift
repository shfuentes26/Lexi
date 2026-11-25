//
//  AudioPreprocessor.swift
//  PersonalEnglishDictionary
//
//  Created by Satur Hernandez Fuentes on 11/25/26.
//

import Foundation
import AVFoundation

/// Prepares Lexi's mono 16 kHz WAV recordings for phoneme recognition.
/// Model-specific padding, masking and normalization belong in the inference service.
struct AudioPreprocessor {
    static let sampleRate: Double = 16_000
    static let maximumSamples = 160_000

    struct PreparedAudio: Sendable {
        let samples: [Float]
        let sampleRate: Double
        let originalDuration: TimeInterval
        let leadingTrim: TimeInterval
        let trailingTrim: TimeInterval
        let peakAmplitude: Float
        let rmsAmplitude: Float
        var duration: TimeInterval { Double(samples.count) / sampleRate }
    }

    enum ProcessingError: LocalizedError {
        case unsupportedFormat, emptyRecording, recordingTooLong, insufficientSignal
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "Expected mono audio at 16 kHz."
            case .emptyRecording: return "The recording is empty. Please try again."
            case .recordingTooLong: return "The recording exceeds ten seconds."
            case .insufficientSignal: return "Not enough audio signal. Please speak closer to the microphone."
            }
        }
    }

    /// Silence trimming is deliberately disabled by default to protect quiet phonemes.
    func prepare(url: URL, trimSilence: Bool = false) throws -> PreparedAudio {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        guard format.channelCount == 1, abs(format.sampleRate - Self.sampleRate) < 0.5 else {
            throw ProcessingError.unsupportedFormat
        }
        guard file.length > 0 else { throw ProcessingError.emptyRecording }
        guard file.length <= AVAudioFramePosition(Self.maximumSamples) else { throw ProcessingError.recordingTooLong }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw ProcessingError.emptyRecording
        }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else {
            throw ProcessingError.emptyRecording
        }
        let raw = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        return try prepare(samples: raw, trimSilence: trimSilence)
    }

    /// Separate entry point for unit tests and future recording implementations.
    func prepare(samples raw: [Float], trimSilence: Bool = false) throws -> PreparedAudio {
        guard !raw.isEmpty else { throw ProcessingError.emptyRecording }
        guard raw.count <= Self.maximumSamples else { throw ProcessingError.recordingTooLong }
        guard raw.allSatisfy({ $0.isFinite }) else { throw ProcessingError.unsupportedFormat }
        let mean = raw.reduce(0.0) { $0 + Double($1) } / Double(raw.count)
        let centered = raw.map { $0 - Float(mean) }
        let peak = centered.reduce(Float.zero) { max($0, abs($1)) }
        let sumOfSquares: Double = centered.reduce(0.0) { (sum: Double, sample: Float) -> Double in
            let value = Double(sample)
            return sum + value * value
        }
        let meanSquare: Double = sumOfSquares / Double(centered.count)
        let rms: Float = Float(meanSquare.squareRoot())
        guard centered.count >= 1_600, peak >= 0.003, rms >= 0.0005 else {
            throw ProcessingError.insufficientSignal
        }
        var start = 0
        var end = centered.count
        if trimSilence {
            // 20 ms RMS windows; retain 250 ms of context on each side.
            let window = 320
            let margin = 4_000
            let threshold = max(Float(0.0005), rms * 0.08)
            var first: Int?
            var last: Int?
            for offset in stride(from: 0, to: centered.count, by: window) {
                let stop = min(offset + window, centered.count)
                let energy = centered[offset..<stop].reduce(0.0) { $0 + Double($1) * Double($1) }
                if sqrt(energy / Double(stop - offset)) >= Double(threshold) {
                    if first == nil { first = offset }
                    last = stop
                }
            }
            if let first, let last {
                start = max(0, first - margin)
                end = min(centered.count, last + margin)
            }
        }
        let samples = Array(centered[start..<end])
        return PreparedAudio(samples: samples, sampleRate: Self.sampleRate,
                             originalDuration: Double(raw.count) / Self.sampleRate,
                             leadingTrim: Double(start) / Self.sampleRate,
                             trailingTrim: Double(raw.count - end) / Self.sampleRate,
                             peakAmplitude: peak, rmsAmplitude: rms)
    }
}

