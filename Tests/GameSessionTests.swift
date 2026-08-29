import XCTest
import ARKit
import AVFoundation
import Dispatch
import RealityKit
import Speech
import simd
@testable import ROB_Training

private struct SendableAudioTapInvocation: @unchecked Sendable {
    let tap: AVAudioNodeTapBlock
    let buffer: AVAudioPCMBuffer
    let time: AVAudioTime

    func call() { tap(buffer, time) }
}

@MainActor
final class GameSessionTests: XCTestCase {
    private func completeCurrentLevel(_ game: GameSession) {
        game.collectedCells = game.level.cellCount
        game.doorOpen = true
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        game.nextLevel()
    }

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

    func testPauseAndResumePreserveMissionProgress() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        game.collectCell()
        game.setTreads(left: 1, right: 1)
        game.tick(0.25)
        let elapsedBeforePause = game.elapsed
        let positionBeforePause = game.robotPosition

        XCTAssertTrue(game.pause())
        XCTAssertFalse(game.isRunning)
        XCTAssertTrue(game.isPaused)
        XCTAssertEqual(game.leftTread, 0)
        XCTAssertEqual(game.rightTread, 0)

        game.tick(5)
        game.moveStep(forward: 1)
        XCTAssertEqual(game.elapsed, elapsedBeforePause)
        XCTAssertEqual(game.robotPosition, positionBeforePause)
        XCTAssertEqual(game.collectedCells, 1)

