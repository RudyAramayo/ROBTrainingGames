import RealityKit
import SwiftUI

struct IOSRootView: View {
    @Bindable var session: GameSession
    @Bindable var voice: RobotVoice
    @Environment(\.scenePhase) private var scenePhase
    @State private var fullScreenExperience: FullScreenExperience?

    var body: some View {
        TabView {
            MissionLaunchView(session: session, launch: launchMission)
                .tabItem { Label("Play", systemImage: "gamecontroller.fill") }
            ARLabLaunchView(session: session, launch: launchARLab)
                .tabItem { Label("AR Lab", systemImage: "arkit") }
            ComponentExplorer(session: session).tabItem { Label("ROB", systemImage: "cpu") }
            RobotVoiceScreen(voice: voice, session: session).tabItem { Label("Voice", systemImage: "waveform") }
        }
        .tint(.cyan)
        .onChange(of: session.situationCount) { _, count in if count > 0 { voice.react(to: session.lastSituation, game: session) } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.pause() } }
        .fullScreenCover(item: $fullScreenExperience) { experience in
            switch experience {
            case .mission:
                MissionView(session: session, onExit: exitMission)
                    .interactiveDismissDisabled()
            case .arLab:
                ARLabView(session: session, onExit: exitARLab)
                    .interactiveDismissDisabled()
            }
        }
    }

    private func launchMission() {
        if session.isPaused { session.resume() }
        else if !session.isRunning { session.begin() }
        fullScreenExperience = .mission
    }

    private func exitMission() {
        session.pause()
        fullScreenExperience = nil
    }

    private func launchARLab() {
        if session.isPaused { session.resume() }
        else if !session.isRunning { session.begin() }
        fullScreenExperience = .arLab
    }

    private func exitARLab() {
        session.pause()
        fullScreenExperience = nil
    }
}

private enum FullScreenExperience: String, Identifiable {
    case mission
    case arLab

    var id: String { rawValue }
}

