------------------------------------------------------------------------------
-- Lekmap_IslandCatalog.lua — type → TryPlace* after XX_island_* includes.
------------------------------------------------------------------------------

LekIslandTypePlace = {
	dot = TryPlaceDotIsland,
	pebble = TryPlacePebbleIsland,
	strip = TryPlaceStripIsland,
	splinteredCliffsTiny = TryPlaceSplinteredCliffsTinyIsland,
	chunk = TryPlaceChunkIsland,
	lollipop = TryPlaceLollipopIsland,
	barbell = TryPlaceBarbellIsland,
	wishbone = TryPlaceWishboneIsland,
	snake = TryPlaceSnakeIsland,
	splinteredMountains = TryPlaceSplinteredMountainsIsland,
	splinteredCliffs = TryPlaceSplinteredCliffsIsland,
	twinBay = TryPlaceTwinBayIslands,
	mountainWall = TryPlaceMountainWallIsland,
	drownedRidge = TryPlaceDrownedRidgeIsland,
	horn = TryPlaceHornIsland,
	shatteredRing = TryPlaceShatteredRingIsland,
	steppingStone = TryPlaceSteppingStoneIsland,
	clusterOfTiny = TryPlaceClusterOfTinyIslands,
	junglePeak = TryPlaceJunglePeakIsland,
	sinaiIsland = TryPlaceSinaiIsland,
	crescent = TryPlaceCrescentIsland,
	shoreSineChain = TryPlaceShoreSineChainIsland,
	solomonsMinesIsland = TryPlaceSolomonsMinesIsland,
	volcanicRing = TryPlaceVolcanicRing,
	geothermalIsland = TryPlaceGeothermalIsland,
	wrapSoftLandbridge = TryPlaceWrapSoftLandbridge,
	hotspotTrail = TryPlaceHotspotTrail,
	atollRing = TryPlaceAtollRingIsland,
	-- polarMerge / lakeRidge: special-cased in Lekmap_IslandEngine (not via this table).
};

-- Optional capability tags for future policy deny filters (engine does not require yet).
LekIslandTypeTags = {
	wrapSoftLandbridge = { "wrap_landbridge", "needs_ew_ocean_gap" },
	polarMerge = { "needs_polar_merge", "needs_deep_ocean" },
	shoreSineChain = { "shore_close" },
	steppingStone = { "needs_deep_ocean" },
	waterRift = { "needs_deep_ocean" },
	geothermalIsland = { "nw_forced", "shore_close" },
	sinaiIsland = { "nw_forced" },
	solomonsMinesIsland = { "nw_forced" },
	volcanicRing = { "nw_forced" },
};
