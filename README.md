# ROB Training Games

A shared educational game for iPhone, iPad, and Apple Vision Pro that matches the Orbitus Robotics browser simulator.

## Experiences

- **Shared campaign:** twenty-four matching missions in expanded arenas with raised ledge decks that require ROB's two-pole, rear-shaft LT-2-style flipper, three lives shared across the full trial, coordinated arrow driving, animated directional conveyor chevrons, Flipper Zero door and security-camera hacks, security-camera stealth zones, larger energy-cell routes, a manually triggered bubble shield that fades after a short defensive window, shield and repair pickups, battle-funded upgrade bays between levels, shared drive-and-laser energy management, reinforced campaign bosses, enemy-contact damage, level restart, scoring, and increasingly difficult route-planning challenges. Losing the third life clears the trial score, upgrade points, and installed upgrades before returning to Level 1.
- **Active combat:** both AMBER arm assemblies alternate wide dual-saber sweeps and trigger a torso spin on the third consecutive attack. Ranged loadouts fire collision-tested projectiles; Twin Blasters launch two visible beams and gain independent two-target locks after the Targeting Computer upgrade, while spider bots and Dalek-style sentry robots coordinate increasingly dense counterattacks.
- **Matching keyboard controls:** use arrow keys or `WASD` to drive, `F` to lower the flippers and raise the front, `B` to raise them for stable travel, `Space` for the saber combo, `Q` to charge the virtual pan-tilt training laser, and `E` to trigger the short bubble-shield window on iPad/iPhone with a hardware keyboard and Vision Pro with a connected keyboard.
- **Circuit School and Droid Workshop:** open the 90-build Circuit Quest from the Learn tab (80 core passport builds plus ten Book Bridge missions), then watch tutorial ranges accumulate into tread, torso, camera/network, compute, arm, commissioned, base-flipper, voice/audio, and show-ready robot sections. Learners add the base lift motor and recovery state, follow samples into ROB's speakers and procedural techno, and explore far-field conference-microphone signal, echo, privacy, and authority before choosing a finish, housing material, and housing style. A checked Droid Code moves the profile between the website, iPhone, iPad, and Apple Vision Pro without an account.
- **Vision Pro tabletop controls:** place the complete scaled arena in a movable volumetric window while the compact mission deck stays in front of the board, pinch and drag independent left/right tread pads with either hand, use both sticks plus action buttons on a gamepad, or drive each tread with its matching member of a paired spatial-controller set.
- **Readable spatial materials:** the campaign and AutoNet arenas use bright physically based wall/floor textures with a balanced four-light rig, preserving depth and obstacle readability in both tabletop and room-scale play.
- **AutoNet multiplayer battle:** nearby iPhone, iPad, and Vision Pro simulators securely discover and join one another without an address or lobby code. Up to four pilots—one simulator and optional game controller each—choose Deathmatch or host-authoritative Capture the Flag, vote between Neon Foundry, Orbital Ring, Reactor Grid, and Shadow Yard, then spawn facing the arena center in the standard view, spatial view, or iOS AR. Every CTF pilot owns a colored base flag, can carry one opponent flag home, drops it when disabled, and can recover their own dropped flag; the first to three captures wins. The standard phone camera follows the local droid closely instead of framing the entire arena. Buffered remote-pose interpolation smooths opponent movement; animated treads, gatling recoil, and dual-saber sweeps expose every droid's actions. Rate-limited metal clanks and synchronized separation impulses keep robot collisions readable without audio chatter, while local cues make combat and flag events audible. Each encrypted peer identity includes its portable Droid Profile, so remote finish, face, material, housing, and assembled sections render consistently for everyone.
- **Generative soundtrack:** an original procedural techno engine synthesizes its kick, hats, bass sequence, and level-reactive tempo locally at runtime. It does not download music or reuse a copyrighted recording.
- **iOS game:** the shared campaign rendered with RealityKit, translucent edge controls, a compact corner HUD in portrait and landscape, optional mission guidance, and local high scores.
- **iOS AR missions:** place the current campaign arena on a horizontal surface, then drive, fight, collect cells, unlock doors, and advance levels over the live camera view. AR shares health, weapons, objectives, collision, and progress with the standard and visionOS missions.
- **visionOS:** a windowed mission console plus an immersive campaign where ROB can be driven, fight training robots, solve key-and-door objectives, and be inspected in the room.
- **Component Explorer:** Animated triangular tri-wheel treads, power, Cerebro, sensing, arms, and safety. Descriptions are deliberately high-level until the publication documentation is expanded.
- **ROB Voice:** push-to-talk, live on-device speech recognition, Apple’s on-device Foundation Model, spoken answers, and optional kid-safe commentary about mission events. Automatic commentary defaults to off and can be enabled from the Voice controls. A small scripted personality remains available when Apple Intelligence is unsupported, disabled, or not ready.

