-- LEKMOD: Great Scientist decay feedback (New Specs 11, 2026-11-05).
-- When a held Great Scientist's bulb value drops at the start of your turn (lobby option "no scientist saving"),
-- a red "-N Science" floats over the unit. Local only: nothing is sent over the network.

local g_LastAmount = {}   -- unit ID -> discover amount at the last check

local function LekmodIsScientist(unit)
	return unit ~= nil and unit.GetDiscoverAmount ~= nil and GameInfo.Units[unit:GetUnitType()].BaseBeakersTurnsToCount > 0
end

local function LekmodCheckScientists(bShow)
	local player = Players[Game.GetActivePlayer()]
	if player == nil or not player:IsAlive() then
		return
	end
	local seen = {}
	for unit in player:Units() do
		if LekmodIsScientist(unit) then
			local id = unit:GetID()
			local amount = unit:GetDiscoverAmount()
			local last = g_LastAmount[id]
			if bShow and last ~= nil and amount < last then
				local plot = unit:GetPlot()
				if plot ~= nil then
					local text = "[COLOR_NEGATIVE_TEXT]-" .. (last - amount) .. "[ENDCOLOR] [ICON_RESEARCH]"
					Events.AddPopupTextEvent(HexToWorld(ToHexFromGrid{x = plot:GetX(), y = plot:GetY()}), text, 1)
				end
			end
			g_LastAmount[id] = amount
			seen[id] = true
		end
	end
	for id in pairs(g_LastAmount) do
		if not seen[id] then
			g_LastAmount[id] = nil
		end
	end
end

Events.ActivePlayerTurnStart.Add(function() LekmodCheckScientists(true) end)
Events.LoadScreenClose.Add(function() LekmodCheckScientists(false) end)
-- A Great Scientist born during the turn: note its value so the first drop shows too
Events.SerialEventUnitCreated.Add(function(playerID, unitID)
	if playerID ~= Game.GetActivePlayer() then
		return
	end
	local player = Players[playerID]
	local unit = player and player:GetUnitByID(unitID)
	if LekmodIsScientist(unit) and g_LastAmount[unitID] == nil then
		g_LastAmount[unitID] = unit:GetDiscoverAmount()
	end
end)
