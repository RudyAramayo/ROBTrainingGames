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
        ROBLevel(id: 1, name: "Calibration Deck", lesson: "Equal tread speeds drive straight; unequal speeds turn.", cellCount: 3, enemyCount: 2, enemyShields: 2, timeBonus: 900),
        ROBLevel(id: 2, name: "Neon Foundry", lesson: "Sensors report the world; the operator still owns safety.", cellCount: 4, enemyCount: 3, enemyShields: 3, timeBonus: 1_400),
        ROBLevel(id: 3, name: "Sentinel Maze", lesson: "Complex robots coordinate power, signals, software, and people.", cellCount: 5, enemyCount: 4, enemyShields: 4, timeBonus: 2_200),
    ]
    let components = [
        ROBComponent(id: "base", name: "Tracked Base", summary: "Independent left and right treads create forward motion, curves, and point turns.", color: 0x263746),
        ROBComponent(id: "power", name: "Power System", summary: "Batteries, protection, disconnects, and motor electronics form ROB’s energy path.", color: 0xF1B93A),
        ROBComponent(id: "cerebro", name: "Cerebro", summary: "The Mac-based control layer coordinates operator intent, cameras, networking, and diagnostics.", color: 0x36DFFF),
        ROBComponent(id: "sensors", name: "Sensors", summary: "Cameras, lidar, inertial sensing, and infrared observations help ROB describe its environment.", color: 0x55DD88),
        ROBComponent(id: "arms", name: "Arms & Tools", summary: "Articulated mechanisms extend ROB’s reach. Every moving joint introduces limits and pinch hazards.", color: 0xAEB9C4),
        ROBComponent(id: "safety", name: "Safety Layer", summary: "A trained operator, exclusion zone, tested physical stop, and bounded trials remain essential.", color: 0xFF5C72),
    ]
    var levelIndex = 0
    var score = 0
    var collectedCells = 0
    var remainingEnemies = 2
    var elapsed = 0.0
    var leftTread = 0.0
    var rightTread = 0.0
    var robotPosition = SIMD3<Float>(0, 0, 1.8)
    var robotHeading: Float = .pi
    var selectedComponent: ROBComponent?
    var message = "ROB systems ready."
    var isRunning = false
    var lastSituation = "ROB systems ready."
    var situationCount = 0
    var level: ROBLevel { levels[levelIndex] }

    private func report(_ situation: String) { lastSituation = situation; situationCount += 1 }
    func begin() { isRunning = true; message = "Level \(level.id): \(level.name)"; report("The pilot started \(level.name), with \(remainingEnemies) training enemies blocking the route."); SoundPlayer.shared.play("mission-start") }
    func tick(_ delta: TimeInterval) { guard isRunning else { return }; elapsed += delta; let linear = Float((leftTread + rightTread) * 0.5) * Float(delta) * 0.7; robotHeading += Float(leftTread - rightTread) * Float(delta) * 0.85; robotPosition.x -= sin(robotHeading) * linear; robotPosition.z -= cos(robotHeading) * linear; robotPosition.x = min(2.4, max(-2.4, robotPosition.x)); robotPosition.z = min(2.6, max(-2.6, robotPosition.z)) }
    func fire() { guard isRunning, remainingEnemies > 0 else { return }; score += 50; message = "Training laser fired."; report("ROB fired at a stubborn training enemy, but it is still causing trouble."); SoundPlayer.shared.play("laser") }
    func collectCell() { guard collectedCells < level.cellCount else { return }; collectedCells += 1; score += 150; message = "Energy cell \(collectedCells) of \(level.cellCount)."; report("ROB collected energy cell \(collectedCells) of \(level.cellCount)."); SoundPlayer.shared.play("pickup") }
    func disableEnemy() { guard remainingEnemies > 0 else { return }; remainingEnemies -= 1; score += 300; message = "Training obstacle disabled."; report("ROB disabled a training enemy. \(remainingEnemies) remain, presumably reconsidering their career choices."); SoundPlayer.shared.play("laser") }
    func nextLevel() { guard levelIndex < levels.count - 1 else { return }; score += max(0, level.timeBonus - Int(elapsed) * 10); levelIndex += 1; elapsed = 0; collectedCells = 0; remainingEnemies = level.enemyCount; robotPosition = SIMD3<Float>(0, 0, 1.8); robotHeading = .pi; message = level.lesson; report("ROB advanced to \(level.name). Difficulty increased and the obstacles are feeling overconfident."); SoundPlayer.shared.play("level-complete") }
    func reset() { levelIndex = 0; score = 0; elapsed = 0; collectedCells = 0; remainingEnemies = levels[0].enemyCount; robotPosition = SIMD3<Float>(0, 0, 1.8); robotHeading = .pi; isRunning = false; message = "ROB systems ready." }
}
