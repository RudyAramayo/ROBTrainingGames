import SwiftUI

struct GameKeyboardControls: ViewModifier {
    @Bindable var session: GameSession
    @Environment(\.scenePhase) private var scenePhase
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
                        if press.key == "f" { session.activateBaseFlipper() }
                        if press.key == .space { session.saberAttack() }
                    }
                } else {
                    heldKeys.remove(press.key)
                    if press.key == "q" { session.releaseLaserCharge() }
                }
                updateDrive()
                return .handled
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { cancelInput() } }
            .onDisappear(perform: cancelInput)
    }

    private func updateDrive() {
        let forward = (heldKeys.contains("w") || heldKeys.contains(.upArrow) ? 1.0 : 0.0)
            - (heldKeys.contains("s") || heldKeys.contains(.downArrow) ? 1.0 : 0.0)
        let steering = (heldKeys.contains("a") || heldKeys.contains(.leftArrow) ? 1.0 : 0.0)
            - (heldKeys.contains("d") || heldKeys.contains(.rightArrow) ? 1.0 : 0.0)
        session.setDrive(forward: forward, steering: steering)
    }

    private func cancelInput() {
        if heldKeys.contains("q") { session.releaseLaserCharge() }
        heldKeys = []
        session.stopDrive()
    }

    private static let supportedKeys: Set<KeyEquivalent> = [
        "w", "a", "s", "d", "q", "f", .upArrow, .downArrow, .leftArrow, .rightArrow, .space,
    ]
}

struct DriveHoldButton: View {
    @Bindable var session: GameSession
    let title: String
    var forward = 0.0
    var steering = 0.0
    @State private var pressing = false

    var body: some View {
        Text(title)
            .font(.body.bold())
            .frame(minWidth: 42, minHeight: 40)
            .padding(.horizontal, 4)
            .foregroundStyle(.white)
            .background(pressing ? Color.cyan : Color.cyan.opacity(0.82), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressing else { return }
                        pressing = true
                        session.setDrive(forward: forward, steering: steering)
                    }
                    .onEnded { _ in stop() }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(pressing ? "Driving" : "Stopped")
            .accessibilityAction { session.moveStep(forward: forward, steering: steering) }
            .onDisappear(perform: stop)
    }

    private var accessibilityLabel: String {
        if forward > 0 { return "Drive forward" }
        if forward < 0 { return "Drive in reverse" }
        return steering > 0 ? "Turn left" : "Turn right"
    }

    private func stop() {
        session.stopDrive()
        pressing = false
    }
}

extension View {
    func robGameKeyboardControls(session: GameSession) -> some View {
        modifier(GameKeyboardControls(session: session))
    }
}
