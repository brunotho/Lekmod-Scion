-- Shore-following island chain: a spine that tracks the coast one water tile out (sometimes two), cut into
-- 3-5 islets that read as one structure: stretched along the spine, largest in the middle, tapered at
-- the ends, thickened only on the ocean side, evenly spaced, with a hilly spine and an optional peak.

include("X_IslandHelpers");

local CONFIG = {
	HALF_LEN_MIN = 6, HALF_LEN_RANGE = 4,   -- spine columns = 2*half+1 -> 13..19
	SHORE_SCAN_OUT = 4,                     -- start this many rows seaward of the seed when looking for the shore
	SHORE_SCAN_MAX = 14,
	FAR_ISLET_PCT = 25,                     -- islets placed two water tiles out instead of one
	MIN_NEAR_ISLETS = 2,                    -- islets that must sit one water tile off the coast
	MIDDLE_LEN_MIN = 3, MIDDLE_LEN_RANGE = 2,  -- middle islets: 3..4 spine tiles
	END_LEN_MIN = 2, END_LEN_RANGE = 2,        -- first/last islet: 2..3
	GAP2_PCT = 25,                          -- gap of 2 columns instead of 1
	THICKEN_PCT = 50,                       -- inner spine tile gets one ocean-side tile
	MAX_ISLET_TILES = 5,
	MIN_ISLETS = 3, MAX_ISLETS = 5,
	SPINE_HILLS_PCT = 65,
	PEAK_PCT = 50,                          -- middle of the longest islet becomes a mountain
	SIDE_HILLS_PCT = 40,
	MIN_LAND_TILES = 8,
};

local function pidx(x, y, iW)
	return y * iW + x + 1;
