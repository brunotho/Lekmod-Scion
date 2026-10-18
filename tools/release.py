"""Prepare and package a Lekmod Scion release (mod and map).

usage:
  python tools/release.py check   1.0.0    checks only: version numbers, changelog, map logs, clean trees
  python tools/release.py prepare 1.0.0    renames "## UNRELEASED (...)" to "## 1.0.0 (<date>)" in changelog.txt,
                                           opens a new empty UNRELEASED block, sets the release date in
                                           scion_versions.json. Review the diff and commit it yourself.
  python tools/release.py package 1.0.0    writes dist/Lekmod Scion 1.0.0.zip and dist/Lekmap Scion 1.0.0.zip
                                           from the committed state (git archive) and prints the gh commands
                                           that publish both releases. Nothing is pushed or published here.

Options: --map DIR (map repo, default: the game's Assets/Maps/lekmap-main), --date YYYY-MM-DD (default: today).
"""
import argparse, datetime, json, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_MAP = r"C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V\Assets\Maps\lekmap-main"
CHANGELOG = os.path.join(REPO, "changelog.txt")
VERSIONS_JSON = os.path.join(REPO, "LekmodInstaller", "github_setup", "scion_versions.json")
# Copies downloaded while the mod was called Rosebranch (2026-10-18) check this file; keep it equal to VERSIONS_JSON.
LEGACY_VERSIONS_JSON = os.path.join(REPO, "LekmodInstaller", "github_setup", "rosebranch_versions.json")
VERSION_LUA = os.path.join(REPO, "LEKMOD", "Lua", "Utilities", "Lekmod_version.lua")
TEXTS = os.path.join(REPO, "LEKMOD", "Override", "CIV5Units_Mongol.xml")
MAP_LEAF = "LekmapScion_FractalPangaea.lua"
# Developer files in the map repo that players don't need.
MAP_EXCLUDE = ["CLAUDE_HANDOFF.md", "Changelog_v*", "LEKMAP-*.txt", "SCRATCHPAD-*", "scripts", ".DS_Store"]
# Files that are always modified locally (ui_check.bat sets a flag in it, see CLAUDE.md).
ALLOWED_DIRTY = {"LEKMOD/Lua/UI/FrontEnd.lua"}


def git(args, cwd=REPO):
    return subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True, encoding="utf-8").stdout


