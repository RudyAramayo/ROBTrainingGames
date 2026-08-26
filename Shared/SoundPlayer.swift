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
        if kind == .spider { playSpider(.lunge) } else { playProceduralEffect(kind) }
        guard kind == .fax, !speech.isSpeaking else { return }
        let warning = AVSpeechUtterance(string: "Exterminate!")
        warning.voice = AVSpeechSynthesisVoice(language: "en-US")
        warning.rate = 0.38; warning.pitchMultiplier = 0.52; warning.volume = 0.82
        speech.speak(warning)
    }

    func playSpider(_ cue: SpiderSoundCue) {
        guard let buffer = makeSpiderBuffer(cue) else { return }
        playProceduralBuffer(buffer)
    }

    func playLaser(charge: Double) {
        let clampedCharge = min(1, max(0, charge))
        if clampedCharge < 0.12 { play("laser"); return }
        guard let buffer = makeLaserBuffer(clampedCharge) else { return }
        do { if !engine.isRunning { try engine.start() }; effectNode.scheduleBuffer(buffer, at: nil, options: .interrupts); effectNode.play() } catch { }
    }

    private func playProceduralEffect(_ kind: TrainingEnemyKind) {
        guard let buffer = makeBuffer(kind) else { return }
        playProceduralBuffer(buffer)
    }

    private func playProceduralBuffer(_ buffer: AVAudioPCMBuffer) {
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
            let frequencies = [720.0, 1_280, 860, 1_640, 620]
            let step = min(frequencies.count - 1, Int(time / 0.065)), carrier = sin(2 * .pi * frequencies[step] * time)
            let edge = min(1, time * 45) * min(1, (duration - time) * 28)
            samples[frame] = Float((carrier * 0.72 + white * 0.28) * edge * 0.3)
        }
        return buffer
    }

    private func makeSpiderBuffer(_ cue: SpiderSoundCue) -> AVAudioPCMBuffer? {
        let duration: Double = switch cue {
        case .skitter: 0.25
        case .lunge: 0.34
        case .impact: 0.24
        case .shutdown: 0.48
        }
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var noise: UInt64 = 0x535049444552424F
        for frame in 0..<Int(frames) {
            let time = Double(frame) / format.sampleRate
            noise = noise &* 6_364_136_223_846_793_005 &+ 1
            let white = Double(Int64(bitPattern: noise)) / Double(Int64.max)
            switch cue {
            case .skitter:
                let pulse = time.truncatingRemainder(dividingBy: 0.038), gate = pulse < 0.015 ? exp(-pulse * 150) : 0
                let step = Double(Int(time / 0.038) % 3), carrier = sin(2 * .pi * (1_720 + step * 310) * time)
                samples[frame] = Float((carrier * 0.42 + white * 0.58) * gate * 0.28)
            case .lunge:
                let pulse = time.truncatingRemainder(dividingBy: 0.058), gate = pulse < 0.035 ? exp(-pulse * 62) : 0
                let step = Double(Int(time / 0.058) % 5), carrier = sin(2 * .pi * (980 + step * 310) * time)
                samples[frame] = Float((carrier * 0.58 + white * 0.42) * gate * 0.38)
            case .impact:
                let fall = exp(-time * 15), carrier = sin(2 * .pi * (520 - time * 720) * time)
                samples[frame] = Float((carrier * 0.42 + white * 0.58) * fall * 0.42)
            case .shutdown:
                let fall = exp(-time * 4.6), pitch = max(180, 1_180 - time * 1_850), carrier = sin(2 * .pi * pitch * time)
                samples[frame] = Float((carrier * 0.62 + white * 0.38) * fall * 0.34)
            }
        }
        return buffer
    }

    private func makeLaserBuffer(_ charge: Double) -> AVAudioPCMBuffer? {
        let duration = 0.16 + charge * 0.34
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var noise: UInt64 = 0x4741544C494E4752
        for frame in 0..<Int(frames) {
            let time = Double(frame) / format.sampleRate
            noise = noise &* 2_862_933_555_777_941_757 &+ 3_037_000_493
            let white = Double(Int64(bitPattern: noise)) / Double(Int64.max)
            let pitch = 310 - charge * 190, fall = exp(-time * (5.5 - charge * 2.4))
            let carrier = sin(2 * .pi * pitch * time) + sin(2 * .pi * pitch * 0.49 * time) * (0.45 + charge * 0.25)
            let crack = white * exp(-time * 32) * 0.38
            samples[frame] = Float((carrier * 0.27 + crack) * fall * (0.72 + charge * 0.28))
        }
        return buffer
    }
}
