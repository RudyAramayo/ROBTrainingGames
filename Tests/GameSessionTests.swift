import XCTest
import AVFoundation
import RealityKit
import simd
@testable import ROB_Training

@MainActor
final class GameSessionTests: XCTestCase {
    func testCalibrationMatchesBrowserCampaign() {
        let game = GameSession(audioEnabled: false)

        XCTAssertEqual(game.level.cellCount, 3)
        XCTAssertEqual(game.level.enemyShields, 2)
        XCTAssertEqual(game.enemies.map(\.kind), [.spider, .fax, .spider])
        XCTAssertEqual(game.remainingEnemies, 3)
        XCTAssertEqual(game.levels.count, 15)
        XCTAssertGreaterThan(game.puzzle.arenaHalfExtent, 5)
    }

    func testLevelOneNeedsNoKeyAndAdvancesWhenObjectivesReachTheDock() {
        let game = GameSession(audioEnabled: false)
        game.begin()

        XCTAssertFalse(game.level.requiresKey)
        XCTAssertNil(game.puzzle.key)
        XCTAssertTrue(game.doorOpen)

        game.collectedCells = game.level.cellCount
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        game.robotPosition = [game.puzzle.dock.x, 0, game.puzzle.dock.y]
        game.tick(1.0 / 30.0)

        XCTAssertEqual(game.level.id, 2)
        XCTAssertTrue(game.isRunning)
    }

    func testLevelOneDockExplainsItsActualRemainingObjectives() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        game.robotPosition = [game.puzzle.dock.x, 0, game.puzzle.dock.y]

        game.tick(1.0 / 30.0)

