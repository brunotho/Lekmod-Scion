"""Prepare and package a Lekmod Scion release (the map ships inside the mod since 2026-11-27).

usage:
  python tools/release.py check   1.0.0    checks only: version numbers, changelog, map logs, clean tree
  python tools/release.py prepare 1.0.0    renames "## UNRELEASED (...)" to "## 1.0.0 (<date>)" in changelog.txt,
                                           opens a new empty UNRELEASED block, sets the release date in
                                           scion_versions.json, freezes the in-game texts of New/Reworked lines
                                           (website/freeze_refs.rb). Review the diff and commit it yourself.
  python tools/release.py package 1.0.0    writes dist/Lekmod Scion 1.0.0.zip from the committed state (git archive,
                                           with Lekmap Scion in its Maps folder) and prints the gh command that
                                           publishes it. Nothing is pushed or published here.

Options: --date YYYY-MM-DD (default: today).
"""
import argparse, datetime, json, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG = os.path.join(REPO, "changelog.txt")
VERSIONS_JSON = os.path.join(REPO, "LekmodInstaller", "github_setup", "scion_versions.json")
# Copies downloaded while the mod was called Rosebranch (2026-10-18) check this file; keep it equal to VERSIONS_JSON.
LEGACY_VERSIONS_JSON = os.path.join(REPO, "LekmodInstaller", "github_setup", "rosebranch_versions.json")
VERSION_LUA = os.path.join(REPO, "LEKMOD", "Lua", "Utilities", "Lekmod_version.lua")
TEXTS = os.path.join(REPO, "LEKMOD", "Override", "CIV5Units_Mongol.xml")
# Lekmap Scion: the scripts players get (the DLL copies them into Assets/Maps/Lekmap Scion) and the map changelog.
MAP_LEAF = os.path.join(REPO, "LEKMOD", "Maps", "LekmapScion_FractalPangaea.lua")
MAP_CHANGELOG = os.path.join(REPO, "map", "CHANGELOG.txt")
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


def check(version):
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
    # the in-game Civilopedia home page must match website/data/essentials.txt (user, 2026-10-28)
    if subprocess.run([sys.executable, os.path.join(REPO, "tools", "sync_pedia_essentials.py"), "--check"], capture_output=True).returncode != 0:
        problems.append("Civilopedia essentials differ from website/data/essentials.txt (run python tools/sync_pedia_essentials.py)")
    log = read(CHANGELOG)
    if not re.search(r"^## (UNRELEASED|%s)\b" % re.escape(version), log, re.M):
        problems.append("changelog.txt has neither an UNRELEASED block nor ## %s" % version)
    dirty = [l[3:] for l in git(["status", "--porcelain"]).splitlines() if l[3:] not in ALLOWED_DIRTY]
    if dirty:
        problems.append("mod repo has uncommitted changes: %s" % ", ".join(dirty[:8]))
    leaf = read(MAP_LEAF)
    if re.search(r"^_lek_mapgen_logs\s*=\s*true", leaf, re.M):
        problems.append("map: _lek_mapgen_logs = true in %s (switch logs off for a release)" % os.path.basename(MAP_LEAF))
    if ("Lekmap Scion %s[" % version) not in leaf:
        problems.append("map lobby name in %s is not Lekmap Scion %s" % (os.path.basename(MAP_LEAF), version))
    if not read(MAP_CHANGELOG).startswith("# Lekmap Scion %s " % version):
        problems.append("map/CHANGELOG.txt heading is not Lekmap Scion %s" % version)
    return problems


def prepare(version, date):
    log = read(CHANGELOG)
    m = re.search(r"^## UNRELEASED.*$", log, re.M)
    if not m:
        sys.exit("changelog.txt: no '## UNRELEASED' block")
    head = "## UNRELEASED (next version)\n\n\n## %s (%s)" % (version, date)
    write_like(CHANGELOG, log[:m.start()] + head + log[m.end():])
    # "- New/Reworked: TYPE" lines keep the in-game text this release ships ("  | text"); the release commit only
    # touches changelog.txt and the version files, so HEAD holds the release's game data
    ruby = r"C:\Ruby34-x64\bin\ruby.exe" if os.path.exists(r"C:\Ruby34-x64\bin\ruby.exe") else "ruby"
    subprocess.run([ruby, os.path.join(REPO, "website", "freeze_refs.rb"), version, "HEAD"], cwd=REPO, check=True)
    versions = json.loads(read(VERSIONS_JSON))
    entry = versions.setdefault("v" + version, {"changelog": "Lekmod Scion " + version})
    entry["release_date"] = date
    write_like(VERSIONS_JSON, json.dumps(versions, indent=2) + "\n")
    write_like(LEGACY_VERSIONS_JSON, json.dumps(versions, indent=2) + "\n")
    print("changelog.txt and scion_versions.json updated; review with git diff, then commit.")


def package(version):
    dist = os.path.join(REPO, "dist")
    os.makedirs(dist, exist_ok=True)
    mod_name = "Lekmod Scion %s" % version
    mod_zip = os.path.join(dist, mod_name + ".zip")
    subprocess.run(["git", "archive", "--format=zip", "--prefix=%s/" % mod_name, "-o", mod_zip, "HEAD:LEKMOD"],
                   cwd=REPO, check=True)
    print("%s  %.1f MB" % (mod_zip, os.path.getsize(mod_zip) / 1e6))
    mod_sha = git(["rev-parse", "HEAD"]).strip()
    print("\nTo publish (check the zip first; the commit must be pushed; this makes it public):")
    print('  gh release create v%s "%s" -R brunotho/Lekmod-Scion --target %s --title "%s" --notes "See the website changelog."'
          % (version, mod_zip, mod_sha, mod_name))
    print("The Website workflow then rebuilds the site with this release.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("step", choices=["check", "prepare", "package"])
    ap.add_argument("version", help="e.g. 1.0.0")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    a = ap.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", a.version):
        sys.exit("version must look like 1.0.0")
    if a.step == "prepare":
        prepare(a.version, a.date)
        return
    problems = check(a.version)
    for p in problems:
        print("- " + p)
    if a.step == "check":
        print("ok" if not problems else "%d problem(s)" % len(problems))
        sys.exit(1 if problems else 0)
    if problems:
        sys.exit("fix the problems above before packaging")
    package(a.version)


if __name__ == "__main__":
    main()
