-------------------------------------------------
-- LEKMOD (2026-10-28): announcement banner at the top of the screen.
-- Big announcements also show as a banner for a few seconds (one after the other, fading in and out):
--   special City-State announcements (the DLL marks them with iExtraGameData LEKMOD_ANNOUNCEMENT_BANNER_MARKER),
--   a world wonder another civilization completed, and declarations of war.
-- The notification itself stays in the notification panel as usual. Click the banner to close it early.
-- Only the local player's own notifications; nothing is sent over the network.
-------------------------------------------------
local BANNER_MARKER = 4242 -- LEKMOD_ANNOUNCEMENT_BANNER_MARKER (_Defines.h)
local SHOW_SECONDS = 5.0
local FADE_SECONDS = 0.6

local g_tBannerTypes = {
	[NotificationTypes.NOTIFICATION_WONDER_COMPLETED] = true,
	[NotificationTypes.NOTIFICATION_WAR_ACTIVE_PLAYER] = true,
	[NotificationTypes.NOTIFICATION_WAR] = true,
};

local g_aQueue = {};
local g_tSeen = {};       -- notification ids already handled (the panel rebroadcasts them on load)
local g_bReady = false;   -- false until the game is on screen: notifications rebroadcast while loading are old
local g_fShown = -1;      -- seconds the current banner has been up; -1 = none

local function ShowNext()
	local entry = table.remove(g_aQueue, 1);
	if (entry == nil) then
		g_fShown = -1;
		Controls.Banner:SetHide(true);
		return;
	end
	Controls.Title:SetText(entry.Title);
	Controls.Body:SetText(entry.Body);
	Controls.Body:SetHide(entry.Body == "");
	Controls.BannerStack:CalculateSize();
	Controls.BannerStack:ReprocessAnchoring();
	local _, height = Controls.BannerStack:GetSizeVal();
	Controls.Banner:SetSizeVal(760, height + 36);
	Controls.BannerButton:SetSizeVal(760, height + 36);
	Controls.Banner:SetAlpha(0);
	Controls.Banner:SetHide(false);
	g_fShown = 0;
end

ContextPtr:SetUpdate(function(fDTime)
	if (g_fShown < 0) then
		return;
	end
	g_fShown = g_fShown + fDTime;
	local alpha = 1;
	if (g_fShown < FADE_SECONDS) then
		alpha = g_fShown / FADE_SECONDS;
	elseif (g_fShown > SHOW_SECONDS - FADE_SECONDS) then
		alpha = math.max(0, (SHOW_SECONDS - g_fShown) / FADE_SECONDS);
	end
	Controls.Banner:SetAlpha(alpha);
	if (g_fShown >= SHOW_SECONDS) then
		ShowNext();
	end
end);

Controls.BannerButton:RegisterCallback(Mouse.eLClick, function()
	if (g_fShown >= 0 and g_fShown < SHOW_SECONDS - FADE_SECONDS) then
		g_fShown = SHOW_SECONDS - FADE_SECONDS; -- fade out now
	end
end);

-- the first sentence of a long message is enough for the banner; the notification keeps the full text
local function ShortBody(strText)
	if (strText == nil) then
		return "";
	end
	local strFirst = string.match(strText, "^(.-%.)%s") or strText;
	if (string.len(strFirst) > 220) then
		strFirst = string.sub(strFirst, 1, 217) .. "...";
	end
	return strFirst;
end

Events.NotificationAdded.Add(function(Id, type, toolTip, strSummary, iGameValue, iExtraGameData, ePlayer)
	if (g_tSeen[Id]) then
		return;
	end
	g_tSeen[Id] = true;
	if (not g_bReady) then
		return;
	end
	if (ePlayer ~= nil and ePlayer ~= Game.GetActivePlayer()) then
		return;
	end
	if (iExtraGameData ~= BANNER_MARKER and not g_tBannerTypes[type]) then
		return;
	end
	table.insert(g_aQueue, { Title = strSummary or "", Body = ShortBody(toolTip) });
	if (g_fShown < 0) then
		ShowNext();
	end
end);

Events.LoadScreenClose.Add(function()
	g_bReady = true;
end);

ContextPtr:SetHide(false);
