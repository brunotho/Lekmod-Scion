-- Drowned ridge: a mainland mountain range sinking into the sea. Starts at a coastal mountain (or hill) of the
-- mainland and continues its line outward as 3-4 islets that shrink (3, 2, 1 [, 1] tiles), each one water tile
-- from the next; the first islet sits one water tile off the anchor. Islet cores are mountains, the rest hills.

include("X_IslandHelpers");

local CONFIG = {
	ANCHOR_SEARCH = 4,        -- look for the coastal mainland mountain/hill within this many hexes of the seed
	FOURTH_ISLET_PCT = 30,    -- 3,2,1 -> 3,2,1,1
	WOBBLE_PCT = 30,          -- per water step: turn the ridge line by 60 degrees
	CORE_MOUNTAIN_PCT = { 100, 70, 45, 35 },  -- chance the islet's first tile is a mountain (by islet number)
	HILLS_PCT = 70,           -- other islet tiles: hills, else flat
};

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[y * iW + x + 1];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

-- Build the ridge from anchor (ax, ay) heading `dir`. Returns a list of islets (lists of {x, y}) or nil.
local function planRidge(plotTypes, ax, ay, dir, sizes, p)
	local iW, iH, wrapX, wrapY = p.iW, p.iH, p.wrapX, p.wrapY;
	local owner = {};      -- "x,y" -> islet number
	local islets = {};
	local x, y = ax, ay;
	local h = dir;
	local function step(d)
		local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
		if nx < 0 or nx >= iW or ny < 3 or ny >= iH - 3 then return false; end
		x, y = nx, ny;
		return true;
	end
	for n, size in ipairs(sizes) do
		-- One water tile before every islet (the first one: between anchor and islet).
		if n > 1 and Map.Rand(100, "drownedRidgeWobble") < CONFIG.WOBBLE_PCT then
			h = rotDir(h, (Map.Rand(2, "") == 0) and 1 or -1);
		end
		if not step(h) or isLand(plotTypes, x, y, iW, iH) then return nil; end
		local islet = {};
		for i = 1, math.min(size, 2) do
			if not step(h) then return nil; end
			islet[#islet + 1] = { x, y };
		end
		if size >= 3 then
			-- Third tile beside the second one, on a random flank, so the big islet is not a pure line.
			local last = islet[#islet];
			local fx, fy = GetHexNeighbor(last[1], last[2], rotDir(h, (Map.Rand(2, "") == 0) and 2 or -2), iW, iH, wrapX, wrapY);
			if fx < 0 or fx >= iW or fy < 3 or fy >= iH - 3 then return nil; end
			islet[#islet + 1] = { fx, fy };
		end
		for _, t in ipairs(islet) do
			local k = t[1] .. "," .. t[2];
			if owner[k] then return nil; end
			owner[k] = n;
		end
		islets[#islets + 1] = islet;
	end
	-- Every islet tile: water now, no existing land next to it, and no other islet next to it.
	for n, islet in ipairs(islets) do
		for _, t in ipairs(islet) do
			if isLand(plotTypes, t[1], t[2], iW, iH) then return nil; end
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(t[1], t[2], d, iW, iH, wrapX, wrapY);
				if isLand(plotTypes, nx, ny, iW, iH) then return nil; end
				local o = owner[nx .. "," .. ny];
				if o and o ~= n then return nil; end
			end
		end
	end
	return islets;
end

function TryPlaceDrownedRidgeIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 0;
	local effMin = params.effMin or 1;
	local effMax = params.effMax or 4;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local iW, iH, wrapX, wrapY = params.iW, params.iH, params.wrapX, params.wrapY;
	local cx = WrapCoord(centerX, iW, wrapX);
	local cy = WrapCoord(centerY, iH, wrapY);
	if cx < 0 or cx >= iW or cy < 0 or cy >= iH then return false; end

	-- Anchors: coastal mainland mountains near the seed (hills only when there is no mountain).
	local mountains, hills = {}, {};
	for _, t in ipairs(GetHexDisk(cx, cy, CONFIG.ANCHOR_SEARCH, iW, iH, wrapX, wrapY)) do
		local k = t[2] * iW + t[1] + 1;
		local pt = plotTypes[k];
		local main = (params.mainland == nil) or params.mainland[k];
		if main and (pt == PlotTypes.PLOT_MOUNTAIN or pt == PlotTypes.PLOT_HILLS) then
			local coastal = false;
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(t[1], t[2], d, iW, iH, wrapX, wrapY);
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH and not isLand(plotTypes, nx, ny, iW, iH) then coastal = true; break; end
			end
			if coastal then
				if pt == PlotTypes.PLOT_MOUNTAIN then mountains[#mountains + 1] = t; else hills[#hills + 1] = t; end
			end
		end
	end
	local anchors = (#mountains > 0) and mountains or hills;
	if #anchors == 0 then return false; end
	local anchor = anchors[1 + Map.Rand(#anchors, "drownedRidgeAnchor")];

	local sizes = { 3, 2, 1 };
	if Map.Rand(100, "drownedRidgeFourth") < CONFIG.FOURTH_ISLET_PCT then sizes[4] = 1; end

	-- Headings that leave the coast (first step is water); try them in random order.
	local dirs = {};
	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(anchor[1], anchor[2], d, iW, iH, wrapX, wrapY);
		if nx >= 0 and nx < iW and ny >= 0 and ny < iH and not isLand(plotTypes, nx, ny, iW, iH) then dirs[#dirs + 1] = d; end
	end
	for i = #dirs, 2, -1 do
		local j = 1 + Map.Rand(i, "drownedRidgeDirShuffle");
		dirs[i], dirs[j] = dirs[j], dirs[i];
	end
	local islets = nil;
	for _, d in ipairs(dirs) do
		islets = planRidge(plotTypes, anchor[1], anchor[2], d, sizes, params);
		if islets then break; end
	end
	if not islets then return false; end

	for n, islet in ipairs(islets) do
		local coreMtn = Map.Rand(100, "drownedRidgeCore") < (CONFIG.CORE_MOUNTAIN_PCT[n] or 35);
		for i, t in ipairs(islet) do
			local idx = t[2] * iW + t[1] + 1;
			if i == 1 and coreMtn then
				plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
			else
				plotTypes[idx] = (Map.Rand(100, "drownedRidgeHills") < CONFIG.HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
			end
		end
	end
	return true, islets[1][1][1], islets[1][1][2];
end
