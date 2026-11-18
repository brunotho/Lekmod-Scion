-- LEKMOD: combat sounds (New Specs 12, 2026-11-18).
-- A unit of yours that dies attacking in melee plays the sound of a wonder built by another player.
-- The game core calls GameEvents.LekmodMeleeAttackerDied(owner, unitType) on every machine; only the owner hears it.
-- Local only: nothing is sent over the network.

local function LekmodOnMeleeAttackerDied(iPlayer, iUnitType)
	if iPlayer == Game.GetActivePlayer() then
		Events.AudioPlay2DSound("AS2D_INTERFACE_OTHER_CIV_WONDER")
	end
end

if GameEvents.LekmodMeleeAttackerDied ~= nil then
	GameEvents.LekmodMeleeAttackerDied.Add(LekmodOnMeleeAttackerDied)
end
