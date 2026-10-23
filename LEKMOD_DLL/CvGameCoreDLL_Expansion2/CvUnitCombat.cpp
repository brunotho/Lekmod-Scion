/*	-------------------------------------------------------------------------------------------------------
	� 1991-2012 Take-Two Interactive Software and its subsidiaries.  Developed by Firaxis Games.  
	Sid Meier's Civilization V, Civ, Civilization, 2K Games, Firaxis Games, Take-Two Interactive Software 
	and their respective logos are all trademarks of Take-Two interactive Software, Inc.  
	All other marks and trademarks are the property of their respective owners.  
	All rights reserved. 
	------------------------------------------------------------------------------------------------------- */
#include "CvGameCoreDLLPCH.h"
#include "CvUnit.h"
#include "CvUnitCombat.h"
#include "CvUnitMission.h"
#include "CvGameCoreUtils.h"
#include "ICvDLLUserInterface.h"
#include "CvDiplomacyAI.h"
#include "CvTypes.h"

#include "CvDllCity.h"
#include "CvDllUnit.h"
#include "CvDllCombatInfo.h"

// include this after all other headers
#include "LintFree.h"

// Maximum damage members for the nuke, units and cities
#define MAX_NUKE_DAMAGE_MEMBERS	64

#define POST_QUICK_COMBAT_DELAY	110
#define POST_COMBAT_DELAY		1

//	---------------------------------------------------------------------------
static int GetPostCombatDelay()
{
	return CvPreGame::quickCombat() ? POST_QUICK_COMBAT_DELAY : POST_COMBAT_DELAY;
}

//	---------------------------------------------------------------------------
// Find a object in the combat member array
static CvCombatMemberEntry* FindCombatMember(CvCombatMemberEntry* pkArray, int iMembers, IDInfo kMember, CvCombatMemberEntry::MEMBER_TYPE eType)
{
	if(iMembers > 0)
	{
		while(iMembers--)
		{
			if(pkArray->IsType(eType))
			{
				if(pkArray->GetID() == kMember.iID && pkArray->GetPlayer() == kMember.eOwner)
					return pkArray;
			}
			++pkArray;
		}
	}

	return NULL;
}

//	---------------------------------------------------------------------------
// Add a member to the combat array
static CvCombatMemberEntry* AddCombatMember(CvCombatMemberEntry* pkArray, int* piMembers, int iMaxMembers, IDInfo kMember, CvCombatMemberEntry::MEMBER_TYPE eType, int iX, int iY, EraTypes eEra)
{
	if(*piMembers < iMaxMembers)
	{
		int iCount = *piMembers;
		if(!FindCombatMember(pkArray, iCount, kMember, eType))
		{
			CvCombatMemberEntry& kEntry = pkArray[iCount];
			kEntry.SetPlayer(kMember.eOwner);
			kEntry.SetID(kMember.iID, eType);
			kEntry.SetDamage(0);
			kEntry.SetFinalDamage(0);
			kEntry.SetMaxHitPoints(0);
			kEntry.SetPlot(iX, iY);
			kEntry.SetEra(eEra);
			*piMembers += 1;
			return &(pkArray[iCount]);
		}
	}
	return NULL;
}

//	---------------------------------------------------------------------------
// Add a unit member to the combat array
static CvCombatMemberEntry* AddCombatMember(CvCombatMemberEntry* pkArray, int* piMembers, int iMaxMembers, CvUnit* pkMember)
{
	if(pkMember)
		return AddCombatMember(pkArray, piMembers, iMaxMembers, pkMember->GetIDInfo(), CvCombatMemberEntry::MEMBER_UNIT, pkMember->getX(), pkMember->getY(), GET_PLAYER(pkMember->getOwner()).GetCurrentEra());

	return NULL;
}

//	---------------------------------------------------------------------------
// Add a city member to the combat array
static CvCombatMemberEntry* AddCombatMember(CvCombatMemberEntry* pkArray, int* piMembers, int iMaxMembers, CvCity* pkMember)
{
	if(pkMember)
		return AddCombatMember(pkArray, piMembers, iMaxMembers, pkMember->GetIDInfo(), CvCombatMemberEntry::MEMBER_CITY, pkMember->getX(), pkMember->getY(), GET_PLAYER(pkMember->getOwner()).GetCurrentEra());

	return NULL;
}

//	---------------------------------------------------------------------------
void CvUnitCombat::GenerateMeleeCombatInfo(CvCombatInfo* pkCombatInfo)
{
	int iMaxHP = GC.getMAX_HIT_POINTS();
	const CvPlot& plot = *pkCombatInfo->getPlot();
	CvUnit& kAttacker = *pkCombatInfo->getUnit(BATTLE_UNIT_ATTACKER);
	CvUnit* pkDefender = pkCombatInfo->getUnit(BATTLE_UNIT_DEFENDER);
	pkCombatInfo->setDefenderRetaliates(true); // Defender always retaliates in melee combat.
	pkCombatInfo->setAttackIsRanged(false); // Melee combat is never ranged.
	// Calculates and sets:
	// - damage inflicted by attacker and defender
	// - final damage for attacker and defender
	// - mutual lethal correction
	GC.getGame().getCombatDamage(*pkCombatInfo);

	if (pkDefender != NULL) // Unit vs. Unit
	{
#ifdef NQ_HEAVY_CHARGE_DOWNHILL
		bool isAttackingFromHigherElevation = kAttacker.GetHeavyChargeDownhill() > 0 && (kAttacker.plot()->isMountain() && !pkDefender->plot()->isMountain()) || (kAttacker.plot()->isHills() && pkDefender->plot()->isFlatlands());
#endif
		bool bAdvance = true;

		if(plot.getNumDefenders(pkDefender->getOwner()) > 1)
		{
			bAdvance = false;
		}
		else if(pkCombatInfo->getFinalDamage(BATTLE_UNIT_DEFENDER) >= iMaxHP && kAttacker.IsCaptureDefeatedEnemy() && kAttacker.AreUnitsOfSameType(*pkDefender))
		{
			int iCaptureRoll = GC.getGame().getJonRandNum(100, "Capture Enemy Roll");
			if (iCaptureRoll < kAttacker.GetCaptureChance(pkDefender))
			{
				bAdvance = false;
				pkCombatInfo->setDefenderCaptured(true);
			}
		}
#ifdef NQ_HEAVY_CHARGE_DOWNHILL
		else if ((kAttacker.IsCanHeavyCharge() || isAttackingFromHigherElevation) && !pkDefender->isDelayedDeath() && (pkCombatInfo->getDamageInflicted(BATTLE_UNIT_ATTACKER) > pkCombatInfo->getDamageInflicted(BATTLE_UNIT_DEFENDER)))
#endif
		{
			bAdvance = true;
		}

		pkCombatInfo->setAttackerAdvances(bAdvance);
	}

	GC.GetEngineUserInterface()->setDirty(UnitInfo_DIRTY_BIT, true);
}

//	---------------------------------------------------------------------------
void CvUnitCombat::ResolveMeleeCombat(const CvCombatInfo& kCombatInfo, uint uiParentEventID)
{
	// After combat stuff
	CvString strBuffer;
	bool bAttackerDead = false;
	bool bDefenderDead = false;
	int iAttackerDamageDelta = 0;

	CvUnit* pkAttacker = kCombatInfo.getUnit(BATTLE_UNIT_ATTACKER);
	CvUnit* pkDefender = kCombatInfo.getUnit(BATTLE_UNIT_DEFENDER);
	CvPlot* pkTargetPlot = kCombatInfo.getPlot();
	if(!pkTargetPlot && pkDefender)
		pkTargetPlot = pkDefender->plot();

	CvAssert_Debug(pkAttacker && pkDefender && pkTargetPlot);

	int iActivePlayerID = GC.getGame().getActivePlayer();

	// Iaijutsu: remember whether the defender was at full HP before this attack
	const bool bDefenderWasFullHP = (pkDefender != NULL && pkDefender->getDamage() == 0);

	bool bAttackerDidMoreDamage = false;

	if(pkAttacker != NULL && pkDefender != NULL && pkTargetPlot != NULL &&
	        pkDefender->IsCanDefend()) 		// Did the defender actually defend?
	{
		// Internal variables
		int iAttackerDamageInflicted = kCombatInfo.getDamageInflicted(BATTLE_UNIT_ATTACKER);
		int iDefenderDamageInflicted = kCombatInfo.getDamageInflicted(BATTLE_UNIT_DEFENDER);
		int iAttackerFearDamageInflicted = 0;//pInfo->getFearDamageInflicted( BATTLE_UNIT_ATTACKER );

		bAttackerDidMoreDamage = iAttackerDamageInflicted > iDefenderDamageInflicted;

		//One Hit
		if(pkDefender->GetCurrHitPoints() == GC.getMAX_HIT_POINTS() && iAttackerDamageInflicted >= pkDefender->GetCurrHitPoints()  // Defender at full hit points and will the damage be more than the full hit points?
		        && pkAttacker->isHuman() && !GC.getGame().isGameMultiPlayer())
		{
			gDLL->UnlockAchievement(ACHIEVEMENT_ONEHITKILL);
		}

		pkDefender->changeDamage(iAttackerDamageInflicted, pkAttacker->getOwner());
		iAttackerDamageDelta = pkAttacker->changeDamage(iDefenderDamageInflicted, pkDefender->getOwner(), -1.f);		// Signal that we don't want the popup text.  It will be added later when the unit is at its final location

		// Update experience for both sides.
		pkDefender->changeExperience(
		    kCombatInfo.getExperience(BATTLE_UNIT_DEFENDER),
		    kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_DEFENDER),
		    true,
		    kCombatInfo.getInBorders(BATTLE_UNIT_DEFENDER),
		    kCombatInfo.getUpdateGlobal(BATTLE_UNIT_DEFENDER));

		pkAttacker->changeExperience(
		    kCombatInfo.getExperience(BATTLE_UNIT_ATTACKER),
		    kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_ATTACKER),
		    true,
		    kCombatInfo.getInBorders(BATTLE_UNIT_ATTACKER),
		    kCombatInfo.getUpdateGlobal(BATTLE_UNIT_ATTACKER));

		// Anyone eat it?
		bAttackerDead = (pkAttacker->getDamage() >= GC.getMAX_HIT_POINTS());
		bDefenderDead = (pkDefender->getDamage() >= GC.getMAX_HIT_POINTS());

		CvPlayerAI& kAttackerOwner = GET_PLAYER(pkAttacker->getOwner());
		kAttackerOwner.GetPlayerAchievements().AttackedUnitWithUnit(pkAttacker, pkDefender);

		// Attacker died
		if(bAttackerDead)
		{
			CvPlayerAI& kDefenderOwner = GET_PLAYER(pkDefender->getOwner());
			kDefenderOwner.GetPlayerAchievements().KilledUnitWithUnit(pkDefender, pkAttacker);

			auto_ptr<ICvUnit1> pAttacker = GC.WrapUnitPointer(pkAttacker);
			gDLL->GameplayUnitDestroyedInCombat(pAttacker.get());

			if(iActivePlayerID == pkAttacker->getOwner())
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_DIED_ATTACKING", pkAttacker->getNameKey(), pkDefender->getNameKey(), iAttackerDamageInflicted, iAttackerFearDamageInflicted);
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
			}
			if(iActivePlayerID == pkDefender->getOwner())
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_KILLED_ENEMY_UNIT", pkDefender->getNameKey(), iAttackerDamageInflicted, iAttackerFearDamageInflicted, pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()));
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
			}
#ifdef PROMOTION_INSTA_HEAL_LOCKED
			if (GET_PLAYER(pkDefender->getOwner()).isTurnActive())
			{
				pkDefender->testPromotionReady();
			}
#else
#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
			pkDefender->testPromotionReady();
#endif
#endif
			ApplyPostCombatTraitEffects(pkDefender, pkAttacker);
		}
		// Defender died
		else if(bDefenderDead)
		{
			kAttackerOwner.GetPlayerAchievements().KilledUnitWithUnit(pkAttacker, pkDefender);

			auto_ptr<ICvUnit1> pDefender = GC.WrapUnitPointer(pkDefender);
			gDLL->GameplayUnitDestroyedInCombat(pDefender.get()); 

			if(iActivePlayerID == pkAttacker->getOwner())
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_DESTROYED_ENEMY", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey());
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
			}

			if(pkAttacker->getVisualOwner(pkDefender->getTeam()) != pkAttacker->getOwner())
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WAS_DESTROYED_UNKNOWN", pkDefender->getNameKey(), pkAttacker->getNameKey(), iDefenderDamageInflicted);
			}
			else
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WAS_DESTROYED", pkDefender->getNameKey(), pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()), iDefenderDamageInflicted);
			}
			if(iActivePlayerID == pkDefender->getOwner())
			{
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*,GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
			}
			CvNotifications* pNotification = GET_PLAYER(pkDefender->getOwner()).GetNotifications();
			if(pNotification)
			{
				Localization::String strSummary = Localization::Lookup("TXT_KEY_UNIT_LOST");
				pNotification->Add(NOTIFICATION_UNIT_DIED, strBuffer, strSummary.toUTF8(), pkDefender->getX(), pkDefender->getY(), (int) pkDefender->getUnitType(), pkDefender->getOwner());
			}

#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
			pkAttacker->testPromotionReady();
#endif

			ApplyPostCombatTraitEffects(pkAttacker, pkDefender);

			// If defender captured, mark who captured him
			if (kCombatInfo.getDefenderCaptured())
			{
				pkDefender->setCapturingPlayer(pkAttacker->getOwner());
				pkDefender->SetCapturedAsIs(true);
			}
		}
		// Nobody died
		else
		{
			if(iActivePlayerID == pkAttacker->getOwner())
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WITHDRAW", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey(), iAttackerDamageInflicted);
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_OUR_WITHDRAWL", MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
			}
			if(iActivePlayerID == pkDefender->getOwner())
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_ENEMY_UNIT_WITHDRAW", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey(), iAttackerDamageInflicted);
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_THEIR_WITHDRAWL", MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
			}

#ifdef PROMOTION_INSTA_HEAL_LOCKED
			if (GET_PLAYER(pkDefender->getOwner()).isTurnActive())
			{
				pkDefender->testPromotionReady();
			}
#else
#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
			pkDefender->testPromotionReady();
#endif
#endif
#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
			pkAttacker->testPromotionReady();
#endif

		}

		// Minors want Barbs near them dead
		if(bAttackerDead)
		{
			if(pkAttacker->isBarbarian())
				pkAttacker->DoTestBarbarianThreatToMinorsWithThisUnitsDeath(pkDefender->getOwner());
		}
		else if(bDefenderDead)
		{
			if(pkDefender->isBarbarian())
				pkDefender->DoTestBarbarianThreatToMinorsWithThisUnitsDeath(pkAttacker->getOwner());
		}
	}

	if(pkAttacker)
	{
		pkAttacker->setCombatUnit(NULL);
		pkAttacker->ClearMissionQueue(GetPostCombatDelay());
	}
	if(pkDefender)
	{
		pkDefender->setCombatUnit(NULL);
		pkDefender->ClearMissionQueue();
	}
	else
		bDefenderDead = true;

	if(pkAttacker)
	{
		if(pkAttacker->isSuicide())
		{
			pkAttacker->setCombatUnit(NULL);	// Must clear this if doing a delayed kill, should this be part of the kill method?
#ifdef ENHANCED_GRAPHS
			if (pkAttacker->getUnitCombatType() != NO_UNITCOMBAT)
			{
				if (pkDefender->getOwner() != NO_PLAYER)
				{
					GET_PLAYER(pkDefender->getOwner()).ChangeNumKilledUnits(1);
				}
				GET_PLAYER(pkAttacker->getOwner()).ChangeNumLostUnits(1);
			}
#endif
			pkAttacker->kill(true);
		}
		else
		{
#ifdef AUI_WARNING_FIXES
			if (pkTargetPlot && pkDefender)
#else
			if(pkTargetPlot)
#endif
			{
#ifdef NQ_HEAVY_CHARGE_DOWNHILL
				bool isAttackingFromHigherElevation = false;
				if (pkAttacker->GetHeavyChargeDownhill() > 0)
				{
					isAttackingFromHigherElevation = 
						(pkAttacker->plot()->isMountain() && !pkDefender->plot()->isMountain()) ||
						(pkAttacker->plot()->isHills() && pkDefender->plot()->isFlatlands());
				}
				if ((pkAttacker->IsCanHeavyCharge() || (pkAttacker->GetHeavyChargeDownhill() > 0 && isAttackingFromHigherElevation))
					&& !pkDefender->isDelayedDeath() && bAttackerDidMoreDamage)
#else
				if (pkAttacker->IsCanHeavyCharge() && !pkDefender->isDelayedDeath() && bAttackerDidMoreDamage)
#endif
				{
					pkDefender->DoFallBackFromMelee(*pkAttacker);
				}

				bool bCanAdvance = kCombatInfo.getAttackerAdvances() && pkTargetPlot->getNumVisibleEnemyDefenders(pkAttacker) == 0;
				if(bCanAdvance)
				{
					if(kCombatInfo.getAttackerAdvancedVisualization())
						// The combat vis has already 'moved' the unit.  Have the game side just do its movement calculations and pop the unit to the new location.
						pkAttacker->move(*pkTargetPlot, false);
					else
						pkAttacker->UnitMove(pkTargetPlot, true, pkAttacker);

					pkAttacker->PublishQueuedVisualizationMoves();
				}
				else
				{
#ifdef NQ_FIX_MOVES_THAT_CONSUME_ALL_MOVEMENT
					pkAttacker->changeMoves(-1 * std::max(GC.getMOVE_DENOMINATOR(), pkTargetPlot->movementCost(pkAttacker, pkAttacker->plot(), pkAttacker->getMoves())));
#else
					pkAttacker->changeMoves(-1 * std::max(GC.getMOVE_DENOMINATOR(), pkTargetPlot->movementCost(pkAttacker, pkAttacker->plot())));
#endif

					if(!pkAttacker->canMove() || !pkAttacker->isBlitz())
					{
						if(pkAttacker->IsSelected())
						{
							if(GC.GetEngineUserInterface()->GetLengthSelectionList() > 1)
							{
								auto_ptr<ICvUnit1> pDllAttacker = GC.WrapUnitPointer(pkAttacker);
								GC.GetEngineUserInterface()->RemoveFromSelectionList(pDllAttacker.get());
							}
						}
					}
				}
			}

			// Iaijutsu: first attack this turn against a full-HP unit grants one more attack
			if(bDefenderWasFullHP && !pkAttacker->IsDead() && pkAttacker->IsExtraAttackVsFullHP() && !pkAttacker->IsExtraAttackVsFullHPUsed())
			{
				pkAttacker->SetExtraAttackVsFullHPUsed(true);
				pkAttacker->RefundAttack();
			}

			// If a Unit loses his moves after attacking, do so
#ifdef NQ_UNIT_TURN_ENDS_ON_FINAL_ATTACK
			if(!pkAttacker->canMoveAfterAttacking() && pkAttacker->isOutOfAttacks())
#else
			if(!pkAttacker->canMoveAfterAttacking())
#endif
			{
				pkAttacker->finishMoves();
				GC.GetEngineUserInterface()->changeCycleSelectionCounter(1);
			}

			// Now that the attacker is in their final location, show any damage popup
			if (!pkAttacker->IsDead() && iAttackerDamageDelta != 0)
				CvUnit::ShowDamageDeltaText(iAttackerDamageDelta, pkAttacker->plot());
		}

		// Report that combat is over in case we want to queue another attack
		GET_PLAYER(pkAttacker->getOwner()).GetTacticalAI()->CombatResolved(pkAttacker, bDefenderDead);
	}
}

