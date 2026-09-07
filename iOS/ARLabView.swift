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
    @AppStorage("robLocalHighScore") private var highScore = 0
    @AppStorage("robShowMissionText") private var showsMissionText = false

    private var isLandscape: Bool { verticalSizeClass == .compact }

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
        .overlay(alignment: .topLeading) {
            if cameraAccess != .authorized {
                Button(action: onExit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.34), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Return to menu")
                .padding(10)
            }
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
            highScore = max(highScore, session.score)
        }
    }

    private var missionControls: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                MissionCornerHUD(
                    session: session,
                    highScore: highScore,
                    showsMissionText: $showsMissionText,
                    onExit: onExit
                )
                .frame(width: isLandscape ? 204 : 220)

                Spacer(minLength: 0)

                Button { placementID = UUID() } label: {
                    Image(systemName: "viewfinder")
                        .font(.headline.bold())
                        .frame(width: isLandscape ? 38 : 44, height: isLandscape ? 38 : 44)
                        .background(.black.opacity(0.34), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Place arena again")
                .accessibilityHint("Scans for a new horizontal surface and places the arena again")
            }

            Spacer(minLength: 0)

            if showsMissionText {
                Text(session.message)
                    .font(.caption.bold())
                    .lineLimit(isLandscape ? 1 : 2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.58), in: Capsule())
                    .frame(maxWidth: isLandscape ? 440 : 520)
            }

            MobileTankControls(session: session, compact: isLandscape)
        }
        .padding(.horizontal, isLandscape ? 8 : 10)
        .padding(.vertical, isLandscape ? 5 : 10)
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
