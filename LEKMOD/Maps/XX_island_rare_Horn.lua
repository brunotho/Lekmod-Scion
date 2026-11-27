-- Short curved horn of land off the coast with a ridge and a sheltered bay beside the mainland.

include("X_IslandHelpers");

local function pidx(x, y, iW) return y * iW + x + 1; end
local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function isOcean(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	return plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_OCEAN;
end

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

local COAST_MARGIN = 4;

local function findCoastCandidates(plotTypes, iW, iH, wrapX, wrapY)
	local candidates = {};
	for y = COAST_MARGIN, iH - 1 - COAST_MARGIN do
		for x = 0, iW - 1 do
			if isLand(plotTypes, x, y, iW, iH) then
				local oceanDirs = {};
				for dir = 1, 6 do
					local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isOcean(plotTypes, nx, ny, iW, iH) then
						oceanDirs[#oceanDirs + 1] = {dir = dir, x = nx, y = ny};
					end
				end
				if #oceanDirs > 0 then
					candidates[#candidates + 1] = {baseX = x, baseY = y, oceanDirs = oceanDirs};
				end
			end
		end
	end
	return candidates;
end

local function hasSpaceForHorn(plotTypes, startX, startY, dir, len, iW, iH, wrapX, wrapY)
	local x, y = startX, startY;
	for step = 1, len do
		local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
		if nx < 0 or nx >= iW or ny < 0 or ny >= iH then return false; end
		if not isOcean(plotTypes, nx, ny, iW, iH) then return false; end
		x, y = nx, ny;
	end
	return true;
end

function TryPlaceHornIsland(plotTypes, opts)
	local iW, iH = opts.iW, opts.iH;
	local wrapX = opts.wrapX or true;
	local wrapY = opts.wrapY or false;

	local candidates = findCoastCandidates(plotTypes, iW, iH, wrapX, wrapY);
	if #candidates < 5 then return false; end

	for attempt = 1, math.min(60, #candidates * 3) do
		local c = candidates[Map.Rand(#candidates, "") + 1];
		local baseY = c.baseY;
		local distFromEdge = math.min(baseY, iH - 1 - baseY);
		if distFromEdge >= 10 then
			local oceanPick = c.oceanDirs[Map.Rand(#c.oceanDirs, "") + 1];
			local outDir = oceanPick.dir;
			local startX, startY = oceanPick.x, oceanPick.y;

			local len = 4 + Map.Rand(4, "");
			if not hasSpaceForHorn(plotTypes, startX, startY, outDir, len - 1, iW, iH, wrapX, wrapY) then
			else
				local width = 1 + Map.Rand(2, "");
				local curveStart = 2 + Map.Rand(2, "");
				local curveSide = (Map.Rand(2, "") == 0) and -1 or 1;
				local ridgeExtend = 2 + Map.Rand(3, "");
				local mtnPct = 40 + Map.Rand(31, "");

				local landTiles, spineTiles, ridgeTiles = buildHornShape(
					plotTypes, c.baseX, c.baseY, startX, startY, outDir, len, width,
					curveStart, curveSide, iW, iH, wrapX, wrapY
				);
				if landTiles and #landTiles >= 6 then
					extendRidgeOntoMainland(plotTypes, c.baseX, c.baseY, outDir, ridgeExtend,
						mtnPct, iW, iH, wrapX, wrapY);
					DrawHorn(plotTypes, landTiles, ridgeTiles, mtnPct, iW);
					return true;
				end
			end
		end
	end
	return false;
end

function buildHornShape(plotTypes, baseX, baseY, startX, startY, outDir, len, width,
	curveStart, curveSide, iW, iH, wrapX, wrapY)
	local landTiles = {};
	local spineTiles = {};
	local ridgeTiles = {};
	local landSet = {};

	local leftDir = rotDir(outDir, -1);
	local rightDir = rotDir(outDir, 1);

	local x, y = startX, startY;
	local dir = outDir;
	for i = 1, len do
		if i > 1 then
			if i == curveStart + 1 then
				dir = rotDir(dir, curveSide);
			end
			if i == len then
				dir = rotDir(dir, curveSide);
			end
			local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
			if nx < 0 or nx >= iW or ny < 0 or ny >= iH then break; end
			if not isOcean(plotTypes, nx, ny, iW, iH) then break; end
			x, y = nx, ny;
		end

		spineTiles[#spineTiles + 1] = {x, y};
		landTiles[#landTiles + 1] = {x, y};
		landSet[x .. "," .. y] = true;

		if width >= 2 and Map.Rand(100, "") < 50 then
			local perpDir = (Map.Rand(2, "") == 0) and leftDir or rightDir;
			local wx, wy = GetHexNeighbor(x, y, perpDir, iW, iH, wrapX, wrapY);
			if wx >= 0 and wx < iW and wy >= 0 and wy < iH and isOcean(plotTypes, wx, wy, iW, iH)
				and not landSet[wx .. "," .. wy] then
				landTiles[#landTiles + 1] = {wx, wy};
				landSet[wx .. "," .. wy] = true;
			end
		end
	end

	if #spineTiles > 0 and Map.Rand(100, "") < 80 then
		local extraIdx = Map.Rand(#spineTiles, "") + 1;
		local tx, ty = spineTiles[extraIdx][1], spineTiles[extraIdx][2];
		local perpDir = (Map.Rand(2, "") == 0) and leftDir or rightDir;
		local ex, ey = GetHexNeighbor(tx, ty, perpDir, iW, iH, wrapX, wrapY);
		if ex >= 0 and ex < iW and ey >= 0 and ey < iH and isOcean(plotTypes, ex, ey, iW, iH)
			and not landSet[ex .. "," .. ey] then
			landTiles[#landTiles + 1] = {ex, ey};
			landSet[ex .. "," .. ey] = true;
		end
	end

	local numRidge = math.max(2, #spineTiles - 1);
	for i = 1, numRidge do
		local idx = math.floor((i - 1) * (#spineTiles - 1) / math.max(1, numRidge - 1)) + 1;
		idx = math.min(idx, #spineTiles);
		ridgeTiles[#ridgeTiles + 1] = spineTiles[idx];
	end
	ridgeTiles[#ridgeTiles + 1] = spineTiles[#spineTiles];

	return landTiles, spineTiles, ridgeTiles;
end

function extendRidgeOntoMainland(plotTypes, baseX, baseY, outDir, ridgeExtend,
	mtnPct, iW, iH, wrapX, wrapY)
	local backDir = rotDir(outDir, 3);
	local x, y = baseX, baseY;
	for step = 1, ridgeExtend do
		local nx, ny = GetHexNeighbor(x, y, backDir, iW, iH, wrapX, wrapY);
		if nx < 0 or nx >= iW or ny < 0 or ny >= iH then break; end
		if not isLand(plotTypes, nx, ny, iW, iH) then break; end
		x, y = nx, ny;
		local idx = pidx(x, y, iW);
		if Map.Rand(100, "") < mtnPct then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		else
			plotTypes[idx] = (Map.Rand(100, "") < 60) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end

function DrawHorn(plotTypes, landTiles, ridgeTiles, mtnPct, iW)
	local ridgeSet = {};
	for _, t in ipairs(ridgeTiles) do
		ridgeSet[t[1] .. "," .. t[2]] = true;
	end
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = pidx(x, y, iW);
		if ridgeSet[x .. "," .. y] then
			plotTypes[idx] = (Map.Rand(100, "") < mtnPct) and PlotTypes.PLOT_MOUNTAIN
				or ((Map.Rand(100, "") < 60) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND);
		else
			plotTypes[idx] = (Map.Rand(100, "") < 60) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
