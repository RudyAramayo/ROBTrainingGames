import RealityKit
import SwiftUI

struct VisionDashboard: View {
    @Bindable var session: GameSession
    @Bindable var voice: RobotVoice
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var immersive = false
    var body: some View {
        NavigationSplitView {
            List { Section("Campaign") { ForEach(session.levels) { level in Label("\(level.id). \(level.name)", systemImage: level.id - 1 <= session.levelIndex ? "checkmark.circle.fill" : "circle") } }; Section("Explore ROB") { ForEach(session.components) { component in Button(component.name) { session.selectedComponent = component } } } }.navigationTitle("ROB Training")
        } detail: {
            VStack(spacing: 18) {
                Image("rob-training-key-art").resizable().scaledToFit().frame(maxHeight: 310).clipShape(RoundedRectangle(cornerRadius: 24))
                Text("ROB Spatial Workshop").font(.largeTitle.bold()); Text("Place ROB at full scale, move it through your room, complete missions, and reveal the systems inside.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                HStack { Label("Level \(session.level.id)/\(session.levels.count)", systemImage: "flag.checkered"); Label("Score \(session.score)", systemImage: "star.fill"); Label("Targets \(session.remainingEnemies)", systemImage: "scope"); Label(session.hasKey ? "Key secured" : "Find key", systemImage: session.hasKey ? "key.fill" : "key") }.monospacedDigit()
                Text("Keyboard: WASD or arrows to move · Space to slash · Q to fire laser").font(.callout.monospaced()).foregroundStyle(.cyan)
                HStack { Button(session.musicEnabled ? "Generated techno on" : "Music off", systemImage: session.musicEnabled ? "music.note" : "speaker.slash") { session.toggleMusic() }; Button(immersive ? "Leave Spatial Workshop" : "Enter Spatial Workshop", systemImage: immersive ? "rectangle.portrait.and.arrow.right" : "vision.pro") { Task { if immersive { await dismissImmersiveSpace(); immersive = false } else { immersive = await openImmersiveSpace(id: "ROBWorkshop") == .opened } } } }.buttonStyle(.borderedProminent)
                RobotVoicePanel(voice: voice, game: session).frame(maxWidth: 620)
                if let component = session.selectedComponent { VStack(alignment: .leading) { Text(component.name).font(.title2.bold()); Text(component.summary).foregroundStyle(.secondary) }.padding().glassBackgroundEffect() }
            }.padding(28)
        }
        .robGameKeyboardControls(session: session)
    }
}

struct ImmersiveROBWorkshop: View {
    @Bindable var session: GameSession
    @Bindable var voice: RobotVoice
    @State private var robot = RobotFactory.makeROB(componentMode: true)
    @State private var scale: Float = 0.75
    var body: some View {
        RealityView { content, attachments in
            robot.position = [0, 0, -2]; robot.scale = .init(repeating: scale); content.add(robot); let room = RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle); room.position = [0, -0.02, -2]; content.add(room)
            if let controls = attachments.entity(for: "controls") { controls.position = [0, 1.9, -1.4]; content.add(controls) }
        } update: { content, _ in robot.scale = .init(repeating: scale); robot.position = session.robotPosition + SIMD3<Float>(0, 0, -2); robot.orientation = simd_quatf(angle: session.robotHeading, axis: [0, 1, 0]); RobotFactory.applyWeapons(to: robot, session: session); let roomName = "Training Room-\(session.levelIndex)"; if let room = content.entities.first(where: { $0.name == roomName }) { RobotFactory.applyPuzzleState(to: room, session: session) } else { content.entities.filter { $0.name.hasPrefix("Training Room-") }.forEach { $0.removeFromParent() }; let room = RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle); room.position = [0, -0.02, -2]; content.add(room) } } attachments: {
            Attachment(id: "controls") {
                VStack(spacing: 12) {
                    Text("ROB Spatial Controls").font(.headline)
                    Text("WASD / arrows · Space slash · Q laser").font(.caption.monospaced()).foregroundStyle(.cyan)
                    HStack { Button("←") { session.moveStep(steering: 1) }; Button("↑") { session.moveStep(forward: 1) }; Button("→") { session.moveStep(steering: -1) } }
                    HStack { Button("↓") { session.moveStep(forward: -1) }; Button("Stop") { session.stopDrive() } }
                    Slider(value: Binding(get: { Double(scale) }, set: { scale = Float($0) }), in: 0.3...1.3) { Text("Scale") }.frame(width: 320)
                    HStack { Button("Fire training laser") { session.fireLaser() }; Button("Sword-style saber slash") { session.saberAttack() } }.tint(.pink)
                    Button(session.musicEnabled ? "♫ Generated techno" : "Music off") { session.toggleMusic() }
                    Text("Navigate ROB onto keys, doors, and cells; locked partitions block every bypass.").font(.caption).frame(width: 420)
                    HStack { Button("Simulate enemy hit") { session.enemyContact() }.tint(.red); if session.canFinish { Button(session.levelIndex == session.levels.count - 1 ? "Finish campaign" : "Next level") { session.nextLevel() } } }
                    Menu("Inspect a component") { ForEach(session.components) { component in Button(component.name) { session.selectedComponent = component } } }
                    if let component = session.selectedComponent { Text(component.summary).font(.caption).frame(width: 420) }
                    RobotVoicePanel(voice: voice, game: session, compact: true).frame(width: 440)
                }.padding().glassBackgroundEffect()
            }
        }
        .robGameKeyboardControls(session: session)
    }
}
