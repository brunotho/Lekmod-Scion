------------------------------------------------------------------------------
-- LekmapPangaeaFractal.lua — lobby leaf: Fractal Pangaea (classic supercontinent)
------------------------------------------------------------------------------
-- LOG MASTER SWITCH: false for release (nothing is written), true while testing.
-- Flow log + all channels below follow it; channels only pick topics when it is true.
_lek_mapgen_logs = false;
_lek_pipeline_flow_log = _lek_mapgen_logs;
-- Use 3 when testing islands on Small (LekIslandProbe budget lines need it).
_lek_mapgen_log_verbosity = 1;
_lek_mapgen_log_channels = {
	islands = false,
	islands_tiles = false,
	-- ### LekIslandMap: island type per tile, per map -> Logs/LekmapIslandMap.log.
	islandmap = true,
	strategics = false,
	starts = false,
	mapgen = false,
	pangaea = false,
	bench = false,
	-- ### LekLandStats (+ LekInlandSea* on Fractal Pangaea) -> Logs/LekmapLandStats.log (+ flow log).
	landstats = true,
	other = false,
};

include("Lekmap_PipelineFlowLog");
_lek_pangaea_land_shape = "fractal_pangaea";
LekPipelineFlowReset("leaf_FractalPangaea");
LekPipelineFlow("leaf_after_shape_set");

LekPipelineFlow("leaf_before_pipeline_include");
include("Lekmap_PangaeaPipeline");
LekPipelineFlow("leaf_after_pipeline_include");

-- Starting Locations menu removed: always Geometric Balance (legacy index 13 = 2).
-- Legacy placement code stays (Equator Ring uses it; Geometric Balance falls back to it).
-- UI slot 1 = Coastal Spawns only (legacy index 17).
_lek_map_visible_ui_order = { 17 };
_lek_map_visible_option_defaults = { [17] = 1 };
_lek_map_hidden_option_defaults[13] = 2;

function GetMapScriptInfo()
	LekPipelineFlow("GetMapScriptInfo_call");
	local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
	return {
		Name = "[COLOR_HIGHLIGHT_TEXT]Lekmap Scion 0.1.10[ENDCOLOR]",
		Description = "Lekmap pangaea — fractal supercontinent with tectonic islands.",
		IsAdvancedMap = false,
		IconIndex = 0,
		SortIndex = 2,
		SupportsMultiplayer = true,
		CustomOptions = {
			{
				Name = "[COLOR_HIGHLIGHT_TEXT]Coastal Spawns[ENDCOLOR]",
				Values = {
					"[COLOR_HIGHLIGHT_TEXT]Coastal Civs Only[ENDCOLOR]",
					"[COLOR_HIGHLIGHT_TEXT]Force 2 Coastals[ENDCOLOR]",
					"[COLOR_HIGHLIGHT_TEXT]All Inland[ENDCOLOR]",
					"[COLOR_HIGHLIGHT_TEXT]Pure Random[ENDCOLOR]",
				},
				DefaultValue = 1,
				SortPriority = -98,
			},
		},
	};
end
