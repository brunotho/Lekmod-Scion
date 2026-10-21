# Art sources and conversion (Lekmod custom art)

This folder holds the **original** art behind every custom Lekmod image, plus the tools that turn it into the
game files. It is not part of the mod download (players only get `LEKMOD/`). The rule: never edit the game files in
`LEKMOD/Art/...` by hand; change the source or the tool here, then rebuild.

## Folder layout

| Path | What |
|---|---|
| `promotions/manifest.csv` | One line per custom promotion icon: name, source file, symbol size (`scale`), `key` (`border` or `all`, see step 2), notes. **The single place to look up where an icon comes from.** |
| `promotions/original_ai_2026-04/` | The April 2026 AI-made icons (256 px, opaque dark background), recovered from git (`fde09fce^`). Amphibious I-III here are superseded by the user art. |
| `promotions/user_art/` | Art the user supplied later: Envelopment and Bunker Busting (2026-10-05, 256 px), Sitting Ducks (64 px), Amphibious I-III and Nuke Resistance (45 px PNG, 2026-10-10). |
| `promotions/superseded/` | Earlier user versions that were replaced (kept for reference). |
| `units/<name>/` | Unit portrait sources: Vanguard Corps (square, 256 px, plus the map flag source `flag/vanguard_corps_watchtower_flag_v1.png`), Barlas Cavalry and Bajoras (ringed 1254 px pictures). |
| `menu_backgrounds/` | The source of the one main menu background (`course_of_empire_destruction_v1.jpg`). |
| `tools/` | `build_promotion_icons.py` (the whole promotion pipeline), `reshape_icons.py` (background key-out), `round_icon.py` (building and unit portraits). |

## Promotion icons

### Where the game shows them
- **Promotion choice** (unit panel, when a promotion is ready): 64 px (45 px on small screens). The game draws a round frame around the icon, so the icon itself is a **gold glyph on transparency**.
- **Earned promotions** next to the unit portrait: **32 px, no frame**. The base game draws these as the gold glyph on a **blue square tile** (`PromotionSquare32`). Without the tile our icons vanished into the dark panel.
- **Civilopedia**: 256 px.

### Building (one command)
From the repo root: `python art_sources/tools/build_promotion_icons.py [name ...]` (no names = all).
Preview without writing: add `--preview out.png`. Needs Pillow and `texconv.exe` (`civ-tools\texconv.exe`, or set `TEXCONV`).
It writes `LEKMOD/Art/Promotions/<name>_{256,64,45,32}.dds`. The atlas rows (`IconTextureAtlases`, one 1x1 atlas per icon,
e.g. `LEKMOD_NUKE_RESISTANCE_PROMOTION_ATLAS`) and the promotion's `IconAtlas`/`PortraitIndex` are in `LEKMOD/Override/CIV5Units.xml`.

### Pipeline steps and why
1. **Upscale the source to 256 px.** Sources come in 45, 64 or 256 px. A small source makes the 256 px (Civilopedia) image soft; ask for 256 px or larger art when possible.
2. **Key out the background** (`reshape_icons.reshape`): only background **connected to the image border** becomes transparent, so dark details inside the glyph (eye patch, skull eyes) stay. With `key=all` in the manifest, enclosed dark areas are cleared too (outline shapes, e.g. the Nuke Resistance shield, whose inside would otherwise show as a dark patch on the 32 px tile). The glyph test is "max(R,G) > 90" (gold); edges get a soft alpha.
3. **Crop and fit the glyph** to `scale` x 256 px (0.72 normally, leaves room for the round frame). Nuke Resistance uses 0.80 because its trefoil detail was lost at 0.72.
4. **Even out the gold**: the AI art had baked-in lighting (bright top-left, darker orange right/bottom), which looked thin and weak on the right at 64 px. Gold/orange pixels (hue 25-60 deg, saturated) are lifted to the same brightness (V 0.97, hue at least 42 deg); dark details are untouched.
5. **Shift 8 px right** (2 px at 64 px): in the promotion choice the icons looked 1-2 px too far left.
6. **Write the sizes**: 256 px as BC3 (DXT5) with mips; **64/45 px uncompressed** (B8G8R8A8, one mip). BC3 compresses 4x4 pixel blocks and smeared fine detail at small sizes (very visible on Nuke Resistance); uncompressed small files are only 8-16 KB and use the same DDS format as the menu background, which the game reads.
7. **32 px tile**: the glyph (from the 256 px result) on a blue square tile (box 4,5-27,28; navy-to-teal gradient, lighter 1 px edge), uncompressed.