        XCTAssertEqual(game.level.id, 1)
        XCTAssertTrue(game.message.contains("3 more energy cells"))
        XCTAssertTrue(game.message.contains("3 more targets"))
        XCTAssertFalse(game.message.localizedCaseInsensitiveContains("key"))
    }

    func testVoiceRejectsInvalidMicrophoneFormatsBeforeInstallingATap() {
        XCTAssertFalse(RobotVoice.isUsableInputFormat(sampleRate: 0, channelCount: 1))
        XCTAssertFalse(RobotVoice.isUsableInputFormat(sampleRate: 48_000, channelCount: 0))
        XCTAssertTrue(RobotVoice.isUsableInputFormat(sampleRate: 48_000, channelCount: 1))
    }

    func testEnemiesPatrolAndInitiateAttacks() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        let startingPositions = game.enemies.map(\.position)

        for _ in 0..<30 { game.tick(1.0 / 30.0) }

        XCTAssertTrue(zip(startingPositions, game.enemies.map(\.position)).contains { simd_distance($0, $1) > 0.01 })

        for _ in 0..<600 where game.enemyAttackCount == 0 { game.tick(1.0 / 30.0) }

        XCTAssertGreaterThan(game.enemyAttackCount, 0)
        XCTAssertTrue(game.isRunning)
    }

    func testDriveInputMovesROBAndStopClearsDemand() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        let startingPosition = game.robotPosition

        game.setDrive(forward: 1, steering: 0)
        game.tick(0.4)
        game.stopDrive()

        XCTAssertGreaterThan(simd_distance(startingPosition, game.robotPosition), 0.1)
        XCTAssertEqual(game.forwardDemand, 0)
        XCTAssertEqual(game.steeringDemand, 0)
    }

    func testStopDriveImmediatelyClearsAStuckTurn() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        game.setDrive(forward: 0, steering: 1)
        game.tick(0.25)
        XCTAssertNotEqual(game.leftTread, 0)
        XCTAssertNotEqual(game.rightTread, 0)

        game.stopDrive()
        let stoppedHeading = game.robotHeading
        game.tick(0.25)

        XCTAssertEqual(game.forwardDemand, 0)
        XCTAssertEqual(game.steeringDemand, 0)
        XCTAssertEqual(game.leftTread, 0)
        XCTAssertEqual(game.rightTread, 0)
        XCTAssertEqual(game.robotHeading, stoppedHeading, accuracy: 0.0001)
    }

    func testDualJoysticksCommandTheirMatchingTreads() {
        let game = GameSession(audioEnabled: false)
        game.begin()

        game.setTreads(left: 1, right: -0.5)
        game.tick(0.25)

        XCTAssertGreaterThan(game.leftTread, 0)
        XCTAssertLessThan(game.rightTread, 0)
        XCTAssertLessThan(game.robotHeading, 0)
    }

    func testFaxRobotFiresTrackedProjectile() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        for index in game.enemies.indices where game.enemies[index].kind == .spider { game.enemies[index].isActive = false }

        for _ in 0..<600 where game.enemyBolts.isEmpty { game.tick(1.0 / 30.0) }

        XCTAssertGreaterThan(game.enemyAttackCount, 0)
        XCTAssertFalse(game.enemyBolts.isEmpty)
        XCTAssertTrue(game.message.contains("Exterminate"))
    }

    func testSharedCombatLayerRendersEnemiesAndProjectiles() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        let layer = RobotFactory.makeCombatLayer(session: game)

        XCTAssertNotNil(layer.findEntity(named: "Training Enemy 0"))
        XCTAssertNotNil(layer.findEntity(named: "Training Enemy 1"))

        for index in game.enemies.indices where game.enemies[index].kind == .spider { game.enemies[index].isActive = false }
        for _ in 0..<600 where game.enemyBolts.isEmpty { game.tick(1.0 / 30.0) }
        RobotFactory.applyCombatState(to: layer, session: game)

        guard let bolt = game.enemyBolts.first else { return XCTFail("Fax robot did not create a projectile") }
        XCTAssertNotNil(layer.findEntity(named: "Enemy Bolt \(bolt.id)"))
    }

    func testFaxProtrudingFrontFacesROB() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        game.tick(1.0 / 30.0)
        guard let fax = game.enemies.first(where: { $0.kind == .fax }) else { return XCTFail("Missing fax robot") }
        let layer = RobotFactory.makeCombatLayer(session: game)
        guard let entity = layer.findEntity(named: "Training Enemy \(fax.id)") else { return XCTFail("Missing fax model") }

        var directionToROB = game.robotPosition - fax.position
        directionToROB.y = 0
        directionToROB = simd_normalize(directionToROB)
        let protrudingFront = entity.orientation.act(SIMD3<Float>(0, 0, -1))

        XCTAssertGreaterThan(simd_dot(protrudingFront, directionToROB), 0.999)
    }

    func testWeaponsRequireAimAndRange() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        guard let spiderIndex = game.enemies.firstIndex(where: { $0.kind == .spider }) else { return XCTFail("Missing spider") }
        let shields = game.enemies[spiderIndex].shields

        game.saberAttack()
        XCTAssertEqual(game.enemies[spiderIndex].shields, shields)

        game.robotPosition = game.enemies[spiderIndex].position + SIMD3<Float>(0, 0, 0.7)
        game.robotHeading = 0
        game.saberAttack()

        XCTAssertEqual(game.enemies[spiderIndex].shields, shields - 1)
        XCTAssertTrue(game.message.contains("dual-saber"))
    }

    func testThirdSaberPressTriggersSpinAndHitsBehindROB() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        let index = game.enemies.startIndex
        game.enemies[index].position = game.robotPosition + SIMD3<Float>(0, 0, 1.25)
        let shields = game.enemies[index].shields

        game.saberAttack()
        game.saberAttack()
        XCTAssertEqual(game.enemies[index].shields, shields)
        game.saberAttack()

        XCTAssertEqual(game.saberStyle, .spin)
        XCTAssertEqual(game.enemies[index].shields, shields - 1)
        XCTAssertTrue(game.message.contains("Spin attack"))
    }

    func testShoulderLaserLocksAndChargedShotDealsMoreDamage() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        guard let targetID = game.lockedEnemyID, let targetIndex = game.enemies.firstIndex(where: { $0.id == targetID }) else { return XCTFail("Shoulder laser did not acquire a target") }
        let shields = game.enemies[targetIndex].shields

        game.beginLaserCharge()
        game.tick(1.0)
        game.releaseLaserCharge()

        XCTAssertFalse(game.isChargingLaser)
        XCTAssertGreaterThan(game.laserShotCharge, 0.7)
        XCTAssertLessThanOrEqual(game.enemies[targetIndex].shields, shields - 2)
        XCTAssertNotNil(game.laserDistance)
    }

    func testROBGeometryContainsSwingingArmsAndShoulderGatling() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()

        XCTAssertNotNil(robot.findEntity(named: "Left Arm Assembly"))
        XCTAssertNotNil(robot.findEntity(named: "Right Arm Assembly"))
        XCTAssertNotNil(robot.findEntity(named: "Right Shoulder Gatling"))
        XCTAssertNotNil(robot.findEntity(named: "Gatling Lock Indicator"))
        XCTAssertNotNil(robot.findEntity(named: "Shoulder Laser Beam"))
        XCTAssertNotNil(robot.findEntity(named: "Left Tri-Wheel Tread"))
        XCTAssertNotNil(robot.findEntity(named: "Right Tri-Wheel Tread"))
        for side in ["Left", "Right"] { for index in 1...3 { XCTAssertNotNil(robot.findEntity(named: "\(side) Tri-Wheel \(index)")) } }

        game.begin()
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertTrue(robot.findEntity(named: "Gatling Lock Indicator")?.isEnabled == true)
    }

    func testROBGestureRootHasInputAndCollisionComponents() {
        let robot = RobotFactory.makeROB()
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)

        XCTAssertNotNil(robot.components[InputTargetComponent.self])
        XCTAssertNotNil(robot.collision)
        XCTAssertFalse(robot.collision?.shapes.isEmpty ?? true)
        XCTAssertEqual(view.installGestures([.translation, .rotation, .scale], for: robot).count, 3)
    }

    func testTurnMixUsesTheCorrectTreadAndPreservesLeftSteering() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        game.setDrive(forward: 0.36, steering: 0.5)
        game.tick(0.25)

        XCTAssertEqual(game.leftWheelAngle, 0, accuracy: 0.0001)
        XCTAssertNotEqual(game.rightWheelAngle, 0)
        XCTAssertGreaterThan(game.robotHeading, 0)
    }

    func testSpinExtendsBothArmsFullyOutward() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()
        game.begin()
        game.saberAttack(); game.saberAttack(); game.saberAttack()

        RobotFactory.applyWeapons(to: robot, session: game)

        for (name, side) in [("Left Arm Assembly", Float(-1)), ("Right Arm Assembly", Float(1))] {
            guard let arm = robot.findEntity(named: name) else { return XCTFail("Missing \(name)") }
            let reach = arm.orientation.act(SIMD3<Float>(0, -1, 0))
            XCTAssertEqual(reach.x, side, accuracy: 0.001)
            XCTAssertEqual(reach.y, 0, accuracy: 0.001)
            XCTAssertEqual(reach.z, 0, accuracy: 0.001)
        }
    }
}
