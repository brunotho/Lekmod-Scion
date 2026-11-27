-- Two S-curved islands facing each other so their inner sides form twin bays.

include("X_IslandHelpers");

local GILL_PCT = 30;

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[y * iW + x + 1];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function footprintClear(plotTypes, tiles, iW, iH)
	for _, t in ipairs(tiles) do
		if isLand(plotTypes, t[1], t[2], iW, iH) then return false; end
	end
	return true;
end

local function buildSSpine(cx, cy, startDir, iW, iH, wrapX, wrapY)
	local seg1 = 2 + Map.Rand(2, "");
	local trans = 1 + Map.Rand(2, "");
	local seg2 = 2 + Map.Rand(2, "");
	local dir = startDir;
	local turn1 = (Map.Rand(2, "") == 0) and -1 or 1;
	local turn2 = -turn1;
	local spine = {{cx, cy}};
	local x, y = cx, cy;
	for _ = 1, seg1 - 1 do
		dir = ((dir + turn1 + 5) % 6) + 1;
		local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
			spine[#spine + 1] = {nx, ny}; x, y = nx, ny;
		else break; end
	end
	for _ = 1, trans do
		local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
			spine[#spine + 1] = {nx, ny}; x, y = nx, ny;
		else break; end
	end
	for _ = 1, seg2 - 1 do
		dir = ((dir + turn2 + 5) % 6) + 1;
		local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
			spine[#spine + 1] = {nx, ny}; x, y = nx, ny;
		else break; end
	end
	return spine;
end

function TryPlaceTwinBayIslands(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 2;
	local effMin = params.effMin or 2;
	local effMax = params.effMax or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local gap = 1 + Map.Rand(2, "");
	local dir = Map.Rand(6, "") + 1;
	local isl1X, isl1Y = cx, cy;
	local isl2X, isl2Y = cx, cy;
	for _ = 1, gap + 1 do
		isl2X, isl2Y = GetHexNeighbor(isl2X, isl2Y, dir, params.iW, params.iH, params.wrapX, params.wrapY);
		if isl2X < 0 or isl2X >= params.iW or isl2Y < 0 or isl2Y >= params.iH then return false; end
	end

	local oppDir = ((dir + 2) % 6) + 1;
	local tiles1 = buildSSpine(isl1X, isl1Y, dir, params.iW, params.iH, params.wrapX, params.wrapY);
	local tiles2 = buildSSpine(isl2X, isl2Y, oppDir, params.iW, params.iH, params.wrapX, params.wrapY);
	if #tiles1 < 4 or #tiles2 < 4 then return false; end

	local occupied = {};
	for _, t in ipairs(tiles1) do occupied[t[1] .. "," .. t[2]] = true; end
	for _, t in ipairs(tiles2) do
		if occupied[t[1] .. "," .. t[2]] then return false; end
	end

	local landTiles = {};
	for _, t in ipairs(tiles1) do landTiles[#landTiles + 1] = {t[1], t[2], 1}; end
	for _, t in ipairs(tiles2) do landTiles[#landTiles + 1] = {t[1], t[2], 2}; end

	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	DrawTwinBayIslands(plotTypes, landTiles, tiles1, tiles2, params.iW);
	return true;
end

function DrawTwinBayIslands(plotTypes, landTiles, tiles1, tiles2, iW)
	local hillsPct = 40 + Map.Rand(11, "");
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		plotTypes[idx] = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
	end
	if Map.Rand(100, "") >= GILL_PCT then return; end
	local which = Map.Rand(2, "") + 1;
	local spine = (which == 1) and tiles1 or tiles2;
	local n = #spine;
	if n < 4 then return; end
	local lo, hi = 2, n - 1;
	local i = lo + Map.Rand(hi - lo + 1, "");
	local t = spine[i];
	local idx = t[2] * iW + t[1] + 1;
	plotTypes[idx] = PlotTypes.PLOT_OCEAN;
end
