import AVFoundation

@MainActor final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [String: AVAudioPlayer] = [:]
    func play(_ name: String) { guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else { return }; do { let player = try AVAudioPlayer(contentsOf: url); players[name] = player; player.play() } catch { } }
}
