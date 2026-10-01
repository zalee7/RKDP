# Cosmetic Figma Guide

Use this as the reference setup for avatar cosmetic design. The current implementation remains code-drawn in `StickDuelerAvatarView.swift`; these dimensions also support future Figma assets. Board, tile, and card themes can stay code-based for now.

## Master Frame

- Frame size: `1024 x 1024`
- Background: transparent
- Export format: PNG for soft effects/glows, SVG/PDF only for crisp flat shapes
- Keep every item centered on the same `1024 x 1024` canvas
- Name exports exactly like the app cosmetic ID, for example `avatar_head_party_hat.png`

## Alignment Guides

Create these guides in every avatar file:

- Canvas center: `x 512`, `y 512`
- Avatar body safe area: `560 x 560`, centered at `x 512`, `y 560`
- Head safe area: `520 x 300`, centered at `x 512`, from `y 130` to `y 430`
- Face safe area: `360 x 220`, centered at `x 512`, from `y 390` to `y 610`
- Aura safe area: full canvas, with main ring/glow inside `820 x 820`, centered at `x 512`, `y 512`

## Current Avatar Shape

The app avatar is staying as a squared puzzle mascot, not the rounded mascot concept.

- Top edge is flat. Do not design around a top puzzle nub.
- Bottom-center puzzle notch stays.
- Side puzzle notches stay.
- Body outline is a thin soft lavender-white, not a thick pure-white sticker border.
- Hands/feet are intentionally small and secondary. Do not make cosmetics depend on limb details.
- Headwear should sit cleanly above the flat top and should not collide with the face.
- For code-drawn hats, keep the entire silhouette inside the avatar square. The current head seam is about 18 points above center on the renderer's 100-point design grid; the hat top must remain within 50 points above center.

## Placement Rules

**Heads**
- Keep the visual weight centered on `x 512`.
- Hats, crowns, halos, ribbons, and spikes should sit above the body safe area.
- Do not push head items far left/right unless the item is intentionally asymmetrical.
- If the item is asymmetrical, balance it with a small detail on the opposite side.

**Faces**
- Keep eyes and mouth centered around the face safe area.
- Avoid tiny details that disappear at shop-card size.
- Use large readable expression shapes. Tiny masks, laser lines, or tiny robot dots are not preferred for launch.
- High-value faces should have one clear premium detail: shine, gem, sparkle, glow, rainbow, crown, or color shift.

**Body Skins**
- Design inside the `560 x 560` body safe area.
- Assume the app will clip/mask the art to the puzzle-piece body.
- Make dark skins readable with edge shine, inner highlights, or reflective details.
- Obsidian should not be plain black: use blue/purple edge highlights, glass shine, and tiny reflection points.
- Body skins should have a subtle theme animation in-app. Design with one obvious animated idea:
  - Frost: ice reflection, drifting frost wisps, or cold vapor.
  - Lava: moving glow, rising bubbles, or heat veins.
  - Prism: sliding light beam or color sweep.
  - Crystal: shifting facets or glints.
  - Starlight/Cosmic: twinkling dots or slow orbit shimmer.
  - Neon/Arcade: pulsing traces or blinking button lights.
- Keep the main motif large. It must read at shop-card avatar size.

**Auras**
- Use the full canvas, but keep the strongest part inside the `820 x 820` aura safe area.
- Leave the center readable so the avatar body does not get buried.
- Auras can extend farther than hats/bodies, but avoid hard edges touching the canvas border.
- Auras should sit behind the character. They should not cover the face or headwear.
- Draw aura artwork above the circular badge background so it remains visible. Storm and Cosmic stay centered with fixed orbit/cloud geometry; animate light intensity rather than rotating the entire scene.

## Launch Visibility

Keep all existing cosmetic IDs stable for ownership compatibility, but the daily shop should prioritize the strongest launch items.

**Launch Head Direction**
- Strong silhouettes are preferred: party hat, headphones, arcade cap, top hat, visor, wizard hat, champion crown, lightning hair, flame crown, golden halo, orbit halo.
- Tiny accessories can stay in code/debug, but should not be prioritized for launch rotation until polished.

**Launch Expression Direction**
- Prefer large readable expressions: smile, wink, laugh, determined, shades, star eyes, lava eyes, heart eyes, rainbow eyes.
- Avoid small launch expressions that read as dots or thin lines at card size.
- Crown Eyes and Cosmic Eyes remain available to existing owners but are held out of launch rotation because they overlap other eye designs.

**Launch Body Direction**
- Ten bodies including the free Custom Solid: Teal Piece, Frost Piece, Candy Piece, Lava Core, Prism Piece, Royal Blue, Royal Velvet, Starlight Piece, and Obsidian Piece.
- Hold Mint Glow, Diamond Pink, Crystal Piece, and Crown Gold out of the launch shop. Their existing owners can still equip them.
- Frost uses broad ice facets and a moving reflection; Lava uses dark rock, glowing seams, and rising embers; Obsidian uses dark glass planes and a cool reflection; Prism uses broad color bands and a light sweep; Starlight uses a dark sky with fixed, twinkling stars.
- Teal uses enamel edges, Candy uses diagonal pink/mint stripes with a quiet face area, Royal Blue uses armor panels and silver trim, and Royal Velvet uses dark fabric with gold piping. All four remain in the launch catalog after the visual review.
- Keep the center behind the eyes quiet. Avoid putting a second emblem or frame over the face.
- Motion is capped at 24 fps for all nine launch paid body materials. It stops in the background, under Reduce Motion / reduced extra animations / Low Power Mode, and offscreen in scrolling containers. iOS 18+ uses scroll visibility callbacks; iOS 17 uses geometry intersection with the nearest scroll viewport.
- Home header remains static. Shop and Profile use the same avatar renderer. Shop artwork remains full-strength when the purchase action is disabled.

**Launch Aura Direction**
- Prefer clear aura identities: teal glow, pink spark, lava bubble, pixel ring, star burst, crown shine, storm cloud, cosmic aura.
- Keep extra or redundant auras hidden from launch rotation until they feel distinct.

## Priority Items

Design these first:

1. `avatar_outfit_obsidian`
2. `avatar_outfit_starlight`
3. `avatar_outfit_candy`
4. `avatar_outfit_prism`
5. `avatar_outfit_royal_velvet`
6. `avatar_outfit_frost`
7. `avatar_outfit_lava`
8. `avatar_aura_pixel`
9. `avatar_aura_cosmic`
10. `avatar_aura_storm`
11. `avatar_head_party_hat`
12. `avatar_head_prize_ribbon`
13. `avatar_head_puzzle_crown`
14. `avatar_head_cosmic_halo`

## Detail Targets

**Common**
- Simple color or small accent.

**Rare**
- Two-tone color, clear outline, one detail layer.

**Epic**
- Gradient, shine, sparkle, or material effect.

**Legendary**
- Strong silhouette, premium glow, multiple detail layers, and obvious rarity color.

## Export Checklist

- Item is centered on the `1024 x 1024` canvas.
- Transparent background is preserved.
- Item still reads clearly when scaled down to `82 x 82`.
- No important detail touches the canvas edge.
- Filename matches the cosmetic ID exactly.
- Keep a non-exported Figma label with the readable item name and rarity.

## Next Work

See `COSMETIC_RELEASE_PLAN.md` for the cleanup sequence and proposed earned status rewards. Earned rewards are not implemented merely by being listed in that plan.
