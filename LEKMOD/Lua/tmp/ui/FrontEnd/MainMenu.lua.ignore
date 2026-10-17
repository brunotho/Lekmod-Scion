-------------------------------------------------
-- Main Menu
-------------------------------------------------
include( "MPGameDefaults" );
include( "Lekmod_version.lua" );

-------------------------------------------------
-- Script Body
-------------------------------------------------
local bHideUITest = true;
local bHideGridExamples = true;
local bHideLoadGame = true;
local bHidePreGame = true;
local fTime = 0;
local i1, i2 = string.find( UI.GetVersionInfo(), " " );
versionNumber = string.sub(UI.GetVersionInfo(), 1, i2-1);
Controls.VersionNumber:SetText(versionNumber);

-------------------------------------------------
-- Lekmod version status (Network.HttpRequest on FrontEnd)
-------------------------------------------------
local g_LekmodDownloadUrl = nil;
local g_LekmodVersionCheckActive = false;

local function LookupOrFallback(key, fallback)
	local text = Locale.Lookup(key);
	if text == nil or text == "" or text == key then
		return fallback;
	end
	return text;
end

local function ApplyLekmodVersionInfo(info)
	if Controls.LekmodVersionLabel == nil then
		return;
	end

	local localVersion = (info and info.Local) or LekmodVersion.GetLocal() or "unknown";
	g_LekmodDownloadUrl = info and info.DownloadUrl or nil;

	if info ~= nil and info.Success and info.IsNewer then
		local label = Locale.ConvertTextKey("TXT_KEY_LEKMOD_MENU_VERSION_OUTDATED", localVersion, info.Latest);
		if label == "TXT_KEY_LEKMOD_MENU_VERSION_OUTDATED" then
			label = "Running Lekmod Rosebranch " .. localVersion .. " - Newer version detected (" .. tostring(info.Latest) .. ") [CLICK TO DOWNLOAD]";
		end
		Controls.LekmodVersionLabel:SetText(label);
		local tip = LookupOrFallback("TXT_KEY_LEKMOD_MENU_VERSION_TT_OUTDATED", "A newer Lekmod build is available. Click to download.");
		Controls.LekmodVersionButton:SetToolTipString(tip);
	elseif info ~= nil and info.Success then
		local label = Locale.ConvertTextKey("TXT_KEY_LEKMOD_MENU_VERSION_UPTODATE", localVersion);
		if label == "TXT_KEY_LEKMOD_MENU_VERSION_UPTODATE" then
			label = "Running Lekmod Rosebranch " .. localVersion .. " - Up to date!";
		end
		Controls.LekmodVersionLabel:SetText(label);
		local tip = LookupOrFallback("TXT_KEY_LEKMOD_MENU_VERSION_TT_UPTODATE", "Your Lekmod install matches the latest installer version.");
		Controls.LekmodVersionButton:SetToolTipString(tip);
		g_LekmodDownloadUrl = nil;
	else
		local err = tostring((info and info.Error) or "unreachable");
		local label = Locale.ConvertTextKey("TXT_KEY_LEKMOD_MENU_VERSION_UNREACHABLE", localVersion);
		if label == "TXT_KEY_LEKMOD_MENU_VERSION_UNREACHABLE" then
			label = "Running Lekmod Rosebranch " .. localVersion .. " - Cannot reach update server";
		end
		Controls.LekmodVersionLabel:SetText(label);
		local tip = LookupOrFallback("TXT_KEY_LEKMOD_MENU_VERSION_TT_UNREACHABLE", "Could not reach the online version list. Check your internet connection.");
		tip = tip .. " [" .. err .. "]";
		Controls.LekmodVersionButton:SetToolTipString(tip);
		g_LekmodDownloadUrl = nil;
	end
end

local function FinishLekmodVersionCheck(info)
	g_LekmodVersionCheckActive = false;
	ContextPtr:ClearUpdate();
	ApplyLekmodVersionInfo(info);
end

local function BeginLekmodHttpVersionCheck()
	local req, urlIndex = LekmodVersion.StartHttpVersionsRequest(1);
	if req == nil then
		FinishLekmodVersionCheck(LekmodVersion.UnreachableResult("request-failed"));
		return;
	end

	local t1 = os.time();
	local tdelta = 0;
	local timeout = LekmodVersion.HTTP_TIMEOUT or 10;

	ContextPtr:SetUpdate(function()
		local t2 = os.time();
		if t2 - t1 > tdelta then
			tdelta = t2 - t1;
		end

		local finished = false;
		local okFinished, isFinished = pcall(function()
			return req.Finished();
		end);
		if okFinished and isFinished then
			finished = true;
		end

		if finished then
			local body = nil;
			pcall(function()
				body = req.PopReceivedData();
			end);
			if body ~= nil and body ~= "" then
				FinishLekmodVersionCheck(LekmodVersion.ResultFromVersionsBody(body, "http"));
				return;
			end

			-- First URL empty/failed: try jsDelivr once.
			if urlIndex == 1 then
				local req2, idx2 = LekmodVersion.StartHttpVersionsRequest(2);
				if req2 ~= nil then
					req = req2;
					urlIndex = idx2;
					t1 = os.time();
					tdelta = 0;
					return;
				end
			end

			FinishLekmodVersionCheck(LekmodVersion.UnreachableResult("no-connection"));
		elseif tdelta >= timeout then
			FinishLekmodVersionCheck(LekmodVersion.UnreachableResult("timeout"));
		end
	end);
