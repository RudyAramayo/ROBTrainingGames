import RealityKit
import SwiftUI
import UIKit

@MainActor
enum ROBBattleFactory {
    static let playerColors: [UIColor] = [.systemCyan, .systemOrange, .systemGreen, .systemPink]
    static let phoneFollowCameraOffset = SIMD3<Float>(0, 6.2, 5.1)
    static let phoneFollowCameraTargetHeight: Float = 0.65

    static func phoneFollowCameraPose(for robot: ROBBattleRobotState) -> (position: SIMD3<Float>, target: SIMD3<Float>) {
        (
            robot.position + phoneFollowCameraOffset,
            robot.position + SIMD3<Float>(0, phoneFollowCameraTargetHeight, 0)
        )
    }

    static func focusPhoneCamera(_ camera: PerspectiveCamera, on robot: ROBBattleRobotState) {
        let pose = phoneFollowCameraPose(for: robot)
        camera.look(at: pose.target, from: pose.position, relativeTo: nil)
    }

    static func makeArena(_ arena: ROBBattleArena, arPresentation: Bool = false) -> Entity {
        let root = Entity()
        root.name = "Deathmatch Arena \(arena.rawValue)"
        let accent = playerColors[arena.accentIndex % playerColors.count]
        func box(
            _ name: String,
            size: SIMD3<Float>,
            position: SIMD3<Float>,
            color: UIColor,
            material: (any RealityKit.Material)? = nil
        ) {
            let materials: [any RealityKit.Material]
            if let material {
                materials = [material]
            } else {
                materials = [SimpleMaterial(color: color, isMetallic: !arPresentation)]
            }
            let entity = ModelEntity(
                mesh: .generateBox(size: size, cornerRadius: 0.06),
                materials: materials
            )
            entity.name = name
            entity.position = position
            root.addChild(entity)
        }

        box(
            "Deathmatch Floor",
            size: [17.6, 0.16, 17.6],
            position: [0, -0.09, 0],
            color: UIColor(red: 0.22, green: 0.27, blue: 0.32, alpha: arPresentation ? 0.82 : 1),
            material: RobotFactory.arenaFloorMaterial(arPresentation: arPresentation)
        )
        for index in -8...8 {
            let color = accent.withAlphaComponent(index.isMultiple(of: 4) ? 0.58 : 0.2)
            box("Grid X \(index)", size: [0.025, 0.018, 17.2], position: [Float(index), 0.015, 0], color: color)
            box("Grid Z \(index)", size: [17.2, 0.018, 0.025], position: [0, 0.015, Float(index)], color: color)
        }
        let wallColor = UIColor(red: 0.13, green: 0.18, blue: 0.24, alpha: 1)
        let wallMaterial = RobotFactory.arenaWallMaterial(arPresentation: arPresentation)
        box("North Wall", size: [17.8, 1.15, 0.3], position: [0, 0.55, -8.65], color: wallColor, material: wallMaterial)
        box("South Wall", size: [17.8, 1.15, 0.3], position: [0, 0.55, 8.65], color: wallColor, material: wallMaterial)
        box("West Wall", size: [0.3, 1.15, 17.8], position: [-8.65, 0.55, 0], color: wallColor, material: wallMaterial)
        box("East Wall", size: [0.3, 1.15, 17.8], position: [8.65, 0.55, 0], color: wallColor, material: wallMaterial)

        for (index, barrier) in arena.barriers.enumerated() {
            box(
                "Arena Cover \(index)",
                size: [barrier.width, 1.3, barrier.depth],
                position: [barrier.x, 0.65, barrier.z],
                color: index.isMultiple(of: 2) ? accent.withAlphaComponent(0.82) : wallColor,
                material: wallMaterial
            )
            box(
                "Arena Cover Light \(index)",
                size: [max(0.12, barrier.width - 0.1), 0.06, max(0.12, barrier.depth - 0.1)],
                position: [barrier.x, 1.33, barrier.z],
                color: accent
            )
        }

        for (index, spawn) in arena.spawnPoints.enumerated() {
            let color = playerColors[index % playerColors.count]
            let pad = ModelEntity(
                mesh: .generateCylinder(height: 0.045, radius: 0.72),
                materials: [UnlitMaterial(color: color.withAlphaComponent(0.72))]
            )
            pad.name = "Spawn Pad \(index)"
            pad.position = spawn + SIMD3<Float>(0, 0.04, 0)
            root.addChild(pad)
        }
        if !arPresentation { root.addChild(RobotFactory.makeArenaLightRig(halfExtent: 8.8)) }
        return root
    }

