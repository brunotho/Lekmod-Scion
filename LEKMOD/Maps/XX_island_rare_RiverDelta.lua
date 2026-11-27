-- Coastal river delta: a diamond of land and hills straddling the shore, half in ocean.

include("X_IslandHelpers");

local RIVER_DELTA_DEBUG = true;

local WEDGE_ROWS = 5;
local WEDGE_W = 5;
local OCEAN_ROWS = 2;

local function pidx(x, y, iW)
	return y * iW + x + 1;
end

local function isOcean(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	return plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_OCEAN;
end

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

local function walk(x, y, dir, steps, iW, iH, wrapX, wrapY)
	for _ = 1, steps do
		if not x or x < 0 or x >= iW or not y or y < 0 or y >= iH then return nil, nil; end
		x, y = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
		if x < 0 or x >= iW or y < 0 or y >= iH then return nil, nil; end
	end
	return x, y;
end

local function isOuterOcean(plotTypes, startX, startY, iW, iH, wrapX, wrapY)
	local visited = {};
	local stack = { { startX, startY } };
	local function key(x, y) return y * iW + x; end
	while #stack > 0 do
		local t = table.remove(stack);
		local x, y = t[1], t[2];
		local k = key(x, y);
		if not visited[k] then
			visited[k] = true;
			if x == 0 or x == iW - 1 or y == 0 or y == iH - 1 then return true; end
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
					local nk = key(nx, ny);
					if not visited[nk] and isOcean(plotTypes, nx, ny, iW, iH) then
						stack[#stack + 1] = { nx, ny };
					end
				end
			end
		end
	end
	return false;
end

local function getRow(cx, cy, leftDir, rightDir, w, iW, iH, wrapX, wrapY)
	local out = {};
	local half = math.floor((w - 1) / 2);
	local lx, ly = walk(cx, cy, leftDir, half, iW, iH, wrapX, wrapY);
	if not lx then return out; end
	for i = 0, w - 1 do
		local px, py = walk(lx, ly, rightDir, i, iW, iH, wrapX, wrapY);
		if px and px >= 0 and px < iW and py >= 0 and py < iH then
			out[#out + 1] = { px, py };
		end
	end
	return out;
end

function TryPlaceRiverDeltaIsland(plotTypes, opts)
	local iW = opts.iW;
	local iH = opts.iH;
	if not iW or not iH then iW, iH = Map.GetGridSize(); end
	local wrapX = opts.wrapX and true or false;
	local wrapY = opts.wrapY and true or false;
	local margin = 10;

	if Map and Map.Rand then
		print("[RiverDelta] TryPlaceRiverDeltaIsland called, iW=" .. tostring(iW) .. " iH=" .. tostring(iH));
	end

	for attempt = 1, 80 do
		local cx = margin + Map.Rand(iW - 2 * margin, "");
		local cy = margin + Map.Rand(iH - 2 * margin, "");
		if cx < 0 or cx >= iW or cy < 0 or cy >= iH then
		elseif not isLand(plotTypes, cx, cy, iW, iH) then
		else
		local oceanDir = nil;
		local oceanX, oceanY = nil, nil;
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx and nx >= 0 and nx < iW and ny >= 0 and ny < iH and isOcean(plotTypes, nx, ny, iW, iH) then
				oceanDir = d;
				oceanX, oceanY = nx, ny;
				break;
			end
		end
		if not oceanDir then
		elseif oceanDir ~= 2 and oceanDir ~= 5 then
		elseif not isOuterOcean(plotTypes, oceanX, oceanY, iW, iH, wrapX, wrapY) then
		else
		local inlandDir = rotDir(oceanDir, 3);
		local leftDir = rotDir(inlandDir, 2);
		local rightDir = rotDir(inlandDir, -2);

		local wedgeSet = {};
		local rowTiles = {};
		local coreOk = true;
		for d = -OCEAN_ROWS, WEDGE_ROWS - 1 - OCEAN_ROWS do
			local rx, ry;
			if d == 0 then
				rx, ry = cx, cy;
			elseif d < 0 then
				rx, ry = walk(cx, cy, oceanDir, -d, iW, iH, wrapX, wrapY);
			else
				rx, ry = walk(cx, cy, inlandDir, d, iW, iH, wrapX, wrapY);
			end
			if not rx or rx < 0 or rx >= iW or ry < 0 or ry >= iH then coreOk = false; break; end
			local row = getRow(rx, ry, leftDir, rightDir, WEDGE_W, iW, iH, wrapX, wrapY);
			if #row ~= WEDGE_W then coreOk = false; break; end
			rowTiles[d] = {};
			for _, cell in ipairs(row) do
				local x, y = cell[1], cell[2];
				local key = x .. "," .. y;
				if not wedgeSet[key] then wedgeSet[key] = true; rowTiles[d][#rowTiles[d] + 1] = { x, y }; end
			end
		end

		if not coreOk or not rowTiles[0] or #rowTiles[0] ~= WEDGE_W then
		else
		for d = -OCEAN_ROWS, WEDGE_ROWS - 1 - OCEAN_ROWS do
			if rowTiles[d] then
				for _, t in ipairs(rowTiles[d]) do
					plotTypes[pidx(t[1], t[2], iW)] = PlotTypes.PLOT_MOUNTAIN;
				end
			end
		end
		if Map and Map.Rand then
			print("[RiverDelta] PLACED at coast (" .. tostring(cx) .. "," .. tostring(cy) .. ")");
		end
		return true;
		end end end
	end
	if Map and Map.Rand then
		print("[RiverDelta] No valid spot after 80 attempts (coast+wedge in bounds)");
	end
	if RIVER_DELTA_DEBUG and plotTypes and margin < iW and margin < iH then
		plotTypes[pidx(margin, margin, iW)] = PlotTypes.PLOT_MOUNTAIN;
		if margin + 1 < iW then plotTypes[pidx(margin + 1, margin, iW)] = PlotTypes.PLOT_MOUNTAIN; end
		if margin + 1 < iH then plotTypes[pidx(margin, margin + 1, iW)] = PlotTypes.PLOT_MOUNTAIN; end
	end
	return false;
end
