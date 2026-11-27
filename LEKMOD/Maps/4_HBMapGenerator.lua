------------------------------------------------------------------------------
--	FILE:	 MapGenerator.lua
--	AUTHORS: Shaun Seckman
--	         Bob Thomas
--	PURPOSE: Base logic for map generation.
------------------------------------------------------------------------------
--	Copyright (c) 2010 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

include("4a_HBAssignStartingPlots");

------------------------------------------------------------------------------
--	Various Map utility functions
------------------------------------------------------------------------------
-- Iterate through plots
function Shuffle(t)
	local len = #t;
	local random = Map.Rand;
	for i = 1, len, 1 do
		local k = random(len - 1, "Shuffling Values") + 1;
		t[i], t[k] = t[k], t[i];
	end
end

local _plots = {}; --memoize table of plots
function Plots(sort)
	local _indices = {};
	for i = 1, Map.GetNumPlots(), 1 do
		_indices[i] = i - 1;
	end	
	
	if(sort) then
		sort(_indices);
	end
	
	local cur = 0;
	local it = function()
		cur = cur + 1;
		local index = _indices[cur];
		local plot;
		
		if(index) then
			plot = _plots[index] or Map.GetPlotByIndex(index);
			_plots[index] = plot;
		end
		return index, plot;
	end
	
	return it;
end

function GetCoreMapOptions()
	--[[ All options have a default SortPriority of 0. Lower values will be shown above
	higher values. Negative integers are valid. So the Core Map Options, which should 
	always be at the top of the list, are getting negative values from -99 to -95. Note
	that any set of options with identical SortPriority will be sorted alphabetically. ]]--
	local world_age = {
		Name = "TXT_KEY_MAP_OPTION_WORLD_AGE",
		Values = {
			"TXT_KEY_MAP_OPTION_THREE_BILLION_YEARS",
			"TXT_KEY_MAP_OPTION_FOUR_BILLION_YEARS",
			"TXT_KEY_MAP_OPTION_FIVE_BILLION_YEARS",
			"TXT_KEY_MAP_OPTION_RANDOM",
		},
		DefaultValue = 2,
		SortPriority = -99,
	};
	local temperature = {
		Name = "TXT_KEY_MAP_OPTION_TEMPERATURE",
		Values = {
			"TXT_KEY_MAP_OPTION_COOL",
			"TXT_KEY_MAP_OPTION_TEMPERATE",
			"TXT_KEY_MAP_OPTION_HOT",
			"TXT_KEY_MAP_OPTION_RANDOM",
		},
		DefaultValue = 2,
		SortPriority = -98,
	};
	local rainfall = {
		Name = "TXT_KEY_MAP_OPTION_RAINFALL",
		Values = {
			"TXT_KEY_MAP_OPTION_ARID",
			"TXT_KEY_MAP_OPTION_NORMAL",
			"TXT_KEY_MAP_OPTION_WET",
			"TXT_KEY_MAP_OPTION_RANDOM",
		},
		DefaultValue = 2,
		SortPriority = -97,
	};
	local sea_level = {
		Name = "TXT_KEY_MAP_OPTION_SEA_LEVEL",
		Values = {
			"TXT_KEY_MAP_OPTION_LOW",
			"TXT_KEY_MAP_OPTION_MEDIUM",
			"TXT_KEY_MAP_OPTION_HIGH",
			"TXT_KEY_MAP_OPTION_RANDOM",
		},
		DefaultValue = 2,
		SortPriority = -96,
	};
	local resources = {
		Name = "TXT_KEY_MAP_OPTION_RESOURCES",
		Values = {
			"TXT_KEY_MAP_OPTION_SPARSE",
			"TXT_KEY_MAP_OPTION_STANDARD",
			"TXT_KEY_MAP_OPTION_ABUNDANT",
			"TXT_KEY_MAP_OPTION_LEGENDARY_START",
			"TXT_KEY_MAP_OPTION_STRATEGIC_BALANCE",
			"TXT_KEY_MAP_OPTION_RANDOM",
		},
		DefaultValue = 2,
		SortPriority = -95,
	};
	return world_age, temperature, rainfall, sea_level, resources
end

------------------------------------------------------------------------------
-- Map Generator Data
------------------------------------------------------------------------------

--Used to determine the next direction when turning
if(FlowDirectionTypes ~= nil) then
	TurnRightFlowDirections = {
		[FlowDirectionTypes.FLOWDIRECTION_NORTH] 
			= FlowDirectionTypes.FLOWDIRECTION_NORTHEAST,
		
		[FlowDirectionTypes.FLOWDIRECTION_NORTHEAST] 
			= FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST,	
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST] 
			= FlowDirectionTypes.FLOWDIRECTION_SOUTH,		
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTH]	
			= FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST,	
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST] 
			= FlowDirectionTypes.FLOWDIRECTION_NORTHWEST,	
		
		[FlowDirectionTypes.FLOWDIRECTION_NORTHWEST]
			= FlowDirectionTypes.FLOWDIRECTION_NORTH,
	};

	TurnLeftFlowDirections = {
		[FlowDirectionTypes.FLOWDIRECTION_NORTH] 
			= FlowDirectionTypes.FLOWDIRECTION_NORTHWEST,
		
		[FlowDirectionTypes.FLOWDIRECTION_NORTHEAST] 
			= FlowDirectionTypes.FLOWDIRECTION_NORTH,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST] 
			= FlowDirectionTypes.FLOWDIRECTION_NORTHEAST,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTH] 
			= FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST] 
			= FlowDirectionTypes.FLOWDIRECTION_SOUTH, 
		
		[FlowDirectionTypes.FLOWDIRECTION_NORTHWEST] 
			= FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST,
	};
