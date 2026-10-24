/*	-------------------------------------------------------------------------------------------------------
	� 1991-2012 Take-Two Interactive Software and its subsidiaries.  Developed by Firaxis Games.  
	Sid Meier's Civilization V, Civ, Civilization, 2K Games, Firaxis Games, Take-Two Interactive Software 
	and their respective logos are all trademarks of Take-Two interactive Software, Inc.  
	All other marks and trademarks are the property of their respective owners.  
	All rights reserved. 
	------------------------------------------------------------------------------------------------------- */
#pragma once

#ifndef CIV5_PROMOTION_CLASSES_H
#define CIV5_PROMOTION_CLASSES_H

#include "CvBitfield.h"

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  CLASS:      CvPromotionEntry
//!  \brief		A single promotion available in the game
//
//!  Key Attributes:
//!  - Used to be called CvPromotionInfo
//!  - Populated from XML\Units\CIV5UnitPromotions.xml
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
class CvPromotionEntry: public CvHotKeyInfo
{
public:
#ifdef LEKMOD_PROMO_YIELD_FROM_CONVERSION
    int GetYieldFromFollowerConversion(int i) const;
    int GetYieldFromFollowerConversionMajority(int i) const;
#if defined(LEKMOD_PROMO_CONVERSION_MAJORITY_ONLY_ONCE)
    bool GetYieldFromFollowerConversionMajorityOnlyOnce(int i) const;
#endif
#endif
	CvPromotionEntry(void);
	~CvPromotionEntry(void);

	virtual bool CacheResults(Database::Results& kResults, CvDatabaseUtility& kUtility);

	int	GetLayerAnimationPath() const;
#if !defined(LEKMOD_RELOCATE_PROMOTION_PREREQ_ORS)
	int	GetPrereqPromotion() const;
	void	SetPrereqPromotion(int i);
	int	GetPrereqOrPromotion1() const;
	void	SetPrereqOrPromotion1(int i);
	int	GetPrereqOrPromotion2() const;
	void	SetPrereqOrPromotion2(int i);
	int	GetPrereqOrPromotion3() const;
	void	SetPrereqOrPromotion3(int i);
	int	GetPrereqOrPromotion4() const;
	void	SetPrereqOrPromotion4(int i);
	int	GetPrereqOrPromotion5() const;
	void	SetPrereqOrPromotion5(int i);
	int	GetPrereqOrPromotion6() const;
	void	SetPrereqOrPromotion6(int i);
	int	GetPrereqOrPromotion7() const;
	void	SetPrereqOrPromotion7(int i);
	int	GetPrereqOrPromotion8() const;
	void	SetPrereqOrPromotion8(int i);
	int	GetPrereqOrPromotion9() const;
	void	SetPrereqOrPromotion9(int i);

