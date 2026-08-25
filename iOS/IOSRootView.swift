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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @AppStorage("robLocalHighScore") private var highScore = 0
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                RealityView { content in
                    content.add(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle))
                    let rob = RobotFactory.makeROB(); rob.position = session.robotPosition; content.add(rob)
                    content.add(RobotFactory.makeCombatLayer(session: session))
                } update: { content in
                    if let rob = content.entities.first(where: { $0.name == "ROB" }) { rob.position = session.robotPosition; rob.orientation = simd_quatf(angle: session.robotHeading, axis: [0, 1, 0]); RobotFactory.applyWeapons(to: rob, session: session) }
                    let roomName = "Training Room-\(session.levelIndex)"
                    if let room = content.entities.first(where: { $0.name == roomName }) { RobotFactory.applyPuzzleState(to: room, session: session) }
                    else { content.entities.filter { $0.name.hasPrefix("Training Room-") }.forEach { $0.removeFromParent() }; content.add(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle)) }
                    let combatName = RobotFactory.combatLayerName(level: session.levelIndex)
                    if let combat = content.entities.first(where: { $0.name == combatName }) { RobotFactory.applyCombatState(to: combat, session: session) }
                    else { content.entities.filter { $0.name.hasPrefix("Combat Layer-") }.forEach { $0.removeFromParent() }; content.add(RobotFactory.makeCombatLayer(session: session)) }
                }
                    .ignoresSafeArea().background(.black)
                VStack(spacing: verticalSizeClass == .compact ? 4 : 10) {
                    HStack { Label("Level \(session.level.id)/\(session.levels.count)", systemImage: "flag.checkered"); Spacer(); Label(session.hasKey ? "Key" : "No key", systemImage: session.hasKey ? "key.fill" : "key"); Text("Targets \(session.remainingEnemies)").monospacedDigit(); Text("Score \(session.score)").monospacedDigit(); Text("Best \(highScore)").foregroundStyle(.cyan).monospacedDigit() }.font(.headline).padding(10).background(.ultraThinMaterial, in: Capsule()).padding(.horizontal)
                    Spacer()
                    Text(session.message).font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 8).background(.black.opacity(0.65), in: Capsule())
                    if verticalSizeClass != .compact {
                        Text("Move: WASD or arrows · Slash: Space · Laser: Q").font(.caption2.bold()).foregroundStyle(.cyan).padding(.horizontal, 12).padding(.vertical, 6).background(.black.opacity(0.65), in: Capsule())
                        RobotVoicePanel(voice: voice, game: session, compact: true).padding(.horizontal)
                    }
                    HStack(alignment: .bottom) { DrivePad(session: session, compact: verticalSizeClass == .compact); Spacer(); VStack { HStack { LaserChargeButton(session: session, title: "Laser", compact: verticalSizeClass == .compact); Button { session.saberAttack() } label: { Label("Saber combo", systemImage: "sparkles") }.buttonStyle(.borderedProminent).tint(.pink) }; Text(session.laserLockDescription).font(.caption2.bold()).foregroundStyle(session.lockedEnemy == nil ? .orange : .red); if verticalSizeClass != .compact { Text("Sweep left, sweep right, then spin · hold laser to charge").font(.caption.bold()).foregroundStyle(.cyan); Text("Drive onto keys, doors, and cells while enemies fight back").font(.caption2) } } }.padding(verticalSizeClass == .compact ? 6 : 16)
                }
            }
            .navigationTitle(session.level.name).navigationBarTitleDisplayMode(.inline)
            .robGameKeyboardControls(session: session)
            .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button { session.toggleMusic() } label: { Label(session.musicEnabled ? "Techno on" : "Music off", systemImage: session.musicEnabled ? "music.note" : "speaker.slash") }; Button(session.isRunning ? "Reset" : "Start") { session.isRunning ? session.reset() : session.begin() } }; ToolbarItem(placement: .topBarLeading) { if session.canFinish { Button(session.levelIndex == session.levels.count - 1 ? "Finish" : "Next Level") { session.nextLevel() } } } }
            .onReceive(timer) { _ in session.tick(1.0 / 30.0); highScore = max(highScore, session.score) }
        }
    }
}

struct DrivePad: View {
    @Bindable var session: GameSession
    var compact = false
    var body: some View {
        Group {
            if compact {
                HStack(spacing: 4) { Button("←") { session.setDrive(forward: 0, steering: 1) }; Button("↑") { session.setDrive(forward: 1, steering: 0) }; Button("■") { session.stopDrive() }; Button("↓") { session.setDrive(forward: -1, steering: 0) }; Button("→") { session.setDrive(forward: 0, steering: -1) } }
            } else {
                VStack(spacing: 6) { Button("↑") { session.setDrive(forward: 1, steering: 0) }; HStack { Button("←") { session.setDrive(forward: 0, steering: 1) }; Button("■") { session.stopDrive() }; Button("→") { session.setDrive(forward: 0, steering: -1) } }; Button("↓") { session.setDrive(forward: -1, steering: 0) }; Text("Treads \(session.leftTread, format: .number.precision(.fractionLength(1))) · \(session.rightTread, format: .number.precision(.fractionLength(1)))").font(.caption.monospacedDigit()) }
            }
        }.buttonStyle(.borderedProminent).tint(.cyan).padding(compact ? 6 : 10).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ComponentExplorer: View {
    @Bindable var session: GameSession
    var body: some View { NavigationStack { ScrollView { Image("rob-training-key-art").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 20)).padding(); ForEach(session.components) { component in Button { session.selectedComponent = component } label: { VStack(alignment: .leading, spacing: 6) { Text(component.name).font(.title3.bold()); Text(component.summary).font(.body).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain).padding(.horizontal) } }.navigationTitle("Inside ROB") } }
}