end

------------------------------------------------------------------------------
-- Map Generator Methods
------------------------------------------------------------------------------
function SetPlotTypes(plotTypes)
	print("Setting Plot Types (MapGenerator.Lua)");
	
	-- NOTE: Plots() is indexed from 0, the way the plots are indexed in C++
	-- However, Lua tables are indexed from 1, and all incoming plot tables should be indexed this way.
	-- So we add 1 to the Plots() index to find the matching plot data in plotTypes.
	for i, plot in Plots() do
		plot:SetPlotType(plotTypes[i + 1], false, false);
	end
end

function GenerateCoasts(args)
	print("Setting coasts and oceans (MapGenerator.Lua)");
	local args = args or {};
	local bExpandCoasts = args.bExpandCoasts or true;
	local expansion_diceroll_table = args.expansion_diceroll_table or {2, 4};
	
	local shallowWater = GameDefines.SHALLOW_WATER_TERRAIN;
	local deepWater = GameDefines.DEEP_WATER_TERRAIN;

	for i, plot in Plots() do
		if(plot:IsWater()) then
			if(plot:IsAdjacentToLand()) then
				plot:SetTerrainType(shallowWater, false, false);
			else
				plot:SetTerrainType(deepWater, false, false);
			end
		end
	end
	
	if bExpandCoasts == false then
		return
	end

	print("Expanding coasts (MapGenerator.Lua)");
	for loop, iExpansionDiceroll in ipairs(expansion_diceroll_table) do
		local shallowWaterPlots = {};
		for i, plot in Plots() do
			if(plot:GetTerrainType() == deepWater) then
				-- Chance for each eligible plot to become an expansion is 1 / iExpansionDiceroll.
				-- Default is two passes at 1/4 chance per eligible plot on each pass.
				if(plot:IsAdjacentToShallowWater() and Map.Rand(iExpansionDiceroll, "add shallows") == 0) then
					table.insert(shallowWaterPlots, plot);
				end
			end
		end
		for i, plot in ipairs(shallowWaterPlots) do
			plot:SetTerrainType(shallowWater, false, false);
		end
	end
end

function SetTerrainTypes(terrainTypes)
	print("Setting Terrain Types (MapGenerator.Lua)");
	for i, plot in Plots() do
		if not plot:IsWater() then
			plot:SetTerrainType(terrainTypes[i], false, false);
		end		
	end
end

function GeneratePlotTypes()
	-- This is a basic, empty shell. All map scripts should replace this function with their own.
	print("Generating Plot Types (MapGenerator.Lua)");
	
	--plotTypes is 0-based to map directly to Map.GetPlotByIndex
	local plotLand = PlotTypes.PLOT_LAND;
	local plotTypes = {};
	for i = 0, Map.GetNumPlots() - 1, 1 do
		plotTypes[i] = plotLand;
	end 
	
	SetPlotTypes(plotTypes);
	
	GenerateCoasts();
end

function GenerateTerrain()
	-- This is a basic, empty shell. All map scripts should replace this function with their own.
	print("Generating Terrain Types (MapGenerator.Lua)");
	
	--terrainTypes is 0-based to map directly to Map.GetPlotByIndex
	local terrainGrass = GameInfo.Terrains.TERRAIN_GRASS.ID;
	local terrainTypes = {};
	for i = 0, Map.GetNumPlots() - 1, 1 do
		terrainTypes[i] = terrainGrass;
	end 
	
	SetTerrainTypes(terrainTypes);	
end

function GetOppositeFlowDirection(dir)
	--DOCUMENT Method uses magic numbers...
	local numTypes = FlowDirectionTypes.NUM_FLOWDIRECTION_TYPES;
	return ((dir + 3) % numTypes);
end

function GetRiverValueAtPlot(plot)

	local numPlots = PlotTypes.NUM_PLOT_TYPES;
	local sum = (numPlots - plot:GetPlotType()) * 20;

	local numDirections = DirectionTypes.NUM_DIRECTION_TYPES;
	for direction = 0, numDirections - 1, 1 do

		local adjacentPlot = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);

		if (adjacentPlot ~= nil) then
			sum = sum + (numPlots - adjacentPlot:GetPlotType());
		else
			sum = sum + (numPlots * 10);
		end
		
	end

	sum = sum + Map.Rand(10, "River Rand");

	return sum;
end