//	---------------------------------------------------------------------------
//	Function: GenerateRangedCombatInfo
//	Take the input parameters and fill in a CvCombatInfo definition assuming a
//	ranged combat.
//
//	Parameters:
//		pkCombatInfo 	-	Output combat info
//	---------------------------------------------------------------------------
void CvUnitCombat::GenerateRangedCombatInfo(CvCombatInfo* pkCombatInfo)
{
	CvUnit* pkAttacker = pkCombatInfo->getUnit(BATTLE_UNIT_ATTACKER);
	CvCity* pkDefenderCity = pkCombatInfo->getCity(BATTLE_UNIT_DEFENDER);

	pkCombatInfo->setAttackIsRanged(true);
	pkCombatInfo->setDefenderRetaliates(false);

	if (pkAttacker != NULL)
	{
		if (pkAttacker->isRangedSupportFire() && pkDefenderCity != NULL)
		{
			return; // can't attack cities with this
		}
	}
	GC.getGame().getCombatDamage(*pkCombatInfo);

	GC.GetEngineUserInterface()->setDirty(UnitInfo_DIRTY_BIT, true);
}

//	---------------------------------------------------------------------------
//	Function: ResolveRangedUnitVsCombat
//	Resolve ranged combat where the attacker is a unit.  This will handle
//  unit vs. unit and unit vs. city
//	---------------------------------------------------------------------------
void CvUnitCombat::ResolveRangedUnitVsCombat(const CvCombatInfo& kCombatInfo, uint uiParentEventID)
{
	bool bTargetDied = false;
	int iDamage = kCombatInfo.getDamageInflicted(BATTLE_UNIT_ATTACKER);
//	int iExperience = kCombatInfo.getExperience(BATTLE_UNIT_ATTACKER);
//	int iMaxXP = kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_ATTACKER);
	bool bBarbarian = false;

	CvUnit* pkAttacker = kCombatInfo.getUnit(BATTLE_UNIT_ATTACKER);
	CvAssert_Debug(pkAttacker);

	CvPlot* pkTargetPlot = kCombatInfo.getPlot();
	CvAssert_Debug(pkTargetPlot);


	ICvUserInterface2* pkDLLInterface = GC.GetEngineUserInterface();
	CvString strBuffer;

	if(pkTargetPlot)
	{
		if(!pkTargetPlot->isCity())
		{
			// Unit
			CvUnit* pkDefender = kCombatInfo.getUnit(BATTLE_UNIT_DEFENDER);
			CvAssert_Debug(pkDefender != NULL);
			if(pkDefender)
			{
				bBarbarian = pkDefender->isBarbarian();

				if(pkAttacker)
				{
					// Defender died
					if(iDamage + pkDefender->getDamage() >= GC.getMAX_HIT_POINTS())
					{
						if(pkAttacker->getOwner() == GC.getGame().getActivePlayer())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_ATTACK_BY_AIR_AND_DEATH", pkAttacker->getNameKey(), pkDefender->getNameKey());
							pkDLLInterface->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pkDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
						}

						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_AIR_AND_DEATH", pkDefender->getNameKey(), pkAttacker->getNameKey());
						CvNotifications* pNotifications = GET_PLAYER(pkDefender->getOwner()).GetNotifications();
						if(pNotifications)
						{
							Localization::String strSummary = Localization::Lookup("TXT_KEY_UNIT_LOST");
							pNotifications->Add(NOTIFICATION_UNIT_DIED, strBuffer, strSummary.toUTF8(), pkDefender->getX(), pkDefender->getY(), (int) pkDefender->getUnitType(), pkDefender->getOwner());
						}

						bTargetDied = true;

						CvPlayerAI& kAttackerOwner = GET_PLAYER(pkAttacker->getOwner());
						kAttackerOwner.GetPlayerAchievements().KilledUnitWithUnit(pkAttacker, pkDefender);

						ApplyPostCombatTraitEffects(pkAttacker, pkDefender);

						if(bBarbarian)
						{
							pkDefender->DoTestBarbarianThreatToMinorsWithThisUnitsDeath(pkAttacker->getOwner());
						}

						//One Hit
						if(pkDefender->GetCurrHitPoints() == GC.getMAX_HIT_POINTS() && pkAttacker->isHuman() && !GC.getGame().isGameMultiPlayer())
						{
							gDLL->UnlockAchievement(ACHIEVEMENT_ONEHITKILL);
						}
					}
					// Nobody died
					else
					{
						if(pkAttacker->getOwner() == GC.getGame().getActivePlayer())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_ATTACK_BY_AIR", pkAttacker->getNameKey(), pkDefender->getNameKey(), iDamage);
							pkDLLInterface->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pkDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
						}
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_AIR", pkDefender->getNameKey(), pkAttacker->getNameKey(), iDamage);
					}

					//red icon over attacking unit
					if(pkDefender->getOwner() == GC.getGame().getActivePlayer())
					{
						pkDLLInterface->AddMessage(uiParentEventID, pkDefender->getOwner(), false, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pkAttacker->m_pUnitInfo->GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkAttacker->getX(), pkAttacker->getY(), true, true*/);
					}
					//white icon over defending unit
					//pkDLLInterface->AddMessage(uiParentEventID, pkDefender->getOwner(), false, 0, ""/*, "AS2D_COMBAT", MESSAGE_TYPE_DISPLAY_ONLY, pkDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_WHITE"), pkDefender->getX(), pkDefender->getY(), true, true*/);

					//set damage but don't update entity damage visibility
					pkDefender->changeDamage(iDamage, pkAttacker->getOwner());

					// Update experience
					pkDefender->changeExperience(
					    kCombatInfo.getExperience(BATTLE_UNIT_DEFENDER),
					    kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_DEFENDER),
					    true,
					    kCombatInfo.getInBorders(BATTLE_UNIT_DEFENDER),
					    kCombatInfo.getUpdateGlobal(BATTLE_UNIT_DEFENDER));
				}

				pkDefender->setCombatUnit(NULL);
				if(!CvUnitMission::IsHeadMission(pkDefender, CvTypes::getMISSION_WAIT_FOR()))		// If the top mission was not a 'wait for', then clear it.
					pkDefender->ClearMissionQueue();
			}
			else
				bTargetDied = true;
		}
		else
		{
			// City
			CvCity* pCity = pkTargetPlot->getPlotCity();
			CvAssert_Debug(pCity != NULL);
			if(pCity)
			{
				if(pkAttacker)
				{
					bBarbarian = pCity->isBarbarian();
					pCity->changeDamage(iDamage);

					// CitySplashDamage: deal flat damage to all non-air units in the city
					if (pkAttacker->GetCitySplashDamage() > 0)
					{
						int iSplash = pkAttacker->GetCitySplashDamage();
						for (int iUnitLoop = pkTargetPlot->getNumUnits() - 1; iUnitLoop >= 0; iUnitLoop--)
						{
							CvUnit* pSplashUnit = pkTargetPlot->getUnitByIndex(iUnitLoop);
							if (pSplashUnit && pSplashUnit->getDomainType() != DOMAIN_AIR)
							{
								pSplashUnit->changeDamage(iSplash, pkAttacker->getOwner());
							}
						}
					}

#ifdef ENHANCED_GRAPHS
					GET_PLAYER(pCity->getOwner()).ChangeCitiesDamageTaken(iDamage);
					GET_PLAYER(pkAttacker->getOwner()).ChangeCitiesDamageDealt(iDamage);
#endif
					if(pCity->getOwner() == GC.getGame().getActivePlayer())
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOUR_CITY_ATTACKED_BY_AIR", pCity->getNameKey(), pkAttacker->getNameKey(), iDamage);
						//red icon over attacking unit
						pkDLLInterface->AddMessage(uiParentEventID, pCity->getOwner(), false, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pkAttacker->m_pUnitInfo->GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkAttacker->getX(), pkAttacker->getY(), true, true*/);
					}
				}

				pCity->clearCombat();
			}
			else
				bTargetDied = true;
		}
	}
	else
		bTargetDied = true;

	if(pkAttacker)
	{
		// Unit gains XP for executing a Range Strike
		if(iDamage > 0) // && iDefenderStrength > 0)
		{
			pkAttacker->changeExperience(
			    kCombatInfo.getExperience(BATTLE_UNIT_ATTACKER),
			    kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_ATTACKER),
			    true,
			    kCombatInfo.getInBorders(BATTLE_UNIT_ATTACKER),
			    kCombatInfo.getUpdateGlobal(BATTLE_UNIT_ATTACKER));
		}

#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
		pkAttacker->testPromotionReady();
#endif

		pkAttacker->setCombatUnit(NULL);
		pkAttacker->ClearMissionQueue(GetPostCombatDelay());

		// Report that combat is over in case we want to queue another attack
		GET_PLAYER(pkAttacker->getOwner()).GetTacticalAI()->CombatResolved(pkAttacker, bTargetDied);
	}
}

//	---------------------------------------------------------------------------
//	Function: ResolveRangedCityVsUnitCombat
//	Resolve ranged combat where the attacker is a city
//	---------------------------------------------------------------------------
void CvUnitCombat::ResolveRangedCityVsUnitCombat(const CvCombatInfo& kCombatInfo, uint uiParentEventID)
{
	bool bTargetDied = false;
	int iDamage = kCombatInfo.getDamageInflicted(BATTLE_UNIT_ATTACKER);
	bool bBarbarian = false;

	CvCity* pkAttacker = kCombatInfo.getCity(BATTLE_UNIT_ATTACKER);
	CvAssert_Debug(pkAttacker);

	if(pkAttacker)
		pkAttacker->clearCombat();

	CvPlot* pkTargetPlot = kCombatInfo.getPlot();
	CvAssert_Debug(pkTargetPlot);

	ICvUserInterface2* pkDLLInterface = GC.GetEngineUserInterface();
	int iActivePlayerID = GC.getGame().getActivePlayer();


	if(pkTargetPlot)
	{
		if(!pkTargetPlot->isCity())
		{
			CvUnit* pkDefender = kCombatInfo.getUnit(BATTLE_UNIT_DEFENDER);
			CvAssert_Debug(pkDefender != NULL);
			if(pkDefender)
			{
				bBarbarian = pkDefender->isBarbarian();

				if(pkAttacker)
				{
					// Info message for the attacking player
					if(iActivePlayerID == pkAttacker->getOwner())
					{
						Localization::String localizedText = Localization::Lookup("TXT_KEY_MISC_YOUR_CITY_RANGE_ATTACK");
						localizedText << pkAttacker->getNameKey() << pkDefender->getNameKey() << iDamage;
						pkDLLInterface->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), localizedText.toUTF8());//, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pPlot->getX(), pPlot->getY());
					}

					// Red icon over defending unit
					if(iActivePlayerID == pkDefender->getOwner())
					{
						Localization::String localizedText = Localization::Lookup("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_CITY");
						localizedText << pkDefender->getNameKey() << pkAttacker->getNameKey() << iDamage;
						pkDLLInterface->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), localizedText.toUTF8());//, "AS2D_COMBAT", MESSAGE_TYPE_COMBAT_MESSAGE, pDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pDefender->getX(), pDefender->getY(), true, true);
					}

					if(iDamage + pkDefender->getDamage() >= GC.getMAX_HIT_POINTS())
					{
						CvNotifications* pNotifications = GET_PLAYER(pkDefender->getOwner()).GetNotifications();
						if(pNotifications)
						{
							Localization::String localizedText = Localization::Lookup("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_CITY");
							localizedText << pkDefender->getNameKey() << pkAttacker->getNameKey() << iDamage;
							Localization::String strSummary = Localization::Lookup("TXT_KEY_UNIT_LOST");
							pNotifications->Add(NOTIFICATION_UNIT_DIED, localizedText.toUTF8(), strSummary.toUTF8(), pkDefender->getX(), pkDefender->getY(), (int) pkDefender->getUnitType(), pkDefender->getOwner());
						}
						bTargetDied = true;

						// Earn bonuses for kills?
						CvPlayer& kAttackingPlayer = GET_PLAYER(pkAttacker->getOwner());
#if !defined(FULL_YIELD_FROM_KILLS)
						kAttackingPlayer.DoYieldsFromKill(NO_UNIT, pkDefender->getUnitType(), pkDefender->getX(), pkDefender->getY(), pkDefender->isBarbarian(), 0);
#else // Pass a null pointer, function handles it safely and is pretty much the same as above. Might make a city compatible one? idk.
						kAttackingPlayer.DoYieldsFromKill(NULL, pkDefender, pkDefender->getX(), pkDefender->getY(), pkDefender->isBarbarian(), 0);
#endif
					}

					//set damage but don't update entity damage visibility
					pkDefender->changeDamage(iDamage, pkAttacker->getOwner());

					// Update experience
					pkDefender->changeExperience(
					    kCombatInfo.getExperience(BATTLE_UNIT_DEFENDER),
					    kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_DEFENDER),
					    true,
					    kCombatInfo.getInBorders(BATTLE_UNIT_DEFENDER),
					    kCombatInfo.getUpdateGlobal(BATTLE_UNIT_DEFENDER));
				}

				pkDefender->setCombatUnit(NULL);
				if(!CvUnitMission::IsHeadMission(pkDefender, CvTypes::getMISSION_WAIT_FOR()))		// If the top mission was not a 'wait for', then clear it.
					pkDefender->ClearMissionQueue();
			}
			else
				bTargetDied = true;
		}
		else
		{
			CvAssert(false);	// Left as an exercise for the reader
			bTargetDied = true;
		}
	}

	// Report that combat is over in case we want to queue another attack
	if(pkAttacker)
		GET_PLAYER(pkAttacker->getOwner()).GetTacticalAI()->CombatResolved((void*)pkAttacker, bTargetDied, true);
}

//	---------------------------------------------------------------------------
//	Function: ResolveRangedCityVsCityCombat
//	Resolves a ranged (bombardment) attack where both the attacker and the defender are cities. A city
//	can never be destroyed by a ranged strike alone (getCombatDamage caps it at MaxHitPoints - 1), so
//	there's no death/capture case to handle here, unlike the unit-defender version above.
//	---------------------------------------------------------------------------
void CvUnitCombat::ResolveRangedCityVsCityCombat(const CvCombatInfo& kCombatInfo, uint uiParentEventID)
{
	int iAttackerDamageDealt = kCombatInfo.getDamageInflicted(BATTLE_UNIT_ATTACKER);
	int iDefenderDamageDealt = kCombatInfo.getDamageInflicted(BATTLE_UNIT_DEFENDER);

	CvCity* pkAttacker = kCombatInfo.getCity(BATTLE_UNIT_ATTACKER);
	CvCity* pkDefender = kCombatInfo.getCity(BATTLE_UNIT_DEFENDER);

	CvAssert_Debug(pkAttacker && pkDefender);

	if(pkAttacker)
		pkAttacker->clearCombat();

	if(pkAttacker && pkDefender)
	{
		pkDefender->changeDamage(iAttackerDamageDealt);
		if(iDefenderDamageDealt > 0)
			pkAttacker->changeDamage(iDefenderDamageDealt);

#ifdef ENHANCED_GRAPHS
		GET_PLAYER(pkDefender->getOwner()).ChangeCitiesDamageTaken(iAttackerDamageDealt);
		GET_PLAYER(pkAttacker->getOwner()).ChangeCitiesDamageDealt(iAttackerDamageDealt);
#endif
	}

	// Report that combat is over in case we want to queue another attack
	if(pkAttacker)
		GET_PLAYER(pkAttacker->getOwner()).GetTacticalAI()->CombatResolved((void*)pkAttacker, false, true);
}