### Tried and rejected (2026-10-10)
- Blue-recoloured glyph on the 32 px tile: the base game keeps the gold glyph at every size.
- Thickening strokes ("bolding") of thin AI art: helps a little, but close lines merge; better to get bold art. What works at 45-64 px: 2-3 thick shapes, wide spacing, no fine detail, solid gold (Envelopment is the reference).

### Adding a new promotion icon
1. Put the source in `promotions/user_art/` (best: 256 px or larger, gold glyph on a plain dark background, bold and simple).
2. Add a line to `promotions/manifest.csv`.
3. Run the build for that name; check the preview first.
4. Add the 1x1 atlas rows (256/64/45/32) and point the promotion's `IconAtlas` at it (`PortraitIndex` 0).

### Re-running everything with a better process
Change the tool, run `--preview` for all icons, compare with the current files, then build all. The build always starts
from the sources, so it can be run any number of times (nothing gets shifted or evened twice).

## Unit art
- Sources: `units/<name>/` (Vanguard Corps: square portrait + map flag source; Barlas Cavalry and Bajoras: 1254 px
  pictures with a gold ring painted on, user 2026-10-14).
- **Portrait** (unit panel, Civilopedia): `python art_sources/tools/round_icon.py units <name>` writes a circle
  177 px wide at (39,40) in a 256 px cell (the old 173 px layout at (41,42), 4 px wider; see the building icons),
  256/128/80/64/45/32 px, BC3, to `LEKMOD/Art/Units/`. The painted gold ring of the two UU pictures is cut off
  (fixed radius in the tool's `RADIUS`); the game draws its own frame.
- The tool takes the **largest** picture directly in the unit's folder, so other pictures (e.g. a map flag source) go in a subfolder (`flag/`). Until 2026-10-15 the 1254 px flag source sat next to the 256 px Vanguard Corps portrait, and the 2026-10-14 rebuild turned every portrait size into the flag silhouette (user saw it in the tech tree). Without texconv (cloud session) the tool writes BC3 with Pillow.
- **Map flag**: a white silhouette on transparency, scaled to 18 px tall, placed at x = centre + 2 px, y = 4 px in a 32 px canvas (it must stay inside the tapering flag shape), BC3 with one mip. The game tints it in the player's colours. (Barlas Cavalry and Bajoras keep the Sipahi/Knight flags.)

## Building icons
- Sources: `buildings/<name>/<name>_<size>.dds` as delivered by the user (OneDrive art inbox, see CLAUDE.md section 7):
  rounded-square pictures on black, darker towards the edge; a few are an object on black (Jongmyo, MI6).
- Base-game layout (measured on `BuildingPortraits3_*_Exp2Patch.dds` and `WonderAtlas`): a circle 171 px wide at
  (43,42) in a 256 px cell (128: 22..107, 64: 11..54, 45: 8..38), transparent around it, no frame. The city screen
  and the city banner (45 px) draw their ring around that circle.
- `python art_sources/tools/round_icon.py buildings <name> [...]`: crops the source to its picture (bounding box of
  the non-black pixels, 5% inside its nearest edge, radius 0.38-0.47 of the width), scales it into a circle 4 px
  wider than the base layout (175 px at 41,40) and writes 32/45/64/80/128/214/256 to `LEKMOD/Art/Lekmod (v 1)/Art/Buildings/`.
  Sources delivered as a cut-out on white get their white background replaced by a dark colour first
  (`WHITE_BACKGROUND`: Ministry of Truth; since 2026-10-22 also the round pictures on white: Appletree, War College,
  Self-Propelled Artillery). Replaced sources go into an `old/` subfolder (the tool reads only the folder itself).
- Why (2026-10-14): the first version cut a fixed 5% off the source and drew exactly the base circle. The size matched
  the base icons, but the art's dark edge sat right inside the ring and looked like a gap in the city banner
  (user screenshot, Fulling Mill vs a base icon). All icons were rebuilt.
- Atlases: one 1x1 atlas per icon.

## Unit action icons
- Sources: `unit_actions/` (2026-10-16: `buy_city_state_heart_v1.png`, the Merchant of Venice's buy-City-State button; a
  white heart on a baked checkerboard).
- `python art_sources/tools/build_action_icon.py <source> <name>`: keeps only near-white pixels as the glyph, fits it to 72%
  of the cell with a soft shadow, writes 64/45 px uncompressed to `LEKMOD/Art/Lekmod (v 1)/Art/UnitActions/`.
- The base action icons are packed sprites in `Expansion2UITextures.fpk` (with `-index.dds` files), so they can't be used as
  templates directly; our replacements are plain square textures in a 1x1 atlas (`Missions.IconAtlas`).

## Espionage screen icons
- `python art_sources/tools/build_levelup_icon.py [--preview out.png]` draws the framed 45 px level-up arrow for the diplomat
  progress bar (`lekmod_esp_levelup45.dds`): gold ring, glossy black-to-blue disc and pale cyan double chevron, matching the
  base game's `Esp_FramedIcons45_Expansion` icons (those are packed in the game archives, so the style was copied from a
  screenshot). Uncompressed, one mip.

