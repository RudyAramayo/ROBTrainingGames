import SwiftUI

struct RobotVoicePanel: View {
    @Bindable var voice: RobotVoice
    let game: GameSession
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Label(voice.status, systemImage: voice.isListening ? "waveform" : "cpu").font(.caption.bold()); Spacer(); Toggle("Auto", isOn: $voice.automaticComments).labelsHidden(); Button { voice.toggleListening(game: game) } label: { Label(voice.isListening ? "Send" : "Talk to ROB", systemImage: voice.isListening ? "stop.circle.fill" : "mic.fill") }.buttonStyle(.borderedProminent).tint(voice.isListening ? .red : .cyan).disabled(voice.isThinking) }
            if !voice.transcript.isEmpty { Text("You: \(voice.transcript)").font(.caption).foregroundStyle(.secondary).lineLimit(compact ? 1 : 3) }
            Text(voice.isThinking ? "ROB is assembling a thought without dropping any bolts…" : voice.answer).font(compact ? .caption : .callout).lineLimit(compact ? 2 : 5)
        }
        .padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .onChange(of: game.situationCount) { _, count in if count > 0 { voice.react(to: game.lastSituation, game: game) } }
    }
}
