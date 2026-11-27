------------------------------------------------------------------------------
--	FILE:	 Lekmap_PangaeaPipeline.lua
--	PURPOSE: Shared Lekmap pangaea pipeline (includes, plot types, terrain, starts).
--	         Lobby leaves set _lek_pangaea_land_shape then include this file.
------------------------------------------------------------------------------
--	Copyright (c) 2011 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

-- Leaf may set these before include; defaults for soft deploy / local tuning.
if _lek_mapgen_log_verbosity == nil then _lek_mapgen_log_verbosity = 1; end
if _lek_mapgen_logs == nil then _lek_mapgen_logs = false; end
if _lek_mapgen_log_channels == nil then
	_lek_mapgen_log_channels = {
		islands = true,
		islands_tiles = true,
		strategics = false,
		starts = false,
		mapgen = false,
		pangaea = false,
		bench = false,
		landstats = false,
		other = false,
	};
end
if _lek_pangaea_land_shape == nil then _lek_pangaea_land_shape = "fractal_pangaea"; end
if _lek_mapgen_world_is_small == nil then _lek_mapgen_world_is_small = false; end

-- Pipeline flow log (always on; dedicated LekmapPipelineFlow.log)
if not LekPipelineFlow then
	include("Lekmap_PipelineFlowLog");
end
if LekPipelineFlow then
	LekPipelineFlow("pipeline_file_body_start");
end


-- TEST ONLY: not used in normal maps. When true, PlaceResources ends with LekTestCopperOnAllWater (ocean/lake copper); engine may skip tiles.
_lek_test_copper_on_all_water = false;

-- RS5: after OG balance majors, place small iron+horse in r4-5 and r6-7 (iron flat-only; horse OG flat primary).
_lek_strat_extra_balance_smalls = true;
-- RS5: when true, skip biome ProcessResourceList / PlaceSmallQuantities / backfill for horse+iron.
-- Split from extras. false = globals on; volume via rs5_* freqs only (no post trim).
_lek_strat_skip_global_horse_iron = false;
-- RS5 oil/uranium balance recipe (in AddStrategicBalanceResources): band guarantees instead of OG 2×oil + 2×uran.
-- Oil: major r1-3, major/minor r4-5, major/minor r6-7. Uran: 50/50 major/minor r3-5 + qty1 r6-8.
-- Land oil globals off (majors + small_strat); CS minor oil kept. Uran majors/backfill spaced.
_lek_strat_ou_bands = true;
-- Per-tile horse/iron/oil/uran placement lines (`### LEK_STRAT_HIT`). On with strat testing.
_lek_strat_audit_log_each_hit = false;

-- Fish: place mainland fish per coast ring (shore ring densest) instead of one even draw over the 3-ring band.
-- Rates are "1 fish per N tiles" before the resource-setting multiplier (0.65 on default resources).
LEK_FISH_RING_BIAS = true;
-- 2026-10-17 (user: too many fish): the 2026-09-26 ring rates { 3.5, 7, 16 } gave about 64% more fish than the old even
-- draw (1 per 10 tiles over all 3 rings); scaled back to that total, keeping the shore-heavy shape.
LEK_FISH_RING_FREQ = { 5.75, 11.5, 26 }; -- shore ring, second ring, third ring
-- Regional luxuries: max hex distance from the region's capital (placement, fallback and shortfall repair).
LEK_REGIONAL_LUX_MAX_DIST = 6;
-- Capitals keep this hex distance from the central volcano peak (natural wonder spacing).
LEK_CENTRAL_NW_START_CLEAR = 5;

-- Debug: paint region AABB outlines/centers as snow (visual only). Off for normal play.
_lek_debug_paint_region_snow = false;

-- Setup UI shows only two map script rows; code still uses legacy indices 1–19 via LekMapGetCustomOption.
-- Engine Map.GetCustomOption(1..2) are those rows, mapped by _lek_map_visible_ui_order to old 13, 17.
-- Start Quality (legacy index 5) is stubbed in _lek_map_hidden_option_defaults, not shown in Advanced Setup.
-- All other legacy indices return fixed defaults matching the former full menu DefaultValues.
_lek_map_visible_ui_order = { 13, 17 }
-- World Age (UI hidden): 1=3By young/more peaks, 2=4By default, 3=5By old/fewer, 4=no mountains, 5=random 1-3.
_lek_map_hidden_option_defaults = {
	[1] = 2, [2] = 2, [3] = 2, [4] = 2,
	[5] = 2,
	[6] = 2, [7] = 15, [8] = 2, [9] = 2, [10] = 2,
	[11] = 6, [12] = 6, [14] = 5, [15] = 1, [16] = 9,
	[18] = 2, [19] = 2,
}
_lek_map_visible_option_defaults = { [13] = 2, [17] = 1 }

function LekMapGetCustomOption(oldindex)
	for ui_slot = 1, #_lek_map_visible_ui_order do
		if _lek_map_visible_ui_order[ui_slot] == oldindex then
			if Map and Map.GetCustomOption then
				local v = Map.GetCustomOption(ui_slot)
				if type(v) == "number" and v >= 1 then
					return v
				end
			end
			return _lek_map_visible_option_defaults[oldindex]
		end
	end
	local h = _lek_map_hidden_option_defaults[oldindex]
	if h ~= nil then
		return h
	end
	return 1
end

if LekPipelineFlow then LekPipelineFlow("include_begin", "4_HBMapGenerator"); end
include("4_HBMapGenerator");
if LekPipelineFlow then LekPipelineFlow("include_ok", "4_HBMapGenerator"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "2_HBFractalWorld"); end
include("2_HBFractalWorld");
if LekPipelineFlow then LekPipelineFlow("include_ok", "2_HBFractalWorld"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "6_HBFeatureGenerator"); end
include("6_HBFeatureGenerator");
if LekPipelineFlow then LekPipelineFlow("include_ok", "6_HBFeatureGenerator"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "5_HBTerrainGenerator"); end
include("5_HBTerrainGenerator");
if LekPipelineFlow then LekPipelineFlow("include_ok", "5_HBTerrainGenerator"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "IslandMaker"); end
include("IslandMaker");
if LekPipelineFlow then LekPipelineFlow("include_ok", "IslandMaker"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "MultilayeredFractal"); end
include("MultilayeredFractal");
if LekPipelineFlow then LekPipelineFlow("include_ok", "MultilayeredFractal"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "3_PangaeaIslands"); end
include("3_PangaeaIslands");
if LekPipelineFlow then LekPipelineFlow("include_ok", "3_PangaeaIslands"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "X_IslandHelpers"); end
include("X_IslandHelpers");
if LekPipelineFlow then LekPipelineFlow("include_ok", "X_IslandHelpers"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "Lekmap_Landmass_FractalPangaea"); end
include("Lekmap_Landmass_FractalPangaea");
if LekPipelineFlow then LekPipelineFlow("include_ok", "Lekmap_Landmass_FractalPangaea"); end
if LekPipelineFlow then LekPipelineFlow("include_begin", "Lekmap_Landmass_EquatorRing"); end
include("Lekmap_Landmass_EquatorRing");
if LekPipelineFlow then LekPipelineFlow("include_ok", "Lekmap_Landmass_EquatorRing"); end
if LekPipelineFlow then LekPipelineFlow("includes_all_done"); end
if LekMapgenPrint then
	LekMapgenPrint("### Lekmap_PangaeaPipeline: includes done shape=" .. tostring(_lek_pangaea_land_shape) .. " ###");
end

-- Option 13 "Geometric Balance": Legacy = HB only. Global six = one-map tuple: extra relax phases on the current landmask,
-- no HB layout regen from tuple/placement/lux gates (see _lek_global_six_one_map_placement_mode); fractal+Pangaea outer redraw unchanged.
-- For this mapscript's one-map focus, keep HB layout loop at one layout.
_lek_global_six_regen_max_layouts = 1;
_lek_fjord_distance_setting_fixed = 1;
_lek_fjord_length_setting_fixed = 1;
-- Pangaea inner loop: redraw fractal+Pangaea until land/islands pass (per single GeneratePlotTypes call). Tuple regen does NOT bump this counter.
_lek_pangaea_max_outer_failed = false;
-- Regen loop: GenerateMap() may re-run LekHB_GenerateMap_Core when code still requests layout regen (e.g. some non-Pangaea maps).
-- Pangaea global-six enables one-map mode so tuple/search does not burn layouts for tuple-fail or post-placement gates; outer fractal failure still uses regen.
_lek_enable_hb_generatemap_regen_loop = true;
_lek_map_layout_attempt = nil;
_lek_global_six_request_map_regen = false;