	//EAP: adding an additional promotion thing
	int	GetPrereqOrPromotion10() const;
	void	SetPrereqOrPromotion10(int i);
#endif
	int  GetTechPrereq() const;
	int  GetInvisibleType() const;
	int  GetSeeInvisibleType() const;
	int  GetVisibilityChange() const;
	int  GetMovesChange() const;
	int  GetMoveDiscountChange() const;
	int  GetHillsMovementDiscountPercent() const;
	int  GetRangeChange() const;
	int  GetRangedAttackModifier() const;
	int  GetInterceptionCombatModifier() const;
	int  GetInterceptionDefenseDamageModifier() const;
	int  GetAirSweepCombatModifier() const;
	int  GetInterceptChanceChange() const;
	int  GetNumInterceptionChange() const;
	int  GetEvasionChange() const;
	int  GetCargoChange() const;
	int  GetEnemyHealChange() const;
	int  GetNeutralHealChange() const;
	int  GetFriendlyHealChange() const;
	int  GetSameTileHealChange() const;
	int  GetAdjacentTileHealChange() const;
	int  GetEnemyDamageChance() const;
	int  GetNeutralDamageChance() const;
	int  GetEnemyDamage() const;
	int  GetNeutralDamage() const;
	int  GetCombatPercent() const;
	int  GetCityAttackPercent() const;
	int  GetCityDefensePercent() const;
	int  GetCitySplashDamage() const;
	int  GetRangedDefenseMod() const;
	int  GetHillsAttackPercent() const;
	int  GetHillsDefensePercent() const;
	int  GetOpenAttackPercent() const;
	int  GetOpenRangedAttackMod() const;
	int  GetRoughAttackPercent() const;
	int  GetRoughRangedAttackMod() const;
	int  GetAttackFortifiedMod() const;
	int  GetAttackWoundedMod() const;
	int  GetFlankAttackModifier() const;
	int  GetNearbyEnemyCombatMod() const;
	int  GetNearbyEnemyCombatRange() const;
	int  GetOpenDefensePercent() const;
	int  GetRoughDefensePercent() const;
	int  GetExtraAttacks() const;
	bool IsGreatGeneral() const;
	bool IsGreatAdmiral() const;
	int  GetGreatGeneralModifier() const;
	bool IsGreatGeneralReceivesMovement() const;
	bool IsEmbarkedUnitReceivesMovement() const; // NQMP GJS - Danish Longship
#ifdef LEKMOD_LONGSHIP_ALL_PROMO
	bool IsLandUnitReceivesMovement() const;
#endif
#ifdef NQ_ART_OF_WAR_PROMOTION
	int GetGreatGeneralOnOrAdjacentConfersMovement() const;
#endif
	int  GetGreatGeneralCombatModifier() const;
	int  GetFriendlyLandsModifier() const;
	int  GetFriendlyLandsAttackModifier() const;
	int  GetOutsideFriendlyLandsModifier() const;
#ifdef NQ_GOLDEN_AGE_FOREIGN_ATTACK_BONUS
	int GetGoldenAgeForeignAttackBonus() const;
#endif
#ifdef NQ_COMBAT_STRENGTH_NEAR_FRIENDLY_MINOR
	int GetCombatStrengthNearFriendlyMinor() const;
#endif
#if defined(LEKMOD_SUBMERGE_MISSION)
	bool IsSubmergePromotion() const;
#endif
	int  GetCommandType() const;
	void SetCommandType(int iNewType);

	int GetPillageChange() const { return m_iPillageChange; }
	int GetPillageXPChange() const { return m_iPillageXPChange; }
	int GetPillageHealChange() const { return m_iPillageHealChange; }
	int GetUpgradeDiscount() const;
	int GetExperiencePercent() const;
	int GetAdjacentMod() const;
	int GetAttackMod() const;
	int GetDefenseMod() const;

	int GetDropRange() const;
	int GetExtraNavalMoves() const;
	int GetHPHealedIfDefeatEnemy() const;
	int GetGoldenAgeValueFromKills() const;
	int GetExtraWithdrawal() const;
	int GetEmbarkExtraVisibility() const;
	int GetEmbarkDefenseModifier() const;
	bool IsEmbarkFlatCost() const;
	bool IsDisembarkFlatCost() const;
	int GetMaxMovesAfterDomainChange() const;
	bool IsHealWhileEmbarked() const;
	bool IsExtraAttackVsFullHP() const;
#ifdef LEKMOD_NUKE_RESISTANCE
	int GetNukeDamageFixed() const;
#endif
#ifdef LEKMOD_ATTACK_VS_EMBARKED
	int GetAttackVsEmbarkedMod() const;
#endif
	int GetMovesNearGeneralChange() const;
	int GetCapitalDefenseModifier() const;
	int GetCapitalDefenseFalloff() const;
	int GetCityAttackPlunderModifier() const;
#ifdef LEKMOD_MOVE_PENALTY_CITY_COMBAT
	int GetCityAttackMovePenalty() const;
#endif
	int GetReligiousStrengthLossRivalTerritory() const;
	
