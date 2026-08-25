import Foundation
import Observation
import simd

struct ROBLevel: Identifiable, Sendable {
    let id: Int
    let name: String
    let lesson: String
    let cellCount: Int
    let enemyKinds: [TrainingEnemyKind]
    let enemyShields: Int
    let timeBonus: Int
    let requiresKey: Bool
    let challenge: String
    var enemyCount: Int { enemyKinds.count }
}

enum TrainingEnemyKind: String, Sendable {
    case spider
    case fax

    var displayName: String { self == .spider ? "Spider bot" : "Dalek-style fax robot" }
}

struct TrainingEnemy: Identifiable, Sendable {
    let id: Int
    let kind: TrainingEnemyKind
    var position: SIMD3<Float>
    let origin: SIMD3<Float>
    var heading: Float = 0
    var shields: Int
    var isActive = true
    var nextAttack: TimeInterval
    var lungeRemaining = 0.0
}

struct TrainingEnemyBolt: Identifiable, Sendable {
    let id: Int
    var position: SIMD3<Float>
    let velocity: SIMD3<Float>
}

struct ROBComponent: Identifiable, Sendable {
    let id: String
    let name: String
    let summary: String
    let color: UInt32
}

struct PuzzleBarrier: Sendable {
    let center: SIMD2<Float>
    let size: SIMD2<Float>
}

struct PuzzleGeometry: Sendable {
    let key: SIMD2<Float>?
    let door: PuzzleBarrier?
    let barriers: [PuzzleBarrier]
    let cells: [SIMD2<Float>]
    let dock: SIMD2<Float>
}

