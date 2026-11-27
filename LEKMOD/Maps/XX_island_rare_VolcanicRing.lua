-- Central peak, inner water moat, broken ring of outer islets in the next rings.

include("X_IslandHelpers");

local function atan2(y, x)
	if x > 0 then return math.atan(y / x);
	elseif x < 0 then return math.atan(y / x) + math.pi;
	elseif y > 0 then return math.pi / 2;
	elseif y < 0 then return -math.pi / 2;
	else return 0; end
end

local CONFIG = {
	DISK_RADIUS = 3,
	WATER_RING_RADIUS = 1,
	NUM_ISLANDS_MIN = 1, NUM_ISLANDS_MAX = 5,
	ONE_ISLAND_RING_PCT_MIN = 80, ONE_ISLAND_RING_PCT_MAX = 95,
	ISLAND_LEN_MIN = 1, ISLAND_LEN_MAX = 3,
	GAP_LEN_MIN = 2, GAP_LEN_MAX = 4,
	THICKNESS_2_PCT = 65,
	HILLS_PCT = 80,
	RIM_MOUNTAIN_PCT = 10, RIM_HILLS_PCT = 70,
	CENTER_TRIANGLE_PCT = 30,
	R3_LAND_MAX_PCT = 65,
	BAY_INLET_PCT = 22,
	OUTER_RING_PCT = 0,
	OUTER_RING_TILES_MIN = 1, OUTER_RING_TILES_MAX = 3,
};