private struct MissionLaunchView: View {
    @Bindable var session: GameSession
    let launch: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                menuBackground
                ScrollView {
                    VStack(spacing: 20) {
                        ExperienceHero(
                            title: "ROB Training Missions",
                            message: "Enter the arena in a dedicated full-screen game. Leaving the arena pauses your current level.",
                            symbol: "gamecontroller.fill",
                            colors: [.cyan, .blue]
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Level \(session.level.id)", systemImage: "flag.checkered")
                                Spacer()
                                Text(session.level.name).foregroundStyle(.cyan)
                            }
                            .font(.headline)
                            Text(session.level.challenge).font(.subheadline).foregroundStyle(.secondary)
                            CombatHealthBars(session: session, compact: true)
                            HStack {
                                Label("\(session.collectedCells)/\(session.level.cellCount) cells", systemImage: "bolt.fill")
                                Spacer()
                                Label("\(session.remainingEnemies) targets", systemImage: "scope")
                                Spacer()
                                Label("\(session.score)", systemImage: "star.fill")
                            }
                            .font(.caption.bold())
                            .monospacedDigit()
                        }
                        .experienceCard()

                        Button(action: launch) {
                            Label(session.isPaused ? "Resume Full-Screen Mission" : "Start Full-Screen Mission", systemImage: session.isPaused ? "play.fill" : "arrow.up.right.square.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .controlSize(.large)

                        if session.isPaused {
                            Button(role: .destructive) { session.reset() } label: {
                                Label("Abandon Mission and Reset", systemImage: "arrow.counterclockwise")
                            }
                        }

                        Text(session.isPaused ? "Mission paused safely. No enemies, timers, or movement advance while you are in the menu or AR Lab." : "Starting opens the game above this menu and hides every tab until you exit.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .padding(.bottom, 96)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Play")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var menuBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.02, green: 0.08, blue: 0.14), Color(red: 0.04, green: 0.2, blue: 0.24), Color(red: 0.06, green: 0.05, blue: 0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct ARLabLaunchView: View {
    @Bindable var session: GameSession
    let launch: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.11, green: 0.05, blue: 0.24), Color(red: 0.03, green: 0.15, blue: 0.22), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        ExperienceHero(
                            title: "ROB AR Missions",
                            message: "Place the full training arena in your room, drive ROB, fight enemies, collect cells, unlock doors, and finish the same campaign in augmented reality.",
                            symbol: "arkit",
                            colors: [.purple, .cyan]
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Live Campaign", systemImage: "gamecontroller.fill").font(.headline)
                            Text("AR uses your current level, health, objectives, weapons, and progress. Leaving the arena pauses the mission safely.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Divider()
                            Label("\(session.robotFinish.displayName) · \(session.rangedWeapon.displayName) · \(session.meleeWeapon.displayName)", systemImage: "wrench.and.screwdriver.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.cyan)
                        }
                        .experienceCard()

                        Button(action: launch) {
                            Label(session.isPaused ? "Resume Full-Screen AR Mission" : "Start Full-Screen AR Mission", systemImage: "camera.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.large)
                    }
                    .padding()
                    .padding(.bottom, 96)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("AR Lab")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

private struct ExperienceHero: View {
    let title: String
    let message: String
    let symbol: String
    let colors: [Color]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 150, height: 150)
                .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 38))
                .shadow(color: colors.last?.opacity(0.65) ?? .clear, radius: 24)
            Text(title).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct MissionView: View {
    @Bindable var session: GameSession
    let onExit: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @AppStorage("robLocalHighScore") private var highScore = 0
    private var compactPhoneLayout: Bool { horizontalSizeClass == .compact }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                RealityView { content in
                    content.add(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle))
                    let rob = RobotFactory.makeROB(); rob.position = session.robotPosition; content.add(rob)
                    content.add(RobotFactory.makeCombatLayer(session: session))
                    let camera = PerspectiveCamera(); camera.name = "Mission Camera"; camera.look(at: session.robotPosition + SIMD3<Float>(0, 0.65, -1.1), from: session.robotPosition + SIMD3<Float>(3.4, 5.2, 5.4), relativeTo: nil); content.add(camera)
                } update: { content in
                    if let rob = content.entities.first(where: { $0.name == "ROB" }) { rob.position = session.robotPosition; rob.orientation = simd_quatf(angle: session.robotHeading, axis: [0, 1, 0]); RobotFactory.applyWeapons(to: rob, session: session) }
                    if let camera = content.entities.first(where: { $0.name == "Mission Camera" }) { camera.look(at: session.robotPosition + SIMD3<Float>(0, 0.65, -1.1), from: session.robotPosition + SIMD3<Float>(3.4, 5.2, 5.4), relativeTo: nil) }
                    let roomName = "Training Room-\(session.levelIndex)"
                    if let room = content.entities.first(where: { $0.name == roomName }) { RobotFactory.applyPuzzleState(to: room, session: session) }
                    else { content.entities.filter { $0.name.hasPrefix("Training Room-") }.forEach { $0.removeFromParent() }; content.add(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle)) }
                    let combatName = RobotFactory.combatLayerName(level: session.levelIndex)
                    if let combat = content.entities.first(where: { $0.name == combatName }) { RobotFactory.applyCombatState(to: combat, session: session) }
                    else { content.entities.filter { $0.name.hasPrefix("Combat Layer-") }.forEach { $0.removeFromParent() }; content.add(RobotFactory.makeCombatLayer(session: session)) }
                }
                    .ignoresSafeArea().background(.black)
                VStack(spacing: verticalSizeClass == .compact ? 4 : 10) {
                    if compactPhoneLayout {
                        CompactMissionStats(session: session, onExit: onExit).padding(.horizontal, 8)
                    } else {
                        VStack(spacing: 7) {
                            HStack { Label("Level \(session.level.id)/\(session.levels.count)", systemImage: "flag.checkered"); Spacer(); MissionKeyStatus(session: session); Text("Cells \(session.collectedCells)/\(session.level.cellCount)").monospacedDigit(); Text("Targets \(session.remainingEnemies)").monospacedDigit(); Text("Score \(session.score)").monospacedDigit(); Text("Best \(highScore)").foregroundStyle(.cyan).monospacedDigit() }.font(.headline)
                            CombatHealthBars(session: session).frame(maxWidth: 460)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal)
                    }
                    Spacer()
                    Text(session.message).font(.subheadline.bold()).lineLimit(compactPhoneLayout ? 1 : 2).padding(.horizontal, 14).padding(.vertical, 8).background(.black.opacity(0.65), in: Capsule())
                    if !compactPhoneLayout && verticalSizeClass != .compact {
                        Text("Move: WASD or arrows · Slash: Space · Laser: Q").font(.caption2.bold()).foregroundStyle(.cyan).padding(.horizontal, 12).padding(.vertical, 6).background(.black.opacity(0.65), in: Capsule())
                    }
                    if compactPhoneLayout {
                        MobileTankControls(session: session).padding(.horizontal, 8)
                    } else {
                        VStack(spacing: 6) {
                            MobileTankControls(session: session)
                            if verticalSizeClass != .compact {
                                Text("Independent treads · sweep left, sweep right, then spin · hold laser to charge").font(.caption.bold()).foregroundStyle(.cyan)
                                Text("Drive onto keys, doors, and cells while enemies fight back").font(.caption2)
                            }
                        }
                        .padding(verticalSizeClass == .compact ? 6 : 16)
                    }
                }
                .padding(.bottom, compactPhoneLayout ? 54 : 0)
            }
            .navigationTitle(compactPhoneLayout ? "" : session.level.name).navigationBarTitleDisplayMode(.inline)
            .toolbar(compactPhoneLayout ? .hidden : .visible, for: .navigationBar)
            .robGameKeyboardControls(session: session)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { session.toggleMusic() } label: { Label(session.musicEnabled ? "Techno on" : "Music off", systemImage: session.musicEnabled ? "music.note" : "speaker.slash") }
                    Button(missionActionTitle) { performMissionAction() }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(action: onExit) { Label("Menu", systemImage: "xmark.circle.fill") }
                    if session.canFinish { Button(session.levelIndex == session.levels.count - 1 ? "Finish" : "Next Level") { session.nextLevel() } }
                }
            }
            .onReceive(timer) { _ in session.tick(1.0 / 30.0); highScore = max(highScore, session.score) }
        }
    }

    private var missionActionTitle: String {
        session.isRunning ? "Reset" : session.isPaused ? "Resume" : "Start"
    }

    private func performMissionAction() {
        if session.isRunning { session.reset() }
        else if session.isPaused { session.resume() }
        else { session.begin() }
    }
}