ROB Voice requires microphone and speech-recognition permission. Foundation Models also requires an Apple Intelligence-capable device with Apple Intelligence enabled and its model downloaded. The simulator does not upload game state to a custom service.

## Build

```sh
brew install xcodegen
xcodegen generate
open ROBTrainingGames.xcodeproj
```

Select `ROBTrainingiOS` or `ROBTrainingVision`, choose your signing team, and run on a compatible device. AR camera behavior and AutoNet discovery must be verified on physical hardware. Nearby battle uses the local-network permission and the `_rob-battle._tcp` Bonjour service with required Multipeer Connectivity encryption. No robot-control connection is included: every mission is simulated.

Run the shared campaign tests on an iOS Simulator with `xcodebuild test -scheme ROBTrainingiOS -destination 'platform=iOS Simulator,name=iPhone 17'`. Build the `ROBTrainingVision` scheme against a visionOS Simulator to verify the shared combat renderer and spatial controls.

## Cross-platform gameplay sync

`Shared/GameSession.swift` and `Shared/RobotFactory.swift` are the shared iOS and visionOS gameplay source. `Shared/ROBDroidProfile.swift` is the native half of the portable customization format; its field keys, allowlists, Base64URL encoding, and FNV-1a checksum must remain byte-compatible with the website's `assets/js/rob-droid-profile.mjs`. Every gameplay rules change must also be mirrored in the Orbitus Robotics website's `assets/js/rob-game-rules.mjs`, `assets/js/rob-simulator.js`, and focused rule tests. Keep `GameSession.gameplayRulesetVersion` equal to the website's `GAMEPLAY_RULESET_VERSION`; the current synchronized version is `2026.09.17.1`.

