# Lekmod Scion website

A static site (plain HTML, CSS, a little JavaScript) built by a Ruby script with ERB templates and published on GitHub Pages. No server, no database, no gems: only Ruby's standard library.

## Pages and where their content comes from

| Page | Source |
|---|---|
| Mod changelog (`index.html`) | `changelog.txt` at the repo root (format: see its header); three views: Full changelog (default, no filters), Essentials, Search (the version/tag/text filters; filter URLs open it) |
| Essentials (view of `index.html`) | `data/essentials.txt`, written by hand for the latest release: only what changes how the game is played broadly (rules, hidden mechanics, the strategic resource economy, big new UI), no civs or beliefs (user, 2026-10-21); same loose format as the map changelog. Rewrite it for each release |
| Map changelog (`map.html`) | `CHANGELOG.txt` in the map repo (`brunotho/lekmap-scion`), loosely written: `#` headings, `-` bullets, tab-indented sub-bullets |
| Installation (`install.html`) | `templates/install.html.erb` (written by hand) |
| Civ list (`civs.html`) | the mod's `LEKMOD/Override/CIV5Units.xml` and `CIV5Units_Mongol.xml`, read directly |
| Known issues (`bugs.html`) | switched off for now (2026-10-18); `data/known_issues.txt` and `templates/bugs.html.erb` stay, see the comment in `build.rb` |

## Build and preview locally

```
ruby website/build.rb --preview --map "C:/Program Files (x86)/Steam/steamapps/common/Sid Meier's Civilization V/Assets/Maps/lekmap-main/CHANGELOG.txt"
python -m http.server -d website/_site 8000
```
Then open http://localhost:8000. `--preview` also shows the `## UNRELEASED` block; the public build shows released versions only.

Tests (also check that `changelog.txt` stays readable for the site): `ruby website/test/changelog_test.rb`

## How the changelog page works

- Each `## <version> (<date>)` block in `changelog.txt` is a release; the newest is at the top of the file. Its items describe the net change compared with the release before.
- The site merges the same item (same `TYPE_KEY` in brackets, or the same name) across releases into one card, with one part per release, newest first.
- The two dropdowns pick a range of releases (the oldest choice is LEKMOD v35.4, the fork point); only the parts inside the range are shown.
- Sections are the item's first tag, in the order of the tag list in the changelog header. Further tags are filter buttons (several = any of them); the search box matches names and lines. The filter state is kept in the URL.
- Inside a section, cards are alphabetical unless `SECTION_LAYOUT` in `build.rb` gives an order (and optional subsection headings): World Congress, Tourism, Policies, Tiles and Resources. Items with a `Weight: minor` line come last under "Minor changes". `(NEW)` after an item's name shows as a badge.
- Collection cards (`Collects:` line) repeat lines from other cards for an overview; each line starts with `{Source Card}`, shown in grey. The tests check every copy against its source.
- Developer lines (`Note`, `DLL`, `Dev`) and items with only such lines are never shown.
- Policy cards (a card named like a policy branch, e.g. TRADITION) show the branch's tree on the right: `lib/policy_trees.rb` reads positions (`GridX`/`GridY`), prerequisites and the current texts from the Override files; `policy_tree_html` in `build.rb` draws it, and `site.js` shows a policy's text in the panel below the tree on hover, focus or tap. Ideologies show their tenets by tier. Long words get a soft hyphen from `PT_BREAKS`.
- `  - item` lines under a changelog line become sub-bullets.

## Download buttons

The "Download mod/map" buttons and the links on the Installation page point at the repos' latest release page. When the page loads, `site.js` asks the GitHub API (`/repos/<repo>/releases/latest`) for the release's `.zip` and points the link straight at it, so one click downloads it. If the API can't be reached (or its hourly limit of 60 requests per visitor is used up), the link stays on the release page. Each release must have exactly one `.zip` asset.

## Publishing

`.github/workflows/website.yml` builds and publishes the site when a GitHub Release is published, or by hand (Actions > Website > Run workflow). One-time setup: repo Settings > Pages > Source = "GitHub Actions". Releases themselves: `python tools/release.py check|prepare|package <version>`.
