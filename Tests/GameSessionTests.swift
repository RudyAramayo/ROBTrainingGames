import XCTest
import ARKit
import AVFoundation
import Dispatch
@preconcurrency import MultipeerConnectivity
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
    func testVisionTankInputMapsEachStickToItsMatchingTreadWithADeadzone() {
        XCTAssertEqual(ROBTreadInput.tank(leftStickY: 0.08, rightStickY: -0.1), ROBTreadInput(left: 0, right: 0))

        let input = ROBTreadInput.tank(leftStickY: 1, rightStickY: -1)
        XCTAssertEqual(input.left, 1, accuracy: 0.001)
        XCTAssertEqual(input.right, -1, accuracy: 0.001)

        let partial = ROBTreadInput.tank(leftStickY: 0.56, rightStickY: 0.34)
        XCTAssertGreaterThan(partial.left, partial.right)
        XCTAssertGreaterThan(partial.right, 0)
    }

    private func alignLeanedHand(_ game: GameSession, with target: SIMD3<Float>, file: StaticString = #filePath, line: UInt = #line) {
        game.stopDrive()
        for _ in 0..<60 where game.saberAnimation > 0 { game.tick(1.0 / 60) }
        if !game.pickupLeanRequested { game.togglePickupLean() }
        for _ in 0..<40 { game.tick(1.0 / 60) }
        let targetFloor = game.puzzle.surfaceHeight(at: [target.x, target.z])
        var found = false
        for heading in [Float.pi, 0, Float.pi / 2, -Float.pi / 2] {
            game.robotHeading = heading
            let offset = game.cargoHandPosition - game.robotPosition
            let stance = SIMD3<Float>(target.x - offset.x, targetFloor, target.z - offset.z)
            if game.isRobotPositionClear(stance), abs(game.puzzle.surfaceHeight(at: [stance.x, stance.z]) - targetFloor) < 0.01 {
                game.robotPosition = stance; found = true; break
            }
        }
        XCTAssertTrue(found, "No clear same-height grasp stance on level \(game.level.id)", file: file, line: line)
        for _ in 0..<3 { game.tick(1.0 / 60) }
        XCTAssertTrue(game.isPickupGrounded, file: file, line: line)
        XCTAssertEqual(game.pickupLeanAmount, 1, accuracy: 0.001, file: file, line: line)
        XCTAssertLessThanOrEqual(simd_distance(game.cargoHandPosition, target), ROBPickupTask.reach * 1.35, file: file, line: line)
    }

    private func deliverCurrentCargo(_ game: GameSession, file: StaticString = #filePath, line: UInt = #line) {
        if !game.isRunning { game.begin() }
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        game.doorOpen = true
        alignLeanedHand(game, with: game.pickupTask.position, file: file, line: line)
        game.interactCargo()
        XCTAssertTrue(game.isCarryingCargo, game.message, file: file, line: line)
        alignLeanedHand(game, with: game.cargoDestination, file: file, line: line)
        let scoreBeforeDelivery = game.score
        game.interactCargo()
        XCTAssertTrue(game.isCargoDelivered, game.message, file: file, line: line)
        XCTAssertEqual(game.score, scoreBeforeDelivery + ROBPickupTask.reward, file: file, line: line)
    }

    private func completeCurrentLevel(_ game: GameSession) {
        deliverCurrentCargo(game)
        game.collectedCells = game.level.cellCount
        game.doorOpen = true
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        game.robotPosition = [game.puzzle.dock.x, game.puzzle.surfaceHeight(at: game.puzzle.dock), game.puzzle.dock.y]
        game.nextLevel()
        if game.isUpgradeIntermission { game.continueAfterUpgradeIntermission() }
    }

    func testCargoInteractionRequiresAStoppedGroundedLeanAndSupportsDropRecovery() {
        var task = ROBPickupTask(position: [0, 0.16, 0])
        let destination = SIMD3<Float>(2, 0.2, 0)
        func attempt(grounded: Bool = true, lean: Float = 1, speed: Double = 0,
                     hand: SIMD3<Float> = [0, 0.2, 0], clear: Bool = true, dropClear: Bool = true) -> ROBPickupTask.Event {
            task.interact(running: true, grounded: grounded, lean: lean, speed: speed,
                          hand: hand, destination: destination, dropPosition: [hand.x, 0.16, hand.z],
                          scale: 1.35, clear: clear, dropClear: dropClear)
        }
        XCTAssertEqual(attempt(grounded: false), .land)
        XCTAssertEqual(attempt(lean: 0.5), .lean)
        XCTAssertEqual(attempt(speed: 0.2), .stop)
        XCTAssertEqual(attempt(hand: [0, 1, 0]), .outOfReach)
        XCTAssertEqual(attempt(clear: false), .blocked)
        XCTAssertEqual(task.phase, .waiting)
        XCTAssertEqual(attempt(), .pickedUp)
        XCTAssertEqual(attempt(dropClear: false), .unsafeDrop)
        XCTAssertEqual(task.phase, .carrying)
        XCTAssertEqual(attempt(hand: [1, 0.2, 0]), .dropped)
        XCTAssertEqual(task.position, [1, 0.16, 0])
        XCTAssertEqual(attempt(hand: [1, 0.2, 0]), .pickedUp)
        XCTAssertEqual(attempt(hand: destination), .delivered)
        XCTAssertEqual(attempt(hand: destination), .inactive)
        XCTAssertEqual(task.position, destination)
    }

    func testAllCargoMissionsHaveReachableGraspAndDeliveryStancesAndResetCleanly() {
        let game = GameSession(audioEnabled: false)
        for index in game.levels.indices {
            game.levelIndex = index; game.begin()
            XCTAssertEqual(game.cargoKind, ROBCargoKind.allCases[index % 3])
            XCTAssertFalse(game.canFinish)
            deliverCurrentCargo(game)
            let deliveredScore = game.score
            game.interactCargo()
            XCTAssertEqual(game.score, deliveredScore)
            let room = RobotFactory.makeTrainingRoom(level: index, puzzle: game.puzzle)
            RobotFactory.applyPuzzleState(to: room, session: game)
            XCTAssertEqual(room.findEntity(named: "Mission Cargo")?.position, game.cargoDestination)
            game.begin()
            XCTAssertEqual(game.pickupTask.phase, .waiting)
            XCTAssertFalse(game.pickupLeanRequested)
            XCTAssertEqual(game.pickupLeanAmount, 0)
        }
    }

    func testCargoFollowsTheVisibleRightHandAndTheChassisStaysOnTheFloor() {
        let game = GameSession(audioEnabled: false); game.begin()
        for i in game.enemies.indices { game.enemies[i].isActive = false }
        alignLeanedHand(game, with: game.pickupTask.position)
        let robot = RobotFactory.makeROB()
        robot.position = game.robotPosition
        robot.orientation = simd_quatf(angle: game.robotHeading, axis: [0, 1, 0])
        RobotFactory.applyWeapons(to: robot, session: game)
        let hand = robot.findEntity(named: "Right Gripper Palm")
        XCTAssertNotNil(hand)
        if let hand {
            XCTAssertLessThan(simd_distance(hand.position(relativeTo: nil), game.cargoHandPosition), 0.001)
        }
        XCTAssertEqual(game.baseLiftPitch, 0, accuracy: 0.001)
        XCTAssertEqual(game.robotPosition.y, 0, accuracy: 0.001)
        game.interactCargo()
        for _ in 0..<45 { game.tick(1.0 / 60) }
        XCTAssertTrue(game.isCarryingCargo)
        XCTAssertEqual(game.pickupLeanAmount, 0, accuracy: 0.001)
        XCTAssertGreaterThan(game.cargoHandPosition.y, 0.4)
    }

    func testCalibrationMatchesBrowserCampaign() {
        let game = GameSession(audioEnabled: false)

        XCTAssertEqual(game.level.cellCount, 7)
        XCTAssertEqual(game.level.enemyShields, 4)
        XCTAssertTrue(game.enemies.allSatisfy { $0.shields == 4 && $0.maxShields == 4 })
        XCTAssertEqual(game.enemies.map(\.kind), [.spider, .fax, .spider])
        XCTAssertEqual(game.remainingEnemies, 3)
        XCTAssertEqual(game.levels.count, 24)
        XCTAssertGreaterThan(game.puzzle.arenaHalfExtent, 5)
    }

    func testLevelOneDockOpensUpgradeIntermissionBeforeAdvancing() {
        let game = GameSession(audioEnabled: false)
        game.begin()

        XCTAssertFalse(game.level.requiresKey)
        XCTAssertNil(game.puzzle.key)
        XCTAssertTrue(game.doorOpen)

        deliverCurrentCargo(game)
        game.collectedCells = game.level.cellCount
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        game.robotPosition = [game.puzzle.dock.x, 0, game.puzzle.dock.y]
        game.tick(1.0 / 30.0)

        XCTAssertEqual(game.level.id, 1)
        XCTAssertTrue(game.isUpgradeIntermission)
        XCTAssertFalse(game.isRunning)
        XCTAssertEqual(game.upgradePoints, 50)

        XCTAssertFalse(game.canPurchaseUpgrade(.speedBoost))
        game.purchaseUpgrade(.speedBoost)
        XCTAssertEqual(game.speedUpgradeLevel, 0)
        XCTAssertEqual(game.upgradePoints, 50)

        game.continueAfterUpgradeIntermission()
        XCTAssertEqual(game.level.id, 2)
        XCTAssertFalse(game.isUpgradeIntermission)
        XCTAssertTrue(game.isRunning)
    }

    func testLevelOneDockExplainsItsActualRemainingObjectives() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        game.robotPosition = [game.puzzle.dock.x, 0, game.puzzle.dock.y]

        game.tick(1.0 / 30.0)

        XCTAssertEqual(game.level.id, 1)
        XCTAssertTrue(game.message.contains("7 more energy cells"))
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

    func testMissionToggleStartsPausesAndResumesForVisionControllerMenuButton() {
        let game = GameSession(audioEnabled: false)

        game.toggleMission()
        XCTAssertTrue(game.isRunning)
        XCTAssertFalse(game.isPaused)

        game.toggleMission()
        XCTAssertFalse(game.isRunning)
        XCTAssertTrue(game.isPaused)

        game.toggleMission()
        XCTAssertTrue(game.isRunning)
        XCTAssertFalse(game.isPaused)
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
        XCTAssertEqual(renderedKey.position.y, RobotFactory.puzzleKeySurfaceOffset, accuracy: 0.0001)
        guard let beacon = renderedKey.findEntity(named: "Puzzle Key Beacon") else {
            return XCTFail("Every training key needs a vertical visibility beacon")
        }
        XCTAssertGreaterThan(beacon.position.y, RobotFactory.puzzleKeyBeaconHeight / 2)
        XCTAssertNotNil(renderedKey.findEntity(named: "Puzzle Key Beacon Tip"))
        XCTAssertNotNil(renderedKey.findEntity(named: "Puzzle Key Shaft"))
        XCTAssertNotNil(renderedKey.findEntity(named: "Puzzle Key Bow Segment 0"))
        XCTAssertNotNil(renderedKey.findEntity(named: "Puzzle Key Tooth 0"))
        XCTAssertGreaterThan(renderedKey.children.count, 16)

        game.robotPosition = [key.x, 0, key.y]
        game.tick(1.0 / 30.0)
        XCTAssertTrue(game.hasKey)
    }

    func testEveryKeyBearingLevelRendersTheVisibilityBeacon() {
        let game = GameSession(audioEnabled: false)

        for levelIndex in game.levels.indices where game.levels[levelIndex].requiresKey {
            game.levelIndex = levelIndex
            let room = RobotFactory.makeTrainingRoom(level: levelIndex, puzzle: game.puzzle)
            let key = room.findEntity(named: "Puzzle Key")
            XCTAssertNotNil(key, "Level \(game.level.id) did not render its key")
            XCTAssertNotNil(
                key?.findEntity(named: "Puzzle Key Beacon"),
                "Level \(game.level.id) key is missing its visibility line"
            )
        }
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

    func testVirtualArenasUsePBRSurfaceMaterialsAndFourLightRig() {
        let game = GameSession(audioEnabled: false)
        let room = RobotFactory.makeTrainingRoom(level: game.levelIndex, puzzle: game.puzzle)
        let floor = room.findEntity(named: "Training Floor") as? ModelEntity
        let wall = room.findEntity(named: "North Training Wall") as? ModelEntity
        let lightRig = room.findEntity(named: "Arena Light Rig")

        XCTAssertTrue(floor?.model?.materials.first is PhysicallyBasedMaterial)
        XCTAssertTrue(wall?.model?.materials.first is PhysicallyBasedMaterial)
        XCTAssertEqual(lightRig?.children.filter { $0.components[PointLightComponent.self] != nil }.count, 3)
        XCTAssertEqual(lightRig?.children.filter { $0.components[DirectionalLightComponent.self] != nil }.count, 1)

        let battleArena = ROBBattleFactory.makeArena(.neonFoundry)
        let battleFloor = battleArena.findEntity(named: "Deathmatch Floor") as? ModelEntity
        XCTAssertTrue(battleFloor?.model?.materials.first is PhysicallyBasedMaterial)
        XCTAssertNotNil(battleArena.findEntity(named: "Arena Light Rig"))
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
        XCTAssertTrue(game.enemies.contains { $0.travelDistance > 0 })

        for _ in 0..<600 where game.enemyAttackCount == 0 { game.tick(1.0 / 30.0) }

        XCTAssertGreaterThan(game.enemyAttackCount, 0)
        XCTAssertTrue(game.isRunning)
    }

    func testROBShieldAbsorbsDamageWithoutRestartingMissionProgress() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        XCTAssertTrue(game.activateShield())
        game.collectedCells = 1
        let enemyShields = game.enemies.map(\.shields)

        XCTAssertTrue(game.enemyContact("Spider bot lunge", damage: 6))

        XCTAssertEqual(game.shields, 34)
        XCTAssertEqual(game.health, game.maxHealth)
        XCTAssertEqual(game.collectedCells, 1)
        XCTAssertEqual(game.enemies.map(\.shields), enemyShields)
        XCTAssertTrue(game.isRunning)
        XCTAssertTrue(game.message.contains("6 shield points"))
        XCTAssertFalse(game.enemyContact("Overlapping collision", damage: 6), "The hit cooldown should prevent damage every rendered frame")
        XCTAssertEqual(game.shields, 34)
        XCTAssertEqual(game.health, game.maxHealth)
    }

    func testBubbleShieldRequiresActivationAndFadesAfterItsDefensiveWindow() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        let robot = RobotFactory.makeROB()

        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertFalse(game.isShieldActive)
        XCTAssertEqual(game.shieldActivationFraction, 0)
        XCTAssertFalse(robot.findEntity(named: "ROB Shield Field")?.isEnabled ?? true)

        XCTAssertTrue(game.activateShield())
        XCTAssertTrue(game.pause())
        XCTAssertFalse(game.isShieldActive)
        XCTAssertEqual(game.shieldTimeRemaining, 0)
        XCTAssertTrue(game.resume())

        XCTAssertTrue(game.enemyContact("Unshielded impact", damage: 6))
        XCTAssertEqual(game.shields, game.maxShields)
        XCTAssertEqual(game.health, game.maxHealth - 6)

        game.tick(0.8)
        XCTAssertTrue(game.activateShield())
        XCTAssertFalse(game.activateShield(), "An active shield cannot be extended by repeated taps")
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertTrue(game.isShieldActive)
        XCTAssertEqual(game.shieldActivationFraction, 1, accuracy: 0.001)
        XCTAssertTrue(robot.findEntity(named: "ROB Shield Field")?.isEnabled ?? false)

        XCTAssertTrue(game.enemyContact("Shielded impact", damage: 6))
        XCTAssertEqual(game.shields, game.maxShields - 6)
        XCTAssertEqual(game.health, game.maxHealth - 6)

        game.tick(GameSession.shieldActivationDuration / 2)
        XCTAssertEqual(game.shieldActivationFraction, 0.5, accuracy: 0.001)
        game.tick(GameSession.shieldActivationDuration / 2 + 0.01)
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertFalse(game.isShieldActive)
        XCTAssertEqual(game.shieldActivationFraction, 0)
        XCTAssertFalse(robot.findEntity(named: "ROB Shield Field")?.isEnabled ?? true)
    }

    func testDamageSpillsThroughAnEmptyShieldIntoHealth() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        XCTAssertTrue(game.activateShield())

        XCTAssertTrue(game.enemyContact("Heavy laser", damage: game.maxShields + 6))

        XCTAssertEqual(game.shields, 0)
        XCTAssertEqual(game.health, 94)
        XCTAssertTrue(game.message.contains("6 hull damage"))
        XCTAssertFalse(game.activateShield(), "An empty shield capacitor cannot create a bubble")
    }

    func testDepletedHealthRestartsOnlyTheCurrentLevel() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 2
        game.begin()
        game.collectedCells = 2

        game.enemyContact("Critical hit", damage: game.maxHealth + game.maxShields)

        XCTAssertEqual(game.level.id, 3)
        XCTAssertEqual(game.health, game.maxHealth)
        XCTAssertEqual(game.collectedCells, 0)
        XCTAssertEqual(game.lives, 2)
        XCTAssertTrue(game.isRunning)
        XCTAssertTrue(game.message.contains("2 remaining"))
        XCTAssertTrue(game.message.contains("Restarting level 3"))
    }

    func testThirdLifeLossWipesPointsAndUpgradesAndReturnsToLevelOne() {
        let suite = "ROBTrialSkills.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(2_000, forKey: GameSession.skillPointsStorageKey)
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        game.begin()
        game.purchaseUpgrade(.kyberCrystals)
        game.purchaseUpgrade(.speedBoost)
        XCTAssertEqual(game.speedUpgradeLevel, 1)
        XCTAssertGreaterThan(game.upgradePoints, 0)

        for expectedLives in [2, 1] {
            XCTAssertTrue(game.enemyContact("Trial impact", damage: game.maxHealth + game.maxShields))
            XCTAssertEqual(game.lives, expectedLives)
            XCTAssertTrue(game.isRunning)
            game.enemies = []
            game.tick(1.05)
        }
        XCTAssertTrue(game.enemyContact("Final trial impact", damage: game.maxHealth + game.maxShields))

        XCTAssertEqual(game.lives, 0)
        XCTAssertEqual(game.level.id, 1)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.upgradePoints, 0)
        XCTAssertEqual(game.speedUpgradeLevel, 0)
        XCTAssertEqual(game.kyberCrystalUpgradeLevel, 0)
        XCTAssertEqual(GameSession(audioEnabled: false, progressStore: defaults).upgradePoints, 0)
        XCTAssertFalse(game.isRunning)
        XCTAssertTrue(game.message.contains("All points and installed upgrades were lost"))

        game.begin()
        XCTAssertEqual(game.lives, GameSession.maximumTrialLives)
        XCTAssertTrue(game.isRunning)
    }

    func testEveryFifthLevelHasAnEscalatingBossThatDealsThirtyContactDamage() {
        let game = GameSession(audioEnabled: false)
        XCTAssertNil(game.activeBoss)
        let expectedBossShields = [4: 60, 9: 90, 14: 120]
        for levelIndex in [4, 9, 14] {
            game.levelIndex = levelIndex
            game.begin()
            guard let boss = game.activeBoss else { return XCTFail("Level \(levelIndex + 1) needs a boss") }
            XCTAssertTrue(boss.isBoss)
            XCTAssertEqual(boss.maxShields, expectedBossShields[levelIndex])
            XCTAssertEqual(boss.shields, boss.maxShields)
            XCTAssertEqual(boss.contactDamage, 30)
            XCTAssertEqual(boss.projectileDamage, 10)
        }

        guard let boss = game.activeBoss else { return XCTFail("Level 15 needs a boss") }
        XCTAssertTrue(game.activateShield())
        game.enemyContact(boss.displayName, damage: boss.contactDamage)
        XCTAssertEqual(game.shields, 10)
        XCTAssertEqual(game.health, game.maxHealth)
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
        XCTAssertGreaterThan(game.robotPosition.z, startingPosition.z, "ROB should approach the wall smoothly before stopping")
        XCTAssertTrue(game.message.localizedCaseInsensitiveContains("wall"))
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
        XCTAssertLessThan(game.robotPosition.z, safeZ, "ROB should use the available clearance instead of freezing before the wall")
    }

    func testROBReversesAndSlidesAwayFromExactWallContact() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        guard let wall = game.puzzle.barriers.first else { return XCTFail("Level needs an interior wall") }
        let contactZ = wall.center.y + wall.size.y / 2 + GameSession.robotCollisionRadius

        game.robotPosition = [wall.center.x, 0, contactZ]
        game.robotHeading = 0
        XCTAssertTrue(game.isRobotPositionClear(game.robotPosition))
        game.setDrive(forward: -1, steering: 0)
        game.tick(0.35)
        game.stopDrive()
        XCTAssertGreaterThan(game.robotPosition.z, contactZ + 0.1, "Reverse should release ROB from an exact wall contact")

        game.robotPosition = [wall.center.x, 0, contactZ]
        game.robotHeading = .pi / 4
        game.setDrive(forward: 1, steering: 0)
        game.tick(0.35)
        game.stopDrive()
        XCTAssertGreaterThan(abs(game.robotPosition.x - wall.center.x), 0.1, "Angled input should slide ROB along the wall")
        XCTAssertGreaterThanOrEqual(game.robotPosition.z, contactZ - 0.001, "Wall assist must not move ROB through the wall")
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
            XCTAssertEqual(game.puzzle.cells.count, game.level.cellCount)
            XCTAssertTrue(
                game.isRobotPositionClear(game.robotPosition),
                "Level \(game.level.id) starts ROB inside a wall collision envelope"
            )

            game.doorOpen = true
            var objectives = game.puzzle.cells + game.puzzle.shieldPickups + game.puzzle.repairPickups + [game.puzzle.dock]
            if let key = game.puzzle.key { objectives.append(key) }
            if let terminal = game.puzzle.hackTerminal { objectives.append(terminal) }
            for objective in objectives {
                XCTAssertTrue(
                    game.isRobotPositionClear([objective.x, game.puzzle.surfaceHeight(at: objective), objective.y]),
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

    func testConveyorArrowsPointAnimateAndWrapAlongTheTravelDirection() {
        XCTAssertEqual(
            RobotFactory.conveyorArrowOffset(baseOffset: 0, elapsed: 1, speed: 0.5, span: 2, direction: 1),
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            RobotFactory.conveyorArrowOffset(baseOffset: 0, elapsed: 1, speed: 0.5, span: 2, direction: -1),
            -0.5,
            accuracy: 0.001
        )

        for levelIndex in [1, 2] {
            let game = GameSession(audioEnabled: false)
            game.levelIndex = levelIndex
            game.begin()
            guard let conveyor = game.puzzle.conveyors.first else {
                return XCTFail("Level \(levelIndex + 1) needs a conveyor")
            }
            let room = RobotFactory.makeTrainingRoom(level: game.levelIndex, puzzle: game.puzzle)
            guard let zone = room.findEntity(named: "Conveyor 0"),
                  let leftStripe = room.findEntity(named: "Conveyor Arrow 0 0 0"),
                  let rightStripe = room.findEntity(named: "Conveyor Arrow 0 0 1") else {
                return XCTFail("Missing animated conveyor arrows")
            }

            let worldDirection = SIMD3<Float>(conveyor.direction.x, 0, conveyor.direction.y)
            let localDirection = zone.orientation.inverse.act(worldDirection)
            let travelDirection: Float = localDirection.z < 0 ? -1 : 1
            for stripe in [leftStripe, rightStripe] {
                let stripeTowardTip = stripe.orientation.act(SIMD3<Float>(0, 0, travelDirection))
                XCTAssertLessThan(
                    stripeTowardTip.x * stripe.position.x,
                    0,
                    "Each arrow stroke should converge into a tip facing the conveyor travel direction"
                )
            }

            let initialOffset = leftStripe.position.z
            game.elapsed = 1
            RobotFactory.applyPuzzleState(to: room, session: game)
            XCTAssertNotEqual(leftStripe.position.z, initialOffset, accuracy: 0.001)
        }
    }

    func testSecurityCameraAlertsEnemiesButShadowsBreakDetection() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 2
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        let combatLayer = RobotFactory.makeCombatLayer(session: game)
        guard let camera = game.puzzle.securityCameras.first, let shadow = game.puzzle.shadowZones.first else {
            return XCTFail("Level 3 needs camera and shadow geometry")
        }
        let heading = game.securityCameraHeading(camera)
        let forward = SIMD2<Float>(-sin(heading), -cos(heading))
        let seenPoint = camera.position + forward * 1.2
        game.robotPosition = [seenPoint.x, 0, seenPoint.y]

        game.tick(0.001)

        XCTAssertTrue(game.isSecurityAlerted)
        let miniBosses = game.enemies.filter(\.isMiniBoss)
        XCTAssertEqual(miniBosses.count, 1)
        XCTAssertEqual(miniBosses[0].shields, 6)
        XCTAssertEqual(miniBosses[0].contactDamage, 12)
        XCTAssertEqual(miniBosses[0].combatScale, 1.15)
        RobotFactory.applyCombatState(to: combatLayer, session: game)
        XCTAssertNotNil(combatLayer.findEntity(named: "Training Enemy \(miniBosses[0].id)"))
        game.robotPosition = [shadow.center.x, 0, shadow.center.y]
        XCTAssertTrue(game.isInShadow)
        game.tick(5.1)
        XCTAssertFalse(game.isSecurityAlerted)
        game.robotPosition = [seenPoint.x, 0, seenPoint.y]
        game.tick(0.001)
        XCTAssertEqual(game.enemies.filter(\.isMiniBoss).count, 1)
    }

    func testFlipperZeroHacksNearbyCameraAndDisablesItsSensorAndVisionCone() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 2
        game.begin()
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        guard let camera = game.puzzle.securityCameras.first else {
            return XCTFail("Level 3 needs a hackable security camera")
        }
        let pointsBeforeHack = game.upgradePoints
        game.robotPosition = [camera.position.x, 0, camera.position.y]

        XCTAssertTrue(game.hasFlipperHackTargets)
        XCTAssertTrue(game.canStartCameraHack)
        XCTAssertEqual(game.flipperHackDescription, "Hack camera")
        game.startFlipperHack()
        XCTAssertEqual(game.hackingCameraID, camera.id)
        game.tick(1.1)
        XCTAssertEqual(game.hackingProgress, 0.5, accuracy: 0.02)

        game.tick(1.2)

        XCTAssertNil(game.hackingCameraID)
        XCTAssertTrue(game.disabledSecurityCameraIDs.contains(camera.id))
        XCTAssertEqual(game.upgradePoints, pointsBeforeHack, "Hacks award score, not spendable skill points")
        XCTAssertEqual(game.securityCameraHeading(camera), camera.heading, accuracy: 0.0001)
        XCTAssertTrue(game.securityCameraVisionDistances(for: camera, rayCount: 5).allSatisfy { $0 == 0 })
        let forward = SIMD2<Float>(-sin(camera.heading), -cos(camera.heading))
        XCTAssertFalse(game.securityCameraCanSee(camera.position + forward, camera: camera))

        let room = RobotFactory.makeTrainingRoom(level: game.levelIndex, puzzle: game.puzzle)
        RobotFactory.applyPuzzleState(to: room, session: game)
        XCTAssertFalse(room.findEntity(named: "Security Camera Beam \(camera.id)")?.isEnabled ?? true)
    }

    func testSecurityCameraDetectionAndRedVisionFanStopAtWalls() {
        let camera = PuzzleSecurityCamera(id: 0, position: [0, 2], heading: 0, sweep: 0, range: 8)
        let wall = PuzzleBarrier(center: [0, 0], size: [8, 0.2])

        XCTAssertTrue(GameSession.securityCameraCanSee([0, 1], camera: camera, heading: 0, blockers: [wall]))
        XCTAssertFalse(GameSession.securityCameraCanSee([0, -2], camera: camera, heading: 0, blockers: [wall]))

        let distances = GameSession.securityCameraVisionDistances(
            camera: camera,
            heading: 0,
            blockers: [wall],
            rayCount: 49
        )
        XCTAssertEqual(distances.count, 49)
        XCTAssertTrue(distances.allSatisfy { $0 < 2.4 })
        XCTAssertTrue(GameSession.securityCameraVisionDistances(
            camera: camera,
            heading: 0,
            blockers: [],
            rayCount: 5
        ).allSatisfy { $0 == camera.range })
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

    func testShieldAndRepairPickupsRestoreDamageAndDisappear() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        XCTAssertTrue(game.activateShield())
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        let room = RobotFactory.makeTrainingRoom(level: game.levelIndex, puzzle: game.puzzle)

        XCTAssertNotNil(room.findEntity(named: "Shield Pickup 0"))
        XCTAssertNotNil(room.findEntity(named: "Repair Pickup 0"))
        game.enemyContact("Heavy laser", damage: game.maxShields + 10)
        XCTAssertEqual(game.shields, 0)
        XCTAssertEqual(game.health, 90)

        let shieldPickup = game.puzzle.shieldPickups[0]
        game.robotPosition = [shieldPickup.x, 0, shieldPickup.y]
        game.tick(0.01)
        XCTAssertEqual(game.shields, game.shieldPickupStrength)

        let repairPickup = game.puzzle.repairPickups[0]
        game.robotPosition = [repairPickup.x, 0, repairPickup.y]
        game.tick(0.01)
        XCTAssertEqual(game.health, game.maxHealth)

        RobotFactory.applyPuzzleState(to: room, session: game)
        XCTAssertFalse(room.findEntity(named: "Shield Pickup 0")?.isEnabled ?? true)
        XCTAssertFalse(room.findEntity(named: "Repair Pickup 0")?.isEnabled ?? true)
    }

    func testMaxLaserPowerCannotMakeBasicSabersInstantlyDefeatEnemies() {
        let suite = "ROBSaberSkills.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(3, forKey: "robWeaponUpgradeLevel")
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        game.begin(); game.enemies = [game.enemies[0]]
        XCTAssertEqual(game.weaponDamageBonus, 3)
        game.collectCell()
        XCTAssertEqual(game.upgradePoints, 0, "Pickups give score and energy, not skill points")
        for strike in 1...4 {
            game.enemies[0].position = game.robotPosition + [0, 0, -1]
            game.saberAttack()
            XCTAssertEqual(game.enemies[0].shields, 4 - strike)
            XCTAssertEqual(game.enemies[0].isActive, strike < 4)
            XCTAssertEqual(game.upgradePoints, strike < 4 ? 0 : 20)
            game.tick(0.9)
        }
        game.saberAttack()
        XCTAssertEqual(game.upgradePoints, 20, "A defeated target cannot pay out again")
    }

    func testKyberCrystalsIncreaseSaberDamageAndRequireLaterLevels() {
        let suite = "ROBKyberRanks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(10_000, forKey: GameSession.skillPointsStorageKey)
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        game.begin(); game.enemies = [game.enemies[0]]
        game.purchaseUpgrade(.kyberCrystals)
        XCTAssertEqual(game.saberDamage, 2)
        XCTAssertEqual(game.weaponDamageBonus, 0)
        game.enemies[0].position = game.robotPosition + [0, 0, -1]
        game.saberAttack()
        XCTAssertEqual(game.enemies[0].shields, 2)
        XCTAssertTrue(game.enemies[0].isActive)
        let balance = game.upgradePoints
        game.purchaseUpgrade(.kyberCrystals)
        XCTAssertEqual(game.upgradePoints, balance)
        XCTAssertEqual(game.kyberCrystalUpgradeLevel, 1)
        XCTAssertTrue(game.upgradeLockReason(.kyberCrystals)?.contains("Level 5") == true)
        for _ in 0..<5 { completeCurrentLevel(game) }
        game.purchaseUpgrade(.kyberCrystals)
        XCTAssertEqual(game.saberDamage, 3)
        game.purchaseUpgrade(.kyberCrystals)
        XCTAssertEqual(game.kyberCrystalUpgradeLevel, 2)
        XCTAssertTrue(game.upgradeLockReason(.kyberCrystals)?.contains("Level 10") == true)
        for _ in 0..<5 { completeCurrentLevel(game) }
        game.purchaseUpgrade(.kyberCrystals)
        XCTAssertEqual(game.saberDamage, 4)
        XCTAssertFalse(game.canPurchaseUpgrade(.kyberCrystals))
        XCTAssertNil(game.upgradeLockReason(.kyberCrystals))
        XCTAssertEqual(GameSession(audioEnabled: false, progressStore: defaults).kyberCrystalUpgradeLevel, 3)
    }

    func testLegacySkillPointsConvertOnceAndKeepPurchasedUpgrades() {
        let suite = "ROBSkillMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(13_100, forKey: "robUpgradePoints")
        defaults.set(3, forKey: "robWeaponUpgradeLevel")
        defaults.set(3, forKey: "robHighestCompletedLevel")
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        XCTAssertEqual(game.upgradePoints, 1_310)
        XCTAssertEqual(game.weaponUpgradeLevel, 3)
        XCTAssertEqual(game.highestCompletedLevel, 3)
        XCTAssertTrue(game.message.contains("converted"))
        game.purchaseUpgrade(.kyberCrystals)
        XCTAssertEqual(game.upgradePoints, 710)
        defaults.set(99_999, forKey: "robUpgradePoints") // An old client still writing the legacy balance.
        let restored = GameSession(audioEnabled: false, progressStore: defaults)
        XCTAssertEqual(restored.upgradePoints, 710)
        XCTAssertEqual(restored.kyberCrystalUpgradeLevel, 1)
        defaults.set(0, forKey: GameSession.skillPointsStorageKey)
        XCTAssertEqual(GameSession(audioEnabled: false, progressStore: defaults).upgradePoints, 0)
    }

    func testEnemyContactMakesCloseCombatDangerous() {
        for (kind, damage): (TrainingEnemyKind, Int) in [(.spider, 18), (.fax, 15)] {
            let game = GameSession(audioEnabled: false)
            game.begin()
            guard let enemy = game.enemies.first(where: { $0.kind == kind }) else { return XCTFail("Missing enemy") }
            XCTAssertEqual(enemy.contactDamage, damage)
            game.enemyContact(enemy.displayName, damage: enemy.contactDamage)
            XCTAssertEqual(game.health, 100 - damage)
        }
    }

    func testFinalLevelPaysItsSkillRewardOnlyOnce() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = game.levels.count - 1; game.begin()
        deliverCurrentCargo(game)
        game.robotPosition = [game.puzzle.dock.x, game.puzzle.surfaceHeight(at: game.puzzle.dock), game.puzzle.dock.y]
        game.collectedCells = game.level.cellCount; game.doorOpen = true
        for index in game.enemies.indices { game.enemies[index].isActive = false }
        game.nextLevel()
        XCTAssertEqual(game.upgradePoints, 190)
        let score = game.score
        game.nextLevel()
        XCTAssertEqual(game.upgradePoints, 190)
        XCTAssertEqual(game.score, score)
    }

    func testPerformanceUpgradesSpendPersistentPointsAndIncreaseCapabilities() {
        let suiteName = "ROBTrainingUpgrades.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(5_000, forKey: GameSession.skillPointsStorageKey)
        let game = GameSession(audioEnabled: false, progressStore: defaults)

        game.purchaseUpgrade(.speedBoost)
        game.purchaseUpgrade(.energyCapacity)
        game.purchaseUpgrade(.weaponPower)
        game.purchaseUpgrade(.targetingComputer)

        XCTAssertEqual(game.speedUpgradeLevel, 1)
        XCTAssertEqual(game.energyUpgradeLevel, 1)
        XCTAssertEqual(game.weaponUpgradeLevel, 1)
        XCTAssertEqual(game.targetingComputerUpgradeLevel, 1)
        XCTAssertTrue(game.hasIndependentTwinTargeting)
        XCTAssertEqual(GameSession.baseDriveSpeed, 1.2, accuracy: 0.0001)
        XCTAssertEqual(game.maxEnergy, 160)
        XCTAssertEqual(game.energy, 160)
        XCTAssertEqual(game.driveSpeedMultiplier, 1.6, accuracy: 0.0001)
        XCTAssertEqual(game.energyPickupAmount, 90)
        XCTAssertEqual(game.passiveEnergyRecharge, 9)
        XCTAssertEqual(game.weaponDamageBonus, 1)
        let restored = GameSession(audioEnabled: false, progressStore: defaults)
        XCTAssertEqual(restored.speedUpgradeLevel, 1)
        XCTAssertEqual(restored.energyUpgradeLevel, 1)
        XCTAssertEqual(restored.weaponUpgradeLevel, 1)
        XCTAssertEqual(restored.targetingComputerUpgradeLevel, 1)
        XCTAssertTrue(restored.hasIndependentTwinTargeting)
        XCTAssertEqual(restored.maxEnergy, 160)
        XCTAssertEqual(restored.driveSpeedMultiplier, 1.6, accuracy: 0.0001)
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

    func testSpeedUpgradesPreserveSlowerSteeringWhileIncreasingTravel() {
        var turns: [Float] = [], distances: [Float] = []
        for rank in [0, 3] {
            let suite = "ROBSteering.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(rank, forKey: "robSpeedUpgradeLevel")
            let game = GameSession(audioEnabled: false, progressStore: defaults)
            game.begin()
            for index in game.enemies.indices { game.enemies[index].isActive = false }
            let start = game.robotPosition
            game.setTreads(left: -1, right: 1)
            for _ in 0..<60 { game.tick(1.0 / 60) }
            turns.append(game.robotHeading)
            XCTAssertGreaterThan(game.robotHeading, .pi / 2)
            XCTAssertLessThan(game.robotHeading, 2.2, "Full joystick turn stays below 126 degrees per second")
            XCTAssertEqual(simd_distance(game.robotPosition, start), 0, accuracy: 0.001)

            game.begin()
            for index in game.enemies.indices { game.enemies[index].isActive = false }
            let driveStart = game.robotPosition
            game.setDrive(forward: 1, steering: 0)
            for _ in 0..<30 { game.tick(1.0 / 60) }
            distances.append(simd_distance(game.robotPosition, driveStart))
        }
        XCTAssertEqual(turns[0], turns[1], accuracy: 0.001)
        XCTAssertGreaterThan(distances[1], distances[0] * 2.7)
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

    func testEnemyModelsExposeAnimatedCrawlAndShooterDriveParts() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        let layer = RobotFactory.makeCombatLayer(session: game)
        guard
            let spiderIndex = game.enemies.firstIndex(where: { $0.kind == .spider }),
            let shooterIndex = game.enemies.firstIndex(where: { $0.kind == .fax }),
            let spider = layer.findEntity(named: "Training Enemy \(game.enemies[spiderIndex].id)"),
            let shooter = layer.findEntity(named: "Training Enemy \(game.enemies[shooterIndex].id)"),
            let spiderHip = spider.findEntity(named: "Spider Left Leg 1 Hip"),
            let shooterWheel = shooter.findEntity(named: "Shooter Left Wheel 1")
        else { return XCTFail("Missing articulated enemy model parts") }

        for side in ["Left", "Right"] {
            for legIndex in 1...4 {
                XCTAssertNotNil(spider.findEntity(named: "Spider \(side) Leg \(legIndex) Hip"))
                XCTAssertNotNil(spider.findEntity(named: "Spider \(side) Leg \(legIndex) Knee"))
            }
            for wheelIndex in 1...3 {
                XCTAssertNotNil(shooter.findEntity(named: "Shooter \(side) Wheel \(wheelIndex)"))
            }
        }
        XCTAssertNotNil(shooter.findEntity(named: "Shooter Turret Assembly"))

        let startingHipOrientation = spiderHip.orientation.vector
        let startingWheelOrientation = shooterWheel.orientation.vector
        game.enemies[spiderIndex].travelDistance += 0.35
        game.enemies[shooterIndex].travelDistance += 0.35
        RobotFactory.applyCombatState(to: layer, session: game)

        XCTAssertNotEqual(spiderHip.orientation.vector, startingHipOrientation)
        XCTAssertNotEqual(shooterWheel.orientation.vector, startingWheelOrientation)
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

        game.tick(0.5)
        game.robotPosition = [0, 0, -2.2]
        game.enemies[spiderIndex].position = [0, 0, -3.2]
        game.robotHeading = 0
        game.saberAttack()

        XCTAssertEqual(game.enemies[spiderIndex].shields, shields - 1)
        XCTAssertTrue(game.message.contains("dual-saber"))
    }

    func testWallOccludesTargetWithoutCancelingSaberAnimation() {
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
        XCTAssertEqual(game.saberAnimation, 1)
        XCTAssertEqual(game.saberStyle, .leftSweep)
        XCTAssertTrue(game.message.localizedCaseInsensitiveContains("missed"))
        XCTAssertFalse(game.message.localizedCaseInsensitiveContains("blocked by the wall"))
    }

    func testNearbyWallDoesNotCancelSpinAttackAgainstRobotsOnTheSameSide() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        guard let wall = game.puzzle.barriers.first, let targetIndex = game.enemies.indices.first else { return XCTFail("Missing wall or target") }
        for index in game.enemies.indices where index != targetIndex { game.enemies[index].isActive = false }
        let z = wall.center.y + wall.size.y / 2 + GameSession.robotCollisionRadius + 0.03
        game.robotPosition = [wall.center.x, 0, z]
        game.robotHeading = .pi / 2
        game.enemies[targetIndex].position = [wall.center.x - 1, 0, z]
        game.enemies[targetIndex].shields = 10
        let shields = game.enemies[targetIndex].shields

        game.saberAttack(); game.tick(0.5)
        game.saberAttack(); game.tick(0.5)
        game.saberAttack()

        XCTAssertEqual(game.saberStyle, .spin)
        XCTAssertEqual(game.enemies[targetIndex].shields, shields - 3)
        XCTAssertTrue(game.message.localizedCaseInsensitiveContains("spin attack"))
    }

    func testROBCannotDriveThroughAnotherRobotEvenWithALargeFrameStep() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        guard let targetIndex = game.enemies.indices.first else { return XCTFail("Missing target") }
        for index in game.enemies.indices where index != targetIndex { game.enemies[index].isActive = false }
        let start = game.robotPosition
        game.enemies[targetIndex].position = [start.x, 0, start.z - 1.35]
        game.enemies[targetIndex].nextAttack = .infinity
        let requiredSeparation = GameSession.robotCollisionRadius + game.enemies[targetIndex].collisionRadius

        game.setDrive(forward: 1, steering: 0)
        game.tick(2)
        game.stopDrive()

        let separation = simd_distance(
            SIMD2<Float>(game.robotPosition.x, game.robotPosition.z),
            SIMD2<Float>(game.enemies[targetIndex].position.x, game.enemies[targetIndex].position.z)
        )
        XCTAssertGreaterThanOrEqual(separation, requiredSeparation - 0.002)
        XCTAssertGreaterThan(game.robotPosition.z, game.enemies[targetIndex].position.z)
    }

    func testEnemiesKeepTheirScaledBodyVolumesSeparated() {
        let game = GameSession(audioEnabled: false)
        game.levelIndex = 14
        game.begin()
        guard game.enemies.count >= 3, game.enemies[0].isBoss, game.enemies[2].kind == .spider else { return XCTFail("Missing boss pair") }
        for index in game.enemies.indices where index != 0 && index != 2 { game.enemies[index].isActive = false }
        let start = game.robotPosition
        game.enemies[0].position = [start.x, 0, start.z - 1.4]
        game.enemies[0].nextAttack = .infinity
        game.enemies[2].position = [start.x, 0, start.z - 2.35]
        game.enemies[2].nextAttack = .infinity
        game.enemies[2].lungeRemaining = 0.72
        let requiredSeparation = game.enemies[0].collisionRadius + game.enemies[2].collisionRadius

        for _ in 0..<60 {
            game.tick(1.0 / 60.0)
            let separation = simd_distance(
                SIMD2<Float>(game.enemies[0].position.x, game.enemies[0].position.z),
                SIMD2<Float>(game.enemies[2].position.x, game.enemies[2].position.z)
            )
            XCTAssertGreaterThanOrEqual(separation, requiredSeparation - 0.002)
        }
    }

    func testSaberBladesStayVisibleBeforeDuringAndAfterAttack() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()
        game.begin()

        RobotFactory.applyWeapons(to: robot, session: game)
        guard let blade = robot.findEntity(named: "Left Lightsaber") else { return XCTFail("Missing saber") }
        XCTAssertEqual(blade.scale.y, 1, accuracy: 0.001)

        game.robotPosition = [0, 0, -2.2]
        game.robotHeading = 0
        game.saberAttack()
        RobotFactory.applyWeapons(to: robot, session: game)

        XCTAssertEqual(blade.scale.y, 1, accuracy: 0.001)
        game.tick(0.6)
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertEqual(blade.scale.y, 1, accuracy: 0.001)
        XCTAssertTrue(blade.isEnabled)
    }

    func testSaberRecoveryIsContinuousAndCannotRepeatDamage() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()
        game.begin()
        game.enemies = [game.enemies[0]]
        game.enemies[0].position = game.robotPosition + [0, 0, -1]
        game.enemies[0].shields = 10
        game.saberAttack()
        let shieldsAfterStrike = game.enemies[0].shields
        XCTAssertEqual(shieldsAfterStrike, 9)
        game.tick(0.25)
        let remaining = game.saberAnimation
        game.saberAttack()
        XCTAssertEqual(game.saberAnimation, remaining, "Repeated input cannot restart a swing mid-pose")
        game.tick(0.25)
        XCTAssertEqual(game.enemies[0].shields, shieldsAfterStrike, "Recovery is visual, not a second hit")
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertEqual(robot.findEntity(named: "Left Arm Assembly")?.orientation, simd_quatf(angle: 0, axis: [0, 1, 0]))

        for style: SaberAttackStyle in [.leftSweep, .rightSweep, .spin, .hammerSmash] {
            var previous = simd_quatf(angle: 0, axis: [0, 1, 0])
            for frame in 0...120 {
                let pose = ROBMeleeAnimation.pose(style, progress: Float(frame) / 120)
                let orientation = simd_quatf(angle: pose.torsoYaw + pose.armYaw, axis: [0, 1, 0])
                    * simd_quatf(angle: pose.armRoll, axis: [0, 0, 1])
                    * simd_quatf(angle: pose.hammerPitch, axis: [1, 0, 0])
                XCTAssertGreaterThan(abs(simd_dot(previous.vector, orientation.vector)), 0.998, "No snap at start, turnaround, or finish")
                previous = orientation
            }
            XCTAssertEqual(abs(previous.real), 1, accuracy: 0.00001)
        }
        let strike = ROBMeleeAnimation.pose(.leftSweep, progress: 0.45)
        let recovery = ROBMeleeAnimation.pose(.leftSweep, progress: 0.75)
        XCTAssertLessThan(abs(recovery.armYaw), abs(strike.armYaw))
        XCTAssertLessThan(recovery.armYaw, 0, "Recovery retraces the sweep")
    }

    func testThirdSaberPressTriggersSpinAndHitsBehindROB() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        let index = game.enemies.startIndex
        game.robotPosition = [0, 0, -2.65]
        game.enemies[index].position = game.robotPosition + SIMD3<Float>(0, 0, 1.25)
        let shields = game.enemies[index].shields

        game.saberAttack(); game.tick(0.5)
        game.saberAttack(); game.tick(0.5)
        XCTAssertEqual(game.enemies[index].shields, shields)
        game.saberAttack()

        XCTAssertEqual(game.saberStyle, .spin)
        XCTAssertEqual(game.enemies[index].shields, shields - 1)
        XCTAssertTrue(game.message.contains("Spin attack"))
    }

    func testBattleHitsAddScoreWithoutAwardingSkillPoints() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        guard let targetIndex = game.enemies.indices.first else { return XCTFail("Missing training target") }
        for index in game.enemies.indices where index != targetIndex { game.enemies[index].isActive = false }
        game.enemies[targetIndex].position = game.robotPosition + SIMD3<Float>(0, 0, -1.7)
        let pointsBeforeHit = game.upgradePoints

        game.fireLaser()
        for _ in 0..<90 where !game.laserProjectiles.isEmpty { game.tick(1.0 / 60.0) }

        XCTAssertEqual(game.upgradePoints, pointsBeforeHit)
        XCTAssertGreaterThanOrEqual(game.score, 50)
    }

    func testManualShoulderLaserChargedShotSpendsEnergyAndDealsMoreDamage() {
        let game = GameSession(audioEnabled: false)
        game.begin()
        guard let targetIndex = game.enemies.indices.first else { return XCTFail("Missing training target") }
        for index in game.enemies.indices where index != targetIndex { game.enemies[index].isActive = false }
        game.enemies[targetIndex].position = game.robotPosition + SIMD3<Float>(0, 0, -1.7)
        let shields = game.enemies[targetIndex].shields

        game.beginLaserCharge()
        game.tick(1.5)
        let energyBeforeShot = game.energy
        game.releaseLaserCharge()

        XCTAssertFalse(game.isChargingLaser)
        XCTAssertGreaterThan(game.laserShotCharge, 0.7)
        XCTAssertEqual(
            game.energy,
            energyBeforeShot - ROBRangedWeapon.shoulderGatling.energyCost(charge: game.laserShotCharge),
            accuracy: 0.001
        )
        XCTAssertEqual(game.enemies[targetIndex].shields, shields, "Firing should not damage a target before the projectile arrives")
        XCTAssertNotNil(game.laserDistance)

        for _ in 0..<60 where game.laserDistance != nil { game.tick(1.0 / 60.0) }

        XCTAssertLessThanOrEqual(game.enemies[targetIndex].shields, shields - 2)
        XCTAssertNil(game.laserDistance)
    }

    func testEveryLaserRequiresTheComputerUpgradeForAutoLock() {
        let suite = "ROBTargeting.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(15, forKey: "robHighestCompletedLevel")
        for weapon in ROBRangedWeapon.allCases {
            defaults.set(1_200, forKey: GameSession.skillPointsStorageKey)
            defaults.set(0, forKey: "robTargetingComputerUpgradeLevel")
            let game = GameSession(audioEnabled: false, progressStore: defaults)
            game.selectRangedWeapon(weapon); game.begin()
            for index in game.enemies.indices { game.enemies[index].position = game.robotPosition + [2 + Float(index), 0, -2] }
            game.tick(0.01)
            XCTAssertNil(game.lockedEnemy); XCTAssertNil(game.secondaryLockedEnemy)
            let basicCycle = game.laserCycleDuration, basicCharge = game.laserChargeDuration
            let robot = RobotFactory.makeROB()
            RobotFactory.applyWeapons(to: robot, session: game)
            XCTAssertFalse(robot.findEntity(named: "Gatling Lock Indicator")!.isEnabled)
            let energy = game.energy
            game.fireLaser()
            XCTAssertTrue(game.laserProjectiles.allSatisfy { $0.targetID == nil && $0.heading == game.robotHeading })
            XCTAssertEqual(game.energy, energy - weapon.energyCost(charge: 0), accuracy: 0.0001)
            game.purchaseUpgrade(.targetingComputer)
            game.tick(0.01)
            XCTAssertNotNil(game.lockedEnemy)
            XCTAssertEqual(game.secondaryLockedEnemy != nil, weapon == .twinBlasters)
            XCTAssertLessThan(game.laserCycleDuration, basicCycle)
            XCTAssertLessThan(game.laserChargeDuration, basicCharge)
            RobotFactory.applyWeapons(to: robot, session: game)
            XCTAssertTrue(robot.findEntity(named: "Gatling Lock Indicator")!.isEnabled)
        }
    }

    func testManualMissSpendsEnergyAndRechargeWaitsUntilFiringStops() {
        let game = GameSession(audioEnabled: false)
        game.begin(); game.enemies = []
        game.robotPosition = [0, 0, 2.8] // A wall stops the forward shot quickly.
        game.fireLaser()
        XCTAssertEqual(game.energy, 92, accuracy: 0.0001)
        game.tick(0.5)
        XCTAssertTrue(game.laserProjectiles.isEmpty)
        XCTAssertEqual(game.energy, 92, accuracy: 0.0001)
        game.fireLaser()
        XCTAssertTrue(game.laserProjectiles.isEmpty, "The basic computer still needs its 0.8 second cycle")
        game.tick(0.31)
        game.fireLaser()
        XCTAssertFalse(game.laserProjectiles.isEmpty)
        XCTAssertEqual(game.energy, 84, accuracy: 0.0001)
        game.tick(0.5)
        game.beginLaserCharge() // Still cooling down.
        XCTAssertFalse(game.isChargingLaser)
        game.tick(0.31)
        game.beginLaserCharge()
        XCTAssertTrue(game.isChargingLaser)
        game.tick(2)
        XCTAssertEqual(game.energy, 84, accuracy: 0.0001, "Holding charge cannot refill the battery")
        game.releaseLaserCharge()
        XCTAssertEqual(game.energy, 60, accuracy: 0.0001)
        game.tick(1)
        XCTAssertEqual(game.energy, 60, accuracy: 0.0001)
        game.tick(1)
        XCTAssertGreaterThan(game.energy, 60)
    }

    func testInsufficientEnergyBlocksChargedAndUnchargedManualShots() {
        let game = GameSession(audioEnabled: false)
        game.begin(); game.enemies = []
        game.setDrive(forward: 0, steering: 1)
        game.tick(30)
        game.stopDrive()
        XCTAssertEqual(game.energy, 0, accuracy: 0.0001)
        game.fireLaser(); game.beginLaserCharge()
        XCTAssertTrue(game.laserProjectiles.isEmpty)
        XCTAssertFalse(game.isChargingLaser)
        game.tick(2) // Twelve units cover a basic shot, but not a charged shot.
        game.beginLaserCharge(); game.tick(2)
        XCTAssertTrue(game.isChargingLaser)
        let energy = game.energy
        game.releaseLaserCharge()
        XCTAssertTrue(game.laserProjectiles.isEmpty)
        XCTAssertEqual(game.energy, energy)
    }

    func testEveryRangedWeaponUsesMoreEnergyForChargedShots() {
        XCTAssertEqual(ROBRangedWeapon.shoulderGatling.energyCost(charge: 0), 8, accuracy: 0.001)
        XCTAssertEqual(ROBRangedWeapon.shoulderGatling.energyCost(charge: 1), 24, accuracy: 0.001)
        XCTAssertEqual(ROBRangedWeapon.twinBlasters.energyCost(charge: 0), 10, accuracy: 0.001)
        XCTAssertEqual(ROBRangedWeapon.twinBlasters.energyCost(charge: 1), 28, accuracy: 0.001)
        XCTAssertEqual(ROBRangedWeapon.arcCannon.energyCost(charge: 0), 16, accuracy: 0.001)
        XCTAssertEqual(ROBRangedWeapon.arcCannon.energyCost(charge: 1), 44, accuracy: 0.001)
    }

    func testTwinBlastersFireForwardWithoutAnyLockBeforeTargetingUpgrade() {
        let game = GameSession(audioEnabled: false)
        for _ in 0..<5 { completeCurrentLevel(game) }
        game.selectRangedWeapon(.twinBlasters)
        game.begin()
        guard game.enemies.count >= 2 else { return XCTFail("Missing training targets") }
        for index in game.enemies.indices where index > 1 { game.enemies[index].isActive = false }
        game.enemies[0].position = game.robotPosition + SIMD3<Float>(-0.45, 0, -1.7)
        game.enemies[1].position = game.robotPosition + SIMD3<Float>(0.45, 0, -1.9)

        game.fireLaser()

        XCTAssertEqual(game.laserProjectiles.count, 2)
        XCTAssertEqual(Set(game.laserProjectiles.map(\.barrel)), [.left, .right])
        XCTAssertTrue(game.laserProjectiles.allSatisfy { $0.targetID == nil && $0.heading == game.robotHeading })
        XCTAssertNil(game.secondaryLockedEnemy)
        XCTAssertNil(game.lockedEnemy)
        XCTAssertTrue(game.laserLockDescription.localizedCaseInsensitiveContains("manual aim"))
    }

    func testTargetingComputerLetsTwinBlastersDamageTwoIndependentTargets() {
        let suite = "ROBTwinSkills.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(1_200, forKey: GameSession.skillPointsStorageKey)
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        for _ in 0..<5 { completeCurrentLevel(game) }
        game.purchaseUpgrade(.targetingComputer)
        game.selectRangedWeapon(.twinBlasters)
        game.begin()
        guard game.enemies.count >= 2 else { return XCTFail("Missing training targets") }
        for index in game.enemies.indices where index > 1 { game.enemies[index].isActive = false }
        game.enemies[0].position = game.robotPosition + SIMD3<Float>(-0.45, 0, -1.7)
        game.enemies[1].position = game.robotPosition + SIMD3<Float>(0.45, 0, -1.9)
        let firstShields = game.enemies[0].shields
        let secondShields = game.enemies[1].shields

        game.fireLaser()

        XCTAssertEqual(game.laserProjectiles.count, 2)
        XCTAssertEqual(Set(game.laserProjectiles.map(\.targetID)).count, 2)
        XCTAssertNotNil(game.secondaryLockedEnemy)
        XCTAssertNotEqual(game.laserProjectiles[0].heading, game.laserProjectiles[1].heading)
        XCTAssertTrue(game.laserLockDescription.localizedCaseInsensitiveContains("dual lock"))
        let robot = RobotFactory.makeROB()
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertTrue(robot.findEntity(named: "Left Blaster Laser Beam")?.isEnabled == true)
        XCTAssertTrue(robot.findEntity(named: "Right Blaster Laser Beam")?.isEnabled == true)

        for _ in 0..<90 where !game.laserProjectiles.isEmpty { game.tick(1.0 / 60.0) }

        XCTAssertLessThan(game.enemies[0].shields, firstShields)
        XCTAssertLessThan(game.enemies[1].shields, secondShields)
        XCTAssertTrue(game.laserProjectiles.isEmpty)
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
        XCTAssertNotNil((robot.findEntity(named: "Captured Shoulder Laser") as? ModelEntity)?.model)
        XCTAssertNil(robot.findEntity(named: "Gatling Housing"), "Use the shoulder housing already captured in the scan")
        XCTAssertNil(robot.findEntity(named: "Gatling Barrel"))
        XCTAssertEqual(robot.findEntity(named: "Gatling Lock Indicator")?.parent?.name, "Shoulder Laser Muzzle")
        XCTAssertNotNil(robot.findEntity(named: "Flipper Zero Hacker"))
        XCTAssertNotNil(robot.findEntity(named: "Gatling Lock Indicator"))
        XCTAssertNotNil(robot.findEntity(named: "Shoulder Laser Beam"))
        XCTAssertNotNil(robot.findEntity(named: "Left Blaster Laser Beam"))
        XCTAssertNotNil(robot.findEntity(named: "Right Blaster Laser Beam"))
        XCTAssertNotNil(robot.findEntity(named: "Left Blaster Mount"))
        XCTAssertNotNil(robot.findEntity(named: "Right Blaster Mount"))
        XCTAssertNil(robot.findEntity(named: "Head Camera"))
        XCTAssertNotNil(robot.findEntity(named: "Face Smiley Left Eye"))
        XCTAssertNotNil(robot.findEntity(named: "Face Smiley Right Eye"))
        XCTAssertNotNil(robot.findEntity(named: "Face Smiley Center Smile"))
        XCTAssertNotNil(robot.findEntity(named: "Left Tri-Wheel Tread"))
        XCTAssertNotNil(robot.findEntity(named: "Right Tri-Wheel Tread"))
        for side in ["Left", "Right"] {
            guard let tread = robot.findEntity(named: "\(side) Tri-Wheel Tread") else { return XCTFail("Missing \(side) tread") }
            XCTAssertGreaterThanOrEqual(tread.children.filter { $0.name.hasPrefix("\(side) Tread Shoe ") }.count, 18, "Tread children: \(tread.children.map(\.name))")
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
        XCTAssertFalse(robot.findEntity(named: "Gatling Lock Indicator")?.isEnabled == true, "The basic computer must not display an automatic target lock")
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
        game.saberAttack(); game.tick(0.5)
        game.saberAttack(); game.tick(0.5)
        game.saberAttack(); game.tick(0.25)

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
        game.selectFaceColor(.magenta)
        game.selectRangedWeapon(.twinBlasters)
        game.reset()

        XCTAssertEqual(game.highestCompletedLevel, 5)
        XCTAssertEqual(game.robotFinish, .rescueOrange)
        XCTAssertEqual(game.faceColor, .magenta)
        XCTAssertEqual(game.rangedWeapon, .twinBlasters)

        let restored = GameSession(audioEnabled: false, progressStore: defaults)
        XCTAssertEqual(restored.highestCompletedLevel, 5)
        XCTAssertEqual(restored.robotFinish, .rescueOrange)
        XCTAssertEqual(restored.faceColor, .magenta)
        XCTAssertEqual(restored.rangedWeapon, .twinBlasters)
    }

    func testDroidCodeMatchesThePortableWebFormatAndRejectsDamage() throws {
        let profile = ROBDroidProfile(
            name: "Nova 7",
            finish: .plasmaPurple,
            faceColor: .cyan,
            material: .brushedAluminum,
            housing: .festivalArmor,
            sections: [.treads, .torso, .cameraNetwork]
        )
        let expected = "ROBDROID1.eyJiIjoiYmx1ZSIsImMiOiJjeWFuIiwiZiI6InBsYXNtYVB1cnBsZSIsImgiOiJmZXN0aXZhbEFybW9yIiwibSI6ImJydXNoZWRBbHVtaW51bSIsIm4iOiJOb3ZhIDciLCJzIjpbInRyZWFkcyIsInRvcnNvIiwiY2FtZXJhTmV0d29yayJdLCJ0IjoicmVkIiwidiI6MSwidyI6InBhblRpbHRHYXRsaW5nIn0.A3BE7536"

        XCTAssertEqual(ROBDroidProfileCode.encode(profile), expected)
        XCTAssertEqual(try ROBDroidProfileCode.decode(expected), profile)
        XCTAssertThrowsError(try ROBDroidProfileCode.decode(String(expected.dropLast()) + "0"))
    }

    func testImportedDroidProfilePersistsAcrossGameSessions() {
        let suiteName = "ROBTrainingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let imported = ROBDroidProfile(
            name: "Maker One", finish: .makerPink, faceColor: .amber,
            material: .impactPolymer, housing: .openMakerFrame, sections: [.treads, .torso]
        )
        let game = GameSession(audioEnabled: false, progressStore: defaults)

        XCTAssertTrue(game.importDroidCode(ROBDroidProfileCode.encode(imported)))
        XCTAssertEqual(game.droidProfile, imported)
        XCTAssertEqual(game.robotFinish, .makerPink)
        XCTAssertEqual(game.faceColor, .amber)

        let restored = GameSession(audioEnabled: false, progressStore: defaults)
        XCTAssertEqual(restored.droidProfile, imported)
        XCTAssertEqual(restored.droidCode, game.droidCode)
    }

    func testSelectedLoadoutChangesVisibleRobotWeapons() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()
        game.selectFinish(.rescueOrange)
        RobotFactory.applyWeapons(to: robot, session: game)

        XCTAssertNotNil(robot.findEntity(named: "Applied Appearance \(game.droidProfile.appearanceKey)"))
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

    func testAutoNetBattleRequiresEveryPilotVoteAndResolvesTieDeterministically() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)

        battle.testReceive(.init(kind: .hello, sender: remote))
        XCTAssertEqual(battle.playerCount, 2)
        XCTAssertTrue(battle.isHost)
        XCTAssertFalse(battle.canStartMatch)

        battle.vote(for: .neonFoundry)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .orbitalRing))

        XCTAssertTrue(battle.allPlayersHaveVoted)
        XCTAssertTrue(battle.canStartMatch)
        battle.startMatch()
        XCTAssertEqual(battle.phase, .playing)
        XCTAssertEqual(battle.arena, .neonFoundry, "A tied vote should use the stable arena ordering")
        XCTAssertEqual(battle.allRobotStates.count, 2)
    }

    func testAutoNetBattleCapsLobbyAtFourPilots() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        for index in 2...6 {
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
            let peer = ROBBattlePlayerIdentity(id: id, name: "Pilot \(index)", transportName: "ROB-\(index)", colorIndex: index % 4)
            battle.testReceive(.init(kind: .hello, sender: peer))
        }

        XCTAssertEqual(battle.playerCount, ROBBattleCoordinator.maximumPlayers)
    }

    func testOnlyTheHostCanSelectAndSynchronizeTheBattleMode() {
        let clientID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let hostID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: clientID, playerName: "Beta", audioEnabled: false)
        let host = ROBBattlePlayerIdentity(id: hostID, name: "Alpha", transportName: "ROB-ALPHA", colorIndex: 0)
        battle.testReceive(.init(kind: .hello, sender: host))

        XCTAssertFalse(battle.isHost)
        battle.selectMode(.captureTheFlag)
        XCTAssertEqual(battle.mode, .deathmatch)

        battle.testReceive(.init(kind: .modeSelection, sender: host, mode: .captureTheFlag))
        XCTAssertEqual(battle.mode, .captureTheFlag)
    }

    func testCaptureTheFlagCreatesVisibleBasesAndScoresReturnedEnemyFlags() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.selectMode(.captureTheFlag)
        battle.vote(for: .neonFoundry)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .neonFoundry))
        battle.startMatch()

        XCTAssertEqual(battle.mode, .captureTheFlag)
        XCTAssertEqual(battle.flags.count, 2)
        XCTAssertTrue(battle.flags.values.allSatisfy { $0.disposition == .atBase && $0.carrierID == nil })

        let root = Entity()
        root.addChild(ROBBattleFactory.makeArena(battle.arena))
        ROBBattleFactory.synchronize(root: root, battle: battle)
        XCTAssertNotNil(root.findEntity(named: ROBBattleFactory.flagName(localID)))
        XCTAssertNotNil(root.findEntity(named: ROBBattleFactory.flagBaseName(localID)))
        XCTAssertNotNil(root.findEntity(named: ROBBattleFactory.flagName(remoteID))?.findEntity(named: "Flag Banner"))

        var remoteAway = battle.remoteRobots[remoteID]!
        remoteAway.x = 4.5
        remoteAway.z = 6.4
        battle.testReceive(.init(kind: .snapshot, sender: remote, snapshot: remoteAway, snapshotSequence: 10))
        let localBase = battle.flags[localID]!.basePosition
        let remoteBase = battle.flags[remoteID]!.basePosition

        for expectedCaptures in 1...ROBBattleMode.captureTheFlag.scoreLimit {
            battle.testSetLocalRobotPosition(remoteBase)
            battle.tick(0.01)
            XCTAssertEqual(battle.flags[remoteID]?.disposition, .carried)
            XCTAssertEqual(battle.flags[remoteID]?.carrierID, localID)

            battle.testSetLocalRobotPosition(localBase)
            battle.tick(0.01)
            XCTAssertEqual(battle.captures[localID], expectedCaptures)
            XCTAssertEqual(battle.flags[remoteID]?.disposition, .atBase)
            XCTAssertNil(battle.flags[remoteID]?.carrierID)
        }

        XCTAssertEqual(battle.phase, .results)
        XCTAssertEqual(battle.winnerID, localID)
        XCTAssertEqual(battle.localScore, ROBBattleMode.captureTheFlag.scoreLimit)
    }

    func testCaptureTheFlagDropsCarriedFlagWhenCarrierIsKnockedOut() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var cues: [ROBBattleSoundCue] = []
        let battle = ROBBattleCoordinator(
            networkingEnabled: false,
            playerID: localID,
            playerName: "Alpha",
            audioEnabled: false,
            soundFeedback: { cues.append($0) }
        )
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.selectMode(.captureTheFlag)
        battle.vote(for: .orbitalRing)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .orbitalRing))
        battle.startMatch()

        var remoteAway = battle.remoteRobots[remoteID]!
        remoteAway.x = 4.5
        remoteAway.z = 6.4
        battle.testReceive(.init(kind: .snapshot, sender: remote, snapshot: remoteAway, snapshotSequence: 10))
        battle.testSetLocalRobotPosition(battle.flags[remoteID]!.basePosition)
        battle.tick(0.01)
        XCTAssertEqual(battle.flags[remoteID]?.carrierID, localID)

        cues.removeAll()
        let deathPosition = battle.localRobot.position
        let knockout = ROBBattleProjectile(
            id: UUID(), ownerID: remoteID,
            x: deathPosition.x, z: deathPosition.z,
            velocityX: 0, velocityZ: 0,
            remaining: 1, damage: 200
        )
        battle.testReceive(.init(kind: .projectile, sender: remote, projectile: knockout))
        battle.tick(0.01)

        XCTAssertFalse(battle.localRobot.isAlive)
        XCTAssertEqual(battle.flags[remoteID]?.disposition, .dropped)
        XCTAssertNil(battle.flags[remoteID]?.carrierID)
        XCTAssertEqual(battle.flags[remoteID]?.x ?? 0, deathPosition.x, accuracy: 0.001)
        XCTAssertEqual(battle.flags[remoteID]?.z ?? 0, deathPosition.z, accuracy: 0.001)
        XCTAssertEqual(cues.filter { $0 == .flagDrop }.count, 1)
    }

    func testCaptureTheFlagOwnerReturnsTheirDroppedFlag() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.selectMode(.captureTheFlag)
        battle.vote(for: .shadowYard)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .shadowYard))
        battle.startMatch()

        let localBase = battle.flags[localID]!.basePosition
        var remoteAtFlag = battle.remoteRobots[remoteID]!
        remoteAtFlag.x = localBase.x
        remoteAtFlag.z = localBase.z
        battle.testReceive(.init(kind: .snapshot, sender: remote, snapshot: remoteAtFlag, snapshotSequence: 10))
        let pickup = ROBBattleFlagRequest(
            id: UUID(), matchID: battle.matchID,
            playerID: remoteID, flagOwnerID: localID, action: .pickup
        )
        battle.testReceive(.init(kind: .flagRequest, sender: remote, flagRequest: pickup))
        XCTAssertEqual(battle.flags[localID]?.carrierID, remoteID)

        let knockout = ROBBattleKnockout(id: UUID(), attackerID: localID, victimID: remoteID)
        battle.testReceive(.init(kind: .knockout, sender: remote, knockout: knockout))
        XCTAssertEqual(battle.flags[localID]?.disposition, .dropped)
        XCTAssertNil(battle.flags[localID]?.carrierID)

        var remoteAway = remoteAtFlag
        remoteAway.x = 4.5
        remoteAway.z = 6.4
        battle.testReceive(.init(kind: .snapshot, sender: remote, snapshot: remoteAway, snapshotSequence: 11))
        battle.testSetLocalRobotPosition(localBase)
        battle.tick(0.01)

        XCTAssertEqual(battle.flags[localID]?.disposition, .atBase)
        XCTAssertEqual(battle.flags[localID]?.position, localBase)
        XCTAssertTrue(battle.statusMessage.localizedCaseInsensitiveContains("returned"))
    }

    func testBattleSpawnAssignmentsFaceEveryDroidTowardArenaCenter() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.vote(for: .orbitalRing)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .orbitalRing))
        battle.startMatch()

        for robot in battle.allRobotStates {
            let forward = SIMD2<Float>(-sin(robot.heading), -cos(robot.heading))
            let towardCenter = simd_normalize(SIMD2<Float>(-robot.x, -robot.z))
            XCTAssertGreaterThan(simd_dot(forward, towardCenter), 0.999)
        }
    }

    func testBattleLasersStopWhenBatteryCannotAffordAnotherShot() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.vote(for: .neonFoundry)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .neonFoundry))
        battle.startMatch()
        for _ in 0..<12 {
            battle.fireLaser()
            for _ in 0..<3 { battle.tick(0.1) }
        }
        XCTAssertEqual(battle.localEnergy, 4, accuracy: 0.0001)
        let projectiles = battle.projectiles.count
        battle.fireLaser()
        XCTAssertEqual(battle.projectiles.count, projectiles)
        XCTAssertTrue(battle.statusMessage.contains("energy"))
        for _ in 0..<8 { battle.tick(0.1) }
        XCTAssertEqual(battle.localEnergy, 4, accuracy: 0.0001)
        for _ in 0..<15 { battle.tick(0.1) }
        XCTAssertGreaterThan(battle.localEnergy, 8)
        let recharged = battle.localEnergy
        battle.fireLaser()
        XCTAssertEqual(battle.localEnergy, recharged - 8, accuracy: 0.0001)
    }

    func testBattleSabersStayVisibleAndReturnBothArmsToRest() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.vote(for: .neonFoundry)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .neonFoundry))
        battle.startMatch()
        let robot = ROBBattleFactory.makeBattleRobot(identity: battle.localIdentity)

        battle.saberAttack()
        battle.tick(0.1)
        ROBBattleFactory.applyAnimation(to: robot, state: battle.animationState(for: localID))

        XCTAssertEqual(robot.findEntity(named: "Left Lightsaber")?.scale.y ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(robot.findEntity(named: "Right Lightsaber")?.scale.y ?? 0, 1, accuracy: 0.001)
        XCTAssertNotEqual(
            robot.findEntity(named: "Left Arm Assembly")?.orientation,
            simd_quatf(angle: 0, axis: [0, 1, 0])
        )
        XCTAssertNotEqual(
            robot.findEntity(named: "Right Arm Assembly")?.orientation,
            simd_quatf(angle: 0, axis: [0, 1, 0])
        )

        for _ in 0..<6 {
            battle.tick(0.1)
        }
        ROBBattleFactory.applyAnimation(to: robot, state: battle.animationState(for: localID))
        XCTAssertEqual(robot.findEntity(named: "Left Lightsaber")?.scale.y ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(
            robot.findEntity(named: "Left Arm Assembly")?.orientation,
            simd_quatf(angle: 0, axis: [0, 1, 0])
        )

        let remoteState = battle.remoteRobots[remoteID]!
        let remoteSaber = ROBBattleMeleeEvent(
            id: UUID(), attackerID: remoteID,
            x: remoteState.x, z: remoteState.z, heading: remoteState.heading, damage: 38
        )
        battle.testReceive(.init(kind: .melee, sender: remote, melee: remoteSaber))
        XCTAssertEqual(
            battle.animationState(for: remoteID).saberRemaining,
            ROBBattleRobotAnimationState.saberDuration,
            accuracy: 0.001
        )
    }

    func testBattleTreadsAnimateForLocalAndInterpolatedRemoteMovement() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.vote(for: .neonFoundry)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .neonFoundry))
        battle.startMatch()

        battle.setTreads(left: 1, right: 0.4)
        battle.tick(0.1)
        let localAnimation = battle.animationState(for: localID)
        XCTAssertNotEqual(localAnimation.leftTreadAngle, 0, accuracy: 0.001)
        XCTAssertNotEqual(localAnimation.rightTreadAngle, 0, accuracy: 0.001)
        XCTAssertNotEqual(localAnimation.leftTreadAngle, localAnimation.rightTreadAngle, accuracy: 0.001)

        var remoteTarget = battle.remoteRobots[remoteID]!
        remoteTarget.x -= sin(remoteTarget.heading) * 0.5
        remoteTarget.z -= cos(remoteTarget.heading) * 0.5
        battle.testReceive(.init(kind: .snapshot, sender: remote, snapshot: remoteTarget, snapshotSequence: 10))
        battle.tick(ROBBattleCoordinator.remoteInterpolationDuration)
        let remoteAnimation = battle.animationState(for: remoteID)
        XCTAssertNotEqual(remoteAnimation.leftTreadAngle, 0, accuracy: 0.001)
        XCTAssertNotEqual(remoteAnimation.rightTreadAngle, 0, accuracy: 0.001)
    }

    func testBattleCollisionClanksOnceAndPushesTheLocalDroidAway() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var cues: [ROBBattleSoundCue] = []
        let battle = ROBBattleCoordinator(
            networkingEnabled: false,
            playerID: localID,
            playerName: "Alpha",
            audioEnabled: false,
            soundFeedback: { cues.append($0) }
        )
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.vote(for: .reactorGrid)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .reactorGrid))
        battle.startMatch()

        let localStart = battle.localRobot
        let forward = SIMD2<Float>(-sin(localStart.heading), -cos(localStart.heading))
        var nearbyRemote = battle.remoteRobots[remoteID]!
        nearbyRemote.x = localStart.x + forward.x * 1.3
        nearbyRemote.z = localStart.z + forward.y * 1.3
        battle.testReceive(.init(
            kind: .snapshot,
            sender: remote,
            snapshot: nearbyRemote,
            snapshotSequence: 10
        ))
        cues.removeAll()

        battle.setTreads(left: 1, right: 1)
        battle.tick(0.1)

        let distanceAfterPush = hypot(
            battle.localRobot.x - nearbyRemote.x,
            battle.localRobot.z - nearbyRemote.z
        )
        XCTAssertGreaterThan(distanceAfterPush, 1.3)
        XCTAssertEqual(cues.filter { $0 == .collision }.count, 1)
        XCTAssertGreaterThan(battle.animationState(for: localID).collisionRemaining, 0)

        for _ in 0..<30 { battle.tick(0.01) }
        XCTAssertEqual(cues.filter { $0 == .collision }.count, 1, "Continuous contact must not restart collision audio every frame")
    }

    func testReceivedBattleCollisionPushesTheOtherDroidAndDebouncesDuplicateContact() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var cues: [ROBBattleSoundCue] = []
        let battle = ROBBattleCoordinator(
            networkingEnabled: false,
            playerID: localID,
            playerName: "Alpha",
            audioEnabled: false,
            soundFeedback: { cues.append($0) }
        )
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.vote(for: .shadowYard)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .shadowYard))
        battle.startMatch()

        let localStart = battle.localRobot
        let towardRemote = SIMD2<Float>(-sin(localStart.heading), -cos(localStart.heading))
        var nearbyRemote = battle.remoteRobots[remoteID]!
        nearbyRemote.x = localStart.x + towardRemote.x * 1.3
        nearbyRemote.z = localStart.z + towardRemote.y * 1.3
        battle.testReceive(.init(kind: .snapshot, sender: remote, snapshot: nearbyRemote, snapshotSequence: 10))
        cues.removeAll()

        let first = ROBBattleCollisionEvent(
            id: UUID(), initiatorID: remoteID, otherRobotID: localID,
            normalX: towardRemote.x, normalZ: towardRemote.y,
            impulse: ROBBattleCoordinator.collisionImpulse
        )
        battle.testReceive(.init(kind: .collision, sender: remote, collision: first))
        let afterFirst = battle.localRobot.position
        let duplicateContact = ROBBattleCollisionEvent(
            id: UUID(), initiatorID: remoteID, otherRobotID: localID,
            normalX: towardRemote.x, normalZ: towardRemote.y,
            impulse: ROBBattleCoordinator.collisionImpulse
        )
        battle.testReceive(.init(kind: .collision, sender: remote, collision: duplicateContact))

        XCTAssertGreaterThan(simd_distance(afterFirst, localStart.position), 0.3)
        XCTAssertEqual(battle.localRobot.position, afterFirst)
        XCTAssertEqual(cues.filter { $0 == .collision }.count, 1)
    }

    func testDeathmatchProjectileKnockoutScoresAndRespawnsROB() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.vote(for: .reactorGrid)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .reactorGrid))
        battle.startMatch()

        let position = battle.localRobot.position
        let hit = ROBBattleProjectile(
            id: UUID(), ownerID: remoteID, x: position.x, z: position.z,
            velocityX: 0, velocityZ: 0, remaining: 1, damage: 28
        )
        battle.testReceive(.init(kind: .projectile, sender: remote, projectile: hit))
        battle.tick(0.01)
        XCTAssertEqual(battle.localRobot.shields, 22)
        XCTAssertEqual(battle.localRobot.health, 100)

        let knockout = ROBBattleProjectile(
            id: UUID(), ownerID: remoteID, x: position.x, z: position.z,
            velocityX: 0, velocityZ: 0, remaining: 1, damage: 150
        )
        battle.testReceive(.init(kind: .projectile, sender: remote, projectile: knockout))
        battle.tick(0.01)
        XCTAssertFalse(battle.localRobot.isAlive)
        XCTAssertEqual(battle.scores[remoteID], 1)
        XCTAssertEqual(battle.deaths[localID], 1)

        for _ in 0..<31 { battle.tick(0.1) }
        XCTAssertTrue(battle.localRobot.isAlive)
        XCTAssertEqual(battle.localRobot.health, 100)
        XCTAssertEqual(battle.localRobot.shields, 50)
    }

    func testBattlePacketsRoundTripAllSynchronizedState() throws {
        let profile = ROBDroidProfile(name: "Blue Nova", finish: .cobaltBlue, faceColor: .magenta, material: .carbonComposite, housing: .festivalArmor, sections: [.treads, .torso, .cameraNetwork])
        let player = ROBBattlePlayerIdentity(id: UUID(), name: "Pilot", transportName: "ROB-TEST", colorIndex: 2, droidProfile: profile)
        let projectile = ROBBattleProjectile(
            id: UUID(), ownerID: player.id, x: 1, z: -2,
            velocityX: 4, velocityZ: -5, remaining: 2, damage: 28
        )
        let packet = ROBBattlePacket(kind: .projectile, sender: player, projectile: projectile)

        let decoded = try JSONDecoder().decode(ROBBattlePacket.self, from: JSONEncoder().encode(packet))

        XCTAssertEqual(decoded.kind, .projectile)
        XCTAssertEqual(decoded.sender, player)
        XCTAssertEqual(decoded.sender.droidProfile, profile)
        XCTAssertEqual(decoded.projectile, projectile)
    }

    func testCaptureTheFlagUpdatePacketRoundTripsAuthoritativeState() throws {
        let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let carrierID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let host = ROBBattlePlayerIdentity(id: ownerID, name: "Host", transportName: "ROB-HOST", colorIndex: 0)
        let flag = ROBBattleFlagState(
            ownerID: ownerID,
            baseX: -6.4, baseZ: -6.4,
            x: -1.25, z: 2.5,
            disposition: .carried, carrierID: carrierID
        )
        let update = ROBBattleFlagUpdate(
            matchID: UUID(),
            revision: 4,
            flags: [flag],
            captures: [.init(playerID: carrierID, captures: 2)],
            action: .pickup,
            actorID: carrierID,
            flagOwnerID: ownerID
        )
        let packet = ROBBattlePacket(kind: .flagUpdate, sender: host, flagUpdate: update)

        let decoded = try JSONDecoder().decode(ROBBattlePacket.self, from: JSONEncoder().encode(packet))

        XCTAssertEqual(decoded.kind, .flagUpdate)
        XCTAssertEqual(decoded.flagUpdate, update)
    }

    func testCaptureTheFlagClientAppliesOnlyNewHostFlagUpdates() {
        let hostID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let clientID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let client = ROBBattleCoordinator(networkingEnabled: false, playerID: clientID, playerName: "Beta", audioEnabled: false)
        let host = ROBBattlePlayerIdentity(id: hostID, name: "Alpha", transportName: "ROB-ALPHA", colorIndex: 0)
        client.testReceive(.init(kind: .hello, sender: host))
        let start = ROBBattleMatchStart(
            matchID: UUID(),
            mode: .captureTheFlag,
            arena: .reactorGrid,
            assignments: [
                .init(playerID: hostID, spawnIndex: 0),
                .init(playerID: clientID, spawnIndex: 1),
            ],
            duration: ROBBattleCoordinator.matchDuration,
            scoreLimit: ROBBattleMode.captureTheFlag.scoreLimit
        )
        client.testReceive(.init(kind: .matchStart, sender: host, matchStart: start))

        var hostFlag = client.flags[hostID]!
        hostFlag.disposition = .carried
        hostFlag.carrierID = clientID
        let accepted = ROBBattleFlagUpdate(
            matchID: client.matchID,
            revision: 2,
            flags: [hostFlag, client.flags[clientID]!],
            captures: [
                .init(playerID: hostID, captures: 0),
                .init(playerID: clientID, captures: 1),
            ],
            action: .pickup,
            actorID: clientID,
            flagOwnerID: hostID
        )
        client.testReceive(.init(kind: .flagUpdate, sender: host, flagUpdate: accepted))
        XCTAssertEqual(client.flags[hostID]?.carrierID, clientID)
        XCTAssertEqual(client.captures[clientID], 1)

        var staleFlag = hostFlag
        staleFlag.disposition = .atBase
        staleFlag.carrierID = nil
        let stale = ROBBattleFlagUpdate(
            matchID: client.matchID,
            revision: 1,
            flags: [staleFlag, client.flags[clientID]!],
            captures: [.init(playerID: clientID, captures: 0)],
            action: .returnHome,
            actorID: hostID,
            flagOwnerID: hostID
        )
        client.testReceive(.init(kind: .flagUpdate, sender: host, flagUpdate: stale))
        XCTAssertEqual(client.flags[hostID]?.carrierID, clientID)
        XCTAssertEqual(client.captures[clientID], 1)
    }

    func testBattleSnapshotsInterpolateRemoteMovementAndDiscardStaleUpdates() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1)
        battle.testReceive(.init(kind: .hello, sender: remote))
        battle.vote(for: .neonFoundry)
        battle.testReceive(.init(kind: .vote, sender: remote, vote: .neonFoundry))
        battle.startMatch()

        let start = battle.remoteRobots[remoteID]!
        var target = start
        target.x -= 1.2
        target.z -= 0.6
        target.heading = -.pi + 0.04
        battle.testReceive(.init(
            kind: .snapshot,
            sender: remote,
            snapshot: target,
            snapshotSequence: 2
        ))

        XCTAssertEqual(battle.remoteRobots[remoteID]?.x, start.x)
        XCTAssertEqual(battle.remoteRobots[remoteID]?.z, start.z)
        battle.tick(ROBBattleCoordinator.remoteInterpolationDuration / 2)
        XCTAssertEqual(battle.remoteRobots[remoteID]?.x ?? 0, (start.x + target.x) / 2, accuracy: 0.001)
        XCTAssertEqual(battle.remoteRobots[remoteID]?.z ?? 0, (start.z + target.z) / 2, accuracy: 0.001)

        var stale = target
        stale.x = start.x + 1
        battle.testReceive(.init(
            kind: .snapshot,
            sender: remote,
            snapshot: stale,
            snapshotSequence: 1
        ))
        battle.tick(ROBBattleCoordinator.remoteInterpolationDuration / 2)
        XCTAssertEqual(battle.remoteRobots[remoteID]?.x ?? 0, target.x, accuracy: 0.001)
        XCTAssertEqual(battle.remoteRobots[remoteID]?.z ?? 0, target.z, accuracy: 0.001)
    }

    func testBattleHeadingInterpolationUsesShortestTurnAcrossPi() {
        let halfway = ROBBattleCoordinator.interpolatedHeading(
            from: .pi - 0.1,
            to: -.pi + 0.1,
            progress: 0.5
        )

        XCTAssertEqual(abs(halfway), .pi, accuracy: 0.001)
    }

    func testBattleUsesUnreliableDeliveryOnlyForFrequentSnapshots() {
        XCTAssertEqual(
            ROBBattleNetwork.deliveryMode(for: .snapshot).rawValue,
            MCSessionSendDataMode.unreliable.rawValue
        )
        XCTAssertEqual(
            ROBBattleNetwork.deliveryMode(for: .projectile).rawValue,
            MCSessionSendDataMode.reliable.rawValue
        )
        XCTAssertEqual(
            ROBBattleNetwork.deliveryMode(for: .knockout).rawValue,
            MCSessionSendDataMode.reliable.rawValue
        )
        XCTAssertEqual(
            ROBBattleNetwork.deliveryMode(for: .collision).rawValue,
            MCSessionSendDataMode.reliable.rawValue
        )
        XCTAssertEqual(
            ROBBattleNetwork.deliveryMode(for: .flagUpdate).rawValue,
            MCSessionSendDataMode.reliable.rawValue
        )
    }

    func testNearbyBattleDownloadsAndRendersEachDroidProfile() {
        let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let remoteID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let localProfile = ROBDroidProfile(name: "Local", finish: .solarYellow, material: .brushedAluminum, housing: .fieldShell)
        let remoteProfile = ROBDroidProfile(name: "Remote", finish: .makerPink, faceColor: .cyan, material: .impactPolymer, housing: .openMakerFrame, sections: [.treads])
        let battle = ROBBattleCoordinator(networkingEnabled: false, playerID: localID, playerName: "Alpha", droidProfile: localProfile, audioEnabled: false)
        let remote = ROBBattlePlayerIdentity(id: remoteID, name: "Beta", transportName: "ROB-BETA", colorIndex: 1, droidProfile: remoteProfile)

        battle.testReceive(.init(kind: .hello, sender: remote))

        XCTAssertEqual(battle.players[remoteID]?.droidProfile, remoteProfile)
        let robot = ROBBattleFactory.makeBattleRobot(identity: remote)
        XCTAssertNotNil(robot.findEntity(named: "Battle Appearance \(remoteProfile.appearanceKey)"))
        XCTAssertNotNil(robot.findEntity(named: "Left Maker Frame Rail"))
        XCTAssertNotNil(robot.findEntity(named: "Virtual Blue Balloon Beam Emitter"))
    }

    func testPhoneBattleCameraTracksTheLocalDroidAtACloserStableOffset() {
        let playerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let first = ROBBattleRobotState(
            id: playerID, x: -6.4, z: -6.4, heading: 0,
            health: 100, shields: 50, isAlive: true, respawnRemaining: 0
        )
        let moved = ROBBattleRobotState(
            id: playerID, x: 2.1, z: -1.3, heading: .pi,
            health: 100, shields: 50, isAlive: true, respawnRemaining: 0
        )

        let firstPose = ROBBattleFactory.phoneFollowCameraPose(for: first)
        let movedPose = ROBBattleFactory.phoneFollowCameraPose(for: moved)

        XCTAssertEqual(firstPose.target, first.position + [0, ROBBattleFactory.phoneFollowCameraTargetHeight, 0])
        XCTAssertEqual(firstPose.position, first.position + ROBBattleFactory.phoneFollowCameraOffset)
        XCTAssertEqual(movedPose.position - firstPose.position, moved.position - first.position)
        XCTAssertEqual(movedPose.target - firstPose.target, moved.position - first.position)
        XCTAssertLessThan(simd_distance(firstPose.position, firstPose.target), 9)
    }

    func testRearFlipperMountsLedgeThenRotatesBackToStabilize() {
        let game = GameSession(audioEnabled: false)
        game.begin(); game.enemies = []
        let ledge = try! XCTUnwrap(game.puzzle.ledges.first)
        game.robotPosition = [0, 0, ledge.approachEdgeZ + 0.18]
        game.setDrive(forward: 1, steering: 0); game.tick(0.45)
        XCTAssertFalse(game.isOnLedge, "Cannot drive through a step without front clearance")
        game.stopDrive(); game.robotPosition = [0, 0, ledge.approachEdgeZ + 0.18]
        let energyBeforeLift = game.energy
        XCTAssertTrue(game.moveBaseFlipperForward())
        XCTAssertEqual(game.energy, energyBeforeLift - GameSession.baseFlipperEnergyCost, accuracy: 0.0001)
        game.tick(GameSession.baseFlipperDuration + 0.01)
        XCTAssertEqual(game.baseFlipperAngle, GameSession.baseFlipperForwardAngle, accuracy: 0.0001)
        XCTAssertEqual(game.baseLiftHeight, 0, "Rear contact must stay grounded during front lift")
        XCTAssertGreaterThan(game.baseLiftPitch, 0.7)
        let robot = RobotFactory.makeROB()
        RobotFactory.applyWeapons(to: robot, session: game)
        let drive = robot.findEntity(named: "Drive Base Assembly")!
        XCTAssertEqual(drive.position.y, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(drive.convert(position: [0, 0, -GameSession.robotContactSpan], to: robot).y, ledge.height)
        XCTAssertLessThan(robot.findEntity(named: "Torso Assembly")!.orientation.act([0, 1, 0]).z, -0.35, "The LACT swings the entire body forward to balance the lifted base")

        game.setDrive(forward: 1, steering: 0)
        var sawAutomaticRearSupport = false
        var rearHeight: Float = 0
        for _ in 0..<160 {
            game.tick(0.02)
            if game.isClimbingLedge {
                sawAutomaticRearSupport = true
                XCTAssertEqual(game.baseFlipperTarget, .rear)
                XCTAssertGreaterThanOrEqual(game.baseLiftHeight, rearHeight - 0.0001)
                XCTAssertGreaterThanOrEqual(game.baseLiftHeight + GameSession.robotContactSpan * sin(game.baseLiftPitch), ledge.height - 0.0001)
                rearHeight = game.baseLiftHeight
            }
        }
        game.stopDrive()
        XCTAssertTrue(sawAutomaticRearSupport, "Forward drive should reverse the flippers at front contact")
        XCTAssertTrue(game.isOnLedge)
        XCTAssertFalse(game.isClimbingLedge)
        XCTAssertTrue(game.isLedgeStabilized)
        XCTAssertEqual(game.baseLiftPitch, 0, accuracy: 0.0001)
        XCTAssertEqual(game.presentationPosition.y, ledge.height, accuracy: 0.0001)

        for _ in 0..<3 {
            XCTAssertTrue(game.moveBaseFlipperForward(), "The completed climb must release its control latch")
            game.tick(GameSession.baseFlipperDuration + 0.05)
            XCTAssertGreaterThan(game.baseLiftPitch, 0.7, "The raised platform supports another front lift")
            XCTAssertEqual(game.baseLiftHeight, ledge.height, accuracy: 0.0001)
            XCTAssertTrue(game.moveBaseFlipperBackward())
            game.tick(GameSession.baseFlipperDuration + 0.05)
            XCTAssertEqual(game.baseLiftPitch, 0, accuracy: 0.0001)
        }
    }

    func testPlatformOverhangDoesNotLockFlipperControlsToTheLowerFloor() {
        for heading: Float in [0, .pi] {
            let game = GameSession(audioEnabled: false)
            game.begin(); game.enemies = []
            let ledge = game.puzzle.ledges[0]
            // The center is on the deck but one tread end extends over its lip.
            game.robotPosition = [0, ledge.height, ledge.approachEdgeZ - 0.1]
            game.robotHeading = heading
            game.tick(0.02)
            let robot = RobotFactory.makeROB()
            for _ in 0..<3 {
                XCTAssertTrue(game.isBaseGrounded)
                XCTAssertTrue(game.moveBaseFlipperForward())
                for _ in 0..<20 { game.tick(0.02) }
                XCTAssertGreaterThan(game.baseLiftPitch, 0.7)
                XCTAssertEqual(game.baseLiftHeight, ledge.height, accuracy: 0.0001)
                RobotFactory.applyWeapons(to: robot, session: game)
                let roller = robot.findEntity(named: "Left Flipper End Roller")!
                XCTAssertEqual(roller.position(relativeTo: robot).y + game.robotPosition.y,
                               ledge.height + 0.029 * ROBScanVisualModel.presentationScale, accuracy: 0.0001)
                XCTAssertTrue(game.moveBaseFlipperBackward())
                for _ in 0..<20 { game.tick(0.02) }
                XCTAssertEqual(game.baseLiftPitch, 0, accuracy: 0.0001)
            }
        }
    }

    func testLeavingPlatformFallsAndReleasesFlippersAfterLanding() {
        let game = GameSession(audioEnabled: false)
        game.begin(); game.enemies = []
        let ledge = game.puzzle.ledges[0]
        game.robotPosition = [0, ledge.height, ledge.approachEdgeZ - 0.1]
        game.robotHeading = .pi
        game.setDrive(forward: 1, steering: 0)
        var sawEdge = false, sawFall = false, sawBackwardLean = false
        for _ in 0..<120 {
            game.tick(0.02)
            sawEdge = sawEdge || game.isAtLedgeEdge
            if game.isFalling {
                sawFall = true
                XCTAssertGreaterThan(game.robotPosition.y, 0)
                XCTAssertLessThan(game.robotPosition.y, ledge.height)
                XCTAssertFalse(game.isClimbingLedge)
                game.stopDrive() // Falling must continue without a drive command.
            }
            sawBackwardLean = sawBackwardLean || (game.baseLiftPitch < -0.1 && game.torsoLeanAngle > 0.1)
        }
        XCTAssertTrue(sawEdge); XCTAssertTrue(sawFall); XCTAssertTrue(sawBackwardLean)
        XCTAssertTrue(game.isBaseGrounded)
        XCTAssertEqual(game.robotPosition.y, 0, accuracy: 0.0001)
        XCTAssertEqual(game.baseLiftPitch, 0, accuracy: 0.0001)
        XCTAssertTrue(game.moveBaseFlipperForward(), "Landing makes the next flip available")
        game.tick(GameSession.baseFlipperDuration + 0.05)
        XCTAssertGreaterThan(game.baseLiftPitch, 0.7)
    }

    func testLACTReferenceLengthAndTorsoHingeRemainConsistent() {
        let rest = ROBBodyKinematics.torsoPose(basePitch: 0, leanAngle: 0)
        XCTAssertEqual(rest.lactLength, 0.20955, accuracy: 0.000001)
        let inMotion = ROBBodyKinematics.advanceLean(0, basePitch: 0.8, delta: 0.05)
        XCTAssertEqual(ROBBodyKinematics.lactLength(leanAngle: inMotion), 0.20955 - 0.045, accuracy: 0.000001)
        for pitch: Float in [0.8, -0.35] {
            let lean = ROBBodyKinematics.advanceLean(0, basePitch: pitch, delta: 1)
            let pose = ROBBodyKinematics.torsoPose(basePitch: pitch, leanAngle: lean)
            let original = ROBBodyKinematics.torsoPose(basePitch: pitch, leanAngle: 0)
            XCTAssertLessThanOrEqual(pose.massCenter.z, 0.212725)
            XCTAssertGreaterThanOrEqual(pose.massCenter.z, 0.212725 - 0.42545 * cos(pitch))
            XCTAssertLessThan(simd_distance(pose.position + pose.orientation.act(ROBBodyKinematics.leanHinge),
                                           original.position + original.orientation.act(ROBBodyKinematics.leanHinge)), 0.000001)
            XCTAssertGreaterThan(abs(pose.lactLength - rest.lactLength), 0.001)
        }
    }

    func testWholeBodySwingsAtUpperTreadWheelWithoutLeaningBehindTheTracks() {
        let game = GameSession(audioEnabled: false)
        game.begin(); game.enemies = []
        let robot = RobotFactory.makeROB()
        let scale = ROBScanVisualModel.presentationScale
        let wheels = (1...3).map { robot.findEntity(named: "Left Tri-Wheel \($0)")! }
        let upperWheel = wheels.max { $0.position(relativeTo: robot).y < $1.position(relativeTo: robot).y }!
        XCTAssertEqual(ROBBodyKinematics.leanHinge.y * scale, upperWheel.position(relativeTo: robot).y + 0.073 * scale, accuracy: 0.0001)
        XCTAssertEqual(ROBBodyKinematics.leanHinge.z * scale, upperWheel.position(relativeTo: robot).z, accuracy: 0.0001)
        for lower in [true, false] {
            XCTAssertTrue(lower ? game.moveBaseFlipperForward() : game.moveBaseFlipperBackward())
            for _ in 0..<40 {
                game.tick(0.01)
                RobotFactory.applyWeapons(to: robot, session: game)
                let torso = robot.findEntity(named: "Torso Assembly")!
                let mass = torso.convert(position: ROBBodyKinematics.torsoMassCenter * scale, to: robot)
                XCTAssertLessThanOrEqual(mass.z, 0.212725 * scale + 0.0001)
                XCTAssertGreaterThanOrEqual(mass.z, (0.212725 - 0.42545 * cos(game.baseLiftPitch)) * scale - 0.0001)
                let chest = robot.findEntity(named: "Cerebro Torso")!
                XCTAssertTrue(chest.parent === torso)
                let drive = robot.findEntity(named: "Drive Base Assembly")!
                let bodyHinge = torso.convert(position: ROBBodyKinematics.leanHinge * scale, to: robot)
                let baseHinge = drive.convert(position: (ROBBodyKinematics.leanHinge - [0, 0, 0.212725]) * scale, to: robot)
                XCTAssertLessThan(simd_distance(bodyHinge, baseHinge), 0.0001, "Body stays attached to the hinge throughout the swing")
            }
        }
    }

    func testEveryCampaignMapIncludesRaisedFlipperDeck() {
        let game = GameSession(audioEnabled: false)
        for index in game.levels.indices {
            game.levelIndex = index
            let ledge = try! XCTUnwrap(game.puzzle.ledges.first, "Level \(index + 1) is missing its ledge")
            XCTAssertGreaterThan(ledge.height, 0)
            XCTAssertTrue(ledge.contains(game.puzzle.dock), "Level \(index + 1) dock should require the raised deck")
        }
    }

    func testCapturedSurfacesKeepTextureAndIndependentHeadMotion() throws {
        let robot = RobotFactory.makeROB()
        for name in ["Camera Head", "Cerebro Torso", "Tri-Wheel Chassis", "Left Tri-Wheel Tread", "Right Upper Arm"] {
            let part = try XCTUnwrap(robot.findEntity(named: name) as? ModelEntity)
            let model = try XCTUnwrap(part.model)
            let material = try XCTUnwrap(model.materials.first as? UnlitMaterial)
            XCTAssertNotNil(material.color.texture, name)
            XCTAssertGreaterThan(model.mesh.bounds.extents.y, 0)
            XCTAssertNil(part.components[CollisionComponent.self], "Detailed scans should not create costly convex hulls")
        }
        XCTAssertEqual(robot.components[CollisionComponent.self]?.shapes.count, 1)
        let head = try XCTUnwrap(robot.findEntity(named: "Camera Head"))
        let neck = try XCTUnwrap(robot.findEntity(named: "Neck Pan"))
        let base = try XCTUnwrap(robot.findEntity(named: "Tri-Wheel Chassis"))
        let before = head.convert(position: [0.06, 0, 0], to: robot)
        let baseBefore = base.transformMatrix(relativeTo: robot)
        neck.orientation = simd_quatf(angle: 0.6, axis: [0, 1, 0])
        XCTAssertGreaterThan(simd_distance(head.convert(position: [0.06, 0, 0], to: robot), before), 0.001)
        XCTAssertEqual(base.transformMatrix(relativeTo: robot), baseBefore)
    }

    func testScanModelHasRearAxleFlippersWithIndependentRollers() {
        let game = GameSession(audioEnabled: false)
        let robot = RobotFactory.makeROB()
        for name in [
            "Base Lift Flipper Assembly", "Left Base Lift Flipper Arm", "Right Base Lift Flipper Arm",
            "Drive Base Assembly", "Torso Linear Actuator", "Left ROB Speaker Cone", "Right ROB Speaker Cone",
        ] {
            XCTAssertNotNil(robot.findEntity(named: name), "Missing \(name)")
        }
        for removedHeadTopPart in ["Conference Microphone", "Conference Microphone Capsule", "Conference Microphone Stand", "Conference Microphone Base"] {
            XCTAssertNil(robot.findEntity(named: removedHeadTopPart), "ROB's head must not include \(removedHeadTopPart)")
        }
        for removedCrossbar in ["Base Lift Flipper Motor", "Base Lift Flipper Blade", "Base Lift Flipper Floor Roller"] {
            XCTAssertNil(robot.findEntity(named: removedCrossbar), "Flipper poles must not be joined by \(removedCrossbar)")
        }
        XCTAssertNotNil(robot.findEntity(named: "Flipper Zero Hacker"))
        let flipperAssembly = robot.findEntity(named: "Base Lift Flipper Assembly")
        XCTAssertEqual(flipperAssembly?.parent?.name, "Drive Base Assembly")
        XCTAssertEqual(flipperAssembly?.children.map(\.name).sorted(), ["Left Base Lift Flipper Arm", "Right Base Lift Flipper Arm"])
        let scale = ROBScanVisualModel.presentationScale
        XCTAssertEqual(flipperAssembly?.position.y ?? 0, 0.11 * scale, accuracy: 0.0001)
        XCTAssertEqual(flipperAssembly?.orientation, simd_quatf(angle: 0, axis: [1, 0, 0]))
        for side in ["Left", "Right"] {
            let plate = try! XCTUnwrap(robot.findEntity(named: "\(side) Perforated UHMW Flipper") as? ModelEntity)
            XCTAssertNotNil(plate.model)
            let roller = try! XCTUnwrap(robot.findEntity(named: "\(side) Flipper End Roller"))
            XCTAssertEqual(roller.position.z, -0.33655 * scale, accuracy: 0.0001)
            let axle = try! XCTUnwrap(robot.findEntity(named: "\(side) Tri-Wheel 3"))
            let pivot = flipperAssembly!.position(relativeTo: robot)
            XCTAssertEqual(axle.position(relativeTo: robot).z, pivot.z, accuracy: 0.0001)
            XCTAssertEqual(axle.position(relativeTo: robot).y, pivot.y, accuracy: 0.0001)
        }
        for name in ["Camera Head", "Left Camera Eye", "Right Camera Eye", "Neck Pan", "Left Gripper Finger -1", "Right Gripper Finger 1"] {
            XCTAssertNotNil(robot.findEntity(named: name), "Missing ROB feature: \(name)")
        }


        game.begin()
        XCTAssertTrue(game.moveBaseFlipperForward())
        game.tick(GameSession.baseFlipperDuration / 2)
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertEqual(flipperAssembly?.orientation, simd_quatf(angle: GameSession.baseFlipperForwardAngle / 2, axis: [1, 0, 0]))
        game.tick(GameSession.baseFlipperDuration / 2 + 0.05)
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertEqual(flipperAssembly?.orientation, simd_quatf(angle: GameSession.baseFlipperForwardAngle, axis: [1, 0, 0]))
        XCTAssertNotEqual(robot.findEntity(named: "Drive Base Assembly")?.orientation, simd_quatf(angle: 0, axis: [1, 0, 0]))
        XCTAssertLessThan(robot.findEntity(named: "Torso Assembly")!.orientation.act([0, 1, 0]).z, -0.35)
    }

    func testFlipperRollersClearTheFloorThroughoutLiftCycle() {
        let robot = RobotFactory.makeROB()
        let drive = robot.findEntity(named: "Drive Base Assembly")!
        let flipper = robot.findEntity(named: "Base Lift Flipper Assembly")!
        for degree in stride(from: 0, through: -360, by: -5) {
            let angle = Float(degree) * .pi / 180
            let pitch = 0.23 * Float(-degree) / 360
            flipper.orientation = simd_quatf(angle: angle, axis: [1, 0, 0])
            drive.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0])
            drive.position.y = ROBScanVisualModel.flipperSupportHeight(angle: angle, pitch: pitch)
            for side in ["Left", "Right"] {
                let roller = robot.findEntity(named: "\(side) Flipper End Roller") as! ModelEntity
                let radius = roller.model!.mesh.bounds.extents.x / 2
                XCTAssertGreaterThanOrEqual(roller.position(relativeTo: robot).y - radius, -0.00001,
                                           "Roller penetrated floor at \(degree) degrees")
            }
        }
    }

    func testBookBridgeDroidSectionsRoundTripAndStayOrdered() throws {
        let profile = ROBDroidProfile(
            name: "Encore ROB",
            sections: [.showReady, .voiceAudio, .baseFlipper, .treads]
        )
        XCTAssertEqual(profile.sections, [.treads, .baseFlipper, .voiceAudio, .showReady])
        XCTAssertEqual(try ROBDroidProfileCode.decode(ROBDroidProfileCode.encode(profile)), profile)
    }
}

