import AVFoundation

final class TechnoMusicEngine: @unchecked Sendable {
    static let shared = TechnoMusicEngine()
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var phase = 0.0
    private var noise: UInt64 = 0x524F42544543484E
    private var sampleIndex: Int64 = 0
    private var level = 0
    private(set) var isPlaying = false

    func start(level: Int) {
        self.level = level
        guard !isPlaying else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = self.nextSample(sampleRate: format.sampleRate)
                for buffer in buffers { buffer.mData!.assumingMemoryBound(to: Float.self)[frame] = sample }
            }
            return noErr
        }
        source = node; engine.attach(node); engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.28
        do { try engine.start(); isPlaying = true } catch { engine.detach(node); source = nil }
    }

    func setLevel(_ level: Int) { self.level = level }
    func stop() { guard isPlaying else { return }; engine.stop(); if let source { engine.detach(source) }; source = nil; isPlaying = false }

    private func nextSample(sampleRate: Double) -> Float {
        let bpm = 126.0 + Double(level) * 1.4, samplesPerStep = sampleRate * 60 / bpm / 4
        let step = Int(Double(sampleIndex) / samplesPerStep), within = Double(sampleIndex % Int64(samplesPerStep)) / samplesPerStep
        let notes = [36, 36, 43, 36, 39, 36, 46, 43, 36, 48, 43, 39, 36, 43, 46, 34]
        let frequency = 440 * pow(2, Double(notes[step % notes.count] - 69) / 12)
        phase += frequency / sampleRate; if phase >= 1 { phase -= 1 }
        let bassEnvelope = exp(-within * 7), bass = (phase * 2 - 1) * bassEnvelope * 0.16
        let quarter = step % 4, kickEnvelope = quarter == 0 ? exp(-within * 22) : 0
        let kick = sin(2 * .pi * (48 + 80 * kickEnvelope) * Double(sampleIndex) / sampleRate) * kickEnvelope * 0.42
        noise = noise &* 6_364_136_223_846_793_005 &+ 1
        let white = Double(Int64(bitPattern: noise)) / Double(Int64.max)
        let hat = (step % 2 == 1 ? white * exp(-within * 45) * 0.055 : 0)
        sampleIndex += 1
        return Float(max(-0.8, min(0.8, kick + bass + hat)))
    }
}
