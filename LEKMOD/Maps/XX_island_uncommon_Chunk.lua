-- Medium island from a radius-3 scattered disk, six to ten tiles with mixed hills, some mountains.

include("X_IslandHelpers");

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

function TryPlaceChunkIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 1;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 6;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local landTiles = GetScatteredDiskLandTiles(cx, cy, 3, params.iW, params.iH, params.wrapX, params.wrapY);
	if #landTiles < 6 or #landTiles > 10 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	local landSet = {};
	for _, t in ipairs(landTiles) do landSet[t[1] .. "," .. t[2]] = t; end

	local hillThresh = 50 + Map.Rand(21, "");
	local mtnChance = 2 + Map.Rand(4, "");
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local ring = t[3] or 0;
		local idx = y * params.iW + x + 1;
		local ht = hillThresh + (ring * 5) + Map.Rand(11, "") - 5;
		ht = math.max(40, math.min(80, ht));
		local mt = (Map.Rand(100, "") < ht) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		if mt == PlotTypes.PLOT_LAND and Map.Rand(100, "") < mtnChance then
			mt = PlotTypes.PLOT_MOUNTAIN;
		end
		plotTypes[idx] = mt;
	end

	if Map.Rand(100, "") < 8 then
		local centerCluster = {};
		if landSet[cx .. "," .. cy] then centerCluster[#centerCluster + 1] = {cx, cy}; end
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, params.iW, params.iH, params.wrapX, params.wrapY);
			if landSet[nx .. "," .. ny] then centerCluster[#centerCluster + 1] = {nx, ny}; end
		end
		local n = math.min(2 + Map.Rand(2, ""), #centerCluster);
		for i = 1, n do
			if #centerCluster == 0 then break; end
			local pick = 1 + Map.Rand(#centerCluster, "");
			local t = centerCluster[pick];
			centerCluster[pick] = centerCluster[#centerCluster];
			centerCluster[#centerCluster] = nil;
			plotTypes[t[2] * params.iW + t[1] + 1] = PlotTypes.PLOT_MOUNTAIN;
		end
	end
	return true;
end
