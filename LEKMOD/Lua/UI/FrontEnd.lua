-- modified by Temudjin from 1.0.3.142 code
-------------------------------------------------
-- FrontEnd
-------------------------------------------------

-- Flipped to true by ui_check.bat / the installer. include() cannot see extra
-- files dumped in Lua/UI, so this flag lives in the FrontEnd script itself.
local LEKMOD_UI_CHECK_DONE = false

local function MarkLekmodUiCheckDone()
	pcall(function()
		local userData = Modding.OpenUserData("LekmodUiCheck", 1);
		userData.SetValue("done", 1);
	end);
end

local function IsUiCheckConfigured()
	if LEKMOD_UI_CHECK_DONE then
		return true;
	end
	local previous = LekmodUiConfigured;
	LekmodUiConfigured = nil;
	pcall(function()
		include("LekmodUiConfigured");
	end);
	local ok = LekmodUiConfigured == true;
	LekmodUiConfigured = previous;
	if ok then
		return true;
	end
	local userOk = false;
	pcall(function()
		local userData = Modding.OpenUserData("LekmodUiCheck", 1);
		userOk = userData.GetValue("done") == 1;
	end);
	return userOk;
end


function ShowHideHandler( bIsHide, bIsInit )

		-- Check for game invites first.  If we have a game invite, we will have flipped 
		-- the Civ5App::eHasShownLegal and not show the legal/touch screens.
		UI:CheckForCommandLineInvitation();

    if not bIsHide then
        Controls.AtlasLogo:SetTexture( "lekmod_menu_background.dds" ); -- LEKMOD: main menu background
    	UIManager:SetUICursor( 0 );
		if not IsUiCheckConfigured() then
			-- Manual install without ui_check.bat: block the menus.
			UIManager:QueuePopup( Controls.LegalScreen, PopupPriority.LegalScreen );
		else
			MarkLekmodUiCheckDone();
			UIManager:QueuePopup( Controls.MainMenu, PopupPriority.MainMenu );
		end
    else
        Controls.AtlasLogo:UnloadTexture();
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );
