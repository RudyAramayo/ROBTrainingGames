import SwiftUI

@main struct ROBTrainingiOSApp: App {
    @State private var session = GameSession()
    @State private var voice = RobotVoice()
    @State private var battle = ROBBattleCoordinator()
    var body: some Scene { WindowGroup { IOSRootView(session: session, voice: voice, battle: battle) } }
}