@MainActor @Observable
final class GameSession {
    let levels = [
        ROBLevel(id: 1, name: "Calibration Deck", lesson: "Arrow controls mix forward speed and steering into two tread demands.", cellCount: 3, enemyKinds: [.spider, .fax], enemyShields: 2, timeBonus: 900, requiresKey: false, challenge: "Learn smooth turns, evade two active enemies, collect three cells, and reach the dock."),
        ROBLevel(id: 2, name: "Key Workshop", lesson: "A key changes the state of a matching locked door.", cellCount: 2, enemyKinds: [.spider], enemyShields: 1, timeBonus: 1_100, requiresKey: true, challenge: "Find the cyan key before approaching the locked workshop door."),
        ROBLevel(id: 3, name: "Crossroads", lesson: "Plan a route before entering a narrow passage.", cellCount: 3, enemyKinds: [.spider, .fax], enemyShields: 1, timeBonus: 1_300, requiresKey: true, challenge: "Choose the safe branch, secure the key, then open the center door."),
        ROBLevel(id: 4, name: "Sensor Hall", lesson: "Wide clearance is often faster than scraping along obstacles.", cellCount: 3, enemyKinds: [.spider, .fax], enemyShields: 2, timeBonus: 1_500, requiresKey: false, challenge: "Use open space and avoid the sentries guarding the cells."),
        ROBLevel(id: 5, name: "Amber Armory", lesson: "A seven-joint arm trades reach for a larger collision envelope.", cellCount: 3, enemyKinds: [.fax, .spider], enemyShields: 2, timeBonus: 1_700, requiresKey: true, challenge: "Recover the armory key and use saber range without touching enemies."),
        ROBLevel(id: 6, name: "Switchback Foundry", lesson: "Slow before turning so both treads can follow the planned curve.", cellCount: 4, enemyKinds: [.spider, .fax, .spider], enemyShields: 2, timeBonus: 1_900, requiresKey: true, challenge: "Navigate alternating turns, unlock the foundry, and clear its guards."),
        ROBLevel(id: 7, name: "Twin Sentinel Bay", lesson: "Keep one escape route open while engaging moving obstacles.", cellCount: 4, enemyKinds: [.fax, .fax, .spider], enemyShields: 3, timeBonus: 2_100, requiresKey: false, challenge: "Separate the sentries instead of fighting all three together."),
        ROBLevel(id: 8, name: "Power Relay", lesson: "Complete prerequisites in the right order: key, door, cells, then dock.", cellCount: 4, enemyKinds: [.spider, .fax, .spider], enemyShields: 3, timeBonus: 2_300, requiresKey: true, challenge: "Unlock the relay room before collecting its protected energy cells."),
        ROBLevel(id: 9, name: "Guardian Maze", lesson: "Reliable autonomy needs state, perception, and a recoverable plan.", cellCount: 5, enemyKinds: [.spider, .fax, .spider, .fax], enemyShields: 3, timeBonus: 2_600, requiresKey: true, challenge: "Find the key in the outer loop and return through the guarded door."),
        ROBLevel(id: 10, name: "Mission Control", lesson: "Combine driving, sequencing, tool use, and safe separation.", cellCount: 5, enemyKinds: [.fax, .spider, .fax, .spider], enemyShields: 4, timeBonus: 3_000, requiresKey: true, challenge: "Complete the full safety sequence and reach Mission Control."),
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
    var enemies: [TrainingEnemy] = []
    var enemyBolts: [TrainingEnemyBolt] = []
    private(set) var enemyAttackCount = 0
    var elapsed = 0.0
    var forwardDemand = 0.0
    var steeringDemand = 0.0
    var leftTread = 0.0
    var rightTread = 0.0
    var robotPosition = SIMD3<Float>(0, 0, 1.8)
    var robotHeading: Float = .pi
    var hasKey = false
    var doorOpen = true
    var collectedCellIndices: Set<Int> = []
    var saberAnimation = 0.0
    var laserDistance: Float?
    var selectedComponent: ROBComponent?
    var message = "ROB systems ready."
    var isRunning = false
    var musicEnabled = true
    var lastSituation = "ROB systems ready."
    var situationCount = 0
    private var nextBoltID = 0
    private let audioEnabled: Bool
    var level: ROBLevel { levels[levelIndex] }
    var remainingEnemies: Int { enemies.filter(\.isActive).count }
    var canFinish: Bool { collectedCells == level.cellCount && remainingEnemies == 0 && (!level.requiresKey || doorOpen) }
    var puzzle: PuzzleGeometry { Self.puzzleGeometry(for: level) }

    init(audioEnabled: Bool = true) {
        self.audioEnabled = audioEnabled
        configureLevel()
    }

    private static func puzzleGeometry(for level: ROBLevel) -> PuzzleGeometry {
        let count = level.cellCount
        let cells = (0..<count).map { index in
            let columns: [Float] = [-2.05, -1.05, 0, 1.05, 2.05]
            return SIMD2<Float>(columns[index % columns.count], index.isMultiple(of: 2) ? -2.15 : -1.15)
        }
        guard level.requiresKey else {
            let zigzag = (0..<max(1, level.id / 3)).map { index in
                PuzzleBarrier(center: [index.isMultiple(of: 2) ? -0.8 : 0.8, 0.25 - Float(index) * 0.65], size: [2.8, 0.18])
            }
            return PuzzleGeometry(key: nil, door: nil, barriers: zigzag, cells: cells, dock: [2.05, -2.35])
        }
        let horizontal = level.id != 2 && level.id != 6 && level.id != 8
        if horizontal {
            let door = PuzzleBarrier(center: [level.id == 9 ? -1.25 : 0, 0.15], size: [0.9, 0.2])
            let left = door.center.x - door.size.x / 2
            let right = door.center.x + door.size.x / 2
            let walls = [
                PuzzleBarrier(center: [(-2.75 + left) / 2, door.center.y], size: [left + 2.75, 0.2]),
                PuzzleBarrier(center: [(right + 2.75) / 2, door.center.y], size: [2.75 - right, 0.2]),
                PuzzleBarrier(center: [level.id.isMultiple(of: 2) ? -1.15 : 1.15, -1.0], size: [0.18, 1.55]),
            ]
            return PuzzleGeometry(key: [level.id == 9 ? 2.1 : -2.1, 2.15], door: door, barriers: walls, cells: cells, dock: [2.05, -2.35])
        }
        let door = PuzzleBarrier(center: [0.35, -0.35], size: [0.2, 0.9])
        let near = door.center.y - door.size.y / 2
        let far = door.center.y + door.size.y / 2
        let walls = [
            PuzzleBarrier(center: [door.center.x, (-2.75 + near) / 2], size: [0.2, near + 2.75]),
            PuzzleBarrier(center: [door.center.x, (far + 2.75) / 2], size: [0.2, 2.75 - far]),
            PuzzleBarrier(center: [-1.1, -1.0], size: [1.5, 0.18]),
        ]
        return PuzzleGeometry(key: [-2.1, 2.15], door: door, barriers: walls, cells: cells.map { SIMD2<Float>($0.x > 0 ? $0.x : abs($0.x) + 0.35, $0.y) }, dock: [2.1, -2.3])
    }

    private func report(_ situation: String) { lastSituation = situation; situationCount += 1 }
    private func play(_ name: String) { if audioEnabled { SoundPlayer.shared.play(name) } }
    private func playEnemyAttack(_ kind: TrainingEnemyKind) { if audioEnabled { SoundPlayer.shared.playEnemyAttack(kind) } }
    private func configuredEnemies() -> [TrainingEnemy] {
        let candidates: [SIMD3<Float>] = [[-2.1, 0, 0.85], [2.1, 0, -1.65], [-1.85, 0, -2.2], [1.75, 0, 0.85], [0, 0, -2.3]]
        let blockers = puzzle.barriers + (puzzle.door.map { [$0] } ?? [])
        let available = candidates.filter { candidate in
            simd_distance(SIMD2<Float>(candidate.x, candidate.z), SIMD2<Float>(0, 1.8)) > 1.5 && !blockers.contains(where: { Self.intersects(candidate, barrier: $0, radius: 0.28) })
        }
        let spawns = available.isEmpty ? candidates : available
        return level.enemyKinds.enumerated().map { index, kind in
            let origin = spawns[index % spawns.count]
            return TrainingEnemy(id: index, kind: kind, position: origin, origin: origin, shields: level.enemyShields, nextAttack: 1.6 + Double(index) * 0.65)
        }
    }
    private func configureLevel() {
        elapsed = 0; collectedCells = 0
        hasKey = false; doorOpen = !level.requiresKey; collectedCellIndices = []; saberAnimation = 0; laserDistance = nil
        forwardDemand = 0; steeringDemand = 0; leftTread = 0; rightTread = 0
        robotPosition = SIMD3<Float>(0, 0, 1.8); robotHeading = .pi
        enemyBolts = []; nextBoltID = 0; enemies = configuredEnemies()
    }
    func begin() { enemyAttackCount = 0; configureLevel(); isRunning = true; if audioEnabled && musicEnabled { TechnoMusicEngine.shared.start(level: levelIndex) }; message = "Level \(level.id): \(level.challenge)"; report("The pilot started \(level.name). \(level.challenge)"); play("mission-start") }
    func toggleMusic() { musicEnabled.toggle(); guard audioEnabled else { return }; if musicEnabled && isRunning { TechnoMusicEngine.shared.start(level: levelIndex) } else { TechnoMusicEngine.shared.stop() } }
    func setDrive(forward: Double, steering: Double) { forwardDemand = forward; steeringDemand = steering }
    func stopDrive() { setDrive(forward: 0, steering: 0) }
    func moveStep(forward: Double = 0, steering: Double = 0) {
        guard isRunning else { begin(); return }
        setDrive(forward: forward, steering: steering)
        tick(0.24)
        stopDrive()
    }
    func tick(_ delta: TimeInterval) {
        guard isRunning else { return }
        elapsed += delta
        let targetLeft = max(-1, min(1, forwardDemand + steeringDemand * 0.72))
        let targetRight = max(-1, min(1, forwardDemand - steeringDemand * 0.72))
        let smoothing = min(1, delta * 8)
        leftTread += (targetLeft - leftTread) * smoothing; rightTread += (targetRight - rightTread) * smoothing
        let linear = Float((leftTread + rightTread) * 0.5) * Float(delta) * 0.85
        robotHeading += Float(leftTread - rightTread) * Float(delta) * 1.05
        let oldPosition = robotPosition
        robotPosition.x -= sin(robotHeading) * linear; robotPosition.z -= cos(robotHeading) * linear
        robotPosition.x = min(2.55, max(-2.55, robotPosition.x)); robotPosition.z = min(2.7, max(-2.7, robotPosition.z))
        let blockers = puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
        if blockers.contains(where: { Self.intersects(robotPosition, barrier: $0) }) {
            robotPosition = oldPosition
            message = hasKey ? "Align with the doorway to unlock it." : "Route blocked. The key is on this side of the partition."
        }
        resolveSpatialObjectives()
        if saberAnimation > 0 { saberAnimation = max(0, saberAnimation - delta * 2.8) }
        if let distance = laserDistance { let next = distance + Float(delta) * 4.5; laserDistance = next > 6 ? nil : next }
        updateEnemies(delta)
    }
    private static func intersects(_ position: SIMD3<Float>, barrier: PuzzleBarrier, radius: Float = 0.32) -> Bool {
        abs(position.x - barrier.center.x) < barrier.size.x / 2 + radius && abs(position.z - barrier.center.y) < barrier.size.y / 2 + radius
    }
    private func moveEnemy(_ enemy: inout TrainingEnemy, toward target: SIMD3<Float>, speed: Float, delta: TimeInterval) {
        var direction = target - enemy.position; direction.y = 0
        let distance = simd_length(direction); guard distance > 0.001 else { return }
        direction /= distance
        let step = min(distance, speed * Float(delta)), blockers = puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
        var proposedX = enemy.position; proposedX.x += direction.x * step
        var proposedZ = enemy.position; proposedZ.z += direction.z * step
        if abs(proposedX.x) < 2.42 && !blockers.contains(where: { Self.intersects(proposedX, barrier: $0, radius: 0.27) }) { enemy.position.x = proposedX.x }
        if abs(proposedZ.z) < 2.57 && !blockers.contains(where: { Self.intersects(proposedZ, barrier: $0, radius: 0.27) }) { enemy.position.z = proposedZ.z }
    }
    private func updateEnemies(_ delta: TimeInterval) {
        for index in enemies.indices where enemies[index].isActive {
            var enemy = enemies[index]
            var toRobot = robotPosition - enemy.position; toRobot.y = 0
            let distance = simd_length(toRobot), phase = Float(elapsed) * (enemy.kind == .spider ? 0.62 : 0.34) + Float(index) * 2.17
            var target = enemy.origin + SIMD3<Float>(cos(phase) * (enemy.kind == .spider ? 0.65 : 0.5), 0, sin(phase) * (enemy.kind == .spider ? 0.65 : 0.5))
            var speed: Float = enemy.kind == .spider ? 0.16 : 0.12
            if enemy.kind == .spider && distance < 3.25 {
                target = robotPosition; speed = 0.3 + Float(levelIndex) * 0.012
                if elapsed >= enemy.nextAttack && distance < 1.2 {
                    enemy.lungeRemaining = 0.72; enemy.nextAttack = elapsed + max(2.5, 3.5 - Double(levelIndex) * 0.06); enemyAttackCount += 1
                    playEnemyAttack(.spider); message = "Spider bot skittering into a lunge — evade or slash!"; report(message)
                }
                if enemy.lungeRemaining > 0 { enemy.lungeRemaining = max(0, enemy.lungeRemaining - delta); speed = 0.78 + Float(levelIndex) * 0.015 }
            } else if enemy.kind == .fax {
                if distance > 1.65 { target = robotPosition }
                else if distance < 1.05, distance > 0.001 { target = enemy.position - simd_normalize(toRobot) }
                else if distance > 0.001 { let tangent = SIMD3<Float>(-toRobot.z, 0, toRobot.x) / distance; target = enemy.position + tangent * (index.isMultiple(of: 2) ? 0.6 : -0.6) }
                speed = 0.19 + Float(levelIndex) * 0.01
                if elapsed >= enemy.nextAttack && distance < 3.35 {
                    enemy.nextAttack = elapsed + max(2.7, 3.9 - Double(levelIndex) * 0.07); enemyAttackCount += 1; fireEnemyBolt(from: enemy)
                    playEnemyAttack(.fax); message = "Dalek-style fax robot: “Exterminate!” Incoming laser — keep moving."; report(message)
                }
            }
            let facing = robotPosition - enemy.position; enemy.heading = atan2(-facing.x, -facing.z)
            moveEnemy(&enemy, toward: target, speed: speed, delta: delta); enemies[index] = enemy
            if simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(enemy.position.x, enemy.position.z)) < (enemy.kind == .spider ? 0.5 : 0.44) {
                playEnemyAttack(enemy.kind); enemyContact(enemy.kind == .spider ? "Spider bot lunge" : "Dalek-style fax collision"); return
            }
        }
        var survivingBolts: [TrainingEnemyBolt] = []
        let blockers = puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
        for var bolt in enemyBolts {
            bolt.position += bolt.velocity * Float(delta)
            if simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(bolt.position.x, bolt.position.z)) < 0.32 {
                playEnemyAttack(.fax); enemyContact("Dalek-style fax laser"); return
            }
            let outside = abs(bolt.position.x) > 2.7 || abs(bolt.position.z) > 2.85
            if !outside && !blockers.contains(where: { Self.intersects(bolt.position, barrier: $0, radius: 0.04) }) { survivingBolts.append(bolt) }
        }
        enemyBolts = survivingBolts
    }
    private func fireEnemyBolt(from enemy: TrainingEnemy) {
        var direction = robotPosition - enemy.position; direction.y = 0
        guard simd_length_squared(direction) > 0.001 else { return }
        direction = simd_normalize(direction)
        enemyBolts.append(TrainingEnemyBolt(id: nextBoltID, position: enemy.position + direction * 0.38 + SIMD3<Float>(0, 0.55, 0), velocity: direction * (2.1 + Float(levelIndex) * 0.05)))
        nextBoltID += 1
    }
    private func resolveSpatialObjectives() {
        let point = SIMD2<Float>(robotPosition.x, robotPosition.z)
        if let key = puzzle.key, !hasKey, simd_distance(point, key) < 0.48 { collectKey() }
        if let door = puzzle.door, !doorOpen, simd_distance(point, door.center) < 0.72 { openDoor() }
        for (index, cell) in puzzle.cells.enumerated() where !collectedCellIndices.contains(index) && simd_distance(point, cell) < 0.45 {
            collectedCellIndices.insert(index); collectCell()
        }
    }
    private func target(maxRange: Float, lateralTolerance: Float, allowBehind: Bool = false) -> (index: Int, distance: Float)? {
        let forward = SIMD2<Float>(-sin(robotHeading), -cos(robotHeading))
        return enemies.indices.compactMap { index -> (Int, Float)? in
            guard enemies[index].isActive else { return nil }
            let offset = SIMD2<Float>(enemies[index].position.x - robotPosition.x, enemies[index].position.z - robotPosition.z)
            let distance = simd_length(offset), projection = simd_dot(offset, forward), lateral = abs(forward.x * offset.y - forward.y * offset.x)
            guard distance <= maxRange, lateral <= lateralTolerance, allowBehind || projection > 0 else { return nil }
            return (index, distance)
        }.min(by: { $0.1 < $1.1 })
    }
    private func damageEnemy(at index: Int, weapon: String) {
        guard enemies.indices.contains(index), enemies[index].isActive else { return }
        enemies[index].shields -= 1; score += 50
        if enemies[index].shields <= 0 {
            let kind = enemies[index].kind; enemies[index].isActive = false; score += 300; playEnemyAttack(kind)
            message = "\(kind.displayName) disabled by \(weapon). \(remainingEnemies) targets remain."
        } else {
            message = "\(enemies[index].kind.displayName) hit by \(weapon) — \(enemies[index].shields) shields remain."
        }
        report(message)
    }
    func fireLaser() {
        guard isRunning, laserDistance == nil else { return }
        if let hit = target(maxRange: 5, lateralTolerance: 0.38) { laserDistance = hit.distance; damageEnemy(at: hit.index, weapon: "laser") }
        else { laserDistance = 0.7; message = "Training laser fired — no target in its path."; report(message) }
        play("laser")
    }
    func saberAttack() {
        guard isRunning else { return }
        saberAnimation = 1
        if let hit = target(maxRange: 0.95, lateralTolerance: 0.78) { damageEnemy(at: hit.index, weapon: "saber") }
        else { message = "Saber slash missed. Face an enemy and move within range."; report(message) }
        play("laser")
    }
    func collectCell() { guard isRunning, collectedCells < level.cellCount else { return }; collectedCells += 1; score += 150; message = "Energy cell \(collectedCells) of \(level.cellCount)."; report(message); play("pickup") }
    func collectKey() { guard isRunning, level.requiresKey, !hasKey else { return }; hasKey = true; score += 250; message = "Key secured. Bring it to the locked door."; report(message); play("pickup") }
    func openDoor() { guard isRunning, level.requiresKey, !doorOpen else { return }; guard hasKey else { message = "The door is locked. Find the key first."; return }; doorOpen = true; score += 300; message = "Key accepted. Door open."; report(message); play("pickup") }
    func enemyContact(_ attack: String = "Enemy contact") { guard isRunning else { return }; score = max(0, score - 200); configureLevel(); isRunning = true; message = "\(attack) damaged ROB. Restarting level \(level.id)."; report(message) }
    func nextLevel() { guard canFinish else { message = "Finish every objective before leaving the level."; return }; score += max(0, level.timeBonus - Int(elapsed) * 10); if levelIndex < levels.count - 1 { levelIndex += 1; if audioEnabled { TechnoMusicEngine.shared.setLevel(levelIndex) }; enemyAttackCount = 0; configureLevel(); isRunning = true; message = level.challenge; report("ROB advanced to \(level.name). \(level.challenge)") } else { isRunning = false; if audioEnabled { TechnoMusicEngine.shared.stop() }; message = "Ten-level campaign complete!" }; play("level-complete") }
    func reset() { levelIndex = 0; score = 0; enemyAttackCount = 0; configureLevel(); isRunning = false; if audioEnabled { TechnoMusicEngine.shared.stop() }; message = "ROB systems ready." }
}
