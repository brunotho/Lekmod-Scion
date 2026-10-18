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

Pipeline that worked (SPA, 2026-10-19; Nexus Buddy steps are clicks in its window):
1. `spa_prepare.py`: source model -> one mesh, ~3,000 triangles, one baked texture.
2. Base unit skeleton: extract `<unit>.gr2` and `unitmodels_stringdatabase.gsd` from `UnitModels.fpk`. Nexus Buddy:
   Additional Actions -> **Load String Database** (the .gsd; without it bone names are empty and Export to NB2
   crashes with a NullReference) -> Open the `.gr2` -> Select Model tab: tick the model -> Export to NB2 (Current Model).
   Blender: `inspect_nb2.py` imports it (bone positions, mesh size/facing) and saves a reference .blend.
3. `spa_build_br2.py`: mesh onto that armature (facing, length, ground level of the base mesh), vertex groups named
   after bones (every mesh needs 2+ bones), Export BR2. **Use `matrix_world * v.co`**: Blender 2.79's OBJ import
   keeps its Y-up turn as object rotation (raw `v.co` made the first SPA lie on its side).
4. Nexus Buddy: Open the `.gr2` -> tick the model -> "Use Unit Template" -> Overwrite Meshes From BR2 (Current Model)
   (saves into the open file). The NB2 export after that crashes (index out of range); ignore it.
5. Nexus Buddy Edit Model tab: the new mesh has **no material** (invisible in game, white in the viewer): set its
   material column to the base material (`Game_ModernArmor`) and that material's BaseTextureMap / SREFMap to our
   `.dds` names (typing the file name works) -> Save. Later mesh overwrites of the same file only need the material
   column again.
6. Mod: `.gr2` + `.fxsxml` (the base unit's, Mesh and textures renamed) + `.dds` anywhere under `LEKMOD/Art`;
   ArtDefine_UnitInfos / UnitInfoMemberInfos / UnitMemberInfos (Model = the .fxsxml name) / UnitMemberCombats /
   UnitMemberCombatWeapons / StrategicView rows at the end of CIV5Units.xml; the unit's UnitArtInfo.
   Diagnosis trick: point the .fxsxml at the base mesh (e.g. ModernArmor.gr2): if that shows, only our .gr2 is wrong.
Textures: 256 DXT5 `_DIFF` (alpha 255 = no player colour) and `_SREF` (darkened colours, alpha ~30), `texconv -f BC3_UNORM -m 0`.