def read(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-8")


def write_like(path, text):
    """Writes text with the line endings the file had."""
    crlf = b"\r\n" in open(path, "rb").read()
    data = text.replace("\r\n", "\n")
    if crlf:
        data = data.replace("\n", "\r\n")
    with open(path, "wb") as f:
        f.write(data.encode("utf-8"))


def check(version, map_dir):
    problems = []
    lua = read(VERSION_LUA)
    m = re.search(r'LOCAL_VERSION\s*=\s*"v?([0-9.]+)"', lua)
    if not m or m.group(1) != version:
        problems.append("Lekmod_version.lua LOCAL_VERSION is %s, not v%s" % (m.group(1) if m else "?", version))
    titles = set(re.findall(r"SCION v([0-9.]+)", read(TEXTS)))
    if titles != {version}:
        problems.append("menu/lobby texts name version(s) %s, not v%s" % (", ".join(sorted(titles)) or "none", version))
    versions = json.loads(read(VERSIONS_JSON))
    if "v" + version not in versions:
        problems.append("scion_versions.json has no entry v%s" % version)
    if read(LEGACY_VERSIONS_JSON) != read(VERSIONS_JSON):
        problems.append("rosebranch_versions.json differs from scion_versions.json (copy it over)")
    log = read(CHANGELOG)
    if not re.search(r"^## (UNRELEASED|%s)\b" % re.escape(version), log, re.M):
        problems.append("changelog.txt has neither an UNRELEASED block nor ## %s" % version)
    dirty = [l[3:] for l in git(["status", "--porcelain"]).splitlines() if l[3:] not in ALLOWED_DIRTY]
    if dirty:
        problems.append("mod repo has uncommitted changes: %s" % ", ".join(dirty[:8]))
    if not os.path.isdir(map_dir):
        problems.append("map repo not found: %s" % map_dir)
    else:
        leaf = read(os.path.join(map_dir, MAP_LEAF))
        if re.search(r"^_lek_mapgen_logs\s*=\s*true", leaf, re.M):
            problems.append("map: _lek_mapgen_logs = true in %s (switch logs off for a release)" % MAP_LEAF)
        if version not in read(os.path.join(map_dir, "VERSION")):
            problems.append("map VERSION is not %s" % version)
        if git(["status", "--porcelain"], cwd=map_dir).strip():
            problems.append("map repo has uncommitted changes")
    return problems


def prepare(version, date):
    log = read(CHANGELOG)
    m = re.search(r"^## UNRELEASED.*$", log, re.M)
    if not m:
        sys.exit("changelog.txt: no '## UNRELEASED' block")
    head = "## UNRELEASED (next version)\n\n\n## %s (%s)" % (version, date)
    write_like(CHANGELOG, log[:m.start()] + head + log[m.end():])
    versions = json.loads(read(VERSIONS_JSON))
    entry = versions.setdefault("v" + version, {"changelog": "Lekmod Scion " + version})
    entry["release_date"] = date
    write_like(VERSIONS_JSON, json.dumps(versions, indent=2) + "\n")
    write_like(LEGACY_VERSIONS_JSON, json.dumps(versions, indent=2) + "\n")
    print("changelog.txt and scion_versions.json updated; review with git diff, then commit.")


def package(version, map_dir):
    dist = os.path.join(REPO, "dist")
    os.makedirs(dist, exist_ok=True)
    mod_name = "Lekmod Scion %s" % version
    map_name = "Lekmap Scion %s" % version
    mod_zip = os.path.join(dist, mod_name + ".zip")
    map_zip = os.path.join(dist, map_name + ".zip")
    subprocess.run(["git", "archive", "--format=zip", "--prefix=%s/" % mod_name, "-o", mod_zip, "HEAD:LEKMOD"],
                   cwd=REPO, check=True)
    excludes = [":(exclude)%s" % p for p in MAP_EXCLUDE]
    subprocess.run(["git", "archive", "--format=zip", "--prefix=%s/" % map_name, "-o", map_zip, "HEAD", "--", "."]
                   + excludes, cwd=map_dir, check=True)
    for z in (mod_zip, map_zip):
        print("%s  %.1f MB" % (z, os.path.getsize(z) / 1e6))
    mod_sha = git(["rev-parse", "HEAD"]).strip()
    map_sha = git(["rev-parse", "HEAD"], cwd=map_dir).strip()
    print("\nTo publish (check the zips first; both commits must be pushed; this makes them public):")
    print('  gh release create v%s "%s" -R brunotho/Lekmod-Scion --target %s --title "%s" --notes "See the website changelog."'
          % (version, mod_zip, mod_sha, mod_name))
    print('  gh release create v%s "%s" -R brunotho/lekmap-scion --target %s --title "%s" --notes "See CHANGELOG.txt."'
          % (version, map_zip, map_sha, map_name))
    print("The Website workflow then rebuilds the site with this release.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("step", choices=["check", "prepare", "package"])
    ap.add_argument("version", help="e.g. 1.0.0")
    ap.add_argument("--map", default=DEFAULT_MAP)
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    a = ap.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", a.version):
        sys.exit("version must look like 1.0.0")
    if a.step == "prepare":
        prepare(a.version, a.date)
        return
    problems = check(a.version, a.map)
    for p in problems:
        print("- " + p)
    if a.step == "check":
        print("ok" if not problems else "%d problem(s)" % len(problems))
        sys.exit(1 if problems else 0)
    if problems:
        sys.exit("fix the problems above before packaging")
    package(a.version, a.map)


if __name__ == "__main__":
    main()
