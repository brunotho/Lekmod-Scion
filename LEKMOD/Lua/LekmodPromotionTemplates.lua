-- LEKMOD (2026-11-05, New Specs 10): promotion templates.
-- Per unit combat type (Armor, Gun, Melee, ...) two templates of up to 4 promotions. One of them may be Auto.
-- The templates live on this PC (Modding.OpenUserData "LekmodPromotionTemplates") and are sent to the game once
-- (Network -30, only entries that differ from what the game already has); the DLL keeps them in the save and applies
-- the Auto one itself when a unit is trained, bought or gifted by a City-State. A click (or Shift+1 / Shift+2) on a
-- template sends one message (-31 / -32) and the DLL gives the unit as many of its promotions as it can pick.
--
-- Visibility: the panel opens by itself when the selected unit can pick a promotion and its type has no Auto
-- template (the X closes it for that unit until its state changes). "Always show" (Alt+T, or Map Options >
-- Promotion templates; option LEK_PromoTemplatesShown) keeps it open, also without a selected unit.
include( "IconSupport" );
include( "InstanceManager" );

local MAX_PROMOS = 4;
local NUM_SLOTS = 2;
local PICK_COLUMNS = 8;
local PICK_SIZE = 48;

local g_UserData = nil;
pcall( function() g_UserData = Modding.OpenUserData( "LekmodPromotionTemplates", 1 ); end );
local g_Options = nil;
pcall( function() g_Options = Modding.OpenUserData( "Enhanced User Interface Options", 1 ); end );

local g_IconIM = { InstanceManager:new( "TemplateIconInstance", "Icon", Controls.Icons1 ),
                   InstanceManager:new( "TemplateIconInstance", "Icon", Controls.Icons2 ) };
local g_PickIM = InstanceManager:new( "PickInstance", "Button", Controls.PickArea );

local g_PendingSync = false;
local g_ViewCombat = nil;      -- UnitCombatInfos row the panel shows (follows the selected unit, or the dropdown)
local g_LastUnit = nil;        -- ID of the unit the view last followed
local g_BuilderSlot = nil;
local g_BuilderSeq = {};
local g_DismissUnit = nil;     -- the X closed the automatic panel for this unit ...
local g_DismissReady = nil;    -- ... while its "can pick a promotion" state stays the same

----------------------------------------------------------------
-- local storage: "<UNITCOMBAT>_<slot>" = "PROMOTION_A,PROMOTION_B". Auto is not stored on the PC: it belongs to the
-- game (the DLL saves it), so every new game starts with Auto off (user, 2026-11-05)
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
local g_AutoSlot = {};   -- combat type -> slot marked Auto in this game (read from the game at load, then kept here)
function LekmodPTAutoSlot( combatType )
	local v = g_AutoSlot[combatType] or 0;
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
		g_AutoSlot[combatType] = 0;
	end
end

-- "Always show" option
function LekmodPTAlwaysShown()
	return g_Options ~= nil and g_Options.GetValue( "LEK_PromoTemplatesShown" ) == 1;
end
local function SetAlwaysShown( bOn )
	if g_Options ~= nil then
		g_Options.SetValue( "LEK_PromoTemplatesShown", bOn and 1 or 0 );
	end
	LuaEvents.LekmodPromoTemplatesShownChanged();
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

local function SelectedUnit()
	local unit = UI.GetHeadSelectedUnit();
	if unit == nil or unit:GetOwner() ~= Game.GetActivePlayer() then
		return nil;
	end
	return unit;
end
-- what a fresh unit of this type starts with: only promotions that can't be picked (e.g. Prussia's Gehorsam) and only
-- when the selected unit is of the viewed type; chosen and free pickable ones (Alhambra's Drill I) don't count
local function NaiveHave( combat )
	local have = {};
	local unit = SelectedUnit();
	if unit ~= nil and combat ~= nil and unit:GetUnitCombatType() == combat.ID then
		for promo in GameInfo.UnitPromotions() do
			if promo.CannotBeChosen and unit:IsHasPromotion( promo.ID ) then
				have[promo.Type] = true;
			end
		end
	end
	return have;
end
-- the combat type's promotions a fresh unit can ever reach (civ-only lines such as Prussia's need a free promotion
-- other units never have)
function LekmodPTReachable( combat, have )
	local all = CombatPromotions( combat.Type );
	local reach = {};
	local lookup = setmetatable( {}, { __index = function( t, k ) return have[k] or reach[k]; end } );
	local bChanged = true;
	while bChanged do
		bChanged = false;
		for _, promo in ipairs( all ) do
			if not reach[promo.Type] and LekmodPTPrereqsMet( promo, lookup ) then
				reach[promo.Type] = true;
				bChanged = true;
			end
		end
	end
	local list = {};
	for _, promo in ipairs( all ) do
		if reach[promo.Type] then
			table.insert( list, promo );
		end
	end
	return list;
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

