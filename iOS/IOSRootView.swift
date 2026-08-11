import RealityKit
import SwiftUI

struct IOSRootView: View {
    @Bindable var session: GameSession
    var body: some View {
        TabView {
            MissionView(session: session).tabItem { Label("Missions", systemImage: "gamecontroller.fill") }
            ARLabView(session: session).tabItem { Label("AR Lab", systemImage: "arkit") }
            ComponentExplorer(session: session).tabItem { Label("ROB", systemImage: "cpu") }
        }.tint(.cyan)
    }
}

struct MissionView: View {
    @Bindable var session: GameSession
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @AppStorage("robLocalHighScore") private var highScore = 0
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                RealityView { content in content.add(RobotFactory.makeTrainingRoom(level: session.levelIndex)); let rob = RobotFactory.makeROB(); rob.position = session.robotPosition; content.add(rob) } update: { content in if let rob = content.entities.first(where: { $0.name == "ROB" }) { rob.position = session.robotPosition; rob.orientation = simd_quatf(angle: session.robotHeading, axis: [0, 1, 0]) } }
                    .ignoresSafeArea().background(.black)
                VStack(spacing: 10) {
                    HStack { Label("Level \(session.level.id)/3", systemImage: "flag.checkered"); Spacer(); Text("Score \(session.score)").monospacedDigit(); Text("Best \(highScore)").foregroundStyle(.cyan).monospacedDigit() }.font(.headline).padding(10).background(.ultraThinMaterial, in: Capsule()).padding(.horizontal)
                    Spacer()
                    Text(session.message).font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 8).background(.black.opacity(0.65), in: Capsule())
                    HStack(alignment: .bottom) {
                        TreadControl(title: "LEFT", value: $session.leftTread)
                        Spacer()
                        VStack { Button { session.fire() } label: { Image(systemName: "laser.burst").font(.title).frame(width: 64, height: 64) }.buttonStyle(.borderedProminent).tint(.pink); Button("Cell") { session.collectCell() }.buttonStyle(.bordered); Button("Target") { session.disableEnemy() }.buttonStyle(.bordered) }
                        Spacer()
                        TreadControl(title: "RIGHT", value: $session.rightTread)
                    }.padding()
                }
            }
            .navigationTitle(session.level.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(session.isRunning ? "Reset" : "Start") { session.isRunning ? session.reset() : session.begin() } }; ToolbarItem(placement: .topBarLeading) { if session.collectedCells == session.level.cellCount && session.remainingEnemies == 0 && session.levelIndex < 2 { Button("Next Level") { session.nextLevel() } } } }
            .onReceive(timer) { _ in session.tick(1.0 / 30.0); highScore = max(highScore, session.score) }
        }
    }
}

struct TreadControl: View {
    let title: String
    @Binding var value: Double
    var body: some View { VStack { Text("▲").font(.caption); Slider(value: $value, in: -1...1).rotationEffect(.degrees(-90)).frame(width: 120, height: 44).frame(width: 64, height: 130); Text(title).font(.caption2.bold()).foregroundStyle(.cyan); Text(value, format: .number.precision(.fractionLength(2))).font(.caption.monospacedDigit()) }.padding(8).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18)) }
}

struct ComponentExplorer: View {
    @Bindable var session: GameSession
    var body: some View { NavigationStack { ScrollView { Image("rob-training-key-art").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 20)).padding(); ForEach(session.components) { component in Button { session.selectedComponent = component } label: { VStack(alignment: .leading, spacing: 6) { Text(component.name).font(.title3.bold()); Text(component.summary).font(.body).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain).padding(.horizontal) } }.navigationTitle("Inside ROB") } }
}
