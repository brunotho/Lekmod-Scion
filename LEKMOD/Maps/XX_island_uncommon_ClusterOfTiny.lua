include("X_IslandHelpers");

local ELLIPSE_RX = 5;
local ELLIPSE_RY = 7;
local MIN_ISLANDS = 4;
local MAX_ISLANDS = 8;

local function collectEllipsePositions(clusterRadius)
	local rx = clusterRadius;
	local ry = math.ceil(clusterRadius * ELLIPSE_RY / ELLIPSE_RX);
	local out = {};
	for dy = -ry, ry do
		for dx = -rx, rx do
			local v = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry);
			if v <= 1 then
				out[#out + 1] = { dx, dy };
			end
		end
	end
	return out;
end

local function shuffleInPlace(t)
	for i = #t, 2, -1 do
		local j = 1 + Map.Rand(i, "");
		t[i], t[j] = t[j], t[i];
	end
end

local function key(x, y)
	return x .. "," .. y;
end

local function buildMicroTiles(ax, ay, size, iW, iH, wrapX, wrapY)
	local tiles = { { ax, ay } };
	local seen = { [key(ax, ay)] = true };
	if size <= 1 then return tiles; end
	local curx, cury = ax, ay;
	for _ = 2, size do
		local placed = false;
		local d0 = 1 + Map.Rand(6, "");
		for j = 0, 5 do
			local d = ((d0 + j - 1) % 6) + 1;
			local nx, ny = GetHexNeighbor(curx, cury, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local k = key(nx, ny);
				if not seen[k] then
					seen[k] = true;
					tiles[#tiles + 1] = { nx, ny };
					curx, cury = nx, ny;
					placed = true;
					break;
				end
			end
		end
		if not placed then break; end
	end
	return tiles;
end

local function canPlaceIsland(tiles, occupied, iW, iH, wrapX, wrapY)
	local occSet = {};
	for _, k in ipairs(occupied) do occSet[k] = true; end
	for _, p in ipairs(tiles) do
		local k = key(p[1], p[2]);
		if occSet[k] then return false; end
	end
	for _, p in ipairs(tiles) do
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(p[1], p[2], d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local nk = key(nx, ny);
				if occSet[nk] then
					local same = false;
					for _, q in ipairs(tiles) do
						if q[1] == nx and q[2] == ny then same = true; break; end
					end
					if not same then return false; end
				end
			end
		end
	end
	return true;
end

local function mergeOccupied(occupied, tiles)
	for _, p in ipairs(tiles) do
		occupied[#occupied + 1] = key(p[1], p[2]);
	end
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

function TryPlaceClusterOfTinyIslands(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 1;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 4;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local clusterRadius = 2;
	if params.radiusVariance then
		local r = Map.Rand(100, "");
		if r < 15 then clusterRadius = 1;
		elseif r < 90 then clusterRadius = 2;
		else clusterRadius = 3; end
	end

	local positions = collectEllipsePositions(clusterRadius);
	if #positions < 4 then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local anchors = {};
	for _, p in ipairs(positions) do
		local gx = WrapCoord(cx + p[1], params.iW, params.wrapX);
		local gy = WrapCoord(cy + p[2], params.iH, params.wrapY);
		if gx >= 0 and gx < params.iW and gy >= 0 and gy < params.iH then
			anchors[#anchors + 1] = { gx, gy };
		end
	end
	shuffleInPlace(anchors);

	local occupied = {};
	local allTiles = {};
	local target = MIN_ISLANDS + Map.Rand(MAX_ISLANDS - MIN_ISLANDS + 1, "");
	local placedMicro = 0;

	for _, a in ipairs(anchors) do
		if placedMicro >= target then break; end
		local rsize = Map.Rand(100, "");
		local size = 1;
		if rsize < 62 then size = 1;
		elseif rsize < 92 then size = 2;
		else size = 3; end
		local tiles = buildMicroTiles(a[1], a[2], size, params.iW, params.iH, params.wrapX, params.wrapY);
		if #tiles < size then
			tiles = buildMicroTiles(a[1], a[2], 1, params.iW, params.iH, params.wrapX, params.wrapY);
		end
		if canPlaceIsland(tiles, occupied, params.iW, params.iH, params.wrapX, params.wrapY) and footprintClear(plotTypes, tiles, params.iW, params.iH) then
			for _, t in ipairs(tiles) do allTiles[#allTiles + 1] = t; end
			mergeOccupied(occupied, tiles);
			placedMicro = placedMicro + 1;
		end
	end

	if #allTiles < 3 then return false; end
	if not footprintClear(plotTypes, allTiles, params.iW, params.iH) then return false; end

	DrawClusterOfTinyIslands(plotTypes, allTiles, params.iW);
	return true;
end

function DrawClusterOfTinyIslands(plotTypes, landTiles, iW)
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		-- Never mountains: 30% flat, 70% hills.
		local r = Map.Rand(100, "");
		if r < 30 then
			plotTypes[idx] = PlotTypes.PLOT_LAND;
		else
			plotTypes[idx] = PlotTypes.PLOT_HILLS;
		end
	end
end
