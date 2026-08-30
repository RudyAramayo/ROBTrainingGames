import ARKit
import AVFoundation
import RealityKit
import SwiftUI
import UIKit

private enum ROBCameraAccess: Equatable {
    case checking, authorized, denied, unsupported
}

struct ARLabView: View {
    @Bindable var session: GameSession
    let onExit: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var cameraAccess: ROBCameraAccess = .checking
    @State private var isActive = false
    @State private var placementID = UUID()
    @State private var timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            switch cameraAccess {
            case .authorized:
                ROBARView(session: session, isActive: isActive)
                    .id(placementID)
                    .ignoresSafeArea()
                missionControls
            case .checking:
                ARLabUnavailableView(
                    title: "Preparing the camera",
                    message: "ROB is finding a surface for the training arena.",
                    symbol: "camera.aperture"
                )
            case .denied:
                ARLabUnavailableView(
                    title: "Camera access is off",
                    message: "Allow camera access in Settings so AR missions can appear in your room.",
                    symbol: "camera.fill",
                    actionTitle: "Open Settings",
                    action: openSettings
                )
            case .unsupported:
                ARLabUnavailableView(
                    title: "AR is unavailable",
                    message: "This device does not support the world tracking required by ROB AR missions.",
                    symbol: "arkit"
                )
            }
        }
        .overlay {
            if session.isUpgradeIntermission {
                ZStack {
                    Color.black.opacity(0.72).ignoresSafeArea()
                    MissionUpgradeIntermission(session: session)
                        .padding(verticalSizeClass == .compact ? 12 : 28)
                }
            }
        }
        .overlay(alignment: .top) {
            HStack {
                Button(action: onExit) {
                    Label("Menu", systemImage: "xmark.circle.fill")
                }
                .accessibilityLabel("Pause AR mission and return to menu")

                Spacer()

                if cameraAccess == .authorized {
                    Button { placementID = UUID() } label: {
                        Label("Place Again", systemImage: "viewfinder")
                    }
                    .accessibilityHint("Scans for a new horizontal surface and places the arena again")
                }
            }
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .buttonStyle(.plain)
            .padding()
        }
        .background {
            LinearGradient(colors: [.indigo.opacity(0.8), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .task { await updateCameraAccess(requestIfNeeded: true) }
        .onAppear {
            isActive = scenePhase == .active
            startOrResumeMission()
        }
        .onDisappear {
            isActive = false
            session.stopDrive()
        }
        .onChange(of: scenePhase) { _, phase in
            isActive = phase == .active
            if phase == .active {
                Task { await updateCameraAccess(requestIfNeeded: false) }
                startOrResumeMission()
            } else {
                session.pause()
            }
        }
        .onReceive(timer) { _ in
            guard cameraAccess == .authorized, isActive else { return }
            session.tick(1.0 / 30.0)
        }
    }

    private var missionControls: some View {
        VStack(spacing: verticalSizeClass == .compact ? 5 : 9) {
            ARMissionStats(session: session, compact: verticalSizeClass == .compact)

            Spacer(minLength: 8)

            if session.canFinish && !session.isUpgradeIntermission {
                Button(session.levelIndex == session.levels.count - 1 ? "Finish Campaign" : "Complete Level") {
                    session.nextLevel()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            Text(session.message)
                .font(.caption.bold())
                .lineLimit(verticalSizeClass == .compact ? 1 : 2)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.black.opacity(0.72), in: Capsule())

            MobileTankControls(session: session)
        }
        .padding(.horizontal, 8)
        .padding(.top, verticalSizeClass == .compact ? 54 : 68)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startOrResumeMission() {
        guard !session.isUpgradeIntermission else { return }
        if session.isPaused { session.resume() }
        else if !session.isRunning { session.begin() }
    }

    private func updateCameraAccess(requestIfNeeded: Bool) async {
        guard ARWorldTrackingConfiguration.isSupported else {
            cameraAccess = .unsupported
            session.pause()
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAccess = .authorized
            if isActive { startOrResumeMission() }
        case .notDetermined where requestIfNeeded:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAccess = granted ? .authorized : .denied
            if granted && isActive { startOrResumeMission() }
            else if !granted { session.pause() }
        case .notDetermined:
            cameraAccess = .checking
        case .denied, .restricted:
            cameraAccess = .denied
            session.pause()
        @unknown default:
            cameraAccess = .denied
            session.pause()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct ARMissionStats: View {
    @Bindable var session: GameSession
    let compact: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Label("L\(session.level.id)", systemImage: "flag.checkered")
                if !compact {
                    Text(session.level.name).lineLimit(1)
                }
                Spacer(minLength: 2)
                Button { session.toggleMusic() } label: {
                    Image(systemName: session.musicEnabled ? "music.note" : "speaker.slash")
                }
                Button {
                    if session.isRunning { session.pause() }
                    else { startOrResume() }
                } label: {
                    Image(systemName: session.isRunning ? "pause.fill" : "play.fill")
                }
                Button { session.begin() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Restart current level")
            }
            .font(.subheadline.bold())

            HStack(spacing: compact ? 8 : 14) {
                keyStatus
                Spacer(minLength: 0)
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

    @ViewBuilder private var keyStatus: some View {
        if !session.level.requiresKey {
            Label("No key", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Label(session.hasKey ? "Key" : "Find key", systemImage: session.hasKey ? "key.fill" : "key")
        }
    }

    private func startOrResume() {
        if session.isPaused { session.resume() }
        else { session.begin() }
    }
}

private struct ARLabUnavailableView: View {
    let title: String
    let message: String
    let symbol: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.white)
    }
}

struct ROBARView: UIViewRepresentable {
    @Bindable var session: GameSession
    let isActive: Bool

    static let missionRootName = "AR Mission Root"
    static let arenaScale: Float = 0.16

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.renderOptions.formUnion([.disableGroundingShadows, .disableMotionBlur, .disableDepthOfField])
        view.environment.sceneUnderstanding.options.remove(.occlusion)

        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.55, 0.55]))
        let missionRoot = Self.makeMissionRoot(session: session)
        anchor.addChild(missionRoot)
        anchor.addChild(Self.makeFillLightRig())
        view.scene.addAnchor(anchor)

        let coaching = ARCoachingOverlayView()
        coaching.session = view.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: view.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        context.coordinator.missionRoot = missionRoot
        context.coordinator.setSessionActive(isActive, in: view, resetTracking: true)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.setSessionActive(isActive, in: view)
        if let missionRoot = context.coordinator.missionRoot {
            Self.updateMissionRoot(missionRoot, session: session)
        }
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.setSessionActive(false, in: view)
    }

    static func makeMissionRoot(session: GameSession) -> Entity {
        let root = Entity()
        root.name = missionRootName
        root.scale = .init(repeating: arenaScale)

        root.addChild(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle, arPresentation: true))

        let robot = RobotFactory.makeROB(arPresentation: true)
        robot.position = session.presentationPosition
        robot.orientation = session.presentationOrientation
        RobotFactory.applyWeapons(to: robot, session: session, arPresentation: true)
        root.addChild(robot)

        root.addChild(RobotFactory.makeCombatLayer(session: session))
        return root
    }

    static func updateMissionRoot(_ root: Entity, session: GameSession) {
        if let robot = root.findEntity(named: "ROB") {
            robot.position = session.presentationPosition
            robot.orientation = session.presentationOrientation
            RobotFactory.applyWeapons(to: robot, session: session, arPresentation: true)
        }

        let roomName = "Training Room-\(session.levelIndex)"
        if let room = root.children.first(where: { $0.name == roomName }) {
            RobotFactory.applyPuzzleState(to: room, session: session)
        } else {
            for child in Array(root.children) where child.name.hasPrefix("Training Room-") {
                child.removeFromParent()
            }
            root.addChild(RobotFactory.makeTrainingRoom(level: session.levelIndex, puzzle: session.puzzle, arPresentation: true))
        }

        let combatName = RobotFactory.combatLayerName(level: session.levelIndex)
        if let combat = root.children.first(where: { $0.name == combatName }) {
            RobotFactory.applyCombatState(to: combat, session: session)
        } else {
            for child in Array(root.children) where child.name.hasPrefix("Combat Layer-") {
                child.removeFromParent()
            }
            root.addChild(RobotFactory.makeCombatLayer(session: session))
        }
    }

    static func makeConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic
        return configuration
    }

    static func makeFillLightRig() -> Entity {
        let rig = Entity()
        rig.name = "AR Fill Lights"

        let daylight = Entity()
        daylight.name = "AR Directional Light"
        daylight.look(at: [0, 0.45, 0], from: [-1.2, 2.4, 1.2], relativeTo: nil)
        daylight.components.set(DirectionalLightComponent(color: .white, intensity: 4_500))
        rig.addChild(daylight)

        for (name, position, intensity) in [
            ("AR Key Light", SIMD3<Float>(-0.8, 1.5, 0.8), Float(24_000)),
            ("AR Fill Light", SIMD3<Float>(0.9, 1.1, 0.6), Float(12_000)),
        ] {
            let light = Entity()
            light.name = name
            light.position = position
            light.components.set(PointLightComponent(color: .white, intensity: intensity, attenuationRadius: 5))
            rig.addChild(light)
        }
        return rig
    }

    @MainActor final class Coordinator {
        var missionRoot: Entity?
        private var sessionIsRunning = false

        func setSessionActive(_ active: Bool, in view: ARView, resetTracking: Bool = false) {
            if active {
                guard !sessionIsRunning || resetTracking else { return }
                let options: ARSession.RunOptions = resetTracking ? [.resetTracking, .removeExistingAnchors] : []
                view.session.run(ROBARView.makeConfiguration(), options: options)
            } else {
                guard sessionIsRunning else { return }
                view.session.pause()
            }
            sessionIsRunning = active
        }
    }
}
