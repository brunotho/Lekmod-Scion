-- Long thin meandering island that follows the coast one water tile out; usually hills and land, sometimes a
-- mountain head or a mid-body mountain cluster. Longer than 6 tiles: a 1-2 tile water cut splits it in two.

include("X_IslandHelpers");

local HILLS_MIN = 40;
local HILLS_MAX = 75;

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

local SPINE_LEN_MIN = 9;      -- spine tiles (9..12)
local SPINE_LEN_RANGE = 4;
local SPINE_MIN_OK = 8;       -- shorter walks (coast ran out / blocked) are rejected
local SPLIT_OVER = 6;         -- spines longer than this get a 1-2 tile water cut (two islands, each >= 3)
local STRAIGHT_PCT = 50;      -- per step: keep heading, else try a 60-degree turn first
local DRIFT_PCT = 30;         -- per step: allow one tile two water tiles out (wiggle), never twice in a row

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

-- 1 = touches land, 2 = land exactly two away (one water tile between), 3 = further.
local function landDist(plotTypes, x, y, iW, iH, wrapX, wrapY)
	for r = 1, 2 do
		for _, n in ipairs(GetHexRingAtRadius(x, y, r, iW, iH, wrapX, wrapY)) do
			if isLand(plotTypes, n[1], n[2], iW, iH) then return r; end
		end
	end
	return 3;
end

-- Walk along the coast one water tile out, keeping the line one tile thin (a new tile may only touch the
-- previous spine tile).
local function walkCoast(plotTypes, sx, sy, heading, steps, spineSet, p)
	local out = {};
	local x, y, h = sx, sy, heading;
	local offCoast = 0;
	for _ = 1, steps do
		local order;
		if Map.Rand(100, "snakeStraight") < STRAIGHT_PCT then
			order = (Map.Rand(2, "") == 0) and {0, 1, -1} or {0, -1, 1};
		else
			order = (Map.Rand(2, "") == 0) and {1, 0, -1} or {-1, 0, 1};
		end
		local drift = offCoast == 0 and Map.Rand(100, "snakeDrift") < DRIFT_PCT;
		local pick = nil;
		for pass = 1, 2 do
			for _, off in ipairs(order) do
				local d = rotDir(h, off);
				local nx, ny = GetHexNeighbor(x, y, d, p.iW, p.iH, p.wrapX, p.wrapY);
				local nk = nx .. "," .. ny;
				if nx >= 0 and nx < p.iW and ny >= 0 and ny < p.iH and not spineSet[nk] then
					local ld = landDist(plotTypes, nx, ny, p.iW, p.iH, p.wrapX, p.wrapY);
					local want = (pass == 1) and 2 or 3;
					if ld == want and (pass == 1 or drift) then
						local thin = true;
						for _, n in ipairs(GetHexRingAtRadius(nx, ny, 1, p.iW, p.iH, p.wrapX, p.wrapY)) do
							local k = n[1] .. "," .. n[2];
							if spineSet[k] and not (n[1] == x and n[2] == y) then thin = false; break; end
						end
						if thin then pick = { nx, ny, d, ld }; break; end
					end
				end
			end
			if pick then break; end
		end
		if not pick then break; end
		x, y, h = pick[1], pick[2], pick[3];
		offCoast = (pick[4] == 2) and 0 or offCoast + 1;
		spineSet[x .. "," .. y] = true;
		out[#out + 1] = { x, y };
	end
	-- Do not end on a drifted tile.
	if #out > 0 and offCoast > 0 then
		local t = table.remove(out);
		spineSet[t[1] .. "," .. t[2]] = nil;
	end
	return out;
end

function TryPlaceSnakeIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 1;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 1;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local iW, iH, wrapX, wrapY = params.iW, params.iH, params.wrapX, params.wrapY;
	if centerX < 0 or centerX >= iW or centerY < 0 or centerY >= iH then return false; end
	if landDist(plotTypes, centerX, centerY, iW, iH, wrapX, wrapY) ~= 2 then return false; end

	-- Headings along the coast from the seed: neighbours that also sit one water tile out.
	local dirs = {};
	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(centerX, centerY, d, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH and landDist(plotTypes, nx, ny, iW, iH, wrapX, wrapY) == 2 then
			dirs[#dirs + 1] = d;
		end
	end
	if #dirs == 0 then return false; end
	local hA = dirs[1 + Map.Rand(#dirs, "snakeHeading")];

	local len = SPINE_LEN_MIN + Map.Rand(SPINE_LEN_RANGE, "snakeLen");
	local spineSet = { [centerX .. "," .. centerY] = true };
	local a = walkCoast(plotTypes, centerX, centerY, hA, len - 1, spineSet, params);
	local b = {};
	if #a < len - 1 then
		-- Grow the other way from the seed, roughly opposite heading.
		b = walkCoast(plotTypes, centerX, centerY, rotDir(hA, 3), len - 1 - #a, spineSet, params);
	end
	local spine = {};
	for i = #b, 1, -1 do spine[#spine + 1] = b[i]; end
	spine[#spine + 1] = { centerX, centerY };
	for _, t in ipairs(a) do spine[#spine + 1] = t; end
	if #spine < SPINE_MIN_OK then return false; end

	local cutFrom, cutLen = nil, 0;
	if #spine > SPLIT_OVER then
		cutLen = 1 + Map.Rand(2, "snakeCutLen");
		-- Both pieces keep >= 3 tiles: cut starts at 4 .. #spine - cutLen - 2.
		local lo, hi = 4, #spine - cutLen - 2;
		if hi >= lo then cutFrom = lo + Map.Rand(hi - lo + 1, "snakeCutAt"); end
	end
	local landTiles = {};
	for i, t in ipairs(spine) do
		if not (cutFrom and i >= cutFrom and i < cutFrom + cutLen) then
			landTiles[#landTiles + 1] = { t[1], t[2] };
		end
	end

	local variant = Map.Rand(100, "");
	local hasHead = (variant < 3);
	local hasMountainCluster = (variant >= 3 and variant < 6);

	if not footprintClear(plotTypes, landTiles, iW, iH) then return false; end

	DrawSnakeIsland(plotTypes, landTiles, hasHead, hasMountainCluster, iW, iH, wrapX, wrapY);
	return true;
end

function DrawSnakeIsland(plotTypes, landTiles, hasHead, hasMountainCluster, iW, iH, wrapX, wrapY)
	wrapY = wrapY or false;
	local mountainTiles = {};
	if hasHead then
		local endIdx = (#landTiles >= 2) and ((Map.Rand(2, "") == 0) and 1 or #landTiles) or 1;
		mountainTiles[#mountainTiles + 1] = landTiles[endIdx];
	elseif hasMountainCluster then
		local mid = math.floor(#landTiles / 2);
		local clusterSize = 2 + Map.Rand(3, "");
		for i = math.max(1, mid - 1), math.min(#landTiles, mid + 2) do
			if #mountainTiles < clusterSize then
				mountainTiles[#mountainTiles + 1] = landTiles[i];
			end
		end
	end

	local mountainSet = {};
	for _, t in ipairs(mountainTiles) do
		mountainSet[t[1] .. "," .. t[2]] = true;
	end

	local hillsPct = HILLS_MIN + Map.Rand(HILLS_MAX - HILLS_MIN + 1, "");
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		if mountainSet[x .. "," .. y] then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		else
			plotTypes[idx] = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