function TryPlaceVolcanicRing(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 0;
	local effMin = params.effMin or 0;
	local effMax = params.effMax or 6;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local disk1 = GetHexDisk(cx, cy, CONFIG.WATER_RING_RADIUS, params.iW, params.iH, params.wrapX, params.wrapY);
	local disk2 = GetHexDisk(cx, cy, 2, params.iW, params.iH, params.wrapX, params.wrapY);
	local disk3 = GetHexDisk(cx, cy, CONFIG.DISK_RADIUS, params.iW, params.iH, params.wrapX, params.wrapY);

	local disk1Set = {};
	for _, t in ipairs(disk1) do disk1Set[t[1] .. "," .. t[2]] = true; end

	local centerMountainSet = {};
	local hasTriangleCenter = false;
	if Map.Rand(100, "") < CONFIG.CENTER_TRIANGLE_PCT then
		hasTriangleCenter = true;
		local d = Map.Rand(6, "") + 1;
		local d2 = (d % 6) + 1;
		centerMountainSet[cx .. "," .. cy] = true;
		local nx1, ny1 = GetHexNeighbor(cx, cy, d, params.iW, params.iH, params.wrapX, params.wrapY);
		local nx2, ny2 = GetHexNeighbor(cx, cy, d2, params.iW, params.iH, params.wrapX, params.wrapY);
		if nx1 >= 0 and nx1 < params.iW and ny1 >= 0 and ny1 < params.iH then
			centerMountainSet[nx1 .. "," .. ny1] = true;
		end
		if nx2 >= 0 and nx2 < params.iW and ny2 >= 0 and ny2 < params.iH then
			centerMountainSet[nx2 .. "," .. ny2] = true;
		end
	else
		centerMountainSet[cx .. "," .. cy] = true;
	end

	for _, t in ipairs(disk1) do
		local key = t[1] .. "," .. t[2];
		if centerMountainSet[key] then
			plotTypes[t[2] * params.iW + t[1] + 1] = PlotTypes.PLOT_MOUNTAIN;
		else
			plotTypes[t[2] * params.iW + t[1] + 1] = PlotTypes.PLOT_OCEAN;
		end
	end

	local disk2Set = {};
	for _, t in ipairs(disk2) do disk2Set[t[1] .. "," .. t[2]] = true; end

	local ring2 = {};
	local ring3 = {};
	for _, t in ipairs(disk2) do
		if not disk1Set[t[1] .. "," .. t[2]] then
			ring2[#ring2 + 1] = t;
		end
	end
	for _, t in ipairs(disk3) do
		if not disk2Set[t[1] .. "," .. t[2]] then
			ring3[#ring3 + 1] = t;
		end
	end

	local ring2Set = {};
	for _, t in ipairs(ring2) do ring2Set[t[1] .. "," .. t[2]] = true; end

	local ring23 = {};
	for _, t in ipairs(ring2) do ring23[#ring23 + 1] = {t[1], t[2], 2}; end
	for _, t in ipairs(ring3) do ring23[#ring23 + 1] = {t[1], t[2], 3}; end
	table.sort(ring23, function(a, b)
		local ax, ay = a[1] - cx, a[2] - cy;
		local bx, by = b[1] - cx, b[2] - cy;
		return atan2(ax, ay) < atan2(bx, by);
	end);

	local islandSet = {};
	local numIslands = CONFIG.NUM_ISLANDS_MIN + Map.Rand(CONFIG.NUM_ISLANDS_MAX - CONFIG.NUM_ISLANDS_MIN + 1, "");
	local n = #ring23;

	if numIslands == 1 then
		local ringPct = CONFIG.ONE_ISLAND_RING_PCT_MIN + Map.Rand(CONFIG.ONE_ISLAND_RING_PCT_MAX - CONFIG.ONE_ISLAND_RING_PCT_MIN + 1, "");
		local islandTiles = math.max(1, math.floor(n * ringPct / 100));
		local gapTiles = math.max(1, n - islandTiles);
		islandTiles = n - gapTiles;
		local gapStart = Map.Rand(n, "");
		local gapIdxSet = {};
		for g = 0, gapTiles - 1 do
			gapIdxSet[((gapStart + g) % n) + 1] = true;
		end
		for i = 1, n do
			if not gapIdxSet[i] then
				local t = ring23[i];
				islandSet[t[1] .. "," .. t[2]] = t[3];
			end
		end
	else
		local idx = 1;
		for _ = 1, numIslands do
			if idx > n then break; end
			local len = CONFIG.ISLAND_LEN_MIN + Map.Rand(CONFIG.ISLAND_LEN_MAX - CONFIG.ISLAND_LEN_MIN + 1, "");
			len = math.min(len, n - idx + 1);
			for i = 1, len do
				if idx <= n then
					local t = ring23[idx];
					islandSet[t[1] .. "," .. t[2]] = t[3];
					idx = idx + 1;
				end
			end
			local gapLen = CONFIG.GAP_LEN_MIN + Map.Rand(CONFIG.GAP_LEN_MAX - CONFIG.GAP_LEN_MIN + 1, "");
			idx = idx + gapLen;
		end
	end

	do
		local filled = 0;
		for _, t in ipairs(ring23) do
			if islandSet[t[1] .. "," .. t[2]] then
				filled = filled + 1;
			end
		end
		if filled >= n then
			local t = ring23[1 + Map.Rand(n, "volc_ring_break")];
			islandSet[t[1] .. "," .. t[2]] = nil;
		end
	end

	for _, t in ipairs(ring23) do
		local x, y = t[1], t[2];
		local key = x .. "," .. y;
		if islandSet[key] then
			if islandSet[key] == 3 and Map.Rand(100, "") < CONFIG.THICKNESS_2_PCT then
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(x, y, d, params.iW, params.iH, params.wrapX, params.wrapY);
					if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and ring2Set[nx .. "," .. ny] then
						islandSet[nx .. "," .. ny] = 2;
						break;
					end
				end
			end
		end
	end

	if hasTriangleCenter then
		local r1WaterAdj = {};
		for _, t in ipairs(disk1) do
			local key = t[1] .. "," .. t[2];
			if not centerMountainSet[key] then
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(t[1], t[2], d, params.iW, params.iH, params.wrapX, params.wrapY);
					if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and ring2Set[nx .. "," .. ny] then
						r1WaterAdj[nx .. "," .. ny] = true;
					end
				end
			end
		end
		local adjList = {};
		for k in pairs(r1WaterAdj) do adjList[#adjList + 1] = k; end
		if #adjList > 0 then
			local i = 1 + Map.Rand(#adjList, "");
			islandSet[adjList[i]] = nil;
		end
	end

	local r3LandList = {};
	for _, t in ipairs(ring3) do
		local key = t[1] .. "," .. t[2];
		if islandSet[key] then r3LandList[#r3LandList + 1] = key; end
	end
	local r3MaxLand = math.max(1, math.floor(#ring3 * CONFIG.R3_LAND_MAX_PCT / 100));
	while #r3LandList > r3MaxLand do
		local i = 1 + Map.Rand(#r3LandList, "");
		islandSet[r3LandList[i]] = nil;
		r3LandList[i] = r3LandList[#r3LandList];
		r3LandList[#r3LandList] = nil;
	end
	for _, key in ipairs(r3LandList) do
		if Map.Rand(100, "") < CONFIG.BAY_INLET_PCT then
			islandSet[key] = nil;
		end
	end

	if Map.Rand(100, "") < CONFIG.OUTER_RING_PCT then
		local disk4 = GetHexDisk(cx, cy, 4, params.iW, params.iH, params.wrapX, params.wrapY);
		local disk3Set = {};
		for _, t in ipairs(disk3) do disk3Set[t[1] .. "," .. t[2]] = true; end
		local ring4 = {};
		for _, t in ipairs(disk4) do
			if not disk3Set[t[1] .. "," .. t[2]] then ring4[#ring4 + 1] = t; end
		end
		local nOuter = CONFIG.OUTER_RING_TILES_MIN + Map.Rand(CONFIG.OUTER_RING_TILES_MAX - CONFIG.OUTER_RING_TILES_MIN + 1, "");
		for i = 1, math.min(nOuter, #ring4) do
			local j = i + Map.Rand(#ring4 - i + 1, "");
			if j < i then j = i; end
			ring4[i], ring4[j] = ring4[j], ring4[i];
			local t = ring4[i];
			islandSet[t[1] .. "," .. t[2]] = 4;
		end
	end

	local waterSet = {};
	for _, t in ipairs(disk1) do waterSet[t[1] .. "," .. t[2]] = true; end
	for _, t in ipairs(ring23) do
		if not islandSet[t[1] .. "," .. t[2]] then
			waterSet[t[1] .. "," .. t[2]] = true;
		end
	end

	for _, t in ipairs(ring23) do
		local x, y = t[1], t[2];
		local key = x .. "," .. y;
		if islandSet[key] then
			local adjWater = false;
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(x, y, d, params.iW, params.iH, params.wrapX, params.wrapY);
				if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and waterSet[nx .. "," .. ny] then
					adjWater = true;
					break;
				end
			end
			local mt;
			if adjWater and Map.Rand(100, "") < CONFIG.RIM_MOUNTAIN_PCT then
				mt = PlotTypes.PLOT_MOUNTAIN;
			else
				local hillsPct = adjWater and CONFIG.RIM_HILLS_PCT or CONFIG.HILLS_PCT;
				mt = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
			end
			plotTypes[y * params.iW + x + 1] = mt;
		else
			plotTypes[y * params.iW + x + 1] = PlotTypes.PLOT_OCEAN;
		end
	end
	for key, ringNum in pairs(islandSet) do
		if ringNum == 4 then
			local x, y = key:match("([^,]+),([^,]+)");
			x, y = tonumber(x), tonumber(y);
			local hillsPct = CONFIG.RIM_HILLS_PCT;
			plotTypes[y * params.iW + x + 1] = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end

	local ringLandKeys = {};
	for _, t in ipairs(ring23) do
		local x, y, rn = t[1], t[2], t[3];
		local key = x .. "," .. y;
		if islandSet[key] and (rn == 2 or rn == 3) then
			local pt = plotTypes[y * params.iW + x + 1];
			if pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS or pt == PlotTypes.PLOT_MOUNTAIN then
				ringLandKeys[#ringLandKeys + 1] = { x, y };
			end
		end
	end
	local nErase = math.min(2 + Map.Rand(2, ""), #ringLandKeys);
	for i = #ringLandKeys, 2, -1 do
		local j = 1 + Map.Rand(i, "");
		ringLandKeys[i], ringLandKeys[j] = ringLandKeys[j], ringLandKeys[i];
	end
	for i = 1, nErase do
		local t = ringLandKeys[i];
		plotTypes[t[2] * params.iW + t[1] + 1] = PlotTypes.PLOT_OCEAN;
	end
	return true;
end
