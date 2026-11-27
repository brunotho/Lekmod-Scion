-- Hotspot trail: a line of islands leading away from the coast, shrinking with distance
-- (e.g. 5, 3, 2, 1 tiles; Hawaii-like). The first island may carry a volcanic peak. Every island keeps
-- at least one water tile to the mainland and to its neighbours in the trail.

include("X_IslandHelpers");

local CONFIG = {
	FIRST_SIZE_MIN = 4, FIRST_SIZE_RANGE = 3,  -- 4..6 tiles
	SIZES_AFTER = { 3, 2, 1 },                 -- islands 2..4
	FIFTH_ISLAND_PCT = 30,                      -- extra 1-tile islet at the far end
	MIN_ISLANDS = 3,
	MAX_ADVANCE_STEPS = 5,                      -- steps searched for the next island's anchor
	BEND_PCT = 25,                              -- chance per island to bend the trail by 60 degrees
	VOLCANO_PCT = 45,                           -- first island centre becomes a mountain
	HILLS_PCT = 55,
	EDGE_ROWS = 3,                              -- keep clear of the polar rows
};

local function pidx(x, y, iW) return y * iW + x + 1; end

local function isLand(plotTypes, x, y, iW)
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

function TryPlaceHotspotTrail(plotTypes, centerX, centerY, islLandInRing, params)
	if params.nearPangea == false then return false; end
	local pullBack = params.pullBack or 0;
	local effMin = params.effMin or 3;
	local effMax = params.effMax or 5;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local iW, iH = params.iW, params.iH;
	local wrapX, wrapY = params.wrapX, params.wrapY;
	local lx, ly = params.landX, params.landY;
	if type(lx) ~= "number" or type(ly) ~= "number" then return false; end
	local cx = WrapCoord(centerX, iW, wrapX);
	local cy = WrapCoord(centerY, iH, wrapY);
	local function inRows(y) return y >= CONFIG.EDGE_ROWS and y < iH - CONFIG.EDGE_ROWS; end
	if cx < 0 or cx >= iW or not inRows(cy) then return false; end
	if isLand(plotTypes, cx, cy, iW) then return false; end

	local function distLand(x, y) return Map.PlotDistance(lx, ly, x, y); end
	-- Free = in bounds, ocean, and no land neighbour except tiles of the island being grown (`own`).
	local function free(x, y, own)
		if x < 0 or x >= iW or not inRows(y) then return false; end
		if isLand(plotTypes, x, y, iW) then return false; end
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(plotTypes, nx, ny, iW)
				and not (own and own[ny * iW + nx]) then
				return false;
			end
		end
		return true;
	end

	-- Trail direction: a hex direction that steps away from the coast point.
	local function awayDirs(x, y)
		local out = {};
		local d0 = distLand(x, y);
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and distLand(nx, ny) > d0 then
				out[#out + 1] = d;
			end
		end
		return out;
	end
	local dirs = awayDirs(cx, cy);
	if #dirs == 0 then return false; end
	local dir = dirs[1 + Map.Rand(#dirs, "hotspot_dir")];

	local written = {};
	local function paint(x, y, t)
		local i = pidx(x, y, iW);
		if written[i] == nil then written[i] = plotTypes[i]; end
		plotTypes[i] = t;
	end
	local function revert()
		for i, t in pairs(written) do plotTypes[i] = t; end
	end

	-- Grow one compact island of `size` tiles from an anchor, preferring tiles further from the coast.
	local function growIsland(ax, ay, size)
		if not free(ax, ay, nil) then return nil; end
		local tiles = { { ax, ay } };
		local own = { [ay * iW + ax] = true };
		while #tiles < size do
			local cands = {};
			for _, t in ipairs(tiles) do
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(t[1], t[2], d, iW, iH, wrapX, wrapY);
					local nk = ny * iW + nx;
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and not own[nk] then
						own[nk] = true; -- tentatively, so free() ignores it as a neighbour
						local ok = free(nx, ny, own);
						own[nk] = nil;
						if ok then
							local w = (distLand(nx, ny) >= distLand(ax, ay)) and 3 or 1;
							cands[#cands + 1] = { nx, ny, w };
						end
					end
				end
			end
			if #cands == 0 then break; end
			local tot = 0;
			for _, c in ipairs(cands) do tot = tot + c[3]; end
			local r = Map.Rand(tot, "hotspot_grow");
			local pick = cands[#cands];
			for _, c in ipairs(cands) do
				r = r - c[3];
				if r < 0 then pick = c; break; end
			end
			tiles[#tiles + 1] = { pick[1], pick[2] };
			own[pick[2] * iW + pick[1]] = true;
		end
		return tiles;
	end

	local sizes = { CONFIG.FIRST_SIZE_MIN + Map.Rand(CONFIG.FIRST_SIZE_RANGE, "hotspot_first") };
	for _, s in ipairs(CONFIG.SIZES_AFTER) do sizes[#sizes + 1] = s; end
	if Map.Rand(100, "hotspot_fifth") < CONFIG.FIFTH_ISLAND_PCT then sizes[#sizes + 1] = 1; end

	local placed = 0;
	local ax, ay = cx, cy;
	for i, size in ipairs(sizes) do
		local tiles = growIsland(ax, ay, size);
		if not tiles or (i == 1 and #tiles < 3) then break; end
		for j, t in ipairs(tiles) do
			local pt;
			if i == 1 and j == 1 and Map.Rand(100, "hotspot_volcano") < CONFIG.VOLCANO_PCT then
				pt = PlotTypes.PLOT_MOUNTAIN;
			else
				pt = (Map.Rand(100, "hotspot_hills") < CONFIG.HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
			end
			paint(t[1], t[2], pt);
		end
		placed = placed + 1;

		-- Next anchor: keep walking the trail direction until a tile is clear of all land (1+ water gap).
		if Map.Rand(100, "hotspot_bend") < CONFIG.BEND_PCT then
			local turn = (Map.Rand(2, "hotspot_bend_dir") == 0) and 1 or -1;
			local nd = ((dir - 1 + turn) % 6) + 1;
			local tx, ty = GetHexNeighbor(ax, ay, nd, iW, iH, wrapX, wrapY);
			if tx >= 0 and tx < iW and ty >= 0 and ty < iH and distLand(tx, ty) > distLand(ax, ay) then
				dir = nd;
			end
		end
		local nx, ny = ax, ay;
		local found = false;
		for _ = 1, CONFIG.MAX_ADVANCE_STEPS do
			nx, ny = GetHexNeighbor(nx, ny, dir, iW, iH, wrapX, wrapY);
			if nx < 0 or nx >= iW or ny < 0 or ny >= iH or not inRows(ny) then break; end
			if free(nx, ny, nil) then
				found = true;
				break;
			end
		end
		if not found then break; end
		ax, ay = nx, ny;
	end

	if placed < CONFIG.MIN_ISLANDS then
		revert();
		return false;
	end
	return true, cx, cy;
end