private struct CompactMissionStats: View {
    @Bindable var session: GameSession
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Button(action: onExit) {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel("Exit mission to menu")
                Text("Level \(session.level.id) · \(session.level.name)").font(.subheadline.bold()).lineLimit(1)
                Spacer(minLength: 2)
                Button { session.toggleMusic() } label: {
                    Image(systemName: session.musicEnabled ? "music.note" : "speaker.slash")
                }
                Button(missionActionTitle) { performMissionAction() }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
            }
            HStack(spacing: 12) {
                Label("\(session.level.id)/\(session.levels.count)", systemImage: "flag.checkered")
                Spacer(minLength: 0)
                MissionKeyStatus(session: session, compact: true)
                Label("\(session.collectedCells)/\(session.level.cellCount)", systemImage: "bolt.fill")
                Label("\(session.remainingEnemies)", systemImage: "scope")
                Label("\(session.score)", systemImage: "star.fill")
            }
            .font(.caption.bold())
            .monospacedDigit()
            CombatHealthBars(session: session, compact: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var missionActionTitle: String {
        session.isRunning ? "Reset" : session.isPaused ? "Resume" : "Start"
    }

    private func performMissionAction() {
        if session.isRunning { session.reset() }
        else if session.isPaused { session.resume() }
        else { session.begin() }
    }
}

private struct MissionKeyStatus: View {
    @Bindable var session: GameSession
    var compact = false

    var body: some View {
        if !session.level.requiresKey {
            Label(compact ? "Key N/A" : "Key not required", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Label(session.hasKey ? "Key" : "Find key", systemImage: session.hasKey ? "key.fill" : "key")
        }
    }
}

private struct RobotVoiceScreen: View {
    @Bindable var voice: RobotVoice
    @Bindable var session: GameSession

