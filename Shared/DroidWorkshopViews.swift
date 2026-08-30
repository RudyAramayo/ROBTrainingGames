import SwiftUI

struct CircuitSchoolPortal: View {
    @Bindable var session: GameSession

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.indigo.opacity(0.9), .black, .cyan.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("ROB CIRCUIT SCHOOL", systemImage: "bolt.circle.fill")
                            .font(.caption.bold()).tracking(3).foregroundStyle(.cyan)
                        Text("Learn. Build. Customize. Play.").font(.system(size: 42, weight: .black, design: .rounded))
                        Text("Circuit Quest is the interactive web lab for closed loops, Ohm's law, AC/DC, Arduino, 555 timers, op amps, RLC circuits, and ROB's real systems architecture. Finished ROB chapters become assembled sections in your portable droid profile.")
                            .foregroundStyle(.secondary).lineSpacing(4)
                        Link(destination: URL(string: "https://www.orbitusrobotics.com/robot-lab/")!) {
                            Label("Open interactive Circuit Quest", systemImage: "arrow.up.right.square.fill")
                                .frame(maxWidth: .infinity).padding()
                        }
                        .buttonStyle(.borderedProminent).tint(.cyan)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Assembled robot", systemImage: "wrench.and.screwdriver.fill").font(.headline)
                                Spacer()
                                Text("\(session.droidProfile.sections.count)/\(ROBDroidSection.allCases.count)").monospacedDigit().foregroundStyle(.cyan)
                            }
                            ForEach(ROBDroidSection.allCases) { section in
                                HStack {
                                    Image(systemName: section.symbol).frame(width: 28).foregroundStyle(session.droidProfile.sections.contains(section) ? .green : .secondary)
                                    Text(section.displayName)
                                    Spacer()
                                    Image(systemName: session.droidProfile.sections.contains(section) ? "checkmark.seal.fill" : "circle.dashed")
                                        .foregroundStyle(session.droidProfile.sections.contains(section) ? .green : .secondary)
                                }
                            }
                        }
                        .padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

                        Text("The red target dot and blue balloon beam are virtual effects only. Never aim a real laser at a person, animal, vehicle, aircraft, or reflective surface.")
                            .font(.caption.bold()).foregroundStyle(.yellow).padding()
                            .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding().frame(maxWidth: 760).frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Learn")
        }
        .preferredColorScheme(.dark)
    }
}

struct DroidProfileWorkshopCard: View {
    @Bindable var session: GameSession
    @State private var portableCode = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Circuit Quest Droid", systemImage: "shippingbox.and.arrow.backward.fill").font(.title3.bold())
            Text("Customize the protective shell, then carry this checked profile between the web, iPhone, iPad, and Apple Vision Pro.")
                .font(.caption).foregroundStyle(.secondary)

            TextField("Droid designation", text: Binding(
                get: { session.droidProfile.name },
                set: { session.renameDroid($0) }
            ))
            .textFieldStyle(.roundedBorder)

            Picker("Housing material", selection: Binding(
                get: { session.droidProfile.material },
                set: { session.selectHousingMaterial($0) }
            )) {
                ForEach(ROBHousingMaterial.allCases) { Text($0.displayName).tag($0) }
            }

            Picker("Panel style", selection: Binding(
                get: { session.droidProfile.housing },
                set: { session.selectHousingStyle($0) }
            )) {
                ForEach(ROBHousingStyle.allCases) { Text($0.displayName).tag($0) }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                ForEach(ROBDroidSection.allCases) { section in
                    let built = session.droidProfile.sections.contains(section)
                    Label(section.displayName, systemImage: built ? "checkmark.seal.fill" : section.symbol)
                        .font(.caption.bold()).foregroundStyle(built ? .green : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(9)
                        .background((built ? Color.green : Color.secondary).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            TextEditor(text: $portableCode)
                .font(.caption2.monospaced()).frame(minHeight: 82).padding(6)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12)))
            HStack {
                Button("Load my code", systemImage: "arrow.clockwise") { portableCode = session.droidCode }
                Button("Import", systemImage: "square.and.arrow.down") { _ = session.importDroidCode(portableCode) }
                ShareLink(item: session.droidCode, subject: Text("ROB Droid Code"), message: Text("Import this checked code in ROB Training or Circuit Quest.")) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .buttonStyle(.bordered)
            Text(session.message).font(.caption.bold()).foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 5) {
                Label("Pan-tilt virtual Gatling", systemImage: "scope").font(.headline)
                Text("A simulated yaw servo and tilt servo guide a red targeting dot and blue training beam. The game intentionally contains no instructions for a real high-power laser.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding().background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .onAppear { if portableCode.isEmpty { portableCode = session.droidCode } }
    }
}
