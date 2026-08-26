import RealityKit
import SwiftUI

struct IOSRootView: View {
    @Bindable var session: GameSession
    @Bindable var voice: RobotVoice
    var body: some View {
        TabView {
            MissionView(session: session, voice: voice).tabItem { Label("Missions", systemImage: "gamecontroller.fill") }
            ARLabView(session: session, voice: voice).tabItem { Label("AR Lab", systemImage: "arkit") }
            ComponentExplorer(session: session).tabItem { Label("ROB", systemImage: "cpu") }
        }.tint(.cyan)
    }
}

struct MissionView: View {
    @Bindable var session: GameSession
    @Bindable var voice: RobotVoice
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @AppStorage("robLocalHighScore") private var highScore = 0
    private var compactPhoneLayout: Bool { horizontalSizeClass == .compact }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                RealityView { content in
                    content.add(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle))
                    let rob = RobotFactory.makeROB(); rob.position = session.robotPosition; content.add(rob)
                    content.add(RobotFactory.makeCombatLayer(session: session))
                    let camera = PerspectiveCamera(); camera.name = "Mission Camera"; camera.look(at: session.robotPosition + SIMD3<Float>(0, 0.65, -1.1), from: session.robotPosition + SIMD3<Float>(3.4, 5.2, 5.4), relativeTo: nil); content.add(camera)
                } update: { content in
                    if let rob = content.entities.first(where: { $0.name == "ROB" }) { rob.position = session.robotPosition; rob.orientation = simd_quatf(angle: session.robotHeading, axis: [0, 1, 0]); RobotFactory.applyWeapons(to: rob, session: session) }
                    if let camera = content.entities.first(where: { $0.name == "Mission Camera" }) { camera.look(at: session.robotPosition + SIMD3<Float>(0, 0.65, -1.1), from: session.robotPosition + SIMD3<Float>(3.4, 5.2, 5.4), relativeTo: nil) }
                    let roomName = "Training Room-\(session.levelIndex)"
                    if let room = content.entities.first(where: { $0.name == roomName }) { RobotFactory.applyPuzzleState(to: room, session: session) }
                    else { content.entities.filter { $0.name.hasPrefix("Training Room-") }.forEach { $0.removeFromParent() }; content.add(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle)) }
                    let combatName = RobotFactory.combatLayerName(level: session.levelIndex)
                    if let combat = content.entities.first(where: { $0.name == combatName }) { RobotFactory.applyCombatState(to: combat, session: session) }
                    else { content.entities.filter { $0.name.hasPrefix("Combat Layer-") }.forEach { $0.removeFromParent() }; content.add(RobotFactory.makeCombatLayer(session: session)) }
                }
                    .ignoresSafeArea().background(.black)
                VStack(spacing: verticalSizeClass == .compact ? 4 : 10) {
                    if compactPhoneLayout {
                        CompactMissionStats(session: session, highScore: highScore).padding(.horizontal, 8)
                    } else {
                        HStack { Label("Level \(session.level.id)/\(session.levels.count)", systemImage: "flag.checkered"); Spacer(); Label(session.hasKey ? "Key" : "No key", systemImage: session.hasKey ? "key.fill" : "key"); Text("Targets \(session.remainingEnemies)").monospacedDigit(); Text("Score \(session.score)").monospacedDigit(); Text("Best \(highScore)").foregroundStyle(.cyan).monospacedDigit() }.font(.headline).padding(10).background(.ultraThinMaterial, in: Capsule()).padding(.horizontal)
                    }
                    Spacer()
                    Text(session.message).font(.subheadline.bold()).lineLimit(compactPhoneLayout ? 1 : 2).padding(.horizontal, 14).padding(.vertical, 8).background(.black.opacity(0.65), in: Capsule())
                    if !compactPhoneLayout && verticalSizeClass != .compact {
                        Text("Move: WASD or arrows · Slash: Space · Laser: Q").font(.caption2.bold()).foregroundStyle(.cyan).padding(.horizontal, 12).padding(.vertical, 6).background(.black.opacity(0.65), in: Capsule())
                        RobotVoicePanel(voice: voice, game: session, compact: true).padding(.horizontal)
                    }
                    if compactPhoneLayout {
                        RobotVoicePanel(voice: voice, game: session, compact: true).padding(.horizontal, 8)
                        MobileTankControls(session: session).padding(.horizontal, 8)
                    } else {
                        VStack(spacing: 6) {
                            MobileTankControls(session: session)
                            if verticalSizeClass != .compact {
                                Text("Independent treads · sweep left, sweep right, then spin · hold laser to charge").font(.caption.bold()).foregroundStyle(.cyan)
                                Text("Drive onto keys, doors, and cells while enemies fight back").font(.caption2)
                            }
                        }
                        .padding(verticalSizeClass == .compact ? 6 : 16)
                    }
                }
                .padding(.bottom, compactPhoneLayout ? 54 : 0)
            }
            .navigationTitle(compactPhoneLayout ? "" : session.level.name).navigationBarTitleDisplayMode(.inline)
            .toolbar(compactPhoneLayout ? .hidden : .visible, for: .navigationBar)
            .robGameKeyboardControls(session: session)
            .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button { session.toggleMusic() } label: { Label(session.musicEnabled ? "Techno on" : "Music off", systemImage: session.musicEnabled ? "music.note" : "speaker.slash") }; Button(session.isRunning ? "Reset" : "Start") { session.isRunning ? session.reset() : session.begin() } }; ToolbarItem(placement: .topBarLeading) { if session.canFinish { Button(session.levelIndex == session.levels.count - 1 ? "Finish" : "Next Level") { session.nextLevel() } } } }
            .onReceive(timer) { _ in session.tick(1.0 / 30.0); highScore = max(highScore, session.score) }
        }
    }
}

