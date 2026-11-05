-- LEKMOD (2026-11-05, New Specs 10): promotion templates.
-- Per unit combat type (Armor, Gun, Melee, ...) two templates of up to 4 promotions. One of them may be Auto.
-- The templates live on this PC (Modding.OpenUserData "LekmodPromotionTemplates") and are sent to the game once
-- (Network -30, only entries that differ from what the game already has); the DLL keeps them in the save and applies
-- the Auto one itself when a unit is trained, bought or gifted by a City-State. A click (or Shift+1 / Shift+2) on a
-- template sends one message (-31 / -32) and the DLL gives the unit as many of its promotions as it can pick.
include( "IconSupport" );
include( "InstanceManager" );

local MAX_PROMOS = 4;
local NUM_SLOTS = 2;
local PICK_COLUMNS = 8;
local PICK_SIZE = 48;

local g_UserData = nil;
pcall( function() g_UserData = Modding.OpenUserData( "LekmodPromotionTemplates", 1 ); end );

local g_IconIM = { InstanceManager:new( "TemplateIconInstance", "Icon", Controls.Icons1 ),
                   InstanceManager:new( "TemplateIconInstance", "Icon", Controls.Icons2 ) };
local g_PickIM = InstanceManager:new( "PickInstance", "Button", Controls.PickArea );

local g_PendingSync = false;
local g_CurrentCombat = nil;   -- UnitCombatInfos row of the panel
local g_BuilderSlot = nil;
local g_BuilderSeq = {};

----------------------------------------------------------------
-- local storage: "<UNITCOMBAT>_<slot>" = "PROMOTION_A,PROMOTION_B", "<UNITCOMBAT>_AUTO" = slot (0 = none)
----------------------------------------------------------------
local function GetValue( key )
	if g_UserData == nil then return nil; end
	local ok, v = pcall( function() return g_UserData.GetValue( key ); end );
	if ok then return v; end
	return nil;
end
local function SetValue( key, value )
	if g_UserData == nil then return; end
	pcall( function() g_UserData.SetValue( key, value ); end );
end

-- the template's promotion rows (GameInfo.UnitPromotions), unknown types dropped
function LekmodPTLoad( combatType, slot )
	local list = {};
	local s = GetValue( combatType .. "_" .. slot );
	if type( s ) == "string" then
		for promoType in string.gmatch( s, "[^,]+" ) do
			local promo = GameInfo.UnitPromotions[promoType];
			if promo ~= nil and #list < MAX_PROMOS then
				table.insert( list, promo );
			end
		end
	end
	return list;
end
function LekmodPTAutoSlot( combatType )
	local v = tonumber( GetValue( combatType .. "_AUTO" ) ) or 0;
	if v >= 1 and v <= NUM_SLOTS and #LekmodPTLoad( combatType, v ) > 0 then
		return v;
	end
	return 0;
end
local function SaveTemplate( combatType, slot, list )
	local types = {};
	for _, promo in ipairs( list ) do
		table.insert( types, promo.Type );
	end
	SetValue( combatType .. "_" .. slot, table.concat( types, "," ) );
	if #list == 0 and LekmodPTAutoSlot( combatType ) == slot then
		SetValue( combatType .. "_AUTO", 0 );
	end
end

----------------------------------------------------------------
-- sending the templates to the game (only differences; never after the turn was ended: that would un-end it)
----------------------------------------------------------------
local function SendEntry( combatID, slot0, field, value )
	local data = ((combatID * NUM_SLOTS + slot0) * 5 + field) * 1024 + value + 1;
	Network.SendGiftUnit( data, -30 );
end
function LekmodPTSync()
	local pPlayer = Players[Game.GetActivePlayer()];
	if pPlayer == nil or pPlayer.LekmodGetPromotionTemplate == nil or not pPlayer:IsHuman() then
		return;
	end
	if Network.HasSentNetTurnComplete() then
		g_PendingSync = true;
		return;
	end
	g_PendingSync = false;
	for combat in GameInfo.UnitCombatInfos() do
		local autoSlot = LekmodPTAutoSlot( combat.Type );
		for slot = 1, NUM_SLOTS do
			local list = LekmodPTLoad( combat.Type, slot );
			local cur = { pPlayer:LekmodGetPromotionTemplate( combat.ID, slot - 1 ) };
			for field = 1, MAX_PROMOS do
				local want = (list[field] ~= nil) and list[field].ID or -1;
				if cur[field] ~= want then
					SendEntry( combat.ID, slot - 1, field - 1, want );
				end
			end
			-- Auto last, so the template is complete when it switches on (the game keeps only one Auto per type)
			local wantAuto = (autoSlot == slot) and 1 or 0;
			if cur[MAX_PROMOS + 1] ~= wantAuto and (wantAuto == 1 or autoSlot == 0) then
				SendEntry( combat.ID, slot - 1, MAX_PROMOS, wantAuto );
			end
		end
	end
