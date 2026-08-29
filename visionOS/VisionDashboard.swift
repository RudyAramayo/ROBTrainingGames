import RealityKit
import SwiftUI

struct VisionDashboard: View {
    @Bindable var session: GameSession
    @Bindable var voice: RobotVoice
    @Bindable var controller: VisionGameControllerInput
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @State private var immersive = false

    var body: some View {
        NavigationSplitView {
            List {
                Section("Campaign") {
                    ForEach(session.levels) { level in
                        Label(
                            "\(level.id). \(level.name)",
                            systemImage: level.id - 1 <= session.levelIndex ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
                Section("ROB Loadout") {
                    Label("\(session.highestCompletedLevel)/\(session.levels.count) levels complete", systemImage: "wrench.and.screwdriver.fill")
                    VisionLoadoutMenu(session: session)
                }
                Section("Explore ROB") {
                    ForEach(session.components) { component in
                        Button(component.name) { session.selectedComponent = component }
                    }
                }
            }
            .navigationTitle("ROB Training")
        } detail: {
            VStack(spacing: 18) {
                Image("rob-training-key-art")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                Text("ROB Spatial Workshop").font(.largeTitle.bold())
                Text("Open the complete arena as a tabletop game, place the volume where it is comfortable, and drive with hand pinches, a gamepad, or two spatial controllers.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                HStack {
                    Label("Level \(session.level.id)/\(session.levels.count)", systemImage: "flag.checkered")
                    Label("Score \(session.score)", systemImage: "star.fill")
                    Label("Upgrade points \(session.upgradePoints)", systemImage: "star.circle.fill")
                    Label("Targets \(session.remainingEnemies)", systemImage: "scope")
                }
                .monospacedDigit()
                CombatHealthBars(session: session).frame(width: 420)
                Label(controller.modeDescription, systemImage: controller.isConnected ? "gamecontroller.fill" : "hand.point.up.left.fill")
                    .font(.callout.bold())
                    .foregroundStyle(.cyan)
                Text("Gamepad: both sticks drive matching treads · A/X saber · right trigger laser · B hack · Menu start/pause")
                    .font(.caption.monospaced())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text(session.laserLockDescription)
                    .font(.headline.monospaced())
                    .foregroundStyle(session.lockedEnemy == nil ? .orange : .red)
                HStack {
                    Button("Open Tabletop Game", systemImage: "cube.transparent") {
                        openWindow(id: "ROBTabletop")
                    }
                    Button(immersive ? "Leave Room-Scale Game" : "Enter Room-Scale Game", systemImage: immersive ? "rectangle.portrait.and.arrow.right" : "vision.pro") {
                        Task {
                            if immersive {
                                await dismissImmersiveSpace()
                                immersive = false
                            } else {
                                immersive = await openImmersiveSpace(id: "ROBWorkshop") == .opened
                            }
                        }
                    }
                    Button(session.musicEnabled ? "Generated techno on" : "Music off", systemImage: session.musicEnabled ? "music.note" : "speaker.slash") {
                        session.toggleMusic()
                    }
                }
                .buttonStyle(.borderedProminent)
                Text("Tabletop placement: grab the volume's window bar, move it onto a table, then rotate or resize the volume until the whole arena is comfortable to view.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                RobotVoicePanel(voice: voice, game: session).frame(maxWidth: 620)
                if let component = session.selectedComponent {
                    VStack(alignment: .leading) {
                        Text(component.name).font(.title2.bold())
                        Text(component.summary).foregroundStyle(.secondary)
                    }
                    .padding()
                    .glassBackgroundEffect()
                }
            }
            .padding(28)
        }
        .robGameKeyboardControls(session: session)
        .onAppear { controller.start(session: session) }
    }
}

struct TabletopROBWorkshop: View {
    @Bindable var session: GameSession
    @Bindable var controller: VisionGameControllerInput
    @State private var arenaScale: Float = 0.085
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ROBSpatialArena(session: session, scale: arenaScale, position: [0, -0.3, 0])
            .ornament(attachmentAnchor: .scene(.top)) {
                VisionArenaStatus(session: session, controller: controller)
                    .padding(10)
            }
            .ornament(attachmentAnchor: .scene(.bottom)) {
                VisionControlDeck(
                    session: session,
                    controller: controller,
                    arenaScale: $arenaScale,
                    scaleRange: 0.065...0.105,
                    placementHelp: "Grab the volume bar to place this arena on a tabletop."
                )
                .frame(width: 760)
                .padding(12)
            }
            .robGameKeyboardControls(session: session)
            .onAppear { controller.start(session: session) }
            .onReceive(timer) { _ in session.tick(1.0 / 30.0) }
    }
}

struct ImmersiveROBWorkshop: View {
    @Bindable var session: GameSession
    @Bindable var controller: VisionGameControllerInput
    @State private var arenaScale: Float = 0.16
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ROBSpatialArena(session: session, scale: arenaScale, position: [0, 0.72, -2.0])
            .ornament(attachmentAnchor: .scene(.top)) {
                VisionArenaStatus(session: session, controller: controller)
                    .padding(10)
            }
            .ornament(attachmentAnchor: .scene(.bottom)) {
                VisionControlDeck(
                    session: session,
                    controller: controller,
                    arenaScale: $arenaScale,
                    scaleRange: 0.1...0.24,
                    placementHelp: "Room-scale view keeps the entire arena grouped and centered."
                )
                .frame(width: 760)
                .padding(12)
            }
            .robGameKeyboardControls(session: session)
            .onAppear { controller.start(session: session) }
            .onReceive(timer) { _ in session.tick(1.0 / 30.0) }
    }
}

private struct ROBSpatialArena: View {
    @Bindable var session: GameSession
    let scale: Float
    let position: SIMD3<Float>
    @State private var arenaRoot = Entity()
    @State private var robot = RobotFactory.makeROB(componentMode: true)

    var body: some View {
        RealityView { content in
            arenaRoot.name = "ROB Spatial Arena Root"
            arenaRoot.scale = .init(repeating: scale)
            arenaRoot.position = position
            robot.position = session.robotPosition
            robot.orientation = simd_quatf(angle: session.robotHeading, axis: [0, 1, 0])
            arenaRoot.addChild(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle))
            arenaRoot.addChild(RobotFactory.makeCombatLayer(session: session))
            arenaRoot.addChild(robot)
            content.add(arenaRoot)
        } update: { _ in
            arenaRoot.scale = .init(repeating: scale)
            arenaRoot.position = position
            robot.position = session.robotPosition
            robot.orientation = simd_quatf(angle: session.robotHeading, axis: [0, 1, 0])
            RobotFactory.applyWeapons(to: robot, session: session, componentMode: true)

            let roomName = "Training Room-\(session.levelIndex)"
            if let room = arenaRoot.findEntity(named: roomName) {
                RobotFactory.applyPuzzleState(to: room, session: session)
            } else {
                for child in Array(arenaRoot.children) where child.name.hasPrefix("Training Room-") {
                    child.removeFromParent()
                }
                arenaRoot.addChild(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle))
            }

            let combatName = RobotFactory.combatLayerName(level: session.levelIndex)
            if let combat = arenaRoot.findEntity(named: combatName) {
                RobotFactory.applyCombatState(to: combat, session: session)
            } else {
                for child in Array(arenaRoot.children) where child.name.hasPrefix("Combat Layer-") {
                    child.removeFromParent()
                }
                arenaRoot.addChild(RobotFactory.makeCombatLayer(session: session))
            }
        }
    }
}