private struct CompactMissionStats: View {
    @Bindable var session: GameSession
    let highScore: Int

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Text("Level \(session.level.id) · \(session.level.name)").font(.subheadline.bold()).lineLimit(1)
                Spacer(minLength: 2)
                Button { session.toggleMusic() } label: {
                    Image(systemName: session.musicEnabled ? "music.note" : "speaker.slash")
                }
                Button(session.isRunning ? "Reset" : "Start") { session.isRunning ? session.reset() : session.begin() }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
            }
            HStack(spacing: 12) {
                Label("\(session.level.id)/\(session.levels.count)", systemImage: "flag.checkered")
                Spacer(minLength: 0)
                Label(session.hasKey ? "Key" : "No key", systemImage: session.hasKey ? "key.fill" : "key")
                Label("\(session.remainingEnemies)", systemImage: "scope")
                Label("\(session.score)", systemImage: "star.fill")
                Label("\(highScore)", systemImage: "trophy.fill").foregroundStyle(.cyan)
            }
            .font(.caption.bold())
            .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct MobileTankControls: View {
    @Bindable var session: GameSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var leftDemand = 0.0
    @State private var rightDemand = 0.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TreadJoystick(title: "LEFT", demand: updateLeft)
            VStack(spacing: 5) {
                LaserChargeButton(session: session, title: "Laser", compact: true)
                Button { session.saberAttack() } label: {
                    Label("Saber", systemImage: "sparkles").font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.75)
                }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                Text(session.laserLockDescription)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .foregroundStyle(session.lockedEnemy == nil ? .orange : .red)
            }
            .frame(maxWidth: .infinity)
            TreadJoystick(title: "RIGHT", demand: updateRight)
        }
        .padding(8)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 720)
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
        .onDisappear(perform: stop)
    }

    private func updateLeft(_ value: Double) {
        leftDemand = value
        session.setTreads(left: leftDemand, right: rightDemand)
    }

    private func updateRight(_ value: Double) {
        rightDemand = value
        session.setTreads(left: leftDemand, right: rightDemand)
    }

    private func stop() {
        leftDemand = 0
        rightDemand = 0
        session.stopDrive()
    }
}

private struct TreadJoystick: View {
    let title: String
    let demand: (Double) -> Void
    @State private var knobOffset: CGFloat = 0
    private let travel: CGFloat = 28

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(.cyan.opacity(0.2)).overlay(Circle().stroke(.cyan.opacity(0.8), lineWidth: 2))
                Capsule().fill(.cyan.opacity(0.25)).frame(width: 5, height: 54)
                Circle().fill(.cyan).frame(width: 34, height: 34).shadow(color: .cyan.opacity(0.8), radius: 6).offset(y: knobOffset)
            }
            .frame(width: 82, height: 82)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let value = max(-1, min(1, Double(-gesture.translation.height / travel)))
                        knobOffset = -CGFloat(value) * travel
                        demand(value)
                    }
                    .onEnded { _ in release() }
            )
            Text("\(title) TREAD").font(.caption2.bold()).foregroundStyle(.cyan)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.capitalized) tread joystick")
        .accessibilityValue(knobOffset == 0 ? "Stopped" : knobOffset < 0 ? "Forward" : "Reverse")
        .accessibilityAdjustableAction { direction in
            let value = direction == .increment ? 1.0 : direction == .decrement ? -1.0 : 0.0
            knobOffset = -CGFloat(value) * travel
            demand(value)
        }
        .onDisappear(perform: release)
    }

    private func release() {
        knobOffset = 0
        demand(0)
    }
}

struct DrivePad: View {
    @Bindable var session: GameSession
    var compact = false
    var body: some View {
        Group {
            if compact {
                HStack(spacing: 4) { DriveHoldButton(session: session, title: "←", steering: 1); DriveHoldButton(session: session, title: "↑", forward: 1); Button("■") { session.stopDrive() }; DriveHoldButton(session: session, title: "↓", forward: -1); DriveHoldButton(session: session, title: "→", steering: -1) }
            } else {
                VStack(spacing: 6) { DriveHoldButton(session: session, title: "↑", forward: 1); HStack { DriveHoldButton(session: session, title: "←", steering: 1); Button("■") { session.stopDrive() }; DriveHoldButton(session: session, title: "→", steering: -1) }; DriveHoldButton(session: session, title: "↓", forward: -1); Text("Treads \(session.leftTread, format: .number.precision(.fractionLength(1))) · \(session.rightTread, format: .number.precision(.fractionLength(1)))").font(.caption.monospacedDigit()) }
            }
        }.buttonStyle(.borderedProminent).tint(.cyan).padding(compact ? 6 : 10).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ComponentExplorer: View {
    @Bindable var session: GameSession
    var body: some View { NavigationStack { ScrollView { Image("rob-training-key-art").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 20)).padding(); ForEach(session.components) { component in Button { session.selectedComponent = component } label: { VStack(alignment: .leading, spacing: 6) { Text(component.name).font(.title3.bold()); Text(component.summary).font(.body).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain).padding(.horizontal) } }.navigationTitle("Inside ROB") } }
}
