-- A curved water cut through a small hex disk, leaving hills and land around it like a rift inlet.

include("X_IslandHelpers");

local CONFIG = {
	DISK_RADIUS = 3,
	INNER_HILLS_PCT = 64,
	OUTER_LAND_PCT_INNER = 52, OUTER_LAND_PCT_OUTER = 24,
	OUTER_TILE_APPEAR_PCT = 73,
	RIFT_TURN_LEFT_PCT = 38, RIFT_TURN_RIGHT_PCT = 24, RIFT_DOUBLE_TURN_PCT = 18,
	RIFT_STEPS_MIN = 5, RIFT_STEPS_RANGE = 3,
	BRANCH_COUNT_MIN = 0, BRANCH_COUNT_RANGE = 2,
	BRANCH_STEPS_MIN = 1, BRANCH_STEPS_RANGE = 1,
	BRANCH_DIR_CHANGE_PCT = 38,
};

function TryPlaceWaterRift(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 0;
	local effMin = params.effMin or 0;
	local effMax = params.effMax or 6;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local disk = GetHexDisk(cx, cy, CONFIG.DISK_RADIUS, params.iW, params.iH, params.wrapX, params.wrapY);
	local diskSet = {};
	for _, t in ipairs(disk) do diskSet[t[1] .. "," .. t[2]] = true; end

	local riftDir = Map.Rand(6, "") + 1;
	local oppDir = ((riftDir + 2) % 6) + 1;
	local riftSet = {};
	riftSet[cx .. "," .. cy] = true;

	local function walkRift(startX, startY, baseDir, steps)
		local px, py = startX, startY;
		local dir = baseDir;
		for _ = 1, steps do
			px, py = GetHexNeighbor(px, py, dir, params.iW, params.iH, params.wrapX, params.wrapY);
			if px >= 0 and px < params.iW and py >= 0 and py < params.iH and diskSet[px .. "," .. py] then
				riftSet[px .. "," .. py] = true;
				local r = Map.Rand(100, "");
				if r < CONFIG.RIFT_TURN_LEFT_PCT then dir = ((dir - 2) % 6) + 1;
				elseif r >= (100 - CONFIG.RIFT_TURN_RIGHT_PCT) then dir = ((dir + 2) % 6) + 1; end
				if Map.Rand(100, "") < CONFIG.RIFT_DOUBLE_TURN_PCT then dir = ((dir + (Map.Rand(2, "") == 0 and -2 or 2)) % 6) + 1; end
			else break; end
		end
	end
	walkRift(cx, cy, riftDir, CONFIG.RIFT_STEPS_MIN + Map.Rand(CONFIG.RIFT_STEPS_RANGE, ""));
	walkRift(cx, cy, oppDir, CONFIG.RIFT_STEPS_MIN + Map.Rand(CONFIG.RIFT_STEPS_RANGE, ""));

	for _ = 1, CONFIG.BRANCH_COUNT_MIN + Map.Rand(CONFIG.BRANCH_COUNT_RANGE, "") do
		local branchDir = Map.Rand(6, "") + 1;
		local bx, by = cx, cy;
		for step = 1, CONFIG.BRANCH_STEPS_MIN + Map.Rand(CONFIG.BRANCH_STEPS_RANGE, "") do
			bx, by = GetHexNeighbor(bx, by, branchDir, params.iW, params.iH, params.wrapX, params.wrapY);
			if bx >= 0 and bx < params.iW and by >= 0 and by < params.iH and diskSet[bx .. "," .. by] then
				riftSet[bx .. "," .. by] = true;
				if Map.Rand(100, "") < CONFIG.BRANCH_DIR_CHANGE_PCT then branchDir = ((branchDir + (Map.Rand(2, "") == 0 and -1 or 1)) % 6) + 1; end
			else break; end
		end
	end

	local riftList = {};
	for k in pairs(riftSet) do
		local x, y = k:match("^(%d+),(%d+)$");
		if x then riftList[#riftList + 1] = {tonumber(x), tonumber(y)}; end
	end
	local function axialQ(x, y) return x; end
	local function axialR(x, y) return y - math.floor(x / 2); end
	local minQ, maxQ, minR, maxR, minQR, maxQR = 1e9, -1e9, 1e9, -1e9, 1e9, -1e9;
	for _, t in ipairs(riftList) do
		local x, y = t[1], t[2];
		local q, r = axialQ(x, y), axialR(x, y);
		local qr = q + r;
		if q < minQ then minQ = q; end
		if q > maxQ then maxQ = q; end
		if r < minR then minR = r; end
		if r > maxR then maxR = r; end
		if qr < minQR then minQR = qr; end
		if qr > maxQR then maxQR = qr; end
	end
	local isPerfectLine = (#riftList >= 2) and ((maxQ - minQ == 0) or (maxR - minR == 0) or (maxQR - minQR == 0));
	if isPerfectLine then
		local jitterCandidates = {};
		for _, t in ipairs(riftList) do
			local x, y = t[1], t[2];
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(x, y, d, params.iW, params.iH, params.wrapX, params.wrapY);
				if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH then
					local key = nx .. "," .. ny;
					if diskSet[key] and not riftSet[key] then jitterCandidates[key] = {nx, ny}; end
				end
			end
		end
		local jitterList = {};
		for _, v in pairs(jitterCandidates) do jitterList[#jitterList + 1] = v; end
		local numJitter = math.min(1 + Map.Rand(2, ""), #jitterList);
		for i = 1, numJitter do
			if #jitterList == 0 then break; end
			local idx = Map.Rand(#jitterList, "") + 1;
			local t = jitterList[idx];
			riftSet[t[1] .. "," .. t[2]] = true;
			jitterList[idx] = jitterList[#jitterList];
			jitterList[#jitterList] = nil;
		end
	end

	local disk2 = GetHexDisk(cx, cy, CONFIG.DISK_RADIUS - 1, params.iW, params.iH, params.wrapX, params.wrapY);
	local disk2Set = {};
	for _, t in ipairs(disk2) do disk2Set[t[1] .. "," .. t[2]] = true; end

	for _, t in ipairs(disk) do
		local x, y = t[1], t[2];
		if riftSet[x .. "," .. y] then
			plotTypes[y * params.iW + x] = PlotTypes.PLOT_OCEAN;
		elseif disk2Set[x .. "," .. y] then
			plotTypes[y * params.iW + x] = (Map.Rand(100, "") < CONFIG.INNER_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		else
			local adjInner = false;
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(x, y, d, params.iW, params.iH, params.wrapX, params.wrapY);
				if nx >= 0 and nx < params.iW and ny >= 0 and ny < params.iH and disk2Set[nx .. "," .. ny] then
					adjInner = true;
					break;
				end
			end
			local landPct = adjInner and CONFIG.OUTER_LAND_PCT_INNER or CONFIG.OUTER_LAND_PCT_OUTER;
			local roll = Map.Rand(100, "");
			plotTypes[y * params.iW + x] = (roll < CONFIG.OUTER_TILE_APPEAR_PCT and Map.Rand(100, "") < landPct) and PlotTypes.PLOT_LAND or PlotTypes.PLOT_OCEAN;
		end
	end
	return true;
end
