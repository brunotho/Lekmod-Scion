# Self-Propelled Artillery: 3D model

Source: `model_ha-to_herdyn_cc-by/` ("Ha-to artillery" by Herdyn, CC-BY 4.0; see CREDITS.txt there).

As downloaded (checked 2026-10-19): OBJ, 7,179 triangles, 33 parts (body, turret, gun, gun_rot = the gun's
elevation pivot, two tracks, 24 wheels, doors, engine, a number decal), 5 textures (hato 512, wheels 512,
tracks 128x32, three number decals 96x192). Long axis X, Y up.

Done 2026-10-19 (in the game, playtested): 3,280 triangles, decals dropped, one baked 256 texture, all on
`tank_bone_body` of the Modern Armor skeleton (gun static), Artillery combat effects. Original plan:
- reduce to about 3,000 triangles (the wheels are ~3,800 of them and mostly hidden behind the tracks)
- drop the number decals; pack the textures into one 256 (or 512) DXT5 `_DIFF` texture plus an `_SREF`
- bind body/tracks/wheels to `tank_bone_main` and gun + gun_rot (+ turret) to `tank_bone_gun` of the
  Modern Armor skeleton, reuse its animations (see the 3D notes in CLAUDE.md / the session of 2026-10-19)
