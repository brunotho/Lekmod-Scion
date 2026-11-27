-- Solomon's Mines island hex footprint; mine on body ridge tile; mixed hills below. Random 60 degree rotation per placement.

include("X_IslandHelpers");

local SOLOMONS_EDGE_MARGIN = 10;

local SOLOMONS_ISLAND_HEX_TEMPLATE = {
	{5,0},{6,0},
	{2,1},{3,1},{4,1},{5,1},{6,1},{7,1},
	{1,2},{2,2},{3,2},{4,2},{5,2},{6,2},{7,2},
	{0,3},{1,3},{2,3},{3,3},{4,3},{5,3},{6,3},
	{1,4},{2,4},{5,4},{6,4},
};
local MOUNTAIN_TILES = {
	{5,0},{6,0},
	{2,1},{3,1},{4,1},{5,1},{6,1},{7,1},
	{1,2},{2,2},{3,2},{4,2},{5,2},{6,2},{7,2},
};
local HORN_TILE = { 0, 3 };
local LEG_TILES = { {1,4},{2,4},{5,4},{6,4} };
local NORTHERN_RIDGE = { {5,0},{6,0}, {2,1},{3,1},{4,1},{5,1},{6,1},{7,1} };

local function pidx(x, y, iW)
	return y * iW + x + 1;
end

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	return plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_LAND
		or plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_HILLS
		or plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_MOUNTAIN;
end

local function footprintClear(plotTypes, tiles, iW, iH)
	for _, t in ipairs(tiles) do
		if isLand(plotTypes, t[1], t[2], iW, iH) then return false; end
	end
	return true;
end