@MainActor
extension GameSessionTests {
    func testPlasmaBoosterRequiresProgressAndPersistsPurchase() {
        let name = "ROBRocket.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(900, forKey: GameSession.skillPointsStorageKey)
        let locked = GameSession(audioEnabled: false, progressStore: defaults)
        locked.purchaseUpgrade(.rocketBooster)
        XCTAssertFalse(locked.hasRocketBooster)
        XCTAssertEqual(locked.upgradePoints, 900)
        defaults.set(3, forKey: "robHighestCompletedLevel")
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        game.purchaseUpgrade(.rocketBooster)
        XCTAssertTrue(game.hasRocketBooster)
        XCTAssertEqual(game.upgradePoints, 0)
        XCTAssertTrue(GameSession(audioEnabled: false, progressStore: defaults).hasRocketBooster)
        XCTAssertFalse(game.canPurchaseUpgrade(.rocketBooster))
    }

    func testRocketConsumesEnergyStopsOnPauseAndLandsWithoutAirborneRecharge() {
        let defaults = UserDefaults(suiteName: "ROBRocketFlightTests")!
        defer { defaults.removePersistentDomain(forName: "ROBRocketFlightTests") }
        defaults.set(1, forKey: "robRocketBoosterUpgradeLevel")
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        game.begin(); for i in game.enemies.indices { game.enemies[i].isActive = false }
        game.setRocketHeld(true)
        for _ in 0..<60 { game.tick(1.0 / 60) }
        XCTAssertTrue(game.isRocketAirborne)
        XCTAssertTrue(game.isRocketThrusting)
        XCTAssertGreaterThan(game.robotPosition.y, 1)
        XCTAssertEqual(game.energy, 82, accuracy: 0.001)
        let robot = RobotFactory.makeROB(); RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertTrue(robot.findEntity(named: "Left Plasma Jet")?.isEnabled == true)
        XCTAssertTrue(game.pause())
        XCTAssertFalse(game.rocketHeld)
        XCTAssertFalse(game.isRocketThrusting)
        let height = game.robotPosition.y; game.tick(1)
        XCTAssertEqual(game.robotPosition.y, height)
        game.resume()
        for _ in 0..<300 where game.isRocketAirborne { game.tick(1.0 / 60) }
        XCTAssertFalse(game.isRocketAirborne)
        XCTAssertEqual(game.robotPosition.y, 0, accuracy: 0.001)
        XCTAssertEqual(game.energy, 82, accuracy: 0.001)
        RobotFactory.applyWeapons(to: robot, session: game)
        XCTAssertTrue(robot.findEntity(named: "Left Plasma Jet")?.isEnabled == false)
    }