----------------------------------------------------------------------------------------------------------------------
nextRiverID = 0;
_rivers = {};
function DoRiver(startPlot, thisFlowDirection, originalFlowDirection, riverID)

	thisFlowDirection = thisFlowDirection or FlowDirectionTypes.NO_FLOWDIRECTION;
	originalFlowDirection = originalFlowDirection or FlowDirectionTypes.NO_FLOWDIRECTION;

	-- pStartPlot = the plot at whose SE corner the river is starting
	if (riverID == nil) then
		riverID = nextRiverID;
		nextRiverID = nextRiverID + 1;
	end

	local otherRiverID = _rivers[startPlot]
	if (otherRiverID ~= nil and otherRiverID ~= riverID and originalFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then
		return; -- Another river already exists here; can't branch off of an existing river!
	end

	local riverPlot;
	
	local bestFlowDirection = FlowDirectionTypes.NO_FLOWDIRECTION;
	if (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTH) then
	
		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if ( adjacentPlot == nil or riverPlot:IsWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater() ) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetWOfRiver(true, thisFlowDirection);
		riverPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
		
	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHEAST) then
	
		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		if ( adjacentPlot == nil or riverPlot:IsNWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater() ) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change
	
	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST) then
	
		riverPlot = Map.PlotDirection(startPlot:GetX(), startPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if (riverPlot == nil) then
			return;
		end
		
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		if (adjacentPlot == nil or riverPlot:IsNEOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNEOfRiver(true, thisFlowDirection);
		-- riverPlot does not change
	
	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTH) then
	
		riverPlot = Map.PlotDirection(startPlot:GetX(), startPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		if (riverPlot == nil) then
			return;
		end
		
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if (adjacentPlot == nil or riverPlot:IsWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end
		
		_rivers[riverPlot] = riverID;
		riverPlot:SetWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change
	
	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST) then

		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		if (adjacentPlot == nil or riverPlot:IsNWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end
		
		_rivers[riverPlot] = riverID;
		riverPlot:SetNWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change

	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST) then
		
		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		
		if ( adjacentPlot == nil or riverPlot:IsNEOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNEOfRiver(true, thisFlowDirection);
		riverPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_WEST);

	else
	
		--error("Illegal direction type"); 
		-- River is starting here, set the direction in the next step
		riverPlot = startPlot;		
	end

	if (riverPlot == nil or riverPlot:IsWater()) then
		-- The river has flowed off the edge of the map or into the ocean. All is well.
		return; 
	end

	-- Storing X,Y positions as locals to prevent redundant function calls.
	local riverPlotX = riverPlot:GetX();
	local riverPlotY = riverPlot:GetY();
	
	-- Table of methods used to determine the adjacent plot.
	local adjacentPlotFunctions = {
		[FlowDirectionTypes.FLOWDIRECTION_NORTH] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHWEST); 
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_NORTHEAST] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHEAST);
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_EAST);
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTH] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_SOUTHWEST);
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_WEST);
		end,
		
		[FlowDirectionTypes.FLOWDIRECTION_NORTHWEST] = function() 
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHWEST);
		end	
	}
	
	if(bestFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then

		-- Attempt to calculate the best flow direction.
		local bestValue = math.huge;
		for flowDirection, getAdjacentPlot in pairs(adjacentPlotFunctions) do
			
			if (GetOppositeFlowDirection(flowDirection) ~= originalFlowDirection) then
				
				if (thisFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION or
					flowDirection == TurnRightFlowDirections[thisFlowDirection] or 
					flowDirection == TurnLeftFlowDirections[thisFlowDirection]) then
				
					local adjacentPlot = getAdjacentPlot();
					
					if (adjacentPlot ~= nil) then
					
						local value = GetRiverValueAtPlot(adjacentPlot);
						if (flowDirection == originalFlowDirection) then
							value = (value * 3) / 4;
						end
						
						if (value < bestValue) then
							bestValue = value;
							bestFlowDirection = flowDirection;
						end
					end
				end
			end
		end
		
		-- Try a second pass allowing the river to "flow backwards".
		if(bestFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then
		
			local bestValue = math.huge;
			for flowDirection, getAdjacentPlot in pairs(adjacentPlotFunctions) do
			
				if (thisFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION or
					flowDirection == TurnRightFlowDirections[thisFlowDirection] or 
					flowDirection == TurnLeftFlowDirections[thisFlowDirection]) then
				
					local adjacentPlot = getAdjacentPlot();
					
					if (adjacentPlot ~= nil) then
						
						local value = GetRiverValueAtPlot(adjacentPlot);
						if (value < bestValue) then
							bestValue = value;
							bestFlowDirection = flowDirection;
						end
					end	
				end
			end
		end
		
	end
	
	--Recursively generate river.
	if (bestFlowDirection ~= FlowDirectionTypes.NO_FLOWDIRECTION) then
		if  (originalFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then
			originalFlowDirection = bestFlowDirection;
		end
		
		DoRiver(riverPlot, bestFlowDirection, originalFlowDirection, riverID, riverLength);
	end
	
end

----------------------------------------------------------------------------------------------------------------------
function AddRivers()
	local riverSourceRangeDefault = 1.5;
	local seaWaterRangeDefault = 0.75;
	local plotsPerRiverEdge =  9;
	local riverRnd = 210;
	local rivers_level = LekMapGetCustomOption(9)

	if rivers_level == 1 then
		riverSourceRangeDefault = 3;
		seaWaterRangeDefault = 2;
		plotsPerRiverEdge =  12;
		riverRnd = 180;
	elseif rivers_level	== 3 then
		riverSourceRangeDefault = 1;
		seaWaterRangeDefault = 0.5;
		plotsPerRiverEdge =  8;
		riverRnd = 230;
	end

	print("Map Generation - Adding Rivers");
	
	local passConditions = {
		function(plot)
			return (plot:IsHills() or plot:IsMountain());
		end,
		
		function(plot)
			return (not plot:IsCoastalLand()) and (Map.Rand(8, "MapGenerator AddRivers") == 0);
		end,
		
		function(plot)
			local area = plot:Area();
			return (plot:IsHills() or plot:IsMountain()) and (area:GetNumRiverEdges() <	((area:GetNumTiles() / plotsPerRiverEdge) + 1));
		end,
		
		function(plot)
			local area = plot:Area();
			return (area:GetNumRiverEdges() < (area:GetNumTiles() / plotsPerRiverEdge) + 1);
		end
	}
	
	for iPass, passCondition in ipairs(passConditions) do
					
		if (iPass <= 2) then
			riverSourceRange = riverSourceRangeDefault;
			seaWaterRange = seaWaterRangeDefault;
		else
			riverSourceRange = (riverSourceRangeDefault / 2);
			seaWaterRange = (seaWaterRangeDefault / 2);
		end
			
		local iW, iH = Map.GetGridSize();

		for i = 0, (iW * iH) - 1, 1 do
			plot = Map.GetPlotByIndex(i);
			if(not plot:IsWater()) then
				if(passCondition(plot)) then -- and plot:IsNaturalWonder() == false and AdjacentToNaturalWonder(plot) == false) then
					if (not Map.FindWater(plot, riverSourceRange, true)) then
						if (not Map.FindWater(plot, seaWaterRange, false)) then
							local inlandCorner = plot:GetInlandCorner();
							if(inlandCorner) then -- and plot:IsNaturalWonder() == false and AdjacentToNaturalWonder(plot) == false) then
								local riverChance = Map.Rand(riverRnd, "MapGenerator AddRivers");
								if riverChance > 178 then
									DoRiver(inlandCorner);
								end
							end
						end
					end
				end			
			end
		end
	end		
end

----------------------------------------------------------------------------------------------------------------------
function AddLakes()

	print("Map Generation - Adding Lakes");
	
	local numLakesAdded = 0;
	local lakePlotRand = GameDefines.LAKE_PLOT_RAND;
	for i, plot in Plots() do
		if not plot:IsWater() then
			if not plot:IsCoastalLand() then
				if not plot:IsRiver() then
					local r = Map.Rand(lakePlotRand, "MapGenerator AddLakes");
					if r == 0 then
						plot:SetArea(-1);
						plot:SetPlotType(PlotTypes.PLOT_OCEAN);
						numLakesAdded = numLakesAdded + 1;
					end
				end
			end
		end
	end
	
	-- this is a minimalist update because lakes have been added
	if numLakesAdded > 0 then
		print(tostring(numLakesAdded).." lakes added")
		Map.CalculateAreas();
	end
end

----------------------------------------------------------------------------------------------------------------------
function AddFeatures()
	-- This is a basic, empty shell. All map scripts should replace this function with their own.
	print("Map Generation - Adding Features");
	
	for i, plot in Plots() do
		for feature in GameInfo.Features() do
			if(plot:CanHaveFeature(feature.ID)) then
				local r = Map.Rand(10000, "MapGenerator AddFeatures");
				if(r < feature.AppearanceProbability) then
					plot:SetFeatureType(feature.ID);
				end 
			end
		end
	end
end

function CanPlaceGoodyAt(improvement, plot)

	local improvementID = improvement.ID;
	local NO_TEAM = -1;
	local NO_RESOURCE = -1;
	local NO_IMPROVEMENT = -1;
	
	if (not plot:CanHaveImprovement(improvementID, NO_TEAM)) then
		return false;
	end
	
	if (plot:GetImprovementType() ~= NO_IMPROVEMENT) then
		return false;
	end

	if (plot:GetResourceType() ~= NO_RESOURCE) then
		return false;
	end

	if (plot:IsImpassable()) then
		return false;
	end

	if (plot:IsMountain()) then
		return false;
	end
	
	-- Don't allow on tiny islands.
	local areaID = plot:GetArea();
	local area = Map.GetArea(areaID);	
	local numTiles = area:GetNumTiles();
	if (numTiles < 3) then
		return false;
	end

	-- Check for being too close to another of this goody type.
	local uniqueRange = improvement.GoodyRange;
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -uniqueRange, uniqueRange - 1, 1 do
		for dy = -uniqueRange, uniqueRange - 1, 1 do
			local otherPlot = Map.PlotXYWithRangeCheck(plotX, plotY, dx, dy, uniqueRange);
			if(otherPlot and otherPlot:GetImprovementType() == improvementID) then
				return false;
			end
		end
	end 

	-- Check for being too close to a civ start.
	for dx = -3, 3 do
		for dy = -3, 3 do
			local otherPlot = Map.PlotXYWithRangeCheck(plotX, plotY, dx, dy, 4);
			if(otherPlot) then
				if otherPlot:IsStartingPlot() then -- Loop through all ever-alive major civs, check if their start plot matches "otherPlot"
					for player_num = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
						local player = Players[player_num];
						if player:IsEverAlive() then
							-- Need to compare otherPlot with this civ's start plot and return false if a match.
							local playerStartPlot = player:GetStartingPlot();
							if otherPlot == playerStartPlot then
								return false;
							end
						end
					end
				end
			end
		end
	end

	return true;
end

function AddGoodies()

	print("-------------------------------");
	print("Map Generation - Adding Goodies");
	
	-- If an era setting wants no goodies, don't place any.
	local startEra = Game.GetStartEra();
	if(GameInfo.Eras[startEra].NoGoodies) then
		print("** The Era specified NO GOODY HUTS");
		return;
	end

	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_GOODY_HUTS)) then
		print("** The game specified NO GOODY HUTS");
		return false;
	end

	-- Check XML for any and all Improvements flagged as "Goody" and distribute them.
	for improvement in GameInfo.Improvements() do
		local tilesPerGoody = improvement.TilesPerGoody;
		
		if(improvement.Goody and tilesPerGoody > 0) then
		
			local improvementID = improvement.ID;
			for index, plot in Plots(Shuffle) do
				if ( not plot:IsWater() ) then
					
					-- Prevents too many goodies from clustering on any one landmass.
					local area = plot:Area();
					local improvementCount = area:GetNumImprovements(improvementID);
					local scaler = (area:GetNumTiles() + (tilesPerGoody/2))/tilesPerGoody;	
					if (improvementCount < scaler) then
						
						if (CanPlaceGoodyAt(improvement, plot)) then
							plot:SetImprovementType(improvementID);
						end
					end
				end
			end
		end
	end
	print("-------------------------------");