	int GetTradeMissionInfluenceModifier() const;
	int GetTradeMissionGoldModifier() const;
#if defined(v35_TRAITIFY)
	int GetNearbyWaterCombatModifier() const { return m_iNearbyWaterCombatModifier; }
	int GetAttackExtraMoves() const { return m_iAttackExtraMoves; }
	bool IsKillRefreshMove() const { return m_bKillRefreshMove; }
	bool IsKillRefreshAttack() const { return m_bKillRefreshAttack; }
#endif

	bool IsCannotBeChosen() const;
	bool IsLostWithUpgrade() const;
	bool IsNotWithUpgrade() const;
	bool IsInstaHeal() const;
	bool IsLeader() const;
	bool IsBlitz() const;
	bool IsAmphib() const;
	bool IsRiver() const;
	bool IsEnemyRoute() const;
	bool IsRivalTerritory() const;
	bool IsMustSetUpToRangedAttack() const;
	bool IsRangedSupportFire() const;
	bool IsAlwaysHeal() const;
	bool IsHealOutsideFriendly() const;
	bool IsHillsDoubleMove() const;

	bool IsIgnoreTerrainCost() const;
	bool IsRoughTerrainEndsTurn() const;
	bool IsHoveringUnit() const;
	bool IsFlatMovementCost() const;
	bool IsCanMoveImpassable() const;
	bool IsNoCapture() const;
	bool IsOnlyDefensive() const;
	bool IsNoDefensiveBonus() const;
#if defined(LEKMOD_NO_FORTIFY_VS_RANGED_PROMO)
	bool IsNoFortifyVsRanged() const;
#endif
	bool IsNukeImmune() const;
	bool IsHiddenNationality() const;
	bool IsAlwaysHostile() const;
	bool IsNoRevealMap() const;
	bool IsRecon() const;
	bool CanMoveAllTerrain() const;
	bool IsCanMoveAfterAttacking() const;
	bool IsAirSweepCapable() const;
	bool IsAllowsEmbarkation() const;
	bool IsRangeAttackIgnoreLOS() const;
	bool IsFreePillageMoves() const;
	bool IsHealOnPillage() const;
	bool IsCanCrossMountains() const;
	bool IsCarpetBombing() const;
	int  GetAdjacentTileHealOutsideFriendly() const;
	bool IsHealIfDefeatExcludeBarbarians() const;
	bool IsEmbarkedAllWater() const;
	bool IsCityAttackOnly() const;
	bool IsCaptureDefeatedEnemy() const;
	bool IsIgnoreGreatGeneralBenefit() const;
	bool IsIgnoreZOC() const;
	bool IsSapper() const;

	// CMP
	int GetConvertDomainUnit() const;
	int GetConvertDomain() const;
	int GetGiveDomain() const;
	//

	bool IsCanHeavyCharge() const;
#ifdef NQ_HEAVY_CHARGE_DOWNHILL
	int GetHeavyChargeDownhill() const;
#endif
	bool HasPostCombatPromotions() const;
	bool ArePostCombatPromotionsExclusive() const;

