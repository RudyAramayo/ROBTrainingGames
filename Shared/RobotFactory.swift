import RealityKit
import UIKit

@MainActor enum RobotFactory {
    static func makeROB(componentMode: Bool = false) -> Entity {
        let root = Entity(); root.name = "ROB"
        func part(_ name: String, _ size: SIMD3<Float>, _ position: SIMD3<Float>, _ color: UIColor) { let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.015), materials: [SimpleMaterial(color: color, isMetallic: true)]); entity.name = name; entity.position = position; root.addChild(entity) }
        part("Base", [0.72, 0.18, 0.82], [0, 0.18, 0], .black)
        part("Left Tread", [0.18, 0.32, 0.98], [-0.46, 0.2, 0], .darkGray); part("Right Tread", [0.18, 0.32, 0.98], [0.46, 0.2, 0], .darkGray)
        part("Cerebro", [0.66, 0.62, 0.54], [0, 0.62, 0], UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1))
        part("Left Arm", [0.13, 0.72, 0.13], [-0.5, 0.74, 0], componentMode ? .systemGreen : .gray); part("Right Arm", [0.13, 0.72, 0.13], [0.5, 0.74, 0], componentMode ? .systemBlue : .gray)
        part("Sensor Mast", [0.1, 0.52, 0.1], [0, 1.16, 0], .gray)
        let head = ModelEntity(mesh: .generateSphere(radius: 0.22), materials: [SimpleMaterial(color: .black, isMetallic: true)]); head.name = "Sensors"; head.position = [0, 1.52, 0]; root.addChild(head)
        for x: Float in [-0.18, 0.18] { let color: UIColor = x < 0 ? .systemGreen : .systemCyan; let ring = ModelEntity(mesh: .generateSphere(radius: 0.09), materials: [UnlitMaterial(color: color)]); ring.name = "Power & Status"; ring.position = [x, 0.67, -0.29]; root.addChild(ring) }
        root.components.set(InputTargetComponent()); root.generateCollisionShapes(recursive: true); return root
    }

    static func makeTrainingRoom(level: Int) -> Entity {
        let room = Entity(); room.name = "Training Room"
        let color: UIColor = level == 1 ? .systemIndigo : UIColor(white: 0.16, alpha: 1)
        let floor = ModelEntity(mesh: .generatePlane(width: 6, depth: 6), materials: [SimpleMaterial(color: color, isMetallic: false)]); room.addChild(floor)
        let layouts: [[SIMD3<Float>]] = [[[-1.4, 0.3, 0], [1.2, 0.3, -0.8]], [[-1.8, 0.3, -0.5], [0, 0.3, 0.4], [1.7, 0.3, -1.2]], [[-2, 0.3, 0], [-0.8, 0.3, -1], [0.8, 0.3, 0.8], [2, 0.3, -0.5]]]
        for (index, position) in layouts[min(level, 2)].enumerated() { let block = ModelEntity(mesh: .generateBox(size: [0.55, 0.6 + Float(index % 2) * 0.3, 0.75], cornerRadius: 0.04), materials: [SimpleMaterial(color: UIColor(white: 0.28, alpha: 1), isMetallic: true)]); block.position = position; room.addChild(block) }
        return room
    }
}
