------------------------------------------------------------------------------
-- Lekmap_Islands_EquatorRing.lua — pangaea-draft policy for equator ring.
-- Coastal bonus (4a) + inland-sea spray (RoundInlandSeas) stay separate.
--
-- v1: shoreSineChain in rare menu; polar basins; no EW-gap / wrap / polarMerge.
-- Budget ~half of Fractal Pangaea (less usable ocean).
------------------------------------------------------------------------------

function LekIslands_GetEquatorRingPolicy()
	return {
		id = "equator_ring",
		channels = {
			pangaeaDraft = true,
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
		totalBudget = 5,
		dotStripEarlyBudget = 0, -- early dot/strip phase off (dots were flooding coasts)
		budgetRetry = false,
		relaxBudgetTier = false,
		maxRunOnceNominal = 2,
		maxTriesPerBudget = 40,
		budgetFloor = 2,
		site = {
			basins = "polar",
		},
		denyTags = {
			"wrap_landbridge",
			"needs_ew_ocean_gap",
			"needs_polar_merge",
		},
		common = {
			{ type = "dot",                  odds = 1, pullBack = 1, effMin = 0, effMax = 2, budget = 0.12 },
			{ type = "pebble",               odds = 3, pullBack = 1, effMin = 0, effMax = 2, budget = 0.37 },
			{ type = "strip",                odds = 3, pullBack = 1, effMin = 0, effMax = 3, budget = 0.38 },
			{ type = "splinteredCliffsTiny", odds = 3, pullBack = 1, effMin = 0, effMax = 3, budget = 0.30 },
		},
		uncommon = {
			{ type = "snake",               odds = 5, pullBack = 1, effMin = 1, effMax = 1, budget = 1.05 },
			{ type = "barbell",             odds = 4, pullBack = 1, effMin = 0, effMax = 4, budget = 0.61 },
			{ type = "wishbone",            odds = 4, pullBack = 1, effMin = 0, effMax = 3, budget = 0.67 },
			{ type = "lollipop",            odds = 2, pullBack = 1, effMin = 0, effMax = 4, budget = 0.97 },
			{ type = "chunk",               odds = 2, pullBack = 1, effMin = 0, effMax = 4, budget = 0.61 },
			{ type = "clusterOfTiny",       odds = 5, pullBack = 1, effMin = 0, effMax = 4, budget = 0.56, fragile = true },
			{ type = "atollRing",           odds = 2, pullBack = 0, effMin = 4, effMax = 5, budget = 0.48 },
			{ type = "splinteredCliffs",    odds = 2, pullBack = 0, effMin = 1, effMax = 4, budget = 1.01, fragile = true },
			{ type = "mountainWall",        odds = 1, pullBack = 0, effMin = 2, effMax = 3, budget = 0.76 },
			{ type = "drownedRidge",        odds = 2, pullBack = 0, effMin = 1, effMax = 4, budget = 0.60 },
			{ type = "twinBay",             odds = 1, pullBack = 1, effMin = 0, effMax = 3, budget = 0.89 },
			{ type = "shatteredRing",       odds = 1, pullBack = 1, effMin = 0, effMax = 4, budget = 1.07 },
		},
		rare = {
			-- ~8–16+ land across 3–5 islets → between crescent (1.50) and volcanicRing (1.71)
			{ type = "shoreSineChain",     odds = 5, pullBack = 1, effMin = 0, effMax = 7, budget = 0.90 },
			{ type = "crescent",            odds = 0, pullBack = 1, effMin = 0, effMax = 4, budget = 1.57 },
			{ type = "volcanicRing",        odds = 1, pullBack = 1, effMin = 1, effMax = 4, budget = 0.83 },
			{ type = "hotspotTrail",        odds = 2, pullBack = 0, effMin = 3, effMax = 5, budget = 0.97 },
			{ type = "junglePeak",          odds = 2, pullBack = 1, effMin = 2, effMax = 5, budget = 1.13 },
			{ type = "sinaiIsland",         odds = 1, pullBack = 1, effMin = 0, effMax = 4, budget = 1.45 },
			{ type = "geothermalIsland",    odds = 1, pullBack = 2, effMin = 2, effMax = 6, budget = 1.77 },
			-- Inland paint only (no new land) — budget 0; rare specialty like crescent
			{ type = "lakeRidge",           odds = 2, pullBack = 0, effMin = 0, effMax = 2, budget = 0 },
			-- denied: polarMerge, wrapSoftLandbridge, steppingStone, EdgeOfWorld, fjordPeninsula
		},
		dotStripEarly = {
			{ type = "dot", odds = 5, budget = 0.12 },
			{ type = "strip", odds = 2, budget = 0.38 },
		},
		specialPhaseTypes = {
			shoreSineChain = true,
			geothermalIsland = true,
			lakeRidge = true,
		},
		namedPriority = {
			shoreSineChain = 1,
			lakeRidge = 2,
		},
		tierBasePriority = {
			rare = 5,
			uncommon = 6,
			common = 8,
		},
	};
end