	const char* GetSound() const;
	void SetSound(const char* szVal);

#ifdef LEKMOD_CIV_PROMOTION_EFFECTS
	bool IsLekmodFightWellDamaged() const;
	bool IsLekmodNoFortify() const;
	int GetLekmodStrongerEnemyMod() const;
	int GetLekmodAdjacentEnemiesMod() const;
	int GetLekmodAdjacentEnemiesNeeded() const;
	int GetLekmodMovesAfterKill() const;
	int GetLekmodFarFromCityMod() const;
	int GetLekmodFarFromCityDistance() const;
	int GetLekmodAuraVsWoundedMod() const;
#ifdef LEKMOD_CIV_PROMOTION_EFFECTS_J
#ifdef LEKMOD_SPREAD_ABILITIES
	int GetLekmodHealRateMod() const;
#endif
	int GetLekmodFlatMoveCostMod() const;
	int GetLekmodCoastMoveCostMod() const;
	int GetLekmodCoastAttackMod() const;
	bool IsLekmodAlwaysHealFriendly() const;
#ifdef LEKMOD_PORTUGAL
	bool IsLekmodAdjacentAlwaysHeal() const;
	int GetLekmodSameTileEmbarkedHeal() const;
	bool IsLekmodSameTileDisembark() const;
#endif
#ifdef LEKMOD_POST_CHANGES
	bool IsLekmodExpandedZOC() const;
	bool IsLekmodCiviliansToo() const;
#endif
#ifdef LEKMOD_SPECS_2026_10_24
	int GetLekmodFarRangedDamageMod() const;
	int GetLekmodFarRangedDistance() const;
	int GetLekmodFriendlyAuraMod() const { return m_iLekmodFriendlyAuraMod; }
	int GetLekmodFriendlyAuraRange() const { return m_iLekmodFriendlyAuraRange; }
	int GetLekmodDeathHealHP() const { return m_iLekmodDeathHealHP; }
	int GetLekmodDeathHealRange() const { return m_iLekmodDeathHealRange; }
#endif
	int GetLekmodAttackFullHPMod() const;
	bool IsLekmodPostCombatOnSpawn() const;
#endif
	bool HasLekmodCivEffect() const;
#endif
#ifdef LEKMOD_NAVAL_PENALTY_PROMOTIONS
	int GetAdjacentRangedAttackMod() const;
	bool IsNoAdjacentRangedAttack() const;
	bool IsNoAttackFromCity() const;
#endif
#ifdef LEKMOD_UNIT_COMBAT_ATTACK_DEFENSE_MODS
	int GetUnitCombatAttackModifierPercent(int i) const;
	int GetUnitCombatDefenseModifierPercent(int i) const;
#endif

	// Arrays
#ifdef AUI_WARNING_FIXES
	int GetTerrainAttackPercent(uint i) const;
	int GetTerrainDefensePercent(uint i) const;
	int GetFeatureAttackPercent(uint i) const;
	int GetFeatureDefensePercent(uint i) const;
	int GetUnitCombatModifierPercent(uint i) const;
	int GetUnitClassModifierPercent(uint i) const;
	int GetDomainModifierPercent(uint i) const;
#if defined(LEKMOD_DOMAIN_PROMO_ATTACK_DEFENSE)
	int GetDomainAttackPercent(uint i) const;
	int GetDomainDefensePercent(uint i) const;
#endif
	int GetFeaturePassableTech(uint i) const;
	int GetUnitClassAttackModifier(uint i) const;
	int GetUnitClassDefenseModifier(uint i) const;

	bool GetTerrainDoubleMove(uint i) const;
	bool GetFeatureDoubleMove(uint i) const;
	bool GetTerrainImpassable(uint i) const;
	int  GetTerrainPassableTech(uint i) const;
	bool GetFeatureImpassable(uint i) const;
	bool GetUnitCombatClass(uint i) const;
	bool GetCivilianUnitType(uint i) const;
	bool IsPostCombatRandomPromotion(uint i) const;
#else
	int GetTerrainAttackPercent(int i) const;
	int GetTerrainDefensePercent(int i) const;
	int GetFeatureAttackPercent(int i) const;
	int GetFeatureDefensePercent(int i) const;
	int GetUnitCombatModifierPercent(int i) const;
	int GetUnitClassModifierPercent(int i) const;
	int GetDomainModifierPercent(int i) const;
#if defined(LEKMOD_DOMAIN_PROMO_ATTACK_DEFENSE)
	int GetDomainAttackPercent(int i) const;
	int GetDomainDefensePercent(int i) const;
#endif
	int GetFeaturePassableTech(int i) const;
	int GetUnitClassAttackModifier(int i) const;
	int GetUnitClassDefenseModifier(int i) const;

