# ROB Training Games

A shared educational game for iPhone, iPad, and Apple Vision Pro that matches the Orbitus Robotics browser simulator.

## Experiences

- **Shared campaign:** fifteen matching missions in expanded arenas with coordinated arrow driving, keys and locked doors, collectibles, active target lock, enemy-contact damage, level restart, scoring, and increasingly difficult route-planning challenges.
- **Active combat:** both AMBER arm assemblies alternate wide dual-saber sweeps and trigger a torso spin on the third consecutive attack. A black right-shoulder gatling scans for targets, signals lock in red, and charges larger, deeper laser shots while spider bots and Dalek-style fax robots coordinate increasingly dense counterattacks.
- **Matching keyboard controls:** use arrow keys or `WASD` to drive, press `Space` repeatedly for the saber combo, and hold `Q` to charge the shoulder laser on the website, iPad/iPhone with a hardware keyboard, and Vision Pro with a connected keyboard.
- **Generative soundtrack:** an original procedural techno engine synthesizes its kick, hats, bass sequence, and level-reactive tempo locally at runtime. It does not download music or reuse a copyrighted recording.
- **iOS game:** the shared campaign rendered with RealityKit controls and local high scores.
- **iOS AR Lab:** places a manipulable ROB in the camera view and exposes an educational component explorer.
- **visionOS:** a windowed mission console plus an immersive campaign where ROB can be driven, fight training robots, solve key-and-door objectives, and be inspected in the room.
- **Component Explorer:** Base and treads, power, Cerebro, sensing, arms, and safety. Descriptions are deliberately high-level until the publication documentation is expanded.
- **ROB Voice:** push-to-talk, live on-device speech recognition, Apple’s on-device Foundation Model, spoken answers, and automatic kid-safe commentary about mission events. A small scripted personality remains available when Apple Intelligence is unsupported, disabled, or not ready.

ROB Voice requires microphone and speech-recognition permission. Foundation Models also requires an Apple Intelligence-capable device with Apple Intelligence enabled and its model downloaded. The simulator does not upload game state to a custom service.

## Build

```sh
brew install xcodegen
xcodegen generate
open ROBTrainingGames.xcodeproj
```

Select `ROBTrainingiOS` or `ROBTrainingVision`, choose your signing team, and run on a compatible device. AR camera behavior must be verified on physical hardware. No robot-control connection is included: every mission is simulated.

Run the shared campaign tests on an iOS Simulator with `xcodebuild test -scheme ROBTrainingiOS -destination 'platform=iOS Simulator,name=iPhone 17'`. Build the `ROBTrainingVision` scheme against a visionOS Simulator to verify the shared combat renderer and spatial controls.

Before App Store submission, add production icons/screenshots, signing, privacy review, age rating, support URLs, and device testing. Keep lessons synchronized with `Presentation/ROB-Books/ROBOT_GAME_CURRICULUM.md` as the books evolve.
