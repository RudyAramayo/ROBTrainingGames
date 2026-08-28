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

    var displayName: String { self == .spider ? "Spider bot" : "Dalek-style sentry robot" }
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
    let isBoss: Bool
    var position: SIMD3<Float>
    let origin: SIMD3<Float>
    var heading: Float = 0
    var shields: Int
    let maxShields: Int
    var isActive = true
    var nextAttack: TimeInterval
    var nextSkitterSound: TimeInterval = 0
    var lungeRemaining = 0.0

    var displayName: String { isBoss ? "Boss \(kind.displayName)" : kind.displayName }
    var contactDamage: Int { isBoss ? 10 : (kind == .spider ? 6 : 5) }
    var projectileDamage: Int { isBoss ? 10 : 4 }
}

struct TrainingEnemyBolt: Identifiable, Sendable {
    let id: Int
    var position: SIMD3<Float>
    let velocity: SIMD3<Float>
    let damage: Int
    let sourceName: String
    let isBoss: Bool
}

enum SaberAttackStyle: Sendable, Equatable {
    case leftSweep
    case rightSweep
    case spin
    case hammerSmash
}

enum ROBFinish: String, CaseIterable, Identifiable, Sendable {
    case graphite
    case rescueOrange
    case arcticWhite
    case cobaltBlue
    case tacticalGreen

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .graphite: "Graphite"
        case .rescueOrange: "Rescue Orange"
        case .arcticWhite: "Arctic White"
        case .cobaltBlue: "Cobalt Blue"
        case .tacticalGreen: "Tactical Green"
        }
    }
}

enum ROBRangedWeapon: String, CaseIterable, Identifiable, Sendable {
    case shoulderGatling
    case twinBlasters
    case arcCannon

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .shoulderGatling: "Shoulder Gatling"
        case .twinBlasters: "Twin Blasters"
        case .arcCannon: "Arc Cannon"
        }
    }
    var shortName: String {
        switch self {
        case .shoulderGatling: "Gatling"
        case .twinBlasters: "Blasters"
        case .arcCannon: "Arc Cannon"
        }
    }
    var summary: String {
        switch self {
        case .shoulderGatling: "Balanced tracking weapon with a chargeable shoulder shot."
        case .twinBlasters: "Faster paired projectiles for mobile close-range fights."
        case .arcCannon: "Heavy charged energy that arcs into a nearby second target."
        }
    }
    var requiredCompletedLevel: Int {
        switch self {
        case .shoulderGatling: 0
        case .twinBlasters: 5
        case .arcCannon: 15
        }
    }
    var projectileSpeed: Float {
        switch self {
        case .shoulderGatling: 5.5
        case .twinBlasters: 8.4
        case .arcCannon: 4.6
        }
    }
    func damage(charge: Double) -> Int {
        switch self {
        case .shoulderGatling: 1 + Int(floor(charge * 2.1))
        case .twinBlasters: 1 + Int(floor(charge * 1.5))
        case .arcCannon: 2 + Int(floor(charge * 3.0))
        }
    }
}

enum ROBMeleeWeapon: String, CaseIterable, Identifiable, Sendable {
    case dualSabers
    case powerHammer

