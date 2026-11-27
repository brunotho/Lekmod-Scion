# Lekmap Scion (map development files)

Lekmap Scion ships inside the mod since 2026-11-27 (user decision: one download, one version).
Until then it was the separate repo `brunotho/lekmap-scion` (its history stays there; that repo is archived).

## Where things are

| Path | What |
|---|---|
| `LEKMOD/Maps/*.lua` | The map scripts players get. **Edit the map here.** The leaf is `LekmapScion_FractalPangaea.lua` (lobby name `Lekmap Scion <version>`, `_lek_mapgen_logs` switch). |
| `map/CHANGELOG.txt` | Player changelog against Lekmap 5.2; the website's map page (`ruby website/build.rb` reads it by default). Heading `# Lekmap Scion <version> (compared with Lekmap 5.2)`. |
| `map/` (rest) | Developer notes from the map repo: `CLAUDE_HANDOFF.md`, `LEKMAP-DEBUG-MANUAL.txt`, the tuning spec, `SCRATCHPAD-*`, the old `Changelog_v6.0.*`, `scripts/` (log digest, island harness), `unused/` (Equator Ring, parked as `.lua.off`), `New_Tables.xml` (never loaded). |

## How players get it

The game lists map scripts only from `Assets/Maps` (and Documents' `Maps`) and Firaxis' own DLC, not from a mod package.
So the DLL copies every `LEKMOD/Maps/*.lua` that is missing or differs into `Assets/Maps/Lekmap Scion/` when it loads
(`LekmodSyncMapScripts`, switch `LEKMOD_BUNDLED_MAPS`, after snowve's `SnowveSyncMapScripts` by megawac), and deletes
`.lua` files there that the mod no longer has. Nothing else under `Assets/Maps` is touched. `xml.log` gets
`Lekmap Scion maps: ...\Assets\Maps\Lekmap Scion\: N copied, M unchanged, K removed`.

The game scans map scripts before it loads the DLL, so a copy that changed files (first install, update) is listed
only from the next launch. The DLL sets the define `LEKMOD_MAPS_CHANGED` (files copied or removed this load), and the
main menu then asks for one restart (`LekmodShowMapsNotice`, `TXT_KEY_LEKMOD_MAPS_UPDATED`). Snowve instead reloads
the DLC once from the front end (toggling an optional DLC) to rescan; not done here (more moving parts).

`include()` finds files by bare name anywhere under `Assets`, so the copies in `Assets/Maps/Lekmap Scion/` and the
files in the mod folder are found alike (they are byte for byte the same). An old standalone download
(`Assets/Maps/Lekmap Scion 0.1.8` etc.) has the same file names with older content: players must delete it (install page).

## Releases

The map has the mod's version number. `python tools/release.py check <version>` checks the lobby name, the map
changelog heading and that mapgen logs are off; the release zip (`git archive HEAD:LEKMOD`) contains `Maps/`.