    func testBoosterClearsTallPlatformSideAndLandsOnItsTop() {
        let defaults = UserDefaults(suiteName: "ROBRocketLandingTests")!
        defer { defaults.removePersistentDomain(forName: "ROBRocketLandingTests") }
        defaults.set(1, forKey: "robRocketBoosterUpgradeLevel")
        let game = GameSession(audioEnabled: false, progressStore: defaults)
        game.levelIndex = 15; game.begin()
        for i in game.enemies.indices { game.enemies[i].isActive = false }
        let platform = game.puzzle.ledges[1]
        game.robotPosition = [platform.center.x, 0.34, platform.approachEdgeZ + 0.8]
        XCTAssertFalse(game.isRobotPositionClear([platform.center.x, 0.34, platform.center.y]))
        game.setRocketHeld(true)
        for _ in 0..<100 { game.tick(1.0 / 60) }
        XCTAssertGreaterThan(game.robotPosition.y, platform.height)
        game.setDrive(forward: 1, steering: 0)
        for _ in 0..<85 { game.tick(1.0 / 60) }
        game.stopDrive(); game.setRocketHeld(false)
        for _ in 0..<300 where game.isRocketAirborne { game.tick(1.0 / 60) }
        XCTAssertTrue(platform.contains([game.robotPosition.x, game.robotPosition.z]))
        XCTAssertEqual(game.robotPosition.y, platform.height, accuracy: 0.01)
        XCTAssertTrue(game.isBaseGrounded)
        XCTAssertTrue(game.moveBaseFlipperForward())
    }

