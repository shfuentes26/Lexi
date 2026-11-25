//
//  PronunciationView.swift
//  PersonalEnglishDictionary
//
//  Created by Satur Hernandez Fuentes on 11/25/26.
//

import SwiftUI

/// US-English pronunciation practice. Results are experimental and session-only.
@MainActor
struct PronunciationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: PronunciationViewModel

    init(word: String) {
        _vm = State(initialValue: PronunciationViewModel(word: word))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LexiTheme.spacing) {
                VStack(spacing: 8) {
                    Text(vm.word)
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .foregroundStyle(LexiTheme.primaryText)
                        .multilineTextAlignment(.center)
                    Text("🇺🇸 US English")
                        .font(.subheadline)
                        .foregroundStyle(LexiTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

                recordingCard
                if let result = vm.result {
                    resultCard(result)
                    phonemeCard(result)
                    if !result.differences.isEmpty { differencesCard(result) }
                }
                if let message = vm.errorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Unable to complete practice", systemImage: "exclamationmark.circle")
                            .font(.headline).foregroundStyle(LexiTheme.destructive)
                        Text(message).foregroundStyle(LexiTheme.secondaryText)
                        Button("Dismiss") { vm.dismissError() }
                    }
                    .lexiPronunciationCard()
                }
                Label("Private · On-device AI", systemImage: "shield.checkered")
                    .font(.caption).foregroundStyle(LexiTheme.secondaryText)
            }
            .padding(LexiTheme.screenPadding)
        }
        .background(LexiTheme.background.ignoresSafeArea())
        .navigationTitle("Pronunciation Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LexiTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { vm.reset(); dismiss() }
            }
        }
        .tint(LexiTheme.accent)
        .preferredColorScheme(.dark)
        .onDisappear { vm.reset() }
    }

    private var recordingCard: some View {
        VStack(spacing: 16) {
            switch vm.state {
            case .requestingPermission:
                ProgressView("Preparing microphone…")
            case .recording:
                Label("Recording…", systemImage: "waveform")
                    .foregroundStyle(LexiTheme.destructive)
                Button { vm.stopRecording() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(LexiTheme.onAccent)
                        .frame(width: 76, height: 76)
                        .background(LexiTheme.destructive, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop recording and analyze")
                Text("Stop & analyze").font(.headline)
            case .finishingRecording:
                ProgressView("Preparing audio…")
            case .analyzing:
                ProgressView("Analyzing pronunciation…")
                Text("Running the phoneme model on your device.")
                    .font(.caption).foregroundStyle(LexiTheme.secondaryText)
                Button("Cancel analysis") { vm.reset() }
            case .playing:
                Label("Playing your recording…", systemImage: "speaker.wave.2.fill")
                Button("Stop playback") { vm.stopPlayback() }
            case .idle, .completed, .failed:
                Text("Pronounce the word clearly and naturally.")
                    .foregroundStyle(LexiTheme.secondaryText)
                Button { vm.startRecording() } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(LexiTheme.onAccent)
                        .frame(width: 84, height: 84)
                        .background(LexiTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!vm.canRecord)
                .accessibilityLabel(vm.hasRecording ? "Record again" : "Start recording")
                Text(vm.hasRecording ? "Try again" : "Tap to record").font(.headline)
                Text("Maximum recording: 10 seconds")
                    .font(.caption).foregroundStyle(LexiTheme.secondaryText)
                if vm.hasRecording {
                    Button { vm.playRecording() } label: {
                        Label("Listen to your recording", systemImage: "play.circle")
                    }
                    .disabled(!vm.canPlayRecording)
                }
            }
            if vm.state == .recording || vm.state == .requestingPermission {
                Button("Cancel") { vm.reset() }.font(.subheadline)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(LexiTheme.primaryText)
        .lexiPronunciationCard()
    }

    private func resultCard(_ result: PronunciationResult) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(LexiTheme.border, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(min(100, max(0, result.score))) / 100)
                    .stroke(scoreColor(result.score), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(result.score)").font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(LexiTheme.primaryText)
                    Text("/ 100").font(.subheadline).foregroundStyle(LexiTheme.secondaryText)
                }
            }
            .frame(width: 142, height: 142)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Experimental pronunciation score: \(result.score) out of 100")
            Text("Experimental pronunciation score").font(.headline)
            Text("An estimate of acoustic and phoneme matching, not a calibrated accuracy percentage.")
                .font(.caption).foregroundStyle(LexiTheme.secondaryText)
            HStack(spacing: 12) {
                metric("Acoustic", score: result.acousticScore)
                metric("Sequence", score: result.sequenceScore)
            }
            Divider().overlay(LexiTheme.border)
            VStack(alignment: .leading, spacing: 6) {
                Text("Expected pronunciation").font(.caption).foregroundStyle(LexiTheme.secondaryText)
                Text("/\(result.referenceIPA)/").font(.title3)
                Text("Detected pronunciation").font(.caption).foregroundStyle(LexiTheme.secondaryText)
                    .padding(.top, 6)
                Text(result.recognizedIPA.isEmpty ? "No phonemes detected" : result.recognizedIPA).font(.title3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let seconds = result.analysisDuration {
                Text("Analyzed on device in \(seconds.formatted(.number.precision(.fractionLength(2)))) s")
                    .font(.caption).foregroundStyle(LexiTheme.secondaryText)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(LexiTheme.primaryText)
        .lexiPronunciationCard()
    }

    private func metric(_ title: String, score: Int) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(LexiTheme.secondaryText)
            Text("\(score)/100").font(.headline).foregroundStyle(scoreColor(score))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(LexiTheme.background, in: RoundedRectangle(cornerRadius: LexiTheme.smallCornerRadius))
    }

    private func phonemeCard(_ result: PronunciationResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Phoneme analysis").font(.headline)
            ForEach(result.phonemes) { item in
                HStack(spacing: 12) {
                    Text(item.phoneme).font(.title3.weight(.semibold))
                        .frame(minWidth: 36, minHeight: 36)
                    ProgressView(value: Double(min(100, max(0, item.score))), total: 100)
                        .tint(scoreColor(item.score))
                    Text("\(item.score)/100").font(.caption.monospacedDigit())
                        .foregroundStyle(scoreColor(item.score))
                }
                .accessibilityElement(children: .combine)
            }
            if let weakest = result.weakestPhoneme {
                Label("Lowest estimated score: /\(weakest.phoneme)/", systemImage: "lightbulb")
                    .font(.subheadline).foregroundStyle(LexiTheme.favorite)
            }
        }
        .foregroundStyle(LexiTheme.primaryText)
        .lexiPronunciationCard()
    }

    private func differencesCard(_ result: PronunciationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Possible pronunciation differences").font(.headline)
            ForEach(result.differences) { difference in
                VStack(alignment: .leading, spacing: 4) {
                    Text(difference.kind.rawValue.capitalized).font(.subheadline.weight(.semibold))
                        .foregroundStyle(LexiTheme.favorite)
                    Text("Expected: \(difference.expected ?? "—") · Detected: \(difference.detected ?? "—")")
                        .font(.subheadline)
                }
            }
            Text("Recognition differences may also reflect accent variation or model errors.")
                .font(.caption).foregroundStyle(LexiTheme.secondaryText)
        }
        .foregroundStyle(LexiTheme.primaryText)
        .lexiPronunciationCard()
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return LexiTheme.accent }
        if score >= 60 { return LexiTheme.favorite }
        return LexiTheme.destructive
    }
}

private extension View {
    func lexiPronunciationCard() -> some View {
        self.frame(maxWidth: .infinity)
            .padding(20)
            .background(LexiTheme.surface, in: RoundedRectangle(cornerRadius: LexiTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LexiTheme.cornerRadius)
                    .strokeBorder(LexiTheme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}
