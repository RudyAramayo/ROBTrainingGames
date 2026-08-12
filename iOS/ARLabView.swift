import ARKit
import RealityKit
import SwiftUI

struct ARLabView: View {
    @Bindable var session: GameSession
    @Bindable var voice: RobotVoice
    @State private var componentMode = false
    var body: some View {
        ZStack(alignment: .bottom) {
            ROBARView(componentMode: componentMode).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack { Label("Level \(session.level.id)", systemImage: "flag.checkered"); Spacer(); Text("Score \(session.score)").monospacedDigit(); Text("Cells \(session.collectedCells)/\(session.level.cellCount)"); Text("Targets \(session.remainingEnemies)") }.font(.caption.bold()).padding(10).background(.ultraThinMaterial, in: Capsule())
                Text(componentMode ? "Tap a ROB part, then use the guide below." : "Drag to move · pinch to resize · twist to rotate").font(.callout.bold()).padding(10).background(.ultraThinMaterial, in: Capsule())
                Toggle("Component Explorer", isOn: $componentMode).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                if componentMode { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(session.components) { item in Button(item.name) { session.selectedComponent = item }.buttonStyle(.borderedProminent).tint(.cyan) } }.padding(.horizontal) }; if let item = session.selectedComponent { Text(item.summary).font(.footnote).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
                HStack { Button("Start") { session.begin() }; Button("Key") { session.collectKey() }; Button("Door") { session.openDoor() }; Button("Cell") { session.collectCell() }; Button("Laser") { session.fireLaser() }; Button("Slash") { session.saberAttack() }; if session.canFinish { Button("Next") { session.nextLevel() }.buttonStyle(.borderedProminent) } }.buttonStyle(.bordered)
                RobotVoicePanel(voice: voice, game: session, compact: true)
            }.padding()
        }
        .robGameKeyboardControls(session: session)
    }
}

struct ROBARView: UIViewRepresentable {
    let componentMode: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false); let config = ARWorldTrackingConfiguration(); config.planeDetection = [.horizontal]; view.session.run(config); view.environment.sceneUnderstanding.options.insert(.occlusion)
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.25, 0.25])); let rob = RobotFactory.makeROB(componentMode: componentMode); rob.scale = [0.32, 0.32, 0.32]; anchor.addChild(rob); view.scene.addAnchor(anchor); context.coordinator.robot = rob
        view.installGestures([.translation, .rotation, .scale], for: rob as! HasCollision); return view
    }
    func updateUIView(_ view: ARView, context: Context) { }
    final class Coordinator { var robot: Entity? }
}
