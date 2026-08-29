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
                            Text("Nearby ROB Training simulators find each other automatically for encrypted, four-player deathmatches. Each simulator contributes one pilot and controller.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)

                        ROBBattleLobbyStatus(battle: battle)

                        switch battle.phase {
                        case .voting:
                            arenaVoting
                            if battle.isHost {
                                Button { battle.startMatch() } label: {
                                    Label(battle.allPlayersHaveVoted ? "Start Voted Arena" : "Waiting for Every Vote", systemImage: "play.fill")
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
                                Text("\(battle.arena.name) is live").font(.title2.bold())
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
                    Text("\(battle.scores[player.id, default: 0]) KOs")
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

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onExit) { Label("Lobby", systemImage: "xmark.circle.fill") }
                Spacer()
                Text(battle.arena.name).font(.headline)
                Spacer()
                Label(timeText, systemImage: "timer").monospacedDigit()
            }
            .padding(10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal)
            Spacer()
            VStack(spacing: 6) {
                HStack {
                    ProgressView(value: battle.localHealthFraction).tint(.red)
                    Text("H \(battle.localRobot.health)").monospacedDigit()
                    ProgressView(value: battle.localShieldFraction).tint(.cyan)
                    Text("S \(battle.localRobot.shields)").monospacedDigit()
                    Text("\(battle.localScore) KOs").foregroundStyle(.yellow).monospacedDigit()
                }
                .font(.caption.bold())
                ROBBattleScoreboard(battle: battle)
                if !battle.localRobot.isAlive {
                    Text("REBUILDING \(Int(ceil(battle.localRobot.respawnRemaining)))")
                        .font(.title2.bold()).foregroundStyle(.orange).monospacedDigit()
                }
                Text(battle.statusMessage).font(.caption.bold()).foregroundStyle(.cyan).lineLimit(2)
                ROBBattleTankControls(battle: battle)
            }
            .padding(8)
            .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
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
    }

    private var timeText: String {
        let seconds = max(0, Int(ceil(battle.remainingTime)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ROBBattleTankControls: View {
    @Bindable var battle: ROBBattleCoordinator
    @State private var left = 0.0
    @State private var right = 0.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ROBBattleTreadPad(title: "LEFT") { left = $0; publish() }
            VStack(spacing: 8) {
                Button { battle.fireLaser() } label: { Label("FIRE", systemImage: "scope") }
                    .buttonStyle(.borderedProminent).tint(.cyan)
                Button { battle.saberAttack() } label: { Label("SLASH", systemImage: "bolt.fill") }
                    .buttonStyle(.borderedProminent).tint(.pink)
                if let controller = battle.connectedControllerName {
                    Label(controller, systemImage: "gamecontroller.fill").font(.caption2).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            ROBBattleTreadPad(title: "RIGHT") { right = $0; publish() }
        }
        .frame(maxWidth: 720)
        .onDisappear { left = 0; right = 0; battle.stopDrive() }
    }

    private func publish() { battle.setTreads(left: left, right: right) }
}

private struct ROBBattleTreadPad: View {
    let title: String
    let changed: (Double) -> Void
    @State private var offset: CGFloat = 0

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(.cyan.opacity(0.2)).overlay(Circle().stroke(.cyan, lineWidth: 2))
                Capsule().fill(.cyan.opacity(0.25)).frame(width: 5, height: 54)
                Circle().fill(.cyan).frame(width: 34, height: 34).offset(y: offset).shadow(color: .cyan, radius: 7)
            }
            .frame(width: 82, height: 82)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let demand = max(-1, min(1, Double(-value.translation.height / 28)))
                        offset = -CGFloat(demand) * 28
                        changed(demand)
                    }
                    .onEnded { _ in offset = 0; changed(0) }
            )
            Text(title).font(.caption2.bold())
        }
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
                ProgressView("Preparing AR deathmatch…")
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
