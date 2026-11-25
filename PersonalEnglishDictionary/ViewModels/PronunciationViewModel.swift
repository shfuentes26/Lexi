//
//  PronunciationViewModel.swift
//  PersonalEnglishDictionary
//
//  Created by Satur Hernandez Fuentes on 11/25/26.
//

import Foundation
import Observation

/// Coordinates a single US-English pronunciation practice session.
/// Scores are experimental and are not persisted.
@MainActor
@Observable
final class PronunciationViewModel {
    enum State: Equatable {
        case idle, requestingPermission, recording, finishingRecording
        case analyzing, completed, playing, failed
    }

    let word: String
    private(set) var state: State = .idle
    private(set) var result: PronunciationResult?
    private(set) var errorMessage: String?
    private(set) var hasRecording = false
    private(set) var recordingDuration: TimeInterval = 0

    @ObservationIgnored private let recorder = AudioRecordingService()
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    init(word: String) {
        self.word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        recorder.onRecordingFinished = { [weak self] outcome in
            self?.recordingFinished(outcome)
        }
        recorder.onPlaybackFinished = { [weak self] in
            guard let self, self.state == .playing else { return }
            self.state = self.result == nil ? .idle : .completed
        }
    }

    var isBusy: Bool {
        switch state {
        case .requestingPermission, .recording, .finishingRecording, .analyzing, .playing: true
        default: false
        }
    }
    var canRecord: Bool { !isBusy && !word.isEmpty }
    var canStopRecording: Bool { state == .recording }
    var canPlayRecording: Bool { hasRecording && !isBusy }

    func startRecording() {
        guard canRecord else { return }
        operation?.cancel()
        generation = UUID()
        let token = generation
        recorder.discardRecording()
        result = nil
        errorMessage = nil
        hasRecording = false
        recordingDuration = 0
        state = .requestingPermission
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                // Fail early for unsupported words, before opening the microphone.
                _ = try await PhoneticDictionaryService.shared.pronunciations(for: self.word)
                try Task.checkCancellation()
                guard self.generation == token else { return }
                try await self.recorder.startRecording()
                try Task.checkCancellation()
                guard self.generation == token else { return }
                self.state = .recording
                self.operation = nil
            } catch {
                guard self.generation == token else { return }
                self.recorder.discardRecording()
                self.fail(error)
            }
        }
    }

    func stopRecording() {
        guard canStopRecording else { return }
        state = .finishingRecording
        recorder.stopRecording()
        // The recorder delegate supplies the finalized WAV (also at the 10 s limit).
    }

    private func recordingFinished(_ outcome: Result<URL, Error>) {
        guard state == .recording || state == .finishingRecording else { return }
        switch outcome {
        case .failure(let error):
            hasRecording = false
            recordingDuration = 0
            fail(error)
        case .success(let url):
            hasRecording = true
            recordingDuration = recorder.duration
            analyze(url: url)
        }
    }

    private func analyze(url: URL) {
        state = .analyzing
        let token = generation
        let target = word
        operation = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                let start = Date()
                try Task.checkCancellation()
                let audio = try AudioPreprocessor().prepare(url: url)
                try Task.checkCancellation()
                let references = try await PhoneticDictionaryService.shared.pronunciations(for: target)
                let recognition = try await PhonemeRecognitionService.shared.recognize(audio)
                try Task.checkCancellation()
                let evaluation = try PronunciationScoringService().evaluate(recognition, references: references)
                try Task.checkCancellation()
                return PronunciationResult(word: target, evaluation: evaluation,
                                           analysisDuration: Date().timeIntervalSince(start))
            }
            do {
                let output = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard let self, self.generation == token, !Task.isCancelled else { return }
                self.result = output
                self.errorMessage = nil
                self.state = .completed
                self.operation = nil
            } catch {
                guard let self, self.generation == token else { return }
                self.fail(error)
            }
        }
    }

    func playRecording() {
        guard canPlayRecording else { return }
        errorMessage = nil
        do {
            try recorder.playRecording()
            state = .playing
        } catch { fail(error) }
    }

    func stopPlayback() {
        guard state == .playing else { return }
        recorder.stopPlayback()
        state = result == nil ? .idle : .completed
    }

    func dismissError() {
        errorMessage = nil
        if state == .failed { state = result == nil ? .idle : .completed }
    }

    /// Call on disappearance or to reset the session. Invalidates late results.
    func reset() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        recorder.discardRecording()
        result = nil
        errorMessage = nil
        hasRecording = false
        recordingDuration = 0
        state = .idle
    }

    private func fail(_ error: Error) {
        operation = nil
        if error is CancellationError {
            state = .idle
            return
        }
        errorMessage = error.localizedDescription
        state = .failed
    }
}
