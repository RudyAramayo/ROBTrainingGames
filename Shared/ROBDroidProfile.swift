import Foundation

enum ROBHousingMaterial: String, CaseIterable, Codable, Identifiable, Sendable {
    case powderCoatedSteel
    case brushedAluminum
    case impactPolymer
    case carbonComposite

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .powderCoatedSteel: "Powder-coated steel"
        case .brushedAluminum: "Brushed aluminum"
        case .impactPolymer: "Impact polymer"
        case .carbonComposite: "Carbon composite"
        }
    }
    var summary: String {
        switch self {
        case .powderCoatedSteel: "Tough panels with a durable colored finish."
        case .brushedAluminum: "Light, bright panels with a metallic sheen."
        case .impactPolymer: "Rounded nonmetal panels for a friendly maker-floor shell."
        case .carbonComposite: "Dark lightweight panels reserved for advanced builds."
        }
    }
    var isMetallic: Bool { self == .powderCoatedSteel || self == .brushedAluminum }
}

enum ROBHousingStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case fieldShell
    case openMakerFrame
    case festivalArmor

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fieldShell: "Field shell"
        case .openMakerFrame: "Open maker frame"
        case .festivalArmor: "Festival armor"
        }
    }
    var summary: String {
        switch self {
        case .fieldShell: "Full service panels protect wiring and connectors."
        case .openMakerFrame: "Color-coded covers leave teaching systems visible."
        case .festivalArmor: "Rounded high-visibility panels for the Maker Faire floor."
        }
    }
}

enum ROBDroidSection: String, CaseIterable, Codable, Identifiable, Sendable {
    case treads
    case torso
    case cameraNetwork
    case bellyCompute
    case arms
    case commissioned

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .treads: "Tread system"
        case .torso: "Torso & rotation"
        case .cameraNetwork: "Camera & network"
        case .bellyCompute: "Belly compute"
        case .arms: "Arm system"
        case .commissioned: "Mission-ready ROB"
        }
    }
    var symbol: String {
        switch self {
        case .treads: "gearshape.2.fill"
        case .torso: "rotate.3d.fill"
        case .cameraNetwork: "network"
        case .bellyCompute: "desktopcomputer"
        case .arms: "figure.strengthtraining.traditional"
        case .commissioned: "flag.checkered"
        }
    }
}

struct ROBDroidProfile: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let storageKey = "robDroidProfileCode"

    var version = Self.schemaVersion
    var name = "ROB MAKER"
    var finish = ROBFinish.graphite
    var faceColor = ROBFaceColor.lime
    var material = ROBHousingMaterial.powderCoatedSteel
    var housing = ROBHousingStyle.fieldShell
    var sections: [ROBDroidSection] = []
    var weaponMount = "panTiltGatling"
    var targetLaser = "red"
    var trainingBeam = "blue"

    enum CodingKeys: String, CodingKey {
        case trainingBeam = "b"
        case faceColor = "c"
        case finish = "f"
        case housing = "h"
        case material = "m"
        case name = "n"
        case sections = "s"
        case targetLaser = "t"
        case version = "v"
        case weaponMount = "w"
    }

    init(
        name: String = "ROB MAKER",
        finish: ROBFinish = .graphite,
        faceColor: ROBFaceColor = .lime,
        material: ROBHousingMaterial = .powderCoatedSteel,
        housing: ROBHousingStyle = .fieldShell,
        sections: [ROBDroidSection] = []
    ) {
        self.name = Self.cleanName(name)
        self.finish = finish
        self.faceColor = faceColor
        self.material = material
        self.housing = housing
        self.sections = Self.orderedSections(sections)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try values.decode(Int.self, forKey: .version)
        guard decodedVersion == Self.schemaVersion else { throw ROBDroidProfileCodeError.unsupportedVersion }
        version = decodedVersion
        name = Self.cleanName(try values.decode(String.self, forKey: .name))
        finish = try values.decode(ROBFinish.self, forKey: .finish)
        faceColor = try values.decode(ROBFaceColor.self, forKey: .faceColor)
        material = try values.decode(ROBHousingMaterial.self, forKey: .material)
        housing = try values.decode(ROBHousingStyle.self, forKey: .housing)
        sections = Self.orderedSections(try values.decode([ROBDroidSection].self, forKey: .sections))
        weaponMount = try values.decode(String.self, forKey: .weaponMount)
        targetLaser = try values.decode(String.self, forKey: .targetLaser)
        trainingBeam = try values.decode(String.self, forKey: .trainingBeam)
        guard weaponMount == "panTiltGatling", targetLaser == "red", trainingBeam == "blue" else {
            throw ROBDroidProfileCodeError.unsupportedVersion
        }
    }

    mutating func sanitize() {
        version = Self.schemaVersion
        name = Self.cleanName(name)
        sections = Self.orderedSections(sections)
        weaponMount = "panTiltGatling"
        targetLaser = "red"
        trainingBeam = "blue"
    }

    var appearanceKey: String {
        [finish.rawValue, faceColor.rawValue, material.rawValue, housing.rawValue, sections.map(\.rawValue).joined(separator: "-")].joined(separator: ":")
    }

    static func cleanName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-"))
        let clean = value.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String((clean.isEmpty ? "ROB MAKER" : clean).prefix(20))
    }

    private static func orderedSections(_ values: [ROBDroidSection]) -> [ROBDroidSection] {
        let set = Set(values)
        return ROBDroidSection.allCases.filter(set.contains)
    }
}

enum ROBDroidProfileCodeError: LocalizedError {
    case invalidFormat
    case damaged
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidFormat: "That is not a complete ROB Droid Code."
        case .damaged: "The Droid Code was damaged while copying."
        case .unsupportedVersion: "This Droid Code uses an unsupported version."
        }
    }
}

enum ROBDroidProfileCode {
    static let prefix = "ROBDROID1"

    static func encode(_ profile: ROBDroidProfile) -> String {
        var clean = profile
        clean.sanitize()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(clean)) ?? Data()
        let payload = data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "\(prefix).\(payload).\(checksum(data))"
    }

    static func decode(_ code: String) throws -> ROBDroidProfile {
        let parts = code.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == Substring(prefix), parts[2].count == 8 else { throw ROBDroidProfileCodeError.invalidFormat }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload), checksum(data).caseInsensitiveCompare(String(parts[2])) == .orderedSame else {
            throw ROBDroidProfileCodeError.damaged
        }
        do { return try JSONDecoder().decode(ROBDroidProfile.self, from: data) }
        catch let error as ROBDroidProfileCodeError { throw error }
        catch { throw ROBDroidProfileCodeError.invalidFormat }
    }

    static func checksum(_ data: Data) -> String {
        var hash: UInt32 = 0x811c9dc5
        for byte in data {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return String(format: "%08X", hash)
    }
}