end

----------------------------------------------------------------
-- promotions of a combat type and their prerequisites
----------------------------------------------------------------
local g_CombatPromos = {};   -- combat type -> list of promotion rows, in ID order
local g_OrPrereqs = nil;     -- promotion type -> list of types (any one of them)
local function CombatPromotions( combatType )
	if g_CombatPromos[combatType] ~= nil then
		return g_CombatPromos[combatType];
	end
	local list, seen = {}, {};
	for row in GameInfo.UnitPromotions_UnitCombats{ UnitCombatType = combatType } do
		local promo = GameInfo.UnitPromotions[row.PromotionType];
		if promo ~= nil and not seen[promo.ID] and not promo.CannotBeChosen and not promo.InstaHeal then
			seen[promo.ID] = true;
			table.insert( list, promo );
		end
	end
	table.sort( list, function( a, b ) return a.ID < b.ID; end );
	g_CombatPromos[combatType] = list;
	return list;
end
local function OrPrereqs( promo )
	if g_OrPrereqs == nil then
		g_OrPrereqs = {};
		pcall( function()
			for row in DB.Query( "SELECT PromotionType, PrerequisitePromotion FROM UnitPromotions_PromotionPrereqOrs" ) do
				g_OrPrereqs[row.PromotionType] = g_OrPrereqs[row.PromotionType] or {};
				table.insert( g_OrPrereqs[row.PromotionType], row.PrerequisitePromotion );
			end
		end );
	end
	local list = {};
	for _, t in ipairs( g_OrPrereqs[promo.Type] or {} ) do
		table.insert( list, t );
	end
	for i = 1, 9 do
		local t = promo["PromotionPrereqOr" .. i];
		if t ~= nil and t ~= "" then
			table.insert( list, t );
		end
	end
	return list;
end
-- can the promotion follow when the unit has (or the template already takes) the promotions in have[type]?
function LekmodPTPrereqsMet( promo, have )
	if promo.PromotionPrereq ~= nil and promo.PromotionPrereq ~= "" and not have[promo.PromotionPrereq] then
		return false;
	end
	local ors = OrPrereqs( promo );
	if #ors == 0 then
		return true;
	end
	for _, t in ipairs( ors ) do
		if have[t] then
			return true;
		end
	end
	return false;
end

----------------------------------------------------------------
-- the panel
----------------------------------------------------------------
local function SelectedUnit()
	local unit = UI.GetHeadSelectedUnit();
	if unit == nil or unit:GetOwner() ~= Game.GetActivePlayer() then
		return nil;
	end
	return unit;
end
local function UnitCombat( unit )
	if unit == nil then return nil; end
	local id = unit:GetUnitCombatType();
	if id == nil or id < 0 then return nil; end
	local combat = GameInfo.UnitCombatInfos[id];
	if combat == nil or #CombatPromotions( combat.Type ) == 0 then return nil; end
	return combat;
end
local function PromoNames( list )
	local names = {};
	for _, promo in ipairs( list ) do
		table.insert( names, "[ICON_BULLET]" .. Locale.ConvertTextKey( promo.Description ) );
	end
	return table.concat( names, "[NEWLINE]" );
end

