import XCTest
import RealityKit
import simd
@testable import ROB_Training

@MainActor final class ROBTacticalTests: XCTestCase {
    private func game(points: Int = 10_000, completed: Int = 10, installed: Bool = true) -> (GameSession, UserDefaults, String) {
        let name = "ROBTactical.\(UUID().uuidString)", store = UserDefaults(suiteName: name)!
        store.set(points, forKey: GameSession.skillPointsStorageKey)
        store.set(completed, forKey: "robHighestCompletedLevel")
        if installed { store.set(1, forKey: "robJammerUpgradeLevel"); store.set(1, forKey: "robGelBlasterUpgradeLevel") }
        let session = GameSession(audioEnabled: false, progressStore: store)
        session.begin(); session.enemies = []
        return (session, store, name)
    }
    func testPremiumCostsLocksAndPersistence() {
        let (g, store, name) = game(installed: false); defer { store.removePersistentDomain(forName: name) }
        g.purchaseUpgrade(.jammer); g.purchaseUpgrade(.gelBlaster)
        XCTAssertEqual(g.upgradePoints, 2_200); XCTAssertTrue(g.hasJammer); XCTAssertTrue(g.hasGelBlaster)
        g.purchaseUpgrade(.gelBlaster); XCTAssertEqual(g.upgradePoints, 2_200)
        let restored = GameSession(audioEnabled: false, progressStore: store)
        XCTAssertTrue(restored.hasJammer); XCTAssertTrue(restored.hasGelBlaster); XCTAssertFalse(restored.jammerActive)
        let (locked, defaults, suite) = game(completed: 0, installed: false); defer { defaults.removePersistentDomain(forName: suite) }
        locked.purchaseUpgrade(.jammer); locked.purchaseUpgrade(.gelBlaster)
        XCTAssertEqual(locked.upgradePoints, 10_000); XCTAssertFalse(locked.hasGelBlaster)
    }
    func testJammerDrainsWithoutIdleRechargeAndShutsDownOnDepletionOrPause() {
        let (g, store, name) = game(); defer { store.removePersistentDomain(forName: name) }
        g.toggleJammer()
        for _ in 0..<20 { g.tick(0.05) }
        XCTAssertEqual(g.energy, 86, accuracy: 0.01)
        for _ in 0..<123 { g.tick(0.05) }
        XCTAssertFalse(g.jammerActive); XCTAssertEqual(g.energy, 0, accuracy: 0.01)
        g.tick(0.05); XCTAssertGreaterThan(g.energy, 0)
        for _ in 0..<10 { g.tick(0.05) }
        g.toggleJammer(); XCTAssertTrue(g.jammerActive)
        g.pause(); XCTAssertFalse(g.jammerActive)
    }
    func testBasicRobotAndCameraSignalsAreJammedButBossesAndDistantTargetsResist() {
        let (g, store, name) = game(); defer { store.removePersistentDomain(forName: name) }
        let origin = g.robotPosition + SIMD3<Float>(1, 0, -1)
        var enemy = TrainingEnemy(id: 1, kind: .fax, isBoss: false, isMiniBoss: false, position: origin, origin: origin, shields: 8, maxShields: 8, nextAttack: 0)
        g.enemies = [enemy]; g.toggleJammer()
        XCTAssertTrue(g.isEnemyJammed(enemy)); XCTAssertTrue(g.isSignalJammed(at: origin))
        for _ in 0..<10 { g.tick(0.05) }
        XCTAssertEqual(g.enemies[0].position, origin); XCTAssertEqual(g.enemyAttackCount, 0)
        enemy.position = g.robotPosition + [5, 0, 0]; XCTAssertFalse(g.isEnemyJammed(enemy))
        XCTAssertFalse(ROBTacticalRules.jammed(active: true, origin: .zero, target: .zero, boss: true))
        XCTAssertFalse(ROBTacticalRules.jammed(active: true, origin: .zero, target: .zero, miniBoss: true))
        g.toggleJammer(); for _ in 0..<25 { g.tick(0.05) }; XCTAssertGreaterThan(g.enemyAttackCount, 0)
    }
    func testGelSpendsEnergyUsesFixedDamageAndCannotFireWhileHandsAreBusy() {
        let (g, store, name) = game(); defer { store.removePersistentDomain(forName: name) }
        g.toggleGelBlaster(); XCTAssertTrue(g.gelBlasterEquipped)
        let pose = g.tacticalMuzzlePose, position = pose.position + pose.direction * 1.3
        let floor = g.puzzle.surfaceHeight(at: [position.x, position.z])
        let enemyPosition = SIMD3<Float>(position.x, floor, position.z)
        g.enemies = [TrainingEnemy(id: 1, kind: .fax, isBoss: false, isMiniBoss: false, position: enemyPosition, origin: enemyPosition, shields: 8, maxShields: 8, nextAttack: 100)]
        g.fireLaser(); XCTAssertEqual(g.energy, 97); XCTAssertEqual(g.gelProjectiles.count, 1)
        g.fireLaser(); XCTAssertEqual(g.energy, 97, "cooldown rejects duplicate discharge")
        for _ in 0..<5 { g.tick(0.05) }
        XCTAssertEqual(g.enemies[0].shields, 6)
        g.togglePickupLean(); XCTAssertFalse(g.gelBlasterEquipped)
        g.toggleGelBlaster(); XCTAssertFalse(g.gelBlasterEquipped)
    }
    func testRemoteRelayPaysOnceAndReleasesDoorWithSweptProjectile() {
        let (g, store, name) = game(); defer { store.removePersistentDomain(forName: name) }
        // Fire along a clear same-floor approach to the first cell's relay.
        let relay = g.remoteRelayPosition
        g.robotPosition = [relay.x - ROBTacticalRules.muzzle.x * 1.35, g.puzzle.surfaceHeight(at: [relay.x, relay.z]), relay.z + 2]
        g.robotHeading = 0; g.toggleGelBlaster()
        let before = g.upgradePoints
        g.fireLaser(); for _ in 0..<12 { g.tick(0.05) }
        XCTAssertTrue(g.remoteRelayActivated); XCTAssertTrue(g.doorOpen)
        XCTAssertEqual(g.upgradePoints, before + 60)
        g.fireLaser(); for _ in 0..<12 { g.tick(0.05) }
        XCTAssertEqual(g.upgradePoints, before + 60)
    }
    func testPEQModesAndVisualHandsRestoreAfterStowing() {
        let (g, store, name) = game(); defer { store.removePersistentDomain(forName: name) }
        let robot = RobotFactory.makeROB()
        g.toggleGelBlaster(); g.cyclePEQ(); XCTAssertEqual(g.peqMode, .blue)
        RobotFactory.applyWeapons(to: robot, session: g)
        XCTAssertEqual(robot.findEntity(named: "Left Arm Assembly")?.isEnabled, false)
        XCTAssertEqual(robot.findEntity(named: "PEQ Blue Beam")?.isEnabled, true)
        XCTAssertNotNil(robot.findEntity(named: "Left gripping palm")); XCTAssertNotNil(robot.findEntity(named: "Upright antenna 16"))
        g.cyclePEQ(); XCTAssertEqual(g.peqMode, .infrared)
        g.cyclePEQ(); XCTAssertEqual(g.peqMode, .flashlight)
        RobotFactory.applyWeapons(to: robot, session: g)
        XCTAssertEqual(robot.findEntity(named: "PEQ Flashlight")?.isEnabled, true)
        g.stowGelBlaster(); RobotFactory.applyWeapons(to: robot, session: g)
        XCTAssertEqual(robot.findEntity(named: "Left Arm Assembly")?.isEnabled, true)
        XCTAssertEqual(robot.findEntity(named: "Two-handed StrikeForce Gel Kit")?.isEnabled, false)
    }
}
