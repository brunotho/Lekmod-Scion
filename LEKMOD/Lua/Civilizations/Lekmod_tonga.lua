-- Author: EnormousApplePie
include("Lekmod_utilities.lua")
include("PlotIterators.lua")

local this_civ = GameInfoTypes["CIVILIZATION_TONGA"]
local is_active = LekmodUtilities:is_civilization_active(this_civ)

------------------------------------------------------------------------------------------------------------------------
-- Tonga UA. Reveal nearby islands and explore nearby coastline at the start of the game.
------------------------------------------------------------------------------------------------------------------------
-- Each tile is revealed with 75% chance, like the map ruin (GOODY_MAP MapProb), so the edge looks noisy (user, 2026-10-23).
-- The roll is a hash of the tile and the start position: the same on every machine, no synced random number used.
local function lekmod_tonga_keep(plot, start_plot)
   local n = (plot:GetX() * 389 + plot:GetY() * 7919 + start_plot:GetX() * 31 + start_plot:GetY() * 977) % 2147483647 + 1
   for _ = 1, 3 do
      n = (n * 16807) % 2147483647
   end
   return n % 100 < 75
end

function lekmod_tonga_explore(player)

   local team = player:GetTeam()
   local start_plot = player:GetStartingPlot()

   local explore_radius = 6
   for loop_plot in PlotAreaSpiralIterator(start_plot, explore_radius, SECTOR_NORTH, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do

      if loop_plot:Area() ~= start_plot:Area() and loop_plot:IsCoastalLand() and not loop_plot:IsLake() then
         for island_plot in PlotAreaSweepIterator(loop_plot, 5, SECTOR_NORTH, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do
            if island_plot:Area() == loop_plot:Area() then
               for to_reveal_plot in PlotAreaSweepIterator(island_plot, 1, SECTOR_NORTH, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do
                  if lekmod_tonga_keep(to_reveal_plot, start_plot) then
                     to_reveal_plot:SetRevealed(team, true)
                  end
               end
            end
         end
      end

   end

   for loop_plot in PlotAreaSpiralIterator(start_plot, 6, SECTOR_NORTH, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do

      local no_lake = true
      for possible_lake_plot in PlotAreaSweepIterator(loop_plot, 1, SECTOR_NORTH, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do
         if possible_lake_plot:IsLake() then
            no_lake = false
         end
      end
      if loop_plot:IsCoastalLand() and no_lake then
         for to_reveal_plot in PlotAreaSweepIterator(loop_plot, 1, SECTOR_NORTH, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_EXCLUDE) do
            if (to_reveal_plot:IsCoastalLand() or to_reveal_plot:IsWater()) and lekmod_tonga_keep(to_reveal_plot, start_plot) then
               to_reveal_plot:SetRevealed(team, true);
            end
         end
      end

   end

end

function lekmod_tonga_ua()

   for _, player in pairs(Players) do
      if player:IsEverAlive() and player:GetCivilizationType() == this_civ then
         lekmod_tonga_explore(player)
      end
   end
   -- Redraw the fog now; with the patchy reveal it otherwise stayed until a unit was selected (user, 2026-10-27)
   Map.UpdateDeferredFog()
   if UI ~= nil and UI.RequestMinimapBroadcast ~= nil then
      UI:RequestMinimapBroadcast()
   end

end
------------------------------------------------------------------------------------------------------------------------
if is_active then
   Events.SequenceGameInitComplete.Add(lekmod_tonga_ua)
end