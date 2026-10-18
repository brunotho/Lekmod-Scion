# 3D unit models (set up 2026-10-19)

Tools live outside the repo in `C:\Users\bbruno\civ-tools\3d\`:
- `blender-2.79b-windows64\` portable Blender 2.79b (blender.org, MD5 checked) with Deliverator's add-ons
  `io_export_br2.py` / `io_import_nb2.py` (from github.com/deliverator23/Civilization-Blender-Scripts, Blender-2.7-Addons)
- `dl_nb2\repo\Nexus-Buddy-2\` Nexus Buddy 2 (github.com/deliverator23/Nexus-Buddy-2_Release), 32-bit .NET; needs
  `HKCU\Software\Firaxis\Tools\ToolAssetPath` = `C:\Users\bbruno\civ-tools\3d\nb2_dummy` (set 2026-10-19)
- base unit files: `python tools/fpk_extract.py "<Civ V>/Resource/Common/UnitModels.fpk" <out> <prefix>`

Scripts here:
- `objstats.py <obj>`: triangles, parts (with size/centre), materials of an OBJ
- `objrender.py <obj> <texdir> <out.png>`: quick flat-shaded preview sheet (three-quarter, front, top, game size)
- `spa_prepare.py` (Blender: `blender.exe -b --python spa_prepare.py -- <obj> <outdir>`): drops decals, vertex groups
  MAIN/GUN, decimates, joins, bakes all textures into one 512 texture on a new UV layout, exports OBJ + .blend
- `nb2cli.cs`: command-line front end for Nexus Buddy 2 (export NB2 / overwrite meshes from BR2 / save). Not built:
  compiling and running it was blocked by the session's safety check on 2026-10-19; the same two steps can be
  done in Nexus Buddy's window.

Pipeline: source model -> `spa_prepare.py` -> base unit skeleton (Nexus Buddy: open the base `.gr2`, Export to NB2;
Blender: import NB2) -> parent the mesh to that armature, vertex groups named after its bones -> Export BR2 ->
Nexus Buddy: open the base `.gr2`, Overwrite Meshes from BR2, Save As -> `.fxsxml` + textures + ArtDefine rows.