private struct VisionArenaStatus: View {
    @Bindable var session: GameSession
    @Bindable var controller: VisionGameControllerInput

    var body: some View {
        HStack(spacing: 14) {
            Label("Level \(session.level.id)", systemImage: "flag.checkered")
            Label("\(session.remainingEnemies) targets", systemImage: "scope")
            Label(controller.modeDescription, systemImage: controller.spatialControllerCount >= 2 ? "vision.pro" : controller.isConnected ? "gamecontroller.fill" : "hand.raised.fill")
            Text(session.laserLockDescription)
                .foregroundStyle(session.lockedEnemy == nil ? .orange : .red)
        }
        .font(.caption.bold())
        .monospacedDigit()
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassBackgroundEffect()
    }
}

private struct VisionControlDeck: View {
    @Bindable var session: GameSession
    @Bindable var controller: VisionGameControllerInput
    @Binding var arenaScale: Float
    let scaleRange: ClosedRange<Float>
    let placementHelp: String

    var body: some View {
        VStack(spacing: 10) {
            if session.isUpgradeIntermission {
                VisionUpgradeIntermission(session: session)
            } else {
                Text("HAND + CONTROLLER DRIVE DECK").font(.headline)
                Text("Pinch each tread pad and drag up or down. Two hands can command the treads independently.")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                VisionHandDriveControls(session: session)
                HStack {
                    LaserChargeButton(session: session, title: session.rangedWeapon.displayName, compact: true)
                    Button(session.meleeWeapon.displayName, systemImage: "bolt.fill") { session.saberAttack() }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                    if session.hasFlipperHackTargets {
                        Button(session.flipperHackDescription, systemImage: "dot.radiowaves.left.and.right") {
                            session.startFlipperHack()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(session.isHackingCamera || session.isHackingDoor ? .yellow : session.canStartCameraHack ? .cyan : session.canStartDoorHack ? .orange : .gray)
                        .disabled(!session.canStartFlipperHack)
                    }
                    VisionLoadoutMenu(session: session, compact: true)
                }
                HStack {
                    Button(session.isRunning ? "Pause" : session.isPaused ? "Resume" : "Start Mission", systemImage: session.isRunning ? "pause.fill" : "play.fill") {
                        if session.isRunning { _ = session.pause() }
                        else if session.isPaused { _ = session.resume() }
                        else { session.begin() }
                    }
                    Button("Reset", systemImage: "arrow.counterclockwise") { session.reset() }
                    if session.canFinish {
                        Button(session.levelIndex == session.levels.count - 1 ? "Finish Campaign" : "Complete Level") { session.nextLevel() }
                    }
                    Slider(value: $arenaScale, in: scaleRange) { Text("Arena size") }
                        .frame(width: 180)
                }
                Label(controller.modeDescription, systemImage: controller.isConnected ? "gamecontroller.fill" : "hand.point.up.left.fill")
                    .font(.caption.bold())
                    .foregroundStyle(controller.spatialControllerCount >= 2 ? .green : .secondary)
                Text(placementHelp).font(.caption2).foregroundStyle(.secondary)
                CombatHealthBars(session: session, compact: true).frame(width: 390)
            }
        }
        .padding(14)
        .glassBackgroundEffect()
        .onDisappear { session.stopDrive() }
    }
}

private struct VisionUpgradeIntermission: View {
    @Bindable var session: GameSession

