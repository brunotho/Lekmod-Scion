------------------------------------------------------------------------------
-- 3_PangaeaIslands.lua — load placers + policies + island engine.
-- Draft/place loop lives in Lekmap_IslandEngine.lua (GeneratePangaeaIslands).
-- Coastal bonus islands and inland-sea spray are NOT here.
------------------------------------------------------------------------------
if LekMapgenPrint then
	LekMapgenPrint("### PangaeaIslands: loading ###");
elseif _lek_mapgen_logs == true then
	print("### PangaeaIslands: loading ###");
end

include("X_IslandHelpers");
include("XX_island_common_Dot");
include("XX_island_common_Pebble");
include("XX_island_common_Strip");
include("XX_island_common_SplinteredCliffsTiny");
-- include("XX_island_uncommon_WaterRift");
include("XX_island_uncommon_Chunk");
include("XX_island_uncommon_Lollipop");
include("XX_island_uncommon_Barbell");
include("XX_island_uncommon_Wishbone");
include("XX_island_uncommon_Snake");
include("XX_island_uncommon_SplinteredMountains");
include("XX_island_uncommon_SplinteredCliffs");
include("XX_island_uncommon_TwinBay");
include("XX_island_uncommon_MountainWall");
include("XX_island_uncommon_DrownedRidge");
include("XX_island_uncommon_LakeRidge");
include("XX_island_uncommon_ClusterOfTiny");
include("XX_island_uncommon_AtollRing");
include("XX_island_rare_PolarMerge");
-- include("XX_island_rare_PangaeaBow");
include("XX_island_rare_Horn");
include("XX_island_rare_ShatteredRing");
include("XX_island_rare_SteppingStone");
include("XX_island_rare_JunglePeak");
include("XX_island_rare_SinaiIsland");
include("XX_island_rare_Crescent");
include("XX_island_rare_ShoreSineChain");
include("XX_island_rare_SolomonsMinesIsland");
include("XX_island_rare_VolcanicRing");
include("XX_island_rare_GeothermalIsland");
include("XX_island_rare_WrapSoftLandbridge");
include("XX_island_rare_HotspotTrail");
-- include("XX_island_rare_FjordPeninsula");
-- include("XX_island_rare_BrokenHeart");
-- include("XX_island_rare_EdgeOfWorld");
-- include("XX_island_rare_EllipseArchipelago");
-- include("XX_island_rare_RiverDelta");

include("Lekmap_IslandCatalog");
include("Lekmap_Islands_FractalPangaea");
include("Lekmap_Islands_EquatorRing");
include("Lekmap_IslandEngine");
