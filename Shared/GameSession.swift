import Foundation
import Observation
import simd

struct ROBLevel: Identifiable, Sendable {
    let id: Int
    let name: String
    let lesson: String
    let cellCount: Int
    let enemyCount: Int
    let enemyShields: Int
    let timeBonus: Int
    let requiresKey: Bool
    let challenge: String
}

struct ROBComponent: Identifiable, Sendable {
    let id: String
    let name: String
    let summary: String
    let color: UInt32
}

@MainActor @Observable
final class GameSession {
    let levels = [
        ROBLevel(id: 1, name: "Calibration Deck", lesson: "Arrow controls mix forward speed and steering into two tread demands.", cellCount: 2, enemyCount: 1, enemyShields: 1, timeBonus: 900, requiresKey: false, challenge: "Learn smooth turns, collect two cells, and reach the dock."),
        ROBLevel(id: 2, name: "Key Workshop", lesson: "A key changes the state of a matching locked door.", cellCount: 2, enemyCount: 1, enemyShields: 1, timeBonus: 1_100, requiresKey: true, challenge: "Find the cyan key before approaching the locked workshop door."),
        ROBLevel(id: 3, name: "Crossroads", lesson: "Plan a route before entering a narrow passage.", cellCount: 3, enemyCount: 2, enemyShields: 1, timeBonus: 1_300, requiresKey: true, challenge: "Choose the safe branch, secure the key, then open the center door."),
        ROBLevel(id: 4, name: "Sensor Hall", lesson: "Wide clearance is often faster than scraping along obstacles.", cellCount: 3, enemyCount: 2, enemyShields: 2, timeBonus: 1_500, requiresKey: false, challenge: "Use open space and avoid the sentries guarding the cells."),
        ROBLevel(id: 5, name: "Amber Armory", lesson: "A seven-joint arm trades reach for a larger collision envelope.", cellCount: 3, enemyCount: 2, enemyShields: 2, timeBonus: 1_700, requiresKey: true, challenge: "Recover the armory key and use saber range without touching enemies."),
        ROBLevel(id: 6, name: "Switchback Foundry", lesson: "Slow before turning so both treads can follow the planned curve.", cellCount: 4, enemyCount: 3, enemyShields: 2, timeBonus: 1_900, requiresKey: true, challenge: "Navigate alternating turns, unlock the foundry, and clear its guards."),
        ROBLevel(id: 7, name: "Twin Sentinel Bay", lesson: "Keep one escape route open while engaging moving obstacles.", cellCount: 4, enemyCount: 3, enemyShields: 3, timeBonus: 2_100, requiresKey: false, challenge: "Separate the sentries instead of fighting all three together."),
        ROBLevel(id: 8, name: "Power Relay", lesson: "Complete prerequisites in the right order: key, door, cells, then dock.", cellCount: 4, enemyCount: 3, enemyShields: 3, timeBonus: 2_300, requiresKey: true, challenge: "Unlock the relay room before collecting its protected energy cells."),
        ROBLevel(id: 9, name: "Guardian Maze", lesson: "Reliable autonomy needs state, perception, and a recoverable plan.", cellCount: 5, enemyCount: 4, enemyShields: 3, timeBonus: 2_600, requiresKey: true, challenge: "Find the key in the outer loop and return through the guarded door."),
        ROBLevel(id: 10, name: "Mission Control", lesson: "Combine driving, sequencing, tool use, and safe separation.", cellCount: 5, enemyCount: 4, enemyShields: 4, timeBonus: 3_000, requiresKey: true, challenge: "Complete the full safety sequence and reach Mission Control."),
    ]
    let components = [
        ROBComponent(id: "base", name: "Tracked Base", summary: "A drive mixer converts forward and steering commands into coordinated left and right tread speeds.", color: 0x263746),
        ROBComponent(id: "power", name: "Power System", summary: "Batteries, protection, disconnects, and motor electronics form ROB’s energy path.", color: 0xF1B93A),
        ROBComponent(id: "cerebro", name: "Cerebro", summary: "The Mac-based control layer coordinates operator intent, cameras, networking, and diagnostics.", color: 0x36DFFF),
        ROBComponent(id: "sensors", name: "Sensors", summary: "Cameras, lidar, inertial sensing, and infrared observations help ROB describe its environment.", color: 0x55DD88),
        ROBComponent(id: "arms", name: "Dual AMBER B1 Arms", summary: "Each arm has seven visible joint stages. Tool motion must respect joint limits, self-collision, and safe separation.", color: 0xAEB9C4),
        ROBComponent(id: "safety", name: "Safety Layer", summary: "A trained operator, exclusion zone, tested physical stop, and bounded trials remain essential.", color: 0xFF5C72),
    ]
    var levelIndex = 0
    var score = 0
    var collectedCells = 0
    var remainingEnemies = 1
    var elapsed = 0.0
    var forwardDemand = 0.0
    var steeringDemand = 0.0
    var leftTread = 0.0
    var rightTread = 0.0
    var robotPosition = SIMD3<Float>(0, 0, 1.8)
    var robotHeading: Float = .pi
    var hasKey = false
    var doorOpen = true
    var saberAnimation = 0.0
    var laserDistance: Float?
    var selectedComponent: ROBComponent?
    var message = "ROB systems ready."
    var isRunning = false
    var lastSituation = "ROB systems ready."
    var situationCount = 0
    var level: ROBLevel { levels[levelIndex] }
    var canFinish: Bool { collectedCells == level.cellCount && remainingEnemies == 0 && (!level.requiresKey || doorOpen) }