//	---------------------------------------------------------------------------
//	Function: ResolveCityMeleeCombat
//
//	Resolves combat between a melee unit and a city.
//  The unit does not have to be a hand-to-hand combat type unit, just a unit doing
//  a non-ranged attack to an adjacent city.  The visualization of the attack will
//	usually appear as if it is ranged, simply because we don't want the unit members
//	running through a city and they wouldn't have anything to attack.
//	This is also the case where a city is able to attack back.
void CvUnitCombat::ResolveCityMeleeCombat(const CvCombatInfo& kCombatInfo, uint uiParentEventID)
{
	CvUnit* pkAttacker = kCombatInfo.getUnit(BATTLE_UNIT_ATTACKER);
	CvCity* pkDefender = kCombatInfo.getCity(BATTLE_UNIT_DEFENDER);

	CvAssert_Debug(pkAttacker && pkDefender);

	CvPlot* pkPlot = kCombatInfo.getPlot();
	if(!pkPlot && pkDefender)
		pkPlot = pkDefender->plot();

	CvAssert_Debug(pkPlot);

	int iAttackerDamageInflicted = kCombatInfo.getDamageInflicted(BATTLE_UNIT_ATTACKER);
	int iDefenderDamageInflicted = kCombatInfo.getDamageInflicted(BATTLE_UNIT_DEFENDER);

	if(pkAttacker && pkDefender)
	{
		pkAttacker->changeDamage(iDefenderDamageInflicted, pkDefender->getOwner());
		pkDefender->changeDamage(iAttackerDamageInflicted);

#ifdef ENHANCED_GRAPHS
		GET_PLAYER(pkDefender->getOwner()).ChangeCitiesDamageTaken(iAttackerDamageInflicted);
		GET_PLAYER(pkAttacker->getOwner()).ChangeCitiesDamageDealt(iAttackerDamageInflicted);
#endif

		pkAttacker->changeExperience(kCombatInfo.getExperience(BATTLE_UNIT_ATTACKER),
		                             kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_ATTACKER),
		                             true,
		                             kCombatInfo.getInBorders(BATTLE_UNIT_ATTACKER),
		                             kCombatInfo.getUpdateGlobal(BATTLE_UNIT_ATTACKER));
	}

	bool bCityConquered = false;

	if(pkDefender)
		pkDefender->clearCombat();
	else
		bCityConquered = true;

	if(pkAttacker)
	{
		pkAttacker->setCombatUnit(NULL);
		pkAttacker->ClearMissionQueue(GetPostCombatDelay());

		if(pkAttacker->isSuicide())
		{
			pkAttacker->setCombatUnit(NULL);	// Must clear this if doing a delayed kill, should this be part of the kill method?
#ifdef ENHANCED_GRAPHS
			if (pkAttacker->getUnitCombatType() != NO_UNITCOMBAT)
			{
				if (pkDefender->getOwner() != NO_PLAYER)
				{
					GET_PLAYER(pkDefender->getOwner()).ChangeNumKilledUnits(1);
				}
				GET_PLAYER(pkAttacker->getOwner()).ChangeNumLostUnits(1);
			}
#endif
			pkAttacker->kill(true);
		}
	}

	CvString strBuffer;
	int iActivePlayerID = GC.getGame().getActivePlayer();

	// Barbarians don't capture Cities
	if(pkAttacker && pkDefender)
	{
		if(pkAttacker->isBarbarian() && (pkDefender->getDamage() >= pkDefender->GetMaxHitPoints()))
		{
			// 1 HP left
			pkDefender->setDamage(pkDefender->GetMaxHitPoints() - 1);

			int iNumGoldStolen = GC.getBARBARIAN_CITY_GOLD_RANSOM();	// 200

			if(iNumGoldStolen > GET_PLAYER(pkDefender->getOwner()).GetTreasury()->GetGold())
			{
				iNumGoldStolen = GET_PLAYER(pkDefender->getOwner()).GetTreasury()->GetGold();
			}

			// City is ransomed for Gold
			GET_PLAYER(pkDefender->getOwner()).GetTreasury()->ChangeGold(-iNumGoldStolen);

			if(pkDefender->getOwner() == iActivePlayerID)
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_CITY_RANSOMED_BY_BARBARIANS", pkDefender->getNameKey(), iNumGoldStolen);
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*,GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkPlot->getX(), pkPlot->getY()*/);
			}

			if( pkDefender->GetPlayer()->GetID() == GC.getGame().getActivePlayer() && pkDefender->isHuman() && !GC.getGame().isGameMultiPlayer())
			{
				gDLL->UnlockAchievement(ACHIEVEMENT_REALLY_SUCK);
			}

			// Barb goes away after ransom
			pkAttacker->kill(true, NO_PLAYER);

#ifdef ENHANCED_GRAPHS
			if (pkAttacker->getUnitCombatType() != NO_UNITCOMBAT)
			{
				if (pkDefender->getOwner() != NO_PLAYER)
				{
					GET_PLAYER(pkDefender->getOwner()).ChangeNumKilledUnits(1);
				}
				GET_PLAYER(pkAttacker->getOwner()).ChangeNumLostUnits(1);
			}
#endif

			// Treat this as a conquest
			bCityConquered = true;
		}
		// Attacker died
		else if(pkAttacker->IsDead())
		{
			auto_ptr<ICvUnit1> pAttacker = GC.WrapUnitPointer(pkAttacker);
			gDLL->GameplayUnitDestroyedInCombat(pAttacker.get());
			if(pkAttacker->getOwner() == iActivePlayerID)
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_DIED_ATTACKING_CITY", pkAttacker->getNameKey(), pkDefender->getNameKey(), iAttackerDamageInflicted);
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkPlot->getX(), pkPlot->getY()*/);
			}
			if(pkDefender->getOwner() == iActivePlayerID)
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_KILLED_ENEMY_UNIT_CITY", pkDefender->getNameKey(), iAttackerDamageInflicted, pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()));
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkPlot->getX(), pkPlot->getY()*/);
			}
		}
		// City conquest
		else if(pkDefender->getDamage() >= pkDefender->GetMaxHitPoints())
		{
			if(!pkAttacker->isNoCapture())
			{
				if(pkAttacker->getOwner() == iActivePlayerID)
				{
					strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_CAPTURED_ENEMY_CITY", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey());
					GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkPlot->getX(), pkPlot->getY()*/);
				}
				if(pkDefender->getOwner() == iActivePlayerID)
				{
					strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_CITY_WAS_CAPTURED", pkDefender->getNameKey(), pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()), iDefenderDamageInflicted);
					GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*,GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkPlot->getX(), pkPlot->getY()*/);
				}

				pkAttacker->UnitMove(pkPlot, true, pkAttacker);

				bCityConquered = true;
			}
		}
		// Neither side lost
		else
		{
			if(pkAttacker->getOwner() == iActivePlayerID)
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WITHDRAW_CITY", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey(), iAttackerDamageInflicted);
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_OUR_WITHDRAWL", MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkPlot->getX(), pkPlot->getY()*/);
			}
			if(pkDefender->getOwner() == iActivePlayerID)
			{
				strBuffer = GetLocalizedText("TXT_KEY_MISC_ENEMY_UNIT_WITHDRAW_CITY", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey(), iAttackerDamageInflicted);
				GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_THEIR_WITHDRAWL", MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkPlot->getX(), pkPlot->getY()*/);
			}
#ifdef LEKMOD_MOVE_PENALTY_CITY_COMBAT
			int iPenalty = pkAttacker->GetCityAttackMovePenalty();
#ifdef LEKMOD_SPECS_2026_10_23
			// Coastal Raider (-1 per level) can remove the extra cost, but an attack never gives moves back
			iPenalty = std::max(0, iPenalty);
#endif
			pkAttacker->changeMoves(-GC.getMOVE_DENOMINATOR() * ( 1 + iPenalty));
#else
			pkAttacker->changeMoves(-GC.getMOVE_DENOMINATOR());
#endif

			ApplyPostCityCombatEffects(pkAttacker, pkDefender, iAttackerDamageInflicted);
		}
	}

	if(pkAttacker)
	{
		pkAttacker->PublishQueuedVisualizationMoves();

#ifdef NQ_UNIT_TURN_ENDS_ON_FINAL_ATTACK
		if(!pkAttacker->canMoveAfterAttacking() && pkAttacker->isOutOfAttacks())
#else
		if(!pkAttacker->canMoveAfterAttacking())
#endif
		{
			pkAttacker->finishMoves();
			GC.GetEngineUserInterface()->changeCycleSelectionCounter(1);
		}

		// Report that combat is over in case we want to queue another attack
		GET_PLAYER(pkAttacker->getOwner()).GetTacticalAI()->CombatResolved(pkAttacker, bCityConquered);
	}
}

//	GenerateAirCombatInfo
//	Function: GenerateRangedCombatInfo
//	Take the input parameters and fill in a CvCombatInfo definition assuming a
//	air bombing mission.
//
//	Parameters:
//		pkCombatInfo 	-	Output combat info
//	---------------------------------------------------------------------------
void CvUnitCombat::GenerateAirCombatInfo(CvCombatInfo* pkCombatInfo)
{
	CvUnit& kAttacker = *pkCombatInfo->getUnit(BATTLE_UNIT_ATTACKER);
	CvUnit* pkDefender = pkCombatInfo->getUnit(BATTLE_UNIT_DEFENDER);
	CvCity* pkDefenderCity = pkCombatInfo->getCity(BATTLE_UNIT_DEFENDER);
	CvPlot& plot = *pkCombatInfo->getPlot();

	// Any interception to be done?
	CvUnit* pInterceptor = kAttacker.GetBestInterceptor(plot, pkDefender);

	if(pInterceptor != NULL && pInterceptor != pkDefender)
	{
		// Does the attacker evade?
		if(GC.getGame().getJonRandNum(100, "Evasion Rand") >= kAttacker.evasionProbability())
		{
			// Is the interception successful?
			if(GC.getGame().getJonRandNum(100, "Intercept Rand (Air)") < pInterceptor->currInterceptionProbability())
			{
				pkCombatInfo->setUnit(BATTLE_UNIT_INTERCEPTOR, pInterceptor);
			}
		}
	}
	pkCombatInfo->setAttackIsBombingMission(true);
	pkCombatInfo->setDefenderRetaliates(true);

	GC.getGame().getCombatDamage(*pkCombatInfo);


	if (pkDefenderCity != NULL) // Target is a City
	{
		//Achievement for Washington
		CvUnitEntry* pkUnitInfo = GC.getUnitInfo(kAttacker.getUnitType());
		if(pkUnitInfo)
		{
			if(kAttacker.isHuman() && !GC.getGame().isGameMultiPlayer() && _stricmp(pkUnitInfo->GetType(), "UNIT_AMERICAN_B17") == 0)
			{
				gDLL->UnlockAchievement(ACHIEVEMENT_SPECIAL_B17);
			}
		}
	}

	GC.GetEngineUserInterface()->setDirty(UnitInfo_DIRTY_BIT, true);
}

//	ResolveAirUnitVsCombat
//	Function: ResolveRangedUnitVsCombat
//	Resolve air combat where the attacker is a unit.  This will handle
//  unit vs. unit and unit vs. city
//	---------------------------------------------------------------------------
void CvUnitCombat::ResolveAirUnitVsCombat(const CvCombatInfo& kCombatInfo, uint uiParentEventID)
{
	bool bTargetDied = false;
	int iAttackerDamageInflicted = kCombatInfo.getDamageInflicted(BATTLE_UNIT_ATTACKER);
	int iDefenderDamageInflicted = kCombatInfo.getDamageInflicted(BATTLE_UNIT_DEFENDER);

	CvUnit* pkAttacker = kCombatInfo.getUnit(BATTLE_UNIT_ATTACKER);

	// If there's no valid attacker, then get out of here
	CvAssert_Debug(pkAttacker);

	// Interception?
	int iInterceptionDamage = kCombatInfo.getDamageInflicted(BATTLE_UNIT_INTERCEPTOR);
	CvUnit* pInterceptor = kCombatInfo.getUnit(BATTLE_UNIT_INTERCEPTOR);
	if (pInterceptor != NULL)
	{
		CvAssertMsg(iInterceptionDamage > 0, "Successful interceptor should have inflicted damage.");
		iDefenderDamageInflicted += iInterceptionDamage;

		pInterceptor->setMadeInterception(true);
		pInterceptor->setCombatUnit(NULL);

		pInterceptor->changeExperience(
			kCombatInfo.getExperience(BATTLE_UNIT_INTERCEPTOR),
			kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_INTERCEPTOR),
			true,
			kCombatInfo.getInBorders(BATTLE_UNIT_INTERCEPTOR),
			kCombatInfo.getUpdateGlobal(BATTLE_UNIT_INTERCEPTOR));
	}
	else
	{
		CvAssertMsg(iInterceptionDamage == 0, "Interception damage exists without an interceptor.");
	}
	CvPlot* pkTargetPlot = kCombatInfo.getPlot();
	CvAssert_Debug(pkTargetPlot);

	ICvUserInterface2* pkDLLInterface = GC.GetEngineUserInterface();
	int iActivePlayerID = GC.getGame().getActivePlayer();
	CvString strBuffer;

	if(pkTargetPlot)
	{
		if(!pkTargetPlot->isCity())
		{
			// Target was a Unit
			CvUnit* pkDefender = kCombatInfo.getUnit(BATTLE_UNIT_DEFENDER);
			CvAssert_Debug(pkDefender != NULL);

			if(pkDefender)
			{
				if(pkAttacker)
				{
					//One Hit
					if(pkDefender->GetCurrHitPoints() == GC.getMAX_HIT_POINTS() && pkAttacker->isHuman() && !GC.getGame().isGameMultiPlayer())
					{
						gDLL->UnlockAchievement(ACHIEVEMENT_ONEHITKILL);
					}

					pkAttacker->changeDamage(iDefenderDamageInflicted, pkDefender->getOwner());
					pkDefender->changeDamage(iAttackerDamageInflicted, pkAttacker->getOwner());

					// Carpet Bombing: 20% splash to adjacent non-air units
					if (pkAttacker->IsCarpetBombing() && iAttackerDamageInflicted > 0)
					{
						int iCarpetSplash = std::max(1, iAttackerDamageInflicted * 20 / 100);
						for (int iDirLoop = 0; iDirLoop < NUM_DIRECTION_TYPES; iDirLoop++)
						{
							CvPlot* pAdjPlot = plotDirection(pkTargetPlot->getX(), pkTargetPlot->getY(), (DirectionTypes)iDirLoop);
							if (!pAdjPlot) continue;
							for (int iUnitLoop = pAdjPlot->getNumUnits() - 1; iUnitLoop >= 0; iUnitLoop--)
							{
								CvUnit* pCarpetUnit = pAdjPlot->getUnitByIndex(iUnitLoop);
								if (!pCarpetUnit || pCarpetUnit->getDomainType() == DOMAIN_AIR) continue;
								if (pCarpetUnit->getTeam() == pkAttacker->getTeam()) continue; // no friendly fire
								if (pkAttacker->getTeam() != pCarpetUnit->getTeam()
									&& !GET_TEAM(pkAttacker->getTeam()).isAtWar(pCarpetUnit->getTeam()))
								{
									if (GET_PLAYER(pCarpetUnit->getOwner()).isMinorCiv())
										GET_TEAM(pkAttacker->getTeam()).declareWar(pCarpetUnit->getTeam());
									// Major civ not at war: damage without declaration
								}
								pCarpetUnit->changeDamage(iCarpetSplash, pkAttacker->getOwner());
								{
									char szCarpetText[64] = { 0 };
									sprintf_s(szCarpetText, "[COLOR_RED]-%d[ENDCOLOR]", iCarpetSplash);
									GC.GetEngineUserInterface()->AddPopupText(pAdjPlot->getX(), pAdjPlot->getY(), szCarpetText, GC.getPOST_COMBAT_TEXT_DELAY() * 2);
								}
							}
						}
					}

					// Update experience
					pkDefender->changeExperience(
					    kCombatInfo.getExperience(BATTLE_UNIT_DEFENDER),
					    kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_DEFENDER),
					    true,
					    kCombatInfo.getInBorders(BATTLE_UNIT_DEFENDER),
					    kCombatInfo.getUpdateGlobal(BATTLE_UNIT_DEFENDER));

					// Attacker died
					if(pkAttacker->IsDead())
					{
						auto_ptr<ICvUnit1> pAttacker = GC.WrapUnitPointer(pkAttacker);
						gDLL->GameplayUnitDestroyedInCombat(pAttacker.get());

						CvPlayerAI& kDefenderOwner = GET_PLAYER(pkDefender->getOwner());
						kDefenderOwner.GetPlayerAchievements().KilledUnitWithUnit(pkDefender, pkAttacker);

						if(iActivePlayerID == pkAttacker->getOwner())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_DIED_ATTACKING", pkAttacker->getNameKey(), pkDefender->getNameKey(), iAttackerDamageInflicted);
							pkDLLInterface->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
						}
						if(iActivePlayerID == pkDefender->getOwner())
						{
							if (iInterceptionDamage > 0 && pInterceptor)
							{
								strBuffer = GetLocalizedText("TXT_KEY_MISC_ENEMY_AIR_UNIT_DESTROYED", pInterceptor->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()), pkAttacker->getNameKey(), pkDefender->getNameKey());
								pkDLLInterface->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
							}
							else
							{
								strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_KILLED_ENEMY_UNIT", pkDefender->getNameKey(), iAttackerDamageInflicted, 0, pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()));
								pkDLLInterface->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
							}
						}

						ApplyPostCombatTraitEffects(pkDefender, pkAttacker);
					}
					// Defender died
					else if(pkDefender->IsDead())
					{
						CvPlayerAI& kAttackerOwner = GET_PLAYER(pkAttacker->getOwner());
						kAttackerOwner.GetPlayerAchievements().KilledUnitWithUnit(pkAttacker, pkDefender);

						if(iActivePlayerID == pkAttacker->getOwner())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_ATTACK_BY_AIR_AND_DEATH", pkAttacker->getNameKey(), pkDefender->getNameKey());
							pkDLLInterface->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pkDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
						}
						if(iActivePlayerID == pkDefender->getOwner())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_AIR_AND_DEATH", pkDefender->getNameKey(), pkAttacker->getNameKey());
							pkDLLInterface->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pkDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
						}

						CvNotifications* pNotifications = GET_PLAYER(pkDefender->getOwner()).GetNotifications();
						if(pNotifications)
						{
							Localization::String strSummary = Localization::Lookup("TXT_KEY_UNIT_LOST");
							pNotifications->Add(NOTIFICATION_UNIT_DIED, strBuffer, strSummary.toUTF8(), pkDefender->getX(), pkDefender->getY(), (int) pkDefender->getUnitType(), pkDefender->getOwner());
						}

						bTargetDied = true;

						ApplyPostCombatTraitEffects(pkAttacker, pkDefender);
					}
					// Nobody died
					else
					{
						if(iActivePlayerID == pkAttacker->getOwner())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_ATTACK_BY_AIR", pkAttacker->getNameKey(), pkDefender->getNameKey(), iDefenderDamageInflicted);
							pkDLLInterface->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pkDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
						}
						if(iActivePlayerID == pkDefender->getOwner())
						{
							if (iInterceptionDamage > 0 && pInterceptor)
							{
								strBuffer = GetLocalizedText("TXT_KEY_MISC_ENEMY_AIR_UNIT_INTERCEPTED", pInterceptor->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()), pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey());
								pkDLLInterface->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
							}
							else
							{
								strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_AIR", pkDefender->getNameKey(), pkAttacker->getNameKey(), iAttackerDamageInflicted);
								pkDLLInterface->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_COMBAT", MESSAGE_TYPE_INFO, pkDefender->getUnitInfo().GetButton(), (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
							}
						}
					}
				}

				//set damage but don't update entity damage visibility
				//pkDefender->changeDamage(iDamage, pkAttacker->getOwner());

				pkDefender->setCombatUnit(NULL);
				if(!CvUnitMission::IsHeadMission(pkDefender, CvTypes::getMISSION_WAIT_FOR()))		// If the top mission was not a 'wait for', then clear it.
					pkDefender->ClearMissionQueue();
			}
			else
				bTargetDied = true;
		}
		else
		{
			// Target was a City
			CvCity* pCity = pkTargetPlot->getPlotCity();
			CvAssert_Debug(pCity != NULL);

			if(pCity)
			{
				pCity->clearCombat();
				if(pkAttacker)
				{
					pCity->changeDamage(iAttackerDamageInflicted);

					// CitySplashDamage: deal flat damage to all non-air units in the city
					if (pkAttacker->GetCitySplashDamage() > 0)
					{
						int iSplash = pkAttacker->GetCitySplashDamage();
						for (int iUnitLoop = pkTargetPlot->getNumUnits() - 1; iUnitLoop >= 0; iUnitLoop--)
						{
							CvUnit* pSplashUnit = pkTargetPlot->getUnitByIndex(iUnitLoop);
							if (pSplashUnit && pSplashUnit->getDomainType() != DOMAIN_AIR)
							{
								pSplashUnit->changeDamage(iSplash, pkAttacker->getOwner());
							}
						}
					}

					// Carpet Bombing: 20% splash to adjacent non-air units
					if (pkAttacker->IsCarpetBombing() && iAttackerDamageInflicted > 0)
					{
						int iCarpetSplash = std::max(1, iAttackerDamageInflicted * 20 / 100);
						for (int iDirLoop = 0; iDirLoop < NUM_DIRECTION_TYPES; iDirLoop++)
						{
							CvPlot* pAdjPlot = plotDirection(pkTargetPlot->getX(), pkTargetPlot->getY(), (DirectionTypes)iDirLoop);
							if (!pAdjPlot) continue;
							for (int iUnitLoop = pAdjPlot->getNumUnits() - 1; iUnitLoop >= 0; iUnitLoop--)
							{
								CvUnit* pCarpetUnit = pAdjPlot->getUnitByIndex(iUnitLoop);
								if (!pCarpetUnit || pCarpetUnit->getDomainType() == DOMAIN_AIR) continue;
								if (pCarpetUnit->getTeam() == pkAttacker->getTeam()) continue; // no friendly fire
								if (pkAttacker->getTeam() != pCarpetUnit->getTeam()
									&& !GET_TEAM(pkAttacker->getTeam()).isAtWar(pCarpetUnit->getTeam()))
								{
									if (GET_PLAYER(pCarpetUnit->getOwner()).isMinorCiv())
										GET_TEAM(pkAttacker->getTeam()).declareWar(pCarpetUnit->getTeam());
									// Major civ not at war: damage without declaration
								}
								pCarpetUnit->changeDamage(iCarpetSplash, pkAttacker->getOwner());
								{
									char szCarpetText[64] = { 0 };
									sprintf_s(szCarpetText, "[COLOR_RED]-%d[ENDCOLOR]", iCarpetSplash);
									GC.GetEngineUserInterface()->AddPopupText(pAdjPlot->getX(), pAdjPlot->getY(), szCarpetText, GC.getPOST_COMBAT_TEXT_DELAY() * 2);
								}
							}
						}
					}

#ifdef ENHANCED_GRAPHS
					GET_PLAYER(pCity->getOwner()).ChangeCitiesDamageTaken(iAttackerDamageInflicted);
					GET_PLAYER(pkAttacker->getOwner()).ChangeCitiesDamageDealt(iAttackerDamageInflicted);
#endif
					pkAttacker->changeDamage(iDefenderDamageInflicted, pCity->getOwner());

					//		iUnitDamage = std::max(pCity->getDamage(), pCity->getDamage() + iDamage);

					if(pkAttacker->IsDead())
					{
						if(iActivePlayerID == pkAttacker->getOwner())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_DIED_ATTACKING_CITY", pkAttacker->getNameKey(), pCity->getNameKey(), iAttackerDamageInflicted);
							pkDLLInterface->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
						}
					}

					if(pCity->getOwner() == iActivePlayerID)
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOUR_CITY_ATTACKED_BY_AIR", pCity->getNameKey(), pkAttacker->getNameKey(), iDefenderDamageInflicted);
						//red icon over attacking unit
						pkDLLInterface->AddMessage(uiParentEventID, pCity->getOwner(), false, GC.getEVENT_MESSAGE_TIME(), strBuffer);
					}
				}
			}
			else
				bTargetDied = true;
		}
	}
	else
		bTargetDied = true;

	// Suicide Unit (e.g. Missiles)
	if(pkAttacker)
	{
		if(pkAttacker->isSuicide())
		{
			pkAttacker->setCombatUnit(NULL);	// Must clear this if doing a delayed kill, should this be part of the kill method?
#ifdef ENHANCED_GRAPHS
			if (pkAttacker->getUnitCombatType() != NO_UNITCOMBAT)
			{
				if (!pkTargetPlot->isCity())
				{
					CvUnit* pkDefender = kCombatInfo.getUnit(BATTLE_UNIT_DEFENDER);
					if (pkDefender->getOwner() != NO_PLAYER)
					{
						GET_PLAYER(pkDefender->getOwner()).ChangeNumKilledUnits(1);
					}
				}
				else
				{
					CvCity* pCity = pkTargetPlot->getPlotCity();
					if (pCity->getOwner() != NO_PLAYER)
					{
						GET_PLAYER(pCity->getOwner()).ChangeNumKilledUnits(1);
					}
				}
				GET_PLAYER(pkAttacker->getOwner()).ChangeNumLostUnits(1);
			}
#endif
			pkAttacker->kill(true);
		}
		else
		{
			// Experience
			if(iAttackerDamageInflicted > 0)
			{
				pkAttacker->changeExperience(kCombatInfo.getExperience(BATTLE_UNIT_ATTACKER),
				                             kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_ATTACKER),
				                             true,
				                             kCombatInfo.getInBorders(BATTLE_UNIT_ATTACKER),
				                             kCombatInfo.getUpdateGlobal(BATTLE_UNIT_ATTACKER));

#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
				// Promotion time?
				pkAttacker->testPromotionReady();
#endif

			}

			// Clean up some stuff
			pkAttacker->setCombatUnit(NULL);
			pkAttacker->ClearMissionQueue(GetPostCombatDelay());

			// Spend a move for this attack
			pkAttacker->changeMoves(-GC.getMOVE_DENOMINATOR());

			// Can't move or attack again
#ifdef NQ_UNIT_TURN_ENDS_ON_FINAL_ATTACK
			if(!pkAttacker->canMoveAfterAttacking() && pkAttacker->isOutOfAttacks())
#else
			if(!pkAttacker->canMoveAfterAttacking())
#endif
			{
				pkAttacker->finishMoves();
			}
		}

		// Report that combat is over in case we want to queue another attack
		GET_PLAYER(pkAttacker->getOwner()).GetTacticalAI()->CombatResolved(pkAttacker, bTargetDied);
	}
}

