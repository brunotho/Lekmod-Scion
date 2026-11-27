-- Several small islands spaced on an ellipse around open water, hills and flat only.

include("X_IslandHelpers");

local HILLS_PCT = 60;

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

local function ellipseSeeds(cx, cy, axisA, axisB, numIslands, iW, iH, wrapX, wrapY)
	local rot = Map.Rand(100, "") / 100 * 2 * math.pi;
	local angles = {};
	for i = 1, numIslands do
		local base = (i - 1) * (2 * math.pi / numIslands);
		local jitter = (Map.Rand(100, "") / 100 - 0.5) * 0.6;
		angles[#angles + 1] = base + jitter;
	end
	local seeds = {};
	for _, t in ipairs(angles) do
		local dx = math.floor(axisA * math.cos(t) + 0.5);
		local dy = math.floor(axisB * math.sin(t) + 0.5);
		local dxr = math.floor(dx * math.cos(rot) - dy * math.sin(rot) + 0.5);
		local dyr = math.floor(dx * math.sin(rot) + dy * math.cos(rot) + 0.5);
		local gx = WrapCoord(cx + dxr, iW, wrapX);
		local gy = WrapCoord(cy + dyr, iH, wrapY);
		if gx >= 0 and gx < iW and gy >= 0 and gy < iH then
			seeds[#seeds + 1] = {gx, gy};
		end
	end
	return seeds;
end

local function growIsland(seedX, seedY, targetSize, iW, iH, wrapX, wrapY, occupied)
	local tiles = {{seedX, seedY}};
	local frontier = {{seedX, seedY}};
	local seen = {}; seen[seedY * iW + seedX] = true;

	while #tiles < targetSize and #frontier > 0 do
		local r = Map.Rand(#frontier, "") + 1;
		local fx, fy = frontier[r][1], frontier[r][2];
		table.remove(frontier, r);
		local candidates = {};
		for dir = 1, 6 do
			local nx, ny = GetHexNeighbor(fx, fy, dir, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local idx = ny * iW + nx;
				if not seen[idx] and not occupied[nx .. "," .. ny] then
					for _, t in ipairs(tiles) do
						if IsHexAdjacent(t[1], t[2], nx, ny) then
							candidates[#candidates + 1] = {nx, ny};
							break;
						end
					end
				end
			end
		end
		if #candidates > 0 then
			local pick = 1 + Map.Rand(#candidates, "");
			local gx, gy = candidates[pick][1], candidates[pick][2];
			tiles[#tiles + 1] = {gx, gy};
			frontier[#frontier + 1] = {gx, gy};
			seen[gy * iW + gx] = true;
		end
	end
	return tiles;
end

function TryPlaceEllipseArchipelagoIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.ellipseArchipelago then return false; end
	local pullBack = params.pullBack or 4;
	local effMin = params.effMin or 5;
	local effMax = params.effMax or 6;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local attempt = params.attempt or 1;
	local shrink = math.min(attempt - 1, 3);
	local axisA = (6 - shrink) + Map.Rand(math.max(1, (9 - shrink) - (6 - shrink) + 1), "");
	local axisB = (4 - math.floor(shrink / 2)) + Map.Rand(math.max(1, (6 - math.floor(shrink / 2)) - (4 - math.floor(shrink / 2)) + 1), "");
	local numIslands = (shrink >= 2) and (3 + Map.Rand(2, "")) or (3 + Map.Rand(3, ""));
	local islandSizeMin, islandSizeMax = 2, 4;
	if shrink >= 2 then islandSizeMax = 3; end

	local seeds = ellipseSeeds(centerX, centerY, axisA, axisB, numIslands, params.iW, params.iH, params.wrapX, params.wrapY);
	if #seeds < 3 then return false; end

	local allTiles = {};
	local occupied = {};
	for _, seed in ipairs(seeds) do
		if not occupied[seed[1] .. "," .. seed[2]] then
			local size = islandSizeMin + Map.Rand(islandSizeMax - islandSizeMin + 1, "");
			local tiles = growIsland(seed[1], seed[2], size, params.iW, params.iH, params.wrapX, params.wrapY, occupied);
			for _, t in ipairs(tiles) do
				allTiles[#allTiles + 1] = {t[1], t[2]};
				occupied[t[1] .. "," .. t[2]] = true;
			end
		end
	end

	if #allTiles < 6 then return false; end
	if not footprintClear(plotTypes, allTiles, params.iW, params.iH) then return false; end

	DrawEllipseArchipelagoIsland(plotTypes, allTiles, params.iW);
	if not _island_placed then _island_placed = {}; end
	_island_placed.ellipseArchipelago = true;
	return true;
end

function DrawEllipseArchipelagoIsland(plotTypes, landTiles, iW)
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		plotTypes[idx] = (Map.Rand(100, "") < HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
	end
end
