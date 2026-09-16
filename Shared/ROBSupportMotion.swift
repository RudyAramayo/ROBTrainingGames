import Foundation
import simd

// Matches rob-support-motion.mjs. Visual anchors follow the lower waist frame.
// The reference photo's 8¼ inches is a pose length, not an actuator stroke.
enum ROBBodyKinematics {
    static let lactReferenceLength: Float = 0.20955
    static let leanHinge = SIMD3<Float>(0, 0.37, 0.035)
    static let lactFixedPin = SIMD3<Float>(0, 0.30, -0.08)
    static let lactMovingPin = SIMD3<Float>(0, 0.30 + sqrt(lactReferenceLength * lactReferenceLength - 0.135 * 0.135), 0.055)

    static func moveToward(_ value: Float, _ target: Float, _ step: Float) -> Float {
        value + (target >= value ? 1 : -1) * min(abs(target - value), max(0, step))
    }
    static func advanceLean(_ angle: Float, basePitch: Float, delta: TimeInterval) -> Float {
        let target = max(-0.85, min(0.65, -basePitch))
        let length = lactLength(leanAngle: angle), targetLength = lactLength(leanAngle: target), step = 0.30 * Float(max(0, delta))
        if abs(targetLength - length) <= step { return target }
        let nextLength = moveToward(length, targetLength, step)
        // Monotonic branch of the illustrated linkage; presentation values.
        var low: Float = -0.85, high: Float = 0.65
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if lactLength(leanAngle: mid) < nextLength { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }
    static func lactLength(leanAngle: Float) -> Float {
        let moving = leanHinge + simd_quatf(angle: leanAngle, axis: [1, 0, 0]).act(lactMovingPin - leanHinge)
        return simd_distance(moving, lactFixedPin)
    }
    struct TorsoPose {
        let position: SIMD3<Float>
        let orientation: simd_quatf
        let fixedPin: SIMD3<Float>
        let movingPin: SIMD3<Float>
        var lactLength: Float { simd_distance(fixedPin, movingPin) }
    }
    static func torsoPose(basePitch: Float, leanAngle: Float, rearHeight: Float = 0, rootHeight: Float = 0, scale: Float = 1, yaw: Float = 0) -> TorsoPose {
        let rear = SIMD3<Float>(0, 0, 0.212725)
        let base = simd_quatf(angle: basePitch, axis: [1, 0, 0])
        let body = simd_quatf(angle: basePitch + leanAngle, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
        let hinge = rear + base.act(leanHinge - rear)
        let offset = hinge - body.act(leanHinge)
        return TorsoPose(position: offset * scale + [0, rearHeight - rootHeight, 0], orientation: body,
                         fixedPin: rear + base.act(lactFixedPin - rear), movingPin: offset + body.act(lactMovingPin))
    }
}

struct ROBSupportMotion {
    enum Phase { case grounded, edge, falling, settling }
    var height: Float
    var velocity: Float = 0
    var pitch: Float = 0
    var phase: Phase = .grounded
    var supportHeight: Float
    var fallDirection: Float = 0
    init(height: Float = 0) { self.height = height; supportHeight = height }

    func advanced(frontFloor: Float, rearFloor: Float, centerFloor: Float, contactSpan: Float, scale: Float = 1, forward: Float = 0, delta: TimeInterval) -> Self {
        var next = self
        let dt = Float(max(0, delta)), epsilon: Float = 0.0001
        let high = max(frontFloor, rearFloor), low = min(frontFloor, rearFloor, centerFloor)
        let mixedSupport = high - min(frontFloor, rearFloor) > epsilon
        if mixedSupport && high <= supportHeight + epsilon && phase != .falling && phase != .settling {
            let target = max(-0.38, min(0.38, asin(max(-1, min(1, (frontFloor - rearFloor) / contactSpan))) * 0.6))
            next.pitch = ROBBodyKinematics.moveToward(pitch, target, dt * 2.4)
            next.height = rearFloor > frontFloor ? rearFloor : frontFloor - contactSpan * sin(next.pitch)
            next.velocity = 0; next.phase = .edge; next.supportHeight = high
            next.fallDirection = frontFloor < rearFloor ? 1 : -1
            return next
        }
        if high < supportHeight - epsilon && (phase == .grounded || phase == .edge) {
            next.phase = .falling; next.velocity = 0
            if phase != .edge { next.fallDirection = forward == 0 ? 0 : forward > 0 ? 1 : -1 }
        }
        if next.phase == .falling {
            next.pitch = ROBBodyKinematics.moveToward(next.pitch, -0.35 * next.fallDirection, dt * 2.4)
            let gravity: Float = 9.81 * scale
            next.height += next.velocity * dt - 0.5 * gravity * dt * dt
            next.velocity -= gravity * dt
            let contactHeight = high - min(0, contactSpan * sin(next.pitch))
            if next.height <= contactHeight {
                next.height = contactHeight; next.velocity = 0; next.phase = .settling; next.supportHeight = high
            }
            return next
        }
        if next.phase == .settling || (next.phase == .edge && !mixedSupport) {
            next.pitch = ROBBodyKinematics.moveToward(next.pitch, 0, dt * 2.8)
            next.height = high - min(0, contactSpan * sin(next.pitch))
            next.velocity = 0; next.supportHeight = high
            next.phase = abs(next.pitch) < epsilon ? .grounded : .settling
            return next
        }
        return Self(height: mixedSupport ? low : centerFloor)
    }
}