-- Flow-log civ census. Does not change game state. iNumCivs for regions = same IsEverAlive rule.
function LekPipelineLogCivCensus(tag)
	if not LekPipelineFlow then return; end
	local nEver, ids = 0, {};
	local slotBits = {};
	if GameDefines and Players then
		local maxM = GameDefines.MAX_MAJOR_CIVS or 22;
		local dumpN = math.min(maxM, 8);
		for i = 0, maxM - 1 do
			local pl = Players[i];
			local ever = pl and pl.IsEverAlive and pl:IsEverAlive();
			if ever then
				nEver = nEver + 1;
				ids[#ids + 1] = tostring(i);
			end
			if i < dumpN then
				local hum = (pl and pl.IsHuman and pl:IsHuman()) and "H" or "-";
				local ev = ever and "E" or "-";
				local alive = (pl and pl.IsAlive and pl:IsAlive()) and "A" or "-";
				slotBits[#slotBits + 1] = tostring(i) .. ":" .. hum .. ev .. alive;
			end
		end
	end
	LekPipelineFlow(tag or "civ_census",
		"everAliveMajors=" .. tostring(nEver)
		.. " ids=" .. table.concat(ids, ",")
		.. " slots=[" .. table.concat(slotBits, " ") .. "]");
end

------------------------------------------------------------------------------
function GetMapInitData(worldSize)

		if LekPipelineFlow then LekPipelineFlow("GetMapInitData_entry"); end
	-- Early census: if this already shows 2, nothing later in our pipeline "turned 6 into 2".
	LekPipelineLogCivCensus("GetMapInitData_civ_census");
	_lek_mapgen_world_is_small = false;

	local LandSizeXDuel = 22 + (LekMapGetCustomOption(11) * 2);
	local LandSizeYDuel = 18 + (LekMapGetCustomOption(12) * 2);

	local LandSizeXTiny = 36 + (LekMapGetCustomOption(11) * 2);
	local LandSizeYTiny = 30 + (LekMapGetCustomOption(12) * 2);

	local LandSizeXSmall = 32 + (LekMapGetCustomOption(11) * 2);
	local LandSizeYSmall = 40 + (LekMapGetCustomOption(12) * 2);

	local LandSizeXStandard = 54 + (LekMapGetCustomOption(11) * 2);
	local LandSizeYStandard = 48 + (LekMapGetCustomOption(12) * 2);

	local LandSizeXLarge = 62 + (LekMapGetCustomOption(11) * 2);
	local LandSizeYLarge = 54 + (LekMapGetCustomOption(12) * 2);

	local LandSizeXHuge = 70 + (LekMapGetCustomOption(11) * 2);
	local LandSizeYHuge = 62 + (LekMapGetCustomOption(12) * 2);

	local worldsizes = {};

	worldsizes = {

		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {LandSizeXDuel, LandSizeYDuel}, -- 1020
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {LandSizeXTiny, LandSizeYTiny}, -- 2016
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {LandSizeXSmall, LandSizeYSmall}, -- 3016
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {LandSizeXStandard, LandSizeYStandard}, -- 3960
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {LandSizeXLarge, LandSizeYLarge}, -- 5032
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {LandSizeXHuge, LandSizeYHuge} -- 6068
		}
		
	local grid_size = worldsizes[worldSize];
	--
	local world = GameInfo.Worlds[worldSize];
	_lek_mapgen_world_is_small = (world ~= nil and worldSize == GameInfo.Worlds.WORLDSIZE_SMALL.ID);
	if (world ~= nil) then
		local width = grid_size[1];
		local height = grid_size[2];
		-- Equator Ring: narrower canvas (no EW water gap); Compact keeps the classic sizes.
		if LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing() then
			width = math.max(16, width - 6);
		end
		if LekPipelineFlow then
			LekPipelineFlow("GetMapInitData_size",
				"shape=" .. tostring(_lek_pangaea_land_shape or "?")
				.. " W=" .. tostring(width) .. " H=" .. tostring(height));
		end
		return {
			Width = width,
			Height = height,
			WrapX = true,
		}; 
	end

end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- START OF FRACTAL PANGAEA CREATION CODE
------------------------------------------------------------------------------
PangaeaFractalWorld = {};
------------------------------------------------------------------------------
function PangaeaFractalWorld.Create(fracXExp, fracYExp)
	local gridWidth, gridHeight = Map.GetGridSize();
	
	local data = {
		InitFractal = FractalWorld.InitFractal,
		ShiftPlotTypes = FractalWorld.ShiftPlotTypes,
		ShiftPlotTypesBy = FractalWorld.ShiftPlotTypesBy,
		DetermineXShift = FractalWorld.DetermineXShift,
		DetermineYShift = FractalWorld.DetermineYShift,
		GenerateCenterRift = FractalWorld.GenerateCenterRift,
		GeneratePlotTypes = PangaeaFractalWorld.GeneratePlotTypes,	-- Custom method
		
		iFlags = Map.GetFractalFlags(),
		
		fracXExp = fracXExp,
		fracYExp = fracYExp,
		
		iNumPlotsX = gridWidth,
		iNumPlotsY = gridHeight,
		plotTypes = table.fill(PlotTypes.PLOT_OCEAN, gridWidth * gridHeight)
	};
		
	return data;
end

------------------------------------------------------------------------------
-- Before PangaeaIslands: demote mountains with at least one OCEAN neighbor (main + inland-sea mask).
-- pctRoll: 0-100, fraction to demote (100 = all). Returns count demoted.
------------------------------------------------------------------------------
function LekDemoteMountainsTouchingOcean(plotTypes, iW, iH, wrapX, wrapY, pctRoll)
	if not GetHexNeighbor or not plotTypes or type(pctRoll) ~= "number" then
		return 0;
	end
	if pctRoll <= 0 then
		return 0;
	end
	local n = 0;
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local idx = y * iW + x + 1;
			if plotTypes[idx] == PlotTypes.PLOT_MOUNTAIN then
				local touches = false;
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY or false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						if plotTypes[ny * iW + nx + 1] == PlotTypes.PLOT_OCEAN then
							touches = true;
							break;
						end
					end
				end
				if touches and Map.Rand(100, "lek_demote_coast_mtn") < pctRoll then
					plotTypes[idx] = PlotTypes.PLOT_HILLS;
					n = n + 1;
				end
			end
		end
	end
	return n;
end

------------------------------------------------------------------------------
-- After majors are placed: demote only mountains that touch ocean, are PlotDistance 4 from a coastal
-- major start, and are still mountains on the live map. Replaces broad LekDemoteMountainsTouchingOcean(100).
------------------------------------------------------------------------------
function LekDemoteRing4CoastalMountainsNearCoastalMajors(start_plot_database)
	if not start_plot_database or not GetHexNeighbor then
		return 0;
	end
	local iW, iH = Map.GetGridSize();
	if not iW or not iH then
		return 0;
	end
	local wrapX = Map.IsWrapX and Map:IsWrapX() or false;
	local wrapY = Map.IsWrapY and Map:IsWrapY() or false;
	local function pd(x1, y1, x2, y2)
		if Map.PlotDistance then
			return Map.PlotDistance(x1, y1, x2, y2);
		end
		if PlotDistance then
			return PlotDistance(x1, y1, x2, y2);
		end
		return nil;
	end
	local starts = {};
	for loop = 1, start_plot_database.iNumCivs or 0 do
		local pid = start_plot_database.player_ID_list[loop];
		local pl = pid and Players[pid];
		if pl and pl:IsEverAlive() and not pl:IsMinorCiv() then
			local sp = pl:GetStartingPlot();
			if sp and sp:IsCoastalLand() then
				starts[#starts + 1] = { sp:GetX(), sp:GetY() };
			end
		end
	end
	if #starts == 0 then
		return 0;
	end
	local n = 0;
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local plot = Map.GetPlot(x, y);
			if plot and plot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
				local touchesOcean = false;
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local np = Map.GetPlot(nx, ny);
						if np and np:GetPlotType() == PlotTypes.PLOT_OCEAN then
							touchesOcean = true;
							break;
						end
					end
				end
				if touchesOcean then
					for si = 1, #starts do
						local st = starts[si];
						if pd(x, y, st[1], st[2]) == 4 then
							plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
							n = n + 1;
							break;
						end
					end
				end
			end
		end
	end
	return n;
end

------------------------------------------------------------------------------
-- After majors are placed: coastal starts only —
--   ring 1: at most 1 mountain
--   within r4 (PlotDistance 1..4): at most 4 mountains
-- Excess demoted to hills (random). r4 applied first, then r1.
------------------------------------------------------------------------------
function LekCapRing1MountainsNearCoastalMajors(start_plot_database)
	if not start_plot_database or not GetHexNeighbor then
		return 0, 0;
	end
	local iW, iH = Map.GetGridSize();
	if not iW or not iH then
		return 0, 0;
	end
	local wrapX = Map.IsWrapX and Map:IsWrapX() or false;
	local wrapY = Map.IsWrapY and Map:IsWrapY() or false;
	local function pd(x1, y1, x2, y2)
		if Map.PlotDistance then
			return Map.PlotDistance(x1, y1, x2, y2);
		end
		if PlotDistance then
			return PlotDistance(x1, y1, x2, y2);
		end
		return nil;
	end
	local nR1, nR4 = 0, 0;
	for loop = 1, start_plot_database.iNumCivs or 0 do
		local pid = start_plot_database.player_ID_list[loop];
		local pl = pid and Players[pid];
		if pl and pl:IsEverAlive() and not pl:IsMinorCiv() then
			local sp = pl:GetStartingPlot();
			if sp and sp:IsCoastalLand() then
				local sx, sy = sp:GetX(), sp:GetY();
				local mtnsR4 = {};
				for y = 0, iH - 1 do
					for x = 0, iW - 1 do
						local d = pd(x, y, sx, sy);
						if d ~= nil and d >= 1 and d <= 4 then
							local plot = Map.GetPlot(x, y);
							if plot and plot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
								mtnsR4[#mtnsR4 + 1] = plot;
							end
						end
					end
				end
				while #mtnsR4 > 4 do
					local idx = 1 + Map.Rand(#mtnsR4, "lek_cap_r4_mtn");
					mtnsR4[idx]:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
					nR4 = nR4 + 1;
					table.remove(mtnsR4, idx);
				end
				local mtnsR1 = {};
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(sx, sy, d, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local plot = Map.GetPlot(nx, ny);
						if plot and plot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
							mtnsR1[#mtnsR1 + 1] = plot;
						end
					end
				end
				while #mtnsR1 > 1 do
					local idx = 1 + Map.Rand(#mtnsR1, "lek_cap_r1_mtn");
					mtnsR1[idx]:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
					nR1 = nR1 + 1;
					table.remove(mtnsR1, idx);
				end
			end
		end
	end
	return nR1, nR4;
end

------------------------------------------------------------------------------
-- Fractal Pangaea, after ChooseLocations (before BalanceAndAssign normalises starts): for each coastal
-- major start, the half of rings 1 and 2 facing the map center (3 of 6 and 6 of 12 tiles, smallest angle
-- to the start->center line) loses salt water (ocean + inland sea, not lakes) and mountains; they become
-- flat or hills with terrain from the land neighbours. Afterwards the start must still be coastal (next to
-- main-ocean salt water whose water body reaches 300 tiles, as IsCoastalLand(300)); otherwise that start's
-- edits are undone. Returns starts cleared, tiles changed, starts reverted.
------------------------------------------------------------------------------
LEK_COASTAL_CENTER_CLEAR_MIN_SEA = 300;

-- Center-facing half of rings 1 and 2 around (sx, sy): returns targets (3 ring-1 + 6 ring-2 tiles, {x, y})
-- and ring1Rest (the 3 ring-1 tiles facing away). nil when the start is the map center.
function LekCenterFacingRingTiles(sx, sy)
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local cx, cy = math.floor(iW / 2), math.floor(iH / 2);
	local function relVec(fx, fy, tx, ty)
		local dx = (tx + 0.5 * (ty % 2)) - (fx + 0.5 * (fy % 2));
		if wrapX then
			if dx > iW / 2 then dx = dx - iW; elseif dx < -iW / 2 then dx = dx + iW; end
		end
		return dx, (ty - fy) * 0.8660254;
	end
	local vx, vy = relVec(sx, sy, cx, cy);
	local vlen = math.sqrt(vx * vx + vy * vy);
	if vlen == 0 then return nil, nil; end
	local targets, ring1Rest = {}, {};
	for _, ring in ipairs({ { 1, 3 }, { 2, 6 } }) do
		local cand = {};
		for _, tt in ipairs(GetHexRingAtRadius(sx, sy, ring[1], iW, iH, wrapX, false)) do
			local dx, dy = relVec(sx, sy, tt[1], tt[2]);
			cand[#cand + 1] = { tt[1], tt[2], (dx * vx + dy * vy) / (math.sqrt(dx * dx + dy * dy) * vlen) };
		end
		table.sort(cand, function(a, b) return a[3] > b[3]; end);
		for i = 1, #cand do
			if i <= ring[2] then
				targets[#targets + 1] = cand[i];
			elseif ring[1] == 1 then
				ring1Rest[#ring1Rest + 1] = cand[i];
			end
		end
	end
	return targets, ring1Rest;
end

-- Placement gate (Fractal only): a coastal candidate must keep main-ocean salt water on a ring-1 tile the
-- center clear never touches, so LekClearCoastalStartsTowardCenter cannot make it non-coastal.
function LekCoastalCandidateSurvivesCenterClear(x, y)
	if not (LekLandmass_IsFractalPangaea and LekLandmass_IsFractalPangaea()) then return true; end
	local _, rest = LekCenterFacingRingTiles(x, y);
	if rest == nil then return true; end
	for _, tt in ipairs(rest) do
		local p = Map.GetPlot(tt[1], tt[2]);
		if p and p:IsWater() and not p:IsLake() and not (LekIsInlandSeaPlot and LekIsInlandSeaPlot(p)) then
			return true;
		end
	end
	return false;
end

function LekClearCoastalStartsTowardCenter(start_plot_database)
	if not start_plot_database or not GetHexRingAtRadius or not AdjacentToSaltWater then
		return 0, 0, 0;
	end
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local function isPurgeWater(p)
		return p:IsWater() and (not p:IsLake() or (LekIsInlandSeaPlot and LekIsInlandSeaPlot(p)));
	end
	-- Start still coastal: adjacent main-ocean salt water, and that water body has >= MIN_SEA tiles.
	local function stillCoastal(sx, sy)
		if not AdjacentToSaltWater(sx, sy) then return false; end
		local seen, q = {}, {};
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(sx, sy, d, iW, iH, wrapX, false);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local p = Map.GetPlot(nx, ny);
				local k = ny * iW + nx;
				if p and p:IsWater() and not p:IsLake() and not (LekIsInlandSeaPlot and LekIsInlandSeaPlot(p)) and not seen[k] then
					seen[k] = true;
					q[#q + 1] = k;
				end
			end
		end
		local h = 1;
		while h <= #q do
			if #q >= LEK_COASTAL_CENTER_CLEAR_MIN_SEA then return true; end
			local k = q[h];
			h = h + 1;
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), d, iW, iH, wrapX, false);
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
					local nk = ny * iW + nx;
					local p = Map.GetPlot(nx, ny);
					if not seen[nk] and p and p:IsWater() then
						seen[nk] = true;
						q[#q + 1] = nk;
					end
				end
			end
		end
		return #q >= LEK_COASTAL_CENTER_CLEAR_MIN_SEA;
	end

	local nStarts, nTiles, nReverted = 0, 0, 0;
	local parts = {};
	for r = 1, start_plot_database.iNumCivs or 0 do
		local t = start_plot_database.startingPlots and start_plot_database.startingPlots[r];
		local sx, sy = t and t[1], t and t[2];
		if type(sx) == "number" and type(sy) == "number" and AdjacentToSaltWater(sx, sy) then
			local targets = LekCenterFacingRingTiles(sx, sy);
			if targets then
				local undo, changed = {}, {};
				for _, tt in ipairs(targets) do
					local p = Map.GetPlot(tt[1], tt[2]);
					if p and (p:IsMountain() or isPurgeWater(p)) then
						undo[#undo + 1] = { p, p:GetPlotType(), p:GetTerrainType(), p:GetFeatureType(), p:GetResourceType(-1), p:GetNumResource() };
						changed[#changed + 1] = p;
					end
				end
				-- Water/mountain -> flat or hills (hill odds = share of hills+mountains among land neighbours).
				for _, p in ipairs(changed) do
					local nLand, nHigh = 0, 0;
					for d = 0, 5 do
						local np = Map.PlotDirection(p:GetX(), p:GetY(), d);
						if np and not np:IsWater() then
							nLand = nLand + 1;
							if np:IsHills() or np:IsMountain() then nHigh = nHigh + 1; end
						end
					end
					local hills = nLand > 0 and Map.Rand(nLand, "lek_center_clear_hill") < nHigh;
					if p:IsWater() then
						p:SetResourceType(-1);
						p:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
					end
					p:SetPlotType(hills and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND, false, true);
				end
				-- Terrain: majority of land neighbours (ties -> lower id), default grass.
				for _, p in ipairs(changed) do
					local votes, bestT, bestN = {}, TerrainTypes.TERRAIN_GRASS, 0;
					for d = 0, 5 do
						local np = Map.PlotDirection(p:GetX(), p:GetY(), d);
						if np and not np:IsWater() then
							local tt = np:GetTerrainType();
							if tt ~= TerrainTypes.TERRAIN_COAST and tt ~= TerrainTypes.TERRAIN_OCEAN then
								votes[tt] = (votes[tt] or 0) + 1;
								if votes[tt] > bestN or (votes[tt] == bestN and tt < bestT) then
									bestN = votes[tt];
									bestT = tt;
								end
							end
						end
					end
					p:SetTerrainType(bestT, false, true);
				end
				-- Deep ocean next to new land becomes coast.
				for _, p in ipairs(changed) do
					for d = 0, 5 do
						local np = Map.PlotDirection(p:GetX(), p:GetY(), d);
						if np and np:IsWater() and np:GetTerrainType() == TerrainTypes.TERRAIN_OCEAN then
							undo[#undo + 1] = { np, np:GetPlotType(), np:GetTerrainType(), np:GetFeatureType(), np:GetResourceType(-1), np:GetNumResource() };
							np:SetTerrainType(TerrainTypes.TERRAIN_COAST, false, true);
						end
					end
				end
				if #changed > 0 then
					if stillCoastal(sx, sy) then
						nStarts = nStarts + 1;
						nTiles = nTiles + #changed;
						parts[#parts + 1] = sx .. "," .. sy .. ":" .. #changed;
					else
						for i = #undo, 1, -1 do
							local u = undo[i];
							u[1]:SetPlotType(u[2], false, true);
							u[1]:SetTerrainType(u[3], false, true);
							u[1]:SetFeatureType(u[4], -1);
							if u[5] ~= -1 then u[1]:SetResourceType(u[5], u[6]); end
						end
						nReverted = nReverted + 1;
						parts[#parts + 1] = sx .. "," .. sy .. ":reverted";
					end
				end
			end
		end
	end
	LekLandStatsLog("### LekCoastalCenterClear starts=" .. nStarts .. " tiles=" .. nTiles
		.. " reverted=" .. nReverted .. " " .. table.concat(parts, " "));
	return nStarts, nTiles, nReverted;
end

------------------------------------------------------------------------------
-- Break oversized connected mountain blobs (6-neighbor). Demote highest-degree
-- peaks to hills until each component is <= maxCompSize. Returns tiles demoted.
------------------------------------------------------------------------------
function LekBreakLargeMountainComponents(plotTypes, iW, iH, wrapX, wrapY, maxCompSize)
	if not GetHexNeighbor or not plotTypes or type(maxCompSize) ~= "number" or maxCompSize < 1 then
		return 0;
	end
	wrapX = wrapX or false;
	wrapY = wrapY or false;
	local function pidx(x, y) return y * iW + x + 1; end
	local function isMtn(x, y)
		if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
		return plotTypes[pidx(x, y)] == PlotTypes.PLOT_MOUNTAIN;
	end
	local function mtnDegree(x, y)
		local d = 0;
		for dir = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
			if isMtn(nx, ny) then d = d + 1; end
		end
		return d;
	end
	local demoted = 0;
	local guard = 0;
	local maxGuard = iW * iH;
	while guard < maxGuard do
		guard = guard + 1;
		local seen = {};
		local victim = nil;
		local victimDeg = -1;
		local victimTies = {};
		for y = 0, iH - 1 do
			for x = 0, iW - 1 do
				local k0 = y * iW + x;
				if isMtn(x, y) and not seen[k0] then
					local comp = {};
					local queue = {{x, y}};
					seen[k0] = true;
					comp[#comp + 1] = {x, y};
					local q = 1;
					while q <= #queue do
						local cx, cy = queue[q][1], queue[q][2];
						q = q + 1;
						for dir = 1, 6 do
							local nx, ny = GetHexNeighbor(cx, cy, dir, iW, iH, wrapX, wrapY);
							if isMtn(nx, ny) then
								local nk = ny * iW + nx;
								if not seen[nk] then
									seen[nk] = true;
									queue[#queue + 1] = {nx, ny};
									comp[#comp + 1] = {nx, ny};
								end
							end
						end
					end
					if #comp > maxCompSize then
						for i = 1, #comp do
							local deg = mtnDegree(comp[i][1], comp[i][2]);
							local tile = comp[i];
							if deg > victimDeg then
								victimDeg = deg;
								victimTies = {tile};
							elseif deg == victimDeg then
								victimTies[#victimTies + 1] = tile;
							end
						end
					end
				end
			end
		end
		if #victimTies == 0 then
			break;
		end
		victim = victimTies[1 + Map.Rand(#victimTies, "lek_mtn_clump_break")];
		plotTypes[pidx(victim[1], victim[2])] = PlotTypes.PLOT_HILLS;
		demoted = demoted + 1;
	end
	return demoted;
end

------------------------------------------------------------------------------
-- Mountain + inland-water barriers (not open ocean). If a connected hard body
-- (mountains OR inland water) has >= minMtn mountains, keep one mountain and
-- demote the rest to hills. Inland water unchanged. Returns mountains demoted.
------------------------------------------------------------------------------
function LekBreakMountainInlandWaterBarriers(plotTypes, iW, iH, wrapX, wrapY, minMtn)
	if not GetHexNeighbor or not plotTypes then
		return 0;
	end
	minMtn = minMtn or 3;
	wrapX = wrapX or false;
	wrapY = wrapY or false;
	local function pidx(x, y) return y * iW + x + 1; end
	local function isOcean(x, y)
		if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
		return plotTypes[pidx(x, y)] == PlotTypes.PLOT_OCEAN;
	end
	local function isMtn(x, y)
		if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
		return plotTypes[pidx(x, y)] == PlotTypes.PLOT_MOUNTAIN;
	end

	local openOcean = {};
	local queue = {};
	for x = 0, iW - 1 do
		for _, edgeY in ipairs({0, iH - 1}) do
			if isOcean(x, edgeY) then
				local k = edgeY * iW + x;
				if not openOcean[k] then
					openOcean[k] = true;
					queue[#queue + 1] = {x, edgeY};
				end
			end
		end
	end
	local q = 1;
	while q <= #queue do
		local cx, cy = queue[q][1], queue[q][2];
		q = q + 1;
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isOcean(nx, ny) then
				local nk = ny * iW + nx;
				if not openOcean[nk] then
					openOcean[nk] = true;
					queue[#queue + 1] = {nx, ny};
				end
			end
		end
	end

	local function isHard(x, y)
		-- The central volcano's sea and peaks are a deliberate feature, not a barrier.
		if _lek_central_volcano and _lek_central_sea_plots and _lek_central_sea_plots[y * iW + x] then return false; end
		if isMtn(x, y) then return true; end
		if not isOcean(x, y) then return false; end
		return openOcean[y * iW + x] ~= true;
	end

	local demoted = 0;
	local seen = {};
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local k0 = y * iW + x;
			if isHard(x, y) and not seen[k0] then
				local mtns = {};
				local hasInlandWater = false;
				local queue2 = {{x, y}};
				seen[k0] = true;
				local qi = 1;
				while qi <= #queue2 do
					local cx, cy = queue2[qi][1], queue2[qi][2];
					qi = qi + 1;
					if isMtn(cx, cy) then
						mtns[#mtns + 1] = {cx, cy};
					elseif isOcean(cx, cy) and openOcean[cy * iW + cx] ~= true then
						hasInlandWater = true;
					end
					for d = 1, 6 do
						local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
						if isHard(nx, ny) then
							local nk = ny * iW + nx;
							if not seen[nk] then
								seen[nk] = true;
								queue2[#queue2 + 1] = {nx, ny};
							end
						end
					end
				end
				if hasInlandWater and #mtns >= minMtn then
					local keep = 1 + Map.Rand(#mtns, "lek_mtn_inland_keep");
					for i = 1, #mtns do
						if i ~= keep then
							plotTypes[pidx(mtns[i][1], mtns[i][2])] = PlotTypes.PLOT_HILLS;
							demoted = demoted + 1;
						end
					end
				end
			end
		end
	end
	return demoted;
end

------------------------------------------------------------------------------
-- Round thin inland seas (Lua 5.1 compatible: no goto). Inland-sea islands are sprayed during this pass.
------------------------------------------------------------------------------
function RoundInlandSeas(self)
	if not GetHexNeighbor then return; end
	local iW, iH = self.iNumPlotsX, self.iNumPlotsY;
	local wrapX = Map.IsWrapX and Map:IsWrapX() or false;
	local wrapY = Map.IsWrapY and Map:IsWrapY() or false;
	local plotTypes = self.plotTypes;
	local function pidx(x, y) return y * iW + x + 1; end
	local function isOcean(x, y)
		if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
		return plotTypes[pidx(x, y)] == PlotTypes.PLOT_OCEAN;
	end
	local function isLand(x, y)
		if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
		return plotTypes[pidx(x, y)] ~= PlotTypes.PLOT_OCEAN;
	end

	local openOcean = {};
	local queue = {};
	for x = 0, iW - 1 do
		for _, edgeY in ipairs({0, iH - 1}) do
			if isOcean(x, edgeY) then
				local k = edgeY * iW + x;
				if not openOcean[k] then openOcean[k] = true; queue[#queue + 1] = {x, edgeY}; end
			end
		end
	end
	local q = 1;
	while q <= #queue do
		local cx, cy = queue[q][1], queue[q][2];
		q = q + 1;
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isOcean(nx, ny) then
				local nk = ny * iW + nx;
				if not openOcean[nk] then openOcean[nk] = true; queue[#queue + 1] = {nx, ny}; end
			end
		end
	end

	-- Land distance to open ocean (hex steps). Used so inland-sea expansion only nibbles toward pangaea center.
	local distToOpenOcean = {};
	queue = {};
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local k = y * iW + x;
			if openOcean[k] then
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(nx, ny) then
						local nk = ny * iW + nx;
						if distToOpenOcean[nk] == nil then
							distToOpenOcean[nk] = 1;
							queue[#queue + 1] = {nx, ny};
						end
					end
				end
			end
		end
	end
	q = 1;
	while q <= #queue do
		local cx, cy = queue[q][1], queue[q][2];
		q = q + 1;
		local ck = cy * iW + cx;
		local cd = distToOpenOcean[ck];
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(nx, ny) then
				local nk = ny * iW + nx;
				if distToOpenOcean[nk] == nil then
					distToOpenOcean[nk] = cd + 1;
					queue[#queue + 1] = {nx, ny};
				end
			end
		end
	end

	local inlandSet = {};
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			if isOcean(x, y) and not openOcean[y * iW + x] then
				inlandSet[y * iW + x] = {x, y};
			end
		end
	end
	if next(inlandSet) == nil then
		if LekPipelineFlow then
			LekPipelineFlow("round_inland_seas_noop", "no_enclosed_ocean (needs landlocked ocean pockets; ring solid belt + bays off usually empty)");
		end
		return;
	end

	local components = {};
	local used = {};
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local k = y * iW + x;
			if inlandSet[k] and not used[k] then
				local comp = {};
				queue = {{x, y}};
				used[k] = true;
				comp[k] = true;
				q = 1;
				while q <= #queue do
					local cx, cy = queue[q][1], queue[q][2];
					q = q + 1;
					for d = 1, 6 do
						local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
							local nk = ny * iW + nx;
							if inlandSet[nk] and not used[nk] then
								used[nk] = true; comp[nk] = true; queue[#queue + 1] = {nx, ny};
							end
						end
					end
				end
				components[#components + 1] = comp;
			end
		end
	end

	-- Hex distance from every tile to nearest main-ocean water. Inland-sea water must stay at
	-- dist >= MIN_INLAND_TO_OPEN_WATER_DIST (6 => at least 5 land tiles between the water bodies).
	local MIN_INLAND_TO_OPEN_WATER_DIST = LEK_INLAND_SEA_MIN_OCEAN_DIST or 6;
	local distFromOpenWater = {};
	queue = {};
	for k, _ in pairs(openOcean) do
		local ox = k % iW;
		local oy = math.floor(k / iW);
		distFromOpenWater[k] = 0;
		queue[#queue + 1] = {ox, oy};
	end
	q = 1;
	while q <= #queue do
		local cx, cy = queue[q][1], queue[q][2];
		q = q + 1;
		local cd = distFromOpenWater[cy * iW + cx];
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local nk = ny * iW + nx;
				if distFromOpenWater[nk] == nil then
					distFromOpenWater[nk] = cd + 1;
					queue[#queue + 1] = {nx, ny};
				end
			end
		end
	end

	-- Paint inland-sea ocean that is too close to main ocean back to land. Optional comp limits to one body.
	local function enforceInlandOpenOceanLandGap(comp)
		local filled = 0;
		local keys = {};
		if comp ~= nil then
			for k in pairs(comp) do
				keys[#keys + 1] = k;
			end
		else
			for k in pairs(inlandSet) do
				keys[#keys + 1] = k;
			end
		end
		for i = 1, #keys do
			local k = keys[i];
			local d = distFromOpenWater[k];
			if d ~= nil and d < MIN_INLAND_TO_OPEN_WATER_DIST then
				local tx = k % iW;
				local ty = math.floor(k / iW);
				if isOcean(tx, ty) and not openOcean[k] then
					plotTypes[pidx(tx, ty)] = PlotTypes.PLOT_LAND;
					inlandSet[k] = nil;
					if comp ~= nil then
						comp[k] = nil;
					end
					filled = filled + 1;
				end
			end
		end
		return filled;
	end

	-- Fix ridge-created seas that already sit too close, before thickening.
	enforceInlandOpenOceanLandGap(nil);

	-- Thicken inland seas: random ocean seeds, paint ring-1 land→ocean with noise (no touch to open ocean).
	local MIN_SIZE = 6;
	local MIN_DIST_FROM_OPEN_OCEAN = LEK_INLAND_SEA_MIN_OCEAN_DIST or 6;
	local BLOB_PAINT_ITERS = 12;
	local BLOB_EDGE_PAINT_PCT = 70;
	for _, comp in ipairs(components) do
		local tiles = {};
		for k in pairs(comp) do
			if inlandSet[k] ~= nil then
				tiles[#tiles + 1] = inlandSet[k];
			end
		end
		if #tiles >= MIN_SIZE then
			for _blob = 1, BLOB_PAINT_ITERS do
				local oceanCells = {};
				for k in pairs(comp) do
					local tx = k % iW;
					local ty = math.floor(k / iW);
					if isOcean(tx, ty) then
						oceanCells[#oceanCells + 1] = {tx, ty};
					end
				end
				if #oceanCells == 0 then
					break;
				end
				local seed = oceanCells[1 + Map.Rand(#oceanCells, "inland_blob_center")];
				local sx, sy = seed[1], seed[2];
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(sx, sy, d, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(nx, ny) then
						if Map.Rand(100, "inland_blob_noise") < BLOB_EDGE_PAINT_PCT then
							local adjOpenOcean = false;
							for d2 = 1, 6 do
								local ax, ay = GetHexNeighbor(nx, ny, d2, iW, iH, wrapX, wrapY);
								if ax >= 0 and ax < iW and ay >= 0 and ay < iH and openOcean[ay * iW + ax] then
									adjOpenOcean = true;
									break;
								end
							end
							local nk = ny * iW + nx;
							local distO = distToOpenOcean[nk];
							local waterDist = distFromOpenWater[nk];
							-- Require known land-dist AND hex-dist-to-main-ocean water (>= 6 => 5 land tiles between).
							local farEnough = (distO ~= nil) and (distO >= MIN_DIST_FROM_OPEN_OCEAN)
								and (waterDist ~= nil) and (waterDist >= MIN_INLAND_TO_OPEN_WATER_DIST);
							if not adjOpenOcean and farEnough then
								plotTypes[pidx(nx, ny)] = PlotTypes.PLOT_OCEAN;
								comp[nk] = true;
								inlandSet[nk] = {nx, ny};
							end
						end
					end
				end
			end
			-- After thicken: fill any too-close inland water back to land (same step family).
			enforceInlandOpenOceanLandGap(comp);
			tiles = {};
			for k in pairs(comp) do
				local tx = k % iW;
				local ty = math.floor(k / iW);
				if isOcean(tx, ty) then
					tiles[#tiles + 1] = {tx, ty};
				end
			end
			if #tiles > 0 then
			local minX, maxX, minY, maxY = iW, -1, iH, -1;
			for _, t in ipairs(tiles) do
				local x, y = t[1], t[2];
				if x < minX then minX = x; end
				if x > maxX then maxX = x; end
				if y < minY then minY = y; end
				if y > maxY then maxY = y; end
			end
			local w, h = maxX - minX + 1, maxY - minY + 1;
			local aspectX = w / math.max(1, h);
			local aspectY = h / math.max(1, w);
			-- Distance to mainland shore only (land bordering this inland sea). So spray can fill around sprayed islands.
			local shoreSet = {};
			for _, t in ipairs(tiles) do
				local x, y = t[1], t[2];
				for dir = 1, 6 do
					local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(nx, ny) then
						shoreSet[ny * iW + nx] = true;
					end
				end
			end
			local distToShore = {};
			queue = {};
			for _, t in ipairs(tiles) do
				local x, y = t[1], t[2];
				local k = y * iW + x;
				for dir = 1, 6 do
					local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and shoreSet[ny * iW + nx] then
						distToShore[k] = 1;
						queue[#queue + 1] = {x, y};
						break;
					end
				end
			end
			q = 1;
			while q <= #queue do
				local cx, cy = queue[q][1], queue[q][2];
				q = q + 1;
				local ck = cy * iW + cx;
				local cd = distToShore[ck];
				for dir = 1, 6 do
					local nx, ny = GetHexNeighbor(cx, cy, dir, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local nk = ny * iW + nx;
						if comp[nk] and distToShore[nk] == nil then
							distToShore[nk] = cd + 1;
							queue[#queue + 1] = {nx, ny};
						end
					end
				end
			end
			local function distFromShore(x, y)
				return distToShore[y * iW + x] or 99;
			end
			-- Spray inland islands (single pass; no grow-fill — that erased spray variance).
			-- Per eligible ocean tile: independent Map.Rand < SPRAY_CHANCE (not one roll for the sea).
			local doSpray = (aspectX < 2.85 and aspectY < 2.85);
			if doSpray then
				local SPRAY_CHANCE = 75; -- was 85; -10pp per-tile land chance
				local MIN_DIST = 2;       -- tiles 2+ from mainland shore eligible
				for _, t in ipairs(tiles) do
					local x, y = t[1], t[2];
					if plotTypes[pidx(x, y)] == PlotTypes.PLOT_OCEAN and distFromShore(x, y) >= MIN_DIST then
						if Map.Rand(100, "inland_spray") < SPRAY_CHANCE then
							local r = Map.Rand(100, "");
							if r < 3 then plotTypes[pidx(x, y)] = PlotTypes.PLOT_MOUNTAIN;
							else plotTypes[pidx(x, y)] = (r < 53) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND; end
						end
					end
				end
			end
			end -- #tiles > 0
		end
	end
	-- Small / unthickened seas + any leftover violations.
	enforceInlandOpenOceanLandGap(nil);
end

------------------------------------------------------------------------------
-- Inland-sea curation (fractal pangaea). Inland sea = ocean not connected to the map-edge ocean.
--   * water must be >= LEK_INLAND_SEA_MIN_OCEAN_DIST hexes from main-ocean water (closer water -> land)
--   * span <= LEK_INLAND_SEA_MAX_SPAN tiles in any direction (water outside the disk around the
--     sea's most central tile -> land)
--   * no inland-sea water within LEK_INLAND_SEA_CAPITAL_CLEAR hexes of a capital (whole sea -> land,
--     after StartPlotSystem; start placement also ignores inland-sea shores as "coast")
------------------------------------------------------------------------------
LEK_INLAND_SEA_MIN_OCEAN_DIST = 6;
LEK_INLAND_SEA_MAX_SPAN = 7;
LEK_INLAND_SEA_CAPITAL_CLEAR = 3;
-- Final inland-sea water after plot types: key = plot index (y * iW + x). Nil when not curated.
_lek_inland_sea_plots = nil;

-- Fractal Pangaea only (Equator Ring keeps its own inland-sea behaviour).
function LekInlandSeaCurationActive()
	return LekLandmass_IsFractalPangaea ~= nil and LekLandmass_IsFractalPangaea();
end

-- True when plot is water belonging to a curated inland sea (not main ocean).
function LekIsInlandSeaPlot(plot)
	local set = _lek_inland_sea_plots;
	if set == nil or plot == nil then
		return false;
	end
	local iW = select(1, Map.GetGridSize());
	return set[plot:GetY() * iW + plot:GetX()] == true;
end

-- Fill water of one inland sea outside the disk (radius (maxSpan-1)/2) around its most central tile.
-- comp: set of keys y*iW+x. Returns number of tiles filled.
function LekTrimInlandSeaSpan(plotTypes, iW, comp, maxSpan)
	local radius = math.floor((maxSpan - 1) / 2);
	local keys = {};
	for k in pairs(comp) do
		if plotTypes[k + 1] == PlotTypes.PLOT_OCEAN then
			keys[#keys + 1] = k;
		end
	end
	if #keys <= 1 then
		return 0;
	end
	table.sort(keys);
	local cells = {};
	for i, k in ipairs(keys) do
		cells[i] = { k, k % iW, math.floor(k / iW) };
	end
	local bestI, bestEcc, diam = 1, nil, 0;
	for i = 1, #cells do
		local ecc = 0;
		for j = 1, #cells do
			local d = Map.PlotDistance(cells[i][2], cells[i][3], cells[j][2], cells[j][3]);
			if d > ecc then ecc = d; end
		end
		if ecc > diam then diam = ecc; end
		if bestEcc == nil or ecc < bestEcc then
			bestEcc = ecc;
			bestI = i;
		end
	end
	if diam + 1 <= maxSpan then
		return 0;
	end
	local c = cells[bestI];
	local filled = 0;
	for i = 1, #cells do
		if Map.PlotDistance(c[2], c[3], cells[i][2], cells[i][3]) > radius then
			plotTypes[cells[i][1] + 1] = PlotTypes.PLOT_LAND;
			comp[cells[i][1]] = nil;
			filled = filled + 1;
		end
	end
	return filled;
end

-- Main ocean = water flood-filled from the map edges. Returns openOcean set and hex distance
-- (through anything) from main-ocean water, both keyed y*iW+x.
function LekOpenOceanDistances(plotTypes, iW, iH, wrapX, wrapY)
	local openOcean = {};
	local queue = {};
	local function seedOpen(x, y)
		local k = y * iW + x;
		if plotTypes[k + 1] == PlotTypes.PLOT_OCEAN and not openOcean[k] then
			openOcean[k] = true;
			queue[#queue + 1] = { x, y };
		end
	end
	for x = 0, iW - 1 do
		seedOpen(x, 0);
		seedOpen(x, iH - 1);
	end
	if not wrapX then
		for y = 0, iH - 1 do
			seedOpen(0, y);
			seedOpen(iW - 1, y);
		end
	end
	local q = 1;
	while q <= #queue do
		local cx, cy = queue[q][1], queue[q][2];
		q = q + 1;
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				seedOpen(nx, ny);
			end
		end
	end
	local dist = {};
	queue = {};
	for k in pairs(openOcean) do
		dist[k] = 0;
		queue[#queue + 1] = { k % iW, math.floor(k / iW) };
	end
	q = 1;
	while q <= #queue do
		local cx, cy = queue[q][1], queue[q][2];
		q = q + 1;
		local cd = dist[cy * iW + cx];
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local nk = ny * iW + nx;
				if dist[nk] == nil then
					dist[nk] = cd + 1;
					queue[#queue + 1] = { nx, ny };
				end
			end
		end
	end
	return openOcean, dist;
end

------------------------------------------------------------------------------
-- Central inland sea (Fractal Pangaea): LEK_CENTRAL_SEA_CHANCE % of maps get one sea painted near the
-- canvas centre (+-2 tiles), a noisy hex disk of radius 2-3 (span <= 7), with sprayed islands inside.
-- Tiles closer than LEK_INLAND_SEA_MIN_OCEAN_DIST to main ocean are skipped. No pre-existing water needed.
------------------------------------------------------------------------------
LEK_CENTRAL_SEA_CHANCE = 30;
LEK_CENTRAL_SEA_R3_PCT = 60;      -- else radius 2
LEK_CENTRAL_SEA_EDGE_PCT = 65;    -- chance an outer-ring tile becomes water (ragged edge)
LEK_CENTRAL_SEA_MIN_TILES = 7;
LEK_CENTRAL_SEA_ISLAND_PCT = 75;  -- per interior tile (2+ from shore), like the old inland spray
-- Plot indices (y*iW+x) of the painted sea; island draft skips them. Nil when none.
_lek_central_sea_plots = nil;

LEK_BAY_MAX_MOUTH_STEPS = 3;   -- bay tiles further than this (through the bay) from its sea mouth are refilled

------------------------------------------------------------------------------
-- Central volcano (Fractal Pangaea, rare): the JunglePeak island (peak, caldera, broken ring of islets)
-- stamped into the middle of the pangaea, inside a ragged sea dug around it. The peak rolls a natural
-- wonder (Krakatoa / Sri Pada, else a jungle tile) and the island is mostly jungle. Replaces the normal central
-- sea on that map. This sea is exempt from the 7-tile span cap, the capital-clearance fill and the
-- mountain/inland-water barrier breaker.
------------------------------------------------------------------------------
LEK_CENTRAL_VOLCANO_CHANCE = 5;     -- % of Fractal Pangaea maps
LEK_CENTRAL_VOLCANO_ANCHOR_R = 6;   -- anchor: any tile within this hex radius of the canvas centre
LEK_CENTRAL_VOLCANO_NW = { krakatoa = 10, sripada = 10 };  -- else the peak is a jungle hill/flat tile
LEK_CENTRAL_VOLCANO_JUNGLE_MIN = 60;  -- % of the island's non-mountain tiles with jungle (min + 0..range)
LEK_CENTRAL_VOLCANO_JUNGLE_RANGE = 20;
LEK_CENTRAL_VOLCANO_NOISE_MIN = 3;    -- random land<->water flips on the island / moat / outer shore (3..5)
LEK_CENTRAL_VOLCANO_NOISE_RANGE = 2;
_lek_central_volcano = false;
_lek_central_volcano_nw = nil;        -- { plot = plotIndex1, kind = "krakatoa" | "sripada" }
_lek_central_volcano_island = nil;    -- list of plot indices (0-based) of the island's land

function LekPaintCentralVolcano(self, dist)
	local iW, iH = self.iNumPlotsX, self.iNumPlotsY;
	local wrapX = Map:IsWrapX();
	local pt = self.plotTypes;
	local function gapOk(x, y) return (dist[y * iW + x] or 0) >= LEK_INLAND_SEA_MIN_OCEAN_DIST; end
	-- Anchor: random tile within LEK_CENTRAL_VOLCANO_ANCHOR_R of the canvas centre whose radius-3 core
	-- keeps the main-ocean gap.
	local anchors = GetHexDisk(math.floor(iW / 2), math.floor(iH / 2), LEK_CENTRAL_VOLCANO_ANCHOR_R, iW, iH, wrapX, false);
	for i = #anchors, 2, -1 do
		local j = 1 + Map.Rand(i, "central_volcano_shuffle");
		anchors[i], anchors[j] = anchors[j], anchors[i];
	end
	local cx, cy = nil, nil;
	for _, o in ipairs(anchors) do
		local tx, ty = o[1], o[2];
		local ok = true;
		for _, t in ipairs(GetHexDisk(tx, ty, 4, iW, iH, wrapX, false)) do
			if not gapOk(t[1], t[2]) then ok = false; break; end
		end
		if ok then cx, cy = tx, ty; break; end
	end
	if not cx then
		LekLandStatsLog("### LekInlandSeaCentral volcano=0 reason=too_close_to_ocean");
		return false;
	end

	-- Minimal sea: stamp JunglePeak into a temporarily cleared radius-3 disk, then keep as water only the
	-- caldera and a one-tile moat around the island; every other cleared tile gets its land back.
	local disk3 = GetHexDisk(cx, cy, 3, iW, iH, wrapX, false);
	local orig = {};
	for _, t in ipairs(disk3) do
		local k = t[2] * iW + t[1];
		orig[k] = pt[k + 1];
		pt[k + 1] = PlotTypes.PLOT_OCEAN;
	end
	local savedPlaced = _island_placed;
	_island_placed = {};
	local ok = TryPlaceJunglePeakIsland(pt, cx, cy, 6, {
		pullBack = 3, effMin = 3, effMax = 5, iW = iW, iH = iH, wrapX = wrapX, wrapY = false,
	});
	_island_placed = savedPlaced;
	local islandSet = {};
	local peakK = cy * iW + cx;
	_lek_central_volcano_peak = peakK;
	for _, t in ipairs(disk3) do
		local k = t[2] * iW + t[1];
		if pt[k + 1] ~= PlotTypes.PLOT_OCEAN then
			islandSet[k] = true;
			-- Only the central peak is a mountain; ring mountains become hills.
			if k ~= peakK and pt[k + 1] == PlotTypes.PLOT_MOUNTAIN then
				pt[k + 1] = PlotTypes.PLOT_HILLS;
			end
		end
	end
	local sea = {};
	for _, t in ipairs(GetHexDisk(cx, cy, 1, iW, iH, wrapX, false)) do  -- caldera
		local k = t[2] * iW + t[1];
		if not islandSet[k] then sea[k] = true; end
	end
	for k in pairs(islandSet) do  -- moat
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), d, iW, iH, wrapX, false);
			local nk = ny * iW + nx;
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and not islandSet[nk] and gapOk(nx, ny) then
				sea[nk] = true;
			end
		end
	end
	for _, t in ipairs(disk3) do  -- restore cleared tiles that are neither island nor sea
		local k = t[2] * iW + t[1];
		if not islandSet[k] and not sea[k] then pt[k + 1] = orig[k]; end
	end
	for k in pairs(sea) do pt[k + 1] = PlotTypes.PLOT_OCEAN; end

	-- Natural wonder on the peak: Krakatoa / Sri Pada (re-applied after the island engine); otherwise the peak
	-- becomes a hill or flat tile that LekJungleCentralVolcano always covers with jungle.
	_lek_central_volcano_nw = nil;
	local r = Map.Rand(100, "central_volcano_nw");
	local peak = cy * iW + cx + 1;
	if r < LEK_CENTRAL_VOLCANO_NW.krakatoa then
		_lek_central_volcano_nw = { plot = peak, kind = "krakatoa" };
	elseif r < LEK_CENTRAL_VOLCANO_NW.krakatoa + LEK_CENTRAL_VOLCANO_NW.sripada then
		_lek_central_volcano_nw = { plot = peak, kind = "sripada" };
	else
		pt[peak] = (Map.Rand(2, "central_volcano_peak_flat") == 0) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
	end
	LekApplyCentralVolcanoWonder();

	-- Shoreline noise: a few random flips so the moat is not an exact outline of the island.
	do
		local peakNear = {};
		for _, t in ipairs(GetHexDisk(cx, cy, 1, iW, iH, wrapX, false)) do peakNear[t[2] * iW + t[1]] = true; end
		local flips = LEK_CENTRAL_VOLCANO_NOISE_MIN + Map.Rand(LEK_CENTRAL_VOLCANO_NOISE_RANGE + 1, "central_volcano_noise");
		local done = 0;
		for _ = 1, 40 do
			if done >= flips then break; end
			local kind = Map.Rand(3, "central_volcano_noise_kind");
			local cands = {};
			if kind == 0 then      -- island tile -> water (never the peak)
				for k in pairs(islandSet) do
					if k ~= peakK then cands[#cands + 1] = k; end
				end
			elseif kind == 1 then  -- moat/caldera water -> land (never next to the peak)
				for k in pairs(sea) do
					if not peakNear[k] and pt[k + 1] == PlotTypes.PLOT_OCEAN then cands[#cands + 1] = k; end
				end
			else                   -- outer mainland shore -> water (keeps the main-ocean gap)
				for k in pairs(sea) do
					for d = 1, 6 do
						local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), d, iW, iH, wrapX, false);
						local nk = ny * iW + nx;
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH and not sea[nk] and not islandSet[nk]
							and pt[nk + 1] ~= PlotTypes.PLOT_OCEAN and gapOk(nx, ny) then
							cands[#cands + 1] = nk;
						end
					end
				end
			end
			if #cands > 0 then
				table.sort(cands);
				local k = cands[1 + Map.Rand(#cands, "central_volcano_noise_pick")];
				if kind == 0 then
					islandSet[k] = nil;
					pt[k + 1] = PlotTypes.PLOT_OCEAN;
					sea[k] = true;
				elseif kind == 1 then
					sea[k] = nil;
					pt[k + 1] = (Map.Rand(100, "central_volcano_noise_hill") < 40) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
				else
					pt[k + 1] = PlotTypes.PLOT_OCEAN;
					sea[k] = true;
				end
				done = done + 1;
			end
		end
	end

	local land = {};
	for k in pairs(islandSet) do
		land[#land + 1] = k;
		sea[k] = true;
	end
	table.sort(land);
	_lek_central_sea_plots = sea;
	_lek_central_volcano = true;
	_lek_central_volcano_island = land;
	if LekRegisterExtraIsland and #land > 0 then LekRegisterExtraIsland("centralVolcano", land); end
	local nSea = 0;
	for _ in pairs(sea) do nSea = nSea + 1; end
	LekLandStatsLog("### LekInlandSeaCentral volcano=1 at=" .. tostring(cx) .. "," .. tostring(cy)
		.. " placerOk=" .. tostring(ok) .. " nw=" .. tostring(_lek_central_volcano_nw and _lek_central_volcano_nw.kind or "none_jungle")
		.. " islandTiles=" .. tostring(#land) .. " waterTiles=" .. tostring(nSea - #land));
	return true;
end

-- Point the island natural-wonder markers at the central peak (the island engine resets them per run).
function LekApplyCentralVolcanoWonder()
	local nw = _lek_central_volcano_nw;
	if not nw then return; end
	-- Only set our own marker: the other one may belong to a Geothermal Krakatoa (no engine JunglePeak exists
	-- on central-volcano maps, so nothing else can hold Sri Pada).
	if nw.kind == "krakatoa" then
		_krakatoa_island_plot = nw.plot;
	elseif nw.kind == "sripada" then
		_sri_pada_island_plot = nw.plot;
	end
end

-- After features: jungle on 60-80% of the central island's flat/hill tiles.
function LekJungleCentralVolcano()
	local land = _lek_central_volcano_island;
	if not (_lek_central_volcano and land) then return; end
	local pct = LEK_CENTRAL_VOLCANO_JUNGLE_MIN + Map.Rand(LEK_CENTRAL_VOLCANO_JUNGLE_RANGE + 1, "central_volcano_jungle_pct");
	local n = 0;
	for _, k in ipairs(land) do
		local plot = Map.GetPlotByIndex(k);
		local isPeak = (k == _lek_central_volcano_peak) and not _lek_central_volcano_nw;
		if plot and not plot:IsWater() and not plot:IsMountain() and (isPeak or Map.Rand(100, "central_volcano_jungle") < pct) then
			local ft = plot:GetFeatureType();
			local info = (ft ~= FeatureTypes.NO_FEATURE) and GameInfo.Features[ft] or nil;
			if not (info and info.NaturalWonder) then
				if plot:GetTerrainType() ~= TerrainTypes.TERRAIN_PLAINS then
					plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, true);
				end
				plot:SetFeatureType(FeatureTypes.FEATURE_JUNGLE, -1);
				n = n + 1;
			end
		end
	end
	if LekPipelineFlow then LekPipelineFlow("central_volcano_jungle", "pct=" .. tostring(pct) .. " jungle=" .. tostring(n)); end
end

function LekPaintCentralInlandSea(self)
	_lek_central_sea_plots = nil;
	_lek_central_volcano = false;
	_lek_central_volcano_nw = nil;
	_lek_central_volcano_island = nil;
	_lek_central_volcano_peak = nil;
	local iW, iH = self.iNumPlotsX, self.iNumPlotsY;
	local wrapX = Map:IsWrapX();
	local pt = self.plotTypes;
	if Map.Rand(100, "central_volcano_roll") < LEK_CENTRAL_VOLCANO_CHANCE then
		local _, vdist = LekOpenOceanDistances(pt, iW, iH, wrapX, false);
		if LekPaintCentralVolcano(self, vdist) then
			return;
		end
	end
	local roll = Map.Rand(100, "central_sea_roll");
	if roll >= LEK_CENTRAL_SEA_CHANCE then
		LekLandStatsLog("### LekInlandSeaCentral painted=0 reason=roll roll=" .. tostring(roll)
			.. " chance=" .. tostring(LEK_CENTRAL_SEA_CHANCE));
		return;
	end
	local _, dist = LekOpenOceanDistances(pt, iW, iH, wrapX, false);
	local cx = math.floor(iW / 2) + Map.Rand(5, "central_sea_dx") - 2;
	local cy = math.floor(iH / 2) + Map.Rand(5, "central_sea_dy") - 2;
	local R = (Map.Rand(100, "central_sea_r") < LEK_CENTRAL_SEA_R3_PCT) and 3 or 2;

	local sea = {};
	local seaList = {};
	for _, t in ipairs(GetHexDisk(cx, cy, R, iW, iH, wrapX, false)) do
		local x, y = t[1], t[2];
		local k = y * iW + x;
		local d = Map.PlotDistance(cx, cy, x, y);
		local keep = (d < R) or (Map.Rand(100, "central_sea_edge") < LEK_CENTRAL_SEA_EDGE_PCT);
		if keep and (dist[k] or 0) >= LEK_INLAND_SEA_MIN_OCEAN_DIST then
			sea[k] = true;
			seaList[#seaList + 1] = k;
		end
	end
	if #seaList < LEK_CENTRAL_SEA_MIN_TILES then
		LekLandStatsLog("### LekInlandSeaCentral painted=0 reason=too_close_to_ocean tiles=" .. tostring(#seaList)
			.. " at=" .. tostring(cx) .. "," .. tostring(cy) .. " R=" .. tostring(R));
		return;
	end
	for _, k in ipairs(seaList) do
		pt[k + 1] = PlotTypes.PLOT_OCEAN;
	end

	-- Islands: sea tiles 2+ steps from the surrounding mainland.
	local shoreDist = {};
	local queue = {};
	for _, k in ipairs(seaList) do
		local x, y = k % iW, math.floor(k / iW);
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, false);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and pt[ny * iW + nx + 1] ~= PlotTypes.PLOT_OCEAN then
				shoreDist[k] = 1;
				queue[#queue + 1] = k;
				break;
			end
		end
	end
	local q = 1;
	while q <= #queue do
		local k = queue[q];
		q = q + 1;
		local x, y = k % iW, math.floor(k / iW);
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, false);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local nk = ny * iW + nx;
				if sea[nk] and shoreDist[nk] == nil then
					shoreDist[nk] = shoreDist[k] + 1;
					queue[#queue + 1] = nk;
				end
			end
		end
	end
	local islandTiles = 0;
	for _, k in ipairs(seaList) do
		if (shoreDist[k] or 99) >= 2 and Map.Rand(100, "central_sea_isle") < LEK_CENTRAL_SEA_ISLAND_PCT then
			local r = Map.Rand(100, "central_sea_isle_type");
			if r < 3 then
				pt[k + 1] = PlotTypes.PLOT_MOUNTAIN;
			elseif r < 53 then
				pt[k + 1] = PlotTypes.PLOT_HILLS;
			else
				pt[k + 1] = PlotTypes.PLOT_LAND;
			end
			islandTiles = islandTiles + 1;
		end
	end
	_lek_central_sea_plots = sea;
	if LekRegisterExtraIsland then
		local isl = {};
		for _, k in ipairs(seaList) do
			if pt[k + 1] ~= PlotTypes.PLOT_OCEAN then isl[#isl + 1] = k; end
		end
		if #isl > 0 then LekRegisterExtraIsland("centralSeaIslands", isl); end
	end
	LekLandStatsLog("### LekInlandSeaCentral painted=1 at=" .. tostring(cx) .. "," .. tostring(cy)
		.. " R=" .. tostring(R)
		.. " seaTiles=" .. tostring(#seaList - islandTiles)
		.. " islandTiles=" .. tostring(islandTiles));
end

-- Final plot-type pass: re-derive inland seas from scratch (islands and carves ran after RoundInlandSeas)
-- and enforce ocean gap + span. Records _lek_inland_sea_plots. Returns stats table.
function LekCurateInlandSeas(plotTypes, iW, iH, wrapX, wrapY)
	local function isOcean(x, y)
		return plotTypes[y * iW + x + 1] == PlotTypes.PLOT_OCEAN;
	end
	local openOcean, dist = LekOpenOceanDistances(plotTypes, iW, iH, wrapX, wrapY);
	local queue, q;

	local stats = { seas = 0, water = 0, gapFilled = 0, spanFilled = 0, secondaryFilled = 0 };
	local inland = {};
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local k = y * iW + x;
			if isOcean(x, y) and not openOcean[k] then
				if (dist[k] or 0) < LEK_INLAND_SEA_MIN_OCEAN_DIST then
					plotTypes[k + 1] = PlotTypes.PLOT_LAND;
					stats.gapFilled = stats.gapFilled + 1;
				else
					inland[k] = true;
				end
			end
		end
	end

	local used = {};
	local final = {};
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local k = y * iW + x;
			if inland[k] and not used[k] then
				local comp = { [k] = true };
				used[k] = true;
				queue = { { x, y } };
				q = 1;
				while q <= #queue do
					local cx, cy = queue[q][1], queue[q][2];
					q = q + 1;
					for d = 1, 6 do
						local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
							local nk = ny * iW + nx;
							if inland[nk] and not used[nk] then
								used[nk] = true;
								comp[nk] = true;
								queue[#queue + 1] = { nx, ny };
							end
						end
					end
				end
				local isCentral = false;
				if _lek_central_sea_plots then
					for ck in pairs(comp) do
						if _lek_central_sea_plots[ck] then isCentral = true; break; end
					end
				end
				if _lek_central_sea_plots and not isCentral then
					-- A central sea / volcano exists: it is the only inland sea; fill every other one.
					for ck in pairs(comp) do
						plotTypes[ck + 1] = PlotTypes.PLOT_LAND;
						comp[ck] = nil;
						stats.secondaryFilled = stats.secondaryFilled + 1;
					end
				else
					if isCentral then
						-- Water merely connected to the central sea (incidental puddles) is filled too.
						for ck in pairs(comp) do
							if not _lek_central_sea_plots[ck] then
								plotTypes[ck + 1] = PlotTypes.PLOT_LAND;
								comp[ck] = nil;
								stats.secondaryFilled = stats.secondaryFilled + 1;
							end
						end
					end
					if not (isCentral and _lek_central_volcano) then
						stats.spanFilled = stats.spanFilled + LekTrimInlandSeaSpan(plotTypes, iW, comp, LEK_INLAND_SEA_MAX_SPAN);
					end
				end
				local n = 0;
				for ck in pairs(comp) do
					final[ck] = true;
					n = n + 1;
				end
				if n > 0 then
					stats.seas = stats.seas + 1;
					stats.water = stats.water + n;
				end
			end
		end
	end
	_lek_inland_sea_plots = final;
	return stats;
end

-- After StartPlotSystem (areas may be recalculated again): fill every inland sea that has water within
-- LEK_INLAND_SEA_CAPITAL_CLEAR of a major capital. Seas holding a natural wonder are left alone.
function LekFillInlandSeasNearCapitals()
	local set = _lek_inland_sea_plots;
	if set == nil or next(set) == nil then
		return;
	end
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local caps = {};
	for pid = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local pl = Players[pid];
		if pl and pl:IsEverAlive() and not pl:IsMinorCiv() then
			local sp = pl:GetStartingPlot();
			if sp then
				caps[#caps + 1] = { sp:GetX(), sp:GetY() };
			end
		end
	end
	-- Central volcano check: nearest capital to the peak and what ended up on the peak.
	if _lek_central_volcano and _lek_central_volcano_peak then
		local px, py = _lek_central_volcano_peak % iW, math.floor(_lek_central_volcano_peak / iW);
		local nearest = 99;
		for _, c in ipairs(caps) do
			local d = Map.PlotDistance(px, py, c[1], c[2]);
			if d < nearest then nearest = d; end
		end
		local peakPlot = Map.GetPlot(px, py);
		local ft = peakPlot and peakPlot:GetFeatureType() or -1;
		local fname = (ft ~= FeatureTypes.NO_FEATURE and GameInfo.Features[ft]) and GameInfo.Features[ft].Type or "none";
		LekLandStatsLog("### LekCentralVolcanoCheck peak=" .. px .. "," .. py .. " nearestCapital=" .. tostring(nearest)
			.. " wantedNW=" .. tostring(_lek_central_volcano_nw and _lek_central_volcano_nw.kind or "none_jungle")
			.. " featureOnPeak=" .. fname);
	end
	local function isSeaWater(k)
		if not set[k] then return false; end
		local p = Map.GetPlotByIndex(k);
		return p ~= nil and p:IsWater();
	end
	local keys = {};
	for k in pairs(set) do
		keys[#keys + 1] = k;
	end
	table.sort(keys);

	local seen = {};
	local seasFilled, tilesFilled, seasSkippedNW = 0, 0, 0;
	for _, k in ipairs(keys) do
		if not seen[k] and isSeaWater(k) then
			-- Whole sea (connected inland water).
			local comp = { k };
			seen[k] = true;
			local q = 1;
			while q <= #comp do
				local ck = comp[q];
				q = q + 1;
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(ck % iW, math.floor(ck / iW), d, iW, iH, wrapX, false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local nk = ny * iW + nx;
						if not seen[nk] and isSeaWater(nk) then
							seen[nk] = true;
							comp[#comp + 1] = nk;
						end
					end
				end
			end
			local nearCap, hasNW = false, false;
			for _, ck in ipairs(comp) do
				local x, y = ck % iW, math.floor(ck / iW);
				local p = Map.GetPlotByIndex(ck);
				local ft = p:GetFeatureType();
				if ft ~= FeatureTypes.NO_FEATURE and GameInfo.Features[ft] and GameInfo.Features[ft].NaturalWonder then
					hasNW = true;
				end
				for _, c in ipairs(caps) do
					if Map.PlotDistance(x, y, c[1], c[2]) <= LEK_INLAND_SEA_CAPITAL_CLEAR then
						nearCap = true;
					end
				end
			end
			if nearCap and _lek_central_volcano and _lek_central_sea_plots then
				for _, ck in ipairs(comp) do
					if _lek_central_sea_plots[ck] then nearCap = false; break; end
				end
			end
			if nearCap and hasNW then
				seasSkippedNW = seasSkippedNW + 1;
			elseif nearCap then
				-- Turn water to flat land first, then pick terrain from land neighbours (majority).
				for _, ck in ipairs(comp) do
					local p = Map.GetPlotByIndex(ck);
					p:SetResourceType(-1);
					p:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
					p:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				end
				for _, ck in ipairs(comp) do
					local p = Map.GetPlotByIndex(ck);
					local votes, bestT, bestN = {}, TerrainTypes.TERRAIN_GRASS, 0;
					for d = 0, 5 do
						local np = Map.PlotDirection(p:GetX(), p:GetY(), d);
						if np and not np:IsWater() then
							local t = np:GetTerrainType();
							if t ~= TerrainTypes.TERRAIN_COAST and t ~= TerrainTypes.TERRAIN_OCEAN then
								votes[t] = (votes[t] or 0) + 1;
								if votes[t] > bestN or (votes[t] == bestN and t < bestT) then
									bestN = votes[t];
									bestT = t;
								end
							end
						end
					end
					p:SetTerrainType(bestT, false, false);
					set[ck] = nil;
				end
				seasFilled = seasFilled + 1;
				tilesFilled = tilesFilled + #comp;
			end
		end
	end
	if seasFilled > 0 then
		Map.RecalculateAreas();
	end
	LekLandStatsLog("### LekInlandSeaCapitalClear capitals=" .. tostring(#caps)
		.. " seasFilled=" .. tostring(seasFilled)
		.. " tilesFilled=" .. tostring(tilesFilled)
		.. " seasSkippedNaturalWonder=" .. tostring(seasSkippedNW)
		.. " clearRadius=" .. tostring(LEK_INLAND_SEA_CAPITAL_CLEAR));
end

------------------------------------------------------------------------------
-- Land stats (both shapes): file-only, no Lua.log. Needs master _lek_mapgen_logs + channel landstats.
--   Logs/LekmapLandStats.log   appended, keeps every rolled map (for averages)
--   Logs/LekmapPipelineFlow.log same line as a flow entry (file is reset per map load)
-- Mainland = biggest connected land component (flat+hills+mountains). Islands touching it count as mainland.
------------------------------------------------------------------------------
function LekLandStatsLog(line)
	if not (LekMapgenChannelEnabled and LekMapgenChannelEnabled("landstats")) then
		return;
	end
	if LekAppendCiv5Log then
		LekAppendCiv5Log("LekmapLandStats.log", line);
	end
	if LekPipelineFlow then
		LekPipelineFlow("land_stats", line);
	end
end

-- plotTypes: 1-based array (index y * iW + x + 1).
function LekCountLandStats(plotTypes, iW, iH, wrapX, wrapY)
	local seen = {};
	local total, landmasses = 0, 0;
	local best = { n = 0, hills = 0, mtn = 0 };
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local i = y * iW + x + 1;
			if plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
				total = total + 1;
				if not seen[i] then
					landmasses = landmasses + 1;
					local comp = { n = 0, hills = 0, mtn = 0 };
					local queue = { { x, y } };
					seen[i] = true;
					local q = 1;
					while q <= #queue do
						local cx, cy = queue[q][1], queue[q][2];
						q = q + 1;
						local pt = plotTypes[cy * iW + cx + 1];
						comp.n = comp.n + 1;
						if pt == PlotTypes.PLOT_HILLS then
							comp.hills = comp.hills + 1;
						elseif pt == PlotTypes.PLOT_MOUNTAIN then
							comp.mtn = comp.mtn + 1;
						end
						for d = 1, 6 do
							local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
							if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
								local ni = ny * iW + nx + 1;
								if not seen[ni] and plotTypes[ni] ~= PlotTypes.PLOT_OCEAN then
									seen[ni] = true;
									queue[#queue + 1] = { nx, ny };
								end
							end
						end
					end
					if comp.n > best.n then
						best = comp;
					end
				end
			end
		end
	end
	return {
		total = total,
		mainland = best.n,
		hills = best.hills,
		mtn = best.mtn,
		flat = best.n - best.hills - best.mtn,
		otherLand = total - best.n,
		landmasses = landmasses,
	};
end

function LekLogLandStats(stage, plotTypes, iW, iH, wrapX, wrapY)
	if not (LekMapgenChannelEnabled and LekMapgenChannelEnabled("landstats")) then
		return;
	end
	local s = LekCountLandStats(plotTypes, iW, iH, wrapX, wrapY);
	local canvas = iW * iH;
	LekLandStatsLog("### LekLandStats stage=" .. tostring(stage)
		.. " shape=" .. tostring(_lek_pangaea_land_shape or "na")
		.. " W=" .. tostring(iW) .. " H=" .. tostring(iH)
		.. " waterPct=" .. tostring(_lek_last_water_percent or "?")
		.. " outerAttempts=" .. tostring(_lek_pangaea_outer_attempt or "?")
		.. " mainland=" .. tostring(s.mainland)
		.. " mainlandPctOfCanvas=" .. string.format("%.1f", 100 * s.mainland / math.max(1, canvas))
		.. " flat=" .. tostring(s.flat)
		.. " hills=" .. tostring(s.hills)
		.. " mtn=" .. tostring(s.mtn)
		.. " otherLand=" .. tostring(s.otherLand)
		.. " totalLand=" .. tostring(s.total)
		.. " landmasses=" .. tostring(s.landmasses));
end

------------------------------------------------------------------------------
-- Polar snow rows: every land tile in the LEK_POLAR_SNOW_ROWS rows at the north and south map edge is snow
-- (islands can paint other terrain there). Land features on those tiles are cleared, natural wonders kept.
-- Runs after AddFeatures and again after the coastal bonus islands (both before resources).
------------------------------------------------------------------------------
LEK_POLAR_SNOW_ROWS = 2;

function LekForcePolarSnowRows()
	local iW, iH = Map.GetGridSize();
	local rows = LEK_POLAR_SNOW_ROWS;
	local changed = 0;
	for y = 0, iH - 1 do
		if y < rows or y >= iH - rows then
			for x = 0, iW - 1 do
				local plot = Map.GetPlot(x, y);
				if plot and not plot:IsWater() then
					if plot:GetTerrainType() ~= TerrainTypes.TERRAIN_SNOW then
						plot:SetTerrainType(TerrainTypes.TERRAIN_SNOW, false, true);
						changed = changed + 1;
					end
					local ft = plot:GetFeatureType();
					if ft ~= FeatureTypes.NO_FEATURE then
						local info = GameInfo.Features[ft];
						if not (info and info.NaturalWonder) then
							plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
						end
					end
				end
			end
		end
	end
	-- Snow never borders grass / plains / desert directly: such tiles become tundra (map-wide, mostly
	-- polar islands). Features tundra cannot carry (jungle, marsh, oasis, flood plains) are cleared.
	local buffered = 0;
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local plot = Map.GetPlot(x, y);
			if plot and not plot:IsWater() then
				local tt = plot:GetTerrainType();
				if tt == TerrainTypes.TERRAIN_GRASS or tt == TerrainTypes.TERRAIN_PLAINS or tt == TerrainTypes.TERRAIN_DESERT then
					local nextToSnow = false;
					for d = 0, 5 do
						local np = Map.PlotDirection(x, y, d);
						if np and not np:IsWater() and np:GetTerrainType() == TerrainTypes.TERRAIN_SNOW then
							nextToSnow = true;
							break;
						end
					end
					if nextToSnow then
						plot:SetTerrainType(TerrainTypes.TERRAIN_TUNDRA, false, true);
						local ft = plot:GetFeatureType();
						if ft ~= FeatureTypes.NO_FEATURE and ft ~= FeatureTypes.FEATURE_FOREST then
							local info = GameInfo.Features[ft];
							if not (info and info.NaturalWonder) then
								plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
							end
						end
						buffered = buffered + 1;
					end
				end
			end
		end
	end
	if LekPipelineFlow then
		LekPipelineFlow("polar_snow_rows", "rows=" .. tostring(rows) .. " changed=" .. tostring(changed)
			.. " tundraBuffer=" .. tostring(buffered));
	end
	return changed;
end

------------------------------------------------------------------------------
-- Medium mountain ridges (Fractal Pangaea). The clump breaker keeps every mountain group <= 4 tiles, which
-- leaves few real ridges. This pass tops the map up to 3-5 ridges of 3-4 mountains (length <= 4 tiles in
-- any direction, never touching another mountain group or inland water), with a
-- LEK_RIDGE_CLUMP_PCT chance that one of them is a compact 5-6 tile clump (fits a radius-1 hex).
------------------------------------------------------------------------------
LEK_RIDGE_TARGET_MIN = 3;
LEK_RIDGE_TARGET_RANGE = 2;   -- target = min + 0..range
LEK_RIDGE_CLUMP_PCT = 25;

function LekAddMediumMountainRidges(plotTypes, iW, iH, wrapX)
	local n = iW * iH;
	local function isOceanK(k) return plotTypes[k + 1] == PlotTypes.PLOT_OCEAN; end
	local function isMtnK(k) return plotTypes[k + 1] == PlotTypes.PLOT_MOUNTAIN; end
	local function xyK(k) return k % iW, math.floor(k / iW); end
	local function nbrs(k)
		local x, y = xyK(k);
		local out = {};
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, false);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then out[#out + 1] = ny * iW + nx; end
		end
		return out;
	end
	local openOcean = LekOpenOceanDistances(plotTypes, iW, iH, wrapX, false);

	-- Mountain groups.
	local compOf, comps = {}, {};
	for k = 0, n - 1 do
		if isMtnK(k) and compOf[k] == nil then
			local c = { k };
			compOf[k] = #comps + 1;
			local h = 1;
			while h <= #c do
				for _, nk in ipairs(nbrs(c[h])) do
					if isMtnK(nk) and compOf[nk] == nil then
						compOf[nk] = #comps + 1;
						c[#c + 1] = nk;
					end
				end
				h = h + 1;
			end
			comps[#comps + 1] = c;
		end
	end
	local existing = 0;
	for _, c in ipairs(comps) do
		if #c >= 3 then existing = existing + 1; end
	end
	local target = LEK_RIDGE_TARGET_MIN + Map.Rand(LEK_RIDGE_TARGET_RANGE + 1, "lek_ridge_target");
	local need = target - existing;
	local added, clumpMade = 0, 0;
	if need <= 0 then
		LekLandStatsLog("### LekMountainRidges existing=" .. tostring(existing) .. " target=" .. tostring(target) .. " added=0");
		return 0;
	end

	local yMin, yMax = LEK_POLAR_SNOW_ROWS + 1, iH - LEK_POLAR_SNOW_ROWS - 2;
	-- A tile may join ridge `own` if it is land, off the polar rows, not beside inland water,
	-- and every mountain neighbour belongs to `own` (so ridges never merge into bigger groups).
	local function canJoin(k, own)
		if isOceanK(k) or isMtnK(k) then return false; end
		if _lek_no_mountain_plots and _lek_no_mountain_plots[k] then return false; end	-- e.g. the soft land bridge
		local _, y = xyK(k);
		if y < yMin or y > yMax then return false; end
		for _, nk in ipairs(nbrs(k)) do
			if isOceanK(nk) and not openOcean[nk] then return false; end
			if isMtnK(nk) and not own[nk] then return false; end
		end
		return true;
	end
	local function span(tiles)
		local m = 0;
		for i = 1, #tiles do
			local ax, ay = xyK(tiles[i]);
			for j = i + 1, #tiles do
				local bx, by = xyK(tiles[j]);
				local d = Map.PlotDistance(ax, ay, bx, by);
				if d > m then m = d; end
			end
		end
		return m;
	end

	-- Seeds: small existing groups (1-2 mountains) first, then hills.
	local seeds = {};
	for _, c in ipairs(comps) do
		if #c <= 2 then seeds[#seeds + 1] = c; end
	end
	local hillSeeds = {};
	for k = 0, n - 1 do
		if plotTypes[k + 1] == PlotTypes.PLOT_HILLS then hillSeeds[#hillSeeds + 1] = k; end
	end

	-- One roll per map: if it hits, the first ridge built is a compact clump.
	local wantClump = (Map.Rand(100, "lek_ridge_clump") < LEK_RIDGE_CLUMP_PCT);
	local tries = 0;
	while need > 0 and tries < 200 do
		tries = tries + 1;
		local ridge = {};
		local own = {};
		if #seeds > 0 then
			local c = table.remove(seeds, 1 + Map.Rand(#seeds, "lek_ridge_seed"));
			for _, k in ipairs(c) do ridge[#ridge + 1] = k; own[k] = true; end
		elseif #hillSeeds > 0 then
			local k = hillSeeds[1 + Map.Rand(#hillSeeds, "lek_ridge_hill_seed")];
			if canJoin(k, own) then
				ridge[1] = k;
				own[k] = true;
			end
		else
			break;
		end
		if #ridge > 0 then
			local clump = wantClump and clumpMade == 0;
			local want = clump and (5 + Map.Rand(2, "lek_ridge_clump_n")) or (3 + Map.Rand(2, "lek_ridge_n"));
			local maxSpan = clump and 2 or 3;
			local newTiles = {};
			local dir = nil;
			local guard = 0;
			while #ridge < want and guard < 40 do
				guard = guard + 1;
				-- Ridges: prefer continuing the line from the last tile; clumps: grow around any tile.
				local cands = {};
				local last = ridge[#ridge];
				local lx, ly = xyK(last);
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(lx, ly, d, iW, iH, wrapX, false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local nk = ny * iW + nx;
						if not own[nk] and canJoin(nk, own) then
							local w = (dir == d) and 6 or 1;
							if clump then w = 1; end
							if plotTypes[nk + 1] == PlotTypes.PLOT_HILLS then w = w + 1; end
							cands[#cands + 1] = { nk, d, w };
						end
					end
				end
				if clump or #cands == 0 then
					for _, rk in ipairs(ridge) do
						for _, nk in ipairs(nbrs(rk)) do
							if not own[nk] and canJoin(nk, own) then cands[#cands + 1] = { nk, nil, 1 }; end
						end
					end
				end
				if #cands == 0 then break; end
				local tot = 0;
				for _, c in ipairs(cands) do tot = tot + c[3]; end
				local r = Map.Rand(tot, "lek_ridge_grow");
				local pick = cands[#cands];
				for _, c in ipairs(cands) do
					r = r - c[3];
					if r < 0 then pick = c; break; end
				end
				ridge[#ridge + 1] = pick[1];
				if span(ridge) > maxSpan then
					ridge[#ridge] = nil;
				else
					own[pick[1]] = true;
					newTiles[#newTiles + 1] = pick[1];
					if pick[2] then dir = pick[2]; end
				end
			end
			if #ridge >= 3 then
				for _, k in ipairs(newTiles) do plotTypes[k + 1] = PlotTypes.PLOT_MOUNTAIN; end
				added = added + 1;
				need = need - 1;
				if clump then clumpMade = 1; end
			end
		end
	end
	LekLandStatsLog("### LekMountainRidges existing=" .. tostring(existing) .. " target=" .. tostring(target)
		.. " added=" .. tostring(added) .. " clump=" .. tostring(clumpMade));
	return added;
end

------------------------------------------------------------------------------
-- Straight horizontal ridges: a mountain group of 3+ tiles that all sit in one row (east-west, nothing above or
-- below) looks ruler-drawn. Bend it: an end tile moves one step diagonally (up or down, random) next to its
-- neighbour on the ridge and the old end becomes hills; 4+ tile runs bend both ends. The new mountain must be
-- land, not a mountain, and touch no other mountain group; if neither side works the end just becomes hills.
-- Runs last on the final plot types (after ridges, breakers and islands), before terrain.
------------------------------------------------------------------------------
function LekBendHorizontalMountainRuns(plotTypes, iW, iH, wrapX)
	local MTN, HILLS, LAND = PlotTypes.PLOT_MOUNTAIN, PlotTypes.PLOT_HILLS, PlotTypes.PLOT_LAND;
	local function nb(k, d)
		local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), d, iW, iH, wrapX, false);
		if nx < 0 or nx >= iW or ny < 0 or ny >= iH then return nil; end
		return ny * iW + nx;
	end
	local seen, bent, shortened, runs = {}, 0, 0, 0;
	for k0 = 0, iW * iH - 1 do
		if plotTypes[k0 + 1] == MTN and not seen[k0] then
			local comp, h = { k0 }, 1;
			seen[k0] = true;
			while h <= #comp do
				local k = comp[h];
				h = h + 1;
				for d = 1, 6 do
					local nk = nb(k, d);
					if nk and not seen[nk] and plotTypes[nk + 1] == MTN then
						seen[nk] = true;
						comp[#comp + 1] = nk;
					end
				end
			end
			local row = math.floor(comp[1] / iW);
			local flat = #comp >= 3;
			for _, k in ipairs(comp) do
				if math.floor(k / iW) ~= row then flat = false; break; end
			end
			if flat then
				runs = runs + 1;
				local inComp = {};
				for _, k in ipairs(comp) do inComp[k] = true; end
				-- Ends: tiles with exactly one mountain neighbour in the run.
				local ends = {};
				for _, k in ipairs(comp) do
					local n = 0;
					local inner = nil;
					for d = 1, 6 do
						local nk = nb(k, d);
						if nk and inComp[nk] then n = n + 1; inner = nk; end
					end
					if n == 1 then ends[#ends + 1] = { k, inner }; end
				end
				if #ends == 2 and #comp == 3 then
					table.remove(ends, 1 + Map.Rand(2, "lek_flat_ridge_end"));
				end
				for _, e in ipairs(ends) do
					local old, inner = e[1], e[2];
					-- Candidates: off-row tiles next to both the inner ridge tile and the old end.
					local cands = {};
					for d = 1, 6 do
						local t = nb(inner, d);
						if t and math.floor(t / iW) ~= row then
							for d2 = 1, 6 do
								if nb(t, d2) == old then cands[#cands + 1] = t; break; end
							end
						end
					end
					if #cands == 2 and Map.Rand(2, "lek_flat_ridge_side") == 0 then cands[1], cands[2] = cands[2], cands[1]; end
					local done = false;
					for _, t in ipairs(cands) do
						local pt = plotTypes[t + 1];
						if pt == LAND or pt == HILLS then
							local lonely = true;
							for d = 1, 6 do
								local nk = nb(t, d);
								if nk and nk ~= inner and nk ~= old and plotTypes[nk + 1] == MTN then lonely = false; break; end
							end
							if lonely then
								plotTypes[t + 1] = MTN;
								plotTypes[old + 1] = HILLS;
								bent = bent + 1;
								done = true;
								break;
							end
						end
					end
					if not done then
						plotTypes[old + 1] = HILLS;
						shortened = shortened + 1;
					end
				end
			end
		end
	end
	LekLandStatsLog("### LekFlatRidges runs=" .. tostring(runs) .. " bent=" .. tostring(bent) .. " shortened=" .. tostring(shortened));
	return bent, shortened;
end

------------------------------------------------------------------------------
-- Central volcano: no mountain groups near its water. Any mountain within 2 hexes of the centerpiece
-- water that touches another mountain becomes hills (repeat until only single peaks remain there).
------------------------------------------------------------------------------
function LekClearMountainGroupsNearCentralSea(plotTypes, iW, iH, wrapX)
	if not (_lek_central_volcano and _lek_central_sea_plots) then return 0; end
	local peakK = _lek_central_volcano_peak;
	local near, q = {}, {};
	for k in pairs(_lek_central_sea_plots) do
		if plotTypes[k + 1] == PlotTypes.PLOT_OCEAN then
			near[k] = 0;
			q[#q + 1] = k;
		end
	end
	local h = 1;
	while h <= #q do
		local k = q[h];
		h = h + 1;
		if near[k] < 2 then
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), d, iW, iH, wrapX, false);
				local nk = ny * iW + nx;
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH and near[nk] == nil then
					near[nk] = near[k] + 1;
					q[#q + 1] = nk;
				end
			end
		end
	end
	local demoted = 0;
	local changed = true;
	while changed do
		changed = false;
		for k in pairs(near) do
			if k ~= peakK and plotTypes[k + 1] == PlotTypes.PLOT_MOUNTAIN then
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), d, iW, iH, wrapX, false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and plotTypes[ny * iW + nx + 1] == PlotTypes.PLOT_MOUNTAIN then
						plotTypes[k + 1] = PlotTypes.PLOT_HILLS;
						demoted = demoted + 1;
						changed = true;
						break;
					end
				end
			end
		end
	end
	if LekPipelineFlow then LekPipelineFlow("central_volcano_mtn_clear", "demoted=" .. tostring(demoted)); end
	return demoted;
end

------------------------------------------------------------------------------
-- Island vegetation (both shapes): on every landmass that is not the mainland, LEK_ISLAND_VEG_PCT of the
-- bare flat/hill tiles get forest, or jungle (on plains) in the tropical band. Snow, desert, mountains,
-- natural wonders and the central volcano island (own jungle rule) are skipped. Runs after AddFeatures.
------------------------------------------------------------------------------
LEK_ISLAND_VEG_PCT = 80;
LEK_ISLAND_JUNGLE_BAND = 0.36;  -- |latitude| as a share of the half map height that counts as tropical

function LekIslandVegetation()
	local main = Map.FindBiggestArea(false);
	if not main then return; end
	local mainId = main:GetID();
	local iW, iH = Map.GetGridSize();
	local central = {};
	for _, k in ipairs(_lek_central_volcano_island or {}) do central[k] = true; end
	local eq = (iH - 1) / 2;
	local forest, jungle = 0, 0;
	for y = 0, iH - 1 do
		local tropical = math.abs(y - eq) / (iH / 2) <= LEK_ISLAND_JUNGLE_BAND;
		for x = 0, iW - 1 do
			local plot = Map.GetPlot(x, y);
			if plot and not plot:IsWater() and not plot:IsMountain() and plot:GetArea() ~= mainId
				and not central[y * iW + x] and plot:GetFeatureType() == FeatureTypes.NO_FEATURE then
				local tt = plot:GetTerrainType();
				local green = (tt == TerrainTypes.TERRAIN_GRASS or tt == TerrainTypes.TERRAIN_PLAINS);
				if (green or tt == TerrainTypes.TERRAIN_TUNDRA) and Map.Rand(100, "lek_island_veg") < LEK_ISLAND_VEG_PCT then
					if tropical and green then
						if tt ~= TerrainTypes.TERRAIN_PLAINS then plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, true); end
						plot:SetFeatureType(FeatureTypes.FEATURE_JUNGLE, -1);
						jungle = jungle + 1;
					else
						plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
						forest = forest + 1;
					end
				end
			end
		end
	end
	if LekPipelineFlow then LekPipelineFlow("island_vegetation", "forest=" .. tostring(forest) .. " jungle=" .. tostring(jungle)); end
end

------------------------------------------------------------------------------
-- Island map (channel islandmap): Logs/LekmapIslandMap.log, overwritten per map (= the map currently open).
-- Every island tile with the island type that painted it, plus all non-mainland land.
-- Lookup: grep "xy=X,Y " (Civ plot coords, 0,0 = bottom-left).
------------------------------------------------------------------------------
function LekDumpIslandMap()
	if not (LekMapgenChannelEnabled and LekMapgenChannelEnabled("islandmap")) then
		return;
	end
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local n = iW * iH;
	local land = {};
	for k = 0, n - 1 do
		land[k] = not Map.GetPlotByIndex(k):IsWater();
	end
	-- Final landmasses; mainland = biggest.
	local comp, best, bestN = {}, nil, 0;
	for k = 0, n - 1 do
		if land[k] and comp[k] == nil then
			local q, h = { k }, 1;
			comp[k] = k;
			while h <= #q do
				local x, y = q[h] % iW, math.floor(q[h] / iW);
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local nk = ny * iW + nx;
						if land[nk] and comp[nk] == nil then
							comp[nk] = k;
							q[#q + 1] = nk;
						end
					end
				end
				h = h + 1;
			end
			if #q > bestN then bestN = #q; best = k; end
		end
	end
	local function xy(k) return tostring(k % iW) .. "," .. tostring(math.floor(k / iW)); end
	local function where(k)
		if not land[k] then return "water_now"; end
		return (comp[k] == best) and "mainland" or "island";
	end

	local srcOf = {};
	local lines = {};
	lines[#lines + 1] = "### LekIslandMap BEGIN date=" .. ((os and os.date) and os.date("%Y-%m-%d %H:%M:%S") or "?")
		.. " runId=" .. tostring(_lek_run_id or "na")
		.. " shape=" .. tostring(_lek_pangaea_land_shape or "na")
		.. " W=" .. tostring(iW) .. " H=" .. tostring(iH);
	local function sourceLine(label, tiles, extra)
		local parts, nowLand, merged = {}, 0, 0;
		for _, k in ipairs(tiles) do
			parts[#parts + 1] = xy(k);
			srcOf[k] = srcOf[k] or label;
			if land[k] then
				nowLand = nowLand + 1;
				if comp[k] == best then merged = merged + 1; end
			end
		end
		-- One placement can paint several separate pieces (e.g. splintered types): list their sizes.
		local inP, seenP, pieceSizes = {}, {}, {};
		for _, k in ipairs(tiles) do if land[k] then inP[k] = true; end end
		for _, k0 in ipairs(tiles) do
			if inP[k0] and not seenP[k0] then
				local grp, h = { k0 }, 1;
				seenP[k0] = true;
				while h <= #grp do
					local gx, gy = grp[h] % iW, math.floor(grp[h] / iW);
					for d = 1, 6 do
						local nx, ny = GetHexNeighbor(gx, gy, d, iW, iH, wrapX, false);
						local nk = ny * iW + nx;
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH and inP[nk] and not seenP[nk] then
							seenP[nk] = true;
							grp[#grp + 1] = nk;
						end
					end
					h = h + 1;
				end
				pieceSizes[#pieceSizes + 1] = #grp;
			end
		end
		table.sort(pieceSizes, function(p1, p2) return p1 > p2; end);
		lines[#lines + 1] = "### LekIslandMap island src=" .. label
			.. " tilesLandNow=" .. tostring(nowLand) .. "/" .. tostring(#tiles)
			.. " pieces=" .. (#pieceSizes > 0 and table.concat(pieceSizes, "+") or "0")
			.. " onMainland=" .. tostring(merged)
			.. (extra or "")
			.. " tiles=" .. table.concat(parts, ";");
	end
	local track = _lek_island_track;
	if track and track.placements then
		for _, pl in ipairs(track.placements) do
			sourceLine(tostring(pl.type) .. "#" .. tostring(pl.seq), pl.tiles,
				" at=" .. tostring(pl.atX) .. "," .. tostring(pl.atY) .. " carvedWater=" .. tostring(pl.carved));
		end
	else
		lines[#lines + 1] = "### LekIslandMap note=no_island_draft_tracking";
	end
	for i, e in ipairs(_lek_island_extra or {}) do
		-- Split into connected pieces (coastal bonus islands arrive as one batch per map).
		local inE, done = {}, {};
		for _, k in ipairs(e.tiles) do inE[k] = true; end
		local piece = 0;
		for _, k0 in ipairs(e.tiles) do
			if not done[k0] then
				piece = piece + 1;
				local grp, h = { k0 }, 1;
				done[k0] = true;
				while h <= #grp do
					local x, y = grp[h] % iW, math.floor(grp[h] / iW);
					for d = 1, 6 do
						local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, false);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
							local nk = ny * iW + nx;
							if inE[nk] and not done[nk] then
								done[nk] = true;
								grp[#grp + 1] = nk;
							end
						end
					end
					h = h + 1;
				end
				sourceLine(tostring(e.type) .. "#x" .. tostring(i) .. "." .. tostring(piece), grp, nil);
			end
		end
	end
	-- Bays carved from the pangaea edge (depth = steps inland from the pre-bay coast).
	local baySrc = {};
	for bi, b in ipairs(_lek_bay_track or {}) do
		local parts, nowWater = {}, 0;
		for _, k in ipairs(b.tiles) do
			parts[#parts + 1] = xy(k);
			baySrc[k] = "bay#" .. tostring(bi);
			if not land[k] then nowWater = nowWater + 1; end
		end
		lines[#lines + 1] = "### LekIslandMap bay src=bay#" .. tostring(bi)
			.. " kind=" .. (b.opens and "bay" or "inland_puddle")
			.. " carved=" .. tostring(#b.tiles) .. " waterNow=" .. tostring(nowWater)
			.. " depth=" .. tostring(b.depth)
			.. " tiles=" .. table.concat(parts, ";");
	end
	for k, lbl in pairs(baySrc) do
		if not srcOf[k] then
			lines[#lines + 1] = "### LekIslandMap tile xy=" .. xy(k) .. " src=" .. lbl .. " now=" .. where(k);
		end
	end
	-- Per-tile index: every attributed tile + every non-mainland land tile.
	for k = 0, n - 1 do
		if srcOf[k] or (land[k] and comp[k] ~= best) then
			lines[#lines + 1] = "### LekIslandMap tile xy=" .. xy(k) .. " src=" .. tostring(srcOf[k] or "fractal_or_other")
				.. " now=" .. where(k);
		end
	end
	lines[#lines + 1] = "### LekIslandMap END";
	if LekAppendCiv5Log then
		LekAppendCiv5Log("LekmapIslandMap.log", lines, true);
	end
end

-- Final map (called from LekHB_GenerateMap_Core after StartPlotSystem).
function LekLogFinalLandStats()
	local iW, iH = Map.GetGridSize();
	local pts = {};
	for i = 0, iW * iH - 1 do
		pts[i + 1] = Map.GetPlotByIndex(i):GetPlotType();
	end
	LekLogLandStats("final", pts, iW, iH, Map:IsWrapX(), false);
end

------------------------------------------------------------------------------
local function LekPangaeaProbeLog(msg, minVerb)
	minVerb = minVerb or 2;
	if LekMapgenChannelEnabled then
		if not LekMapgenChannelEnabled("pangaea") then
			return;
		end
	elseif LekMapgenLogsEnabled and not LekMapgenLogsEnabled() then
		return;
	end
	if _lek_mapgen_world_is_small == true and minVerb < 3 then
		minVerb = 3;
	end
	if LekMapgenLogAtLeast and not LekMapgenLogAtLeast(minVerb) then
		return;
	end
	print(msg);
	pcall(function()
		if LekMapgenDiagLogAppend then
			LekMapgenDiagLogAppend({ msg });
		end
	end);
end

-- Outer-loop reject: row land < thinMax with rows at y±2 both > thickMin (horizontal water sliver).
local function LekPangaeaWaterSliceReject(plotTypes, iW, iH, thinMax, thickMin)
	if not plotTypes or type(iW) ~= "number" or type(iH) ~= "number" or iH < 5 then
		return false;
	end
	thinMax = thinMax or 10;
	thickMin = thickMin or 18;
	local rowN = {};
	for y = 0, iH - 1 do
		local n = 0;
		for x = 0, iW - 1 do
			if plotTypes[y * iW + x + 1] ~= PlotTypes.PLOT_OCEAN then
				n = n + 1;
			end
		end
		rowN[y] = n;
	end
	for y = 2, iH - 3 do
		if rowN[y] < thinMax and rowN[y - 2] > thickMin and rowN[y + 2] > thickMin then
			LekPangaeaProbeLog("### LekPangaea waterSliceReject row=" .. tostring(y)
				.. " land=" .. tostring(rowN[y])
				.. " rowN_y-2=" .. tostring(rowN[y - 2])
				.. " rowN_y+2=" .. tostring(rowN[y + 2])
				.. " thinMax=" .. tostring(thinMax) .. " thickMin=" .. tostring(thickMin), 1);
			return true;
		end
	end
	return false;
end

function PangaeaFractalWorld:GeneratePlotTypes(args)

		if LekPipelineFlow then LekPipelineFlow("PangaeaFractalWorld_GeneratePlotTypes_entry"); end
	if(args == nil) then args = {}; end
	_lek_pangaea_max_outer_failed = false;
	_lek_inland_sea_plots = nil;
	_lek_central_sea_plots = nil;
	_lek_island_extra = {};
	_lek_bay_track = nil;

	local allcomplete = false;
	local outerAttempts = 0;
	local MAX_OUTER = 50;

	while allcomplete == false do
		outerAttempts = outerAttempts + 1;

		if LekPipelineFlow then LekPipelineFlow("outer_attempt_begin"); end
		_lek_pangaea_outer_attempt = outerAttempts;
		if not _lek_mapgen_world_is_small then
			if LekMapgenPrint then LekMapgenPrint("### Pangaea attempt " .. outerAttempts .. "/" .. MAX_OUTER .. " ###"); end
		end
		if outerAttempts > MAX_OUTER then
			_lek_pangaea_max_outer_failed = true;
			print("########################################################################");
			print("[Lekmap] Pangaea failed: " .. tostring(MAX_OUTER) .. " redraws, land/islands check never passed.");
			print("Game will load with NO major starting plots — everyone dead on spawn (intentional fail).");
			print("########################################################################");
			LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe outcome=max_outer_no_starts outerAttempts=" .. tostring(outerAttempts), 1);
			break;
		end

		local tPass0 = (os and os.clock) and os.clock() or 0;
		local laProbe = _lek_map_layout_attempt or 0;

		local sea_level_low = 64;
		local sea_level_normal = 67;
		local sea_level_high = 70;
		local world_size_for_sea = Map.GetWorldSize();
		if world_size_for_sea == GameInfo.Worlds.WORLDSIZE_SMALL.ID then
			-- Small canvas (reduced X): lower water threshold to keep comparable pangaea mass.
			sea_level_low = 54;
			sea_level_normal = 57;
			sea_level_high = 60;
			-- Fractal Pangaea: one point less water than Ring (measured ~+3.5% mainland on the 44x52 Small canvas:
			-- ~1101 vs ~1073 tiles at 57). Ring keeps 54/57/60.
			if LekLandmass_IsFractalPangaea and LekLandmass_IsFractalPangaea() then
				sea_level_low = 53;
				sea_level_normal = 56;
				sea_level_high = 59;
			end
		end
		local world_age_old = 3;
		local world_age_normal = 4;
		local world_age_new = 5;
		--
		local extra_mountains = 4;
		local grain_amount = 0;
		local adjust_plates = 1.3;
		local shift_plot_types = true;
		local tectonic_islands = true;
		local hills_ridge_flags = self.iFlags;
		local peaks_ridge_flags = self.iFlags;
		local has_center_rift = true;
		local adjadj = 1.2;
		local xshift = 0;
		local yshift = 0;
		local yshiftamt = 0;
		local xshiftamt = 0;
		local xstart, xend = 0,0;
		local ystart, yend = 0,0;

		local sea_level = LekMapGetCustomOption(4)
		if sea_level == 4 then
			sea_level = 1 + Map.Rand(3, "Random Sea Level - Lua");
		end
		local world_age = LekMapGetCustomOption(1)
		if world_age == 5 then
			world_age = 1 + Map.Rand(3, "Random World Age - Lua");
		end

		-- Set Sea Level according to user selection.
		local water_percent = sea_level_normal;
		local fjorddistmodif = _lek_fjord_distance_setting_fixed;
		local fjordlengthmodif = _lek_fjord_length_setting_fixed;
		local fjordmodif = (fjorddistmodif - 1) * (fjordlengthmodif + 1);
		if sea_level == 1 then -- Low Sea Level
			water_percent = sea_level_low
		elseif sea_level == 3 then -- High Sea Level
			water_percent = sea_level_high
		else -- Normal Sea Level
		
		end
		water_percent = water_percent - math.floor(fjordmodif / 10);
		_lek_last_water_percent = water_percent;
		
		-- Set values for hills and mountains according to World Age chosen by user.
		local adjustment = world_age_normal;
		if world_age == 4 then -- No Moutains
			adjustment = world_age_old;
			adjust_plates = adjust_plates * 0.5;
		elseif world_age == 3 then -- 5 Billion Years
			adjustment = world_age_old;
			adjust_plates = adjust_plates * 0.5;
		elseif world_age == 1 then -- 3 Billion Years
			adjustment = world_age_new;
			adjust_plates = adjust_plates * 1;
		else -- 4 Billion Years
		end
		-- Apply adjustment to hills and peaks settings.
		local hillsBottom1 = 26 - (adjustment * adjadj);
		local hillsTop1 = 26 + (adjustment * adjadj);
		local hillsBottom2 = 72 - (adjustment * adjadj);
		local hillsTop2 = 72 + (adjustment * adjadj);
		local hillsClumps = 1 + (adjustment * adjadj);
		local hillsNearMountains = 91 - (adjustment * 2) - extra_mountains;
		local mountains = 95 - adjustment - extra_mountains;
	
		if world_age == 4 then
			mountains = 300 - adjustment - extra_mountains;
		end

		-- Hills and Mountains handled differently according to map size - Bob
		local WorldSizeTypes = {};
		for row in GameInfo.Worlds() do
			WorldSizeTypes[row.Type] = row.ID;
		end
		local sizekey = Map.GetWorldSize();
		-- Fractal Grains
		local sizevalues = {
			[WorldSizeTypes.WORLDSIZE_DUEL]     = 3,
			[WorldSizeTypes.WORLDSIZE_TINY]     = 3,
			[WorldSizeTypes.WORLDSIZE_SMALL]    = 3,
			[WorldSizeTypes.WORLDSIZE_STANDARD] = 3,
			[WorldSizeTypes.WORLDSIZE_LARGE]    = 3,
			[WorldSizeTypes.WORLDSIZE_HUGE]		= 3
		};
		local grain = sizevalues[sizekey] or 3;
		-- Tectonics Plate Counts
		local platevalues = {
			[WorldSizeTypes.WORLDSIZE_DUEL]		= 100,
			[WorldSizeTypes.WORLDSIZE_TINY]     = 100,
			[WorldSizeTypes.WORLDSIZE_SMALL]    = 100,
			[WorldSizeTypes.WORLDSIZE_STANDARD] = 100,
			[WorldSizeTypes.WORLDSIZE_LARGE]    = 100,
			[WorldSizeTypes.WORLDSIZE_HUGE]     = 100
		};
		local numPlates = platevalues[sizekey] or 5;
		-- Add in any plate count modifications passed in from the map script. - Bob
		numPlates = numPlates * adjust_plates;

		-- Generate continental fractal layer and examine the largest landmass. Reject
		-- the result until the largest landmass occupies 90% or more of the total land.
		local bMapOK = false;
		local middleAttempts = 0;
		local MAX_MIDDLE = 200;
		local ringSkipMargin = false;
		if LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing() then

		if LekPipelineFlow then LekPipelineFlow("landmass_branch_equator_ring"); end
			local ringEnv = {
				water_percent = water_percent,
				grain = grain,
				numPlates = numPlates,
				adjustment = adjustment,
				hills_ridge_flags = hills_ridge_flags,
				peaks_ridge_flags = peaks_ridge_flags,
				hillsBottom1 = hillsBottom1,
				hillsTop1 = hillsTop1,
				hillsBottom2 = hillsBottom2,
				hillsTop2 = hillsTop2,
				hillsClumps = hillsClumps,
				hillsNearMountains = hillsNearMountains,
				mountains = mountains,
			};
			local ringRes = LekLandmass_EquatorRing_Build(self, ringEnv);
			if ringRes and ringRes.ok then
				xshift = ringRes.xshift or 0;
				yshift = ringRes.yshift or 0;
				xshiftamt = ringRes.xshiftamt or 0;
				yshiftamt = ringRes.yshiftamt or 0;
				ringSkipMargin = ringRes.skipMarginClear == true;
				xstart, xend = 0, self.iNumPlotsX - 1;
				ystart, yend = 0, self.iNumPlotsY - 1;
				bMapOK = true;
				print("[PangaeaRing] equator ring mainland accepted");
			else
				print("[PangaeaRing] equator ring build failed; outer will redraw");
				bMapOK = true; -- leave middle; outer land-% check will fail and redraw
				ringSkipMargin = true;
			end
		else
		while bMapOK == false do

		if LekPipelineFlow then LekPipelineFlow("landmass_branch_fractal_pangaea"); end
			middleAttempts = middleAttempts + 1;
			if middleAttempts >= MAX_MIDDLE then
				print("[Pangaea] MAX_MIDDLE reached, accepting last draw");
			end
			local done = false;
			local iAttempts = 0;
			local MAX_INNER = 50;
			local iWaterThreshold, biggest_area, iNumTotalLandTiles, iNumBiggestAreaTiles, iBiggestID;
			while done == false do
				local grain_dice = Map.Rand(7, "Continental Grain roll - LUA Pangaea");
				if grain_dice < 4 then
					grain_dice = 1;
				else
					grain_dice = 2;
				end
				local rift_dice = Map.Rand(3, "Rift Grain roll - LUA Pangaea");
				if rift_dice < 1 then
					rift_dice = -1;
				end

				rift_dice = -1;
				grain_dice = 7;

				self.continentsFrac = nil;
				self:InitFractal{continent_grain = grain_dice, rift_grain = rift_dice};
				iWaterThreshold = self.continentsFrac:GetHeight(water_percent);
		
				iNumTotalLandTiles = 0;
				for x = 0, self.iNumPlotsX - 1 do
					for y = 0, self.iNumPlotsY - 1 do
						local i = y * self.iNumPlotsX + x + 1;
						local val = self.continentsFrac:GetHeight(x, y);
						if(val <= iWaterThreshold) then
							self.plotTypes[i] = PlotTypes.PLOT_OCEAN;
						else
							self.plotTypes[i] = PlotTypes.PLOT_LAND;
							iNumTotalLandTiles = iNumTotalLandTiles + 1;
						end
					end
				end

				SetPlotTypes(self.plotTypes);
				Map.RecalculateAreas();
		
				biggest_area = Map.FindBiggestArea(false);
				iNumBiggestAreaTiles = biggest_area:GetNumTiles();
				-- Now test the biggest landmass to see if it is large enough.
				if iNumBiggestAreaTiles >= iNumTotalLandTiles * 1 then
					done = true;
					iBiggestID = biggest_area:GetID();
				end
				iAttempts = iAttempts + 1;
				if iAttempts >= MAX_INNER then
					done = true;
					iBiggestID = biggest_area:GetID();
					print("[Pangaea] MAX_INNER reached, accepting best landmass");
				end

				--[[--Printout for debug use only
				print("-"); print("--- Pangaea landmass generation, Attempt#", iAttempts, "---");
				print("- This attempt successful: ", done);
				print("- Total Land Plots in world:", iNumTotalLandTiles);
				print("- Land Plots belonging to biggest landmass:", iNumBiggestAreaTiles);
				print("- Percentage of land belonging to Pangaea: ", 100 * iNumBiggestAreaTiles / iNumTotalLandTiles);
				print("- Continent Grain for this attempt: ", grain_dice);
				print("- Rift Grain for this attempt: ", rift_dice);
				print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
				print(".");--]]
		
			end

			-- Generate fractals to govern hills and mountains
			self.hillsFrac = Fractal.Create(self.iNumPlotsX, self.iNumPlotsY, grain, self.iFlags, self.fracXExp, self.fracYExp);
			self.mountainsFrac = Fractal.Create(self.iNumPlotsX, self.iNumPlotsY, grain, self.iFlags, self.fracXExp, self.fracYExp);
			self.hillsFrac:BuildRidges(numPlates, hills_ridge_flags, 1, 2);
			self.mountainsFrac:BuildRidges((numPlates * 2) / 3, peaks_ridge_flags, 6, 1);
			-- Get height values
			local iHillsBottom1 = self.hillsFrac:GetHeight(hillsBottom1);
			local iHillsTop1 = self.hillsFrac:GetHeight(hillsTop1);
			local iHillsBottom2 = self.hillsFrac:GetHeight(hillsBottom2);
			local iHillsTop2 = self.hillsFrac:GetHeight(hillsTop2);
			local iHillsClumps = self.mountainsFrac:GetHeight(hillsClumps);
			local iHillsNearMountains = self.mountainsFrac:GetHeight(hillsNearMountains);
			local iMountainThreshold = self.mountainsFrac:GetHeight(mountains);
			local iPassThreshold = self.hillsFrac:GetHeight(hillsNearMountains);
			-- Get height values for tectonic islands
			local iMountain100 = self.mountainsFrac:GetHeight(100);
			local iMountain99 = self.mountainsFrac:GetHeight(99);
			local iMountain97 = self.mountainsFrac:GetHeight(97);
			local iMountain95 = self.mountainsFrac:GetHeight(95);

			-- Because we haven't yet shifted the plot types, we will not be able to take advantage 
			-- of having water and flatland plots already set. We still have to generate all data
			-- for hills and mountains, too, then shift everything, then set plots one more time.
			for x = 0, self.iNumPlotsX - 1 do
				for y = 0, self.iNumPlotsY - 1 do
		
					local i = y * self.iNumPlotsX + x + 1;
					local val = self.continentsFrac:GetHeight(x, y);
					local mountainVal = self.mountainsFrac:GetHeight(x, y);
					local hillVal = self.hillsFrac:GetHeight(x, y);
	
					if(val <= iWaterThreshold) then
						self.plotTypes[i] = PlotTypes.PLOT_OCEAN;
				
						if tectonic_islands then -- Build islands in oceans along tectonic ridge lines - Brian
							if (mountainVal == iMountain100) then -- Isolated peak in the ocean
								self.plotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
							elseif (mountainVal == iMountain99) then
								self.plotTypes[i] = PlotTypes.PLOT_HILLS;
							elseif (mountainVal == iMountain97) or (mountainVal == iMountain95) then
								self.plotTypes[i] = PlotTypes.PLOT_LAND;
							end
						end
					
					else
						if (mountainVal >= iMountainThreshold) then
							if (hillVal >= iPassThreshold) then -- Mountain Pass though the ridgeline - Brian
								self.plotTypes[i] = PlotTypes.PLOT_HILLS;
							else -- Mountain
								-- set some randomness to mountains next to each other
								local iIsMount = Map.Rand(100, "Mountain Spawn Chance");
								--print("-"); print("Mountain Spawn Chance: ", iIsMount);
								local iIsMountAdj = 48 - adjustment;
								if iIsMount >= iIsMountAdj then
									self.plotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
								else
									-- set some randomness to hills or flat land next to the mountain
									local iIsHill = Map.Rand(100, "Hill Spawn Chance");
									--print("-"); print("Mountain Spawn Chance: ", iIsMount);
									local iIsHillAdj = 30 - adjustment;
									if iIsHill >= iIsHillAdj then
										self.plotTypes[i] = PlotTypes.PLOT_HILLS;
									else
										self.plotTypes[i] = PlotTypes.PLOT_LAND;
									end
								end
							end
						elseif (mountainVal >= iHillsNearMountains) then
							self.plotTypes[i] = PlotTypes.PLOT_HILLS; -- Foot hills - Bob
						else
							if ((hillVal >= iHillsBottom1 and hillVal <= iHillsTop1) or (hillVal >= iHillsBottom2 and hillVal <= iHillsTop2)) then
								self.plotTypes[i] = PlotTypes.PLOT_HILLS;
							else
								self.plotTypes[i] = PlotTypes.PLOT_LAND;
							end
						end
					end
				end
			end

			self:ShiftPlotTypes();
	
			--#####################
		



			--check landmass
			local iW, iH = Map.GetGridSize();
			local bfland = false;
			local startcol = 0;
			local cont = 0;
			local bprev = false;
			local biggest = 0;
			local mainstart = 0;
			local mainend = 0;
			local cencol = 0;
			local colshift = 0;
			local landincol = 0;
			local chkstart = 0;
			local chkend = 0;
			local chokepoint = 16;
			local bXChkFail = false;
			local bYChkFail = false;
			local bLastLand = false;
			local contlandincol = 0;
			local xcen = 0;
			local ycen = 0;

			--check y choke points
			print("-----------------------------------");
			print("Checking Y Chokes");
			print("-----------------------------------");
			for x = 1, iW do
				bfland = false;
				landincol = 0;
		
				for y = 2, iH-2  do
					local i = iW * y + x + 1;
					--print("Plot Location = ", i);
					if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
						landincol = landincol + 1;
						bfland = true;
					end
				end
		
				if bfland == false then
					--print("No Land Found in Col: ", x);
					bprev = false;
					if cont > biggest then
						biggest = cont;
						mainstart = startcol;
						mainend = x-1;
					end
					cont = 0;
					startcol = 0;
				else
					--print("Land Found In Col: ", x, "Qty: ", landincol);
					if startcol == 0 then
						startcol = x;
					end
					bprev = true;
					cont = cont + 1;	
				end
			end
		
			xstart = mainstart;
			xend = mainend;

			chkstart = mainstart + 8;
			chkend = mainend -  8;

			local landincol_prev1 = chokepoint;
			local landincol_prev2 = chokepoint;

			for x = chkstart, chkend do
				landincol = 0;
				contlandincol = 0;
				for y = 2, iH-2  do
					local i = iW * y + x + 1;
					--print("Plot Location = ", i);
					if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
					
						if bLastLand == true then
							landincol = landincol + 1;
							bLastLand = true;
						else
							landincol = 1;
							bLastLand = true;
						end
					else
						if contlandincol < landincol then
							contlandincol = landincol;
						end
						bLastLand = false;
						landincol = 0;
					end
				end

				--print("Checking Col:", x, "Continuous Land In Col: ", contlandincol);

				if landincol_prev1 + landincol_prev2 + contlandincol < 3 * chokepoint then
					--print("Choke Point in Col: ", x);
					bXChkFail = true;
				end
				landincol_prev2 = contlandincol;
				landincol_prev1 = landincol_prev2;
			end



			--check x choke points
			print("-----------------------------------");
			print("Checking X Chokes");
			print("-----------------------------------");
			startcol = 0;
			cont = 0;
			biggest = 0;
			for y = 2, iH-2 do
				bfland = false;
				landincol = 0;
		
				for x = 1, iW  do
					local i = iW * y + x;
					--print("Plot Location = ", i);
					if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
						landincol = landincol + 1;
						bfland = true;
					end
				end
		
				if bfland == false then
					--print("No Land Found in Row: ", y);
					bprev = false;
					if cont > biggest then
						biggest = cont;
						mainstart = startcol;
						mainend = y-1;
					end
					cont = 0;
					startcol = 0;
				else
					--print("Land Found In Row: ", y, "Qty: ", landincol);
					if startcol == 0 then
						startcol = y;
					end
					bprev = true;
					cont = cont + 1;	
				end
			end
	
			ystart = mainstart;
			yend = mainend;

			chkstart = mainstart + 5;
			chkend = mainend -  5;
			--print("-----");
			--print("Mainland Start Row: ", chkstart);
			--print("Mainland End Row: ", chkend);
			--print("-----");
			for y = chkstart, chkend do
				landincol = 0;
				contlandincol = 0;
				for x = 1, iW  do
					local i = iW * y + x;
					--print("Plot Location = ", i);
					if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
					
						if bLastLand == true then
							landincol = landincol + 1;
							bLastLand = true;
						else
							landincol = 1;
							bLastLand = true;
						end
					else
						if contlandincol < landincol then
							contlandincol = landincol;
						end
						bLastLand = false;
						landincol = 0;
					end
				end

				--print("Checking Col:", y, "Continuous Land In Col: ", contlandincol);

				if contlandincol < chokepoint then
					--print("Choke Point in Row: ", y);
					bYChkFail = true;
				end
			end



			if bXChkFail == true then
				print("X Check: False");
			else
				print("X Check: True");
			end

			if bYChkFail == true then
				print("Y Check: False");
			else
				print("Y Check: True");
			end

			if LekPipelineFlow then
				LekPipelineFlow("choke_check", "middle=" .. tostring(middleAttempts)
					.. " xFail=" .. (bXChkFail and "1" or "0")
					.. " yFail=" .. (bYChkFail and "1" or "0")
					.. " landCols=" .. tostring(xstart) .. ".." .. tostring(xend)
					.. " landRows=" .. tostring(ystart) .. ".." .. tostring(yend));
			end
			-- Choke check is enforced (keeps the pangaea free of thin necks / 1-tile bridges): redraw until it
			-- passes. MAX_MIDDLE is only a runaway guard; past it the last draw is accepted.
			if (bXChkFail == true or bYChkFail == true) and middleAttempts < MAX_MIDDLE then
				print("##############################################");
				print("Map No Good");
				print("##############################################");
				bMapOK = false;
			else
				print("##############################################");
				print("Map Passes");
				print("##############################################");
				bMapOK = true;
			
				cencol = xstart + ((xend - xstart) / 2);
				colshift = (iW/2)-cencol;
				print("Pangaea X Starts At Col: ", xstart, " And Edns At Col: ", xend);
				print("Center X of Lanmass is at Col: ", cencol, "Shift Need: ", colshift);
				xshiftamt = math.ceil(colshift);
				print("Actual Integer Shift Applied: ", xshiftamt);
				if xshiftamt > 0 then
					xshift = 1;
				elseif xshiftamt < 0 then
					xshift = 2;
				else
					xshift = 0;
				end

				print("##############################################");
				cencol = ystart + ((yend - ystart) / 2);
				colshift = (iH/2)-cencol;
				print("Pangaea Y Starts At Col: ", ystart, " And Edns At Col: ", yend);
				print("Center Y of Lanmass is at Col: ", cencol, "Shift Need: ", colshift);
				yshiftamt = math.ceil(colshift);
				print("Actual Integer Shift Applied: ", yshiftamt);
				print("##############################################");
				if yshiftamt > 0 then
					yshift = 1;
				elseif yshiftamt < 0 then
					yshift = 2;
				else
					yshift = 0;
				end
			end

		

		
		end
		end -- compact vs equator_ring middle generation

		if LekPipelineFlow then LekPipelineFlow("landmass_middle_done"); end
		--####################################################
		--clear area around pangaea (compact only; ring already wraps)
		local iW, iH = Map.GetGridSize();
		if not ringSkipMargin then

		if LekPipelineFlow then LekPipelineFlow("margin_clear_begin"); end
		for x = 0, xstart - 1 do --clear west side of map
			for y = 0, iH - 1 do
				destPlotIndex = iW * y + x + 1;
				self.plotTypes[destPlotIndex] = PlotTypes.PLOT_OCEAN;
			end
		end


		for x = xend + 1, iW - 1 do --clear east side of map
			for y = 0, iH - 1 do
				destPlotIndex = iW * y + x + 1;
				self.plotTypes[destPlotIndex] = PlotTypes.PLOT_OCEAN;
			end
		end

		for y = 0, ystart - 1 do --clear south side of map
			for x = 0, iW - 1 do
				destPlotIndex = iW * y + x + 1;
				self.plotTypes[destPlotIndex] = PlotTypes.PLOT_OCEAN;
			end
		end
	
		for y = yend + 1, iH - 1 do --clear north side of map
			for x = 0, iW - 1 do
				destPlotIndex = iW * y + x + 1;
				self.plotTypes[destPlotIndex] = PlotTypes.PLOT_OCEAN;
			end
		end

		end -- not ringSkipMargin (EW/NS ocean margin clear)

		if LekPipelineFlow then LekPipelineFlow("margin_clear_done"); end
		--map generated now shift to center

		if LekPipelineFlow then LekPipelineFlow("shift_begin"); end		-- Copy-on-shift: read from a scratch snapshot, write plotTypes. Avoids in-place races
		-- and replaces nil/OOB reads (whole-row ocean "slices") with explicit margin ocean.
		local plotCount = iW * iH;
		local shiftScratch = {};
		for si = 1, plotCount do
			shiftScratch[si] = self.plotTypes[si];
		end

		-- x shift first
		if xshift == 1 then --shift east
			print("-----------------------------------");
			print("Shifting East........");
			print("-----------------------------------");

			local dx = math.abs(xshiftamt);
			for y = 0, iH - 1 do
				for x = 0, iW - 1 do
					local destPlotIndex = iW * y + x + 1;
					local sx = x - dx;
					if sx >= 0 then
						local sourcePlotIndex = iW * y + sx + 1;
						self.plotTypes[destPlotIndex] = shiftScratch[sourcePlotIndex] or PlotTypes.PLOT_OCEAN;
					else
						self.plotTypes[destPlotIndex] = PlotTypes.PLOT_OCEAN;
					end
				end
			end
		elseif xshift == 2 then --shift west
			print("-----------------------------------");
			print("Shifting West........");
			print("-----------------------------------");

			local dx = math.abs(xshiftamt);
			for y = 0, iH - 1 do
				for x = 0, iW - 1 do
					local destPlotIndex = iW * y + x + 1;
					local sx = x + dx;
					if sx < iW then
						local sourcePlotIndex = iW * y + sx + 1;
						self.plotTypes[destPlotIndex] = shiftScratch[sourcePlotIndex] or PlotTypes.PLOT_OCEAN;
					else
						self.plotTypes[destPlotIndex] = PlotTypes.PLOT_OCEAN;
					end
				end
			end

		else
			--no shift
		end

		if xshift ~= 0 then
			for si = 1, plotCount do
				shiftScratch[si] = self.plotTypes[si];
			end
		end

		-- now shift y
		if yshift == 1 then --shift north
			print("-----------------------------------");
			print("Shifting North........");
			print("-----------------------------------");

			local dy = math.abs(yshiftamt);
			for y = 0, iH - 1 do
				for x = 0, iW - 1 do
					local destPlotIndex = iW * y + x + 1;
					local sy = y - dy;
					if sy >= 0 then
						local sourcePlotIndex = iW * sy + x + 1;
						self.plotTypes[destPlotIndex] = shiftScratch[sourcePlotIndex] or PlotTypes.PLOT_OCEAN;
					else
						self.plotTypes[destPlotIndex] = PlotTypes.PLOT_OCEAN;
					end
				end
			end

		elseif yshift == 2 then --shift south
			print("-----------------------------------");
			print("Shifting South........");
			print("-----------------------------------");

			local dy = math.abs(yshiftamt);
			for y = 0, iH - 1 do
				for x = 0, iW - 1 do
					local destPlotIndex = iW * y + x + 1;
					local sy = y + dy;
					if sy < iH then
						local sourcePlotIndex = iW * sy + x + 1;
						self.plotTypes[destPlotIndex] = shiftScratch[sourcePlotIndex] or PlotTypes.PLOT_OCEAN;
					else
						self.plotTypes[destPlotIndex] = PlotTypes.PLOT_OCEAN;
					end
				end
			end

		else
			--no shift
		end

		--Fjordgenerator by t0m:

		if LekPipelineFlow then LekPipelineFlow("fjords_begin"); end
		fjord_distance_setting = _lek_fjord_distance_setting_fixed;
		if fjord_distance_setting ~= 1 then
			if fjord_distance_setting == 2 then
				fjord_d = 20;
			elseif fjord_distance_setting == 3 then
				fjord_d = 15;
			elseif fjord_distance_setting == 4 then
				fjord_d = 12;
			elseif fjord_distance_setting == 5 then
				fjord_d = 10;
			elseif fjord_distance_setting == 6 then
				fjord_d = 8;
			else
				fjord_d = 6;
			end
		
			fjord_length_setting = _lek_fjord_length_setting_fixed;
			if fjord_length_setting == 1 then
				fjord_l = 2;
			elseif fjord_length_setting == 2 then
				fjord_l = 3;
			elseif fjord_length_setting == 3 then
				fjord_l = 4;
			elseif fjord_length_setting == 4 then
				fjord_l = 5;
			else
				fjord_l = 6;
			end

			
			y = 9;
			k = 0;
			while (k == 0) -- Starts from bottom left going up. Fjordmaking towards right
			do
				x = 6;
				i = 0;
				while (i == 0)
				do
					local PlotIndex = iW * y + x + 1;
					if self.plotTypes[PlotIndex] ~= PlotTypes.PLOT_OCEAN then
						self.plotTypes[PlotIndex] = PlotTypes.PLOT_OCEAN;
						j = 1;
						while (j < fjord_l - 1 + Map.Rand(3, ""))
						do
							local rdm = Map.Rand(4, "")
							if (y % 2 == 0) then --even, either y increases or decreases, or x increases
								if rdm == 0 then
									y = y + 1;
								elseif rdm == 1 then
									y = y - 1;
								else
									x = x + 1;
								end
							else --odd, x increases by 1 and y increases or decreases by 1
								x = x + 1;
								if rdm == 0 then
									y = y + 1;
								elseif rdm == 1 then
									y = y - 1;
								end
							end
							if x > iW - 18 then
								i = 1;
							end
							local PlotIndex = iW * y + x + 1;
							self.plotTypes[PlotIndex] = PlotTypes.PLOT_OCEAN;
							j = j + 1;
						end
						i = 1;
					else
						x = x + 1;
						if x > iW - 18 then
							i = 1;
						end
					end
				end
				y = y + fjord_d - 2 + Map.Rand(5, "");
				if y > iH - 9 then
					k = 1;
				end
				i = 0;
			end
			y = 9;
			k = 0;
			while (k == 0)	-- Starts from bottom right going up. Fjordmaking towards left
			do
				x = iW - 6;
				i = 0;
				while (i == 0)
				do
					local PlotIndex = iW * y + x + 1;
					if self.plotTypes[PlotIndex] ~= PlotTypes.PLOT_OCEAN then
						self.plotTypes[PlotIndex] = PlotTypes.PLOT_OCEAN;
						j = 1;
						while (j < fjord_l - 1 + Map.Rand(3, ""))
						do
							local rdm = Map.Rand(4, "")
							if (y % 2 == 0) then
								x = x - 1;
								if rdm == 0 then
									y = y + 1;
								elseif rdm == 1 then
									y = y - 1;
								end
							else
								if rdm == 0 then
									y = y + 1;
								elseif rdm == 1 then
									y = y - 1;
								else
									x = x - 1;
								end
							end
							if x < 18 then
								i = 1;
							end
							local PlotIndex = iW * y + x + 1;
							self.plotTypes[PlotIndex] = PlotTypes.PLOT_OCEAN;
							j = j + 1;
						end
						i = 1;
					else
						x = x - 1;
						if x < 18 then
							i = 1;
						end
					end
				end
				y = y + fjord_d - 2 + Map.Rand(5, "");
				if y > iH - 9 then
					k = 1;
				end
				i = 0;
			end
			x = 10;
			k = 0;
			while (k == 0) -- Starts from top left going right. Fjordmaking downwards.
			do
				y = iH - 6;
				i = 0;
				while (i == 0)
				do
					local PlotIndex = iW * y + x + 1;
					if self.plotTypes[PlotIndex] ~= PlotTypes.PLOT_OCEAN then
						self.plotTypes[PlotIndex] = PlotTypes.PLOT_OCEAN;
						j = 1;
						while (j < fjord_l - 1 + Map.Rand(3, ""))
						do
							local rdm = Map.Rand(10, "")
							if (y % 2 == 0) then
								if rdm < 4 then
									y = y - 1;
								elseif rdm > 5 then
									y = y - 1;
									x = x - 1;
								elseif rdm == 4 then
									x = x - 1;
								else
									x = x + 1;
								end
							else
								if rdm < 4 then
									y = y - 1;
								elseif rdm > 5 then
									y = y - 1;
									x = x + 1;
								elseif rdm == 4 then
									x = x - 1;
								else
									x = x + 1;
								end
							end
							if y < 3 then
								i = 1;
							end
							local PlotIndex = iW * y + x + 1;
							self.plotTypes[PlotIndex] = PlotTypes.PLOT_OCEAN;
							j = j + 1;
						end
						i = 1;
					else
						y = y - 1;
						if y < 10 then
							i = 1;
						end
					end
				end
				x = x + fjord_d - 2 + Map.Rand(5, "");
				if x > iW - 10 then
					k = 1;
				end
				i = 0;
			end
			x = 10;
			k = 0;
			while (k == 0) -- Starts from bottom left going right. Fjordmaking upwards.
			do
				y = 6;
				i = 0;
				while (i == 0)
				do
					local PlotIndex = iW * y + x + 1;
					if self.plotTypes[PlotIndex] ~= PlotTypes.PLOT_OCEAN then
						self.plotTypes[PlotIndex] = PlotTypes.PLOT_OCEAN;
						j = 1;
						while (j < fjord_l - 1 + Map.Rand(3, ""))
						do
							local rdm = Map.Rand(10, "")
							if (y % 2 == 0) then
								if rdm < 4 then
									y = y + 1;
								elseif rdm > 5 then
									y = y + 1;
									x = x - 1;
								elseif rdm == 4 then
									x = x - 1;
								else
									x = x + 1;
								end
							else --odd, x increases by 1 and y increases or decreases by 1
								if rdm < 4 then
									y = y + 1;
								elseif rdm > 5 then
									y = y + 1;
									x = x + 1;
								elseif rdm == 4 then
									x = x - 1;
								else
									x = x + 1;
								end
							end
							if y > iH - 9 then
								i = 1;
							end
							local PlotIndex = iW * y + x + 1;
							self.plotTypes[PlotIndex] = PlotTypes.PLOT_OCEAN;
							j = j + 1;
						end
						i = 1;
					else
						y = y + 1;
						if y > iH - 9 then
							i = 1;
						end
					end
				end
				x = x + fjord_d - 2 + Map.Rand(5, "");
				if x > iW - 10 then
					k = 1;
				end
				i = 0;
			end
		end --fjord-process ends

		if LekPipelineFlow then LekPipelineFlow("fjords_done"); end		
		--#####################
		--add bays to the outter edge of the biggest landmass
		--[[
		local baysdone = false;
		local iW, iH = Map.GetGridSize();

		while baysdone == false do
			local x = Map.Rand(iW, "");
			local y = 6 + Map.Rand((iH-12), "");
			local plot = Map.GetPlot(x, y);

			if plot:IsCoastalLand() then
				--add a bay here



				print("----"); print("Bay Added"); print("----");
				baysdone = true;
			end
		end
		--]]
		--#####################


		local iW, iH = Map.GetGridSize();
		-- Compact ellipse "bays" carve assumes a centered blob; on equator_ring it
		-- punches the belt and forces dozens of outer redraws. Skip for ring.
		local skipBays = LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing();
		if skipBays then
			if LekPipelineFlow then LekPipelineFlow("bays_skipped_equator_ring"); end
		else
		local centerX = iW / 2;
		local centerY = iH / 2;
		local fracFlags = {FRAC_POLAR = true};
		local baysFrac = Fractal.Create(iW, iH, 3, fracFlags, -1, -1);

		if LekPipelineFlow then LekPipelineFlow("bays_begin"); end
		local iBaysThreshold = baysFrac:GetHeight(96);  --lakes lavel size
		local axis_list = {0.87, 0.81, 0.75};
		local axis_multiplier = axis_list[sea_level];
		local cohesion_list = {0.36, 0.33, 0.30};
		local cohesion_multiplier = cohesion_list[sea_level] or cohesion_list[2];
		majorAxis = centerX * cohesion_multiplier;
		minorAxis = centerY * cohesion_multiplier;
		majorAxisSquared = majorAxis * majorAxis;
		minorAxisSquared = minorAxis * minorAxis;
		local preBaysPlotTypes = {};
		for i = 1, iW * iH do
			preBaysPlotTypes[i] = self.plotTypes[i];
		end
		for y = 0, iH - 1 do
			for x = 0, iW - 1 do
				local deltaX = x - centerX;
				local deltaY = y - centerY;
				local deltaXSquared = deltaX * deltaX;
				local deltaYSquared = deltaY * deltaY;
				local d = deltaXSquared/majorAxisSquared + deltaYSquared/minorAxisSquared;
				if d > 1 then
					local i = y * iW + x + 1;
					local baysVal = baysFrac:GetHeight(x, y);
					if baysVal >= iBaysThreshold then
						self.plotTypes[i] = PlotTypes.PLOT_OCEAN;
					end
				end
			end
		end
		-- Bays must open broadly to the sea: mouth = carved tiles touching pre-bay water; carved tiles more than
		-- LEK_BAY_MAX_MOUTH_STEPS steps (through the bay) from a mouth become land again. Kills canals that run
		-- along the coast behind a thin peninsula; wide shallow bays are untouched. Inland puddles are left as is.
		do
			local wrapXB = Map:IsWrapX();
			local distB, qB = {}, {};
			for i = 1, iW * iH do
				if self.plotTypes[i] == PlotTypes.PLOT_OCEAN and preBaysPlotTypes[i] ~= PlotTypes.PLOT_OCEAN then
					local k = i - 1;
					for dir = 1, 6 do
						local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), dir, iW, iH, wrapXB, false);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH
							and preBaysPlotTypes[ny * iW + nx + 1] == PlotTypes.PLOT_OCEAN then
							distB[k] = 0;
							qB[#qB + 1] = k;
							break;
						end
					end
				end
			end
			local hB = 1;
			while hB <= #qB do
				local k = qB[hB];
				hB = hB + 1;
				for dir = 1, 6 do
					local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), dir, iW, iH, wrapXB, false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local nk = ny * iW + nx;
						if distB[nk] == nil and self.plotTypes[nk + 1] == PlotTypes.PLOT_OCEAN
							and preBaysPlotTypes[nk + 1] ~= PlotTypes.PLOT_OCEAN then
							distB[nk] = distB[k] + 1;
							qB[#qB + 1] = nk;
						end
					end
				end
			end
			local trimmed = 0;
			for k, d in pairs(distB) do
				if d > LEK_BAY_MAX_MOUTH_STEPS then
					self.plotTypes[k + 1] = preBaysPlotTypes[k + 1];
					trimmed = trimmed + 1;
				end
			end
			if LekPipelineFlow then LekPipelineFlow("bays_trimmed", "tiles=" .. tostring(trimmed)); end
		end
		-- Bay tracking (island map log): carved components, how deep each cuts (steps from the pre-bay
		-- water), and whether it opens to that water (bay) or sits inland (puddle).
		_lek_bay_track = nil;
		if LekMapgenChannelEnabled and LekMapgenChannelEnabled("islandmap") then
			local depth, q = {}, {};
			for i = 1, iW * iH do
				if preBaysPlotTypes[i] == PlotTypes.PLOT_OCEAN then
					depth[i - 1] = 0;
					q[#q + 1] = i - 1;
				end
			end
			local h = 1;
			while h <= #q do
				local k = q[h];
				h = h + 1;
				for dir = 1, 6 do
					local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), dir, iW, iH, Map:IsWrapX(), false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local nk = ny * iW + nx;
						if depth[nk] == nil then
							depth[nk] = depth[k] + 1;
							q[#q + 1] = nk;
						end
					end
				end
			end
			local carved, seenB, bays = {}, {}, {};
			for i = 1, iW * iH do
				if self.plotTypes[i] == PlotTypes.PLOT_OCEAN and preBaysPlotTypes[i] ~= PlotTypes.PLOT_OCEAN then
					carved[i - 1] = true;
				end
			end
			for k0 in pairs(carved) do
				if not seenB[k0] then
					local grp, gh, maxD, opens = { k0 }, 1, 0, false;
					seenB[k0] = true;
					while gh <= #grp do
						local k = grp[gh];
						gh = gh + 1;
						if (depth[k] or 0) > maxD then maxD = depth[k]; end
						for dir = 1, 6 do
							local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), dir, iW, iH, Map:IsWrapX(), false);
							if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
								local nk = ny * iW + nx;
								if carved[nk] and not seenB[nk] then
									seenB[nk] = true;
									grp[#grp + 1] = nk;
								elseif preBaysPlotTypes[nk + 1] == PlotTypes.PLOT_OCEAN then
									opens = true;
								end
							end
						end
					end
					table.sort(grp);
					bays[#bays + 1] = { tiles = grp, depth = maxD, opens = opens };
				end
			end
			table.sort(bays, function(a, b) return a.tiles[1] < b.tiles[1]; end);
			_lek_bay_track = bays;
		end
		if _lek_bay_track then
			local nb, np, carvedT, depths = 0, 0, 0, {};
			for _, b in ipairs(_lek_bay_track) do
				carvedT = carvedT + #b.tiles;
				if b.opens then
					nb = nb + 1;
					depths[#depths + 1] = b.depth;
				else
					np = np + 1;
				end
			end
			table.sort(depths, function(a, b) return a > b; end);
			LekLandStatsLog("### LekBays bays=" .. tostring(nb) .. " inlandPuddles=" .. tostring(np)
				.. " carvedTiles=" .. tostring(carvedT) .. " bayDepths=" .. table.concat(depths, ","));
		end

		do
			local function idx1(x, y, w)
				return y * w + x + 1;
			end
			local function bfsFarthest(startX, startY, member, w, h, wrapX)
				local dist = {};
				local q = {};
				local head, tail = 1, 1;
				local sk = startX .. "," .. startY;
				dist[sk] = 0;
				q[1] = { startX, startY };
				local bestK, bestD = sk, 0;
				while head <= tail do
					local cx, cy = q[head][1], q[head][2];
					head = head + 1;
					local dk = dist[cx .. "," .. cy];
					for dir = 1, 6 do
						local nx, ny = GetHexNeighbor(cx, cy, dir, w, h, wrapX, false);
						if nx >= 0 and nx < w and ny >= 0 and ny < h then
							local ii = idx1(nx, ny, w);
							if member[ii] then
								local nk = nx .. "," .. ny;
								if dist[nk] == nil then
									dist[nk] = dk + 1;
									if dist[nk] > bestD then
										bestD = dist[nk];
										bestK = nk;
									end
									tail = tail + 1;
									q[tail] = { nx, ny };
								end
							end
						end
					end
				end
				local bx, by = bestK:match("^([^,]+),([^,]+)$");
				return tonumber(bx), tonumber(by), bestD;
			end
			local function bfsDiameter(sx, sy, member, w, h, wrapX)
				local ax, ay = bfsFarthest(sx, sy, member, w, h, wrapX);
				local _, _, diam = bfsFarthest(ax, ay, member, w, h, wrapX);
				return diam;
			end
			local newOcean = {};
			for i = 1, iW * iH do
				if self.plotTypes[i] == PlotTypes.PLOT_OCEAN and preBaysPlotTypes[i] ~= PlotTypes.PLOT_OCEAN then
					newOcean[i] = true;
				end
			end
			local seen = {};
			for i = 1, iW * iH do
				if newOcean[i] and not seen[i] then
					local sy = math.floor((i - 1) / iW);
					local sx = (i - 1) % iW;
					local comp = {};
					local member = {};
					local q = {};
					local qh, qt = 1, 1;
					q[1] = { sx, sy };
					seen[i] = true;
					member[i] = true;
					comp[1] = i;
					while qh <= qt do
						local cx, cy = q[qh][1], q[qh][2];
						qh = qh + 1;
						for dir = 1, 6 do
							local nx, ny = GetHexNeighbor(cx, cy, dir, iW, iH, Map:IsWrapX(), false);
							if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
								local ni = idx1(nx, ny, iW);
								if newOcean[ni] and not seen[ni] then
									seen[ni] = true;
									member[ni] = true;
									comp[#comp + 1] = ni;
									qt = qt + 1;
									q[qt] = { nx, ny };
								end
							end
						end
					end
					local nComp = #comp;
					if nComp >= 6 and nComp <= 22 then
						local diam = bfsDiameter(sx, sy, member, iW, iH, Map:IsWrapX());
						if diam <= 7 and Map.Rand(100, "") < 68 then
							local want = 2 + Map.Rand(4, "");
							want = math.min(want, nComp);
							local chosen = {};
							local seedIdx = comp[1 + Map.Rand(nComp, "")];
							chosen[seedIdx] = true;
							self.plotTypes[seedIdx] = (Map.Rand(100, "") < 65) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
							local added = 1;
							while added < want do
								local found = nil;
								for _, ci in ipairs(comp) do
									if chosen[ci] then
										local cyy = math.floor((ci - 1) / iW);
										local cxx = (ci - 1) % iW;
										for dir = 1, 6 do
											local nx, ny = GetHexNeighbor(cxx, cyy, dir, iW, iH, Map:IsWrapX(), false);
											if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
												local ni = idx1(nx, ny, iW);
												if member[ni] and not chosen[ni] then
													found = ni;
													break;
												end
											end
										end
										if found then break; end
									end
								end
								if not found then break; end
								chosen[found] = true;
								self.plotTypes[found] = (Map.Rand(100, "") < 65) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
								added = added + 1;
							end
						end
					end
				end
			end
		end
		end -- skipBays else (compact ellipse bay carve)

		-- Round thin inland seas (elongated from BuildRidges) so center can fit islands.
		local tBeforeRoundInland = (os and os.clock) and os.clock() or 0;
		LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe outer=" .. tostring(outerAttempts)
			.. " layoutAttempt=" .. tostring(laProbe)
			.. " preRoundInlandSeas_dt=" .. tostring(tBeforeRoundInland - tPass0), 2);
		-- Equator ring: solid belt has no enclosed ocean — seed 0–2 landlocked pockets first.
		if LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing()
			and LekLandmass_EquatorRing_SeedInlandSeas then
			LekLandmass_EquatorRing_SeedInlandSeas(self);
		end
		if LekInlandSeaCurationActive() then
			-- Fractal Pangaea: incidental puddles stay as drawn; maybe paint one central sea instead.
			LekPaintCentralInlandSea(self);
		else
			RoundInlandSeas(self);
		end

		if LekPipelineFlow then LekPipelineFlow("round_inland_seas_done"); end
		local tAfterRoundInland = (os and os.clock) and os.clock() or 0;
		LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe outer=" .. tostring(outerAttempts)
			.. " layoutAttempt=" .. tostring(laProbe)
			.. " roundInlandSeas_dt=" .. tostring(tAfterRoundInland - tBeforeRoundInland), 2);

		local tM0 = (os and os.clock) and os.clock() or 0;
		local nDem = LekDemoteMountainsTouchingOcean(self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, Map:IsWrapX(), false, 0);
		local tM1 = (os and os.clock) and os.clock() or 0;
		LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe demoteOceanAdjMountains_pct=0 n=" .. tostring(nDem)
			.. " dt=" .. tostring(tM1 - tM0), 2);

		local islandsOpt = LekMapGetCustomOption(16);
		local minIslands = (islandsOpt and islandsOpt > 1) and (islandsOpt - 1) or 0;
		local islandGenOpts = nil;
		if minIslands == 0 then
			islandGenOpts = { budgetRetry = false };
		end
		-- Ring: lobby island-count min does not apply until we opt in via policy.minPlaced.
		if LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing() then
			local pol = LekIslands_GetEquatorRingPolicy and LekIslands_GetEquatorRingPolicy();
			if pol and type(pol.minPlaced) == "number" then
				minIslands = pol.minPlaced;
			else
				minIslands = 0;
			end
			islandGenOpts = { budgetRetry = false };
		end

		local islandsPlaced = 0;
		local islandsBudgetOk = true;
		local tIs0 = (os and os.clock) and os.clock() or 0;
		-- Ring pangaea-draft off via LekIslands_GetEquatorRingPolicy().channels.pangaeaDraft;
		-- coastal bonus + inland spray stay outside GeneratePangaeaIslands.
		local ok, retPlaced, retBudgetOk = pcall(GeneratePangaeaIslands, self, islandGenOpts);

		if LekPipelineFlow then LekPipelineFlow("islands_pcall_returned"); end
		local tIs1 = (os and os.clock) and os.clock() or 0;
		LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe outer=" .. tostring(outerAttempts)
			.. " layoutAttempt=" .. tostring(laProbe)
			.. " generatePangaeaIslands_dt=" .. tostring(tIs1 - tIs0)
			.. " islandsOk=" .. (ok and "1" or "0"), 1);
		if not ok then
			if LekMapgenPrint then LekMapgenPrint("### GeneratePangaeaIslands ERROR (islands skipped): " .. tostring(retPlaced) .. " ###"); end
			if LekPipelineFlow then LekPipelineFlow("islands_error", tostring(retPlaced)); end
			islandsPlaced = 0;
			islandsBudgetOk = false;
		else
			islandsPlaced = tonumber(retPlaced) or 0;
			islandsBudgetOk = (retBudgetOk ~= false);
			-- Shore specks: extra tiny islands / strips one water tile off the mainland (outside the budget).
			if islandsBudgetOk and LekPlaceShoreSpecks and LekIslands_ResolvePolicy then
				local okS, errS = pcall(LekPlaceShoreSpecks, self, LekIslands_ResolvePolicy(nil));
				if not okS and LekPipelineFlow then LekPipelineFlow("shore_specks_error", tostring(errS)); end
			end
			-- The island engine resets island NW markers each run; re-point them at the central peak.
			if LekApplyCentralVolcanoWonder then LekApplyCentralVolcanoWonder(); end
		end

		--check to make sure map has not failed
		local iNumLandTilesInUse = 0;
		local iW, iH = Map.GetGridSize();
		local landFloorFrac = 0.40;
		local iPercent = (iW * iH) * landFloorFrac;

		for y = 0, iH - 1 do
			for x = 0, iW - 1 do
				local i = iW * y + x + 1;
				if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
					iNumLandTilesInUse = iNumLandTilesInUse + 1;
				end
			end
		end

		if not _lek_mapgen_world_is_small then
			print("######### Map Failure Check #########");
			print(tostring(math.floor(landFloorFrac * 100)) .. "% Of Map Area: ", iPercent);
			print("Map Land Tiles: ", iNumLandTilesInUse);
			print("Islands Placed: ", islandsPlaced, "(min ", minIslands, " required)", " budgetOk=", tostring(islandsBudgetOk));
		end

		local tPass1 = (os and os.clock) and os.clock() or 0;
		local waterSliceBad = false;
		if not (LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing()) then
			waterSliceBad = LekPangaeaWaterSliceReject(self.plotTypes, iW, iH, 10, 18);
		end
		-- Islands: the budget is the rule; the island count is logged only (a few big islands can fill it).
		local basePass = (iNumLandTilesInUse >= iPercent and islandsBudgetOk);
		if waterSliceBad and not _lek_mapgen_world_is_small then
			print("######### Map Failure (water-slice heuristic) #########");
		end
		if basePass and not waterSliceBad then
			allcomplete = true;

		if LekPipelineFlow then LekPipelineFlow("outer_pass_ok"); end
			_lek_bench_islands_dt = tIs1 - tIs0;
			if not _lek_mapgen_world_is_small then
				print("######### Map Pass #########");
			end
		else
			if not _lek_mapgen_world_is_small then
				print("######### Map Failure #########");
			end
			if LekPipelineFlow then
				LekPipelineFlow("outer_pass_fail", "land=" .. tostring(iNumLandTilesInUse)
					.. " landFloor=" .. tostring(math.floor(iPercent))
					.. " islands=" .. tostring(islandsPlaced) .. "/" .. tostring(minIslands)
					.. " islandsBudgetOk=" .. (islandsBudgetOk and "1" or "0")
					.. " waterSlice=" .. (waterSliceBad and "1" or "0")
					.. " middleAttempts=" .. tostring(middleAttempts));
			end
		end
		LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe outer=" .. tostring(outerAttempts)
			.. " layoutAttempt=" .. tostring(laProbe)
			.. " outerPassTotal_dt=" .. tostring(tPass1 - tPass0)
			.. " waterSliceReject=" .. (waterSliceBad and "1" or "0")
			.. " mapPass=" .. ((basePass and not waterSliceBad) and "1" or "0"), 2);
	end

	if allcomplete then
		local nClump, nInland = 0, 0;
		-- Equator ring: keep mountain+lake chains intact (no clump / inland-barrier breakers).
		if not (LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing()) then
			nClump = LekBreakLargeMountainComponents(
				self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, Map:IsWrapX(), false, 4);
			nInland = LekBreakMountainInlandWaterBarriers(
				self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, Map:IsWrapX(), false, 3);
		elseif LekPipelineFlow then
			LekPipelineFlow("mtn_breakers_skipped_equator_ring");
		end
		if LekInlandSeaCurationActive() then
			local okR, errR = pcall(LekAddMediumMountainRidges, self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, Map:IsWrapX());
			if not okR and LekPipelineFlow then LekPipelineFlow("ridges_error", tostring(errR)); end
			pcall(LekClearMountainGroupsNearCentralSea, self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, Map:IsWrapX());
		end
		if LekInlandSeaCurationActive() then
			local cs = LekCurateInlandSeas(self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, Map:IsWrapX(), false);
			LekLandStatsLog("### LekInlandSeaCuration stage=plotTypes seas=" .. tostring(cs.seas)
				.. " water=" .. tostring(cs.water)
				.. " gapFilled=" .. tostring(cs.gapFilled)
				.. " spanFilled=" .. tostring(cs.spanFilled)
				.. " secondaryFilled=" .. tostring(cs.secondaryFilled)
				.. " minOceanDist=" .. tostring(LEK_INLAND_SEA_MIN_OCEAN_DIST)
				.. " maxSpan=" .. tostring(LEK_INLAND_SEA_MAX_SPAN));
		end
		local okB, errB = pcall(LekBendHorizontalMountainRuns, self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, Map:IsWrapX());
		if not okB and LekPipelineFlow then LekPipelineFlow("flat_ridges_error", tostring(errB)); end
		LekLogLandStats("plotTypes", self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, Map:IsWrapX(), false);
		LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe islandOuterRegen_summary layoutAttempt=" .. tostring(laProbe)
			.. " outcome=pass outerAttemptsToPass=" .. tostring(outerAttempts)
			.. " outerRedrawsBeforePass=" .. tostring(math.max(0, outerAttempts - 1))
			.. " mtnClumpBreak_demoted=" .. tostring(nClump) .. " maxComp=4"
			.. " mtnInlandBarrier_demoted=" .. tostring(nInland) .. " minMtn=3", 2);
	elseif outerAttempts > MAX_OUTER then
		LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe islandOuterRegen_summary layoutAttempt=" .. tostring(laProbe)
			.. " outcome=max_outer_no_pass outerAttempts=" .. tostring(outerAttempts), 1);
	end

	if LekPipelineFlow then LekPipelineFlow("PangaeaFractalWorld_GeneratePlotTypes_return"); end
	return self.plotTypes;
end

------------------------------------------------------------------------------

------------------------------------------------------------------------------
local function dbg(msg)
	if LekMapgenPrint then
		LekMapgenPrint(msg);
	elseif LekMapgenLogsEnabled and LekMapgenLogsEnabled() then
		print(msg);
	end
end

function GeneratePlotTypes()
	if LekPipelineFlow then LekPipelineFlow("GeneratePlotTypes_entry"); end
	_lek_no_mountain_plots = {};	-- tiles that must never become mountains (filled by island types, read by the ridges pass)
	if not _lek_mapgen_world_is_small then
		dbg("### STAGE: GeneratePlotTypes ENTRY ###");
		dbg("### STAGE: GeneratePlotTypes start ###");
	end
	local laTop = _lek_map_layout_attempt or 0;
	local t0 = (os and os.clock) and os.clock() or 0;
	local fractal_world = PangaeaFractalWorld.Create();

		if LekPipelineFlow then LekPipelineFlow("GeneratePlotTypes_after_Create"); end
	if not _lek_mapgen_world_is_small then
		dbg("### STAGE: fractal created ###");
		dbg("### STAGE: calling fractal_world:GeneratePlotTypes (may take 1-2 min) ###");
	end
	local tF0 = (os and os.clock) and os.clock() or 0;
	local plotTypes = fractal_world:GeneratePlotTypes();

		if LekPipelineFlow then LekPipelineFlow("GeneratePlotTypes_after_world_GeneratePlotTypes"); end
	local tF1 = (os and os.clock) and os.clock() or 0;
	if not _lek_mapgen_world_is_small then
		dbg("### STAGE: plotTypes generated ###");
	end
	local tS0 = (os and os.clock) and os.clock() or 0;
	SetPlotTypes(plotTypes);

		if LekPipelineFlow then LekPipelineFlow("GeneratePlotTypes_after_SetPlotTypes"); end
	local tS1 = (os and os.clock) and os.clock() or 0;
	if not _lek_mapgen_world_is_small then
		dbg("### STAGE: SetPlotTypes done ###");
	end
	Map.RecalculateAreas();
	if LekPipelineFlow then
		local ba = Map.FindBiggestArea(false);
		LekPipelineFlow("GeneratePlotTypes_after_RecalculateAreas",
			ba and ("area=" .. tostring(ba:GetID())) or "no_biggest_area");
	end
	local tC0 = (os and os.clock) and os.clock() or 0;
	GenerateCoasts();

		if LekPipelineFlow then LekPipelineFlow("GeneratePlotTypes_after_GenerateCoasts"); end
	Map.RecalculateAreas();
	local tC1 = (os and os.clock) and os.clock() or 0;
	if not _lek_mapgen_world_is_small then
		dbg("### STAGE: GenerateCoasts done ###");
	end
	_lek_bench_fractal_world_dt = tF1 - tF0;
	_lek_bench_generate_plot_types_lua_total_dt = tC1 - t0;
	LekPangaeaProbeLog("### LekPangaeaPlotTypesProbe layoutAttempt=" .. tostring(laTop)
		.. " fractalWorldGeneratePlotTypes_dt=" .. tostring(tF1 - tF0)
		.. " setPlotTypes_dt=" .. tostring(tS1 - tS0)
		.. " generateCoasts_dt=" .. tostring(tC1 - tC0)
		.. " generatePlotTypes_lua_total_dt=" .. tostring(tC1 - t0), 1);
end
------------------------------------------------------------------------------
function GenerateTerrain()

		if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_entry"); end
	local DesertPercent = 22;

	-- Get Temperature setting input by user.
	local temp = LekMapGetCustomOption(2)
	if temp == 4 then
		temp = 1 + Map.Rand(3, "Random Temperature - Lua");
	end

	local grassMoist = LekMapGetCustomOption(8);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_options", "temp=" .. tostring(temp)); end

	local args = {
			temperature = temp,
			iDesertPercent = DesertPercent,
			iGrassMoist = grassMoist,
			};

	local okCreate, terraingen = pcall(TerrainGenerator.Create, args);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_Create", okCreate and "ok" or tostring(terraingen)); end
	if not okCreate then
		print("### GenerateTerrain TerrainGenerator.Create FAIL " .. tostring(terraingen));
		return;
	end
	_lekmap_terrain_generator = terraingen;

	local okGen, terrainTypesOrErr = pcall(function()
		return terraingen:GenerateTerrain();
	end);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_GenerateTerrain", okGen and "ok" or tostring(terrainTypesOrErr)); end
	if not okGen then
		print("### GenerateTerrain GenerateTerrain FAIL " .. tostring(terrainTypesOrErr));
		return;
	end
	local terrainTypes = terrainTypesOrErr;
	
	SetTerrainTypes(terrainTypes);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_SetTerrainTypes"); end

	-- MOD.EAP: New
	local okFix, errFix = pcall(FixCoastLine);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_FixCoastLine", okFix and "ok" or tostring(errFix)); end
	
	okFix, errFix = pcall(FixIslands);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_FixIslands", okFix and "ok" or tostring(errFix)); end

	okFix, errFix = pcall(FixSolomonsMinesIslandDesert);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_FixSolomons", okFix and "ok" or tostring(errFix)); end

	okFix, errFix = pcall(FixSinaiIslandDesert);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_FixSinai", okFix and "ok" or tostring(errFix)); end

	okFix, errFix = pcall(FixGeothermalIslandSnow);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_FixGeoSnow", okFix and "ok" or tostring(errFix)); end

	okFix, errFix = pcall(FixGeothermalIslandForest);
	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_after_FixGeoForest", okFix and "ok" or tostring(errFix)); end

	if LekPipelineFlow then LekPipelineFlow("GenerateTerrain_done"); end
end

------------------------------------------------------------------------------
function FixGeothermalIslandSnow()
	if not _geothermal_snow_plot_indices then return; end
	local iW, iH = Map.GetGridSize();
	for _, idx in ipairs(_geothermal_snow_plot_indices) do
		local x = (idx - 1) % iW;
		local y = math.floor((idx - 1) / iW);
		local plot = Map.GetPlot(x, y);
		if plot and not plot:IsWater() then
			local pt = plot:GetPlotType();
			if pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS or pt == PlotTypes.PLOT_MOUNTAIN then
				local nearMapEdge = (y <= 4) or (y >= iH - 5);
				if nearMapEdge and pt ~= PlotTypes.PLOT_MOUNTAIN and Map.Rand(100, "") < 48 then
					plot:SetTerrainType(TerrainTypes.TERRAIN_TUNDRA, false, false);
				else
					plot:SetTerrainType(TerrainTypes.TERRAIN_SNOW, false, false);
				end
			end
		end
	end
end

------------------------------------------------------------------------------
function FixGeothermalIslandForest()
	if not _geothermal_forest_ring_indices then return; end
	local iW, _ = Map.GetGridSize();
	for _, idx in ipairs(_geothermal_forest_ring_indices) do
		if Map.Rand(100, "") < 10 then
			local x = (idx - 1) % iW;
			local y = math.floor((idx - 1) / iW);
			local plot = Map.GetPlot(x, y);
			if plot and not plot:IsWater() then
				local pt = plot:GetPlotType();
				if (pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS) and plot:GetFeatureType() == FeatureTypes.NO_FEATURE then
					plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
				end
			end
		end
	end
end

------------------------------------------------------------------------------
function FixSolomonsMinesIslandDesert()
	if not _solomons_island_mines_plot or not GetHexNeighbor then return; end
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map.IsWrapY and Map:IsWrapY() or false;
	local idx = _solomons_island_mines_plot;
	local cx = (idx - 1) % iW;
	local cy = math.floor((idx - 1) / iW);
	local ring1Keys = {};
	local ring1 = {};
	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
			local k = nx .. "," .. ny;
			ring1Keys[k] = true;
			ring1[#ring1 + 1] = { nx, ny };
		end
	end
	for _, p in ipairs(ring1) do
		local plot = Map.GetPlot(p[1], p[2]);
		if plot and not plot:IsWater() then
			local pt = plot:GetPlotType();
			if (pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS) and Map.Rand(100, "") < 80 then
				plot:SetTerrainType(TerrainTypes.TERRAIN_DESERT, false, false);
			end
		end
	end
	local ring2Seen = {};
	for _, p in ipairs(ring1) do
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(p[1], p[2], d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local k = nx .. "," .. ny;
				if (nx ~= cx or ny ~= cy) and not ring1Keys[k] and not ring2Seen[k] then
					ring2Seen[k] = true;
					local plot = Map.GetPlot(nx, ny);
					if plot and not plot:IsWater() then
						local pt = plot:GetPlotType();
						if (pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS) and Map.Rand(100, "") < 20 then
							plot:SetTerrainType(TerrainTypes.TERRAIN_DESERT, false, false);
						end
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------
function FixSinaiIslandDesert()
	if not _sinai_island_plot or not GetHexNeighbor then return; end
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local wrapY = Map.IsWrapY and Map:IsWrapY() or false;
	local idx = _sinai_island_plot;
	local cx = (idx - 1) % iW;
	local cy = math.floor((idx - 1) / iW);
	local ring1Keys = {};
	local ring1 = {};
	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
			local k = nx .. "," .. ny;
			ring1Keys[k] = true;
			ring1[#ring1 + 1] = { nx, ny };
		end
	end
	for _, p in ipairs(ring1) do
		local plot = Map.GetPlot(p[1], p[2]);
		if plot and not plot:IsWater() then
			local pt = plot:GetPlotType();
			if (pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS) and Map.Rand(100, "") < 65 then
				plot:SetTerrainType(TerrainTypes.TERRAIN_DESERT, false, false);
			end
		end
	end
	local ring2Seen = {};
	for _, p in ipairs(ring1) do
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(p[1], p[2], d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local k = nx .. "," .. ny;
				if (nx ~= cx or ny ~= cy) and not ring1Keys[k] and not ring2Seen[k] then
					ring2Seen[k] = true;
					local plot = Map.GetPlot(nx, ny);
					if plot and not plot:IsWater() then
						local pt = plot:GetPlotType();
						if (pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS) and Map.Rand(100, "") < 15 then
							plot:SetTerrainType(TerrainTypes.TERRAIN_DESERT, false, false);
						end
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------
function FixIslands()
	--function to change some of the flat land tundra on islands to plains tiles
	local iW, iH = Map.GetGridSize();
	local biggest_area = Map.FindBiggestArea(false);
	if biggest_area == nil then
		if LekPipelineFlow then LekPipelineFlow("FixIslands_no_biggest_area"); end
		return;
	end
	local iAreaID = biggest_area:GetID();

	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local i = y * iW + x;
			local plot = Map.GetPlotByIndex(i);
			plotAreaID = plot:GetArea();
			if plotAreaID ~= iAreaID then
				local terrainType = plot:GetTerrainType();
				local plotType = plot:GetPlotType();

				if terrainType == TerrainTypes.TERRAIN_TUNDRA then
					if plotType ~= PlotTypes.PLOT_HILLS then
						--give a chance to turn this flat tundra to plains
						local tundratoplains = Map.Rand(100, "Plains Spwan Chance");
						if tundratoplains >= 30 then
							plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, true);
						end
					end
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function FixCoastLine()

	local iW, iH = Map.GetGridSize();
	local biggest_area = Map.FindBiggestArea(false);
	if biggest_area == nil then
		if LekPipelineFlow then LekPipelineFlow("FixCoastLine_no_biggest_area"); end
		return;
	end
	local iAreaID = biggest_area:GetID();

	-- Pass 1: collect all eligible flat coastal tiles.
	local eligible = {};
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local plot = Map.GetPlotByIndex(iW * y + x);
			local pt = plot:GetPlotType();
			if pt == PlotTypes.PLOT_LAND
				and plot:GetArea() == iAreaID
				and plot:IsCoastalLand(8)
				and not plot:IsRiverSide() then
				eligible[y * iW + x] = true;
			end
		end
	end

	local wrapX = Map:IsWrapX();
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			if eligible[y * iW + x] then
				local disk = GetHexDisk(x, y, 2, iW, iH, wrapX, false);
				local landFlats = {};
				local allFlat = true;
				for _, t in ipairs(disk) do
					local px, py = t[1], t[2];
					local p = Map.GetPlot(px, py);
					if p and not p:IsWater() then
						local pt = p:GetPlotType();
						if pt ~= PlotTypes.PLOT_LAND then
							allFlat = false;
							break;
						end
						landFlats[#landFlats + 1] = p;
					end
				end
				if allFlat and #landFlats >= 2 then
					local pick = landFlats[1 + Map.Rand(#landFlats, "")];
					pick:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
				end
			end
		end
	end

	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			if eligible[y * iW + x] then
				local plot = Map.GetPlotByIndex(iW * y + x);
				if plot:GetPlotType() ~= PlotTypes.PLOT_LAND then
				else
					local hillNeighbors = 0;
					for d = 0, 5 do
						local neighbor = Map.PlotDirection(x, y, d);
						if neighbor and neighbor:GetPlotType() == PlotTypes.PLOT_HILLS then
							hillNeighbors = hillNeighbors + 1;
						end
					end
					local threshold;
					if hillNeighbors <= 1 then
						threshold = 20;
					elseif hillNeighbors <= 4 then
						threshold = 80;
					else
						threshold = 101;
					end
					if Map.Rand(100, "") >= threshold then
						plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
					end
				end
			end
		end
	end

end
------------------------------------------------------------------------------
function FixInlandPancakes()
	local iW, iH = Map.GetGridSize();
	local biggest_area = Map.FindBiggestArea(false);
	local iAreaID = biggest_area:GetID();
	local wrapX = Map:IsWrapX();
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local plot = Map.GetPlot(x, y);
			if plot and not plot:IsWater()
				and plot:GetArea() == iAreaID
				and plot:GetPlotType() == PlotTypes.PLOT_LAND
				and not plot:IsCoastalLand(8)
				and not plot:IsRiverSide()
				and plot:GetFeatureType() == FeatureTypes.NO_FEATURE then
				local disk = GetHexDisk(x, y, 2, iW, iH, wrapX, false);
				local hillCt = 0;
				for _, t in ipairs(disk) do
					local p = Map.GetPlot(t[1], t[2]);
					if p and not p:IsWater() and p:GetPlotType() == PlotTypes.PLOT_HILLS then
						hillCt = hillCt + 1;
					end
				end
				if hillCt < 3 and Map.Rand(100, "") < 26 then
					local terr = plot:GetTerrainType();
					local canForest =
						(terr == TerrainTypes.TERRAIN_GRASS or terr == TerrainTypes.TERRAIN_PLAINS or terr == TerrainTypes.TERRAIN_TUNDRA)
						and plot:GetFeatureType() == FeatureTypes.NO_FEATURE;
					if canForest and Map.Rand(100, "") < 38 then
						plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
					else
						plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
					end
				end
			end
		end
	end
end

function LekPurgeIceAdjacentMainlandNearPoles(edgeRows)
	edgeRows = edgeRows or 4;
	local iW, iH = Map.GetGridSize();
	if iW < 1 or iH < 1 then
		return;
	end
	local landmass = Map.FindBiggestArea(false);
	if not landmass then
		return;
	end
	local mainAid = landmass:GetID();
	local wrapY = Map.IsWrapY and Map:IsWrapY();
	local function nearMapEdgeRow(y)
		if wrapY then
			return false;
		end
		return y < edgeRows or y >= (iH - edgeRows);
	end
	local removed = 0;
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local plot = Map.GetPlot(x, y);
			if plot and plot:GetFeatureType() == FeatureTypes.FEATURE_ICE and plot:IsWater() then
				if nearMapEdgeRow(y) then
				else
					local touchMain = false;
					for d = 0, 5 do
						local np = Map.PlotDirection(x, y, d);
						if np then
							local pt = np:GetPlotType();
							if pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS or pt == PlotTypes.PLOT_MOUNTAIN then
								if np:GetArea() == mainAid then
									touchMain = true;
									break;
								end
							end
						end
					end
					if touchMain then
						plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
						removed = removed + 1;
					end
				end
			end
		end
	end
	if removed > 0 then
		if LekMapgenPrint then LekMapgenPrint("### LekPurgeIceAdjacentMainlandNearPoles removed=" .. tostring(removed) .. " edgeRows=" .. tostring(edgeRows)); end
	end
end
------------------------------------------------------------------------------
function AddFeatures()

		if LekPipelineFlow then LekPipelineFlow("AddFeatures_entry"); end
	-- Get Rainfall setting input by user.
	local rain = LekMapGetCustomOption(3)
	if rain == 4 then
		rain = 1 + Map.Rand(3, "Random Rainfall - Lua");
	end
	
	local args = {rainfall = rain}
	local featuregen = FeatureGenerator.Create(args);

	-- True = allow mountains on coast (skip coastal mountain demotion).
	featuregen:AddFeatures(true);

	-- Sparse forest on snow: 2% per snow flat tile, excluding the 3 rows at each map edge.
	do
		local iW, iH = Map.GetGridSize();
		for y = 3, iH - 4 do
			for x = 0, iW - 1 do
				local plot = Map.GetPlot(x, y);
				if plot
					and plot:GetTerrainType() == TerrainTypes.TERRAIN_SNOW
					and plot:GetPlotType() == PlotTypes.PLOT_LAND
					and plot:GetFeatureType() == FeatureTypes.NO_FEATURE
					and Map.Rand(100, "") < 2 then
					plot:SetFeatureType(FeatureTypes.FEATURE_FOREST, -1);
				end
			end
		end
	end

	LekPurgeIceAdjacentMainlandNearPoles(4);
	pcall(LekJungleCentralVolcano);
	pcall(LekIslandVegetation);
	pcall(LekForcePolarSnowRows);
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function StartPlotSystem()

		if LekPipelineFlow then LekPipelineFlow("StartPlotSystem_entry"); end
	_lek_run_id = tostring(math.floor((os.clock and os.clock() or 0) * 1000));
	LekPipelineLogCivCensus("StartPlotSystem_civ_census");
	local function appendLekLog(lines)
		if LekMapgenAllowMsg and not LekMapgenAllowMsg(lines) then
			return;
		elseif (not LekMapgenAllowMsg) and LekMapgenLogsEnabled and not LekMapgenLogsEnabled() then
			return;
		end
		if _lek_mapgen_tuple_benchmark_mode or _lek_mapgen_world_is_small then
			return;
		end
		pcall(function()
			if type(LekMapgenDiagLogAppend) == "function" then
				LekMapgenDiagLogAppend(lines);
			end
		end);
	end
	appendLekLog({
		"### RunStage runId=" .. tostring(_lek_run_id) .. " stage=StartPlotSystem.begin"
	});

	local function startPlacementSanity(start_plot_database, stageTag, checkPlayerAssign)
		if not start_plot_database then
			return;
		end
		local runId = tostring(_lek_run_id or "na");
		local nCiv = start_plot_database.iNumCivs or 0;
		local tblOk = 0;
		local bits = {};
		for loop = 1, nCiv do
			local tr = start_plot_database.startingPlots and start_plot_database.startingPlots[loop];
			if tr and type(tr[1]) == "number" and type(tr[2]) == "number" then
				tblOk = tblOk + 1;
				bits[#bits + 1] = string.format("r%d_tbl=%d,%d", loop, tr[1], tr[2]);
			else
				bits[#bits + 1] = string.format("r%d_tbl=nil", loop);
			end
		end
		local nNilPlayer = 0;
		local nMismatch = 0;
		local nWaterStart = 0;
		if checkPlayerAssign == true then
			for loop = 1, nCiv do
				local pid = start_plot_database.player_ID_list[loop];
				local pl = Players[pid];
				local ps = pl and pl:GetStartingPlot();
				local tr = start_plot_database.startingPlots and start_plot_database.startingPlots[loop];
				local sx, sy = nil, nil;
				if tr and type(tr[1]) == "number" and type(tr[2]) == "number" then
					sx, sy = tr[1], tr[2];
				end
				if not ps then
					nNilPlayer = nNilPlayer + 1;
					bits[#bits + 1] = string.format("r%d_pid%d_PLAYER=nil", loop, pid);
				else
					local px, py = ps:GetX(), ps:GetY();
					if sx and (sx ~= px or sy ~= py) then
						nMismatch = nMismatch + 1;
						bits[#bits + 1] = string.format(
							"r%d_pid%d_MISMATCH_tbl(%d,%d)_player(%d,%d)",
							loop, pid, sx, sy, px, py);
					end
					if ps:IsWater() then
						nWaterStart = nWaterStart + 1;
						bits[#bits + 1] = string.format("r%d_pid%d_WATER_START", loop, pid);
					end
				end
			end
		end
		local msg = "### StartSanity runId=" .. runId .. " stage=" .. tostring(stageTag)
			.. " iNumCivs=" .. tostring(nCiv)
			.. " regionTblCoords=" .. tostring(tblOk) .. "/" .. tostring(nCiv)
			.. (checkPlayerAssign and (
				" nilPlayer=" .. tostring(nNilPlayer)
				.. " mismatchTblVsPlayer=" .. tostring(nMismatch)
				.. " waterStart=" .. tostring(nWaterStart)
			) or "")
			.. " regenReq=" .. tostring(_lek_global_six_request_map_regen == true)
			.. " | " .. table.concat(bits, " ");
		if not _lek_mapgen_tuple_benchmark_mode then
			if LekMapgenPrint then
				LekMapgenPrint(msg);
			elseif LekMapgenLogsEnabled and LekMapgenLogsEnabled() then
				print(msg);
			end
			appendLekLog({ msg });
		end
	end

	local RegionalMethod = 1;

	-- Debug helper: visualize region rectangles by recoloring land and clearing plot features.
	-- This is intentionally executed *after* all start/resources/city-state placement so it
	-- doesn't disrupt the functional placement logic.
	local function DebugPaintRegionsTerrains(start_plot_database)
		if not start_plot_database or not start_plot_database.regionData then return; end
		local regionCount = table.maxn(start_plot_database.regionData);
		if LekMapgenPrint then
			LekMapgenPrint("### DebugPaintRegionsTerrains: regionCount=", tostring(regionCount));
		end

		local iW, iH = Map.GetGridSize();
		local function paintIfLand(x, y, terrain)
			local p = Map.GetPlot(x, y);
			if not (p and not p:IsWater()) then return false; end
			-- Paint a 3x3 block so the marker is easy to spot.
			for dy = -1, 1 do
				for dx = -1, 1 do
					local nx, ny = x + dx, y + dy;
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local np = Map.GetPlot(nx, ny);
						if np and not np:IsWater() then
							np:SetTerrainType(terrain, false, true);
							np:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
						end
					end
				end
			end
			return true;
		end

		local function paint1IfLand(x, y, terrain)
			local p = Map.GetPlot(x, y);
			if not (p and not p:IsWater()) then return false; end
			p:SetTerrainType(terrain, false, true);
			p:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			return true;
		end
		-- Outline can be expensive (many SetTerrainType calls). Keep it bounded.
		local outlinePaintCount = 0;
		local outlinePaintCountMax = 2000;
		local function paintOutlineIfLand(x, y, terrain)
			if outlinePaintCount >= outlinePaintCountMax then return false; end
			local p = Map.GetPlot(x, y);
			if not (p and not p:IsWater()) then return false; end
			outlinePaintCount = outlinePaintCount + 1;
			p:SetTerrainType(terrain, false, true);
			-- Don't touch features for outline; terrain repaint is already visible.
			return true;
		end

		local function regionCenter(region)
			local westX, southY, width, height = region[1], region[2], region[3], region[4];
			local cx = (westX + math.floor((width - 1) / 2)) % iW;
			local cy = (southY + math.floor((height - 1) / 2)) % iH;
			return cx, cy;
		end

		local function paintNearestLand(x, y, terrain, searchRadius)
			searchRadius = searchRadius or 3;
			if paintIfLand(x, y, terrain) then return true; end
			for r = 1, searchRadius do
				for dy = -r, r do
					for dx = -r, r do
						local nx, ny = x + dx, y + dy;
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
							if paintIfLand(nx, ny, terrain) then return true; end
						end
					end
				end
			end
			return false;
		end

		-- Sort roughly into "rows": higher centerY first (north row), then by centerX.
		local regions = {};
		for _, region in ipairs(start_plot_database.regionData) do
			regions[#regions + 1] = region;
		end
		table.sort(regions, function(a, b)
			local ax, ay = regionCenter(a);
			local bx, by = regionCenter(b);
			if ay == by then return ax < bx; end
			return ay > by;
		end);

		-- Snow center + coarse rectangle outline per region (AABB; wrong-looking on equator_ring until redesigned).
		for idx, region in ipairs(regions) do
			local westX, southY, width, height = region[1], region[2], region[3], region[4];
			local targetTerrain = TerrainTypes.TERRAIN_SNOW;

			local rcx, rcy = regionCenter(region);
			local ok = paintNearestLand(rcx, rcy, targetTerrain, 1);
			if ok then
				if LekMapgenPrint then LekMapgenPrint("### DebugPaintRegionsTerrains: region", tostring(idx), "center approx", tostring(rcx), tostring(rcy), "painted"); end
			else
				if LekMapgenPrint then LekMapgenPrint("### DebugPaintRegionsTerrains: region", tostring(idx), "center approx", tostring(rcx), tostring(rcy), "no land found"); end
			end

			local stepX = math.max(1, math.floor(width / 25));
			local stepY = math.max(1, math.floor(height / 25));
			for localX = 0, width - 1, stepX do
				local topY = (southY) % iH;
				local botY = (southY + height - 1) % iH;
				local x = (westX + localX) % iW;
				paintOutlineIfLand(x, topY, targetTerrain);
				paintOutlineIfLand(x, botY, targetTerrain);
			end
			for localY = 0, height - 1, stepY do
				local leftX = (westX) % iW;
				local rightX = (westX + width - 1) % iW;
				local y = (southY + localY) % iH;
				paintOutlineIfLand(leftX, y, targetTerrain);
				paintOutlineIfLand(rightX, y, targetTerrain);
			end
		end
		if LekPipelineFlow then
			LekPipelineFlow("region_snow_paint_done", "regions=" .. tostring(#regions) .. " outlineTiles=" .. tostring(outlinePaintCount));
		end
	end

	-- Get Resources setting input by user.
	local AllowInlandSea = LekMapGetCustomOption(19)
	local res = LekMapGetCustomOption(14) or 5
	local starts = LekMapGetCustomOption(5)
	--if starts == 7 then
		--starts = 1 + Map.Rand(8, "Random Resources Option - Lua");
	--end

	-- Handle coastal spawns and start bias
	MixedBias = false;
	local IgnoreAllStartBias = false;
	local BalancedCoastalExactTwo = false;
	local ForceAllInlandPlayerSpawns = false;
	-- Option 17 "Coastal Spawns": 1=Civs Only, 2=Force 2, 3=All Inland, 4=Pure Random (must match CustomOptions order).
	if LekMapGetCustomOption(17) == 1 then
		OnlyCoastal = true;
		BalancedCoastal = false;
	end
	if LekMapGetCustomOption(17) == 2 then
		OnlyCoastal = false;
		BalancedCoastal = true;
		BalancedCoastalExactTwo = true;
	end
	if LekMapGetCustomOption(17) == 3 then
		BalancedCoastal = false;
		OnlyCoastal = false;
		ForceAllInlandPlayerSpawns = true;
	end
	if LekMapGetCustomOption(17) == 4 then
		BalancedCoastal = false;
		OnlyCoastal = false;
	end
	
	if LekMapGetCustomOption(18) == 1 then
	CoastLux = true
	end

	if LekMapGetCustomOption(18) == 2 then
	CoastLux = false
	end

	print("Creating start plot database.");
	local start_plot_database = AssignStartingPlots.Create()

	local function shortCircuitStartPlotSystemIfRegen(stageTag)
		if _lek_global_six_request_map_regen ~= true then
			return false;
		end
		_lek_bench_short_circuit_stage = tostring(stageTag or "na");
		startPlacementSanity(start_plot_database, stageTag, false);
		local att = _lek_map_layout_attempt or 1;
		local maxL = _lek_global_six_regen_max_layouts;
		if type(maxL) ~= "number" or maxL < 1 then
			maxL = 4;
		end
		local msg = "### LekMapGen StartPlotSystem short_circuit runId=" .. tostring(_lek_run_id or "na")
			.. " layout=" .. tostring(att) .. "/" .. tostring(maxL)
			.. " reason=_lek_global_six_request_map_regen"
			.. " regenReason=" .. tostring(_lek_global_six_request_map_regen_reason or "na")
			.. " stage=" .. tostring(stageTag);
		if LekPlacementProbeAt then
			LekPlacementProbeAt(1, msg);
		elseif LekPlacementProbeLog then
			LekPlacementProbeLog(msg);
		else
			if LekMapgenPrintAndDiagFile then
				LekMapgenPrintAndDiagFile(msg);
			else
				appendLekLog({ msg });
			end
		end
		if LekMapgenFormatBench6SummaryLine and LekMapgenEmitBench6OneLine then
			local benchLine = LekMapgenFormatBench6SummaryLine(start_plot_database);
			if benchLine then
				LekMapgenEmitBench6OneLine(benchLine);
			end
		end
		return true;
	end

	do
		-- UI: 1 = Legacy, 2 = Global six. Older saves with value 3 map to 2.
		-- Equator ring: Geometric Balance is blob-era; force Legacy until a ring-native placer exists.
		local paceSel = 2;
		local okP, vP = pcall(function()
			return LekMapGetCustomOption(13);
		end);
		if okP and type(vP) == "number" and vP >= 1 then
			paceSel = math.floor(vP + 0.5);
		end
		if paceSel < 1 then
			paceSel = 2;
		elseif paceSel > 2 then
			paceSel = 2;
		end
		local ringForceLegacy = LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing();
		if ringForceLegacy then
			paceSel = 1;
		end
		start_plot_database._lek_ui_starting_locations_pace = paceSel;
		start_plot_database._lek_global_six_skip_tuple_use_legacy = (paceSel == 1);
		start_plot_database._lek_global_six_tuple_regen_on_solver_fail = false;
		start_plot_database._lek_global_six_one_map_placement_mode = (paceSel == 2);
		start_plot_database._lek_global_six_tuple_skip_dfs_rank1_head_s2 = (paceSel == 2);
		if paceSel == 1 then
			start_plot_database._lek_global_six_pace_fast = false;
			start_plot_database._lek_global_six_fatal_on_exhausted = false;
			start_plot_database._lek_global_six_regen_max_layouts = 1;
			start_plot_database._lek_global_six_tuple_relax_min_layout = false;
			start_plot_database._lek_global_six_tuple_minimal_s2_fallback_max_layout = false;
			start_plot_database._lek_global_six_one_map_placement_mode = false;
		else
			start_plot_database._lek_global_six_pace_fast = false;
			start_plot_database._lek_global_six_fatal_on_exhausted = false;
			-- Lekmod spacing rules (2026-10-18): no passing set of capitals after all phases on a map = new map,
			-- up to 8 maps; the 8th takes the best set seen (4a LekSpacingRulesPass)
			start_plot_database._lek_global_six_regen_max_layouts = 8;
			start_plot_database._lek_global_six_tuple_regen_on_solver_fail = true;
			start_plot_database._lek_global_six_tuple_relax_min_layout = false;
			start_plot_database._lek_global_six_tuple_minimal_s2_fallback_max_layout = false;
			-- nil relaxation_phases → 4a LekGlobalSix_DefaultTupleRelaxationPhases()
		end
		if LekPipelineFlow then
			local pathName = (paceSel == 1) and "Legacy" or "GeometricBalance";
			local extra = ringForceLegacy and " ringForceLegacy=1" or "";
			LekPipelineFlow("geom_balance_ui", "pace=" .. tostring(paceSel) .. " path=" .. pathName .. extra);
		end
	end

	     start_plot_database._lek_global_six_solver = true;
	     start_plot_database._lek_global_six_ripple_dry_run = false;
	     start_plot_database._lek_tuple_pool_diag = false;
	     -- Section5 (bias feasibility) hardness policy:
	     -- Coastal + river remain hard constraints; region priority/avoid are softened
	     -- to mimic legacy practical outcomes (usually satisfied, but not map-killing).
	     start_plot_database._lek_global_six_s5_avoid_hard = false;
	     start_plot_database._lek_global_six_s5_prim_hard = false;
	     start_plot_database._lek_global_six_coastal_bias_requires_salt = true;
	     start_plot_database._lek_global_six_coastal_disk3_max_salt_water_pct = 40;
	     start_plot_database._lek_global_six_coastal_salt_water_disk_radius = 3;
	     -- Per-phase defaults from 4a unless _lek_global_six_tuple_relaxation_phases is set.
	     start_plot_database._lek_global_six_max_fail_complete = 1000;
	     start_plot_database._lek_global_six_max_leaf_evals = 8000;
	     -- Tuple stress testing toggle (manual perf experiments):
	     -- false = normal day-to-day budgets
	     -- true  = expensive search to test whether deeper tuple effort meaningfully improves tuple_ok rate
	     local tupleStressMode = false;
	     if tupleStressMode then
		start_plot_database._lek_global_six_max_fail_complete = 12000;
		start_plot_database._lek_global_six_max_leaf_evals = 40000;
		-- Optional pool breadth bump for stress studies.
		start_plot_database._lek_global_six_max_candidates_per_region = 48;
	     end
	     start_plot_database._lek_global_six_force_geometry_only = true;
	     start_plot_database._lek_global_six_force_geometry_sample_count = 1000;
	     start_plot_database._lek_global_six_force_geometry_candidate_cap = 36;
	     -- Center deadzone floor only (outer band / target / hex ring unchanged).
	     start_plot_database._lek_global_six_force_geometry_center_band_min = 9;
	     start_plot_database._lek_global_six_force_geometry_center_band_max = 16;
	     start_plot_database._lek_global_six_force_geometry_target_center_d = 13;
	     start_plot_database._lek_enable_virtual_six_retries = false;
	     start_plot_database._lek_disable_virtual_six = true;
	     start_plot_database._lek_flatten_region_start_tiers = false
	     -- _lek_stronger_bias 
	     start_plot_database.centerBias = 20
	     start_plot_database.middleBias = 50
	     -- 
	     start_plot_database._lek_collide_coastals = true
		-- Interacts with CoastLux, makes that option undefined -- however true/false just marks guarantee/random
		-- CoastLux = false
		start_plot_database._lek_coastal_refish = false
		start_plot_database._lek_regional_lux_require_start_same_area = true
	if type(start_plot_database._lek_global_six_regen_max_layouts) == "number" and start_plot_database._lek_global_six_regen_max_layouts >= 1 then
		_lek_global_six_regen_max_layouts = start_plot_database._lek_global_six_regen_max_layouts;
	end
	
	if not _lek_mapgen_tuple_benchmark_mode then
		print("Dividing the map in to Regions.");
	end
	-- Regional Division Method 1: Biggest Landmass
	-- Equator ring @ 6 civs: CustomOverride swaps HB chops for staggered 3×2 brick AABBs
	-- before MeasureTerrainInRegions / regionTypes (still inside GenerateRegions).
	if LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing() then
		start_plot_database.CustomOverride = function(db)
			LekLandmass_EquatorRing_ApplyBrickRegions(db);
		end
		-- Coastal bonus islands on (guaranteed near-capital shore isles). PangaeaIslands still skipped.
		-- Narrow ring + Legacy: do not fatal-error out of B&A / lux gates (soft proceed).
		start_plot_database._lek_major_min_pairwise_soft = true;
		start_plot_database._lek_global_six_one_map_placement_mode = true;
	end
	local args = {
		method = RegionalMethod,
		start_locations = starts,
		resources = res,
		AllowInlandSea = AllowInlandSea,
		CoastLux = CoastLux,
		NoCoastInland = (OnlyCoastal == true) or (ForceAllInlandPlayerSpawns == true),
		BalancedCoastal = BalancedCoastal,
		BalancedCoastalExactTwo = BalancedCoastalExactTwo,
		ForceAllInlandPlayerSpawns = ForceAllInlandPlayerSpawns,
		MixedBias = MixedBias,
		IgnoreAllStartBias = IgnoreAllStartBias,
		};
	do
		local ok, err = pcall(function() start_plot_database:GenerateRegions(args) end);
		if not ok then
			local msg = "### GenerateRegions CRASH runId=" .. tostring(_lek_run_id or "na") .. " err=" .. tostring(err);
			if LekMapgenPrintAndDiagFile then LekMapgenPrintAndDiagFile(msg); else appendLekLog({ msg }); end
		end
	end

	if start_plot_database._lek_global_six_skip_tuple_use_legacy == true then
		_lek_mapgen_tuple_benchmark_mode = false;
	else
		_lek_mapgen_tuple_benchmark_mode = true;
	end
	if _lek_mapgen_tuple_benchmark_mode then
		_lek_bench_tuple_ok = nil;
		_lek_bench_tuple_why = "";
		_lek_bench_tuple_leaf = nil;
		_lek_bench_tuple_fail_complete = nil;
		_lek_bench_tuple_relax = "";
		_lek_bench_tuple_tier = "";
		_lek_bench_regional_lux_repair_cleared = 0;
		_lek_bench_lux_regional_shortfall_queued = 0;
		_lek_bench_spacing_min_nearest = nil;
		_lek_bench_spacing_avg_nearest = nil;
		_lek_bench_spacing_median_second = nil;
		_lek_bench_spacing_max_second = nil;
		_lek_bench_spacing_min_center = nil;
		_lek_bench_spacing_coastal_n = nil;
		_lek_bench_spacing_salt_adj_n = nil;
		_lek_bench_short_circuit_stage = nil;
		_lek_global_six_request_map_regen_reason = nil;
		_lek_bench_hex_ok = nil;
		_lek_bench_hex_rot = nil;
		_lek_bench_hex_ringR = nil;
		_lek_bench_feas_bn = nil;
		_lek_bench_feas_xmin = nil;
		_lek_bench_feas_h2max = nil;
		_lek_bench_feas_margmin = nil;
		_lek_bench_feas_k = nil;
	end

	--[[ Debug: snow terrain on region centers + rectangle outline (expensive). Re-enable when diagnosing regions.
	print("### DEBUG region markers paint START")
	DebugPaintRegionsTerrains(start_plot_database)
	print("### DEBUG region markers paint END")
	--]]

	if not _lek_mapgen_tuple_benchmark_mode then
		print("Choosing start locations for civilizations.");
	end

	do
		local ok, err = pcall(function() start_plot_database:ChooseLocations() end);
		if not ok then
			local msg = "### ChooseLocations CRASH runId=" .. tostring(_lek_run_id or "na") .. " err=" .. tostring(err);
			if LekMapgenPrintAndDiagFile then LekMapgenPrintAndDiagFile(msg); else appendLekLog({ msg }); end
			local maxRegenL = _lek_global_six_regen_max_layouts;
			if type(maxRegenL) ~= "number" or maxRegenL < 1 then
				maxRegenL = 4;
			end
			local att = _lek_map_layout_attempt or 1;
			local dsbOk, dsbV = pcall(function()
				return Game.GetCustomOption("GAMEOPTION_DISABLE_START_BIAS");
			end);
			local biasSkipsSix = (dsbOk and dsbV == 1);
			if AssignStartingPlots.LekGlobalSix_CanRequestLayoutRegenForPlacementGate(start_plot_database)
				and start_plot_database._lek_global_six_solver == true
				and not biasSkipsSix
				and start_plot_database.iNumCivs == 6
				and att < maxRegenL then
				_lek_global_six_request_map_regen_reason = "ChooseLocations_pcall_err";
				_lek_global_six_request_map_regen = true;
				local rq = "### LekGlobalSix mapRegen request runId=" .. tostring(_lek_run_id or "na")
					.. " layout=" .. tostring(att) .. "/" .. tostring(maxRegenL)
					.. " reason=ChooseLocations_pcall_err";
				appendLekLog({ rq });
				if LekPlacementProbeAt then
					LekPlacementProbeAt(1, rq);
				elseif LekPlacementProbeLog then
					LekPlacementProbeLog(rq);
				else
					print(rq);
				end
			end
		end
	end

	if shortCircuitStartPlotSystemIfRegen("short_circuit_before_BA_table_only") then
		return;
	end

	startPlacementSanity(start_plot_database, "after_ChooseLocations", false);
	if LekLandmass_IsFractalPangaea and LekLandmass_IsFractalPangaea() then
		local ok, err = pcall(function()
			local nS, nT, nR = LekClearCoastalStartsTowardCenter(start_plot_database);
			if nT > 0 then
				-- Coast data feeds city states / resources later; rebuild it on the edited terrain.
				AssignStartingPlots.LekBuildCoastTables(start_plot_database);
				start_plot_database.plotDataMainlandCoastWater, start_plot_database.plotDataExpandedMainlandCoastWater = GenerateMainlandExpandedCoastData();
			end
			if LekPipelineFlow then
				LekPipelineFlow("coastal_center_clear", "starts=" .. nS .. " tiles=" .. nT .. " reverted=" .. nR);
			end
		end);
		if not ok and LekPipelineFlow then
			LekPipelineFlow("coastal_center_clear_error", tostring(err));
		end
	end
	if LekPipelineFlow then
		local pace = start_plot_database._lek_ui_starting_locations_pace or -1;
		local pathName = (pace == 1) and "Legacy" or ((pace == 2) and "GeometricBalance" or "unknown");
		local skipLegacy = (start_plot_database._lek_global_six_skip_tuple_use_legacy == true);
		local forceGeom = (start_plot_database._lek_global_six_force_geometry_only == true);
		local tier = tostring(start_plot_database._lek_global_six_placement_tier or "?");
		-- ranGeom=1 means UI asked for Geometric Balance and ChooseLocations did not take the legacy-menu skip path.
		local ranGeom = (pace == 2 and not skipLegacy and tier ~= "legacy_menu_skip_tuple") and "1" or "0";
		LekPipelineFlow("geom_balance_after_ChooseLocations",
			"path=" .. pathName
			.. " ranGeom=" .. ranGeom
			.. " forceGeom=" .. (forceGeom and "1" or "0")
			.. " tier=" .. tier
			.. " civs=" .. tostring(start_plot_database.iNumCivs or "?"));
	end
	
	if not _lek_mapgen_tuple_benchmark_mode then
		print("Normalizing start locations and assigning them to Players.");
	end
	if LekPipelineFlow then LekPipelineFlow("BalanceAndAssign_begin"); end
	do
		local ok, err = pcall(function() start_plot_database:BalanceAndAssign(args) end);
		if LekPipelineFlow then
			LekPipelineFlow("BalanceAndAssign_done", ok and "ok" or tostring(err));
		end
		if not ok then
			local msg = "### BalanceAndAssign CRASH runId=" .. tostring(_lek_run_id or "na") .. " err=" .. tostring(err);
			if LekMapgenPrintAndDiagFile then
				LekMapgenPrintAndDiagFile(msg);
			else
				appendLekLog({ msg });
			end
		end
	end
	do
		local ok, err = pcall(function()
			if start_plot_database and start_plot_database.LekGlobalSix_ForceApplyExpectedPlayerStarts then
				start_plot_database:LekGlobalSix_ForceApplyExpectedPlayerStarts();
			end
		end);
		if not ok then
			local msg = "### LekGlobalSix forceBiasApply CRASH runId=" .. tostring(_lek_run_id or "na") .. " err=" .. tostring(err);
			if LekMapgenPrintAndDiagFile then
				LekMapgenPrintAndDiagFile(msg);
			else
				appendLekLog({ msg });
			end
		end
	end
	do
		local ok, err = pcall(function()
			if start_plot_database and start_plot_database.LekGlobalSix_LogForceBiasAssignmentAudit then
				start_plot_database:LekGlobalSix_LogForceBiasAssignmentAudit();
			end
		end);
		if not ok then
			local msg = "### LekGlobalSix forceBiasAudit CRASH runId=" .. tostring(_lek_run_id or "na") .. " err=" .. tostring(err);
			if LekMapgenPrintAndDiagFile then
				LekMapgenPrintAndDiagFile(msg);
			else
				appendLekLog({ msg });
			end
		end
	end

	do
		local nR4Coast = LekDemoteRing4CoastalMountainsNearCoastalMajors(start_plot_database);
		local nR1, nR4Cap = LekCapRing1MountainsNearCoastalMajors(start_plot_database);
		if not _lek_mapgen_tuple_benchmark_mode then
			local msg = "### LekMapGen demote_ring4_coastal_mtn n=" .. tostring(nR4Coast)
				.. " cap_r1_coastal_mtn n=" .. tostring(nR1)
				.. " cap_r4_coastal_mtn n=" .. tostring(nR4Cap)
				.. " runId=" .. tostring(_lek_run_id or "na");
			if LekMapgenPrintAndDiagFile then
				LekMapgenPrintAndDiagFile(msg);
			else
				appendLekLog({ msg });
			end
		end
	end

	if shortCircuitStartPlotSystemIfRegen("after_BalanceAndAssign") then
		return;
	end

	-- After BalanceAndAssign, rescue any player still without a starting plot.
	-- Global-six 6p: only unused region starts; no random land scan; request regen if still missing.
	do
		local missing_pids = {};
		for loop = 1, start_plot_database.iNumCivs do
			local pid = start_plot_database.player_ID_list[loop];
			local pl = Players[pid];
			if pl and pl:IsEverAlive() and not pl:IsMinorCiv() then
				if pl:GetStartingPlot() == nil then
					missing_pids[#missing_pids + 1] = pid;
				end
			end
		end
		if #missing_pids > 0 then
			local strictSix = (start_plot_database._lek_global_six_solver == true)
				and ((start_plot_database.iNumCivs or 0) == 6);
			local rescue_candidates = {};
			local used_plots = {};
			for loop = 1, start_plot_database.iNumCivs do
				local pid = start_plot_database.player_ID_list[loop];
				local pl = Players[pid];
				if pl then
					local sp = pl:GetStartingPlot();
					if sp then used_plots[sp:GetX() .. "," .. sp:GetY()] = true; end
				end
			end
			for r = 1, start_plot_database.iNumCivs do
				local t = start_plot_database.startingPlots[r];
				if t and type(t[1]) == "number" and type(t[2]) == "number" then
					local k = t[1] .. "," .. t[2];
					if not used_plots[k] then
						rescue_candidates[#rescue_candidates + 1] = { t[1], t[2] };
					end
				end
			end
			if #rescue_candidates == 0 and not strictSix then
				local iW, iH = Map.GetGridSize();
				for y = 1, iH - 2 do
					for x = 0, iW - 1 do
						local p = Map.GetPlot(x, y);
						if p and (p:GetPlotType() == PlotTypes.PLOT_LAND or p:GetPlotType() == PlotTypes.PLOT_HILLS) then
							rescue_candidates[#rescue_candidates + 1] = { x, y };
							if #rescue_candidates >= 20 then break; end
						end
					end
					if #rescue_candidates >= 20 then break; end
				end
			elseif #rescue_candidates == 0 and strictSix then
				local zmsg = "### StartPlotSystem RESCUE strict_global_six no_unused_region_start runId="
					 .. tostring(_lek_run_id or "na") .. " missing_majors=" .. tostring(#missing_pids);
				print(zmsg);
				if not _lek_mapgen_tuple_benchmark_mode then
					appendLekLog({ zmsg });
				end
			end
			local rescue_log = {};
			for i, pid in ipairs(missing_pids) do
				local cand = rescue_candidates[i];
				if cand then
					local p = Map.GetPlot(cand[1], cand[2]);
					if p then
						Players[pid]:SetStartingPlot(p);
						rescue_log[#rescue_log + 1] = "pid=" .. pid .. "->(" .. cand[1] .. "," .. cand[2] .. ")";
					else
						rescue_log[#rescue_log + 1] = "pid=" .. pid .. "->FAILED";
					end
				else
					rescue_log[#rescue_log + 1] = "pid=" .. pid .. "->NO_CANDIDATE";
				end
			end
			local msg = "### StartPlotSystem RESCUE runId=" .. tostring(_lek_run_id or "na")
				.. " rescued=" .. #missing_pids .. " " .. table.concat(rescue_log, " | ");
			if not _lek_mapgen_tuple_benchmark_mode then
				if LekMapgenPrintAndDiagFile then
					LekMapgenPrintAndDiagFile(msg);
				else
					appendLekLog({ msg });
				end
			end
			if strictSix then
				local anyNil = false;
				for _, pid2 in ipairs(missing_pids) do
					local pl2 = Players[pid2];
					if pl2 and pl2:GetStartingPlot() == nil then
						anyNil = true;
						break;
					end
				end
				if anyNil then
					local maxRegenL = _lek_global_six_regen_max_layouts;
					if type(maxRegenL) ~= "number" or maxRegenL < 1 then
						maxRegenL = 4;
					end
					local att = _lek_map_layout_attempt or 1;
					local canRegen = AssignStartingPlots.LekGlobalSix_CanRequestLayoutRegenForPlacementGate(start_plot_database)
						and (att < maxRegenL);
					local rmsg = "### StartPlotSystem RESCUE strict_global_six incomplete runId="
						.. tostring(_lek_run_id or "na")
						.. " requestRegen=" .. (canRegen and "1" or "0")
						.. " layout=" .. tostring(att) .. "/" .. tostring(maxRegenL);
					if not _lek_mapgen_tuple_benchmark_mode then
						print(rmsg);
						appendLekLog({ rmsg });
					end
					if canRegen then
						_lek_global_six_request_map_regen_reason = "after_BA_missing_major_start_strict_rescue";
						_lek_global_six_request_map_regen = true;
					elseif LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing() then
						if LekPipelineFlow then
							LekPipelineFlow("rescue_incomplete_soft_proceed", "ring=1");
						end
						print("### StartPlotSystem RESCUE incomplete soft_proceed equator_ring");
					else
						error("Lekmap: global-six majors without starting plots after strict rescue; regen exhausted.");
					end
				end
			end
		end
	end

	if shortCircuitStartPlotSystemIfRegen("after_StartPlotSystem_rescue") then
		return;
	end

	-- Validation log: report any remaining issues after rescue.
	do
		local problems = {};
		for loop = 1, start_plot_database.iNumCivs do
			local pid = start_plot_database.player_ID_list[loop];
			local pl = Players[pid];
			if pl and pl:IsEverAlive() and not pl:IsMinorCiv() then
				if pl:GetStartingPlot() == nil then
					problems[#problems + 1] = "player " .. tostring(pid) .. " still missing";
				end
			end
		end
		if #problems > 0 then
			local msg = "### Lekmap FATAL runId=" .. tostring(_lek_run_id or "na") .. " post-rescue issues: " .. table.concat(problems, "; ");
			-- Always surface fatal placement failure even when diagnostic logs are off.
			print(msg);
			if not _lek_mapgen_tuple_benchmark_mode then
				appendLekLog({ msg });
			end
		end
	end

	startPlacementSanity(start_plot_database, "after_BalanceAndAssign_rescue", true);

	-- Post-pass: major start pairwise distances (always → LekPipelineFlow; Small/quiet maps
	-- used to skip LekmapStartSpacing6P entirely via appendLekLog gates).
	do
		local iNumCivs = start_plot_database.iNumCivs or 0;
		if iNumCivs >= 2 then
			local iW, iH = Map.GetGridSize();
			local centerX, centerY = math.floor(iW / 2), math.floor(iH / 2);
			local player_ID_list = start_plot_database.player_ID_list or {};

			local starts = {}; -- { pid=, x=, y=, coastal=, dCenter= }
			for _, pid in ipairs(player_ID_list) do
				local pl = Players[pid];
				if pl and pl:IsEverAlive() and not pl:IsMinorCiv() then
					local sp = pl:GetStartingPlot();
					if sp then
						local x, y = sp:GetX(), sp:GetY();
						local coast = false;
						if AssignStartingPlots.LekGlobalSix_MeasureBiasConditionsAtXY then
							local m = AssignStartingPlots.LekGlobalSix_MeasureBiasConditionsAtXY(start_plot_database, x, y);
							local saltOnly = (start_plot_database._lek_global_six_coastal_bias_requires_salt == true);
							if saltOnly then
								coast = (m.alongOcean == true);
							else
								coast = ((m.alongOcean or m.nextToLake) == true);
							end
						elseif sp.IsCoastalLand then
							coast = sp:IsCoastalLand(300);
						end
						starts[#starts + 1] = { pid = pid, x = x, y = y, coastal = coast };
					end
				end
			end

			local function dist(ax, ay, bx, by)
				if Map.PlotDistance then return Map.PlotDistance(ax, ay, bx, by); end
				if PlotDistance then return PlotDistance(ax, ay, bx, by); end
				return nil;
			end

			if #starts >= 2 then
				for i = 1, #starts do
					starts[i].dCenter = dist(starts[i].x, starts[i].y, centerX, centerY) or -1;
				end

				local nearest = {};
				local secondNearest = {};
				local minPair = nil;
				for i = 1, #starts do
					local dists = {};
					local toBits = {};
					for j = 1, #starts do
						if i ~= j then
							local d = dist(starts[i].x, starts[i].y, starts[j].x, starts[j].y);
							if d ~= nil then
								dists[#dists + 1] = d;
								toBits[#toBits + 1] = "p" .. tostring(starts[j].pid) .. "=" .. tostring(d);
								if minPair == nil or d < minPair then
									minPair = d;
								end
							end
						end
					end
					table.sort(dists);
					nearest[i] = dists[1] or -1;
					secondNearest[i] = dists[2] or -1;
					if LekPipelineFlow then
						LekPipelineFlow("player_distances",
							"p" .. tostring(starts[i].pid)
							.. " xy=" .. tostring(starts[i].x) .. "," .. tostring(starts[i].y)
							.. " coastal=" .. (starts[i].coastal and "1" or "0")
							.. " dCenter=" .. tostring(starts[i].dCenter)
							.. " to=[" .. table.concat(toBits, ",") .. "]"
							.. " nearest=" .. tostring(nearest[i])
							.. " second=" .. tostring(secondNearest[i]));
					end
				end

				local nearestSorted = {};
				local secondNearestSorted = {};
				for i = 1, #starts do
					nearestSorted[#nearestSorted + 1] = nearest[i];
					secondNearestSorted[#secondNearestSorted + 1] = secondNearest[i];
				end
				table.sort(nearestSorted);
				table.sort(secondNearestSorted);
				local function median(arr)
					local n = #arr;
					if n == 0 then return -1; end
					if n % 2 == 1 then return arr[math.floor((n + 1) / 2)]; end
					return (arr[n / 2] + arr[n / 2 + 1]) / 2;
				end
				local sum = 0;
				for i = 1, #nearestSorted do sum = sum + nearestSorted[i]; end
				local avgNearest = (#nearestSorted > 0) and (sum / #nearestSorted) or -1;

				if LekPipelineFlow then
					LekPipelineFlow("player_distances_summary",
						"n=" .. tostring(#starts)
						.. " minPair=" .. tostring(minPair)
						.. " nearestSorted=" .. table.concat(nearestSorted, ",")
						.. " avgNearest=" .. tostring(avgNearest)
						.. " medianNearest=" .. tostring(median(nearestSorted))
						.. " secondSorted=" .. table.concat(secondNearestSorted, ",")
						.. " medianSecond=" .. tostring(median(secondNearestSorted)));
				end

				-- Keep compact-era StartSpacing6P lines when diag append exists (6 civs only).
				if #starts == 6 and not _lek_mapgen_tuple_benchmark_mode then
					local lines = {};
					local runId = tostring(_lek_run_id or "na");
					lines[#lines + 1] = "### StartSpacing6P runId=" .. runId ..
						" center=(" .. centerX .. "," .. centerY .. ")" ..
						" nearestSorted=" .. tostring(table.concat(nearestSorted, ",")) ..
						" avgNearest=" .. tostring(avgNearest) ..
						" medianNearest=" .. tostring(median(nearestSorted)) ..
						" secondNearestSorted=" .. tostring(table.concat(secondNearestSorted, ",")) ..
						" medianSecondNearest=" .. tostring(median(secondNearestSorted));
					for i = 1, 6 do
						lines[#lines + 1] = "### StartSpacing6P: pid=" .. tostring(starts[i].pid) ..
							" x,y=(" .. starts[i].x .. "," .. starts[i].y .. ")" ..
							" coastal=" .. tostring(starts[i].coastal) ..
							" dCenter=" .. tostring(starts[i].dCenter) ..
							" nearest=" .. tostring(nearest[i]) ..
							" secondNearest=" .. tostring(secondNearest[i]);
					end
					-- Bypass Small/quiet gates: always try diag file for A/B vs compact.
					pcall(function()
						if type(LekMapgenDiagLogAppend) == "function" then
							LekMapgenDiagLogAppend(lines);
						end
					end);
				end

				if #starts == 6 and _lek_mapgen_tuple_benchmark_mode then
					_lek_bench_spacing_min_nearest = nearestSorted[1];
					_lek_bench_spacing_avg_nearest = avgNearest;
					_lek_bench_spacing_median_second = median(secondNearestSorted);
					_lek_bench_spacing_max_second = secondNearestSorted[#secondNearestSorted] or -1;
					local minCenter = starts[1].dCenter or -1;
					for i = 2, 6 do
						if starts[i].dCenter < minCenter then
							minCenter = starts[i].dCenter;
						end
					end
					_lek_bench_spacing_min_center = minCenter;
					local cn = 0;
					for i = 1, 6 do
						if starts[i].coastal then cn = cn + 1; end
					end
					_lek_bench_spacing_coastal_n = cn;
				end
			elseif LekPipelineFlow then
				LekPipelineFlow("player_distances_fail",
					"got=" .. tostring(#starts) .. " need>=2 iNumCivs=" .. tostring(iNumCivs));
			end
		end
	end

	if not _lek_mapgen_tuple_benchmark_mode then
		print("Placing Natural Wonders.");
	end
	local wonders = LekMapGetCustomOption(7)
	if wonders == 14 then
		wonders = Map.Rand(13, "Number of Wonders To Spawn - Lua");
	elseif wonders == 15 then
		wonders = 3 + Map.Rand(4, "NW count hidden opt 15");
	elseif wonders == 16 then
		wonders = Map.Rand(5, "") + 2
	else
		wonders = wonders - 1;
	end

	if not _lek_mapgen_tuple_benchmark_mode then
		print("########## Wonders ##########");
		print("Natural Wonders To Place: ", wonders);
	end

	local wonderargs = {
		wonderamt = wonders,
	};
	start_plot_database:PlaceNaturalWonders(wonderargs);
	FixInlandPancakes();
	if not _lek_mapgen_tuple_benchmark_mode then
		print("Placing Resources and City States.");
	end
	appendLekLog({
		"### RunStage runId=" .. tostring(_lek_run_id or "na") .. " stage=before.PlaceResourcesAndCityStates"
	});
	start_plot_database:PlaceResourcesAndCityStates()
	appendLekLog({
		"### RunStage runId=" .. tostring(_lek_run_id or "na") .. " stage=after.PlaceResourcesAndCityStates"
	});

	startPlacementSanity(start_plot_database, "after_PlaceResourcesAndCityStates", true);

	if LekMapgenFormatBench6SummaryLine and LekMapgenEmitBench6OneLine then
		local benchLine = LekMapgenFormatBench6SummaryLine(start_plot_database);
		if benchLine then
			LekMapgenEmitBench6OneLine(benchLine);
		end
	end

	if _lek_global_six_request_map_regen == true then
		local att = _lek_map_layout_attempt or 1;
		local maxL = _lek_global_six_regen_max_layouts;
		if type(maxL) ~= "number" or maxL < 1 then
			maxL = 4;
		end
		local msg = "### LekMapGen StartPlotSystem short_circuit runId=" .. tostring(_lek_run_id or "na")
			.. " layout=" .. tostring(att) .. "/" .. tostring(maxL)
			.. " skip=post_PlaceResources capital_lux_minimum_or_other_regen";
		if LekPlacementProbeAt then
			LekPlacementProbeAt(1, msg);
		elseif LekPlacementProbeLog then
			LekPlacementProbeLog(msg);
		else
			if LekMapgenPrintAndDiagFile then
				LekMapgenPrintAndDiagFile(msg);
			else
				appendLekLog({ msg });
			end
		end
		return;
	end

	-- Region snow outline (AABB) for start-region tuning. Off by default.
	if _lek_debug_paint_region_snow then
		if LekPipelineFlow then LekPipelineFlow("region_snow_paint_begin"); end
		DebugPaintRegionsTerrains(start_plot_database)
	elseif LekPipelineFlow then
		LekPipelineFlow("region_snow_paint_skipped");
	end
	if LekPipelineFlow then LekPipelineFlow("StartPlotSystem_done"); end
end

------------------------------------------------------------------------------
-- Lekmap (user, 2026-10-27): rivers that end on dry land find their way to water.
-- Rivers are made before start placement; afterwards some water becomes land (inland seas near capitals,
-- the coastal-capital clearing, coastal bonus islands), and a river that flowed into it ends on land, which
-- the game draws as a puddle. This pass finds every river edge whose downstream corner touches no water and
-- has no river flowing on, and walks on from there edge by edge toward the nearest water (until it reaches
-- water, the map edge or a river that flows on). If it can't get out, the tile at its end becomes a lake.
--
-- Corners are identified by their three plots. River flags (Civ V): W = river on the plot's east edge
-- (corners NE and SE, flow N/S), NW = on its southeast edge (corners SE and S, flow NE/SW), NE = on its
-- southwest edge (corners S and SW, flow SE/NW).
------------------------------------------------------------------------------
LEK_RIVER_REPAIR_MAX_STEPS = 40;

function LekRepairDeadEndRivers()
	local iW, iH = Map.GetGridSize();
	local D = DirectionTypes;
	local F = FlowDirectionTypes;
	local function nb(p, dir)
		if p == nil then return nil; end
		return Map.PlotDirection(p:GetX(), p:GetY(), dir);
	end
	local function idx(p) return p and (p:GetY() * iW + p:GetX()) or -1; end
	local function corner(a, b, c)
		local t = { idx(a), idx(b), idx(c) };
		table.sort(t);
		return { key = t[1] .. ":" .. t[2] .. ":" .. t[3], plots = { a, b, c } };
	end
	local function cNE(p) return corner(p, nb(p, D.DIRECTION_NORTHEAST), nb(p, D.DIRECTION_EAST)); end
	local function cSE(p) return corner(p, nb(p, D.DIRECTION_EAST), nb(p, D.DIRECTION_SOUTHEAST)); end
	local function cS(p) return corner(p, nb(p, D.DIRECTION_SOUTHEAST), nb(p, D.DIRECTION_SOUTHWEST)); end
	local function cSW(p) return corner(p, nb(p, D.DIRECTION_SOUTHWEST), nb(p, D.DIRECTION_WEST)); end
	-- An edge: holder plot + flag ("W", "NW", "NE"), its two corners and the flow that leads to each.
	local function edge(h, flag)
		if flag == "W" then
			return { h = h, flag = flag, a = cNE(h), fa = F.FLOWDIRECTION_NORTH, b = cSE(h), fb = F.FLOWDIRECTION_SOUTH };
		elseif flag == "NW" then
			return { h = h, flag = flag, a = cSE(h), fa = F.FLOWDIRECTION_NORTHEAST, b = cS(h), fb = F.FLOWDIRECTION_SOUTHWEST };
		else
			return { h = h, flag = flag, a = cSW(h), fa = F.FLOWDIRECTION_NORTHWEST, b = cS(h), fb = F.FLOWDIRECTION_SOUTHEAST };
		end
	end
	local function hasRiver(e)
		if e.flag == "W" then return e.h:IsWOfRiver(); elseif e.flag == "NW" then return e.h:IsNWOfRiver(); end
		return e.h:IsNEOfRiver();
	end
	local function flowOf(e)
		if e.flag == "W" then return e.h:GetRiverEFlowDirection(); elseif e.flag == "NW" then return e.h:GetRiverSEFlowDirection(); end
		return e.h:GetRiverSWFlowDirection();
	end
	local function setRiver(e, flow)
		if e.flag == "W" then e.h:SetWOfRiver(true, flow); elseif e.flag == "NW" then e.h:SetNWOfRiver(true, flow);
		else e.h:SetNEOfRiver(true, flow); end
	end
	local function downstream(e)
		local fl = flowOf(e);
		if fl == e.fa then return e.a; elseif fl == e.fb then return e.b; end
		return nil;
	end
	-- The edge between two neighbouring plots (nil if they aren't neighbours).
	local function edgeBetween(p, q)
		if p == nil or q == nil then return nil; end
		local x, y = q:GetX(), q:GetY();
		local function is(dir) local r = nb(p, dir); return r ~= nil and r:GetX() == x and r:GetY() == y; end
		if is(D.DIRECTION_EAST) then return edge(p, "W"); elseif is(D.DIRECTION_WEST) then return edge(q, "W");
		elseif is(D.DIRECTION_SOUTHEAST) then return edge(p, "NW"); elseif is(D.DIRECTION_NORTHWEST) then return edge(q, "NW");
		elseif is(D.DIRECTION_SOUTHWEST) then return edge(p, "NE"); elseif is(D.DIRECTION_NORTHEAST) then return edge(q, "NE"); end
		return nil;
	end
	local function cornerEdges(c)
		local p = c.plots;
		return { edgeBetween(p[1], p[2]), edgeBetween(p[2], p[3]), edgeBetween(p[1], p[3]) };
	end
	local function touchesWaterOrEdge(c)
		for i = 1, 3 do
			local p = c.plots[i];
			if p == nil or p:IsWater() then return true; end
		end
		return false;
	end
	local function sameEdge(e1, e2) return e1 ~= nil and e2 ~= nil and e1.flag == e2.flag and idx(e1.h) == idx(e2.h); end
	-- A river flows on from corner c along another edge than e.
	local function flowsOn(c, e)
		for _, o in ipairs(cornerEdges(c)) do
			if o ~= nil and not sameEdge(o, e) and hasRiver(o) then
				local d = downstream(o);
				if d ~= nil and d.key ~= c.key then return true; end
			end
		end
		return false;
	end
	-- Distance of every plot to the nearest water (BFS over the map).
	local dist, q = {}, {};
	for k = 0, Map.GetNumPlots() - 1 do
		if Map.GetPlotByIndex(k):IsWater() then dist[k] = 0; q[#q + 1] = k; end
	end
	local h = 1;
	while h <= #q do
		local k = q[h]; h = h + 1;
		local p = Map.GetPlotByIndex(k);
		for dir = 0, 5 do
			local n = nb(p, dir);
			if n ~= nil then
				local nk = idx(n);
				if dist[nk] == nil then dist[nk] = dist[k] + 1; q[#q + 1] = nk; end
			end
		end
	end
	local function cornerDist(c)
		local best = 999;
		for i = 1, 3 do
			local p = c.plots[i];
			if p ~= nil and (dist[idx(p)] or 999) < best then best = dist[idx(p)] or 999; end
		end
		return best;
	end
	-- Collect the dead ends first, then repair them.
	local dead = {};
	for k = 0, Map.GetNumPlots() - 1 do
		local p = Map.GetPlotByIndex(k);
		for _, flag in ipairs({ "W", "NW", "NE" }) do
			local e = edge(p, flag);
			if hasRiver(e) then
				local c = downstream(e);
				if c ~= nil and not touchesWaterOrEdge(c) and not flowsOn(c, e) then
					dead[#dead + 1] = { e = e, c = c };
				end
			end
		end
	end
	local nExtended, nSteps, nLakes, nFailed = 0, 0, 0, 0;
	local startPlots = {};
	for pid = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
		local pl = Players[pid];
		if pl and pl:IsEverAlive() then
			local sp = pl:GetStartingPlot();
			if sp then startPlots[idx(sp)] = true; end
		end
	end
	for _, d in ipairs(dead) do
		local e, c = d.e, d.c;
		if not touchesWaterOrEdge(c) and not flowsOn(c, e) then	-- an earlier repair may have fixed it
			local visited = { [c.key] = true };
			local added = {};
			local ok = false;
			for _ = 1, LEK_RIVER_REPAIR_MAX_STEPS do
				local best, bestD, bestFlow, bestNext = nil, 999, nil, nil;
				for _, o in ipairs(cornerEdges(c)) do
					if o ~= nil and not sameEdge(o, e) then
						local nextC, fl;
						if o.a.key == c.key then nextC, fl = o.b, o.fb; else nextC, fl = o.a, o.fa; end
						if not visited[nextC.key] then
							if hasRiver(o) then
								-- joining a river that already flows away from here
								if downstream(o) ~= nil and downstream(o).key == nextC.key then
									best, bestD, bestNext = o, -1, nextC;
								end
							else
								local dd = cornerDist(nextC) * 10 + Map.Rand(10, "Lek river repair");
								if dd < bestD then best, bestD, bestFlow, bestNext = o, dd, fl, nextC; end
							end
						end
					end
				end
				if best == nil then break; end
				if bestD == -1 then ok = true; break; end	-- merged
				setRiver(best, bestFlow);
				added[#added + 1] = best;
				nSteps = nSteps + 1;
				visited[bestNext.key] = true;
				e, c = best, bestNext;
				if touchesWaterOrEdge(c) or flowsOn(c, e) then ok = true; break; end
			end
			if ok then
				nExtended = nExtended + 1;
			else
				-- no way out: take the walk back and put a one-tile lake at the original end, on the plot the
				-- river doesn't run along (resource-free, not a start, not a natural wonder)
				for _, a in ipairs(added) do
					if a.flag == "W" then a.h:SetWOfRiver(false, F.NO_FLOWDIRECTION);
					elseif a.flag == "NW" then a.h:SetNWOfRiver(false, F.NO_FLOWDIRECTION);
					else a.h:SetNEOfRiver(false, F.NO_FLOWDIRECTION); end
				end
				nSteps = nSteps - #added;
				local made = false;
				for i = 1, 3 do
					local p = d.c.plots[i];
					local nextToWonder = false;
					if p ~= nil then
						for dir = 0, 5 do
							local np = nb(p, dir);
							if np ~= nil and LekPlotIsNaturalWonder(np) then nextToWonder = true; end
						end
					end
					if p ~= nil and not made and not startPlots[idx(p)] and p:GetResourceType(-1) == -1
						and not LekPlotIsNaturalWonder(p) and not p:IsMountain() and not nextToWonder then
						-- the plot opposite the incoming edge: not one of the two plots the edge separates
						local ee = edgeBetween(d.c.plots[(i % 3) + 1], d.c.plots[((i + 1) % 3) + 1]);
						if ee ~= nil and sameEdge(ee, d.e) then
							p:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
							p:SetPlotType(PlotTypes.PLOT_OCEAN, false, false);
							p:SetTerrainType(TerrainTypes.TERRAIN_COAST, false, false);
							made = true;
						end
					end
				end
				if made then nLakes = nLakes + 1; else nFailed = nFailed + 1; end
			end
		end
	end
	if nLakes > 0 then
		Map.RecalculateAreas();
	end
	print("### LekRivers deadEnds=" .. #dead .. " extended=" .. nExtended .. " steps=" .. nSteps .. " lakes=" .. nLakes .. " unfixed=" .. nFailed);
end
