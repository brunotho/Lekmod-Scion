-- Triangle of land pinned to the north or south map edge, ridge down the middle, wider at the rim.

include("X_IslandHelpers");

local HILLS_ADJ = 75;
local FLAT_COAST = 75;

function TryPlaceEdgeOfWorldIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.edgeOfWorld then return false; end
	if islLandInRing < 2 then return false; end

	if Map and Map.Rand then
		print("[EdgeOfWorld] TryPlaceEdgeOfWorldIsland at center (" .. tostring(centerX) .. "," .. tostring(centerY) .. "), islLandInRing=" .. tostring(islLandInRing));
	end

	if params.wrapY then return false; end
	local iW, iH = params.iW, params.iH;
	if not iW or not iH then iW, iH = Map.GetGridSize(); end

	local edgeBand = math.min(5, math.floor(iH * 0.15));
	local tipY;
	if centerY <= edgeBand then
		tipY = 0;
	elseif centerY >= iH - 1 - edgeBand then
		tipY = iH - 1;
	else
		if Map and Map.Rand then
			print("[EdgeOfWorld] Rejecting center (" .. tostring(centerX) .. "," .. tostring(centerY) .. ") not near north/south edge (iH=" .. tostring(iH) .. ")");
		end
		return false;
	end

	DrawEdgeOfWorldIsland(plotTypes, centerX, tipY, iW, iH, params.wrapX, params.wrapY);
	if not _island_placed then _island_placed = {}; end
	_island_placed.edgeOfWorld = true;
	if Map and Map.Rand then
		print("[EdgeOfWorld] PLACED at (" .. tostring(centerX) .. "," .. tostring(tipY) .. ")");
	end
	return true;
end

function DrawEdgeOfWorldIsland(plotTypes, centerX, centerY, iW, iH, wrapX, wrapY)
	wrapY = wrapY or false;

	local baseWidth = 6 + Map.Rand(3, "");
	local maxRows = baseWidth + 2;
	local numRidge = 4 + Map.Rand(3, "");
	local ridgeWaterExt = (Map.Rand(100, "") < 5) and 1 or 0;

	local southEdge = (centerY == 0);
	local dy = southEdge and 1 or -1;
	local rows = {};
	for r = 0, maxRows - 1 do
		local rowY = southEdge and (centerY + r) or (centerY - r);
		if rowY < 0 or rowY >= iH then break; end
		local w = baseWidth - r;
		if w <= 0 and r > 0 then break; end
		if w <= 0 then w = 1; end
		rows[#rows + 1] = {y = rowY, width = w};
	end

	local landTiles = {};
	local ridgeTiles = {};
	for _, row in ipairs(rows) do
		local half = math.floor(row.width / 2);
		for dx = -half, half do
			local x = centerX + dx;
			if x >= 0 and x < iW then
				landTiles[#landTiles + 1] = {x, row.y};
			end
		end
		if row.width > 0 then
			local ridgeX = centerX + (Map.Rand(3, "") - 1);
			ridgeX = math.max(centerX - 1, math.min(centerX + 1, ridgeX));
			ridgeTiles[#ridgeTiles + 1] = {ridgeX, row.y};
		end
	end

	if ridgeWaterExt > 0 and #ridgeTiles > 0 then
		local tip = ridgeTiles[#ridgeTiles];
		local extY = tip[2] + dy;
		if extY >= 0 and extY < iH then
			ridgeTiles[#ridgeTiles + 1] = {tip[1], extY};
			landTiles[#landTiles + 1] = {tip[1], extY};
		end
	end

	local ridgeSet = {};
	for _, t in ipairs(ridgeTiles) do
		ridgeSet[t[1] .. "," .. t[2]] = true;
	end
	local landSet = {};
	for _, t in ipairs(landTiles) do
		landSet[t[1] .. "," .. t[2]] = true;
	end

	local ridgePicks = {};
	for i = 1, #ridgeTiles do ridgePicks[i] = i; end
	for i = #ridgePicks, 2, -1 do
		local j = Map.Rand(i, "") + 1;
		ridgePicks[i], ridgePicks[j] = ridgePicks[j], ridgePicks[i];
	end
	local mountainCount = math.min(numRidge, #ridgeTiles);
	for i = 1, mountainCount do
		ridgeSet[ridgeTiles[ridgePicks[i]][1] .. "," .. ridgeTiles[ridgePicks[i]][2]] = "mountain";
	end

	local function isCoast(x, y)
		for dir = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
			if nx < 0 or nx >= iW or ny < 0 or ny >= iH then return true; end
			if not landSet[nx .. "," .. ny] then return true; end
		end
		return false;
	end

	local function adjToMountain(x, y)
		for dir = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
			if ridgeSet[nx .. "," .. ny] == "mountain" then return true; end
		end
		return false;
	end

	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		if ridgeSet[x .. "," .. y] == "mountain" then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		elseif adjToMountain(x, y) then
			plotTypes[idx] = (Map.Rand(100, "") < HILLS_ADJ) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		elseif isCoast(x, y) then
			plotTypes[idx] = (Map.Rand(100, "") < (100 - FLAT_COAST)) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		else
			plotTypes[idx] = (Map.Rand(100, "") < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