end

local function UpdateLekmodVersionLabel()
	if Controls.LekmodVersionLabel == nil then
		return;
	end
	if g_LekmodVersionCheckActive then
		return;
	end

	local localVersion = LekmodVersion.GetLocal() or "unknown";
	Controls.LekmodVersionLabel:SetText(Locale.ConvertTextKey("TXT_KEY_LEKMOD_MENU_VERSION_CHECKING", localVersion));
	if Controls.LekmodVersionLabel:GetText() == "TXT_KEY_LEKMOD_MENU_VERSION_CHECKING" then
		Controls.LekmodVersionLabel:SetText("Running Lekmod Rosebranch " .. localVersion .. " - Checking for updates...");
	end

	g_LekmodVersionCheckActive = true;

	if LekmodVersion.HasHttpRequest and LekmodVersion.HasHttpRequest() then
		BeginLekmodHttpVersionCheck();
	else
		FinishLekmodVersionCheck(LekmodVersion.UnreachableResult("no-http-api"));
	end
end

function OnLekmodVersionClicked()
	if g_LekmodDownloadUrl ~= nil then
		LekmodVersion.OpenDownload(g_LekmodDownloadUrl);
	end
end
if Controls.LekmodVersionButton ~= nil then
	Controls.LekmodVersionButton:RegisterCallback(Mouse.eLClick, OnLekmodVersionClicked);
end
UpdateLekmodVersionLabel();


function ShowHideHandler( bIsHide, bIsInit )
    if( not bIsHide ) then
        Controls.Civ5Logo:SetTexture( "CivilzationV_Logo.dds" );

        UpdateLekmodVersionLabel();

        if (not ContextPtr:IsHotLoad()) then
			-- This is a catch all to ensure that mods are not activated at this point in the UI.
			-- Also, since certain maps and settings will only be available in either the modding or multiplayer
			-- screen, we want to ensure that "safe" settings are loaded that can be used for either SP, MP or Mods.
			-- Activating the DLC (there doesn't have to be any) will make sure no mods are active and all the user's
			-- purchased content is available
			UIManager:SetUICursor( 1 );
			Modding.ActivateDLC();
			PreGame.LoadPreGameSettings();
			UIManager:SetUICursor( 0 );
			
			-- Send out an event to continue on, as the ActivateDLC may have swapped out the UI	
			Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "MainMenu" );
		end
    else
        Controls.Civ5Logo:UnloadTexture();
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-------------------------------------------------
-- StartGame Button Handler
-------------------------------------------------
function SinglePlayerClick()
	UIManager:QueuePopup( Controls.SinglePlayerScreen, PopupPriority.SinglePlayerScreen );
end
Controls.SinglePlayerButton:RegisterCallback( Mouse.eLClick, SinglePlayerClick );

-------------------------------------------------
-- Multiplayer Button Handler
-------------------------------------------------
function MultiplayerClick()
    UIManager:QueuePopup( Controls.MultiplayerSelectScreen, PopupPriority.MultiplayerSelectScreen );
end
Controls.MultiplayerButton:RegisterCallback( Mouse.eLClick, MultiplayerClick );


-------------------------------------------------
-- Mods button handler
-------------------------------------------------
function ModsButtonClick()
    UIManager:QueuePopup( Controls.ModsEULAScreen, PopupPriority.ModsEULAScreen );
end
Controls.ModsButton:RegisterCallback( Mouse.eLClick, ModsButtonClick );


-------------------------------------------------
-- Options Button Handler
-------------------------------------------------
function OptionsClick()
    UIManager:QueuePopup( Controls.OptionsMenu_FrontEnd, PopupPriority.OptionsMenu );
end
Controls.OptionsButton:RegisterCallback( Mouse.eLClick, OptionsClick );


-------------------------------------------------
-- Hall Of Fame Button Handler
-------------------------------------------------
function OtherClick()
    UIManager:QueuePopup( Controls.Other, PopupPriority.OtherMenu );
end
Controls.OtherButton:RegisterCallback( Mouse.eLClick, OtherClick );


-------------------------------------------------
-- Discord / GitHub link buttons
-------------------------------------------------
local LEKMOD_DISCORD_URL = "http://discord.gg/VQBNPmc";
local LEKMOD_GITHUB_URL = "http://github.com/EnormousApplePie/Lekmod";

