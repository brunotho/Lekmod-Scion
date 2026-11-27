-- Sea stacks: a short row of single-tile mountain islets standing one water tile off the coast, parallel to
-- the shore and one water tile apart (eroded-cliff look, e.g. the Twelve Apostles). Sometimes one pair is two
-- water tiles apart. Two rows on the same map never use the same number of stacks. In most rows 1-2 stacks
-- stand one tile further out (two water tiles to the shore).

include("X_IslandHelpers");

local CONFIG = {
	STACKS_MIN = 3, STACKS_RANGE = 1,  -- 3..4 stacks
	FIFTH_STACK_PCT = 20,              -- extra stack at the end of the row
	SHORE_GAP = 2,                     -- hex distance to the nearest land (2 = one water tile between)
	WIDE_GAP_PCT = 10,                 -- one pair of neighbouring stacks two water tiles apart instead of one
	SCAN_RADIUS = 8,                   -- local window for the distance-to-land field
	OUTER_PCT = 60,                    -- rows where some stacks stand one tile further out (two water tiles)
	OUTER_TWO_PCT = 35,                -- of those: two stacks instead of one
};

local function isLand(plotTypes, x, y, iW)
	local t = plotTypes[y * iW + x + 1];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

function TryPlaceSplinteredCliffsTinyIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 0;
	local effMin = params.effMin or 2;
	local effMax = params.effMax or 4;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local iW, iH = params.iW, params.iH;
	local wrapX, wrapY = params.wrapX, params.wrapY;
	local cx = WrapCoord(centerX, iW, wrapX);
	local cy = WrapCoord(centerY, iH, wrapY);
	if cx < 0 or cx >= iW or cy < 2 or cy >= iH - 2 then return false; end

	-- Distance to the mainland in a local window (BFS from mainland tiles; any land if the engine did
	-- not pass the mainland mask). Other land only has to be avoided (no neighbouring land at all).
	local dist, q = {}, {};
	local window = GetHexDisk(cx, cy, CONFIG.SCAN_RADIUS, iW, iH, wrapX, wrapY);
	local inWin = {};
	for _, t in ipairs(window) do
		local k = t[2] * iW + t[1];
		inWin[k] = true;
		local isMain = params.mainland and params.mainland[k + 1] or (not params.mainland and isLand(plotTypes, t[1], t[2], iW));
		if isMain then
			dist[k] = 0;
			q[#q + 1] = k;
		end
	end
	local h = 1;
	while h <= #q do
		local k = q[h];
		h = h + 1;
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), d, iW, iH, wrapX, wrapY);
			local nk = ny * iW + nx;
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and inWin[nk] and dist[nk] == nil then
				dist[nk] = dist[k] + 1;
				q[#q + 1] = nk;
			end
		end
	end
	local function onBand(x, y, gap)
		if y < 2 or y >= iH - 2 or dist[y * iW + x] ~= (gap or CONFIG.SHORE_GAP) then return false; end
		if isLand(plotTypes, x, y, iW) then return false; end
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(plotTypes, nx, ny, iW) then return false; end
		end
		return true;
	end
	if not onBand(cx, cy) then return false; end

	local stacks = { { cx, cy } };
	local function clearOfStacks(x, y)
		for _, s in ipairs(stacks) do
			if Map.PlotDistance(s[1], s[2], x, y) < 2 then return false; end
		end
		return true;
	end
	local want = CONFIG.STACKS_MIN + Map.Rand(CONFIG.STACKS_RANGE + 1, "seaStackCount");
	if Map.Rand(100, "seaStackFifth") < CONFIG.FIFTH_STACK_PCT then want = want + 1; end
	-- Stack counts already used by other rows on this map (reset with _island_placed each engine run).
	local usedCounts = (_island_placed and _island_placed.seaStackCounts) or {};
	if usedCounts[want] then
		local free = {};
		for c = CONFIG.STACKS_MIN, CONFIG.STACKS_MIN + CONFIG.STACKS_RANGE + 1 do
			if not usedCounts[c] then free[#free + 1] = c; end
		end
		if #free == 0 then return false; end
		want = free[1 + Map.Rand(#free, "seaStackCountFree")];
	end
	-- Step (1-based: stack #wideAt + 1) that is two water tiles from the previous stack, or none.
	local wideAt = (Map.Rand(100, "seaStackWide") < CONFIG.WIDE_GAP_PCT) and (1 + Map.Rand(want - 1, "seaStackWideAt")) or nil;

	-- Each next stack: two steps from the previous one, on the one-water-tile band, extending the row
	-- (furthest from the first stack; the second stack picks a side at random).
	while #stacks < want do
		local last = stacks[#stacks];
		local best, bestD, ties = nil, -1, {};
		local step = (#stacks == wideAt) and 3 or 2;
		for _, t in ipairs(GetHexRingAtRadius(last[1], last[2], step, iW, iH, wrapX, wrapY)) do
			if onBand(t[1], t[2]) and clearOfStacks(t[1], t[2]) then
				local d = (#stacks == 1) and 0 or Map.PlotDistance(stacks[1][1], stacks[1][2], t[1], t[2]);
				if d > bestD then
					bestD = d;
					ties = { t };
				elseif d == bestD then
					ties[#ties + 1] = t;
				end
			end
		end
		if #ties == 0 then break; end
		best = ties[1 + Map.Rand(#ties, "seaStackPick")];
		-- Only accept moves that actually extend the row.
		if #stacks >= 2 and bestD <= Map.PlotDistance(stacks[1][1], stacks[1][2], last[1], last[2]) then break; end
		stacks[#stacks + 1] = best;
	end
	if #stacks < CONFIG.STACKS_MIN or usedCounts[#stacks] then return false; end

	-- Noise: in some rows 1-2 stacks step one tile further out (two water tiles to the shore). The first
	-- stack always stays on the one-water-tile band, so the row keeps its mainland anchor.
	if Map.Rand(100, "seaStackOuter") < CONFIG.OUTER_PCT then
		local nOuter = (Map.Rand(100, "seaStackOuterTwo") < CONFIG.OUTER_TWO_PCT) and 2 or 1;
		local order = {};
		for i = 2, #stacks do order[#order + 1] = i; end
		for i = #order, 2, -1 do
			local j = 1 + Map.Rand(i, "seaStackOuterOrder");
			order[i], order[j] = order[j], order[i];
		end
		local moved = 0;
		for _, si in ipairs(order) do
			if moved >= nOuter then break; end
			local s = stacks[si];
			local opts = {};
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(s[1], s[2], d, iW, iH, wrapX, wrapY);
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH and onBand(nx, ny, CONFIG.SHORE_GAP + 1) then
					local ok = true;
					for sj, o in ipairs(stacks) do
						if sj ~= si and Map.PlotDistance(o[1], o[2], nx, ny) < 2 then ok = false; break; end
					end
					if ok then opts[#opts + 1] = { nx, ny }; end
				end
			end
			if #opts > 0 then
				stacks[si] = opts[1 + Map.Rand(#opts, "seaStackOuterPick")];
				moved = moved + 1;
			end
		end
	end

	for _, s in ipairs(stacks) do
		plotTypes[s[2] * iW + s[1] + 1] = PlotTypes.PLOT_MOUNTAIN;
	end
	-- New table (not in-place): the engine rolls _island_placed back by shallow copy on a rejected placement.
	if not _island_placed then _island_placed = {}; end
	local counts = {};
	for c in pairs(usedCounts) do counts[c] = true; end
	counts[#stacks] = true;
	_island_placed.seaStackCounts = counts;
	return true, cx, cy;
end
