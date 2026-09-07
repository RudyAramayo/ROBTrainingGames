@preconcurrency import GameController
import Foundation
@preconcurrency import MultipeerConnectivity
import Observation
import simd

enum ROBBattleArena: String, CaseIterable, Codable, Identifiable, Sendable {
    case neonFoundry
    case orbitalRing
    case reactorGrid
    case shadowYard

    var id: String { rawValue }

    var name: String {
        switch self {
        case .neonFoundry: "Neon Foundry"
        case .orbitalRing: "Orbital Ring"
        case .reactorGrid: "Reactor Grid"
        case .shadowYard: "Shadow Yard"
        }
    }

    var summary: String {
        switch self {
        case .neonFoundry: "Cross lanes and hot cover reward fast flanking."
        case .orbitalRing: "A circular brawl with a dangerous open center."
        case .reactorGrid: "Dense reactor blocks create close-range ambushes."
        case .shadowYard: "Long sightlines alternate with offset dark walls."
        }
    }

    var symbol: String {
        switch self {
        case .neonFoundry: "flame.fill"
        case .orbitalRing: "circle.hexagongrid.fill"
        case .reactorGrid: "bolt.horizontal.circle.fill"
        case .shadowYard: "moon.stars.fill"
        }
    }

    var accentIndex: Int {
        switch self {
        case .neonFoundry: 0
        case .orbitalRing: 1
        case .reactorGrid: 2
        case .shadowYard: 3
        }
    }

    var barriers: [ROBBattleBarrier] {
        switch self {
        case .neonFoundry:
            [
                .init(x: 0, z: -3.2, width: 5.4, depth: 0.5),
                .init(x: 0, z: 3.2, width: 5.4, depth: 0.5),
                .init(x: -3.5, z: 0, width: 0.5, depth: 3.4),
                .init(x: 3.5, z: 0, width: 0.5, depth: 3.4),
            ]
        case .orbitalRing:
            [
                .init(x: -2.6, z: -2.6, width: 2.4, depth: 0.45),
                .init(x: 2.6, z: -2.6, width: 2.4, depth: 0.45),
                .init(x: -2.6, z: 2.6, width: 2.4, depth: 0.45),
                .init(x: 2.6, z: 2.6, width: 2.4, depth: 0.45),
                .init(x: -2.6, z: 0, width: 0.45, depth: 2.4),
                .init(x: 2.6, z: 0, width: 0.45, depth: 2.4),
            ]
        case .reactorGrid:
            [
                .init(x: -3, z: -3, width: 1.5, depth: 1.5),
                .init(x: 3, z: -3, width: 1.5, depth: 1.5),
                .init(x: -3, z: 3, width: 1.5, depth: 1.5),
                .init(x: 3, z: 3, width: 1.5, depth: 1.5),
                .init(x: 0, z: 0, width: 1.8, depth: 1.8),
            ]
        case .shadowYard:
            [
                .init(x: -2.8, z: -2.4, width: 4.4, depth: 0.45),
                .init(x: 2.8, z: 0, width: 4.4, depth: 0.45),
                .init(x: -2.8, z: 2.4, width: 4.4, depth: 0.45),
                .init(x: 0, z: -4.8, width: 0.45, depth: 2.1),
                .init(x: 0, z: 4.8, width: 0.45, depth: 2.1),
            ]
        }
    }

    var spawnPoints: [SIMD3<Float>] {
        [
            [-6.4, 0, -6.4], [6.4, 0, 6.4],
            [6.4, 0, -6.4], [-6.4, 0, 6.4],
        ]
    }
}

struct ROBBattleBarrier: Codable, Equatable, Sendable {
    let x: Float
    let z: Float
    let width: Float
    let depth: Float
}

struct ROBBattlePlayerIdentity: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let transportName: String
    let colorIndex: Int
    var droidProfile: ROBDroidProfile? = nil
}

struct ROBBattleRobotState: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var x: Float
    var z: Float
    var heading: Float
    var health: Int
    var shields: Int
    var isAlive: Bool
    var respawnRemaining: Double

    var position: SIMD3<Float> { [x, 0, z] }
}

struct ROBBattleProjectile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let ownerID: UUID
    var x: Float
    var z: Float
    let velocityX: Float
    let velocityZ: Float
    var remaining: Double
    let damage: Int

    var position: SIMD3<Float> { [x, 0.82, z] }
}

struct ROBBattleMeleeEvent: Codable, Equatable, Sendable {
    let id: UUID
    let attackerID: UUID
    let x: Float
    let z: Float
    let heading: Float
    let damage: Int
}

struct ROBBattleKnockout: Codable, Equatable, Sendable {
    let id: UUID
    let attackerID: UUID
    let victimID: UUID
}

struct ROBBattleCollisionEvent: Codable, Equatable, Sendable {
    let id: UUID
    let initiatorID: UUID
    let otherRobotID: UUID
    let normalX: Float
    let normalZ: Float
    let impulse: Float
}

struct ROBBattleSpawnAssignment: Codable, Equatable, Sendable {
    let playerID: UUID
    let spawnIndex: Int
}

struct ROBBattleMatchStart: Codable, Equatable, Sendable {
    let matchID: UUID
    let arena: ROBBattleArena
    let assignments: [ROBBattleSpawnAssignment]
    let duration: Double
    let scoreLimit: Int
}

enum ROBBattlePacketKind: String, Codable, Sendable {
    case hello, vote, matchStart, snapshot, projectile, projectileImpact, melee, knockout, collision, matchEnd, nextVote
}

struct ROBBattlePacket: Codable, Sendable {
    let kind: ROBBattlePacketKind
    let sender: ROBBattlePlayerIdentity
    var vote: ROBBattleArena?
    var matchStart: ROBBattleMatchStart?
    var snapshot: ROBBattleRobotState?
    var projectile: ROBBattleProjectile?
    var projectileID: UUID?
    var melee: ROBBattleMeleeEvent?
    var knockout: ROBBattleKnockout?
    var collision: ROBBattleCollisionEvent?
    var winnerID: UUID?
    var snapshotSequence: UInt64?
}