	bool GetTerrainDoubleMove(int i) const;
	bool GetFeatureDoubleMove(int i) const;
	bool GetTerrainImpassable(int i) const;
	int  GetTerrainPassableTech(int i) const;
	bool GetFeatureImpassable(int i) const;
	bool GetUnitCombatClass(int i) const;
	bool GetCivilianUnitType(int i) const;
	bool IsPostCombatRandomPromotion(int i) const;
#endif
#if defined(FULL_YIELD_FROM_KILLS)
	int GetYieldFromKills(int i) const;
	int GetKillYieldCap(int i) const;
	bool IsKillYieldEraValid(int i) const;
#endif
#if defined(LEKMOD_CONVERT_PROMOTIONS_UPGRADE)
	int GetUpgradeConversionPromotion(int i) const;
#endif
#if defined(LEKMOD_RELOCATE_PROMOTION_PREREQ_ORS)
	const std::vector<int>& GetPromotionPrereqOrs() const { return m_vPromotionPrereqOrs; }
#endif
#ifdef LEKMOD_DIFFERENT_IDEO_COMBAT_BONUS
	int GetCombatDifferentIdeology() const;
#endif

protected:
#ifdef LEKMOD_PROMO_YIELD_FROM_CONVERSION
    int* m_paiYieldFromFollowerConversion;
    int* m_paiYieldFromFollowerConversionMajority;
#if defined(LEKMOD_PROMO_CONVERSION_MAJORITY_ONLY_ONCE)
    bool* m_pabYieldFromFollowerConversionMajorityOnlyOnce;
#endif
#endif
	int m_iLayerAnimationPath;
#if !defined(LEKMOD_RELOCATE_PROMOTION_PREREQ_ORS)
	int m_iPrereqPromotion;
	int m_iPrereqOrPromotion1;
	int m_iPrereqOrPromotion2;
	int m_iPrereqOrPromotion3;
	int m_iPrereqOrPromotion4;
	int m_iPrereqOrPromotion5;
	int m_iPrereqOrPromotion6;
	int m_iPrereqOrPromotion7;
	int m_iPrereqOrPromotion8;
	int m_iPrereqOrPromotion9;
	int m_iPrereqOrPromotion10;
#endif
	int m_iTechPrereq;
	int m_iInvisibleType;
	int m_iSeeInvisibleType;
	int m_iVisibilityChange;
	int m_iMovesChange;
	int m_iMoveDiscountChange;
	int m_iHillsMovementDiscountPercent;
	int m_iRangeChange;
	int m_iRangedAttackModifier;
	int m_iInterceptionCombatModifier;
	int m_iInterceptionDefenseDamageModifier;
	int m_iAirSweepCombatModifier;
	int m_iInterceptChanceChange;
	int m_iNumInterceptionChange;
	int m_iEvasionChange;
	int m_iCargoChange;
	int m_iEnemyHealChange;
	int m_iNeutralHealChange;
	int m_iFriendlyHealChange;
	int m_iSameTileHealChange;
	int m_iAdjacentTileHealChange;
	int m_iEnemyDamageChance;
	int m_iNeutralDamageChance;
	int m_iEnemyDamage;
	int m_iNeutralDamage;
	int m_iCombatPercent;
	int m_iCityAttackPercent;
	int m_iCityDefensePercent;
	int m_iCitySplashDamage;
	int m_iRangedDefenseMod;
	int m_iHillsAttackPercent;
	int m_iHillsDefensePercent;
	int m_iOpenAttackPercent;
	int m_iOpenRangedAttackMod;
	int m_iRoughAttackPercent;
	int m_iRoughRangedAttackMod;
	int m_iAttackFortifiedMod;
	int m_iAttackWoundedMod;
	int m_iFlankAttackModifier;
	int m_iNearbyEnemyCombatMod;
	int m_iNearbyEnemyCombatRange;
	int m_iOpenDefensePercent;
	int m_iRoughDefensePercent;
	int m_iExtraAttacks;
	bool m_bGreatGeneral;
	bool m_bGreatAdmiral;
	int m_iGreatGeneralModifier;
	bool m_bGreatGeneralReceivesMovement;
	bool m_bEmbarkedUnitReceivesMovement; // NQMP GJS - Danish Longship
#ifdef LEKMOD_LONGSHIP_ALL_PROMO
	bool m_bLandUnitReceivesMovement;
#endif
#ifdef NQ_ART_OF_WAR_PROMOTION
	int m_iGreatGeneralOnOrAdjacentConfersMovement;
#endif
	int m_iGreatGeneralCombatModifier;
	int m_iFriendlyLandsModifier;
	int m_iFriendlyLandsAttackModifier;
	int m_iOutsideFriendlyLandsModifier;
#ifdef NQ_GOLDEN_AGE_FOREIGN_ATTACK_BONUS
	int m_iGoldenAgeForeignAttackBonus;
#endif
#ifdef NQ_COMBAT_STRENGTH_NEAR_FRIENDLY_MINOR
	int m_iCombatStrengthNearFriendlyMinor;
#endif
#if defined(LEKMOD_SUBMERGE_MISSION)
	bool m_bSubmergePromotion;
#endif
	int m_iCommandType;
	int m_iPillageChange;
	int m_iPillageXPChange;
	int m_iPillageHealChange;
	int m_iUpgradeDiscount;
	int m_iExperiencePercent;
	int m_iAdjacentMod;
	int m_iAttackMod;
	int m_iDefenseMod;
	int m_iDropRange;
	int m_iExtraNavalMoves;
	int m_iHPHealedIfDefeatEnemy;
	int m_iGoldenAgeValueFromKills;
	int m_iExtraWithdrawal;
	int m_iEmbarkExtraVisibility;
	int m_iEmbarkDefenseModifier;
	bool m_bEmbarkFlatCost;
	bool m_bDisembarkFlatCost;
	int m_iMaxMovesAfterDomainChange;
	bool m_bHealWhileEmbarked;
	bool m_bExtraAttackVsFullHP;
#ifdef LEKMOD_NUKE_RESISTANCE
	int m_iNukeDamageFixed;
#endif
#ifdef LEKMOD_ATTACK_VS_EMBARKED
	int m_iAttackVsEmbarkedMod;
#endif
	int m_iMovesNearGeneralChange;
	int m_iCapitalDefenseModifier;
	int m_iCapitalDefenseFalloff;
	int m_iCityAttackPlunderModifier;
#ifdef LEKMOD_MOVE_PENALTY_CITY_COMBAT
	int m_iCityAttackMovePenalty;
#endif
	int m_iReligiousStrengthLossRivalTerritory;
	int m_iTradeMissionInfluenceModifier;
	int m_iTradeMissionGoldModifier;
#if defined(v35_TRAITIFY)
	int m_iNearbyWaterCombatModifier;
	int m_iAttackExtraMoves;
	bool m_bKillRefreshMove;
	bool m_bKillRefreshAttack;
#endif

