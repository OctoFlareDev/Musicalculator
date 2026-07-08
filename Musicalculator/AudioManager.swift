import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioManager: ObservableObject {
    @Published private(set) var isPlayingSequence = false

    private final class Voice {
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()
    }

    private let engine = AVAudioEngine()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var voices: [Voice] = []
    private var nextVoiceIndex = 0
    private var sequenceTask: Task<Void, Never>?

    private static let soundNames = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "+", "-", "mul", "div", "="
    ]

    init() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setPreferredIOBufferDuration(0.005)
        try? session.setActive(true)
        #endif

        Self.soundNames.forEach { _ = audioBuffer(named: $0) }
        guard let format = buffers["1"]?.format else { return }

        for _ in 0..<12 {
            let voice = Voice()
            voice.pitch.overlap = 8
            engine.attach(voice.player)
            engine.attach(voice.pitch)
            engine.connect(voice.player, to: voice.pitch, format: format)
            engine.connect(voice.pitch, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        engine.prepare()
        try? engine.start()
    }

    func playSound(named name: String, semitoneUp: Bool = false) {
        guard let buffer = buffers[name] ?? audioBuffer(named: name), !voices.isEmpty else { return }
        let voice = voices[nextVoiceIndex]
        nextVoiceIndex = (nextVoiceIndex + 1) % voices.count
        voice.player.stop()
        voice.pitch.pitch = semitoneUp ? 100 : 0

        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                return
            }
        }

        voice.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        voice.player.play()
    }

    func toggleSequence(
        _ tokens: [MusicToken],
        from startIndex: Int = 0,
        onCursorChange: @escaping @MainActor (Int) -> Void = { _ in }
    ) {
        if isPlayingSequence {
            stopSequence()
            return
        }
        let safeStart = min(max(startIndex, 0), tokens.count)
        guard safeStart < tokens.count else { return }
        isPlayingSequence = true
        sequenceTask = Task { [weak self] in
            let initialTempo = tokens[..<safeStart]
                .reversed()
                .first(where: { $0.kind == .tempo })?
                .tempoBPM ?? 90
            var quarterNote = MusicTiming.quarterNoteNanoseconds(bpm: initialTempo)

            for index in safeStart..<tokens.count {
                guard !Task.isCancelled else { break }
                let token = tokens[index]
                onCursorChange(index)
                switch token.kind {
                case .note, .symbol:
                    if let soundName = token.soundName {
                        self?.playSound(named: soundName, semitoneUp: token.isSharp)
                    }
                    try? await Task.sleep(nanoseconds: quarterNote)
                case .rest:
                    try? await Task.sleep(nanoseconds: quarterNote * UInt64(max(token.restCount, 1)))
                case .tempo:
                    quarterNote = MusicTiming.quarterNoteNanoseconds(bpm: token.tempoBPM ?? 90)
                }
            }
            guard !Task.isCancelled else { return }
            onCursorChange(tokens.count)
            self?.isPlayingSequence = false
        }
    }

    func stopSequence() {
        sequenceTask?.cancel()
        sequenceTask = nil
        isPlayingSequence = false
    }

    private func audioBuffer(named name: String) -> AVAudioPCMBuffer? {
        if let cached = buffers[name] { return cached }
        guard let url = soundURL(named: name),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              ) else { return nil }
        do {
            try file.read(into: buffer)
            buffers[name] = buffer
            return buffer
        } catch {
            return nil
        }
    }

    private func soundURL(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
    }
}
