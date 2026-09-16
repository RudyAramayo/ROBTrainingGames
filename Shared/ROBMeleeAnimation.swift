import Foundation

// Matches rob-melee-animation.mjs. The return is part of the attack rather
// than a reset to identity when its timer expires.
struct ROBMeleeAnimation {
    var armYaw: Float = 0
    var armRoll: Float = 0
    var torsoYaw: Float = 0
    var hammerPitch: Float = 0

    static func duration(_ style: SaberAttackStyle?) -> TimeInterval {
        switch style {
        case .spin: 0.82
        case .hammerSmash: 0.65
        default: 0.48
        }
    }

    static func pose(_ style: SaberAttackStyle?, progress: Float) -> Self {
        let p = max(0, min(1, progress))
        guard let style, p > 0, p < 1 else { return Self() }
        func smooth(_ value: Float) -> Float {
            let t = max(0, min(1, value))
            return t * t * (3 - 2 * t)
        }
        let excursion = p < 0.45 ? smooth(p / 0.45) : 1 - smooth((p - 0.45) / 0.55)
        switch style {
        case .spin:
            return Self(armRoll: .pi / 2 * smooth(p / 0.2) * (1 - smooth((p - 0.75) / 0.25)),
                        torsoYaw: smooth(p) * .pi * 2)
        case .hammerSmash:
            return Self(hammerPitch: -1.5 * excursion)
        case .leftSweep, .rightSweep:
            let direction: Float = style == .leftSweep ? -1 : 1
            return Self(armYaw: direction * 1.3 * excursion, armRoll: 0.5 * excursion,
                        torsoYaw: direction * 0.24 * excursion)
        }
    }
}