end

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function isWater(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	return plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_OCEAN;
end

local function keyXY(x, y)
	return x .. "," .. y;
end

function TryPlaceShoreSineChainIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.shoreSineChain then return false; end

	local pullBack = params.pullBack or 1;
	local effMin = params.effMin;
	if effMin == nil then effMin = 0; end
	local effMax = params.effMax;
	if effMax == nil then effMax = 5; end
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local iW, iH = params.iW, params.iH;
	local wrapX = params.wrapX;
	local wrapY = params.wrapY;
	local cx = WrapCoord(centerX, iW, wrapX);
	local cy = centerY;
	if wrapY then cy = WrapCoord(cy, iH, wrapY); end
	if cx < 0 or cx >= iW or cy < 0 or cy >= iH then return false; end
	if not isWater(plotTypes, cx, cy, iW, iH) then return false; end

	local landY = params.landY;
	local landDirY;
	if type(landY) == "number" then
		landDirY = (landY >= cy) and 1 or -1;
	else
		local midY = math.floor(iH / 2);
		landDirY = (cy >= midY) and -1 or 1;
	end
	local away = -landDirY;

	local chainSet = {}; -- tiles already planned for this chain
	-- Free = ocean, inside the rows, no land neighbour except tiles of this chain in `own`.
	local function free(x, y, own)
		if y < 2 or y >= iH - 2 then return false; end
		if not isWater(plotTypes, x, y, iW, iH) or chainSet[keyXY(x, y)] then return false; end
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local k = keyXY(nx, ny);
				if (isLand(plotTypes, nx, ny, iW, iH) or chainSet[k]) and not (own and own[k]) then return false; end
			end
		end
		return true;
	end
	local function adjacent(a, b)
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(a[1], a[2], d, iW, iH, wrapX, wrapY);
			if nx == b[1] and ny == b[2] then return true; end
		end
		return false;
	end

	-- 1) Shore row per column: scan from seaward of the seed back toward land; first land = shore.
	local halfLen = CONFIG.HALF_LEN_MIN + Map.Rand(CONFIG.HALF_LEN_RANGE + 1, "sineChainLen");
	local cols = {};
	for t = -halfLen, halfLen do
		local x = WrapCoord(cx + t, iW, wrapX);
		local shoreY = nil;
		local y0 = cy + away * CONFIG.SHORE_SCAN_OUT;
		for s = 0, CONFIG.SHORE_SCAN_MAX do
			local y = y0 - away * s;
			if y < 0 or y >= iH then break; end
			if isLand(plotTypes, x, y, iW, iH) then
				if s > 0 then shoreY = y; end
				break;
			end
		end
		cols[#cols + 1] = { x = x, shoreY = shoreY };
	end

	-- 2) Islets along the columns: offset from the shore fixed per islet (2 = one water tile), lengths
	-- follow an envelope (ends short, middle long), consecutive spine tiles must touch.
	local islets = {};
	local ci = 1;
	local nCols = #cols;
	while ci <= nCols and #islets < CONFIG.MAX_ISLETS do
		local mid = math.abs((ci - 1) - (nCols - 1) / 2) < nCols / 4;
		local want = mid and (CONFIG.MIDDLE_LEN_MIN + Map.Rand(CONFIG.MIDDLE_LEN_RANGE, "sineChainMidLen"))
			or (CONFIG.END_LEN_MIN + Map.Rand(CONFIG.END_LEN_RANGE, "sineChainEndLen"));
		local offs = (Map.Rand(100, "sineChainFar") < CONFIG.FAR_ISLET_PCT) and { 3, 2 } or { 2, 3 };
		local spine, used = nil, nil;
		for _, off in ipairs(offs) do
			local sp, own = {}, {};
			local c0 = cols[ci];
			if c0.shoreY then
				local t0 = { c0.x, c0.shoreY + away * off };
				own[keyXY(t0[1], t0[2])] = true;
				if free(t0[1], t0[2], own) then
					sp[1] = t0;
				else
					own[keyXY(t0[1], t0[2])] = nil;
				end
			end
			-- Next spine tiles: in the next column, touching the previous tile, 1-2 water tiles off the
			-- shore (prefer the islet's own offset), so the spine can step diagonally along a jagged coast.
			local j = ci + 1;
			while #sp > 0 and j <= nCols and #sp < want do
				local c = cols[j];
				if not c.shoreY then break; end
				local prev = sp[#sp];
				local best, bestScore = nil, nil;
				for dy = -1, 1 do
					local t = { c.x, prev[2] + dy };
					local o = (t[2] - c.shoreY) * away;
					if (o == 2 or o == 3) and adjacent(prev, t) then
						own[keyXY(t[1], t[2])] = true;
						local okT = free(t[1], t[2], own);
						own[keyXY(t[1], t[2])] = nil;
						if okT then
							local score = (o == off) and 0 or 1;
							if not bestScore or score < bestScore then best, bestScore = t, score; end
						end
					end
				end
				if not best then break; end
				own[keyXY(best[1], best[2])] = true;
				sp[#sp + 1] = best;
				j = j + 1;
			end
			if #sp >= 2 then spine = sp; used = off; break; end
		end
		if spine then
			local islet = { tiles = {}, spine = spine, off = used };
			local own = {};
			for _, t in ipairs(spine) do
				islet.tiles[#islet.tiles + 1] = { t[1], t[2], "spine" };
				own[keyXY(t[1], t[2])] = true;
			end
			-- Ocean-side thickening on inner spine tiles only, capped per islet.
			for si = 2, #spine - 1 do
				if #islet.tiles >= CONFIG.MAX_ISLET_TILES then break; end
				if Map.Rand(100, "sineChainThick") < CONFIG.THICKEN_PCT then
					local t = spine[si];
					local sx, sy = t[1], t[2] + away;
					own[keyXY(sx, sy)] = true;
					if free(sx, sy, own) then
						islet.tiles[#islet.tiles + 1] = { sx, sy, "side" };
					else
						own[keyXY(sx, sy)] = nil;
					end
				end
			end
			for _, t in ipairs(islet.tiles) do chainSet[keyXY(t[1], t[2])] = true; end
			islets[#islets + 1] = islet;
			ci = ci + #spine + 1 + ((Map.Rand(100, "sineChainGap") < CONFIG.GAP2_PCT) and 1 or 0);
		else
			ci = ci + 1;
		end
	end

	if #islets < CONFIG.MIN_ISLETS then return false; end
	local near, total, longest = 0, 0, nil;
	for _, il in ipairs(islets) do
		if il.off == 2 then near = near + 1; end
		total = total + #il.tiles;
		if not longest or #il.spine > #longest.spine then longest = il; end
	end
	if near < CONFIG.MIN_NEAR_ISLETS or total < CONFIG.MIN_LAND_TILES then return false; end

	-- 3) Terrain: hilly spine, optional peak mid-spine of the longest islet, milder ocean side.
	local peakKey = nil;
	if Map.Rand(100, "sineChainPeak") < CONFIG.PEAK_PCT then
		local m = longest.spine[math.floor((#longest.spine + 1) / 2)];
		peakKey = keyXY(m[1], m[2]);
	end
	for _, il in ipairs(islets) do
		for _, t in ipairs(il.tiles) do
			local pt;
			if keyXY(t[1], t[2]) == peakKey then
				pt = PlotTypes.PLOT_MOUNTAIN;
			elseif t[3] == "spine" then
				pt = (Map.Rand(100, "sineChainSpine") < CONFIG.SPINE_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
			else
				pt = (Map.Rand(100, "sineChainSide") < CONFIG.SIDE_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
			end
			plotTypes[pidx(t[1], t[2], iW)] = pt;
		end
	end

	if not _island_placed then _island_placed = {}; end
	_island_placed.shoreSineChain = true;
	return true;
end