private struct ROBBattlePeerBox: @unchecked Sendable {
    let peer: MCPeerID
}

private struct ROBBattleDataBox: @unchecked Sendable {
    let data: Data
}

private struct ROBBattleInvitationBox: @unchecked Sendable {
    let peer: MCPeerID
    let handler: (Bool, MCSession?) -> Void
}

@MainActor
@Observable
final class ROBBattleNetwork: NSObject {
    static let serviceType = "rob-battle"
    static let maximumPlayers = 4

    private(set) var isSearching = false
    private(set) var connectedPeerNames: [String] = []
    var onPacket: ((ROBBattlePacket) -> Void)?
    var onPeerConnected: (() -> Void)?
    var onPeerDisconnected: ((String) -> Void)?

    @ObservationIgnored private let localPeer: MCPeerID
    @ObservationIgnored private lazy var session = MCSession(
        peer: localPeer,
        securityIdentity: nil,
        encryptionPreference: .required
    )
    @ObservationIgnored private lazy var advertiser = MCNearbyServiceAdvertiser(
        peer: localPeer,
        discoveryInfo: ["game": "deathmatch", "version": "2"],
        serviceType: Self.serviceType
    )
    @ObservationIgnored private lazy var browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
    @ObservationIgnored private var pendingPeers: Set<String> = []

    init(transportName: String) {
        localPeer = MCPeerID(displayName: String(transportName.prefix(63)))
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        guard !isSearching else { return }
        isSearching = true
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func pauseDiscovery() {
        guard isSearching else { return }
        isSearching = false
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        pendingPeers.removeAll()
    }

    func stop() {
        pauseDiscovery()
        session.disconnect()
        connectedPeerNames = []
    }

    func send(_ packet: ROBBattlePacket) {
        guard !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(packet) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: Self.deliveryMode(for: packet.kind))
    }

    static func deliveryMode(for kind: ROBBattlePacketKind) -> MCSessionSendDataMode {
        kind == .snapshot ? .unreliable : .reliable
    }

    private func receive(_ data: Data) {
        guard let packet = try? JSONDecoder().decode(ROBBattlePacket.self, from: data) else { return }
        onPacket?(packet)
    }

    private func peerChanged(_ peer: MCPeerID, state: MCSessionState) {
        pendingPeers.remove(peer.displayName)
        connectedPeerNames = session.connectedPeers.map(\.displayName).sorted()
        switch state {
        case .connected: onPeerConnected?()
        case .notConnected: onPeerDisconnected?(peer.displayName)
        case .connecting: break
        @unknown default: break
        }
    }

    private func found(_ peer: MCPeerID) {
        guard peer != localPeer,
              session.connectedPeers.count + pendingPeers.count < Self.maximumPlayers - 1,
              !pendingPeers.contains(peer.displayName),
              !session.connectedPeers.contains(peer) else { return }
        pendingPeers.insert(peer.displayName)
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 12)
    }

    private func accept(_ invitation: ROBBattleInvitationBox) {
        let hasRoom = session.connectedPeers.count + pendingPeers.count < Self.maximumPlayers - 1
        if hasRoom { pendingPeers.insert(invitation.peer.displayName) }
        invitation.handler(hasRoom, hasRoom ? session : nil)
    }
}

extension ROBBattleNetwork: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let box = ROBBattlePeerBox(peer: peerID)
        Task { @MainActor [weak self] in self?.peerChanged(box.peer, state: state) }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let box = ROBBattleDataBox(data: data)
        Task { @MainActor [weak self] in self?.receive(box.data) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension ROBBattleNetwork: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard info?["game"] == "deathmatch", info?["version"] == "2" else { return }
        let box = ROBBattlePeerBox(peer: peerID)
        Task { @MainActor [weak self] in self?.found(box.peer) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension ROBBattleNetwork: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let box = ROBBattleInvitationBox(peer: peerID, handler: invitationHandler)
        Task { @MainActor [weak self] in self?.accept(box) }
    }
}

enum ROBBattlePhase: String, Sendable {
    case voting, playing, results
}

private struct ROBBattleRemoteInterpolation {
    let start: ROBBattleRobotState
    let target: ROBBattleRobotState
    var elapsed = 0.0
}

struct ROBBattleRobotAnimationState: Equatable, Sendable {
    static let saberDuration = 0.48
    static let laserDuration = 0.24
    static let collisionDuration = 0.32

    var leftTreadAngle: Float = 0
    var rightTreadAngle: Float = 0
    var saberRemaining = 0.0
    var laserRemaining = 0.0
    var collisionRemaining = 0.0
}

@MainActor
@Observable
final class ROBBattleCoordinator {
    static let maximumPlayers = 4
    static let matchDuration = 180.0
    static let scoreLimit = 5
    static let arenaHalfExtent: Float = 8.2
    static let robotRadius: Float = 0.64
    static let remoteInterpolationDuration = 0.1
    static let remoteSnapDistance: Float = 3
    static let collisionImpulse: Float = 0.38
    static let collisionEventCooldown = 0.75
    static let collisionSoundCooldown = 0.9

