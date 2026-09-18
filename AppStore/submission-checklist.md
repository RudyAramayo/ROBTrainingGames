# ROB Training Submission Checklist

Status: **iOS 1.0 (5) in preparation; build 4 remains Waiting for Review**

Updated: September 17, 2026

Apple accepted version 1.0 build 4 for review on September 17, 2026 at 4:59 PM Pacific. Build 4 replaces the earlier build 2 submission; build 3 was uploaded but superseded before submission. Automatic release after approval remains selected. This is a review submission, not a public App Store release. Apple Vision Pro distribution remains on hold. Unchecked hardware and manual checks below remain unverified.

## September 17 build 5 preparation

- Adds matching browser/iOS/visionOS campaign Jammer, premium two-hand gel kit, PEQ modes and remote relay switches; ruleset `2026.09.17.3`.
- Original shared 116-part display model checked in offline front/back renders. No physical radio or weapon controls; no URDF calibration changes.
- Browser: 67 game tests and 46 lab tests passed; production build, 333-item gallery and 59-page subpath checks passed. All 122 iOS Simulator tests passed; six tactical tests passed again after final visual/input polish. The visionOS Simulator build passed.
- Website source `f489e5cc3fd0c2a0f6b8b31e1595f749a13d7c9e` deployed successfully; the public simulator and bundled tactical model returned HTTP 200.
- App Store upload and replacement review submission pending. Vision distribution remains on hold.

## September 17 build 4 release record

