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
    var arenaHalfExtent: Float { 5.2 + min(Float(id - 1) * 0.08, 0.8) }
}

enum TrainingEnemyKind: String, Sendable {
    case spider
    case fax

    var displayName: String { self == .spider ? "Spider bot" : "Dalek-style fax robot" }
}

enum SpiderSoundCue: Sendable {
    case skitter
    case lunge
    case impact
    case shutdown
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
    var nextSkitterSound: TimeInterval = 0
    var lungeRemaining = 0.0
}

struct TrainingEnemyBolt: Identifiable, Sendable {
    let id: Int
    var position: SIMD3<Float>
    let velocity: SIMD3<Float>
}

enum SaberAttackStyle: Sendable, Equatable {
    case leftSweep
    case rightSweep
    case spin
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
    let arenaHalfExtent: Float
    let key: SIMD2<Float>?
    let door: PuzzleBarrier?
    let barriers: [PuzzleBarrier]
    let cells: [SIMD2<Float>]
    let dock: SIMD2<Float>
}

@MainActor @Observable
final class GameSession {
    let levels = [
        ROBLevel(id: 1, name: "Calibration Deck", lesson: "Arrow controls mix forward speed and steering into two tread demands.", cellCount: 3, enemyKinds: [.spider, .fax, .spider], enemyShields: 2, timeBonus: 900, requiresKey: false, challenge: "Learn smooth turns, evade three active enemies, collect three cells, and reach the dock."),
        ROBLevel(id: 2, name: "Key Workshop", lesson: "A key changes the state of a matching locked door.", cellCount: 3, enemyKinds: [.spider, .fax, .spider], enemyShields: 2, timeBonus: 1_100, requiresKey: true, challenge: "Find the cyan key while a three-robot patrol guards the workshop door."),
        ROBLevel(id: 3, name: "Crossroads", lesson: "Plan a route before entering a narrow passage.", cellCount: 4, enemyKinds: [.spider, .fax, .spider], enemyShields: 2, timeBonus: 1_300, requiresKey: true, challenge: "Choose the safe branch, secure the key, then break through the center patrol."),
        ROBLevel(id: 4, name: "Sensor Hall", lesson: "Wide clearance is often faster than scraping along obstacles.", cellCount: 4, enemyKinds: [.spider, .fax, .spider, .fax], enemyShields: 2, timeBonus: 1_500, requiresKey: false, challenge: "Use the expanded hall to separate four sentries guarding the cells."),
        ROBLevel(id: 5, name: "Amber Armory", lesson: "A seven-joint arm trades reach for a larger collision envelope.", cellCount: 4, enemyKinds: [.fax, .spider, .fax, .spider], enemyShields: 3, timeBonus: 1_700, requiresKey: true, challenge: "Recover the armory key and chain wide saber swings without touching enemies."),
        ROBLevel(id: 6, name: "Switchback Foundry", lesson: "Slow before turning so both treads can follow the planned curve.", cellCount: 5, enemyKinds: [.spider, .fax, .spider, .fax, .spider], enemyShields: 3, timeBonus: 1_900, requiresKey: true, challenge: "Navigate alternating turns while five guards coordinate their attacks."),
        ROBLevel(id: 7, name: "Twin Sentinel Bay", lesson: "Keep one escape route open while engaging moving obstacles.", cellCount: 5, enemyKinds: [.fax, .fax, .spider, .spider, .fax], enemyShields: 3, timeBonus: 2_100, requiresKey: false, challenge: "Separate the sentinel wave and keep moving through crossfire."),
        ROBLevel(id: 8, name: "Power Relay", lesson: "Complete prerequisites in the right order: key, door, cells, then dock.", cellCount: 5, enemyKinds: [.spider, .fax, .spider, .fax, .spider], enemyShields: 4, timeBonus: 2_300, requiresKey: true, challenge: "Unlock the relay room before clearing its reinforced defenders."),
        ROBLevel(id: 9, name: "Guardian Maze", lesson: "Reliable autonomy needs state, perception, and a recoverable plan.", cellCount: 6, enemyKinds: [.spider, .fax, .spider, .fax, .spider, .fax], enemyShields: 4, timeBonus: 2_600, requiresKey: true, challenge: "Find the key in the outer loop and survive the six-robot guardian wave."),
        ROBLevel(id: 10, name: "Mission Control", lesson: "Combine driving, sequencing, tool use, and safe separation.", cellCount: 6, enemyKinds: [.fax, .spider, .fax, .spider, .fax, .spider], enemyShields: 4, timeBonus: 3_000, requiresKey: true, challenge: "Complete the full safety sequence under alternating ranged and melee attacks."),
        ROBLevel(id: 11, name: "Reactor Run", lesson: "A target lock is useful only when the route remains safe.", cellCount: 6, enemyKinds: [.spider, .spider, .fax, .spider, .fax, .fax], enemyShields: 4, timeBonus: 3_300, requiresKey: false, challenge: "Cross the reactor floor while charging shoulder shots between lunges."),
        ROBLevel(id: 12, name: "Eclipse Hangar", lesson: "Scan, prioritize, and reposition before committing to an attack.", cellCount: 6, enemyKinds: [.fax, .spider, .fax, .spider, .fax, .spider], enemyShields: 4, timeBonus: 3_600, requiresKey: true, challenge: "Open the hangar partition and defeat a balanced six-robot squad."),
        ROBLevel(id: 13, name: "Quantum Causeway", lesson: "Short control cycles preserve options in crowded spaces.", cellCount: 7, enemyKinds: [.spider, .fax, .spider, .fax, .spider, .fax, .spider], enemyShields: 5, timeBonus: 3_900, requiresKey: true, challenge: "Use spin attacks to make room without stopping in the causeway."),
        ROBLevel(id: 14, name: "Siege Foundry", lesson: "Threat management matters more than attacking the nearest target.", cellCount: 7, enemyKinds: [.fax, .fax, .spider, .fax, .spider, .spider, .fax], enemyShields: 5, timeBonus: 4_200, requiresKey: true, challenge: "Break the foundry siege by charging shots only when the lane is clear."),
        ROBLevel(id: 15, name: "Final Citadel", lesson: "Integrate mobility, target lock, timing, and tool choice.", cellCount: 8, enemyKinds: [.spider, .fax, .spider, .fax, .spider, .fax, .spider, .fax], enemyShields: 5, timeBonus: 4_800, requiresKey: true, challenge: "Clear the eight-robot citadel wave and complete the expanded campaign."),
    ]
    let components = [
        ROBComponent(id: "base", name: "Tri-Wheel Tracked Base", summary: "Three-wheel triangular tread pods expose the road wheels while a drive mixer preserves independent left and right tread speeds.", color: 0x263746),
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
    var robotHeading: Float = 0
    var leftWheelAngle: Float = 0
    var rightWheelAngle: Float = 0
    var hasKey = false
    var doorOpen = true
    var collectedCellIndices: Set<Int> = []
    var saberAnimation = 0.0
    var saberStyle: SaberAttackStyle?
    private(set) var saberComboCount = 0
    private var lastSaberAttackTime = -Double.infinity
    var laserDistance: Float?
    private(set) var laserCharge = 0.0
    private(set) var isChargingLaser = false
    private(set) var laserShotCharge = 0.0
    private(set) var laserShotHeading: Float = 0
    private(set) var lockedEnemyID: Int?
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
    var lockedEnemy: TrainingEnemy? { enemies.first(where: { $0.id == lockedEnemyID && $0.isActive }) }
    var laserLockDescription: String { lockedEnemy.map { "LOCK: \($0.kind.displayName.uppercased())" } ?? "SCANNING" }
    var laserLockHeading: Float? {
        guard let target = lockedEnemy else { return nil }
        return atan2(-(target.position.x - robotPosition.x), -(target.position.z - robotPosition.z))
    }
    var canFinish: Bool { collectedCells == level.cellCount && remainingEnemies == 0 && (!level.requiresKey || doorOpen) }
    var puzzle: PuzzleGeometry { Self.puzzleGeometry(for: level) }

    init(audioEnabled: Bool = true) {
        self.audioEnabled = audioEnabled
        configureLevel()
    }

    private static func puzzleGeometry(for level: ROBLevel) -> PuzzleGeometry {
        let half = level.arenaHalfExtent, margin = half - 0.8
        let columns: [Float] = [-margin, -margin * 0.5, 0, margin * 0.5, margin]
        let cells = (0..<level.cellCount).map { index in
            SIMD2<Float>(columns[index % columns.count], -margin + Float(index / columns.count) * 2.0)
        }
        guard level.requiresKey else {
            let zigzag = (0..<min(5, max(2, level.id / 3 + 1))).map { index in
                PuzzleBarrier(center: [index.isMultiple(of: 2) ? -1.35 : 1.35, 1.8 - Float(index) * 1.45], size: [half * 1.05, 0.24])
            }
            return PuzzleGeometry(arenaHalfExtent: half, key: nil, door: nil, barriers: zigzag, cells: cells, dock: [margin, -margin])
        }
        let horizontal = ![2, 6, 8, 12, 14].contains(level.id)
        if horizontal {
            let door = PuzzleBarrier(center: [level.id.isMultiple(of: 3) ? -1.45 : 0.65, 0.35], size: [1.25, 0.24])
            let left = door.center.x - door.size.x / 2
            let right = door.center.x + door.size.x / 2
            let walls = [
                PuzzleBarrier(center: [(-half + left) / 2, door.center.y], size: [left + half, 0.24]),
                PuzzleBarrier(center: [(right + half) / 2, door.center.y], size: [half - right, 0.24]),
                PuzzleBarrier(center: [level.id.isMultiple(of: 2) ? -2.1 : 2.1, -2.2], size: [0.24, 2.7]),
            ]
            return PuzzleGeometry(arenaHalfExtent: half, key: [level.id.isMultiple(of: 3) ? margin : -margin, margin], door: door, barriers: walls, cells: cells, dock: [margin, -margin])
        }
        let door = PuzzleBarrier(center: [0.45, -0.45], size: [0.24, 1.25])
        let near = door.center.y - door.size.y / 2
        let far = door.center.y + door.size.y / 2
        let walls = [
            PuzzleBarrier(center: [door.center.x, (-half + near) / 2], size: [0.24, near + half]),
            PuzzleBarrier(center: [door.center.x, (far + half) / 2], size: [0.24, half - far]),
            PuzzleBarrier(center: [-2.0, -2.2], size: [2.8, 0.24]),
        ]
        return PuzzleGeometry(arenaHalfExtent: half, key: [-margin, margin], door: door, barriers: walls, cells: cells.map { SIMD2<Float>($0.x > 0 ? $0.x : abs($0.x) + 0.6, $0.y) }, dock: [margin, -margin])
    }

    private func report(_ situation: String) { lastSituation = situation; situationCount += 1 }
    private func play(_ name: String) { if audioEnabled { SoundPlayer.shared.play(name) } }
    private func playEnemyAttack(_ kind: TrainingEnemyKind) { if audioEnabled { SoundPlayer.shared.playEnemyAttack(kind) } }
    private func playSpider(_ cue: SpiderSoundCue) { if audioEnabled { SoundPlayer.shared.playSpider(cue) } }
    private func configuredEnemies() -> [TrainingEnemy] {
        let margin = puzzle.arenaHalfExtent - 0.85
        let candidates: [SIMD3<Float>] = [
            [-margin, 0, margin * 0.35], [margin, 0, -margin * 0.7], [-margin * 0.85, 0, -margin],
            [margin * 0.8, 0, margin * 0.25], [0, 0, -margin], [margin, 0, margin * 0.72],
            [-margin * 0.35, 0, -margin * 0.45], [margin * 0.32, 0, -margin * 0.2],
        ]
        let blockers = puzzle.barriers + (puzzle.door.map { [$0] } ?? [])
        let available = candidates.filter { candidate in
            simd_distance(SIMD2<Float>(candidate.x, candidate.z), SIMD2<Float>(0, margin)) > 1.8 && !blockers.contains(where: { Self.intersects(candidate, barrier: $0, radius: 0.28) })
        }
        let spawns = available.isEmpty ? candidates : available
        return level.enemyKinds.enumerated().map { index, kind in
            let origin = spawns[index % spawns.count]
            return TrainingEnemy(id: index, kind: kind, position: origin, origin: origin, shields: level.enemyShields, nextAttack: 1.6 + Double(index) * 0.65, nextSkitterSound: 0.8 + Double(index) * 0.38)
        }
    }
    private func configureLevel() {
        elapsed = 0; collectedCells = 0
        hasKey = false; doorOpen = !level.requiresKey; collectedCellIndices = []; saberAnimation = 0; saberStyle = nil; saberComboCount = 0; lastSaberAttackTime = -.infinity
        laserDistance = nil; laserCharge = 0; laserShotCharge = 0; isChargingLaser = false; lockedEnemyID = nil
        forwardDemand = 0; steeringDemand = 0; leftTread = 0; rightTread = 0
        robotPosition = SIMD3<Float>(0, 0, puzzle.arenaHalfExtent - 0.8); robotHeading = 0; leftWheelAngle = 0; rightWheelAngle = 0
        enemyBolts = []; nextBoltID = 0; enemies = configuredEnemies()
        updateLaserLock()
    }
    func begin() { enemyAttackCount = 0; configureLevel(); isRunning = true; if audioEnabled && musicEnabled { TechnoMusicEngine.shared.start(level: levelIndex) }; message = "Level \(level.id): \(level.challenge)"; report("The pilot started \(level.name). \(level.challenge)"); play("mission-start") }
    func toggleMusic() { musicEnabled.toggle(); guard audioEnabled else { return }; if musicEnabled && isRunning { TechnoMusicEngine.shared.start(level: levelIndex) } else { TechnoMusicEngine.shared.stop() } }
    func setDrive(forward: Double, steering: Double) { forwardDemand = forward; steeringDemand = steering }
    func setTreads(left: Double, right: Double) {
        let left = max(-1, min(1, left))
        let right = max(-1, min(1, right))
        forwardDemand = (left + right) * 0.5
        steeringDemand = (right - left) / 1.44
    }
    func stopDrive() { setDrive(forward: 0, steering: 0); leftTread = 0; rightTread = 0 }
    func moveStep(forward: Double = 0, steering: Double = 0) {
        guard isRunning else { begin(); return }
        setDrive(forward: forward, steering: steering)
        tick(0.24)
        stopDrive()
    }
    func tick(_ delta: TimeInterval) {
        guard isRunning else { return }
        elapsed += delta
        let targetLeft = max(-1, min(1, forwardDemand - steeringDemand * 0.72))
        let targetRight = max(-1, min(1, forwardDemand + steeringDemand * 0.72))
        let smoothing = min(1, delta * 8)
        leftTread += (targetLeft - leftTread) * smoothing; rightTread += (targetRight - rightTread) * smoothing
        let linear = Float((leftTread + rightTread) * 0.5) * Float(delta) * 0.85
        leftWheelAngle -= Float(leftTread) * Float(delta) * 4.8; rightWheelAngle -= Float(rightTread) * Float(delta) * 4.8
        robotHeading += Float(rightTread - leftTread) * Float(delta) * 1.05
        let oldPosition = robotPosition
        robotPosition.x -= sin(robotHeading) * linear; robotPosition.z -= cos(robotHeading) * linear
        let movementLimit = puzzle.arenaHalfExtent - 0.35
        robotPosition.x = min(movementLimit, max(-movementLimit, robotPosition.x)); robotPosition.z = min(movementLimit, max(-movementLimit, robotPosition.z))
        let blockers = puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
        if blockers.contains(where: { Self.intersects(robotPosition, barrier: $0) }) {
            robotPosition = oldPosition
            message = hasKey ? "Align with the doorway to unlock it." : "Route blocked. The key is on this side of the partition."
        }
        resolveSpatialObjectives()
        if saberAnimation > 0 {
            saberAnimation = max(0, saberAnimation - delta * (saberStyle == .spin ? 1.25 : 2.25))
            if saberAnimation == 0 { saberStyle = nil }
        }
        if isChargingLaser { laserCharge = min(1, laserCharge + delta / 1.25) }
        if let distance = laserDistance {
            let next = distance + Float(delta) * (5.5 + Float(laserShotCharge) * 3.5)
            laserDistance = next > puzzle.arenaHalfExtent * 2.2 ? nil : next
        }
        updateEnemies(delta)
        updateLaserLock()
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
        let movementLimit = puzzle.arenaHalfExtent - 0.48
        if abs(proposedX.x) < movementLimit && !blockers.contains(where: { Self.intersects(proposedX, barrier: $0, radius: 0.27) }) { enemy.position.x = proposedX.x }
        if abs(proposedZ.z) < movementLimit && !blockers.contains(where: { Self.intersects(proposedZ, barrier: $0, radius: 0.27) }) { enemy.position.z = proposedZ.z }
    }
    private func updateEnemies(_ delta: TimeInterval) {
        for index in enemies.indices where enemies[index].isActive {
            var enemy = enemies[index]
            var toRobot = robotPosition - enemy.position; toRobot.y = 0
            let distance = simd_length(toRobot), phase = Float(elapsed) * (enemy.kind == .spider ? 0.62 : 0.34) + Float(index) * 2.17
            var target = enemy.origin + SIMD3<Float>(cos(phase) * (enemy.kind == .spider ? 0.65 : 0.5), 0, sin(phase) * (enemy.kind == .spider ? 0.65 : 0.5))
            var speed: Float = enemy.kind == .spider ? 0.16 : 0.12
            if enemy.kind == .spider && distance < 6.4 {
                target = robotPosition; speed = 0.34 + Float(levelIndex) * 0.018
                if elapsed >= enemy.nextSkitterSound {
                    enemy.nextSkitterSound = elapsed + 2.1 + Double(index % 3) * 0.42
                    playSpider(.skitter)
                }
                if elapsed >= enemy.nextAttack && distance < 1.65 {
                    enemy.lungeRemaining = 0.72; enemy.nextAttack = elapsed + max(2.5, 3.5 - Double(levelIndex) * 0.06); enemyAttackCount += 1
                    playSpider(.lunge); message = "Spider bot skittering into a lunge — evade or slash!"; report(message)
                }
                if enemy.lungeRemaining > 0 { enemy.lungeRemaining = max(0, enemy.lungeRemaining - delta); speed = 0.9 + Float(levelIndex) * 0.02 }
            } else if enemy.kind == .fax {
                if distance > 2.8 { target = robotPosition }
                else if distance < 1.65, distance > 0.001 { target = enemy.position - simd_normalize(toRobot) }
                else if distance > 0.001 { let tangent = SIMD3<Float>(-toRobot.z, 0, toRobot.x) / distance; target = enemy.position + tangent * (index.isMultiple(of: 2) ? 0.6 : -0.6) }
                speed = 0.24 + Float(levelIndex) * 0.015
                if elapsed >= enemy.nextAttack && distance < 7.5 {
                    enemy.nextAttack = elapsed + max(1.85, 3.65 - Double(levelIndex) * 0.09); enemyAttackCount += 1; fireEnemyBolt(from: enemy)
                    playEnemyAttack(.fax); message = "Dalek-style fax robot: “Exterminate!” Incoming laser — keep moving."; report(message)
                }
            }
            let facing = robotPosition - enemy.position; enemy.heading = atan2(-facing.x, -facing.z)
            moveEnemy(&enemy, toward: target, speed: speed, delta: delta); enemies[index] = enemy
            if simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(enemy.position.x, enemy.position.z)) < (enemy.kind == .spider ? 0.5 : 0.44) {
                if enemy.kind == .spider { playSpider(.impact) } else { playEnemyAttack(.fax) }
                enemyContact(enemy.kind == .spider ? "Spider bot lunge" : "Dalek-style fax collision"); return
            }
        }
        var survivingBolts: [TrainingEnemyBolt] = []
        let blockers = puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
        for var bolt in enemyBolts {
            bolt.position += bolt.velocity * Float(delta)
            if simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(bolt.position.x, bolt.position.z)) < 0.32 {
                playEnemyAttack(.fax); enemyContact("Dalek-style fax laser"); return
            }
            let outside = abs(bolt.position.x) > puzzle.arenaHalfExtent || abs(bolt.position.z) > puzzle.arenaHalfExtent
            if !outside && !blockers.contains(where: { Self.intersects(bolt.position, barrier: $0, radius: 0.04) }) { survivingBolts.append(bolt) }
        }
        enemyBolts = survivingBolts
    }
    private func fireEnemyBolt(from enemy: TrainingEnemy) {
        var direction = robotPosition - enemy.position; direction.y = 0
        guard simd_length_squared(direction) > 0.001 else { return }
        direction = simd_normalize(direction)
        enemyBolts.append(TrainingEnemyBolt(id: nextBoltID, position: enemy.position + direction * 0.38 + SIMD3<Float>(0, 0.55, 0), velocity: direction * (2.45 + Float(levelIndex) * 0.06)))
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
    private func updateLaserLock() {
        let maxRange = puzzle.arenaHalfExtent * 1.75
        lockedEnemyID = enemies.indices.compactMap { index -> (id: Int, distance: Float)? in
            guard enemies[index].isActive else { return nil }
            let distance = simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(enemies[index].position.x, enemies[index].position.z))
            return distance <= maxRange ? (enemies[index].id, distance) : nil
        }.min(by: { $0.distance < $1.distance })?.id
    }
    private func damageEnemy(at index: Int, weapon: String, amount: Int = 1) {
        guard enemies.indices.contains(index), enemies[index].isActive else { return }
        enemies[index].shields -= amount; score += 50 * amount
        if enemies[index].kind == .spider { playSpider(enemies[index].shields <= 0 ? .shutdown : .impact) }
        if enemies[index].shields <= 0 {
            let kind = enemies[index].kind; enemies[index].isActive = false; score += 300
            if kind == .fax { playEnemyAttack(kind) }
            message = "\(kind.displayName) disabled by \(weapon). \(remainingEnemies) targets remain."
        } else {
            message = "\(enemies[index].kind.displayName) hit by \(weapon) — \(enemies[index].shields) shields remain."
        }
        report(message)
        updateLaserLock()
    }
    func fireLaser() {
        fireLaser(charge: 0)
    }
    func beginLaserCharge() {
        guard isRunning, laserDistance == nil, !isChargingLaser else { return }
        laserCharge = 0; isChargingLaser = true; message = lockedEnemy == nil ? "Shoulder gatling scanning — no target lock yet." : "Shoulder gatling charging on locked target…"
    }
    func releaseLaserCharge() {
        guard isChargingLaser else { return }
        let charge = laserCharge; isChargingLaser = false; laserCharge = 0
        fireLaser(charge: charge)
    }
    private func fireLaser(charge: Double) {
        guard isRunning, laserDistance == nil else { return }
        updateLaserLock()
        guard let targetID = lockedEnemyID, let index = enemies.firstIndex(where: { $0.id == targetID && $0.isActive }), let heading = laserLockHeading else {
            message = "Shoulder gatling still scanning. Turn or move closer until the lock indicator turns red."; report(message); return
        }
        let clampedCharge = min(1, max(0, charge)), damage = 1 + Int(floor(clampedCharge * 2.1))
        laserShotCharge = clampedCharge; laserShotHeading = heading; laserDistance = 0.55
        damageEnemy(at: index, weapon: clampedCharge > 0.72 ? "charged shoulder laser" : "shoulder laser", amount: damage)
        if audioEnabled { SoundPlayer.shared.playLaser(charge: clampedCharge) }
    }
    func saberAttack() {
        guard isRunning else { return }
        saberComboCount = elapsed - lastSaberAttackTime <= 1.15 ? saberComboCount + 1 : 1
        lastSaberAttackTime = elapsed; saberAnimation = 1
        let spin = saberComboCount >= 3
        saberStyle = spin ? .spin : (saberComboCount == 1 ? .leftSweep : .rightSweep)
        if spin { saberComboCount = 0 }
        let forward = SIMD2<Float>(-sin(robotHeading), -cos(robotHeading))
        let hitIndices = enemies.indices.filter { index in
            guard enemies[index].isActive else { return false }
            let offset = SIMD2<Float>(enemies[index].position.x - robotPosition.x, enemies[index].position.z - robotPosition.z)
            let distance = simd_length(offset)
            return distance <= (spin ? 2.15 : 1.55) && (spin || simd_dot(offset, forward) > -0.12)
        }
        if hitIndices.isEmpty { message = spin ? "Spin attack cleared space but missed every target." : "Wide saber swing missed. Move within arm range."; report(message) }
        else {
            for index in hitIndices { damageEnemy(at: index, weapon: spin ? "dual-saber spin" : "dual-saber sweep") }
            if spin { message = "Spin attack! ROB extended both sabers and struck \(hitIndices.count) targets."; report(message) }
        }
        play("laser")
    }
    func collectCell() { guard isRunning, collectedCells < level.cellCount else { return }; collectedCells += 1; score += 150; message = "Energy cell \(collectedCells) of \(level.cellCount)."; report(message); play("pickup") }
    func collectKey() { guard isRunning, level.requiresKey, !hasKey else { return }; hasKey = true; score += 250; message = "Key secured. Bring it to the locked door."; report(message); play("pickup") }
    func openDoor() { guard isRunning, level.requiresKey, !doorOpen else { return }; guard hasKey else { message = "The door is locked. Find the key first."; return }; doorOpen = true; score += 300; message = "Key accepted. Door open."; report(message); play("pickup") }
    func enemyContact(_ attack: String = "Enemy contact") { guard isRunning else { return }; score = max(0, score - 200); configureLevel(); isRunning = true; message = "\(attack) damaged ROB. Restarting level \(level.id)."; report(message) }
    func nextLevel() { guard canFinish else { message = "Finish every objective before leaving the level."; return }; score += max(0, level.timeBonus - Int(elapsed) * 10); if levelIndex < levels.count - 1 { levelIndex += 1; if audioEnabled { TechnoMusicEngine.shared.setLevel(levelIndex) }; enemyAttackCount = 0; configureLevel(); isRunning = true; message = level.challenge; report("ROB advanced to \(level.name). \(level.challenge)") } else { isRunning = false; if audioEnabled { TechnoMusicEngine.shared.stop() }; message = "Fifteen-level campaign complete!" }; play("level-complete") }
    func reset() { levelIndex = 0; score = 0; enemyAttackCount = 0; configureLevel(); isRunning = false; if audioEnabled { TechnoMusicEngine.shared.stop() }; message = "ROB systems ready." }
}
