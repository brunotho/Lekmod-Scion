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
local g_aKinds = { [0] = "GREAT_WORKS", [1] = "EXHIBITION", [2] = "VETERAN_GENERAL", [3] = "CAMBRIDGE" };
local CAMBRIDGE = 3;
local GREAT_WORK_VALUE = 400; -- LEKMOD_CAMBRIDGE_GREAT_WORK_VALUE
local g_tWorkInstances = {}; -- per auction row: the instance manager of its Great Work list

-- the active player's Great Works: { {Index, Name}, ... }
local function MyGreatWorks()
	local aWorks = {};
	local pPlayer = Players[Game.GetActivePlayer()];
	for pCity in pPlayer:Cities() do
		for building in GameInfo.Buildings() do
			if ((building.GreatWorkCount or 0) > 0 and pCity:IsHasBuilding(building.ID)) then
				local iClass = GameInfo.BuildingClasses[building.BuildingClass].ID;
				for iSlot = 0, building.GreatWorkCount - 1 do
					local iWork = pCity:GetBuildingGreatWork(iClass, iSlot);
					if (iWork ~= nil and iWork >= 0) then
						table.insert(aWorks, { Index = iWork, Name = Locale.ConvertTextKey(Game.GetGreatWorkName(iWork)) .. " (" .. pCity:GetName() .. ")" });
					end
				end
			end
		end
	end
	return aWorks;
end

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
		-- Cambridge: Great Works to offer (400 Gold each)
		local tChecks = {};
		if (g_tWorkInstances[inst.WorkStack] == nil) then
			g_tWorkInstances[inst.WorkStack] = InstanceManager:new("WorkInstance", "Check", inst.WorkStack);
		end
		local workIM = g_tWorkInstances[inst.WorkStack];
		workIM:ResetInstances();
		if (a.Index == CAMBRIDGE and a.MyBid <= 0 and g_tSent[a.Index] == nil and pPlayer:IsTurnActive()) then
			for _, w in ipairs(MyGreatWorks()) do
				local wi = workIM:GetInstance();
				wi.Check:GetTextButton():SetText(w.Name);
				wi.Check:SetCheck(false);
				table.insert(tChecks, { Check = wi.Check, Index = w.Index });
			end
		end
		inst.WorkStack:CalculateSize();
		inst.WorkStack:ReprocessAnchoring();
		local bBid = (a.MyBid > 0);
		local bCanBid = (not bBid) and (g_tSent[a.Index] == nil) and pPlayer:IsTurnActive();
		inst.BidRow:SetHide(not bCanBid);
		if (bBid and a.Index == CAMBRIDGE) then
			inst.Status:SetText(Locale.Lookup("TXT_KEY_LEKMOD_CAMBRIDGE_YOUR_OFFER", a.MyBid - a.MyWorks * GREAT_WORK_VALUE, a.MyWorks, a.MyBid));
		elseif (bBid) then
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
			local aOffered = {};
			for _, c in ipairs(tChecks) do
				if (c.Check:IsChecked()) then
					table.insert(aOffered, c.Index);
				end
			end
			if (iGold < 0 or iGold > pPlayer:GetGold() or (iGold == 0 and #aOffered == 0) or not pPlayer:IsTurnActive()) then
				inst.Status:SetText(Locale.Lookup("TXT_KEY_LEKMOD_AUCTION_BAD_BID", pPlayer:GetGold()));
				return;
			end
			g_tSent[iAuction] = iGold;
			for _, iWork in ipairs(aOffered) do
				Network.SendGiftUnit(iWork, -28); -- Cambridge: held like the Gold, before the Gold message closes the offer
			end
			Network.SendGiftUnit(iGold * 4 + iAuction, -26);
			LuaEvents.LekmodAuctionBidSent(iAuction); -- the big notification prompt goes away
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