    var body: some View {
        VStack(spacing: 12) {
            Label("LEVEL \(session.level.id) CLEARED · UPGRADE BAY", systemImage: "flag.checkered.circle.fill")
                .font(.title3.bold())
                .foregroundStyle(.green)
            Label("\(session.upgradePoints) battle points", systemImage: "star.circle.fill")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.yellow)
            HStack(spacing: 8) {
                ForEach(ROBUpgrade.allCases) { upgrade in
                    let level = session.upgradeLevel(upgrade)
                    let cost = session.upgradeCost(upgrade)
                    Button {
                        session.purchaseUpgrade(upgrade)
                    } label: {
                        VStack(spacing: 3) {
                            Text(upgrade.displayName).font(.caption.bold())
                            Text(cost.map { "L\(level) · \($0)" } ?? "MAX")
                                .font(.caption2.monospacedDigit())
                        }
                    }
                    .disabled(cost == nil || session.upgradePoints < (cost ?? 0))
                }
            }
            Text(session.message).font(.caption).foregroundStyle(.cyan).lineLimit(2)
            Button("Deploy to Level \(session.level.id + 1)", systemImage: "play.fill") {
                session.continueAfterUpgradeIntermission()
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .onAppear { session.stopDrive() }
    }
}

private struct VisionHandDriveControls: View {
    @Bindable var session: GameSession
    @State private var left = 0.0
    @State private var right = 0.0

    var body: some View {
        HStack(spacing: 18) {
            VisionTreadPad(title: "LEFT TREAD", value: $left) { newValue in
                left = newValue
                apply()
            }
            Button("STOP", systemImage: "stop.fill") { stop() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.escape, modifiers: [])
            VisionTreadPad(title: "RIGHT TREAD", value: $right) { newValue in
                right = newValue
                apply()
            }
        }
        .onDisappear(perform: stop)
    }

