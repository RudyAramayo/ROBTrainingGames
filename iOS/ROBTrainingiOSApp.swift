import SwiftUI

@main struct ROBTrainingiOSApp: App {
    @State private var session = GameSession()
    var body: some Scene { WindowGroup { IOSRootView(session: session) } }
}