end

function DetermineContinents()
	print("Determining continents for art purposes (MapGenerator.Lua)");
	-- Each plot has a continent art type. Mixing and matching these could look
	-- extremely bad, but there is nothing technical to prevent it. The worst 
	-- that will happen is that it can't find a blend and draws red checkerboards.
	
	-- Command for setting the art type for a plot is: <plot object>:SetContinentArtType(<art_set_number>)
	
	-- CONTINENTAL ART SETS
	-- 0) Ocean
	-- 1) America
	-- 2) Asia
	-- 3) Africa
	-- 4) Europe
	
	-- Here is an example that sets all land in the world to use the European art set.
	--[[
	for i, plot in Plots() do
		if plot:IsWater() then
			plot:SetContinentArtType(0);
		else
			plot:SetContinentArtType(4);
		end
	end
	]]--
	
	-- Default for this function operates in C++, but you can override by
	-- replacing this method with your own and not calling the default stamper.
	Map.DefaultContinentStamper();

	-- Lekmap (user, 2026-10-27): one art set for all land. The default stamper gives every landmass of 10+ tiles
	-- its own random set, so Scion's bigger islands next to the pangaea looked out of place.
	local artSet = 1 + Map.Rand(4, "Lekmap continent art set");
	for i = 0, Map.GetNumPlots() - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:IsWater() then
			plot:SetContinentArtType(0);
		else
			plot:SetContinentArtType(artSet);
		end
	end
	print("Lekmap: continent art set " .. artSet .. " for all land");