local function buildLayout(rotSteps)
	local rot = rotSteps % 6;
	local mountainOnly = {};
	for _, m in ipairs(MOUNTAIN_TILES) do
		local rx, ry = RotateOffset60(m[1], m[2], rot);
		mountainOnly[rx .. "," .. ry] = true;
	end
	local hornx, horny = RotateOffset60(HORN_TILE[1], HORN_TILE[2], rot);
	local hornKey = hornx .. "," .. horny;

	local mountainSet = {};
	for k in pairs(mountainOnly) do mountainSet[k] = true; end
	mountainSet[hornKey] = true;

	local bodySet = {};
	for _, p in ipairs(SOLOMONS_ISLAND_HEX_TEMPLATE) do
		local rx, ry = RotateOffset60(p[1], p[2], rot);
		local k = rx .. "," .. ry;
		if not mountainOnly[k] and k ~= hornKey then bodySet[k] = true; end
	end

	local legTiles = {};
	for _, L in ipairs(LEG_TILES) do
		local rx, ry = RotateOffset60(L[1], L[2], rot);
		legTiles[#legTiles + 1] = { rx, ry };
	end

	local northernRidge = {};
	for _, p in ipairs(NORTHERN_RIDGE) do
		local rx, ry = RotateOffset60(p[1], p[2], rot);
		northernRidge[#northernRidge + 1] = { rx, ry };
	end

	return {
		rot = rot,
		mountainOnly = mountainOnly,
		mountainSet = mountainSet,
		hornKey = hornKey,
		hornx = hornx, horny = horny,
		legTiles = legTiles,
		northernRidge = northernRidge,
		bodySet = bodySet,
	};
end

local function isTemplateCoordAdjacentToMountain(tx, ty, layout)
	for k in pairs(layout.mountainOnly) do
		local mx, my = k:match("([^,]+),([^,]+)");
		mx, my = tonumber(mx), tonumber(my);
		if IsHexAdjacent(tx, ty, mx, my) then return true; end
	end
	if IsHexAdjacent(tx, ty, layout.hornx, layout.horny) then return true; end
	return false;
end

local function spineTileHasBodyNeighbor(dx, dy, bodySet)
	for dir = 1, 6 do
		local adj = (dy % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
		local nx, ny = dx + adj[1], dy + adj[2];
		if bodySet[nx .. "," .. ny] then return true; end
	end
	return false;
end

local function isLegTile(dx, dy, legTiles)
	for _, L in ipairs(legTiles) do
		if L[1] == dx and L[2] == dy then return true; end
	end
	return false;
end

local function northernRidgeNeighbors(dx, dy, northernRidge)
	local out = {};
	for _, p in ipairs(northernRidge) do
		if (p[1] ~= dx or p[2] ~= dy) and IsHexAdjacent(dx, dy, p[1], p[2]) then
			out[#out + 1] = p;
		end
	end
	return out;
end

local function ridgeTilesAwayFromLegs(layout)
	local ridge = {};
	for k in pairs(layout.mountainSet) do
		local mx, my = k:match("([^,]+),([^,]+)");
		mx, my = tonumber(mx), tonumber(my);
		ridge[k] = { mx, my };
	end
	local out = {};
	for _, p in pairs(ridge) do
		local adjToLeg = false;
		for _, L in ipairs(layout.legTiles) do
			if IsHexAdjacent(p[1], p[2], L[1], L[2]) then adjToLeg = true; break; end
		end
		if not adjToLeg then out[#out + 1] = p; end
	end
	return out;
end

function TryPlaceSolomonsMinesIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.solomonsMinesIsland then return false; end
	local pullBack = params.pullBack or 3;
	local effMin = params.effMin or 3;
	local effMax = params.effMax or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local rotSteps = Map.Rand(6, "");
	local layout = buildLayout(rotSteps);

	local landTiles = {};
	for _, off in ipairs(SOLOMONS_ISLAND_HEX_TEMPLATE) do
		local dx, dy = RotateOffset60(off[1], off[2], rotSteps);
		local gx = WrapCoord(cx + dx, params.iW, params.wrapX);
		local gy = WrapCoord(cy - dy, params.iH, params.wrapY);
		if gx >= 0 and gx < params.iW and gy >= 0 and gy < params.iH then
			landTiles[#landTiles + 1] = { gx, gy, dx, dy };
		end
	end

	if #landTiles < 22 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	local iHy = params.iH;
	if iHy < SOLOMONS_EDGE_MARGIN * 2 + 1 then return false; end
	local yMax = iHy - 1 - SOLOMONS_EDGE_MARGIN;
	for _, t in ipairs(landTiles) do
		local gy = t[2];
		if gy < SOLOMONS_EDGE_MARGIN or gy > yMax then return false; end
	end

	_solomons_island_nw_type = (Map.Rand(100, "") < 20) and "FEATURE_GEYSER" or nil;

	DrawSolomonsMinesIsland(plotTypes, landTiles, params.iW, layout);
	if not _island_placed then _island_placed = {}; end
	_island_placed.solomonsMinesIsland = true;
	return true;
end

function DrawSolomonsMinesIsland(plotTypes, landTiles, iW, layout)
	local mountainSet = layout.mountainSet;
	local bodySet = layout.bodySet;
	local LEG_TILES_L = layout.legTiles;
	local NORTHERN_RIDGE_L = layout.northernRidge;

	local splinterSet = {};
	for k in pairs(layout.mountainOnly) do
		if Map.Rand(100, "") < 18 then splinterSet[k] = true; end
	end
	if Map.Rand(100, "") < 18 then splinterSet[layout.hornKey] = true; end

	local baySet = {};
	if Map.Rand(100, "") < 12 then
		local p = NORTHERN_RIDGE_L[1 + Map.Rand(#NORTHERN_RIDGE_L, "")];
		baySet[p[1] .. "," .. p[2]] = true;
		if Map.Rand(100, "") < 50 then
			local adj = northernRidgeNeighbors(p[1], p[2], NORTHERN_RIDGE_L);
			if #adj > 0 then
				local q = adj[1 + Map.Rand(#adj, "")];
				baySet[q[1] .. "," .. q[2]] = true;
			end
		end
	end

	local allowedRidge = ridgeTilesAwayFromLegs(layout);
	local cx, cy = 0, 0;
	for _, t in ipairs(landTiles) do cx = cx + t[3]; cy = cy + t[4]; end
	cx = cx / #landTiles; cy = cy / #landTiles;
	local minesPlotKey = nil;
	if #allowedRidge > 0 then
		local best = allowedRidge[1];
		local bestD = (best[1] - cx)^2 + (best[2] - cy)^2;
		for i = 2, #allowedRidge do
			local p = allowedRidge[i];
			local d = (p[1] - cx)^2 + (p[2] - cy)^2;
			if d < bestD then best = p; bestD = d; end
		end
		minesPlotKey = best[1] .. "," .. best[2];
	end

	local legSkipKey = nil;
	local legSkipKey2 = nil;
	if Map.Rand(100, "") < 25 then
		legSkipKey = LEG_TILES_L[1 + Map.Rand(#LEG_TILES_L, "")];
		legSkipKey = legSkipKey[1] .. "," .. legSkipKey[2];
		if Map.Rand(100, "") < 12 then
			repeat
				legSkipKey2 = LEG_TILES_L[1 + Map.Rand(#LEG_TILES_L, "")];
				legSkipKey2 = legSkipKey2[1] .. "," .. legSkipKey2[2];
			until legSkipKey2 ~= legSkipKey;
		end
	end
	local bodySkipKey = nil;
	if Map.Rand(100, "") < 12 then
		local bodyList = {};
		for k in pairs(bodySet) do bodyList[#bodyList + 1] = k; end
		if #bodyList > 0 then bodySkipKey = bodyList[1 + Map.Rand(#bodyList, "")]; end
	end

	for _, t in ipairs(landTiles) do
		local gx, gy = t[1], t[2];
		local dx, dy = t[3], t[4];
		local idx = pidx(gx, gy, iW);
		local key = dx .. "," .. dy;
		if key == minesPlotKey then
			_solomons_island_mines_plot = idx;
			plotTypes[idx] = PlotTypes.PLOT_LAND;
		elseif key == bodySkipKey then
			plotTypes[idx] = PlotTypes.PLOT_OCEAN;
		elseif mountainSet[key] then
			if baySet[key] then
				plotTypes[idx] = PlotTypes.PLOT_OCEAN;
			else
				local onInnerEdge = spineTileHasBodyNeighbor(dx, dy, bodySet);
				if splinterSet[key] or (onInnerEdge and Map.Rand(100, "") < 38) then
					plotTypes[idx] = PlotTypes.PLOT_HILLS;
				else
					plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
				end
			end
		elseif isLegTile(dx, dy, LEG_TILES_L) then
			if key == legSkipKey or key == legSkipKey2 then
				plotTypes[idx] = PlotTypes.PLOT_OCEAN;
			else
				plotTypes[idx] = (Map.Rand(100, "") < 22) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
			end
		else
			local adjMtn = isTemplateCoordAdjacentToMountain(dx, dy, layout);
			plotTypes[idx] = (adjMtn and Map.Rand(100, "") < 78) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