    var body: some View {
        NavigationStack {
            ScrollView {
                RobotVoicePanel(voice: voice, game: session, observesGameEvents: false)
                    .padding()
            }
            .navigationTitle("ROB Voice")
        }
    }
}

struct MobileTankControls: View {
    @Bindable var session: GameSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var leftDemand = 0.0
    @State private var rightDemand = 0.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TreadJoystick(title: "LEFT", demand: updateLeft)
            VStack(spacing: 5) {
                if session.level.requiresKey && !session.doorOpen {
                    Button { session.startDoorHack() } label: {
                        Label(session.doorHackDescription, systemImage: "lock.open.trianglebadge.exclamationmark")
                            .font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(session.canStartDoorHack ? .orange : .gray)
                    .disabled(!session.canStartDoorHack)
                }
                LaserChargeButton(session: session, title: session.rangedWeapon.shortName, compact: true)
                Button { session.saberAttack() } label: {
                    Label(session.meleeWeapon.shortName, systemImage: session.meleeWeapon == .dualSabers ? "sparkles" : "hammer.fill").font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.75)
                }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                Text(session.laserLockDescription)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .foregroundStyle(session.lockedEnemy == nil ? .orange : .red)
            }
            .frame(maxWidth: .infinity)
            TreadJoystick(title: "RIGHT", demand: updateRight)
        }
        .padding(8)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 720)
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
        .onDisappear(perform: stop)
    }

    private func updateLeft(_ value: Double) {
        leftDemand = value
        session.setTreads(left: leftDemand, right: rightDemand)
    }

    private func updateRight(_ value: Double) {
        rightDemand = value
        session.setTreads(left: leftDemand, right: rightDemand)
    }

    private func stop() {
        leftDemand = 0
        rightDemand = 0
        session.stopDrive()
    }
}

private struct TreadJoystick: View {
    let title: String
    let demand: (Double) -> Void
    @State private var knobOffset: CGFloat = 0
    private let travel: CGFloat = 28

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(.cyan.opacity(0.2)).overlay(Circle().stroke(.cyan.opacity(0.8), lineWidth: 2))
                Capsule().fill(.cyan.opacity(0.25)).frame(width: 5, height: 54)
                Circle().fill(.cyan).frame(width: 34, height: 34).shadow(color: .cyan.opacity(0.8), radius: 6).offset(y: knobOffset)
            }
            .frame(width: 82, height: 82)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let value = max(-1, min(1, Double(-gesture.translation.height / travel)))
                        knobOffset = -CGFloat(value) * travel
                        demand(value)
                    }
                    .onEnded { _ in release() }
            )
            Text("\(title) TREAD").font(.caption2.bold()).foregroundStyle(.cyan)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.capitalized) tread joystick")
        .accessibilityValue(knobOffset == 0 ? "Stopped" : knobOffset < 0 ? "Forward" : "Reverse")
        .accessibilityAdjustableAction { direction in
            let value = direction == .increment ? 1.0 : direction == .decrement ? -1.0 : 0.0
            knobOffset = -CGFloat(value) * travel
            demand(value)
        }
        .onDisappear(perform: release)
    }

    private func release() {
        knobOffset = 0
        demand(0)
    }
}