    private func apply() {
        session.setTreads(left: left, right: right)
    }

    private func stop() {
        left = 0
        right = 0
        session.stopDrive()
    }
}

private struct VisionTreadPad: View {
    let title: String
    @Binding var value: Double
    let changed: (Double) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2.bold())
            GeometryReader { proxy in
                let travel = max(1, proxy.size.height * 0.38)
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.cyan.opacity(0.18))
                    Capsule().fill(.white.opacity(0.18)).frame(width: 5)
                    Circle()
                        .fill(value == 0 ? .cyan : .white)
                        .shadow(color: .cyan.opacity(0.7), radius: 8)
                        .frame(width: 42, height: 42)
                        .offset(y: -value * travel)
                    VStack {
                        Text("▲")
                        Spacer()
                        Text("▼")
                    }
                    .font(.caption.bold())
                    .padding(8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let raw = (proxy.size.height / 2 - gesture.location.y) / travel
                            let newValue = min(1, max(-1, raw))
                            value = newValue
                            changed(newValue)
                        }
                        .onEnded { _ in
                            value = 0
                            changed(0)
                        }
                )
            }
            .frame(width: 112, height: 126)
            Text(value.formatted(.number.precision(.fractionLength(2))))
                .font(.caption2.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value == 0 ? "Stopped" : value > 0 ? "Forward" : "Reverse")
    }
}

private struct VisionLoadoutMenu: View {
    @Bindable var session: GameSession
    var compact = false

    var body: some View {
        Menu {
            Section("Body Finish") {
                ForEach(ROBFinish.allCases) { finish in
                    Button { session.selectFinish(finish) } label: {
                        Label(finish.displayName, systemImage: session.robotFinish == finish ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
            Section("Smiley Color") {
                ForEach(ROBFaceColor.allCases) { color in
                    Button { session.selectFaceColor(color) } label: {
                        Label(color.displayName, systemImage: session.faceColor == color ? "checkmark.circle.fill" : "face.smiling")
                    }
                }
            }
            Section("Ranged Weapons") {
                ForEach(ROBRangedWeapon.allCases) { weapon in
                    Button { session.selectRangedWeapon(weapon) } label: {
                        Label(
                            session.isUnlocked(weapon) ? weapon.displayName : "\(weapon.displayName) · Level \(weapon.requiredCompletedLevel)",
                            systemImage: session.rangedWeapon == weapon ? "checkmark.circle.fill" : session.isUnlocked(weapon) ? "circle" : "lock.fill"
                        )
                    }
                    .disabled(!session.isUnlocked(weapon))
                }
            }
            Section("Melee Weapons") {
                ForEach(ROBMeleeWeapon.allCases) { weapon in
                    Button { session.selectMeleeWeapon(weapon) } label: {
                        Label(
                            session.isUnlocked(weapon) ? weapon.displayName : "\(weapon.displayName) · Level \(weapon.requiredCompletedLevel)",
                            systemImage: session.meleeWeapon == weapon ? "checkmark.circle.fill" : session.isUnlocked(weapon) ? "circle" : "lock.fill"
                        )
                    }
                    .disabled(!session.isUnlocked(weapon))
                }
            }
            Section("Performance Upgrades · \(session.upgradePoints) points") {
                ForEach(ROBUpgrade.allCases) { upgrade in
                    let level = session.upgradeLevel(upgrade)
                    let cost = session.upgradeCost(upgrade)
                    Button { session.purchaseUpgrade(upgrade) } label: {
                        Label(
                            cost.map { "\(upgrade.displayName) L\(level) · \($0) points" } ?? "\(upgrade.displayName) · MAX",
                            systemImage: upgrade == .speedBoost ? "speedometer" : upgrade == .energyCapacity ? "battery.100percent.bolt" : "scope"
                        )
                    }
                    .disabled(cost == nil || session.upgradePoints < (cost ?? 0))
                }
            }
        } label: {
            Label(
                compact ? "Loadout" : "\(session.robotFinish.displayName) · \(session.rangedWeapon.shortName) · \(session.meleeWeapon.shortName)",
                systemImage: "paintpalette.fill"
            )
        }
    }
}
