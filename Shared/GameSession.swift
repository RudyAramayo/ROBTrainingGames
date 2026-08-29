import Foundation
import Observation
import simd

struct ROBTreadInput: Equatable, Sendable {
    let left: Double
    let right: Double

    static func tank(leftStickY: Float, rightStickY: Float, deadzone: Float = 0.12) -> ROBTreadInput {
        ROBTreadInput(
            left: Double(normalize(leftStickY, deadzone: deadzone)),
            right: Double(normalize(rightStickY, deadzone: deadzone))
        )
    }

    private static func normalize(_ value: Float, deadzone: Float) -> Float {
        let deadzone = min(0.45, max(0, deadzone))
        let value = min(1, max(-1, value))
        let magnitude = abs(value)
        guard magnitude > deadzone else { return 0 }
        return copysign((magnitude - deadzone) / (1 - deadzone), value)
    }
}

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
    let isMiniBoss: Bool
    var position: SIMD3<Float>
    let origin: SIMD3<Float>
    var heading: Float = 0
    var shields: Int
    let maxShields: Int
    var isActive = true
    var nextAttack: TimeInterval
    var nextSkitterSound: TimeInterval = 0
    var lungeRemaining = 0.0

    var displayName: String { isMiniBoss ? "Mini Boss \(kind.displayName)" : isBoss ? "Boss \(kind.displayName)" : kind.displayName }
    var contactDamage: Int { isMiniBoss ? 4 : isBoss ? 10 : (kind == .spider ? 6 : 5) }
    var projectileDamage: Int { isMiniBoss ? 3 : isBoss ? 10 : 4 }
    var combatScale: Float { isMiniBoss ? 1.15 : isBoss ? 1.35 : 1 }
    var defeatReward: Int { isMiniBoss ? 500 : isBoss ? 1_000 : 300 }
}

struct TrainingEnemyBolt: Identifiable, Sendable {
    let id: Int
    var position: SIMD3<Float>
    let velocity: SIMD3<Float>
    let damage: Int
    let sourceName: String
    let isBoss: Bool
}

enum ROBLaserBarrel: String, Hashable, Sendable {
    case center
    case left
    case right
}