end

function StartPlotSystem()
	-- Divide the map in to Regions, choose starting locations, place civs, 
	-- place city states, Normalize locations, and place Resources.
	--
	-- The code for these operations resides in AssignStartingPlots.lua and MapmakerUtilities.lua
	-- They are all interwoven and interdependent. Do not change this order of operations.
	--
	-- GenerateRegions() and ChooseLocations() allow for some parameters. Refer to
	-- these functions, or to examples used in map scripts, for more details. Also,
	-- there is a detailed Reference section at the end of AssignStartingPlots.lua
	--
	-- Map scripts can execute enormous power over this operation via replacing
	-- specific pieces of it with modified or custom methods.

	print("Creating start plot database.");
	local start_plot_database = AssignStartingPlots.Create()
	
	print("Dividing the map in to Regions.");
	start_plot_database:GenerateRegions();
	
	print("Choosing start locations for civilizations.");
	start_plot_database:ChooseLocations()
	if _lek_global_six_request_map_regen == true then
		local att = _lek_map_layout_attempt or 1;
		local maxL = _lek_global_six_regen_max_layouts;
		if type(maxL) ~= "number" or maxL < 1 then
			maxL = 4;
		end
		local msg = "### LekMapGen StartPlotSystem short_circuit runId=" .. tostring(_lek_run_id or "na")
			.. " layout=" .. tostring(att) .. "/" .. tostring(maxL)
			.. " skip=BalanceAndAssign_NW_resources mapScript=HB_default";
		if LekPlacementProbeAt then
			LekPlacementProbeAt(1, msg);
		elseif LekMapgenPrint then
			LekMapgenPrint(msg);
		end
		return;
	end

	print("Normalizing start locations and assigning them to Players.");
	start_plot_database:BalanceAndAssign()

	if _lek_global_six_request_map_regen == true then
		local att = _lek_map_layout_attempt or 1;
		local maxL = _lek_global_six_regen_max_layouts;
		if type(maxL) ~= "number" or maxL < 1 then
			maxL = 4;
		end
		local msg = "### LekMapGen StartPlotSystem short_circuit runId=" .. tostring(_lek_run_id or "na")
			.. " layout=" .. tostring(att) .. "/" .. tostring(maxL)
			.. " skip=after_BalanceAndAssign_NW_resources mapScript=HB_default";
		if LekPlacementProbeAt then
			LekPlacementProbeAt(1, msg);
		elseif LekMapgenPrint then
			LekMapgenPrint(msg);
		end
		return;
	end
	
	print("Placing Natural Wonders.");
	start_plot_database:PlaceNaturalWonders()

	print("Placing Resources and City States.");
	start_plot_database:PlaceResourcesAndCityStates()
end

