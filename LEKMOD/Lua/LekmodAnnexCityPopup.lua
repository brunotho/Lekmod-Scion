-- LEKMOD (2026-10-27): the popup when you click one of your puppets (BUTTONPOPUP_ANNEX_CITY) also offers Raze.
-- Included by GenericPopup.lua (Lua/tmp/ui/Popups) after the base popups, so this layout replaces the base one.
-- Conquered cities that can't be liberated become puppets without the capture popup, so this is where they are razed.
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_ANNEX_CITY] = function(popupInfo)

	local cityID		= popupInfo.Data1;
	local activePlayer	= Players[Game.GetActivePlayer()];
	local newCity		= activePlayer:GetCityByID(cityID);
	if newCity == nil then
		return;
	end

	SetPopupText(Locale.ConvertTextKey("TXT_KEY_POPUP_ANNEX_PUPPET", newCity:GetNameKey()));

	-- 'Annex City'
	local OnAnnexClicked = function()
		Network.SendDoTask(cityID, TaskTypes.TASK_ANNEX_PUPPET, -1, -1, false, false, false, false);
	end
	AddButton(Locale.ConvertTextKey("TXT_KEY_POPUP_ANNEX_CITY"), OnAnnexClicked);

	-- 'Raze' (same rules as in the capture popup: not your own cities, not original capitals)
	if activePlayer:CanRaze(newCity) and not newCity:IsRazing() then
		local iUnhappinessForRazing = activePlayer:GetUnhappinessForecast(newCity, nil) - activePlayer:GetUnhappiness();
		local OnRazeClicked = function()
			Network.SendDoTask(cityID, TaskTypes.TASK_RAZE, -1, -1, false, false, false, false);
		end
		AddButton(Locale.ConvertTextKey("TXT_KEY_POPUP_RAZE_CAPTURED_CITY"), OnRazeClicked,
			Locale.ConvertTextKey("TXT_KEY_POPUP_CITY_CAPTURE_INFO_RAZE", math.max(0, iUnhappinessForRazing)));
	end

	-- 'Leave City as a Puppet'
	AddButton(Locale.ConvertTextKey("TXT_KEY_POPUP_DONT_ANNEX_CITY"));

	-- 'View City'
	local OnViewCityClicked = function()
		UI.SetCityScreenViewingMode(true);
		UI.DoSelectCityAtPlot( newCity:Plot() );
	end
	AddButton(Locale.ConvertTextKey("TXT_KEY_POPUP_VIEW_CITY"), OnViewCityClicked, Locale.ConvertTextKey("TXT_KEY_POPUP_VIEW_CITY_DETAILS"));

	Controls.CloseButton:SetHide( false );
end
