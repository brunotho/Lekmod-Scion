-- Two arms from the pangaea's east and west toward the north or south map edge, with ridges, sea gaps through the arms, optional join at the pole, and sometimes extra land in the enclosed sea.

include("X_IslandHelpers");

local CONFIG = {
	EMBRACE_ODDS = 100,

	ARM_COUNT_ODDS = { [1] = 5, [2] = 90, [3] = 5 },
	ARM_ANCHOR_INSET_MIN = 0, ARM_ANCHOR_INSET_MAX = 35,
	ARM_ANCHOR_JITTER_PCT = 15,

	ARM_WIDTH_MIN = 2, ARM_WIDTH_RANGE = 5,
	ARM_ONE_ARM_LEN_MIN = 5, ARM_ONE_ARM_LEN_RANGE = 3,
	ARM_ONE_ARM_WIDTH_MIN = 4,
	ARM_WIDTH_AT_PANGEA_MIN = 1,
	ARM_WIDTH_1_TILE_ALLOW_PCT = 5,
	ARM_WIDTH_MAX_INLAND = 6,
	EDGE_EXPAND_ROWS = 3,
	EDGE_EXPAND_PCT = 45,
	MERGE_GAP_THRESHOLD = 6,
	MERGE_GAP_THRESHOLD_FRAC = 0.24,
	MERGE_PCT = 18,
	PANGAEA_EDGE_SCAN_DEPTH_MAX = 25,
	MIN_PANGAEA_EDGE_SPAN_FRAC = 0.38,
	MIN_PANGAEA_EDGE_SPAN_CAP = 15,
	MIN_PANGAEA_EDGE_SPAN_FLOOR = 7,
	ARM_ANCHOR_SEPARATION_FRAC = 0.34,
	ARM_ANCHOR_SEPARATION_MIN = 3,
	ARM_ANCHOR_SEPARATION_CAP = 5,
	THICKEN_TOWARD_EDGE_PCT = 80,
	SOFTER_CURVE_PCT = 25,
	GENTLER_FREQ_PCT = 45,
	CURVE_FREQ_HIGH_MAX = 0.72,
	CURVE_AMP_HIGH_FREQ_BOOST = 1.22,
	CURVE_AMP_VARIATION_PCT = 12,
	ARM_OUTWARD_DRIFT_MAX = 1,   -- tiles an arm may bend away from the enclosed sea (toward the wrap seam)

	HILLS_PCT_MIN = 50,
	HILLS_PCT_ADJ = 80, HILLS_PCT_2ND = 65, HILLS_PCT_3RD = 50,
	COASTAL_FLAT_PCT = 90,
	COASTAL_THIN_WIDTH = 5,
	THIN_STRIP_HILLS_PCT = 70,
	RIDGE_WIDTH_THRESHOLD = 4,
	RIDGE_3_TILE_PCT = 35, RIDGE_4_TILE_PCT = 12,
	RIDGE_POSITIONS = 3,
	RIDGE_SECTION_COUNT = 4,
	RIDGE_RIFT_COUNT_MIN = 1, RIDGE_RIFT_COUNT_MAX = 3,
	RIDGE_RIFT_HEIGHT_MIN = 1, RIDGE_RIFT_HEIGHT_MAX = 1,
	RIDGE_RIFT_IS_WATER = true,
	RIDGE_RIFT_HILLS_PCT = 70,
	RIDGE_RIFT_CLUSTER_PCT = 35,
	RIDGE_RIFT_CLUSTER_BAND_ROWS = 4,
	RIDGE_RIFT_CLUSTER_NUM_PATHS = 2,
	RIDGE_RIFT_CLUSTER_PATH_TILES_MIN = 1, RIDGE_RIFT_CLUSTER_PATH_TILES_MAX = 2,
	HEAVY_RIDGE_PCT = 16,
	HEAVY_RIDGE_RIFT_COUNT_MIN = 4, HEAVY_RIDGE_RIFT_COUNT_MAX = 7,
	HEAVY_RIDGE_RIFT_HEIGHT = 1,
	SPLINTERED_RIDGE_PCT = 40,
	SPLINTERED_RIDGE_WIDTH_MIN = 3, SPLINTERED_RIDGE_WIDTH_MAX = 5,
	SPLINTERED_GAP_COUNT_MIN = 8, SPLINTERED_GAP_COUNT_MAX = 18,
	SPLINTERED_GAP_2_TILE_PCT = 40,
	RIDGE_THIN_EXPAND_ROWS = 2,
	RIDGE_THIN_EXPAND_PCT = 85,
	RIDGE_THIN_FORCE_AT = 5,
	ARM_STRAIGHT_FORCE_AT = 5,

	ARCTIC_FILL_EDGE_EXTEND_ROWS = 1,
	ARCTIC_FILL_8_ROW_PCT = 22,
	ARCTIC_FILL_8_ROW_DEPTH_MIN = 4, ARCTIC_FILL_8_ROW_DEPTH_MAX = 6,
	ARCTIC_FILL_DEPTH_MIN = 1, ARCTIC_FILL_DEPTH_MAX = 4,
	ARCTIC_FILL_EXTENDED_MAP_PCT = 8,
	ARCTIC_FILL_EXTENDED_BAND_FRAC = 0.08,
	ARCTIC_FILL_TILE_PCT = 28,
	ARCTIC_FILL_TILE_PCT_ROW_VAR = 15,
	ARCTIC_FILL_TILE_PCT_NEAR_EDGE = 56,
	ARCTIC_FILL_ADJACENT_PCT = 70,
	ARCTIC_FILL_ISOLATED_PCT = 6,
	ARCTIC_FILL_HILLS_PCT = 48,
	ARCTIC_FILL_HILLS_ROW_VAR = 16,
	ARCTIC_RIDGE_PCT = 22,
	ARCTIC_RIDGE_WIDTH_MIN = 2, ARCTIC_RIDGE_WIDTH_MAX = 4,

	ARM_RIDGE_MTN_PCT_NEAR_POLE = 68,
	ARM_RIDGE_INLAND_DEPTH_START = 10,
	ARM_RIDGE_MTN_PCT_INLAND_MIN = 22,
	ARM_RIDGE_MTN_INLAND_LERP_DEPTH = 12,
	ARM_RIDGE_MTN_PCT_THIN_ROW_MIN = 20,
	ARM_RIDGE_MTN_PCT_THIN_ROW_MAX = 30,

	GAP_POLICY = "always",
	GAP_OPTIONAL_PCT = 60,
	GAP_COUNT_MIN = 2, GAP_COUNT_MAX = 5,
	GAP_THICKNESS_MIN = 2, GAP_THICKNESS_MAX = 5,
	GAP_CUT_FULL_WIDTH = true,
	GAP_SPLINTER_PCT = 100,
	GAP_SPLINTER_STEP_PCT = 55,
	GAP_DIST_FROM_EDGE_MIN = 4, GAP_DIST_FROM_EDGE_MAX = 11,

	EXTENDED_INLAND_PCT = 4,
	EXTENDED_INLAND_DEPTH_BONUS_MIN = 2, EXTENDED_INLAND_DEPTH_BONUS_MAX = 5,
	EXTENDED_INLAND_WIDTH_MAX = 6,
	EXTENDED_INLAND_TILE_PCT = 20,
	EXTENDED_INLAND_MTN_PCT = 22, EXTENDED_INLAND_LAKE_PCT = 48,
};

local function pidx(x, y, iW) return y * iW + x + 1; end
local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function findPangeaExtentAtEdge(plotTypes, iW, iH, southEdge, scanDepth)
	local extent = { west = iW, east = -1, maxDistFromEdge = 0 };
	local edgeY = southEdge and 0 or (iH - 1);
	for x = 0, iW - 1 do
		for d = 0, scanDepth do
			local y = southEdge and d or (edgeY - d);
			if y >= 0 and y < iH and isLand(plotTypes, x, y, iW, iH) then
				if x < extent.west then extent.west = x; end
				if x > extent.east then extent.east = x; end
				if d > extent.maxDistFromEdge then extent.maxDistFromEdge = d; end
				break;
			end
		end
	end
	return extent;
end