    var id: String { rawValue }
    var displayName: String { self == .dualSabers ? "Dual Sabers" : "Power Hammer" }
    var shortName: String { self == .dualSabers ? "Sabers" : "Hammer" }
    var summary: String {
        self == .dualSabers
            ? "Fast alternating sweeps build into a full-circle spin attack."
            : "A slower forward smash reaches farther and breaks two shield points."
    }
    var requiredCompletedLevel: Int { self == .dualSabers ? 0 : 10 }
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
    let maxHealth = 100
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
    private(set) var health = 100
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
    private(set) var laserShotWeapon: ROBRangedWeapon = .shoulderGatling
    private var laserShotOrigin = SIMD2<Float>.zero
    private(set) var lockedEnemyID: Int?
    var selectedComponent: ROBComponent?
    var message = "ROB systems ready."
    var isRunning = false
    var musicEnabled = true
    var lastSituation = "ROB systems ready."
    var situationCount = 0
    private(set) var highestCompletedLevel = 0
    private(set) var robotFinish: ROBFinish = .graphite
    private(set) var rangedWeapon: ROBRangedWeapon = .shoulderGatling
    private(set) var meleeWeapon: ROBMeleeWeapon = .dualSabers
    private var nextBoltID = 0
    private var wasAtDock = false
    private var damageInvulnerabilityRemaining = 0.0
    private let audioEnabled: Bool
    private let progressStore: UserDefaults?
    var level: ROBLevel { levels[levelIndex] }
    var remainingEnemies: Int { enemies.filter(\.isActive).count }
    var lockedEnemy: TrainingEnemy? { enemies.first(where: { $0.id == lockedEnemyID && $0.isActive }) }
    var activeBoss: TrainingEnemy? { enemies.first(where: { $0.isBoss && $0.isActive }) }
    var healthFraction: Double { Double(health) / Double(maxHealth) }
    var laserLockDescription: String { lockedEnemy.map { "LOCK: \($0.displayName.uppercased())" } ?? "SCANNING" }
    var laserLockHeading: Float? {
        guard let target = lockedEnemy else { return nil }
        return atan2(-(target.position.x - robotPosition.x), -(target.position.z - robotPosition.z))
    }
    var canFinish: Bool { collectedCells == level.cellCount && remainingEnemies == 0 && (!level.requiresKey || doorOpen) }
    var puzzle: PuzzleGeometry { Self.puzzleGeometry(for: level) }

    init(audioEnabled: Bool = true, progressStore: UserDefaults? = nil) {
        self.audioEnabled = audioEnabled
        self.progressStore = progressStore ?? (audioEnabled ? .standard : nil)
        if let store = self.progressStore {
            highestCompletedLevel = min(levels.count, max(0, store.integer(forKey: "robHighestCompletedLevel")))
            robotFinish = ROBFinish(rawValue: store.string(forKey: "robRobotFinish") ?? "") ?? .graphite
            let savedRanged = ROBRangedWeapon(rawValue: store.string(forKey: "robRangedWeapon") ?? "") ?? .shoulderGatling
            let savedMelee = ROBMeleeWeapon(rawValue: store.string(forKey: "robMeleeWeapon") ?? "") ?? .dualSabers
            rangedWeapon = savedRanged.requiredCompletedLevel <= highestCompletedLevel ? savedRanged : .shoulderGatling
            meleeWeapon = savedMelee.requiredCompletedLevel <= highestCompletedLevel ? savedMelee : .dualSabers
        }
        configureLevel()
    }

