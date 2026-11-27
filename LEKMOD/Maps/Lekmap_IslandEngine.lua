------------------------------------------------------------------------------
-- Lekmap_IslandEngine.lua — shared pangaea-island draft/place loop.
-- Placers: XX_island_* (via 3_PangaeaIslands includes). Policies: Lekmap_Islands_*.
-- Coastal bonus + inland-sea spray stay outside this file.
------------------------------------------------------------------------------

function LekIslands_ResolvePolicy(explicit)
	if explicit ~= nil then
		return explicit;
	end
	if LekLandmass_IsEquatorRing and LekLandmass_IsEquatorRing()
		and LekIslands_GetEquatorRingPolicy then
		return LekIslands_GetEquatorRingPolicy();
	end
	if LekIslands_GetFractalPangaeaPolicy then
		return LekIslands_GetFractalPangaeaPolicy();
	end
	if LekIslands_GetCompactPolicy then
		return LekIslands_GetCompactPolicy();
	end
	return nil;
end

local function LekIslandProbeLog(msg, minVerb)
	minVerb = minVerb or 2;
	if LekMapgenChannelEnabled then
		if not LekMapgenChannelEnabled("islands") then
			return;
		end
	elseif LekMapgenLogsEnabled and not LekMapgenLogsEnabled() then
		return;
	end
	if _lek_mapgen_world_is_small == true and minVerb < 3 then
		minVerb = 3;
	end
	if LekMapgenLogAtLeast and not LekMapgenLogAtLeast(minVerb) then
		return;
	end
	print(msg);
	pcall(function()
		if LekMapgenDiagLogAppend then
			LekMapgenDiagLogAppend({ msg });
		end
	end);
end

local function LekIslandBudgetFillPct(spent, target)
	if not target or type(target) ~= "number" or target <= 0 then
		return 0;
	end
	return 100 * spent / target;
end

-- Island map tracking (channel islandmap): which island type painted which tile, final accepted run only.
function LekIslandMapEnabled()
	return LekMapgenChannelEnabled ~= nil and LekMapgenChannelEnabled("islandmap");
end

