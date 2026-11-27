-- A short wiggly chain of four to six tiles along hex steps, biased to run alongshore (parallel to pangaea).

include("X_IslandHelpers");

local CONFIG = {
	HILLS_PCT_MIN = 50, HILLS_PCT_RANGE = 11,
	MTN_CHANCE_SMALL = 0, MTN_CHANCE_LARGE = 0,
	SIZE_THRESHOLD = 6,
	TURN_PCT = 48,
	GILL_PCT = 26,
	ALONG_PREFERRED_TURN_PCT = 72,
};

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

local function bestStepDirToward(ox, oy, lx, ly, iW, iH, wrapX, wrapY)
	local bestD, bestScore = 1, 1e9;
	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(ox, oy, d, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
			local dx, dy = lx - nx, ly - ny;
			local sc = dx * dx + dy * dy;
			if sc < bestScore then
				bestScore = sc;
				bestD = d;
			end
		end
	end
	return bestD;
end

local function hexDirMargin(a, b)
	local d = math.abs(a - b);
	return math.min(d, 6 - d);
end

local function alongshoreDirs(towardLand)
	return rotDir(towardLand, 1), rotDir(towardLand, 5);
end

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

function TryPlaceStripIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if params.nearPangea == false then return false; end
	local pullBack = params.pullBack or 1;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 6;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local lx, ly = params.landX, params.landY;
	local towardLand = nil;
	if lx ~= nil and ly ~= nil then
		towardLand = bestStepDirToward(cx, cy, lx, ly, params.iW, params.iH, params.wrapX, params.wrapY);
	end

	local tanA, tanB = 1, 3;
	if towardLand then
		tanA, tanB = alongshoreDirs(towardLand);
	end
	local dir;
	if towardLand then
		dir = (Map.Rand(2, "") == 0) and tanA or tanB;
	else
		dir = Map.Rand(6, "") + 1;
	end

	local size = 4 + Map.Rand(3, "");
	local landTiles = {{cx, cy}};
	local x, y = cx, cy;
	local used = {}; used[cx .. "," .. cy] = true;

	for _ = 1, size - 1 do
		if #landTiles == 4 then
			local delta = (Map.Rand(2, "") == 0) and -1 or 1;
			dir = rotDir(dir, delta);
		elseif Map.Rand(100, "") < CONFIG.TURN_PCT then
			local delta = (Map.Rand(2, "") == 0) and -1 or 1;
			dir = rotDir(dir, delta);
		end
		if towardLand and Map.Rand(100, "") < CONFIG.ALONG_PREFERRED_TURN_PCT then
			if math.min(hexDirMargin(dir, tanA), hexDirMargin(dir, tanB)) >= 2 then
				dir = (Map.Rand(2, "") == 0) and tanA or tanB;
			end
		end

		local tryOrder = {};
		for j = 0, 5 do
			tryOrder[j + 1] = ((dir + j - 1) % 6) + 1;
		end
		if towardLand then
			-- Random tie-break rolled once per dir: a comparator that calls Map.Rand is inconsistent
			-- and makes table.sort throw ("invalid order function" / nil compare).
			local tieKey = {};
			for _, d in ipairs(tryOrder) do
				tieKey[d] = Map.Rand(1000, "");
			end
			table.sort(tryOrder, function(a, b)
				local sa = math.min(hexDirMargin(a, tanA), hexDirMargin(a, tanB));
				local sb = math.min(hexDirMargin(b, tanA), hexDirMargin(b, tanB));
				if sa ~= sb then return sa < sb; end
				if tieKey[a] ~= tieKey[b] then return tieKey[a] < tieKey[b]; end
				return a < b;
			end);
		end

		local placedStep = false;
		for _, tryDir in ipairs(tryOrder) do
			local nx, ny = GetHexNeighbor(x, y, tryDir, params.iW, params.iH, params.wrapX, params.wrapY);
			if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and not used[nx .. "," .. ny] then
				landTiles[#landTiles + 1] = {nx, ny};
				used[nx .. "," .. ny] = true;
				x, y = nx, ny;
				dir = tryDir;
				placedStep = true;
				break;
			end
		end
		if not placedStep then
			break;
		end
	end

	if #landTiles < 4 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	DrawStripIsland(plotTypes, landTiles, params.iW);
	return true;
end

function DrawStripIsland(plotTypes, landTiles, iW)
	local hillsPct = CONFIG.HILLS_PCT_MIN + Map.Rand(CONFIG.HILLS_PCT_RANGE, "");
	local n = #landTiles;
	local mtnChance = (n <= CONFIG.SIZE_THRESHOLD) and CONFIG.MTN_CHANCE_SMALL or CONFIG.MTN_CHANCE_LARGE;
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		local mt = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		if mt == PlotTypes.PLOT_LAND and Map.Rand(100, "") < mtnChance then
			mt = PlotTypes.PLOT_MOUNTAIN;
		end
		plotTypes[idx] = mt;
	end
	if n >= 4 and Map.Rand(100, "") < CONFIG.GILL_PCT then
		local lo, hi = 2, n - 1;
		if lo <= hi then
			local i = lo + Map.Rand(hi - lo + 1, "");
			local t = landTiles[i];
			plotTypes[t[2] * iW + t[1] + 1] = PlotTypes.PLOT_OCEAN;
		end
	end
end
