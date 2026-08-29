import SwiftUI

struct CombatHealthBars: View {
    @Bindable var session: GameSession
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            meter(
                title: "ROB HEALTH",
                value: session.health,
                maximum: session.maxHealth,
                color: healthColor,
                icon: "heart.fill"
            )
            meter(
                title: "ROB SHIELDS",
                value: session.shields,
                maximum: session.maxShields,
                color: session.shields == 0 ? .gray : .cyan,
                icon: "shield.fill"
            )
            energyMeter
            if session.isSecurityAlerted {
                Label("SECURITY ALERT · REACH A SHADOW ZONE", systemImage: "video.fill")
                    .font(compact ? .caption2.bold() : .caption.bold())
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if session.isInShadow {
                Label("HIDDEN IN SHADOW", systemImage: "moon.fill")
                    .font(compact ? .caption2.bold() : .caption.bold())
                    .foregroundStyle(.indigo)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let boss = session.activeBoss {
                meter(
                    title: "BOSS SHIELDS",
                    value: max(0, boss.shields),
                    maximum: boss.maxShields,
                    color: .red,
                    icon: "shield.lefthalf.filled"
                )
            }
        }
        .monospacedDigit()
    }

    private func meter(title: String, value: Int, maximum: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
                Spacer(minLength: 4)
                Text("\(value)/\(maximum)")
            }
            .font(compact ? .caption2.bold() : .caption.bold())
            .foregroundStyle(color)
            ProgressView(value: Double(value), total: Double(maximum))
                .progressViewStyle(.linear)
                .tint(color)
                .accessibilityLabel(title)
                .accessibilityValue("\(value) of \(maximum)")
        }
    }

    private var energyMeter: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.batteryblock.fill")
                Text("DRIVE ENERGY")
                Spacer(minLength: 4)
                Text("\(Int(session.energy))/\(Int(session.maxEnergy))")
            }
            .font(compact ? .caption2.bold() : .caption.bold())
            .foregroundStyle(session.energyFraction < 0.2 ? .orange : .cyan)
            ProgressView(value: session.energy, total: session.maxEnergy)
                .progressViewStyle(.linear)
                .tint(session.energyFraction < 0.2 ? .orange : .cyan)
                .accessibilityLabel("Drive energy")
                .accessibilityValue("\(Int(session.energy)) of \(Int(session.maxEnergy))")
        }
    }

    private var healthColor: Color {
        switch session.healthFraction {
        case ..<0.25: .red
        case ..<0.55: .orange
        default: .green
        }
    }
}

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
