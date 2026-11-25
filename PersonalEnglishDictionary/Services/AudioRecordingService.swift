//
//  AudioRecordingService.swift
//  PersonalEnglishDictionary
//
//  Created by Satur Hernandez Fuentes on 11/25/26.
//

import AVFoundation
import Foundation

@MainActor
final class AudioRecordingService: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    enum RecordingError: LocalizedError {
        case permissionDenied, busy, recordingFailed, noRecording, playbackFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Allow microphone access in Settings to practice pronunciation."
            case .busy: return "Another audio operation is in progress."
            case .recordingFailed: return "Couldn't record audio. Please try again."
            case .noRecording: return "Record your pronunciation first."
            case .playbackFailed: return "Couldn't play the recording."
            }
        }
    }

    private let session = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var requestingPermission = false
    private var ownsAudioSession = false
    private(set) var recordingURL: URL?
    private(set) var duration: TimeInterval = 0
    var onRecordingFinished: ((Result<URL, Error>) -> Void)?
    var onPlaybackFinished: (() -> Void)?

    var isRecording: Bool { recorder?.isRecording == true }
    var isPlaying: Bool { player?.isPlaying == true }
    static let maximumDuration: TimeInterval = 10

    func startRecording() async throws {
        guard !requestingPermission, recorder == nil, player == nil else { throw RecordingError.busy }
        requestingPermission = true
        defer { requestingPermission = false }
        guard await AVAudioApplication.requestRecordPermission() else { throw RecordingError.permissionDenied }
        try Task.checkCancellation()
        discardRecording()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lexi-\(UUID().uuidString).wav")
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            ownsAudioSession = true
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16_000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            recordingURL = url
            recorder = newRecorder
            guard newRecorder.prepareToRecord(), newRecorder.record(forDuration: Self.maximumDuration) else {
                throw RecordingError.recordingFailed
            }
        } catch {
            recorder?.delegate = nil
            recorder?.stop()
            recorder = nil
            recordingURL = nil
            try? FileManager.default.removeItem(at: url)
            deactivateSession()
            throw error
        }
    }

    func stopRecording() {
        guard let recorder else { return }
        duration = recorder.currentTime
        recorder.stop()
    }

    func playRecording() throws {
        guard !requestingPermission, recorder == nil, player == nil else { throw RecordingError.busy }
        guard let url = recordingURL, duration > 0 else { throw RecordingError.noRecording }
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            ownsAudioSession = true
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            player = newPlayer
            guard newPlayer.prepareToPlay(), newPlayer.play() else { throw RecordingError.playbackFailed }
        } catch {
            player = nil
            deactivateSession()
            throw error
        }
    }

    func stopPlayback() {
        guard let player else { return }
        player.delegate = nil
        player.stop()
        self.player = nil
        deactivateSession()
        onPlaybackFinished?()
    }

    func discardRecording() {
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        player?.delegate = nil
        player?.stop()
        player = nil
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        duration = 0
        deactivateSession()
    }

    private func deactivateSession() {
        guard ownsAudioSession else { return }
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        ownsAudioSession = false
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor [weak self] in
            guard let self, self.recordingURL == url, self.recorder != nil else { return }
            self.recorder = nil
            self.deactivateSession()
            if flag, let file = try? AVAudioFile(forReading: url), file.length > 0 {
                self.duration = Double(file.length) / file.processingFormat.sampleRate
                self.onRecordingFinished?(.success(url))
            } else {
                self.discardRecording()
                self.onRecordingFinished?(.failure(RecordingError.recordingFailed))
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let identity = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == identity else { return }
            self.player = nil
            self.deactivateSession()
            self.onPlaybackFinished?()
        }
    }
}