- Release source commit: `417234fa917379bf4a83a46f5f360d4271d56598`, committed and pushed before archiving.
- Added matching 24-level lean/grasp/carry/delivery objectives, including chess-pawn placement; ruleset `2026.09.17.2`.
- All 116 iOS Simulator tests passed with zero failures/skips. Tests cover interaction guards, all 24 pickup/delivery stances, scoring once, reset and visible-hand agreement.
- The visionOS Simulator build passed. Vision distribution remains on hold.
- Signed archive: `/Users/rob/Downloads/ROBTraining-Releases/2026-09-17-build-4/ROBTraining-iOS-1.0-4.xcarchive`; validation, archive, upload and export logs are retained in the same release folder.
- Xcode upload succeeded at 4:44 PM Pacific. Apple processing completed; build 4 was selected and the updated 24-mission, pickup/delivery and 102 online Circuit Quest metadata was saved in App Store Connect.
- Retained App Store export: `export/ROB Training.ipa`, 25,178,945 bytes, SHA-256 `2fdb7746fe43b68115be94d2121fc25abb25ca04471d6d16f44a8e6eab743789`.
- Apple Distribution signature and App Store provisioning profile verified: team `975CAGD5EW`, `get-task-allow` false, no registered-device restriction.
- App Store build ID: `57bfa0df-d21f-4b9d-acc9-685127135385`.
- Submission ID: `a36aea89-9ec4-4de3-80cf-18862830631c`.
- [Review record](https://appstoreconnect.apple.com/apps/6805294621/distribution/reviewsubmissions/details/a36aea89-9ec4-4de3-80cf-18862830631c) visibly confirmed **iOS 1.0 (4), Waiting for Review** after submission.
- No separate companion binary is required; native missions work offline and Circuit Quest opens the hosted website.
- [ ] After approval, verify the public App Store listing before reporting a public release.

## Release records

| App | App Store ID | Bundle ID | Version | Build |
| --- | --- | --- | --- | --- |
| ROB Training | 6805294621 | `com.orbitusrobotics.ROBTraining` | 1.0 | 4 submitted |
| ROB Training Vision | 6805295387 | `com.orbitusrobotics.ROBTraining.vision` | 1.0 | 1 |

### September 17 build 3 (superseded by build 4)

- Release source commit: `3636076a91e118d8956937b1062f7a7504c31643`, committed and pushed before archiving.
- Xcode 26.6 (17F113), iPhoneOS SDK 26.5, minimum iOS 18.0, arm64.
- All 113 iOS tests passed with zero failures on the iPhone 17 simulator (iOS 26.5).
- Release archive creation and archive signature verification passed; bundle ID, marketing version, and build were verified before upload.
- Upload used the existing `AppStore/ExportOptions-Upload.plist`, App Store Connect distribution, automatic signing, and team `975CAGD5EW`.
- The simulator app launched to its Play menu. This is not a physical-device or full campaign validation.
- Artifacts and logs: `/Users/rob/Downloads/ROBTraining-Releases/2026-09-17-build-3/` (`Tests.xcresult`, `tests.log`, `archive.log`, `upload.log`, and `ROBTraining-iOS-1.0-3.xcarchive`).
- Retained App Store export: `export/ROB Training.ipa`, 25,145,286 bytes, SHA-256 `e69cb53ee7f7cbd382b28eda6416006743ae002505ed6bd267aa934d504269bd`. This local export is from the uploaded archive; its Apple Distribution signature and App Store provisioning profile passed verification (`get-task-allow` false, no registered-device restriction). `release-manifest.json` records the artifact and upload outcome.
- Support, privacy, marketing, Circuit Quest, and web simulator URLs all returned HTTP 200.
- No separate companion binary is required by this iOS release; native missions work offline and Circuit Quest opens the hosted website.
- Build 3 was superseded by build 4; no build 3 review submission is required.
- [ ] After approval, verify the public App Store listing before reporting a public release.

### Previous September 13 build 2 submission

The iOS app was submitted on September 13, 2026 at 1:15 PM Pacific with automatic release after approval. The account holder supplied the review phone number, and the contact details were saved in App Store Connect. The last visible iOS record was **Waiting for Review** with build 2. The public listing was not yet live.

- Submission ID: `ac4f2632-d99f-4d66-9d4d-0f19d2229f7c`
- App Store build ID: `9ba58069-b1a5-4f0e-bcb1-c546583263eb`
- Release source commit: `8cdc14a`
- Review record: https://appstoreconnect.apple.com/apps/6805294621/distribution/reviewsubmissions/details/ac4f2632-d99f-4d66-9d4d-0f19d2229f7c
- Native app information: https://www.orbitusrobotics.com/rob-training-apps/
- Existing Circuit Quest and web simulator URLs returned HTTP 200. Native missions work offline; online Circuit Quest opens in Safari. No separate companion binary is required by this iOS release.

## September 13 preparation completed

- [x] iOS version 1.0 build 2 uploaded, processed, selected, and submitted. Vision build 1 remains prepared only.
- [x] Current iPhone 6.9-inch gameplay/menu screenshots and iPad 13-inch gameplay screenshot uploaded and accepted. Smaller iPhone sizes inherit the 6.9-inch set. Existing Vision screenshots remain prepared.
- [x] Descriptions, keywords, promotional text, URLs, categories, and review notes saved.
- [x] Primary category set to Education and secondary category set to Games — Action.
- [x] Content rights confirmed, age rating calculated as 13+, and Vision motion set to no high motion.
- [x] Both apps configured as free, public, and available worldwide in 175 countries or regions.
- [x] Automatic release after approval selected.
- [x] Native privacy answers published as **Data Not Collected**.
- [x] Customer-facing robot terminology uses “sentry robot” consistently.
- [x] **Add for Review** and **Submit for Review** completed for iOS; Apple confirmed one item submitted.
- [x] App Review contact name, phone, and email confirmed and saved in the portal. Private contact details are not recorded in this repository.

## Automated validation completed

- [x] September 13: current iOS source passed all 92 tests, with zero failures or skips, on the iPhone 17 simulator (iOS 26.5). Results retained at `/tmp/robtraining-release-20260913/Tests.xcresult`.

- [x] iOS unit tests passed with the `ROBTrainingiOS` scheme on an iPhone 17 Pro Max simulator.
- [x] Release simulator builds passed for the iOS and visionOS schemes.
- [x] The iOS app installed and launched successfully on an iPhone 17 Pro Max simulator.
- [x] The visionOS app installed and launched successfully on an Apple Vision Pro simulator.
- [x] Website production build, 333-item gallery validation, and 51-page subpath validation passed.
- [x] Both simulator launch screens were visually inspected for layout and model-rendering regressions.

Automated launch checks do not establish full gameplay quality. The following physical-device and extended gameplay checks remain unverified; retain them for release follow-up.

## iPhone and iPad manual validation backlog

- [ ] Confirm the left control drives the left tread and the right control drives the right tread.
- [ ] Test simultaneous joystick input and rapid touch changes without dropped or crossed controls.
- [ ] Interrupt input with `touchcancel`, app backgrounding, view changes, and Control Center; ROB must stop and no direction may remain stuck.
- [ ] Drive ROB against walls, partitions, doors, props, and enemies; the body must not visibly penetrate obstacles.
- [ ] Confirm saber attacks alternate as wide left- and right-arm swings with visible arm geometry.
- [ ] Trigger three consecutive saber attacks; both arms and sabers must extend fully while the torso completes the spin attack.
- [ ] Confirm the captured laser sits on ROB’s right shoulder, starts with manual aim, and gains automatic locks only after the Targeting Computer upgrade.
- [ ] Tap Laser for a normal shot; hold it to charge a visibly larger shot with a louder, deeper firing sound.
- [ ] Confirm multiple spider and sentry enemies navigate, pursue, attack, fire projectiles, damage ROB, and reset correctly.
- [ ] Confirm every sentry’s protruding front faces its target and that its laser originates from the front.
- [ ] Confirm sentry voice effects include “Exterminate!” and remain intelligible at normal device volume.
- [ ] Confirm the spider robot has varied, appropriate movement, attack, hit, and defeat sounds.
- [ ] Complete all 24 missions, including cells, keys, locked doors, flipper climbs, plasma boosters, Mission Control docking, progression, scoring, retry, and completion states.
- [ ] Verify music and sound-effect controls, interruption recovery, mute behavior, and audio mixing.
- [ ] Test AR Lab permission handling, surface placement, scale, movement, and return to the standard app.
- [ ] On two to four physical devices, allow local-network access and confirm AutoNet discovery, the four-player cap, every-player arena voting, game-controller input, movement/projectile synchronization, scoring, respawning, next-arena voting, disconnect handling, and both standard and AR battle views.
- [ ] Test ROB Voice opt-in, microphone and speech permission paths, denial handling, supported-device behavior, and offline behavior.
- [ ] Repeat the complete control and layout pass on a physical iPad in every supported orientation.

## Apple Vision Pro manual validation backlog

- [ ] Enter and exit the immersive workshop repeatedly without a crash, hang, or stranded immersive state.
- [ ] Confirm spatial panels, gaze-and-pinch input, and keyboard controls provide equivalent movement and combat behavior.
- [ ] Repeat the tread, stuck-input, collision, saber combo, laser lock/charge, enemy combat, audio, and all-mission tests from iOS.
- [ ] Confirm full-scale placement, reach, occlusion, collision, and enemy spacing are comfortable and visually plausible.
- [ ] Verify motion remains comfortable during pursuit, spin attacks, projectiles, damage feedback, and mission transitions.
- [ ] Test microphone and speech permissions, ROB Voice opt-in, denial handling, and offline behavior in visionOS.
- [ ] Complete a sustained play session on Apple Vision Pro hardware when hardware is available.
- [ ] Join an iPhone/iPad AutoNet battle from Vision Pro and verify the shared vote, arena, robots, projectiles, scoreboard, controller input, and next-round flow.

## Website regression gate

- [ ] On iPhone and Android browsers, confirm the dual joysticks work simultaneously and replace arrow-button controls.
- [ ] Verify movement always stops after `touchcancel`, pointer cancellation, focus loss, page visibility changes, and fullscreen exit.
- [ ] Confirm fullscreen mode hides the surrounding site interface and uses the maximum viewport allowed by the browser.
- [ ] Repeat enemy movement, combat, sound, sentry orientation, saber, laser, collision, level, and progression tests.
- [ ] Confirm the public CloudKit leaderboard can be read without signing in.
- [ ] Confirm Sign in with Apple can publish the player’s call sign, score, and campaign time.
- [ ] Confirm local leaderboard fallback and CloudKit loading, authentication, save, and error states are understandable.
- [ ] Confirm production has `ROB_CLOUDKIT_LEADERBOARD_ENABLED=true` and a valid CloudKit API token before advertising public ranking.

## Privacy and leaderboard boundary

Version 1.0 of the native iOS and visionOS apps stores scores locally and does not contain the website’s CloudKit leaderboard integration. AutoNet battle packets remain inside the nearby encrypted Multipeer Connectivity session and are not collected by Orbitus Robotics. The current native **Data Not Collected** declaration matches those builds.

- [ ] If CloudKit sync, accounts, analytics, telemetry, advertising, or any other data transfer is added to either native app, reassess and update App Privacy before submission.
- [ ] Do not claim native cross-device or public leaderboard sync in the store listing unless that feature is present in the selected build and has passed review.

## September 13 portal recheck

- [x] Confirmed version, build, screenshots, metadata, support URL, marketing URL, and privacy-policy URL are attached and saved.
- [x] Rechecked privacy answers: **Data Not Collected**; no native CloudKit, analytics, or account integration found.
- [x] Reconfirmed content rights, 13+ rating, $0.00 price, public distribution, 175-country availability, and automatic release.
- [x] Updated store text to sentry robot terminology and described online Circuit Quest access accurately.
- [x] Enter and verify private App Review contact details.
- [ ] Confirm there are no unresolved P0/P1 defects, crashes, hangs, stuck controls, progress blockers, or major visual/audio regressions.
- [x] Captured iPhone 17/17 Pro Max and iPad Pro 13-inch simulator screenshots; verified mission launch, pause, return to menu, and the Learn link. Artifacts are retained in `/tmp/robtraining-release-20260913/`.
- [x] Account holder authorized publishing the iOS game on September 13, 2026.
- [x] Reviewed the summary showing iOS 1.0 (2), submitted it, and verified **Waiting for Review**.

The historical build 2 submission was removed on September 17 and replaced by the build 4 submission recorded above. Do not describe the app as published until approval and public listing verification are complete.

Previous build 2 archive location: `/tmp/robtraining-release-20260913/ROBTraining-iOS-1.0-2.xcarchive` (temporary artifact; no longer present on September 17). Its archive signature verification and Xcode export/upload passed on September 13, and its processing completed before selection and submission.
