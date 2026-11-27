include("X_IslandHelpers");

local CONFIG = {
	OVAL_SEMI_MAJOR = 7,
	OVAL_SEMI_MINOR = 4,
	BLOB_HALF_LEN_MIN = 3, BLOB_HALF_LEN_MAX = 5,
	BLOB_HALF_W_MIN = 1, BLOB_HALF_W_MAX = 2,
	GAP_WIDTH = 1,
	SPLINTER_COUNT_MIN = 4, SPLINTER_COUNT_MAX = 7,
	SPLINTER_LEN_MIN = 1, SPLINTER_LEN_MAX = 3,
	OUTER_LAND_PER_BLOB_MIN = 2, OUTER_LAND_PER_BLOB_MAX = 4,
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

function TryPlaceSplinteredMountainsIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.splinteredMountains then return false; end
	local pullBack = params.pullBack or 2;
	local effMin = params.effMin or 2;
	local effMax = params.effMax or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end
	local orient = Map.Rand(2, "");
	local alongA = (orient == 0) and 1 or 4;
	local alongB = ((alongA + 2) % 6) + 1;
	local splitDir = ((alongA + 1) % 6) + 1;
	local splitOpp = ((splitDir + 2) % 6) + 1;

	local function inOval(tx, ty)
		local dx = tx - cx;
		local dy = ty - cy;
		if params.wrapX and math.abs(dx) > params.iW / 2 then
			dx = dx - (dx > 0 and params.iW or -params.iW);
		end
		local ex, ey;
		if orient == 0 then
			ex = dx / CONFIG.OVAL_SEMI_MAJOR;
			ey = dy / CONFIG.OVAL_SEMI_MINOR;
		else
			ex = dy / CONFIG.OVAL_SEMI_MAJOR;
			ey = dx / CONFIG.OVAL_SEMI_MINOR;
		end
		return ex * ex + ey * ey <= 1;
	end

	local allSet = {};
	local mountainSet = {};
	local landType = {};
	local allTiles = {};

	local function markMountain(x, y)
		if x < 0 or x >= params.iW or y < 0 or y >= params.iH or not inOval(x, y) then return; end
		local k = y * params.iW + x;
		if not allSet[k] then
			allSet[k] = true;
			allTiles[#allTiles + 1] = {x, y};
		end
		mountainSet[k] = true;
		landType[k] = "mountain";
	end
	local function markLand(x, y, t)
		if x < 0 or x >= params.iW or y < 0 or y >= params.iH or not inOval(x, y) then return; end
		local k = y * params.iW + x;
		if not allSet[k] then
			allSet[k] = true;
			allTiles[#allTiles + 1] = {x, y};
		end
		if not mountainSet[k] then landType[k] = t; end
	end

	local cAx, cAy = GetHexNeighbor(cx, cy, splitDir, params.iW, params.iH, params.wrapX, params.wrapY);
	local cBx, cBy = GetHexNeighbor(cx, cy, splitOpp, params.iW, params.iH, params.wrapX, params.wrapY);
	if cAx < 0 or cAx >= params.iW or cAy < 0 or cAy >= params.iH then return false; end
	if cBx < 0 or cBx >= params.iW or cBy < 0 or cBy >= params.iH then return false; end

	local lenA = CONFIG.BLOB_HALF_LEN_MIN + Map.Rand(CONFIG.BLOB_HALF_LEN_MAX - CONFIG.BLOB_HALF_LEN_MIN + 1, "");
	local lenB = CONFIG.BLOB_HALF_LEN_MIN + Map.Rand(CONFIG.BLOB_HALF_LEN_MAX - CONFIG.BLOB_HALF_LEN_MIN + 1, "");
	local hwA = CONFIG.BLOB_HALF_W_MIN + Map.Rand(CONFIG.BLOB_HALF_W_MAX - CONFIG.BLOB_HALF_W_MIN + 1, "");
	local hwB = CONFIG.BLOB_HALF_W_MIN + Map.Rand(CONFIG.BLOB_HALF_W_MAX - CONFIG.BLOB_HALF_W_MIN + 1, "");

	local function drawBlob(seedX, seedY, alongDir, len, halfW)
		local x, y = seedX, seedY;
		for i = 1, len do
			markMountain(x, y);
			for w = 1, halfW do
				local ldir = ((alongDir + 4) % 6) + 1;
				local rdir = ((alongDir) % 6) + 1;
				local lx, ly = x, y;
				local rx, ry = x, y;
				for _ = 1, w do lx, ly = GetHexNeighbor(lx, ly, ldir, params.iW, params.iH, params.wrapX, params.wrapY); end
				for _ = 1, w do rx, ry = GetHexNeighbor(rx, ry, rdir, params.iW, params.iH, params.wrapX, params.wrapY); end
				if lx >= 0 and lx < params.iW and ly >= 0 and ly < params.iH then markMountain(lx, ly); end
				if rx >= 0 and rx < params.iW and ry >= 0 and ry < params.iH then markMountain(rx, ry); end
			end
			if i < len then
				if Map.Rand(100, "") < 30 then alongDir = alongA; else alongDir = alongB; end
				local nx, ny = GetHexNeighbor(x, y, alongDir, params.iW, params.iH, params.wrapX, params.wrapY);
				if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then break; end
				x, y = nx, ny;
			end
		end
	end

	drawBlob(cAx, cAy, alongA, lenA, hwA);
	drawBlob(cBx, cBy, alongB, lenB, hwB);

	-- Single split cleft between the two blobs.
	do
		local gx, gy = cx, cy;
		for _ = 1, CONFIG.GAP_WIDTH do
			local k = gy * params.iW + gx;
			allSet[k] = nil;
			mountainSet[k] = nil;
			landType[k] = nil;
			local nx, ny = GetHexNeighbor(gx, gy, splitDir, params.iW, params.iH, params.wrapX, params.wrapY);
			if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then break; end
			gx, gy = nx, ny;
		end
	end

	-- Mountain splinters mostly extending from each blob.
	local spl = CONFIG.SPLINTER_COUNT_MIN + Map.Rand(CONFIG.SPLINTER_COUNT_MAX - CONFIG.SPLINTER_COUNT_MIN + 1, "");
	local seeds = {
		{ cAx, cAy, splitDir },
		{ cBx, cBy, splitOpp },
	};
	for _ = 1, spl do
		local s = seeds[1 + Map.Rand(#seeds, "")];
		local sx, sy, sdir = s[1], s[2], s[3];
		local px, py = sx, sy;
		local n = CONFIG.SPLINTER_LEN_MIN + Map.Rand(CONFIG.SPLINTER_LEN_MAX - CONFIG.SPLINTER_LEN_MIN + 1, "");
		for _j = 1, n do
			local dir = sdir;
			if Map.Rand(100, "") < 35 then dir = ((dir + ((Map.Rand(2, "") == 0) and -1 or 1) + 5) % 6) + 1; end
			local nx, ny = GetHexNeighbor(px, py, dir, params.iW, params.iH, params.wrapX, params.wrapY);
			if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then break; end
			px, py = nx, ny;
			markMountain(px, py);
		end
	end

	-- Place a few land/hill tiles on the outer side of each blob (away from the split).
	local outerCount = CONFIG.OUTER_LAND_PER_BLOB_MIN + Map.Rand(CONFIG.OUTER_LAND_PER_BLOB_MAX - CONFIG.OUTER_LAND_PER_BLOB_MIN + 1, "");
	for _ = 1, outerCount do
		local ox, oy = cAx, cAy;
		local steps = 1 + Map.Rand(2, "");
		for _s = 1, steps do
			ox, oy = GetHexNeighbor(ox, oy, splitOpp, params.iW, params.iH, params.wrapX, params.wrapY);
		end
		if ox >= 0 and ox < params.iW and oy >= 0 and oy < params.iH then
			markLand(ox, oy, (Map.Rand(100, "") < 55) and "hill" or "land");
		end
	end
	for _ = 1, outerCount do
		local ox, oy = cBx, cBy;
		local steps = 1 + Map.Rand(2, "");
		for _s = 1, steps do
			ox, oy = GetHexNeighbor(ox, oy, splitDir, params.iW, params.iH, params.wrapX, params.wrapY);
		end
		if ox >= 0 and ox < params.iW and oy >= 0 and oy < params.iH then
			markLand(ox, oy, (Map.Rand(100, "") < 55) and "hill" or "land");
		end
	end

	local landTiles = {};
	for _, t in ipairs(allTiles) do
		local k = t[2] * params.iW + t[1];
		if allSet[k] then
			landTiles[#landTiles + 1] = { t[1], t[2], landType[k] or "mountain" };
		end
	end
	if #landTiles < 12 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	DrawSplinteredMountainsIsland(plotTypes, landTiles, params.iW);
	if not _island_placed then _island_placed = {}; end
	_island_placed.splinteredMountains = true;
	return true;
end

function DrawSplinteredMountainsIsland(plotTypes, landTiles, iW)
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		if t[3] == "mountain" then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		elseif t[3] == "hill" then
			plotTypes[idx] = PlotTypes.PLOT_HILLS;
		else
			plotTypes[idx] = (Map.Rand(100, "") < 40) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
