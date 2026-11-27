-- Narrow mountain spine (single file) with sin-smoothed hex turns; one flanking hills/land band for a natural ridge vs a ruler-straight wall.

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

function TryPlaceMountainWallIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 0;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local baseDir = Map.Rand(6, "") + 1;
	local phase = Map.Rand(628, "mwallPhase") / 100;
	local amp = 0.75 + Map.Rand(40, "mwallAmp") / 100;
	local freq = 0.55 + Map.Rand(30, "mwallFreq") / 100;
	local ridgeLen = 4 + Map.Rand(5, "mwallLen");
	local gapPos = (ridgeLen >= 6 and Map.Rand(100, "") < 55) and (2 + Map.Rand(ridgeLen - 3, "mwallGap")) or nil;

	local spine = {};
	local flank = {};
	local used = {};

	local function markFlank(px, py)
		if px < 0 or px >= params.iW or py < 0 or py >= params.iH then return; end
		local k = px .. "," .. py;
		if used[k] then return; end
		used[k] = true;
		flank[#flank + 1] = { px, py };
	end

	local x, y = cx, cy;
	local walkDir = baseDir;
	for i = 1, ridgeLen do
		if i ~= gapPos then
			spine[#spine + 1] = { x, y };
		end
		local wobble = math.floor(amp * math.sin(i * freq + phase));
		if wobble > 0 then
			walkDir = rotDir(walkDir, 1);
		elseif wobble < 0 then
			walkDir = rotDir(walkDir, -1);
		end
		local perp = rotDir(walkDir, Map.Rand(2, "") == 0 and 2 or -2);
		local fx, fy = GetHexNeighbor(x, y, perp, params.iW, params.iH, params.wrapX, params.wrapY);
		if Map.Rand(100, "mwallFlank") < 78 then
			markFlank(fx, fy);
		end
		local nx, ny = GetHexNeighbor(x, y, walkDir, params.iW, params.iH, params.wrapX, params.wrapY);
		if nx < 0 or nx >= params.iW or ny < 0 or ny >= params.iH then break; end
		x, y = nx, ny;
	end

	if #spine < 3 then return false; end

	local all = {};
	for _, t in ipairs(spine) do
		all[#all + 1] = t;
	end
	for _, t in ipairs(flank) do
		all[#all + 1] = t;
	end
	if not footprintClear(plotTypes, all, params.iW, params.iH) then return false; end

	local ridgeSet = {};
	for _, t in ipairs(spine) do
		ridgeSet[t[1] .. "," .. t[2]] = true;
	end

	for _, t in ipairs(all) do
		local px, py = t[1], t[2];
		local idx = py * params.iW + px + 1;
		if ridgeSet[px .. "," .. py] then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		else
			local roll = Map.Rand(100, "mwallFoot");
			plotTypes[idx] = (roll < 62) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
	return true;
end