//	---------------------------------------------------------------------------
void CvUnitCombat::GenerateAirSweepCombatInfo(CvCombatInfo* pkCombatInfo)
{
	pkCombatInfo->setAttackIsRanged(false);
	pkCombatInfo->setAttackIsAirSweep(true);
	pkCombatInfo->setAttackerAdvances(false);
	pkCombatInfo->setDefenderRetaliates(true);

	GC.getGame().getCombatDamage(*pkCombatInfo);

	GC.GetEngineUserInterface()->setDirty(UnitInfo_DIRTY_BIT, true);
}

//	---------------------------------------------------------------------------
void CvUnitCombat::ResolveAirSweep(const CvCombatInfo& kCombatInfo, uint uiParentEventID)
{
	// After combat stuff
	CvString strBuffer;
	bool bAttackerDead = false;
	bool bDefenderDead = false;

	CvUnit* pkAttacker = kCombatInfo.getUnit(BATTLE_UNIT_ATTACKER);
	CvUnit* pkDefender = kCombatInfo.getUnit(BATTLE_UNIT_DEFENDER);
	CvPlot* pkTargetPlot = kCombatInfo.getPlot();
	if(!pkTargetPlot && pkDefender)
		pkTargetPlot = pkDefender->plot();

	CvAssert_Debug(pkAttacker && pkDefender && pkTargetPlot);

	// Internal variables
	int iAttackerDamageInflicted = kCombatInfo.getDamageInflicted(BATTLE_UNIT_ATTACKER);
	int iDefenderDamageInflicted = kCombatInfo.getDamageInflicted(BATTLE_UNIT_DEFENDER);

	// Made interception!
	if(pkDefender)
	{
		pkDefender->setMadeInterception(true);
		if(pkAttacker && pkTargetPlot)
		{
			//One Hit
			if(pkDefender->GetCurrHitPoints() == GC.getMAX_HIT_POINTS() && pkAttacker->isHuman() && !GC.getGame().isGameMultiPlayer())
			{
				gDLL->UnlockAchievement(ACHIEVEMENT_ONEHITKILL);
			}

			pkDefender->changeDamage(iAttackerDamageInflicted, pkAttacker->getOwner());
			pkAttacker->changeDamage(iDefenderDamageInflicted, pkDefender->getOwner());

			// Update experience for both sides.
			pkDefender->changeExperience(
			    kCombatInfo.getExperience(BATTLE_UNIT_DEFENDER),
			    kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_DEFENDER),
			    true,
			    kCombatInfo.getInBorders(BATTLE_UNIT_DEFENDER),
			    kCombatInfo.getUpdateGlobal(BATTLE_UNIT_DEFENDER));

			pkAttacker->changeExperience(
			    kCombatInfo.getExperience(BATTLE_UNIT_ATTACKER),
			    kCombatInfo.getMaxExperienceAllowed(BATTLE_UNIT_ATTACKER),
			    true,
			    kCombatInfo.getInBorders(BATTLE_UNIT_ATTACKER),
			    kCombatInfo.getUpdateGlobal(BATTLE_UNIT_ATTACKER));

			// Anyone eat it?
			bAttackerDead = (pkAttacker->getDamage() >= GC.getMAX_HIT_POINTS());
			bDefenderDead = (pkDefender->getDamage() >= GC.getMAX_HIT_POINTS());

			int iActivePlayerID = GC.getGame().getActivePlayer();

			//////////////////////////////////////////////////////////////////////////

#ifndef AUI_UNIT_COMBAT_FIX_AIR_SWEEP_VS_GROUND_INTERCEPTOR
			// Ground AA interceptor
			if(pkDefender->getDomainType() != DOMAIN_AIR)
			{
				// Attacker died
				if(bAttackerDead)
				{
					auto_ptr<ICvUnit1> pAttacker = GC.WrapUnitPointer(pkAttacker);
					gDLL->GameplayUnitDestroyedInCombat(pAttacker.get());

					if(iActivePlayerID == pkAttacker->getOwner())
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_DIED_ATTACKING", pkAttacker->getNameKey(), pkDefender->getNameKey(), iAttackerDamageInflicted, 0);
						GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
					}
					if(iActivePlayerID == pkDefender->getOwner())
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_KILLED_ENEMY_UNIT", pkDefender->getNameKey(), iAttackerDamageInflicted, 0, pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()));
						GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
					}

#ifdef PROMOTION_INSTA_HEAL_LOCKED
					if (GET_PLAYER(pkDefender->getOwner()).isTurnActive())
					{
						pkDefender->testPromotionReady();
					}
#else
#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
					pkDefender->testPromotionReady();
#endif
#endif
				}
			}
			// Air AA interceptor
			else
#endif
			{
				// Attacker died
				if(bAttackerDead)
				{
					auto_ptr<ICvUnit1> pAttacker = GC.WrapUnitPointer(pkAttacker);
					gDLL->GameplayUnitDestroyedInCombat(pAttacker.get());

					if(iActivePlayerID == pkAttacker->getOwner())
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_DIED_ATTACKING", pkAttacker->getNameKey(), pkDefender->getNameKey(), iAttackerDamageInflicted, 0);
						GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
					}
					if(iActivePlayerID == pkDefender->getOwner())
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_KILLED_ENEMY_UNIT", pkDefender->getNameKey(), iAttackerDamageInflicted, 0, pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()));
						GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
					}

#ifdef PROMOTION_INSTA_HEAL_LOCKED
					if (GET_PLAYER(pkDefender->getOwner()).isTurnActive())
					{
						pkDefender->testPromotionReady();
					}
#else
#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
					pkDefender->testPromotionReady();
#endif

#endif
					ApplyPostCombatTraitEffects(pkDefender, pkAttacker);
				}
				// Defender died
				else if(bDefenderDead)
				{
					auto_ptr<ICvUnit1> pDefender = GC.WrapUnitPointer(pkDefender);
					gDLL->GameplayUnitDestroyedInCombat(pDefender.get());

					if(iActivePlayerID == pkAttacker->getOwner())
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_DESTROYED_ENEMY", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey());
						GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitVictoryScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
					}
					if(iActivePlayerID == pkDefender->getOwner())
					{
						if(pkAttacker->getVisualOwner(pkDefender->getTeam()) != pkAttacker->getOwner())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WAS_DESTROYED_UNKNOWN", pkDefender->getNameKey(), pkAttacker->getNameKey(), iDefenderDamageInflicted);
						}
						else
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WAS_DESTROYED", pkDefender->getNameKey(), pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()), iDefenderDamageInflicted);
						}
						GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*,GC.getEraInfo(GC.getGame().getCurrentEra())->getAudioUnitDefeatScript(), MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
					}

					CvNotifications* pNotification = GET_PLAYER(pkDefender->getOwner()).GetNotifications();
					if(pNotification)
					{
						if(pkAttacker->getVisualOwner(pkDefender->getTeam()) != pkAttacker->getOwner())
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WAS_DESTROYED_UNKNOWN", pkDefender->getNameKey(), pkAttacker->getNameKey(), iDefenderDamageInflicted);
						}
						else
						{
							strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WAS_DESTROYED", pkDefender->getNameKey(), pkAttacker->getNameKey(), pkAttacker->getVisualCivAdjective(pkDefender->getTeam()), iDefenderDamageInflicted);
						}
						Localization::String strSummary = Localization::Lookup("TXT_KEY_UNIT_LOST");
						pNotification->Add(NOTIFICATION_UNIT_DIED, strBuffer, strSummary.toUTF8(), pkDefender->getX(), pkDefender->getY(), (int) pkDefender->getUnitType(), pkDefender->getOwner());
					}

#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
					pkAttacker->testPromotionReady();
#endif

					ApplyPostCombatTraitEffects(pkAttacker, pkDefender);
				}
				// Nobody died
				else
				{
					if(iActivePlayerID == pkAttacker->getOwner())
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_YOU_UNIT_WITHDRAW", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey(), iAttackerDamageInflicted);
						GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkAttacker->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_OUR_WITHDRAWL", MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_GREEN"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
					}
					if(iActivePlayerID == pkDefender->getOwner())
					{
						strBuffer = GetLocalizedText("TXT_KEY_MISC_ENEMY_UNIT_WITHDRAW", pkAttacker->getNameKey(), iDefenderDamageInflicted, pkDefender->getNameKey(), iAttackerDamageInflicted);
						GC.GetEngineUserInterface()->AddMessage(uiParentEventID, pkDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer/*, "AS2D_THEIR_WITHDRAWL", MESSAGE_TYPE_INFO, NULL, (ColorTypes)GC.getInfoTypeForString("COLOR_RED"), pkTargetPlot->getX(), pkTargetPlot->getY()*/);
					}

#ifdef PROMOTION_INSTA_HEAL_LOCKED
					if (GET_PLAYER(pkDefender->getOwner()).isTurnActive())
					{
						pkDefender->testPromotionReady();
					}
#else
#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
					pkDefender->testPromotionReady();
#endif
#endif
#ifndef AUI_UNIT_TEST_PROMOTION_READY_MOVED
					pkAttacker->testPromotionReady();
#endif
				}
			}
		}
	}
	else
		bDefenderDead = true;

	// Clean up some stuff
	if(pkDefender)
	{
		pkDefender->setCombatUnit(NULL);
		pkDefender->ClearMissionQueue();
#ifdef NQM_UNIT_COMBAT_WITHDRAW_INTERCEPT_AFTER_SWEEP_IF_AT_OR_BELOW_TARGET_HEALTH
		if (pkDefender->GetActivityType() == ACTIVITY_INTERCEPT)
		{
			int iEffectiveDefenderHP = pkDefender->GetCurrHitPoints();
			if (pkDefender->isAlwaysHeal() && pkDefender->isOutOfInterceptions() && !GET_PLAYER(pkDefender->getOwner()).isEndTurn() && pkDefender->canHeal(pkDefender->plot()))
				iEffectiveDefenderHP += pkDefender->healRate(pkDefender->plot());
			if (iEffectiveDefenderHP * NQM_UNIT_COMBAT_WITHDRAW_INTERCEPT_AFTER_SWEEP_IF_AT_OR_BELOW_TARGET_HEALTH <= GC.getMAX_HIT_POINTS() * 100)
				pkDefender->SetActivityType(ACTIVITY_AWAKE);
		}
#endif
	}

	if(pkAttacker)
	{
		pkAttacker->setCombatUnit(NULL);
		pkAttacker->ClearMissionQueue(GetPostCombatDelay());

		// Spend a move for this attack
		pkAttacker->changeMoves(-GC.getMOVE_DENOMINATOR());

		// Can't move or attack again
#ifdef NQ_UNIT_TURN_ENDS_ON_FINAL_ATTACK
		if(!pkAttacker->canMoveAfterAttacking() && pkAttacker->isOutOfAttacks())
#else
		if(!pkAttacker->canMoveAfterAttacking())
#endif
		{
			pkAttacker->finishMoves();
		}

		// Report that combat is over in case we want to queue another attack
		GET_PLAYER(pkAttacker->getOwner()).GetTacticalAI()->CombatResolved(pkAttacker, bDefenderDead);
	}
}

