# ROB Training Submission Checklist

Status: **TABLED — DO NOT ADD FOR REVIEW OR SUBMIT**

Prepared: August 25, 2026

The App Store records are prepared, but submission is intentionally paused until the manual test gate below is complete and the account holder provides the private App Review contact details.

## Release records

| App | App Store ID | Bundle ID | Version | Build |
| --- | --- | --- | --- | --- |
| ROB Training | 6805294621 | `com.orbitusrobotics.ROBTraining` | 1.0 | 1 |
| ROB Training Vision | 6805295387 | `com.orbitusrobotics.ROBTraining.vision` | 1.0 | 1 |

Both records must remain in **Prepare for Submission** until every required item is checked.

## Preparation completed

- [x] Version 1.0 build 1 uploaded and selected for both apps.
- [x] iPhone, iPad, and Apple Vision Pro screenshots accepted.
- [x] Descriptions, keywords, promotional text, URLs, categories, and review notes saved.
- [x] Primary category set to Education and secondary category set to Games — Action.
- [x] Content rights confirmed, age rating calculated as 13+, and Vision motion set to no high motion.
- [x] Both apps configured as free, public, and available worldwide in 175 countries or regions.
- [x] Automatic release after approval selected.
- [x] Native privacy answers published as **Data Not Collected**.
- [x] Customer-facing robot terminology uses “sentry robot” consistently.
- [x] **Add for Review** has not been selected and neither app has been submitted.
- [ ] Enter App Review contact first name, last name, phone number, and email only after the account holder supplies and confirms them.

## Automated validation completed

- [x] iOS unit tests passed with the `ROBTrainingiOS` scheme on an iPhone 17 Pro Max simulator.
- [x] Release simulator builds passed for the iOS and visionOS schemes.
- [x] The iOS app installed and launched successfully on an iPhone 17 Pro Max simulator.
- [x] The visionOS app installed and launched successfully on an Apple Vision Pro simulator.
- [x] Website production build, 333-item gallery validation, and 51-page subpath validation passed.
- [x] Both simulator launch screens were visually inspected for layout and model-rendering regressions.

Automated launch checks do not establish full gameplay quality. Complete the following tests before submission.

## iPhone and iPad manual test gate

- [ ] Confirm the left control drives the left tread and the right control drives the right tread.
- [ ] Test simultaneous joystick input and rapid touch changes without dropped or crossed controls.
- [ ] Interrupt input with `touchcancel`, app backgrounding, view changes, and Control Center; ROB must stop and no direction may remain stuck.
- [ ] Drive ROB against walls, partitions, doors, props, and enemies; the body must not visibly penetrate obstacles.
- [ ] Confirm saber attacks alternate as wide left- and right-arm swings with visible arm geometry.
- [ ] Trigger three consecutive saber attacks; both arms and sabers must extend fully while the torso completes the spin attack.
- [ ] Confirm the black gatling laser sits on ROB’s right shoulder, scans for enemies, and shows an obvious red lock indication.
- [ ] Tap Laser for a normal shot; hold it to charge a visibly larger shot with a louder, deeper firing sound.
- [ ] Confirm multiple spider and sentry enemies navigate, pursue, attack, fire projectiles, damage ROB, and reset correctly.
- [ ] Confirm every sentry’s protruding front faces its target and that its laser originates from the front.
- [ ] Confirm sentry voice effects include “Exterminate!” and remain intelligible at normal device volume.
- [ ] Confirm the spider robot has varied, appropriate movement, attack, hit, and defeat sounds.
- [ ] Complete all 15 missions, including cells, keys, locked doors, Mission Control docking, progression, scoring, retry, and completion states.
- [ ] Verify music and sound-effect controls, interruption recovery, mute behavior, and audio mixing.
- [ ] Test AR Lab permission handling, surface placement, scale, movement, and return to the standard app.
- [ ] Test ROB Voice opt-in, microphone and speech permission paths, denial handling, supported-device behavior, and offline behavior.
- [ ] Repeat the complete control and layout pass on a physical iPad in every supported orientation.

## Apple Vision Pro manual test gate

- [ ] Enter and exit the immersive workshop repeatedly without a crash, hang, or stranded immersive state.
- [ ] Confirm spatial panels, gaze-and-pinch input, and keyboard controls provide equivalent movement and combat behavior.
- [ ] Repeat the tread, stuck-input, collision, saber combo, laser lock/charge, enemy combat, audio, and all-mission tests from iOS.
- [ ] Confirm full-scale placement, reach, occlusion, collision, and enemy spacing are comfortable and visually plausible.
- [ ] Verify motion remains comfortable during pursuit, spin attacks, projectiles, damage feedback, and mission transitions.
- [ ] Test microphone and speech permissions, ROB Voice opt-in, denial handling, and offline behavior in visionOS.
- [ ] Complete a sustained play session on Apple Vision Pro hardware when hardware is available.

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

Version 1.0 of the native iOS and visionOS apps stores scores locally and does not contain the website’s CloudKit leaderboard integration. The current native **Data Not Collected** declaration matches those builds.

- [ ] If CloudKit sync, accounts, analytics, telemetry, advertising, or any other data transfer is added to either native app, reassess and update App Privacy before submission.
- [ ] Do not claim native cross-device or public leaderboard sync in the store listing unless that feature is present in the selected build and has passed review.

## Final portal recheck

- [ ] Confirm version, build, screenshots, metadata, support URL, marketing URL, and privacy-policy URL are still attached and saved.
- [ ] Recheck privacy answers against the exact binaries selected for review.
- [ ] Reconfirm content rights, 13+ rating, free price, public distribution, worldwide availability, and automatic release.
- [ ] Confirm customer-facing robot terminology remains consistent across descriptions, screenshots, and review notes.
- [ ] Enter and verify private App Review contact details.
- [ ] Confirm there are no unresolved P0/P1 defects, crashes, hangs, stuck controls, progress blockers, or major visual/audio regressions.
- [ ] Capture final regression screenshots and retain the test results with the release record.
- [ ] Obtain action-time approval from the account holder before selecting **Add for Review**.
- [ ] Review the submission summary, then obtain separate action-time approval before the final **Submit for Review** action.

Submission is ready only when all required manual checks pass and both approvals are explicit. A prior general confirmation does not authorize a future review or submission click after this test hold.
