-- Pangaea bow: polar-arm style depth × width bands, but from an E/W ocean flank — seaward spine
-- with ~180° hex turns, one half-sine lateral bulge, splintered tiles, no mountains.

include("X_IslandHelpers");

local CONFIG = {
	DEPTH_MIN = 9,
	DEPTH_RANGE = 7,
	ARM_LEN_MIN = 2,
	ARM_LEN_RANGE = 5,
	WIDTH_FLOOR = 1,
	WIDTH_CAP_INLAND = 6,
	SPLINTER_SKIP_MIN = 38,
	SPLINTER_SKIP_RANGE = 28,
	FLAKE_PCT = 22,
	CURVE_AMP_MIN = 2,
	CURVE_AMP_RANGE = 2,
	TURN_STEPS = 3,
	THICKEN_TOWARD_FAR_PCT = 78,
	HILLS_PCT = 18,
}

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[y * iW + x];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

local function footprintClear(plotTypes, tiles, iW, iH)
	for _, t in ipairs(tiles) do
		if isLand(plotTypes, t[1], t[2], iW, iH) then return false; end
	end
	return true;
end

local function bestStepDirToward(ox, oy, lx, ly, iW, iH, wrapX, wrapY)
	local bestD, bestScore = 1, 1e9;
	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(ox, oy, d, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
			local dx, dy = lx - nx, ly - ny;
			local sc = dx * dx + dy * dy;
			if sc < bestScore then
				bestScore = sc;
				bestD = d;
			end
		end
	end
	return bestD;
end

local function stepDirNTimes(x, y, dir, n, iW, iH, wrapX, wrapY)
	local px, py = x, y;
	local dabs = math.abs(n);
	local stepDir = (n >= 0) and dir or rotDir(dir, 3);
	for _ = 1, dabs do
		px, py = GetHexNeighbor(px, py, stepDir, iW, iH, wrapX, wrapY);
	end
	return px, py;
end

local function widthAtDepth(d, maxDepth, armLen, thickenTowardFar)
	local t = (maxDepth > 1) and (d / (maxDepth - 1)) or 1;
	if not thickenTowardFar then
		t = 1 - t;
	end
	local w = math.max(CONFIG.WIDTH_FLOOR,
		math.floor(CONFIG.WIDTH_FLOOR + (armLen - CONFIG.WIDTH_FLOOR) * t + 0.001) + Map.Rand(2, "bowW") - 1);
	if d <= 1 and w == 1 and Map.Rand(100, "bowHead") < 72 then
		w = 2;
	end
	if w == 1 and Map.Rand(100, "bow1w") >= 8 then
		w = 2;
	end
	w = math.min(armLen + 2, w);
	if d >= 4 then
		w = math.min(CONFIG.WIDTH_CAP_INLAND, w);
	end
	return math.max(1, w);
end

function TryPlacePangaeaBowIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 0;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local lx = params.landX;
	local ly = params.landY;
	if lx == nil or ly == nil then return false; end

	local iW = params.iW;
	local iH = params.iH;
	local wrapX = params.wrapX;
	local wrapY = params.wrapY;

	local cx = WrapCoord(centerX, iW, wrapX);
	local cy = WrapCoord(centerY, iH, wrapY);
	if cx < 0 or cx >= iW or cy < 0 or cy >= iH then return false; end

	local towardLand = bestStepDirToward(cx, cy, lx, ly, iW, iH, wrapX, wrapY);
	if math.abs(lx - cx) < math.abs(ly - cy) then
		return false;
	end
	local seaDir = rotDir(towardLand, 3);

	local maxDepth = CONFIG.DEPTH_MIN + Map.Rand(CONFIG.DEPTH_RANGE, "bowDepth");
	local armLen = CONFIG.ARM_LEN_MIN + Map.Rand(CONFIG.ARM_LEN_RANGE, "bowArmLen");
	local thickenTowardFar = Map.Rand(100, "bowThicken") < CONFIG.THICKEN_TOWARD_FAR_PCT;
	local curveAmp = CONFIG.CURVE_AMP_MIN + Map.Rand(CONFIG.CURVE_AMP_RANGE, "bowAmp");
	local curveHand = (Map.Rand(2, "bowHand") == 0) and 1 or -1;
	local latDir = rotDir(seaDir, curveHand);

	local splinter = CONFIG.SPLINTER_SKIP_MIN + Map.Rand(CONFIG.SPLINTER_SKIP_RANGE, "bowSplinter");

	local turnAt = {};
	local nTurn = CONFIG.TURN_STEPS;
	for i = 1, nTurn do
		turnAt[i] = math.max(1, math.floor(maxDepth * i / (nTurn + 1)));
	end

	local tiles = {};
	local used = {};
	local function tryAdd(px, py)
		if px < 0 or px >= iW or py < 0 or py >= iH then return; end
		if isLand(plotTypes, px, py, iW, iH) then return; end
		local key = py * iW + px;
		if used[key] then return; end
		if Map.Rand(100, "bowSpine") < splinter then return; end
		used[key] = true;
		tiles[#tiles + 1] = { px, py };
	end

	local hx, hy = cx, cy;
	local walkDir = seaDir;
	local turnApplied = 0;

	for d = 0, maxDepth - 1 do
		local t = (maxDepth > 1) and (d / (maxDepth - 1)) or 0;
		local halfWave = math.sin(math.pi * t);
		local lateral = math.floor(curveAmp * halfWave + 0.0001);

		local wx, wy = stepDirNTimes(hx, hy, latDir, lateral, iW, iH, wrapX, wrapY);
		local wBand = widthAtDepth(d, maxDepth, armLen, thickenTowardFar);
		local spreadDir = rotDir(walkDir, -curveHand);

		for ww = 0, wBand - 1 do
			local px, py = stepDirNTimes(wx, wy, spreadDir, ww, iW, iH, wrapX, wrapY);
			tryAdd(px, py);
			if CONFIG.FLAKE_PCT > 0 and Map.Rand(100, "bowFlake") < CONFIG.FLAKE_PCT then
				local fd = rotDir(spreadDir, Map.Rand(2, "") == 0 and 1 or -1);
				local fx, fy = GetHexNeighbor(px, py, fd, iW, iH, wrapX, wrapY);
				tryAdd(fx, fy);
			end
		end

		if d < maxDepth - 1 then
			for ti = 1, nTurn do
				if d == turnAt[ti] and turnApplied < nTurn then
					walkDir = rotDir(walkDir, curveHand);
					turnApplied = turnApplied + 1;
				end
			end
			hx, hy = GetHexNeighbor(hx, hy, walkDir, iW, iH, wrapX, wrapY);
			if hx < 0 or hx >= iW or hy < 0 or hy >= iH then break; end
		end
	end

	if #tiles < 5 then return false; end
	if not footprintClear(plotTypes, tiles, iW, iH) then return false; end

	for _, t in ipairs(tiles) do
		local px, py = t[1], t[2];
		local idx = py * iW + px;
		plotTypes[idx] = (Map.Rand(100, "bowHill") < CONFIG.HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
	end
	return true;
end