//	GenerateNuclearCombatInfo
//	Function: GenerateNuclearCombatInfo
//	Take the input parameters and fill in a CvCombatInfo definition assuming a
//	mission to do a nuclear attack.
//
//	Parameters:
//		pkDefender   	-	Defending unit.  Can be null, in which case the input plot must have a city
//		plot         	-	The plot of the defending unit/city
//		pkCombatInfo 	-	Output combat info
//	---------------------------------------------------------------------------
void CvUnitCombat::GenerateNuclearCombatInfo(CvCombatInfo* pkCombatInfo)
{
	CvUnit& kAttacker = *pkCombatInfo->getUnit(BATTLE_UNIT_ATTACKER);
	CvPlot& plot = *pkCombatInfo->getPlot();
	pkCombatInfo->setUnit(BATTLE_UNIT_DEFENDER, NULL);


	//////////////////////////////////////////////////////////////////////

	CvString strBuffer;
	bool abTeamsAffected[MAX_TEAMS];
	int iI;
	for(iI = 0; iI < MAX_TEAMS; iI++)
	{
		abTeamsAffected[iI] = kAttacker.isNukeVictim(&plot, ((TeamTypes)iI));
	}

	int iPlotTeam = plot.getTeam();
	bool bWar = false;
	bool bBystander = false;

	for(iI = 0; iI < MAX_TEAMS; iI++)
	{
		if(abTeamsAffected[iI])
		{
			if(!kAttacker.isEnemy((TeamTypes)iI))
			{
				GET_TEAM(kAttacker.getTeam()).declareWar(((TeamTypes)iI));

				if (iPlotTeam == iI) 
				{
					bWar = true;
				} 
				else 
				{
					bBystander = true;
				}
			}
		}
	}

	ICvEngineScriptSystem1* pkScriptSystem = gDLL->GetScriptSystem();
	if (pkScriptSystem) 
	{	
		CvLuaArgsHandle args;

		args->Push(kAttacker.getOwner());
		args->Push(plot.getX());
		args->Push(plot.getY());
		args->Push(bWar);
		args->Push(bBystander);

		bool bResult;
		LuaSupport::CallHook(pkScriptSystem, "NuclearDetonation", args.get(), bResult);
	}

	kAttacker.setReconPlot(&plot);

	//////////////////////////////////////////////////////////////////////

	pkCombatInfo->setFinalDamage(BATTLE_UNIT_ATTACKER, 0);		// Total damage to the unit
	pkCombatInfo->setDamageInflicted(BATTLE_UNIT_ATTACKER, 0);	// Damage inflicted this round
	pkCombatInfo->setFinalDamage(BATTLE_UNIT_DEFENDER, 0);		// Total damage to the unit
	pkCombatInfo->setDamageInflicted(BATTLE_UNIT_DEFENDER, 0);	// Damage inflicted this round

	pkCombatInfo->setFearDamageInflicted(BATTLE_UNIT_ATTACKER, 0);

	pkCombatInfo->setExperience(BATTLE_UNIT_ATTACKER, 0);
	pkCombatInfo->setMaxExperienceAllowed(BATTLE_UNIT_ATTACKER, 0);
	pkCombatInfo->setInBorders(BATTLE_UNIT_ATTACKER, plot.getOwner() != kAttacker.getOwner());
#ifdef NQ_NO_GG_POINTS_FROM_CS_OR_BARBS
	pkCombatInfo->setUpdateGlobal(BATTLE_UNIT_ATTACKER, false); // Since experience earned is 0 anyway, no need to bother
#else
	pkCombatInfo->setUpdateGlobal(BATTLE_UNIT_ATTACKER, !kAttacker.isBarbarian());
#endif

	pkCombatInfo->setExperience(BATTLE_UNIT_DEFENDER, 0);
	pkCombatInfo->setMaxExperienceAllowed(BATTLE_UNIT_DEFENDER, 0);
	pkCombatInfo->setInBorders(BATTLE_UNIT_DEFENDER, plot.getOwner() == kAttacker.getOwner());
	pkCombatInfo->setUpdateGlobal(BATTLE_UNIT_DEFENDER, false);

	pkCombatInfo->setAttackIsBombingMission(true);
	pkCombatInfo->setDefenderRetaliates(false);
	pkCombatInfo->setAttackNuclearLevel(kAttacker.GetNukeDamageLevel() + 1);

	// Set all of the units in the blast radius to defenders and calculate their damage
	int iDamageMembers = 0;
	GenerateNuclearExplosionDamage(&plot, kAttacker.GetNukeDamageLevel(), &kAttacker, pkCombatInfo->getDamageMembers(), &iDamageMembers, pkCombatInfo->getMaxDamageMemberCount());
	pkCombatInfo->setDamageMemberCount(iDamageMembers);

	GC.GetEngineUserInterface()->setDirty(UnitInfo_DIRTY_BIT, true);
}

//	-------------------------------------------------------------------------------------
uint CvUnitCombat::ApplyNuclearExplosionDamage(CvPlot* pkTargetPlot, int iDamageLevel, CvUnit* /* pkAttacker = NULL*/)
{
	CvCombatMemberEntry kDamageMembers[MAX_NUKE_DAMAGE_MEMBERS];
	int iDamageMembers = 0;
	GenerateNuclearExplosionDamage(pkTargetPlot, iDamageLevel, NULL, &kDamageMembers[0], &iDamageMembers, MAX_NUKE_DAMAGE_MEMBERS);
	return ApplyNuclearExplosionDamage(&kDamageMembers[0], iDamageMembers, NULL, pkTargetPlot, iDamageLevel);
}