struct ROBLaserProjectile: Identifiable, Sendable {
    var id: ROBLaserBarrel { barrel }
    let barrel: ROBLaserBarrel
    let weapon: ROBRangedWeapon
    let charge: Double
    let targetID: Int
    let origin: SIMD2<Float>
    let heading: Float
    var distance: Float
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

enum ROBFaceColor: String, CaseIterable, Identifiable, Sendable {
    case lime
    case cyan
    case amber
    case magenta
    case white
    case red

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lime: "Lime"
        case .cyan: "Cyan"
        case .amber: "Amber"
        case .magenta: "Magenta"
        case .white: "White"
        case .red: "Red"
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
        case .twinBlasters: "Two fast projectiles converge on one lock, or split across two targets with the targeting computer upgrade."
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
    func energyCost(charge: Double) -> Double {
        let charge = min(1, max(0, charge))
        return switch self {
        case .shoulderGatling: 4 + charge * 8
        case .twinBlasters: 5 + charge * 9
        case .arcCannon: 8 + charge * 14
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

struct PuzzleConveyor: Identifiable, Sendable {
    let id: Int
    let center: SIMD2<Float>
    let size: SIMD2<Float>
    let direction: SIMD2<Float>
    let speed: Float
}

struct PuzzleSecurityCamera: Identifiable, Sendable {
    let id: Int
    let position: SIMD2<Float>
    let heading: Float
    let sweep: Float
    let range: Float
}

struct PuzzleGeometry: Sendable {
    let arenaHalfExtent: Float
    let key: SIMD2<Float>?
    let door: PuzzleBarrier?
    let barriers: [PuzzleBarrier]
    let cells: [SIMD2<Float>]
    let shieldPickups: [SIMD2<Float>]
    let repairPickups: [SIMD2<Float>]
    let dock: SIMD2<Float>
    let hackTerminal: SIMD2<Float>?
    let conveyors: [PuzzleConveyor]
    let securityCameras: [PuzzleSecurityCamera]
    let shadowZones: [PuzzleBarrier]
}

enum ROBUpgrade: String, CaseIterable, Identifiable, Sendable {
    case speedBoost
    case energyCapacity
    case weaponPower
    case targetingComputer

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .speedBoost: "Speed Boost"
        case .energyCapacity: "Energy Capacity"
        case .weaponPower: "Weapon Power"
        case .targetingComputer: "Targeting Computer"
        }
    }
    var summary: String {
        switch self {
        case .speedBoost: "Raises tread speed by 35% per upgrade."
        case .energyCapacity: "Adds 25 energy and improves passive charging."
        case .weaponPower: "Adds one shield point of damage to every hit."
        case .targetingComputer: "Unlocks independent target locks for the two Twin Blaster barrels."
        }
    }
    var maximumLevel: Int { self == .targetingComputer ? 1 : 3 }
    func cost(for level: Int) -> Int {
        switch self {
        case .speedBoost: 700 + level * 650
        case .energyCapacity: 550 + level * 500
        case .weaponPower: 900 + level * 800
        case .targetingComputer: 1_200
        }
    }
}

@MainActor @Observable
final class GameSession {
    static let gameplayRulesetVersion = "2026.09.05"
    static let robotCollisionRadius: Float = 0.62
    static let securityCameraHalfAngle: Float = .pi / 5
    static let doorwayWidth: Float = 2.1
    static let zigzagSpacing: Float = 1.9
    let maxHealth = 100
    let maxShields = 40
    let shieldPickupStrength = 24
    let repairPickupStrength = 35
    let levels = [
        ROBLevel(id: 1, name: "Calibration Deck", lesson: "Arrow controls mix forward speed and steering into two tread demands.", cellCount: 5, enemyKinds: [.spider, .fax, .spider], enemyShields: 2, timeBonus: 900, requiresKey: false, challenge: "Learn smooth turns, evade three active enemies, collect five cells, and reach the dock."),
        ROBLevel(id: 2, name: "Key Workshop", lesson: "A key changes the state of a matching locked door.", cellCount: 5, enemyKinds: [.spider, .fax, .spider], enemyShields: 2, timeBonus: 1_100, requiresKey: true, challenge: "Find the cyan key while a three-robot patrol guards the workshop door."),
        ROBLevel(id: 3, name: "Crossroads", lesson: "Plan a route before entering a narrow passage.", cellCount: 6, enemyKinds: [.spider, .fax, .spider], enemyShields: 2, timeBonus: 1_300, requiresKey: true, challenge: "Choose the safe branch, secure the key, then break through the center patrol."),
        ROBLevel(id: 4, name: "Sensor Hall", lesson: "Wide clearance is often faster than scraping along obstacles.", cellCount: 6, enemyKinds: [.spider, .fax, .spider, .fax], enemyShields: 2, timeBonus: 1_500, requiresKey: false, challenge: "Use the expanded hall to separate four sentries guarding the cells."),
        ROBLevel(id: 5, name: "Amber Armory", lesson: "A seven-joint arm trades reach for a larger collision envelope.", cellCount: 6, enemyKinds: [.fax, .spider, .fax, .spider], enemyShields: 3, timeBonus: 1_700, requiresKey: true, challenge: "Recover the armory key and chain wide saber swings without touching enemies."),
        ROBLevel(id: 6, name: "Switchback Foundry", lesson: "Slow before turning so both treads can follow the planned curve.", cellCount: 7, enemyKinds: [.spider, .fax, .spider, .fax, .spider], enemyShields: 3, timeBonus: 1_900, requiresKey: true, challenge: "Navigate alternating turns while five guards coordinate their attacks."),
        ROBLevel(id: 7, name: "Twin Sentinel Bay", lesson: "Keep one escape route open while engaging moving obstacles.", cellCount: 7, enemyKinds: [.fax, .fax, .spider, .spider, .fax], enemyShields: 3, timeBonus: 2_100, requiresKey: false, challenge: "Separate the sentinel wave and keep moving through crossfire."),
        ROBLevel(id: 8, name: "Power Relay", lesson: "Complete prerequisites in the right order: key, door, cells, then dock.", cellCount: 7, enemyKinds: [.spider, .fax, .spider, .fax, .spider], enemyShields: 4, timeBonus: 2_300, requiresKey: true, challenge: "Unlock the relay room before clearing its reinforced defenders."),
        ROBLevel(id: 9, name: "Guardian Maze", lesson: "Reliable autonomy needs state, perception, and a recoverable plan.", cellCount: 8, enemyKinds: [.spider, .fax, .spider, .fax, .spider, .fax], enemyShields: 4, timeBonus: 2_600, requiresKey: true, challenge: "Find the key in the outer loop and survive the six-robot guardian wave."),
        ROBLevel(id: 10, name: "Mission Control", lesson: "Combine driving, sequencing, tool use, and safe separation.", cellCount: 8, enemyKinds: [.fax, .spider, .fax, .spider, .fax, .spider], enemyShields: 4, timeBonus: 3_000, requiresKey: true, challenge: "Complete the full safety sequence under alternating ranged and melee attacks."),
        ROBLevel(id: 11, name: "Reactor Run", lesson: "A target lock is useful only when the route remains safe.", cellCount: 8, enemyKinds: [.spider, .spider, .fax, .spider, .fax, .fax], enemyShields: 4, timeBonus: 3_300, requiresKey: false, challenge: "Cross the reactor floor while charging shoulder shots between lunges."),
        ROBLevel(id: 12, name: "Eclipse Hangar", lesson: "Scan, prioritize, and reposition before committing to an attack.", cellCount: 8, enemyKinds: [.fax, .spider, .fax, .spider, .fax, .spider], enemyShields: 4, timeBonus: 3_600, requiresKey: true, challenge: "Open the hangar partition and defeat a balanced six-robot squad."),
        ROBLevel(id: 13, name: "Quantum Causeway", lesson: "Short control cycles preserve options in crowded spaces.", cellCount: 9, enemyKinds: [.spider, .fax, .spider, .fax, .spider, .fax, .spider], enemyShields: 5, timeBonus: 3_900, requiresKey: true, challenge: "Use spin attacks to make room without stopping in the causeway."),
        ROBLevel(id: 14, name: "Siege Foundry", lesson: "Threat management matters more than attacking the nearest target.", cellCount: 9, enemyKinds: [.fax, .fax, .spider, .fax, .spider, .spider, .fax], enemyShields: 5, timeBonus: 4_200, requiresKey: true, challenge: "Break the foundry siege by charging shots only when the lane is clear."),
        ROBLevel(id: 15, name: "Final Citadel", lesson: "Integrate mobility, target lock, timing, and tool choice.", cellCount: 10, enemyKinds: [.spider, .fax, .spider, .fax, .spider, .fax, .spider, .fax], enemyShields: 5, timeBonus: 4_800, requiresKey: true, challenge: "Clear the eight-robot citadel wave and complete the expanded campaign."),
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
    private(set) var upgradePoints = 0
    private(set) var health = 100
    private(set) var shields = 40
    private(set) var energy = 100.0
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
    private(set) var isHackingDoor = false
    private(set) var hackingProgress = 0.0
    private(set) var securityAlertRemaining = 0.0
    var collectedCellIndices: Set<Int> = []
    var collectedShieldPickupIndices: Set<Int> = []
    var collectedRepairPickupIndices: Set<Int> = []
    var saberAnimation = 0.0
    var saberStyle: SaberAttackStyle?
    private(set) var saberComboCount = 0
    private var lastSaberAttackTime = -Double.infinity
    private(set) var laserProjectiles: [ROBLaserProjectile] = []
    private(set) var laserCharge = 0.0
    private(set) var isChargingLaser = false
    private(set) var laserShotCharge = 0.0
    private(set) var lockedEnemyID: Int?
    private(set) var secondaryLockedEnemyID: Int?
    var selectedComponent: ROBComponent?
    var message = "ROB systems ready."
    var isRunning = false
    private(set) var isPaused = false
    private(set) var isUpgradeIntermission = false
    var musicEnabled = true
    var lastSituation = "ROB systems ready."
    var situationCount = 0
    private(set) var highestCompletedLevel = 0
    private(set) var robotFinish: ROBFinish = .graphite
    private(set) var faceColor: ROBFaceColor = .lime
    private(set) var rangedWeapon: ROBRangedWeapon = .shoulderGatling
    private(set) var meleeWeapon: ROBMeleeWeapon = .dualSabers
    private(set) var speedUpgradeLevel = 0
    private(set) var energyUpgradeLevel = 0
    private(set) var weaponUpgradeLevel = 0
    private(set) var targetingComputerUpgradeLevel = 0
    private var nextBoltID = 0
    private var wasAtDock = false
    private var wasEnergyDepleted = false
    private var damageInvulnerabilityRemaining = 0.0
    private let audioEnabled: Bool
    private let progressStore: UserDefaults?
    var level: ROBLevel { levels[levelIndex] }
    var remainingEnemies: Int { enemies.filter(\.isActive).count }
    var laserDistance: Float? { laserProjectiles.first?.distance }
    var lockedEnemy: TrainingEnemy? { enemies.first(where: { $0.id == lockedEnemyID && $0.isActive }) }
    var secondaryLockedEnemy: TrainingEnemy? { enemies.first(where: { $0.id == secondaryLockedEnemyID && $0.isActive }) }
    var activeBoss: TrainingEnemy? { enemies.first(where: { $0.isBoss && $0.isActive }) }
    var healthFraction: Double { Double(health) / Double(maxHealth) }
    var shieldFraction: Double { Double(shields) / Double(maxShields) }
    var maxEnergy: Double { 100 + Double(energyUpgradeLevel * 25) }
    var energyFraction: Double { energy / maxEnergy }
    var driveSpeedMultiplier: Double { 1 + Double(speedUpgradeLevel) * 0.35 }
    var weaponDamageBonus: Int { weaponUpgradeLevel }
    var hasIndependentTwinTargeting: Bool { targetingComputerUpgradeLevel > 0 }
    var isSecurityAlerted: Bool { securityAlertRemaining > 0 }
    var isInShadow: Bool {
        let point = SIMD3<Float>(robotPosition.x, 0, robotPosition.z)
        return puzzle.shadowZones.contains { Self.intersects(point, barrier: $0, radius: 0) }
    }
    var isNearHackTerminal: Bool {
        guard let terminal = puzzle.hackTerminal else { return false }
        return simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), terminal) <= Self.robotCollisionRadius + 0.48
    }
    var canStartDoorHack: Bool { isRunning && level.requiresKey && hasKey && !doorOpen && !isHackingDoor && isNearHackTerminal }
    var doorHackDescription: String {
        if doorOpen { return "Door hacked" }
        if isHackingDoor { return "Hacking \(Int(hackingProgress * 100))%" }
        if !hasKey { return "Find access key" }
        return isNearHackTerminal ? "Hack door" : "Reach orange hack panel"
    }
    var laserLockDescription: String {
        guard let primary = lockedEnemy else { return "SCANNING" }
        guard rangedWeapon == .twinBlasters else { return "LOCK: \(primary.displayName.uppercased())" }
        if let secondary = secondaryLockedEnemy {
            return "DUAL LOCK: \(primary.displayName.uppercased()) + \(secondary.displayName.uppercased())"
        }
        return hasIndependentTwinTargeting
            ? "LOCK: \(primary.displayName.uppercased()) · SEEKING SECOND TARGET"
            : "LOCK: \(primary.displayName.uppercased()) · UPGRADE TARGETING COMPUTER FOR DUAL LOCK"
    }
    var laserLockHeading: Float? {
        guard let target = lockedEnemy else { return nil }
        return atan2(-(target.position.x - robotPosition.x), -(target.position.z - robotPosition.z))
    }
    var secondaryLaserLockHeading: Float? {
        guard let target = secondaryLockedEnemy else { return nil }
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
            faceColor = ROBFaceColor(rawValue: store.string(forKey: "robFaceColor") ?? "") ?? .lime
            let savedRanged = ROBRangedWeapon(rawValue: store.string(forKey: "robRangedWeapon") ?? "") ?? .shoulderGatling
            let savedMelee = ROBMeleeWeapon(rawValue: store.string(forKey: "robMeleeWeapon") ?? "") ?? .dualSabers
            rangedWeapon = savedRanged.requiredCompletedLevel <= highestCompletedLevel ? savedRanged : .shoulderGatling
            meleeWeapon = savedMelee.requiredCompletedLevel <= highestCompletedLevel ? savedMelee : .dualSabers
            upgradePoints = max(0, store.integer(forKey: "robUpgradePoints"))
            speedUpgradeLevel = min(ROBUpgrade.speedBoost.maximumLevel, max(0, store.integer(forKey: "robSpeedUpgradeLevel")))
            energyUpgradeLevel = min(ROBUpgrade.energyCapacity.maximumLevel, max(0, store.integer(forKey: "robEnergyUpgradeLevel")))
            weaponUpgradeLevel = min(ROBUpgrade.weaponPower.maximumLevel, max(0, store.integer(forKey: "robWeaponUpgradeLevel")))
            targetingComputerUpgradeLevel = min(ROBUpgrade.targetingComputer.maximumLevel, max(0, store.integer(forKey: "robTargetingComputerUpgradeLevel")))
        }
        configureLevel()
    }

