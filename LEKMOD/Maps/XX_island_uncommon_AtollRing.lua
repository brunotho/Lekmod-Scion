-- Atoll ring: 4-6 tiny islets (mostly 1 tile, sometimes 2) spaced around a hex ring of radius 2-3 with an
-- open water centre. The whole ring is planned before painting: the islet walk starts on a ring tile that sits
-- exactly one water tile off the coast, so the nearest islet always has a one-tile gap; the rest curves away.

include("X_IslandHelpers");

local CONFIG = {
	RADIUS3_PCT = 40,                  -- ring radius 3 instead of 2
	ISLETS_MIN = 4, ISLETS_RANGE = 2,  -- 4..6 islets
	TWO_TILE_PCT = 25,                 -- islet covers two consecutive ring tiles
	GAP2_PCT = 35,                     -- two water tiles between islets instead of one
	HILLS_PCT = 35,
	SHORE_DIST = 2,                    -- nearest ring tile's distance to land (2 = one water tile between)
};

local function isLand(plotTypes, x, y, iW)
	local t = plotTypes[y * iW + x + 1];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

function TryPlaceAtollRingIsland(plotTypes, centerX, centerY, islLandInRing, params)
	if params.nearPangea == false then return false; end
	local iW, iH = params.iW, params.iH;
	local wrapX, wrapY = params.wrapX, params.wrapY;
	local cx = WrapCoord(centerX, iW, wrapX);
	local cy = WrapCoord(centerY, iH, wrapY);
	if cx < 0 or cx >= iW then return false; end

	local R = (Map.Rand(100, "atollRadius") < CONFIG.RADIUS3_PCT) and 3 or 2;
	-- Seed = ring centre; nearest land at R + SHORE_DIST puts the ring's near side one water tile off.
	if islLandInRing ~= R + CONFIG.SHORE_DIST then return false; end
	if cy - R < 3 or cy + R > iH - 4 then return false; end

	-- Whole disk must be open water with no land touching the ring.
	for _, t in ipairs(GetHexDisk(cx, cy, R + 1, iW, iH, wrapX, wrapY)) do
		if isLand(plotTypes, t[1], t[2], iW) then return false; end
	end
	local ring = GetHexRingAtRadius(cx, cy, R, iW, iH, wrapX, wrapY);  -- tiles in walking order
	local n = #ring;
	if n < 6 * R then return false; end

	-- Anchor: ring tiles with land exactly SHORE_DIST away (none closer: the R+1 disk is clear). The walk
	-- starts there, so the first islet is the one hugging the coast.
	local anchors = {};
	for idx, t in ipairs(ring) do
		for _, u in ipairs(GetHexRingAtRadius(t[1], t[2], CONFIG.SHORE_DIST, iW, iH, wrapX, wrapY)) do
			if isLand(plotTypes, u[1], u[2], iW) then anchors[#anchors + 1] = idx - 1; break; end
		end
	end
	if #anchors == 0 then return false; end

	-- Walk the ring from the anchor: islet (1-2 tiles), gap (1-2 tiles), repeat.
	local want = CONFIG.ISLETS_MIN + Map.Rand(CONFIG.ISLETS_RANGE + 1, "atollCount");
	local start = anchors[1 + Map.Rand(#anchors, "atollStart")];
	local islets = {};
	local i = 0;
	while #islets < want and i < n do
		local len = (Map.Rand(100, "atollTwo") < CONFIG.TWO_TILE_PCT) and 2 or 1;
		local gap = (Map.Rand(100, "atollGap") < CONFIG.GAP2_PCT) and 2 or 1;
		-- Leave at least one water tile before wrapping back to the first islet.
		if i + len + 1 > n then break; end
		local islet = {};
		for j = 0, len - 1 do
			islet[#islet + 1] = ring[((start + i + j) % n) + 1];
		end
		islets[#islets + 1] = islet;
		i = i + len + gap;
	end
	if #islets < CONFIG.ISLETS_MIN then return false; end

	for _, islet in ipairs(islets) do
		for _, t in ipairs(islet) do
			plotTypes[t[2] * iW + t[1] + 1] = (Map.Rand(100, "atollHills") < CONFIG.HILLS_PCT)
				and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
	return true, cx, cy;
end
