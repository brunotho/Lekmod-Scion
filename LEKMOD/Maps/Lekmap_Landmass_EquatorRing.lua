-- Equator-ring mainland: X-wrapping land belt, open polar oceans, jagged N/S coasts from fractal.

-- Tunables (fraction of map height for mean half-band; poles reachable via extent rolls).
local RING_HALF_THICK_FRAC = 0.26;
-- Shore: middle ground between per-column spikes (amp3) and heavy chunks (amp5/chunk5).
local RING_COAST_NOISE_AMP = 4;
local RING_COAST_CHUNK_COLS = 3;
local RING_COAST_SMOOTH_BLEND = 0.45; -- 0=linear (spikier), 1=full smoothstep (chunkier)
local RING_POLE_REACH_PCT = 12; -- among rare-edge maps only: % of chunks that hit hard max half
local RING_EXTENT_POWER = 2; -- u^power biases most chunks toward base half (fat toward poles rare)
local RING_MIN_COL_THICK = 8;
-- Edge reserve (1-indexed from N/S map edge): rows 1-3 never land; rows 4-6 <2% of maps.
local RING_POLAR_OCEAN_HARD = 3; -- never use these edge rows
local RING_POLAR_OCEAN_SOFT = 6; -- normal max reach (leaves rows 4-6 empty)
local RING_RARE_EDGE_PCT = 2; -- % of maps allowed to land in soft band (rows 4-6)

-- TEMP visual A/B: force aggressive peaks + paint one long inland mountain spine every map.
-- Flip to false when done checking.
local RING_FORCE_MONSTER_RIDGE = false;
local RING_MONSTER_RIDGE_LEN = 12; -- target contiguous mountains

local function lekRingLerp(a, b, t)
	return a + (b - a) * t;
end

-- Sample half-thickness toward a pole: usually near baseHalf, sometimes all the way to maxHalf.
local function lekRingSampleHalf(baseHalf, maxHalf)
	if maxHalf < baseHalf then
		return maxHalf;
	end
	if Map.Rand(100, "ringPoleReach") < RING_POLE_REACH_PCT then
		return maxHalf;
	end
	local u = Map.Rand(1000, "ringExtent") / 1000;
	if RING_EXTENT_POWER == 2 then
		u = u * u;
	elseif RING_EXTENT_POWER ~= 1 then
		-- avoid math.pow (not always present in Civ Lua builds)
		local p = RING_EXTENT_POWER;
		local acc = u;
		for _ = 2, p do
			acc = acc * u;
		end
		u = acc;
	end
	return math.floor(baseHalf + (maxHalf - baseHalf) * u + 0.5);
end