	bool m_bCannotBeChosen;
	bool m_bLostWithUpgrade;
	bool m_bNotWithUpgrade;
	bool m_bInstaHeal;
	bool m_bLeader;
	bool m_bBlitz;
	bool m_bAmphib;
	bool m_bRiver;
	bool m_bEnemyRoute;
	bool m_bRivalTerritory;
	bool m_bMustSetUpToRangedAttack;
	bool m_bRangedSupportFire;
	bool m_bAlwaysHeal;
	bool m_bHealOutsideFriendly;
	bool m_bHillsDoubleMove;
	bool m_bIgnoreTerrainCost;
	bool m_bRoughTerrainEndsTurn;
	bool m_bHoveringUnit;
	bool m_bFlatMovementCost;
	bool m_bCanMoveImpassable;
	bool m_bNoCapture;
	bool m_bOnlyDefensive;
	bool m_bNoDefensiveBonus;
#if defined(LEKMOD_NO_FORTIFY_VS_RANGED_PROMO)
	bool m_bNoFortifyVsRanged;
#endif
	bool m_bNukeImmune;
	bool m_bHiddenNationality;
	bool m_bAlwaysHostile;
	bool m_bNoRevealMap;
	bool m_bRecon;
	bool m_bCanMoveAllTerrain;
	bool m_bCanMoveAfterAttacking;
	bool m_bAirSweepCapable;
	bool m_bAllowsEmbarkation;
	bool m_bRangeAttackIgnoreLOS;
	bool m_bFreePillageMoves;
	bool m_bHealOnPillage;
	bool m_bCanCrossMountains;
	bool m_bCarpetBombing;
	int  m_iAdjacentTileHealOutsideFriendly;
	bool m_bHealIfDefeatExcludesBarbarians;
	bool m_bEmbarkedAllWater;
	bool m_bCityAttackOnly;
	bool m_bCaptureDefeatedEnemy;
	bool m_bIgnoreGreatGeneralBenefit;
	bool m_bIgnoreZOC;
	bool m_bHasPostCombatPromotions;
	bool m_bPostCombatPromotionsExclusive;
	bool m_bSapper;