local function OpenExternalUrl(url)
	-- Force http:// for Steam overlay compatibility.
	local target = tostring(url or "");
	if string.sub(target, 1, 8) == "https://" then
		target = "http://" .. string.sub(target, 9);
	elseif string.sub(target, 1, 7) ~= "http://" then
		target = "http://" .. target;
	end

	local ok = pcall(function()
		Steam.ActivateGameOverlayToWebPage(target);
	end);
	if not ok and LekmodVersion ~= nil and LekmodVersion.OpenDownload ~= nil then
		LekmodVersion.OpenDownload(target);
	end
end

function DiscordClick()
	OpenExternalUrl(LEKMOD_DISCORD_URL);
end
function GitHubClick()
	OpenExternalUrl(LEKMOD_GITHUB_URL);
end

if Controls.DiscordButton ~= nil then
	Controls.DiscordButton:RegisterCallback(Mouse.eLClick, DiscordClick);
	local tip = Locale.Lookup("TXT_KEY_LEKMOD_MENU_DISCORD_TT");
	if tip == nil or tip == "" or tip == "TXT_KEY_LEKMOD_MENU_DISCORD_TT" then
		tip = "Join the Lekmod Discord";
	end
	Controls.DiscordButton:SetToolTipString(tip);
end
if Controls.GitHubButton ~= nil then
	Controls.GitHubButton:RegisterCallback(Mouse.eLClick, GitHubClick);
	local tip = Locale.Lookup("TXT_KEY_LEKMOD_MENU_GITHUB_TT");
	if tip == nil or tip == "" or tip == "TXT_KEY_LEKMOD_MENU_GITHUB_TT" then
		tip = "Open the Lekmod GitHub repository";
	end
	Controls.GitHubButton:SetToolTipString(tip);
end



-------------------------------------------------
-- Exit Button Handler
-------------------------------------------------
function OnExitGame()
	Events.UserRequestClose();
end
Controls.ExitButton:RegisterCallback( Mouse.eLClick, OnExitGame );


----------------------------------------------------------------        
----------------------------------------------------------------
Steam.SetOverlayNotificationPosition( "bottom_left" );

-------------------------------------------------
-- Event Handler: MultiplayerGameLaunched
-------------------------------------------------
function OnGameLaunched()
	UIManager:DequeuePopup( ContextPtr );
end
Events.MultiplayerGameLaunched.Add( OnGameLaunched );


----------------------------------------------------------------        
function OnExpansionRulesSwitch()
	UIManager:QueuePopup( Controls.PremiumContentScreen, PopupPriority.OtherMenu );
end		
Controls.ExpansionRulesSwitch:RegisterCallback(Mouse.eLClick, OnExpansionRulesSwitch);

-------------------------------------------------------------------------------
function OnSystemUpdateUI( type, tag  )
    if( type == SystemUpdateUIType.RestoreUI) then
		if (tag == "MainMenu") then
			-- Look for any cached invite
			UI:CheckForCommandLineInvitation();
			if (Network.IsDedicatedServer()) then
					ResetMultiplayerOptions(); 
			    UIManager:QueuePopup( ContextPtr:LookUpControl( "DedicatedServerScreen" ), PopupPriority.LobbyScreen );
			end
		elseif (tag == "StagingRoom") then
			if (UIManager:GetVisibleNamedContext("StagingRoom") == nil) then
				UIManager:QueuePopup( Controls.StagingRoomScreen, PopupPriority.StagingScreen );
			end
		elseif (tag == "ScenariosMenuReset") then			
			local pScenarioScreen = ContextPtr:LookUpControl( "SinglePlayerScreen/ScenariosScreen" );
			if (pScenarioScreen ~= nil) then
				if (pScenarioScreen:IsHidden()) then						
					UIManager:QueuePopup( pScenarioScreen, PopupPriority.GameSetupScreen );
				end
			end
		elseif (tag == "ModsBrowserReset") then
			local pModsMenu = ContextPtr:LookUpControl("ModsEULAScreen/ModsBrowser" );
			if(pModsMenu ~= nil) then
				if(pModsMenu:IsHidden()) then
					UIManager:QueuePopup(pModsMenu, PopupPriority.ModsBrowserScreen);
				end
			end 
		elseif (tag == "ModsMenu" ) then
			local pModsMenu = ContextPtr:LookUpControl("ModsEULAScreen/ModsBrowser/ModsMenu" );
			if(pModsMenu ~= nil) then
				if(pModsMenu:IsHidden()) then
					UIManager:QueuePopup(pModsMenu, PopupPriority.ModsMenuScreen);
				end
			end 
	    end
	end
end

Events.SystemUpdateUI.Add( OnSystemUpdateUI );

-------------------------------------------------------------------------------
if Controls.TouchHelpButton ~= nil then
	Controls.TouchHelpButton:SetHide( true );
end
if Controls.TouchControlsMenu ~= nil then
	Controls.TouchControlsMenu:SetHide( true );
end