function LekLandmass_EquatorRing_Build(self, env)
	if LekPipelineFlow then LekPipelineFlow("EquatorRing_Build_entry"); end
	local iW = self.iNumPlotsX;
	local iH = self.iNumPlotsY;
	local water_percent = env.water_percent;
	local grain = env.grain;
	local numPlates = env.numPlates;
	local adjustment = env.adjustment;
	local hills_ridge_flags = env.hills_ridge_flags;
	local peaks_ridge_flags = env.peaks_ridge_flags;
	local hillsBottom1 = env.hillsBottom1;
	local hillsTop1 = env.hillsTop1;
	local hillsBottom2 = env.hillsBottom2;
	local hillsTop2 = env.hillsTop2;
	local hillsClumps = env.hillsClumps;
	local hillsNearMountains = env.hillsNearMountains;
	local mountains = env.mountains;
	-- Ring: slightly more peak hits + stickier mountain rolls (breakers already skipped).
	mountains = mountains - 2;
	hillsNearMountains = hillsNearMountains - 1;
	local ringMountStick = 8; -- lower spawn bar vs default 48-adjustment
	if RING_FORCE_MONSTER_RIDGE then
		mountains = mountains - 5;
		hillsNearMountains = hillsNearMountains - 2;
		ringMountStick = 25;
	end

	self.continentsFrac = nil;
	self:InitFractal{ continent_grain = 7, rift_grain = -1 };
	local iWaterThreshold = self.continentsFrac:GetHeight(water_percent);

	local mid = math.floor(iH / 2);
	local baseHalf = math.max(RING_MIN_COL_THICK, math.floor(iH * RING_HALF_THICK_FRAC + 0.5));
	-- Hard floor: never land in edge rows 1-3. Soft floor: normally stop before rows 4-6.
	local yMinHard = RING_POLAR_OCEAN_HARD;
	local yMaxHard = iH - 1 - RING_POLAR_OCEAN_HARD;
	local yMinSoft = RING_POLAR_OCEAN_SOFT;
	local yMaxSoft = iH - 1 - RING_POLAR_OCEAN_SOFT;
	if yMinSoft > mid - RING_MIN_COL_THICK then yMinSoft = math.max(yMinHard, mid - RING_MIN_COL_THICK); end
	if yMaxSoft < mid + RING_MIN_COL_THICK - 1 then yMaxSoft = math.min(yMaxHard, mid + RING_MIN_COL_THICK - 1); end
	local allowRareEdge = Map.Rand(100, "ringRareEdge") < RING_RARE_EDGE_PCT;
	local yMinPole = allowRareEdge and yMinHard or yMinSoft;
	local yMaxPole = allowRareEdge and yMaxHard or yMaxSoft;
	local maxHalfS = mid - yMinPole;
	local maxHalfN = yMaxPole - mid;

	-- Chunky coast samples around the wrap (low-frequency N/S extent + shore offset).
	local chunk = math.max(3, RING_COAST_CHUNK_COLS);
	local nSamp = math.max(3, math.floor(iW / chunk + 0.5));
	local southSamp = {};
	local northSamp = {};
	for s = 0, nSamp - 1 do
		local hS = lekRingSampleHalf(baseHalf, maxHalfS);
		local hN = lekRingSampleHalf(baseHalf, maxHalfN);
		local wobS = Map.Rand(2 * RING_COAST_NOISE_AMP + 1, "ringCoastS") - RING_COAST_NOISE_AMP;
		local wobN = Map.Rand(2 * RING_COAST_NOISE_AMP + 1, "ringCoastN") - RING_COAST_NOISE_AMP;
		-- Mild fractal correlation between neighboring samples.
		local sx = math.floor((s / nSamp) * iW) % iW;
		local n1 = self.continentsFrac:GetHeight(sx, mid);
		local n2 = self.continentsFrac:GetHeight((sx + math.floor(iW / 3)) % iW, mid);
		if n1 > iWaterThreshold then wobS = wobS + 1; end
		if n2 > iWaterThreshold then wobN = wobN - 1; end
		southSamp[s] = mid - hS + wobS;
		northSamp[s] = mid + hN + wobN;
	end

	for x = 0, iW - 1 do
		local f = (x / iW) * nSamp;
		local i0 = math.floor(f) % nSamp;
		local i1 = (i0 + 1) % nSamp;
		local t = f - math.floor(f);
		-- Blend linear + smoothstep: less mega-lobe than full smoothstep, less 1-tile spikes than raw columns.
		local ts = t * t * (3 - 2 * t);
		local blend = RING_COAST_SMOOTH_BLEND;
		if type(blend) ~= "number" then blend = 0.45; end
		if blend < 0 then blend = 0; elseif blend > 1 then blend = 1; end
		t = (1 - blend) * t + blend * ts;
		local ySouth = math.floor(lekRingLerp(southSamp[i0], southSamp[i1], t) + 0.5);
		local yNorth = math.floor(lekRingLerp(northSamp[i0], northSamp[i1], t) + 0.5);
		if ySouth < yMinPole then ySouth = yMinPole; end
		if yNorth > yMaxPole then yNorth = yMaxPole; end
		if yNorth < ySouth + RING_MIN_COL_THICK - 1 then
			yNorth = math.min(yMaxPole, ySouth + RING_MIN_COL_THICK - 1);
		end
		for y = 0, iH - 1 do
			local i = y * iW + x + 1;
			if y >= ySouth and y <= yNorth then
				self.plotTypes[i] = PlotTypes.PLOT_LAND;
			else
				self.plotTypes[i] = PlotTypes.PLOT_OCEAN;
			end
		end
	end

	-- Ring seal: no all-ocean column in the equatorial band.
	for x = 0, iW - 1 do
		local hasLand = false;
		for y = yMinPole, yMaxPole do
			local i = y * iW + x + 1;
			if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
				hasLand = true;
				break;
			end
		end
		if not hasLand then
			local y0 = mid - math.floor(RING_MIN_COL_THICK / 2);
			local y1 = y0 + RING_MIN_COL_THICK - 1;
			if y0 < yMinPole then y0 = yMinPole; end
			if y1 > yMaxPole then y1 = yMaxPole; end
			for y = y0, y1 do
				self.plotTypes[y * iW + x + 1] = PlotTypes.PLOT_LAND;
			end
		end
	end

	-- Hills / mountains on land only (no polar tectonic islands).
	self.hillsFrac = Fractal.Create(iW, iH, grain, self.iFlags, self.fracXExp, self.fracYExp);
	self.mountainsFrac = Fractal.Create(iW, iH, grain, self.iFlags, self.fracXExp, self.fracYExp);
	self.hillsFrac:BuildRidges(numPlates, hills_ridge_flags, 1, 2);
	self.mountainsFrac:BuildRidges((numPlates * 2) / 3, peaks_ridge_flags, 6, 1);

	local iHillsBottom1 = self.hillsFrac:GetHeight(hillsBottom1);
	local iHillsTop1 = self.hillsFrac:GetHeight(hillsTop1);
	local iHillsBottom2 = self.hillsFrac:GetHeight(hillsBottom2);
	local iHillsTop2 = self.hillsFrac:GetHeight(hillsTop2);
	local iHillsNearMountains = self.mountainsFrac:GetHeight(hillsNearMountains);
	local iMountainThreshold = self.mountainsFrac:GetHeight(mountains);
	local iPassThreshold = self.hillsFrac:GetHeight(hillsNearMountains);

	for x = 0, iW - 1 do
		for y = 0, iH - 1 do
			local i = y * iW + x + 1;
			if self.plotTypes[i] ~= PlotTypes.PLOT_OCEAN then
				local mountainVal = self.mountainsFrac:GetHeight(x, y);
				local hillVal = self.hillsFrac:GetHeight(x, y);
				if mountainVal >= iMountainThreshold then
					if hillVal >= iPassThreshold then
						self.plotTypes[i] = PlotTypes.PLOT_HILLS;
					else
						local iIsMount = Map.Rand(100, "Ring Mountain Spawn Chance");
						local iIsMountAdj = 48 - adjustment - ringMountStick;
						if iIsMount >= iIsMountAdj then
							self.plotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
						else
							local iIsHill = Map.Rand(100, "Ring Hill Spawn Chance");
							local iIsHillAdj = 30 - adjustment;
							if iIsHill >= iIsHillAdj then
								self.plotTypes[i] = PlotTypes.PLOT_HILLS;
							else
								self.plotTypes[i] = PlotTypes.PLOT_LAND;
							end
						end
					end
				elseif mountainVal >= iHillsNearMountains then
					self.plotTypes[i] = PlotTypes.PLOT_HILLS;
				elseif (hillVal >= iHillsBottom1 and hillVal <= iHillsTop1)
					or (hillVal >= iHillsBottom2 and hillVal <= iHillsTop2) then
					self.plotTypes[i] = PlotTypes.PLOT_HILLS;
				else
					self.plotTypes[i] = PlotTypes.PLOT_LAND;
				end
			end
		end
	end

	-- TEMP: guarantee one long inland mountain spine for visual A/B.
	local monsterLen = 0;
	if RING_FORCE_MONSTER_RIDGE then
		local wrapX = Map.IsWrapX and Map:IsWrapX() or true;
		local wrapY = false;
		local function isDry(x, y)
			if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
			local t = self.plotTypes[y * iW + x + 1];
			return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
		end
		local function paintMtn(x, y)
			self.plotTypes[y * iW + x + 1] = PlotTypes.PLOT_MOUNTAIN;
		end
		local sx = Map.Rand(iW, "monsterRidgeX");
		local sy = mid - 2 + Map.Rand(5, "monsterRidgeY"); -- near equator band interior
		if not isDry(sx, sy) then
			for _ = 1, 40 do
				sx = Map.Rand(iW, "monsterRidgeX2");
				sy = mid - 3 + Map.Rand(7, "monsterRidgeY2");
				if isDry(sx, sy) then break; end
			end
		end
		if isDry(sx, sy) then
			paintMtn(sx, sy);
			monsterLen = 1;
			local x, y = sx, sy;
			local dir = 1 + Map.Rand(6, "monsterRidgeDir");
			for step = 2, RING_MONSTER_RIDGE_LEN do
				local placed = false;
				for turn = 0, 5 do
					local d = ((dir + turn - 1) % 6) + 1;
					local nx, ny;
					if GetHexNeighbor then
						nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
					else
						nx = (x + ((turn % 2 == 0) and 1 or -1) + iW) % iW;
						ny = y + ((d <= 3) and 1 or -1);
					end
					if isDry(nx, ny) then
						paintMtn(nx, ny);
						x, y = nx, ny;
						dir = d;
						monsterLen = monsterLen + 1;
						placed = true;
						break;
					end
				end
				if not placed then break; end
			end
		end
	end

	-- No Y-recenter: polar reaches from extent rolls should stick.
	if LekPipelineFlow then
		LekPipelineFlow("EquatorRing_Build_ok",
			"baseHalf=" .. tostring(baseHalf)
			.. " chunks=" .. tostring(nSamp)
			.. " rareEdge=" .. (allowRareEdge and "1" or "0")
			.. " yClamp=" .. tostring(yMinPole) .. "-" .. tostring(yMaxPole)
			.. " polePct=" .. tostring(RING_POLE_REACH_PCT)
			.. " forceMonster=" .. (RING_FORCE_MONSTER_RIDGE and "1" or "0")
			.. " monsterLen=" .. tostring(monsterLen));
	end
	return {
		ok = true,
		xshift = 0,
		yshift = 0,
		xshiftamt = 0,
		yshiftamt = 0,
		skipMarginClear = true,
		skipXShift = true,
		iWaterThreshold = iWaterThreshold,
	};
