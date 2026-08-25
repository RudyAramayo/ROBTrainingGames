import SwiftUI

struct GameKeyboardControls: ViewModifier {
    @Bindable var session: GameSession
    @State private var heldKeys: Set<KeyEquivalent> = []

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(phases: [.down, .up]) { press in
                guard Self.supportedKeys.contains(press.key) else { return .ignored }
                if press.phase == .down {
                    let wasHeld = heldKeys.contains(press.key)
                    heldKeys.insert(press.key)
                    if !wasHeld {
                        if press.key == "q" { session.beginLaserCharge() }
                        if press.key == .space { session.saberAttack() }
                    }
                } else {
                    heldKeys.remove(press.key)
                    if press.key == "q" { session.releaseLaserCharge() }
                }
                updateDrive()
                return .handled
            }
            .onDisappear { if heldKeys.contains("q") { session.releaseLaserCharge() } }
    }

    private func updateDrive() {
        let forward = (heldKeys.contains("w") || heldKeys.contains(.upArrow) ? 1.0 : 0.0)
            - (heldKeys.contains("s") || heldKeys.contains(.downArrow) ? 1.0 : 0.0)
        let steering = (heldKeys.contains("a") || heldKeys.contains(.leftArrow) ? 1.0 : 0.0)
            - (heldKeys.contains("d") || heldKeys.contains(.rightArrow) ? 1.0 : 0.0)
        session.setDrive(forward: forward, steering: steering)
    }

    private static let supportedKeys: Set<KeyEquivalent> = [
        "w", "a", "s", "d", "q", .upArrow, .downArrow, .leftArrow, .rightArrow, .space,
    ]
}

extension View {
    func robGameKeyboardControls(session: GameSession) -> some View {
        modifier(GameKeyboardControls(session: session))
    }
}
