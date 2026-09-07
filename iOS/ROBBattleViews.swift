import ARKit
import AVFoundation
import RealityKit
import SwiftUI
import UIKit

struct ROBBattleLaunchView: View {
    @Bindable var battle: ROBBattleCoordinator
    let launchGame: () -> Void
    let launchAR: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.02, blue: 0.12), Color(red: 0.04, green: 0.2, blue: 0.22), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 12) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundStyle(.cyan)
                                .shadow(color: .cyan, radius: 20)
                            Text("AutoNet Robot Battle").font(.largeTitle.bold()).multilineTextAlignment(.center)
                            Text("Nearby ROB Training simulators find each other automatically for encrypted Deathmatch or Capture the Flag battles. Each simulator contributes one pilot and controller.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)

                        ROBBattleLobbyStatus(battle: battle)

                        switch battle.phase {
                        case .voting:
                            modeSelection
                            arenaVoting
                            if battle.isHost {
                                Button { battle.startMatch() } label: {
                                    Label(
                                        battle.allPlayersHaveVoted ? "Start \(battle.mode.name)" : "Waiting for Every Vote",
                                        systemImage: "play.fill"
                                    )
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .controlSize(.large)
                                .disabled(!battle.canStartMatch)
                            } else if battle.playerCount > 1 {
                                Label("Host starts after every pilot votes", systemImage: "hourglass")
                                    .foregroundStyle(.secondary)
                            }
                        case .playing:
                            VStack(spacing: 12) {
                                Text("\(battle.mode.name) · \(battle.arena.name) is live").font(.title2.bold())
                                HStack {
                                    Button(action: launchGame) {
                                        Label("Enter Game View", systemImage: "gamecontroller.fill").frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent).tint(.cyan)
                                    Button(action: launchAR) {
                                        Label("Enter AR View", systemImage: "arkit").frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent).tint(.purple)
                                }
                            }
                            .battleCard()
                        case .results:
                            VStack(spacing: 12) {
                                Label(battle.winnerName.map { "\($0) wins!" } ?? "Match complete", systemImage: "trophy.fill")
                                    .font(.title.bold()).foregroundStyle(.yellow)
                                ROBBattleScoreboard(battle: battle)
                                if battle.isHost {
                                    Button { battle.openNextArenaVote() } label: {
                                        Label("Vote on the Next Arena", systemImage: "checkmark.bubble.fill")
                                    }
                                    .buttonStyle(.borderedProminent).tint(.cyan)
                                } else {
                                    Text("Waiting for the host to open the next vote.").foregroundStyle(.secondary)
                                }
                            }
                            .battleCard()
                        }

                        Text(battle.statusMessage)
                            .font(.callout.bold())
                            .foregroundStyle(.cyan)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .padding(.bottom, 96)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Battle")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { battle.startDiscovery() }
    }

    private var modeSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Game mode", systemImage: battle.mode.symbol).font(.headline)
            Picker(
                "Game mode",
                selection: Binding(get: { battle.mode }, set: { battle.selectMode($0) })
            ) {
                ForEach(ROBBattleMode.allCases) { mode in
                    Label(mode.name, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!battle.isHost)
            Text(battle.mode.summary).font(.caption).foregroundStyle(.secondary)
            if !battle.isHost {
                Text("The host chooses the game mode.").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .battleCard()
    }

    private var arenaVoting: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Vote for the next arena", systemImage: "checkmark.bubble.fill").font(.headline)
            ForEach(ROBBattleArena.allCases) { arena in
                Button { battle.vote(for: arena) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: arena.symbol).font(.title2).frame(width: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(arena.name).font(.headline)
                            Text(arena.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(battle.votes(for: arena))")
                            .font(.title3.bold()).monospacedDigit()
                        Image(systemName: battle.selectedVote == arena ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(battle.selectedVote == arena ? .cyan : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if arena != ROBBattleArena.allCases.last { Divider() }
            }
        }
        .battleCard()
    }
}

struct ROBBattleLobbyStatus: View {
    @Bindable var battle: ROBBattleCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AutoNet nearby lobby", systemImage: "network")
                Spacer()
                Label(battle.mode.name, systemImage: battle.mode.symbol).foregroundStyle(.yellow)
                Text(battle.networkPlayerDescription).monospacedDigit().foregroundStyle(.cyan)
            }
            .font(.headline)
            ForEach(battle.orderedPlayers) { player in
                HStack {
                    Circle()
                        .fill(battleColor(player.colorIndex))
                        .frame(width: 12, height: 12)
                    Text(player.name).lineLimit(1)
                    if player.id == battle.localIdentity.id { Text("YOU").font(.caption2.bold()).foregroundStyle(.cyan) }
                    if player.id == battle.players.keys.min(by: { $0.uuidString < $1.uuidString }) {
                        Image(systemName: "crown.fill").foregroundStyle(.yellow).accessibilityLabel("Host")
                    }
                    Spacer()
                    if let vote = battle.votes[player.id] { Text(vote.name).font(.caption).foregroundStyle(.secondary) }
                }
            }
            if battle.playerCount == 1 {
                Label("Open Battle on another nearby device to join automatically", systemImage: "iphone.radiowaves.left.and.right")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .battleCard()
    }

    private func battleColor(_ index: Int) -> Color {
        [.cyan, .orange, .green, .pink][index % 4]
    }
}

struct ROBBattleScoreboard: View {
    @Bindable var battle: ROBBattleCoordinator

    var body: some View {
        VStack(spacing: 6) {
            ForEach(battle.orderedPlayers) { player in
                HStack {
                    Text(player.name).lineLimit(1)
                    Spacer()
                    if battle.mode == .captureTheFlag {
                        Text("\(battle.captures[player.id, default: 0]) captures").foregroundStyle(.yellow)
                    } else {
                        Text("\(battle.scores[player.id, default: 0]) KOs")
                    }
                    Text("\(battle.deaths[player.id, default: 0]) downs").foregroundStyle(.secondary)
                }
                .font(.subheadline.bold()).monospacedDigit()
            }
        }
    }
}

struct ROBBattleView: View {
    @Bindable var battle: ROBBattleCoordinator
    let onExit: () -> Void
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @State private var controller = ROBBattleControllerInput()

    var body: some View {
        ZStack(alignment: .bottom) {
            ROBBattleRealityScene(battle: battle, includesCamera: true)
                .ignoresSafeArea().background(.black)
            ROBBattlePlayOverlay(battle: battle, onExit: onExit)
        }
        .robBattleKeyboardControls(battle: battle)
        .onAppear { controller.start(battle: battle) }
        .onDisappear { controller.stop(); battle.stopDrive() }
        .onReceive(timer) { _ in battle.tick(1.0 / 30.0) }
    }
}

private struct ROBBattlePlayOverlay: View {
    @Bindable var battle: ROBBattleCoordinator
    let onExit: () -> Void
    @State private var showsBattleDetails = false
    @State private var selectedPlayerID: UUID?

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                VStack(spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Button(action: onExit) {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                                .frame(width: 34, height: 34)
                                .foregroundStyle(.white)
                                .background(.black.opacity(0.16), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Return to battle lobby")

                        ROBBattleCompactScores(battle: battle) { playerID in
                            selectedPlayerID = playerID
                            showsBattleDetails = true
                        }

                        Spacer(minLength: 2)
                        ROBBattleVitals(battle: battle, timeText: timeText)
                    }

                    if let objective = battle.localFlagObjectiveText {
                        Label(objective, systemImage: "flag.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.yellow)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.14), in: Capsule())
                    }

                    Spacer(minLength: 0)

                    if !battle.localRobot.isAlive {
                        Text("REBUILDING \(Int(ceil(battle.localRobot.respawnRemaining)))")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.2), in: Capsule())
                    }

                    ROBBattleTankControls(battle: battle, compact: landscape)
                }
                .padding(.horizontal, landscape ? 10 : 8)
                .padding(.top, 4)
                .padding(.bottom, landscape ? 2 : 6)

                ROBBattleFightIntro(
                    mode: battle.mode,
                    elapsed: ROBBattleCoordinator.matchDuration - battle.remainingTime
                )
            }
        }
        .overlay {
            if battle.phase == .results {
                VStack(spacing: 14) {
                    Image(systemName: "trophy.fill").font(.system(size: 56)).foregroundStyle(.yellow)
                    Text(battle.winnerName.map { "\($0) WINS" } ?? "MATCH COMPLETE").font(.largeTitle.bold())
                    ROBBattleScoreboard(battle: battle)
                    Button("Return to Arena Vote", action: onExit).buttonStyle(.borderedProminent).tint(.cyan)
                }
                .padding(28)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28))
            }
        }
        .fullScreenCover(isPresented: $showsBattleDetails) {
            ROBBattleDetailsView(battle: battle, selectedPlayerID: selectedPlayerID)
        }
    }

    private var timeText: String {
        let seconds = max(0, Int(ceil(battle.remainingTime)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ROBBattleCompactScores: View {
    @Bindable var battle: ROBBattleCoordinator
    let selected: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 5) {
                ForEach(battle.orderedPlayers) { player in
                    Button { selected(player.id) } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(robBattlePlayerColor(player.colorIndex))
                                .frame(width: 7, height: 7)
                            Text(player.name)
                                .lineLimit(1)
                            Text("\(battle.matchScore(for: player.id))")
                                .foregroundStyle(.yellow)
                                .monospacedDigit()
                        }
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .frame(height: 28)
                        .background(.black.opacity(0.13), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(player.name), score \(battle.matchScore(for: player.id)). Show battle details")
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: 460, alignment: .leading)
    }
}

private struct ROBBattleVitals: View {
    @Bindable var battle: ROBBattleCoordinator
    let timeText: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Label(timeText, systemImage: "timer")
                .font(.caption2.bold())
                .monospacedDigit()
            vitalRow(value: battle.localHealthFraction, tint: .red, label: "H \(battle.localRobot.health)")
            vitalRow(value: battle.localShieldFraction, tint: .cyan, label: "S \(battle.localRobot.shields)")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.16)))
    }

    private func vitalRow(value: Double, tint: Color, label: String) -> some View {
        HStack(spacing: 5) {
            ProgressView(value: value)
                .tint(tint)
                .frame(width: 76)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .frame(width: 32, alignment: .trailing)
        }
    }
}

