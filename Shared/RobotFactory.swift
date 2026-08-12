import RealityKit
import UIKit

@MainActor enum RobotFactory {
    static func makeROB(componentMode: Bool = false) -> Entity {
        let root = Entity(); root.name = "ROB"
        func part(_ name: String, _ size: SIMD3<Float>, _ position: SIMD3<Float>, _ color: UIColor) { let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.015), materials: [SimpleMaterial(color: color, isMetallic: true)]); entity.name = name; entity.position = position; root.addChild(entity) }
        func cylinder(_ name: String, radius: Float, height: Float, position: SIMD3<Float>, color: UIColor, faceForward: Bool = false, sideways: Bool = false) {
            let entity = ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [SimpleMaterial(color: color, isMetallic: true)])
            entity.name = name; entity.position = position
            if faceForward { entity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) }
            if sideways { entity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1]) }
            root.addChild(entity)
        }
        part("Base", [0.72, 0.22, 0.82], [0, 0.2, 0], .black)
        part("Left Tread", [0.2, 0.34, 1.02], [-0.47, 0.22, 0], UIColor(white: 0.04, alpha: 1)); part("Right Tread", [0.2, 0.34, 1.02], [0.47, 0.22, 0], UIColor(white: 0.04, alpha: 1))
        for x: Float in [-0.47, 0.47] { for z: Float in [-0.32, 0, 0.32] { cylinder("Tread Wheel", radius: 0.12, height: 0.21, position: [x, 0.22, z], color: .darkGray, sideways: true) } }
        part("Cerebro Torso", [0.68, 0.64, 0.54], [0, 0.72, 0], UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1))
        for x: Float in [-0.19, 0.19] {
            let color: UIColor = x < 0 ? .systemBlue : .systemCyan
            cylinder("Torso Light Ring", radius: 0.12, height: 0.025, position: [x, 0.8, -0.285], color: color, faceForward: true)
            cylinder("Torso Speaker", radius: 0.078, height: 0.032, position: [x, 0.8, -0.305], color: UIColor(white: 0.025, alpha: 1), faceForward: true)
        }
        part("Depth Camera", [0.2, 0.1, 0.065], [0, 0.59, -0.3], .gray)
        cylinder("Front Linear Actuator", radius: 0.045, height: 0.72, position: [0, 0.28, -0.62], color: .gray, faceForward: true)
        for side: Float in [-1, 1] {
            let armColor: UIColor = componentMode ? (side < 0 ? .systemGreen : .systemBlue) : .gray
            let prefix = side < 0 ? "Left" : "Right"
            let jointX = side * 0.51
            cylinder("\(prefix) Shoulder Joint", radius: 0.095, height: 0.15, position: [jointX, 0.93, 0], color: .darkGray, sideways: true)
            part("\(prefix) Upper Arm", [0.12, 0.32, 0.13], [side * 0.56, 0.75, 0], armColor)
            cylinder("\(prefix) Elbow Joint", radius: 0.075, height: 0.13, position: [side * 0.59, 0.57, -0.01], color: .darkGray, sideways: true)
            part("\(prefix) Forearm", [0.1, 0.28, 0.11], [side * 0.61, 0.41, -0.02], armColor)
            cylinder("\(prefix) Wrist Joint", radius: 0.06, height: 0.11, position: [side * 0.62, 0.25, -0.03], color: .darkGray, sideways: true)
            for joint in 0..<4 {
                cylinder("\(prefix) AMBER Joint \(joint + 4)", radius: 0.035, height: 0.08, position: [side * (0.62 + Float(joint) * 0.035), 0.22, -0.09 - Float(joint) * 0.07], color: joint.isMultiple(of: 2) ? .lightGray : .darkGray, sideways: true)
            }
            cylinder("\(prefix) Lightsaber", radius: 0.025, height: 0.78, position: [side * 0.75, 0.29, -0.48], color: side < 0 ? .systemGreen : .systemCyan, faceForward: true)
        }
        cylinder("Training Laser", radius: 0.018, height: 0.45, position: [0, 0.82, -0.8], color: .systemRed, faceForward: true)
        part("Sensor Mast", [0.1, 0.48, 0.1], [0, 1.2, 0], .gray)
        let head = ModelEntity(mesh: .generateSphere(radius: 0.22), materials: [SimpleMaterial(color: .black, isMetallic: true)]); head.name = "Camera Head"; head.position = [0, 1.52, 0]; head.scale.z = 0.82; root.addChild(head)
        cylinder("Head Camera", radius: 0.055, height: 0.045, position: [0, 1.52, -0.2], color: .systemGreen, faceForward: true)
        root.components.set(InputTargetComponent()); root.generateCollisionShapes(recursive: true); return root
    }

    static func applyWeapons(to robot: Entity, session: GameSession) {
        let swing = Float(sin(session.saberAnimation * .pi))
        for name in ["Left Lightsaber", "Right Lightsaber"] {
            guard let saber = robot.findEntity(named: name) else { continue }
            let side: Float = name.hasPrefix("Left") ? -1 : 1
            saber.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * simd_quatf(angle: side * swing * 1.25, axis: [0, 1, 0])
        }
        if let laser = robot.findEntity(named: "Training Laser") {
            if let distance = session.laserDistance { laser.isEnabled = true; laser.position = [0, 0.82, -distance] } else { laser.isEnabled = false }
        }
    }

    static func makeTrainingRoom(level: Int) -> Entity {
        let room = Entity(); room.name = "Training Room"
        let color: UIColor = level == 1 ? .systemIndigo : UIColor(white: 0.16, alpha: 1)
        let floor = ModelEntity(mesh: .generatePlane(width: 6, depth: 6), materials: [SimpleMaterial(color: color, isMetallic: false)]); room.addChild(floor)
        let layouts: [[SIMD3<Float>]] = [[[-1.4, 0.3, 0], [1.2, 0.3, -0.8]], [[-1.8, 0.3, -0.5], [0, 0.3, 0.4], [1.7, 0.3, -1.2]], [[-2, 0.3, 0], [-0.8, 0.3, -1], [0.8, 0.3, 0.8], [2, 0.3, -0.5]]]
        for (index, position) in layouts[level % layouts.count].enumerated() { let block = ModelEntity(mesh: .generateBox(size: [0.48, 0.6 + Float(index % 2) * 0.3, 0.68], cornerRadius: 0.08), materials: [SimpleMaterial(color: UIColor(white: 0.28, alpha: 1), isMetallic: true)]); block.position = position; room.addChild(block) }
        return room
    }
}
