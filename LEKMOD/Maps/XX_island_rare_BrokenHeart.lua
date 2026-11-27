-- Heart-shaped island from a fixed even-r template (point south, cleft north), hills and flat.

include("X_IslandHelpers");

local HEART_ODD_ROW_X_SHIFT = 0;

HEART_TEMPLATE = {
	{0,0},
	{0,1},{-1,1},
	{-1,2},{0,2},{1,2},
	{-2,3},{-1,3},{0,3},{1,3},
	{-2,4},{-1,4},{0,4},{1,4},{2,4},
	{-3,5},{-2,5},{-1,5},{0,5},{1,5},{2,5},
	{-2,6},{-1,6},        {1,6},{2,6},
};

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

function TryPlaceBrokenHeartIsland(plotTypes, centerX, centerY, islLandInRing, params)
	return false;
end

function DrawBrokenHeartIsland(plotTypes, landTiles, riftTiles, iW)
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		plotTypes[idx] = (Map.Rand(100, "") < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
	end
	for _, t in ipairs(riftTiles or {}) do
		plotTypes[t[2] * iW + t[1] + 1] = PlotTypes.PLOT_OCEAN;
	end
end

function ForcePlaceBrokenHeartIsland(plotTypes, cx, cy, iW, iH)
	local landTiles = {};
	for _, t in ipairs(HEART_TEMPLATE) do
		local dy = t[2];
		local absY = cy + dy;
		local dx = 0;
		if (cy % 2 ~= 0) and (dy % 2 ~= 0) then dx = 1; end
		local gx = (cx + t[1] + dx + iW) % iW;
		local gy = absY;
		if gy >= 0 and gy < iH then
			landTiles[#landTiles + 1] = {gx, gy};
		end
	end
	DrawBrokenHeartIsland(plotTypes, landTiles, {}, iW);
	if not _island_placed then _island_placed = {}; end
	_island_placed.brokenHeart = true;
end