end

-- After HB GenerateRegions division: replace regionData with staggered 3×2 brick AABBs
-- (6 civs only). Fertility is measured inside each fixed brick; it does not choose cuts.
-- Hooked via AssignStartingPlots:CustomOverride so MeasureTerrainInRegions sees bricks.
function LekLandmass_EquatorRing_ApplyBrickRegions(startDb)
	if not (LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing()) then
		return false;
	end
	if not startDb or (startDb.iNumCivs or 0) ~= 6 then
		if LekPipelineFlow then
			LekPipelineFlow("brick_regions_skip", "civs=" .. tostring(startDb and startDb.iNumCivs or "?"));
		end
		return false;
	end

	local iW, iH = Map.GetGridSize();
	local biggest = Map.FindBiggestArea(false);
	if biggest == nil then
		if LekPipelineFlow then LekPipelineFlow("brick_regions_fail", "no_biggest_area"); end
		return false;
	end
	local areaID = biggest:GetID();

	-- Polar-merge land joins the mainland but must not stretch brick Y / fert
	-- (starts already skip these via EvaluateCandidatePlot).
	local function isBrickLand(p, x, y)
		if not p or p:IsWater() or p:GetArea() ~= areaID then
			return false;
		end
		if _polar_merge_excluded_plots then
			local plotIndex = y * iW + x + 1;
			if _polar_merge_excluded_plots[plotIndex] then
				return false;
			end
		end
		return true;
	end

	local yMin, yMax = iH, -1;
	local exclSkipped = 0;
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local p = Map.GetPlot(x, y);
			if p and not p:IsWater() and p:GetArea() == areaID then
				local plotIndex = y * iW + x + 1;
				if _polar_merge_excluded_plots and _polar_merge_excluded_plots[plotIndex] then
					exclSkipped = exclSkipped + 1;
				else
					if y < yMin then yMin = y; end
					if y > yMax then yMax = y; end
				end
			end
		end
	end
	if yMax < yMin then
		if LekPipelineFlow then LekPipelineFlow("brick_regions_fail", "no_land_y"); end
		return false;
	end

	local landH = yMax - yMin + 1;
	local rowHSouth = math.max(1, math.floor(landH / 2));
	local rowHNorth = math.max(1, landH - rowHSouth);
	local southY = yMin;
	local northY = yMin + rowHSouth;

	-- Three X cells covering full wrap width; remainder columns go to the first cells.
	local baseW = math.floor(iW / 3);
	local rem = iW - baseW * 3;
	local widths = {
		baseW + ((rem > 0) and 1 or 0),
		baseW + ((rem > 1) and 1 or 0),
		baseW,
	};
	local southWest = { 0, widths[1], widths[1] + widths[2] };
	local offset = math.floor(iW / 6); -- half-cell stagger for north row
	local northWest = {
		offset % iW,
		(offset + widths[1]) % iW,
		(offset + widths[1] + widths[2]) % iW,
	};

	local function measureBrick(westX, sY, width, height)
		local fert, plots = 0, 0;
		for dy = 0, height - 1 do
			for dx = 0, width - 1 do
				local x = (westX + dx) % iW;
				local y = sY + dy;
				if y >= 0 and y < iH then
					local p = Map.GetPlot(x, y);
					if isBrickLand(p, x, y) then
						plots = plots + 1;
						if startDb.MeasureStartPlacementFertilityOfPlot then
							fert = fert + (startDb:MeasureStartPlacementFertilityOfPlot(x, y, true) or 0);
						end
					end
				end
			end
		end
		if plots < 1 then
			plots = 1;
		end
		local avg = fert / plots;
		return { westX, sY, width, height, areaID, fert, plots, avg };
	end

	local bricks = {};
	for i = 1, 3 do
		bricks[#bricks + 1] = measureBrick(southWest[i], southY, widths[i], rowHSouth);
	end
	for i = 1, 3 do
		bricks[#bricks + 1] = measureBrick(northWest[i], northY, widths[i], rowHNorth);
	end

	startDb.regionData = bricks;
	if LekPipelineFlow then
		LekPipelineFlow("brick_regions_applied",
			"n=6 y=" .. tostring(yMin) .. "-" .. tostring(yMax)
			.. " offset=" .. tostring(offset)
			.. " w=" .. tostring(widths[1]) .. "," .. tostring(widths[2]) .. "," .. tostring(widths[3])
			.. " polar_excl=" .. tostring(exclSkipped));
	end
	return true;
end

-- Sparse enclosed ocean seeds for RoundInlandSeas (0–2 bodies). Ring belt is solid, so
-- without this RoundInlandSeas finds no inlandSet and no-ops. Compact does not call this.
-- Seeds stay >= MIN_GAP hex from open (polar) ocean so RoundInlandSeas can thicken them.
function LekLandmass_EquatorRing_SeedInlandSeas(self)
	if not (LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing()) then
		return 0;
	end
	if not self or not self.plotTypes or not GetHexNeighbor then
		return 0;
	end

	local iW = self.iNumPlotsX;
	local iH = self.iNumPlotsY;
	local wrapX = Map.IsWrapX and Map:IsWrapX() or false;
	local wrapY = Map.IsWrapY and Map:IsWrapY() or false;
	local plotTypes = self.plotTypes;
	local function pidx(x, y) return y * iW + x + 1; end
	local function isOcean(x, y)
		if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
		return plotTypes[pidx(x, y)] == PlotTypes.PLOT_OCEAN;
	end
	local function isLand(x, y)
		if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
		return plotTypes[pidx(x, y)] ~= PlotTypes.PLOT_OCEAN;
	end

	-- Match RoundInlandSeas gap (6 => ≥5 land between inland water and open ocean).
	local MIN_GAP = 6;
	local CENTER_MIN_DIST = 8; -- seed centers a bit deeper so blob can grow
	local MIN_SEED_TILES = 7;
	local MAX_SEED_TILES = 12;
	local MIN_BODY_SEP = 14;

	-- How many bodies this map: sparse 0–2 (~40% none, ~45% one, ~15% two).
	local roll = Map.Rand(100, "ringInlandSeedCount");
	local targetN = 0;
	if roll < 40 then
		targetN = 0;
	elseif roll < 85 then
		targetN = 1;
	else
		targetN = 2;
	end
	if targetN == 0 then
		if LekPipelineFlow then LekPipelineFlow("ring_inland_seed", "n=0 (rolled none)"); end
		return 0;
	end

	local openOcean = {};
	local queue = {};
	for x = 0, iW - 1 do
		for _, edgeY in ipairs({0, iH - 1}) do
			if isOcean(x, edgeY) then
				local k = edgeY * iW + x;
				if not openOcean[k] then
					openOcean[k] = true;
					queue[#queue + 1] = {x, edgeY};
				end
			end
		end
	end
	local q = 1;
	while q <= #queue do
		local cx, cy = queue[q][1], queue[q][2];
		q = q + 1;
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isOcean(nx, ny) then
				local nk = ny * iW + nx;
				if not openOcean[nk] then
					openOcean[nk] = true;
					queue[#queue + 1] = {nx, ny};
				end
			end
		end
	end

	local distFromOpen = {};
	queue = {};
	for k, _ in pairs(openOcean) do
		local ox = k % iW;
		local oy = math.floor(k / iW);
		distFromOpen[k] = 0;
		queue[#queue + 1] = {ox, oy};
	end
	q = 1;
	while q <= #queue do
		local cx, cy = queue[q][1], queue[q][2];
		q = q + 1;
		local cd = distFromOpen[cy * iW + cx];
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(cx, cy, d, iW, iH, wrapX, wrapY);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				local nk = ny * iW + nx;
				if distFromOpen[nk] == nil then
					distFromOpen[nk] = cd + 1;
					queue[#queue + 1] = {nx, ny};
				end
			end
		end
	end

	local function plotDist(ax, ay, bx, by)
		if Map.PlotDistance then return Map.PlotDistance(ax, ay, bx, by); end
		if PlotDistance then return PlotDistance(ax, ay, bx, by); end
		return math.abs(ax - bx) + math.abs(ay - by);
	end

	local centers = {};
	local sizes = {};
	local blocked = {}; -- tiles too close to an already placed body

	for body = 1, targetN do
		local candidates = {};
		for y = 0, iH - 1 do
			for x = 0, iW - 1 do
				local k = y * iW + x;
				if not blocked[k] and isLand(x, y) then
					local d = distFromOpen[k];
					if d ~= nil and d >= CENTER_MIN_DIST then
						local farEnough = true;
						for _, c in ipairs(centers) do
							if plotDist(x, y, c[1], c[2]) < MIN_BODY_SEP then
								farEnough = false;
								break;
							end
						end
						if farEnough then
							candidates[#candidates + 1] = {x, y};
						end
					end
				end
			end
		end
		if #candidates == 0 then
			break;
		end

		local pick = candidates[1 + Map.Rand(#candidates, "ringInlandSeedPick")];
		local sx, sy = pick[1], pick[2];
		local want = MIN_SEED_TILES + Map.Rand(MAX_SEED_TILES - MIN_SEED_TILES + 1, "ringInlandSeedSize");
		local painted = {};
		local growQ = {{sx, sy}};
		local growSeen = {};
		growSeen[sy * iW + sx] = true;
		local nPaint = 0;
		local gi = 1;
		while gi <= #growQ and nPaint < want do
			local cx, cy = growQ[gi][1], growQ[gi][2];
			gi = gi + 1;
			local ck = cy * iW + cx;
			local d = distFromOpen[ck];
			if d ~= nil and d >= MIN_GAP and isLand(cx, cy) and not blocked[ck] then
				plotTypes[pidx(cx, cy)] = PlotTypes.PLOT_OCEAN;
				painted[#painted + 1] = {cx, cy};
				nPaint = nPaint + 1;
			end
			-- Shuffle neighbor order lightly via random start dir.
			local d0 = 1 + Map.Rand(6, "ringInlandGrowDir");
			for off = 0, 5 do
				local dir = ((d0 + off - 1) % 6) + 1;
				local nx, ny = GetHexNeighbor(cx, cy, dir, iW, iH, wrapX, wrapY);
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
					local nk = ny * iW + nx;
					if not growSeen[nk] then
						growSeen[nk] = true;
						local nd = distFromOpen[nk];
						if nd ~= nil and nd >= MIN_GAP and isLand(nx, ny) then
							growQ[#growQ + 1] = {nx, ny};
						end
					end
				end
			end
		end

		if nPaint < MIN_SEED_TILES then
			-- Revert undersized attempt.
			for _, t in ipairs(painted) do
				plotTypes[pidx(t[1], t[2])] = PlotTypes.PLOT_LAND;
			end
		else
			centers[#centers + 1] = {sx, sy};
			sizes[#sizes + 1] = nPaint;
			-- Block a halo so a second body does not merge / sit on top.
			for _, t in ipairs(painted) do
				local px, py = t[1], t[2];
				blocked[py * iW + px] = true;
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(px, py, d, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						blocked[ny * iW + nx] = true;
						for d2 = 1, 6 do
							local n2x, n2y = GetHexNeighbor(nx, ny, d2, iW, iH, wrapX, wrapY);
							if n2x >= 0 and n2x < iW and n2y >= 0 and n2y < iH then
								blocked[n2y * iW + n2x] = true;
							end
						end
					end
				end
			end
			-- Also keep centers far via MIN_BODY_SEP check on candidate pick.
		end
	end

	if LekPipelineFlow then
		local sizeStr = (#sizes > 0) and table.concat(sizes, ",") or "-";
		LekPipelineFlow("ring_inland_seed",
			"target=" .. tostring(targetN)
			.. " placed=" .. tostring(#centers)
			.. " sizes=" .. sizeStr);
	end
	return #centers;
end
