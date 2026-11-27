include("X_IslandHelpers");

local DISK_R = 3;
local NW_BARRINGER = "FEATURE_CRATER";
local NW_FOUNTAIN_YOUTH = "FEATURE_FOUNTAIN_YOUTH";
local NW_KRAKATOA = "FEATURE_VOLCANO";

local function pidx(x, y, iW)
	return y * iW + x + 1;
end

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function footprintClear(plotTypes, tiles, iW, iH)
	for _, t in ipairs(tiles) do
		if isLand(plotTypes, t[1], t[2], iW, iH) then return false; end
	end
	return true;
end

local function ringDistances(cx, cy, landSet, iW, iH, wrapX, wrapY)
	local ck = function(x, y) return x .. "," .. y; end
	local dist = {};
	local queue = {};
	local qi = 1;
	dist[ck(cx, cy)] = 0;
	queue[1] = { cx, cy };
	while qi <= #queue do
		local x, y = queue[qi][1], queue[qi][2];
		qi = qi + 1;
		local d = dist[ck(x, y)];
		for dir = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
			if nx < 0 or nx >= iW or ny < 0 or ny >= iH then
			else
				local k = ck(nx, ny);
				if landSet[k] and dist[k] == nil then
					dist[k] = d + 1;
					queue[#queue + 1] = { nx, ny };
				end
			end
		end
	end
	return dist;
end

function TryPlaceGeothermalIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.geothermalIsland then return false; end
	local pullBack = params.pullBack or 2;
	local effMin = params.effMin or 2;
	local effMax = params.effMax or 6;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local disk = GetHexDisk(cx, cy, DISK_R, params.iW, params.iH, params.wrapX, params.wrapY);
	if #disk < 7 then return false; end

	local landSet = {};
	local landTiles = {};
	for _, t in ipairs(disk) do
		local gx, gy = t[1], t[2];
		local k = gx .. "," .. gy;
		landSet[k] = true;
		landTiles[#landTiles + 1] = { gx, gy };
	end

	local needNS = not params.wrapY;
	local needWE = not params.wrapX;
	local touchNS = not needNS;
	local touchWE = not needWE;
	for _, t in ipairs(landTiles) do
		local gx, gy = t[1], t[2];
		if needNS and (gy <= 1 or gy >= params.iH - 2) then
			touchNS = true;
		end
		if needWE and (gx <= 1 or gx >= params.iW - 2) then
			touchWE = true;
		end
	end
	if needNS and needWE then
		if not (touchNS or touchWE) then
			return false;
		end
	else
		if needNS and not touchNS then
			return false;
		end
		if needWE and not touchWE then
			return false;
		end
	end

	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(cx, cy, d, params.iW, params.iH, params.wrapX, params.wrapY);
		if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then return false; end
		if not landSet[nx .. "," .. ny] then return false; end
	end

	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	local roll = Map.Rand(100, "");
	-- Krakatoa is unique: skip it when the central volcano already took it.
	local krakatoaTaken = _lek_central_volcano_nw and _lek_central_volcano_nw.kind == "krakatoa";
	if roll < 20 and not krakatoaTaken then
		_geothermal_island_nw_type = NW_KRAKATOA;
		_geothermal_is_krakatoa = true;
	else
		_geothermal_island_nw_type = NW_BARRINGER;
		_geothermal_is_krakatoa = false;
	end
	DrawGeothermalIsland(plotTypes, landTiles, landSet, cx, cy, params.iW, params.iH, params.wrapX, params.wrapY);
	if _geothermal_is_krakatoa then
		-- Route through the shared _krakatoa_island_plot pathway so FEATURE_VOLCANO is
		-- force-placed here by the NW system (same path JunglePeak uses). Clear
		-- _geothermal_island_nw_type so the geothermal NW pathway doesn't also fire.
		-- If JunglePeak is also on this map, whichever island was placed last wins the NW;
		-- the other keeps its terrain shape without a wonder, which is fine.
		_krakatoa_island_plot = _geothermal_island_plot;
		_geothermal_island_nw_type = nil;
	end
	if not _island_placed then _island_placed = {}; end
	_island_placed.geothermalIsland = true;
	return true;
end

function DrawGeothermalIsland(plotTypes, landTiles, landSet, cx, cy, iW, iH, wrapX, wrapY)
	_geothermal_island_plot = nil;
	_geothermal_snow_plot_indices = {};
	_geothermal_forest_ring_indices = {};

	local function markSnow(ix, iy)
		_geothermal_snow_plot_indices[#_geothermal_snow_plot_indices + 1] = pidx(ix, iy, iW);
	end

	local dist = ringDistances(cx, cy, landSet, iW, iH, wrapX, wrapY);

	if _geothermal_is_krakatoa then
		-- Krakatoa variant: center is hills, ring-1 is all ocean (water moat),
		-- ring-2+ follows the same randOuter logic as Crater (scattered land/hills/ocean).
		local function randOuter()
			local r = Map.Rand(100, "");
			if r < 40 then return PlotTypes.PLOT_OCEAN;
			elseif r < 60 then return PlotTypes.PLOT_LAND;
			elseif r < 80 then return PlotTypes.PLOT_HILLS;
			else return PlotTypes.PLOT_MOUNTAIN; end
		end
		for _, t in ipairs(landTiles) do
			local gx, gy = t[1], t[2];
			local idx = pidx(gx, gy, iW);
			local k = gx .. "," .. gy;
			local rd = dist[k];
			if rd == nil then rd = 99; end
			if gx == cx and gy == cy then
				_geothermal_island_plot = idx;
				plotTypes[idx] = PlotTypes.PLOT_HILLS;
			elseif rd == 1 then
				plotTypes[idx] = PlotTypes.PLOT_OCEAN;
			elseif rd >= 2 then
				plotTypes[idx] = randOuter();
				local pt = plotTypes[idx];
				if pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS or pt == PlotTypes.PLOT_MOUNTAIN then
					markSnow(gx, gy);
				end
			end
		end
		for _, t in ipairs(landTiles) do
			local gx, gy = t[1], t[2];
			if gx ~= cx or gy ~= cy then
				local k = gx .. "," .. gy;
				local rd = dist[k];
				if rd == 2 then
					local idx = pidx(gx, gy, iW);
					local pt = plotTypes[idx];
					if pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS then
						_geothermal_forest_ring_indices[#_geothermal_forest_ring_indices + 1] = idx;
					end
				end
			end
		end
		return;
	end

	-- Crater / Barringer variant: keep a denser core than Krakatoa, but splash more water
	-- so the footprint reads less like a solid land disk.
	local function randOuter()
		local r = Map.Rand(100, "");
		if r < 52 then return PlotTypes.PLOT_OCEAN;
		elseif r < 70 then return PlotTypes.PLOT_LAND;
		elseif r < 88 then return PlotTypes.PLOT_HILLS;
		else return PlotTypes.PLOT_MOUNTAIN; end
	end

	for _, t in ipairs(landTiles) do
		local gx, gy = t[1], t[2];
		local idx = pidx(gx, gy, iW);
		local k = gx .. "," .. gy;
		local rd = dist[k];
		if rd == nil then rd = 99; end
		if gx == cx and gy == cy then
			_geothermal_island_plot = idx;
			plotTypes[idx] = PlotTypes.PLOT_LAND;
			markSnow(gx, gy);
		elseif rd == 1 then
			local r1 = Map.Rand(100, "");
			if r1 < 2 then
				plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
			elseif r1 < 82 then
				plotTypes[idx] = PlotTypes.PLOT_LAND;
			else
				plotTypes[idx] = PlotTypes.PLOT_HILLS;
			end
			markSnow(gx, gy);
		elseif rd >= 2 then
			plotTypes[idx] = randOuter();
			local pt = plotTypes[idx];
			if pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS or pt == PlotTypes.PLOT_MOUNTAIN then
				markSnow(gx, gy);
			end
		end
	end
	for _, t in ipairs(landTiles) do
		local gx, gy = t[1], t[2];
		if gx == cx and gy == cy then
		else
			local k = gx .. "," .. gy;
			local rd = dist[k];
			if rd == 1 or rd == 2 then
				local idx = pidx(gx, gy, iW);
				local pt = plotTypes[idx];
				if pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS then
					_geothermal_forest_ring_indices[#_geothermal_forest_ring_indices + 1] = idx;
				end
			end
		end
	end
end
