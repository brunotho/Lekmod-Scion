include("X_IslandHelpers");

local function pidx(x, y, iW)
	return y * iW + x + 1;
end

local function isOcean(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then
		return false;
	end
	return plotTypes[pidx(x, y, iW)] == PlotTypes.PLOT_OCEAN;
end

local function randStdNormal()
	local u = (Map.Rand(999998, "") + 1) / 1000000;
	local v = (Map.Rand(999998, "") + 1) / 1000000;
	return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
end

local function pickCenterRow(iH)
	local lo = 12;
	local hi = 42;
	if hi > iH - 3 then
		hi = math.max(lo, iH - 3);
	end
	if lo > hi then
		lo = math.max(2, math.floor(iH / 2));
		hi = lo;
	end
	local c = 26 + randStdNormal() * 5;
	c = math.floor(c + 0.5);
	if c < lo then
		c = lo;
	end
	if c > hi then
		c = hi;
	end
	c = math.max(2, math.min(iH - 3, c));
	return c;
end

local function keyXY(x, y)
	return tostring(x) .. "," .. tostring(y);
end

local function maxOceanRunWrapRow(plotTypes, y, iW, iH)
	if y < 0 or y >= iH then
		return 0;
	end
	local best, run = 0, 0;
	for i = 1, 2 * iW do
		local x = (i - 1) % iW;
		if isOcean(plotTypes, x, y, iW, iH) then
			run = run + 1;
			if run > best then
				best = run;
			end
			if run >= iW then
				return iW;
			end
		else
			run = 0;
		end
	end
	return math.min(best, iW);
end

local function maxLandRunWrapRow(plotTypes, y, iW, iH)
	if y < 0 or y >= iH then
		return 0;
	end
	local best, run = 0, 0;
	for i = 1, 2 * iW do
		local x = (i - 1) % iW;
		if isOcean(plotTypes, x, y, iW, iH) then
			run = 0;
		else
			run = run + 1;
			if run > best then
				best = run;
			end
			if run >= iW then
				return iW;
			end
		end
	end
	return math.min(best, iW);
end

local function pangaeaNorthSouthSpan(plotTypes, iW, iH)
	local minRun = math.max(5, math.floor(iW * 0.09 + 0.5));
	local yMin, yMax = nil, nil;
	for y = 0, iH - 1 do
		if maxLandRunWrapRow(plotTypes, y, iW, iH) >= minRun then
			if yMin == nil then
				yMin = y;
			end
			yMax = y;
		end
	end
	return yMin, yMax;
end

local function pickYBandInPangaeaSpan(ySouth, yNorth, vSpan, jitterMax)
	local spanRows = yNorth - ySouth + 1;
	local inset = math.max(0, math.min(3, math.floor(spanRows * 0.04 + 0.5)));
	local loBound = ySouth + inset + jitterMax;
	local hiBound = yNorth - inset - vSpan + 1;
	if hiBound < loBound then
		inset = 0;
		loBound = ySouth + jitterMax;
		hiBound = yNorth - vSpan + 1;
	end
	if hiBound < loBound then
		local center = math.floor((ySouth + yNorth - vSpan + 1) / 2);
		loBound = math.max(ySouth, math.min(center, yNorth - vSpan + 1));
		hiBound = loBound;
	end
	local spanRand = hiBound - loBound + 1;
	if spanRand < 1 then
		spanRand = 1;
	end
	return loBound + Map.Rand(spanRand, ""), inset;
end

local function avgStraitTilesInBand(plotTypes, yLo, yHi, iW, iH)
	local sum, n = 0, 0;
	for y = yLo, yHi do
		if y >= 0 and y < iH then
			sum = sum + maxOceanRunWrapRow(plotTypes, y, iW, iH);
			n = n + 1;
		end
	end
	if n == 0 then
		return 0;
	end
	return sum / n;
end

local function straitBrushScale(avgStrait, iW)
	local narrowN = math.max(5, math.floor(iW * 0.11 + 0.5));
	local wideN = math.max(11, math.floor(iW * 0.34 + 0.5));
	if wideN <= narrowN then
		wideN = narrowN + 1;
	end
	local t = (avgStrait - narrowN) / (wideN - narrowN);
	if t < 0 then
		t = 0;
	elseif t > 1 then
		t = 1;
	end
	local BRIDGE_SCALE_MIN = 0.27;
	return 1 - (1 - BRIDGE_SCALE_MIN) * t;
end

local function horizontalGapsTryPercent(scale)
	local t = 7 + math.floor(47 * (1 - scale) + 0.5);
	if t < 4 then
		return 4;
	end
	if t > 72 then
		return 72;
	end
	return t;
end

local function applyOccasionalHorizontalGaps(tiles, minTiles, scale)
	if Map.Rand(100, "") >= horizontalGapsTryPercent(scale) then
		return tiles, false;
	end
	local w = {};
	for _, t in ipairs(tiles) do
		w[#w + 1] = { t[1], t[2] };
	end
	if #w <= minTiles + 2 then
		return tiles, false;
	end

	local changed = false;
	local g = 1 - scale;

	if Map.Rand(100, "") < math.min(88, math.floor(26 + 26 * g + 0.5)) then
		local byX = {};
		for _, t in ipairs(w) do
			local x = t[1];
			if not byX[x] then
				byX[x] = {};
			end
			table.insert(byX[x], t);
		end
		local xs = {};
		for x, col in pairs(byX) do
			if #col >= 1 and #col <= 5 then
				xs[#xs + 1] = x;
			end
		end
		if #xs > 0 then
			local gx = xs[1 + Map.Rand(#xs, "")];
			local col = byX[gx];
			if col and #w - #col >= minTiles then
				local drop = {};
				for _, c in ipairs(col) do
					drop[keyXY(c[1], c[2])] = true;
				end
				local nw = {};
				for _, t in ipairs(w) do
					if not drop[keyXY(t[1], t[2])] then
						nw[#nw + 1] = t;
					end
				end
				w = nw;
				changed = true;
			end
		end
	end

	if not changed and #w > minTiles + 1 and Map.Rand(100, "") < math.min(90, math.floor(40 + 24 * g + 0.5)) then
		table.remove(w, 1 + Map.Rand(#w, ""));
		changed = true;
	elseif changed and #w > minTiles + 1 and Map.Rand(100, "") < math.floor(15 + 20 * g + 0.5) then
		table.remove(w, 1 + Map.Rand(#w, ""));
	end

	if #w < minTiles then
		return tiles, false;
	end
	if not changed then
		return tiles, false;
	end
	return w, true;
end

function TryPlaceWrapSoftLandbridge(plotTypes, opts)
	if not opts.wrapX then
		return false;
	end
	local iW, iH = opts.iW, opts.iH;

	local vSpan = 2 + Map.Rand(2, "");
	local jitterMax = math.floor(vSpan / 2) + 1;
	local yPSouth, yPNorth = pangaeaNorthSouthSpan(plotTypes, iW, iH);
	local spanInset;
	local yLo;
	if yPSouth ~= nil and yPNorth ~= nil and yPNorth - yPSouth >= vSpan + jitterMax - 1 then
		yLo, spanInset = pickYBandInPangaeaSpan(yPSouth, yPNorth, vSpan, jitterMax);
	else
		spanInset = nil;
		local yMid = pickCenterRow(iH);
		yLo = yMid - Map.Rand(vSpan + 1, "") + 1;
		if yLo < 2 then
			yLo = 2;
		end
		if yLo + vSpan > iH - 3 then
			yLo = math.max(2, iH - 3 - vSpan);
		end
	end
	local jitter = Map.Rand(math.max(1, vSpan + 1), "");
	yLo = yLo - math.min(jitter, jitterMax);
	if spanInset ~= nil then
		if yLo < yPSouth + spanInset then
			yLo = yPSouth + spanInset;
		end
		local yHiAllowed = yPNorth - spanInset - vSpan + 1;
		if yLo > yHiAllowed then
			yLo = yHiAllowed;
		end
	else
		if yLo < 2 then
			yLo = 2;
		end
		if yLo + vSpan > iH - 3 then
			yLo = math.max(2, iH - 3 - vSpan);
		end
	end
	local yHi = math.min(iH - 1, yLo + vSpan - 1);

	local avgStrait = avgStraitTilesInBand(plotTypes, yLo, yHi, iW, iH);
	if avgStrait < 2.5 then
		return false;
	end
	local scale = straitBrushScale(avgStrait, iW);
	local reachScale = math.max(0.82, scale);
	local markExtra = math.min(16, math.floor((1 - scale) * 14 + 0.5));
	local pruneFloor = math.min(38, 22 + math.floor((1 - scale) * 18 + 0.5));
	local nWalk = math.max(4, math.floor((5 + Map.Rand(3, "")) * (0.55 + 0.45 * scale) + 0.5));
	local stepsCap = math.max(14, math.floor((24 + Map.Rand(40, "")) * reachScale + 0.5));
	local penRaw = 6 + Map.Rand(math.max(1, math.floor(iW * 0.38)), "");
	local minPen = math.max(10, math.floor(iW * 0.26 + 0.5));
	local maxPen = math.max(minPen, math.floor(penRaw * (0.68 + 0.32 * reachScale) + 0.5));
	local thickenIters = math.max(3, math.floor((11 + Map.Rand(20, "")) * scale + 0.5));
	local thickenP = math.max(12, math.floor(38 * scale + 0.5));
	local minTiles = (scale >= 0.52) and 8 or 6;

	local seen = {};

	local function clampYMap(yy)
		return math.max(0, math.min(iH - 1, yy));
	end

	local bandMidY = math.floor((yLo + yHi + 1) * 0.5);
	local envPhase = Map.Rand(628, "") * 0.01;
	local envFreq1 = 0.09 + Map.Rand(18, "") * 0.0045;
	local envFreq2 = 0.056 + Map.Rand(12, "") * 0.004;
	local envCenterAmp = math.max(2, math.floor((yHi - yLo + 2) * 0.45 + Map.Rand(3, "")));
	local envHalfWLo = math.max(1, math.floor(vSpan * 0.35 + 0.5));
	local envHalfWHi = math.max(envHalfWLo + 2, vSpan + 2 + Map.Rand(5, ""));

	local function envelopeCenterY(x)
		x = math.max(0, math.min(iW - 1, x));
		local w =
			math.sin(x * envFreq1 + envPhase) * 0.55
			+ math.sin(x * envFreq2 + envPhase * 1.7) * 0.45;
		return clampYMap(bandMidY + math.floor(w * envCenterAmp + 0.5));
	end

	local function envelopeHalfWidth(x)
		x = math.max(0, math.min(iW - 1, x));
		local u = (math.sin(x * 0.127 + envPhase * 0.3) + math.sin(x * 0.073 + envPhase * 0.8)) * 0.5;
		if u < -1 then
			u = -1;
		elseif u > 1 then
			u = 1;
		end
		u = (u + 1) * 0.5;
		return envHalfWLo + math.floor(u * (envHalfWHi - envHalfWLo) + 0.5);
	end

	local function envelopeAllowsMark(x, y)
		local cy = envelopeCenterY(x);
		local hw = envelopeHalfWidth(x);
		return math.abs(y - cy) <= hw;
	end

	local function jitterRowDelta()
		if Map.Rand(100, "") < 72 then
			return Map.Rand(3, "") - 1;
		end
		return Map.Rand(5, "") - 2;
	end

	local function rotateHeading60(heading)
		local turn = (Map.Rand(2, "") == 0) and 1 or -1;
		return ((heading - 1 + turn + 6) % 6) + 1;
	end

	local function tryMarkOcean(x, y, plotTypes)
		local keepP = 72 + Map.Rand(18, "") + markExtra;
		if keepP > 95 then
			keepP = 95;
		end
		if Map.Rand(100, "") >= keepP then
			return;
		end
		x = math.max(0, math.min(iW - 1, x));
		if y < 0 or y >= iH then
			return;
		end
		if not isOcean(plotTypes, x, y, iW, iH) then
			return;
		end
		if not envelopeAllowsMark(x, y) then
			return;
		end
		local k = keyXY(x, y);
		if seen[k] then
			return;
		end
		seen[k] = true;
	end

	local function walkFromLeft(plotTypes)
		for _w = 1, nWalk do
			local x, y = 0, yLo + Map.Rand(vSpan + 2, "") - 1;
			y = clampYMap(y);
			local heading = 2;
			local bendStep = 1 + Map.Rand(stepsCap, "");
			for _s = 1, stepsCap do
				if x >= maxPen and Map.Rand(100, "") > 12 then
					break;
				end
				if _s == bendStep then
					heading = rotateHeading60(heading);
				end
				tryMarkOcean(x, y, plotTypes);
				local stepped = false;
				if Map.Rand(100, "") < 36 then
					local nx, ny = GetHexNeighbor(x, y, heading, iW, iH, false, false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and nx >= x - 1 then
						x, y = nx, clampYMap(ny);
						stepped = true;
					end
				end
				if not stepped then
					local r = Map.Rand(100, "");
					if r < 40 then
						x = math.min(iW - 1, x + 1);
						if Map.Rand(100, "") < 64 then
							y = clampYMap(y + jitterRowDelta());
						end
					elseif r < 73 then
						x = math.min(iW - 1, x + 1);
					elseif r < 93 then
						y = clampYMap(y + jitterRowDelta());
					else
						local d = (Map.Rand(100, "") < 55) and heading or (1 + Map.Rand(6, ""));
						local nx, ny = GetHexNeighbor(x, y, d, iW, iH, false, false);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH and nx >= x - 1 then
							x, y = nx, clampYMap(ny);
						else
							x = math.min(iW - 1, x + 1);
							y = clampYMap(y + jitterRowDelta());
						end
					end
				end
			end
		end
	end

	local function walkFromRight(plotTypes)
		for _w = 1, nWalk do
			local x, y = iW - 1, yLo + Map.Rand(vSpan + 2, "") - 1;
			y = clampYMap(y);
			local heading = 5;
			local bendStep = 1 + Map.Rand(stepsCap, "");
			for _s = 1, stepsCap do
				if (iW - 1 - x) >= maxPen and Map.Rand(100, "") > 12 then
					break;
				end
				if _s == bendStep then
					heading = rotateHeading60(heading);
				end
				tryMarkOcean(x, y, plotTypes);
				local stepped = false;
				if Map.Rand(100, "") < 36 then
					local nx, ny = GetHexNeighbor(x, y, heading, iW, iH, false, false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and nx <= x + 1 then
						x, y = nx, clampYMap(ny);
						stepped = true;
					end
				end
				if not stepped then
					local r = Map.Rand(100, "");
					if r < 40 then
						x = math.max(0, x - 1);
						if Map.Rand(100, "") < 64 then
							y = clampYMap(y + jitterRowDelta());
						end
					elseif r < 73 then
						x = math.max(0, x - 1);
					elseif r < 93 then
						y = clampYMap(y + jitterRowDelta());
					else
						local d = (Map.Rand(100, "") < 55) and heading or (1 + Map.Rand(6, ""));
						local nx, ny = GetHexNeighbor(x, y, d, iW, iH, false, false);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH and nx <= x + 1 then
							x, y = nx, clampYMap(ny);
						else
							x = math.max(0, x - 1);
							y = clampYMap(y + jitterRowDelta());
						end
					end
				end
			end
		end
	end

	walkFromLeft(plotTypes);
	walkFromRight(plotTypes);

	local seeds = {};
	for k, _ in pairs(seen) do
		seeds[#seeds + 1] = k;
	end
	for _t = 1, thickenIters do
		if #seeds == 0 then
			break;
		end
		local sk = seeds[1 + Map.Rand(#seeds, "")];
		local sx, sy = sk:match("^([^,]+),([^,]+)$");
		sx, sy = tonumber(sx), tonumber(sy);
		if sx == nil then
			break;
		end
		local d = 1 + Map.Rand(6, "");
		local nx, ny = GetHexNeighbor(sx, sy, d, iW, iH, false, false);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
			if isOcean(plotTypes, nx, ny, iW, iH) and envelopeAllowsMark(nx, ny) and Map.Rand(100, "") < thickenP then
				local nk = keyXY(nx, ny);
				if not seen[nk] then
					seen[nk] = true;
					seeds[#seeds + 1] = nk;
				end
			end
		end
	end

	local tiles = {};
	for k, _ in pairs(seen) do
		local sx, sy = k:match("^([^,]+),([^,]+)$");
		sx, sy = tonumber(sx), tonumber(sy);
		if sx ~= nil then
			tiles[#tiles + 1] = { sx, sy };
		end
	end

	local kept = {};
	for _, t in ipairs(tiles) do
		if Map.Rand(100, "") >= pruneFloor then
			kept[#kept + 1] = t;
		end
	end
	tiles = kept;

	if #tiles < minTiles then
		return false;
	end

	local gapsApplied;
	tiles, gapsApplied = applyOccasionalHorizontalGaps(tiles, minTiles, scale);
	if #tiles < minTiles then
		return false;
	end

	if LekMapgenPrint then
		LekMapgenPrint("### WrapSoftLandbridge: avgStraitEst=" .. string.format("%.1f", avgStrait) .. " brushScale=" .. string.format("%.2f", scale) .. " waterGaps=" .. (gapsApplied and "on" or "off") .. " paintTiles=" .. tostring(#tiles));
	end

	for _, t in ipairs(tiles) do
		if not isOcean(plotTypes, t[1], t[2], iW, iH) then
			return false;
		end
	end

	for _, t in ipairs(tiles) do
		local idx = pidx(t[1], t[2], iW);
		local r = Map.Rand(100, "");
		-- flat and hills only, no mountains (user, 2026-10-27); later passes (ridges) skip these tiles too
		_lek_no_mountain_plots = _lek_no_mountain_plots or {};
		_lek_no_mountain_plots[idx - 1] = true;
		if r < 60 then
			plotTypes[idx] = PlotTypes.PLOT_HILLS;
		else
			plotTypes[idx] = PlotTypes.PLOT_LAND;
		end
	end

	return true, tiles[1][1], tiles[1][2];
end
