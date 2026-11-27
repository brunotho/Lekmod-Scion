-- Diamond of land with the Sinai wonder peak at its centre, hills around it, 1-2 extra peaks on the far
-- tips (never next to Sinai), and small satellite islets.

include("X_IslandHelpers");

local function plotIdx1(x, y, iW) return y * iW + x + 1; end

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

local function wrapCoord(v, size, doWrap)
	if not doWrap then return v; end
	v = v % size;
	if v < 0 then v = v + size; end
	return v;
end

local DIAMOND_OFFSETS = {
	{0, 3},
	{-1, 2}, {0, 2},
	{-1, 1}, {0, 1}, {1, 1},
	{-2, 0}, {-1, 0}, {0, 0}, {1, 0},
	{-1, -1}, {0, -1}, {1, -1},
	{-1, -2}, {0, -2},
	{0, -3},
};

-- The map is odd-r (odd rows shifted right). Offsets below are authored for an even-row centre; they are
-- turned into axial coordinates, rotated there, and added to the centre so the shape is the same on any row.
local function offsetToAxial(dx, dy) return dx - (dy - dy % 2) / 2, dy; end
local function cellToAxial(x, y) return x - (y - y % 2) / 2, y; end
local function axialToCell(q, r) return q + (r - r % 2) / 2, r; end
local function rotateAxial(q, r, steps)
	for _ = 1, steps % 6 do
		q, r = -r, q + r;
	end
	return q, r;
end
-- Tile for a DIAMOND offset around (cx, cy) after `rot` 60-degree turns.
local function diamondTile(cx, cy, dx, dy, rot, iW, iH, wrapX)
	local oq, orr = offsetToAxial(dx, dy);
	oq, orr = rotateAxial(oq, orr, rot);
	local cq, cr = cellToAxial(cx, cy);
	local x, y = axialToCell(cq + oq, cr + orr);
	if wrapX then x = x % iW; end
	return x, y;
end

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