    private func report(_ situation: String) { lastSituation = situation; situationCount += 1 }
    private func configureLevel() {
        elapsed = 0; collectedCells = 0; remainingEnemies = level.enemyCount
        hasKey = false; doorOpen = !level.requiresKey; saberAnimation = 0; laserDistance = nil
        forwardDemand = 0; steeringDemand = 0; leftTread = 0; rightTread = 0
        robotPosition = SIMD3<Float>(0, 0, 1.8); robotHeading = .pi
    }
    func begin() { configureLevel(); isRunning = true; message = "Level \(level.id): \(level.challenge)"; report("The pilot started \(level.name). \(level.challenge)"); SoundPlayer.shared.play("mission-start") }
    func setDrive(forward: Double, steering: Double) { forwardDemand = forward; steeringDemand = steering }
    func stopDrive() { setDrive(forward: 0, steering: 0) }
    func tick(_ delta: TimeInterval) {
        guard isRunning else { return }
        elapsed += delta
        let targetLeft = max(-1, min(1, forwardDemand + steeringDemand * 0.72))
        let targetRight = max(-1, min(1, forwardDemand - steeringDemand * 0.72))
        let smoothing = min(1, delta * 8)
        leftTread += (targetLeft - leftTread) * smoothing; rightTread += (targetRight - rightTread) * smoothing
        let linear = Float((leftTread + rightTread) * 0.5) * Float(delta) * 0.85
        robotHeading += Float(leftTread - rightTread) * Float(delta) * 1.05
        robotPosition.x -= sin(robotHeading) * linear; robotPosition.z -= cos(robotHeading) * linear
        robotPosition.x = min(2.55, max(-2.55, robotPosition.x)); robotPosition.z = min(2.7, max(-2.7, robotPosition.z))
        if saberAnimation > 0 { saberAnimation = max(0, saberAnimation - delta * 2.8) }
        if let distance = laserDistance { let next = distance + Float(delta) * 4.5; laserDistance = next > 6 ? nil : next }
    }
    func fireLaser() { guard isRunning, laserDistance == nil else { return }; laserDistance = 0.7; message = "Training laser fired."; report(message); SoundPlayer.shared.play("laser") }
    func saberAttack() { guard isRunning else { return }; saberAnimation = 1; if remainingEnemies > 0 { remainingEnemies -= 1; score += 350; message = "Sword-style saber slash disabled a training robot. \(remainingEnemies) remain." } else { message = "ROB completed a guarded saber slash." }; report(message); SoundPlayer.shared.play("laser") }
    func collectCell() { guard isRunning, collectedCells < level.cellCount else { return }; collectedCells += 1; score += 150; message = "Energy cell \(collectedCells) of \(level.cellCount)."; report(message); SoundPlayer.shared.play("pickup") }
    func collectKey() { guard isRunning, level.requiresKey, !hasKey else { return }; hasKey = true; score += 250; message = "Key secured. Bring it to the locked door."; report(message); SoundPlayer.shared.play("pickup") }
    func openDoor() { guard isRunning, level.requiresKey, !doorOpen else { return }; guard hasKey else { message = "The door is locked. Find the key first."; return }; doorOpen = true; score += 300; message = "Key accepted. Door open."; report(message); SoundPlayer.shared.play("pickup") }
    func enemyContact() { guard isRunning else { return }; score = max(0, score - 200); configureLevel(); isRunning = true; message = "Enemy contact damaged ROB. Restarting level \(level.id)."; report(message) }
    func nextLevel() { guard canFinish else { message = "Finish every objective before leaving the level."; return }; score += max(0, level.timeBonus - Int(elapsed) * 10); if levelIndex < levels.count - 1 { levelIndex += 1; configureLevel(); isRunning = true; message = level.challenge; report("ROB advanced to \(level.name). \(level.challenge)") } else { isRunning = false; message = "Ten-level campaign complete!" }; SoundPlayer.shared.play("level-complete") }
    func reset() { levelIndex = 0; score = 0; configureLevel(); isRunning = false; message = "ROB systems ready." }
}