        XCTAssertTrue(game.resume())
        XCTAssertTrue(game.isRunning)
        XCTAssertFalse(game.isPaused)
        game.tick(0.25)
        XCTAssertGreaterThan(game.elapsed, elapsedBeforePause)
        XCTAssertEqual(game.collectedCells, 1)
    }

    func testLevelTwoHasAVisibleReachableKeyOnTheStartingSide() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 1
        game.begin()

        guard let key = game.puzzle.key, let door = game.puzzle.door else {
            return XCTFail("Level 2 must provide both a key and a locked door")
        }
        XCTAssertLessThan(key.x, door.center.x)
        XCTAssertLessThan(abs(key.x), game.puzzle.arenaHalfExtent - 0.35)
        XCTAssertLessThan(abs(key.y), game.puzzle.arenaHalfExtent - 0.35)

        let room = RobotFactory.makeTrainingRoom(level: game.levelIndex, puzzle: game.puzzle)
        guard let renderedKey = room.findEntity(named: "Puzzle Key") else {
            return XCTFail("Level 2 did not render its key")
        }
        XCTAssertNotNil(renderedKey.findEntity(named: "Puzzle Key Beacon"))
        XCTAssertGreaterThan(renderedKey.children.count, 3)

        game.robotPosition = [key.x, 0, key.y]
        game.tick(1.0 / 30.0)
        XCTAssertTrue(game.hasKey)
    }

    func testVoiceRejectsInvalidMicrophoneFormatsBeforeInstallingATap() {
        XCTAssertFalse(RobotVoice.isUsableInputFormat(sampleRate: 0, channelCount: 1))
        XCTAssertFalse(RobotVoice.isUsableInputFormat(sampleRate: 48_000, channelCount: 0))
        XCTAssertTrue(RobotVoice.isUsableInputFormat(sampleRate: 48_000, channelCount: 1))
    }

    func testAutomaticVoiceCommentaryDefaultsOff() {
        XCTAssertFalse(RobotVoice().automaticComments)
    }

    func testARLabEnablesCameraLightingAndFillLights() {
        let configuration = ROBARView.makeConfiguration()
        let lightRig = ROBARView.makeFillLightRig()

        XCTAssertEqual(configuration.planeDetection, [.horizontal])
        XCTAssertTrue(configuration.isLightEstimationEnabled)
        XCTAssertEqual(configuration.environmentTexturing, .automatic)
        XCTAssertEqual(lightRig.children.count, 3)
        XCTAssertEqual(lightRig.children.filter { $0.components[PointLightComponent.self] != nil }.count, 2)
        XCTAssertEqual(lightRig.children.filter { $0.components[DirectionalLightComponent.self] != nil }.count, 1)
    }

    func testARLabRendersAndUpdatesThePlayableMission() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        let root = ROBARView.makeMissionRoot(session: game)

        XCTAssertEqual(root.name, ROBARView.missionRootName)
        XCTAssertEqual(root.scale, SIMD3<Float>(repeating: ROBARView.arenaScale))
        XCTAssertNotNil(root.findEntity(named: "Training Room-0"))
        XCTAssertNotNil(root.findEntity(named: "Training Floor"))
        XCTAssertNotNil(root.findEntity(named: RobotFactory.combatLayerName(level: 0)))
        XCTAssertNotNil(root.findEntity(named: "Puzzle Cell 0"))
        XCTAssertNotNil(root.findEntity(named: "Training Enemy 0"))

        game.robotPosition = [1.25, 0, -0.75]
        game.robotHeading = .pi / 3
        game.enemies[0].isActive = false
        game.collectedCellIndices.insert(0)
        ROBARView.updateMissionRoot(root, session: game)

        XCTAssertEqual(root.findEntity(named: "ROB")?.position, game.robotPosition)
        XCTAssertFalse(root.findEntity(named: "Training Enemy 0")?.isEnabled ?? true)
        XCTAssertFalse(root.findEntity(named: "Puzzle Cell 0")?.isEnabled ?? true)

        game.levelIndex = 1
        game.begin()
        ROBARView.updateMissionRoot(root, session: game)

        XCTAssertNil(root.findEntity(named: "Training Room-0"))
        XCTAssertNil(root.findEntity(named: RobotFactory.combatLayerName(level: 0)))
        XCTAssertNotNil(root.findEntity(named: "Training Room-1"))
        XCTAssertNotNil(root.findEntity(named: "Puzzle Key"))
        XCTAssertNotNil(root.findEntity(named: RobotFactory.combatLayerName(level: 1)))
    }

    nonisolated func testVoiceAudioTapRunsOutsideMainActor() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32)!
        buffer.frameLength = 32
        let request = SFSpeechAudioBufferRecognitionRequest()
        let invocation = SendableAudioTapInvocation(
            tap: RobotVoice.makeRecognitionTap(request: request),
            buffer: buffer,
            time: AVAudioTime(sampleTime: 0, atRate: format.sampleRate)
        )
        let finished = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            invocation.call()
            finished.signal()
        }

        XCTAssertEqual(finished.wait(timeout: .now() + 1), .success)
        request.endAudio()
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

    func testRegularDamageReducesHealthWithoutRestartingMissionProgress() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        game.collectedCells = 1
        let enemyShields = game.enemies.map(\.shields)

        XCTAssertTrue(game.enemyContact("Spider bot lunge", damage: 6))

        XCTAssertEqual(game.health, 94)
        XCTAssertEqual(game.collectedCells, 1)
        XCTAssertEqual(game.enemies.map(\.shields), enemyShields)
        XCTAssertTrue(game.isRunning)
        XCTAssertTrue(game.message.contains("6 damage"))
        XCTAssertFalse(game.enemyContact("Overlapping collision", damage: 6), "The hit cooldown should prevent damage every rendered frame")
        XCTAssertEqual(game.health, 94)
    }

    func testDepletedHealthRestartsOnlyTheCurrentLevel() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 2
        game.begin()
        game.collectedCells = 2

        game.enemyContact("Critical hit", damage: game.maxHealth)

        XCTAssertEqual(game.level.id, 3)
        XCTAssertEqual(game.health, game.maxHealth)
        XCTAssertEqual(game.collectedCells, 0)
        XCTAssertTrue(game.isRunning)
        XCTAssertTrue(game.message.contains("Restarting level 3"))
    }

    func testEveryFifthLevelHasAReinforcedBossThatDealsTenDamage() {
        let game = GameSession(audioEnabled: false)
        XCTAssertNil(game.activeBoss)
        for levelIndex in [4, 9, 14] {
            game.levelIndex = levelIndex
            game.begin()
            guard let boss = game.activeBoss else { return XCTFail("Level \(levelIndex + 1) needs a boss") }
            XCTAssertTrue(boss.isBoss)
            XCTAssertGreaterThanOrEqual(boss.maxShields, 10)
            XCTAssertEqual(boss.shields, boss.maxShields)
            XCTAssertEqual(boss.contactDamage, 10)
            XCTAssertEqual(boss.projectileDamage, 10)
        }

        guard let boss = game.activeBoss else { return XCTFail("Level 15 needs a boss") }
        game.enemyContact(boss.displayName, damage: boss.contactDamage)
        XCTAssertEqual(game.health, 90)
    }

    func testBossHasDistinctLargerGeometryAndShieldCore() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 4
        game.begin()
        guard let boss = game.activeBoss else { return XCTFail("Level 5 needs a boss") }
        let layer = RobotFactory.makeCombatLayer(session: game)
        guard let entity = layer.findEntity(named: "Training Enemy \(boss.id)") else { return XCTFail("Missing boss model") }

        XCTAssertGreaterThan(entity.scale.x, 1.3)
        XCTAssertNotNil(entity.findEntity(named: "Boss Core"))
        XCTAssertNotNil(entity.findEntity(named: "Boss Beacon"))
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

    func testROBChassisStopsBeforeThePerimeterWall() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        let startingPosition = game.robotPosition

        game.setDrive(forward: -1, steering: 0)
        game.tick(1)
        game.stopDrive()

        let wallSafeLimit = game.puzzle.arenaHalfExtent - 0.09 - GameSession.robotCollisionRadius
        XCTAssertLessThanOrEqual(abs(game.robotPosition.z), wallSafeLimit + 0.001)
        XCTAssertEqual(game.robotPosition.z, startingPosition.z, accuracy: 0.001)
        XCTAssertTrue(game.message.localizedCaseInsensitiveContains("wall collision"))
    }

    func testSweptChassisCollisionCannotTunnelThroughAnInteriorWall() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        guard let wall = game.puzzle.barriers.first else { return XCTFail("Level needs an interior wall") }
        let safeZ = wall.center.y + wall.size.y / 2 + GameSession.robotCollisionRadius + 0.03
        game.robotPosition = [wall.center.x, 0, safeZ]
        game.robotHeading = 0

        game.setDrive(forward: 1, steering: 0)
        game.tick(1)
        game.stopDrive()

        XCTAssertGreaterThanOrEqual(game.robotPosition.z, wall.center.y + wall.size.y / 2 + GameSession.robotCollisionRadius)
        XCTAssertEqual(game.robotPosition.z, safeZ, accuracy: 0.001)
    }

    func testChassisCanUnlockAndPassThroughEveryLevelDoorway() {
        let game = GameSession(audioEnabled: false)
        for levelIndex in game.levels.indices where game.levels[levelIndex].requiresKey {
            game.levelIndex = levelIndex
            game.begin()
            for index in game.enemies.indices { game.enemies[index].isActive = false }
            game.collectKey()
            guard let door = game.puzzle.door, let terminal = game.puzzle.hackTerminal else {
                return XCTFail("Level \(game.level.id) needs a door and hack terminal")
            }

            let openingWidth = max(door.size.x, door.size.y)
            XCTAssertGreaterThanOrEqual(
                openingWidth - GameSession.robotCollisionRadius * 2,
                0.8,
                "Level \(game.level.id) doorway needs useful steering clearance"
            )

            let crossingOffset = GameSession.robotCollisionRadius + min(door.size.x, door.size.y) / 2 + 0.28
            game.robotPosition = [terminal.x, 0, terminal.y]
            XCTAssertTrue(game.canStartDoorHack, "Level \(game.level.id) hack terminal is not reachable")
            game.startDoorHack()
            game.tick(2.3)
            XCTAssertTrue(game.doorOpen, "Level \(game.level.id) Flipper Zero hack did not open the door")

            if door.size.x < door.size.y {
                game.robotPosition = [door.center.x + crossingOffset, 0, door.center.y]
                game.robotHeading = .pi / 2
            } else {
                game.robotPosition = [door.center.x, 0, door.center.y + crossingOffset]
                game.robotHeading = 0
            }

            game.setDrive(forward: 1, steering: 0)
            for _ in 0..<240 { game.tick(1.0 / 60.0) }
            game.stopDrive()

            if door.size.x < door.size.y {
                XCTAssertLessThan(
                    game.robotPosition.x,
                    door.center.x - crossingOffset,
                    "ROB could not drive through Level \(game.level.id)'s vertical doorway"
                )
            } else {
                XCTAssertLessThan(
                    game.robotPosition.z,
                    door.center.y - crossingOffset,
                    "ROB could not drive through Level \(game.level.id)'s horizontal doorway"
                )
            }
        }
    }

    func testEveryLevelProvidesClearSpawnsObjectivesAndCorridors() {
        let game = GameSession(audioEnabled: false)

        for levelIndex in game.levels.indices {
            game.levelIndex = levelIndex
            game.begin()
            XCTAssertTrue(
                game.isRobotPositionClear(game.robotPosition),
                "Level \(game.level.id) starts ROB inside a wall collision envelope"
            )

            game.doorOpen = true
            var objectives = game.puzzle.cells + [game.puzzle.dock]
            if let key = game.puzzle.key { objectives.append(key) }
            if let terminal = game.puzzle.hackTerminal { objectives.append(terminal) }
            for objective in objectives {
                XCTAssertTrue(
                    game.isRobotPositionClear([objective.x, 0, objective.y]),
                    "Level \(game.level.id) places an objective outside ROB's navigable space at \(objective)"
                )
            }

            guard !game.level.requiresKey else { continue }
            let walls = game.puzzle.barriers.sorted { $0.center.y > $1.center.y }
            for (first, second) in zip(walls, walls.dropFirst()) {
                let physicalGap = abs(first.center.y - second.center.y) - (first.size.y + second.size.y) / 2
                let steeringClearance = physicalGap - GameSession.robotCollisionRadius * 2
                XCTAssertGreaterThanOrEqual(
                    steeringClearance,
                    0.4,
                    "Level \(game.level.id) zigzag is too narrow for ROB to change sides"
                )
            }
        }
    }

    func testDoorHackRequiresKeyProximityAndAutomaticHackTime() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 1
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        guard let terminal = game.puzzle.hackTerminal else { return XCTFail("Missing hack terminal") }

        game.robotPosition = [terminal.x, 0, terminal.y]
        game.startDoorHack()
        XCTAssertFalse(game.isHackingDoor)
        XCTAssertFalse(game.doorOpen)

        game.collectKey()
        game.robotPosition = [terminal.x + 2, 0, terminal.y]
        game.startDoorHack()
        XCTAssertFalse(game.isHackingDoor)

        game.robotPosition = [terminal.x, 0, terminal.y]
        game.startDoorHack()
        XCTAssertTrue(game.isHackingDoor)
        game.tick(1.1)
        XCTAssertEqual(game.hackingProgress, 0.5, accuracy: 0.02)
        XCTAssertFalse(game.doorOpen)
        game.tick(1.2)
        XCTAssertTrue(game.doorOpen)
        XCTAssertFalse(game.isHackingDoor)
        XCTAssertTrue(game.message.contains("hack complete"))
    }

    func testConveyorCarriesROBInItsArrowDirection() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 1
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        guard let conveyor = game.puzzle.conveyors.first else { return XCTFail("Level 2 needs a conveyor") }
        game.robotPosition = [conveyor.center.x, 0, conveyor.center.y]
        let start = SIMD2<Float>(game.robotPosition.x, game.robotPosition.z)

        game.tick(0.5)

        let movement = SIMD2<Float>(game.robotPosition.x, game.robotPosition.z) - start
        XCTAssertGreaterThan(simd_dot(movement, conveyor.direction), 0.08)
    }

    func testSecurityCameraAlertsEnemiesButShadowsBreakDetection() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 2
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        guard let camera = game.puzzle.securityCameras.first, let shadow = game.puzzle.shadowZones.first else {
            return XCTFail("Level 3 needs camera and shadow geometry")
        }
        let heading = game.securityCameraHeading(camera)
        let forward = SIMD2<Float>(-sin(heading), -cos(heading))
        let seenPoint = camera.position + forward * 1.2
        game.robotPosition = [seenPoint.x, 0, seenPoint.y]

        game.tick(0.001)

        XCTAssertTrue(game.isSecurityAlerted)
        game.robotPosition = [shadow.center.x, 0, shadow.center.y]
        XCTAssertTrue(game.isInShadow)
        game.tick(5.1)
        XCTAssertFalse(game.isSecurityAlerted)
    }

    func testEnergyDrainsWhileDrivingAndRecoversWhileStopped() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        let fullEnergy = game.energy

        game.setDrive(forward: 1, steering: 0)
        game.tick(0.75)
        game.stopDrive()
        let drivenEnergy = game.energy

        XCTAssertLessThan(drivenEnergy, fullEnergy)
        game.tick(1)
        XCTAssertGreaterThan(game.energy, drivenEnergy)

        let recoveredEnergy = game.energy
        game.setDrive(forward: 0, steering: 1)
        game.tick(0.5)
        game.stopDrive()
        XCTAssertLessThan(game.energy, recoveredEnergy, "Pivoting the powered treads should also consume energy")
    }

    func testPerformanceUpgradesSpendPersistentPointsAndIncreaseCapabilities() {
        let suiteName = "ROBTrainingUpgrades.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(5_000, forKey: "robUpgradePoints")
        let game = GameSession(audioEnabled: false, progressStore: defaults)

        game.purchaseUpgrade(.speedBoost)
        game.purchaseUpgrade(.energyCapacity)
        game.purchaseUpgrade(.weaponPower)

        XCTAssertEqual(game.speedUpgradeLevel, 1)
        XCTAssertEqual(game.energyUpgradeLevel, 1)
        XCTAssertEqual(game.weaponUpgradeLevel, 1)
        XCTAssertEqual(game.maxEnergy, 125)
        XCTAssertGreaterThan(game.driveSpeedMultiplier, 1)
        XCTAssertEqual(game.weaponDamageBonus, 1)
        let restored = GameSession(audioEnabled: false, progressStore: defaults)
        XCTAssertEqual(restored.speedUpgradeLevel, 1)
        XCTAssertEqual(restored.energyUpgradeLevel, 1)
        XCTAssertEqual(restored.weaponUpgradeLevel, 1)
        XCTAssertEqual(restored.upgradePoints, game.upgradePoints)
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

        game.robotPosition = [0, 0, -2.2]
        game.enemies[spiderIndex].position = [0, 0, -3.2]
        game.robotHeading = 0
        game.saberAttack()

        XCTAssertEqual(game.enemies[spiderIndex].shields, shields - 1)
        XCTAssertTrue(game.message.contains("dual-saber"))
    }

    func testWallBlocksSaberAnimationAndDamage() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        guard let wall = game.puzzle.barriers.first, let targetIndex = game.enemies.indices.first else { return XCTFail("Missing wall or target") }
        for index in game.enemies.indices where index != targetIndex { game.enemies[index].isActive = false }
        let clearance = GameSession.robotCollisionRadius + 0.03
        game.robotPosition = [wall.center.x, 0, wall.center.y + wall.size.y / 2 + clearance]
        game.robotHeading = 0
        game.enemies[targetIndex].position = [wall.center.x, 0, wall.center.y - wall.size.y / 2 - clearance]
        let shields = game.enemies[targetIndex].shields

        game.saberAttack()

        XCTAssertEqual(game.enemies[targetIndex].shields, shields)
        XCTAssertEqual(game.saberAnimation, 0)
        XCTAssertNil(game.saberStyle)
        XCTAssertTrue(game.message.localizedCaseInsensitiveContains("blocked by the wall"))
    }

    func testSaberBladesStayRetractedUntilAValidAttack() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()
        game.begin()

        RobotFactory.applyWeapons(to: robot, session: game)
        guard let blade = robot.findEntity(named: "Left Lightsaber") else { return XCTFail("Missing saber") }
        XCTAssertLessThan(blade.scale.y, 0.1)

        game.robotPosition = [0, 0, -2.2]
        game.robotHeading = 0
        game.saberAttack()
        RobotFactory.applyWeapons(to: robot, session: game)

        XCTAssertEqual(blade.scale.y, 1, accuracy: 0.001)
    }

    func testThirdSaberPressTriggersSpinAndHitsBehindROB() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        let index = game.enemies.startIndex
        game.robotPosition = [0, 0, -2.65]
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
        guard let targetIndex = game.enemies.indices.first else { return XCTFail("Missing training target") }
        for index in game.enemies.indices where index != targetIndex { game.enemies[index].isActive = false }
        game.enemies[targetIndex].position = game.robotPosition + SIMD3<Float>(0, 0, -1.7)
        let shields = game.enemies[targetIndex].shields

        game.beginLaserCharge()
        game.tick(1.0)
        game.releaseLaserCharge()

        XCTAssertFalse(game.isChargingLaser)
        XCTAssertGreaterThan(game.laserShotCharge, 0.7)
        XCTAssertEqual(game.enemies[targetIndex].shields, shields, "Firing should not damage a target before the projectile arrives")
        XCTAssertNotNil(game.laserDistance)

        for _ in 0..<60 where game.laserDistance != nil { game.tick(1.0 / 60.0) }

        XCTAssertLessThanOrEqual(game.enemies[targetIndex].shields, shields - 2)
        XCTAssertNil(game.laserDistance)
    }

    func testShoulderLaserStopsAtAWallBeforeDamagingAnEnemy() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        guard let targetIndex = game.enemies.indices.first else { return XCTFail("Missing training target") }
        for index in game.enemies.indices where index != targetIndex { game.enemies[index].isActive = false }
        game.robotPosition = [0, 0, 2.8]
        game.enemies[targetIndex].position = [0, 0, 0.8]
        let shields = game.enemies[targetIndex].shields

        game.fireLaser()
        XCTAssertNotNil(game.laserDistance)
        XCTAssertEqual(game.enemies[targetIndex].shields, shields)

        game.tick(0.5)

        XCTAssertNil(game.laserDistance)
        XCTAssertEqual(game.enemies[targetIndex].shields, shields)
        XCTAssertTrue(game.message.localizedCaseInsensitiveContains("wall"))
    }

    func testEnemyLaserCannotTunnelThroughAWallIntoROB() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        guard let wall = game.puzzle.barriers.first else { return XCTFail("Level needs an interior wall") }

        if wall.size.x > wall.size.y {
            game.robotPosition = [wall.center.x, 0, wall.center.y - 1]
            game.enemyBolts = [TrainingEnemyBolt(id: 900, position: [wall.center.x, 0.55, wall.center.y + 1], velocity: [0, 0, -6], damage: 10, sourceName: "Boss laser", isBoss: true)]
        } else {
            game.robotPosition = [wall.center.x - 1, 0, wall.center.y]
            game.enemyBolts = [TrainingEnemyBolt(id: 900, position: [wall.center.x + 1, 0.55, wall.center.y], velocity: [-6, 0, 0], damage: 10, sourceName: "Boss laser", isBoss: true)]
        }

        game.tick(0.5)

        XCTAssertEqual(game.health, game.maxHealth)
        XCTAssertTrue(game.enemyBolts.isEmpty)
    }

    func testROBGeometryContainsSwingingArmsAndShoulderGatling() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()

        XCTAssertNotNil(robot.findEntity(named: "Left Arm Assembly"))
        XCTAssertNotNil(robot.findEntity(named: "Right Arm Assembly"))
        XCTAssertNotNil(robot.findEntity(named: "Right Shoulder Gatling"))
        XCTAssertNotNil(robot.findEntity(named: "Flipper Zero Hacker"))
        XCTAssertNotNil(robot.findEntity(named: "Gatling Lock Indicator"))
        XCTAssertNotNil(robot.findEntity(named: "Shoulder Laser Beam"))
        XCTAssertNotNil(robot.findEntity(named: "Left Tri-Wheel Tread"))
        XCTAssertNotNil(robot.findEntity(named: "Right Tri-Wheel Tread"))
        for side in ["Left", "Right"] {
            guard let tread = robot.findEntity(named: "\(side) Tri-Wheel Tread") else { return XCTFail("Missing \(side) tread") }
            XCTAssertGreaterThanOrEqual(tread.children.filter { $0.name.hasPrefix("\(side) Tread Shoe ") }.count, 18)
            for index in 1...6 { XCTAssertNotNil(robot.findEntity(named: "\(side) Track Belt Segment \(index)")) }
            for index in 1...3 { XCTAssertNotNil(robot.findEntity(named: "\(side) Tri-Wheel \(index)")) }
            guard
                let frontWheel = robot.findEntity(named: "\(side) Tri-Wheel 1"),
                let raisedWheel = robot.findEntity(named: "\(side) Tri-Wheel 2"),
                let rearWheel = robot.findEntity(named: "\(side) Tri-Wheel 3")
            else { return XCTFail("Missing \(side) tri-wheel bogie") }
            XCTAssertGreaterThan(raisedWheel.position.y, frontWheel.position.y)
            XCTAssertEqual(frontWheel.position.y, rearWheel.position.y, accuracy: 0.001)
            XCTAssertLessThan(frontWheel.position.z, raisedWheel.position.z)
            XCTAssertGreaterThan(rearWheel.position.z, raisedWheel.position.z)
        }

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
        game.robotPosition = [0, 0, -2.65]
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

    func testWeaponsUnlockAfterEveryFiveCompletedLevels() {
        let game = GameSession(audioEnabled: false)

        for _ in 0..<4 { completeCurrentLevel(game) }
        XCTAssertEqual(game.highestCompletedLevel, 4)
        XCTAssertFalse(game.isUnlocked(.twinBlasters))
        game.selectRangedWeapon(.twinBlasters)
        XCTAssertEqual(game.rangedWeapon, .shoulderGatling)
        XCTAssertTrue(game.message.contains("Level 5"))

        completeCurrentLevel(game)
        XCTAssertEqual(game.highestCompletedLevel, 5)
        XCTAssertTrue(game.isUnlocked(.twinBlasters))
        XCTAssertFalse(game.isUnlocked(.powerHammer))

        for _ in 0..<5 { completeCurrentLevel(game) }
        XCTAssertEqual(game.highestCompletedLevel, 10)
        XCTAssertTrue(game.isUnlocked(.powerHammer))
        XCTAssertFalse(game.isUnlocked(.arcCannon))

        for _ in 0..<5 { completeCurrentLevel(game) }
        XCTAssertEqual(game.highestCompletedLevel, 15)
        XCTAssertTrue(game.isUnlocked(.arcCannon))
    }

    func testWorkshopChoicesPersistAndResetKeepsUnlocks() {
        let suiteName = "ROBTrainingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        for _ in 0..<5 { completeCurrentLevel(game) }
        game.selectFinish(.rescueOrange)
        game.selectRangedWeapon(.twinBlasters)
        game.reset()

        XCTAssertEqual(game.highestCompletedLevel, 5)
        XCTAssertEqual(game.robotFinish, .rescueOrange)
        XCTAssertEqual(game.rangedWeapon, .twinBlasters)

        let restored = GameSession(audioEnabled: false, progressStore: defaults)
        XCTAssertEqual(restored.highestCompletedLevel, 5)
        XCTAssertEqual(restored.robotFinish, .rescueOrange)
        XCTAssertEqual(restored.rangedWeapon, .twinBlasters)
    }

    func testSelectedLoadoutChangesVisibleRobotWeapons() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()
        game.selectFinish(.rescueOrange)
        RobotFactory.applyWeapons(to: robot, session: game)

        XCTAssertNotNil(robot.findEntity(named: "Applied Appearance rescueOrange"))
        XCTAssertTrue(robot.findEntity(named: "Right Shoulder Gatling")?.isEnabled == true)
        XCTAssertTrue(robot.findEntity(named: "Twin Blasters")?.isEnabled == false)
        XCTAssertTrue(robot.findEntity(named: "Left Lightsaber")?.isEnabled == true)
        XCTAssertTrue(robot.findEntity(named: "Power Hammer")?.isEnabled == false)

        for _ in 0..<10 { completeCurrentLevel(game) }
        game.selectRangedWeapon(.twinBlasters)
        game.selectMeleeWeapon(.powerHammer)
        RobotFactory.applyWeapons(to: robot, session: game)

        XCTAssertTrue(robot.findEntity(named: "Right Shoulder Gatling")?.isEnabled == false)
        XCTAssertTrue(robot.findEntity(named: "Twin Blasters")?.isEnabled == true)
        XCTAssertTrue(robot.findEntity(named: "Left Lightsaber")?.isEnabled == false)
        XCTAssertTrue(robot.findEntity(named: "Power Hammer")?.isEnabled == true)
    }

    func testArcCannonChainsDamageToANearbyTarget() {
        let game = GameSession(audioEnabled: false)
        for _ in 0..<15 { completeCurrentLevel(game) }
        game.reset()
        game.selectRangedWeapon(.arcCannon)
        game.begin()
        guard game.enemies.count >= 2 else { return XCTFail("Missing training targets") }
        for index in game.enemies.indices where index > 1 { game.enemies[index].isActive = false }
        game.enemies[0].position = game.robotPosition + SIMD3<Float>(0, 0, -1.7)
        game.enemies[1].position = game.robotPosition + SIMD3<Float>(0.65, 0, -1.75)
        let primaryShields = game.enemies[0].shields
        let secondaryShields = game.enemies[1].shields

        game.fireLaser()
        for _ in 0..<60 where game.laserDistance != nil { game.tick(1.0 / 60.0) }

        XCTAssertLessThanOrEqual(game.enemies[0].shields, primaryShields - 2)
        XCTAssertLessThan(game.enemies[1].shields, secondaryShields)
    }

    func testPowerHammerHasAHeavyForwardHit() {
        let game = GameSession(audioEnabled: false)
        for _ in 0..<10 { completeCurrentLevel(game) }
        game.selectMeleeWeapon(.powerHammer)
        guard let targetIndex = game.enemies.indices.first else { return XCTFail("Missing training target") }
        game.robotHeading = 0
        game.enemies[targetIndex].position = game.robotPosition + SIMD3<Float>(0, 0, -1.8)
        let shields = game.enemies[targetIndex].shields

        game.saberAttack()

        XCTAssertEqual(game.saberStyle, .hammerSmash)
        XCTAssertEqual(game.enemies[targetIndex].shields, shields - 2)
        XCTAssertTrue(game.message.localizedCaseInsensitiveContains("hammer"))
    }
}