## Main menu backgrounds
Since 2026-10-13 there is one background: `course_of_empire_destruction_v1.jpg` (1920x1200), written as BC1 (no alpha)
with one mip to `LEKMOD/Art/Lekmod (v 1)/UI/lekmod_menu_background.dds` (1.2 MB):
`texconv -f BC1_UNORM -m 1` on a PNG copy. `FrontEnd.lua` sets it directly.
The earlier random rotation (11 paintings, the Great Wall DDS) and the old upstream backgrounds (`oracle_background`, `pyramids_background`)
were deleted on 2026-10-17 (user: one image only); they are in the git history if ever needed.

## Policy branch pictures
- The policy screen loads one 192x292 picture per branch by file name (`PolicyBranch_<Branch>.dds` in
  Expansion2's `SocialPolicyPopup.xml`); a file of the same name under `LEKMOD/Art/` replaces it.
- `policy_branches/extracted/`: the base-game branch pictures, pulled out of
  `Assets/DLC/Expansion2/Resource/DX9/UITextures.fpk` with `python tools/fpk_extract.py <pack> <out_dir> socialpolicies`.
- Expansionism (`PolicyBranch_Exploration.dds`, 2026-10-12) = the Commerce picture (`socialpoliciescommerce.dds`), copied
  unchanged (user decision); Commerce gets new art from the user later.
- The base branches use `SocialPolicies<Branch>.dds` (Commerce, Honor, Piety, Patronage, Rationalism, Order, Freedom,
  Autocracy...), BNW's newer ones `PolicyBranch_<Branch>.dds` (Aesthetics, Exploration). All are 192x292 DXT1, one mip.
- Build: `python art_sources/tools/build_policy_branch.py <source> <game texture name>` (cover-scale to 192x292, centre crop,
  `texconv -f BC1_UNORM -m 1`, written to `LEKMOD/Art/Lekmod (v 1)/Art/PolicyBranches/`).
- Commerce: `policy_branches/commerce/commerce_merchant_ledger_v3.png` (user, 2026-10-12; v1, v2 kept for reference)
  -> `SocialPoliciesCommerce.dds`.

## Tile yield icons (map)
- `YieldIconManager.lua` draws tile yields from 128 px atlases; cells 1-4 show 1-4 icons, the cell at y 512 is the "5+" icon
  with the number drawn on top by the game.
- Tourism (`YieldAtlas_128_Tourism.dds`, upstream Lekmod 2026-08-08) had a camera in the 5+ cell. Since 2026-10-12
  `python art_sources/tools/tourism_yield_atlas.py` rebuilds it from `yield_icons/tourism_yield_atlas_upstream.dds`
  with the single suitcase scaled x2 in that cell (user: players know Tourism as the suitcase).
