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

    static func combatLayerName(level: Int) -> String { "Combat Layer-\(level)" }

    static func makeCombatLayer(session: GameSession) -> Entity {
        let root = Entity(); root.name = combatLayerName(level: session.levelIndex)
        for enemy in session.enemies { root.addChild(makeEnemy(enemy)) }
        applyCombatState(to: root, session: session)
        return root
    }

    private static func makeEnemy(_ enemy: TrainingEnemy) -> Entity {
        let root = Entity(); root.name = "Training Enemy \(enemy.id)"
        func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ color: UIColor) { let part = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.02), materials: [SimpleMaterial(color: color, isMetallic: true)]); part.position = position; root.addChild(part) }
        func cylinder(radius: Float, height: Float, position: SIMD3<Float>, color: UIColor) { let part = ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [SimpleMaterial(color: color, isMetallic: true)]); part.position = position; root.addChild(part) }
        if enemy.kind == .spider {
            box([0.62, 0.2, 0.5], [0, 0.3, 0], .darkGray)
            let skull = ModelEntity(mesh: .generateSphere(radius: 0.22), materials: [SimpleMaterial(color: UIColor(red: 0.88, green: 0.84, blue: 0.7, alpha: 1), isMetallic: false)]); skull.position = [0, 0.5, -0.18]; skull.scale.z = 1.25; root.addChild(skull)
            for side: Float in [-1, 1] { for row: Float in [-1, 1] { box([0.46, 0.07, 0.09], [side * 0.43, 0.24, row * 0.2], .gray); box([0.08, 0.32, 0.1], [side * 0.68, 0.12, row * 0.2], UIColor(white: 0.82, alpha: 1)) } }
        } else {
            cylinder(radius: 0.38, height: 0.64, position: [0, 0.34, 0], color: .lightGray)
            cylinder(radius: 0.27, height: 0.24, position: [0, 0.78, 0], color: .darkGray)
            let dome = ModelEntity(mesh: .generateSphere(radius: 0.28), materials: [SimpleMaterial(color: .lightGray, isMetallic: true)]); dome.position = [0, 0.94, 0]; dome.scale.y = 0.55; root.addChild(dome)
            let eye = ModelEntity(mesh: .generateBox(size: [0.08, 0.08, 0.48], cornerRadius: 0.02), materials: [SimpleMaterial(color: .systemCyan, isMetallic: true)]); eye.position = [0, 0.96, -0.37]; root.addChild(eye)
            for y: Float in [0.18, 0.38, 0.58] { for x: Float in [-0.22, 0, 0.22] { let light = ModelEntity(mesh: .generateSphere(radius: 0.055), materials: [SimpleMaterial(color: .systemBlue, isMetallic: true)]); light.position = [x, y, -0.31]; root.addChild(light) } }
        }
        return root
    }

    static func applyCombatState(to layer: Entity, session: GameSession) {
        for enemy in session.enemies {
            guard let entity = layer.findEntity(named: "Training Enemy \(enemy.id)") else { continue }
            entity.isEnabled = enemy.isActive
            entity.position = enemy.position + SIMD3<Float>(0, enemy.kind == .spider ? Float(sin(session.elapsed * 10 + Double(enemy.id))) * 0.025 : Float(sin(session.elapsed * 2.4 + Double(enemy.id))) * 0.015, 0)
            entity.orientation = simd_quatf(angle: enemy.heading, axis: [0, 1, 0])
        }
        let boltNames = Set(session.enemyBolts.map { "Enemy Bolt \($0.id)" })
        for child in Array(layer.children) where child.name.hasPrefix("Enemy Bolt ") && !boltNames.contains(child.name) { child.removeFromParent() }
        for bolt in session.enemyBolts {
            let name = "Enemy Bolt \(bolt.id)"
            let entity: Entity
            if let existing = layer.findEntity(named: name) { entity = existing }
            else { let created = ModelEntity(mesh: .generateSphere(radius: 0.055), materials: [SimpleMaterial(color: .systemCyan, isMetallic: true)]); created.name = name; layer.addChild(created); entity = created }
            entity.position = bolt.position
        }
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

    static func makeTrainingRoom(level: Int, puzzle: PuzzleGeometry) -> Entity {
        let room = Entity(); room.name = "Training Room-\(level)"
        let color: UIColor = level == 1 ? .systemIndigo : UIColor(white: 0.16, alpha: 1)
        let floor = ModelEntity(mesh: .generatePlane(width: 6, depth: 6), materials: [SimpleMaterial(color: color, isMetallic: false)]); room.addChild(floor)
        for barrier in puzzle.barriers { let block = ModelEntity(mesh: .generateBox(size: [barrier.size.x, 0.75, barrier.size.y], cornerRadius: 0.03), materials: [SimpleMaterial(color: UIColor(white: 0.28, alpha: 1), isMetallic: true)]); block.position = [barrier.center.x, 0.375, barrier.center.y]; room.addChild(block) }
        if let door = puzzle.door { let entity = ModelEntity(mesh: .generateBox(size: [door.size.x, 0.9, door.size.y], cornerRadius: 0.025), materials: [SimpleMaterial(color: .systemRed, isMetallic: true)]); entity.name = "Puzzle Door"; entity.position = [door.center.x, 0.45, door.center.y]; room.addChild(entity) }
        if let key = puzzle.key { let entity = ModelEntity(mesh: .generateBox(size: [0.28, 0.08, 0.12], cornerRadius: 0.04), materials: [SimpleMaterial(color: .systemCyan, isMetallic: true)]); entity.name = "Puzzle Key"; entity.position = [key.x, 0.2, key.y]; room.addChild(entity) }
        for (index, cell) in puzzle.cells.enumerated() { let entity = ModelEntity(mesh: .generateCylinder(height: 0.28, radius: 0.11), materials: [SimpleMaterial(color: .systemYellow, isMetallic: true)]); entity.name = "Puzzle Cell \(index)"; entity.position = [cell.x, 0.2, cell.y]; room.addChild(entity) }
        let dock = ModelEntity(mesh: .generateBox(size: [0.7, 0.025, 0.7], cornerRadius: 0.08), materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]); dock.name = "Puzzle Dock"; dock.position = [puzzle.dock.x, 0.02, puzzle.dock.y]; room.addChild(dock)
        return room
    }

    static func applyPuzzleState(to room: Entity, session: GameSession) {
        room.findEntity(named: "Puzzle Key")?.isEnabled = !session.hasKey
        room.findEntity(named: "Puzzle Door")?.isEnabled = !session.doorOpen
        for index in session.puzzle.cells.indices { room.findEntity(named: "Puzzle Cell \(index)")?.isEnabled = !session.collectedCellIndices.contains(index) }
    }
}