    func isUnlocked(_ weapon: ROBRangedWeapon) -> Bool { highestCompletedLevel >= weapon.requiredCompletedLevel }
    func isUnlocked(_ weapon: ROBMeleeWeapon) -> Bool { highestCompletedLevel >= weapon.requiredCompletedLevel }
    func upgradeLevel(_ upgrade: ROBUpgrade) -> Int {
        switch upgrade {
        case .speedBoost: speedUpgradeLevel
        case .energyCapacity: energyUpgradeLevel
        case .weaponPower: weaponUpgradeLevel
        case .targetingComputer: targetingComputerUpgradeLevel
        }
    }
    func upgradeCost(_ upgrade: ROBUpgrade) -> Int? {
        let level = upgradeLevel(upgrade)
        return level < upgrade.maximumLevel ? upgrade.cost(for: level) : nil
    }
    func purchaseUpgrade(_ upgrade: ROBUpgrade) {
        let level = upgradeLevel(upgrade)
        guard level < upgrade.maximumLevel else { message = "\(upgrade.displayName) is already fully upgraded."; return }
        let cost = upgrade.cost(for: level)
        guard upgradePoints >= cost else { message = "\(cost - upgradePoints) more mission points needed for \(upgrade.displayName)."; return }
        upgradePoints -= cost
        switch upgrade {
        case .speedBoost:
            speedUpgradeLevel += 1
            progressStore?.set(speedUpgradeLevel, forKey: "robSpeedUpgradeLevel")
        case .energyCapacity:
            energyUpgradeLevel += 1
            energy = min(maxEnergy, energy + 25)
            progressStore?.set(energyUpgradeLevel, forKey: "robEnergyUpgradeLevel")
        case .weaponPower:
            weaponUpgradeLevel += 1
            progressStore?.set(weaponUpgradeLevel, forKey: "robWeaponUpgradeLevel")
        case .targetingComputer:
            targetingComputerUpgradeLevel += 1
            progressStore?.set(targetingComputerUpgradeLevel, forKey: "robTargetingComputerUpgradeLevel")
        }
        progressStore?.set(upgradePoints, forKey: "robUpgradePoints")
        message = "\(upgrade.displayName) upgraded to Level \(level + 1)."
        report(message)
    }
    func selectFinish(_ finish: ROBFinish) {
        robotFinish = finish
        progressStore?.set(finish.rawValue, forKey: "robRobotFinish")
        message = "\(finish.displayName) finish equipped."
    }
    func selectFaceColor(_ color: ROBFaceColor) {
        faceColor = color
        progressStore?.set(color.rawValue, forKey: "robFaceColor")
        message = "\(color.displayName) smile equipped."
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
        let columns: [Float] = [-margin, -margin * 0.45, 0, margin * 0.45]
        let cells = (0..<level.cellCount).map { index in
            SIMD2<Float>(columns[index % columns.count], -margin + Float(index / columns.count) * 2.0)
        }
        let environment = environmentalGeometry(for: level, margin: margin)
        func makeGeometry(
            key: SIMD2<Float>?,
            door: PuzzleBarrier?,
            barriers: [PuzzleBarrier],
            cells: [SIMD2<Float>],
            dock: SIMD2<Float>,
            hackTerminal: SIMD2<Float>?
        ) -> PuzzleGeometry {
            let blockers = barriers + (door.map { [$0] } ?? [])
            var reserved = [dock]
            if let key { reserved.append(key) }
            if let hackTerminal { reserved.append(hackTerminal) }
            let gridSteps: [Float] = [-1, -0.72, -0.45, -0.18, 0.18, 0.45, 0.72, 1]
            let gridCandidates = gridSteps.flatMap { y in gridSteps.map { x in SIMD2<Float>(x * margin, y * margin) } }
            let gridRotation = level.id * 3 % gridCandidates.count
            let orderedGrid = Array(gridCandidates[gridRotation...]) + Array(gridCandidates[..<gridRotation])
            var safeCells: [SIMD2<Float>] = []
            for candidate in cells + orderedGrid where safeCells.count < level.cellCount {
                guard reserved.allSatisfy({ simd_distance(candidate, $0) > 0.68 }) else { continue }
                guard blockers.allSatisfy({
                    !intersects(SIMD3<Float>(candidate.x, 0, candidate.y), barrier: $0, radius: robotCollisionRadius)
                }) else { continue }
                safeCells.append(candidate)
                reserved.append(candidate)
            }

            let candidates: [SIMD2<Float>] = [
                [-margin * 0.82, -margin * 0.62], [margin * 0.78, -margin * 0.48],
                [-margin * 0.72, margin * 0.18], [margin * 0.74, margin * 0.34],
                [-margin * 0.28, margin * 0.72], [margin * 0.22, -margin * 0.78],
                [0, margin * 0.46], [-margin * 0.48, -margin * 0.08],
                [margin * 0.46, margin * 0.02], [0, -margin * 0.42],
            ]
            let rotation = level.id % candidates.count
            let ordered = Array(candidates[rotation...]) + Array(candidates[..<rotation])
            var available = ordered.filter { candidate in
                abs(candidate.x) < margin && abs(candidate.y) < margin
                    && reserved.allSatisfy { simd_distance(candidate, $0) > 0.68 }
                    && blockers.allSatisfy {
                        !intersects(SIMD3<Float>(candidate.x, 0, candidate.y), barrier: $0, radius: robotCollisionRadius)
                    }
            }
            func takePickup() -> SIMD2<Float> {
                guard !available.isEmpty else { return [0, 0] }
                let pickup = available.removeFirst()
                reserved.append(pickup)
                available.removeAll { simd_distance($0, pickup) <= 0.75 }
                return pickup
            }
            let shieldPickups = (0..<(level.id >= 8 ? 2 : 1)).map { _ in takePickup() }
            let repairPickups = (0..<(level.id >= 10 ? 2 : 1)).map { _ in takePickup() }
            return PuzzleGeometry(
                arenaHalfExtent: half,
                key: key,
                door: door,
                barriers: barriers,
                cells: safeCells,
                shieldPickups: shieldPickups,
                repairPickups: repairPickups,
                dock: dock,
                hackTerminal: hackTerminal,
                conveyors: environment.conveyors,
                securityCameras: environment.cameras,
                shadowZones: environment.shadows
            )
        }
        guard level.requiresKey else {
            let zigzag = (0..<min(5, max(2, level.id / 3 + 1))).map { index in
                PuzzleBarrier(center: [index.isMultiple(of: 2) ? -1.35 : 1.35, 1.8 - Float(index) * zigzagSpacing], size: [half * 1.05, 0.24])
            }
            return makeGeometry(
                key: nil,
                door: nil,
                barriers: zigzag,
                cells: cells,
                dock: [margin, -margin],
                hackTerminal: nil
            )
        }
        let horizontal = ![2, 6, 8, 12, 14].contains(level.id)
        if horizontal {
            let door = PuzzleBarrier(center: [level.id.isMultiple(of: 3) ? -1.45 : 0.65, 0.35], size: [doorwayWidth, 0.24])
            let left = door.center.x - door.size.x / 2
            let right = door.center.x + door.size.x / 2
            let walls = [
                PuzzleBarrier(center: [(-half + left) / 2, door.center.y], size: [left + half, 0.24]),
                PuzzleBarrier(center: [(right + half) / 2, door.center.y], size: [half - right, 0.24]),
                PuzzleBarrier(center: [level.id.isMultiple(of: 2) ? -2.1 : 2.1, -2.2], size: [0.24, 2.7]),
            ]
            return makeGeometry(
                key: [level.id.isMultiple(of: 3) ? margin : -margin, margin],
                door: door,
                barriers: walls,
                cells: cells,
                dock: [margin, -margin],
                hackTerminal: [door.center.x, door.center.y + 0.85]
            )
        }
        let door = PuzzleBarrier(center: [0.45, -0.45], size: [0.24, doorwayWidth])
        let near = door.center.y - door.size.y / 2
        let far = door.center.y + door.size.y / 2
        let walls = [
            PuzzleBarrier(center: [door.center.x, (-half + near) / 2], size: [0.24, near + half]),
            PuzzleBarrier(center: [door.center.x, (far + half) / 2], size: [0.24, half - far]),
            PuzzleBarrier(center: [-2.0, -2.2], size: [2.8, 0.24]),
        ]
        let key: SIMD2<Float> = level.id == 2 ? [-2.6, 2.8] : [-margin, margin]
        let cellMinimumX = door.center.x + door.size.x / 2 + robotCollisionRadius + 0.25
        let adjustedCells = cells.map { cell in
            let horizontalProgress = (cell.x + margin) / (margin * 2)
            return SIMD2<Float>(cellMinimumX + (margin - cellMinimumX) * horizontalProgress, cell.y)
        }
        return makeGeometry(
            key: key,
            door: door,
            barriers: walls,
            cells: adjustedCells,
            dock: [margin, -margin],
            hackTerminal: [door.center.x - 0.85, door.center.y]
        )
    }