local function oppDir(d) return ((d - 1 + 3) % 6) + 1; end
local function DrawSinaiSatellites(plotTypes, cx, cy, rot, diamondSet, iW, iH, wrapX, wrapY)
	local axisDir = rotDir(1, rot);
	local perpDirs = { rotDir(2, rot), rotDir(5, rot) };
	local numSats = 1 + Map.Rand(2, "");
	for _ = 1, numSats do
		local perpDir = perpDirs[Map.Rand(2, "") + 1];
		local steps = 2 + Map.Rand(2, "");
		local x, y = cx, cy;
		for _ = 1, steps do
			x, y = GetHexNeighbor(x, y, perpDir, iW, iH, wrapX, wrapY);
			if x < 0 or x >= iW or y < 0 or y >= iH then break; end
		end
		if x >= 0 and x < iW and y >= 0 and y < iH and not diamondSet[x .. "," .. y] then
			local satTiles = {};
			local idx = y * iW + x + 1;
			if plotTypes[idx] == PlotTypes.PLOT_OCEAN then
				satTiles[#satTiles + 1] = {x, y};
			end
			if #satTiles > 0 then
				local ax, ay = GetHexNeighbor(x, y, axisDir, iW, iH, wrapX, wrapY);
				if ax >= 0 and ax < iW and ay >= 0 and ay < iH and not diamondSet[ax .. "," .. ay] and plotTypes[ay * iW + ax + 1] == PlotTypes.PLOT_OCEAN then
					satTiles[#satTiles + 1] = {ax, ay};
				end
				if #satTiles < 2 then
					local ox, oy = GetHexNeighbor(x, y, oppDir(axisDir), iW, iH, wrapX, wrapY);
					if ox >= 0 and ox < iW and oy >= 0 and oy < iH and not diamondSet[ox .. "," .. oy] and plotTypes[oy * iW + ox + 1] == PlotTypes.PLOT_OCEAN then
						satTiles[#satTiles + 1] = {ox, oy};
					end
				elseif Map.Rand(2, "") == 0 then
					local ox, oy = GetHexNeighbor(x, y, oppDir(axisDir), iW, iH, wrapX, wrapY);
					if ox >= 0 and ox < iW and oy >= 0 and oy < iH and not diamondSet[ox .. "," .. oy] and plotTypes[oy * iW + ox + 1] == PlotTypes.PLOT_OCEAN then
						satTiles[#satTiles + 1] = {ox, oy};
					end
				end
			end
			if #satTiles >= 2 then
				for _, t in ipairs(satTiles) do
					local tx, ty = t[1], t[2];
					plotTypes[ty * iW + tx + 1] = (Map.Rand(100, "") < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
				end
			end
		end
	end
end

function TryPlaceSinaiIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.sinaiIsland then return false; end
	local pullBack = params.pullBack or 2;
	local effMin = params.effMin or 2;
	local effMax = params.effMax or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end
	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	local margin = 4;
	if not params.wrapY and (cy < margin or cy >= params.iH - margin) then return false; end
	if not params.wrapX and (cx < margin or cx >= params.iW - margin) then return false; end

	local rot = Map.Rand(6, "");
	local landTiles = {};
	for _, off in ipairs(DIAMOND_OFFSETS) do
		local gx, gy = diamondTile(cx, cy, off[1], off[2], rot, params.iW, params.iH, params.wrapX);
		if gx >= 0 and gx < params.iW and gy >= 0 and gy < params.iH then
			landTiles[#landTiles + 1] = {gx, gy};
		end
	end
	if #landTiles < 14 then return false; end
	local outerRingIdx = {};
	for _, idx in ipairs({1, 2, 3, 14, 15, 16}) do
		if idx <= #landTiles then outerRingIdx[#outerRingIdx + 1] = idx; end
	end
	-- 3-4 of the 6 outer tiles go (was 1-2): diamond of 12-13 tiles instead of 14-15.
	local numToRemove = math.min(3 + Map.Rand(2, ""), #outerRingIdx);
	local toRemove = {};
	for _ = 1, numToRemove do
		local pick = 1 + Map.Rand(#outerRingIdx, "");
		toRemove[#toRemove + 1] = outerRingIdx[pick];
		table.remove(outerRingIdx, pick);
	end
	table.sort(toRemove, function(a, b) return a > b; end);
	for _, idx in ipairs(toRemove) do
		table.remove(landTiles, idx);
	end
	if #landTiles < 10 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	local diamondSet = {};
	for _, t in ipairs(landTiles) do diamondSet[t[1] .. "," .. t[2]] = true; end

	DrawSinaiIsland(plotTypes, cx, cy, landTiles, rot, params.iW, params.iH, params.wrapX, params.wrapY);
	DrawSinaiSatellites(plotTypes, cx, cy, rot, diamondSet, params.iW, params.iH, params.wrapX, params.wrapY);
	_sinai_island_plot = plotIdx1(cx, cy, params.iW);
	if not _island_placed then _island_placed = {}; end
	_island_placed.sinaiIsland = true;
	return true;
end

function DrawSinaiIsland(plotTypes, cx, cy, landTiles, rot, iW, iH, wrapX, wrapY)
	-- Sinai = the diamond centre (same tile as _sinai_island_plot).
	local sinaiX, sinaiY = cx, cy;
	-- Extra peaks: 1-2 diamond tiles at least 2 steps from Sinai, the two tips first.
	local outerMtnSet = {};
	do
		local tips, others = {}, {};
		local t1x, t1y = diamondTile(cx, cy, 0, 3, rot, iW, iH, wrapX);
		local t2x, t2y = diamondTile(cx, cy, 0, -3, rot, iW, iH, wrapX);
		for _, t in ipairs(landTiles) do
			if Map.PlotDistance(sinaiX, sinaiY, t[1], t[2]) >= 2 then
				if (t[1] == t1x and t[2] == t1y) or (t[1] == t2x and t[2] == t2y) then
					tips[#tips + 1] = t;
				else
					others[#others + 1] = t;
				end
			end
		end
		local want = 1 + Map.Rand(2, "sinaiExtraPeaks");
		local picked = {};
		local function pickFrom(list)
			while #list > 0 and #picked < want do
				local i = 1 + Map.Rand(#list, "sinaiPeakPick");
				local t = list[i];
				table.remove(list, i);
				local ok = true;
				for _, p in ipairs(picked) do
					if Map.PlotDistance(p[1], p[2], t[1], t[2]) < 2 then ok = false; break; end
				end
				if ok then picked[#picked + 1] = t; end
			end
		end
		pickFrom(tips);
		pickFrom(others);
		for _, t in ipairs(picked) do outerMtnSet[t[1] .. "," .. t[2]] = true; end
	end

	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		local d = Map.PlotDistance(sinaiX, sinaiY, x, y);
		if d == 0 then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		elseif outerMtnSet[x .. "," .. y] then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		elseif d == 1 then
			plotTypes[idx] = PlotTypes.PLOT_HILLS;
		else
			plotTypes[idx] = (Map.Rand(100, "") < 40) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