//	-------------------------------------------------------------------------------------
uint CvUnitCombat::ApplyNuclearExplosionDamage(const CvCombatMemberEntry* pkDamageArray, int iDamageMembers, CvUnit* pkAttacker, CvPlot* pkTargetPlot, int iDamageLevel)
{
	uint uiOpposingDamageCount = 0;
	PlayerTypes eAttackerOwner = pkAttacker?pkAttacker->getOwner():NO_PLAYER;

	// Do all the units first
	for(int i = 0; i < iDamageMembers; ++i)
	{
		const CvCombatMemberEntry& kEntry = pkDamageArray[i];
		if(kEntry.IsUnit())
		{
			CvUnit* pkUnit = GET_PLAYER(kEntry.GetPlayer()).getUnit(kEntry.GetUnitID());
			if(pkUnit)
			{
				// Apply the damage
				pkUnit->setCombatUnit(NULL);
				pkUnit->ClearMissionQueue();
				pkUnit->SetAutomateType(NO_AUTOMATE); // kick unit out of automation

				if((eAttackerOwner == NO_PLAYER || pkUnit->getOwner() != eAttackerOwner) && !pkUnit->isBarbarian())
					uiOpposingDamageCount++;	// Count the number of non-barbarian opposing units

				if(pkUnit->IsCombatUnit() || pkUnit->IsCanAttackRanged())
				{
					pkUnit->changeDamage(kEntry.GetDamage(), eAttackerOwner);
				}
				else if(kEntry.GetDamage() >= /*6*/ GC.getNUKE_NON_COMBAT_DEATH_THRESHOLD())
				{
					pkUnit->kill(false, eAttackerOwner);
				}

#ifdef AUI_WARNING_FIXES
				if (pkAttacker)
#endif
				GET_PLAYER(kEntry.GetPlayer()).GetDiplomacyAI()->ChangeNumTimesNuked(pkAttacker->getOwner(), 1);
			}
		}
	}

	// Then the terrain effects
	int iBlastRadius = GC.getNUKE_BLAST_RADIUS();

#ifdef AUI_HEXSPACE_DX_LOOPS
	int iMaxDX, iDX;
	CvPlot* pLoopPlot;
	if (pkTargetPlot)
	{
		for (int iDY = -iBlastRadius; iDY <= iBlastRadius; iDY++)
		{
			iMaxDX = iBlastRadius - MAX(0, iDY);
			for (iDX = -iBlastRadius - MIN(0, iDY); iDX <= iMaxDX; iDX++) // MIN() and MAX() stuff is to reduce loops (hexspace!)
			{
				// No need for range check because loops are set up properly
				pLoopPlot = plotXY(pkTargetPlot->getX(), pkTargetPlot->getY(), iDX, iDY);
#else
	for(int iDX = -(iBlastRadius); iDX <= iBlastRadius; iDX++)
	{
		for(int iDY = -(iBlastRadius); iDY <= iBlastRadius; iDY++)
		{
			CvPlot* pLoopPlot = plotXYWithRangeCheck(pkTargetPlot->getX(), pkTargetPlot->getY(), iDX, iDY, iBlastRadius);
#endif

			if(pLoopPlot != NULL)
			{
				// if we remove roads, don't remove them on the city... XXX
				CvCity* pLoopCity = pLoopPlot->getPlotCity();

				if(pLoopCity == NULL)
				{
					if(!(pLoopPlot->isWater()) && !(pLoopPlot->isImpassable()))
					{
						if(pLoopPlot->getFeatureType() != NO_FEATURE)
						{
							CvFeatureInfo* pkFeatureInfo = GC.getFeatureInfo(pLoopPlot->getFeatureType());
							if(pkFeatureInfo && !pkFeatureInfo->isNukeImmune())
							{
								if(pLoopPlot == pkTargetPlot || GC.getGame().getJonRandNum(100, "Nuke Fallout") < GC.getNUKE_FALLOUT_PROB())
								{
									if(pLoopPlot->getImprovementType() != NO_IMPROVEMENT)
									{
										pLoopPlot->SetImprovementPillaged(true);
									}
									pLoopPlot->setFeatureType((FeatureTypes)(GC.getNUKE_FEATURE()));
								}
							}
						}
						else
						{
							if(pLoopPlot == pkTargetPlot || GC.getGame().getJonRandNum(100, "Nuke Fallout") < GC.getNUKE_FALLOUT_PROB())
							{
								if(pLoopPlot->getImprovementType() != NO_IMPROVEMENT)
								{
									pLoopPlot->SetImprovementPillaged(true);
								}
								pLoopPlot->setFeatureType((FeatureTypes)(GC.getNUKE_FEATURE()));
							}
						}
					}
				}
			}
		}
	}
#ifdef AUI_HEXSPACE_DX_LOOPS
	}
#endif

	// Then the cities
	for(int i = 0; i < iDamageMembers; ++i)
	{
		const CvCombatMemberEntry& kEntry = pkDamageArray[i];
		if(kEntry.IsCity())
		{
			CvCity* pkCity = GET_PLAYER(kEntry.GetPlayer()).getCity(kEntry.GetCityID());
			if(pkCity)
			{
				pkCity->setCombatUnit(NULL);

				if(eAttackerOwner == NO_PLAYER || pkCity->getOwner() != eAttackerOwner)
					uiOpposingDamageCount++;

				if(kEntry.GetFinalDamage() >= pkCity->GetMaxHitPoints() && !pkCity->IsOriginalCapital())
				{
					auto_ptr<ICvCity1> pkDllCity(new CvDllCity(pkCity));
					gDLL->GameplayCitySetDamage(pkDllCity.get(), 0, pkCity->getDamage()); // to stop the fires
					gDLL->GameplayCityDestroyed(pkDllCity.get(), NO_PLAYER);

					PlayerTypes eOldOwner = pkCity->getOwner();
					pkCity->kill();

					// slewis - check for killing a player
#ifdef AUI_WARNING_FIXES
					if (pkAttacker)
#endif
					GET_PLAYER(pkAttacker->getOwner()).CheckForMurder(eOldOwner);
				}
				else
				{
					// Unlike the city hit points, the population damage is calculated when the pre-calculated damage is applied.
					// This is simply to save space in the damage array, since the combat visualization does not need it.
					// It can be moved into the pre-calculated damage array if needed.
					int iBaseDamage, iRandDamage1, iRandDamage2;
					// How much destruction is unleashed on nearby Cities?
					if(iDamageLevel == 1)
					{
						iBaseDamage = /*30*/ GC.getNUKE_LEVEL1_POPULATION_DEATH_BASE();
						iRandDamage1 = GC.getGame().getJonRandNum(/*20*/ GC.getNUKE_LEVEL1_POPULATION_DEATH_RAND_1(), "Population Nuked 1");
						iRandDamage2 = GC.getGame().getJonRandNum(/*20*/ GC.getNUKE_LEVEL1_POPULATION_DEATH_RAND_2(), "Population Nuked 2");
					}
					else
					{
						iBaseDamage = /*60*/ GC.getNUKE_LEVEL2_POPULATION_DEATH_BASE();
						iRandDamage1 = GC.getGame().getJonRandNum(/*10*/ GC.getNUKE_LEVEL2_POPULATION_DEATH_RAND_1(), "Population Nuked 1");
						iRandDamage2 = GC.getGame().getJonRandNum(/*10*/ GC.getNUKE_LEVEL2_POPULATION_DEATH_RAND_2(), "Population Nuked 2");
					}

					int iNukedPopulation = pkCity->getPopulation() * (iBaseDamage + iRandDamage1 + iRandDamage2) / 100;

					iNukedPopulation *= std::max(0, (pkCity->getNukeModifier() + 100));
					iNukedPopulation /= 100;

					pkCity->changePopulation(-(std::min((pkCity->getPopulation() - 1), iNukedPopulation)));

					// Add damage to the city
#ifdef ENHANCED_GRAPHS
					GET_PLAYER(pkCity->getOwner()).ChangeCitiesDamageTaken(kEntry.GetFinalDamage() - pkCity->getDamage());
					GET_PLAYER(pkAttacker->getOwner()).ChangeCitiesDamageDealt(kEntry.GetFinalDamage() - pkCity->getDamage());
#endif
					pkCity->setDamage(kEntry.GetFinalDamage());

#ifdef AUI_WARNING_FIXES
					if (pkAttacker)
#endif
					GET_PLAYER(pkCity->getOwner()).GetDiplomacyAI()->ChangeNumTimesNuked(pkAttacker->getOwner(), 1);
				}
			}
		}
	}
	return uiOpposingDamageCount;
}

//	-------------------------------------------------------------------------------------
//	Generate nuclear explosion damage for all the units and cities in the radius of the specified plot.
//	The attacker is optional, this is also called for a meltdown
void CvUnitCombat::GenerateNuclearExplosionDamage(CvPlot* pkTargetPlot, int iDamageLevel, CvUnit* pkAttacker, CvCombatMemberEntry* pkDamageArray, int* piDamageMembers, int iMaxDamageMembers)
{
	int iBlastRadius = GC.getNUKE_BLAST_RADIUS();

	*piDamageMembers = 0;

#ifdef AUI_HEXSPACE_DX_LOOPS
	int iMaxDX, iDX;
	CvPlot* pLoopPlot;
	for (int iDY = -iBlastRadius; iDY <= iBlastRadius; iDY++)
	{
		iMaxDX = iBlastRadius - MAX(0, iDY);
		for (iDX = -iBlastRadius - MIN(0, iDY); iDX <= iMaxDX; iDX++) // MIN() and MAX() stuff is to reduce loops (hexspace!)
		{
			// No need for range check because loops are set up properly
			pLoopPlot = plotXY(pkTargetPlot->getX(), pkTargetPlot->getY(), iDX, iDY);
#else
	for(int iDX = -(iBlastRadius); iDX <= iBlastRadius; iDX++)
	{
		for(int iDY = -(iBlastRadius); iDY <= iBlastRadius; iDY++)
		{
			CvPlot* pLoopPlot = plotXYWithRangeCheck(pkTargetPlot->getX(), pkTargetPlot->getY(), iDX, iDY, iBlastRadius);
#endif

			if(pLoopPlot != NULL)
			{
				CvCity* pLoopCity = pLoopPlot->getPlotCity();

				FFastSmallFixedList<IDInfo, 25, true, c_eCiv5GameplayDLL > oldUnits;
				IDInfo* pUnitNode = pLoopPlot->headUnitNode();

				while(pUnitNode != NULL)
				{
					oldUnits.insertAtEnd(pUnitNode);
					pUnitNode = pLoopPlot->nextUnitNode(pUnitNode);
				}

				pUnitNode = oldUnits.head();

				while(pUnitNode != NULL)
				{
					CvUnit* pLoopUnit = ::getUnit(*pUnitNode);
					pUnitNode = oldUnits.next(pUnitNode);

					if(pLoopUnit != NULL)
					{
						if(pLoopUnit != pkAttacker)
						{
							if(!pLoopUnit->isNukeImmune() && !pLoopUnit->isDelayedDeath())
							{
								int iNukeDamage;
								// How much destruction is unleashed on nearby Units?
								if(iDamageLevel == 1 && pLoopPlot != pkTargetPlot)	// Nuke level 1, but NOT the plot that got hit directly (units there are killed)
								{
									iNukeDamage = (/*3*/ GC.getNUKE_UNIT_DAMAGE_BASE() + /*4*/ GC.getGame().getJonRandNum(GC.getNUKE_UNIT_DAMAGE_RAND_1(), "Nuke Damage 1") + /*4*/ GC.getGame().getJonRandNum(GC.getNUKE_UNIT_DAMAGE_RAND_2(), "Nuke Damage 2"));
								}
								// Wipe everything out
								else
								{
									iNukeDamage = GC.getMAX_HIT_POINTS();
								}

								if(pLoopCity != NULL)
								{
									iNukeDamage *= std::max(0, (pLoopCity->getNukeModifier() + 100));
									iNukeDamage /= 100;
								}
#ifdef LEKMOD_DEFENSE_BUILDINGS
								// Bomb Shelter: military units (planes too) in the city take exactly this damage
								if (pLoopCity != NULL && (pLoopUnit->IsCombatUnit() || pLoopUnit->getDomainType() == DOMAIN_AIR) && pLoopCity->GetLekmodBuildingStat(5, true) > 0)
								{
									iNukeDamage = pLoopCity->GetLekmodBuildingStat(5, true);
								}
#endif
#ifdef LEKMOD_NUKE_RESISTANCE
								// Nuke resistance: the same damage everywhere (ground zero, open terrain); a lower Bomb Shelter value wins
								if (pLoopUnit->GetLekmodNukeDamageFixed() > 0)
								{
									iNukeDamage = std::min(iNukeDamage, pLoopUnit->GetLekmodNukeDamageFixed());
								}
#endif

								CvCombatMemberEntry* pkDamageEntry = AddCombatMember(pkDamageArray, piDamageMembers, iMaxDamageMembers, pLoopUnit);
								if(pkDamageEntry)
								{
									pkDamageEntry->SetDamage(iNukeDamage);
									pkDamageEntry->SetFinalDamage(std::min(iNukeDamage + pLoopUnit->getDamage(), GC.getMAX_HIT_POINTS()));
									pkDamageEntry->SetMaxHitPoints(GC.getMAX_HIT_POINTS());
									if(pkAttacker)
										pLoopUnit->setCombatUnit(pkAttacker);
								}
								else
								{
									CvAssertMsg(*piDamageMembers < iMaxDamageMembers, "Ran out of entries for the nuclear damage array");
								}
							}
						}
					}
				}

				if(pLoopCity != NULL)
				{
					bool bKillCity = false;

					// Is the city wiped out? - no capitals!
					if(!pLoopCity->IsOriginalCapital())
					{
						if(iDamageLevel > 2)
						{
							bKillCity = true;
						}
						else if(iDamageLevel > 1)
						{
							if(pLoopCity->getPopulation() < /*5*/ GC.getNUKE_LEVEL2_ELIM_POPULATION_THRESHOLD())
							{
								bKillCity = true;
							}
						}
					}

					int iTotalDamage;
					if(bKillCity)
					{
						iTotalDamage = pLoopCity->GetMaxHitPoints();
					}
					else
					{
						// Add damage to the city
						iTotalDamage = (pLoopCity->GetMaxHitPoints() - pLoopCity->getDamage()) * /*50*/ GC.getNUKE_CITY_HIT_POINT_DAMAGE();
						iTotalDamage /= 100;

						iTotalDamage += pLoopCity->getDamage();

						// Can't bring a city below 1 HP
						iTotalDamage = min(iTotalDamage, pLoopCity->GetMaxHitPoints() - 1);
					}

					CvCombatMemberEntry* pkDamageEntry = AddCombatMember(pkDamageArray, piDamageMembers, iMaxDamageMembers, pLoopCity);
					if(pkDamageEntry)
					{
						pkDamageEntry->SetDamage(iTotalDamage - pLoopCity->getDamage());
						pkDamageEntry->SetFinalDamage(iTotalDamage);
						pkDamageEntry->SetMaxHitPoints(pLoopCity->GetMaxHitPoints());

						if(pkAttacker)
							pLoopCity->setCombatUnit(pkAttacker);
					}
					else
					{
						CvAssertMsg(*piDamageMembers < iMaxDamageMembers, "Ran out of entries for the nuclear damage array");
					}
				}
			}
		}
	}
}

//	---------------------------------------------------------------------------
//	Function: ResolveNuclearCombat
//	Resolve combat from a nuclear attack.
void CvUnitCombat::ResolveNuclearCombat(const CvCombatInfo& kCombatInfo, uint uiParentEventID)
{
	UNREFERENCED_PARAMETER(uiParentEventID);

	CvUnit* pkAttacker = kCombatInfo.getUnit(BATTLE_UNIT_ATTACKER);
	CvAssert_Debug(pkAttacker);

	CvPlot* pkTargetPlot = kCombatInfo.getPlot();
	CvAssert_Debug(pkTargetPlot);

	CvString strBuffer;

	GC.getGame().changeNukesExploded(1);

	if(pkAttacker)
	{
		// Make sure we are disconnected from any unit transporting the attacker (i.e. its a missile)
		pkAttacker->setTransportUnit(NULL);

		if(pkTargetPlot)
		{
			if(ApplyNuclearExplosionDamage(kCombatInfo.getDamageMembers(), kCombatInfo.getDamageMemberCount(), pkAttacker, pkTargetPlot, kCombatInfo.getAttackNuclearLevel() - 1) > 0)
			{
				if(pkAttacker->getOwner() == GC.getGame().getActivePlayer())
				{
					// Must damage someone to get the achievement.
					gDLL->UnlockAchievement(ACHIEVEMENT_DROP_NUKE);

					if(GC.getGame().getGameTurnYear() == 2012)
					{
						CvPlayerAI& kPlayer = GET_PLAYER(GC.getGame().getActivePlayer());
						if(strncmp(kPlayer.getCivilizationTypeKey(), "CIVILIZATION_MAYA", 32) == 0)
						{
							gDLL->UnlockAchievement(ACHIEVEMENT_XP1_36);
						}

					}

				}
			}
		}

		// Suicide Unit (currently all nuclear attackers are)
		if(pkAttacker->isSuicide())
		{
			pkAttacker->setCombatUnit(NULL);	// Must clear this if doing a delayed kill, should this be part of the kill method?
			pkAttacker->setAttackPlot(NULL, false);
			pkAttacker->kill(true);
		}
		else
		{
			CvAssertMsg(pkAttacker->isSuicide(), "A nuke unit that is not a one time use?");

			// Clean up some stuff
			pkAttacker->setCombatUnit(NULL);
			pkAttacker->ClearMissionQueue(GetPostCombatDelay());
			pkAttacker->SetAutomateType(NO_AUTOMATE); // kick unit out of automation

			// Spend a move for this attack
			pkAttacker->changeMoves(-GC.getMOVE_DENOMINATOR());

			// Can't move or attack again
#ifdef NQ_UNIT_TURN_ENDS_ON_FINAL_ATTACK
			if(!pkAttacker->canMoveAfterAttacking() && pkAttacker->isOutOfAttacks())
#else
			if(!pkAttacker->canMoveAfterAttacking())
#endif
			{
				pkAttacker->finishMoves();
			}
		}

		// Report that combat is over in case we want to queue another attack
		GET_PLAYER(pkAttacker->getOwner()).GetTacticalAI()->CombatResolved(pkAttacker, true);
	}
}

//	---------------------------------------------------------------------------
void CvUnitCombat::ResolveCombat(const CvCombatInfo& kInfo, uint uiParentEventID /* = 0 */)
{
	PlayerTypes eAttackingPlayer = NO_PLAYER;
	// Restore visibility
	CvUnit* pAttacker = kInfo.getUnit(BATTLE_UNIT_ATTACKER);

	const TeamTypes eActiveTeam = GC.getGame().getActiveTeam();

	if(pAttacker)
	{
		eAttackingPlayer = pAttacker->getOwner();
		auto_ptr<ICvUnit1> pDllUnit(new CvDllUnit(pAttacker));
		gDLL->GameplayUnitVisibility(pDllUnit.get(), !pAttacker->isInvisible(eActiveTeam, false));
	}

	CvUnit* pDefender = kInfo.getUnit(BATTLE_UNIT_DEFENDER);
	if(pDefender)
	{
		auto_ptr<ICvUnit1> pDllUnit(new CvDllUnit(pDefender));
		gDLL->GameplayUnitVisibility(pDllUnit.get(), !pDefender->isInvisible(eActiveTeam, false));
	}

	CvUnit* pDefenderSupport = kInfo.getUnit(BATTLE_UNIT_INTERCEPTOR);
	if(pDefenderSupport)
	{
		auto_ptr<ICvUnit1> pDllUnit(new CvDllUnit(pDefenderSupport));
		gDLL->GameplayUnitVisibility(pDllUnit.get(), !pDefenderSupport->isInvisible(eActiveTeam, false));
	}
#ifdef LEKMOD_AIR_COMBAT_FEEDBACK
	// Remember where the air unit started: it may die during resolution
	const int iAirFeedbackX = pAttacker ? pAttacker->getX() : -1;
	const int iAirFeedbackY = pAttacker ? pAttacker->getY() : -1;
	// ... and where the damage lands (the defending unit, e.g. a sweep's interceptor, can be off the target tile)
	CvPlot* pAirFeedbackTargetPlot = pDefender ? pDefender->plot() : kInfo.getPlot();
	const int iAirTargetX = pAirFeedbackTargetPlot ? pAirFeedbackTargetPlot->getX() : -1;
	const int iAirTargetY = pAirFeedbackTargetPlot ? pAirFeedbackTargetPlot->getY() : -1;
#endif
	// Nuclear Mission
	if(kInfo.getAttackIsNuclear())
	{
		ResolveNuclearCombat(kInfo, uiParentEventID);
	}

	// Bombing Mission
	else if(kInfo.getAttackIsBombingMission())
	{
		ResolveAirUnitVsCombat(kInfo, uiParentEventID);
	}

	// Air Sweep Mission
	else if(kInfo.getAttackIsAirSweep())
	{
		ResolveAirSweep(kInfo, uiParentEventID);
	}

	// Ranged Attack
	else if(kInfo.getAttackIsRanged())
	{
		if(kInfo.getUnit(BATTLE_UNIT_ATTACKER))
		{
			ResolveRangedUnitVsCombat(kInfo, uiParentEventID);
			CvPlot *pPlot = kInfo.getPlot();
			if (kInfo.getUnit(BATTLE_UNIT_ATTACKER) && kInfo.getUnit(BATTLE_UNIT_DEFENDER) && pPlot)
			{
				pPlot->AddArchaeologicalRecord(CvTypes::getARTIFACT_BATTLE_RANGED(), kInfo.getUnit(BATTLE_UNIT_ATTACKER)->getOwner(), kInfo.getUnit(BATTLE_UNIT_DEFENDER)->getOwner());
			}
		}
		else if (kInfo.getCity(BATTLE_UNIT_DEFENDER))
		{
			ResolveRangedCityVsCityCombat(kInfo, uiParentEventID);
		}
		else
		{
			ResolveRangedCityVsUnitCombat(kInfo, uiParentEventID);
			CvPlot *pPlot = kInfo.getPlot();
			if (kInfo.getCity(BATTLE_UNIT_ATTACKER) && kInfo.getUnit(BATTLE_UNIT_DEFENDER) && pPlot)
			{
				pPlot->AddArchaeologicalRecord(CvTypes::getARTIFACT_BATTLE_RANGED(), kInfo.getCity(BATTLE_UNIT_ATTACKER)->getOwner(), kInfo.getUnit(BATTLE_UNIT_DEFENDER)->getOwner());
			}
		}
	}

	// Melee Attack
	else
	{
		if(kInfo.getCity(BATTLE_UNIT_DEFENDER))
		{
			ResolveCityMeleeCombat(kInfo, uiParentEventID);
		}
		else
		{
			ResolveMeleeCombat(kInfo, uiParentEventID);
			CvPlot *pPlot = kInfo.getPlot();
			if (kInfo.getUnit(BATTLE_UNIT_ATTACKER) && kInfo.getUnit(BATTLE_UNIT_DEFENDER) && pPlot)
			{
				pPlot->AddArchaeologicalRecord(CvTypes::getARTIFACT_BATTLE_MELEE(), kInfo.getUnit(BATTLE_UNIT_ATTACKER)->getOwner(), kInfo.getUnit(BATTLE_UNIT_DEFENDER)->getOwner());
			}
		}
	}

#ifdef LEKMOD_AIR_COMBAT_FEEDBACK
	// Without the combat animation (quick combat) nothing shows what an air strike or sweep did: float the damage numbers
	if((kInfo.getAttackIsBombingMission() || kInfo.getAttackIsAirSweep()) && !kInfo.getVisualizeCombat())
	{
		const float fDelay = GC.getPOST_COMBAT_TEXT_DELAY();
		CvPlot* pTargetPlot = GC.getMap().plot(iAirTargetX, iAirTargetY);
		CvString strText;

		// Damage dealt by the air unit (to the defending unit or city)
		const int iDealt = kInfo.getDamageInflicted(BATTLE_UNIT_ATTACKER);
		if(pTargetPlot && iDealt > 0 && pTargetPlot->isVisible(eActiveTeam))
		{
			strText.Format("[COLOR_NEGATIVE_TEXT]-%d[ENDCOLOR]", iDealt);
			GC.GetEngineUserInterface()->AddPopupText(pTargetPlot->getX(), pTargetPlot->getY(), strText, fDelay);
		}

		// Damage taken by the air unit (from the defender and from interception)
		const int iTaken = kInfo.getDamageInflicted(BATTLE_UNIT_DEFENDER) + kInfo.getDamageInflicted(BATTLE_UNIT_INTERCEPTOR);
		CvPlot* pAirPlot = GC.getMap().plot(iAirFeedbackX, iAirFeedbackY);
		if(pAirPlot && iTaken > 0 && pAirPlot->isVisible(eActiveTeam))
		{
			strText.Format("[COLOR_NEGATIVE_TEXT]-%d[ENDCOLOR]", iTaken);
			GC.GetEngineUserInterface()->AddPopupText(pAirPlot->getX(), pAirPlot->getY(), strText, fDelay);
		}
	}
#endif

	// Clear popup blocking after combat resolves
	if(eAttackingPlayer == GC.getGame().getActivePlayer())
	{
		GC.GetEngineUserInterface()->SetDontShowPopups(false);
	}
}

//	----------------------------------------------------------------------------
CvUnitCombat::ATTACK_RESULT CvUnitCombat::Attack(CvUnit& kAttacker, CvPlot& targetPlot, ATTACK_OPTION eOption)
{
	CvString strBuffer;

	//VALIDATE_OBJECT
	CvAssert(kAttacker.canMoveInto(targetPlot, CvUnit::MOVEFLAG_ATTACK | CvUnit::MOVEFLAG_PRETEND_CORRECT_EMBARK_STATE));
	CvAssert(kAttacker.getCombatTimer() == 0);

	CvUnitCombat::ATTACK_RESULT eResult = CvUnitCombat::ATTACK_ABORTED;

	CvAssert(kAttacker.getCombatTimer() == 0);
	//	CvAssert(pDefender != NULL);
	CvAssert(!kAttacker.isFighting());

	// Unit that attacks loses his Fort bonus
	kAttacker.setFortifyTurns(0);

	UnitHandle pDefender;
	pDefender = targetPlot.getBestDefender(NO_PLAYER, kAttacker.getOwner(), &kAttacker, true);

	// JAR - without pDefender, nothing in here is going to work, just crash
	if(!pDefender)
	{
		return eResult;
	}

	kAttacker.SetAutomateType(NO_AUTOMATE);
	pDefender->SetAutomateType(NO_AUTOMATE);

	// slewis - tutorial'd
	if(kAttacker.getOwner() == GC.getGame().getActivePlayer())
	{
		GC.getGame().SetEverAttackedTutorial(true);
	}
	// end tutorial'd

	// handle the Zulu special thrown spear first attack
	ATTACK_RESULT eFireSupportResult = ATTACK_ABORTED;
	if (kAttacker.isRangedSupportFire() && pDefender->IsCanDefend())
	{
		eFireSupportResult = AttackRanged(kAttacker, pDefender->getX(), pDefender->getY(), CvUnitCombat::ATTACK_OPTION_NO_DEFENSIVE_SUPPORT);
		if (pDefender->isDelayedDeath())
		{
			// Killed him, move to the plot if we can.
			if(targetPlot.getNumVisibleEnemyDefenders(&kAttacker) == 0)
			{
				if (kAttacker.UnitMove(&targetPlot, true, &kAttacker, true))
					kAttacker.finishMoves();	// Burn all the moves we have
			}
			return eFireSupportResult;
		}
	}

	CvCombatInfo kCombatInfo;
	kCombatInfo.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
	kCombatInfo.setUnit(BATTLE_UNIT_DEFENDER, pDefender.pointer());
	kCombatInfo.setPlot(&targetPlot);
	GenerateMeleeCombatInfo(&kCombatInfo);

	CvAssertMsg(!kAttacker.isDelayedDeath() && !pDefender->isDelayedDeath(), "Trying to battle and one of the units is already dead!");

#ifdef AUI_UNIT_FIX_NO_RETREAT_ON_CIVILIAN_GUARD
	if (pDefender->getExtraWithdrawal() > 0 && pDefender->CanWithdrawFromMelee(kAttacker, &kCombatInfo))
#else
	if(pDefender->getExtraWithdrawal() > 0 && pDefender->CanWithdrawFromMelee(kAttacker))
#endif
	{
		pDefender->DoWithdrawFromMelee(kAttacker);

		if(kAttacker.getOwner() == GC.getGame().getActivePlayer())
		{
			strBuffer = GetLocalizedText("TXT_KEY_MISC_ENEMY_UNIT_WITHDREW", pDefender->getNameKey());
			GC.GetEngineUserInterface()->AddMessage(0, kAttacker.getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer);
		}
		else if(pDefender->getOwner() == GC.getGame().getActivePlayer())
		{
			strBuffer = GetLocalizedText("TXT_KEY_MISC_FRIENDLY_UNIT_WITHDREW", pDefender->getNameKey());
			GC.GetEngineUserInterface()->AddMessage(0, pDefender->getOwner(), true, GC.getEVENT_MESSAGE_TIME(), strBuffer);
		}

		// Move forward
		if(targetPlot.getNumVisibleEnemyDefenders(&kAttacker) == 0)
		{
			kAttacker.UnitMove(&targetPlot, true, &kAttacker);
		}

//		kAttacker.setMadeAttack(true);   /* EFB: Doesn't work, causes tactical AI to not dequeue this attack; but we've decided you don't lose your attack anyway */
		eResult = ATTACK_COMPLETED;
	}

	else if(!pDefender->IsCanDefend())
	{
		CvMissionDefinition kMission;
		kMission.setMissionTime(kAttacker.getCombatTimer() * gDLL->getSecsPerTurn());
		kMission.setMissionType(CvTypes::getMISSION_SURRENDER());
		kMission.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
		kMission.setUnit(BATTLE_UNIT_DEFENDER, pDefender.pointer());
		kMission.setPlot(&targetPlot);

		// Surrender mission
		CvMissionInfo* pkSurrenderMission = GC.getMissionInfo(CvTypes::getMISSION_SURRENDER());
		if(pkSurrenderMission == NULL)
		{
			CvAssert(false);
		}
		else
		{
			kAttacker.setCombatTimer(pkSurrenderMission->getTime());
		}

		// Kill them!
		pDefender->setDamage(GC.getMAX_HIT_POINTS());

		Localization::String strMessage;
		Localization::String strSummary;

		// Some units can't capture civilians. Embarked units are also not captured, they're simply killed. And some aren't a type that gets captured.
		if(!kAttacker.isNoCapture() && (!pDefender->isEmbarked() || pDefender->getUnitInfo().IsCaptureWhileEmbarked()) && pDefender->getCaptureUnitType(GET_PLAYER(pDefender->getOwner()).getCivilizationType()) != NO_UNIT)
		{
			pDefender->setCapturingPlayer(kAttacker.getOwner());

			if(kAttacker.isBarbarian())
			{
				strMessage = Localization::Lookup("TXT_KEY_UNIT_CAPTURED_BARBS_DETAILED");
				strMessage << pDefender->getUnitInfo().GetTextKey() << GET_PLAYER(kAttacker.getOwner()).getNameKey();
				strSummary = Localization::Lookup("TXT_KEY_UNIT_CAPTURED_BARBS");
			}
			else
			{
				strMessage = Localization::Lookup("TXT_KEY_UNIT_CAPTURED_DETAILED");
				strMessage << pDefender->getUnitInfo().GetTextKey();
				strSummary = Localization::Lookup("TXT_KEY_UNIT_CAPTURED");
			}
		}
		// Unit was killed instead
		else
		{
			strMessage = Localization::Lookup("TXT_KEY_UNIT_LOST");
			strSummary = strMessage;
		}

		CvNotifications* pNotification = GET_PLAYER(pDefender->getOwner()).GetNotifications();
		if(pNotification)
			pNotification->Add(NOTIFICATION_UNIT_DIED, strMessage.toUTF8(), strSummary.toUTF8(), pDefender->getX(), pDefender->getY(), (int) pDefender->getUnitType(), pDefender->getOwner());

		bool bAdvance;
		bAdvance = kAttacker.canAdvance(targetPlot, ((pDefender->IsCanDefend()) ? 1 : 0));

		// Move forward
		if(targetPlot.getNumVisibleEnemyDefenders(&kAttacker) == 0)
		{
			kAttacker.UnitMove(&targetPlot, true, ((bAdvance) ? &kAttacker : NULL));
		}

		// KWG: Should this be called? The defender is killed above and the unit.
		//      If anything, the above code should be put in the ResolveCombat method.
		ResolveCombat(kCombatInfo);
		eResult = ATTACK_COMPLETED;
	}
	else
	{
		ATTACK_RESULT eSupportResult = ATTACK_ABORTED;
		if(eOption != ATTACK_OPTION_NO_DEFENSIVE_SUPPORT)
		{
			// Ranged fire support from artillery units
			CvUnit* pFireSupportUnit = GetFireSupportUnit(pDefender->getOwner(), pDefender->getX(), pDefender->getY(), kAttacker.getX(), kAttacker.getY());
			if(pFireSupportUnit != NULL)
			{
				CvAssertMsg(!pFireSupportUnit->isDelayedDeath(), "Supporting battle unit is already dead!");
				eSupportResult = AttackRanged(*pFireSupportUnit, kAttacker.getX(), kAttacker.getY(), CvUnitCombat::ATTACK_OPTION_NO_DEFENSIVE_SUPPORT);
				// Turn off Fortify Turns, as this is the trigger for whether or not a ranged Unit can provide support fire (in addition to hasMadeAttack)
				pFireSupportUnit->setFortifyTurns(0);
			}

			if(eSupportResult == ATTACK_QUEUED)
			{
				// The supporting unit has queued their attack (against the attacker), we must have the attacker queue its attack.
				// Also, flag the current mission that the next time through, the defender doesn't get any defensive support.
				const_cast<MissionData*>(kAttacker.GetHeadMissionData())->iFlags |= MISSION_MODIFIER_NO_DEFENSIVE_SUPPORT;
				CvUnitMission::WaitFor(&kAttacker, pFireSupportUnit);
				eResult = ATTACK_QUEUED;
			}
		}

		if(eResult != ATTACK_QUEUED)
		{
			kAttacker.setMadeAttack(true);

			uint uiParentEventID = 0;
			// Send the combat message if the target plot is visible.
			bool isTargetVisibleToActivePlayer = targetPlot.isActiveVisible(false);
			bool quickCombat = CvPreGame::quickCombat();
			if(!quickCombat)
			{
				// Center camera here!
				if(isTargetVisibleToActivePlayer)
				{
					auto_ptr<ICvPlot1> pDefenderPlot = GC.WrapPlotPointer(pDefender->plot());
					GC.GetEngineUserInterface()->lookAt(pDefenderPlot.get(), CAMERALOOKAT_NORMAL);
				}
				kCombatInfo.setVisualizeCombat(isTargetVisibleToActivePlayer);

				auto_ptr<ICvCombatInfo1> pDllCombatInfo(new CvDllCombatInfo(&kCombatInfo));
				uiParentEventID = gDLL->GameplayUnitCombat(pDllCombatInfo.get());

				// Set the combat units so that other missions do not continue until combat is over.
				kAttacker.setCombatUnit(pDefender.pointer(), true);
				pDefender->setCombatUnit(&kAttacker, false);

				eResult = ATTACK_QUEUED;
			}
			else
				eResult = ATTACK_COMPLETED;

			// Resolve combat here.
			ResolveCombat(kCombatInfo, uiParentEventID);

		}
	}

	return eResult;
}

//	---------------------------------------------------------------------------
CvUnitCombat::ATTACK_RESULT CvUnitCombat::AttackRanged(CvUnit& kAttacker, int iX, int iY, CvUnitCombat::ATTACK_OPTION /* eOption */)
{
	//VALIDATE_OBJECT
	CvPlot* pPlot = GC.getMap().plot(iX, iY);
	ATTACK_RESULT eResult = ATTACK_ABORTED;

	CvAssertMsg(kAttacker.getDomainType() != DOMAIN_AIR, "Air units should not use AttackRanged, they should just MoveTo the target");

	if(NULL == pPlot)
	{
		return eResult;
	}

	if (!kAttacker.isRangedSupportFire())
	{
		if(!kAttacker.canRangeStrikeAt(iX, iY))
		{
			return eResult;
		}

		if(GC.getRANGED_ATTACKS_USE_MOVES() == 0)
		{
			kAttacker.setMadeAttack(true);
		}
		kAttacker.changeMoves(-GC.getMOVE_DENOMINATOR());
	}

	// Unit that attacks loses his Fort bonus
	kAttacker.setFortifyTurns(0);

	// New test feature - attacking/range striking uses up all moves for most Units
#ifdef NQ_UNIT_TURN_ENDS_ON_FINAL_ATTACK
	if(!kAttacker.canMoveAfterAttacking() && !kAttacker.isRangedSupportFire() && kAttacker.isOutOfAttacks())
#else
	if(!kAttacker.canMoveAfterAttacking() && !kAttacker.isRangedSupportFire())
#endif
	{
		kAttacker.finishMoves();
		GC.GetEngineUserInterface()->changeCycleSelectionCounter(1);
	}

	kAttacker.SetAutomateType(NO_AUTOMATE);

	bool bDoImmediate = CvPreGame::quickCombat();
	// Range-striking a Unit
	if(!pPlot->isCity())
	{
		CvUnit* pDefender = kAttacker.airStrikeTarget(*pPlot, true);
		CvAssert(pDefender != NULL);
		if(!pDefender) return ATTACK_ABORTED;

		pDefender->SetAutomateType(NO_AUTOMATE);

		CvCombatInfo kCombatInfo;
		kCombatInfo.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
		kCombatInfo.setUnit(BATTLE_UNIT_DEFENDER, pDefender);
		kCombatInfo.setPlot(pPlot);
		GenerateRangedCombatInfo(&kCombatInfo);
		CvAssertMsg(!kAttacker.isDelayedDeath() && !pDefender->isDelayedDeath(), "Trying to battle and one of the units is already dead!");

		uint uiParentEventID = 0;
		if(!bDoImmediate)
		{
			// Center camera here!
			bool isTargetVisibleToActivePlayer = pPlot->isActiveVisible(false);
			if(isTargetVisibleToActivePlayer)
			{
				auto_ptr<ICvPlot1> pDllPlot = GC.WrapPlotPointer(pPlot);
				GC.GetEngineUserInterface()->lookAt(pDllPlot.get(), CAMERALOOKAT_NORMAL);
			}
			kCombatInfo.setVisualizeCombat(isTargetVisibleToActivePlayer);

			auto_ptr<ICvCombatInfo1> pDllCombatInfo(new CvDllCombatInfo(&kCombatInfo));
			uiParentEventID = gDLL->GameplayUnitCombat(pDllCombatInfo.get());

			// Set the combat units so that other missions do not continue until combat is over.
			kAttacker.setCombatUnit(pDefender, true);
			pDefender->setCombatUnit(&kAttacker, false);
			eResult = ATTACK_QUEUED;
		}
		else
			eResult = ATTACK_COMPLETED;

		ResolveCombat(kCombatInfo, uiParentEventID);
	}
	// Range-striking a City
	else
	{
		if (kAttacker.isRangedSupportFire())
		{
			return eResult;
		}

		CvCombatInfo kCombatInfo;
		kCombatInfo.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
		kCombatInfo.setCity(BATTLE_UNIT_DEFENDER, pPlot->getPlotCity());
		kCombatInfo.setPlot(pPlot);
		GenerateRangedCombatInfo(&kCombatInfo);
		CvAssertMsg(!kAttacker.isDelayedDeath(), "Trying to battle and the attacker is already dead!");

		uint uiParentEventID = 0;
		if(!bDoImmediate)
		{
			// Center camera here!
			bool isTargetVisibleToActivePlayer = pPlot->isActiveVisible(false);
			if(isTargetVisibleToActivePlayer)
			{
				auto_ptr<ICvPlot1> pDllPlot = GC.WrapPlotPointer(pPlot);
				GC.GetEngineUserInterface()->lookAt(pDllPlot.get(), CAMERALOOKAT_NORMAL);
			}

			kCombatInfo.setVisualizeCombat(isTargetVisibleToActivePlayer);

			auto_ptr<ICvCombatInfo1> pDllCombatInfo(new CvDllCombatInfo(&kCombatInfo));
			uiParentEventID = gDLL->GameplayCityCombat(pDllCombatInfo.get());

			CvCity* pkDefender = pPlot->getPlotCity();
			kAttacker.setCombatCity(pkDefender);
			if(pkDefender)
				pkDefender->setCombatUnit(&kAttacker);
			eResult = ATTACK_QUEUED;
		}
		else
			eResult = ATTACK_COMPLETED;

		ResolveCombat(kCombatInfo, uiParentEventID);
	}

	return eResult;
}

//	----------------------------------------------------------------------------
CvUnitCombat::ATTACK_RESULT CvUnitCombat::AttackAir(CvUnit& kAttacker, CvPlot& targetPlot, ATTACK_OPTION /* eOption */)
{
	//VALIDATE_OBJECT
	CvAssert(kAttacker.getCombatTimer() == 0);

	CvUnitCombat::ATTACK_RESULT eResult = CvUnitCombat::ATTACK_ABORTED;

	// Can we actually hit the target?
	if(!kAttacker.canRangeStrikeAt(targetPlot.getX(), targetPlot.getY()))
	{
		return eResult;
	}

	bool bDoImmediate = CvPreGame::quickCombat();
	kAttacker.SetAutomateType(NO_AUTOMATE);
	kAttacker.setMadeAttack(true);

	// Bombing a Unit
	if(!targetPlot.isCity())
	{
		CvUnit* pDefender = kAttacker.airStrikeTarget(targetPlot, true);
		CvAssert(pDefender != NULL);
		if(!pDefender) return CvUnitCombat::ATTACK_ABORTED;

		pDefender->SetAutomateType(NO_AUTOMATE);

		CvCombatInfo kCombatInfo;
		kCombatInfo.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
		kCombatInfo.setUnit(BATTLE_UNIT_DEFENDER, pDefender);
		kCombatInfo.setPlot(&targetPlot);
		CvUnitCombat::GenerateAirCombatInfo(&kCombatInfo);
		CvAssertMsg(!kAttacker.isDelayedDeath() && !pDefender->isDelayedDeath(), "Trying to battle and one of the units is already dead!");

		uint uiParentEventID = 0;
		if(!bDoImmediate)
		{
			// Center camera here!
			bool isTargetVisibleToActivePlayer = targetPlot.isActiveVisible(false);
			if(isTargetVisibleToActivePlayer)
			{
				auto_ptr<ICvPlot1> pDllTargetPlot = GC.WrapPlotPointer(&targetPlot);
				GC.GetEngineUserInterface()->lookAt(pDllTargetPlot.get(), CAMERALOOKAT_NORMAL);
			}
			kCombatInfo.setVisualizeCombat(isTargetVisibleToActivePlayer);

			auto_ptr<ICvCombatInfo1> pDllCombatInfo(new CvDllCombatInfo(&kCombatInfo));
			uiParentEventID = gDLL->GameplayUnitCombat(pDllCombatInfo.get());

			// Set the combat units so that other missions do not continue until combat is over.
			kAttacker.setCombatUnit(pDefender, true);
			pDefender->setCombatUnit(&kAttacker, false);
			CvUnit* pDefenderSupport = kCombatInfo.getUnit(BATTLE_UNIT_INTERCEPTOR);
			if(pDefenderSupport)
				pDefenderSupport->setCombatUnit(&kAttacker, false);

			eResult = ATTACK_QUEUED;
		}
		else
			eResult = ATTACK_COMPLETED;

		ResolveCombat(kCombatInfo, uiParentEventID);
	}
	// Bombing a City
	else
	{
		CvCombatInfo kCombatInfo;
		kCombatInfo.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
		kCombatInfo.setCity(BATTLE_UNIT_DEFENDER, targetPlot.getPlotCity());
		kCombatInfo.setPlot(&targetPlot);
		GenerateAirCombatInfo(&kCombatInfo);
		CvAssertMsg(!kAttacker.isDelayedDeath(), "Trying to battle and the attacker is already dead!");

		uint uiParentEventID = 0;
		if(!bDoImmediate)
		{
			// Center camera here!
			bool isTargetVisibleToActivePlayer = targetPlot.isActiveVisible(false);
			if(isTargetVisibleToActivePlayer)
			{
				auto_ptr<ICvPlot1> pDllTargetPlot = GC.WrapPlotPointer(&targetPlot);
				GC.GetEngineUserInterface()->lookAt(pDllTargetPlot.get(), CAMERALOOKAT_NORMAL);
			}

			kCombatInfo.setVisualizeCombat(isTargetVisibleToActivePlayer);
			auto_ptr<ICvCombatInfo1> pDllCombatInfo(new CvDllCombatInfo(&kCombatInfo));
			uiParentEventID = gDLL->GameplayCityCombat(pDllCombatInfo.get());

			CvCity* pkDefender = targetPlot.getPlotCity();
			kAttacker.setCombatCity(pkDefender);
			if(pkDefender)
				pkDefender->setCombatUnit(&kAttacker);
			CvUnit* pDefenderSupport = kCombatInfo.getUnit(BATTLE_UNIT_INTERCEPTOR);
			if(pDefenderSupport)
				pDefenderSupport->setCombatUnit(&kAttacker, false);
			eResult = ATTACK_QUEUED;
		}
		else
			eResult = ATTACK_COMPLETED;

		ResolveCombat(kCombatInfo, uiParentEventID);
	}

	return eResult;
}

//	----------------------------------------------------------------------------
CvUnitCombat::ATTACK_RESULT CvUnitCombat::AttackAirSweep(CvUnit& kAttacker, CvPlot& targetPlot, ATTACK_OPTION /* eOption */)
{
	//VALIDATE_OBJECT
	CvAssert(kAttacker.getCombatTimer() == 0);

	CvUnitCombat::ATTACK_RESULT eResult = CvUnitCombat::ATTACK_ABORTED;

	// Can we actually hit the target?
	if(!kAttacker.canAirSweepAt(targetPlot.getX(), targetPlot.getY()))
	{
		return eResult;
	}

	CvUnit* pInterceptor = kAttacker.GetBestInterceptor(targetPlot);
	kAttacker.SetAutomateType(NO_AUTOMATE);

	// Any interceptor to sweep for?
	if(pInterceptor != NULL)
	{
		kAttacker.setMadeAttack(true);
		CvCombatInfo kCombatInfo;
		kCombatInfo.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
		kCombatInfo.setUnit(BATTLE_UNIT_DEFENDER, pInterceptor); // Interceptor is the defender in this Sweeps
		kCombatInfo.setPlot(&targetPlot);
		CvUnitCombat::GenerateAirSweepCombatInfo(&kCombatInfo);
		CvUnit* pkDefender = kCombatInfo.getUnit(BATTLE_UNIT_DEFENDER);
		pkDefender->SetAutomateType(NO_AUTOMATE);
		CvAssertMsg(!kAttacker.isDelayedDeath() && !pkDefender->isDelayedDeath(), "Trying to battle and one of the units is already dead!");

		uint uiParentEventID = 0;
		bool bDoImmediate = CvPreGame::quickCombat();
		if(!bDoImmediate)
		{
			// Center camera here!
			bool isTargetVisibleToActivePlayer = targetPlot.isActiveVisible(false);
			if(isTargetVisibleToActivePlayer)
			{
				auto_ptr<ICvPlot1> pDllTargetPlot = GC.WrapPlotPointer(&targetPlot);
				GC.GetEngineUserInterface()->lookAt(pDllTargetPlot.get(), CAMERALOOKAT_NORMAL);
			}
			kCombatInfo.setVisualizeCombat(isTargetVisibleToActivePlayer);

			auto_ptr<ICvCombatInfo1> pDllCombatInfo(new CvDllCombatInfo(&kCombatInfo));
			uiParentEventID = gDLL->GameplayUnitCombat(pDllCombatInfo.get());

			// Set the combat units so that other missions do not continue until combat is over.
			kAttacker.setCombatUnit(pInterceptor, true);
			pInterceptor->setCombatUnit(&kAttacker, false);
			eResult = ATTACK_QUEUED;
		}
		else
			eResult = ATTACK_COMPLETED;

		ResolveCombat(kCombatInfo, uiParentEventID);
	}
	else
	{
		// attempted to do a sweep in a plot that had no interceptors
		// consume the movement and finish its moves
		if(kAttacker.getOwner() == GC.getGame().getActivePlayer())
		{
			Localization::String localizedText = Localization::Lookup("TXT_KEY_AIR_PATROL_FOUND_NOTHING");
			localizedText << kAttacker.getUnitInfo().GetTextKey();
			GC.GetEngineUserInterface()->AddMessage(0, kAttacker.getOwner(), false, GC.getEVENT_MESSAGE_TIME(), localizedText.toUTF8());
#ifdef LEKMOD_AIR_COMBAT_FEEDBACK
			// Show it on the map too
			GC.GetEngineUserInterface()->AddPopupText(targetPlot.getX(), targetPlot.getY(), GetLocalizedText("TXT_KEY_LEKMOD_AIR_SWEEP_NO_RESISTANCE"), 0.0f);
#endif
		}

		// Spend a move for this attack
		kAttacker.changeMoves(-GC.getMOVE_DENOMINATOR());

		// Can't move or attack again
#ifdef NQ_UNIT_TURN_ENDS_ON_FINAL_ATTACK
		if(!kAttacker.canMoveAfterAttacking() && kAttacker.isOutOfAttacks())
#else
		if(!kAttacker.canMoveAfterAttacking())
#endif
		{
			kAttacker.finishMoves();
		}
	}

	return eResult;
}

//	---------------------------------------------------------------------------
CvUnitCombat::ATTACK_RESULT CvUnitCombat::AttackCity(CvUnit& kAttacker, CvPlot& plot, CvUnitCombat::ATTACK_OPTION eOption)
{
	//VALIDATE_OBJECT

	ATTACK_RESULT eResult = ATTACK_ABORTED;
	CvCity* pCity = plot.getPlotCity();
	CvAssertMsg(pCity != NULL, "If this unit is attacking a NULL city then something funky is goin' down");
	if(!pCity) return eResult;

	kAttacker.SetAutomateType(NO_AUTOMATE);

	if(eOption != ATTACK_OPTION_NO_DEFENSIVE_SUPPORT)
	{
		// See if the city has some supporting fire to fend off the attacker
		CvUnit* pFireSupportUnit = GetFireSupportUnit(pCity->getOwner(), pCity->getX(), pCity->getY(), kAttacker.getX(), kAttacker.getY());

		ATTACK_RESULT eSupportResult = ATTACK_ABORTED;
		if(pFireSupportUnit)
		{
			eSupportResult = AttackRanged(*pFireSupportUnit, kAttacker.getX(), kAttacker.getY(), CvUnitCombat::ATTACK_OPTION_NO_DEFENSIVE_SUPPORT);
			// Turn off Fortify Turns, as this is the trigger for whether or not a ranged Unit can provide support fire (in addition to hasMadeAttack)
			pFireSupportUnit->setFortifyTurns(0);
		}

		if(eSupportResult == ATTACK_QUEUED)
		{
			// The supporting unit has queued their attack (against the attacker), we must have the attacker queue its attack.
			// Also, flag the current mission that the next time through, the defender doesn't get any defensive support.
			const_cast<MissionData*>(kAttacker.GetHeadMissionData())->iFlags |= MISSION_MODIFIER_NO_DEFENSIVE_SUPPORT;
			CvUnitMission::WaitFor(&kAttacker, pFireSupportUnit);
			eResult = ATTACK_QUEUED;
		}
	}

	if(eResult != ATTACK_QUEUED)
	{
		kAttacker.setMadeAttack(true);

		// We are doing a non-ranged attack on a city
		CvCombatInfo kCombatInfo;
		kCombatInfo.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
		kCombatInfo.setCity(BATTLE_UNIT_DEFENDER, pCity);
		kCombatInfo.setPlot(&plot);
		GenerateMeleeCombatInfo(&kCombatInfo);
		CvAssertMsg(!kAttacker.isDelayedDeath(), "Trying to battle and the attacker is already dead!");

		// Send the combat message if the target plot is visible.
		bool isTargetVisibleToActivePlayer = plot.isActiveVisible(false);

		uint uiParentEventID = 0;
		bool bDoImmediate = CvPreGame::quickCombat();
		if(!bDoImmediate)
		{
			// Center camera here!
			if(isTargetVisibleToActivePlayer)
			{
				auto_ptr<ICvPlot1> pDllPlot = GC.WrapPlotPointer(&plot);
				GC.GetEngineUserInterface()->lookAt(pDllPlot.get(), CAMERALOOKAT_NORMAL);
			}
			kCombatInfo.setVisualizeCombat(isTargetVisibleToActivePlayer);

			auto_ptr<ICvCombatInfo1> pDllCombatInfo(new CvDllCombatInfo(&kCombatInfo));
			uiParentEventID = gDLL->GameplayCityCombat(pDllCombatInfo.get());

			CvCity* pkDefender = plot.getPlotCity();
			kAttacker.setCombatCity(pkDefender);
			if(pkDefender)
				pkDefender->setCombatUnit(&kAttacker);
			eResult = ATTACK_QUEUED;
		}
		else
			eResult = ATTACK_COMPLETED;

		ResolveCombat(kCombatInfo, uiParentEventID);
	}
	return eResult;
}

//	-------------------------------------------------------------------------------------------
//	Return a ranged unit that will defend the supplied location against the attacker at the specified location.
CvUnit* CvUnitCombat::GetFireSupportUnit(PlayerTypes eDefender, int iDefendX, int iDefendY, int iAttackX, int iAttackY)
{
	VALIDATE_OBJECT

	if(GC.getFIRE_SUPPORT_DISABLED() == 1)
		return NULL;

	CvPlot* pAdjacentPlot = NULL;
	CvPlot* pPlot = GC.getMap().plot(iDefendX, iDefendY);

	for(int iI = 0; iI < NUM_DIRECTION_TYPES; iI++)
	{
		pAdjacentPlot = plotDirection(pPlot->getX(), pPlot->getY(), ((DirectionTypes)iI));

		if(pAdjacentPlot != NULL)
		{
#ifdef AUI_WARNING_FIXES
			for (uint iUnitLoop = 0; iUnitLoop < pAdjacentPlot->getNumUnits(); iUnitLoop++)
#else
			for(int iUnitLoop = 0; iUnitLoop < pAdjacentPlot->getNumUnits(); iUnitLoop++)
#endif
			{
				CvUnit* pLoopUnit = pAdjacentPlot->getUnitByIndex(iUnitLoop);

				// Unit owned by same player?
				if(pLoopUnit->getOwner() == eDefender)
				{
					// Can this unit perform a ranged strike on the attacker's plot?
					if(pLoopUnit->canRangeStrikeAt(iAttackX, iAttackY))
					{
						// Range strike would be calculated here, so get the estimated damage
						return pLoopUnit;
					}
				}
			}
		}
	}

	return NULL;
}

//	----------------------------------------------------------------------------
CvUnitCombat::ATTACK_RESULT CvUnitCombat::AttackNuclear(CvUnit& kAttacker, int iX, int iY, ATTACK_OPTION /* eOption */)
{
	ATTACK_RESULT eResult = ATTACK_ABORTED;

#ifdef LEKMOD_CONGRESS_CYCLE
	// Non-Proliferation: launching a nuke declares war on every met civilization and City-State, except your City-State allies
	if (GC.getMap().plot(iX, iY) != NULL && GC.getGame().GetGameLeagues()->LekmodSumActive(LRC_NUKE_COST) > 0 && !GC.getGame().isOption(GAMEOPTION_ALWAYS_PEACE))
	{
		CvTeam& kAttackerTeam = GET_TEAM(kAttacker.getTeam());
		for (int iPlayer = 0; iPlayer < MAX_CIV_PLAYERS; iPlayer++)
		{
			CvPlayer& kOther = GET_PLAYER((PlayerTypes)iPlayer);
			const TeamTypes eOtherTeam = kOther.getTeam();
			if (!kOther.isAlive() || eOtherTeam == kAttacker.getTeam() || kAttackerTeam.isAtWar(eOtherTeam) || !kAttackerTeam.isHasMet(eOtherTeam))
				continue;
			if (kOther.isMinorCiv() && kOther.GetMinorCivAI()->IsAllies(kAttacker.getOwner()))
				continue;
			kAttackerTeam.declareWar(eOtherTeam);
		}
	}
#endif
	CvPlot* pPlot = GC.getMap().plot(iX, iY);
	if(NULL == pPlot)
		return eResult;

	bool bDoImmediate = CvPreGame::quickCombat();
	CvCombatInfo kCombatInfo;
	kCombatInfo.setUnit(BATTLE_UNIT_ATTACKER, &kAttacker);
	kCombatInfo.setPlot(pPlot);
	CvUnitCombat::GenerateNuclearCombatInfo(&kCombatInfo);
	CvAssertMsg(!kAttacker.isDelayedDeath(), "Trying to battle and the attacker is already dead!");
	kAttacker.setMadeAttack(true);
	uint uiParentEventID = 0;
	if(!bDoImmediate)
	{
		// Nuclear attacks are different in that you can target a plot you can't see, so check to see if the active player
		// is involved in the combat
		TeamTypes eActiveTeam = GC.getGame().getActiveTeam();

		bool isTargetVisibleToActivePlayer = pPlot->isActiveVisible(false);
		if(!isTargetVisibleToActivePlayer)
		{
			// Is the attacker part of the local team?
			isTargetVisibleToActivePlayer = (kAttacker.getTeam() != NO_TEAM && eActiveTeam == kAttacker.getTeam());

			if(!isTargetVisibleToActivePlayer)
			{
				// Are any of the teams effected by the blast in the local team?
				for(int i = 0; i < MAX_TEAMS && !isTargetVisibleToActivePlayer; ++i)
				{
					if(kAttacker.isNukeVictim(pPlot, ((TeamTypes)i)))
					{
						isTargetVisibleToActivePlayer = eActiveTeam == ((TeamTypes)i);
					}
				}
			}
		}

		if(isTargetVisibleToActivePlayer)
		{
			auto_ptr<ICvPlot1> pDllPlot = GC.WrapPlotPointer(pPlot);
			GC.GetEngineUserInterface()->lookAt(pDllPlot.get(), CAMERALOOKAT_NORMAL);
		}
		kCombatInfo.setVisualizeCombat(isTargetVisibleToActivePlayer);

		// Set a combat unit/city.  Not really needed for the combat since we are killing everyone, but it is currently the only way a unit is marked that it is 'in-combat'
		if(pPlot->getPlotCity())
			kAttacker.setCombatCity(pPlot->getPlotCity());
		else
		{
			if(pPlot->getNumUnits())
				kAttacker.setCombatUnit(pPlot->getUnitByIndex(0), true);
			else
				kAttacker.setAttackPlot(pPlot, false);
		}

		auto_ptr<ICvCombatInfo1> pDllCombatInfo(new CvDllCombatInfo(&kCombatInfo));
		uiParentEventID = gDLL->GameplayUnitCombat(pDllCombatInfo.get());

		eResult = ATTACK_QUEUED;
	}
	else
	{
		eResult = ATTACK_COMPLETED;
		// Set the plot, just so the unit is marked as 'in-combat'
		kAttacker.setAttackPlot(pPlot, false);
	}

	ResolveCombat(kCombatInfo,  uiParentEventID);

	return eResult;
}

//	---------------------------------------------------------------------------
void CvUnitCombat::ApplyPostCombatTraitEffects(CvUnit* pkWinner, CvUnit* pkLoser)
{
	int iExistingDelay = 0;

#if defined(v35_TRAITIFY)
	if (!pkWinner->killedUnit())
	{
		pkWinner->setKilledUnit(true);
		if (pkWinner->IsKillRefreshMoves())
		{
			pkWinner->setMoves(pkWinner->maxMoves() + GC.getMOVE_DENOMINATOR());
		}
		if (pkWinner->IsKillRefreshAttacks())
		{
			pkWinner->setMadeAttack(false);
		}
	}
#endif

#ifdef LEKMOD_CIV_PROMOTION_EFFECTS
	// Mandekalu Cavalry: extra movement after a kill
	if (pkWinner->GetLekmodMovesAfterKill() > 0)
	{
		pkWinner->changeMoves(pkWinner->GetLekmodMovesAfterKill() * GC.getMOVE_DENOMINATOR());
	}
#endif
	// "Heal if defeat enemy" promotion; doesn't apply if defeat a barbarian
	if(pkWinner->getHPHealedIfDefeatEnemy() > 0 && (pkLoser->getOwner() != BARBARIAN_PLAYER || !(pkWinner->IsHealIfDefeatExcludeBarbarians())))
	{
		if(pkWinner->getHPHealedIfDefeatEnemy() > pkWinner->getDamage())
		{
			pkWinner->changeDamage(-pkWinner->getDamage());
		}
		else
		{
			pkWinner->changeDamage(-pkWinner->getHPHealedIfDefeatEnemy());
		}
	}

	CvPlayer& kPlayer = GET_PLAYER(pkWinner->getOwner());
	// Moved the old Promotion for GAP, as its now being hooked up with all the rest, if v34 is not defined then FULL_YIELD_FROM_KILLS does not support GAP from Kills
#if !defined(FULL_YIELD_FROM_KILLS) || !defined(LEKMOD_v34)
	if (pkWinner->GetGoldenAgeValueFromKills() > 0)
	{
		int iCombatStrength = max(pkLoser->getUnitInfo().GetCombat(), pkLoser->getUnitInfo().GetRangedCombat());
		if (iCombatStrength > 0)
		{
			int iValue = iCombatStrength * pkWinner->GetGoldenAgeValueFromKills() / 100;
			kPlayer.ChangeGoldenAgeProgressMeter(iValue);

			CvString yieldString = "[COLOR_WHITE]+%d[ENDCOLOR][ICON_GOLDEN_AGE]";

			if (pkWinner->getOwner() == GC.getGame().getActivePlayer())
			{
				char text[256] = { 0 };
				float fDelay = GC.getPOST_COMBAT_TEXT_DELAY() * 1.5f;
				sprintf_s(text, yieldString, iValue);
				GC.GetEngineUserInterface()->AddPopupText(pkLoser->getX(), pkLoser->getY(), text, fDelay);

				iExistingDelay++;
			}
		}
	}
#endif
	// Earn bonuses for kills?
#if !defined(FULL_YIELD_FROM_KILLS)
	kPlayer.DoYieldsFromKill(pkWinner->getUnitType(), pkLoser->getUnitType(), pkLoser->getX(), pkLoser->getY(), pkLoser->isBarbarian(), iExistingDelay);
#else
	// This now directly passes the Unit Pointers into the function chain so the Yield From Kills can be given from promotions
	kPlayer.DoYieldsFromKill(pkWinner, pkLoser, pkLoser->getX(), pkLoser->getY(), pkLoser->isBarbarian(), iExistingDelay);
#endif

	//Achievements and Stats
	if(pkWinner->isHuman() && !GC.getGame().isGameMultiPlayer())
	{
		CvString szUnitType;
		CvUnitEntry* pkUnitInfo = GC.getUnitInfo(pkWinner->getUnitType());
		if(pkUnitInfo)
			szUnitType = pkUnitInfo->GetType();

		//Elizabeth Special Achievement
		if((CvString)kPlayer.getLeaderTypeKey() == "LEADER_ELIZABETH" && pkLoser->getDomainType() == DOMAIN_SEA)
		{
			gDLL->IncrementSteamStatAndUnlock(ESTEAMSTAT_BRITISHNAVY, 357, ACHIEVEMENT_SPECIAL_ARMADA);
		}
		//Ramkang's Special Achievement
		if(szUnitType == "UNIT_SIAMESE_WARELEPHANT")
		{
			//CvString szUnitTypeLoser = (CvString) GC.getUnitInfo(pkLoser->getUnitType())->GetType();
		}

		//Oda's Special Achievement
		if((CvString)kPlayer.getLeaderTypeKey() == "LEADER_ODA_NOBUNAGA" && (pkWinner->GetMaxHitPoints() - pkWinner->getDamage() == 1))
		{
			gDLL->UnlockAchievement(ACHIEVEMENT_SPECIAL_KAMIKAZE);
		}
		//Napoleon's Special Achievement
		if(szUnitType == "UNIT_FRENCH_MUSKETEER")
		{
			if(pkLoser->GetNumSpecificEnemyUnitsAdjacent(pkLoser, pkWinner) >=3)
			{
				gDLL->UnlockAchievement(ACHIEVEMENT_SPECIAL_MUSKETEERS);
			}
		}

		//DLC_05 Sejong's Turtle Boat Achievement
		if(szUnitType == "UNIT_KOREAN_TURTLE_SHIP")
		{
			CvString szLoserUnitType;
			CvUnitEntry* pkLoserUnitInfo = GC.getUnitInfo(pkLoser->getUnitType());
			if(pkLoserUnitInfo)
			{
				szLoserUnitType = pkLoserUnitInfo->GetType();
			}
			if(szLoserUnitType == "UNIT_IRONCLAD")
			{
				gDLL->UnlockAchievement(ACHIEVEMENT_SPECIAL_IRONCLAD_TURTLE);
			}
		}

		//DLC_05 Sejong's Hwacha Achievement
		if(szUnitType == "UNIT_KOREAN_HWACHA")
		{
			gDLL->IncrementSteamStatAndUnlock(ESTEAMSTAT_HWACHAKILLS, 99, ACHIEVEMENT_SPECIAL_HWATCH_OUT);
		}

	}
}

void CvUnitCombat::ApplyPostCityCombatEffects(CvUnit* pkAttacker, CvCity* pkDefender, int iAttackerDamageInflicted)
{
	CvString colorString;
	int iPlunderModifier;
	float fDelay = GC.getPOST_COMBAT_TEXT_DELAY() * 3;
	iPlunderModifier = pkAttacker->GetCityAttackPlunderModifier();
	if(iPlunderModifier > 0)
	{
		int iGoldPlundered = iAttackerDamageInflicted * iPlunderModifier;
		iGoldPlundered /= 100;

		if(iGoldPlundered > 0)
		{
			GET_PLAYER(pkAttacker->getOwner()).GetTreasury()->ChangeGold(iGoldPlundered);

			CvPlayer& kCityPlayer = GET_PLAYER(pkDefender->getOwner());
			int iDeduction = min(iGoldPlundered, kCityPlayer.GetTreasury()->GetGold());
			kCityPlayer.GetTreasury()->ChangeGold(-iDeduction);

			if(pkAttacker->getOwner() == GC.getGame().getActivePlayer())
			{
				char text[256] = {0};
				colorString = "[COLOR_YELLOW]+%d[ENDCOLOR][ICON_GOLD]";
				sprintf_s(text, colorString, iGoldPlundered);
				GC.GetEngineUserInterface()->AddPopupText(pkAttacker->getX(), pkAttacker->getY(), text, fDelay);
			}
		}
	}
}