    func isUnlocked(_ weapon: ROBRangedWeapon) -> Bool { highestCompletedLevel >= weapon.requiredCompletedLevel }
    func isUnlocked(_ weapon: ROBMeleeWeapon) -> Bool { highestCompletedLevel >= weapon.requiredCompletedLevel }
    func selectFinish(_ finish: ROBFinish) {
        robotFinish = finish
        progressStore?.set(finish.rawValue, forKey: "robRobotFinish")
        message = "\(finish.displayName) finish equipped."
    }
    func selectRangedWeapon(_ weapon: ROBRangedWeapon) {
        guard isUnlocked(weapon) else {
            message = "Complete Level \(weapon.requiredCompletedLevel) to unlock \(weapon.displayName)."
            return
        }
        rangedWeapon = weapon
        progressStore?.set(weapon.rawValue, forKey: "robRangedWeapon")
        message = "\(weapon.displayName) equipped."
    }
    func selectMeleeWeapon(_ weapon: ROBMeleeWeapon) {
        guard isUnlocked(weapon) else {
            message = "Complete Level \(weapon.requiredCompletedLevel) to unlock \(weapon.displayName)."
            return
        }
        meleeWeapon = weapon
        progressStore?.set(weapon.rawValue, forKey: "robMeleeWeapon")
        message = "\(weapon.displayName) equipped."
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
        let key: SIMD2<Float> = level.id == 2 ? [-2.6, 2.8] : [-margin, margin]
        return PuzzleGeometry(arenaHalfExtent: half, key: key, door: door, barriers: walls, cells: cells.map { SIMD2<Float>($0.x > 0 ? $0.x : abs($0.x) + 0.6, $0.y) }, dock: [margin, -margin])
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
            let isBoss = level.id.isMultiple(of: 5) && index == 0
            let shields = isBoss ? max(10, level.enemyShields * 3) : level.enemyShields
            return TrainingEnemy(id: index, kind: kind, isBoss: isBoss, position: origin, origin: origin, shields: shields, maxShields: shields, nextAttack: 1.6 + Double(index) * 0.65, nextSkitterSound: 0.8 + Double(index) * 0.38)
        }
    }
    private func configureLevel() {
        elapsed = 0; collectedCells = 0
        hasKey = false; doorOpen = !level.requiresKey; collectedCellIndices = []; saberAnimation = 0; saberStyle = nil; saberComboCount = 0; lastSaberAttackTime = -.infinity
        laserDistance = nil; laserCharge = 0; laserShotCharge = 0; laserShotWeapon = rangedWeapon; laserShotOrigin = .zero; isChargingLaser = false; lockedEnemyID = nil
        forwardDemand = 0; steeringDemand = 0; leftTread = 0; rightTread = 0
        robotPosition = SIMD3<Float>(0, 0, puzzle.arenaHalfExtent - 0.8); robotHeading = 0; leftWheelAngle = 0; rightWheelAngle = 0
        enemyBolts = []; nextBoltID = 0; wasAtDock = false; enemies = configuredEnemies()
        updateLaserLock()
    }
    func begin() { enemyAttackCount = 0; health = maxHealth; damageInvulnerabilityRemaining = 0; configureLevel(); isRunning = true; if audioEnabled && musicEnabled { TechnoMusicEngine.shared.start(level: levelIndex) }; message = "Level \(level.id): \(level.challenge)"; report("The pilot started \(level.name). \(level.challenge)"); play("mission-start") }
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
        damageInvulnerabilityRemaining = max(0, damageInvulnerabilityRemaining - delta)
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
            let animationSpeed = switch saberStyle {
            case .spin: 1.25
            case .hammerSmash: 1.55
            default: 2.25
            }
            saberAnimation = max(0, saberAnimation - delta * animationSpeed)
            if saberAnimation == 0 { saberStyle = nil }
        }
        if isChargingLaser { laserCharge = min(1, laserCharge + delta / 1.25) }
        updateLaserProjectile(delta)
        updateEnemies(delta)
        updateLaserLock()
    }
    private static func intersects(_ position: SIMD3<Float>, barrier: PuzzleBarrier, radius: Float = 0.32) -> Bool {
        abs(position.x - barrier.center.x) < barrier.size.x / 2 + radius && abs(position.z - barrier.center.y) < barrier.size.y / 2 + radius
    }
    private var projectileBlockers: [PuzzleBarrier] {
        let half = puzzle.arenaHalfExtent
        let perimeter = [
            PuzzleBarrier(center: [0, -half], size: [half * 2, 0.18]),
            PuzzleBarrier(center: [0, half], size: [half * 2, 0.18]),
            PuzzleBarrier(center: [-half, 0], size: [0.18, half * 2]),
            PuzzleBarrier(center: [half, 0], size: [0.18, half * 2]),
        ]
        return puzzle.barriers + perimeter + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
    }
    private static func segmentHitFraction(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        barrier: PuzzleBarrier,
        padding: Float
    ) -> Float? {
        let delta = end - start
        let minimum = barrier.center - barrier.size / 2 - SIMD2<Float>(repeating: padding)
        let maximum = barrier.center + barrier.size / 2 + SIMD2<Float>(repeating: padding)
        var entry: Float = 0
        var exit: Float = 1

        for axis in 0..<2 {
            if abs(delta[axis]) < 0.000_001 {
                guard start[axis] >= minimum[axis], start[axis] <= maximum[axis] else { return nil }
                continue
            }
            let first = (minimum[axis] - start[axis]) / delta[axis]
            let second = (maximum[axis] - start[axis]) / delta[axis]
            entry = max(entry, min(first, second))
            exit = min(exit, max(first, second))
            if entry > exit { return nil }
        }
        return entry
    }
    private static func segmentHitFraction(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        center: SIMD2<Float>,
        radius: Float
    ) -> Float? {
        let delta = end - start
        let offset = start - center
        let a = simd_dot(delta, delta)
        guard a > 0.000_001 else { return simd_length_squared(offset) <= radius * radius ? 0 : nil }
        let c = simd_dot(offset, offset) - radius * radius
        if c <= 0 { return 0 }
        let b = 2 * simd_dot(offset, delta)
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return nil }
        let root = sqrt(discriminant)
        let first = (-b - root) / (2 * a)
        let second = (-b + root) / (2 * a)
        if (0...1).contains(first) { return first }
        if (0...1).contains(second) { return second }
        return nil
    }
    private func updateLaserProjectile(_ delta: TimeInterval) {
        guard let distance = laserDistance else { return }
        let maximumDistance = puzzle.arenaHalfExtent * 2.2
        let nextDistance = min(maximumDistance, distance + Float(delta) * (laserShotWeapon.projectileSpeed + Float(laserShotCharge) * 3.5))
        let direction = SIMD2<Float>(-sin(laserShotHeading), -cos(laserShotHeading))
        let start = laserShotOrigin + direction * distance
        let end = laserShotOrigin + direction * nextDistance

        enum Impact {
            case barrier
            case enemy(Int)
        }
        var nearestImpact: (fraction: Float, impact: Impact)?
        for blocker in projectileBlockers {
            guard let fraction = Self.segmentHitFraction(from: start, to: end, barrier: blocker, padding: 0.07) else { continue }
            if nearestImpact.map({ fraction < $0.fraction }) ?? true {
                nearestImpact = (fraction, .barrier)
            }
        }
        for index in enemies.indices where enemies[index].isActive {
            let enemy = enemies[index]
            let radius: Float = (enemy.kind == .spider ? 0.34 : 0.4) * (enemy.isBoss ? 1.35 : 1)
            guard let fraction = Self.segmentHitFraction(
                from: start,
                to: end,
                center: [enemy.position.x, enemy.position.z],
                radius: radius
            ) else { continue }
            if nearestImpact.map({ fraction < $0.fraction }) ?? true {
                nearestImpact = (fraction, .enemy(index))
            }
        }

        if let nearestImpact {
            laserDistance = nil
            switch nearestImpact.impact {
            case .barrier:
                message = "\(laserShotWeapon.displayName) struck the wall. Reposition for a clear shot."
                report(message)
            case let .enemy(index):
                let damage = laserShotWeapon.damage(charge: laserShotCharge)
                let weapon = laserShotWeapon
                let secondaryTargets = weapon == .arcCannon ? enemies.indices.filter { candidate in
                    candidate != index && enemies[candidate].isActive && simd_distance(enemies[candidate].position, enemies[index].position) <= 1.45
                } : []
                damageEnemy(
                    at: index,
                    weapon: laserShotCharge > 0.72 ? "charged \(weapon.displayName.lowercased())" : weapon.displayName.lowercased(),
                    amount: damage
                )
                if let secondary = secondaryTargets.first {
                    damageEnemy(at: secondary, weapon: "arc cannon chain", amount: max(1, damage / 2))
                }
            }
        } else {
            laserDistance = nextDistance >= maximumDistance ? nil : nextDistance
        }
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
                    playEnemyAttack(.fax); message = "Dalek-style sentry robot: “Exterminate!” Incoming laser — keep moving."; report(message)
                }
            }
            let facing = robotPosition - enemy.position; enemy.heading = atan2(-facing.x, -facing.z)
            moveEnemy(&enemy, toward: target, speed: speed, delta: delta); enemies[index] = enemy
            let contactRadius: Float = (enemy.kind == .spider ? 0.5 : 0.44) * (enemy.isBoss ? 1.35 : 1)
            if simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(enemy.position.x, enemy.position.z)) < contactRadius {
                if enemy.kind == .spider { playSpider(.impact) } else { playEnemyAttack(.fax) }
                if enemyContact(enemy.kind == .spider ? "\(enemy.displayName) lunge" : "\(enemy.displayName) collision", damage: enemy.contactDamage) { return }
            }
        }
        var survivingBolts: [TrainingEnemyBolt] = []
        let blockers = puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
        for var bolt in enemyBolts {
            bolt.position += bolt.velocity * Float(delta)
            if simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(bolt.position.x, bolt.position.z)) < 0.32 {
                playEnemyAttack(.fax)
                enemyBolts = survivingBolts
                enemyContact(bolt.sourceName, damage: bolt.damage)
                return
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
        enemyBolts.append(TrainingEnemyBolt(id: nextBoltID, position: enemy.position + direction * 0.38 + SIMD3<Float>(0, 0.55, 0), velocity: direction * (2.45 + Float(levelIndex) * 0.06), damage: enemy.projectileDamage, sourceName: "\(enemy.displayName) laser", isBoss: enemy.isBoss))
        nextBoltID += 1
    }
    private func resolveSpatialObjectives() {
        let point = SIMD2<Float>(robotPosition.x, robotPosition.z)
        if let key = puzzle.key, !hasKey, simd_distance(point, key) < 0.48 { collectKey() }
        if let door = puzzle.door, !doorOpen, simd_distance(point, door.center) < 0.72 { openDoor() }
        for (index, cell) in puzzle.cells.enumerated() where !collectedCellIndices.contains(index) && simd_distance(point, cell) < 0.45 {
            collectedCellIndices.insert(index); collectCell()
        }
        let atDock = simd_distance(point, puzzle.dock) < 0.55
        if atDock && canFinish {
            nextLevel()
            return
        }
        if atDock && !wasAtDock {
            message = "Dock offline — \(dockRequirements)."
            report(message)
        }
        wasAtDock = atDock
    }
    private var dockRequirements: String {
        var requirements: [String] = []
        if level.requiresKey && !hasKey { requirements.append("find the key") }
        else if level.requiresKey && !doorOpen { requirements.append("open the door") }
        let cellsLeft = level.cellCount - collectedCells
        if cellsLeft > 0 { requirements.append("collect \(cellsLeft) more energy \(cellsLeft == 1 ? "cell" : "cells")") }
        if remainingEnemies > 0 { requirements.append("disable \(remainingEnemies) more \(remainingEnemies == 1 ? "target" : "targets")") }
        return requirements.joined(separator: " and ")
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
            let kind = enemies[index].kind, name = enemies[index].displayName, wasBoss = enemies[index].isBoss
            enemies[index].isActive = false; score += wasBoss ? 1_000 : 300
            if kind == .fax { playEnemyAttack(kind) }
            message = "\(name) disabled by \(weapon). \(remainingEnemies) targets remain."
        } else {
            message = "\(enemies[index].displayName) hit by \(weapon) — \(enemies[index].shields) shields remain."
        }
        report(message)
        updateLaserLock()
    }
    func fireLaser() {
        fireLaser(charge: 0)
    }
    func beginLaserCharge() {
        guard isRunning, laserDistance == nil, !isChargingLaser else { return }
        laserCharge = 0; isChargingLaser = true; message = lockedEnemy == nil ? "\(rangedWeapon.displayName) scanning — no target lock yet." : "\(rangedWeapon.displayName) charging on locked target…"
    }
    func releaseLaserCharge() {
        guard isChargingLaser else { return }
        let charge = laserCharge; isChargingLaser = false; laserCharge = 0
        fireLaser(charge: charge)
    }
    private func fireLaser(charge: Double) {
        guard isRunning, laserDistance == nil else { return }
        updateLaserLock()
        guard let targetID = lockedEnemyID, enemies.contains(where: { $0.id == targetID && $0.isActive }), let heading = laserLockHeading else {
            message = "\(rangedWeapon.displayName) is still scanning. Turn or move closer until the lock indicator turns red."; report(message); return
        }
        let clampedCharge = min(1, max(0, charge))
        laserShotCharge = clampedCharge; laserShotHeading = heading; laserShotWeapon = rangedWeapon
        laserShotOrigin = [robotPosition.x, robotPosition.z]; laserDistance = 0.55
        message = "\(rangedWeapon.displayName) fired."
        report(message)
        if audioEnabled { SoundPlayer.shared.playLaser(charge: clampedCharge) }
    }
    func saberAttack() {
        guard isRunning else { return }
        if meleeWeapon == .powerHammer {
            saberComboCount = 0; lastSaberAttackTime = elapsed; saberAnimation = 1; saberStyle = .hammerSmash
            let forward = SIMD2<Float>(-sin(robotHeading), -cos(robotHeading))
            let hitIndices = enemies.indices.filter { index in
                guard enemies[index].isActive else { return false }
                let offset = SIMD2<Float>(enemies[index].position.x - robotPosition.x, enemies[index].position.z - robotPosition.z)
                return simd_length(offset) <= 2.05 && simd_dot(offset, forward) > 0.08
            }
            if hitIndices.isEmpty {
                message = "Power hammer smash missed. Face a target within reach."; report(message)
            } else {
                for index in hitIndices { damageEnemy(at: index, weapon: "power hammer", amount: 2) }
                message = "Power hammer smash struck \(hitIndices.count) \(hitIndices.count == 1 ? "target" : "targets")."; report(message)
            }
            play("laser")
            return
        }
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
    @discardableResult
    func enemyContact(_ attack: String = "Enemy contact", damage: Int = 5) -> Bool {
        guard isRunning, damageInvulnerabilityRemaining <= 0 else { return false }
        let appliedDamage = max(0, damage)
        health = max(0, health - appliedDamage)
        score = max(0, score - appliedDamage * 20)
        damageInvulnerabilityRemaining = 0.75
        if health == 0 {
            configureLevel()
            health = maxHealth
            damageInvulnerabilityRemaining = 1
            isRunning = true
            message = "ROB was disabled by \(attack). Restarting level \(level.id) with full health."
        } else {
            message = "\(attack) dealt \(appliedDamage) damage. ROB health: \(health)/\(maxHealth)."
        }
        report(message)
        return true
    }
    func nextLevel() {
        guard canFinish else { message = "Finish every objective before leaving the level."; return }
        let completedLevel = level.id
        score += max(0, level.timeBonus - Int(elapsed) * 10)
        let earnedNewProgress = completedLevel > highestCompletedLevel
        highestCompletedLevel = max(highestCompletedLevel, completedLevel)
        progressStore?.set(highestCompletedLevel, forKey: "robHighestCompletedLevel")
        let reward: String?
        if earnedNewProgress {
            switch completedLevel {
            case 5: reward = "Twin Blasters unlocked in the ROB workshop!"
            case 10: reward = "Power Hammer unlocked in the ROB workshop!"
            case 15: reward = "Arc Cannon unlocked in the ROB workshop!"
            default: reward = nil
            }
        } else {
            reward = nil
        }
        if levelIndex < levels.count - 1 {
            levelIndex += 1
            if audioEnabled { TechnoMusicEngine.shared.setLevel(levelIndex) }
            enemyAttackCount = 0; health = maxHealth; damageInvulnerabilityRemaining = 0; configureLevel(); isRunning = true
            message = [reward, level.challenge].compactMap { $0 }.joined(separator: " ")
            report("ROB advanced to \(level.name). \(message)")
        } else {
            isRunning = false
            if audioEnabled { TechnoMusicEngine.shared.stop() }
            message = [reward, "Fifteen-level campaign complete!"].compactMap { $0 }.joined(separator: " ")
            report(message)
        }
        play("level-complete")
    }
    func reset() { levelIndex = 0; score = 0; health = maxHealth; damageInvulnerabilityRemaining = 0; enemyAttackCount = 0; configureLevel(); isRunning = false; if audioEnabled { TechnoMusicEngine.shared.stop() }; message = "ROB systems ready." }
}