------------------------------------------------------------------------------
-- Lekmap (user, 2026-11-26): a layout retry starts from a clean map.
-- When start placement rejects a layout, LekHB_GenerateMap_Core runs again in the same map. SetPlotTypes and
-- GenerateTerrain overwrite plot and terrain types, but rivers, features and resources of the rejected layout
-- stayed: DoRiver stops at an existing river and AddFeatures only fills plots without a feature. The old rivers
-- then ran along the new coasts (river edges next to water) and old Oases sat on hills or plains.
------------------------------------------------------------------------------
function LekClearMapForLayoutRetry()
	local F = FlowDirectionTypes;
	local nRivers, nFeatures, nResources = 0, 0, 0;
	for k = 0, Map.GetNumPlots() - 1 do
		local p = Map.GetPlotByIndex(k);
		if p:IsWOfRiver() then p:SetWOfRiver(false, F.NO_FLOWDIRECTION); nRivers = nRivers + 1; end
		if p:IsNWOfRiver() then p:SetNWOfRiver(false, F.NO_FLOWDIRECTION); nRivers = nRivers + 1; end
		if p:IsNEOfRiver() then p:SetNEOfRiver(false, F.NO_FLOWDIRECTION); nRivers = nRivers + 1; end
		if p:GetFeatureType() ~= FeatureTypes.NO_FEATURE then
			p:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			nFeatures = nFeatures + 1;
		end
		if p:GetResourceType(-1) ~= -1 then
			p:SetResourceType(-1, 0);
			nResources = nResources + 1;
		end
	end
	print("### LekMapGen layout_retry_reset rivers=" .. nRivers .. " features=" .. nFeatures .. " resources=" .. nResources);
end