    private static func environmentalGeometry(
        for level: ROBLevel,
        margin: Float
    ) -> (conveyors: [PuzzleConveyor], cameras: [PuzzleSecurityCamera], shadows: [PuzzleBarrier]) {
        let conveyorDirection: SIMD2<Float> = level.id.isMultiple(of: 2) ? [1, 0] : [0, -1]
        let conveyors = level.id >= 2 ? [
            PuzzleConveyor(
                id: 0,
                center: [level.id.isMultiple(of: 2) ? -1.75 : 1.75, level.id.isMultiple(of: 3) ? -1.25 : 1.45],
                size: conveyorDirection.x == 0 ? [1.15, 2.35] : [2.35, 1.15],
                direction: conveyorDirection,
                speed: min(0.62, 0.26 + Float(level.id) * 0.022)
            ),
        ] : []

        guard level.id >= 3 else { return (conveyors, [], []) }
        let firstPosition = SIMD2<Float>(level.id.isMultiple(of: 2) ? -margin + 0.75 : margin - 0.75, -0.9)
        let firstTarget = SIMD2<Float>(0, 0.6)
        let firstHeading = atan2(-(firstTarget.x - firstPosition.x), -(firstTarget.y - firstPosition.y))
        var cameras = [PuzzleSecurityCamera(id: 0, position: firstPosition, heading: firstHeading, sweep: 0.7, range: 5.7)]
        var shadows = [PuzzleBarrier(center: [-firstPosition.x * 0.36, 2.65], size: [2.1, 1.25])]
        if level.id >= 8 {
            let secondPosition = SIMD2<Float>(-firstPosition.x, -2.8)
            let secondHeading = atan2(-(-0.35 - secondPosition.x), -(0.5 - secondPosition.y))
            cameras.append(PuzzleSecurityCamera(id: 1, position: secondPosition, heading: secondHeading, sweep: 0.55, range: 5.3))
            shadows.append(PuzzleBarrier(center: [firstPosition.x * 0.28, -1.65], size: [1.8, 1.1]))
        }
        return (conveyors, cameras, shadows)
    }