function GenerateIslands(self, policy, genOpts)
	genOpts = genOpts or {};
	_lek_island_track = nil;
	local lastRunTrack = nil;
	policy = policy or LekIslands_ResolvePolicy(genOpts.policy);
	if policy == nil then
		if LekPipelineFlow then LekPipelineFlow("islands_engine_no_policy"); end
		return 0, true;
	end
	if policy.channels and policy.channels.pangaeaDraft == false then
		if LekPipelineFlow then
			LekPipelineFlow("islands_draft_skipped", "policy=" .. tostring(policy.id or "?"));
		end
		return 0, true;
	end
	if LekPipelineFlow then
		LekPipelineFlow("islands_engine_begin",
			"policy=" .. tostring(policy.id or "?")
			.. " budget=" .. tostring(policy.totalBudget or "?"));
	end

	local CommonIslands = policy.common or {};
	local UncommonIslands = policy.uncommon or {};
	local RareIslands = policy.rare or {};
	local AllIslandTypeTables = {
		{ tier = "common", pool = CommonIslands },
		{ tier = "uncommon", pool = UncommonIslands },
		{ tier = "rare", pool = RareIslands },
	};
	local IslandTypePlace = LekIslandTypePlace;
	if not IslandTypePlace then
		if LekPipelineFlow then LekPipelineFlow("islands_engine_no_catalog"); end
		return 0, false;
	end
	local PANGAEA_ISLAND_TOTAL_BUDGET = policy.totalBudget or 8;
	local PANGAEA_ISLAND_DOT_STRIP_EARLY_BUDGET = policy.dotStripEarlyBudget or 2;
	local skipCommonFill = (policy.skipCommonFill == true);
	local DotStripEarlyPool = policy.dotStripEarly or {
		{ type = "dot", odds = 5, budget = 0.09 },
		{ type = "strip", odds = 2, budget = 0.39 },
	};
	local IslandSpecialPhaseTypes = policy.specialPhaseTypes or {};
	local PANGAEA_COMMON_FILL_MAX_PASSES = policy.commonFillMaxPasses or 10000;
	local PANGAEA_ISLAND_BUDGET_RETRY = policy.budgetRetry;
	if PANGAEA_ISLAND_BUDGET_RETRY == nil then PANGAEA_ISLAND_BUDGET_RETRY = true; end
	local PANGAEA_ISLAND_RELAX_BUDGET_TIER = policy.relaxBudgetTier;
	if PANGAEA_ISLAND_RELAX_BUDGET_TIER == nil then PANGAEA_ISLAND_RELAX_BUDGET_TIER = false; end
	local PANGAEA_ISLAND_MAX_RUNONCE_NOMINAL = policy.maxRunOnceNominal or 2;
	local PANGAEA_ISLAND_MAX_TRIES_PER_BUDGET = policy.maxTriesPerBudget or 80;
	local PANGAEA_ISLAND_BUDGET_FLOOR = policy.budgetFloor or 5;
	local PANGAEA_SHORE_SMALL_ISLAND_ATTEMPTS = policy.shoreSmallAttempts or 600;
	local PANGAEA_COMMON_SMALL_ISLAND_TRIES_TIGHT = policy.commonTriesTight or 500;
	local PANGAEA_COMMON_SMALL_ISLAND_TRIES_LOOSE = policy.commonTriesLoose or 350;
	local PANGAEA_COMMON_FILL_IDLE_BREAK = policy.commonFillIdleBreak or 400;
	local PANGAEA_RUNONCE_MAX_CLOCK = policy.runOnceMaxClock or 75;
	local PANGAEA_BUDGET_TIER_MAX_CLOCK = policy.budgetTierMaxClock;
	local PANGAEA_BUDGET_FAST_FAIL_TRIES = policy.budgetFastFailTries;
	local PANGAEA_BUDGET_FAST_FAIL_SPENT_FRAC = policy.budgetFastFailSpentFrac or 0.68;
	local NAMED_PRIORITY = policy.namedPriority or { polarMerge = 1, wrapSoftLandbridge = 2 };
	local TIER_BASE_PRIORITY = policy.tierBasePriority or { rare = 5, uncommon = 6, common = 8 };

	local function GetOptEntry(islandType)
		for _, t in ipairs(AllIslandTypeTables) do
			for _, e in ipairs(t.pool) do
				if e.type == islandType then e.tier = t.tier; return e; end
			end
		end
		return nil;
	end

	local function GetBudget(islandType)
		local e = GetOptEntry(islandType);
		return e and e.budget or 1;
	end

	local function IsMaxOne(islandType)
		local e = GetOptEntry(islandType);
		return e ~= nil and (e.tier == "rare");
	end

	local function GetPlaceParams(islandType)
		local e = GetOptEntry(islandType);
		if e and e.pullBack then
			-- effMin may be 0; do not use `or` (0 is falsy in Lua).
			local effMin = e.effMin;
			if effMin == nil then
				effMin = (1 + Map.Rand(3, "")) - e.pullBack - 1;
			end
			return { pullBack = e.pullBack, effMin = effMin, effMax = e.effMax };
		end
		return { pullBack = 1, effMin = 1, effMax = 6 };
	end

	-- policy.maxPerType = { type = n }: hard cap per map (counts reset with each budget try).
	local maxPerType = policy.maxPerType or {};
	local runTypeCounts = {};
	local function typeCapped(t)
		return t ~= nil and maxPerType[t] ~= nil and (runTypeCounts[t] or 0) >= maxPerType[t];
	end

	local guardedPlace; -- assigned below once the pre-island land mask exists
	local function TryPlaceIsland(plotTypes, x, y, islLandInRing, opts, forceType)
		local islandType = forceType or "dot";
		if not IslandTypePlace[islandType] then return false, islandType; end
		if typeCapped(islandType) then return false, islandType; end
		local params = GetPlaceParams(islandType);
		params.iW = opts.iW;
		params.iH = opts.iH;
		params.wrapX = opts.wrapX;
		params.wrapY = opts.wrapY;
		params.landX = opts.landX;
		params.landY = opts.landY;
		params.mainland = opts.mainland;  -- 1-based set of mainland tiles (pre-island biggest landmass)
		if opts.attempt then params.attempt = opts.attempt; end
		local placed = guardedPlace(islandType, function(pt)
			return IslandTypePlace[islandType](pt, x, y, islLandInRing, params);
		end);
		return placed, islandType;
	end

	local function DraftOneFromTier(pool, excludeSet)
		local totalWeight = 0;
		for _, e in ipairs(pool) do
			if typeCapped(e.type) then
				-- capped for this map: never drafted again
			elseif not (IsMaxOne(e.type) and excludeSet[e.type]) then
				totalWeight = totalWeight + e.odds;
			end
		end
		if totalWeight == 0 then return nil; end
		local roll = Map.Rand(totalWeight, "");
		local cumulative = 0;
		for _, e in ipairs(pool) do
			if not typeCapped(e.type) and not (IsMaxOne(e.type) and excludeSet[e.type]) then
				cumulative = cumulative + e.odds;
				if roll < cumulative then return e.type; end
			end
		end
		return nil;
	end

	local function GetDraftPriority(islandType)
		if NAMED_PRIORITY[islandType] then return NAMED_PRIORITY[islandType]; end
		local e = GetOptEntry(islandType);
		if not e then return 99; end
		if e.fragile then return 7; end
		return TIER_BASE_PRIORITY[e.tier] or 99;
	end

	local budgetRetry = genOpts.budgetRetry;
	if budgetRetry == nil then budgetRetry = PANGAEA_ISLAND_BUDGET_RETRY; end
	local maxTriesPerBudget = genOpts.maxTriesPerBudget or PANGAEA_ISLAND_MAX_TRIES_PER_BUDGET;
	local budgetFloor = genOpts.budgetFloor or PANGAEA_ISLAND_BUDGET_FLOOR;
	local relaxBudgetTier = genOpts.relaxBudgetTier;
	if relaxBudgetTier == nil then relaxBudgetTier = PANGAEA_ISLAND_RELAX_BUDGET_TIER; end
	local maxRunOnceNominal = genOpts.maxRunOnceNominal;
	if maxRunOnceNominal == nil then maxRunOnceNominal = PANGAEA_ISLAND_MAX_RUNONCE_NOMINAL; end
	local laIsland = _lek_map_layout_attempt or 0;
	local outerIsland = tonumber(_lek_pangaea_outer_attempt) or 0;
	local tIslandGen0 = (os and os.clock) and os.clock() or 0;
	local islandRunBudget = 0;
	local islandRunTry = 0;
	local tallyRunOnceAborts = 0;
	local globalBestSpent = 0;
	local tierClockStopCount = 0;
	local fastFailStopCount = 0;
	local nominalBudget = PANGAEA_ISLAND_TOTAL_BUDGET;

	local function dbg2(msg)
		if LekMapgenPrint then
			LekMapgenPrint(msg);
		elseif LekMapgenLogsEnabled and LekMapgenLogsEnabled() then
			print(msg);
		end
	end
	dbg2("### GeneratePangaeaIslands: start [" .. os.date("%H:%M:%S") .. "] ###");
	local iW, iH = Map.GetGridSize();
	local n = iW * iH;
	local snapshot = {};
	for i = 1, n do
		snapshot[i] = self.plotTypes[i];
	end

	local pangeaTiles = {};
	for i = 0, (iW * iH) - 1 do
		local t = snapshot[i + 1];
		if t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN then
			pangeaTiles[i + 1] = true;
		end
	end

	local wrapX = Map:IsWrapX();
	local wrapY = false;

	-- Mainland = biggest connected piece of the pre-island land (keys 1-based like pangeaTiles).
	-- Seeds anchor to it; stray tectonic specks / central-sea islands do not count as anchors.
	local mainlandTiles = {};
	do
		local compOf, bestC, bestN, nC = {}, nil, 0, 0;
		for i in pairs(pangeaTiles) do
			if not compOf[i] then
				nC = nC + 1;
				local grp, h = { i }, 1;
				compOf[i] = nC;
				while h <= #grp do
					local k0 = grp[h] - 1;
					for d = 1, 6 do
						local nx, ny = GetHexNeighbor(k0 % iW, math.floor(k0 / iW), d, iW, iH, wrapX, wrapY);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
							local ni = ny * iW + nx + 1;
							if pangeaTiles[ni] and not compOf[ni] then
								compOf[ni] = nC;
								grp[#grp + 1] = ni;
							end
						end
					end
					h = h + 1;
				end
				if #grp > bestN then bestN = #grp; bestC = nC; end
			end
		end
		for i, c in pairs(compOf) do
			if c == bestC then mainlandTiles[i] = true; end
		end
	end

	-- Gap guard: types not in policy.mayTouchMainland must keep >= 1 water tile from the pre-island land
	-- (pangeaTiles). Writes go through a recording proxy; a placement that paints next to / over that land
	-- (or carves it) is undone and counts as a failed try. Island marker globals are rolled back with it.
	local mayTouch = policy.mayTouchMainland or {};
	-- Civ5 map scripts have no _G, so the marker globals are saved/restored by name explicitly.
	local function saveMarkers()
		return { _sri_pada_island_plot, _solomons_island_mines_plot, _solomons_island_nw_type,
			_krakatoa_island_plot, _sinai_island_plot, _geothermal_island_plot, _geothermal_island_nw_type,
			_geothermal_is_krakatoa, _geothermal_snow_plot_indices, _geothermal_forest_ring_indices };
	end
	local function restoreMarkers(m)
		_sri_pada_island_plot, _solomons_island_mines_plot, _solomons_island_nw_type = m[1], m[2], m[3];
		_krakatoa_island_plot, _sinai_island_plot, _geothermal_island_plot, _geothermal_island_nw_type = m[4], m[5], m[6], m[7];
		_geothermal_is_krakatoa, _geothermal_snow_plot_indices, _geothermal_forest_ring_indices = m[8], m[9], m[10];
	end
	local gapRejects = 0;
	-- Max distance rule: an island's closest tile must be within policy.maxMainlandGap hexes of the mainland
	-- (2 = exactly one water tile, since the gap guard forbids touching). policy.mainlandGapByType overrides it
	-- per type; types in policy.farFromMainlandOk are exempt (e.g. the outward-heading hotspot trail).
	local maxMainlandGap = policy.maxMainlandGap;
	local gapByType = policy.mainlandGapByType or {};
	local farOk = policy.farFromMainlandOk or {};
	local mainDist = {};
	local bfsGap = maxMainlandGap;
	if bfsGap then
		for _, g in pairs(gapByType) do
			if g > bfsGap then bfsGap = g; end
		end
	end
	if maxMainlandGap then
		local qd = {};
		for i in pairs(mainlandTiles) do
			mainDist[i - 1] = 0;
			qd[#qd + 1] = i - 1;
		end
		local hd = 1;
		while hd <= #qd do
			local k = qd[hd];
			hd = hd + 1;
			if mainDist[k] < bfsGap then
				for d = 1, 6 do
					local nx, ny = GetHexNeighbor(k % iW, math.floor(k / iW), d, iW, iH, wrapX, wrapY);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local nk = ny * iW + nx;
						if mainDist[nk] == nil then
							mainDist[nk] = mainDist[k] + 1;
							qd[#qd + 1] = nk;
						end
					end
				end
			end
		end
	end
	local function isLandType(t)
		return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
	end
	guardedPlace = function(islandType, placeFn)
		local real = self.plotTypes;
		-- Connectors (mayTouchMainland) may touch / bridge to the mainland, but still keep islandGap from other islands.
		local connector = mayTouch[islandType];
		local saved = saveMarkers();
		local savedPlaced = {};
		for k, v in pairs(_island_placed or {}) do savedPlaced[k] = v; end
		local old = {};
		local proxy = setmetatable({}, {
			__index = real,
			__newindex = function(_, i, v)
				if old[i] == nil then old[i] = { real[i] }; end
				real[i] = v;
			end,
		});
		local r1, r2, r3 = placeFn(proxy);
		local bad = false;
		if r1 and not connector then
			for i, o in pairs(old) do
				local nowLand = isLandType(real[i]);
				if pangeaTiles[i] and real[i] ~= o[1] then
					bad = true;
				elseif nowLand and not isLandType(o[1]) then
					local k = i - 1;
					local x0, y0 = k % iW, math.floor(k / iW);
					for d = 1, 6 do
						local nx, ny = GetHexNeighbor(x0, y0, d, iW, iH, wrapX, wrapY);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH and pangeaTiles[ny * iW + nx + 1] then
							bad = true;
							break;
						end
					end
				end
				if bad then break; end
			end
		end
		-- Island spacing: every new land tile keeps policy.islandGap water tiles (default 2) from any land that is
		-- neither mainland nor painted by this placement (earlier islands, stray specks, central-sea islands).
		local islandGap = policy.islandGap or 2;
		if r1 and not bad and islandGap > 0 then
			for i, o in pairs(old) do
				if isLandType(real[i]) and not isLandType(o[1]) then
					local k = i - 1;
					for _, t in ipairs(GetHexDisk(k % iW, math.floor(k / iW), islandGap, iW, iH, wrapX, wrapY)) do
						local ti = t[2] * iW + t[1] + 1;
						if isLandType(real[ti]) and not mainlandTiles[ti] and old[ti] == nil then
							bad = true;
							break;
						end
					end
					if bad then break; end
				end
			end
		end
		if r1 and not bad and maxMainlandGap and not farOk[islandType] and not connector then
			local limit = gapByType[islandType] or maxMainlandGap;
			local near = false;
			for i, o in pairs(old) do
				local md = mainDist[i - 1];
				if isLandType(real[i]) and not isLandType(o[1]) and md ~= nil and md <= limit then
					near = true;
					break;
				end
			end
			if not near then bad = true; end
		end
		if r1 and not bad then
			return r1, r2, r3;
		end
		for i, o in pairs(old) do real[i] = o[1]; end
		if bad then
			gapRejects = gapRejects + 1;
			restoreMarkers(saved);
			_island_placed = savedPlaced;
		end
		return false;
	end
	local odd = firstRingYIsOdd;
	local even = firstRingYIsEven;
	do
		local t1 = (os and os.clock) and os.clock() or 0;
		LekIslandProbeLog("### LekIslandProbe layoutAttempt=" .. tostring(laIsland)
			.. " phase=snapshot_pangeaMask dt=" .. tostring(t1 - tIslandGen0), 2);
	end

	local opts = {
		iW = iW, iH = iH, wrapX = wrapX, wrapY = wrapY,
		landX = 0, landY = 0,
		lakeRidgeCenterX = math.floor(iW / 2),
		lakeRidgeCenterY = math.floor(iH / 2),
		lakeRidgeMaxHexFromCenter = 10,
	};

	local function resetIslandGlobals()
		_island_placed = {};
		_polar_merge_excluded_plots = {};
		_sri_pada_island_plot = nil;
		_solomons_island_mines_plot = nil;
		_solomons_island_nw_type = nil;
		_krakatoa_island_plot = nil;
		_sinai_island_plot = nil;
		_geothermal_island_plot = nil;
		_geothermal_island_nw_type = nil;
		_geothermal_is_krakatoa = nil;
		_geothermal_snow_plot_indices = nil;
		_geothermal_forest_ring_indices = nil;
		-- The central volcano is a JunglePeak stamp with its own wonder: no second JunglePeak on that map.
		if _lek_central_volcano then _island_placed.junglePeak = true; end
	end

	local function restorePlotTypes()
		for i = 1, n do
			self.plotTypes[i] = snapshot[i];
		end
	end

	local function runOnce(TOTAL_BUDGET)
		local tR0 = (os and os.clock) and os.clock() or 0;
		local runOnceDeadline = nil;
		if PANGAEA_RUNONCE_MAX_CLOCK and type(PANGAEA_RUNONCE_MAX_CLOCK) == "number" and PANGAEA_RUNONCE_MAX_CLOCK > 0 and os and os.clock then
			runOnceDeadline = os.clock() + PANGAEA_RUNONCE_MAX_CLOCK;
		end
		local runOnceAbortReason = nil;
		local function runOnceMarkAbort(reason)
			if runOnceAbortReason == nil then
				runOnceAbortReason = reason;
			end
		end
		local function runOnceClockExpired()
			if runOnceDeadline and os and os.clock and os.clock() > runOnceDeadline then
				runOnceMarkAbort("runOnce_clock_cap");
				return true;
			end
			return false;
		end
		restorePlotTypes();
		resetIslandGlobals();

	local excludeSet = {};
	local drafted = {};
	local draftEstimate = 0;

	local function draftAdd(t)
		if t then
			drafted[#drafted + 1] = t;
			if IsMaxOne(t) then excludeSet[t] = true; end
		end
	end

	local numRare = 1 + Map.Rand(4, "");
	local numUncommon = 1 + Map.Rand(6, "");

	for _ = 1, numRare do
		for _try = 1, 50 do
			local pick = DraftOneFromTier(RareIslands, excludeSet);
			if not pick then break; end
			local b = GetBudget(pick);
			if draftEstimate + b <= TOTAL_BUDGET then
				draftAdd(pick);
				draftEstimate = draftEstimate + b;
				break;
			end
		end
	end
	for _ = 1, numUncommon do
		for _try = 1, 50 do
			local pick = DraftOneFromTier(UncommonIslands, excludeSet);
			if not pick then break; end
			local b = GetBudget(pick);
			if draftEstimate + b <= TOTAL_BUDGET then
				draftAdd(pick);
				draftEstimate = draftEstimate + b;
				break;
			end
		end
	end

	table.sort(drafted, function(a, b)
		return GetDraftPriority(a) < GetDraftPriority(b);
	end);
	local draftedSpecials = {};
	local draftedRest = {};
	for _, islandType in ipairs(drafted) do
		if IslandSpecialPhaseTypes[islandType] then
			draftedSpecials[#draftedSpecials + 1] = islandType;
		else
			draftedRest[#draftedRest + 1] = islandType;
		end
	end
	local tAfterDraft = (os and os.clock) and os.clock() or 0;

	local islandsPlaced = 0;
	local rollIslandSequence = {};
	local rollIslandCounts = {};
	runTypeCounts = {};
	local lastTryOceanSeedX, lastTryOceanSeedY;
	local lastTryLandX, lastTryLandY;
	local lastPaintBefore = nil;
	local tileOwnerByIndex = {};

	local function islandTilesLogEnabled()
		if LekMapgenChannelEnabled then
			return LekMapgenChannelEnabled("islands_tiles");
		end
		return LekMapgenLogsEnabled and LekMapgenLogsEnabled();
	end

	local function emitIslandLogLine(msg)
		if LekMapgenPrintAndDiagFile then
			LekMapgenPrintAndDiagFile(msg);
		else
			print(msg);
			pcall(function()
				if LekMapgenDiagLogAppend then
					LekMapgenDiagLogAppend(msg);
				end
			end);
		end
	end

	local function isIslandLandPlotType(t)
		return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
	end

	local function islandPlotTypeTag(t)
		if t == PlotTypes.PLOT_MOUNTAIN then
			return "mtn";
		elseif t == PlotTypes.PLOT_HILLS then
			return "hills";
		elseif t == PlotTypes.PLOT_LAND then
			return "land";
		end
		return "other";
	end

	local function captureIslandLandState()
		local s = {};
		for i = 1, n do
			local t = self.plotTypes[i];
			if isIslandLandPlotType(t) then
				s[i] = t;
			end
		end
		return s;
	end

	-- Lightweight owner tracking: land mask diff after each successful placement.
	local trackOn = LekIslandMapEnabled();
	local trackLand = trackOn and captureIslandLandState() or nil;
	local trackPlacements = {};
	local trackOwner = {};
	local function trackPlacement(islandType, seq, atX, atY)
		if not trackOn then return; end
		local pl = { seq = seq, type = islandType, atX = atX, atY = atY, tiles = {}, carved = 0 };
		for i = 1, n do
			local isL = isIslandLandPlotType(self.plotTypes[i]);
			if isL and not trackLand[i] then
				trackOwner[i - 1] = seq;
				pl.tiles[#pl.tiles + 1] = i - 1;
				trackLand[i] = self.plotTypes[i];
			elseif (not isL) and trackLand[i] then
				pl.carved = pl.carved + 1;
				trackLand[i] = nil;
				trackOwner[i - 1] = nil;
			end
		end
		trackPlacements[#trackPlacements + 1] = pl;
	end

	local function markIslandPaintBefore()
		if islandTilesLogEnabled() then
			lastPaintBefore = captureIslandLandState();
		else
			lastPaintBefore = nil;
		end
	end

	local function logIslandPaintedTiles(islandType, seq)
		if not lastPaintBefore or not islandTilesLogEnabled() then
			lastPaintBefore = nil;
			return;
		end
		local before = lastPaintBefore;
		lastPaintBefore = nil;
		local added = {};
		for i = 1, n do
			local t = self.plotTypes[i];
			if isIslandLandPlotType(t) and before[i] == nil then
				local i0 = i - 1;
				local x = i0 % iW;
				local y = math.floor(i0 / iW);
				added[#added + 1] = { x = x, y = y, t = t, i = i };
			end
		end
		table.sort(added, function(a, b)
			if a.y ~= b.y then
				return a.y < b.y;
			end
			return a.x < b.x;
		end);
		local minX, maxX, minY, maxY = nil, nil, nil, nil;
		for _, row in ipairs(added) do
			local prev = tileOwnerByIndex[row.i];
			tileOwnerByIndex[row.i] = islandType;
			if minX == nil or row.x < minX then minX = row.x; end
			if maxX == nil or row.x > maxX then maxX = row.x; end
			if minY == nil or row.y < minY then minY = row.y; end
			if maxY == nil or row.y > maxY then maxY = row.y; end
			local prevPart = "";
			if prev ~= nil then
				prevPart = " overwrite=" .. tostring(prev);
			end
			emitIslandLogLine("### LekIslandTile runId=" .. tostring(_lek_run_id or "na")
				.. " layoutAttempt=" .. tostring(laIsland)
				.. " outerAttempt=" .. tostring(outerIsland)
				.. " budgetTry=" .. tostring(islandRunTry)
				.. " seq=" .. tostring(seq)
				.. " type=" .. tostring(islandType)
				.. " xy=" .. tostring(row.x) .. "," .. tostring(row.y)
				.. " plot=" .. islandPlotTypeTag(row.t)
				.. prevPart);
		end
		emitIslandLogLine("### LekIslandFootprint runId=" .. tostring(_lek_run_id or "na")
			.. " layoutAttempt=" .. tostring(laIsland)
			.. " outerAttempt=" .. tostring(outerIsland)
			.. " budgetTry=" .. tostring(islandRunTry)
			.. " seq=" .. tostring(seq)
			.. " type=" .. tostring(islandType)
			.. " nLand=" .. tostring(#added)
			.. " bbox=" .. tostring(minX or "na") .. "," .. tostring(minY or "na")
			.. "-" .. tostring(maxX or "na") .. "," .. tostring(maxY or "na"));
	end

	-- Fired only when a placer returns true (budget retries may wipe later; match final LekIslandRollSummary).
	local function recordIslandPlaced(islandType, atX, atY, nearLandX, nearLandY)
		rollIslandSequence[#rollIslandSequence + 1] = islandType;
		rollIslandCounts[islandType] = (rollIslandCounts[islandType] or 0) + 1;
		runTypeCounts[islandType] = (runTypeCounts[islandType] or 0) + 1;
		local seq = #rollIslandSequence;
		trackPlacement(islandType, seq, atX, atY);
		local atPart = " at=na";
		if atX ~= nil and atY ~= nil then
			atPart = " at=" .. tostring(atX) .. "," .. tostring(atY);
		end
		local nearPart = "";
		if nearLandX ~= nil and nearLandY ~= nil then
			nearPart = " nearLand=" .. tostring(nearLandX) .. "," .. tostring(nearLandY);
		end
		emitIslandLogLine("### LekIslandPlaced runId=" .. tostring(_lek_run_id or "na")
			.. " layoutAttempt=" .. tostring(laIsland)
			.. " outerAttempt=" .. tostring(outerIsland)
			.. " budgetTry=" .. tostring(islandRunTry)
			.. " seq=" .. tostring(seq)
			.. " type=" .. tostring(islandType)
			.. atPart
			.. nearPart);
		logIslandPaintedTiles(islandType, seq);
	end
	local function logRollIslandSummary(spent, target)
		local keys = {};
		for k in pairs(rollIslandCounts) do
			keys[#keys + 1] = k;
		end
		table.sort(keys);
		local countParts = {};
		for _, k in ipairs(keys) do
			countParts[#countParts + 1] = tostring(k) .. "=" .. tostring(rollIslandCounts[k]);
		end
		local summary = "### LekIslandRollSummary runId=" .. tostring(_lek_run_id or "na")
			.. " layoutAttempt=" .. tostring(laIsland)
			.. " outerAttempt=" .. tostring(outerIsland)
			.. " budgetTry=" .. tostring(islandRunTry)
			.. " budgetTarget=" .. tostring(target)
			.. " spent=" .. string.format("%.3f", spent or 0)
			.. " placedN=" .. tostring(#rollIslandSequence)
			.. " order=" .. table.concat(rollIslandSequence, ",")
			.. " countsByType=" .. table.concat(countParts, ";");
		emitIslandLogLine(summary);
	end
	local function tryOneSpot(forceType, attempt, overrideSpot)
		local x, y;
		if overrideSpot and type(overrideSpot) == "table" and #overrideSpot >= 2 then
			x, y = overrideSpot[1], overrideSpot[2];
		else
			x = Map.Rand(iW, "");
			y = nil;
		end
		if y == nil then
			if forceType == "junglePeak" then
				if attempt and attempt >= 25 then
					y = 3 + Map.Rand((iH - 6), "");
				else
					local bandHeight = 6 + Map.Rand(5, "");
					local centerY = math.floor(iH / 2);
					local jungleMin = math.max(2, centerY - math.floor(bandHeight / 2));
					local jungleMax = math.min(iH - 3, jungleMin + bandHeight - 1);
					y = jungleMin + Map.Rand(math.max(1, jungleMax - jungleMin + 1), "");
				end
			elseif forceType == "solomonsMinesIsland" then
				if attempt and attempt >= 60 then
					y = 3 + Map.Rand((iH - 6), "");
				else
					local bandHeight = 5 + Map.Rand(4, "");
					if Map.Rand(2, "") == 0 then
						local dMin = math.max(2, math.floor(0.22 * iH));
						local dMax = math.min(iH - 3, math.floor(0.34 * iH));
						if dMax >= dMin then
							local c0 = dMin + Map.Rand(math.max(1, dMax - dMin + 1), "");
							local lo = math.max(2, c0 - math.floor(bandHeight / 2));
							local hi = math.min(iH - 3, lo + bandHeight - 1);
							y = lo + Map.Rand(math.max(1, hi - lo + 1), "");
						else
							y = 3 + Map.Rand((iH - 6), "");
						end
					else
						local dMin = math.max(2, math.floor(0.66 * iH));
						local dMax = math.min(iH - 3, math.floor(0.78 * iH));
						if dMax >= dMin then
							local c0 = dMin + Map.Rand(math.max(1, dMax - dMin + 1), "");
							local lo = math.max(2, c0 - math.floor(bandHeight / 2));
							local hi = math.min(iH - 3, lo + bandHeight - 1);
							y = lo + Map.Rand(math.max(1, hi - lo + 1), "");
						else
							y = 3 + Map.Rand((iH - 6), "");
						end
					end
				end
			elseif forceType == "geothermalIsland" then
				if attempt and attempt >= 25 then
					y = 3 + Map.Rand((iH - 6), "");
				else
					if iH > 8 then
						if Map.Rand(2, "") == 0 then
							y = 3 + Map.Rand(2, "");
						else
							y = (iH - 4) + Map.Rand(2, "");
						end
					else
						y = 3 + Map.Rand(math.max(1, iH - 6), "");
					end
				end
			elseif forceType == "shoreSineChain" then
				-- Bias to polar ocean bands just off the ring coasts (EW chain needs room).
				if attempt and attempt >= 40 then
					y = 3 + Map.Rand((iH - 6), "");
				else
					local southLo, southHi = 3, math.min(12, math.floor(iH * 0.28));
					local northLo = math.max(iH - 13, math.floor(iH * 0.72));
					local northHi = iH - 4;
					if Map.Rand(2, "") == 0 and southHi >= southLo then
						y = southLo + Map.Rand(math.max(1, southHi - southLo + 1), "");
					elseif northHi >= northLo then
						y = northLo + Map.Rand(math.max(1, northHi - northLo + 1), "");
					else
						y = 3 + Map.Rand((iH - 6), "");
					end
				end
			elseif forceType == "sinaiIsland" then
				if attempt and attempt >= 50 then
					y = 3 + Map.Rand((iH - 6), "");
				else
					local northMin = math.max(2, math.floor(0.22 * iH));
					local northMax = math.min(iH - 3, math.floor(0.36 * iH));
					local southMin = math.max(2, math.floor(0.64 * iH));
					local southMax = math.min(iH - 3, math.floor(0.78 * iH));
					if Map.Rand(2, "") == 0 and northMax >= northMin then
						y = northMin + Map.Rand(math.max(1, northMax - northMin + 1), "");
					elseif southMax >= southMin then
						y = southMin + Map.Rand(math.max(1, southMax - southMin + 1), "");
					else
						y = northMin + Map.Rand(math.max(1, northMax - northMin + 1), "");
					end
				end
			else
				y = 3 + Map.Rand((iH - 6), "");
			end
		end
		if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
		local plotIndex = y * iW + x + 1;
		if self.plotTypes[plotIndex] ~= PlotTypes.PLOT_OCEAN then return false; end
		-- Keep ocean islands out of the painted central inland sea (it has its own islands).
		if _lek_central_sea_plots and _lek_central_sea_plots[plotIndex - 1] then return false; end
		local islLandInRing, landX, landY, landPlot = 0, 0, 0, 0;
		local spotOpts = { iW = iW, iH = iH, wrapX = wrapX, wrapY = wrapY, landX = 0, landY = 0 };
		if attempt then spotOpts.attempt = attempt; end
		for ripple_radius = 1, 6 do
			local currentX = x - ripple_radius;
			local currentY = y;
			for direction_index = 1, 6 do
				for plot_to_handle = 1, ripple_radius do
					local plot_adjustments;
					if currentY / 2 > math.floor(currentY / 2) then
						plot_adjustments = odd[direction_index];
					else
						plot_adjustments = even[direction_index];
					end
					local nextX = currentX + plot_adjustments[1];
					local nextY = currentY + plot_adjustments[2];
					if wrapX == false and (nextX < 0 or nextX >= iW) then
					elseif wrapY == false and (nextY < 0 or nextY >= iH) then
					else
						local realX = nextX;
						local realY = nextY;
						if wrapX then realX = realX % iW; end
						if wrapY then realY = realY % iH; end
					local scanPlotIndex = realY * iW + realX + 1;
					if self.plotTypes[scanPlotIndex] ~= PlotTypes.PLOT_OCEAN then
						islLandInRing = ripple_radius;
						landPlot = scanPlotIndex;
						landX = realX;
						landY = realY;
						break;
					end
						currentX, currentY = nextX, nextY;
					end
				end
				if islLandInRing ~= 0 then break; end
			end
			if islLandInRing ~= 0 then break; end
		end
		if islLandInRing == 0 or self.plotTypes[landPlot] == PlotTypes.PLOT_OCEAN then return false; end
		-- Anchor to the mainland only: if the nearest land is a stray speck or another island, reject
		-- (stops islands leapfrogging off each other away from the pangaea).
		if not mainlandTiles[landPlot] then return false; end
		if forceType == "clusterOfTiny" and islLandInRing > 0 and attempt ~= nil and attempt < 50 then
			if islLandInRing >= 5 then return false; end
			if islLandInRing >= 4 and Map.Rand(100, "") < 78 then return false; end
			if islLandInRing == 3 and Map.Rand(100, "") < 35 then return false; end
		end
		spotOpts.landX = landX;
		spotOpts.landY = landY;
		spotOpts.nearPangea = mainlandTiles[landPlot];  -- landPlot is 1-based
		spotOpts.mainland = mainlandTiles;
		lastTryOceanSeedX, lastTryOceanSeedY = x, y;
		lastTryLandX, lastTryLandY = landX, landY;
		return TryPlaceIsland(self.plotTypes, x, y, islLandInRing, spotOpts, forceType);
	end

	local spentBudget = 0;
	local function placeAndCount(islandType, attemptsCap)
		local placed = false;
		local attempts = 0;
		local cap = attemptsCap or 180;
		while not placed and attempts < cap do
			if runOnceClockExpired() then
				break;
			end
			markIslandPaintBefore();
			placed = tryOneSpot(islandType, attempts);
			attempts = attempts + 1;
		end
		if placed then
			recordIslandPlaced(islandType, lastTryOceanSeedX, lastTryOceanSeedY, lastTryLandX, lastTryLandY);
			spentBudget = spentBudget + GetBudget(islandType);
			islandsPlaced = islandsPlaced + 1;
		else
			lastPaintBefore = nil;
		end
		return placed;
	end

	dbg2("### GeneratePangaeaIslands: placing special-phase drafted islands ###");

	local function placeDraftedOne(islandType)
		if runOnceClockExpired() then
			return;
		end
		dbg2("### placing: " .. tostring(islandType) .. " ###");
		if islandType == "polarMerge" then
			markIslandPaintBefore();
			local ok, px, py = TryPlacePolarMerge(self.plotTypes, opts);
			if ok then
				recordIslandPlaced("polarMerge", px, py);
				spentBudget = spentBudget + GetBudget(islandType);
				islandsPlaced = islandsPlaced + 1;
			else
				lastPaintBefore = nil;
			end
		--[[ elseif islandType == "fjordPeninsula" then
			local placedFjord = false;
			for _fj = 1, 45 do
				if TryPlaceFjordPeninsulaIsland(self.plotTypes, opts) then
					placedFjord = true;
					break;
				end
			end
			if placedFjord then
				spentBudget = spentBudget + GetBudget(islandType);
				islandsPlaced = islandsPlaced + 1;
			end
		]]
		elseif islandType == "steppingStone" then
			markIslandPaintBefore();
			local ok, px, py = guardedPlace("steppingStone", function(pt)
				return TryPlaceSteppingStoneIsland(pt, opts);
			end);
			if ok then
				recordIslandPlaced("steppingStone", px, py);
				spentBudget = spentBudget + GetBudget(islandType);
				islandsPlaced = islandsPlaced + 1;
			else
				lastPaintBefore = nil;
			end
		elseif islandType == "wrapSoftLandbridge" then
			local placedBridge = false;
			local bx, by = nil, nil;
			for _wb = 1, 28 do
				if runOnceClockExpired() then
					break;
				end
				markIslandPaintBefore();
				local ok, px, py = TryPlaceWrapSoftLandbridge(self.plotTypes, opts);
				if ok then
					placedBridge = true;
					bx, by = px, py;
					break;
				else
					lastPaintBefore = nil;
				end
			end
			if placedBridge then
				recordIslandPlaced("wrapSoftLandbridge", bx, by);
				spentBudget = spentBudget + GetBudget(islandType);
				islandsPlaced = islandsPlaced + 1;
			end
		elseif islandType == "mainlandRidge" then
			markIslandPaintBefore();
			local ok, px, py = TryPlaceMainlandRidge(self.plotTypes, opts);
			if ok then
				recordIslandPlaced("mainlandRidge", px, py);
				spentBudget = spentBudget + GetBudget(islandType);
				islandsPlaced = islandsPlaced + 1;
			else
				lastPaintBefore = nil;
			end
		elseif islandType == "lakeRidge" then
			markIslandPaintBefore();
			local ok, px, py = TryPlaceLakeRidge(self.plotTypes, opts);
			if ok then
				recordIslandPlaced("lakeRidge", px, py);
				spentBudget = spentBudget + GetBudget(islandType);
				islandsPlaced = islandsPlaced + 1;
			else
				lastPaintBefore = nil;
			end
		elseif IslandTypePlace[islandType] then
			local maxAttempts = 180;
			if islandType == "solomonsMinesIsland" then
				maxAttempts = 300;
			elseif islandType == "shoreSineChain" then
				maxAttempts = 280;
			end
			placeAndCount(islandType, maxAttempts);
		else
			dbg2("### placeDraftedOne: no placer for " .. tostring(islandType) .. " ###");
			if LekPipelineFlow then
				LekPipelineFlow("islands_no_placer", tostring(islandType));
			end
		end
	end

	for _, islandType in ipairs(draftedSpecials) do
		placeDraftedOne(islandType);
	end
	if LekPipelineFlow then
		LekPipelineFlow("islands_specials_done",
			"n=" .. tostring(#draftedSpecials)
			.. " placed=" .. tostring(islandsPlaced)
			.. " spent=" .. string.format("%.2f", spentBudget));
	end

	local commonPass = 0;
	if not skipCommonFill then
		dbg2("### GeneratePangaeaIslands: early dot/strip after specials (target budget "
			.. tostring(PANGAEA_ISLAND_DOT_STRIP_EARLY_BUDGET or 2) .. ") ###");
		local earlyTarget = PANGAEA_ISLAND_DOT_STRIP_EARLY_BUDGET or 2;
		local earlySpent = 0;
		while earlySpent + 0.001 < earlyTarget
			and spentBudget + 0.004 < TOTAL_BUDGET do
			if runOnceClockExpired() then
				break;
			end
			local remainingEarly = earlyTarget - earlySpent;
			local islandType;
			if remainingEarly < 0.39 then
				islandType = "dot";
			else
				islandType = DraftOneFromTier(DotStripEarlyPool, {});
			end
			if not islandType then
				break;
			end
			local placed = false;
			for i = 1, PANGAEA_COMMON_SMALL_ISLAND_TRIES_LOOSE do
				if (i % 40 == 0) and runOnceClockExpired() then
					break;
				end
				markIslandPaintBefore();
				placed = tryOneSpot(islandType, nil, nil);
				if placed then
					break;
				else
					lastPaintBefore = nil;
				end
			end
			if placed then
				recordIslandPlaced(islandType, lastTryOceanSeedX, lastTryOceanSeedY, lastTryLandX, lastTryLandY);
				local b = GetBudget(islandType);
				earlySpent = earlySpent + b;
				spentBudget = spentBudget + b;
				islandsPlaced = islandsPlaced + 1;
			else
				break;
			end
		end
	end

	dbg2("### GeneratePangaeaIslands: placing remaining drafted islands ###");
	for _, islandType in ipairs(draftedRest) do
		placeDraftedOne(islandType);
	end

	local tAfterDraftedPlaced = (os and os.clock) and os.clock() or 0;

	if skipCommonFill then
		dbg2("### GeneratePangaeaIslands: common fill skipped (policy.skipCommonFill) ###");
	else
		dbg2("### GeneratePangaeaIslands: drafted done, filling commons (until spent >= " .. TOTAL_BUDGET .. ", est at draft was " .. draftEstimate .. ") ###");
		local idleCommonPasses = 0;
		while spentBudget + 0.004 < TOTAL_BUDGET and commonPass < PANGAEA_COMMON_FILL_MAX_PASSES do
			if runOnceClockExpired() then
				break;
			end
			commonPass = commonPass + 1;
			if commonPass == 1 or commonPass % 200 == 0 then
				dbg2("### common fill pass " .. commonPass .. ", spent " .. spentBudget .. "/" .. TOTAL_BUDGET .. " ###");
			end
			local remaining = TOTAL_BUDGET - spentBudget;
			local islandType;
			if remaining <= 0.15 then
				islandType = "dot";
			elseif remaining <= 0.45 then
				islandType = (Map.Rand(2, "") == 0) and "dot" or "pebble";
			elseif remaining <= 0.95 and Map.Rand(100, "") < 55 then
				islandType = (Map.Rand(2, "") == 0) and "pebble" or "splinteredCliffsTiny";
			else
				islandType = DraftOneFromTier(CommonIslands, {});
			end
			if typeCapped(islandType) then islandType = "pebble"; end
			if islandType then
				local placed = false;
				local tries = (remaining <= 0.55) and PANGAEA_COMMON_SMALL_ISLAND_TRIES_TIGHT or PANGAEA_COMMON_SMALL_ISLAND_TRIES_LOOSE;
				for i = 1, tries do
					if (i % 40 == 0) and runOnceClockExpired() then
						break;
					end
					markIslandPaintBefore();
					placed = tryOneSpot(islandType, nil, nil);
					if placed then
						break;
					else
						lastPaintBefore = nil;
					end
				end
				if placed then
					recordIslandPlaced(islandType, lastTryOceanSeedX, lastTryOceanSeedY, lastTryLandX, lastTryLandY);
					spentBudget = spentBudget + GetBudget(islandType);
					islandsPlaced = islandsPlaced + 1;
					idleCommonPasses = 0;
				else
					idleCommonPasses = idleCommonPasses + 1;
					if idleCommonPasses >= PANGAEA_COMMON_FILL_IDLE_BREAK then
						dbg2("### common fill stall break at " .. spentBudget .. "/" .. TOTAL_BUDGET .. " ###");
						break;
					end
				end
			end
		end
	end
	local tAfterCommonFill = (os and os.clock) and os.clock() or 0;
		local runTotal = tAfterCommonFill - tR0;
		LekIslandProbeLog("### LekIslandProbe layoutAttempt=" .. tostring(laIsland)
			.. " runOnce budgetTarget=" .. tostring(TOTAL_BUDGET)
			.. " retryTry=" .. tostring(islandRunTry) .. "/" .. tostring(maxTriesPerBudget)
			.. " draft_dt=" .. tostring(tAfterDraft - tR0)
			.. " shore_dt=0"
			.. " draftedPlace_dt=" .. tostring(tAfterDraftedPlaced - tAfterDraft)
			..(" commonFill_dt=" .. tostring(tAfterCommonFill - tAfterDraftedPlaced))
			.. " commonPasses=" .. tostring(commonPass)
			.. " islandsPlaced=" .. tostring(islandsPlaced)
			.. " spentBudget=" .. string.format("%.3f", spentBudget)
			.. " runOnce_total_dt=" .. tostring(runTotal)
			.. " abort=" .. tostring(runOnceAbortReason or "none"), 3);
		local fillPct = LekIslandBudgetFillPct(spentBudget, TOTAL_BUDGET);
		local shortfall = math.max(0, TOTAL_BUDGET - spentBudget);
		LekIslandProbeLog("### LekIslandProbe runOnce_summary layoutAttempt=" .. tostring(laIsland)
			.. " target=" .. tostring(TOTAL_BUDGET)
			.. " spent=" .. string.format("%.3f", spentBudget)
			.. " fillPct=" .. string.format("%.1f", fillPct)
			.. " shortfall=" .. string.format("%.3f", shortfall)
			.. " islandsPlaced=" .. tostring(islandsPlaced)
			.. " dt=" .. string.format("%.2f", runTotal)
			.. " commonPasses=" .. tostring(commonPass)
			.. " abort=" .. tostring(runOnceAbortReason or "none"), 2);
		if runOnceAbortReason then
			tallyRunOnceAborts = tallyRunOnceAborts + 1;
		end

		logRollIslandSummary(spentBudget, TOTAL_BUDGET);

		lastRunTrack = trackOn and { placements = trackPlacements, owner = trackOwner } or nil;
		return islandsPlaced, spentBudget;
	end

	if not budgetRetry then
		islandRunBudget = PANGAEA_ISLAND_TOTAL_BUDGET;
		islandRunTry = 1;
		local ip, sp = runOnce(PANGAEA_ISLAND_TOTAL_BUDGET);
		dbg2("### GeneratePangaeaIslands: islands placed = " .. tostring(ip) .. " spent " .. string.format("%.2f", sp) .. "/" .. PANGAEA_ISLAND_TOTAL_BUDGET .. " ###");
		do
			local tEnd = (os and os.clock) and os.clock() or 0;
			LekIslandProbeLog("### LekIslandProbe layoutAttempt=" .. tostring(laIsland)
				.. " exit=no_budget_retry ok=1 generatePangaeaIslands_total_dt=" .. tostring(tEnd - tIslandGen0), 1);
			LekIslandProbeLog("### LekIslandProbe budgetOutcome layoutAttempt=" .. tostring(laIsland)
				.. " path=no_budget_retry islandsPlaced=" .. tostring(ip)
				.. " spent=" .. string.format("%.3f", sp)
				.. " nominalTarget=" .. tostring(nominalBudget)
				.. " fillPctOfNominal=" .. string.format("%.1f", LekIslandBudgetFillPct(sp, nominalBudget))
				.. " runOnceAbortsThisGen=" .. tostring(tallyRunOnceAborts), 2);
			LekIslandProbeLog("### LekIslandProbe innerSuccessProfile layoutAttempt=" .. tostring(laIsland)
				.. " outer=" .. tostring(outerIsland)
				.. " acceptedTier=" .. tostring(nominalBudget)
				.. " winningTry=1"
				.. " cumulativeRunOnceCalls=1"
				.. " tierDropsBeforeOk=0"
				.. " relaxBudgetTier=n/a_path"
				.. " note=single_runOnce_no_budget_retry", 2);
		end
		_lek_island_track = lastRunTrack;
		return ip, true;
	end

	local b = PANGAEA_ISLAND_TOTAL_BUDGET;
	local budgetSlack = 0.06;
	local cumulativeRunOnce = 0;
	local nominalRunOnceCount = 0;
	local island_nominal_tier_abort_no_relax = false;
	while b >= budgetFloor do
		islandRunBudget = b;
		local tierClock0 = (os and os.clock) and os.clock() or 0;
		local bestSpentTry = 0;
		local nominalTierLoopExit = nil;
		for _t = 1, maxTriesPerBudget do
			islandRunTry = _t;
			if b == nominalBudget and type(maxRunOnceNominal) == "number" and maxRunOnceNominal > 0
				and nominalRunOnceCount >= maxRunOnceNominal then
				nominalTierLoopExit = "nominal_runOnce_cap";
				LekIslandProbeLog("### LekIslandProbe budgetTierCap budget=" .. tostring(b)
					.. " reason=nominal_runOnce_cap triesUsed=" .. tostring(_t - 1)
					.. " cap=" .. tostring(maxRunOnceNominal), 2);
				break;
			end
			cumulativeRunOnce = cumulativeRunOnce + 1;
			if b == nominalBudget then
				nominalRunOnceCount = nominalRunOnceCount + 1;
			end
			local tTry0 = (os and os.clock) and os.clock() or 0;
			local ip, sp = runOnce(b);
			local tryDt = (os and os.clock) and (os.clock() - tTry0) or 0;
			if sp > bestSpentTry then
				bestSpentTry = sp;
			end
			if sp + budgetSlack >= b then
				dbg2("### GeneratePangaeaIslands: islands placed = " .. tostring(ip) .. ", budget target " .. b .. " met ###");
				do
					local tEnd = (os and os.clock) and os.clock() or 0;
					LekIslandProbeLog("### LekIslandProbe layoutAttempt=" .. tostring(laIsland)
						.. " exit=budget_met budgetFinal=" .. tostring(b)
						.. " spentFinal=" .. string.format("%.3f", sp)
						.. " islandsPlaced=" .. tostring(ip)
						.. " generatePangaeaIslands_total_dt=" .. tostring(tEnd - tIslandGen0), 1);
					LekIslandProbeLog("### LekIslandProbe budgetOutcome layoutAttempt=" .. tostring(laIsland)
						.. " path=budget_retry_success acceptedTier=" .. tostring(b)
						.. " islandsPlaced=" .. tostring(ip)
						.. " spent=" .. string.format("%.3f", sp)
						.. " fillPctOfAcceptedTier=" .. string.format("%.1f", LekIslandBudgetFillPct(sp, b))
						.. " nominalTarget=" .. tostring(nominalBudget)
						.. " fillPctOfNominal=" .. string.format("%.1f", LekIslandBudgetFillPct(sp, nominalBudget))
						.. " tiersBelowNominal=" .. tostring(math.max(0, nominalBudget - b))
						.. " runOnceAbortsThisGen=" .. tostring(tallyRunOnceAborts)
						.. " tierClockStops=" .. tostring(tierClockStopCount)
						.. " fastFailStops=" .. tostring(fastFailStopCount), 2);
					LekIslandProbeLog("### LekIslandProbe innerSuccessProfile layoutAttempt=" .. tostring(laIsland)
						.. " outer=" .. tostring(outerIsland)
						.. " acceptedTier=" .. tostring(b)
						.. " winningTry=" .. tostring(_t)
						.. " cumulativeRunOnceCalls=" .. tostring(cumulativeRunOnce)
						.. " tierDropsBeforeOk=" .. tostring(math.max(0, nominalBudget - b))
						.. " nominalRunOnceCallsSession=" .. tostring(nominalRunOnceCount)
						.. " relaxBudgetTier=" .. (relaxBudgetTier and "1" or "0"), 2);
				end
				_lek_island_track = lastRunTrack;
				return ip, true;
			end
			if sp > globalBestSpent then
				globalBestSpent = sp;
			end
			LekIslandProbeLog("### LekIslandProbe budgetMiss budget=" .. tostring(b)
				.. " try=" .. tostring(_t) .. "/" .. tostring(maxTriesPerBudget)
				.. " spent=" .. string.format("%.3f", sp)
				.. " fillPctOfTier=" .. string.format("%.1f", LekIslandBudgetFillPct(sp, b))
				.. " try_dt=" .. string.format("%.2f", tryDt)
				.. " bestSoFar=" .. string.format("%.3f", bestSpentTry)
				.. " gapToTier=" .. string.format("%.3f", math.max(0, b - budgetSlack - sp)), 2);
			if PANGAEA_BUDGET_TIER_MAX_CLOCK and type(PANGAEA_BUDGET_TIER_MAX_CLOCK) == "number" and PANGAEA_BUDGET_TIER_MAX_CLOCK > 0 and os and os.clock then
				if (os.clock() - tierClock0) > PANGAEA_BUDGET_TIER_MAX_CLOCK then
					nominalTierLoopExit = "tier_clock_cap";
					tierClockStopCount = tierClockStopCount + 1;
					LekIslandProbeLog("### LekIslandProbe budgetTierCap budget=" .. tostring(b)
						.. " reason=tier_clock_cap triesUsed=" .. tostring(_t)
						.. " tier_dt=" .. string.format("%.2f", os.clock() - tierClock0)
						.. " bestSpent=" .. string.format("%.3f", bestSpentTry)
						.. " tierFillPct=" .. string.format("%.1f", LekIslandBudgetFillPct(bestSpentTry, b)), 2);
					break;
				end
			end
			if PANGAEA_BUDGET_FAST_FAIL_TRIES and type(PANGAEA_BUDGET_FAST_FAIL_TRIES) == "number" and PANGAEA_BUDGET_FAST_FAIL_TRIES > 0
				and type(PANGAEA_BUDGET_FAST_FAIL_SPENT_FRAC) == "number" and PANGAEA_BUDGET_FAST_FAIL_SPENT_FRAC > 0
				and _t >= PANGAEA_BUDGET_FAST_FAIL_TRIES then
				if bestSpentTry + budgetSlack < b * PANGAEA_BUDGET_FAST_FAIL_SPENT_FRAC then
					nominalTierLoopExit = "fast_fail_hopeless";
					fastFailStopCount = fastFailStopCount + 1;
					LekIslandProbeLog("### LekIslandProbe budgetTierCap budget=" .. tostring(b)
						.. " reason=fast_fail_hopeless bestSpent=" .. string.format("%.3f", bestSpentTry)
						.. " tierFillPct=" .. string.format("%.1f", LekIslandBudgetFillPct(bestSpentTry, b))
						.. " gate=b*" .. tostring(PANGAEA_BUDGET_FAST_FAIL_SPENT_FRAC)
						.. " triesUsed=" .. tostring(_t), 2);
					break;
				end
			end
		end
		if nominalTierLoopExit == nil and b == nominalBudget and islandRunTry >= maxTriesPerBudget then
			nominalTierLoopExit = "max_tries_per_budget";
		end
		if relaxBudgetTier == false and b == nominalBudget then
			island_nominal_tier_abort_no_relax = true;
			LekIslandProbeLog("### LekIslandProbe innerFailProfile layoutAttempt=" .. tostring(laIsland)
				.. " outer=" .. tostring(outerIsland)
				.. " reason=" .. tostring(nominalTierLoopExit or "nominal_tier_exhausted_skip_relax")
				.. " lastBudget=" .. tostring(b)
				.. " cumulativeRunOnceCalls=" .. tostring(cumulativeRunOnce)
				.. " nominalRunOnceCalls=" .. tostring(nominalRunOnceCount)
				.. " tierClockStops=" .. tostring(tierClockStopCount)
				.. " note=next_step_Pangaea_outer_regen", 2);
			break;
		end
		LekIslandProbeLog("### LekIslandProbe tierDrop layoutAttempt=" .. tostring(laIsland)
			.. " fromBudget=" .. tostring(b)
			.. " tierBestSpent=" .. string.format("%.3f", bestSpentTry)
			.. " tierFillPct=" .. string.format("%.1f", LekIslandBudgetFillPct(bestSpentTry, b))
			.. " nominalTarget=" .. tostring(nominalBudget)
			.. " globalBestSpentSoFar=" .. string.format("%.3f", globalBestSpent), 2);
		dbg2("### GeneratePangaeaIslands: budget " .. b .. " incomplete after tier attempts/caps; lowering target ###");
		b = b - 1;
	end

	restorePlotTypes();
	resetIslandGlobals();
	dbg2("### GeneratePangaeaIslands: budget retry exhausted, islands cleared ###");
	do
		local tEnd = (os and os.clock) and os.clock() or 0;
		LekIslandProbeLog("### LekIslandProbe layoutAttempt=" .. tostring(laIsland)
			.. " exit=budget_retry_exhausted ok=0 generatePangaeaIslands_total_dt=" .. tostring(tEnd - tIslandGen0)
			.. " globalBestSpent=" .. string.format("%.3f", globalBestSpent)
			.. " bestFillPctOfNominal=" .. string.format("%.1f", LekIslandBudgetFillPct(globalBestSpent, nominalBudget))
			.. " runOnceAborts=" .. tostring(tallyRunOnceAborts)
			.. " tierClockStops=" .. tostring(tierClockStopCount)
			.. " fastFailStops=" .. tostring(fastFailStopCount), 1);
		LekIslandProbeLog("### LekIslandProbe budgetOutcome layoutAttempt=" .. tostring(laIsland)
			.. " path=budget_retry_exhausted islandsPlaced=0 spent=0.000"
			.. " nominalTarget=" .. tostring(nominalBudget)
			.. " globalBestSpentSeen=" .. string.format("%.3f", globalBestSpent)
			.. " bestFillPctOfNominal=" .. string.format("%.1f", LekIslandBudgetFillPct(globalBestSpent, nominalBudget))
			.. " runOnceAborts=" .. tostring(tallyRunOnceAborts)
			.. " tierClockStops=" .. tostring(tierClockStopCount)
			.. " fastFailStops=" .. tostring(fastFailStopCount), 2);
		if not island_nominal_tier_abort_no_relax then
			LekIslandProbeLog("### LekIslandProbe innerFailProfile layoutAttempt=" .. tostring(laIsland)
				.. " outer=" .. tostring(outerIsland)
				.. " reason=budget_retry_exhausted_all_tiers"
				.. " cumulativeRunOnceCalls=" .. tostring(cumulativeRunOnce)
				.. " globalBestSpent=" .. string.format("%.3f", globalBestSpent)
				.. " relaxBudgetTier=" .. (relaxBudgetTier and "1" or "0"), 2);
		end
	end
	return 0, false;
end


function GeneratePangaeaIslands(self, genOpts)
	genOpts = genOpts or {};
	return GenerateIslands(self, LekIslands_ResolvePolicy(genOpts.policy), genOpts);
end

------------------------------------------------------------------------------
-- Extra island sources outside the budgeted draft, for the island map log:
-- list of { type = "...", tiles = { plotIndex0, ... } }. Reset per GeneratePlotTypes.
------------------------------------------------------------------------------
_lek_island_extra = {};

function LekRegisterExtraIsland(islandType, tiles)
	if _lek_island_extra == nil then _lek_island_extra = {}; end
	_lek_island_extra[#_lek_island_extra + 1] = { type = islandType, tiles = tiles };
end

------------------------------------------------------------------------------
-- Shore specks: tiny 1-2 tile islands and short strips exactly one water tile off the mainland
-- (hex distance 2 from mainland land, never adjacent to any land). Runs after the budgeted draft;
-- does not count toward the island budget. Counts come from policy.shoreSpecks.
------------------------------------------------------------------------------
function LekPlaceShoreSpecks(self, policy)
	local cfg = policy and policy.shoreSpecks;
	if not cfg then
		return 0, 0;
	end
	local iW, iH = Map.GetGridSize();
	local wrapX = Map:IsWrapX();
	local pt = self.plotTypes;
	local n = iW * iH;
	local function isLand(k) return pt[k + 1] ~= PlotTypes.PLOT_OCEAN; end
	local function nbrs(k)
		local x, y = k % iW, math.floor(k / iW);
		local out = {};
		for d = 1, 6 do
			local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, false);
			if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
				out[#out + 1] = ny * iW + nx;
			end
		end
		return out;
	end

	-- Mainland = biggest land component right now.
	local comp, best, bestN = {}, nil, 0;
	for k = 0, n - 1 do
		if isLand(k) and comp[k] == nil then
			local q, h = { k }, 1;
			comp[k] = k;
			while h <= #q do
				for _, nk in ipairs(nbrs(q[h])) do
					if isLand(nk) and comp[nk] == nil then
						comp[nk] = k;
						q[#q + 1] = nk;
					end
				end
				h = h + 1;
			end
			if #q > bestN then
				bestN = #q;
				best = k;
			end
		end
	end
	if best == nil then
		return 0, 0;
	end
	-- Hex steps from mainland land (only the first few rings are needed).
	local dist, q = {}, {};
	for k = 0, n - 1 do
		if comp[k] == best then
			dist[k] = 0;
			q[#q + 1] = k;
		end
	end
	local h = 1;
	while h <= #q do
		local k = q[h];
		h = h + 1;
		if dist[k] < 3 then
			for _, nk in ipairs(nbrs(k)) do
				if dist[nk] == nil then
					dist[nk] = dist[k] + 1;
					q[#q + 1] = nk;
				end
			end
		end
	end

	local yMin, yMax = 3, iH - 4;
	-- Free = ocean, one water tile off the mainland, no land neighbour except tiles in `own`.
	local islandGap = (policy and policy.islandGap) or 2;
	local function free(k, own)
		if isLand(k) or dist[k] ~= 2 then return false; end
		if _lek_central_sea_plots and _lek_central_sea_plots[k] then return false; end
		local y = math.floor(k / iW);
		if y < yMin or y > yMax then return false; end
		for _, nk in ipairs(nbrs(k)) do
			if isLand(nk) and not (own and own[nk]) then return false; end
		end
		-- Keep islandGap water tiles from any non-mainland land (other islands).
		for _, t in ipairs(GetHexDisk(k % iW, y, islandGap, iW, iH, wrapX, false)) do
			local tk = t[2] * iW + t[1];
			if isLand(tk) and comp[tk] ~= best and not (own and own[tk]) then return false; end
		end
		return true;
	end
	local seeds = {};
	for k = 0, n - 1 do
		if free(k, nil) then seeds[#seeds + 1] = k; end
	end
	if #seeds == 0 then
		return 0, 0;
	end

	local function paint(tiles, hillsPct)
		for _, k in ipairs(tiles) do
			pt[k + 1] = (Map.Rand(100, "shore_speck_hills") < hillsPct) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
	local function randomSeed()
		for _ = 1, 60 do
			local k = seeds[1 + Map.Rand(#seeds, "shore_speck_seed")];
			if free(k, nil) then return k; end
		end
		return nil;
	end

	local wantTiny = (cfg.tinyMin or 0) + Map.Rand((cfg.tinyRange or 0) + 1, "shore_speck_ntiny");
	local wantStrip = (cfg.stripMin or 0) + Map.Rand((cfg.stripRange or 0) + 1, "shore_speck_nstrip");
	local placedTiny, placedStrip = 0, 0;

	for _ = 1, wantStrip do
		for _try = 1, 40 do
			local s0 = randomSeed();
			if not s0 then break; end
			local len = (cfg.stripLenMin or 3) + Map.Rand((cfg.stripLenRange or 2) + 1, "shore_speck_len");
			local tiles, own = { s0 }, { [s0] = true };
			local cur, dir = s0, 1 + Map.Rand(6, "shore_speck_dir");
			while #tiles < len do
				local nextK = nil;
				-- Prefer straight on, then gentle turns; every tile stays one water tile off the shore.
				for _, turn in ipairs({ 0, 1, -1, 2, -2 }) do
					local d = ((dir - 1 + turn) % 6) + 1;
					local x, y = cur % iW, math.floor(cur / iW);
					local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, false);
					if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
						local nk = ny * iW + nx;
						if not own[nk] and free(nk, own) then
							nextK = nk;
							dir = d;
							break;
						end
					end
				end
				if not nextK then break; end
				tiles[#tiles + 1] = nextK;
				own[nextK] = true;
				cur = nextK;
			end
			if #tiles >= (cfg.stripLenMin or 3) then
				paint(tiles, cfg.hillsPct or 55);
				LekRegisterExtraIsland("shoreStrip", tiles);
				placedStrip = placedStrip + 1;
				break;
			end
		end
	end

	for _ = 1, wantTiny do
		local s0 = randomSeed();
		if not s0 then break; end
		local tiles, own = { s0 }, { [s0] = true };
		if Map.Rand(100, "shore_speck_two") < (cfg.twoTilePct or 50) then
			local opts = {};
			for _, nk in ipairs(nbrs(s0)) do
				if free(nk, own) then opts[#opts + 1] = nk; end
			end
			if #opts > 0 then
				tiles[2] = opts[1 + Map.Rand(#opts, "shore_speck_second")];
			end
		end
		paint(tiles, cfg.hillsPct or 55);
		LekRegisterExtraIsland("shoreTiny", tiles);
		placedTiny = placedTiny + 1;
	end

	if LekPipelineFlow then
		LekPipelineFlow("shore_specks", "tiny=" .. tostring(placedTiny) .. "/" .. tostring(wantTiny)
			.. " strips=" .. tostring(placedStrip) .. "/" .. tostring(wantStrip)
			.. " seeds=" .. tostring(#seeds));
	end
	return placedTiny, placedStrip;
end
