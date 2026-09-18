import Foundation
import RealityKit
import UIKit
import simd

@MainActor enum ROBTacticalVisual {
    private struct Model: Decodable {
        struct Part: Decodable {
            let group: String, name: String, shape: String
            let size: [Float], position: [Float], rotation: [Float]
            let color: Int
        }
        let parts: [Part]
    }
    private static let model: Model = {
        let url = Bundle.main.url(forResource: "rob-tactical-model", withExtension: "json")!
        return try! JSONDecoder().decode(Model.self, from: Data(contentsOf: url))
    }()
    static func install(on robot: Entity) {
        guard let torso = robot.findEntity(named: "Torso Assembly") else { return }
        let jammer = Entity(), blaster = Entity()
        jammer.name = "Router Backpack Jammer"; blaster.name = "Two-handed StrikeForce Gel Kit"
        torso.addChild(jammer); torso.addChild(blaster)
        let scale = ROBScanVisualModel.presentationScale
        for part in model.parts {
            let size = SIMD3(part.size[0], part.size[1], part.size[2]) * scale
            let mesh: MeshResource = switch part.shape {
            case "box": .generateBox(size: size)
            case "sphere": .generateSphere(radius: size.x)
            default: .generateCylinder(height: size.y, radius: size.x)
            }
            let color = UIColor(red: CGFloat((part.color >> 16) & 255) / 255, green: CGFloat((part.color >> 8) & 255) / 255, blue: CGFloat(part.color & 255) / 255, alpha: 1)
            let entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: color, roughness: 0.52, isMetallic: true)])
            entity.name = part.name
            entity.position = SIMD3(part.position[0], part.position[1], part.position[2]) * scale
            entity.orientation = simd_quatf(vector: SIMD4(part.rotation[0], part.rotation[1], part.rotation[2], part.rotation[3]))
            (part.group == "jammer" ? jammer : blaster).addChild(entity)
        }
        let beam = ModelEntity(mesh: .generateBox(size: [0.004, 0.004, 4]), materials: [UnlitMaterial(color: .systemBlue)])
        beam.name = "PEQ Blue Beam"; beam.position = ROBTacticalRules.muzzle * scale + [0, 0, -2]; blaster.addChild(beam)
        let flashlight = Entity(); flashlight.name = "PEQ Flashlight"
        flashlight.position = ROBTacticalRules.muzzle * scale
        flashlight.components.set(SpotLightComponent(color: .white, intensity: 4_000, innerAngleInDegrees: 18, outerAngleInDegrees: 35, attenuationRadius: 8))
        blaster.addChild(flashlight)
        jammer.isEnabled = false; blaster.isEnabled = false
        let field = Entity(); field.name = "Jammer Field"; robot.addChild(field)
        for index in 0..<48 {
            let angle = Float(index) * .pi * 2 / 48
            let dot = ModelEntity(mesh: .generateSphere(radius: 0.025), materials: [UnlitMaterial(color: .systemPurple)])
            dot.position = [sin(angle) * ROBTacticalRules.jammerRadius, 0.035, cos(angle) * ROBTacticalRules.jammerRadius]
            field.addChild(dot)
        }
        field.isEnabled = false
    }
    static func apply(to robot: Entity, session: GameSession, componentMode: Bool) {
        let drawn = !componentMode && session.gelBlasterEquipped && !session.tacticalHandsBusy
        robot.findEntity(named: "Router Backpack Jammer")?.isEnabled = !componentMode && session.hasJammer
        robot.findEntity(named: "Two-handed StrikeForce Gel Kit")?.isEnabled = drawn
        robot.findEntity(named: "PEQ Blue Beam")?.isEnabled = drawn && session.peqMode == .blue
        robot.findEntity(named: "PEQ Flashlight")?.isEnabled = drawn && session.peqMode == .flashlight
        robot.findEntity(named: "Jammer Field")?.isEnabled = !componentMode && session.jammerActive && session.isRunning
        for side in ["Left", "Right"] { robot.findEntity(named: "\(side) Arm Assembly")?.isEnabled = !drawn }
        if drawn {
            for name in ["Power Hammer", "Gatling Lock Indicator"] { robot.findEntity(named: name)?.isEnabled = false }
        }
    }
    static func applyWorld(to layer: Entity, session: GameSession) {
        let valid = Set(session.gelProjectiles.map { "Gel Pellet \($0.id)" })
        for child in Array(layer.children) where child.name.hasPrefix("Gel Pellet ") && !valid.contains(child.name) { child.removeFromParent() }
        for shot in session.gelProjectiles {
            let name = "Gel Pellet \(shot.id)"
            let entity: Entity
            if let existing = layer.findEntity(named: name) { entity = existing }
            else {
                let pellet = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [UnlitMaterial(color: .systemMint)])
                pellet.name = name; layer.addChild(pellet); entity = pellet
            }
            entity.position = shot.position
        }
        for enemy in session.enemies {
            let name = "IR Target \(enemy.id)"
            let marker: Entity
            if let existing = layer.findEntity(named: name) { marker = existing }
            else {
                let box = ModelEntity(mesh: .generateBox(size: [0.5, 0.05, 0.05]), materials: [UnlitMaterial(color: .systemPurple)])
                box.name = name; layer.addChild(box); marker = box
            }
            marker.position = enemy.position + [0, 1.3, 0]
            marker.isEnabled = enemy.isActive && (session.isInfraredTarget(enemy) || session.isEnemyJammed(enemy))
            marker.scale = .init(repeating: session.isEnemyJammed(enemy) ? 1 + Float(sin(session.elapsed * 25)) * 0.07 : 1)
        }
        let relay: ModelEntity
        if let existing = layer.findEntity(named: "Remote Gel Relay") as? ModelEntity { relay = existing }
        else {
            relay = ModelEntity(mesh: .generateCylinder(height: 0.06, radius: 0.25), materials: [SimpleMaterial(color: .systemOrange, isMetallic: true)])
            relay.name = "Remote Gel Relay"; relay.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]); layer.addChild(relay)
        }
        relay.position = session.remoteRelayPosition; relay.isEnabled = session.hasGelBlaster
        let stateName = session.remoteRelayActivated ? "Relay activated" : "Relay ready"
        if relay.children.first?.name != stateName {
            relay.children.removeAll(); let marker = Entity(); marker.name = stateName; relay.addChild(marker)
            relay.model?.materials = [SimpleMaterial(color: session.remoteRelayActivated ? .systemGreen : .systemOrange, isMetallic: true)]
        }
    }
}
