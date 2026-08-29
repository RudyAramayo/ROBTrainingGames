import SwiftUI

@main struct ROBTrainingVisionApp: App {
    @State private var session = GameSession()
    @State private var voice = RobotVoice()
    @State private var controller = VisionGameControllerInput()
    var body: some Scene {
        WindowGroup { VisionDashboard(session: session, voice: voice, controller: controller) }
        WindowGroup(id: "ROBTabletop") {
            TabletopROBWorkshop(session: session, controller: controller)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.15, height: 0.78, depth: 1.15, in: .meters)
        ImmersiveSpace(id: "ROBWorkshop") {
            ImmersiveROBWorkshop(session: session, controller: controller)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