    static func makeBattleRobot(identity: ROBBattlePlayerIdentity, arPresentation: Bool = false) -> Entity {
        let robot = RobotFactory.makeROB(arPresentation: arPresentation)
        robot.name = robotName(identity.id)
        robot.scale = .init(repeating: 0.72)
        robot.findEntity(named: "Twin Blasters")?.isEnabled = false
        robot.findEntity(named: "Arc Cannon")?.isEnabled = false
        robot.findEntity(named: "Power Hammer")?.isEnabled = false
        applyAppearance(to: robot, identity: identity, arPresentation: arPresentation)

        let color = playerColors[identity.colorIndex % playerColors.count]
        let beacon = ModelEntity(
            mesh: .generateSphere(radius: 0.105),
            materials: [UnlitMaterial(color: color)]
        )
        beacon.name = "Pilot Beacon"
        beacon.position = [0, 1.92, 0]
        robot.addChild(beacon)
        return robot
    }

    static func makeFlagBase(flag: ROBBattleFlagState, identity: ROBBattlePlayerIdentity) -> Entity {
        let root = Entity()
        root.name = flagBaseName(flag.ownerID)
        root.position = flag.basePosition + SIMD3<Float>(0, 0.035, 0)
        let color = playerColors[identity.colorIndex % playerColors.count]
        let pad = ModelEntity(
            mesh: .generateCylinder(height: 0.055, radius: 0.92),
            materials: [UnlitMaterial(color: color.withAlphaComponent(0.42))]
        )
        pad.name = "Flag Base Pad"
        root.addChild(pad)
        let core = ModelEntity(
            mesh: .generateCylinder(height: 0.075, radius: 0.26),
            materials: [UnlitMaterial(color: color)]
        )
        core.name = "Flag Base Core"
        core.position.y = 0.025
        root.addChild(core)
        return root
    }

