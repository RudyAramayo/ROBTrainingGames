@preconcurrency import ARKit
import Foundation
@preconcurrency import GameController
import Observation

@MainActor
@Observable
final class VisionGameControllerInput: NSObject {
    private enum TreadSide: Equatable {
        case left
        case right
        case both
    }

    private struct ControllerState {
        var side: TreadSide
        var stickY: Float = 0
        var secondStickY: Float = 0
        var saberPressed = false
        var laserPressed = false
        var hackPressed = false
        var menuPressed = false
    }

    private(set) var isConnected = false
    private(set) var controllerName = "Hands only"
    private(set) var modeDescription = "Pinch and drag both tread pads"
    private(set) var leftTread = 0.0
    private(set) var rightTread = 0.0
    private(set) var spatialControllerCount = 0

    @ObservationIgnored private weak var session: GameSession?
    @ObservationIgnored private var controllers: [ObjectIdentifier: GCController] = [:]
    @ObservationIgnored private var states: [ObjectIdentifier: ControllerState] = [:]
    @ObservationIgnored private var sideTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var saberWasPressed = false
    @ObservationIgnored private var laserWasPressed = false
    @ObservationIgnored private var hackWasPressed = false
    @ObservationIgnored private var menuWasPressed = false

    func start(session: GameSession) {
        self.session = session
        guard !isStarted else {
            publish()
            return
        }
        isStarted = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        for controller in GCController.controllers() { configure(controller) }
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        NotificationCenter.default.removeObserver(self)
        GCController.stopWirelessControllerDiscovery()
        for controller in controllers.values {
            controller.extendedGamepad?.valueChangedHandler = nil
            controller.physicalInputProfile.valueDidChangeHandler = nil
        }
        sideTasks.values.forEach { $0.cancel() }
        sideTasks.removeAll()
        controllers.removeAll()
        states.removeAll()
        if laserWasPressed { session?.releaseLaserCharge() }
        session?.stopDrive()
        saberWasPressed = false
        laserWasPressed = false
        hackWasPressed = false
        menuWasPressed = false
        publish()
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        configure(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        let id = ObjectIdentifier(controller)
        controller.extendedGamepad?.valueChangedHandler = nil
        controller.physicalInputProfile.valueDidChangeHandler = nil
        controllers.removeValue(forKey: id)
        states.removeValue(forKey: id)
        sideTasks.removeValue(forKey: id)?.cancel()
        assignFallbackSpatialSides()
        publish()
    }

    private func configure(_ controller: GCController) {
        let id = ObjectIdentifier(controller)
        guard controllers[id] == nil else { return }
        let physicalProfile = controller.physicalInputProfile
        guard controller.extendedGamepad != nil || Self.primaryStick(in: physicalProfile) != nil else { return }

        controllers[id] = controller
        states[id] = ControllerState(side: controller.extendedGamepad == nil ? availableSpatialSide() : .both)
        assignPlayerIndices()
        if let gamepad = controller.extendedGamepad {
            gamepad.valueChangedHandler = { [weak self] gamepad, _ in
                Task { @MainActor [weak self] in self?.update(id, from: gamepad) }
            }
            update(id, from: gamepad)
        } else {
            physicalProfile.valueDidChangeHandler = { [weak self] profile, _ in
                Task { @MainActor [weak self] in self?.update(id, from: profile) }
            }
            update(id, from: physicalProfile)
            identifySpatialSide(of: controller, id: id)
        }
        publish()
    }

    private func update(_ id: ObjectIdentifier, from gamepad: GCExtendedGamepad) {
        guard var state = states[id] else { return }
        state.side = .both
        state.stickY = gamepad.leftThumbstick.yAxis.value
        state.secondStickY = gamepad.rightThumbstick.yAxis.value
        state.saberPressed = gamepad.buttonA.isPressed || gamepad.buttonX.isPressed
        state.laserPressed = gamepad.rightTrigger.value > 0.2 || gamepad.rightShoulder.isPressed
        state.hackPressed = gamepad.buttonB.isPressed || gamepad.leftShoulder.isPressed
        state.menuPressed = gamepad.buttonMenu.isPressed
        states[id] = state
        publish()
    }

    private func update(_ id: ObjectIdentifier, from profile: GCPhysicalInputProfile) {
        guard let stick = Self.primaryStick(in: profile), var state = states[id] else { return }
        state.stickY = stick.yAxis.value
        let trigger = Self.isPressed(["Trigger", GCInputRightTrigger, GCInputLeftTrigger], in: profile)
        let primary = Self.isPressed(["Button A", GCInputButtonA], in: profile)
        let secondary = Self.isPressed(["Button B", GCInputButtonB], in: profile)
        switch state.side {
        case .left:
            state.saberPressed = trigger
            state.laserPressed = false
            state.hackPressed = primary || secondary
            state.menuPressed = false
        case .right:
            state.saberPressed = false
            state.laserPressed = trigger
            state.hackPressed = secondary
            state.menuPressed = primary
        case .both:
            break
        }
        states[id] = state
        publish()
    }

    private func publish() {
        let conventional = states.values.first(where: { $0.side == .both })
        let leftSpatial = states.values.first(where: { $0.side == .left })
        let rightSpatial = states.values.first(where: { $0.side == .right })
        let input = ROBTreadInput.tank(
            leftStickY: leftSpatial?.stickY ?? conventional?.stickY ?? 0,
            rightStickY: rightSpatial?.stickY ?? conventional?.secondStickY ?? 0
        )
        leftTread = input.left
        rightTread = input.right
        session?.setTreads(left: input.left, right: input.right)

        let saberPressed = states.values.contains(where: \.saberPressed)
        let laserPressed = states.values.contains(where: \.laserPressed)
        let hackPressed = states.values.contains(where: \.hackPressed)
        let menuPressed = states.values.contains(where: \.menuPressed)
        if saberPressed && !saberWasPressed { session?.saberAttack() }
        if laserPressed && !laserWasPressed { session?.beginLaserCharge() }
        if !laserPressed && laserWasPressed { session?.releaseLaserCharge() }
        if hackPressed && !hackWasPressed { session?.startDoorHack() }
        if menuPressed && !menuWasPressed { toggleMission() }
        saberWasPressed = saberPressed
        laserWasPressed = laserPressed
        hackWasPressed = hackPressed
        menuWasPressed = menuPressed

        isConnected = !controllers.isEmpty
        spatialControllerCount = states.values.filter { $0.side != .both }.count
        let names = Set(controllers.values.map { $0.vendorName ?? "Game controller" }).sorted()
        controllerName = names.isEmpty ? "Hands only" : names.joined(separator: " + ")
        if spatialControllerCount >= 2 {
            modeDescription = "Two spatial controllers · matching sticks drive each tread"
        } else if conventional != nil {
            modeDescription = "Gamepad · left and right sticks drive matching treads"
        } else if spatialControllerCount == 1 {
            modeDescription = "One spatial controller connected · connect its partner"
        } else {
            modeDescription = "Pinch and drag both tread pads"
        }
    }

    private func toggleMission() {
        guard let session else { return }
        if session.isRunning { _ = session.pause() }
        else if session.isPaused { _ = session.resume() }
        else { session.begin() }
    }

    private func availableSpatialSide() -> TreadSide {
        states.values.contains(where: { $0.side == .left }) ? .right : .left
    }

    private func assignFallbackSpatialSides() {
        var nextSide = TreadSide.left
        for id in controllers.keys where controllers[id]?.extendedGamepad == nil {
            guard var state = states[id] else { continue }
            state.side = nextSide
            states[id] = state
            nextSide = nextSide == .left ? .right : .left
        }
    }

    private func assignPlayerIndices() {
        for (index, controller) in controllers.values.enumerated() {
            controller.playerIndex = switch index {
            case 0: .index1
            case 1: .index2
            case 2: .index3
            case 3: .index4
            default: .indexUnset
            }
        }
    }

    nonisolated private static func primaryStick(in profile: GCPhysicalInputProfile) -> GCControllerDirectionPad? {
        profile.dpads[GCInputLeftThumbstick]
            ?? profile.dpads["Thumbstick"]
            ?? profile.dpads.first(where: { $0.key != GCInputDirectionPad })?.value
    }

    nonisolated private static func isPressed(_ names: [String], in profile: GCPhysicalInputProfile) -> Bool {
        names.contains { (profile.buttons[$0]?.value ?? 0) > 0.2 }
    }

    private struct SendableController: @unchecked Sendable {
        let value: GCController
    }

    private func identifySpatialSide(of controller: GCController, id: ObjectIdentifier) {
        guard #available(visionOS 26.0, *) else { return }
        let sendableController = SendableController(value: controller)
        sideTasks[id]?.cancel()
        sideTasks[id] = Task { @MainActor [weak self] in
            do {
                let chirality = try await Task.detached {
                    try await Accessory(device: sendableController.value).inherentChirality
                }.value
                guard !Task.isCancelled, var state = self?.states[id] else { return }
                switch chirality {
                case .left: state.side = .left
                case .right: state.side = .right
                case .unspecified: return
                @unknown default: return
                }
                self?.states[id] = state
                self?.publish()
            } catch {
                // Discovery order remains a usable left/right fallback.
            }
        }
    }
}
