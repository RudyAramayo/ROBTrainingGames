import Foundation
import simd

// Matches rob-pickup.mjs. These are game presentation values, not calibrated
// B1 targets or an actuator-to-angle mapping for the physical robot.
enum ROBCargoKind: String, CaseIterable, Sendable {
    case supplyCrate, batteryModule, chessPawn
    var name: String { switch self { case .supplyCrate: "supply crate"; case .batteryModule: "battery module"; case .chessPawn: "chess pawn" } }
    var destination: String { switch self { case .supplyCrate: "supply pad"; case .batteryModule: "charging pad"; case .chessPawn: "marked chess square" } }
}

struct ROBPickupTask: Sendable {
    enum Phase: Sendable { case waiting, carrying, delivered }
    enum Event { case inactive, land, stop, lean, outOfReach, blocked, unsafeDrop, pickedUp, dropped, delivered }
    var phase: Phase = .waiting
    var position: SIMD3<Float>
    static let leanAngle: Float = -0.85
    static let reach: Float = 0.22
    static let reward = 350
    static func advanceLean(_ amount: Float, requested: Bool, delta: TimeInterval) -> Float {
        ROBBodyKinematics.moveToward(amount, requested ? 1 : 0, Float(max(0, delta)) * 1.8)
    }
    static func driveMultiplier(lean: Float, carrying: Bool) -> Float { lean > 0.05 ? 0.25 : carrying ? 0.72 : 1 }

    mutating func interact(running: Bool, grounded: Bool, lean: Float, speed: Double,
                           hand: SIMD3<Float>, destination: SIMD3<Float>, dropPosition: SIMD3<Float>,
                           scale: Float, clear: Bool, dropClear: Bool) -> Event {
        guard running, phase != .delivered else { return .inactive }
        guard grounded else { return .land }
        guard abs(speed) <= 0.08 else { return .stop }
        guard lean >= 0.95 else { return .lean }
        guard scale.isFinite, scale > 0, hand.x.isFinite, hand.y.isFinite, hand.z.isFinite else { return .outOfReach }
        guard clear else { return .blocked }
        if phase == .waiting {
            guard simd_distance(hand, position) <= Self.reach * scale else { return .outOfReach }
            phase = .carrying; return .pickedUp
        }
        if simd_distance(hand, destination) <= Self.reach * scale {
            phase = .delivered; position = destination; return .delivered
        }
        guard dropClear, simd_distance(hand, dropPosition) <= Self.reach * scale else { return .unsafeDrop }
        phase = .waiting; position = dropPosition; return .dropped
    }
}