private struct ROBBattleFightIntro: View {
    let mode: ROBBattleMode
    let elapsed: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let title {
            ZStack {
                if let flashColor, !reduceMotion {
                    flashColor
                        .opacity(0.14)
                        .ignoresSafeArea()
                        .blendMode(.screen)
                }
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: title == "FIGHT!" ? 72 : 86, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .red.opacity(0.9), radius: 12)
                        .scaleEffect(scale)
                        .accessibilityAddTraits(.isHeader)
                    Text(mode == .captureTheFlag ? "FIRST TO 3 CAPTURES WINS" : "FIRST TO 5 KNOCKOUTS WINS")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.18), in: Capsule())
                }
                .opacity(opacity)
            }
            .allowsHitTesting(false)
        }
    }

    private var title: String? {
        switch elapsed {
        case 0..<1: "3"
        case 1..<2: "2"
        case 2..<3: "1"
        case 3..<4.5: "FIGHT!"
        default: nil
        }
    }

    private var flashColor: Color? {
        switch elapsed {
        case 3..<3.12: .red
        case 3.3..<3.42: .orange
        default: nil
        }
    }

    private var scale: Double {
        guard !reduceMotion else { return 1 }
        if elapsed < 3 {
            let fraction = elapsed.truncatingRemainder(dividingBy: 1)
            return 1.32 - fraction * 0.32
        }
        let fightElapsed = elapsed - 3
        return 1 + abs(sin(fightElapsed * .pi * 4)) * max(0, 0.22 - fightElapsed * 0.1)
    }

    private var opacity: Double {
        if elapsed < 3 { return max(0.2, 1 - elapsed.truncatingRemainder(dividingBy: 1) * 0.45) }
        return min(1, max(0, (4.5 - elapsed) * 2))
    }
}