    func testRocketStagesHaveElevatedObjectivesAndRequireEquipmentBeforeDeployment() {
        let game = GameSession(audioEnabled: false)
        for index in 15..<24 {
            game.levelIndex = index; game.begin()
            XCTAssertEqual(game.puzzle.ledges.count, 4)
            XCTAssertEqual(game.puzzle.cells.count, 16)
            XCTAssertGreaterThan(game.puzzle.surfaceHeight(at: game.puzzle.dock), 2.5)
            XCTAssertTrue(game.puzzle.ledges.dropFirst().prefix(2).allSatisfy { ledge in game.puzzle.cells.contains(where: ledge.contains) })
            XCTAssertLessThan(game.puzzle.ledges.map(\.height).max()!, 3 * 1.35)
            game.collectedCells = game.level.cellCount
            for i in game.enemies.indices { game.enemies[i].isActive = false }
            game.robotPosition = [game.puzzle.dock.x, 0.34, game.puzzle.dock.y]
            XCTAssertFalse(game.canFinish, "Cannot finish underneath the summit dock")
        }
        game.levelIndex = 14; game.begin()
        deliverCurrentCargo(game)
        game.collectedCells = game.level.cellCount; game.doorOpen = true
        for i in game.enemies.indices { game.enemies[i].isActive = false }
        game.nextLevel(); game.continueAfterUpgradeIntermission()
        XCTAssertEqual(game.levelIndex, 14)
        XCTAssertTrue(game.needsBoosterForNextLevel)
        game.replayForBoosterPoints()
        XCTAssertTrue(game.isRunning)
        XCTAssertFalse(game.isUpgradeIntermission)
    }
}
