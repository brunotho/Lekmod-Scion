------------------------------------------------------------------------------
-- Lekmap_Islands_FractalPangaea.lua — pangaea-draft policy for Fractal Pangaea.
-- Coastal bonus + inland-sea spray are NOT owned here.
------------------------------------------------------------------------------

function LekIslands_GetFractalPangaeaPolicy()
	return {
		id = "fractal_pangaea",
		channels = {
			pangaeaDraft = true,
			-- coastalBonus / inlandSeaSpray: other modules; listed for docs only
			coastalBonus = true,
			inlandSeaSpray = true,
		},
		-- Extra tiny islands / short strips one water tile off the mainland (not part of the budget).
		shoreSpecks = { tinyMin = 3, tinyRange = 2, twoTilePct = 50, stripMin = 1, stripRange = 1,
			stripLenMin = 3, stripLenRange = 2, hillsPct = 55 },
		-- Only these may touch/merge with the mainland; every other type keeps >= 1 water tile (engine
		-- gap guard undoes violating placements). Non-merge effMax values are +2 so farther seeds exist.
		-- Hard caps per map; islands' closest tile must be within 3 hexes of the mainland (hotspot trail exempt).
		maxPerType = { splinteredCliffsTiny = 2, atollRing = 1 },
		maxMainlandGap = 2,     -- closest tile within 2 hexes = exactly one water tile to the mainland
		-- Fragile multi-piece shapes may sit one tile further out (fewer rejected tries near the coast).
		mainlandGapByType = { splinteredCliffs = 3, shatteredRing = 3, volcanicRing = 3 },
		islandGap = 2,          -- water tiles every island keeps from other islands (0 = off)
		farFromMainlandOk = { hotspotTrail = true },
		mayTouchMainland = { polarMerge = true, wrapSoftLandbridge = true },
		-- Budgets = average tiles / 11.5 (measured 2026-09-26), so one budget point is ~11.5 tiles for every type.
		totalBudget = 8,
		dotStripEarlyBudget = 0, -- early dot/strip phase off (dots were flooding coasts)
		-- Sequential loosening: up to 5 tries at budget 8, then up to 5 at 7, then Pangaea outer redraw.
		budgetRetry = true,
		relaxBudgetTier = true,
		maxRunOnceNominal = 5,
		maxTriesPerBudget = 5,
		budgetFloor = 7,
		site = { basins = "any_ocean" },
		common = {
			{ type = "dot",                  odds = 1, pullBack = 1, effMin = 0, effMax = 2, budget = 0.12 },
			{ type = "pebble",               odds = 2, pullBack = 1, effMin = 0, effMax = 2, budget = 0.37 },
			{ type = "strip",                odds = 2, pullBack = 1, effMin = 0, effMax = 3, budget = 0.38 },
			{ type = "splinteredCliffsTiny", odds = 3, pullBack = 1, effMin = 0, effMax = 3, budget = 0.30 },
		},
		uncommon = {
			{ type = "mountainWall",        odds = 2, pullBack = 0, effMin = 2, effMax = 3, budget = 0.76 },
			{ type = "drownedRidge",        odds = 3, pullBack = 0, effMin = 1, effMax = 4, budget = 0.60 },
			{ type = "splinteredCliffs",    odds = 2, pullBack = 0, effMin = 1, effMax = 4, budget = 1.01, fragile = true },
			{ type = "chunk",               odds = 1, pullBack = 1, effMin = 0, effMax = 4, budget = 0.61 },
			{ type = "barbell",             odds = 4, pullBack = 1, effMin = 0, effMax = 4, budget = 0.61 },
			{ type = "snake",               odds = 4, pullBack = 1, effMin = 1, effMax = 1, budget = 1.05 },
			{ type = "lollipop",            odds = 2, pullBack = 1, effMin = 0, effMax = 4, budget = 0.97 },
			{ type = "wishbone",            odds = 5, pullBack = 1, effMin = 0, effMax = 3, budget = 0.67 },
			{ type = "twinBay",             odds = 1, pullBack = 1, effMin = 0, effMax = 3, budget = 0.89 },
			{ type = "shatteredRing",       odds = 2, pullBack = 1, effMin = 0, effMax = 4, budget = 1.07 },
			{ type = "clusterOfTiny",       odds = 5, pullBack = 1, effMin = 0, effMax = 4, budget = 0.56, fragile = true },
			{ type = "atollRing",           odds = 2, pullBack = 0, effMin = 4, effMax = 5, budget = 0.48 },
		},
		rare = {
			{ type = "polarMerge",          odds = 7, pullBack = 3, effMin = 3, effMax = 5, budget = 4.33 },
			{ type = "steppingStone",       odds = 1, pullBack = 2, effMin = 2, effMax = 6, budget = 0.87 },
			{ type = "crescent",            odds = 0, pullBack = 1, effMin = 0, effMax = 4, budget = 1.57 },
			{ type = "volcanicRing",        odds = 1, pullBack = 1, effMin = 1, effMax = 4, budget = 0.83 },
			{ type = "solomonsMinesIsland", odds = 0, pullBack = 1, effMin = 0, effMax = 4, budget = 1.54 },
			{ type = "sinaiIsland",         odds = 1, pullBack = 1, effMin = 0, effMax = 4, budget = 1.45 },
			{ type = "geothermalIsland",    odds = 2, pullBack = 2, effMin = 2, effMax = 7, budget = 1.77 },
			{ type = "wrapSoftLandbridge",  odds = 2, pullBack = 2, effMin = 2, effMax = 5, budget = 2.95 },
			-- Chains: shore-parallel islet chain (from Equator Ring) and a trail leading away from the coast.
			{ type = "shoreSineChain",      odds = 2, pullBack = 1, effMin = 0, effMax = 7, budget = 0.90 },
			{ type = "hotspotTrail",        odds = 3, pullBack = 0, effMin = 3, effMax = 5, budget = 0.97 },
			{ type = "junglePeak",          odds = 2, pullBack = 1, effMin = 2, effMax = 5, budget = 1.13 },
			{ type = "lakeRidge",           odds = 0, pullBack = 0, effMin = 0, effMax = 2, budget = 0 },
		},
		dotStripEarly = {
			{ type = "dot", odds = 5, budget = 0.12 },
			{ type = "strip", odds = 2, budget = 0.38 },
		},
		specialPhaseTypes = {
			polarMerge = true,
			steppingStone = true,
			wrapSoftLandbridge = true,
			lakeRidge = true,
			geothermalIsland = true,
		},
		namedPriority = {
			polarMerge = 1,
			wrapSoftLandbridge = 2,
		},
		tierBasePriority = {
			rare = 5,
			uncommon = 6,
			common = 8,
		},
	};
end

-- Back-compat alias for older includes / docs.
function LekIslands_GetCompactPolicy()
	return LekIslands_GetFractalPangaeaPolicy();
end
