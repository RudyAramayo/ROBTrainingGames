import SwiftUI

struct LaserChargeButton: View {
    @Bindable var session: GameSession
    var title = "Shoulder laser"
    var compact = false
    @State private var pressing = false

    var body: some View {
        Label(pressing ? "Charge \(Int(session.laserCharge * 100))%" : title, systemImage: session.lockedEnemy == nil ? "scope" : "scope")
            .font(compact ? .caption.bold() : .body.bold())
            .lineLimit(1)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 8 : 11)
            .foregroundStyle(.white)
            .background(backgroundColor, in: Capsule())
            .overlay(Capsule().stroke(session.lockedEnemy == nil ? Color.white.opacity(0.25) : Color.red, lineWidth: session.lockedEnemy == nil ? 1 : 2))
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressing else { return }
                        pressing = true
                        session.beginLaserCharge()
                    }
                    .onEnded { _ in
                        session.releaseLaserCharge()
                        pressing = false
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Charge and fire shoulder laser")
            .accessibilityValue(session.laserLockDescription)
            .accessibilityAction { session.fireLaser() }
            .onDisappear { if pressing { session.releaseLaserCharge(); pressing = false } }
    }

    private var backgroundColor: Color {
        if pressing { return Color(red: 0.68, green: 0.08, blue: 0.05).opacity(0.8 + session.laserCharge * 0.2) }
        return session.lockedEnemy == nil ? Color.gray.opacity(0.72) : Color.red.opacity(0.78)
    }
}
