-- Small central blob with two short curved one-tile arms that stay apart.

include("X_IslandHelpers");

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

local function growArm(sx, sy, baseDir, armLen, bendBias, used, params)
	local tiles = {};
	local x, y  = sx, sy;
	local dir   = baseDir;
	if Map.Rand(2, "") == 0 then dir = rotDir(dir, (Map.Rand(2, "") == 0) and 1 or -1); end
	local doBend   = Map.Rand(10, "") < 7;
	local bendAt   = 1 + Map.Rand(math.max(1, armLen - 1), "");
	local bendSide = (Map.Rand(10, "") < 7) and bendBias or -bendBias;
	for i = 1, armLen do
		if doBend and i == bendAt then
			dir = rotDir(dir, bendSide);
		end
		local nx, ny = GetHexNeighbor(x, y, dir, params.iW, params.iH, params.wrapX, params.wrapY);
		if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then break; end
		local key = nx .. "," .. ny;
		if used[key] then break; end
		tiles[#tiles + 1] = {nx, ny};
		used[key] = true;
		x, y = nx, ny;
	end
	return tiles;
end

local function armsTouch(arm1, arm2, params)
	local arm2Set = {};
	for _, t in ipairs(arm2) do
		arm2Set[t[1] .. "," .. t[2]] = true;
	end
	for i = 2, #arm1 do
		local t = arm1[i];
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(t[1], t[2], d, params.iW, params.iH, params.wrapX, params.wrapY);
			if arm2Set[nx .. "," .. ny] then return true; end
		end
	end
	local arm1Set = {};
	for _, t in ipairs(arm1) do
		arm1Set[t[1] .. "," .. t[2]] = true;
	end
	for i = 2, #arm2 do
		local t = arm2[i];
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(t[1], t[2], d, params.iW, params.iH, params.wrapX, params.wrapY);
			if arm1Set[nx .. "," .. ny] then return true; end
		end
	end
	return false;
end

function TryPlaceWishboneIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack  = params.pullBack or 2;
	local effMin    = params.effMin   or 2;
	local effMax    = params.effMax   or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local landTiles = {};
	local used      = {};

	local disk = GetHexDisk(cx, cy, 1, params.iW, params.iH, params.wrapX, params.wrapY);
	for i = 1, #disk do
		local t = disk[i];
		if i == 1 or Map.Rand(100, "") < (40 + Map.Rand(16, "")) then
			local key = t[1] .. "," .. t[2];
			if not used[key] then
				landTiles[#landTiles + 1] = t;
				used[key] = true;
			end
		end
	end

	local arm1Dir = Map.Rand(6, "") + 1;
	local arm2Dir = rotDir(arm1Dir, (Map.Rand(2, "") == 0) and 1 or -1);

	local function farthestInDir(dir)
		local best, bestScore = nil, -999;
		for _, t in ipairs(landTiles) do
			local dx = t[1] - cx;
			local dy = t[2] - cy;
			local adj = (cy % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
			local score = dx * adj[1] + dy * adj[2];
			if score > bestScore then bestScore = score; best = t; end
		end
		return best;
	end
	local arm1Start = farthestInDir(arm1Dir);
	local arm2Start = farthestInDir(arm2Dir);
	if not arm1Start or not arm2Start then return false; end

	local armLen = 2 + Map.Rand(2, "");
	local arm1Tiles = growArm(arm1Start[1], arm1Start[2], arm1Dir, armLen, -1, used, params);
	local arm2Tiles = growArm(arm2Start[1], arm2Start[2], arm2Dir, armLen,  1, used, params);

	if armsTouch(arm1Tiles, arm2Tiles, params) then return false; end

	for _, t in ipairs(arm1Tiles) do landTiles[#landTiles + 1] = t; end
	for _, t in ipairs(arm2Tiles) do landTiles[#landTiles + 1] = t; end

	if #landTiles < 5 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	DrawWishboneIsland(plotTypes, landTiles, #landTiles, params.iW);
	return true;
end

function DrawWishboneIsland(plotTypes, landTiles, baseCount, iW)
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx   = y * iW + x + 1;
		plotTypes[idx] = (Map.Rand(100, "") < 70) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
	end
end