private struct ROBBattleTankControls: View {
    @Bindable var battle: ROBBattleCoordinator
    let compact: Bool
    @State private var left = 0.0
    @State private var right = 0.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            HStack(alignment: .bottom, spacing: 5) {
                ROBBattleTreadPad(title: "LEFT", compact: compact) { left = $0; publish() }
                ROBBattleActionButton(title: "SLASH", systemImage: "bolt.fill", tint: .pink, compact: compact) {
                    battle.saberAttack()
                }
            }
            Spacer(minLength: 24)
            HStack(alignment: .bottom, spacing: 5) {
                ROBBattleActionButton(title: "FIRE", systemImage: "scope", tint: .cyan, compact: compact) {
                    battle.fireLaser()
                }
                ROBBattleTreadPad(title: "RIGHT", compact: compact) { right = $0; publish() }
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            if let controller = battle.connectedControllerName {
                Label(controller, systemImage: "gamecontroller.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.12), in: Capsule())
            }
        }
        .onDisappear { left = 0; right = 0; battle.stopDrive() }
    }

    private func publish() { battle.setTreads(left: left, right: right) }
}

private struct ROBBattleActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 18 : 21, weight: .bold))
                    .frame(width: compact ? 42 : 48, height: compact ? 42 : 48)
                    .background(.black.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(tint.opacity(0.7), lineWidth: 1.5))
                    .shadow(color: tint.opacity(0.35), radius: 4)
                Text(title).font(.system(size: 8, weight: .black))
            }
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title.capitalized)
    }
}

