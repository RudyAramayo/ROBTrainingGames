import AVFoundation

@MainActor final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [String: AVAudioPlayer] = [:]
    private let engine = AVAudioEngine()
    private let effectNode = AVAudioPlayerNode()
    private let speech = AVSpeechSynthesizer()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        engine.attach(effectNode)
        engine.connect(effectNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.48
    }

    func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else { return }
        do { let player = try AVAudioPlayer(contentsOf: url); players[name] = player; player.play() } catch { }
    }

    func playEnemyAttack(_ kind: TrainingEnemyKind) {
        playProceduralEffect(kind)
        guard kind == .fax, !speech.isSpeaking else { return }
        let warning = AVSpeechUtterance(string: "Exterminate!")
        warning.voice = AVSpeechSynthesisVoice(language: "en-US")
        warning.rate = 0.38; warning.pitchMultiplier = 0.52; warning.volume = 0.82
        speech.speak(warning)
    }

    private func playProceduralEffect(_ kind: TrainingEnemyKind) {
        guard let buffer = makeBuffer(kind) else { return }
        do { if !engine.isRunning { try engine.start() }; effectNode.scheduleBuffer(buffer, at: nil, options: .interrupts); effectNode.play() } catch { }
    }

    private func makeBuffer(_ kind: TrainingEnemyKind) -> AVAudioPCMBuffer? {
        let duration = kind == .spider ? 0.28 : 0.36
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var noise: UInt64 = 0x524F42534F554E44
        for frame in 0..<Int(frames) {
            let time = Double(frame) / format.sampleRate
            noise = noise &* 6_364_136_223_846_793_005 &+ 1
            let white = Double(Int64(bitPattern: noise)) / Double(Int64.max)
            if kind == .spider {
                let pulse = time.truncatingRemainder(dividingBy: 0.065), gate = pulse < 0.032 ? exp(-pulse * 70) : 0
                let step = Double(Int(time / 0.065) % 4), carrier = sin(2 * .pi * (1_100 + step * 260) * time)
                samples[frame] = Float((carrier * 0.55 + white * 0.45) * gate * 0.34)
            } else {
                let frequencies = [720.0, 1_280, 860, 1_640, 620]
                let step = min(frequencies.count - 1, Int(time / 0.065)), carrier = sin(2 * .pi * frequencies[step] * time)
                let edge = min(1, time * 45) * min(1, (duration - time) * 28)
                samples[frame] = Float((carrier * 0.72 + white * 0.28) * edge * 0.3)
            }
        }
        return buffer
    }
}
