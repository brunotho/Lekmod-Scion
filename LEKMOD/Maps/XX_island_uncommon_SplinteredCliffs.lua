-- Broken coastal cliff escarpment: thin mountain segments with water gaps + detached peaklets.
-- Stays shore-close via pullBack/eff* from the island table; grows along-shore, not as a filled oval.

include("X_IslandHelpers");

local CONFIG = {
	SPINE_LEN_MIN = 7,
	SPINE_LEN_MAX = 11,
	GAP_COUNT_MIN = 1,
	GAP_COUNT_MAX = 2,
	PEAK_BUMP_PCT = 28,
	TURN_PCT = 38,
	SEAWARD_NUDGE_PCT = 22,
	DETACHED_MIN = 2,
	DETACHED_MAX = 4,
	DETACHED_CLUSTER_MAX = 2,
	FOOT_HILL_PCT = 24,
	MIN_MOUNTAINS = 8,
	MAX_LAND_TILES = 22,
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

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

local function kxy(x, y)
	return x .. "," .. y;
end

local function wrapDelta(a, b, size, doWrap)
	local d = b - a;
	if doWrap and size > 0 then
		if d > size / 2 then d = d - size; end
		if d < -size / 2 then d = d + size; end
	end
	return d;
end

local function hexDistApprox(ax, ay, bx, by, iW, iH, wrapX, wrapY)
	local dx = wrapDelta(ax, bx, iW, wrapX);
	local dy = wrapDelta(ay, by, iH, wrapY);
	return math.abs(dx) + math.abs(dy);
end

local function bestDirToward(x, y, tx, ty, iW, iH, wrapX, wrapY)
	local bestDir, bestDist = 1, 9999;
	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
		local dist = hexDistApprox(nx, ny, tx, ty, iW, iH, wrapX, wrapY);
		if dist < bestDist then
			bestDist = dist;
			bestDir = d;
		end
	end
	return bestDir;
end

function TryPlaceSplinteredCliffsIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.splinteredCliffs then return false; end

	local pullBack = params.pullBack or 0;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 2;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local landX = params.landX or cx;
	local landY = params.landY or cy;
	local towardLand = bestDirToward(cx, cy, landX, landY, params.iW, params.iH, params.wrapX, params.wrapY);
	local seaward = rotDir(towardLand, 3);
	local alongA = rotDir(towardLand, 2);
	local alongB = rotDir(towardLand, -2);
	local walkDir = (Map.Rand(2, "scAlong") == 0) and alongA or alongB;

	local mountainSet = {};
	local hillSet = {};
	local allSet = {};
	local allTiles = {};
	local spine = {};

	local function tryAdd(x, y, asMountain)
		if x < 0 or x >= params.iW or y < 0 or y >= params.iH then return false; end
		local k = kxy(x, y);
		if allSet[k] then return false; end
		if #allTiles >= CONFIG.MAX_LAND_TILES then return false; end
		allSet[k] = true;
		allTiles[#allTiles + 1] = { x, y };
		if asMountain then
			mountainSet[k] = true;
		else
			hillSet[k] = true;
		end
		return true;
	end

	local spineLen = CONFIG.SPINE_LEN_MIN + Map.Rand(CONFIG.SPINE_LEN_MAX - CONFIG.SPINE_LEN_MIN + 1, "scLen");
	local gapCount = CONFIG.GAP_COUNT_MIN + Map.Rand(CONFIG.GAP_COUNT_MAX - CONFIG.GAP_COUNT_MIN + 1, "scGaps");
	local gapSlots = {};
	do
		local candidates = {};
		for i = 3, spineLen - 2 do
			candidates[#candidates + 1] = i;
		end
		for i = #candidates, 2, -1 do
			local j = 1 + Map.Rand(i, "scGapShuf");
			candidates[i], candidates[j] = candidates[j], candidates[i];
		end
		local used = {};
		local placed = 0;
		for _, slot in ipairs(candidates) do
			if placed >= gapCount then break; end
			if not used[slot - 1] and not used[slot + 1] then
				gapSlots[slot] = true;
				used[slot] = true;
				placed = placed + 1;
			end
		end
	end

	local x, y = cx, cy;
	for step = 1, spineLen do
		local isGap = gapSlots[step] == true;
		if not isGap then
			if tryAdd(x, y, true) then
				spine[#spine + 1] = { x, y };
				if Map.Rand(100, "scBump") < CONFIG.PEAK_BUMP_PCT then
					local bumpDir = (Map.Rand(2, "scBumpSide") == 0) and seaward or rotDir(walkDir, Map.Rand(2, "") == 0 and 1 or -1);
					local bx, by = GetHexNeighbor(x, y, bumpDir, params.iW, params.iH, params.wrapX, params.wrapY);
					tryAdd(bx, by, true);
				end
			end
		end

		if Map.Rand(100, "scTurn") < CONFIG.TURN_PCT then
			walkDir = rotDir(walkDir, Map.Rand(2, "scTurnSign") == 0 and 1 or -1);
		elseif Map.Rand(100, "scSea") < CONFIG.SEAWARD_NUDGE_PCT then
			walkDir = seaward;
		else
			local preferAlong = (walkDir == alongA or walkDir == alongB) and walkDir or alongA;
			if Map.Rand(2, "scReAlong") == 0 then preferAlong = alongA; else preferAlong = alongB; end
			if Map.Rand(100, "scKeep") < 70 then
				walkDir = preferAlong;
			end
		end

		local nx, ny = GetHexNeighbor(x, y, walkDir, params.iW, params.iH, params.wrapX, params.wrapY);
		if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then break; end
		if hexDistApprox(nx, ny, landX, landY, params.iW, params.iH, params.wrapX, params.wrapY)
			< hexDistApprox(x, y, landX, landY, params.iW, params.iH, params.wrapX, params.wrapY)
			and Map.Rand(100, "scAvoidLand") < 80 then
			nx, ny = GetHexNeighbor(x, y, seaward, params.iW, params.iH, params.wrapX, params.wrapY);
			walkDir = seaward;
			if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then break; end
		end
		x, y = nx, ny;
	end

	if #spine < 4 then return false; end

	local detachedN = CONFIG.DETACHED_MIN + Map.Rand(CONFIG.DETACHED_MAX - CONFIG.DETACHED_MIN + 1, "scDetN");
	for _ = 1, detachedN do
		if #spine == 0 then break; end
		local seed = spine[1 + Map.Rand(#spine, "scDetSeed")];
		local dx, dy = seed[1], seed[2];
		local steps = 1 + Map.Rand(2, "scDetDist");
		local ok = true;
		for _s = 1, steps do
			dx, dy = GetHexNeighbor(dx, dy, seaward, params.iW, params.iH, params.wrapX, params.wrapY);
			if dx < 0 or dx >= params.iW or dy < 0 or dy >= params.iH then
				ok = false;
				break;
			end
			if Map.Rand(100, "scDetWiggle") < 35 then
				local wdir = rotDir(seaward, Map.Rand(2, "") == 0 and 1 or -1);
				local wx, wy = GetHexNeighbor(dx, dy, wdir, params.iW, params.iH, params.wrapX, params.wrapY);
				if wx >= 0 and wx < params.iW and wy >= 0 and wy < params.iH then
					dx, dy = wx, wy;
				end
			end
		end
		if ok and not allSet[kxy(dx, dy)] then
			tryAdd(dx, dy, true);
			local cluster = 1 + Map.Rand(CONFIG.DETACHED_CLUSTER_MAX, "scDetCl");
			for _c = 2, cluster do
				local cd = Map.Rand(6, "scDetAdj") + 1;
				local ax, ay = GetHexNeighbor(dx, dy, cd, params.iW, params.iH, params.wrapX, params.wrapY);
				tryAdd(ax, ay, true);
			end
		end
	end

	local mtnCount = 0;
	for _ in pairs(mountainSet) do
		mtnCount = mtnCount + 1;
	end
	if mtnCount < CONFIG.MIN_MOUNTAINS then return false; end

	for _, t in ipairs(spine) do
		if Map.Rand(100, "scFoot") < CONFIG.FOOT_HILL_PCT then
			local fx, fy = GetHexNeighbor(t[1], t[2], seaward, params.iW, params.iH, params.wrapX, params.wrapY);
			if fx >= 0 and fx < params.iW and fy >= 0 and fy < params.iH and not allSet[kxy(fx, fy)] then
				tryAdd(fx, fy, false);
			end
		end
	end

	if not footprintClear(plotTypes, allTiles, params.iW, params.iH) then return false; end

	for _, t in ipairs(allTiles) do
		local px, py = t[1], t[2];
		local idx = py * params.iW + px + 1;
		local k = kxy(px, py);
		if mountainSet[k] then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		elseif hillSet[k] then
			plotTypes[idx] = PlotTypes.PLOT_HILLS;
		else
			plotTypes[idx] = (Map.Rand(100, "scHill") < 55) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end

	if not _island_placed then _island_placed = {}; end
	_island_placed.splinteredCliffs = true;
	return true;
end
