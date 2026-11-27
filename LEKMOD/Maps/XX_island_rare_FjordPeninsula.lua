-- Narrow peninsula from the coast with a mountain spine, tapering tip, and side water inlets.

include("X_IslandHelpers");

local firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
local firstRingYIsOdd  = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};

local HILLS_ADJ = 75;

local function pidx(x, y, iW)
	return y * iW + x + 1;
end

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function isOcean(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	return plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_OCEAN;
end

local COAST_EDGE_MARGIN = 6;

local function findCoastCandidates(plotTypes, iW, iH, wrapX, wrapY)
	local candidates = {};
	for y = COAST_EDGE_MARGIN, iH - 1 - COAST_EDGE_MARGIN do
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
					candidates[#candidates + 1] = {cx = x, cy = y, oceanDirs = oceanDirs};
				end
			end
		end
	end
	return candidates;
end

local function hasSpaceForPeninsula(plotTypes, startX, startY, dir, len, iW, iH, wrapX, wrapY)
	local x, y = startX, startY;
	for step = 1, len do
		local adj = (y % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
		x = WrapCoord(x + adj[1], iW, wrapX);
		y = WrapCoord(y + adj[2], iH, wrapY);
		if y < 0 or y >= iH then return false; end
		if not isOcean(plotTypes, x, y, iW, iH) then return false; end
	end
	return true;
end

local function paintMainlandConnection(plotTypes, baseX, baseY, ridgeTiles, iW, iH, wrapX, wrapY)
	local firstRidge = ridgeTiles[1];
	local ridgeAdjacent = IsHexAdjacent(baseX, baseY, firstRidge[1], firstRidge[2]);
	local disk = GetHexDisk(baseX, baseY, 1, iW, iH, wrapX or true, wrapY or false);
	for _, p in ipairs(disk) do
		local x, y = p[1], p[2];
		if isLand(plotTypes, x, y, iW, iH) then
			local idx = pidx(x, y, iW);
			if plotTypes[idx] ~= PlotTypes.PLOT_MOUNTAIN then
				if ridgeAdjacent and (x == baseX and y == baseY) then
					plotTypes[idx] = (Map.Rand(100, "") < 80) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
				else
					plotTypes[idx] = (Map.Rand(100, "") < 65) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
				end
			end
		end
	end
end

local function mergeCoastMouth(plotTypes, baseX, baseY, landTiles, iW, iH, wrapX, wrapY)
	local landSet = {};
	for _, t in ipairs(landTiles) do landSet[t[1] .. "," .. t[2]] = true; end
	local merged = {};
	for d = 1, 6 do
		local ox, oy = GetHexNeighbor(baseX, baseY, d, iW, iH, wrapX, wrapY);
		if ox >= 0 and ox < iW and oy >= 0 and oy < iH and isOcean(plotTypes, ox, oy, iW, iH) then
			local touchesPen = false;
			for _, t in ipairs(landTiles) do
				if IsHexAdjacent(ox, oy, t[1], t[2]) then
					touchesPen = true;
					break;
				end
			end
			if touchesPen then
				local k = ox .. "," .. oy;
				if not landSet[k] then
					landTiles[#landTiles + 1] = {ox, oy};
					landSet[k] = true;
					merged[#merged + 1] = k;
				end
			end
		end
	end
	if #merged > 1 and Map.Rand(100, "") < 14 then
		local rm = merged[Map.Rand(#merged, "") + 1];
		for i = #landTiles, 1, -1 do
			local t = landTiles[i];
			if t[1] .. "," .. t[2] == rm then table.remove(landTiles, i); break; end
		end
	end
end

local function findMainlandMountainOrHill(plotTypes, cx, cy, iW, iH, wrapX, wrapY)
	local disk = GetHexDisk(cx, cy, 2, iW, iH, wrapX, wrapY);
	for _, p in ipairs(disk) do
		if p[1] ~= cx or p[2] ~= cy then
			local t = plotTypes[pidx(p[1], p[2], iW)];
			if t == PlotTypes.PLOT_MOUNTAIN or t == PlotTypes.PLOT_HILLS then
				return p[1], p[2];
			end
		end
	end
	return nil, nil;
end

function TryPlaceFjordPeninsulaIsland(plotTypes, opts)
	if _island_placed and _island_placed.fjordPeninsula then return false; end
	local iW, iH = opts.iW, opts.iH;
	local wrapX = opts.wrapX or true;
	local wrapY = opts.wrapY or false;

	local candidates = findCoastCandidates(plotTypes, iW, iH, wrapX, wrapY);
	if #candidates < 6 then return false; end

	local maxAttempts = math.min(500, math.max(320, #candidates * 4));
	for attempt = 1, maxAttempts do
		local c = candidates[Map.Rand(#candidates, "") + 1];
		local oceanPick = c.oceanDirs[Map.Rand(#c.oceanDirs, "") + 1];
		local dir = oceanPick.dir;
		local startX, startY = oceanPick.x, oceanPick.y;

		if not IsHexAdjacent(c.cx, c.cy, startX, startY) then
		else
		local len = 8 + Map.Rand(5, "");
		if not hasSpaceForPeninsula(plotTypes, startX, startY, dir, len - 1, iW, iH, wrapX, wrapY) then
		else
			local baseWidth = 2 + Map.Rand(3, "");
			local ridgeOffset = 0;
			local mx, my = findMainlandMountainOrHill(plotTypes, c.cx, c.cy, iW, iH, wrapX, wrapY);
			if not mx then
				ridgeOffset = 1 + Map.Rand(2, "");
			end

			local landTiles, spineTiles, ridgeTiles = buildPeninsulaShape(
				plotTypes, c.cx, c.cy, startX, startY, dir, len, baseWidth, ridgeOffset,
				iW, iH, wrapX, wrapY
			);
			if landTiles and #landTiles >= 10 then
				mergeCoastMouth(plotTypes, c.cx, c.cy, landTiles, iW, iH, wrapX, wrapY);
				carveInlets(landTiles, spineTiles, dir, iW, iH, wrapX, wrapY);
				jaggedFringe(plotTypes, landTiles, spineTiles, dir, iW, iH, wrapX, wrapY);
				roughenOutline(plotTypes, landTiles, iW, iH, wrapX, wrapY);
				paintMainlandConnection(plotTypes, c.cx, c.cy, ridgeTiles, iW, iH, wrapX, wrapY);
				DrawFjordPeninsula(plotTypes, landTiles, ridgeTiles, iW, iH, wrapX, wrapY);
				if not _island_placed then _island_placed = {}; end
				_island_placed.fjordPeninsula = true;
				return true;
			end
		end
		end
	end
	return false;
end

function buildPeninsulaShape(plotTypes, baseX, baseY, startX, startY, dir, len, baseWidth, ridgeOffset, iW, iH, wrapX, wrapY)
	local landTiles = {};
	local spineTiles = {};
	local ridgeTiles = {};
	local landSet = {};

	local x, y = startX, startY;
	if not isOcean(plotTypes, x, y, iW, iH) then return nil; end
	if not IsHexAdjacent(baseX, baseY, x, y) then return nil; end

	local leftDir = ((dir + 2) % 6) + 1;
	local rightDir = ((dir + 4) % 6) + 1;

	for i = 0, len - 1 do
		if i > 0 then
			local d = (y % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
			x = WrapCoord(x + d[1], iW, wrapX);
			y = WrapCoord(y + d[2], iH, wrapY);
			if y < 0 or y >= iH then return nil; end
			if not isOcean(plotTypes, x, y, iW, iH) then return nil; end
			if Map.Rand(100, "") < 30 then
				local tryDir = (Map.Rand(2, "") == 0) and leftDir or rightDir;
				local ring = (y % 2 ~= 0) and firstRingYIsOdd or firstRingYIsEven;
				local dd = ring[tryDir];
				local tx = WrapCoord(x + dd[1], iW, wrapX);
				local ty = WrapCoord(y + dd[2], iH, wrapY);
				if ty >= 0 and ty < iH and isOcean(plotTypes, tx, ty, iW, iH) then
					x, y = tx, ty;
				end
			end
		end

		local t = (len > 1) and (1 - i / (len - 1)) or 1;
		local wobble = Map.Rand(9, "") - 4;
		local w = math.max(1, math.min(baseWidth + 2, math.floor(baseWidth * t + 0.5) + wobble));
		spineTiles[#spineTiles + 1] = {x, y, i};
		landTiles[#landTiles + 1] = {x, y};
		landSet[x .. "," .. y] = true;

		local leftCount = math.floor((w - 1) / 2);
		local rightCount = (w - 1) - leftCount;
		local lx, ly = x, y;
		for _ = 1, leftCount do
			local ring = (ly % 2 ~= 0) and firstRingYIsOdd or firstRingYIsEven;
			local d = ring[leftDir];
			lx = WrapCoord(lx + d[1], iW, wrapX);
			ly = WrapCoord(ly + d[2], iH, wrapY);
			if ly >= 0 and ly < iH and not landSet[lx .. "," .. ly] and isOcean(plotTypes, lx, ly, iW, iH) then
				landTiles[#landTiles + 1] = {lx, ly};
				landSet[lx .. "," .. ly] = true;
			end
		end
		local rx, ry = x, y;
		for _ = 1, rightCount do
			local ring = (ry % 2 ~= 0) and firstRingYIsOdd or firstRingYIsEven;
			local d = ring[rightDir];
			rx = WrapCoord(rx + d[1], iW, wrapX);
			ry = WrapCoord(ry + d[2], iH, wrapY);
			if ry >= 0 and ry < iH and not landSet[rx .. "," .. ry] and isOcean(plotTypes, rx, ry, iW, iH) then
				landTiles[#landTiles + 1] = {rx, ry};
				landSet[rx .. "," .. ry] = true;
			end
		end
	end

	local numRidge = 4 + Map.Rand(5, "");
	local ridgeStart = ridgeOffset + 1;
	local ridgeLen = #spineTiles - ridgeOffset;
	if ridgeLen < 2 then ridgeStart = 1; ridgeLen = #spineTiles; end
	numRidge = math.min(numRidge, ridgeLen);
	for i = 1, numRidge do
		local idx = ridgeStart + math.floor((i - 1) * (ridgeLen - 1) / math.max(1, numRidge - 1));
		idx = math.min(idx, #spineTiles);
		ridgeTiles[#ridgeTiles + 1] = spineTiles[idx];
	end
	ridgeTiles[#ridgeTiles + 1] = spineTiles[#spineTiles];

	return landTiles, spineTiles, ridgeTiles;
end

function jaggedFringe(plotTypes, landTiles, spineTiles, dir, iW, iH, wrapX, wrapY)
	local landSet = {};
	for _, t in ipairs(landTiles) do landSet[t[1] .. "," .. t[2]] = true; end
	local leftDir = ((dir + 2) % 6) + 1;
	local rightDir = ((dir + 4) % 6) + 1;
	for si = 1, math.max(1, #spineTiles - 1) do
		if Map.Rand(100, "") < 68 then
			local st = spineTiles[si];
			local sideDir = (Map.Rand(2, "") == 0) and leftDir or rightDir;
			local ring = (st[2] % 2 ~= 0) and firstRingYIsOdd or firstRingYIsEven;
			local d = ring[sideDir];
			local nx = WrapCoord(st[1] + d[1], iW, wrapX);
			local ny = WrapCoord(st[2] + d[2], iH, wrapY);
			if ny >= 0 and ny < iH and not landSet[nx .. "," .. ny] and isOcean(plotTypes, nx, ny, iW, iH) then
				landTiles[#landTiles + 1] = {nx, ny};
				landSet[nx .. "," .. ny] = true;
			end
		end
	end
end

function roughenOutline(plotTypes, landTiles, iW, iH, wrapX, wrapY)
	for pass = 1, 4 do
		local landSet = {};
		for _, t in ipairs(landTiles) do landSet[t[1] .. "," .. t[2]] = true; end
		local pct = (pass == 1) and 58 or ((pass == 2) and 42 or ((pass == 3) and 28 or 18));
		for _, t in ipairs(landTiles) do
			if Map.Rand(100, "") < pct then
				local d = 1 + Map.Rand(6, "");
				local nx, ny = GetHexNeighbor(t[1], t[2], d, iW, iH, wrapX, wrapY);
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH and not landSet[nx .. "," .. ny] and isOcean(plotTypes, nx, ny, iW, iH) then
					landTiles[#landTiles + 1] = {nx, ny};
					landSet[nx .. "," .. ny] = true;
				end
			end
		end
	end
end

function carveInlets(landTiles, spineTiles, dir, iW, iH, wrapX, wrapY)
	local landSet = {};
	for _, t in ipairs(landTiles) do landSet[t[1] .. "," .. t[2]] = true; end

	local leftDir = ((dir + 2) % 6) + 1;
	local rightDir = ((dir + 4) % 6) + 1;

	local numInlets = 2 + Map.Rand(3, "");
	local side = (Map.Rand(2, "") == 0);
	for _ = 1, numInlets do
		local spineIdx = 2 + Map.Rand(math.max(1, #spineTiles - 5), "");
		if spineIdx >= #spineTiles then break; end
		local st = spineTiles[spineIdx];
		local perpDir = side and leftDir or rightDir;
		local depth = 2 + Map.Rand(3, "");
		local width = 1 + Map.Rand(2, "");

		local px, py = st[1], st[2];
		for w = 1, width do
			local cx, cy = px, py;
			for d = 1, depth do
				local a = (cy % 2 ~= 0) and firstRingYIsOdd[perpDir] or firstRingYIsEven[perpDir];
				cx = WrapCoord(cx + a[1], iW, wrapX);
				cy = WrapCoord(cy + a[2], iH, wrapY);
				if cy < 0 or cy >= iH then break; end
				local key = cx .. "," .. cy;
				if landSet[key] then
					landSet[key] = nil;
					for i = #landTiles, 1, -1 do
						if landTiles[i][1] == cx and landTiles[i][2] == cy then
							table.remove(landTiles, i);
							break;
						end
					end
				end
			end
			local fwd = (py % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
			px = WrapCoord(px + fwd[1], iW, wrapX);
			py = WrapCoord(py + fwd[2], iH, wrapY);
			if py < 0 or py >= iH then break; end
		end
		side = not side;
	end
end

function DrawFjordPeninsula(plotTypes, landTiles, ridgeTiles, iW, iH, wrapX, wrapY)
	wrapX = wrapX ~= false;
	wrapY = wrapY or false;
	local ridgeSet = {};
	for _, t in ipairs(ridgeTiles) do
		ridgeSet[t[1] .. "," .. t[2]] = true;
	end

	local landSet = {};
	for _, t in ipairs(landTiles) do
		landSet[t[1] .. "," .. t[2]] = true;
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
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and ridgeSet[nx .. "," .. ny] then return true; end
		end
		return false;
	end

	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = pidx(x, y, iW);
		if ridgeSet[x .. "," .. y] then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		elseif adjToMountain(x, y) then
			plotTypes[idx] = (Map.Rand(100, "") < HILLS_ADJ) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		elseif isCoast(x, y) then
			plotTypes[idx] = (Map.Rand(100, "") < 40) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		else
			plotTypes[idx] = (Map.Rand(100, "") < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
