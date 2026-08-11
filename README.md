# ROB Training Games

A shared educational game for iPhone, iPad, and Apple Vision Pro that matches the Orbitus Robotics browser simulator.

## Experiences

- **iOS game:** three tank-drive levels, objectives, score, dual-tread controls, sound, and a local leaderboard.
- **iOS AR Lab:** places a manipulable ROB in the camera view and exposes an educational component explorer.
- **visionOS:** a windowed mission console plus an immersive space where ROB can be moved, rotated, scaled, and inspected in the room.
- **Component Explorer:** Base and treads, power, Cerebro, sensing, arms, and safety. Descriptions are deliberately high-level until the publication documentation is expanded.

## Build

```sh
brew install xcodegen
xcodegen generate
open ROBTrainingGames.xcodeproj
```

Select `ROBTrainingiOS` or `ROBTrainingVision`, choose your signing team, and run on a compatible device. AR camera behavior must be verified on physical hardware. No robot-control connection is included: every mission is simulated.

Before App Store submission, add production icons/screenshots, signing, privacy review, age rating, support URLs, and device testing. Keep lessons synchronized with `Presentation/ROB-Books/ROBOT_GAME_CURRICULUM.md` as the books evolve.

