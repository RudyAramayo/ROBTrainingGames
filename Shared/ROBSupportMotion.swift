import Foundation
import simd

// Matches rob-support-motion.mjs. The hinge is above the upper (third) tread wheel.
// The reference photo's 8¼ inches is a pose length, not an actuator stroke.
enum ROBBodyKinematics {
    static let lactReferenceLength: Float = 0.20955
    static let leanHinge = SIMD3<Float>(0, 0.302 + 0.073, 0.065)
    // Approximate game mass center, not measured physical mass properties.
    static let torsoMassCenter = SIMD3<Float>(0, 0.78, 0.012)
    static let lactFixedPin = SIMD3<Float>(0, 0.30, -0.08)
    static let lactMovingPin = SIMD3<Float>(0, 0.30 + sqrt(lactReferenceLength * lactReferenceLength - 0.135 * 0.135), 0.055)

    static func moveToward(_ value: Float, _ target: Float, _ step: Float) -> Float {
        value + (target >= value ? 1 : -1) * min(abs(target - value), max(0, step))
    }
    static func targetLean(basePitch: Float) -> Float {
        let rear = SIMD3<Float>(0, 0, 0.212725)
        let frontZ = rear.z - 0.42545 * cos(basePitch)
        let hinge = rear + simd_quatf(angle: basePitch, axis: [1, 0, 0]).act(leanHinge - rear)
        let arm = torsoMassCenter - leanHinge
        let uprightZ = hinge.z + arm.z
        let supportedZ = max(frontZ + 0.07, min(rear.z - 0.07, uprightZ))
        // Pitching the tracks moves the hinge aft. Rotate the entire body
        // farther forward when vertical would put its mass behind the tracks.
        let bodyPitch: Float = abs(supportedZ - uprightZ) < 0.000001 ? 0
            : asin(max(-1, min(1, (supportedZ - hinge.z) / hypot(arm.y, arm.z)))) - atan2(arm.z, arm.y)
        return max(-1.45, min(1.15, bodyPitch - basePitch))
    }
    static func advanceLean(_ angle: Float, basePitch: Float, delta: TimeInterval) -> Float {
        let target = targetLean(basePitch: basePitch)
        // Presentation speed keeps pace with the simulated flipper motor.
        let length = lactLength(leanAngle: angle), targetLength = lactLength(leanAngle: target), step = 0.90 * Float(max(0, delta))
        if abs(targetLength - length) <= step { return target }
        let nextLength = moveToward(length, targetLength, step)
        // Monotonic branch of the illustrated linkage; presentation values.
        var low: Float = -1.45, high: Float = 1.15
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
        let massCenter: SIMD3<Float>
        var lactLength: Float { simd_distance(fixedPin, movingPin) }
    }
    static func torsoPose(basePitch: Float, leanAngle: Float, rearHeight: Float = 0, rootHeight: Float = 0, scale: Float = 1, yaw: Float = 0) -> TorsoPose {
        let rear = SIMD3<Float>(0, 0, 0.212725)
        let base = simd_quatf(angle: basePitch, axis: [1, 0, 0])
        let body = simd_quatf(angle: basePitch + leanAngle, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
        let hinge = rear + base.act(leanHinge - rear)
        let offset = hinge - body.act(leanHinge)
        return TorsoPose(position: offset * scale + [0, rearHeight - rootHeight, 0], orientation: body,
                         fixedPin: rear + base.act(lactFixedPin - rear), movingPin: offset + body.act(lactMovingPin),
                         massCenter: offset + body.act(torsoMassCenter))
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
        // A tread end can overhang while its continuous contact patch still
        // supports the center on the current deck. A higher, unreached plane
        // remains a step and cannot teleport ROB upward.
        let centerSupported = centerFloor >= high - epsilon && centerFloor <= supportHeight + epsilon
        let mixedSupport = high - min(frontFloor, rearFloor) > epsilon && !centerSupported
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