private struct ROBBattleTreadPad: View {
    let title: String
    let compact: Bool
    let changed: (Double) -> Void
    @State private var offset: CGFloat = 0

    private var diameter: CGFloat { compact ? 72 : 84 }
    private var travel: CGFloat { diameter * 0.34 }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(.black.opacity(0.07)).overlay(Circle().stroke(.cyan.opacity(0.62), lineWidth: 1.5))
                Capsule().fill(.cyan.opacity(0.14)).frame(width: 4, height: diameter * 0.64)
                Circle()
                    .fill(.cyan.opacity(0.36))
                    .frame(width: diameter * 0.4, height: diameter * 0.4)
                    .overlay(Circle().stroke(.cyan.opacity(0.85)))
                    .offset(y: offset)
                    .shadow(color: .cyan.opacity(0.45), radius: 5)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let demand = max(-1, min(1, Double(-value.translation.height / travel)))
                        offset = -CGFloat(demand) * travel
                        changed(demand)
                    }
                    .onEnded { _ in offset = 0; changed(0) }
            )
            Text(title).font(.system(size: 8, weight: .black))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.capitalized) tread joystick")
    }
}

private struct ROBBattleDetailsView: View {
    @Bindable var battle: ROBBattleCoordinator
    let selectedPlayerID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    let mapSize = min(geometry.size.height - 28, geometry.size.width * 0.58, 560)
                    HStack(spacing: 14) {
                        ROBBattleTacticalMap(battle: battle, selectedPlayerID: selectedPlayerID)
                            .frame(width: mapSize, height: mapSize)
                        VStack(spacing: 12) {
                            battleHeading
                            playerScores
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(14)
                } else {
                    let mapSize = min(geometry.size.width - 28, geometry.size.height * 0.58, 560)
                    VStack(spacing: 12) {
                        battleHeading
                        ROBBattleTacticalMap(battle: battle, selectedPlayerID: selectedPlayerID)
                            .frame(width: mapSize, height: mapSize)
                        playerScores
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Battle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var battleHeading: some View {
        HStack {
            Label(battle.arena.name, systemImage: battle.arena.symbol)
            Spacer()
            Label(battle.mode.name, systemImage: battle.mode.symbol)
        }
        .font(.headline)
        .foregroundStyle(.cyan)
    }

    private var playerScores: some View {
        VStack(spacing: 7) {
            ForEach(battle.orderedPlayers) { player in
                HStack(spacing: 7) {
                    Circle()
                        .fill(robBattlePlayerColor(player.colorIndex))
                        .frame(width: 10, height: 10)
                    Text(player.name).fontWeight(player.id == selectedPlayerID ? .black : .semibold)
                    if player.id == battle.localIdentity.id {
                        Text("YOU").font(.caption2.bold()).foregroundStyle(.cyan)
                    }
                    Spacer()
                    Text(scoreText(for: player.id)).foregroundStyle(.yellow)
                    Text("\(battle.deaths[player.id, default: 0]) downs").foregroundStyle(.secondary)
                }
                .font(.caption)
                .monospacedDigit()
            }
        }
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func scoreText(for playerID: UUID) -> String {
        battle.mode == .captureTheFlag
            ? "\(battle.matchScore(for: playerID)) captures"
            : "\(battle.matchScore(for: playerID)) KOs"
    }
}

private struct ROBBattleTacticalMap: View {
    @Bindable var battle: ROBBattleCoordinator
    let selectedPlayerID: UUID?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.045))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.cyan.opacity(0.55), lineWidth: 2))

