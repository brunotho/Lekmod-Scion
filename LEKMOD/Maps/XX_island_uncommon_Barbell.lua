-- Two small lobes linked by a short neck, usually with a peak on the neck.

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

local function oppDir(d) return ((d + 2) % 6) + 1; end
local function perpDirs(d)
	local p1 = (d == 1) and 6 or (d - 1);
	local p2 = (d % 6) + 1;
	return {p1, p2};
end

function TryPlaceBarbellIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 1;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 6;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local dir = Map.Rand(6, "") + 1;
	local neckLen = 1 + Map.Rand(2, "");
	local landTiles = {{cx, cy}};
	local neckEndX, neckEndY = cx, cy;

	for _ = 1, neckLen do
		neckEndX, neckEndY = GetHexNeighbor(neckEndX, neckEndY, dir, params.iW, params.iH, params.wrapX, params.wrapY);
		if neckEndX < 0 or neckEndX >= params.iW or neckEndY < 0 or neckEndY >= params.iH then return false; end
		landTiles[#landTiles + 1] = {neckEndX, neckEndY};
	end

	local bodySet = {};
	for _, t in ipairs(landTiles) do bodySet[t[1] .. "," .. t[2]] = true; end

	local lobeASize = 1 + Map.Rand(2, "");
	local lobeBSize = 1 + Map.Rand(2, "");
	local opp = oppDir(dir);
	local perps = perpDirs(dir);

	for lobe = 1, lobeASize do
		-- Lobe 1 grows from the centre; later lobe tiles grow from the previous lobe tile.
		local fromX, fromY = cx, cy;
		if lobe > 1 then
			local prev = landTiles[#landTiles];
			fromX, fromY = prev[1], prev[2];
		end
		local candidates = {};
		for _, pd in ipairs(perps) do
			local nx, ny = GetHexNeighbor(fromX, fromY, pd, params.iW, params.iH, params.wrapX, params.wrapY);
			if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and not bodySet[nx .. "," .. ny] then
				candidates[#candidates + 1] = {nx, ny};
			end
		end
		for d = 1, 6 do
			if d ~= dir and d ~= opp then
				local nx, ny = GetHexNeighbor(fromX, fromY, d, params.iW, params.iH, params.wrapX, params.wrapY);
				if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and not bodySet[nx .. "," .. ny] then
					local dup = false;
					for _, c in ipairs(candidates) do if c[1] == nx and c[2] == ny then dup = true; break; end end
					if not dup then candidates[#candidates + 1] = {nx, ny}; end
				end
			end
		end
		if #candidates == 0 then break; end
		local pick = candidates[Map.Rand(#candidates, "") + 1];
		landTiles[#landTiles + 1] = {pick[1], pick[2]};
		bodySet[pick[1] .. "," .. pick[2]] = true;
	end

	for lobe = 1, lobeBSize do
		local fromX, fromY = (lobe == 1) and neckEndX or landTiles[#landTiles][1];
		if lobe == 1 then fromX, fromY = neckEndX, neckEndY; end
		local fromT = landTiles[#landTiles - lobe + 1];
		if lobe > 1 then fromX, fromY = fromT[1], fromT[2]; end
		local candidates = {};
		for _, pd in ipairs(perpDirs(opp)) do
			local nx, ny = GetHexNeighbor(fromX, fromY, pd, params.iW, params.iH, params.wrapX, params.wrapY);
			if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and not bodySet[nx .. "," .. ny] then
				candidates[#candidates + 1] = {nx, ny};
			end
		end
		for d = 1, 6 do
			if d ~= dir and d ~= opp then
				local nx, ny = GetHexNeighbor(fromX, fromY, d, params.iW, params.iH, params.wrapX, params.wrapY);
				if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and not bodySet[nx .. "," .. ny] then
					local dup = false;
					for _, c in ipairs(candidates) do if c[1] == nx and c[2] == ny then dup = true; break; end end
					if not dup then candidates[#candidates + 1] = {nx, ny}; end
				end
			end
		end
		if #candidates == 0 then break; end
		local pick = candidates[Map.Rand(#candidates, "") + 1];
		landTiles[#landTiles + 1] = {pick[1], pick[2]};
		bodySet[pick[1] .. "," .. pick[2]] = true;
	end

	if #landTiles < 7 or #landTiles > 10 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	DrawBarbellIsland(plotTypes, landTiles, neckLen + 1, params.iW);
	return true;
end

function DrawBarbellIsland(plotTypes, landTiles, neckTileCount, iW)
	local hillsPct = 55 + Map.Rand(16, "");
	local neckMid = math.floor(neckTileCount / 2) + 1;
	for i, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		if i == neckMid then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		else
			local mt = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
			plotTypes[idx] = mt;
		end
	end
end
