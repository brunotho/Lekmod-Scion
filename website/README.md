# Lekmod Rosebranch website

A static site (plain HTML, CSS, a little JavaScript) built by a Ruby script with ERB templates and published on GitHub Pages. No server, no database, no gems: only Ruby's standard library.

## Pages and where their content comes from

| Page | Source |
|---|---|
| Mod changelog (`index.html`) | `changelog.txt` at the repo root (format: see its header) |
| Map changelog (`map.html`) | `CHANGELOG.txt` in the map repo (`brunotho/lekmap-rosebranch`), loosely written: `#` headings, `-` bullets, tab-indented sub-bullets |
| Installation (`install.html`) | `templates/install.html.erb` (written by hand) |
| Civ list (`civs.html`) | the mod's `LEKMOD/Override/CIV5Units.xml` and `CIV5Units_Mongol.xml`, read directly |
| Known issues (`bugs.html`) | `data/known_issues.txt` (same loose format as the map changelog) |

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
- Developer lines (`Note`, `DLL`, `Dev`) and items with only such lines are never shown.

## Publishing

`.github/workflows/website.yml` builds and publishes the site when a GitHub Release is published, or by hand (Actions > Website > Run workflow). One-time setup: repo Settings > Pages > Source = "GitHub Actions". Releases themselves: `python tools/release.py check|prepare|package <version>`.