struct DrivePad: View {
    @Bindable var session: GameSession
    var compact = false
    var body: some View {
        Group {
            if compact {
                HStack(spacing: 4) { DriveHoldButton(session: session, title: "←", steering: 1); DriveHoldButton(session: session, title: "↑", forward: 1); Button("■") { session.stopDrive() }; DriveHoldButton(session: session, title: "↓", forward: -1); DriveHoldButton(session: session, title: "→", steering: -1) }
            } else {
                VStack(spacing: 6) { DriveHoldButton(session: session, title: "↑", forward: 1); HStack { DriveHoldButton(session: session, title: "←", steering: 1); Button("■") { session.stopDrive() }; DriveHoldButton(session: session, title: "→", steering: -1) }; DriveHoldButton(session: session, title: "↓", forward: -1); Text("Treads \(session.leftTread, format: .number.precision(.fractionLength(1))) · \(session.rightTread, format: .number.precision(.fractionLength(1)))").font(.caption.monospacedDigit()) }
            }
        }.buttonStyle(.borderedProminent).tint(.cyan).padding(compact ? 6 : 10).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ComponentExplorer: View {
    @Bindable var session: GameSession
    private let finishColumns = [GridItem(.adaptive(minimum: 112), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.08, blue: 0.16),
                        Color(red: 0.035, green: 0.15, blue: 0.2),
                        Color(red: 0.055, green: 0.055, blue: 0.14),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        WorkshopRobotPreview(session: session)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Workshop Progress", systemImage: "wrench.and.screwdriver.fill").font(.headline)
                                Spacer()
                                Text("\(session.highestCompletedLevel)/\(session.levels.count) levels").monospacedDigit().foregroundStyle(.cyan)
                            }
                            ProgressView(value: Double(session.highestCompletedLevel), total: Double(session.levels.count)).tint(.cyan)
                            Text(nextUnlockText).font(.caption).foregroundStyle(.secondary)
                            Label("\(session.upgradePoints) spendable mission points", systemImage: "star.circle.fill")
                                .font(.subheadline.bold()).foregroundStyle(.yellow).monospacedDigit()
                        }
                        .workshopCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Performance Upgrades", systemImage: "gauge.with.dots.needle.67percent").font(.title3.bold())
                            Text("Points earned from cells, hacks, enemies, and fast finishes stay available between campaigns.")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(ROBUpgrade.allCases) { upgrade in
                                UpgradeOption(session: session, upgrade: upgrade)
                            }
                        }
                        .workshopCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Body Finish", systemImage: "paintpalette.fill").font(.title3.bold())
                            Text("Changes the chassis, torso, arms, and camera housing everywhere ROB appears.").font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: finishColumns, spacing: 10) {
                                ForEach(ROBFinish.allCases) { finish in
                                    Button { session.selectFinish(finish) } label: {
                                        VStack(spacing: 7) {
                                            Circle().fill(Color(uiColor: RobotFactory.finishColor(for: finish))).frame(width: 36, height: 36)
                                                .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1))
                                            Text(finish.displayName).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.75)
                                            Image(systemName: session.robotFinish == finish ? "checkmark.circle.fill" : "circle").foregroundStyle(.cyan)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .background(session.robotFinish == finish ? .cyan.opacity(0.18) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                        .workshopCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Smiley Color", systemImage: "face.smiling").font(.title3.bold())
                            Text("Changes the glowing smile on ROB's camera head everywhere ROB appears.").font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: finishColumns, spacing: 10) {
                                ForEach(ROBFaceColor.allCases) { color in
                                    Button { session.selectFaceColor(color) } label: {
                                        VStack(spacing: 7) {
                                            Image(systemName: "face.smiling")
                                                .font(.system(size: 34, weight: .bold))
                                                .foregroundStyle(Color(uiColor: RobotFactory.faceColor(for: color)))
                                            Text(color.displayName).font(.caption.bold())
                                            Image(systemName: session.faceColor == color ? "checkmark.circle.fill" : "circle").foregroundStyle(.cyan)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .background(session.faceColor == color ? .cyan.opacity(0.18) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                        .workshopCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Ranged Weapons", systemImage: "scope").font(.title3.bold())
                            ForEach(ROBRangedWeapon.allCases) { weapon in
                                LoadoutOption(
                                    title: weapon.displayName,
                                    summary: weapon.summary,
                                    systemImage: weapon == .shoulderGatling ? "scope" : weapon == .twinBlasters ? "bolt.horizontal.fill" : "wave.3.right.circle.fill",
                                    selected: session.rangedWeapon == weapon,
                                    unlocked: session.isUnlocked(weapon),
                                    requiredLevel: weapon.requiredCompletedLevel
                                ) { session.selectRangedWeapon(weapon) }
                            }
                        }
                        .workshopCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Melee Weapons", systemImage: "hammer.fill").font(.title3.bold())
                            ForEach(ROBMeleeWeapon.allCases) { weapon in
                                LoadoutOption(
                                    title: weapon.displayName,
                                    summary: weapon.summary,
                                    systemImage: weapon == .dualSabers ? "sparkles" : "hammer.fill",
                                    selected: session.meleeWeapon == weapon,
                                    unlocked: session.isUnlocked(weapon),
                                    requiredLevel: weapon.requiredCompletedLevel
                                ) { session.selectMeleeWeapon(weapon) }
                            }
                        }
                        .workshopCard()

                        Text(session.message).font(.callout.bold()).foregroundStyle(.cyan).frame(maxWidth: .infinity, alignment: .leading).workshopCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Inside ROB", systemImage: "cpu").font(.title2.bold())
                            Text("Select a system to highlight where it lives inside ROB.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            InsideROBDiagram(
                                component: selectedComponent,
                                faceColor: Color(uiColor: RobotFactory.faceColor(for: session.faceColor))
                            )

                            ForEach(session.components) { component in
                                let selected = component.id == selectedComponent.id
                                Button { session.selectedComponent = component } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: component.systemImage)
                                            .font(.title2)
                                            .foregroundStyle(component.accentColor)
                                            .frame(width: 38, height: 38)
                                            .background(component.accentColor.opacity(0.14), in: Circle())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(component.name).font(.headline)
                                            Text(component.summary).font(.caption).foregroundStyle(.secondary).lineLimit(selected ? nil : 2)
                                        }
                                        Spacer(minLength: 4)
                                        Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                                            .foregroundStyle(selected ? component.accentColor : .secondary)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selected ? component.accentColor.opacity(0.16) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selected ? component.accentColor.opacity(0.8) : .white.opacity(0.08), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .workshopCard()
                    }
                    .padding()
                    .frame(maxWidth: 840)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("ROB Workshop")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var selectedComponent: ROBComponent {
        session.selectedComponent ?? session.components[0]
    }

    private var nextUnlockText: String {
        if session.highestCompletedLevel < 5 { return "Next unlock: Twin Blasters after Level 5." }
        if session.highestCompletedLevel < 10 { return "Next unlock: Power Hammer after Level 10." }
        if session.highestCompletedLevel < 15 { return "Next unlock: Arc Cannon after Level 15." }
        return "Every workshop weapon is unlocked."
    }
}

private struct WorkshopRobotPreview: View {
    @Bindable var session: GameSession

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.22, blue: 0.48),
                    Color(red: 0.025, green: 0.16, blue: 0.24),
                    Color(red: 0.08, green: 0.35, blue: 0.4),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle().fill(.cyan.opacity(0.16)).frame(width: 285).blur(radius: 18)
            robotIllustration
        }
        .frame(height: 330)
        .background(LinearGradient(colors: [.indigo.opacity(0.65), .cyan.opacity(0.22)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .topLeading) {
            Label("ROB LOADOUT PREVIEW", systemImage: "paintbrush.pointed.fill").font(.caption.bold()).foregroundStyle(.cyan)
                .padding(.horizontal, 10).padding(.vertical, 7).background(.black.opacity(0.62), in: Capsule()).padding(12)
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.robotFinish.displayName).font(.headline)
                Text("\(session.rangedWeapon.displayName) · \(session.meleeWeapon.displayName)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)).padding(12)
        }
    }

    private var finish: Color { Color(uiColor: RobotFactory.finishColor(for: session.robotFinish)) }
    private var smileColor: Color { Color(uiColor: RobotFactory.faceColor(for: session.faceColor)) }

    private var robotIllustration: some View {
        ZStack {
            Ellipse().fill(.cyan.opacity(0.18)).frame(width: 280, height: 54).offset(y: 105).blur(radius: 8)
            ForEach([-1.0, 1.0], id: \.self) { side in
                ZStack {
                    TriWheelTreadShape().fill(.black)
                    VStack(spacing: 8) {
                        ForEach(0..<10, id: \.self) { _ in Rectangle().fill(.gray.opacity(0.72)).frame(width: 52, height: 3) }
                    }
                    .clipShape(TriWheelTreadShape())
                    Circle().fill(.gray).frame(width: 27, height: 27).overlay(Circle().stroke(.orange, lineWidth: 4)).offset(y: -34)
                    HStack(spacing: 4) {
                        Circle().fill(.gray).frame(width: 27, height: 27).overlay(Circle().stroke(.orange, lineWidth: 4))
                        Circle().fill(.gray).frame(width: 27, height: 27).overlay(Circle().stroke(.orange, lineWidth: 4))
                    }
                    .offset(y: 31)
                }
                .frame(width: 64, height: 126)
                .overlay(TriWheelTreadShape().stroke(.gray, lineWidth: 3))
                .offset(x: CGFloat(side * 86), y: 52)
                Capsule().fill(finish).frame(width: 22, height: 108).rotationEffect(.degrees(side * -12)).offset(x: CGFloat(side * 88), y: 5)
            }
            RoundedRectangle(cornerRadius: 18).fill(finish.gradient).frame(width: 142, height: 104).overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.55), lineWidth: 2)).offset(y: 24)
            Rectangle().fill(.gray).frame(width: 18, height: 64).offset(y: -54)
            Ellipse().fill(finish.gradient).frame(width: 92, height: 65).overlay(Ellipse().stroke(.cyan.opacity(0.85), lineWidth: 3)).offset(y: -94)
            Image(systemName: "face.smiling")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(smileColor)
                .offset(y: -95)
            HStack(spacing: 26) {
                Circle().fill(.blue).frame(width: 25, height: 25)
                Circle().fill(.cyan).frame(width: 25, height: 25)
            }.offset(y: 10)
            rangedIllustration
            meleeIllustration
        }
        .frame(width: 320, height: 255)
        .offset(y: -3)
        .shadow(color: finish.opacity(0.65), radius: 14)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var rangedIllustration: some View {
        switch session.rangedWeapon {
        case .shoulderGatling:
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(.black).frame(width: 48, height: 30)
                ForEach([-12.0, -4, 4, 12], id: \.self) { y in Rectangle().fill(.red).frame(width: 38, height: 3).offset(x: 32, y: CGFloat(y)) }
            }.offset(x: 72, y: -34)
        case .twinBlasters:
            ForEach([-1.0, 1.0], id: \.self) { side in
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(.blue).frame(width: 42, height: 25)
                    Rectangle().fill(.cyan).frame(width: 38, height: 5).offset(y: -18)
                }.offset(x: CGFloat(side * 76), y: -28)
            }
        case .arcCannon:
            ZStack {
                Circle().fill(.cyan).frame(width: 35, height: 35).shadow(color: .cyan, radius: 12)
                RoundedRectangle(cornerRadius: 6).fill(.purple).frame(width: 76, height: 22).offset(y: 18)
            }.offset(y: -58)
        }
    }

    @ViewBuilder private var meleeIllustration: some View {
        switch session.meleeWeapon {
        case .dualSabers:
            Capsule().fill(.green).frame(width: 8, height: 105).rotationEffect(.degrees(-22)).offset(x: -115, y: -4).shadow(color: .green, radius: 8)
            Capsule().fill(.cyan).frame(width: 8, height: 105).rotationEffect(.degrees(22)).offset(x: 115, y: -4).shadow(color: .cyan, radius: 8)
        case .powerHammer:
            ZStack {
                Capsule().fill(.gray).frame(width: 11, height: 116)
                RoundedRectangle(cornerRadius: 6).fill(.orange).frame(width: 67, height: 34).offset(y: -56)
            }.rotationEffect(.degrees(24)).offset(x: 118, y: -7)
        }
    }
}

