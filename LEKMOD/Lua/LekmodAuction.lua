-------------------------------------------------
-- LEKMOD: special City-State auctions (LEKMOD_SPECIAL_CITY_STATES; CvGame::LekmodDoAuctions)
-- An auction runs for one turn: every human civilization may place one sealed Gold bid. The Gold is held
-- right away; the result comes at the start of the next turn (winner announced, the others refunded).
-- Opens by itself when an auction starts; LuaEvents.LekmodShowAuctions() opens it again (City-State screen).
-- The bid goes over the network as Network.SendGiftUnit(Gold * 4 + auction, -26).
-------------------------------------------------
include("InstanceManager");

local g_Instances = InstanceManager:new("AuctionInstance", "Root", Controls.AuctionStack);
local g_iShownTurn = -1;
local g_tSent = {}; -- auctions this machine already sent a bid for (until the bid arrives back)
local g_aKinds = { [0] = "GREAT_WORKS", [1] = "EXHIBITION", [2] = "VETERAN_GENERAL" };

local function Close()
	UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, Close);

ContextPtr:SetInputHandler(function(uiMsg, wParam, lParam)
	if (uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE) then
		Close();
		return true;
	end
end);

local function OpenAuctions()
	local aOpen = {};
	if (Game.LekmodGetAuctions == nil) then
		return aOpen;
	end
	for _, a in ipairs(Game.LekmodGetAuctions(Game.GetActivePlayer())) do
		if (a.State == 1 and a.OpenTurn == Game.GetGameTurn() and g_aKinds[a.Index] ~= nil) then
			table.insert(aOpen, a);
		end
	end
	return aOpen;
end

local function Refresh()
	local pPlayer = Players[Game.GetActivePlayer()];
	g_Instances:ResetInstances();
	for _, a in ipairs(OpenAuctions()) do
		local inst = g_Instances:GetInstance();
		local strMinor = Players[a.Minor]:GetCivilizationShortDescriptionKey();
		inst.Heading:SetText(Locale.Lookup("TXT_KEY_LEKMOD_AUCTION_HEADING_" .. g_aKinds[a.Index], strMinor));
		inst.Description:SetText(Locale.Lookup("TXT_KEY_LEKMOD_AUCTION_RULES_" .. g_aKinds[a.Index]));
		local bBid = (a.MyBid > 0);
		local bCanBid = (not bBid) and (g_tSent[a.Index] == nil) and pPlayer:IsTurnActive();
		inst.BidRow:SetHide(not bCanBid);
		if (bBid) then
			inst.Status:SetText(Locale.Lookup("TXT_KEY_LEKMOD_AUCTION_YOUR_BID", a.MyBid));
		elseif (g_tSent[a.Index] ~= nil) then
			inst.Status:SetText(Locale.Lookup("TXT_KEY_LEKMOD_AUCTION_SENDING"));
		else
			inst.Status:SetText(Locale.Lookup("TXT_KEY_LEKMOD_AUCTION_NO_BID_YET"));
		end
		local iAuction = a.Index;
		inst.BidButton:RegisterCallback(Mouse.eLClick, function()
			local iGold = tonumber(inst.BidEdit:GetText()) or 0;
			iGold = math.floor(iGold);
			if (iGold <= 0 or iGold > pPlayer:GetGold() or not pPlayer:IsTurnActive()) then
				inst.Status:SetText(Locale.Lookup("TXT_KEY_LEKMOD_AUCTION_BAD_BID", pPlayer:GetGold()));
				return;
			end
			g_tSent[iAuction] = iGold;
			Network.SendGiftUnit(iGold * 4 + iAuction, -26);
			Refresh();
		end);
	end
	Controls.Gold:SetText(Locale.Lookup("TXT_KEY_LEKMOD_AUCTION_GOLD", pPlayer:GetGold()));
	Controls.AuctionStack:CalculateSize();
	Controls.AuctionStack:ReprocessAnchoring();
	Controls.Content:CalculateSize();
	Controls.Content:ReprocessAnchoring();
	local width, height = Controls.Content:GetSizeVal();
	Controls.Frame:SetSizeVal(580, height + 90);
end

local function Show()
	if (#OpenAuctions() == 0) then
		return;
	end
	Refresh();
	UIManager:QueuePopup(ContextPtr, PopupPriority.VoteResults);
end
LuaEvents.LekmodShowAuctions.Add(Show);

-- an auction starts with the turn: open once per turn by itself
local function OnTurnStart()
	g_tSent = {};
	if (g_iShownTurn == Game.GetGameTurn()) then
		return;
	end
	if (#OpenAuctions() > 0) then
		g_iShownTurn = Game.GetGameTurn();
		Show();
	end
end
Events.ActivePlayerTurnStart.Add(OnTurnStart);

-- the bid arrived (Gold changed): show it
Events.SerialEventGameDataDirty.Add(function()
	if (not ContextPtr:IsHidden()) then
		for _, a in ipairs(OpenAuctions()) do
			if (a.MyBid > 0) then
				g_tSent[a.Index] = nil;
			end
		end
		Refresh();
	end
end);

ContextPtr:SetHide(true);
