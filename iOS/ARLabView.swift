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
    @Environment(\.scenePhase) private var scenePhase
    @State private var componentMode = false
    @State private var cameraAccess: ROBCameraAccess = .checking
    @State private var isActive = false

    var body: some View {
        ZStack(alignment: .bottom) {
            switch cameraAccess {
            case .authorized:
                ROBARView(componentMode: componentMode, session: session, isActive: isActive)
                    .ignoresSafeArea()
                controls
            case .checking:
                ARLabUnavailableView(
                    title: "Preparing the camera",
                    message: "ROB is calibrating the AR view.",
                    symbol: "camera.aperture"
                )
            case .denied:
                ARLabUnavailableView(
                    title: "Camera access is off",
                    message: "Allow camera access in Settings so the AR Lab can show your room behind ROB.",
                    symbol: "camera.fill",
                    actionTitle: "Open Settings",
                    action: openSettings
                )
            case .unsupported:
                ARLabUnavailableView(
                    title: "AR is unavailable",
                    message: "This device does not support the world tracking required by the ROB AR Lab.",
                    symbol: "arkit"
                )
            }
        }
        .background {
            LinearGradient(colors: [.indigo.opacity(0.8), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .robGameKeyboardControls(session: session)
        .task { await updateCameraAccess(requestIfNeeded: true) }
        .onAppear { isActive = true }
        .onDisappear { isActive = false }
        .onChange(of: scenePhase) { _, phase in
            isActive = phase == .active
            if phase == .active {
                Task { await updateCameraAccess(requestIfNeeded: false) }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Level \(session.level.id)", systemImage: "flag.checkered")
                Spacer()
                Text("Score \(session.score)").monospacedDigit()
                Text("Cells \(session.collectedCells)/\(session.level.cellCount)")
                Text("Targets \(session.remainingEnemies)")
            }
            .font(.caption.bold())
            .padding(10)
            .background(.ultraThinMaterial, in: Capsule())

            Text(componentMode ? "Tap a ROB part, then use the guide below." : "Move the phone to find a surface · drag ROB to reposition")
                .font(.callout.bold())
                .padding(10)
                .background(.ultraThinMaterial, in: Capsule())

            Toggle("Component Explorer", isOn: $componentMode)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

            if componentMode {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(session.components) { item in
                            Button(item.name) { session.selectedComponent = item }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                        }
                    }
                    .padding(.horizontal)
                }
                if let item = session.selectedComponent {
                    Text(item.summary)
                        .font(.footnote)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            HStack {
                Button("Start") { session.begin() }
                Button("Key") { session.collectKey() }
                Button("Door") { session.openDoor() }
                Button("Cell") { session.collectCell() }
                LaserChargeButton(session: session, title: session.rangedWeapon.shortName, compact: true)
                Button(session.meleeWeapon.shortName) { session.saberAttack() }
                if session.canFinish {
                    Button("Next") { session.nextLevel() }.buttonStyle(.borderedProminent)
                }
            }
            .buttonStyle(.bordered)

            Text(session.laserLockDescription)
                .font(.caption.bold())
                .foregroundStyle(session.lockedEnemy == nil ? .orange : .red)
        }
        .padding()
    }

    private func updateCameraAccess(requestIfNeeded: Bool) async {
        guard ARWorldTrackingConfiguration.isSupported else {
            cameraAccess = .unsupported
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAccess = .authorized
        case .notDetermined where requestIfNeeded:
            cameraAccess = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        case .notDetermined:
            cameraAccess = .checking
        case .denied, .restricted:
            cameraAccess = .denied
        @unknown default:
            cameraAccess = .denied
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
    let componentMode: Bool
    @Bindable var session: GameSession
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: true)
        view.renderOptions.formUnion([.disableGroundingShadows, .disableMotionBlur, .disableDepthOfField])
        view.environment.sceneUnderstanding.options.remove(.occlusion)

        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.25, 0.25]))
        let rob = RobotFactory.makeROB(componentMode: componentMode)
        rob.scale = [0.32, 0.32, 0.32]
        RobotFactory.applyWeapons(to: rob, session: session, componentMode: componentMode)
        anchor.addChild(rob)
        anchor.addChild(Self.makeFillLightRig())
        view.scene.addAnchor(anchor)
        view.installGestures([.translation, .rotation, .scale], for: rob)

        context.coordinator.robot = rob
        context.coordinator.adoptAutomaticallyConfiguredSession(isActive: isActive, in: view)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.setSessionActive(isActive, in: view)
        if let robot = context.coordinator.robot {
            RobotFactory.applyWeapons(to: robot, session: session, componentMode: componentMode)
        }
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.setSessionActive(false, in: view)
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
        for (name, position, intensity) in [
            ("AR Key Light", SIMD3<Float>(-1.2, 2.4, 1.2), Float(18_000)),
            ("AR Fill Light", SIMD3<Float>(1.1, 1.4, 0.8), Float(9_000)),
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
        var robot: Entity?
        private var sessionIsRunning = false

        func adoptAutomaticallyConfiguredSession(isActive: Bool, in view: ARView) {
            sessionIsRunning = isActive
            if !isActive { view.session.pause() }
        }

        func setSessionActive(_ active: Bool, in view: ARView) {
            guard active != sessionIsRunning else { return }
            if active {
                view.session.run(ROBARView.makeConfiguration())
            } else {
                view.session.pause()
            }
            sessionIsRunning = active
        }
    }
}