----------------------------------------------------------------
-- unit type dropdown
----------------------------------------------------------------
local function BuildTypePullDown()
	local pd = Controls.TypePullDown;
	pd:ClearEntries();
	local entries = {};
	for combat in GameInfo.UnitCombatInfos() do
		if #LekmodPTReachable( combat, {} ) > 0 then
			table.insert( entries, { ID = combat.ID, Name = Locale.ConvertTextKey( combat.Description ) } );
		end
	end
	table.sort( entries, function( a, b ) return Locale.Compare( a.Name, b.Name ) == -1; end );
	for _, e in ipairs( entries ) do
		local inst = {};
		pd:BuildEntry( "InstanceOne", inst );
		inst.Button:SetVoids( e.ID, 0 );
		inst.Button:SetText( e.Name );
	end
	pd:CalculateInternals();
end
Controls.TypePullDown:RegisterSelectionCallback( function( v1, v2 )
	local combat = GameInfo.UnitCombatInfos[v1];
	if combat ~= nil then
		g_ViewCombat = combat;
		LekmodPTRefresh();
	end
end );

----------------------------------------------------------------
-- the panel
----------------------------------------------------------------
-- right above the unit panel's action box (promotions, builds), as far from it as that box is from the action buttons
-- on its left; the box changes its height with its content, so this reads its real place every time
local PANEL_GAP = 14;
function LekmodPTPosition()
	local box = nil;
	pcall( function() box = ContextPtr:LookUpControl( "/InGame/WorldView/UnitPanel/WorkerActionPanel" ); end );
	local x, y = 72, 123;
	if box ~= nil then
		x = box:GetOffsetX();
		y = box:GetOffsetY();
		if not box:IsHidden() then
			y = y + box:GetSizeY() + PANEL_GAP;
		end
	end
	Controls.Panel:SetOffsetVal( x, y );
end

function LekmodPTRefresh()
	if not Controls.Builder:IsHidden() then
		return;   -- the builder keeps its unit type until it closes
	end
	local unit = SelectedUnit();
	local unitCombat = UnitCombat( unit );
	-- a newly selected unit sets the view to its type; the dropdown can change it afterwards
	local unitID = (unit ~= nil) and unit:GetID() or nil;
	if unitID ~= g_LastUnit then
		g_LastUnit = unitID;
		if unitCombat ~= nil then
			g_ViewCombat = unitCombat;
		end
	end
	if g_ViewCombat == nil then
		g_ViewCombat = unitCombat or GameInfo.UnitCombatInfos["UNITCOMBAT_MELEE"];
	end

	local bReady = (unitCombat ~= nil) and unit:IsPromotionReady();
	if g_DismissUnit ~= unitID or g_DismissReady ~= bReady then
		g_DismissUnit = nil;
	end
	local bAutoOpen = bReady and LekmodPTAutoSlot( unitCombat.Type ) == 0 and g_DismissUnit == nil;
	local bShown = (LekmodPTAlwaysShown() or bAutoOpen) and not UI.IsCityScreenUp() and g_ViewCombat ~= nil;
	Controls.Panel:SetHide( not bShown );
	if not bShown then
		return;
	end

	local combat = g_ViewCombat;
	local combatName = Locale.ConvertTextKey( combat.Description );
	Controls.TypePullDown:GetButton():SetText( combatName );
	-- the template buttons work on the selected unit when it is of the shown type and can pick a promotion
	local bCanApply = bReady and unitCombat.ID == combat.ID;
	local autoSlot = LekmodPTAutoSlot( combat.Type );
	for slot = 1, NUM_SLOTS do
		Controls["Auto" .. slot]:SetCheck( autoSlot == slot );
		local list = LekmodPTLoad( combat.Type, slot );
		local im = g_IconIM[slot];
		im:ResetInstances();
		local apply = Controls["Apply" .. slot];
		local bEmpty = (#list == 0);
		Controls["New" .. slot]:SetHide( not bEmpty );
		Controls["Key" .. slot]:SetHide( bEmpty );
		Controls["AutoBox" .. slot]:SetHide( bEmpty );
		Controls["Delete" .. slot]:SetHide( bEmpty );
		if bEmpty then
			apply:SetDisabled( false );
			apply:SetAlpha( 1 );
			apply:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_LEKMOD_PT_NEW_TT", combatName ) );
		else
			for _, promo in ipairs( list ) do
				local inst = im:GetInstance();
				IconHookup( promo.PortraitIndex, 32, promo.IconAtlas, inst.Icon );
			end
			Controls["Icons" .. slot]:CalculateSize();
			Controls["Icons" .. slot]:ReprocessAnchoring();
			local tt = Locale.ConvertTextKey( "TXT_KEY_LEKMOD_PT_APPLY_TT", slot, PromoNames( list ) );
			if not bCanApply then
				tt = tt .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey( "TXT_KEY_LEKMOD_PT_NOT_READY", combatName );
			end
			apply:SetToolTipString( tt );
			apply:SetDisabled( not bCanApply );
			apply:SetAlpha( bCanApply and 1 or 0.55 );
			Controls["AutoClick" .. slot]:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_LEKMOD_PT_AUTO_TT", combatName ) );
		end
	end
	Controls.PanelStack:CalculateSize();
	Controls.PanelStack:ReprocessAnchoring();
	LekmodPTPosition();
	-- the unit panel resizes its action box on the same events: place the panel again on the next frame
	ContextPtr:SetUpdate( function()
		ContextPtr:ClearUpdate();
		LekmodPTPosition();
	end );
end

-- Shift+1 / Shift+2: the selected unit's own type, also while the panel is closed or shows another type
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
	if g_ViewCombat == nil then return; end
	if #LekmodPTLoad( g_ViewCombat.Type, slot ) == 0 then
		LekmodPTOpenBuilder( slot );
	else
		ApplyTemplate( slot );
	end
end
local function OnAuto( slot )
	if g_ViewCombat == nil then return; end
	local cur = LekmodPTAutoSlot( g_ViewCombat.Type );
	g_AutoSlot[g_ViewCombat.Type] = (cur == slot) and 0 or slot;
	LekmodPTSync();
	LekmodPTRefresh();
end
local function OnDelete( slot )
	if g_ViewCombat == nil then return; end
	SaveTemplate( g_ViewCombat.Type, slot, {} );
	LekmodPTSync();
	LekmodPTRefresh();
end
for slot = 1, NUM_SLOTS do
	local s = slot;
	Controls["Apply" .. s]:RegisterCallback( Mouse.eLClick, function() OnApply( s ); end );
	Controls["AutoClick" .. s]:RegisterCallback( Mouse.eLClick, function() OnAuto( s ); end );
	Controls["Delete" .. s]:RegisterCallback( Mouse.eLClick, function() OnDelete( s ); end );
end

-- the X: switches "Always show" off and closes the automatic panel for this unit
local function ClosePanel()
	if LekmodPTAlwaysShown() then
		SetAlwaysShown( false );
	end
	local unit = SelectedUnit();
	g_DismissUnit = (unit ~= nil) and unit:GetID() or nil;
	g_DismissReady = (unit ~= nil) and UnitCombat( unit ) ~= nil and unit:IsPromotionReady();
	LekmodPTRefresh();
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, ClosePanel );

