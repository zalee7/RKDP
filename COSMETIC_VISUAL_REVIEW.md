# Cosmetic Visual Review - September 24, 2026

## Scope And Changes

Reviewed the actual SwiftUI avatar renderer at 56, 92, and 140 points in an isolated local preview, plus signed-in Home, Shop, Profile, and Profile customization screens. The integrated screens were rechecked after the final renderer update.

- Wizard Hat: shorter centered cone, defined brim, moon/star detail, contained within the avatar square.
- Flame Crown: three actual flame shapes anchored to a gold band; gentle flame motion instead of scattered flame symbols over another crown.
- Lightning Hair: centered lightning spikes with a controlled glow; no bolt extending into the eye area.
- Party Hat: shorter cone and contained pom-pom.
- Top Hat: band sits inside the hat; brim aligns with the head.
- Neon Visor: raised to clear the eyes.
- Crown, Arcade Cap, Headphones, Golden Halo, and Orbit Halo: reviewed; retained.
- Storm Cloud: visible side clouds, rain, and lightning above a blue-gray badge. Reduced external glow. Hat area remains clear.
- Cosmic Aura: dark starfield, fixed orbital arcs, planet dots, and slow twinkling. No whole-scene rotation.
- Teal, Candy, Royal Blue, Royal Velvet: new material layers with clear edges/trim; decorative motifs no longer cover the face. Candy's strongest stripes fade away around the eyes and mouth.
- All nine paid launch bodies now use the same 24 fps maximum material scheduling and motion gating.
- iOS 17 fallback now checks viewport geometry instead of relying only on appearance/disappearance.

Catalog IDs, ownership, prices, and rarity remain stable. Cosmetic descriptions were updated to match the revised visuals. No additional catalog removals were needed in this pass.

## On-Device Rendering Check

Hardware: iPhone 16 Pro Max, iOS 26.6. Optimized isolated preview, built from the actual shared avatar renderer. Nine 92-point body avatars in a three-column grid. No Firebase, gameplay, or animated app background in this harness.

Recorded with Instruments Time Profiler and Points of Interest for 70 seconds. The harness showed animated avatars for 20 seconds, scrolled them offscreen for 20 seconds, then returned them with motion disabled for 20 seconds. Analysis excluded startup and phase transitions.

| Phase | Measured interval | Sampled CPU time | Approximate single-core CPU utilization |
| --- | --- | --- | --- |
| Visible, animated | 16.12 seconds | 2.417 seconds | 15.0% |
| Offscreen | 16.73 seconds | 0.060 seconds | 0.36% |
| Visible, motion disabled | 17.06 seconds | 0.002 seconds | 0.01% |

No material/TimelineView stack samples appeared in the offscreen or motion-disabled analysis windows. Device thermal state remained Nominal throughout the recording.

This is a short sampled CPU check, not a battery-life estimate or a full-game performance benchmark. It confirms rendering activity drops sharply offscreen. It does not establish long-session energy use, GPU cost, or behavior on every supported iPhone/iOS version. The iOS 17 geometry fallback compiles but was not tested on a physical iOS 17 device.

Local trace: `/tmp/rkdp-avatar-device/material-motion.trace`.
Local preview source: `/tmp/rkdp-avatar-review/AvatarReview.swift`.
The isolated Avatar Review app was installed on the simulator and connected test iPhone. It does not access the game account or inventory.

## Validation

- Full simulator app build passed after the renderer refinements.
- Swift parse and DEBUG parse passed.
- `git diff --check` passed.
- Final installed renderer build was checked after sign-in: Home avatar, daily Shop cards (Shades, Party Hat, Headphones, Starlight), visible body checklist cards (Custom Solid, Mint Glow, Teal, Frost), Profile avatar, and owned Head customization.
- No purchases or inventory/equipment changes were made. This account owns only default avatar parts, so the broader hat/body/aura comparisons used the isolated actual-renderer preview. Automated scrolling did not advance the real checklist; lower rows were not rechecked there.
- Final description-only edits also passed a full build; that build was not reinstalled to avoid another sign-in interruption.
- User aesthetic approval remains separate from technical validation.
