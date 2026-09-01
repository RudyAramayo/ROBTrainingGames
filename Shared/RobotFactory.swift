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
        case .solarYellow: UIColor(red: 0.96, green: 0.72, blue: 0.08, alpha: 1)
        case .plasmaPurple: UIColor(red: 0.42, green: 0.17, blue: 0.82, alpha: 1)
        case .makerPink: UIColor(red: 0.88, green: 0.18, blue: 0.52, alpha: 1)
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

    static func applyDroidAppearance(
        to robot: Entity,
        profile: ROBDroidProfile,
        arPresentation: Bool,
        markerPrefix: String = "Applied Appearance"
    ) {
        let markerName = "\(markerPrefix) \(profile.appearanceKey)"
        if robot.children.contains(where: { $0.name == markerName }) { return }
        for marker in Array(robot.children) where marker.name.hasPrefix("\(markerPrefix) ") { marker.removeFromParent() }
        let marker = Entity(); marker.name = markerName; robot.addChild(marker)
        let bodyColor = finishColor(for: profile.finish)
        let bodyMaterial = SimpleMaterial(color: bodyColor, isMetallic: !arPresentation && profile.material.isMetallic)
        for name in ["Tri-Wheel Chassis", "Cerebro Torso", "Camera Head", "Left Upper Arm", "Right Upper Arm", "Left Forearm", "Right Forearm"] {
            (robot.findEntity(named: name) as? ModelEntity)?.model?.materials = [bodyMaterial]
        }
        let smileMaterial = UnlitMaterial(color: faceColor(for: profile.faceColor))
        for name in [
            "Face Smiley Left Eye", "Face Smiley Right Eye", "Face Smiley Left Corner",
            "Face Smiley Left Smile", "Face Smiley Center Smile", "Face Smiley Right Smile", "Face Smiley Right Corner",
        ] {
            (robot.findEntity(named: name) as? ModelEntity)?.model?.materials = [smileMaterial]
        }
        let accent = SimpleMaterial(color: bodyColor.withAlphaComponent(arPresentation ? 0.55 : 0.78), isMetallic: profile.material.isMetallic)
        switch profile.housing {
        case .fieldShell:
            let guardPanel = ModelEntity(mesh: .generateBox(size: [0.5, 0.06, 0.42], cornerRadius: 0.04), materials: [accent])
            guardPanel.name = "Field Shell Guard"; guardPanel.position = [0, 1.04, 0.16]; marker.addChild(guardPanel)
        case .openMakerFrame:
            for side: Float in [-1, 1] {
                let rail = ModelEntity(mesh: .generateBox(size: [0.045, 0.58, 0.045], cornerRadius: 0.01), materials: [accent])
                rail.name = side < 0 ? "Left Maker Frame Rail" : "Right Maker Frame Rail"
                rail.position = [side * 0.31, 0.74, 0.29]; marker.addChild(rail)
            }
        case .festivalArmor:
            let dome = ModelEntity(mesh: .generateSphere(radius: 0.37), materials: [accent])
            dome.name = "Festival Armor Dome"; dome.position = [0, 0.86, 0.17]; dome.scale = [1, 0.82, 0.48]; marker.addChild(dome)
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
        let baseFlipper = Entity(); baseFlipper.name = "Base Lift Flipper Assembly"; baseFlipper.position = [0, 0.46, -0.38]; root.addChild(baseFlipper)
        cylinder("Base Lift Flipper Motor", radius: 0.11, height: 0.62, position: .zero, color: .systemOrange, sideways: true, parent: baseFlipper)
        part("Base Lift Flipper Blade", [0.58, 0.09, 0.88], [0, -0.04, -0.45], .darkGray, parent: baseFlipper)
        part("Base Lift Flipper Floor Pad", [0.7, 0.12, 0.18], [0, -0.04, -0.92], .systemOrange, parent: baseFlipper)
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
            let prefix = x < 0 ? "Left" : "Right"
            let color: UIColor = x < 0 ? .systemBlue : .systemCyan
            cylinder("\(prefix) ROB Speaker Ring", radius: 0.12, height: 0.025, position: [x, 0.8, -0.285], color: color, faceForward: true, parent: torso)
            cylinder("\(prefix) ROB Speaker Cone", radius: 0.078, height: 0.032, position: [x, 0.8, -0.305], color: UIColor(white: 0.025, alpha: 1), faceForward: true, parent: torso)
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
        cylinder("Gatling Pan Servo", radius: 0.13, height: 0.1, position: [0, -0.14, 0.02], color: .darkGray, parent: gatling)
        let tilt = Entity(); tilt.name = "Gatling Tilt Servo"; gatling.addChild(tilt)
        cylinder("Gatling Tilt Axle", radius: 0.08, height: 0.3, position: [0, 0, 0], color: .gray, sideways: true, parent: tilt)
        part("Gatling Housing", [0.24, 0.2, 0.38], [0, 0, -0.08], .black, parent: tilt)
        let barrelCluster = Entity(); barrelCluster.name = "Gatling Barrel Cluster"; tilt.addChild(barrelCluster)
        for x: Float in [-0.055, 0.055] { for y: Float in [-0.055, 0.055] { cylinder("Gatling Barrel", radius: 0.018, height: 0.52, position: [x, y, -0.36], color: .black, faceForward: true, parent: barrelCluster) } }
        let lockLamp = ModelEntity(mesh: .generateSphere(radius: 0.055), materials: [UnlitMaterial(color: .systemRed)]); lockLamp.name = "Gatling Lock Indicator"; lockLamp.position = [0, 0.15, -0.22]; tilt.addChild(lockLamp)
        let blueEmitter = ModelEntity(mesh: .generateSphere(radius: 0.042), materials: [UnlitMaterial(color: .systemBlue)]); blueEmitter.name = "Virtual Blue Balloon Beam Emitter"; blueEmitter.position = [0, -0.13, -0.23]; tilt.addChild(blueEmitter)

        let twinBlasters = Entity(); twinBlasters.name = "Twin Blasters"; twinBlasters.position = [0, 0.98, -0.04]; torso.addChild(twinBlasters)
        for side: Float in [-1, 1] {
            let prefix = side < 0 ? "Left" : "Right"
            let mount = Entity(); mount.name = "\(prefix) Blaster Mount"; mount.position = [side * 0.47, 0, 0]; twinBlasters.addChild(mount)
            part("\(prefix) Blaster Housing", [0.2, 0.15, 0.28], [0, 0, -0.08], .systemBlue, parent: mount)
            for x: Float in [-0.035, 0.035] {
                cylinder("\(prefix) Blaster Barrel", radius: 0.018, height: 0.46, position: [x, 0, -0.34], color: .black, faceForward: true, parent: mount)
            }
        }

        let arcCannon = Entity(); arcCannon.name = "Arc Cannon"; arcCannon.position = [0, 1.12, -0.04]; torso.addChild(arcCannon)
        part("Arc Cannon Housing", [0.34, 0.24, 0.42], [0, 0, -0.1], .systemPurple, parent: arcCannon)
        for side: Float in [-1, 1] {
            cylinder("Arc Cannon Conductor", radius: 0.035, height: 0.54, position: [side * 0.105, 0, -0.4], color: .systemCyan, faceForward: true, parent: arcCannon)
        }
        let arcCore = ModelEntity(mesh: .generateSphere(radius: 0.08), materials: [UnlitMaterial(color: .systemCyan)]); arcCore.name = "Arc Cannon Core"; arcCore.position = [0, 0.02, -0.34]; arcCannon.addChild(arcCore)

        let shot = Entity(); shot.name = "Shoulder Laser Shot"; shot.position = [0.5, 1.08, -0.28]; torso.addChild(shot)
        let beam = ModelEntity(mesh: .generateBox(size: [1, 1, 0.55], cornerRadius: 0.04), materials: [UnlitMaterial(color: .systemBlue)]); beam.name = "Shoulder Laser Beam"; beam.isEnabled = false; shot.addChild(beam)
        for side: Float in [-1, 1] {
            let prefix = side < 0 ? "Left" : "Right"
            let twinShot = Entity(); twinShot.name = "\(prefix) Blaster Laser Shot"; twinShot.position = [side * 0.47, 0.98, -0.32]; torso.addChild(twinShot)
            let twinBeam = ModelEntity(mesh: .generateBox(size: [1, 1, 0.55], cornerRadius: 0.035), materials: [UnlitMaterial(color: .systemBlue)])
            twinBeam.name = "\(prefix) Blaster Laser Beam"; twinBeam.isEnabled = false; twinShot.addChild(twinBeam)
        }

        part("Sensor Mast", [0.1, 0.48, 0.1], [0, 1.2, 0], .gray, parent: torso)
        let head = ModelEntity(mesh: .generateSphere(radius: 0.22), materials: [SimpleMaterial(color: .black, isMetallic: !arPresentation)]); head.name = "Camera Head"; head.position = [0, 1.52, 0]; head.scale.z = 0.82; torso.addChild(head)
        let conferenceMicrophone = Entity(); conferenceMicrophone.name = "Conference Microphone"; conferenceMicrophone.position = [0, 1.82, 0.02]; torso.addChild(conferenceMicrophone)
        cylinder("Conference Microphone Capsule", radius: 0.08, height: 0.19, position: .zero, color: .systemYellow, sideways: true, parent: conferenceMicrophone)
        cylinder("Conference Microphone Stand", radius: 0.014, height: 0.16, position: [0, -0.1, 0], color: .gray, parent: conferenceMicrophone)
        cylinder("Conference Microphone Base", radius: 0.1, height: 0.025, position: [0, -0.19, 0], color: .darkGray, parent: conferenceMicrophone)
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
        if !componentMode {
            applyDroidAppearance(to: robot, profile: session.droidProfile, arPresentation: arPresentation)
        }
        let appearanceName = "Applied Appearance \(componentMode ? "components" : session.droidProfile.appearanceKey)"
        if robot.children.first(where: { $0.name == appearanceName }) == nil {
            for marker in Array(robot.children) where marker.name.hasPrefix("Applied Appearance ") { marker.removeFromParent() }
            let marker = Entity(); marker.name = appearanceName; robot.addChild(marker)
            let bodyMaterial = SimpleMaterial(color: componentMode ? finishColor(for: .graphite) : finishColor(for: session.robotFinish), isMetallic: !arPresentation && session.droidProfile.material.isMetallic)
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
        robot.findEntity(named: "Base Lift Flipper Assembly")?.orientation = simd_quatf(angle: session.baseFlipperAngle, axis: [1, 0, 0])
        let speakerPulse: Float = session.musicEnabled && session.isRunning
            ? 1 + max(0, Float(sin(session.elapsed * .pi * 8))) * 0.13
            : 1
        robot.findEntity(named: "Left ROB Speaker Cone")?.scale = [speakerPulse, 1, speakerPulse]
        robot.findEntity(named: "Right ROB Speaker Cone")?.scale = [1 + (speakerPulse - 1) * 0.78, 1, 1 + (speakerPulse - 1) * 0.78]
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
        let scanningHeading = Float(sin(session.elapsed * 0.85)) * 0.9
        let relativeHeading = session.laserLockHeading.map { $0 - session.robotHeading - torsoYaw } ?? scanningHeading
        for name in ["Right Shoulder Gatling", "Arc Cannon"] {
            robot.findEntity(named: name)?.orientation = simd_quatf(angle: relativeHeading, axis: [0, 1, 0])
        }
        robot.findEntity(named: "Gatling Tilt Servo")?.orientation = simd_quatf(angle: session.lockedEnemy == nil ? Float(sin(session.elapsed * 0.7)) * 0.13 : -0.06, axis: [1, 0, 0])
        robot.findEntity(named: "Twin Blasters")?.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        robot.findEntity(named: "Left Blaster Mount")?.orientation = simd_quatf(angle: relativeHeading, axis: [0, 1, 0])
        let secondaryRelativeHeading = session.secondaryLaserLockHeading.map { $0 - session.robotHeading - torsoYaw } ?? relativeHeading
        robot.findEntity(named: "Right Blaster Mount")?.orientation = simd_quatf(angle: secondaryRelativeHeading, axis: [0, 1, 0])
        if let lamp = robot.findEntity(named: "Gatling Lock Indicator") {
            lamp.isEnabled = session.lockedEnemy != nil
            let pulse = 0.9 + Float(sin(session.elapsed * 9)) * 0.18
            lamp.scale = .init(repeating: pulse)
        }
        robot.findEntity(named: "Gatling Barrel Cluster")?.orientation = simd_quatf(angle: Float(session.elapsed) * 7 + Float(session.laserCharge) * 12, axis: [0, 0, 1])
        let projectileEntities: [ROBLaserBarrel: (shot: String, beam: String)] = [
            .center: ("Shoulder Laser Shot", "Shoulder Laser Beam"),
            .left: ("Left Blaster Laser Shot", "Left Blaster Laser Beam"),
            .right: ("Right Blaster Laser Shot", "Right Blaster Laser Beam"),
        ]
        for names in projectileEntities.values {
            robot.findEntity(named: names.beam)?.isEnabled = false
        }
        for projectile in session.laserProjectiles {
            guard let names = projectileEntities[projectile.barrel],
                  let shot = robot.findEntity(named: names.shot),
                  let beam = robot.findEntity(named: names.beam)
            else { continue }
            shot.orientation = simd_quatf(angle: projectile.heading - session.robotHeading - torsoYaw, axis: [0, 1, 0])
            let charge = Float(projectile.charge), width = 0.035 + charge * 0.13
            if let beam = beam as? ModelEntity {
                let appearanceName = "Projectile Appearance \(projectile.weapon.rawValue)"
                if beam.children.first(where: { $0.name == appearanceName }) == nil {
                    for marker in Array(beam.children) where marker.name.hasPrefix("Projectile Appearance ") { marker.removeFromParent() }
                    let marker = Entity(); marker.name = appearanceName; beam.addChild(marker)
                    let color: UIColor = switch projectile.weapon {
                    case .shoulderGatling: .systemBlue
                    case .twinBlasters: .systemBlue
                    case .arcCannon: .systemCyan
                    }
                    beam.model?.materials = [UnlitMaterial(color: color)]
                }
            }
            beam.isEnabled = true
            beam.position = [0, 0, -projectile.distance]
            beam.scale = [width, width, 1 + charge * 2.6]
        }
    }

    /// Dense rays keep the red edge tight to corners while the camera sweeps.
    private static let securityCameraVisionRayCount = 49

    private static func securityCameraVisionMesh(
        camera: PuzzleSecurityCamera,
        distances: [Float]
    ) -> MeshResource? {
        guard distances.count >= 2 else { return nil }
        var positions = [SIMD3<Float>(0, 0, 0)]
        positions.reserveCapacity(distances.count + 1)
        for (index, distance) in distances.enumerated() {
            let angle = -GameSession.securityCameraHalfAngle
                + GameSession.securityCameraHalfAngle * 2 * Float(index) / Float(distances.count - 1)
            positions.append([-sin(angle) * distance, 0, -cos(angle) * distance])
        }
        var indices: [UInt32] = []
        indices.reserveCapacity((distances.count - 1) * 3)
        for index in 0..<(distances.count - 1) {
            indices.append(contentsOf: [0, UInt32(index + 1), UInt32(index + 2)])
        }
        var descriptor = MeshDescriptor(name: "Security Camera Vision \(camera.id)")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        descriptor.materials = .allFaces(0)
        return try? MeshResource.generate(from: [descriptor])
    }

    private static func initialSecurityCameraBlockers(for puzzle: PuzzleGeometry) -> [PuzzleBarrier] {
        let half = puzzle.arenaHalfExtent
        let perimeter = [
            PuzzleBarrier(center: [0, -half], size: [half * 2, 0.18]),
            PuzzleBarrier(center: [0, half], size: [half * 2, 0.18]),
            PuzzleBarrier(center: [-half, 0], size: [0.18, half * 2]),
            PuzzleBarrier(center: [half, 0], size: [0.18, half * 2]),
        ]
        return puzzle.barriers + perimeter + (puzzle.door.map { [$0] } ?? [])
    }

    static func arenaFloorMaterial(arPresentation: Bool = false) -> any Material {
        if arPresentation {
            return SimpleMaterial(color: UIColor(white: 0.22, alpha: 0.38), isMetallic: false)
        }
        return arenaMaterial(
            textureName: "arena-floor-material",
            fallback: UIColor(white: 0.58, alpha: 1),
            roughness: 0.7,
            metallic: 0.18
        )
    }

    static func arenaWallMaterial(arPresentation: Bool = false) -> any Material {
        if arPresentation {
            return SimpleMaterial(color: UIColor(white: 0.3, alpha: 0.82), isMetallic: false)
        }
        return arenaMaterial(
            textureName: "arena-wall-material",
            fallback: UIColor(white: 0.68, alpha: 1),
            roughness: 0.52,
            metallic: 0.22
        )
    }

    static func makeArenaLightRig(halfExtent: Float) -> Entity {
        let rig = Entity()
        rig.name = "Arena Light Rig"

        let daylight = Entity()
        daylight.name = "Arena Directional Light"
        daylight.look(at: [0, 0, 0], from: [-halfExtent * 0.45, halfExtent, halfExtent * 0.55], relativeTo: nil)
        daylight.components.set(DirectionalLightComponent(
            color: UIColor(red: 0.86, green: 0.93, blue: 1, alpha: 1),
            intensity: 7_500
        ))
        rig.addChild(daylight)

        let radius = max(6, halfExtent * 2.4)
        for (name, position, color, intensity) in [
            (
                "Arena Key Light",
                SIMD3<Float>(-halfExtent * 0.48, halfExtent * 0.7, halfExtent * 0.35),
                UIColor(red: 0.8, green: 0.91, blue: 1, alpha: 1),
                Float(28_000)
            ),
            (
                "Arena Fill Light",
                SIMD3<Float>(halfExtent * 0.48, halfExtent * 0.55, -halfExtent * 0.3),
                UIColor(red: 1, green: 0.91, blue: 0.78, alpha: 1),
                Float(20_000)
            ),
            (
                "Arena Center Light",
                SIMD3<Float>(0, halfExtent * 0.85, 0),
                UIColor.white,
                Float(18_000)
            ),
        ] {
            let light = Entity()
            light.name = name
            light.position = position
            light.components.set(PointLightComponent(color: color, intensity: intensity, attenuationRadius: radius))
            rig.addChild(light)
        }
        return rig
    }

    private static func arenaMaterial(
        textureName: String,
        fallback: UIColor,
        roughness: Float,
        metallic: Float
    ) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        if let resource = try? TextureResource.load(named: textureName) {
            material.baseColor = .init(tint: .white, texture: .init(resource))
        } else {
            material.baseColor = .init(tint: fallback)
        }
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: metallic)
        return material
    }

    static func makeTrainingRoom(level: Int, puzzle: PuzzleGeometry, arPresentation: Bool = false) -> Entity {
        let room = Entity(); room.name = "Training Room-\(level)"
        let size = puzzle.arenaHalfExtent * 2
        let floor = ModelEntity(mesh: .generatePlane(width: size, depth: size), materials: [arenaFloorMaterial(arPresentation: arPresentation)])
        floor.name = "Training Floor"
        room.addChild(floor)
        let walls: [(String, SIMD3<Float>, SIMD3<Float>)] = [
            ("North Training Wall", [0, 0.55, -puzzle.arenaHalfExtent], [size, 1.1, 0.18]),
            ("South Training Wall", [0, 0.55, puzzle.arenaHalfExtent], [size, 1.1, 0.18]),
            ("West Training Wall", [-puzzle.arenaHalfExtent, 0.55, 0], [0.18, 1.1, size]),
            ("East Training Wall", [puzzle.arenaHalfExtent, 0.55, 0], [0.18, 1.1, size]),
        ]
        for (name, position, wallSize) in walls {
            let wall = ModelEntity(
                mesh: .generateBox(size: wallSize, cornerRadius: 0.03),
                materials: [arenaWallMaterial(arPresentation: arPresentation)]
            )
            wall.name = name
            wall.position = position
            room.addChild(wall)
        }
        for (index, barrier) in puzzle.barriers.enumerated() {
            let block = ModelEntity(
                mesh: .generateBox(size: [barrier.size.x, 0.75, barrier.size.y], cornerRadius: 0.03),
                materials: [arenaWallMaterial(arPresentation: arPresentation)]
            )
            block.name = "Training Barrier \(index)"
            block.position = [barrier.center.x, 0.375, barrier.center.y]
            room.addChild(block)
        }
        if !arPresentation { room.addChild(makeArenaLightRig(halfExtent: puzzle.arenaHalfExtent)) }
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
                for (sideIndex, side) in [Float(-1), 1].enumerated() {
                    let stripe = ModelEntity(mesh: .generateBox(size: [0.08, 0.018, min(0.62, conveyor.size.x * 0.38)], cornerRadius: 0.01), materials: [UnlitMaterial(color: index.isMultiple(of: 2) ? .systemYellow : .lightGray)])
                    stripe.name = "Conveyor Arrow \(conveyor.id) \(index) \(sideIndex)"
                    stripe.position = [side * 0.18, 0.032, offset]
                    stripe.orientation = simd_quatf(angle: side * 0.62, axis: [0, 1, 0])
                    zone.addChild(stripe)
                }
            }
            room.addChild(zone)
        }
        let initialCameraBlockers = initialSecurityCameraBlockers(for: puzzle)
        for camera in puzzle.securityCameras {
            let root = Entity(); root.name = "Security Camera \(camera.id)"; root.position = [camera.position.x, 0, camera.position.y]; root.orientation = simd_quatf(angle: camera.heading, axis: [0, 1, 0])
            let post = ModelEntity(mesh: .generateCylinder(height: 1.25, radius: 0.055), materials: [SimpleMaterial(color: .darkGray, isMetallic: true)]); post.position.y = 0.625; root.addChild(post)
            let housing = ModelEntity(mesh: .generateBox(size: [0.34, 0.22, 0.46], cornerRadius: 0.04), materials: [SimpleMaterial(color: .lightGray, isMetallic: true)]); housing.position = [0, 1.2, -0.18]; root.addChild(housing)
            let lens = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [UnlitMaterial(color: .systemRed)]); lens.name = "Security Camera Lens \(camera.id)"; lens.position = [0, 1.2, -0.43]; root.addChild(lens)
            let distances = GameSession.securityCameraVisionDistances(
                camera: camera,
                heading: camera.heading,
                blockers: initialCameraBlockers,
                rayCount: securityCameraVisionRayCount
            )
            if let visionMesh = securityCameraVisionMesh(camera: camera, distances: distances) {
                let beam = ModelEntity(mesh: visionMesh, materials: [UnlitMaterial(color: UIColor.systemRed.withAlphaComponent(arPresentation ? 0.09 : 0.13))])
                beam.name = "Security Camera Beam \(camera.id)"; beam.position.y = 0.04; root.addChild(beam)
            }
            room.addChild(root)
        }
        if let key = puzzle.key {
            let entity = makePuzzleKey()
            entity.position = [key.x, puzzleKeySurfaceOffset, key.y]
            entity.orientation = simd_quatf(angle: -0.32, axis: [0, 1, 0])
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

    static let puzzleKeySurfaceOffset: Float = 0.001

    static func makePuzzleKey() -> Entity {
        let root = Entity()
        root.name = "Puzzle Key"

        let keyColor = UIColor(red: 0.88, green: 0.65, blue: 0.18, alpha: 1)
        let material = SimpleMaterial(color: keyColor, isMetallic: true)
        let thickness: Float = 0.055
        let restingHeight = thickness / 2 + 0.002

        // Build the bow from tangent segments so it reads as a key ring from the
        // overhead game camera without using the solid disc that resembled a gem.
        let bowCenterX: Float = -0.29
        let bowRadius: Float = 0.18
        let bowSegmentCount = 16
        let segmentLength = 2 * Float.pi * bowRadius / Float(bowSegmentCount) * 1.12
        for index in 0..<bowSegmentCount {
            let angle = 2 * Float.pi * Float(index) / Float(bowSegmentCount)
            let segment = ModelEntity(
                mesh: .generateBox(size: [segmentLength, thickness, 0.052], cornerRadius: 0.018),
                materials: [material]
            )
            segment.name = "Puzzle Key Bow Segment \(index)"
            segment.position = [
                bowCenterX + cos(angle) * bowRadius,
                restingHeight,
                sin(angle) * bowRadius,
            ]
            segment.orientation = simd_quatf(angle: -angle - .pi / 2, axis: [0, 1, 0])
            root.addChild(segment)
        }

        let shaft = ModelEntity(
            mesh: .generateBox(size: [0.58, thickness, 0.085], cornerRadius: 0.018),
            materials: [material]
        )
        shaft.name = "Puzzle Key Shaft"
        shaft.position = [0.08, restingHeight, 0]
        root.addChild(shaft)

        for (index, x) in [Float(0.21), 0.34].enumerated() {
            let tooth = ModelEntity(
                mesh: .generateBox(size: [0.085, thickness, 0.16], cornerRadius: 0.016),
                materials: [material]
            )
            tooth.name = "Puzzle Key Tooth \(index)"
            tooth.position = [x, restingHeight, 0.075]
            root.addChild(tooth)
        }

        let tip = ModelEntity(
            mesh: .generateBox(size: [0.1, thickness, 0.12], cornerRadius: 0.016),
            materials: [material]
        )
        tip.name = "Puzzle Key Tip"
        tip.position = [0.415, restingHeight, 0.018]
        root.addChild(tip)

        return root
    }

    static func conveyorArrowOffset(
        baseOffset: Float,
        elapsed: TimeInterval,
        speed: Float,
        span: Float,
        direction: Float
    ) -> Float {
        guard span > 0 else { return baseOffset }
        let halfSpan = span / 2
        var wrapped = (baseOffset + Float(elapsed) * speed * direction + halfSpan)
            .truncatingRemainder(dividingBy: span)
        if wrapped < 0 { wrapped += span }
        return wrapped - halfSpan
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
            let isDisabled = session.disabledSecurityCameraIDs.contains(camera.id)
            room.findEntity(named: "Security Camera \(camera.id)")?.orientation = simd_quatf(angle: session.securityCameraHeading(camera), axis: [0, 1, 0])
            if let beam = room.findEntity(named: "Security Camera Beam \(camera.id)") as? ModelEntity {
                beam.isEnabled = !isDisabled
                if !isDisabled,
                   let visionMesh = securityCameraVisionMesh(
                       camera: camera,
                       distances: session.securityCameraVisionDistances(for: camera, rayCount: securityCameraVisionRayCount)
                   ) {
                    beam.model?.mesh = visionMesh
                }
            }
            if let lens = room.findEntity(named: "Security Camera Lens \(camera.id)") as? ModelEntity {
                let color: UIColor = isDisabled ? .systemGreen
                    : session.hackingCameraID == camera.id ? .systemYellow
                    : session.isSecurityAlerted ? .systemRed : .systemYellow
                lens.model?.materials = [UnlitMaterial(color: color)]
                lens.scale = .init(repeating: session.hackingCameraID == camera.id ? 0.85 + Float(sin(session.elapsed * 9)) * 0.18 : 1)
            }
        }
        for conveyor in session.puzzle.conveyors {
            guard let zone = room.findEntity(named: "Conveyor \(conveyor.id)") else { continue }
            let span = conveyor.direction.x == 0 ? conveyor.size.y : conveyor.size.x
            let worldDirection = SIMD3<Float>(conveyor.direction.x, 0, conveyor.direction.y)
            let localDirection = zone.orientation.inverse.act(worldDirection)
            let travelDirection: Float = localDirection.z < 0 ? -1 : 1
            for index in -3...3 {
                let baseOffset = Float(index) * span / 7
                let offset = conveyorArrowOffset(
                    baseOffset: baseOffset,
                    elapsed: session.elapsed,
                    speed: conveyor.speed,
                    span: span,
                    direction: travelDirection
                )
                for sideIndex in 0...1 {
                    zone.findEntity(named: "Conveyor Arrow \(conveyor.id) \(index) \(sideIndex)")?.position.z = offset
                }
            }
        }
        for index in session.puzzle.cells.indices { room.findEntity(named: "Puzzle Cell \(index)")?.isEnabled = !session.collectedCellIndices.contains(index) }
        for index in session.puzzle.shieldPickups.indices { room.findEntity(named: "Shield Pickup \(index)")?.isEnabled = !session.collectedShieldPickupIndices.contains(index) }
        for index in session.puzzle.repairPickups.indices { room.findEntity(named: "Repair Pickup \(index)")?.isEnabled = !session.collectedRepairPickupIndices.contains(index) }
        if let dock = room.findEntity(named: "Puzzle Dock") as? ModelEntity {
            dock.model?.materials = [SimpleMaterial(color: session.canFinish ? .systemGreen : .systemOrange, isMetallic: false)]
        }
    }
}