    private func report(_ situation: String) { lastSituation = situation; situationCount += 1 }
    private func awardMissionPoints(_ points: Int) {
        guard points > 0 else { return }
        score += points
        upgradePoints += points
        progressStore?.set(upgradePoints, forKey: "robUpgradePoints")
    }
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
            let bossTier = level.id / 5
            let shields = isBoss ? 15 + bossTier * 15 : level.enemyShields
            return TrainingEnemy(id: index, kind: kind, isBoss: isBoss, isMiniBoss: false, position: origin, origin: origin, shields: shields, maxShields: shields, nextAttack: 1.6 + Double(index) * 0.65, nextSkitterSound: 0.8 + Double(index) * 0.38)
        }
    }
    private func configureLevel() {
        isUpgradeIntermission = false
        elapsed = 0; collectedCells = 0
        hasKey = false; doorOpen = !level.requiresKey; isHackingDoor = false; hackingProgress = 0; securityAlertRemaining = 0
        collectedCellIndices = []; collectedShieldPickupIndices = []; collectedRepairPickupIndices = []
        saberAnimation = 0; saberStyle = nil; saberComboCount = 0; lastSaberAttackTime = -.infinity
        laserProjectiles = []; laserCharge = 0; laserShotCharge = 0; isChargingLaser = false; lockedEnemyID = nil; secondaryLockedEnemyID = nil
        forwardDemand = 0; steeringDemand = 0; leftTread = 0; rightTread = 0
        energy = maxEnergy; wasEnergyDepleted = false
        let layout = puzzle
        let startingX: Float
        if let door = layout.door, door.size.x < door.size.y {
            startingX = door.center.x - door.size.x / 2 - Self.robotCollisionRadius - 0.35
        } else {
            startingX = 0
        }
        robotPosition = SIMD3<Float>(startingX, 0, layout.arenaHalfExtent - 0.8); robotHeading = 0; leftWheelAngle = 0; rightWheelAngle = 0
        enemyBolts = []; nextBoltID = 0; wasAtDock = false; enemies = configuredEnemies()
        updateLaserLock()
    }
    func begin() {
        if isUpgradeIntermission {
            continueAfterUpgradeIntermission()
            return
        }
        enemyAttackCount = 0
        health = maxHealth
        shields = maxShields
        damageInvulnerabilityRemaining = 0
        configureLevel()
        isPaused = false
        isRunning = true
        if audioEnabled && musicEnabled { TechnoMusicEngine.shared.start(level: levelIndex) }
        message = "Level \(level.id): \(level.challenge)"
        report("The pilot started \(level.name). \(level.challenge)")
        play("mission-start")
    }
    @discardableResult
    func pause() -> Bool {
        guard isRunning else { return false }
        stopDrive()
        isChargingLaser = false
        laserCharge = 0
        isRunning = false
        isPaused = true
        if audioEnabled { TechnoMusicEngine.shared.stop() }
        message = "Mission paused at Level \(level.id)."
        return true
    }
    @discardableResult
    func resume() -> Bool {
        guard isPaused else { return false }
        isPaused = false
        isRunning = true
        if audioEnabled && musicEnabled { TechnoMusicEngine.shared.start(level: levelIndex) }
        message = "Level \(level.id) resumed."
        return true
    }
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
        guard !isPaused else { return }
        guard isRunning else { begin(); return }
        setDrive(forward: forward, steering: steering)
        tick(0.24)
        stopDrive()
    }
    func tick(_ delta: TimeInterval) {
        guard isRunning else { return }
        elapsed += delta
        damageInvulnerabilityRemaining = max(0, damageInvulnerabilityRemaining - delta)
        securityAlertRemaining = max(0, securityAlertRemaining - delta)
        let hasDriveEnergy = energy > 0.05
        let targetLeft = hasDriveEnergy ? max(-1, min(1, forwardDemand - steeringDemand * 0.72)) : 0
        let targetRight = hasDriveEnergy ? max(-1, min(1, forwardDemand + steeringDemand * 0.72)) : 0
        let smoothing = min(1, delta * 8)
        leftTread += (targetLeft - leftTread) * smoothing; rightTread += (targetRight - rightTread) * smoothing
        let linear = Float((leftTread + rightTread) * 0.5) * Float(delta) * 0.85 * Float(driveSpeedMultiplier)
        leftWheelAngle -= Float(leftTread) * Float(delta) * 4.8; rightWheelAngle -= Float(rightTread) * Float(delta) * 4.8
        robotHeading += Float(rightTread - leftTread) * Float(delta) * 1.05
        let oldPosition = robotPosition
        let proposedPosition = SIMD3<Float>(
            robotPosition.x - sin(robotHeading) * linear,
            robotPosition.y,
            robotPosition.z - cos(robotHeading) * linear
        )
        let resolvedPosition = resolveRobotMovement(from: oldPosition, to: proposedPosition)
        robotPosition = resolvedPosition
        let movementWasLimited = simd_distance(resolvedPosition, proposedPosition) > 0.000_1
        if movementWasLimited {
            let blockedByDoor = !doorOpen && puzzle.door.map {
                Self.segmentHitFraction(
                    from: SIMD2<Float>(oldPosition.x, oldPosition.z),
                    to: SIMD2<Float>(proposedPosition.x, proposedPosition.z),
                    barrier: $0,
                    padding: Self.robotCollisionRadius
                ) != nil
            } == true
            let slidAlongWall = simd_distance(oldPosition, resolvedPosition) > 0.000_1
            message = blockedByDoor
                ? (hasKey ? "Use the orange hack panel beside the door." : "Route blocked. Find the access key before hacking the doorway.")
                : slidAlongWall
                    ? "Wall assist active — ROB is sliding along the open edge. Steer away when clear."
                    : "Wall contact — reverse or pivot away; ROB will release instead of staying trapped."
        }
        let driveLoad = (abs(leftTread) + abs(rightTread)) * 0.5
        if hasDriveEnergy && driveLoad > 0.01 {
            energy = max(0, energy - delta * (4.4 + driveLoad * 2.2))
        } else if !isHackingDoor {
            energy = min(maxEnergy, energy + delta * (3.2 + Double(energyUpgradeLevel) * 0.8))
        }
        if energy <= 0.05, !wasEnergyDepleted {
            wasEnergyDepleted = true
            message = "System energy empty. Hold position briefly while ROB recharges before driving or firing."
            report(message)
        } else if energy > maxEnergy * 0.12 {
            wasEnergyDepleted = false
        }
        applyConveyor(delta)
        resolveSpatialObjectives()
        updateDoorHack(delta)
        updateSecurityCameras()
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
        updateLaserProjectiles(delta)
        updateEnemies(delta)
        updateLaserLock()
    }

    private func applyConveyor(_ delta: TimeInterval) {
        let point = SIMD2<Float>(robotPosition.x, robotPosition.z)
        guard let conveyor = puzzle.conveyors.first(where: {
            abs(point.x - $0.center.x) <= $0.size.x / 2 && abs(point.y - $0.center.y) <= $0.size.y / 2
        }) else { return }
        let end = robotPosition + SIMD3<Float>(conveyor.direction.x, 0, conveyor.direction.y) * conveyor.speed * Float(delta)
        if isRobotMoveClear(from: robotPosition, to: end) { robotPosition = end }
    }

    func securityCameraHeading(_ camera: PuzzleSecurityCamera) -> Float {
        camera.heading + sin(Float(elapsed) * 0.72 + Float(camera.id) * 1.7) * camera.sweep
    }

    static func securityCameraSightDistance(
        camera: PuzzleSecurityCamera,
        heading: Float,
        angleOffset: Float = 0,
        blockers: [PuzzleBarrier]
    ) -> Float {
        let rayHeading = heading + angleOffset
        let end = camera.position + SIMD2<Float>(-sin(rayHeading), -cos(rayHeading)) * camera.range
        let nearestFraction = blockers.compactMap {
            segmentHitFraction(from: camera.position, to: end, barrier: $0, padding: 0.015)
        }.min() ?? 1
        return camera.range * nearestFraction
    }

    static func securityCameraVisionDistances(
        camera: PuzzleSecurityCamera,
        heading: Float,
        blockers: [PuzzleBarrier],
        rayCount: Int = 49
    ) -> [Float] {
        let count = max(2, rayCount)
        return (0..<count).map { index in
            let angleOffset = -securityCameraHalfAngle
                + securityCameraHalfAngle * 2 * Float(index) / Float(count - 1)
            return securityCameraSightDistance(
                camera: camera,
                heading: heading,
                angleOffset: angleOffset,
                blockers: blockers
            )
        }
    }

    func securityCameraVisionDistances(
        for camera: PuzzleSecurityCamera,
        rayCount: Int = 49
    ) -> [Float] {
        Self.securityCameraVisionDistances(
            camera: camera,
            heading: securityCameraHeading(camera),
            blockers: projectileBlockers,
            rayCount: rayCount
        )
    }

    static func securityCameraCanSee(
        _ point: SIMD2<Float>,
        camera: PuzzleSecurityCamera,
        heading: Float,
        blockers: [PuzzleBarrier]
    ) -> Bool {
        let offset = point - camera.position
        let distance = simd_length(offset)
        guard distance > 0.001, distance <= camera.range else { return false }
        let forward = SIMD2<Float>(-sin(heading), -cos(heading))
        guard simd_dot(offset / distance, forward) >= cos(securityCameraHalfAngle) else { return false }
        let targetHeading = atan2(-offset.x, -offset.y)
        return distance <= securityCameraSightDistance(
            camera: camera,
            heading: heading,
            angleOffset: targetHeading - heading,
            blockers: blockers
        ) + 0.001
    }

    func securityCameraCanSee(_ point: SIMD2<Float>, camera: PuzzleSecurityCamera) -> Bool {
        Self.securityCameraCanSee(
            point,
            camera: camera,
            heading: securityCameraHeading(camera),
            blockers: projectileBlockers
        )
    }

    private func updateSecurityCameras() {
        guard !isInShadow else { return }
        let point = SIMD2<Float>(robotPosition.x, robotPosition.z)
        let detectingCamera = puzzle.securityCameras.first { securityCameraCanSee(point, camera: $0) }
        if let detectingCamera {
            let wasAlerted = isSecurityAlerted
            securityAlertRemaining = 5
            if !wasAlerted {
                if !enemies.contains(where: { $0.isMiniBoss }) {
                    releaseSecurityMiniBoss(from: detectingCamera)
                } else {
                    message = "Security camera spotted ROB again! Break line of sight in a shadow zone."
                }
                report(message)
            }
        }
    }

    private func releaseSecurityMiniBoss(from camera: PuzzleSecurityCamera?) {
        guard let camera else { return }
        let margin = puzzle.arenaHalfExtent - 0.85
        let preferred = SIMD3<Float>(-camera.position.x * 0.78, 0, -camera.position.y * 0.78)
        let candidates: [SIMD3<Float>] = [
            preferred, [-margin, 0, -margin], [margin, 0, -margin], [-margin, 0, margin * 0.2], [margin, 0, margin * 0.2],
        ]
        let blockers = puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
        let origin = candidates.first(where: { candidate in
            simd_distance(SIMD2<Float>(candidate.x, candidate.z), SIMD2<Float>(robotPosition.x, robotPosition.z)) > 2.4
                && !blockers.contains(where: { Self.intersects(candidate, barrier: $0, radius: 0.34) })
        }) ?? preferred
        let id = (enemies.map(\.id).max() ?? -1) + 1
        enemies.append(TrainingEnemy(
            id: id,
            kind: .spider,
            isBoss: true,
            isMiniBoss: true,
            position: origin,
            origin: origin,
            shields: 3,
            maxShields: 3,
            nextAttack: elapsed + 1.8,
            nextSkitterSound: elapsed + 0.5
        ))
        message = "Security camera caught ROB! A three-shield mini boss has been released — disable it or escape into shadow."
    }

    private func updateDoorHack(_ delta: TimeInterval) {
        guard isHackingDoor else { return }
        guard isNearHackTerminal else {
            isHackingDoor = false; hackingProgress = 0
            message = "Hack interrupted. Move back beside the orange panel."
            report(message)
            return
        }
        hackingProgress = min(1, hackingProgress + delta / 2.2)
        guard hackingProgress >= 1 else { return }
        isHackingDoor = false; doorOpen = true
        awardMissionPoints(300)
        message = "Flipper Zero hack complete. Security lock bypassed and door open."
        report(message)
        play("pickup")
    }
    private static func intersects(_ position: SIMD3<Float>, barrier: PuzzleBarrier, radius: Float = 0.32) -> Bool {
        abs(position.x - barrier.center.x) < barrier.size.x / 2 + radius && abs(position.z - barrier.center.y) < barrier.size.y / 2 + radius
    }
    private var robotMovementBlockers: [PuzzleBarrier] {
        puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
    }
    func isRobotPositionClear(_ position: SIMD3<Float>) -> Bool {
        let wallInset: Float = 0.09 + Self.robotCollisionRadius
        let movementLimit = puzzle.arenaHalfExtent - wallInset
        guard abs(position.x) <= movementLimit, abs(position.z) <= movementLimit else { return false }
        return !robotMovementBlockers.contains { Self.intersects(position, barrier: $0, radius: Self.robotCollisionRadius) }
    }
    private func resolveRobotMovement(from start: SIMD3<Float>, to end: SIMD3<Float>) -> SIMD3<Float> {
        if isRobotMoveClear(from: start, to: end) { return end }
        let delta = end - start
        let axisOrder = abs(delta.x) >= abs(delta.z) ? [0, 2] : [2, 0]
        var resolved = start

        for axis in axisOrder {
            var axisTarget = resolved
            axisTarget[axis] = end[axis]
            resolved = furthestClearRobotPosition(from: resolved, to: axisTarget)
        }
        return resolved
    }
    private func furthestClearRobotPosition(from start: SIMD3<Float>, to end: SIMD3<Float>) -> SIMD3<Float> {
        if isRobotMoveClear(from: start, to: end) { return end }
        guard simd_distance_squared(start, end) > 0.000_000_1 else { return start }
        var clearFraction: Float = 0
        var blockedFraction: Float = 1
        for _ in 0..<10 {
            let candidateFraction = (clearFraction + blockedFraction) * 0.5
            let candidate = start + (end - start) * candidateFraction
            if isRobotMoveClear(from: start, to: candidate) {
                clearFraction = candidateFraction
            } else {
                blockedFraction = candidateFraction
            }
        }
        return clearFraction > 0.001 ? start + (end - start) * clearFraction : start
    }
    private func isRobotMoveClear(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Bool {
        guard isRobotPositionClear(end) else { return false }
        let start2D = SIMD2<Float>(start.x, start.z)
        let end2D = SIMD2<Float>(end.x, end.z)
        return !robotMovementBlockers.contains { blocker in
            guard Self.segmentHitFraction(from: start2D, to: end2D, barrier: blocker, padding: Self.robotCollisionRadius) != nil else { return false }
            return !Self.motionStaysOutsideContactFace(
                from: start2D,
                to: end2D,
                barrier: blocker,
                padding: Self.robotCollisionRadius
            )
        }
    }
    private static func motionStaysOutsideContactFace(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        barrier: PuzzleBarrier,
        padding: Float
    ) -> Bool {
        let minimum = barrier.center - barrier.size / 2 - SIMD2<Float>(repeating: padding)
        let maximum = barrier.center + barrier.size / 2 + SIMD2<Float>(repeating: padding)
        let tolerance: Float = 0.000_5
        if abs(start.x - minimum.x) <= tolerance, end.x <= minimum.x + tolerance { return true }
        if abs(start.x - maximum.x) <= tolerance, end.x >= maximum.x - tolerance { return true }
        if abs(start.y - minimum.y) <= tolerance, end.y <= minimum.y + tolerance { return true }
        if abs(start.y - maximum.y) <= tolerance, end.y >= maximum.y - tolerance { return true }
        return false
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
    private static func distance(from point: SIMD2<Float>, to barrier: PuzzleBarrier) -> Float {
        let minimum = barrier.center - barrier.size / 2
        let maximum = barrier.center + barrier.size / 2
        let offset = SIMD2<Float>(
            max(max(minimum.x - point.x, 0), point.x - maximum.x),
            max(max(minimum.y - point.y, 0), point.y - maximum.y)
        )
        return simd_length(offset)
    }
    private func meleePathIsClear(to target: SIMD2<Float>, padding: Float) -> Bool {
        let origin = SIMD2<Float>(robotPosition.x, robotPosition.z)
        return !projectileBlockers.contains { blocker in
            Self.segmentHitFraction(from: origin, to: target, barrier: blocker, padding: padding) != nil
        }
    }
    private func meleeAnimationIsClear(style: SaberAttackStyle) -> Bool {
        let origin = SIMD2<Float>(robotPosition.x, robotPosition.z)
        if style == .spin {
            return !projectileBlockers.contains { Self.distance(from: origin, to: $0) <= 2.15 }
        }
        let forward = SIMD2<Float>(-sin(robotHeading), -cos(robotHeading))
        let reach: Float = style == .hammerSmash ? 2.05 : 1.55
        let padding: Float = style == .hammerSmash ? 0.38 : 0.5
        return meleePathIsClear(to: origin + forward * reach, padding: padding)
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
    private func updateLaserProjectiles(_ delta: TimeInterval) {
        guard !laserProjectiles.isEmpty else { return }
        let maximumDistance = puzzle.arenaHalfExtent * 2.2
        var survivors: [ROBLaserProjectile] = []

        enum Impact {
            case barrier
            case enemy(Int)
        }

        for var projectile in laserProjectiles {
            let nextDistance = min(
                maximumDistance,
                projectile.distance + Float(delta) * (projectile.weapon.projectileSpeed + Float(projectile.charge) * 3.5)
            )
            let direction = SIMD2<Float>(-sin(projectile.heading), -cos(projectile.heading))
            let start = projectile.origin + direction * projectile.distance
            let end = projectile.origin + direction * nextDistance
            var nearestImpact: (fraction: Float, impact: Impact)?

            for blocker in projectileBlockers {
                guard let fraction = Self.segmentHitFraction(from: start, to: end, barrier: blocker, padding: 0.07) else { continue }
                if nearestImpact.map({ fraction < $0.fraction }) ?? true {
                    nearestImpact = (fraction, .barrier)
                }
            }
            for index in enemies.indices where enemies[index].isActive {
                let enemy = enemies[index]
                let radius: Float = (enemy.kind == .spider ? 0.34 : 0.4) * enemy.combatScale
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
                switch nearestImpact.impact {
                case .barrier:
                    message = "\(projectile.weapon.displayName) struck the wall. Reposition for a clear shot."
                    report(message)
                case let .enemy(index):
                    let damage = projectile.weapon.damage(charge: projectile.charge)
                    let secondaryTargets = projectile.weapon == .arcCannon ? enemies.indices.filter { candidate in
                        candidate != index && enemies[candidate].isActive && simd_distance(enemies[candidate].position, enemies[index].position) <= 1.45
                    } : []
                    damageEnemy(
                        at: index,
                        weapon: projectile.charge > 0.72 ? "charged \(projectile.weapon.displayName.lowercased())" : projectile.weapon.displayName.lowercased(),
                        amount: damage
                    )
                    if let secondary = secondaryTargets.first {
                        damageEnemy(at: secondary, weapon: "arc cannon chain", amount: max(1, damage / 2))
                    }
                }
            } else if nextDistance < maximumDistance {
                projectile.distance = nextDistance
                survivors.append(projectile)
            }
        }
        laserProjectiles = survivors
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
            if enemy.kind == .spider && (distance < 6.4 || isSecurityAlerted) {
                target = robotPosition; speed = 0.34 + Float(levelIndex) * 0.018 + (isSecurityAlerted ? 0.12 : 0)
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
                if distance > 2.8 || isSecurityAlerted { target = robotPosition }
                else if distance < 1.65, distance > 0.001 { target = enemy.position - simd_normalize(toRobot) }
                else if distance > 0.001 { let tangent = SIMD3<Float>(-toRobot.z, 0, toRobot.x) / distance; target = enemy.position + tangent * (index.isMultiple(of: 2) ? 0.6 : -0.6) }
                speed = 0.24 + Float(levelIndex) * 0.015 + (isSecurityAlerted ? 0.1 : 0)
                if elapsed >= enemy.nextAttack && distance < (isSecurityAlerted ? 9.2 : 7.5) {
                    let alertDelay = isSecurityAlerted ? 0.65 : 0
                    enemy.nextAttack = elapsed + max(1.35, 3.65 - Double(levelIndex) * 0.09 - alertDelay); enemyAttackCount += 1; fireEnemyBolt(from: enemy)
                    playEnemyAttack(.fax); message = "Dalek-style sentry robot: “Exterminate!” Incoming laser — keep moving."; report(message)
                }
            }
            let facing = robotPosition - enemy.position; enemy.heading = atan2(-facing.x, -facing.z)
            moveEnemy(&enemy, toward: target, speed: speed, delta: delta); enemies[index] = enemy
            let contactRadius: Float = (enemy.kind == .spider ? 0.5 : 0.44) * enemy.combatScale
            if simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(enemy.position.x, enemy.position.z)) < contactRadius {
                if enemy.kind == .spider { playSpider(.impact) } else { playEnemyAttack(.fax) }
                if enemyContact(enemy.kind == .spider ? "\(enemy.displayName) lunge" : "\(enemy.displayName) collision", damage: enemy.contactDamage) { return }
            }
        }
        var survivingBolts: [TrainingEnemyBolt] = []
        let blockers = puzzle.barriers + ((!doorOpen && puzzle.door != nil) ? [puzzle.door!] : [])
        for var bolt in enemyBolts {
            let start = SIMD2<Float>(bolt.position.x, bolt.position.z)
            bolt.position += bolt.velocity * Float(delta)
            let end = SIMD2<Float>(bolt.position.x, bolt.position.z)
            let wallImpact = blockers.compactMap {
                Self.segmentHitFraction(from: start, to: end, barrier: $0, padding: 0.04)
            }.min()
            let robotImpact = Self.segmentHitFraction(
                from: start,
                to: end,
                center: [robotPosition.x, robotPosition.z],
                radius: 0.32
            )
            if let robotImpact, wallImpact.map({ robotImpact < $0 }) ?? true {
                playEnemyAttack(.fax)
                enemyBolts = survivingBolts
                enemyContact(bolt.sourceName, damage: bolt.damage)
                return
            }
            if wallImpact != nil { continue }
            let outside = abs(bolt.position.x) > puzzle.arenaHalfExtent || abs(bolt.position.z) > puzzle.arenaHalfExtent
            if !outside { survivingBolts.append(bolt) }
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
        for (index, cell) in puzzle.cells.enumerated() where !collectedCellIndices.contains(index) && simd_distance(point, cell) < 0.45 {
            collectedCellIndices.insert(index); collectCell()
        }
        for (index, pickup) in puzzle.shieldPickups.enumerated()
            where shields < maxShields && !collectedShieldPickupIndices.contains(index) && simd_distance(point, pickup) < 0.48 {
            collectedShieldPickupIndices.insert(index); collectShieldPickup()
        }
        for (index, pickup) in puzzle.repairPickups.enumerated()
            where health < maxHealth && !collectedRepairPickupIndices.contains(index) && simd_distance(point, pickup) < 0.48 {
            collectedRepairPickupIndices.insert(index); collectRepairPickup()
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
        else if level.requiresKey && !doorOpen { requirements.append("hack the security door") }
        let cellsLeft = level.cellCount - collectedCells
        if cellsLeft > 0 { requirements.append("collect \(cellsLeft) more energy \(cellsLeft == 1 ? "cell" : "cells")") }
        if remainingEnemies > 0 { requirements.append("disable \(remainingEnemies) more \(remainingEnemies == 1 ? "target" : "targets")") }
        return requirements.joined(separator: " and ")
    }
    private func updateLaserLock() {
        let maxRange = puzzle.arenaHalfExtent * 1.75
        let candidates = enemies.indices.compactMap { index -> (id: Int, distance: Float)? in
            guard enemies[index].isActive else { return nil }
            let distance = simd_distance(SIMD2<Float>(robotPosition.x, robotPosition.z), SIMD2<Float>(enemies[index].position.x, enemies[index].position.z))
            return distance <= maxRange ? (enemies[index].id, distance) : nil
        }.sorted(by: { $0.distance < $1.distance })
        lockedEnemyID = candidates.first?.id
        secondaryLockedEnemyID = rangedWeapon == .twinBlasters && hasIndependentTwinTargeting
            ? candidates.dropFirst().first?.id
            : nil
    }
    private func damageEnemy(at index: Int, weapon: String, amount: Int = 1) {
        guard enemies.indices.contains(index), enemies[index].isActive else { return }
        let appliedDamage = amount + weaponDamageBonus
        enemies[index].shields -= appliedDamage
        awardMissionPoints(50 * appliedDamage)
        if enemies[index].kind == .spider { playSpider(enemies[index].shields <= 0 ? .shutdown : .impact) }
        if enemies[index].shields <= 0 {
            let kind = enemies[index].kind, name = enemies[index].displayName, reward = enemies[index].defeatReward
            enemies[index].isActive = false
            awardMissionPoints(reward)
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
        guard isRunning, laserProjectiles.isEmpty, !isChargingLaser else { return }
        let minimumEnergy = rangedWeapon.energyCost(charge: 0)
        guard energy >= minimumEnergy else {
            message = "Not enough system energy for the \(rangedWeapon.displayName). Hold position or collect an energy cell."
            report(message)
            return
        }
        laserCharge = 0; isChargingLaser = true; message = lockedEnemy == nil ? "\(rangedWeapon.displayName) scanning — no target lock yet." : "\(rangedWeapon.displayName) charging on locked target…"
    }
    func releaseLaserCharge() {
        guard isChargingLaser else { return }
        let charge = laserCharge; isChargingLaser = false; laserCharge = 0
        fireLaser(charge: charge)
    }
    private func fireLaser(charge: Double) {
        guard isRunning, laserProjectiles.isEmpty else { return }
        updateLaserLock()
        guard let targetID = lockedEnemyID, let primaryTarget = enemies.first(where: { $0.id == targetID && $0.isActive }) else {
            message = "\(rangedWeapon.displayName) is still scanning. Turn or move closer until the lock indicator turns red."; report(message); return
        }
        let clampedCharge = min(1, max(0, charge))
        let energyCost = rangedWeapon.energyCost(charge: clampedCharge)
        guard energy >= energyCost else {
            message = "\(rangedWeapon.displayName) needs \(Int(ceil(energyCost))) system energy. Hold position or collect an energy cell."
            report(message)
            return
        }
        energy -= energyCost
        let robotOrigin = SIMD2<Float>(robotPosition.x, robotPosition.z)
        let forward = SIMD2<Float>(-sin(robotHeading), -cos(robotHeading))
        let right = SIMD2<Float>(cos(robotHeading), -sin(robotHeading))
        func projectile(barrel: ROBLaserBarrel, lateralOffset: Float, target: TrainingEnemy) -> ROBLaserProjectile {
            let origin = robotOrigin + forward * 0.28 + right * lateralOffset
            let heading = atan2(-(target.position.x - origin.x), -(target.position.z - origin.y))
            return ROBLaserProjectile(
                barrel: barrel,
                weapon: rangedWeapon,
                charge: clampedCharge,
                targetID: target.id,
                origin: origin,
                heading: heading,
                distance: 0.55
            )
        }
        if rangedWeapon == .twinBlasters {
            let secondaryTarget = secondaryLockedEnemy ?? primaryTarget
            laserProjectiles = [
                projectile(barrel: .left, lateralOffset: -0.47, target: primaryTarget),
                projectile(barrel: .right, lateralOffset: 0.47, target: secondaryTarget),
            ]
        } else {
            laserProjectiles = [projectile(barrel: .center, lateralOffset: 0, target: primaryTarget)]
        }
        laserShotCharge = clampedCharge
        if rangedWeapon == .twinBlasters, let secondary = secondaryLockedEnemy {
            message = "Twin Blasters fired two independent beams at \(primaryTarget.displayName) and \(secondary.displayName) for \(Int(ceil(energyCost))) energy."
        } else if rangedWeapon == .twinBlasters {
            message = "Twin Blasters fired both beams at \(primaryTarget.displayName) for \(Int(ceil(energyCost))) energy."
        } else {
            message = "\(rangedWeapon.displayName) fired for \(Int(ceil(energyCost))) energy."
        }
        report(message)
        if audioEnabled { SoundPlayer.shared.playLaser(charge: clampedCharge) }
    }
    func saberAttack() {
        guard isRunning else { return }
        if meleeWeapon == .powerHammer {
            guard meleeAnimationIsClear(style: .hammerSmash) else {
                saberAnimation = 0; saberStyle = nil; saberComboCount = 0
                message = "Power hammer blocked by the wall. Back up before swinging."; report(message)
                return
            }
            saberComboCount = 0; lastSaberAttackTime = elapsed; saberAnimation = 1; saberStyle = .hammerSmash
            let forward = SIMD2<Float>(-sin(robotHeading), -cos(robotHeading))
            let hitIndices = enemies.indices.filter { index in
                guard enemies[index].isActive else { return false }
                let offset = SIMD2<Float>(enemies[index].position.x - robotPosition.x, enemies[index].position.z - robotPosition.z)
                let target = SIMD2<Float>(enemies[index].position.x, enemies[index].position.z)
                return simd_length(offset) <= 2.05 && simd_dot(offset, forward) > 0.08 && meleePathIsClear(to: target, padding: 0.08)
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
        let nextComboCount = elapsed - lastSaberAttackTime <= 1.15 ? saberComboCount + 1 : 1
        let spin = nextComboCount >= 3
        let nextStyle: SaberAttackStyle = spin ? .spin : (nextComboCount == 1 ? .leftSweep : .rightSweep)
        guard meleeAnimationIsClear(style: nextStyle) else {
            saberAnimation = 0; saberStyle = nil; saberComboCount = 0
            message = "Saber swing blocked by the wall. Back up before attacking."; report(message)
            return
        }
        saberComboCount = nextComboCount
        lastSaberAttackTime = elapsed; saberAnimation = 1
        saberStyle = nextStyle
        if spin { saberComboCount = 0 }
        let forward = SIMD2<Float>(-sin(robotHeading), -cos(robotHeading))
        let hitIndices = enemies.indices.filter { index in
            guard enemies[index].isActive else { return false }
            let offset = SIMD2<Float>(enemies[index].position.x - robotPosition.x, enemies[index].position.z - robotPosition.z)
            let distance = simd_length(offset)
            let target = SIMD2<Float>(enemies[index].position.x, enemies[index].position.z)
            return distance <= (spin ? 2.15 : 1.55) && (spin || simd_dot(offset, forward) > -0.12) && meleePathIsClear(to: target, padding: 0.08)
        }
        if hitIndices.isEmpty { message = spin ? "Spin attack cleared space but missed every target." : "Wide saber swing missed. Move within arm range."; report(message) }
        else {
            for index in hitIndices { damageEnemy(at: index, weapon: spin ? "dual-saber spin" : "dual-saber sweep") }
            if spin { message = "Spin attack! ROB extended both sabers and struck \(hitIndices.count) targets."; report(message) }
        }
        play("laser")
    }
    func collectCell() {
        guard isRunning, collectedCells < level.cellCount else { return }
        collectedCells += 1
        energy = min(maxEnergy, energy + 32)
        awardMissionPoints(150)
        message = "Energy cell \(collectedCells) of \(level.cellCount). Battery recharged."
        report(message); play("pickup")
    }
    @discardableResult
    func collectShieldPickup() -> Bool {
        guard isRunning, shields < maxShields else { return false }
        let restored = min(shieldPickupStrength, maxShields - shields)
        shields += restored
        awardMissionPoints(100)
        message = "Shield capacitor restored \(restored) points. ROB shields: \(shields)/\(maxShields)."
        report(message); play("pickup")
        return true
    }
    @discardableResult
    func collectRepairPickup() -> Bool {
        guard isRunning, health < maxHealth else { return false }
        let repaired = min(repairPickupStrength, maxHealth - health)
        health += repaired
        awardMissionPoints(100)
        message = "Repair kit restored \(repaired) hull points. ROB health: \(health)/\(maxHealth)."
        report(message); play("pickup")
        return true
    }
    func collectKey() {
        guard isRunning, level.requiresKey, !hasKey else { return }
        hasKey = true
        awardMissionPoints(250)
        message = "Access key secured. Reach the orange panel and start the Flipper Zero hack."
        report(message); play("pickup")
    }
    func startDoorHack() {
        guard isRunning, level.requiresKey, !doorOpen, !isHackingDoor else { return }
        guard hasKey else { message = "The security lock needs its access key before ROB can hack it."; report(message); return }
        guard isNearHackTerminal else { message = "Move ROB beside the orange hack panel first."; report(message); return }
        isHackingDoor = true; hackingProgress = 0
        stopDrive()
        message = "Flipper Zero connected. ROB is running the door hack automatically…"
        report(message)
    }
    func openDoor() { startDoorHack() }
    @discardableResult
    func enemyContact(_ attack: String = "Enemy contact", damage: Int = 5) -> Bool {
        guard isRunning, damageInvulnerabilityRemaining <= 0 else { return false }
        let appliedDamage = max(0, damage)
        let absorbedDamage = min(shields, appliedDamage)
        shields -= absorbedDamage
        let hullDamage = appliedDamage - absorbedDamage
        health = max(0, health - hullDamage)
        score = max(0, score - appliedDamage * 20)
        damageInvulnerabilityRemaining = 0.75
        if health == 0 {
            configureLevel()
            health = maxHealth
            shields = maxShields
            damageInvulnerabilityRemaining = 1
            isPaused = false
            isRunning = true
            message = "ROB was disabled by \(attack). Restarting level \(level.id) with full health."
        } else if hullDamage > 0, absorbedDamage > 0 {
            message = "\(attack) broke ROB’s shield and dealt \(hullDamage) hull damage. Health: \(health)/\(maxHealth)."
        } else if absorbedDamage > 0 {
            message = "\(attack) drained \(absorbedDamage) shield points. ROB shields: \(shields)/\(maxShields)."
        } else {
            message = "\(attack) dealt \(hullDamage) hull damage. ROB health: \(health)/\(maxHealth)."
        }
        report(message)
        return true
    }
    func nextLevel() {
        guard !isUpgradeIntermission else {
            message = "Choose upgrades, then deploy to the next level."
            return
        }
        guard canFinish else { message = "Finish every objective before leaving the level."; return }
        let completedLevel = level.id
        awardMissionPoints(max(0, level.timeBonus - Int(elapsed) * 10))
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
            stopDrive()
            isPaused = false
            isRunning = false
            isUpgradeIntermission = true
            if audioEnabled { TechnoMusicEngine.shared.stop() }
            message = [reward, "Level \(completedLevel) cleared. Spend battle points before deploying to Level \(completedLevel + 1)."]
                .compactMap { $0 }
                .joined(separator: " ")
            report(message)
        } else {
            isPaused = false; isRunning = false; isUpgradeIntermission = false
            if audioEnabled { TechnoMusicEngine.shared.stop() }
            message = [reward, "Fifteen-level campaign complete!"].compactMap { $0 }.joined(separator: " ")
            report(message)
        }
        play("level-complete")
    }
    func continueAfterUpgradeIntermission() {
        guard isUpgradeIntermission, levelIndex < levels.count - 1 else { return }
        levelIndex += 1
        if audioEnabled { TechnoMusicEngine.shared.setLevel(levelIndex) }
        enemyAttackCount = 0
        health = maxHealth
        shields = maxShields
        damageInvulnerabilityRemaining = 0
        configureLevel()
        isPaused = false
        isRunning = true
        if audioEnabled && musicEnabled { TechnoMusicEngine.shared.start(level: levelIndex) }
        message = "Level \(level.id): \(level.challenge)"
        report("ROB deployed to \(level.name). \(level.challenge)")
        play("mission-start")
    }
    func reset() { levelIndex = 0; score = 0; health = maxHealth; shields = maxShields; damageInvulnerabilityRemaining = 0; enemyAttackCount = 0; configureLevel(); isPaused = false; isRunning = false; isUpgradeIntermission = false; if audioEnabled { TechnoMusicEngine.shared.stop() }; message = "ROB systems ready." }
}