function LekmodPTRefresh()
	if not Controls.Builder:IsHidden() then
		return;   -- the builder keeps its combat type until it closes
	end
	local unit = SelectedUnit();
	local combat = UnitCombat( unit );
	g_CurrentCombat = combat;
	if combat == nil or UI.IsCityScreenUp() then
		Controls.Panel:SetHide( true );
		return;
	end
	Controls.Panel:SetHide( false );
	local combatName = Locale.ConvertTextKey( combat.Description );
	Controls.Header:LocalizeAndSetText( "TXT_KEY_LEKMOD_PT_HEADER", combatName );
	local bReady = unit:IsPromotionReady();
	local autoSlot = LekmodPTAutoSlot( combat.Type );
	for slot = 1, NUM_SLOTS do
		local list = LekmodPTLoad( combat.Type, slot );
		local im = g_IconIM[slot];
		im:ResetInstances();
		local apply = Controls["Apply" .. slot];
		if #list == 0 then
			Controls["New" .. slot]:SetHide( false );
			Controls["Auto" .. slot]:SetHide( true );
			Controls["Delete" .. slot]:SetHide( true );
			apply:SetDisabled( false );
			apply:SetAlpha( 1 );
			apply:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_LEKMOD_PT_NEW_TT", combatName ) );
		else
			Controls["New" .. slot]:SetHide( true );
			Controls["Auto" .. slot]:SetHide( false );
			Controls["Delete" .. slot]:SetHide( false );
			for _, promo in ipairs( list ) do
				local inst = im:GetInstance();
				IconHookup( promo.PortraitIndex, 32, promo.IconAtlas, inst.Icon );
				-- promotions the unit already has are skipped: show them dimmed
				inst.Icon:SetAlpha( unit:IsHasPromotion( promo.ID ) and 0.35 or 1 );
			end
			Controls["Icons" .. slot]:CalculateSize();
			local tt = Locale.ConvertTextKey( "TXT_KEY_LEKMOD_PT_APPLY_TT", slot, PromoNames( list ) );
			if not bReady then
				tt = tt .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey( "TXT_KEY_LEKMOD_PT_NOT_READY" );
			end
			apply:SetToolTipString( tt );
			apply:SetDisabled( not bReady );
			apply:SetAlpha( bReady and 1 or 0.6 );
			local bAuto = (autoSlot == slot);
			Controls["AutoLabel" .. slot]:SetText( Locale.ConvertTextKey( bAuto and "TXT_KEY_LEKMOD_PT_AUTO_ON" or "TXT_KEY_LEKMOD_PT_AUTO" ) );
			Controls["Auto" .. slot]:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_LEKMOD_PT_AUTO_TT", combatName ) );
		end
	end
end

local function ApplyTemplate( slot )
	local unit = SelectedUnit();
	local combat = UnitCombat( unit );
	if combat == nil or #LekmodPTLoad( combat.Type, slot ) == 0 or not unit:IsPromotionReady() then
		return false;
	end
	if Players[Game.GetActivePlayer()].LekmodGetPromotionTemplate == nil then
		return false;
	end
	LekmodPTSync();   -- the game must have this PC's version of the template first (sends nothing when it already has)
	Network.SendGiftUnit( unit:GetID(), (slot == 1) and -31 or -32 );
	return true;
end

local function OnApply( slot )
	if g_CurrentCombat == nil then return; end
	if #LekmodPTLoad( g_CurrentCombat.Type, slot ) == 0 then
		LekmodPTOpenBuilder( slot );
	else
		ApplyTemplate( slot );
	end
end
local function OnAuto( slot )
	if g_CurrentCombat == nil then return; end
	local cur = LekmodPTAutoSlot( g_CurrentCombat.Type );
	SetValue( g_CurrentCombat.Type .. "_AUTO", (cur == slot) and 0 or slot );
	LekmodPTSync();
	LekmodPTRefresh();
end
local function OnDelete( slot )
	if g_CurrentCombat == nil then return; end
	SaveTemplate( g_CurrentCombat.Type, slot, {} );
	LekmodPTSync();
	LekmodPTRefresh();
end
for slot = 1, NUM_SLOTS do
	local s = slot;
	Controls["Apply" .. s]:RegisterCallback( Mouse.eLClick, function() OnApply( s ); end );
	Controls["Auto" .. s]:RegisterCallback( Mouse.eLClick, function() OnAuto( s ); end );
	Controls["Delete" .. s]:RegisterCallback( Mouse.eLClick, function() OnDelete( s ); end );
end

----------------------------------------------------------------
-- the builder
----------------------------------------------------------------
local function BuilderHave()
	local have = {};
	local unit = SelectedUnit();
	for _, promo in ipairs( CombatPromotions( g_CurrentCombat.Type ) ) do
		if unit ~= nil and unit:IsHasPromotion( promo.ID ) then
			have[promo.Type] = true;
		end
	end
	for _, promo in ipairs( g_BuilderSeq ) do
		have[promo.Type] = true;
	end
	return have;
end

