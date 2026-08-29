import SwiftUI

struct VisionBattleWorkshop: View {
    @Bindable var battle: ROBBattleCoordinator
    @State private var controller = ROBBattleControllerInput()
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if battle.phase == .playing {
                ROBBattleRealityScene(battle: battle, arenaScale: 0.075, arenaPosition: [0, -0.32, 0])
                    .ornament(attachmentAnchor: .scene(.top)) {
                        battleStatus.padding(12)
                    }
                    .ornament(attachmentAnchor: .scene(.bottom)) {
                        VisionBattleControls(battle: battle).frame(width: 760).padding(12)
                    }
            } else {
                lobby
                    .padding(28)
                    .glassBackgroundEffect()
            }
        }
        .robBattleKeyboardControls(battle: battle)
        .onAppear { battle.startDiscovery(); controller.start(battle: battle) }
        .onDisappear { controller.stop(); battle.stopDrive() }
        .onReceive(timer) { _ in battle.tick(1.0 / 30.0) }
    }

    private var lobby: some View {
        ScrollView {
            VStack(spacing: 18) {
                Label("AutoNet Robot Battle", systemImage: "dot.radiowaves.left.and.right")
                    .font(.largeTitle.bold()).foregroundStyle(.cyan)
                Text("Nearby iPhone, iPad, and Vision Pro simulators join automatically. Up to four pilots battle in the same voted arena.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                HStack {
                    Label(battle.networkPlayerDescription, systemImage: "person.3.fill")
                    if battle.isHost { Label("Host", systemImage: "crown.fill").foregroundStyle(.yellow) }
                }
                .font(.headline)
                ForEach(battle.orderedPlayers) { player in
                    HStack {
                        Circle().fill(playerColor(player.colorIndex)).frame(width: 12, height: 12)
                        Text(player.name)
                        if player.id == battle.localIdentity.id { Text("YOU").font(.caption2.bold()).foregroundStyle(.cyan) }
                        Spacer()
                        if let vote = battle.votes[player.id] { Text(vote.name).foregroundStyle(.secondary) }
                    }
                }
                Divider()
                if battle.phase == .voting {
                    Text("Vote for the next arena").font(.title2.bold())
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())]) {
                        ForEach(ROBBattleArena.allCases) { arena in
                            Button { battle.vote(for: arena) } label: {
                                VStack(spacing: 8) {
                                    Label(arena.name, systemImage: arena.symbol).font(.headline)
                                    Text(arena.summary).font(.caption).foregroundStyle(.secondary)
                                    Text("\(battle.votes(for: arena)) votes").monospacedDigit()
                                    if battle.selectedVote == arena { Image(systemName: "checkmark.circle.fill").foregroundStyle(.cyan) }
                                }
                                .frame(maxWidth: .infinity, minHeight: 118)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if battle.isHost {
                        Button("Start Voted Arena", systemImage: "play.fill") { battle.startMatch() }
                            .buttonStyle(.borderedProminent).tint(.cyan)
                            .disabled(!battle.canStartMatch)
                    } else if battle.playerCount > 1 {
                        Text("The host starts after every pilot votes.").foregroundStyle(.secondary)
                    }
                } else {
                    Label(battle.winnerName.map { "\($0) wins!" } ?? "Match complete", systemImage: "trophy.fill")
                        .font(.title.bold()).foregroundStyle(.yellow)
                    scoreRows
                    if battle.isHost {
                        Button("Vote on the Next Arena", systemImage: "checkmark.bubble.fill") { battle.openNextArenaVote() }
                            .buttonStyle(.borderedProminent).tint(.cyan)
                    } else {
                        Text("Waiting for the host to open the next vote.").foregroundStyle(.secondary)
                    }
                }
                Text(battle.statusMessage).font(.callout.bold()).foregroundStyle(.cyan)
            }
            .frame(maxWidth: 720)
        }
    }

    private var battleStatus: some View {
        HStack(spacing: 16) {
            Label(battle.arena.name, systemImage: battle.arena.symbol)
            Label(timeText, systemImage: "timer").monospacedDigit()
            Label("\(battle.localRobot.health) H", systemImage: "heart.fill").foregroundStyle(.red)
            Label("\(battle.localRobot.shields) S", systemImage: "shield.fill").foregroundStyle(.cyan)
            Label("\(battle.localScore) KOs", systemImage: "scope").foregroundStyle(.yellow)
        }
        .font(.headline)
        .glassBackgroundEffect()
    }

    private var scoreRows: some View {
        VStack {
            ForEach(battle.orderedPlayers) { player in
                HStack {
                    Text(player.name); Spacer()
                    Text("\(battle.scores[player.id, default: 0]) KOs · \(battle.deaths[player.id, default: 0]) downs")
                        .monospacedDigit()
                }
            }
        }
    }

    private var timeText: String {
        let seconds = max(0, Int(ceil(battle.remainingTime)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func playerColor(_ index: Int) -> Color { [.cyan, .orange, .green, .pink][index % 4] }
}

private struct VisionBattleControls: View {
    @Bindable var battle: ROBBattleCoordinator
    @State private var left = 0.0
    @State private var right = 0.0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack { Text("LEFT TREAD").font(.caption.bold()); Slider(value: treadBinding(isLeft: true), in: -1...1) }.frame(width: 210)
                Button("SLASH", systemImage: "bolt.fill") { battle.saberAttack() }
                    .buttonStyle(.borderedProminent).tint(.pink)
                Button("FIRE", systemImage: "scope") { battle.fireLaser() }
                    .buttonStyle(.borderedProminent).tint(.cyan)
                VStack { Text("RIGHT TREAD").font(.caption.bold()); Slider(value: treadBinding(isLeft: false), in: -1...1) }.frame(width: 210)
            }
            if !battle.localRobot.isAlive {
                Text("REBUILDING \(Int(ceil(battle.localRobot.respawnRemaining)))")
                    .font(.headline).foregroundStyle(.orange).monospacedDigit()
            } else if let controller = battle.connectedControllerName {
                Label(controller, systemImage: "gamecontroller.fill").font(.caption)
            } else {
                Text("Connect a game controller, use WASD, or drag both tread sliders.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .glassBackgroundEffect()
        .onDisappear { battle.stopDrive() }
    }

    private func treadBinding(isLeft: Bool) -> Binding<Double> {
        Binding {
            isLeft ? left : right
        } set: { value in
            if isLeft { left = value } else { right = value }
            battle.setTreads(left: left, right: right)
        }
    }
}
