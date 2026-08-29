import RealityKit
import UIKit

@MainActor enum RobotFactory {
    static func finishColor(for finish: ROBFinish) -> UIColor {
        switch finish {
        case .graphite: UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1)
        case .rescueOrange: UIColor(red: 0.92, green: 0.28, blue: 0.055, alpha: 1)
        case .arcticWhite: UIColor(white: 0.86, alpha: 1)
        case .cobaltBlue: UIColor(red: 0.05, green: 0.22, blue: 0.62, alpha: 1)
        case .tacticalGreen: UIColor(red: 0.14, green: 0.31, blue: 0.18, alpha: 1)
        }
    }

    static func faceColor(for color: ROBFaceColor) -> UIColor {
        switch color {
        case .lime: UIColor(red: 0.36, green: 1, blue: 0.42, alpha: 1)
        case .cyan: UIColor(red: 0.32, green: 0.91, blue: 1, alpha: 1)
        case .amber: UIColor(red: 1, green: 0.71, blue: 0.23, alpha: 1)
        case .magenta: UIColor(red: 1, green: 0.38, blue: 0.82, alpha: 1)
        case .white: UIColor(red: 0.95, green: 0.97, blue: 1, alpha: 1)
        case .red: UIColor(red: 1, green: 0.32, blue: 0.41, alpha: 1)
        }
    }

    static func makeROB(
        componentMode: Bool = false,
        arPresentation: Bool = false
    ) -> ModelEntity {
        let root = ModelEntity(); root.name = "ROB"
        @discardableResult func part(_ name: String, _ size: SIMD3<Float>, _ position: SIMD3<Float>, _ color: UIColor, parent: Entity? = nil) -> ModelEntity { let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.015), materials: [SimpleMaterial(color: color, isMetallic: !arPresentation)]); entity.name = name; entity.position = position; (parent ?? root).addChild(entity); return entity }
        func cylinder(_ name: String, radius: Float, height: Float, position: SIMD3<Float>, color: UIColor, faceForward: Bool = false, sideways: Bool = false, parent: Entity? = nil) {
            let entity = ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [SimpleMaterial(color: color, isMetallic: !arPresentation)])
            entity.name = name; entity.position = position
            if faceForward { entity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) }
            if sideways { entity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1]) }
            (parent ?? root).addChild(entity)
        }
        part("Tri-Wheel Chassis", [0.72, 0.2, 0.68], [0, 0.48, 0], .black)
        for side: Float in [-1, 1] {
            let prefix = side < 0 ? "Left" : "Right"
            let tread = Entity(); tread.name = "\(prefix) Tri-Wheel Tread"; tread.position = [side * 0.47, 0, 0]; root.addChild(tread)

            // ROB's physical base uses a continuous cleated belt wrapped around a
            // triangular three-wheel bogie. Build the belt from tangent rails and
            // individual shoes so its silhouette matches the real tracked base.
            let beltPath: [SIMD2<Float>] = [
                [-0.51, 0.06], [0.51, 0.06], [0.43, 0.28],
                [0.18, 0.59], [-0.18, 0.59], [-0.43, 0.28],
            ]
            var shoeIndex = 0
            for segmentIndex in beltPath.indices {
                let start = beltPath[segmentIndex]
                let end = beltPath[(segmentIndex + 1) % beltPath.count]
                let delta = end - start
                let length = simd_length(delta)
                let angle = atan2(-delta.y, delta.x)
                let center = (start + end) / 2
                let rail = part(
                    "\(prefix) Track Belt Segment \(segmentIndex + 1)",
                    [0.27, 0.07, length + 0.025],
                    [0, center.y, center.x],
                    UIColor(white: 0.018, alpha: 1),
                    parent: tread
                )
                rail.orientation = simd_quatf(angle: angle, axis: [1, 0, 0])

                let segmentShoeCount = max(1, Int((length / 0.115).rounded(.up)))
                for offset in 0..<segmentShoeCount {
                    shoeIndex += 1
                    let progress = (Float(offset) + 0.5) / Float(segmentShoeCount)
                    let point = start + delta * progress
                    let shoe = part(
                        "\(prefix) Tread Shoe \(shoeIndex)",
                        [0.31, 0.1, min(0.09, length / Float(segmentShoeCount) * 0.82)],
                        [0, point.y, point.x],
                        UIColor(white: 0.055, alpha: 1),
                        parent: tread
                    )
                    shoe.orientation = simd_quatf(angle: angle, axis: [1, 0, 0])
                }
            }

            let wheelLayout: [(z: Float, y: Float, radius: Float)] = [(-0.35, 0.22, 0.16), (0, 0.43, 0.15), (0.35, 0.22, 0.16)]
            for (index, wheelSpec) in wheelLayout.enumerated() {
                let wheel = Entity(); wheel.name = "\(prefix) Tri-Wheel \(index + 1)"; wheel.position = [0, wheelSpec.y, wheelSpec.z]; tread.addChild(wheel)
                cylinder("\(prefix) Tri-Wheel Tire", radius: wheelSpec.radius, height: 0.285, position: .zero, color: UIColor(white: 0.025, alpha: 1), sideways: true, parent: wheel)
                cylinder("\(prefix) Tri-Wheel Rim", radius: wheelSpec.radius * 0.67, height: 0.3, position: .zero, color: .darkGray, sideways: true, parent: wheel)
                cylinder("\(prefix) Tri-Wheel Hub", radius: wheelSpec.radius * 0.25, height: 0.315, position: .zero, color: .systemOrange, sideways: true, parent: wheel)
            }
        }

        let torso = Entity(); torso.name = "Torso Assembly"; root.addChild(torso)
        part("Cerebro Torso", [0.68, 0.64, 0.54], [0, 0.72, 0], UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1), parent: torso)
        for x: Float in [-0.19, 0.19] {
            let color: UIColor = x < 0 ? .systemBlue : .systemCyan
            cylinder("Torso Light Ring", radius: 0.12, height: 0.025, position: [x, 0.8, -0.285], color: color, faceForward: true, parent: torso)
            cylinder("Torso Speaker", radius: 0.078, height: 0.032, position: [x, 0.8, -0.305], color: UIColor(white: 0.025, alpha: 1), faceForward: true, parent: torso)
        }
        part("Depth Camera", [0.2, 0.1, 0.065], [0, 0.59, -0.3], .gray, parent: torso)
        let flipper = Entity(); flipper.name = "Flipper Zero Hacker"; torso.addChild(flipper)
        part("Flipper Zero Orange Case", [0.13, 0.2, 0.045], [0.3, 0.7, -0.315], .systemOrange, parent: flipper)
        part("Flipper Zero Screen", [0.082, 0.07, 0.012], [0.3, 0.73, -0.344], UIColor(red: 0.12, green: 0.42, blue: 0.2, alpha: 1), parent: flipper)
        for side: Float in [-1, 1] {
            let armColor: UIColor = componentMode ? (side < 0 ? .systemGreen : .systemBlue) : .gray
            let prefix = side < 0 ? "Left" : "Right"
            let arm = Entity(); arm.name = "\(prefix) Arm Assembly"; arm.position = [side * 0.51, 0.93, 0]; torso.addChild(arm)
            cylinder("\(prefix) Shoulder Joint", radius: 0.095, height: 0.15, position: [0, 0, 0], color: .darkGray, sideways: true, parent: arm)
            part("\(prefix) Upper Arm", [0.12, 0.32, 0.13], [side * 0.05, -0.18, 0], armColor, parent: arm)
            cylinder("\(prefix) Elbow Joint", radius: 0.075, height: 0.13, position: [side * 0.08, -0.36, -0.01], color: .darkGray, sideways: true, parent: arm)
            part("\(prefix) Forearm", [0.1, 0.28, 0.11], [side * 0.1, -0.52, -0.02], armColor, parent: arm)
            cylinder("\(prefix) Wrist Joint", radius: 0.06, height: 0.11, position: [side * 0.11, -0.68, -0.03], color: .darkGray, sideways: true, parent: arm)
            for joint in 0..<4 {
                cylinder("\(prefix) AMBER Joint \(joint + 4)", radius: 0.035, height: 0.08, position: [side * (0.12 + Float(joint) * 0.035), -0.71, -0.09 - Float(joint) * 0.07], color: joint.isMultiple(of: 2) ? .lightGray : .darkGray, sideways: true, parent: arm)
            }
            cylinder("\(prefix) Lightsaber", radius: 0.025, height: 0.9, position: [side * 0.24, -0.64, -0.55], color: side < 0 ? .systemGreen : .systemCyan, faceForward: true, parent: arm)
        }

        if let rightArm = root.findEntity(named: "Right Arm Assembly") {
            let hammer = Entity(); hammer.name = "Power Hammer"; rightArm.addChild(hammer)
            cylinder("Power Hammer Handle", radius: 0.035, height: 0.72, position: [0.2, -0.64, -0.46], color: .darkGray, faceForward: true, parent: hammer)
            part("Power Hammer Head", [0.42, 0.2, 0.2], [0.2, -0.64, -0.83], .systemOrange, parent: hammer)
        }

        let gatling = Entity(); gatling.name = "Right Shoulder Gatling"; gatling.position = [0.5, 1.08, -0.05]; torso.addChild(gatling)
        part("Gatling Housing", [0.24, 0.2, 0.38], [0, 0, -0.08], .black, parent: gatling)
        let barrelCluster = Entity(); barrelCluster.name = "Gatling Barrel Cluster"; gatling.addChild(barrelCluster)
        for x: Float in [-0.055, 0.055] { for y: Float in [-0.055, 0.055] { cylinder("Gatling Barrel", radius: 0.018, height: 0.52, position: [x, y, -0.36], color: .black, faceForward: true, parent: barrelCluster) } }
        let lockLamp = ModelEntity(mesh: .generateSphere(radius: 0.055), materials: [SimpleMaterial(color: .systemRed, isMetallic: true)]); lockLamp.name = "Gatling Lock Indicator"; lockLamp.position = [0, 0.15, -0.22]; gatling.addChild(lockLamp)

        let twinBlasters = Entity(); twinBlasters.name = "Twin Blasters"; twinBlasters.position = [0, 0.98, -0.04]; torso.addChild(twinBlasters)
        for side: Float in [-1, 1] {
            part(side < 0 ? "Left Blaster Housing" : "Right Blaster Housing", [0.2, 0.15, 0.28], [side * 0.47, 0, -0.08], .systemBlue, parent: twinBlasters)
            for x: Float in [-0.035, 0.035] {
                cylinder("Blaster Barrel", radius: 0.018, height: 0.46, position: [side * 0.47 + x, 0, -0.34], color: .black, faceForward: true, parent: twinBlasters)
            }
        }

        let arcCannon = Entity(); arcCannon.name = "Arc Cannon"; arcCannon.position = [0, 1.12, -0.04]; torso.addChild(arcCannon)
        part("Arc Cannon Housing", [0.34, 0.24, 0.42], [0, 0, -0.1], .systemPurple, parent: arcCannon)
        for side: Float in [-1, 1] {
            cylinder("Arc Cannon Conductor", radius: 0.035, height: 0.54, position: [side * 0.105, 0, -0.4], color: .systemCyan, faceForward: true, parent: arcCannon)
        }
        let arcCore = ModelEntity(mesh: .generateSphere(radius: 0.08), materials: [UnlitMaterial(color: .systemCyan)]); arcCore.name = "Arc Cannon Core"; arcCore.position = [0, 0.02, -0.34]; arcCannon.addChild(arcCore)

        let shot = Entity(); shot.name = "Shoulder Laser Shot"; shot.position = [0.5, 1.08, -0.28]; torso.addChild(shot)
        let beam = ModelEntity(mesh: .generateBox(size: [1, 1, 0.55], cornerRadius: 0.04), materials: [SimpleMaterial(color: .systemRed, isMetallic: true)]); beam.name = "Shoulder Laser Beam"; beam.isEnabled = false; shot.addChild(beam)

        part("Sensor Mast", [0.1, 0.48, 0.1], [0, 1.2, 0], .gray, parent: torso)
        let head = ModelEntity(mesh: .generateSphere(radius: 0.22), materials: [SimpleMaterial(color: .black, isMetallic: !arPresentation)]); head.name = "Camera Head"; head.position = [0, 1.52, 0]; head.scale.z = 0.82; torso.addChild(head)
        let smileMaterial = UnlitMaterial(color: faceColor(for: .lime))
        let smileParts: [(String, Float, Float, Float)] = [
            ("Face Smiley Left Eye", -0.075, 1.565, 0.026),
            ("Face Smiley Right Eye", 0.075, 1.565, 0.026),
            ("Face Smiley Left Corner", -0.09, 1.475, 0.022),
            ("Face Smiley Left Smile", -0.045, 1.45, 0.022),
            ("Face Smiley Center Smile", 0, 1.44, 0.022),
            ("Face Smiley Right Smile", 0.045, 1.45, 0.022),
            ("Face Smiley Right Corner", 0.09, 1.475, 0.022),
        ]
        for (name, x, y, radius) in smileParts {
            let pixel = ModelEntity(mesh: .generateCylinder(height: 0.018, radius: radius), materials: [smileMaterial])
            pixel.name = name
            pixel.position = [x, y, -0.202]
            pixel.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            torso.addChild(pixel)
        }
        root.components.set(InputTargetComponent())
        root.generateCollisionShapes(recursive: true)
        root.collision = CollisionComponent(shapes: [
            .generateBox(size: [1.6, 1.85, 1.6]).offsetBy(translation: [0, 0.86, -0.28]),
        ])
        let shieldField = ModelEntity(
            mesh: .generateSphere(radius: 1.05),
            materials: [SimpleMaterial(color: UIColor.systemCyan.withAlphaComponent(0.11), isMetallic: false)]
        )
        shieldField.name = "ROB Shield Field"
        shieldField.position = [0, 0.92, -0.08]
        shieldField.scale = [1, 0.92, 1]
        root.addChild(shieldField)
        return root
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
        if enemy.isBoss {
            root.scale = .init(repeating: enemy.combatScale)
            let core = ModelEntity(mesh: .generateSphere(radius: 0.13), materials: [SimpleMaterial(color: .systemRed, isMetallic: true)])
            core.name = "Boss Core"
            core.position = [0, enemy.kind == .spider ? 0.55 : 1.18, 0]
            root.addChild(core)
            let beacon = ModelEntity(mesh: .generateCylinder(height: 0.08, radius: 0.22), materials: [SimpleMaterial(color: .systemOrange, isMetallic: true)])
            beacon.name = "Boss Beacon"
            beacon.position = core.position + SIMD3<Float>(0, 0.18, 0)
            root.addChild(beacon)
        }
        return root
    }

    static func applyCombatState(to layer: Entity, session: GameSession) {
        for enemy in session.enemies {
            let name = "Training Enemy \(enemy.id)"
            let entity: Entity
            if let existing = layer.findEntity(named: name) { entity = existing }
            else { let created = makeEnemy(enemy); layer.addChild(created); entity = created }
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
            else { let created = ModelEntity(mesh: .generateSphere(radius: bolt.isBoss ? 0.09 : 0.055), materials: [SimpleMaterial(color: bolt.isBoss ? .systemRed : .systemCyan, isMetallic: true)]); created.name = name; layer.addChild(created); entity = created }
            entity.position = bolt.position
        }
    }

    static func applyWeapons(
        to robot: Entity,
        session: GameSession,
        componentMode: Bool = false,
        arPresentation: Bool = false
    ) {
        let appearanceName = "Applied Appearance \(componentMode ? "components" : session.robotFinish.rawValue)"
        if robot.children.first(where: { $0.name == appearanceName }) == nil {
            for marker in Array(robot.children) where marker.name.hasPrefix("Applied Appearance ") { marker.removeFromParent() }
            let marker = Entity(); marker.name = appearanceName; robot.addChild(marker)
            let bodyMaterial = SimpleMaterial(color: componentMode ? finishColor(for: .graphite) : finishColor(for: session.robotFinish), isMetallic: !arPresentation)
            for name in ["Tri-Wheel Chassis", "Cerebro Torso", "Camera Head"] {
                (robot.findEntity(named: name) as? ModelEntity)?.model?.materials = [bodyMaterial]
            }
            for side in ["Left", "Right"] {
                let color: UIColor = componentMode ? (side == "Left" ? .systemGreen : .systemBlue) : finishColor(for: session.robotFinish)
                let material = SimpleMaterial(color: color, isMetallic: !arPresentation)
                for name in ["\(side) Upper Arm", "\(side) Forearm"] {
                    (robot.findEntity(named: name) as? ModelEntity)?.model?.materials = [material]
                }
            }
        }
        let smileMaterial = UnlitMaterial(color: faceColor(for: session.faceColor))
        for name in [
            "Face Smiley Left Eye", "Face Smiley Right Eye", "Face Smiley Left Corner",
            "Face Smiley Left Smile", "Face Smiley Center Smile", "Face Smiley Right Smile",
            "Face Smiley Right Corner",
        ] {
            (robot.findEntity(named: name) as? ModelEntity)?.model?.materials = [smileMaterial]
        }
        robot.findEntity(named: "Right Shoulder Gatling")?.isEnabled = session.rangedWeapon == .shoulderGatling
        robot.findEntity(named: "Twin Blasters")?.isEnabled = session.rangedWeapon == .twinBlasters
        robot.findEntity(named: "Arc Cannon")?.isEnabled = session.rangedWeapon == .arcCannon
        robot.findEntity(named: "Left Lightsaber")?.isEnabled = session.meleeWeapon == .dualSabers
        robot.findEntity(named: "Right Lightsaber")?.isEnabled = session.meleeWeapon == .dualSabers
        robot.findEntity(named: "Power Hammer")?.isEnabled = session.meleeWeapon == .powerHammer
        if let shieldField = robot.findEntity(named: "ROB Shield Field") {
            shieldField.isEnabled = session.shields > 0
            let pulse = 0.98 + Float(sin(session.elapsed * 3.2)) * 0.025
            shieldField.scale = [pulse, pulse * 0.92, pulse]
        }
        let bladeScale: Float = session.meleeWeapon == .dualSabers && session.saberAnimation > 0 ? 1 : 0.06
        for (name, side) in [("Left Lightsaber", Float(-1)), ("Right Lightsaber", Float(1))] {
            guard let blade = robot.findEntity(named: name) else { continue }
            blade.scale = [1, bladeScale, 1]
            blade.position = [side * 0.24, -0.64, -0.1 - 0.45 * bladeScale]
        }
        for (prefix, angle) in [("Left", session.leftWheelAngle), ("Right", session.rightWheelAngle)] {
            for index in 1...3 { robot.findEntity(named: "\(prefix) Tri-Wheel \(index)")?.orientation = simd_quatf(angle: angle, axis: [1, 0, 0]) }
        }
        let progress = Float(1 - session.saberAnimation), arc = sin(progress * .pi)
        let torso = robot.findEntity(named: "Torso Assembly")
        var torsoYaw: Float = 0
        if let style = session.saberStyle, session.saberAnimation > 0 {
            switch style {
            case .spin: torsoYaw = progress * 2 * .pi
            case .leftSweep: torsoYaw = -arc * 0.24
            case .rightSweep: torsoYaw = arc * 0.24
            case .hammerSmash: torsoYaw = 0
            }
        }
        torso?.orientation = simd_quatf(angle: torsoYaw, axis: [0, 1, 0])
        for (name, side) in [("Left Arm Assembly", Float(-1)), ("Right Arm Assembly", Float(1))] {
            guard let arm = robot.findEntity(named: name) else { continue }
            guard let style = session.saberStyle, session.saberAnimation > 0 else { arm.orientation = simd_quatf(angle: 0, axis: [0, 1, 0]); continue }
            if style == .hammerSmash {
                arm.orientation = name.hasPrefix("Right")
                    ? simd_quatf(angle: -1.25 + progress * 2.35, axis: [1, 0, 0])
                    : simd_quatf(angle: 0, axis: [0, 1, 0])
            } else if style == .spin {
                arm.orientation = simd_quatf(angle: side * .pi / 2, axis: [0, 0, 1])
            } else {
                let direction: Float = style == .leftSweep ? -1 : 1
                let sweep = direction * (-1.3 + progress * 2.6)
                arm.orientation = simd_quatf(angle: sweep, axis: [0, 1, 0]) * simd_quatf(angle: side * arc * 0.5, axis: [0, 0, 1])
            }
        }
        let relativeHeading = session.laserLockHeading.map { $0 - session.robotHeading - torsoYaw } ?? Float(sin(session.elapsed * 0.85)) * 0.9
        for name in ["Right Shoulder Gatling", "Twin Blasters", "Arc Cannon"] {
            robot.findEntity(named: name)?.orientation = simd_quatf(angle: relativeHeading, axis: [0, 1, 0])
        }
        if let lamp = robot.findEntity(named: "Gatling Lock Indicator") {
            lamp.isEnabled = session.lockedEnemy != nil
            let pulse = 0.9 + Float(sin(session.elapsed * 9)) * 0.18
            lamp.scale = .init(repeating: pulse)
        }
        robot.findEntity(named: "Gatling Barrel Cluster")?.orientation = simd_quatf(angle: Float(session.elapsed) * 7 + Float(session.laserCharge) * 12, axis: [0, 0, 1])
        if let shot = robot.findEntity(named: "Shoulder Laser Shot"), let beam = robot.findEntity(named: "Shoulder Laser Beam") {
            shot.orientation = simd_quatf(angle: session.laserShotHeading - session.robotHeading - torsoYaw, axis: [0, 1, 0])
            if let distance = session.laserDistance {
                let charge = Float(session.laserShotCharge), width = 0.035 + charge * 0.13
                if let beam = beam as? ModelEntity {
                    let appearanceName = "Projectile Appearance \(session.laserShotWeapon.rawValue)"
                    if beam.children.first(where: { $0.name == appearanceName }) == nil {
                        for marker in Array(beam.children) where marker.name.hasPrefix("Projectile Appearance ") { marker.removeFromParent() }
                        let marker = Entity(); marker.name = appearanceName; beam.addChild(marker)
                        let color: UIColor = switch session.laserShotWeapon {
                        case .shoulderGatling: .systemRed
                        case .twinBlasters: .systemBlue
                        case .arcCannon: .systemCyan
                        }
                        beam.model?.materials = [UnlitMaterial(color: color)]
                    }
                }
                beam.isEnabled = true; beam.position = [0, 0, -distance]; beam.scale = [width, width, 1 + charge * 2.6]
            } else { beam.isEnabled = false }
        }
    }

    static func makeTrainingRoom(level: Int, puzzle: PuzzleGeometry, arPresentation: Bool = false) -> Entity {
        let room = Entity(); room.name = "Training Room-\(level)"
        let color: UIColor = level == 1 ? .systemIndigo : UIColor(white: 0.16, alpha: 1)
        let size = puzzle.arenaHalfExtent * 2
        let floorColor = arPresentation ? color.withAlphaComponent(0.38) : color
        let wallColor = UIColor(white: 0.12, alpha: arPresentation ? 0.82 : 1)
        let barrierColor = UIColor(white: 0.28, alpha: arPresentation ? 0.88 : 1)
        let floor = ModelEntity(mesh: .generatePlane(width: size, depth: size), materials: [SimpleMaterial(color: floorColor, isMetallic: false)]); floor.name = "Training Floor"; room.addChild(floor)
        for (position, wallSize) in [
            (SIMD3<Float>(0, 0.55, -puzzle.arenaHalfExtent), SIMD3<Float>(size, 1.1, 0.18)),
            (SIMD3<Float>(0, 0.55, puzzle.arenaHalfExtent), SIMD3<Float>(size, 1.1, 0.18)),
            (SIMD3<Float>(-puzzle.arenaHalfExtent, 0.55, 0), SIMD3<Float>(0.18, 1.1, size)),
            (SIMD3<Float>(puzzle.arenaHalfExtent, 0.55, 0), SIMD3<Float>(0.18, 1.1, size)),
        ] { let wall = ModelEntity(mesh: .generateBox(size: wallSize, cornerRadius: 0.03), materials: [SimpleMaterial(color: wallColor, isMetallic: !arPresentation)]); wall.position = position; room.addChild(wall) }
        for barrier in puzzle.barriers { let block = ModelEntity(mesh: .generateBox(size: [barrier.size.x, 0.75, barrier.size.y], cornerRadius: 0.03), materials: [SimpleMaterial(color: barrierColor, isMetallic: !arPresentation)]); block.position = [barrier.center.x, 0.375, barrier.center.y]; room.addChild(block) }
        if let door = puzzle.door { let entity = ModelEntity(mesh: .generateBox(size: [door.size.x, 0.9, door.size.y], cornerRadius: 0.025), materials: [SimpleMaterial(color: .systemRed, isMetallic: true)]); entity.name = "Puzzle Door"; entity.position = [door.center.x, 0.45, door.center.y]; room.addChild(entity) }
        if let terminal = puzzle.hackTerminal {
            let root = Entity(); root.name = "Hack Terminal"; root.position = [terminal.x, 0, terminal.y]; room.addChild(root)
            let post = ModelEntity(mesh: .generateBox(size: [0.18, 0.62, 0.18], cornerRadius: 0.025), materials: [SimpleMaterial(color: .darkGray, isMetallic: true)]); post.position.y = 0.31; root.addChild(post)
            let panel = ModelEntity(mesh: .generateBox(size: [0.34, 0.32, 0.12], cornerRadius: 0.035), materials: [SimpleMaterial(color: .systemOrange, isMetallic: true)]); panel.name = "Hack Terminal Panel"; panel.position = [0, 0.65, 0]; root.addChild(panel)
            let button = ModelEntity(mesh: .generateSphere(radius: 0.055), materials: [UnlitMaterial(color: .systemGreen)]); button.name = "Hack Terminal Button"; button.position = [0, 0.66, -0.075]; root.addChild(button)
        }
        for shadow in puzzle.shadowZones {
            let zone = ModelEntity(mesh: .generateBox(size: [shadow.size.x, 0.018, shadow.size.y], cornerRadius: 0.08), materials: [SimpleMaterial(color: UIColor(white: 0.015, alpha: arPresentation ? 0.68 : 0.88), isMetallic: false)])
            zone.name = "Shadow Zone"; zone.position = [shadow.center.x, 0.012, shadow.center.y]; room.addChild(zone)
        }
        for conveyor in puzzle.conveyors {
            let zone = Entity(); zone.name = "Conveyor \(conveyor.id)"; zone.position = [conveyor.center.x, 0.018, conveyor.center.y]
            zone.orientation = simd_quatf(angle: atan2(conveyor.direction.x, -conveyor.direction.y), axis: [0, 1, 0])
            let base = ModelEntity(mesh: .generateBox(size: [conveyor.size.x, 0.045, conveyor.size.y], cornerRadius: 0.035), materials: [SimpleMaterial(color: .darkGray, isMetallic: true)]); zone.addChild(base)
            let span = conveyor.direction.x == 0 ? conveyor.size.y : conveyor.size.x
            for index in -3...3 {
                let offset = Float(index) * span / 7
                for side: Float in [-1, 1] {
                    let stripe = ModelEntity(mesh: .generateBox(size: [0.08, 0.018, min(0.62, conveyor.size.x * 0.38)], cornerRadius: 0.01), materials: [UnlitMaterial(color: index.isMultiple(of: 2) ? .systemYellow : .lightGray)])
                    stripe.position = [side * 0.18, 0.032, offset]
                    stripe.orientation = simd_quatf(angle: side * 0.62, axis: [0, 1, 0])
                    zone.addChild(stripe)
                }
            }
            room.addChild(zone)
        }
        for camera in puzzle.securityCameras {
            let root = Entity(); root.name = "Security Camera \(camera.id)"; root.position = [camera.position.x, 0, camera.position.y]; root.orientation = simd_quatf(angle: camera.heading, axis: [0, 1, 0])
            let post = ModelEntity(mesh: .generateCylinder(height: 1.25, radius: 0.055), materials: [SimpleMaterial(color: .darkGray, isMetallic: true)]); post.position.y = 0.625; root.addChild(post)
            let housing = ModelEntity(mesh: .generateBox(size: [0.34, 0.22, 0.46], cornerRadius: 0.04), materials: [SimpleMaterial(color: .lightGray, isMetallic: true)]); housing.position = [0, 1.2, -0.18]; root.addChild(housing)
            let lens = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [UnlitMaterial(color: .systemRed)]); lens.name = "Security Camera Lens \(camera.id)"; lens.position = [0, 1.2, -0.43]; root.addChild(lens)
            let beam = ModelEntity(mesh: .generateBox(size: [1.2, 0.012, camera.range], cornerRadius: 0.08), materials: [SimpleMaterial(color: UIColor.systemRed.withAlphaComponent(arPresentation ? 0.09 : 0.13), isMetallic: false)]); beam.name = "Security Camera Beam \(camera.id)"; beam.position = [0, 0.04, -camera.range / 2]; root.addChild(beam)
            room.addChild(root)
        }
        if let key = puzzle.key {
            let entity = makePuzzleKey()
            entity.position = [key.x, 0.04, key.y]
            room.addChild(entity)
        }
        for (index, cell) in puzzle.cells.enumerated() { let entity = ModelEntity(mesh: .generateCylinder(height: 0.28, radius: 0.11), materials: [SimpleMaterial(color: .systemYellow, isMetallic: true)]); entity.name = "Puzzle Cell \(index)"; entity.position = [cell.x, 0.2, cell.y]; room.addChild(entity) }
        for (index, pickup) in puzzle.shieldPickups.enumerated() {
            let root = Entity(); root.name = "Shield Pickup \(index)"; root.position = [pickup.x, 0.24, pickup.y]
            let core = ModelEntity(mesh: .generateSphere(radius: 0.16), materials: [UnlitMaterial(color: .systemCyan)]); root.addChild(core)
            let halo = ModelEntity(mesh: .generateCylinder(height: 0.035, radius: 0.27), materials: [SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.58), isMetallic: true)]); halo.position.y = 0.02; root.addChild(halo)
            room.addChild(root)
        }
        for (index, pickup) in puzzle.repairPickups.enumerated() {
            let root = Entity(); root.name = "Repair Pickup \(index)"; root.position = [pickup.x, 0.2, pickup.y]
            let kit = ModelEntity(mesh: .generateBox(size: [0.34, 0.24, 0.26], cornerRadius: 0.045), materials: [SimpleMaterial(color: .systemRed, isMetallic: true)]); root.addChild(kit)
            for size in [SIMD3<Float>(0.2, 0.055, 0.025), SIMD3<Float>(0.055, 0.2, 0.025)] {
                let cross = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.012), materials: [UnlitMaterial(color: .white)]); cross.position.z = -0.14; root.addChild(cross)
            }
            room.addChild(root)
        }
        let dock = ModelEntity(mesh: .generateBox(size: [0.7, 0.025, 0.7], cornerRadius: 0.08), materials: [SimpleMaterial(color: .systemOrange, isMetallic: false)]); dock.name = "Puzzle Dock"; dock.position = [puzzle.dock.x, 0.02, puzzle.dock.y]; room.addChild(dock)
        return room
    }

    static func makePuzzleKey() -> Entity {
        let root = Entity()
        root.name = "Puzzle Key"
        let material = UnlitMaterial(color: .systemCyan)
        let shaft = ModelEntity(mesh: .generateBox(size: [0.56, 0.09, 0.16], cornerRadius: 0.035), materials: [material])
        shaft.position = [0.08, 0.1, 0]
        root.addChild(shaft)
        let ring = ModelEntity(mesh: .generateCylinder(height: 0.1, radius: 0.2), materials: [material])
        ring.position = [-0.27, 0.1, 0]
        root.addChild(ring)
        for x: Float in [0.24, 0.39] {
            let tooth = ModelEntity(mesh: .generateBox(size: [0.09, 0.09, 0.22], cornerRadius: 0.025), materials: [material])
            tooth.position = [x, 0.1, 0.1]
            root.addChild(tooth)
        }
        let beacon = ModelEntity(
            mesh: .generateCylinder(height: 0.8, radius: 0.025),
            materials: [UnlitMaterial(color: UIColor.systemCyan.withAlphaComponent(0.55))]
        )
        beacon.name = "Puzzle Key Beacon"
        beacon.position = [0, 0.5, 0]
        root.addChild(beacon)
        return root
    }

    static func applyPuzzleState(to room: Entity, session: GameSession) {
        room.findEntity(named: "Puzzle Key")?.isEnabled = !session.hasKey
        room.findEntity(named: "Puzzle Door")?.isEnabled = !session.doorOpen
        room.findEntity(named: "Hack Terminal")?.isEnabled = !session.doorOpen
        if let button = room.findEntity(named: "Hack Terminal Button") as? ModelEntity {
            let color: UIColor = session.isHackingDoor ? .systemYellow : session.canStartDoorHack ? .systemGreen : .systemRed
            button.model?.materials = [UnlitMaterial(color: color)]
            button.scale = .init(repeating: session.isHackingDoor ? 0.85 + Float(sin(session.elapsed * 9)) * 0.18 : 1)
        }
        for camera in session.puzzle.securityCameras {
            room.findEntity(named: "Security Camera \(camera.id)")?.orientation = simd_quatf(angle: session.securityCameraHeading(camera), axis: [0, 1, 0])
            if let lens = room.findEntity(named: "Security Camera Lens \(camera.id)") as? ModelEntity {
                lens.model?.materials = [UnlitMaterial(color: session.isSecurityAlerted ? .systemRed : .systemYellow)]
            }
        }
        for conveyor in session.puzzle.conveyors {
            room.findEntity(named: "Conveyor \(conveyor.id)")?.position.y = 0.018 + Float(sin(session.elapsed * 5 + Double(conveyor.id))) * 0.006
        }
        for index in session.puzzle.cells.indices { room.findEntity(named: "Puzzle Cell \(index)")?.isEnabled = !session.collectedCellIndices.contains(index) }
        for index in session.puzzle.shieldPickups.indices { room.findEntity(named: "Shield Pickup \(index)")?.isEnabled = !session.collectedShieldPickupIndices.contains(index) }
        for index in session.puzzle.repairPickups.indices { room.findEntity(named: "Repair Pickup \(index)")?.isEnabled = !session.collectedRepairPickupIndices.contains(index) }
        if let dock = room.findEntity(named: "Puzzle Dock") as? ModelEntity {
            dock.model?.materials = [SimpleMaterial(color: session.canFinish ? .systemGreen : .systemOrange, isMetallic: false)]
        }
    }
}