function LekmodPTBuilderRefresh()
	for i = 1, MAX_PROMOS do
		local img = Controls["Seq" .. i];
		local promo = g_BuilderSeq[i];
		if promo ~= nil then
			IconHookup( promo.PortraitIndex, 45, promo.IconAtlas, img );
			img:SetHide( false );
			img:SetToolTipString( Locale.ConvertTextKey( promo.Description ) );
		else
			img:SetHide( true );
		end
	end
	local have = BuilderHave();
	local inSeq = {};
	for _, promo in ipairs( g_BuilderSeq ) do inSeq[promo.ID] = true; end
	local bFull = (#g_BuilderSeq >= MAX_PROMOS);

	g_PickIM:ResetInstances();
	local list = CombatPromotions( g_CurrentCombat.Type );
	for i, promo in ipairs( list ) do
		local inst = g_PickIM:GetInstance();
		local col = (i - 1) % PICK_COLUMNS;
		local row = math.floor( (i - 1) / PICK_COLUMNS );
		inst.Button:SetOffsetVal( col * PICK_SIZE, row * PICK_SIZE );
		IconHookup( promo.PortraitIndex, 45, promo.IconAtlas, inst.Icon );
		local bOk = not bFull and not inSeq[promo.ID] and LekmodPTPrereqsMet( promo, have );
		inst.Button:SetDisabled( not bOk );
		inst.Icon:SetAlpha( bOk and 1 or 0.3 );
		local tt = Locale.ConvertTextKey( promo.Description );
		if promo.Help ~= nil then
			tt = tt .. "[NEWLINE]" .. Locale.ConvertTextKey( promo.Help );
		end
		inst.Button:SetToolTipString( tt );
		local p = promo;
		inst.Button:RegisterCallback( Mouse.eLClick, function()
			if #g_BuilderSeq < MAX_PROMOS then
				table.insert( g_BuilderSeq, p );
				LekmodPTBuilderRefresh();
			end
		end );
	end
	local rows = math.max( 1, math.ceil( #list / PICK_COLUMNS ) );
	Controls.PickArea:SetSizeVal( PICK_COLUMNS * PICK_SIZE, rows * PICK_SIZE );
	Controls.PickScroll:CalculateInternalSize();
	Controls.UndoButton:SetDisabled( #g_BuilderSeq == 0 );
	Controls.SaveButton:SetDisabled( #g_BuilderSeq == 0 );
end

function LekmodPTOpenBuilder( slot )
	if g_CurrentCombat == nil then return; end
	g_BuilderSlot = slot;
	g_BuilderSeq = {};
	Controls.BuilderTitle:LocalizeAndSetText( "TXT_KEY_LEKMOD_PT_BUILDER_TITLE", Locale.ConvertTextKey( g_CurrentCombat.Description ) );
	Controls.Builder:SetHide( false );
	LekmodPTBuilderRefresh();
end
local function CloseBuilder()
	Controls.Builder:SetHide( true );
	g_BuilderSlot = nil;
	g_BuilderSeq = {};
	LekmodPTRefresh();
end
Controls.UndoButton:RegisterCallback( Mouse.eLClick, function()
	table.remove( g_BuilderSeq );
	LekmodPTBuilderRefresh();
end );
Controls.SaveButton:RegisterCallback( Mouse.eLClick, function()
	if g_CurrentCombat ~= nil and g_BuilderSlot ~= nil and #g_BuilderSeq > 0 then
		SaveTemplate( g_CurrentCombat.Type, g_BuilderSlot, g_BuilderSeq );
		LekmodPTSync();
	end
	CloseBuilder();
end );
Controls.CancelButton:RegisterCallback( Mouse.eLClick, CloseBuilder );

----------------------------------------------------------------
-- input: Shift+1 / Shift+2 apply a template; Esc closes the builder
----------------------------------------------------------------
ContextPtr:SetInputHandler( function( uiMsg, wParam, lParam )
	if uiMsg ~= KeyEvents.KeyDown then
		return false;
	end
	if not Controls.Builder:IsHidden() then
		if wParam == Keys.VK_ESCAPE then
			CloseBuilder();
		end
		return true;
	end
	if UI.ShiftKeyDown() and not UI.CtrlKeyDown() and not UI.AltKeyDown() and (wParam == 49 or wParam == 50) then
		return ApplyTemplate( wParam - 48 );
	end
	return false;
end );

----------------------------------------------------------------
-- events
----------------------------------------------------------------
Events.SerialEventUnitInfoDirty.Add( LekmodPTRefresh );
Events.UnitSelectionChanged.Add( function() LekmodPTRefresh(); end );
Events.SerialEventEnterCityScreen.Add( LekmodPTRefresh );
Events.SerialEventExitCityScreen.Add( LekmodPTRefresh );
Events.ActivePlayerTurnStart.Add( function()
	LekmodPTSync();
	LekmodPTRefresh();
end );
Events.GameplaySetActivePlayer.Add( function()
	CloseBuilder();
	LekmodPTSync();
end );
Events.LoadScreenClose.Add( LekmodPTSync );