	int m_iGiveDomain;
	int m_iConvertDomainUnit;
	int m_iConvertDomain;

	bool m_bCanHeavyCharge;
#ifdef NQ_HEAVY_CHARGE_DOWNHILL
	int m_iHeavyChargeDownhill;
#endif
#ifdef	LEKMOD_DIFFERENT_IDEO_COMBAT_BONUS
	int m_iCombatDifferentIdeology;
#endif

	CvString m_strSound;

	// Arrays
#if defined(LEKMOD_RELOCATE_PROMOTION_PREREQ_ORS)
	std::vector<int> m_vPromotionPrereqOrs;
#endif
#if defined(FULL_YIELD_FROM_KILLS)
	int* m_paiYieldFromKills;
	int* m_paiKillYieldCap;
	bool* m_pabKillYieldValidEra;
#endif
#if defined(LEKMOD_CONVERT_PROMOTIONS_UPGRADE)
	int* m_paiConvertPromotionUpgrades;
#endif
	int* m_piTerrainAttackPercent;
	int* m_piTerrainDefensePercent;
	int* m_piFeatureAttackPercent;
	int* m_piFeatureDefensePercent;
	int* m_piUnitCombatModifierPercent;
#ifdef LEKMOD_CIV_PROMOTION_EFFECTS
	bool m_bLekmodFightWellDamaged;
	bool m_bLekmodNoFortify;
	int m_iLekmodStrongerEnemyMod;
	int m_iLekmodAdjacentEnemiesMod;
	int m_iLekmodAdjacentEnemiesNeeded;
	int m_iLekmodMovesAfterKill;
	int m_iLekmodFarFromCityMod;
	int m_iLekmodFarFromCityDistance;
	int m_iLekmodAuraVsWoundedMod;
#ifdef LEKMOD_CIV_PROMOTION_EFFECTS_J
#ifdef LEKMOD_SPREAD_ABILITIES
	int m_iLekmodHealRateMod;
#endif
	int m_iLekmodFlatMoveCostMod;
	int m_iLekmodCoastMoveCostMod;
	int m_iLekmodCoastAttackMod;
	bool m_bLekmodAlwaysHealFriendly;
#ifdef LEKMOD_PORTUGAL
	bool m_bLekmodAdjacentAlwaysHeal;
	int m_iLekmodSameTileEmbarkedHeal;
	bool m_bLekmodSameTileDisembark;
#endif
#ifdef LEKMOD_POST_CHANGES
	bool m_bLekmodExpandedZOC;
	bool m_bLekmodCiviliansToo;
#endif
#ifdef LEKMOD_SPECS_2026_10_24
	int m_iLekmodFarRangedDamageMod;
	int m_iLekmodFarRangedDistance;
	int m_iLekmodFriendlyAuraMod;
	int m_iLekmodFriendlyAuraRange;
	int m_iLekmodDeathHealHP;
	int m_iLekmodDeathHealRange;
#endif
	int m_iLekmodAttackFullHPMod;
	bool m_bLekmodPostCombatOnSpawn;
#endif
#endif
#ifdef LEKMOD_NAVAL_PENALTY_PROMOTIONS
	int m_iAdjacentRangedAttackMod;
	bool m_bNoAdjacentRangedAttack;
	bool m_bNoAttackFromCity;
#endif
#ifdef LEKMOD_UNIT_COMBAT_ATTACK_DEFENSE_MODS
	int* m_piUnitCombatAttackModifierPercent;
	int* m_piUnitCombatDefenseModifierPercent;
#endif
	int* m_piUnitClassModifierPercent;
	int* m_piDomainModifierPercent;
#if defined(LEKMOD_DOMAIN_PROMO_ATTACK_DEFENSE)
	int* m_piDomainAttackPercent;
	int* m_piDomainDefensePercent;
#endif

