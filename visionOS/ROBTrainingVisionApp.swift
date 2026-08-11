import SwiftUI

@main struct ROBTrainingVisionApp: App {
    @State private var session = GameSession()
    @State private var voice = RobotVoice()
    var body: some Scene {
        WindowGroup { VisionDashboard(session: session, voice: voice) }
        ImmersiveSpace(id: "ROBWorkshop") { ImmersiveROBWorkshop(session: session, voice: voice) }
    }
}