private struct InsideROBDiagram: View {
    let component: ROBComponent
    let faceColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                blueprintGrid
                robotSchematic
                componentHighlight
            }
            .frame(height: 265)
            .frame(maxWidth: .infinity)
            .background(
                RadialGradient(
                    colors: [component.accentColor.opacity(0.22), Color(red: 0.015, green: 0.055, blue: 0.11)],
                    center: .center,
                    startRadius: 12,
                    endRadius: 260
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18).stroke(component.accentColor.opacity(0.65), lineWidth: 1.5)
            }

            HStack(spacing: 10) {
                Image(systemName: component.systemImage)
                    .font(.title2)
                    .foregroundStyle(component.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.name).font(.headline)
                    Text(component.summary).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Inside ROB diagram, \(component.name) selected. \(component.summary)")
    }

    private var blueprintGrid: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0.0, through: size.width, by: 24) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: 24) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.cyan.opacity(0.08)), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var robotSchematic: some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                TriWheelTreadShape()
                    .fill(.white.opacity(0.12))
                    .overlay(TriWheelTreadShape().stroke(.white.opacity(0.42), lineWidth: 2))
                    .frame(width: 52, height: 92)
                    .offset(x: CGFloat(side * 73), y: 63)
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(width: 16, height: 94)
                    .rotationEffect(.degrees(side * -10))
                    .offset(x: CGFloat(side * 70), y: -5)
            }
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.55), lineWidth: 2))
                .frame(width: 126, height: 86)
                .offset(y: 22)
            Capsule().fill(.white.opacity(0.35)).frame(width: 15, height: 52).offset(y: -48)
            Ellipse()
                .fill(.white.opacity(0.18))
                .overlay(Ellipse().stroke(.cyan.opacity(0.75), lineWidth: 2))
                .frame(width: 76, height: 52)
                .offset(y: -86)
            Image(systemName: "face.smiling")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(faceColor)
                .offset(y: -86)
        }
        .frame(width: 280, height: 230)
    }

    @ViewBuilder private var componentHighlight: some View {
        switch component.id {
        case "base":
            RoundedRectangle(cornerRadius: 24)
                .stroke(component.accentColor, lineWidth: 5)
                .frame(width: 198, height: 104)
                .offset(y: 65)
        case "power":
            RoundedRectangle(cornerRadius: 12)
                .fill(component.accentColor.opacity(0.28))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(component.accentColor, lineWidth: 4))
                .frame(width: 102, height: 42)
                .offset(y: 39)
        case "cerebro":
            RoundedRectangle(cornerRadius: 12)
                .fill(component.accentColor.opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(component.accentColor, lineWidth: 4))
                .frame(width: 102, height: 39)
                .offset(y: -3)
        case "sensors":
            Ellipse()
                .fill(component.accentColor.opacity(0.25))
                .overlay(Ellipse().stroke(component.accentColor, lineWidth: 4))
                .frame(width: 88, height: 64)
                .offset(y: -86)
        case "arms":
            HStack(spacing: 108) {
                Capsule().stroke(component.accentColor, lineWidth: 5).frame(width: 25, height: 108).rotationEffect(.degrees(10))
                Capsule().stroke(component.accentColor, lineWidth: 5).frame(width: 25, height: 108).rotationEffect(.degrees(-10))
            }
            .offset(y: -3)
        default:
            RoundedRectangle(cornerRadius: 45)
                .stroke(component.accentColor, style: StrokeStyle(lineWidth: 5, dash: [10, 7]))
                .frame(width: 230, height: 224)
        }
    }
}

