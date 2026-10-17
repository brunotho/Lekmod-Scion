# Developer helpers (not shipped)

Scripts used for the Phase 6 civ batches (2026-10-13/14). Paths inside are absolute to this repo and the game's cache.
Run them from this folder (`python tools/dev/q.py ...` also works for the standalone ones).

| Script | What |
|---|---|
| `cpp_edit.py` | `edit(file, anchor, text, mode='after'/'before'/'replace', count=1)`: byte-safe C++ edits (keeps CRLF and non-UTF-8 bytes; the anchor must match exactly `count` times, written with `\n`). `balance(files)`: checks `#if`/`#endif` counts. **Not transactional**: a failing anchor stops the script after earlier edits were written, so start from a clean tree and check `git diff`. Never run while a build is compiling (locked files). |
| `ifstack.py` | `python ifstack.py "CvCity.cpp:pattern" ...`: prints the `#if` stack of every matching line and whether each condition is LIVE or DEAD (from `_Defines.h`). Run after every C++ batch. Ignores `#define`s inside comments (`AUI_CONSTIFY`, `AUI_WARNING_FIXES`, `NQM_PRUNING` are OFF). |
| `deadcode.py [pattern...]` | Every line with `Lekmod`/`LEKMOD_`/`LTI_` (or the given patterns) that sits in a compiled-out branch, and the branch that kills it. Run after every C++ batch; most hits are old upstream duplicates with a live twin. |
| `helpers.py` | Data-script helpers for `CIV5Units.xml`: `P` (the file), `rows(table, *dicts, delete=)`, `upd(table, where, sets)`, `unit(...)`, `res(unit, (res, n)...)`, `promos(unit, add, remove)`, `upgrade(unit, cls)`, `atlas(name, file)` (7-size icon atlas), `dummy(...)` (hidden dummy building + class), `LAND` (land combat classes). |
| `xmlcheck.py` | Parses both Override files: repeated columns inside one `<Row>` (that drops the whole file in game) and duplicate text tags. |
| `refcheck.py` | Every `TYPE_NAME` added in the uncommitted `CIV5Units.xml` diff exists in the loaded DB or is defined in the diff. |
| `civdump.py CIVILIZATION_X` | A civ's trait, unique units/buildings/improvements and all their sub-table rows from the loaded DB. |
| `q.py "select ..."` | SQL against the loaded DB (`Civ5DebugDatabase.db`, written when a game starts; it can be older than the files). |
| `txt.py TAG [TAG%]` | Text lookup in `Localization-Merged.db` (also stale until a game starts; the newest `<Replace>` in `CIV5Units_Mongol.xml` wins). |
| `sqlcheck.py` | Prepares every SQL query of the DLL against the schema of `CIV5Units.xml` (plus the cache for other tables). Run after any C++ query change: an invalid live query (e.g. an ambiguous column after a new JOIN) crashes the game before the main menu. The 4 known failures are compiled out. |
| `dbcheck.py <commit>...` | After a game start: checks that every `<Row>`/`<Update>` a commit added to `CIV5Units.xml` is in the loaded DB (Civ5DebugDatabase.db). Mismatches are either data that never loaded or rows changed by a later commit (check with `git log -S`). |
| `civtexts.py [ua\|ub\|uu\|ui\|all] [CIV...]` | Every civ's effective UA/UU/UB/UI texts, read from the Override files (no game DB needed). |
| `xmlrefs.py <TYPE>` | All rows in `CIV5Units.xml` that mention a type name, with their table and line. |
| `ubdiff.py [filter...]` | Each unique building against the building it replaces, from the loaded DB: differing columns, sub-table rows only one of them has, both Help texts. |
| `ub_texts_2026_10_17.py` | The UB tooltip texts of the 2026-10-17 audit ("Like the X:" / "In addition:"); rerunnable, sets every definition of each Help tag. Edit a text there and rerun, or edit the text file directly and stop using the script. |
| `examples/` | The batch H scripts as a pattern: C++ edits, data + texts appended at the end of the Override files, changelog edits inside a civ's section. |

Batch routine: C++ script → `balance` + `ifstack` + `sqlcheck` → build in the background (CLAUDE.md §5) → data script → `xmlcheck` + `refcheck` → changelog → check Civ V is closed → back up and install the DLL → commit code/data, then the DLL separately → next game start: `dbcheck <commit>` → tracker rows, "Specs to refine" defaults, "Civ tests (Phase 6)" items → CLAUDE.md.
