import SwiftUI

@main struct ROBTrainingVisionApp: App {
    @State private var session = GameSession()
    var body: some Scene {
        WindowGroup { VisionDashboard(session: session) }
        ImmersiveSpace(id: "ROBWorkshop") { ImmersiveROBWorkshop(session: session) }
    }
}