    static func makeFlag(flag: ROBBattleFlagState, identity: ROBBattlePlayerIdentity, arPresentation: Bool = false) -> Entity {
        let root = Entity()
        root.name = flagName(flag.ownerID)
        let color = playerColors[identity.colorIndex % playerColors.count]
        let metal = SimpleMaterial(color: .lightGray, isMetallic: !arPresentation)
        let pole = ModelEntity(mesh: .generateCylinder(height: 1.22, radius: 0.035), materials: [metal])
        pole.name = "Flag Pole"
        pole.position.y = 0.61
        root.addChild(pole)
        let banner = ModelEntity(
            mesh: .generateBox(size: [0.5, 0.32, 0.035], cornerRadius: 0.018),
            materials: [UnlitMaterial(color: color)]
        )
        banner.name = "Flag Banner"
        banner.position = [0.25, 1.04, 0]
        root.addChild(banner)
        let finial = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [UnlitMaterial(color: color)])
        finial.name = "Flag Finial"
        finial.position.y = 1.27
        root.addChild(finial)
        return root
    }

    static func applyColor(to robot: Entity, colorIndex: Int, arPresentation: Bool) {
        let color = playerColors[colorIndex % playerColors.count]
        let material = SimpleMaterial(color: color, isMetallic: !arPresentation)
        for name in ["Tri-Wheel Chassis", "Cerebro Torso", "Camera Head", "Left Upper Arm", "Right Upper Arm", "Left Forearm", "Right Forearm"] {
            (robot.findEntity(named: name) as? ModelEntity)?.model?.materials = [material]
        }
        let face = UnlitMaterial(color: color)
        for name in [
            "Face Smiley Left Eye", "Face Smiley Right Eye", "Face Smiley Left Corner",
            "Face Smiley Left Smile", "Face Smiley Center Smile", "Face Smiley Right Smile", "Face Smiley Right Corner",
        ] {
            (robot.findEntity(named: name) as? ModelEntity)?.model?.materials = [face]
        }
    }

    static func applyAppearance(to robot: Entity, identity: ROBBattlePlayerIdentity, arPresentation: Bool) {
        guard let profile = identity.droidProfile else {
            applyColor(to: robot, colorIndex: identity.colorIndex, arPresentation: arPresentation)
            return
        }
        RobotFactory.applyDroidAppearance(to: robot, profile: profile, arPresentation: arPresentation, markerPrefix: "Battle Appearance")
    }

    static func synchronize(root: Entity, battle: ROBBattleCoordinator, arPresentation: Bool = false) {
        let states = Dictionary(uniqueKeysWithValues: battle.allRobotStates.map { ($0.id, $0) })
        for (id, state) in states {
            let name = robotName(id)
            let robot: Entity
            if let existing = root.findEntity(named: name) {
                robot = existing
            } else if let identity = battle.players[id] {
                let created = makeBattleRobot(identity: identity, arPresentation: arPresentation)
                root.addChild(created)
                robot = created
            } else {
                continue
            }
            if let identity = battle.players[id] { applyAppearance(to: robot, identity: identity, arPresentation: arPresentation) }
            robot.isEnabled = state.isAlive
            let animation = battle.animationState(for: id)
            let collisionProgress = Float(
                1 - animation.collisionRemaining / ROBBattleRobotAnimationState.collisionDuration
            )
            let collisionLift = animation.collisionRemaining > 0 ? sin(collisionProgress * .pi) * 0.1 : 0
            robot.position = state.position + SIMD3<Float>(0, collisionLift, 0)
            robot.orientation = simd_quatf(angle: state.heading, axis: [0, 1, 0])
            robot.findEntity(named: "ROB Shield Field")?.isEnabled = state.shields > 0
            applyAnimation(to: robot, state: animation)
            if let beacon = robot.findEntity(named: "Pilot Beacon") {
                let healthPulse = 0.72 + Float(state.health) / 250
                beacon.scale = .init(repeating: healthPulse)
            }
        }
        for child in Array(root.children) where child.name.hasPrefix("Battle ROB ") {
            let idText = String(child.name.dropFirst("Battle ROB ".count))
            if let id = UUID(uuidString: idText), states[id] == nil { child.removeFromParent() }
        }
        synchronizeFlags(root: root, battle: battle, robotStates: states, arPresentation: arPresentation)

        let projectileNames = Set(battle.projectiles.map { projectileName($0.id) })
        for child in Array(root.children) where child.name.hasPrefix("Battle Projectile ") && !projectileNames.contains(child.name) {
            child.removeFromParent()
        }
        for projectile in battle.projectiles {
            let name = projectileName(projectile.id)
            let entity: Entity
            if let existing = root.findEntity(named: name) {
                entity = existing
            } else {
                let colorIndex = battle.players[projectile.ownerID]?.colorIndex ?? 0
                let projectileColor: UIColor = battle.players[projectile.ownerID]?.droidProfile == nil ? playerColors[colorIndex % playerColors.count] : .systemBlue
                let created = ModelEntity(
                    mesh: .generateSphere(radius: 0.095),
                    materials: [UnlitMaterial(color: projectileColor)]
                )
                created.name = name
                root.addChild(created)
                entity = created
            }
            entity.position = projectile.position
        }
    }

    private static func synchronizeFlags(
        root: Entity,
        battle: ROBBattleCoordinator,
        robotStates: [UUID: ROBBattleRobotState],
        arPresentation: Bool
    ) {
        guard battle.mode == .captureTheFlag else {
            for child in Array(root.children) where child.name.hasPrefix("Battle Flag ") || child.name.hasPrefix("Battle Base ") {
                child.removeFromParent()
            }
            return
        }

        let flagIDs = Set(battle.flags.keys)
        for child in Array(root.children) where child.name.hasPrefix("Battle Flag ") || child.name.hasPrefix("Battle Base ") {
            let prefix = child.name.hasPrefix("Battle Flag ") ? "Battle Flag " : "Battle Base "
            let idText = String(child.name.dropFirst(prefix.count))
            if let id = UUID(uuidString: idText), !flagIDs.contains(id) { child.removeFromParent() }
        }

        for flag in battle.flags.values {
            guard let identity = battle.players[flag.ownerID] else { continue }
            let base: Entity
            if let existing = root.findEntity(named: flagBaseName(flag.ownerID)) {
                base = existing
            } else {
                let created = makeFlagBase(flag: flag, identity: identity)
                root.addChild(created)
                base = created
            }
            base.position = flag.basePosition + SIMD3<Float>(0, 0.035, 0)

            let entity: Entity
            if let existing = root.findEntity(named: flagName(flag.ownerID)) {
                entity = existing
            } else {
                let created = makeFlag(flag: flag, identity: identity, arPresentation: arPresentation)
                root.addChild(created)
                entity = created
            }
            switch flag.disposition {
            case .atBase:
                entity.position = flag.basePosition + SIMD3<Float>(0, 0.07, 0)
                entity.scale = .init(repeating: 1)
                entity.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
            case .dropped:
                entity.position = flag.position + SIMD3<Float>(0, 0.07, 0)
                entity.scale = .init(repeating: 0.82)
                entity.orientation = simd_quatf(angle: 0.72, axis: [0, 0, 1])
            case .carried:
                if let carrierID = flag.carrierID, let robot = robotStates[carrierID] {
                    let rearOffset = SIMD3<Float>(sin(robot.heading) * 0.42, 0.72, cos(robot.heading) * 0.42)
                    entity.position = robot.position + rearOffset
                } else {
                    entity.position = flag.position + SIMD3<Float>(0, 0.72, 0)
                }
                entity.scale = .init(repeating: 0.58)
                entity.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
            }
        }
    }

    static func applyAnimation(to robot: Entity, state: ROBBattleRobotAnimationState) {
        for (prefix, angle) in [("Left", state.leftTreadAngle), ("Right", state.rightTreadAngle)] {
            for index in 1...3 {
                robot.findEntity(named: "\(prefix) Tri-Wheel \(index)")?.orientation =
                    simd_quatf(angle: angle, axis: [1, 0, 0])
            }
        }

        let saberActive = state.saberRemaining > 0
        let saberProgress = saberActive
            ? Float(1 - state.saberRemaining / ROBBattleRobotAnimationState.saberDuration)
            : 1
        let saberArc = sin(saberProgress * .pi)
        for (name, side) in [("Left Lightsaber", Float(-1)), ("Right Lightsaber", Float(1))] {
            guard let blade = robot.findEntity(named: name) else { continue }
            let bladeScale: Float = saberActive ? 1 : 0.06
            blade.isEnabled = true
            blade.scale = [1, bladeScale, 1]
            blade.position = [side * 0.24, -0.64, -0.1 - 0.45 * bladeScale]
        }

        let torso = robot.findEntity(named: "Torso Assembly")
        torso?.orientation = saberActive
            ? simd_quatf(angle: -saberArc * 0.22, axis: [0, 1, 0])
            : simd_quatf(angle: 0, axis: [0, 1, 0])
        for (name, side) in [("Left Arm Assembly", Float(-1)), ("Right Arm Assembly", Float(1))] {
            guard let arm = robot.findEntity(named: name) else { continue }
            guard saberActive else {
                arm.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                continue
            }
            let sweep = side * (-1.4 + saberProgress * 2.8)
            arm.orientation = simd_quatf(angle: sweep, axis: [0, 1, 0])
                * simd_quatf(angle: side * saberArc * 0.48, axis: [0, 0, 1])
        }

        let laserActive = state.laserRemaining > 0
        let laserProgress = laserActive
            ? Float(1 - state.laserRemaining / ROBBattleRobotAnimationState.laserDuration)
            : 1
        robot.findEntity(named: "Gatling Barrel Cluster")?.orientation =
            simd_quatf(angle: laserProgress * 4 * .pi, axis: [0, 0, 1])
        robot.findEntity(named: "Gatling Tilt Servo")?.orientation =
            simd_quatf(angle: laserActive ? -sin(laserProgress * .pi) * 0.16 : 0, axis: [1, 0, 0])
    }

    static func robotName(_ id: UUID) -> String { "Battle ROB \(id.uuidString)" }
    static func projectileName(_ id: UUID) -> String { "Battle Projectile \(id.uuidString)" }
    static func flagName(_ id: UUID) -> String { "Battle Flag \(id.uuidString)" }
    static func flagBaseName(_ id: UUID) -> String { "Battle Base \(id.uuidString)" }
}