App Store delivery is part of every released game update; pushing source or updating the website alone does not finish a release. Increment `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate the Xcode project, run the shared campaign tests, and commit the release source before archiving. Archive `ROBTrainingiOS` in Release for `generic/platform=iOS` with `-allowProvisioningUpdates`, then use `xcodebuild -exportArchive` with `AppStore/ExportOptions-Upload.plist` to upload that signed archive. Verify Apple processing, attach the new build to the intended App Store version, synchronize `AppStore/metadata.md`, and complete submission. Record the source commit, build, validation, and actual Apple status in `AppStore/submission-checklist.md`; an upload is not a public release. ROB Training Vision has a separate App Store record and remains on hold until its release is requested. Production icons/screenshots, signing, privacy answers, age rating, support URLs, and device validation must match the submitted build. Keep lessons synchronized with `Presentation/ROB-Books/ROBOT_GAME_CURRICULUM.md` as the books evolve.

## Captured ROB appearance

`ROBScanVisualModel` loads the same captured surfaces as the website and Cerebro:
113,900 triangles from the upright PLY reconstruction, partitioned across the
chassis, treads, torso, arms, neck and head. Procedural rear axle flippers, end
rollers and face LEDs preserve their interactive controls. Individual captured
speaker cones and road wheels remain in their reference pose.

Regenerate with ORobotics's `scripts/prepare-captured-rob.py`; see that repository's
`docs/rob-visual-model.md`. Copy `rob-visual.json`, `rob-captured.bin` and
`rob-captured-colors.png` together into `Shared/Resources/` and Cerebro, and keep
both Apple adapters identical. Meshes and textures are cached, and the game
keeps a simple chassis collision box to avoid detailed convex-hull generation.
Graphite shows original capture colors; other finishes tint the captured texture.

These meshes are visual approximations, not calibrated physical kinematics.
Existing game inputs and cosmetics still apply. The climb pose pivots about the
rear contact during front lift, then holds the front at the step while the rear
rises. Forward motion triggers the rear-support transition and final stow.
This contact-based presentation is a game approximation, not a rigid-body solver.
Completing a climb releases its latch so another flipper cycle works on the
platform, including near its lip while the center remains supported. A single
overhanging tread end does not disable the controls or replace the deck with the
lower floor. Leaving an edge tips the base, releases it into gravity, and settles it
on the lower floor. The LACT swings the entire upper body about the hinge above
the upper tread wheel. It targets an estimated upper-body mass center within the
tread support span, leaning forward beyond vertical when a raised base moves the
hinge aft. Its animation keeps pace with the flippers during the transition.
`ROBSupportMotion.swift` matches the browser's support motion and body kinematics;
its illustrative pin geometry uses the photo's 8¼-inch reference length (209.55
mm), not an actuator stroke or a calibrated physical control limit.

Equipped sabers remain fully visible while idle, attacking, and recovering.
`ROBMeleeAnimation.swift` matches the browser's `rob-melee-animation.mjs`: sweeps
ease outward and reverse back to rest, and spin arms ease out and back. Recovery
does not repeat damage; another attack waits for the current animation to finish.

The captured base is aligned with the flipper rig. The virtual training laser
uses the captured shoulder housing and a named muzzle attachment, with no
additional housing. These attachment points are visual game effects only.

The basic targeting computer uses manual forward aim with a 0.8-second firing cycle and 1.8-second full charge. The existing 1,200-point upgrade enables automatic locks for all lasers, two independent Twin Blaster locks, a 0.25-second cycle, and 1.25-second full charge. Shots consume 8–24 energy (Gatling), 10–28 per Twin Blaster volley, and 16–44 (Arc Cannon), including misses. Passive charging pauses while charging a laser and for 1.5 seconds after firing. Nearby battles also charge eight energy per shot and show a battery meter; each rebuild restores 100 energy.

Enemy durability is doubled: original campaign robots have 4–10 shield hit points (rocket-stage robots have 12–16), security mini bosses have 6, and the bosses on levels 5, 10, and 15 have 60, 90, and 120.

Basic sabers deal 1 damage regardless of Laser Power. Kyber Crystal ranks cost 600, 1,600, and 2,600 skill points and raise saber damage to 2, 3, and 4; ranks 2 and 3 require clearing levels 5 and 10. Enemy contact deals 18 damage from spiders, 15 from sentries, 12 from security mini bosses, and 30 from bosses.

Skill points are separate from arcade score: normal defeats award 20, mini bosses 30, bosses 100, and clearing level N awards 50 + 10 × (N − 1), up to 190. Hits, pickups, hacks, and time bonuses add score only. The first three full normal waves and level clears earn 360 skill points total. Existing unspent balances migrate once at 10:1 into `robSkillPoints`, keeping the legacy balance and installed upgrades; old clients writing `robUpgradePoints` cannot overwrite the new currency.

The campaign now has 24 levels with longer routes and additional slalom obstacles. Levels 16–24 require the Plasma Booster: one 900-skill-point upgrade available after clearing Level 3. Hold R or gamepad LB to ascend, release to descend, or tap Boost/Land to toggle thrust while steering. The dual rockets show blue plasma only under thrust, use 18 energy per second, stop at an altitude ceiling, and cannot recharge until landed. Each rocket stage has two elevated cell pads and a higher summit dock. Pilots without the booster can replay the previous stage to earn its cost before deploying.

Browser objectives are checked against a connected route with full chassis turning clearance; cells previously authored inside walls are relocated. Door partitions retain wide approach lanes, the cell objective displays a collected/required count, and wall-turn separation prevents corner traps. The Continue button resumes at the next unlocked level after loading an update.

Steering uses a separate 1.1-radian-per-second tread-differential rate: about 91°/s with keyboard steering and 126°/s with fully opposed joysticks. Speed upgrades increase forward/reverse travel while the turn rate stays the same.
