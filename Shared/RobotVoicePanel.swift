import SwiftUI

struct RobotVoicePanel: View {
    @Bindable var voice: RobotVoice
    let game: GameSession
    var compact = false
    var observesGameEvents = true
    var body: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Label(voice.isListening ? "Listening" : "ROB voice", systemImage: voice.isListening ? "waveform" : "cpu")
                            .font(.caption.bold())
                        Spacer(minLength: 4)
                        Toggle("Automatic ROB comments", isOn: $voice.automaticComments).labelsHidden()
                        Button { voice.toggleListening(game: game) } label: {
                            Image(systemName: voice.isListening ? "stop.circle.fill" : voice.isPreparingAudio ? "ellipsis.circle" : "mic.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(voice.isListening ? .red : .cyan)
                        .disabled(voice.isThinking || voice.isPreparingAudio)
                        .accessibilityLabel(voice.isListening ? "Send to ROB" : "Talk to ROB")
                    }
                    Text(compactAnswer).font(.caption).lineLimit(1)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Label(voice.status, systemImage: voice.isListening ? "waveform" : "cpu").font(.caption.bold()); Spacer(); Toggle("Auto", isOn: $voice.automaticComments).labelsHidden(); Button { voice.toggleListening(game: game) } label: { Label(voice.isListening ? "Send" : voice.isPreparingAudio ? "Preparing…" : "Talk to ROB", systemImage: voice.isListening ? "stop.circle.fill" : voice.isPreparingAudio ? "ellipsis.circle" : "mic.fill") }.buttonStyle(.borderedProminent).tint(voice.isListening ? .red : .cyan).disabled(voice.isThinking || voice.isPreparingAudio) }
                    if !voice.transcript.isEmpty { Text("You: \(voice.transcript)").font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                    Text(voice.isThinking ? "ROB is assembling a thought without dropping any bolts…" : voice.answer).font(.callout).lineLimit(5)
                }
            }
        }
        .padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .onChange(of: game.situationCount) { _, count in if observesGameEvents && count > 0 { voice.react(to: game.lastSituation, game: game) } }
    }

    private var compactAnswer: String {
        if !voice.transcript.isEmpty { return "You: \(voice.transcript)" }
        if voice.isThinking { return "ROB is assembling a thought…" }
        return voice.answer
    }
}