local function drawPangaeaEmbrace(plotTypes, iW, iH, wrapX, wrapY)
	if wrapY then return false; end

	local southEdge = (Map.Rand(2, "") == 0);
	local edgeY = southEdge and 0 or (iH - 1);

	local scanDepth = math.min(CONFIG.PANGAEA_EDGE_SCAN_DEPTH_MAX, math.max(6, iH - 2));
	local extent = findPangeaExtentAtEdge(plotTypes, iW, iH, southEdge, scanDepth);

	local span = extent.east - extent.west;
	local minSpan = math.max(
		CONFIG.MIN_PANGAEA_EDGE_SPAN_FLOOR,
		math.min(CONFIG.MIN_PANGAEA_EDGE_SPAN_CAP, math.floor(iW * CONFIG.MIN_PANGAEA_EDGE_SPAN_FRAC + 0.001))
	);
	if span < minSpan then return false; end

	local armCount;
	do
		local total = 0;
		for n, w in pairs(CONFIG.ARM_COUNT_ODDS) do total = total + w; end
		local roll = Map.Rand(total, "");
		local acc = 0;
		for n = 1, 3 do
			local w = CONFIG.ARM_COUNT_ODDS[n] or 0;
			acc = acc + w;
			if roll < acc then armCount = n; break; end
		end
		armCount = armCount or 2;
	end

	local insetPct = CONFIG.ARM_ANCHOR_INSET_MIN + Map.Rand(CONFIG.ARM_ANCHOR_INSET_MAX - CONFIG.ARM_ANCHOR_INSET_MIN + 1, "");
	local jitterPct = CONFIG.ARM_ANCHOR_JITTER_PCT;
	local inset = math.floor(span * insetPct / 100);
	local jitterW = math.floor(span * (Map.Rand(jitterPct * 2 + 1, "") - jitterPct) / 100);
	local jitterE = math.floor(span * (Map.Rand(jitterPct * 2 + 1, "") - jitterPct) / 100);
	local westAnchor = extent.west + inset + jitterW;
	local eastAnchor = extent.east - inset + jitterE;
	local anchorSep = math.max(
		CONFIG.ARM_ANCHOR_SEPARATION_MIN,
		math.min(CONFIG.ARM_ANCHOR_SEPARATION_CAP, math.floor(span * CONFIG.ARM_ANCHOR_SEPARATION_FRAC + 0.001))
	);
	westAnchor = math.max(extent.west, math.min(westAnchor, extent.east - anchorSep));
	eastAnchor = math.min(extent.east, math.max(eastAnchor, extent.west + anchorSep));
	if westAnchor >= eastAnchor then return false; end

	local drawWest = (armCount == 1 and Map.Rand(2, "") == 0) or (armCount >= 2);
	local drawEast = (armCount == 1 and not drawWest) or (armCount >= 2);
	local drawCenter = (armCount == 3);

	local armLenW = drawWest and (CONFIG.ARM_WIDTH_MIN + Map.Rand(CONFIG.ARM_WIDTH_RANGE, "")) or 0;
	local armLenE = drawEast and (CONFIG.ARM_WIDTH_MIN + Map.Rand(CONFIG.ARM_WIDTH_RANGE, "")) or 0;
	local armLenC = drawCenter and (CONFIG.ARM_WIDTH_MIN + Map.Rand(CONFIG.ARM_WIDTH_RANGE, "")) or 0;
	if armCount == 1 then
		local oneMin = CONFIG.ARM_ONE_ARM_LEN_MIN or 5;
		local oneRange = CONFIG.ARM_ONE_ARM_LEN_RANGE or 3;
		if drawWest then armLenW = math.max(armLenW, oneMin + Map.Rand(oneRange, "1arm")); end
		if drawEast then armLenE = math.max(armLenE, oneMin + Map.Rand(oneRange, "1arm")); end
	end
	local centerAnchor = drawCenter and (westAnchor + math.floor((eastAnchor - westAnchor) / 2)) or westAnchor;

	local seaMinX = drawWest and (westAnchor + armLenW) or westAnchor;
	local seaMaxX = drawEast and (eastAnchor - armLenE) or eastAnchor;
	if drawCenter then
		seaMinX = math.min(seaMinX, centerAnchor - math.floor(armLenC / 2));
		seaMaxX = math.max(seaMaxX, centerAnchor + math.floor(armLenC / 2));
	end
	local gap = seaMaxX - seaMinX;
	if gap < 0 then return false; end
	local mergeGapMax = math.min(CONFIG.MERGE_GAP_THRESHOLD, math.max(4, math.floor(iW * (CONFIG.MERGE_GAP_THRESHOLD_FRAC or 0.24) + 0.001)));
	local mergeAtEdge = (armCount == 2 and gap <= mergeGapMax and Map.Rand(100, "") < CONFIG.MERGE_PCT);

	local embraceNarrow = (span > 0 and (gap <= math.floor(span * 0.5)));
	local extendedInland = embraceNarrow and (Map.Rand(100, "") < (CONFIG.EXTENDED_INLAND_PCT or 0));
	local traversibleCol = nil;
	if extendedInland and gap >= 2 then
		traversibleCol = seaMinX + Map.Rand(math.max(1, gap + 1), "");
		if wrapX then traversibleCol = ((traversibleCol % iW) + iW) % iW; end
	end

	local armDepth = extent.maxDistFromEdge + 1;
	if extendedInland then
		local bonus = CONFIG.EXTENDED_INLAND_DEPTH_BONUS_MIN + Map.Rand(CONFIG.EXTENDED_INLAND_DEPTH_BONUS_MAX - CONFIG.EXTENDED_INLAND_DEPTH_BONUS_MIN + 1, "");
		armDepth = math.min(CONFIG.EXTENDED_INLAND_WIDTH_MAX or 12, armDepth + bonus);
	end
	local armWidthW = drawWest and math.max(3, armDepth + Map.Rand(3, "")) or 0;
	local armWidthE = drawEast and math.max(3, armDepth + Map.Rand(3, "")) or 0;
	local armWidthC = drawCenter and math.max(3, armDepth + Map.Rand(3, "")) or 0;

	local curveAmp  = (Map.Rand(100, "") < CONFIG.SOFTER_CURVE_PCT) and (2.0 + Map.Rand(2, "") * 0.25) or (3.0 + Map.Rand(3, ""));
	local curveFreq = (Map.Rand(100, "") < CONFIG.GENTLER_FREQ_PCT) and (0.30 + Map.Rand(2, "") * 0.05) or (0.50 + Map.Rand(4, "") * 0.055);
	if curveFreq > (CONFIG.CURVE_FREQ_HIGH_MAX or 0.72) then curveFreq = CONFIG.CURVE_FREQ_HIGH_MAX; end
	if curveFreq > 0.55 then curveAmp = curveAmp * (CONFIG.CURVE_AMP_HIGH_FREQ_BOOST or 1.22); end
	local thickenBias = (Map.Rand(100, "") < CONFIG.THICKEN_TOWARD_EDGE_PCT) and 1 or 0;
	local edgeExpand = (Map.Rand(100, "") < CONFIG.EDGE_EXPAND_PCT);
	local v = CONFIG.CURVE_AMP_VARIATION_PCT / 100;
	local curveAmpW = curveAmp * (1 - v + Map.Rand(math.floor(v * 200) + 1, "") / 100);
	local curveAmpE = curveAmp * (1 - v + Map.Rand(math.floor(v * 200) + 1, "") / 100);
	local curveAmpC = drawCenter and (curveAmp * (1 - v + Map.Rand(math.floor(v * 200) + 1, "") / 100)) or 0;

	local westTiles = {};
	local eastTiles = {};
	local centerTiles = {};
	local allTilesSet = {};
	local maxDepth = math.max(armDepth, armWidthW or 0, armWidthE or 0, armWidthC or 0);

	local lastW, lastE, lastC = {}, {}, {};
	local function forceChangeIfStraight(last, w, minW, maxW)
		if #last < (CONFIG.ARM_STRAIGHT_FORCE_AT or 5) - 1 then return w; end
		local v = last[#last];
		for i = #last - 1, 1, -1 do if last[i] ~= v then return w; end end
		if w ~= v then return w; end
		local delta = (Map.Rand(2, "straight") == 0) and -1 or 1;
		return math.max(minW, math.min(maxW, w + delta));
	end

	for d = 0, maxDepth - 1 do
		local y = southEdge and d or (edgeY - d);
		if y < 0 or y >= iH then break; end
		local t = (maxDepth > 1) and (d / (maxDepth - 1)) or 1;
		if thickenBias == 0 then t = 1 - t; end
		local widthAtD_W = drawWest and math.max(CONFIG.ARM_WIDTH_AT_PANGEA_MIN, math.floor(CONFIG.ARM_WIDTH_AT_PANGEA_MIN + (armLenW - CONFIG.ARM_WIDTH_AT_PANGEA_MIN) * t) + Map.Rand(2, "") - 1) or 0;
		local widthAtD_E = drawEast and math.max(CONFIG.ARM_WIDTH_AT_PANGEA_MIN, math.floor(CONFIG.ARM_WIDTH_AT_PANGEA_MIN + (armLenE - CONFIG.ARM_WIDTH_AT_PANGEA_MIN) * t) + Map.Rand(2, "") - 1) or 0;
		local widthAtD_C = drawCenter and math.max(CONFIG.ARM_WIDTH_AT_PANGEA_MIN, math.floor(CONFIG.ARM_WIDTH_AT_PANGEA_MIN + (armLenC - CONFIG.ARM_WIDTH_AT_PANGEA_MIN) * t) + Map.Rand(2, "") - 1) or 0;
		if d == 0 then
			if drawWest  and widthAtD_W == 1 and Map.Rand(100, "armHead") < 70 then widthAtD_W = 2; end
			if drawEast  and widthAtD_E == 1 and Map.Rand(100, "armHead") < 70 then widthAtD_E = 2; end
			if drawCenter and widthAtD_C == 1 and Map.Rand(100, "armHead") < 70 then widthAtD_C = 2; end
		elseif d == 1 then
			if drawWest  and widthAtD_W == 1 and Map.Rand(100, "armHead") < 40 then widthAtD_W = 2; end
			if drawEast  and widthAtD_E == 1 and Map.Rand(100, "armHead") < 40 then widthAtD_E = 2; end
			if drawCenter and widthAtD_C == 1 and Map.Rand(100, "armHead") < 40 then widthAtD_C = 2; end
		end
		if widthAtD_W == 1 and Map.Rand(100, "arm1") >= (CONFIG.ARM_WIDTH_1_TILE_ALLOW_PCT or 5) then widthAtD_W = 2; end
		if widthAtD_E == 1 and Map.Rand(100, "arm1") >= (CONFIG.ARM_WIDTH_1_TILE_ALLOW_PCT or 5) then widthAtD_E = 2; end
		if widthAtD_C == 1 and Map.Rand(100, "arm1") >= (CONFIG.ARM_WIDTH_1_TILE_ALLOW_PCT or 5) then widthAtD_C = 2; end
		if edgeExpand and d >= maxDepth - CONFIG.EDGE_EXPAND_ROWS then
			if drawWest then widthAtD_W = armLenW + 1 + Map.Rand(2, ""); end
			if drawEast then widthAtD_E = armLenE + 1 + Map.Rand(2, ""); end
			if drawCenter then widthAtD_C = armLenC + 1 + Map.Rand(2, ""); end
		end
		widthAtD_W = math.min(armLenW + 3, widthAtD_W);
		widthAtD_E = math.min(armLenE + 3, widthAtD_E);
		widthAtD_C = math.min(armLenC + 3, widthAtD_C);
		if armCount == 1 then
			local oneW = CONFIG.ARM_ONE_ARM_WIDTH_MIN or 4;
			if drawWest then widthAtD_W = math.max(oneW, widthAtD_W); end
			if drawEast then widthAtD_E = math.max(oneW, widthAtD_E); end
		end
		if d >= 4 then
			local cap = extendedInland and (CONFIG.EXTENDED_INLAND_WIDTH_MAX or 12) or CONFIG.ARM_WIDTH_MAX_INLAND;
			widthAtD_W = math.min(cap, widthAtD_W);
			widthAtD_E = math.min(cap, widthAtD_E);
			widthAtD_C = math.min(cap, widthAtD_C);
		end
		local cap = (d >= 4) and (extendedInland and (CONFIG.EXTENDED_INLAND_WIDTH_MAX or 12) or CONFIG.ARM_WIDTH_MAX_INLAND) or 99;
		widthAtD_W = drawWest and forceChangeIfStraight(lastW, widthAtD_W, CONFIG.ARM_WIDTH_AT_PANGEA_MIN, math.min(armLenW + 3, cap)) or 0;
		widthAtD_E = drawEast and forceChangeIfStraight(lastE, widthAtD_E, CONFIG.ARM_WIDTH_AT_PANGEA_MIN, math.min(armLenE + 3, cap)) or 0;
		widthAtD_C = drawCenter and forceChangeIfStraight(lastC, widthAtD_C, CONFIG.ARM_WIDTH_AT_PANGEA_MIN, math.min(armLenC + 3, cap)) or 0;
		if drawWest then lastW[#lastW + 1] = widthAtD_W; if #lastW > (CONFIG.ARM_STRAIGHT_FORCE_AT or 5) then table.remove(lastW, 1); end end
		if drawEast then lastE[#lastE + 1] = widthAtD_E; if #lastE > (CONFIG.ARM_STRAIGHT_FORCE_AT or 5) then table.remove(lastE, 1); end end
		if drawCenter then lastC[#lastC + 1] = widthAtD_C; if #lastC > (CONFIG.ARM_STRAIGHT_FORCE_AT or 5) then table.remove(lastC, 1); end end

		if drawWest then
			for w = 0, widthAtD_W - 1 do
				local baseX = westAnchor + w;
				-- Outward drift (toward the wrap seam) capped at 1 tile; inward curve unchanged.
				local offW = math.max(-(CONFIG.ARM_OUTWARD_DRIFT_MAX or 1), math.floor(curveAmpW * math.sin(d * curveFreq)));
				local x = baseX + offW;
				if wrapX then x = ((x % iW) + iW) % iW; end
				if x < 0 or x >= iW then break; end
				if isLand(plotTypes, x, y, iW, iH) then break; end
				local key = y * iW + x;
				if not allTilesSet[key] then
					westTiles[#westTiles + 1] = {x, y};
					allTilesSet[key] = true;
				end
			end
		end

		if drawEast then
			for w = 0, widthAtD_E - 1 do
				local baseX = eastAnchor - w;
				local offE = math.max(-(CONFIG.ARM_OUTWARD_DRIFT_MAX or 1), math.floor(curveAmpE * math.sin(d * curveFreq)));
				local x = baseX - offE;
				if wrapX then x = ((x % iW) + iW) % iW; end
				if x < 0 or x >= iW then break; end
				if isLand(plotTypes, x, y, iW, iH) then break; end
				local key = y * iW + x;
				if not allTilesSet[key] then
					eastTiles[#eastTiles + 1] = {x, y};
					allTilesSet[key] = true;
				end
			end
		end

		if drawCenter then
			local loW = -math.floor(widthAtD_C / 2);
			local hiW = math.floor((widthAtD_C - 1) / 2);
			for w = loW, hiW do
				local baseX = centerAnchor + w;
				local x = baseX + math.floor(curveAmpC * math.sin(d * curveFreq));
				if wrapX then x = ((x % iW) + iW) % iW; end
				if x < 0 or x >= iW then break; end
				if isLand(plotTypes, x, y, iW, iH) then break; end
				local key = y * iW + x;
				if not allTilesSet[key] then
					centerTiles[#centerTiles + 1] = {x, y};
					allTilesSet[key] = true;
				end
			end
		end
	end

	if mergeAtEdge and gap > 0 then
		for d = math.max(0, maxDepth - CONFIG.EDGE_EXPAND_ROWS), maxDepth - 1 do
			local y = southEdge and d or (edgeY - d);
			if y < 0 or y >= iH then break; end
			for gx = seaMinX, seaMaxX do
				local gwx = wrapX and (((gx % iW) + iW) % iW) or gx;
				if gwx >= 0 and gwx < iW and not isLand(plotTypes, gwx, y, iW, iH) then
					local key = y * iW + gwx;
					if not allTilesSet[key] then
						westTiles[#westTiles + 1] = {gwx, y};
						allTilesSet[key] = true;
					end
				end
			end
		end
	end

	local westMinX, westMaxX = {}, {};
	local eastMinX, eastMaxX = {}, {};
	local centerMinX, centerMaxX = {}, {};
	for _, t in ipairs(westTiles) do
		local x, y = t[1], t[2];
		if not westMinX[y] or x < westMinX[y] then westMinX[y] = x; end
		if not westMaxX[y] or x > westMaxX[y] then westMaxX[y] = x; end
	end
	for _, t in ipairs(eastTiles) do
		local x, y = t[1], t[2];
		if not eastMinX[y] or x < eastMinX[y] then eastMinX[y] = x; end
		if not eastMaxX[y] or x > eastMaxX[y] then eastMaxX[y] = x; end
	end
	for _, t in ipairs(centerTiles) do
		local x, y = t[1], t[2];
		if not centerMinX[y] or x < centerMinX[y] then centerMinX[y] = x; end
		if not centerMaxX[y] or x > centerMaxX[y] then centerMaxX[y] = x; end
	end
	if not drawEast then
		for y in pairs(westMaxX) do
			for x = westMaxX[y] + 1, extent.east do
				if isLand(plotTypes, x, y, iW, iH) then eastMinX[y] = x; break; end
			end
		end
	end
	if not drawWest then
		for y in pairs(eastMinX) do
			for x = eastMinX[y] - 1, extent.west, -1 do
				if isLand(plotTypes, x, y, iW, iH) then westMaxX[y] = x; break; end
			end
		end
	end

	local arcticTiles = {};
	local use8RowFill = embraceNarrow and (Map.Rand(100, "") < (CONFIG.ARCTIC_FILL_8_ROW_PCT or 0));
	local maxRow = (maxDepth >= 9) and 6 or (maxDepth >= 7) and 5 or 4;
	if use8RowFill then
		maxRow = math.min(maxDepth, 8);
	else
		maxRow = math.min(maxDepth, maxRow + (CONFIG.ARCTIC_FILL_EDGE_EXTEND_ROWS or 0));
	end
	if extendedInland then maxRow = math.min(maxDepth, 12); end
	local hasExtended = (Map.Rand(100, "") < CONFIG.ARCTIC_FILL_EXTENDED_MAP_PCT);
	local extXLo, extXHi = nil, nil;
	if hasExtended then
		local gapWidth, sampleW, sampleE = 0, nil, nil;
		for ry = 0, 5 do
			local y = southEdge and ry or (iH - 1 - ry);
			if y >= 0 and y < iH then
				local w, e = westMaxX[y], eastMinX[y];
				if w and e and w + 1 < e then
					gapWidth = math.max(gapWidth, e - w - 1);
					sampleW, sampleE = w, e;
				end
			end
		end
		if sampleW and sampleE and gapWidth >= 2 then
			local bandW = math.max(2, math.floor(gapWidth * CONFIG.ARCTIC_FILL_EXTENDED_BAND_FRAC));
			extXLo = sampleW + 1 + Map.Rand(math.max(1, (sampleE - sampleW - 1) - bandW), "");
			extXHi = extXLo + bandW - 1;
			maxRow = 6;
		end
	end
	local depthByX = {};
	local y0 = southEdge and 0 or (iH - 1);
	local y1 = southEdge and math.min(maxRow, iH - 1) or math.max(0, (iH - 1) - maxRow);
	local dy = southEdge and 1 or -1;
	for y = y0, y1, dy do
		local wMax, eMin = westMaxX[y], eastMinX[y];
		if wMax and eMin and wMax + 1 < eMin then
			local distFromEdge = southEdge and y or ((iH - 1) - y);
			local rowPct = (distFromEdge <= 2) and CONFIG.ARCTIC_FILL_TILE_PCT_NEAR_EDGE
				or (CONFIG.ARCTIC_FILL_TILE_PCT + (Map.Rand(CONFIG.ARCTIC_FILL_TILE_PCT_ROW_VAR * 2 + 1, "") - CONFIG.ARCTIC_FILL_TILE_PCT_ROW_VAR));
			local rowHills = CONFIG.ARCTIC_FILL_HILLS_PCT + (Map.Rand(CONFIG.ARCTIC_FILL_HILLS_ROW_VAR * 2 + 1, "") - CONFIG.ARCTIC_FILL_HILLS_ROW_VAR);
			rowHills = math.max(20, math.min(65, rowHills));
			local function tryFill(gx)
				if gx < 0 or gx >= iW or isLand(plotTypes, gx, y, iW, iH) then return; end
				if traversibleCol and gx == traversibleCol then return; end
				local useExtendedFill = extendedInland and distFromEdge >= 7;
				if not useExtendedFill then
					local depth = depthByX[gx];
					if not depth then
						if use8RowFill then
							depth = (CONFIG.ARCTIC_FILL_8_ROW_DEPTH_MIN or 6) + Map.Rand((CONFIG.ARCTIC_FILL_8_ROW_DEPTH_MAX or 8) - (CONFIG.ARCTIC_FILL_8_ROW_DEPTH_MIN or 6) + 1, "");
						elseif extXLo and gx >= extXLo and gx <= extXHi then
							depth = 6 + Map.Rand(2, "");
						else
							depth = CONFIG.ARCTIC_FILL_DEPTH_MIN + Map.Rand(CONFIG.ARCTIC_FILL_DEPTH_MAX - CONFIG.ARCTIC_FILL_DEPTH_MIN + 1, "");
						end
						depthByX[gx] = depth;
					end
					if distFromEdge >= depth then return; end
					if not use8RowFill and distFromEdge > 4 and not (extXLo and gx >= extXLo and gx <= extXHi) then return; end
				end
				if useExtendedFill and distFromEdge >= 5 then
					local centerX = seaMinX + math.floor((seaMaxX - seaMinX) / 2);
					local innerStart = 5;
					local relRow = math.max(0, distFromEdge - innerStart);
					local maxRel = math.max(1, maxRow - innerStart);
					local gapW = math.max(1, seaMaxX - seaMinX + 1);
					local maxHalf = math.max(1, math.floor(gapW * 0.25));
					local allowedHalf = math.min(maxHalf, math.floor(relRow * maxHalf / maxRel));
					if math.abs(gx - centerX) > allowedHalf then return; end
				end
				local adjCount = 0;
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(gx, y, d, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH and allTilesSet[ny * iW + nx] then
						adjCount = adjCount + 1;
					end
				end
				local pct;
				if useExtendedFill then
					pct = CONFIG.EXTENDED_INLAND_TILE_PCT or 42;
				elseif adjCount >= 1 then
					pct = (distFromEdge <= 2) and (CONFIG.ARCTIC_FILL_TILE_PCT_NEAR_EDGE or 78) or (CONFIG.ARCTIC_FILL_ADJACENT_PCT or 88);
				else
					pct = CONFIG.ARCTIC_FILL_ISOLATED_PCT or 12;
				end
				if Map.Rand(100, "") >= pct then return; end
				local key = y * iW + gx;
				if not allTilesSet[key] then
					allTilesSet[key] = true;
					local ptIdx = pidx(gx, y, iW);
					if useExtendedFill then
						local r = Map.Rand(100, "");
						if r < (CONFIG.EXTENDED_INLAND_MTN_PCT or 25) then
							plotTypes[ptIdx] = PlotTypes.PLOT_MOUNTAIN;
							arcticTiles[#arcticTiles + 1] = { gx, y };
						elseif r < (CONFIG.EXTENDED_INLAND_MTN_PCT or 25) + (CONFIG.EXTENDED_INLAND_LAKE_PCT or 30) then
							plotTypes[ptIdx] = PlotTypes.PLOT_OCEAN;
						else
							plotTypes[ptIdx] = (Map.Rand(100, "") < 55) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
							arcticTiles[#arcticTiles + 1] = { gx, y };
						end
					else
						arcticTiles[#arcticTiles + 1] = { gx, y };
						plotTypes[ptIdx] = (Map.Rand(100, "") < rowHills) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
					end
				end
			end
			if wMax < eMin then
				for x = wMax + 1, eMin - 1 do
					tryFill(wrapX and (((x % iW) + iW) % iW) or x);
				end
			elseif wrapX then
				for x = wMax + 1, iW - 1 do tryFill(x); end
				for x = 0, eMin - 1 do tryFill(x); end
			end
		end
	end

	if #arcticTiles > 0 then
		local rowInfo = {};
		local minY, maxY = iH, -1;
		for _, t in ipairs(arcticTiles) do
			local gx, gy = t[1], t[2];
			local info = rowInfo[gy];
			if not info then
				info = { minX = gx, maxX = gx };
				rowInfo[gy] = info;
			else
				if gx < info.minX then info.minX = gx; end
				if gx > info.maxX then info.maxX = gx; end
			end
			if gy < minY then minY = gy; end
			if gy > maxY then maxY = gy; end
		end
		if minY <= maxY then
			local edgeY = southEdge and minY or maxY;
			local farY  = southEdge and maxY or minY;
			local maxDepth = math.abs(farY - edgeY);
			local baseW = CONFIG.ARCTIC_RIDGE_WIDTH_MIN + Map.Rand(CONFIG.ARCTIC_RIDGE_WIDTH_MAX - CONFIG.ARCTIC_RIDGE_WIDTH_MIN + 1, "");
			if baseW < 1 then baseW = 1; end
			local edgeInfo = rowInfo[edgeY];
			if edgeInfo then
				local centerX = math.floor((edgeInfo.minX + edgeInfo.maxX) / 2);
				local gapCount = 1 + Map.Rand(2, "");
				local gapCols = {};
				for i = 1, gapCount do
					local dx = Map.Rand(3, "") - 1;
					gapCols[centerX + dx] = true;
				end

				local rowList = {};
				for y in pairs(rowInfo) do
					rowList[#rowList + 1] = y;
				end
				table.sort(rowList);

				for _, y in ipairs(rowList) do
					local info = rowInfo[y];
					local distFromEdge = southEdge and (y - edgeY) or (edgeY - y);
					if distFromEdge >= 0 then
						local depthFrac = (maxDepth > 0) and (1 - (distFromEdge / maxDepth)) or 1;
						if depthFrac < 0 then depthFrac = 0; end
						local rowW = math.max(1, math.floor(baseW * depthFrac + 0.5));
						local loX, hiX = info.minX, info.maxX;
						rowW = math.min(rowW, hiX - loX + 1);
						local cX = centerX;
						if cX < loX then cX = loX; elseif cX > hiX then cX = hiX; end
						local half = math.floor((rowW - 1) / 2);
						local ridgeLo = cX - half;
						local ridgeHi = ridgeLo + rowW - 1;
						if ridgeLo < loX then
							ridgeHi = ridgeHi + (loX - ridgeLo);
							ridgeLo = loX;
						end
						if ridgeHi > hiX then
							ridgeLo = ridgeLo - (ridgeHi - hiX);
							ridgeHi = hiX;
						end
						for gx = ridgeLo, ridgeHi do
							if not gapCols[gx] then
								local idx = pidx(gx, y, iW);
								if plotTypes[idx] ~= PlotTypes.PLOT_OCEAN then
									plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
								end
							end
						end
					end
				end
			end
		end
	end

	local ridgePosW = Map.Rand(CONFIG.RIDGE_POSITIONS, "");
	local ridgePosE = Map.Rand(CONFIG.RIDGE_POSITIONS, "");
	local ridgePosC = drawCenter and Map.Rand(CONFIG.RIDGE_POSITIONS, "") or 0;
	local splinteredRidge = (Map.Rand(100, "") < (CONFIG.SPLINTERED_RIDGE_PCT or 0));

	local function getRidgeWidth(w)
		local base = 2 + Map.Rand(2, "");
		local widthBias = (w >= 6 and Map.Rand(100, "") < 35) and 1 or 0;
		if w >= 8 and Map.Rand(100, "") < 18 then widthBias = widthBias + 1; end
		return math.min(w, base + widthBias);
	end

	local function buildRidgeWidthByRow(minXByY, maxXByY, useSplintered)
		local rwByY = {};
		local rowList = {};
		for y in pairs(minXByY) do
			if maxXByY[y] then
				rowList[#rowList + 1] = y;
			end
		end
		table.sort(rowList);
		local splinteredW = useSplintered and (CONFIG.SPLINTERED_RIDGE_WIDTH_MIN + Map.Rand(CONFIG.SPLINTERED_RIDGE_WIDTH_MAX - CONFIG.SPLINTERED_RIDGE_WIDTH_MIN + 1, "")) or nil;
		for _, y in ipairs(rowList) do
			local w = maxXByY[y] - minXByY[y] + 1;
			rwByY[y] = math.min(w, splinteredW or getRidgeWidth(w));
		end
		local thinCount = 0;
		for _, y in ipairs(rowList) do
			if rwByY[y] == 1 then
				thinCount = thinCount + 1;
				local w = maxXByY[y] - minXByY[y] + 1;
				if thinCount >= (CONFIG.RIDGE_THIN_FORCE_AT or 999) then
					rwByY[y] = math.min(w, 2);
					thinCount = 0;
				elseif thinCount >= CONFIG.RIDGE_THIN_EXPAND_ROWS and Map.Rand(100, "") < CONFIG.RIDGE_THIN_EXPAND_PCT then
					rwByY[y] = math.min(w, 2);
					thinCount = 0;
				end
			else
				thinCount = 0;
			end
		end
		return rwByY;
	end

	local ridgeWidthWest = buildRidgeWidthByRow(westMinX, westMaxX, splinteredRidge);
	local ridgeWidthEast = buildRidgeWidthByRow(eastMinX, eastMaxX, splinteredRidge);
	local ridgeWidthCenter = drawCenter and buildRidgeWidthByRow(centerMinX, centerMaxX, splinteredRidge) or {};

	local function isRidgeWest(x, y)
		local lo, hi = westMinX[y], westMaxX[y];
		if not lo then return false; end
		hi = hi or lo;
		local w = hi - lo + 1;
		local ridgeW = math.min(ridgeWidthWest[y] or 1, w);
		local start = (ridgePosW == 0) and lo or (ridgePosW == 1) and (lo + math.floor((w - ridgeW) / 2)) or (hi - ridgeW + 1);
		return x >= start and x < start + ridgeW;
	end
	local function isRidgeEast(x, y)
		local lo, hi = eastMinX[y], eastMaxX[y];
		if not hi then return false; end
		lo = lo or hi;
		local w = hi - lo + 1;
		local ridgeW = math.min(ridgeWidthEast[y] or 1, w);
		local start = (ridgePosE == 0) and (hi - ridgeW + 1) or (ridgePosE == 1) and (lo + math.floor((w - ridgeW) / 2)) or lo;
		return x >= start and x < start + ridgeW;
	end
	local function isRidgeCenter(x, y)
		if not drawCenter then return false; end
		local lo, hi = centerMinX[y], centerMaxX[y];
		if not lo then return false; end
		hi = hi or lo;
		local w = hi - lo + 1;
		local ridgeW = math.min(ridgeWidthCenter[y] or 1, w);
		local start = (ridgePosC == 0) and lo or (ridgePosC == 1) and (lo + math.floor((w - ridgeW) / 2)) or (hi - ridgeW + 1);
		return x >= start and x < start + ridgeW;
	end

	local ridgeSet = {};
	for _, t in ipairs(westTiles) do
		if isRidgeWest(t[1], t[2]) then ridgeSet[t[1] .. "," .. t[2]] = true; end
	end
	for _, t in ipairs(eastTiles) do
		if isRidgeEast(t[1], t[2]) then ridgeSet[t[1] .. "," .. t[2]] = true; end
	end
	for _, t in ipairs(centerTiles) do
		if isRidgeCenter(t[1], t[2]) then ridgeSet[t[1] .. "," .. t[2]] = true; end
	end

	local heavyRidge = (Map.Rand(100, "") < CONFIG.HEAVY_RIDGE_PCT);
	local riftCountMin = heavyRidge and CONFIG.HEAVY_RIDGE_RIFT_COUNT_MIN or CONFIG.RIDGE_RIFT_COUNT_MIN;
	local riftCountMax = heavyRidge and CONFIG.HEAVY_RIDGE_RIFT_COUNT_MAX or CONFIG.RIDGE_RIFT_COUNT_MAX;
	local riftHeightMin = heavyRidge and CONFIG.HEAVY_RIDGE_RIFT_HEIGHT or CONFIG.RIDGE_RIFT_HEIGHT_MIN;
	local riftHeightMax = heavyRidge and CONFIG.HEAVY_RIDGE_RIFT_HEIGHT or CONFIG.RIDGE_RIFT_HEIGHT_MAX;

	local function buildRiftRows(tiles)
		local rows = {};
		for _, t in ipairs(tiles) do rows[t[2]] = true; end
		local rowList = {};
		for y in pairs(rows) do rowList[#rowList + 1] = y; end
		table.sort(rowList);
		if #rowList < 2 then return {}, {}; end
		local riftRowSet = {};
		local riftClusterBands = {};
		local nSec = CONFIG.RIDGE_SECTION_COUNT;
		local secSize = math.max(1, math.floor(#rowList / nSec));
		local secWeights = {};
		for s = 1, nSec do
			secWeights[s] = 0.5 + Map.Rand(11, "") / 10;
		end
		local totalWeight = 0;
		for s = 1, nSec do totalWeight = totalWeight + secWeights[s]; end
		local numRifts = riftCountMin + Map.Rand(riftCountMax - riftCountMin + 1, "");
		numRifts = math.min(numRifts, math.max(1, #rowList - 1));
		local clusterCenter;
		if heavyRidge and #rowList >= 3 then
			clusterCenter = rowList[1 + Map.Rand(#rowList, "")];
		end
		local bandRows = CONFIG.RIDGE_RIFT_CLUSTER_BAND_ROWS;
		for _ = 1, numRifts do
			local y;
			if clusterCenter then
				local offset = Map.Rand(5, "") - 2;
				y = clusterCenter + offset;
				y = math.max(rowList[1], math.min(rowList[#rowList], y));
			else
				local r = Map.Rand(math.floor(totalWeight * 100), "") / 100;
				local acc = 0;
				local sec = 1;
				for s = 1, nSec do
					acc = acc + secWeights[s];
					if r < acc then sec = s; break; end
				end
				local loIdx = 1 + (sec - 1) * secSize;
				local hiIdx = (sec < nSec) and (sec * secSize) or #rowList;
				-- Map.Rand is 0..n-1, so no -1 here (was picking index 0 -> nil).
				local pickIdx = loIdx + Map.Rand(math.max(1, hiIdx - loIdx + 1), "");
				y = rowList[math.min(pickIdx, #rowList)];
			end
			y = math.max(rowList[1], math.min(rowList[#rowList], y));
			if Map.Rand(100, "") < CONFIG.RIDGE_RIFT_CLUSTER_PCT and (rowList[#rowList] - rowList[1] + 1) >= bandRows then
				local yMin = math.max(rowList[1], y);
				local yMax = math.min(rowList[#rowList], yMin + bandRows - 1);
				if yMax - yMin + 1 >= 3 then
					riftClusterBands[#riftClusterBands + 1] = { yMin = yMin, yMax = yMax };
				else
					riftRowSet[y] = true;
				end
			else
				local h = riftHeightMin + Map.Rand(riftHeightMax - riftHeightMin + 1, "");
				for dy = 0, h - 1 do
					riftRowSet[y + dy] = true;
				end
			end
		end
		return riftRowSet, riftClusterBands;
	end

	local function isInClusterBand(y, bands)
		for _, b in ipairs(bands) do
			if y >= b.yMin and y <= b.yMax then return true; end
		end
		return false;
	end

	local function buildRiftTileSet(tiles, riftClusterBands, isRidge)
		local riftTileSet = {};
		for _, band in ipairs(riftClusterBands) do
			local ridgeTiles = {};
			for _, t in ipairs(tiles) do
				if t[2] >= band.yMin and t[2] <= band.yMax and isRidge(t[1], t[2]) then
					ridgeTiles[#ridgeTiles + 1] = { t[1], t[2] };
				end
			end
			if #ridgeTiles >= 2 then
				local numPaths = CONFIG.RIDGE_RIFT_CLUSTER_NUM_PATHS;
				local pathTilesMin = CONFIG.RIDGE_RIFT_CLUSTER_PATH_TILES_MIN;
				local pathTilesMax = CONFIG.RIDGE_RIFT_CLUSTER_PATH_TILES_MAX;
				local used = {};
				for p = 1, numPaths do
					local n = pathTilesMin + Map.Rand(pathTilesMax - pathTilesMin + 1, "");
					local candidates = {};
					for i = 1, #ridgeTiles do
						local k = ridgeTiles[i][1] .. "," .. ridgeTiles[i][2];
						if not used[k] then candidates[#candidates + 1] = ridgeTiles[i]; end
					end
					if #candidates == 0 then break; end
					local idx = 1 + Map.Rand(#candidates, "");
					local seed = candidates[idx];
					riftTileSet[seed[1] .. "," .. seed[2]] = true;
					used[seed[1] .. "," .. seed[2]] = true;
					for _ = 2, n do
						local neighbors = {};
						for dir = 1, 6 do
							local nx, ny = GetHexNeighbor(seed[1], seed[2], dir, iW, iH, wrapX, wrapY);
							if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
								local nk = nx .. "," .. ny;
								if not used[nk] then
									for _, rt in ipairs(ridgeTiles) do
										if rt[1] == nx and rt[2] == ny then
											neighbors[#neighbors + 1] = { nx, ny };
											break;
										end
									end
								end
							end
						end
						if #neighbors == 0 then break; end
						local nb = neighbors[1 + Map.Rand(#neighbors, "")];
						riftTileSet[nb[1] .. "," .. nb[2]] = true;
						used[nb[1] .. "," .. nb[2]] = true;
						seed = nb;
					end
				end
			end
		end
		return riftTileSet;
	end

	local westRiftRows, westRiftClusterBands;
	local eastRiftRows, eastRiftClusterBands;
	local centerRiftRows, centerRiftClusterBands;
	if splinteredRidge then
		westRiftRows, westRiftClusterBands = {}, {};
		eastRiftRows, eastRiftClusterBands = {}, {};
		centerRiftRows, centerRiftClusterBands = {}, {};
	else
		westRiftRows, westRiftClusterBands = buildRiftRows(westTiles);
		eastRiftRows, eastRiftClusterBands = buildRiftRows(eastTiles);
		centerRiftRows, centerRiftClusterBands = drawCenter and buildRiftRows(centerTiles) or {}, {};
	end

	local function buildSplinteredGapTileSet(tiles, isRidge)
		local ridgeTiles = {};
		for _, t in ipairs(tiles) do
			if isRidge(t[1], t[2]) then ridgeTiles[#ridgeTiles + 1] = {t[1], t[2]}; end
		end
		if #ridgeTiles < 2 then return {}; end
		local gapMin = CONFIG.SPLINTERED_GAP_COUNT_MIN or 6;
		local gapMax = CONFIG.SPLINTERED_GAP_COUNT_MAX or 14;
		local numGaps = gapMin + Map.Rand(math.max(1, gapMax - gapMin + 1), "splinter");
		numGaps = math.min(numGaps, math.max(1, #ridgeTiles - 1));
		local riftTileSet = {};
		local used = {};
		for _ = 1, numGaps do
			local idx = 1 + Map.Rand(#ridgeTiles, "splinter");
			local t = ridgeTiles[idx];
			if not t then break; end
			local key = t[1] .. "," .. t[2];
			if not used[key] then
				riftTileSet[key] = true;
				used[key] = true;
				if Map.Rand(100, "") < CONFIG.SPLINTERED_GAP_2_TILE_PCT then
					for dir = 1, 6 do
						local nx, ny = GetHexNeighbor(t[1], t[2], dir, iW, iH, wrapX, wrapY);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
							local nk = nx .. "," .. ny;
							if not used[nk] then
								for _, rt in ipairs(ridgeTiles) do
									if rt[1] == nx and rt[2] == ny then
										riftTileSet[nk] = true;
										used[nk] = true;
										break;
									end
								end
								break;
							end
						end
					end
				end
			end
		end
		return riftTileSet;
	end

	local westRiftTileSet = splinteredRidge and buildSplinteredGapTileSet(westTiles, isRidgeWest) or buildRiftTileSet(westTiles, westRiftClusterBands, isRidgeWest);
	local eastRiftTileSet = splinteredRidge and buildSplinteredGapTileSet(eastTiles, isRidgeEast) or buildRiftTileSet(eastTiles, eastRiftClusterBands, isRidgeEast);
	local centerRiftTileSet = splinteredRidge and (drawCenter and buildSplinteredGapTileSet(centerTiles, isRidgeCenter) or {}) or (drawCenter and buildRiftTileSet(centerTiles, centerRiftClusterBands, isRidgeCenter) or {});

	local westRowSpan = {};
	for y, lo in pairs(westMinX) do
		local hi = westMaxX[y];
		if hi then
			westRowSpan[y] = hi - lo + 1;
		end
	end
	local eastRowSpan = {};
	for y, lo in pairs(eastMinX) do
		local hi = eastMaxX[y];
		if hi then
			eastRowSpan[y] = hi - lo + 1;
		end
	end
	local centerRowSpan = {};
	for y, lo in pairs(centerMinX) do
		local hi = centerMaxX[y];
		if hi then
			centerRowSpan[y] = hi - lo + 1;
		end
	end

	local function armDepthFromPolarEdge(tileY)
		if southEdge then
			return tileY;
		end
		return (iH - 1) - tileY;
	end

	local function armRidgeMountainPct(tileY)
		local d = armDepthFromPolarEdge(tileY);
		local d0 = CONFIG.ARM_RIDGE_INLAND_DEPTH_START or 10;
		if d < d0 then
			return CONFIG.ARM_RIDGE_MTN_PCT_NEAR_POLE or 68;
		end
		local span = math.max(1, CONFIG.ARM_RIDGE_MTN_INLAND_LERP_DEPTH or 12);
		local tt = (d - d0) / span;
		if tt > 1 then
			tt = 1;
		end
		local hi = CONFIG.ARM_RIDGE_MTN_PCT_NEAR_POLE or 68;
		local lo = CONFIG.ARM_RIDGE_MTN_PCT_INLAND_MIN or 22;
		return math.floor(hi * (1 - tt) + lo * tt + 0.5);
	end

	local function effectiveArmRidgeMountainPct(tileY, rowSpan)
		if rowSpan and rowSpan >= 1 and rowSpan <= 2 then
			local lo = CONFIG.ARM_RIDGE_MTN_PCT_THIN_ROW_MIN or 20;
			local hi = CONFIG.ARM_RIDGE_MTN_PCT_THIN_ROW_MAX or 30;
			return lo + Map.Rand(math.max(0, hi - lo) + 1, "thinArmMtn");
		end
		return armRidgeMountainPct(tileY);
	end

	local function armRidgeClusterHillsPct(tileY, rowSpan)
		local m = effectiveArmRidgeMountainPct(tileY, rowSpan);
		local norm = math.max(1, CONFIG.ARM_RIDGE_MTN_PCT_NEAR_POLE or 68);
		local clusterMtn = math.floor(18 * m / norm + 0.5);
		if clusterMtn < 5 then
			clusterMtn = 5;
		end
		if clusterMtn > 18 then
			clusterMtn = 18;
		end
		return 100 - clusterMtn;
	end

	for _, t in ipairs(westTiles) do
		local idx = pidx(t[1], t[2], iW);
		if isRidgeWest(t[1], t[2]) then
			local key = t[1] .. "," .. t[2];
			if westRiftTileSet[key] then
				plotTypes[idx] = CONFIG.RIDGE_RIFT_IS_WATER and PlotTypes.PLOT_OCEAN
					or ((Map.Rand(100, "") < CONFIG.RIDGE_RIFT_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND);
			elseif westRiftRows[t[2]] then
				plotTypes[idx] = CONFIG.RIDGE_RIFT_IS_WATER and PlotTypes.PLOT_OCEAN
					or ((Map.Rand(100, "") < CONFIG.RIDGE_RIFT_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND);
			elseif isInClusterBand(t[2], westRiftClusterBands) then
				plotTypes[idx] = (Map.Rand(100, "") < armRidgeClusterHillsPct(t[2], westRowSpan[t[2]])) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_MOUNTAIN;
			else
				plotTypes[idx] = (Map.Rand(100, "") < effectiveArmRidgeMountainPct(t[2], westRowSpan[t[2]])) and PlotTypes.PLOT_MOUNTAIN or PlotTypes.PLOT_HILLS;
			end
		end
	end
	for _, t in ipairs(eastTiles) do
		local idx = pidx(t[1], t[2], iW);
		if isRidgeEast(t[1], t[2]) then
			local key = t[1] .. "," .. t[2];
			if eastRiftTileSet[key] then
				plotTypes[idx] = CONFIG.RIDGE_RIFT_IS_WATER and PlotTypes.PLOT_OCEAN
					or ((Map.Rand(100, "") < CONFIG.RIDGE_RIFT_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND);
			elseif eastRiftRows[t[2]] then
				plotTypes[idx] = CONFIG.RIDGE_RIFT_IS_WATER and PlotTypes.PLOT_OCEAN
					or ((Map.Rand(100, "") < CONFIG.RIDGE_RIFT_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND);
			elseif isInClusterBand(t[2], eastRiftClusterBands) then
				plotTypes[idx] = (Map.Rand(100, "") < armRidgeClusterHillsPct(t[2], eastRowSpan[t[2]])) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_MOUNTAIN;
			else
				plotTypes[idx] = (Map.Rand(100, "") < effectiveArmRidgeMountainPct(t[2], eastRowSpan[t[2]])) and PlotTypes.PLOT_MOUNTAIN or PlotTypes.PLOT_HILLS;
			end
		end
	end
	for _, t in ipairs(centerTiles) do
		local idx = pidx(t[1], t[2], iW);
		if isRidgeCenter(t[1], t[2]) then
			local key = t[1] .. "," .. t[2];
			if centerRiftTileSet[key] then
				plotTypes[idx] = CONFIG.RIDGE_RIFT_IS_WATER and PlotTypes.PLOT_OCEAN
					or ((Map.Rand(100, "") < CONFIG.RIDGE_RIFT_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND);
			elseif centerRiftRows[t[2]] then
				plotTypes[idx] = CONFIG.RIDGE_RIFT_IS_WATER and PlotTypes.PLOT_OCEAN
					or ((Map.Rand(100, "") < CONFIG.RIDGE_RIFT_HILLS_PCT) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND);
			elseif isInClusterBand(t[2], centerRiftClusterBands) then
				plotTypes[idx] = (Map.Rand(100, "") < armRidgeClusterHillsPct(t[2], centerRowSpan[t[2]])) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_MOUNTAIN;
			else
				plotTypes[idx] = (Map.Rand(100, "") < effectiveArmRidgeMountainPct(t[2], centerRowSpan[t[2]])) and PlotTypes.PLOT_MOUNTAIN or PlotTypes.PLOT_HILLS;
			end
		end
	end

	local distToRidge = {};
	local queue = {};
	for k in pairs(ridgeSet) do
		local x, y = k:match("([^,]+),([^,]+)");
		x, y = tonumber(x), tonumber(y);
		distToRidge[k] = 0;
		queue[#queue + 1] = {x, y};
	end
	local q = 1;
	while q <= #queue do
		local x, y = queue[q][1], queue[q][2];
		local key = x .. "," .. y;
		local d = distToRidge[key] or 0;
		for dir = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and allTilesSet[ny * iW + nx] then
				local nk = nx .. "," .. ny;
				if distToRidge[nk] == nil then
					distToRidge[nk] = d + 1;
					queue[#queue + 1] = {nx, ny};
				end
			end
		end
		q = q + 1;
	end

	local function isCoastal(x, y)
		for dir = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				if not allTilesSet[ny * iW + nx] and plotTypes[pidx(nx, ny, iW)] == PlotTypes.PLOT_OCEAN then
					return true;
				end
			end
		end
		return false;
	end

	for _, t in ipairs(westTiles) do
		local idx = pidx(t[1], t[2], iW);
		if not isRidgeWest(t[1], t[2]) then
			local hillsPct = CONFIG.HILLS_PCT_3RD;
			local coastal = isCoastal(t[1], t[2]);
			if coastal then
				local w = westMinX[t[2]] and (westMaxX[t[2]] - westMinX[t[2]] + 1) or 0;
				if w >= CONFIG.COASTAL_THIN_WIDTH then
					hillsPct = 100 - CONFIG.COASTAL_FLAT_PCT;
				else
					hillsPct = math.max(CONFIG.HILLS_PCT_MIN, CONFIG.THIN_STRIP_HILLS_PCT);
				end
			else
				local d = distToRidge[t[1] .. "," .. t[2]];
				if d == 1 then hillsPct = CONFIG.HILLS_PCT_ADJ;
				elseif d == 2 then hillsPct = CONFIG.HILLS_PCT_2ND; end
				hillsPct = math.max(CONFIG.HILLS_PCT_MIN, hillsPct);
			end
			plotTypes[idx] = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
	for _, t in ipairs(eastTiles) do
		local idx = pidx(t[1], t[2], iW);
		if not isRidgeEast(t[1], t[2]) then
			local hillsPct = CONFIG.HILLS_PCT_3RD;
			local coastal = isCoastal(t[1], t[2]);
			if coastal then
				local w = eastMinX[t[2]] and (eastMaxX[t[2]] - eastMinX[t[2]] + 1) or 0;
				if w >= CONFIG.COASTAL_THIN_WIDTH then
					hillsPct = 100 - CONFIG.COASTAL_FLAT_PCT;
				else
					hillsPct = math.max(CONFIG.HILLS_PCT_MIN, CONFIG.THIN_STRIP_HILLS_PCT);
				end
			else
				local d = distToRidge[t[1] .. "," .. t[2]];
				if d == 1 then hillsPct = CONFIG.HILLS_PCT_ADJ;
				elseif d == 2 then hillsPct = CONFIG.HILLS_PCT_2ND; end
				hillsPct = math.max(CONFIG.HILLS_PCT_MIN, hillsPct);
			end
			plotTypes[idx] = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
	for _, t in ipairs(centerTiles) do
		local idx = pidx(t[1], t[2], iW);
		if not isRidgeCenter(t[1], t[2]) then
			local hillsPct = CONFIG.HILLS_PCT_3RD;
			local coastal = isCoastal(t[1], t[2]);
			if coastal then
				local w = centerMinX[t[2]] and (centerMaxX[t[2]] - centerMinX[t[2]] + 1) or 0;
				if w >= CONFIG.COASTAL_THIN_WIDTH then
					hillsPct = 100 - CONFIG.COASTAL_FLAT_PCT;
				else
					hillsPct = math.max(CONFIG.HILLS_PCT_MIN, CONFIG.THIN_STRIP_HILLS_PCT);
				end
			else
				local d = distToRidge[t[1] .. "," .. t[2]];
				if d == 1 then hillsPct = CONFIG.HILLS_PCT_ADJ;
				elseif d == 2 then hillsPct = CONFIG.HILLS_PCT_2ND; end
				hillsPct = math.max(CONFIG.HILLS_PCT_MIN, hillsPct);
			end
			plotTypes[idx] = (Map.Rand(100, "") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end

	local doGaps = (CONFIG.GAP_POLICY == "always") or
		(CONFIG.GAP_POLICY == "optional" and Map.Rand(100, "") < CONFIG.GAP_OPTIONAL_PCT);
	local numGaps = doGaps and (CONFIG.GAP_COUNT_MIN + Map.Rand(CONFIG.GAP_COUNT_MAX - CONFIG.GAP_COUNT_MIN + 1, "")) or 0;
	local distFromEdge = CONFIG.GAP_DIST_FROM_EDGE_MIN + Map.Rand(CONFIG.GAP_DIST_FROM_EDGE_MAX - CONFIG.GAP_DIST_FROM_EDGE_MIN + 1, "");
	distFromEdge = math.min(distFromEdge, math.max(0, maxDepth - 7));

	local function cutSplinteredPath(minXByY, maxXByY, y0, stepDir)
		local lo, hi = minXByY[y0], maxXByY[y0];
		if not lo or not hi then return; end
		local x0 = stepDir > 0 and lo or hi;
		local xEnd = stepDir > 0 and hi or lo;
		local py = y0;
		for x = x0, xEnd, stepDir do
			if minXByY[py] and x >= minXByY[py] and x <= maxXByY[py] then
				local wx = wrapX and (((x % iW) + iW) % iW) or x;
				if wx >= 0 and wx < iW then
					plotTypes[pidx(wx, py, iW)] = PlotTypes.PLOT_OCEAN;
				end
			end
			if Map.Rand(100, "") < CONFIG.GAP_SPLINTER_STEP_PCT then
				local ny = py + (Map.Rand(2, "") == 0 and 1 or -1);
				if minXByY[ny] and maxXByY[ny] and x >= minXByY[ny] and x <= maxXByY[ny] then
					py = ny;
				end
			end
		end
	end

	local function cutStraightRow(minXByY, maxXByY, y0)
		local lo, hi = minXByY[y0], maxXByY[y0];
		if lo and hi then
			for x = lo, hi do
				local wx = wrapX and (((x % iW) + iW) % iW) or x;
				if wx >= 0 and wx < iW then
					plotTypes[pidx(wx, y0, iW)] = PlotTypes.PLOT_OCEAN;
				end
			end
		end
	end

	for g = 1, numGaps do
		local d = southEdge and (maxDepth - 1 - distFromEdge - Map.Rand(2, "")) or (distFromEdge + Map.Rand(2, ""));
		d = math.max(0, math.min(maxDepth - 1, d));
		local y = southEdge and d or (edgeY - d);
		if y >= 0 and y < iH then
			local splinter = Map.Rand(100, "") < CONFIG.GAP_SPLINTER_PCT;
			if splinter then
				if drawWest then cutSplinteredPath(westMinX, westMaxX, y, 1); end
				if drawEast then cutSplinteredPath(eastMinX, eastMaxX, y, -1); end
				if drawCenter then cutSplinteredPath(centerMinX, centerMaxX, y, 1); end
			else
				if drawWest then cutStraightRow(westMinX, westMaxX, y); end
				if drawEast then cutStraightRow(eastMinX, eastMaxX, y); end
				if drawCenter then cutStraightRow(centerMinX, centerMaxX, y); end
			end
		end
	end

	_polar_merge_excluded_plots = _polar_merge_excluded_plots or {};
	for idx in pairs(allTilesSet) do
		local pt = plotTypes[idx + 1];
		if pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS or pt == PlotTypes.PLOT_MOUNTAIN then
			_polar_merge_excluded_plots[idx + 1] = true;
		end
	end

	return true, westAnchor, edgeY;
end

--[==[
local HILLS_ADJ = 75;
local TUNDRA_LAT = 0.85;

local function isWater(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	return plotTypes[y * iW + x + 1] == PlotTypes.PLOT_OCEAN;
end

local function getTundraLatitudeY(iH, southEdge)
	local offset = math.floor((iH / 2) * (1 - TUNDRA_LAT));
	if southEdge then return offset; end
	return iH - 1 - offset;
end

local function rippleToLand(plotTypes, startX, startY, iW, iH, wrapX, southEdge)
	local visited = {};
	local queue = {{startX, startY}};
	visited[startX .. "," .. startY] = true;
	local dist = 0;
	local maxDist = 15;
	while #queue > 0 and dist < maxDist do
		local next = {};
		for _, p in ipairs(queue) do
			local x, y = p[1], p[2];
			if isLand(plotTypes, x, y, iW, iH) then return dist, x, y; end
			for dir = 1, 6 do
				local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, false);
				if ny >= 0 and ny < iH then
					local inward = southEdge and (ny > y) or (ny < y);
					if inward then
						local key = nx .. "," .. ny;
						if not visited[key] then
							visited[key] = true;
							next[#next + 1] = {nx, ny};
						end
					end
				end
			end
		end
		queue = next;
		dist = dist + 1;
	end
	return nil, nil, nil;
end

local function findValidXForPangea(plotTypes, iW, iH, southEdge, maxScan)
	local validX = {};
	local edgeY = southEdge and 0 or (iH - 1);
	for x = 0, iW - 1 do
		for d = 1, math.min(maxScan, 12) do
			local y = southEdge and d or (edgeY - d);
			if y >= 0 and y < iH and isLand(plotTypes, x, y, iW, iH) then
				validX[#validX + 1] = x;
				break;
			end
		end
	end
	return validX;
end

local function drawArcticMerge(plotTypes, centerX, edgeY, southEdge, contactDist, startOffset, hasWaterPath, numRidges, iW, iH, wrapX, wrapY)
	local inlandSeaY = getTundraLatitudeY(iH, southEdge);
	local startY = southEdge and startOffset or (edgeY - startOffset);
	local endY = southEdge and math.min(contactDist + 2, iH - 1) or math.max(0, edgeY - contactDist - 2);

	local width = 8 + Map.Rand(5, "");
	local landTiles = {};
	local ridgeTiles = {};
	local waterPathTiles = {};
	local seaTiles = {};

	local splinterChance = 25;
	local ridge1Gaps = {};
	local ridge2Gaps = {};

	for row = 0, math.abs(endY - startY) do
		local rowY = southEdge and (startY + row) or (startY - row);
		if rowY < 0 or rowY >= iH then break; end
		local half = math.floor(width / 2);
		for dx = -half, half do
			local x = centerX + dx;
			if wrapX then x = ((x % iW) + iW) % iW; end
			if x >= 0 and x < iW then landTiles[#landTiles + 1] = {x, rowY}; end
		end
	end

	local landSet = {};
	for _, t in ipairs(landTiles) do landSet[t[1] .. "," .. t[2]] = true; end

	for row = 0, math.abs(endY - startY) do
		local rowY = southEdge and (startY + row) or (startY - row);
		if rowY < 0 or rowY >= iH then break; end
		local half = math.floor(width / 2);
		local vSpread = math.floor(half * 0.15 * (row + 1));
		local ridge1X = centerX - math.floor(half * 0.35) - vSpread;
		local ridge2X = centerX + math.floor(half * 0.35) + vSpread;
		if Map.Rand(100, "") < splinterChance then ridge1Gaps[row] = true; end
		if Map.Rand(100, "") < splinterChance then ridge2Gaps[row] = true; end
		if not ridge1Gaps[row] then
			local rx = wrapX and (((ridge1X % iW) + iW) % iW) or ridge1X;
			if rx >= 0 and rx < iW and landSet[rx .. "," .. rowY] then ridgeTiles[#ridgeTiles + 1] = {rx, rowY}; end
		end
		if numRidges >= 2 and not ridge2Gaps[row] then
			local rx = wrapX and (((ridge2X % iW) + iW) % iW) or ridge2X;
			if rx >= 0 and rx < iW and landSet[rx .. "," .. rowY] then ridgeTiles[#ridgeTiles + 1] = {rx, rowY}; end
		end
		if hasWaterPath then
			local pathX = wrapX and (((centerX % iW) + iW) % iW) or centerX;
			if pathX >= 0 and pathX < iW and landSet[pathX .. "," .. rowY] then waterPathTiles[#waterPathTiles + 1] = {pathX, rowY}; end
		end
	end

	local seaSize = 4 + Map.Rand(9, "");
	local seaRadius = math.max(1, math.floor(math.sqrt(seaSize / 3.14)));
	local seaCenterX = centerX;
	local yLo, yHi = math.min(startY, endY), math.max(startY, endY);
	local seaCenterY = math.max(yLo + 1, math.min(inlandSeaY, yHi - 1));
	if wrapX then seaCenterX = (((seaCenterX % iW) + iW) % iW); end

	for dy2 = -seaRadius, seaRadius do
		for dx2 = -seaRadius, seaRadius do
			if dx2 * dx2 + dy2 * dy2 <= seaRadius * seaRadius then
				local sx = seaCenterX + dx2;
				if wrapX then sx = (((sx % iW) + iW) % iW); end
				local sy = seaCenterY + dy2;
				if sx >= 0 and sx < iW and sy >= 0 and sy < iH and sy >= startY and (southEdge and sy <= endY or not southEdge and sy >= endY) then
					seaTiles[#seaTiles + 1] = {sx, sy};
				end
			end
		end
	end

	local landSet2 = {};
	for _, t in ipairs(landTiles) do landSet2[t[1] .. "," .. t[2]] = true; end
	local waterPathSet = {};
	for _, t in ipairs(waterPathTiles) do waterPathSet[t[1] .. "," .. t[2]] = true; end
	local seaSet = {};
	for _, t in ipairs(seaTiles) do
		seaSet[t[1] .. "," .. t[2]] = true;
		landSet2[t[1] .. "," .. t[2]] = nil;
	end

	local ridgeSet = {};
	for _, t in ipairs(ridgeTiles) do ridgeSet[t[1] .. "," .. t[2]] = true; end

	local mountainPicks = {};
	for i = 1, #ridgeTiles do mountainPicks[i] = i; end
	for i = #mountainPicks, 2, -1 do
		local j = Map.Rand(i, "") + 1;
		mountainPicks[i], mountainPicks[j] = mountainPicks[j], mountainPicks[i];
	end
	local numMountains = math.min(#ridgeTiles, 2 + Map.Rand(math.max(1, #ridgeTiles), ""));
	for i = 1, numMountains do
		local t = ridgeTiles[mountainPicks[i]];
		ridgeSet[t[1] .. "," .. t[2]] = "mountain";
	end

	local islandInSea = {};
	if seaSize >= 10 and Map.Rand(100, "") < 50 then
		local candidates = {};
		for _, t in ipairs(seaTiles) do
			local x, y = t[1], t[2];
			local adjWater = 0;
			for dir = 1, 6 do
				local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
				if seaSet[nx .. "," .. ny] then adjWater = adjWater + 1; end
			end
			if adjWater >= 4 then candidates[#candidates + 1] = t; end
		end
		if #candidates > 0 then
			local pick = candidates[Map.Rand(#candidates, "") + 1];
			islandInSea[pick[1] .. "," .. pick[2]] = true;
		end
	end

	local function adjToMountain(x, y)
		for dir = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
			if ridgeSet[nx .. "," .. ny] == "mountain" then return true; end
		end
		return false;
	end

	if Map.Rand(100, "") < 25 then
		for _ = 1, 1 + Map.Rand(3, "") do
			local lx = centerX + (Map.Rand(5, "") - 2);
			if wrapX then lx = (((lx % iW) + iW) % iW); end
			local ly = southEdge and Map.Rand(2, "") or (edgeY - Map.Rand(2, ""));
			if lx >= 0 and lx < iW and ly >= 0 and ly < iH then
				landTiles[#landTiles + 1] = {lx, ly};
				landSet2[lx .. "," .. ly] = true;
			end
		end
	end

	for _, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		if seaSet[x .. "," .. y] and not islandInSea[x .. "," .. y] then
			plotTypes[idx] = PlotTypes.PLOT_OCEAN;
		elseif waterPathSet[x .. "," .. y] then
			plotTypes[idx] = PlotTypes.PLOT_OCEAN;
		elseif islandInSea[x .. "," .. y] then
			plotTypes[idx] = (Map.Rand(100, "") < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		elseif ridgeSet[x .. "," .. y] == "mountain" then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		elseif adjToMountain(x, y) then
			plotTypes[idx] = (Map.Rand(100, "") < HILLS_ADJ) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		else
			plotTypes[idx] = (Map.Rand(100, "") < 50) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
--]==]

function TryPlacePolarMerge(plotTypes, opts)
	if _island_placed and _island_placed.polarMerge then return false; end
	local iW, iH = opts.iW, opts.iH;
	local wrapX = opts.wrapX or true;
	local wrapY = opts.wrapY or false;
	if wrapY then return false; end

	if Map.Rand(100, "") < CONFIG.EMBRACE_ODDS then
		local ok, px, py = drawPangaeaEmbrace(plotTypes, iW, iH, wrapX, wrapY);
		if ok then
			if not _island_placed then _island_placed = {}; end
			_island_placed.polarMerge = true;
			return true, px, py;
		end
	end
	return false;
end