	int* m_piUnitClassAttackModifier;
	int* m_piUnitClassDefenseModifier;

	int* m_piTerrainPassableTech;
	int* m_piFeaturePassableTech;

	bool* m_pbTerrainDoubleMove;
	bool* m_pbFeatureDoubleMove;
	bool* m_pbTerrainImpassable;
	bool* m_pbFeatureImpassable;
	bool* m_pbUnitCombat;
	bool* m_pbCivilianUnitType;
	bool* m_pbPostCombatRandomPromotion;
};

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  CLASS:      CvPromotionXMLEntries
//!  \brief		Game-wide information about promotions
//
//! Key Attributes:
//! - Plan is it will be contained in CvGameRules object within CvGame class
//! - Populated from XML\GameInfo\CIV5PromotionInfo.xml
//! - Contains an array of CvPromotionEntry from the above XML file
//! - One instance for the entire game
//! - Accessed heavily by the [what stores info on projects built?] class
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
class CvPromotionXMLEntries
{
public:
	CvPromotionXMLEntries(void);
	~CvPromotionXMLEntries(void);

	// Accessor functions
	std::vector<CvPromotionEntry*>& GetPromotionEntries();
#ifdef AUI_WARNING_FIXES
	uint GetNumPromotions() const;
	_Ret_maybenull_ CvPromotionEntry* GetEntry(uint index);
#else
	int GetNumPromotions();
	_Ret_maybenull_ CvPromotionEntry* GetEntry(int index);
#endif

	// Binary cache functions
	void DeleteArray();

private:
	std::vector<CvPromotionEntry*> m_paPromotionEntries;
};

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  CLASS:      CvUnitPromotions
//!  \brief		Information about the promotions of a single unit
//
//!  Key Attributes:
//!  - Plan is it will be contained in CvPlayerState object within CvUnit class
//!  - One instance for each unit
//!  - Accessed by any class that needs to check promotions
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
class CvUnitPromotions
{
public:
	CvUnitPromotions(void);
	~CvUnitPromotions(void);
	void Init(CvPromotionXMLEntries* pPromotions, CvUnit* pUnit);
	void Uninit();
	void Reset();
	void Read(FDataStream& kStream);
	void Write(FDataStream& kStream) const;

	CvUnit* GetUnit();

	bool HasPromotion(PromotionTypes eIndex) const;
	void SetPromotion(PromotionTypes eIndex, bool bValue);

	bool GetAllowFeaturePassable(FeatureTypes eFeatureType) const;
	bool GetAllowTerrainPassable(TerrainTypes eTerrainType) const ;

	int GetUnitClassAttackMod(UnitClassTypes eUnitClass) const;
	int GetUnitClassDefenseMod(UnitClassTypes eUnitClass) const;
#if defined(LEKMOD_DOMAIN_PROMO_ATTACK_DEFENSE)
	int GetDomainAttackMod(DomainTypes eDomain) const;
	int GetDomainDefenseMod(DomainTypes eDomain) const;
#endif

	PromotionTypes ChangePromotionAfterCombat(PromotionTypes eIndex);

private:

	bool IsInUseByPlayer(PromotionTypes eIndex, PlayerTypes ePlayer); 

	CvBitfield m_kHasPromotion;
	CvPromotionXMLEntries* m_pPromotions;
	CvUnit* m_pUnit;
};

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Helper Functions to serialize arrays of variable length (based on number of promotions defined in game)
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
namespace PromotionArrayHelpers
{
void ReadV3(FDataStream& kStream, CvBitfield& kPromotions);
void Read(FDataStream& kStream, CvBitfield& kPromotions);
void Write(FDataStream& kStream, const CvBitfield& kPromotions, int iArraySize);
}

#endif //CIV5_PROMOTION_CLASSES_H