function LekHB_GenerateMap_Core()
	local tCore0 = (os and os.clock) and os.clock() or 0;
	do
		local la0 = _lek_map_layout_attempt or 0;
		local coreBoot = "### LekMapGen LekHB_GenerateMap_Core_begin layoutAttempt="
			.. tostring(la0) .. " t=" .. tostring((os and os.clock) and os.clock() or 0);
		print(coreBoot);
		pcall(function()
			if LekMapgenDiagLogAppend then
				LekMapgenDiagLogAppend({ coreBoot });
			end
		end);
	end
	local function stage(s)
		if LekMapgenLogAtLeast and not LekMapgenLogAtLeast(2) then
			return;
		end
		local la = _lek_map_layout_attempt or 0;
		local t = (os and os.clock) and os.clock() or 0;
		local m = "### LekMapGen stage=" .. tostring(s) .. " layoutAttempt=" .. tostring(la) .. " t=" .. tostring(t);
		print(m);
		pcall(function()
			if LekMapgenDiagLogAppend then
				LekMapgenDiagLogAppend({ m });
			end
		end);
	end
	stage("core_begin");
	print("Generating Map");
	-- This is the core map generation function.
	-- Every step in this process carries dependencies upon earlier steps.
	-- There isn't any way to change the order of operations without breaking dependencies,
	-- although it would be possible to repair and reorganize certain dependencies with enough work.
	
	-- Plot types are the core layer of the map, determining land or sea, determining flatland, hills or mountains.
	stage("before_GeneratePlotTypes");
	local tPlotTypes0 = (os and os.clock) and os.clock() or 0;
	GeneratePlotTypes();
	local dtPlotTypes = ((os and os.clock) and os.clock() or 0) - tPlotTypes0;
	local laPt = _lek_map_layout_attempt or 0;
	local ptLine = "### LekMapGen GeneratePlotTypes_returned layoutAttempt=" .. tostring(laPt)
		.. " dt_os_clock=" .. tostring(dtPlotTypes);
	if LekPlacementProbeAt then
		LekPlacementProbeAt(1, ptLine);
	elseif LekMapgenPrint then
		LekMapgenPrint(ptLine);
		pcall(function()
			if LekMapgenDiagLogAppend then
				LekMapgenDiagLogAppend({ ptLine });
			end
		end);
	end
	stage("after_GeneratePlotTypes");
	
	-- Terrain covers climate: grassland, plains, desert, tundra, snow.
	GenerateTerrain();
	stage("after_GenerateTerrain");
	
	-- Each body of water, area of mountains, or area of hills+flatlands is independently grouped and tagged.
	Map.RecalculateAreas();
	stage("after_RecalculateAreas_1");
	
	-- River generation is affected by plot types, originating from highlands and preferring to traverse lowlands.
	AddRivers();
	stage("after_AddRivers");
	
	-- Lakes would interfere with rivers, causing them to stop and not reach the ocean, if placed any sooner.
	AddLakes();
	stage("after_AddLakes");
	
	-- Features depend on plot types, terrain types, rivers and lakes to help determine their placement.
	AddFeatures();
	stage("after_AddFeatures");

	-- Feature Ice is impassable and therefore requires another area recalculation.
	Map.RecalculateAreas();
	stage("after_RecalculateAreas_2");

	-- Assign Starting Plots, Place Natural Wonders, and Distribute Resources.
	-- This system was designed and programmed for Civ5 by Bob Thomas.
	-- Starting plots are wholly dependent on all the previous elements being in place.
	-- Natural Wonders are dependent on civ starts being in place, to keep them far enough away.
	-- Resources are dependent on start locations, Natural Wonders, as well as plots, terrain, rivers, lakes and features.
	--
	-- This system relies on Area-based data and cannot tolerate an AreaID recalculation during its operations.
	-- Due to plot changes from Natural Wonders and possibly other source, another recalculation is done as the final action of the system.
	stage("before_StartPlotSystem");
	StartPlotSystem();
	stage("after_StartPlotSystem");

	if _lek_global_six_request_map_regen == true then
		stage("core_skip_goodies_continents_regen_pending");
		local sk = "### LekGlobalSix mapRegen core_skip_goodies_continents runId=" .. tostring(_lek_run_id or "na")
			.. " layoutAttempt=" .. tostring(_lek_map_layout_attempt or 0);
		if LekPlacementProbeAt then
			LekPlacementProbeAt(1, sk);
		elseif LekMapgenPrint then
			LekMapgenPrint(sk);
			pcall(function()
				if LekMapgenDiagLogAppend then
					LekMapgenDiagLogAppend({ sk });
				end
			end);
		end
	else
		-- Lekmap: inland seas must stay clear of capitals (fills whole seas; recalculates areas itself).
		if LekFillInlandSeasNearCapitals then
			LekFillInlandSeasNearCapitals();
			stage("after_LekFillInlandSeasNearCapitals");
		end
		-- Lekmap: rivers that now end on land (water filled in after rivers were made) find their way to water.
		if LekRepairDeadEndRivers then
			local okRiv, errRiv = pcall(LekRepairDeadEndRivers);
			if not okRiv then print("### LekRivers repair failed: " .. tostring(errRiv)); end
			stage("after_LekRepairDeadEndRivers");
		end
		if LekLogFinalLandStats then
			LekLogFinalLandStats();
		end
		if LekDumpIslandMap then
			LekDumpIslandMap();
		end

		-- Goodies depend on not colliding with resources or Natural Wonders, or being placed too near to start plots.
		AddGoodies();
		stage("after_AddGoodies");

		-- Continental artwork selection must wait until Areas are finalized, so it gets handled last.
		DetermineContinents();
		stage("after_DetermineContinents");
	end
	if LekMapgenDiagAt then
		LekMapgenDiagAt(1, {
			"### LekBuildPing end_LekHB_GenerateMap_Core runId=" .. tostring(_lek_run_id or "na"),
		});
	elseif LekMapgenDiagLogAppend then
		LekMapgenDiagLogAppend({
			"### LekBuildPing end_LekHB_GenerateMap_Core runId=" .. tostring(_lek_run_id or "na"),
		});
	end
	if LekPlacementProbeAt then
		LekPlacementProbeAt(2, "### LekGlobalSix mapRegen MARKER core_full_return runId=" .. tostring(_lek_run_id or "na")
			.. " requestRegen=" .. ((_lek_global_six_request_map_regen == true) and "1" or "0"));
	elseif LekMapgenPrint then
		LekMapgenPrint("### LekGlobalSix mapRegen MARKER core_full_return runId=" .. tostring(_lek_run_id or "na")
			.. " requestRegen=" .. ((_lek_global_six_request_map_regen == true) and "1" or "0"));
	end
	do
		local la1 = _lek_map_layout_attempt or 0;
		local tCore1 = (os and os.clock) and os.clock() or 0;
		local coreEnd = "### LekMapGen LekHB_GenerateMap_Core_end layoutAttempt="
			.. tostring(la1) .. " t=" .. tostring(tCore1)
			.. " dt_os_clock=" .. tostring(tCore1 - tCore0);
		if LekMapgenPrintAndDiagFile then
			LekMapgenPrintAndDiagFile(coreEnd);
		elseif LekMapgenLogsEnabled and LekMapgenLogsEnabled() then
			print(coreEnd);
			pcall(function()
				if LekMapgenDiagLogAppend then
					LekMapgenDiagLogAppend({ coreEnd });
				end
			end);
		end
	end
	stage("core_end");
end