-- Alt+T and Map Options: "Always show" on/off
local function ToggleAlwaysShown()
	local bOn = not LekmodPTAlwaysShown();
	SetAlwaysShown( bOn );
	if not bOn then
		local unit = SelectedUnit();
		g_DismissUnit = (unit ~= nil) and unit:GetID() or nil;
		g_DismissReady = (unit ~= nil) and UnitCombat( unit ) ~= nil and unit:IsPromotionReady();
	end
	LekmodPTRefresh();
end
LuaEvents.LekmodPromoTemplatesShownChanged.Add( function() LekmodPTRefresh(); end );
LuaEvents.LekmodPromoTemplatesToggle.Add( ToggleAlwaysShown );   -- Alt+T (InGame.lua InputHandler)

----------------------------------------------------------------
-- the builder (always from a fresh unit's point of view)
----------------------------------------------------------------
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
	local base = NaiveHave( g_ViewCombat );
	local have = {};
	for k, v in pairs( base ) do have[k] = v; end
	local inSeq = {};
	for _, promo in ipairs( g_BuilderSeq ) do
		have[promo.Type] = true;
		inSeq[promo.ID] = true;
	end
	local bFull = (#g_BuilderSeq >= MAX_PROMOS);

	g_PickIM:ResetInstances();
	local list = LekmodPTReachable( g_ViewCombat, base );
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
	if g_ViewCombat == nil then return; end
	g_BuilderSlot = slot;
	g_BuilderSeq = {};
	Controls.BuilderTitle:LocalizeAndSetText( "TXT_KEY_LEKMOD_PT_BUILDER_TITLE", Locale.ConvertTextKey( g_ViewCombat.Description ) );
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
	if g_ViewCombat ~= nil and g_BuilderSlot ~= nil and #g_BuilderSeq > 0 then
		SaveTemplate( g_ViewCombat.Type, g_BuilderSlot, g_BuilderSeq );
		LekmodPTSync();
	end
	CloseBuilder();
end );
Controls.CancelButton:RegisterCallback( Mouse.eLClick, CloseBuilder );

----------------------------------------------------------------
-- input: Shift+1 / Shift+2 apply a template; Esc closes the builder (Alt+T is in InGame.lua)
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
BuildTypePullDown();
-- "Always show" never carries over: every game starts with the panel closed (user, 2026-11-05)
SetAlwaysShown( false );
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
Events.LoadScreenClose.Add( function()
	local pPlayer = Players[Game.GetActivePlayer()];
	if pPlayer ~= nil and pPlayer.LekmodGetPromotionTemplate ~= nil then
		for combat in GameInfo.UnitCombatInfos() do
			for slot = 1, NUM_SLOTS do
				local values = { pPlayer:LekmodGetPromotionTemplate( combat.ID, slot - 1 ) };
				if values[MAX_PROMOS + 1] == 1 then
					g_AutoSlot[combat.Type] = slot;
				end
			end
		end
	end
	SetAlwaysShown( false );
	LekmodPTSync();
	LekmodPTRefresh();
end );