struct ROBBattleRealityScene: View {
    @Bindable var battle: ROBBattleCoordinator
    var arenaScale: Float = 1
    var arenaPosition = SIMD3<Float>.zero
    var includesCamera = false
    var arPresentation = false
    @State private var root = Entity()
    @State private var camera = PerspectiveCamera()

    var body: some View {
        RealityView { content in
            root.name = "ROB Deathmatch Root"
            root.scale = .init(repeating: arenaScale)
            root.position = arenaPosition
            root.addChild(ROBBattleFactory.makeArena(battle.arena, arPresentation: arPresentation))
            ROBBattleFactory.synchronize(root: root, battle: battle, arPresentation: arPresentation)
            content.add(root)
            if includesCamera {
                camera.name = "Deathmatch Camera"
                ROBBattleFactory.focusPhoneCamera(camera, on: battle.localRobot)
                content.add(camera)
            }
        } update: { _ in
            root.scale = .init(repeating: arenaScale)
            root.position = arenaPosition
            ROBBattleFactory.synchronize(root: root, battle: battle, arPresentation: arPresentation)
            if includesCamera {
                ROBBattleFactory.focusPhoneCamera(camera, on: battle.localRobot)
            }
        }
        .id(battle.matchID)
    }
}

struct ROBBattleKeyboardControls: ViewModifier {
    @Bindable var battle: ROBBattleCoordinator
    @State private var heldKeys: Set<KeyEquivalent> = []

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(phases: [.down, .up]) { press in
                guard Self.supportedKeys.contains(press.key) else { return .ignored }
                if press.phase == .down {
                    let inserted = heldKeys.insert(press.key).inserted
                    if inserted && press.key == .space { battle.saberAttack() }
                    if inserted && press.key == "q" { battle.fireLaser() }
                } else {
                    heldKeys.remove(press.key)
                }
                updateDrive()
                return .handled
            }
            .onDisappear { heldKeys = []; battle.stopDrive() }
    }

    private func updateDrive() {
        let forward = (heldKeys.contains("w") || heldKeys.contains(.upArrow) ? 1.0 : 0.0)
            - (heldKeys.contains("s") || heldKeys.contains(.downArrow) ? 1.0 : 0.0)
        let steering = (heldKeys.contains("a") || heldKeys.contains(.leftArrow) ? 1.0 : 0.0)
            - (heldKeys.contains("d") || heldKeys.contains(.rightArrow) ? 1.0 : 0.0)
        battle.setTreads(left: forward - steering * 0.72, right: forward + steering * 0.72)
    }

    private static let supportedKeys: Set<KeyEquivalent> = [
        "w", "a", "s", "d", "q", .upArrow, .downArrow, .leftArrow, .rightArrow, .space,
    ]
}

extension View {
    func robBattleKeyboardControls(battle: ROBBattleCoordinator) -> some View {
        modifier(ROBBattleKeyboardControls(battle: battle))
    }
}
