-- From mainland coast: water gap, stepping tile, gap, then an offshore blob (and optional satellites) built outward.

local firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
local firstRingYIsOdd  = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};

local function getNeighbor(x, y, dir, iW, iH, wrapX, wrapY)
	local adj = (y % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
	local nx = x + adj[1];
	local ny = y + adj[2];
	if wrapX then nx = nx % iW; if nx < 0 then nx = nx + iW; end end
	if wrapY then ny = ny % iH; if ny < 0 then ny = ny + iH; end end
	if not wrapX and (nx < 0 or nx >= iW) then return nil, nil; end
	if not wrapY and (ny < 0 or ny >= iH) then return nil, nil; end
	return nx, ny;
end

local function pidx(x, y, iW) return y * iW + x + 1; end

local function isWater(plotTypes, x, y, iW)
	if x < 0 or x >= iW or y < 0 then return false; end
	return plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_OCEAN;
end

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function noLandNeighbors(plotTypes, x, y, iW, iH, wrapX, wrapY)
	for d = 1, 6 do
		local nx, ny = getNeighbor(x, y, d, iW, iH, wrapX, wrapY);
		if nx and ny >= 0 and ny < iH and isLand(plotTypes, nx, ny, iW, iH) then
			return false;
		end
	end
	return true;
end

local function noMainlandNeighbors(x, y, iW, iH, wrapX, wrapY, mainlandSet)
	for d = 1, 6 do
		local nx, ny = getNeighbor(x, y, d, iW, iH, wrapX, wrapY);
		if nx and ny >= 0 and ny < iH and mainlandSet[pidx(nx, ny, iW)] then
			return false;
		end
	end
	return true;
end

local function floodFillMainland(plotTypes, iW, iH, wrapX, wrapY)
	local visited = {};
	local bestSize, bestStart = 0, nil;
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local idx = pidx(x, y, iW);
			local t = plotTypes[idx];
			if (t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN) and not visited[idx] then
				local stack = {{x, y}};
				local size = 0;
				visited[idx] = true;
				while #stack > 0 do
					local cx, cy = stack[#stack][1], stack[#stack][2];
					stack[#stack] = nil;
					size = size + 1;
					for dir = 1, 6 do
						local adj = (cy % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
						local nx, ny = cx + adj[1], cy + adj[2];
						if wrapX then nx = nx % iW; if nx < 0 then nx = nx + iW; end end
						if wrapY then ny = ny % iH; if ny < 0 then ny = ny + iH; end end
						if (wrapX or (nx >= 0 and nx < iW)) and (wrapY or (ny >= 0 and ny < iH)) then
							local nidx = pidx(nx, ny, iW);
							local nt = plotTypes[nidx];
							if (nt == PlotTypes.PLOT_LAND or nt == PlotTypes.PLOT_HILLS or nt == PlotTypes.PLOT_MOUNTAIN) and not visited[nidx] then
								visited[nidx] = true;
								stack[#stack + 1] = {nx, ny};
							end
						end
					end
				end
				if size > bestSize then bestSize = size; bestStart = {x, y}; end
			end
		end
	end
	return bestStart, bestSize;
end

local function collectMainlandAndCoasts(plotTypes, startX, startY, iW, iH, wrapX, wrapY)
	local mainland = {};
	local coasts = {};
	local stack = {{startX, startY}};
	local seen = {};
	seen[pidx(startX, startY, iW)] = true;
	while #stack > 0 do
		local cx, cy = stack[#stack][1], stack[#stack][2];
		stack[#stack] = nil;
		mainland[#mainland + 1] = {cx, cy};
		local hasOcean = false;
		for dir = 1, 6 do
			local nx, ny = getNeighbor(cx, cy, dir, iW, iH, wrapX, wrapY);
			if nx and ny >= 0 and ny < iH then
				local nidx = pidx(nx, ny, iW);
				local nt = plotTypes[nidx];
				if nt == PlotTypes.PLOT_OCEAN then hasOcean = true;
				elseif (nt == PlotTypes.PLOT_LAND or nt == PlotTypes.PLOT_HILLS or nt == PlotTypes.PLOT_MOUNTAIN) and not seen[nidx] then
					seen[nidx] = true;
					stack[#stack + 1] = {nx, ny};
				end
			end
		end
		if hasOcean then coasts[#coasts + 1] = {cx, cy}; end
	end
	return mainland, coasts;
end

local function wrapCoord(v, size, doWrap)
	if not doWrap then return v; end
	v = v % size;
	if v < 0 then v = v + size; end
	return v;
end

local function drawBlob(plotTypes, centerX, centerY, numTiles, iW, iH, wrapX, wrapY, excludeX, excludeY, forbidAdjX, forbidAdjY)
	local odd, even = firstRingYIsOdd, firstRingYIsEven;
	local ring1, ring2 = {}, {};
	local nextX, nextY, plot_adjustments;
	for ripple_radius = 1, 2 do
		local currentX = centerX - ripple_radius;
		local currentY = centerY;
		for direction_index = 1, 6 do
			for plot_to_handle = 1, ripple_radius do
				if currentY / 2 > math.floor(currentY / 2) then
					plot_adjustments = odd[direction_index];
				else
					plot_adjustments = even[direction_index];
				end
				nextX = currentX + plot_adjustments[1];
				nextY = currentY + plot_adjustments[2];
				local realX = wrapCoord(nextX, iW, wrapX);
				local realY = wrapCoord(nextY, iH, wrapY);
				if realX >= 0 and realX < iW and realY >= 0 and realY < iH then
					local ok = not (realX == excludeX and realY == excludeY);
					if ok and forbidAdjX ~= nil and forbidAdjY ~= nil then
						for dir = 1, 6 do
							local ax, ay = getNeighbor(forbidAdjX, forbidAdjY, dir, iW, iH, wrapX, wrapY);
							if ax and ay and ax == realX and ay == realY then
								ok = false;
								break;
							end
						end
					end
					if ok then
						if ripple_radius == 1 then ring1[#ring1 + 1] = {realX, realY};
						else ring2[#ring2 + 1] = {realX, realY}; end
					end
					currentX, currentY = nextX, nextY;
				end
			end
		end
	end
	local tiles = {{centerX, centerY}};
	if numTiles <= 7 then
		local nFromRing1 = numTiles - 1;
		for i = 1, #ring1 do
			local j = Map.Rand(i, "") + 1;
			ring1[i], ring1[j] = ring1[j], ring1[i];
		end
		for i = 1, math.min(nFromRing1, #ring1) do tiles[#tiles + 1] = ring1[i]; end
	else
		for i = 1, #ring1 do tiles[#tiles + 1] = ring1[i]; end
		local need = numTiles - 7;
		for i = 1, math.min(need, #ring2) do tiles[#tiles + 1] = ring2[i]; end
	end
	for i, t in ipairs(tiles) do
		local x, y = t[1], t[2];
		local r = Map.Rand(100, "");
		if i == 1 then
			if r < 70 then plotTypes[pidx(x, y, iW)] = PlotTypes.PLOT_HILLS;
			else plotTypes[pidx(x, y, iW)] = PlotTypes.PLOT_LAND; end
		else
			plotTypes[pidx(x, y, iW)] = (r < 60) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end

function TryPlaceSteppingStoneIsland(plotTypes, opts)
	if _island_placed and _island_placed.steppingStone then return false; end
	local iW = opts.iW;
	local iH = opts.iH;
	local wrapX = opts.wrapX;
	local wrapY = opts.wrapY or false;

	local start, size = floodFillMainland(plotTypes, iW, iH, wrapX, wrapY);
	if not start or size < 10 then return false; end
	local mainland, coasts = collectMainlandAndCoasts(plotTypes, start[1], start[2], iW, iH, wrapX, wrapY);
	if #coasts == 0 then return false; end
	local mainlandSet = {};
	for _, t in ipairs(mainland) do mainlandSet[pidx(t[1], t[2], iW)] = true; end

	local candidates = {};
	for _, c in ipairs(coasts) do
		local cx, cy = c[1], c[2];
		for dir = 1, 6 do
			local nx1, ny1 = getNeighbor(cx, cy, dir, iW, iH, wrapX, wrapY);
			if nx1 and ny1 >= 0 and ny1 < iH and isWater(plotTypes, nx1, ny1, iW) then
				local nx2, ny2 = getNeighbor(nx1, ny1, dir, iW, iH, wrapX, wrapY);
				if nx2 and ny2 >= 0 and ny2 < iH and isWater(plotTypes, nx2, ny2, iW) then
					local nx3, ny3 = getNeighbor(nx2, ny2, dir, iW, iH, wrapX, wrapY);
					if nx3 and ny3 >= 0 and ny3 < iH and isWater(plotTypes, nx3, ny3, iW) then
						local nx4, ny4 = getNeighbor(nx3, ny3, dir, iW, iH, wrapX, wrapY);
						if nx4 and ny4 >= 0 and ny4 < iH and isWater(plotTypes, nx4, ny4, iW) then
							if noLandNeighbors(plotTypes, nx2, ny2, iW, iH, wrapX, wrapY) and noMainlandNeighbors(nx4, ny4, iW, iH, wrapX, wrapY, mainlandSet) then
								candidates[#candidates + 1] = {coastX = cx, coastY = cy, dir = dir, stepX = nx2, stepY = ny2, nx3 = nx3, ny3 = ny3, centerX = nx4, centerY = ny4};
							end
						end
					end
				end
			end
		end
	end
	if #candidates == 0 then return false; end

	local c = candidates[Map.Rand(#candidates, "") + 1];
	local coastX, coastY = c.coastX, c.coastY;
	local stepX, stepY = c.stepX, c.stepY;
	local centerX, centerY = c.centerX, c.centerY;
	local backX, backY = c.nx3, c.ny3;

	plotTypes[pidx(coastX, coastY, iW)] = PlotTypes.PLOT_MOUNTAIN;
	if Map.Rand(100, "") < 55 then
		local bonusCandidates = {};
		for d = 1, 6 do
			if d ~= c.dir then
				local bx, by = getNeighbor(coastX, coastY, d, iW, iH, wrapX, wrapY);
				if bx and by >= 0 and by < iH and isLand(plotTypes, bx, by, iW, iH) then
					bonusCandidates[#bonusCandidates + 1] = { bx, by };
				end
			end
		end
		if #bonusCandidates > 0 then
			local pick = bonusCandidates[Map.Rand(#bonusCandidates, "") + 1];
			plotTypes[pidx(pick[1], pick[2], iW)] = PlotTypes.PLOT_MOUNTAIN;
		end
	end
	local stepR = Map.Rand(100, "");
	plotTypes[pidx(stepX, stepY, iW)] = (stepR < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_MOUNTAIN;

	local blobSize = 4 + Map.Rand(9, "");
	if Map.Rand(100, "") < 28 then blobSize = blobSize + 3 + Map.Rand(4, ""); end
	blobSize = math.max(4, blobSize - 2);
	drawBlob(plotTypes, centerX, centerY, blobSize, iW, iH, wrapX, wrapY, backX, backY, stepX, stepY);

	if Map.Rand(100, "") < 38 then
		local awayDir = c.dir;
		local frontX, frontY = centerX, centerY;
		while true do
			local nx, ny = getNeighbor(frontX, frontY, awayDir, iW, iH, wrapX, wrapY);
			if not nx or ny < 0 or ny >= iH or not isLand(plotTypes, nx, ny, iW, iH) then break; end
			frontX, frontY = nx, ny;
		end
		local gx, gy = getNeighbor(frontX, frontY, awayDir, iW, iH, wrapX, wrapY);
		if gx and gy >= 0 and gy < iH and isWater(plotTypes, gx, gy, iW) and noMainlandNeighbors(gx, gy, iW, iH, wrapX, wrapY, mainlandSet) then
			local satSize = 1 + Map.Rand(3, "");
			plotTypes[pidx(gx, gy, iW)] = (Map.Rand(100, "") < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
			for _ = 1, satSize - 1 do
				local pickDir = Map.Rand(6, "") + 1;
				local adj = (gy % 2 ~= 0) and firstRingYIsOdd[pickDir] or firstRingYIsEven[pickDir];
				local sx = gx + adj[1];
				local sy = gy + adj[2];
				if wrapX then sx = sx % iW; if sx < 0 then sx = sx + iW; end end
				if wrapY then sy = sy % iH; if sy < 0 then sy = sy + iH; end end
				if sx >= 0 and sx < iW and sy >= 0 and sy < iH and plotTypes[pidx(sx, sy, iW)] == PlotTypes.PLOT_OCEAN and noMainlandNeighbors(sx, sy, iW, iH, wrapX, wrapY, mainlandSet) then
					plotTypes[pidx(sx, sy, iW)] = (Map.Rand(100, "") < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
					gx, gy = sx, sy;
				end
			end
		end
	end

	if not _island_placed then _island_placed = {}; end
	_island_placed.steppingStone = true;
	return true, centerX, centerY;
end