    private(set) var localIdentity: ROBBattlePlayerIdentity
    private(set) var players: [UUID: ROBBattlePlayerIdentity]
    private(set) var votes: [UUID: ROBBattleArena] = [:]
    private(set) var phase = ROBBattlePhase.voting
    private(set) var arena = ROBBattleArena.neonFoundry
    private(set) var matchID = UUID()
    private(set) var remainingTime = ROBBattleCoordinator.matchDuration
    private(set) var localRobot: ROBBattleRobotState
    private(set) var remoteRobots: [UUID: ROBBattleRobotState] = [:]
    private(set) var projectiles: [ROBBattleProjectile] = []
    private(set) var robotAnimations: [UUID: ROBBattleRobotAnimationState] = [:]
    private(set) var scores: [UUID: Int] = [:]
    private(set) var deaths: [UUID: Int] = [:]
    private(set) var winnerID: UUID?
    private(set) var statusMessage = "AutoNet is looking for nearby ROB Training battles…"
    private(set) var connectedControllerName: String?

    @ObservationIgnored private let network: ROBBattleNetwork?
    @ObservationIgnored private let soundFeedback: @MainActor (ROBBattleSoundCue) -> Void
    @ObservationIgnored private var leftTread = 0.0
    @ObservationIgnored private var rightTread = 0.0
    @ObservationIgnored private var lastSnapshotSent = -Double.infinity
    @ObservationIgnored private var lastLaserTime = -Double.infinity
    @ObservationIgnored private var lastMeleeTime = -Double.infinity
    @ObservationIgnored private var processedEvents: Set<UUID> = []
    @ObservationIgnored private var outgoingSnapshotSequence: UInt64 = 0
    @ObservationIgnored private var lastRemoteSnapshotSequences: [UUID: UInt64] = [:]
    @ObservationIgnored private var remoteInterpolations: [UUID: ROBBattleRemoteInterpolation] = [:]
    @ObservationIgnored private var lastCollisionTimes: [UUID: Double] = [:]
    @ObservationIgnored private var lastCollisionSoundTime = -Double.infinity