private extension ROBComponent {
    var accentColor: Color {
        Color(
            red: Double((color >> 16) & 0xFF) / 255,
            green: Double((color >> 8) & 0xFF) / 255,
            blue: Double(color & 0xFF) / 255
        )
    }

    var systemImage: String {
        switch id {
        case "base": "gearshape.2.fill"
        case "power": "bolt.batteryblock.fill"
        case "cerebro": "cpu.fill"
        case "sensors": "sensor.fill"
        case "arms": "figure.strengthtraining.traditional"
        default: "shield.checkered"
        }
    }
}

private struct TriWheelTreadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.34))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.34))
        path.closeSubpath()
        return path
    }
}

private struct LoadoutOption: View {
    let title: String
    let summary: String
    let systemImage: String
    let selected: Bool
    let unlocked: Bool
    let requiredLevel: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: unlocked ? systemImage : "lock.fill").font(.title2).frame(width: 34).foregroundStyle(unlocked ? .cyan : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack { Text(title).font(.headline); if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.cyan) } }
                    Text(unlocked ? summary : "Complete Level \(requiredLevel) to unlock.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .background(selected ? .cyan.opacity(0.18) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct UpgradeOption: View {
    @Bindable var session: GameSession
    let upgrade: ROBUpgrade

    var body: some View {
        let level = session.upgradeLevel(upgrade)
        let cost = session.upgradeCost(upgrade)
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(.yellow).frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(upgrade.displayName).font(.headline)
                    Text("L\(level)/\(upgrade.maximumLevel)").font(.caption.bold()).foregroundStyle(.cyan)
                }
                Text(upgrade.summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Button(cost.map { "Buy \($0)" } ?? "MAX") { session.purchaseUpgrade(upgrade) }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(cost == nil || session.upgradePoints < (cost ?? 0))
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private var icon: String {
        switch upgrade {
        case .speedBoost: "speedometer"
        case .energyCapacity: "battery.100percent.bolt"
        case .weaponPower: "scope"
        case .targetingComputer: "viewfinder.circle"
        }
    }
}

private extension View {
    func workshopCard() -> some View {
        padding(16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    func experienceCard() -> some View {
        padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}