                ForEach(battle.arena.barriers.indices, id: \.self) { index in
                    let barrier = battle.arena.barriers[index]
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.cyan.opacity(0.2))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.cyan.opacity(0.45)))
                        .frame(
                            width: mapLength(barrier.width, total: size.width),
                            height: mapLength(barrier.depth, total: size.height)
                        )
                        .position(mapPoint(x: barrier.x, z: barrier.z, size: size))
                }

                ForEach(Array(battle.flags.values)) { flag in
                    if let owner = battle.players[flag.ownerID] {
                        Image(systemName: flag.disposition == .atBase ? "flag.fill" : "flag")
                            .font(.caption.bold())
                            .foregroundStyle(robBattlePlayerColor(owner.colorIndex))
                            .position(mapPoint(for: flag, size: size))
                    }
                }

                ForEach(battle.allRobotStates) { robot in
                    let player = battle.players[robot.id]
                    ZStack {
                        Circle()
                            .fill(robBattlePlayerColor(player?.colorIndex ?? 0))
                            .overlay(
                                Circle().stroke(
                                    robot.id == selectedPlayerID ? Color.white : Color.black.opacity(0.65),
                                    lineWidth: robot.id == selectedPlayerID ? 3 : 1
                                )
                            )
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.black.opacity(0.75))
                            .rotationEffect(.radians(Double(-robot.heading)))
                    }
                    .frame(width: robot.id == selectedPlayerID ? 25 : 20, height: robot.id == selectedPlayerID ? 25 : 20)
                    .opacity(robot.isAlive ? 1 : 0.35)
                    .position(mapPoint(x: robot.x, z: robot.z, size: size))
                    .accessibilityLabel("\(player?.name ?? "Player") on arena map")
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Full arena map with all players")
    }

    private func mapPoint(for flag: ROBBattleFlagState, size: CGSize) -> CGPoint {
        if let carrierID = flag.carrierID,
           let carrier = battle.allRobotStates.first(where: { $0.id == carrierID }) {
            return mapPoint(x: carrier.x, z: carrier.z, size: size)
        }
        return mapPoint(x: flag.x, z: flag.z, size: size)
    }

    private func mapPoint(x: Float, z: Float, size: CGSize) -> CGPoint {
        let extent = CGFloat(ROBBattleCoordinator.arenaHalfExtent)
        return CGPoint(
            x: (CGFloat(x) + extent) / (extent * 2) * size.width,
            y: (CGFloat(z) + extent) / (extent * 2) * size.height
        )
    }

    private func mapLength(_ length: Float, total: CGFloat) -> CGFloat {
        CGFloat(length) / (CGFloat(ROBBattleCoordinator.arenaHalfExtent) * 2) * total
    }
}

private func robBattlePlayerColor(_ index: Int) -> Color {
    switch index % 4 {
    case 0: .cyan
    case 1: .orange
    case 2: .green
    default: .pink
    }
}

private enum ROBBattleCameraAccess: Equatable { case checking, authorized, denied, unsupported }

struct ROBARBattleView: View {
    @Bindable var battle: ROBBattleCoordinator
    let onExit: () -> Void
    @State private var cameraAccess = ROBBattleCameraAccess.checking
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @State private var controller = ROBBattleControllerInput()
    @State private var placementID = UUID()

    var body: some View {
        ZStack(alignment: .bottom) {
            switch cameraAccess {
            case .authorized:
                ROBBattleARContainer(battle: battle).id(placementID).ignoresSafeArea()
                ROBBattlePlayOverlay(battle: battle, onExit: onExit)
            case .checking:
                ProgressView("Preparing AR battle…")
            case .denied:
                ContentUnavailableView("Camera access is off", systemImage: "camera.fill", description: Text("Enable camera access in Settings to place the battle arena."))
            case .unsupported:
                ContentUnavailableView("AR is unavailable", systemImage: "arkit", description: Text("This device does not support world tracking."))
            }
        }
        .overlay(alignment: .topTrailing) {
            if cameraAccess == .authorized {
                Button { placementID = UUID() } label: { Label("Place Again", systemImage: "viewfinder") }
                    .padding().buttonStyle(.borderedProminent).tint(.purple)
            }
        }
        .background(.black)
        .robBattleKeyboardControls(battle: battle)
        .task { await requestCamera() }
        .onAppear { controller.start(battle: battle) }
        .onDisappear { controller.stop(); battle.stopDrive() }
        .onReceive(timer) { _ in if cameraAccess == .authorized { battle.tick(1.0 / 30.0) } }
    }

    private func requestCamera() async {
        guard ARWorldTrackingConfiguration.isSupported else { cameraAccess = .unsupported; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraAccess = .authorized
        case .notDetermined: cameraAccess = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        default: cameraAccess = .denied
        }
    }
}

private struct ROBBattleARContainer: UIViewRepresentable {
    @Bindable var battle: ROBBattleCoordinator
    private static let scale: Float = 0.075

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.8, 0.8]))
        let root = Entity()
        root.name = "ROB AR Deathmatch Root"
        root.scale = .init(repeating: Self.scale)
        root.addChild(ROBBattleFactory.makeArena(battle.arena, arPresentation: true))
        ROBBattleFactory.synchronize(root: root, battle: battle, arPresentation: true)
        anchor.addChild(root)
        view.scene.addAnchor(anchor)
        context.coordinator.root = root
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        guard let root = context.coordinator.root else { return }
        ROBBattleFactory.synchronize(root: root, battle: battle, arPresentation: true)
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { view.session.pause() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var root: Entity? }
}

private extension View {
    func battleCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.cyan.opacity(0.25)))
    }
}