    var orderedPlayers: [ROBBattlePlayerIdentity] {
        players.values.sorted { lhs, rhs in
            if lhs.id == localIdentity.id { return true }
            if rhs.id == localIdentity.id { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    var playerCount: Int { players.count }
    var isHost: Bool { players.keys.min(by: { $0.uuidString < $1.uuidString }) == localIdentity.id }
    var allPlayersHaveVoted: Bool { players.count >= 2 && players.keys.allSatisfy { votes[$0] != nil } }
    var canStartMatch: Bool { phase == .voting && isHost && allPlayersHaveVoted }
    var selectedVote: ROBBattleArena? { votes[localIdentity.id] }
    var allRobotStates: [ROBBattleRobotState] { [localRobot] + Array(remoteRobots.values) }
    var localScore: Int { scores[localIdentity.id, default: 0] }
    var localDeaths: Int { deaths[localIdentity.id, default: 0] }
    var localHealthFraction: Double { Double(localRobot.health) / 100 }
    var localShieldFraction: Double { Double(localRobot.shields) / 50 }
    var winnerName: String? { winnerID.flatMap { players[$0]?.name } }
    var networkPlayerDescription: String { "\(playerCount)/\(Self.maximumPlayers) players" }

    func animationState(for robotID: UUID) -> ROBBattleRobotAnimationState {
        robotAnimations[robotID, default: .init()]
    }

    init(
        networkingEnabled: Bool = true,
        playerID: UUID? = nil,
        playerName: String? = nil,
        droidProfile: ROBDroidProfile = ROBDroidProfile(),
        audioEnabled: Bool = true,
        soundFeedback: (@MainActor (ROBBattleSoundCue) -> Void)? = nil
    ) {
        let id = playerID ?? Self.installationID()
        let name = playerName ?? Self.defaultPlayerName()
        let transportName = "ROB-\(id.uuidString.prefix(8))"
        let identity = ROBBattlePlayerIdentity(
            id: id,
            name: String(name.prefix(24)),
            transportName: transportName,
            colorIndex: id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % Self.maximumPlayers },
            droidProfile: droidProfile
        )
        localIdentity = identity
        players = [id: identity]
        let initialSpawn = SIMD3<Float>(-6.4, 0, -6.4)
        localRobot = .init(
            id: id, x: initialSpawn.x, z: initialSpawn.z,
            heading: Self.headingTowardArenaCenter(from: initialSpawn),
            health: 100, shields: 50, isAlive: true, respawnRemaining: 0
        )
        robotAnimations = [id: .init()]
        scores = [id: 0]
        deaths = [id: 0]
        if let soundFeedback {
            self.soundFeedback = soundFeedback
        } else if audioEnabled {
            self.soundFeedback = { SoundPlayer.shared.playBattle($0) }
        } else {
            self.soundFeedback = { _ in }
        }
        network = networkingEnabled ? ROBBattleNetwork(transportName: transportName) : nil
        network?.onPacket = { [weak self] packet in self?.receive(packet) }
        network?.onPeerConnected = { [weak self] in self?.broadcastHello() }
        network?.onPeerDisconnected = { [weak self] name in self?.removePeer(transportName: name) }
    }

    func startDiscovery() {
        guard phase != .playing else { return }
        network?.start()
        broadcastHello()
        if playerCount == 1 { statusMessage = "AutoNet is looking for nearby ROB Training battles…" }
    }

    func stopNetworking() { network?.stop() }

    func updateLocalProfile(_ profile: ROBDroidProfile) {
        guard localIdentity.droidProfile != profile else { return }
        localIdentity.droidProfile = profile
        players[localIdentity.id] = localIdentity
        broadcastHello()
    }

    func vote(for arena: ROBBattleArena) {
        guard phase == .voting else { return }
        votes[localIdentity.id] = arena
        statusMessage = "Vote locked for \(arena.name)."
        send(.init(kind: .vote, sender: localIdentity, vote: arena))
    }

    func votes(for arena: ROBBattleArena) -> Int { votes.values.filter { $0 == arena }.count }

    func startMatch() {
        guard canStartMatch else { return }
        let winningArena = resolvedArenaVote()
        let assignments = players.keys.sorted { $0.uuidString < $1.uuidString }.enumerated().map {
            ROBBattleSpawnAssignment(playerID: $0.element, spawnIndex: $0.offset)
        }
        let start = ROBBattleMatchStart(
            matchID: UUID(),
            arena: winningArena,
            assignments: assignments,
            duration: Self.matchDuration,
            scoreLimit: Self.scoreLimit
        )
        applyMatchStart(start)
        send(.init(kind: .matchStart, sender: localIdentity, matchStart: start))
    }

    func openNextArenaVote() {
        guard phase == .results, isHost else { return }
        applyNextVote()
        send(.init(kind: .nextVote, sender: localIdentity))
    }

    func setTreads(left: Double, right: Double) {
        leftTread = max(-1, min(1, left))
        rightTread = max(-1, min(1, right))
    }

    func stopDrive() { setTreads(left: 0, right: 0) }

    func tick(_ delta: TimeInterval) {
        guard phase == .playing else { return }
        let step = min(max(delta, 0), 0.1)
        remainingTime = max(0, remainingTime - step)

        if localRobot.isAlive {
            updateMovement(step)
        } else {
            localRobot.respawnRemaining = max(0, localRobot.respawnRemaining - step)
            if localRobot.respawnRemaining <= 0 { respawnLocalRobot() }
        }
        updateProjectiles(step)
        updateRemoteInterpolation(step)
        updateRobotAnimationTimers(step)

        let matchElapsed = Self.matchDuration - remainingTime
        if matchElapsed - lastSnapshotSent >= 1.0 / 15.0 {
            lastSnapshotSent = matchElapsed
            broadcastSnapshot()
        }

        if isHost, remainingTime <= 0 || scores.values.max() ?? 0 >= Self.scoreLimit {
            finishMatch()
        }
    }

    func fireLaser() {
        let matchElapsed = Self.matchDuration - remainingTime
        guard phase == .playing, localRobot.isAlive, matchElapsed - lastLaserTime >= 0.28 else { return }
        lastLaserTime = matchElapsed
        let speed: Float = 10.5
        let projectile = ROBBattleProjectile(
            id: UUID(),
            ownerID: localIdentity.id,
            x: localRobot.x - sin(localRobot.heading) * 0.72,
            z: localRobot.z - cos(localRobot.heading) * 0.72,
            velocityX: -sin(localRobot.heading) * speed,
            velocityZ: -cos(localRobot.heading) * speed,
            remaining: 2,
            damage: 28
        )
        projectiles.append(projectile)
        startLaserAnimation(for: localIdentity.id)
        play(.laser)
        send(.init(kind: .projectile, sender: localIdentity, projectile: projectile))
    }

    func saberAttack() {
        let matchElapsed = Self.matchDuration - remainingTime
        guard phase == .playing, localRobot.isAlive, matchElapsed - lastMeleeTime >= 0.7 else { return }
        lastMeleeTime = matchElapsed
        let event = ROBBattleMeleeEvent(
            id: UUID(), attackerID: localIdentity.id,
            x: localRobot.x, z: localRobot.z, heading: localRobot.heading, damage: 38
        )
        startSaberAnimation(for: localIdentity.id)
        play(.saber)
        send(.init(kind: .melee, sender: localIdentity, melee: event))
    }

    func updateControllerName(_ name: String?) { connectedControllerName = name }

    private func updateMovement(_ delta: Double) {
        let forward = Float((leftTread + rightTread) * 0.5)
        let turn = Float((rightTread - leftTread) * 0.5)
        advanceTreads(
            for: localIdentity.id,
            leftDistance: Float(leftTread * delta * 3.35),
            rightDistance: Float(rightTread * delta * 3.35)
        )
        localRobot.heading += turn * Float(delta) * 2.25
        let distance = forward * Float(delta) * 3.35
        let candidate = SIMD2<Float>(
            localRobot.x - sin(localRobot.heading) * distance,
            localRobot.z - cos(localRobot.heading) * distance
        )
        let current = SIMD2<Float>(localRobot.x, localRobot.z)
        let resolved = resolvedPosition(from: current, to: candidate)
        localRobot.x = resolved.x
        localRobot.z = resolved.y
    }

    private func resolvedPosition(from current: SIMD2<Float>, to candidate: SIMD2<Float>) -> SIMD2<Float> {
        if let remote = collidingRemote(at: candidate) {
            return resolveRobotCollision(from: current, attempted: candidate, with: remote)
        }
        if isClear(candidate) { return candidate }
        let xOnly = SIMD2<Float>(candidate.x, current.y)
        if isClear(xOnly) { return xOnly }
        let zOnly = SIMD2<Float>(current.x, candidate.y)
        return isClear(zOnly) ? zOnly : current
    }

    private func isClear(_ point: SIMD2<Float>) -> Bool {
        isStaticClear(point) && collidingRemote(at: point) == nil
    }

    private func isStaticClear(_ point: SIMD2<Float>) -> Bool {
        let limit = Self.arenaHalfExtent - Self.robotRadius
        guard abs(point.x) <= limit, abs(point.y) <= limit else { return false }
        return !arena.barriers.contains(where: {
            abs(point.x - $0.x) < $0.width / 2 + Self.robotRadius &&
            abs(point.y - $0.z) < $0.depth / 2 + Self.robotRadius
        })
    }

    private func collidingRemote(at point: SIMD2<Float>, excluding excludedID: UUID? = nil) -> ROBBattleRobotState? {
        remoteRobots.values.first { rendered in
            let state = remoteInterpolations[rendered.id]?.target ?? rendered
            return state.id != excludedID && state.isAlive &&
                hypot(point.x - state.x, point.y - state.z) < Self.robotRadius * 2
        }
    }

    private func resolveRobotCollision(
        from current: SIMD2<Float>,
        attempted: SIMD2<Float>,
        with remote: ROBBattleRobotState
    ) -> SIMD2<Float> {
        let now = Self.matchDuration - remainingTime
        guard now - lastCollisionTimes[remote.id, default: -.infinity] >= Self.collisionEventCooldown else {
            return current
        }
        var away = current - SIMD2<Float>(remote.x, remote.z)
        let distance = simd_length(away)
        if distance < 0.001 {
            away = current - attempted
            if simd_length(away) < 0.001 {
                away = SIMD2<Float>(sin(localRobot.heading), cos(localRobot.heading))
            }
        }
        let normal = simd_normalize(away)
        let overlapCorrection = max(0, Self.robotRadius * 2 - distance)
        let impulse = min(1.2, max(Self.collisionImpulse, overlapCorrection * 0.5 + Self.collisionImpulse))
        let event = ROBBattleCollisionEvent(
            id: UUID(),
            initiatorID: localIdentity.id,
            otherRobotID: remote.id,
            normalX: normal.x,
            normalZ: normal.y,
            impulse: impulse
        )
        lastCollisionTimes[remote.id] = now
        processedEvents.insert(event.id)
        startCollisionAnimation(for: localIdentity.id)
        startCollisionAnimation(for: remote.id)
        playCollisionSound(at: now)
        statusMessage = "Metal-to-metal contact — separating the droids."
        send(.init(kind: .collision, sender: localIdentity, collision: event))
        return pushedPosition(from: current, direction: normal, distance: impulse, excluding: remote.id)
    }

    private func applyCollision(_ event: ROBBattleCollisionEvent, senderID: UUID) {
        guard processedEvents.insert(event.id).inserted,
              phase == .playing,
              event.initiatorID == senderID,
              event.otherRobotID == localIdentity.id,
              localRobot.isAlive,
              let remote = remoteRobots[event.initiatorID], remote.isAlive else { return }
        let now = Self.matchDuration - remainingTime
        guard now - lastCollisionTimes[event.initiatorID, default: -.infinity] >= Self.collisionEventCooldown,
              hypot(localRobot.x - remote.x, localRobot.z - remote.z) <= Self.robotRadius * 3.25 else { return }
        lastCollisionTimes[event.initiatorID] = now
        var direction = SIMD2<Float>(-event.normalX, -event.normalZ)
        if simd_length(direction) < 0.001 {
            direction = SIMD2<Float>(localRobot.x - remote.x, localRobot.z - remote.z)
        }
        if simd_length(direction) < 0.001 {
            direction = SIMD2<Float>(sin(localRobot.heading), cos(localRobot.heading))
        }
        direction = simd_normalize(direction)
        let current = SIMD2<Float>(localRobot.x, localRobot.z)
        let pushed = pushedPosition(
            from: current,
            direction: direction,
            distance: min(1.2, max(0.15, event.impulse)),
            excluding: event.initiatorID
        )
        localRobot.x = pushed.x
        localRobot.z = pushed.y
        startCollisionAnimation(for: localIdentity.id)
        startCollisionAnimation(for: event.initiatorID)
        playCollisionSound(at: now)
        statusMessage = "Metal-to-metal contact — separating the droids."
        broadcastSnapshot()
    }

    private func pushedPosition(
        from current: SIMD2<Float>,
        direction: SIMD2<Float>,
        distance: Float,
        excluding remoteID: UUID
    ) -> SIMD2<Float> {
        let candidate = current + direction * distance
        if isStaticClear(candidate), collidingRemote(at: candidate, excluding: remoteID) == nil { return candidate }
        let xOnly = SIMD2<Float>(candidate.x, current.y)
        if isStaticClear(xOnly), collidingRemote(at: xOnly, excluding: remoteID) == nil { return xOnly }
        let zOnly = SIMD2<Float>(current.x, candidate.y)
        if isStaticClear(zOnly), collidingRemote(at: zOnly, excluding: remoteID) == nil { return zOnly }
        return current
    }

    private func acceptRemoteSnapshot(_ snapshot: ROBBattleRobotState, sequence: UInt64?) {
        if let sequence {
            guard sequence > lastRemoteSnapshotSequences[snapshot.id, default: 0] else { return }
            lastRemoteSnapshotSequences[snapshot.id] = sequence
        }
        guard var rendered = remoteRobots[snapshot.id] else {
            remoteRobots[snapshot.id] = snapshot
            remoteInterpolations.removeValue(forKey: snapshot.id)
            return
        }
        let distance = hypot(snapshot.x - rendered.x, snapshot.z - rendered.z)
        guard rendered.isAlive == snapshot.isAlive, distance < Self.remoteSnapDistance else {
            remoteRobots[snapshot.id] = snapshot
            remoteInterpolations.removeValue(forKey: snapshot.id)
            return
        }
        rendered.health = snapshot.health
        rendered.shields = snapshot.shields
        rendered.respawnRemaining = snapshot.respawnRemaining
        remoteRobots[snapshot.id] = rendered
        remoteInterpolations[snapshot.id] = .init(start: rendered, target: snapshot)
    }

    private func updateRemoteInterpolation(_ delta: Double) {
        for id in Array(remoteInterpolations.keys) {
            guard var interpolation = remoteInterpolations[id] else { continue }
            interpolation.elapsed += delta
            let progress = min(1, Float(interpolation.elapsed / Self.remoteInterpolationDuration))
            var rendered = interpolation.target
            rendered.x = interpolation.start.x + (interpolation.target.x - interpolation.start.x) * progress
            rendered.z = interpolation.start.z + (interpolation.target.z - interpolation.start.z) * progress
            rendered.heading = Self.interpolatedHeading(
                from: interpolation.start.heading,
                to: interpolation.target.heading,
                progress: progress
            )
            advanceRemoteTreads(for: id, from: remoteRobots[id], to: rendered)
            remoteRobots[id] = rendered
            if progress >= 1 {
                remoteInterpolations.removeValue(forKey: id)
            } else {
                remoteInterpolations[id] = interpolation
            }
        }
    }

    static func interpolatedHeading(from start: Float, to target: Float, progress: Float) -> Float {
        let amount = min(1, max(0, progress))
        let shortestDelta = atan2(sin(target - start), cos(target - start))
        let heading = start + shortestDelta * amount
        return atan2(sin(heading), cos(heading))
    }

    static func headingTowardArenaCenter(from spawn: SIMD3<Float>) -> Float {
        atan2(spawn.x, spawn.z)
    }

    private func updateRobotAnimationTimers(_ delta: Double) {
        for id in Array(robotAnimations.keys) {
            guard var animation = robotAnimations[id] else { continue }
            animation.saberRemaining = max(0, animation.saberRemaining - delta)
            animation.laserRemaining = max(0, animation.laserRemaining - delta)
            animation.collisionRemaining = max(0, animation.collisionRemaining - delta)
            robotAnimations[id] = animation
        }
    }

    private func startSaberAnimation(for id: UUID) {
        var animation = animationState(for: id)
        animation.saberRemaining = ROBBattleRobotAnimationState.saberDuration
        robotAnimations[id] = animation
    }

    private func startLaserAnimation(for id: UUID) {
        var animation = animationState(for: id)
        animation.laserRemaining = ROBBattleRobotAnimationState.laserDuration
        robotAnimations[id] = animation
    }

    private func startCollisionAnimation(for id: UUID) {
        var animation = animationState(for: id)
        animation.collisionRemaining = ROBBattleRobotAnimationState.collisionDuration
        robotAnimations[id] = animation
    }

    private func advanceTreads(for id: UUID, leftDistance: Float, rightDistance: Float) {
        var animation = animationState(for: id)
        let wheelRadius: Float = 0.16
        animation.leftTreadAngle = (animation.leftTreadAngle + leftDistance / wheelRadius)
            .truncatingRemainder(dividingBy: 2 * .pi)
        animation.rightTreadAngle = (animation.rightTreadAngle + rightDistance / wheelRadius)
            .truncatingRemainder(dividingBy: 2 * .pi)
        robotAnimations[id] = animation
    }

    private func advanceRemoteTreads(
        for id: UUID,
        from previous: ROBBattleRobotState?,
        to current: ROBBattleRobotState
    ) {
        guard let previous else { return }
        let movement = SIMD2<Float>(current.x - previous.x, current.z - previous.z)
        let forward = SIMD2<Float>(-sin(current.heading), -cos(current.heading))
        let forwardDistance = simd_dot(movement, forward)
        let turn = atan2(sin(current.heading - previous.heading), cos(current.heading - previous.heading))
        let halfTrackWidth: Float = 0.39
        advanceTreads(
            for: id,
            leftDistance: forwardDistance - turn * halfTrackWidth,
            rightDistance: forwardDistance + turn * halfTrackWidth
        )
    }

    private func updateProjectiles(_ delta: Double) {
        var survivors: [ROBBattleProjectile] = []
        for var projectile in projectiles {
            projectile.x += projectile.velocityX * Float(delta)
            projectile.z += projectile.velocityZ * Float(delta)
            projectile.remaining -= delta
            guard projectile.remaining > 0,
                  abs(projectile.x) <= Self.arenaHalfExtent,
                  abs(projectile.z) <= Self.arenaHalfExtent,
                  !arena.barriers.contains(where: {
                      abs(projectile.x - $0.x) < $0.width / 2 && abs(projectile.z - $0.z) < $0.depth / 2
                  }) else { continue }
            if projectile.ownerID != localIdentity.id,
               localRobot.isAlive,
               hypot(projectile.x - localRobot.x, projectile.z - localRobot.z) < 0.72 {
                applyDamage(projectile.damage, attackerID: projectile.ownerID)
                send(.init(kind: .projectileImpact, sender: localIdentity, projectileID: projectile.id))
                continue
            }
            survivors.append(projectile)
        }
        projectiles = survivors
    }

    private func applyMelee(_ event: ROBBattleMeleeEvent) {
        guard processedEvents.insert(event.id).inserted,
              event.attackerID != localIdentity.id,
              localRobot.isAlive else { return }
        let offset = SIMD2<Float>(localRobot.x - event.x, localRobot.z - event.z)
        let distance = simd_length(offset)
        guard distance <= 1.7 else { return }
        let forward = SIMD2<Float>(-sin(event.heading), -cos(event.heading))
        guard distance < 0.01 || simd_dot(simd_normalize(offset), forward) > -0.05 else { return }
        applyDamage(event.damage, attackerID: event.attackerID)
    }

    private func applyDamage(_ damage: Int, attackerID: UUID) {
        guard localRobot.isAlive else { return }
        let shieldDamage = min(localRobot.shields, damage)
        localRobot.shields -= shieldDamage
        localRobot.health = max(0, localRobot.health - (damage - shieldDamage))
        statusMessage = players[attackerID].map { "\($0.name) hit ROB." } ?? "ROB took a hit."
        if localRobot.health == 0 {
            localRobot.isAlive = false
            localRobot.respawnRemaining = 3
            deaths[localIdentity.id, default: 0] += 1
            let knockout = ROBBattleKnockout(id: UUID(), attackerID: attackerID, victimID: localIdentity.id)
            applyKnockout(knockout)
            send(.init(kind: .knockout, sender: localIdentity, knockout: knockout))
            statusMessage = "ROB disabled — rebuilding in 3 seconds."
            play(.knockout)
        } else {
            play(.impact)
        }
        broadcastSnapshot()
    }

    private func applyKnockout(_ knockout: ROBBattleKnockout) {
        guard processedEvents.insert(knockout.id).inserted else { return }
        scores[knockout.attackerID, default: 0] += 1
        if knockout.victimID != localIdentity.id {
            deaths[knockout.victimID, default: 0] += 1
            play(.knockout)
        }
    }

    private func respawnLocalRobot() {
        let ids = players.keys.sorted { $0.uuidString < $1.uuidString }
        let spawnIndex = ids.firstIndex(of: localIdentity.id) ?? 0
        let spawn = arena.spawnPoints[spawnIndex % arena.spawnPoints.count]
        localRobot = .init(
            id: localIdentity.id, x: spawn.x, z: spawn.z,
            heading: Self.headingTowardArenaCenter(from: spawn), health: 100, shields: 50,
            isAlive: true, respawnRemaining: 0
        )
        robotAnimations[localIdentity.id] = .init()
        statusMessage = "ROB rebuilt. Re-enter the arena!"
        play(.respawn)
        broadcastSnapshot()
    }

    private func resolvedArenaVote() -> ROBBattleArena {
        ROBBattleArena.allCases.max { lhs, rhs in
            let left = votes(for: lhs), right = votes(for: rhs)
            if left == right {
                return (ROBBattleArena.allCases.firstIndex(of: lhs) ?? 0) > (ROBBattleArena.allCases.firstIndex(of: rhs) ?? 0)
            }
            return left < right
        } ?? .neonFoundry
    }

    private func applyMatchStart(_ start: ROBBattleMatchStart) {
        matchID = start.matchID
        arena = start.arena
        phase = .playing
        remainingTime = start.duration
        winnerID = nil
        scores = Dictionary(uniqueKeysWithValues: players.keys.map { ($0, 0) })
        deaths = Dictionary(uniqueKeysWithValues: players.keys.map { ($0, 0) })
        projectiles = []
        robotAnimations = Dictionary(uniqueKeysWithValues: players.keys.map { ($0, .init()) })
        processedEvents = []
        outgoingSnapshotSequence = 0
        lastRemoteSnapshotSequences = [:]
        remoteInterpolations = [:]
        lastCollisionTimes = [:]
        lastCollisionSoundTime = -.infinity
        lastSnapshotSent = -.infinity
        lastLaserTime = -.infinity
        lastMeleeTime = -.infinity
        let spawnIndex = start.assignments.first(where: { $0.playerID == localIdentity.id })?.spawnIndex ?? 0
        let spawn = arena.spawnPoints[spawnIndex % arena.spawnPoints.count]
        localRobot = .init(
            id: localIdentity.id, x: spawn.x, z: spawn.z,
            heading: Self.headingTowardArenaCenter(from: spawn), health: 100, shields: 50,
            isAlive: true, respawnRemaining: 0
        )
        remoteRobots = [:]
        for assignment in start.assignments where assignment.playerID != localIdentity.id {
            let remoteSpawn = arena.spawnPoints[assignment.spawnIndex % arena.spawnPoints.count]
            remoteRobots[assignment.playerID] = .init(
                id: assignment.playerID, x: remoteSpawn.x, z: remoteSpawn.z,
                heading: Self.headingTowardArenaCenter(from: remoteSpawn), health: 100, shields: 50,
                isAlive: true, respawnRemaining: 0
            )
        }
        network?.pauseDiscovery()
        statusMessage = "\(arena.name) deathmatch: first to \(Self.scoreLimit) knockouts wins."
        play(.matchStart)
        broadcastSnapshot()
    }

    private func finishMatch() {
        guard phase == .playing else { return }
        winnerID = scores.keys.sorted { lhs, rhs in
            let left = scores[lhs, default: 0], right = scores[rhs, default: 0]
            return left == right ? lhs.uuidString < rhs.uuidString : left > right
        }.first
        phase = .results
        stopDrive()
        projectiles = []
        statusMessage = winnerName.map { "\($0) wins \(arena.name)!" } ?? "Deathmatch complete."
        play(.victory)
        send(.init(kind: .matchEnd, sender: localIdentity, winnerID: winnerID))
    }

    private func applyNextVote() {
        phase = .voting
        votes = [:]
        winnerID = nil
        remoteRobots = [:]
        robotAnimations = [localIdentity.id: .init()]
        remoteInterpolations = [:]
        lastRemoteSnapshotSequences = [:]
        lastCollisionTimes = [:]
        projectiles = []
        statusMessage = "Vote for the next deathmatch arena."
        network?.start()
        broadcastHello()
    }

    private func broadcastSnapshot() {
        outgoingSnapshotSequence &+= 1
        send(.init(
            kind: .snapshot,
            sender: localIdentity,
            snapshot: localRobot,
            snapshotSequence: outgoingSnapshotSequence
        ))
    }

    private func broadcastHello() {
        send(.init(kind: .hello, sender: localIdentity))
    }

    private func send(_ packet: ROBBattlePacket) { network?.send(packet) }

    private func receive(_ packet: ROBBattlePacket) {
        guard packet.sender.id != localIdentity.id else { return }
        let isNewPlayer = players[packet.sender.id] == nil
        if isNewPlayer, players.count >= Self.maximumPlayers { return }
        players[packet.sender.id] = packet.sender
        scores[packet.sender.id, default: 0] = scores[packet.sender.id, default: 0]
        deaths[packet.sender.id, default: 0] = deaths[packet.sender.id, default: 0]
        if packet.kind == .hello {
            statusMessage = "\(packet.sender.name) joined. \(networkPlayerDescription) ready."
            if isNewPlayer { broadcastHello() }
        }
        switch packet.kind {
        case .hello: break
        case .vote:
            if phase == .voting, let vote = packet.vote { votes[packet.sender.id] = vote }
        case .matchStart:
            if packet.sender.id == hostID, let start = packet.matchStart { applyMatchStart(start) }
        case .snapshot:
            if phase == .playing, let snapshot = packet.snapshot {
                acceptRemoteSnapshot(snapshot, sequence: packet.snapshotSequence)
            }
        case .projectile:
            if phase == .playing, let projectile = packet.projectile,
               !projectiles.contains(where: { $0.id == projectile.id }) {
                projectiles.append(projectile)
                startLaserAnimation(for: projectile.ownerID)
                play(.laser)
            }
        case .projectileImpact:
            if let projectileID = packet.projectileID { projectiles.removeAll { $0.id == projectileID } }
        case .melee:
            if phase == .playing, let melee = packet.melee {
                startSaberAnimation(for: melee.attackerID)
                play(.saber)
                applyMelee(melee)
            }
        case .knockout:
            if let knockout = packet.knockout { applyKnockout(knockout) }
        case .collision:
            if let collision = packet.collision { applyCollision(collision, senderID: packet.sender.id) }
        case .matchEnd:
            guard packet.sender.id == hostID else { return }
            winnerID = packet.winnerID
            phase = .results
            stopDrive()
            projectiles = []
            statusMessage = winnerName.map { "\($0) wins \(arena.name)!" } ?? "Deathmatch complete."
            play(.victory)
        case .nextVote:
            if packet.sender.id == hostID { applyNextVote() }
        }
    }

    private var hostID: UUID? { players.keys.min(by: { $0.uuidString < $1.uuidString }) }

    private func removePeer(transportName: String) {
        guard let peer = players.values.first(where: { $0.transportName == transportName }) else { return }
        players.removeValue(forKey: peer.id)
        votes.removeValue(forKey: peer.id)
        remoteRobots.removeValue(forKey: peer.id)
        robotAnimations.removeValue(forKey: peer.id)
        remoteInterpolations.removeValue(forKey: peer.id)
        lastRemoteSnapshotSequences.removeValue(forKey: peer.id)
        lastCollisionTimes.removeValue(forKey: peer.id)
        statusMessage = "\(peer.name) left the battle."
        if phase == .playing, players.count < 2 {
            phase = .results
            winnerID = localIdentity.id
            statusMessage = "Opponent disconnected. \(localIdentity.name) wins."
            play(.victory)
        }
    }

    private func play(_ cue: ROBBattleSoundCue) {
        soundFeedback(cue)
    }

    private func playCollisionSound(at time: Double) {
        guard time - lastCollisionSoundTime >= Self.collisionSoundCooldown else { return }
        lastCollisionSoundTime = time
        play(.collision)
    }

    private static func installationID() -> UUID {
        let key = "ROBBattleInstallationID"
        if let stored = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: stored) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    private static func defaultPlayerName() -> String {
        let raw = ProcessInfo.processInfo.hostName
        let cleaned = raw.replacingOccurrences(of: ".local", with: "")
        return cleaned.isEmpty ? "ROB Pilot" : cleaned
    }

    // Deterministic hooks keep the networking protocol and arena rules testable
    // without opening Bonjour sockets in the unit-test process.
    func testReceive(_ packet: ROBBattlePacket) { receive(packet) }
}

@MainActor
@Observable
final class ROBBattleControllerInput: NSObject {
    private(set) var controllerName: String?
    @ObservationIgnored private weak var battle: ROBBattleCoordinator?
    @ObservationIgnored private var controllers: [ObjectIdentifier: GCController] = [:]
    @ObservationIgnored private var primaryID: ObjectIdentifier?
    @ObservationIgnored private var saberPressed = false
    @ObservationIgnored private var laserPressed = false
    @ObservationIgnored private var isStarted = false

    func start(battle: ROBBattleCoordinator) {
        self.battle = battle
        guard !isStarted else { return }
        isStarted = true
        NotificationCenter.default.addObserver(self, selector: #selector(didConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        for controller in GCController.controllers() { configure(controller) }
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        NotificationCenter.default.removeObserver(self)
        GCController.stopWirelessControllerDiscovery()
        controllers.values.forEach { $0.extendedGamepad?.valueChangedHandler = nil }
        controllers = [:]
        primaryID = nil
        battle?.stopDrive()
        battle?.updateControllerName(nil)
        controllerName = nil
    }

    @objc private func didConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        configure(controller)
    }

    @objc private func didDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        let id = ObjectIdentifier(controller)
        controller.extendedGamepad?.valueChangedHandler = nil
        controllers.removeValue(forKey: id)
        if primaryID == id { primaryID = nil; choosePrimary() }
    }

    private func configure(_ controller: GCController) {
        guard controller.extendedGamepad != nil else { return }
        let id = ObjectIdentifier(controller)
        controllers[id] = controller
        if primaryID == nil { primaryID = id }
        controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, _ in
            Task { @MainActor [weak self] in self?.update(gamepad, id: id) }
        }
        choosePrimary()
    }

    private func choosePrimary() {
        if primaryID == nil { primaryID = controllers.keys.first }
        guard let primaryID, let controller = controllers[primaryID] else {
            controllerName = nil
            battle?.updateControllerName(nil)
            return
        }
        controller.playerIndex = .index1
        controllerName = controller.vendorName ?? "Game controller"
        battle?.updateControllerName(controllerName)
    }

    private func update(_ gamepad: GCExtendedGamepad, id: ObjectIdentifier) {
        guard id == primaryID else { return }
        let input = ROBTreadInput.tank(
            leftStickY: gamepad.leftThumbstick.yAxis.value,
            rightStickY: gamepad.rightThumbstick.yAxis.value
        )
        battle?.setTreads(left: input.left, right: input.right)
        let nextSaber = gamepad.buttonA.isPressed || gamepad.buttonX.isPressed
        let nextLaser = gamepad.rightTrigger.value > 0.2 || gamepad.rightShoulder.isPressed
        if nextSaber && !saberPressed { battle?.saberAttack() }
        if nextLaser && !laserPressed { battle?.fireLaser() }
        saberPressed = nextSaber
        laserPressed = nextLaser
    }
}
