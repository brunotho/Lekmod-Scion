-- A blobby head plus a thin stem of hex steps, like a lollipop.

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

function TryPlaceLollipopIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack  = params.pullBack or 2;
	local effMin    = params.effMin   or 2;
	local effMax    = params.effMax   or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local headDir = Map.Rand(6, "") + 1;
	local oppDir  = rotDir(headDir, 3);
	local stemDir = rotDir(oppDir, Map.Rand(3, "") - 1);

	local headLen = 2 + Map.Rand(2, "");
	local stemLen = 3 + Map.Rand(3, "");

	local landTiles = {};
	local used      = {};
	local baseCount = 0;

	local function addBase(x, y)
		local key = x .. "," .. y;
		if not used[key] and x >= 0 and x < params.iW and y >= 0 and y < params.iH then
			landTiles[#landTiles + 1] = {x, y};
			used[key] = true;
			baseCount  = baseCount + 1;
			return true;
		end
		return false;
	end

	local function addArm(x, y)
		local key = x .. "," .. y;
		if not used[key] and x >= 0 and x < params.iW and y >= 0 and y < params.iH then
			landTiles[#landTiles + 1] = {x, y};
			used[key] = true;
			return true;
		end
		return false;
	end

	local lopsideBias = Map.Rand(3, "") - 1;

	addBase(cx, cy);

	local hx, hy = cx, cy;
	for _ = 1, headLen do
		local nx, ny = GetHexNeighbor(hx, hy, headDir, params.iW, params.iH, params.wrapX, params.wrapY);
		if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then break; end
		addBase(nx, ny);
		hx, hy = nx, ny;

		local lProb = (lopsideBias == -1) and 80 or (lopsideBias == 1) and 25 or 55;
		if Map.Rand(100, "") < lProb then
			local lx, ly = GetHexNeighbor(hx, hy, rotDir(headDir, -1), params.iW, params.iH, params.wrapX, params.wrapY);
			if lx >= 0 and lx < params.iW and ly >= 0 and ly < params.iH then addBase(lx, ly); end
		end

		local rProb = (lopsideBias == 1) and 80 or (lopsideBias == -1) and 25 or 55;
		if Map.Rand(100, "") < rProb then
			local rx, ry = GetHexNeighbor(hx, hy, rotDir(headDir, 1), params.iW, params.iH, params.wrapX, params.wrapY);
			if rx >= 0 and rx < params.iW and ry >= 0 and ry < params.iH then addBase(rx, ry); end
		end
	end

	if Map.Rand(10, "") < 4 then
		local spDir = rotDir(headDir, Map.Rand(3, "") - 1);
		local sx, sy = GetHexNeighbor(hx, hy, spDir, params.iW, params.iH, params.wrapX, params.wrapY);
		if sx >= 0 and sx < params.iW and sy >= 0 and sy < params.iH then addBase(sx, sy); end
	end

	local stemCurDir = stemDir;
	local doBend     = Map.Rand(10, "") < 7;
	local bendAt;
	if stemLen == 5 and not doBend then
		doBend = true;
		bendAt = (Map.Rand(2, "") == 0) and 1 or 5;
	else
		bendAt = 1 + Map.Rand(math.max(1, stemLen - 1), "");
	end
	local bendSide   = (Map.Rand(2, "") == 0) and 1 or -1;

	local tx, ty = cx, cy;
	for i = 1, stemLen do
		if doBend and i == bendAt then
			stemCurDir = rotDir(stemCurDir, bendSide);
		end
		local nx, ny = GetHexNeighbor(tx, ty, stemCurDir, params.iW, params.iH, params.wrapX, params.wrapY);
		if not addArm(nx, ny) then break; end
		tx, ty = nx, ny;
	end

	if #landTiles < 10 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	DrawLollipopIsland(plotTypes, landTiles, baseCount, params.iW);
	return true;
end

function DrawLollipopIsland(plotTypes, landTiles, baseCount, iW)
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx   = y * iW + x + 1;
		plotTypes[idx] = (Map.Rand(100, "") < 70) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
	end
end
