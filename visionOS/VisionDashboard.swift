import RealityKit
import SwiftUI

struct VisionDashboard: View {
    @Bindable var session: GameSession
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
                HStack { Label("Level \(session.level.id)/3", systemImage: "flag.checkered"); Label("Score \(session.score)", systemImage: "star.fill"); Label("Targets \(session.remainingEnemies)", systemImage: "scope") }.monospacedDigit()
                Button(immersive ? "Leave Spatial Workshop" : "Enter Spatial Workshop", systemImage: immersive ? "rectangle.portrait.and.arrow.right" : "vision.pro") { Task { if immersive { await dismissImmersiveSpace(); immersive = false } else { immersive = await openImmersiveSpace(id: "ROBWorkshop") == .opened } } }.buttonStyle(.borderedProminent)
                if let component = session.selectedComponent { VStack(alignment: .leading) { Text(component.name).font(.title2.bold()); Text(component.summary).foregroundStyle(.secondary) }.padding().glassBackgroundEffect() }
            }.padding(28)
        }
    }
}

struct ImmersiveROBWorkshop: View {
    @Bindable var session: GameSession
    @State private var robot = RobotFactory.makeROB(componentMode: true)
    @State private var scale: Float = 0.75
    var body: some View {
        RealityView { content, attachments in
            robot.position = [0, 0, -2]; robot.scale = .init(repeating: scale); content.add(robot); let room = RobotFactory.makeTrainingRoom(level: session.levelIndex); room.position = [0, -0.02, -2]; content.add(room)
            if let controls = attachments.entity(for: "controls") { controls.position = [0, 1.9, -1.4]; content.add(controls) }
        } update: { _, _ in robot.scale = .init(repeating: scale) } attachments: {
            Attachment(id: "controls") {
                VStack(spacing: 12) {
                    Text("ROB Spatial Controls").font(.headline)
                    HStack { Button("◀︎ Turn") { robot.orientation *= simd_quatf(angle: .pi / 8, axis: [0, 1, 0]) }; Button("Forward") { robot.position.z -= 0.2 }; Button("Turn ▶︎") { robot.orientation *= simd_quatf(angle: -.pi / 8, axis: [0, 1, 0]) } }
                    HStack { Button("Left") { robot.position.x -= 0.2 }; Button("Back") { robot.position.z += 0.2 }; Button("Right") { robot.position.x += 0.2 } }
                    Slider(value: Binding(get: { Double(scale) }, set: { scale = Float($0) }), in: 0.3...1.3) { Text("Scale") }.frame(width: 320)
                    Button("Fire training laser") { session.fire() }.tint(.pink)
                    HStack { Button("Collect cell") { session.collectCell() }; Button("Disable target") { session.disableEnemy() }; if session.collectedCells == session.level.cellCount && session.remainingEnemies == 0 && session.levelIndex < 2 { Button("Next level") { session.nextLevel() } } }
                    Menu("Inspect a component") { ForEach(session.components) { component in Button(component.name) { session.selectedComponent = component } } }
                    if let component = session.selectedComponent { Text(component.summary).font(.caption).frame(width: 420) }
                }.padding().glassBackgroundEffect()
            }
        }
        .gesture(DragGesture().targetedToAnyEntity().onChanged { value in let delta = value.gestureValue.translation; robot.position.x += Float(delta.width) * 0.0005; robot.position.y -= Float(delta.height) * 0.0005 })
    }
}
