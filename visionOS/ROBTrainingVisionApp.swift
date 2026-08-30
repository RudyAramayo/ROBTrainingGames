import SwiftUI

@main struct ROBTrainingVisionApp: App {
    @State private var session = GameSession()
    @State private var voice = RobotVoice()
    @State private var controller = VisionGameControllerInput()
    @State private var battle = ROBBattleCoordinator()
    var body: some Scene {
        WindowGroup { VisionDashboard(session: session, voice: voice, controller: controller, battle: battle) }
        WindowGroup(id: "ROBTabletop") {
            TabletopROBWorkshop(session: session, controller: controller)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.3, height: 0.94, depth: 1.3, in: .meters)
        WindowGroup(id: "ROBDeathmatch") {
            VisionBattleWorkshop(battle: battle)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.15, height: 0.82, depth: 1.15, in: .meters)
        ImmersiveSpace(id: "ROBWorkshop") {
            ImmersiveROBWorkshop(session: session, controller: controller)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
