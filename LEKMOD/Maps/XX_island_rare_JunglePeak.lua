-- Tropical volcano-style feature: central peak, caldera water, several small satellite islands around it.

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

local function isAdjacentToTile(ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay;
	local adj = (ay % 2 ~= 0) and firstRingYIsOdd or firstRingYIsEven;
	for d = 1, 6 do
		if adj[d][1] == dx and adj[d][2] == dy then return true; end
	end
	return false;
end

function TryPlaceJunglePeakIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if _island_placed and _island_placed.junglePeak then return false; end
	local pullBack = params.pullBack or 3;
	local effMin = params.effMin or 3;
	local effMax = params.effMax or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local disk = GetHexDisk(cx, cy, 4, params.iW, params.iH, params.wrapX, params.wrapY);
	local calderaTiles = {};
	local ring2Tiles = {};
	local ring3Tiles = {};
	local ring1End = 7;
	local ring2End = 19;
	local ring3End = 37;
	for i = 2, ring1End do calderaTiles[#calderaTiles + 1] = disk[i]; end
	for i = ring1End + 1, ring2End do ring2Tiles[#ring2Tiles + 1] = disk[i]; end
	for i = ring2End + 1, ring3End do ring3Tiles[#ring3Tiles + 1] = disk[i]; end

	local r2Count = #ring2Tiles;
	local r3Count = #ring3Tiles;
	local landTiles = {};
	local used = {};
	local r2lo = math.max(1, math.floor(r2Count * 0.60 + 0.5));
	local r2hi = math.min(r2Count - 1, math.floor(r2Count * 0.80 + 0.5));
	if r2hi < r2lo then r2hi = r2lo; end
	local targetR2 = r2lo + Map.Rand(r2hi - r2lo + 1, "");

	local seeds = {};
	for _, t in ipairs(ring2Tiles) do
		for _, c in ipairs(calderaTiles) do
			if isAdjacentToTile(t[1], t[2], c[1], c[2]) then
				seeds[#seeds + 1] = t;
				break;
			end
		end
	end
	for i = #seeds, 2, -1 do
		local j = 1 + Map.Rand(i, "");
		seeds[i], seeds[j] = seeds[j], seeds[i];
	end

	local filledR2 = {};
	local queue = {};
	for _, t in ipairs(seeds) do
		local k = t[2] * params.iW + t[1];
		if not used[k] then
			used[k] = true;
			filledR2[#filledR2 + 1] = t;
			queue[#queue + 1] = t;
		end
	end

	local qi = 1;
	while qi <= #queue and #filledR2 < targetR2 do
		local t = queue[qi];
		qi = qi + 1;
		for _, u in ipairs(ring2Tiles) do
			local ku = u[2] * params.iW + u[1];
			if not used[ku] and isAdjacentToTile(t[1], t[2], u[1], u[2]) then
				used[ku] = true;
				filledR2[#filledR2 + 1] = u;
				queue[#queue + 1] = u;
				if #filledR2 >= targetR2 then break; end
			end
		end
	end

	while #filledR2 < targetR2 do
		local cands = {};
		for _, u in ipairs(ring2Tiles) do
			local ku = u[2] * params.iW + u[1];
			if not used[ku] then
				for _, f in ipairs(filledR2) do
					if isAdjacentToTile(u[1], u[2], f[1], f[2]) then
						cands[#cands + 1] = u;
						break;
					end
				end
			end
		end
		if #cands == 0 then break; end
		local pick = cands[1 + Map.Rand(#cands, "")];
		local k = pick[2] * params.iW + pick[1];
		used[k] = true;
		filledR2[#filledR2 + 1] = pick;
	end

	local function ripOneRing2()
		if #filledR2 < 2 then
			return;
		end
		local rip = 1 + Map.Rand(#filledR2, "");
		local u = filledR2[rip];
		used[u[2] * params.iW + u[1]] = nil;
		table.remove(filledR2, rip);
	end
	if #filledR2 >= r2Count and r2Count > 1 then
		ripOneRing2();
	end
	if #filledR2 >= 4 then
		ripOneRing2();
	end

	local filledR3 = {};
	for _, t in ipairs(filledR2) do
		for _, u in ipairs(ring3Tiles) do
			local ku = u[2] * params.iW + u[1];
			if not used[ku] and isAdjacentToTile(t[1], t[2], u[1], u[2]) and Map.Rand(100, "") < 15 then
				used[ku] = true;
				filledR3[#filledR3 + 1] = u;
			end
		end
	end
	local capR3 = 2 + Map.Rand(3, "");
	capR3 = math.min(capR3, math.max(2, math.floor(r3Count * 0.22 + 0.5)));
	while #filledR3 > capR3 do
		local rip = 1 + Map.Rand(#filledR3, "");
		local u = filledR3[rip];
		used[u[2] * params.iW + u[1]] = nil;
		table.remove(filledR3, rip);
	end

	for _, t in ipairs(filledR2) do
		landTiles[#landTiles + 1] = {t[1], t[2], "r2"};
	end
	for _, t in ipairs(filledR3) do
		landTiles[#landTiles + 1] = {t[1], t[2], "r3"};
	end

	local footprintTiles = {{cx, cy}};
	for _, t in ipairs(calderaTiles) do footprintTiles[#footprintTiles + 1] = t; end
	for _, t in ipairs(landTiles) do footprintTiles[#footprintTiles + 1] = {t[1], t[2]}; end
	if not footprintClear(plotTypes, footprintTiles, params.iW, params.iH) then return false; end

	DrawJunglePeakIsland(plotTypes, landTiles, calderaTiles, cx, cy, params.iW, params.iH);
	if Map.Rand(2, "") == 0 then
		_krakatoa_island_plot = plotIdx1(cx, cy, params.iW);
		_sri_pada_island_plot = nil;
	else
		-- Sri Pada goes on the central peak too (was cx-1 = a caldera water tile).
		_sri_pada_island_plot = plotIdx1(cx, cy, params.iW);
		_krakatoa_island_plot = nil;
	end
	if not _island_placed then _island_placed = {}; end
	_island_placed.junglePeak = true;
	return true;
end

function DrawJunglePeakIsland(plotTypes, landTiles, calderaTiles, cx, cy, iW, iH)
	plotTypes[cy * iW + cx + 1] = PlotTypes.PLOT_MOUNTAIN;
	for _, t in ipairs(calderaTiles) do
		plotTypes[t[2] * iW + t[1] + 1] = PlotTypes.PLOT_OCEAN;
	end
	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		local adjCaldera = false;
		for _, c in ipairs(calderaTiles) do
			if isAdjacentToTile(x, y, c[1], c[2]) then adjCaldera = true; break; end
		end
		local plotType;
		if adjCaldera then
			plotType = (Map.Rand(100, "") < 6) and PlotTypes.PLOT_MOUNTAIN
				or ((Map.Rand(100, "") < (82 + Map.Rand(14, ""))) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND);
		else
			plotType = (Map.Rand(100, "") < (18 + Map.Rand(15, ""))) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
		plotTypes[idx] = plotType;
	end
end