function GenerateMap()
	local tGen0 = (os and os.clock) and os.clock() or 0;
	local genEntry = "### LekMapGen GenerateMap_lua_entry t=" .. tostring(tGen0);
	local function benchRegenNoiseProbeLevel(msg)
		if not _lek_mapgen_tuple_benchmark_mode then
			return 1;
		end
		if type(msg) ~= "string" then
			return 1;
		end
		if string.find(msg, "GenerateMap_lua_entry", 1, true)
			or string.find(msg, "mapRegen MARKER", 1, true)
			or string.find(msg, "attempt_begin layout=", 1, true)
			or string.find(msg, "layout_result layout=", 1, true)
			or string.find(msg, "postCoreGenerateMap", 1, true) then
			return 2;
		end
		return 1;
	end
	if LekPlacementProbeAt then
		LekPlacementProbeAt(benchRegenNoiseProbeLevel(genEntry), genEntry);
	elseif LekMapgenPrint then
		LekMapgenPrint(genEntry);
	end

	local function logPostCore(layoutAttempt, maxL, req, regenLoopActive)
		local pc = "### LekGlobalSix mapRegen postCoreGenerateMap layout=" .. tostring(layoutAttempt) .. "/" .. tostring(maxL) ..
			" requestRegen=" .. (req and "1" or "0") .. " runId=" .. tostring(_lek_run_id or "na") ..
			" regenLoopActive=" .. (regenLoopActive and "1" or "0");
		if LekPlacementProbeAt then
			LekPlacementProbeAt(benchRegenNoiseProbeLevel(pc), pc);
		else
			if LekMapgenDiagLogAppend then
				LekMapgenDiagLogAppend({ pc });
			end
			print(pc);
		end
	end

	local function markGenerateMap(msg)
		local lvl = benchRegenNoiseProbeLevel(msg);
		if LekPlacementProbeAt then
			LekPlacementProbeAt(lvl, msg);
		elseif LekPlacementProbeLog then
			LekPlacementProbeLog(msg);
		elseif LekMapgenPrint then
			LekMapgenPrint(msg);
			if LekMapgenDiagLogAppend then
				LekMapgenDiagLogAppend({ msg });
			end
		end
	end
	local function markGenerateMapEnd(outcome, layouts)
		local tEnd = (os and os.clock) and os.clock() or 0;
		markGenerateMap("### LekMapGen GenerateMap_lua_exit t=" .. tostring(tEnd)
			.. " dt_os_clock=" .. tostring(tEnd - tGen0)
			.. " outcome=" .. tostring(outcome or "na")
			.. " layouts=" .. tostring(layouts or 0));
	end
	markGenerateMap("### LekGlobalSix mapRegen MARKER GenerateMap_entry regenLoop="
		.. tostring(_lek_enable_hb_generatemap_regen_loop == true));

	if not _lek_enable_hb_generatemap_regen_loop then
		LekHB_GenerateMap_Core();
		local rq0 = (_lek_global_six_request_map_regen == true);
		markGenerateMap("### LekGlobalSix mapRegen MARKER before_postCore layout=1 requestRegen=" .. (rq0 and "1" or "0"));
		logPostCore(1, 1, rq0, false);
		local oc0 = rq0 and "need_regen_but_loop_off" or "accepted";
		markGenerateMap("### LekGlobalSix mapRegen layout_result layout=1/1 runId=" .. tostring(_lek_run_id or "na")
			.. " outcome=" .. oc0 .. " requestRegen=" .. (rq0 and "1" or "0") .. " regenLoop=0");
		markGenerateMapEnd(oc0, 1);
		return;
	end
	local layoutAttempt = 0;
	local lastOutcome = "na";
	while true do
		layoutAttempt = layoutAttempt + 1;
		_lek_map_layout_attempt = layoutAttempt;
		_lek_global_six_request_map_regen = false;
		if layoutAttempt > 1 then
			LekClearMapForLayoutRetry();
		end
		local maxL = _lek_global_six_regen_max_layouts;
		if type(maxL) ~= "number" or maxL < 1 then
			maxL = 4;
		end
		markGenerateMap("### LekGlobalSix mapRegen attempt_begin layout=" .. tostring(layoutAttempt) .. "/" .. tostring(maxL));
		LekHB_GenerateMap_Core();
		maxL = _lek_global_six_regen_max_layouts;
		if type(maxL) ~= "number" or maxL < 1 then
			maxL = 4;
		end
		local req = (_lek_global_six_request_map_regen == true);
		markGenerateMap("### LekGlobalSix mapRegen MARKER before_postCore layout=" .. tostring(layoutAttempt)
			.. " requestRegen=" .. (req and "1" or "0"));
		logPostCore(layoutAttempt, maxL, req, true);
		local outcome;
		if not req then
			outcome = "accepted";
		elseif layoutAttempt >= maxL then
			outcome = "exhausted_still_failed";
		else
			outcome = "retry";
		end
		lastOutcome = outcome;
		markGenerateMap("### LekGlobalSix mapRegen layout_result layout=" .. tostring(layoutAttempt) .. "/" .. tostring(maxL)
			.. " runId=" .. tostring(_lek_run_id or "na")
			.. " outcome=" .. outcome
			.. " requestRegen=" .. (req and "1" or "0")
			.. " regenLoop=1");
		if not req then
			break;
		end
		if layoutAttempt >= maxL then
			local msg = "### LekGlobalSix mapRegen exhausted layouts=" .. tostring(maxL) .. " runId=" .. tostring(_lek_run_id or "na");
			if LekPlacementProbeAt then
				LekPlacementProbeAt(1, msg);
			elseif LekPlacementProbeLog then
				LekPlacementProbeLog(msg);
			elseif LekMapgenPrintAndDiagFile then
				LekMapgenPrintAndDiagFile(msg);
			end
			break;
		end
		local msg = "### LekGlobalSix mapRegen retry nextLayout=" .. tostring(layoutAttempt + 1) .. "/" .. tostring(maxL) .. " runId=" .. tostring(_lek_run_id or "na");
		if LekPlacementProbeAt then
			LekPlacementProbeAt(1, msg);
		elseif LekPlacementProbeLog then
			LekPlacementProbeLog(msg);
		elseif LekMapgenPrint then
			LekMapgenPrint(msg);
			if LekMapgenDiagLogAppend then
				LekMapgenDiagLogAppend({ msg });
			end
		end
	end
	markGenerateMap("### LekGlobalSix mapRegen summary total_layouts_tried=" .. tostring(layoutAttempt)
		.. " final_outcome=" .. tostring(lastOutcome)
		.. " last_runId=" .. tostring(_lek_run_id or "na"));
	markGenerateMapEnd(lastOutcome, layoutAttempt);
	_lek_map_layout_attempt = nil;
end