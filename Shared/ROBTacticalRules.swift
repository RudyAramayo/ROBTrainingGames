import Foundation
import simd

// Campaign-only simulated equipment. No radio or physical robot interface.
enum ROBTacticalRules {
    static let jammerDrain = 14.0
    static let jammerRadius: Float = 4
    static let gelCost = 3.0
    static let gelCycle = 0.22
    static let gelSpeed: Float = 14
    static let gelRange: Float = 16
    static let gelDamage = 2
    static let switchScore = 400
    static let switchSkill = 60
    static let muzzle = SIMD3<Float>(0.14, 0.846, -0.535)

    static func jammed(active: Bool, origin: SIMD3<Float>, target: SIMD3<Float>, boss: Bool = false, miniBoss: Bool = false) -> Bool {
        active && !boss && !miniBoss && simd_distance(origin, target) <= jammerRadius
    }
}

enum ROBPEQMode: String, CaseIterable, Sendable {
    case off, blue, infrared, flashlight
    var next: Self { Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % Self.allCases.count] }
    var label: String { self == .infrared ? "IR sensor view" : rawValue.capitalized }
}

struct ROBGelProjectile: Identifiable, Sendable {
    let id: Int
    var position: SIMD3<Float>
    let direction: SIMD3<Float>
    var distance: Float = 0
}
