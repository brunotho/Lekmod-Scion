-- Neighbors, rings, disks, and offset rotation for even-r hex used by island scripts.

firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
firstRingYIsOdd  = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};

function GetHexRing(y)
	return (y % 2 ~= 0) and firstRingYIsOdd or firstRingYIsEven;
end

function WrapCoord(v, size, doWrap)
	if not doWrap then return v; end
	v = v % size;
	if v < 0 then v = v + size; end
	return v;
end

function GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY)
	local adj = (y % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
	local nx = x + adj[1];
	local ny = y + adj[2];
	nx = WrapCoord(nx, iW, wrapX);
	ny = WrapCoord(ny, iH, wrapY);
	return nx, ny;
end

function GetHexNeighbors(x, y)
	local adj = (y % 2 ~= 0) and firstRingYIsOdd or firstRingYIsEven;
	local out = {};
	for dir = 1, 6 do
		out[#out + 1] = {x + adj[dir][1], y + adj[dir][2]};
	end
	return out;
end

function IsHexAdjacent(ax, ay, bx, by)
	local adj = (ay % 2 ~= 0) and firstRingYIsOdd or firstRingYIsEven;
	local dx, dy = bx - ax, by - ay;
	for d = 1, 6 do
		if adj[d][1] == dx and adj[d][2] == dy then return true; end
	end
	return false;
end

-- Rotate (dx, dy) by steps*60 degrees clockwise on even-r offset hex grid. steps in 0..5.
-- Use for rotating a template: RotateOffset60(tx, ty, steps) gives correct (dx', dy').
function RotateOffset60(dx, dy, steps)
	steps = steps % 6;
	if steps == 0 then return dx, dy; end
	-- Even-r offset -> axial: q = x, r = y - floor((x + (x mod 2)) / 2)
	local q = dx;
	local r = dy - math.floor((dx + (dx % 2)) / 2);
	for _ = 1, steps do
		q, r = -r, q + r;
	end
	-- Axial -> even-r offset: x = q, y = r + floor((q + (q mod 2)) / 2)
	local x = q;
	local y = r + math.floor((q + (q % 2)) / 2);
	return x, y;
end

-- Returns tiles at exactly hex distance radius (ring only). Radius >= 1.
function GetHexRingAtRadius(cx, cy, radius, iW, iH, wrapX, wrapY)
	local out = {};
	local currentX = cx - radius;
	local currentY = cy;
	for dir = 1, 6 do
		for step = 1, radius do
			local gx = WrapCoord(currentX, iW, wrapX);
			local gy = WrapCoord(currentY, iH, wrapY);
			if gx >= 0 and gx < iW and gy >= 0 and gy < iH then
				out[#out + 1] = {gx, gy};
			end
			local adj = (currentY % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
			currentX = currentX + adj[1];
			currentY = currentY + adj[2];
		end
	end
	return out;
end

function GetHexDisk(cx, cy, radius, iW, iH, wrapX, wrapY)
	local out = {};
	local gx = WrapCoord(cx, iW, wrapX);
	local gy = WrapCoord(cy, iH, wrapY);
	if gx >= 0 and gx < iW and gy >= 0 and gy < iH then
		out[#out + 1] = {gx, gy};
	end
	for r = 1, radius do
		local currentX = cx - r;
		local currentY = cy;
		for dir = 1, 6 do
			for step = 1, r do
				local adj = (currentY % 2 ~= 0) and firstRingYIsOdd[dir] or firstRingYIsEven[dir];
				currentX = currentX + adj[1];
				currentY = currentY + adj[2];
				gx = WrapCoord(currentX, iW, wrapX);
				gy = WrapCoord(currentY, iH, wrapY);
				if gx >= 0 and gx < iW and gy >= 0 and gy < iH then
					out[#out + 1] = {gx, gy};
				end
			end
		end
	end
	return out;
end

function GetScatteredDiskLandTiles(centerX, centerY, radius, iW, iH, wrapX, wrapY)
	wrapY = wrapY or false;
	local odd = firstRingYIsOdd;
	local even = firstRingYIsEven;
	local landTiles = {};
	local landvarDefault = 10;

	local cx = WrapCoord(centerX, iW, wrapX);
	local cy = WrapCoord(centerY, iH, wrapY);
	if cx >= 0 and cx < iW and cy >= 0 and cy < iH then
		landTiles[#landTiles + 1] = {cx, cy, 0};
	end

	for r = 1, radius do
		local ringScale = (r == 1) and 1.0 or (r == 2) and 1.25 or 1.5;
		local currentX = centerX - r;
		local currentY = centerY;
		for dir = 1, 6 do
			for step = 1, r do
				local adj = (currentY % 2 ~= 0) and odd[dir] or even[dir];
				currentX = currentX + adj[1];
				currentY = currentY + adj[2];
				local gx = WrapCoord(currentX, iW, wrapX);
				local gy = WrapCoord(currentY, iH, wrapY);
				if gx >= 0 and gx < iW and gy >= 0 and gy < iH then
					local thisislandvar = Map.Rand(30, "") + landvarDefault;
					local islThresh = Map.Rand(50, "") + math.floor(thisislandvar / ringScale);
					local islRand = Map.Rand(100, "");
					if islRand > islThresh then
						landvarDefault = landvarDefault + 5;
					else
						landTiles[#landTiles + 1] = {gx, gy, r};
					end
				end
			end
		end
	end
	return landTiles;
end

function DrawScatteredDisk(plotTypes, landTiles, iW, hillThresh, noMountains)
	if noMountains then
		local hillsPct = hillThresh or 70;
		for _, t in ipairs(landTiles) do
			local x, y = t[1], t[2];
			local idx = y * iW + x + 1;
			plotTypes[idx] = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
		return;
	end
	hillThresh = hillThresh or 70;
	local char = Map.Rand(3, "");
	local hillBias = (char == 0) and -15 or (char == 1) and 20 or 0;
	local mtnBias = (char == 2) and 4 or 0;
	local mtnChance = (#landTiles <= 6) and (2 + mtnBias) or (5 + mtnBias);
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local ring = t[3] or 0;
		local idx = y * iW + x + 1;
		local ht = hillThresh + hillBias + (ring * 5) + Map.Rand(15, "") - 7;
		ht = math.max(25, math.min(85, ht));
		local mt = (Map.Rand(100, "") < ht) and PlotTypes.PLOT_LAND or PlotTypes.PLOT_HILLS;
		if mt == PlotTypes.PLOT_LAND and Map.Rand(100, "") < mtnChance then
			mt = PlotTypes.PLOT_MOUNTAIN;
		end
		plotTypes[idx] = mt;
	end
end

function ApplyBasicIslandTerrain(plotTypes, landTiles, iW)
	local n = #landTiles;
	if n == 0 then return; end
	local hillsPct = 50 + Map.Rand(11, "");
	local hillTiles = {};
	local flatTiles = {};
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		if Map.Rand(100, "") < hillsPct then
			plotTypes[idx] = PlotTypes.PLOT_HILLS;
			hillTiles[#hillTiles + 1] = idx;
		else
			plotTypes[idx] = PlotTypes.PLOT_LAND;
			flatTiles[#flatTiles + 1] = idx;
		end
	end
	local numMountains = 0;
	if n <= 6 then
		if Map.Rand(100, "") < 2 then numMountains = 1;
		elseif Map.Rand(100, "") < 1 then numMountains = 2; end
	else
		if Map.Rand(100, "") < 5 then numMountains = 1;
		elseif Map.Rand(100, "") < 2 then numMountains = 2; end
	end
	local candidates = {};
	for _, idx in ipairs(hillTiles) do candidates[#candidates + 1] = idx; end
	if #candidates == 0 then
		for _, idx in ipairs(flatTiles) do candidates[#candidates + 1] = idx; end
	end
	for i = 1, math.min(numMountains, #candidates) do
		local r = Map.Rand(#candidates, "") + 1;
		plotTypes[candidates[r]] = PlotTypes.PLOT_MOUNTAIN;
		table.remove(candidates, r);
	end
end
