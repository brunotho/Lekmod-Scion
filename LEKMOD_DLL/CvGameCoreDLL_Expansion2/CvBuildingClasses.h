/*	-------------------------------------------------------------------------------------------------------
	� 1991-2012 Take-Two Interactive Software and its subsidiaries.  Developed by Firaxis Games.  
	Sid Meier's Civilization V, Civ, Civilization, 2K Games, Firaxis Games, Take-Two Interactive Software 
	and their respective logos are all trademarks of Take-Two interactive Software, Inc.  
	All other marks and trademarks are the property of their respective owners.  
	All rights reserved. 
	------------------------------------------------------------------------------------------------------- */
#pragma once

#ifndef CIV5_BUILDING_CLASSES_H
#define CIV5_BUILDING_CLASSES_H

#include "CvDatabaseUtility.h"

#define MAX_THEMING_BONUSES 12

struct BuildingFreeTerrainYields
{
	BuildingFreeTerrainYields() :
		m_eTerrain(NO_TERRAIN),
		m_eYield(NO_YIELD),
		m_bRequiresOwner(false),
		m_iRadius(1),
		m_iMinTerrainRequired(0),
		m_iYieldChange(0)
	{
	};
	TerrainTypes m_eTerrain;
	YieldTypes m_eYield;
	bool m_bRequiresOwner;
	int m_iRadius;
	int m_iMinTerrainRequired;
	int m_iYieldChange;
};
#ifdef LEKMOD_CONDITIONAL_BUILDING_YIELDS
// Building_LekmodConditionalYields: one row = a city yield with optional conditions (-1 / 0 = no condition)
struct LekmodBuildingConditionalYield
{
	LekmodBuildingConditionalYield() : m_eYield(NO_YIELD), m_iYield(0), m_eRequiredClass(NO_BUILDINGCLASS), m_bCoastal(false), m_bFreshWater(false),
		m_bConnected(false), m_bCapital(false), m_bPerConnectedCity(false), m_eAdjacentTerrain(NO_TERRAIN), m_eAdjacentFeature(NO_FEATURE),
		m_iAdjacentCount(1), m_iOwnCitiesRange(0), m_iOwnCitiesNeeded(0), m_iPerForeignCityRange(0), m_iPerSameBuildingRange(0),
		m_iNoSameBuildingRange(0), m_iPerPopulation(0), m_eIncomingDomain(NO_DOMAIN), m_eEra(NO_ERA), m_eAllTechsOfEra(NO_ERA), m_bBordersForeign(false), m_bBordersForeignCityOtherReligion(false) {};
	YieldTypes m_eYield;
	int m_iYield;
	BuildingClassTypes m_eRequiredClass;
	bool m_bCoastal;
	bool m_bFreshWater;
	bool m_bConnected;
	bool m_bCapital;
	bool m_bPerConnectedCity;
	TerrainTypes m_eAdjacentTerrain;
	FeatureTypes m_eAdjacentFeature;
	int m_iAdjacentCount;
	int m_iOwnCitiesRange;
	int m_iOwnCitiesNeeded;
	int m_iPerForeignCityRange;
	int m_iPerSameBuildingRange;
	int m_iNoSameBuildingRange;
	int m_iPerPopulation;
	DomainTypes m_eIncomingDomain;
	EraTypes m_eEra;
	EraTypes m_eAllTechsOfEra;
	bool m_bBordersForeign;
	bool m_bBordersForeignCityOtherReligion;
};
#endif
#ifdef LEKMOD_BUILDING_PLOT_YIELDS
// Building_LekmodPlotYields: yield on the city's tiles; plot conditions (terrain, feature, resource, next to a lake) and a city
// condition (at least CityAdjacentCount tiles next to the city with the terrain/feature); -1 = no condition
struct LekmodBuildingPlotYield
{
	LekmodBuildingPlotYield() : m_eYield(NO_YIELD), m_iYield(0), m_eTerrain(NO_TERRAIN), m_eFeature(NO_FEATURE), m_eResource(NO_RESOURCE),
		m_bAdjacentLake(false), m_eCityAdjacentTerrain(NO_TERRAIN), m_eCityAdjacentFeature(NO_FEATURE), m_iCityAdjacentCount(1),
		m_eResourceClass(NO_RESOURCECLASS), m_bRequiresImprovement(false) {};
	YieldTypes m_eYield;
	int m_iYield;
	TerrainTypes m_eTerrain;
	FeatureTypes m_eFeature;
	ResourceTypes m_eResource;
	bool m_bAdjacentLake;
	TerrainTypes m_eCityAdjacentTerrain;
	FeatureTypes m_eCityAdjacentFeature;
	int m_iCityAdjacentCount;
	ResourceClassTypes m_eResourceClass;
	bool m_bRequiresImprovement;
};
#endif
#ifdef LEKMOD_BUILDING_ADJACENT_CITY_YIELDS
// Building_AdjacentCityPlotYieldChanges: yield on plots next to the city; each condition is optional (-1 = any)
struct LekmodBuildingAdjacentYield
{
	LekmodBuildingAdjacentYield() : m_eImprovement(NO_IMPROVEMENT), m_eResource(NO_RESOURCE), m_eTerrain(NO_TERRAIN), m_eFeature(NO_FEATURE), m_eYield(NO_YIELD), m_iYield(0), m_bLake(false), m_eCityAdjacentImprovement(NO_IMPROVEMENT) {};
	ImprovementTypes m_eImprovement;
	ResourceTypes m_eResource;
	TerrainTypes m_eTerrain;
	FeatureTypes m_eFeature;
	YieldTypes m_eYield;
	int m_iYield;
	bool m_bLake;							// the plot must be a lake
	ImprovementTypes m_eCityAdjacentImprovement;	// an unpillaged one must be next to the city (Vietnam: Festival)
};
#endif
#ifdef LEKMOD_BUILDING_TECH_TERRAIN_YIELDS
// Building_TechTerrainYieldChanges: worked tiles of a terrain yield more once the owner knows the tech (Lighthouse: Coast +1 Production with Construction)
struct LekmodBuildingTechTerrainYield
{
	LekmodBuildingTechTerrainYield() : m_eTech(NO_TECH), m_eTerrain(NO_TERRAIN), m_eYield(NO_YIELD), m_iYield(0) {};
	TechTypes m_eTech;
	TerrainTypes m_eTerrain;
	YieldTypes m_eYield;
	int m_iYield;
};
#endif
#ifdef LEKMOD_GREAT_WORK_WONDER_EFFECTS
// Building_GreatWorkFilledYields: city yields once all great work slots of the building are filled (or per filled slot), optionally x (era + 1)
struct LekmodGreatWorkFilledYield
{
	LekmodGreatWorkFilledYield() : m_eYield(NO_YIELD), m_iYield(0), m_bPerSlot(false), m_bPerEra(false), m_bCityTile(false), m_bGlobal(false), m_bModifier(false) {};
	YieldTypes m_eYield;
	int m_iYield;
	bool m_bPerSlot;
	bool m_bPerEra;
	bool m_bCityTile;	// on the city tile (Forbidden Palace)
	bool m_bGlobal;		// in every city of the owner (Angkor Wat)
	bool m_bModifier;	// % yield modifier in the city (Alhambra)
};
// Building_FreshWaterImprovementYieldChanges: improved tiles with fresh water worked by the city yield more (Angkor Wat: farms +1 Faith)
struct LekmodFreshWaterImprovementYield
{
	LekmodFreshWaterImprovementYield() : m_eImprovement(NO_IMPROVEMENT), m_eYield(NO_YIELD), m_iYield(0) {};
	ImprovementTypes m_eImprovement;
	YieldTypes m_eYield;
	int m_iYield;
};
#endif
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  class : CvThemingBonusInfo
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
class CvThemingBonusInfo
{
	friend class CvBuildingEntry;

public:
	CvThemingBonusInfo() :
	  m_iBonus(0),
	  m_bSameEra(false),
	  m_bUniqueEras(false),
	  m_bMustBeArt(false),
	  m_bMustBeArtifact(false),
	  m_bMustBeEqualArtArtifact(false),
	  m_bRequiresOwner(false),
	  m_bRequiresAnyButOwner(false),
	  m_bRequiresSamePlayer(false),
	  m_bRequiresUniquePlayers(false),
	  m_iAIPriority(0)
	  {

	  };

	int GetBonus() {return m_iBonus;};
	CvString GetDescription() {return m_strDescription;};
	bool IsSameEra() {return m_bSameEra;};
	bool IsUniqueEras() {return m_bUniqueEras;};
	bool IsMustBeArt() {return m_bMustBeArt;};
	bool IsMustBeArtifact() {return m_bMustBeArtifact;};
	bool IsMustBeEqualArtArtifact() {return m_bMustBeEqualArtArtifact;};
	bool IsRequiresOwner() {return m_bRequiresOwner;};
	bool IsRequiresAnyButOwner() {return m_bRequiresAnyButOwner;};
	bool IsRequiresSamePlayer() {return m_bRequiresSamePlayer;};
	bool IsRequiresUniquePlayers() {return m_bRequiresUniquePlayers;};
	int GetAIPriority() {return m_iAIPriority;};

protected:
	int m_iBonus;
	CvString m_strDescription;
	bool m_bSameEra;
	bool m_bUniqueEras;
	bool m_bMustBeArt;
	bool m_bMustBeArtifact;
	bool m_bMustBeEqualArtArtifact;
	bool m_bRequiresOwner;
	bool m_bRequiresAnyButOwner;
	bool m_bRequiresSamePlayer;
	bool m_bRequiresUniquePlayers;
	int m_iAIPriority;
};

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  CLASS:      CvBuildingEntry
//!  \brief		A single building available in the game
//
//!  Key Attributes:
//!  - Used to be called CvBuildingInfo
//!  - Populated from XML\Buildings\CIV5BuildingInfos.xml
//!  - Array of these contained in CvBuildingXMLEntries class
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
class CvBuildingEntry: public CvBaseInfo
{
public:
	CvBuildingEntry(void);
	~CvBuildingEntry(void);

	virtual bool CacheResults(Database::Results& kResults, CvDatabaseUtility& kUtility);

	// Accessor Functions (Non-Arrays)
	int GetBuildingClassType() const;
	const CvBuildingClassInfo& GetBuildingClassInfo() const;

	int GetNearbyTerrainRequired() const;
	int GetProhibitedCityTerrain() const;
	int GetVictoryPrereq() const;
	int GetFreeStartEra() const;
	int GetMaxStartEra() const;
	int GetObsoleteTech() const;
	int GetEnhancedYieldTech() const;
	int GetTechEnhancedTourism() const;
	int GetGoldMaintenance() const;
#if defined(BEE)
	bool IsSellable() const { return m_bNoSell; }
#endif
	int GetMutuallyExclusiveGroup() const;
	int GetReplacementBuildingClass() const;
	int GetPrereqAndTech() const;
	int GetEra() const;
	int GetPolicyBranchType() const;
	int GetSpecialistType() const;
	int GetSpecialistCount() const;
	int GetSpecialistExtraCulture() const;
	int GetGreatPeopleRateChange() const;
	GreatWorkSlotType GetGreatWorkSlotType() const;
#ifdef AUI_WARNING_FIXES
	uint GetGreatWorkCount() const;
#else
	int GetGreatWorkCount() const;
#endif
	GreatWorkType GetFreeGreatWork() const;
#ifdef LEKMOD_v34
	int GetFreeGreatWorkCount() const;
#endif
	int GetFreeBuildingClass() const;
	int GetFreeBuildingThisCity() const;
	int GetFreePromotion() const;
	int GetTrainedFreePromotion() const;
	int GetFreePromotionRemoved() const;
	int GetProductionCost() const;
#ifdef LEKMOD_BUILDING_GOLD_COST
	int GetGoldCost() const;
	bool RequiresGoldPurchase() const;
#endif
	int GetFaithCost() const;
	int GetLeagueCost() const;
	int GetNumCityCostMod() const;
	int GetHurryCostModifier() const;
	int GetNumCitiesPrereq() const;
	int GetUnitLevelPrereq() const;
	int GetCultureRateModifier() const;
	int GetGlobalCultureRateModifier() const;
	int GetGreatPeopleRateModifier() const;
	int GetGlobalGreatPeopleRateModifier() const;
	int GetGreatGeneralRateModifier() const;
	int GetGreatPersonExpendGold() const;
	int GetUnitUpgradeCostMod() const;
	int GetGoldenAgeModifier() const;
	int GetFreeExperience() const;
	int GetGlobalFreeExperience() const;
	int GetFoodKept() const;
#if defined(LEKMOD_BUILDING_EXCESS_GROWTH)
	int GetExcessGrowth() const;
#endif
	bool IsAirlift() const;
	int GetAirModifier() const;
	int GetNukeModifier() const;
	int GetNukeExplosionRand() const;
	int GetWorkerSpeedModifier() const;
	int GetMilitaryProductionModifier() const;
#if defined(LEKMOD_BUILDING_MILITARY_PRODUCTION_MOD)
	int GetMilitaryProductionMod() const;
#endif
	int GetSpaceProductionModifier() const;
	int GetGlobalSpaceProductionModifier() const;
	int GetBuildingProductionModifier() const;
	int GetWonderProductionModifier() const;
	int GetCityConnectionTradeRouteModifier() const;
	int GetCapturePlunderModifier() const;
	int GetPolicyCostModifier() const;
	int GetGlobalPlotCultureCostModifier() const;
	int GetPlotCultureCostModifier() const;
	int GetGlobalPlotBuyCostModifier() const;
	int GetPlotBuyCostModifier() const;
	int GetMinAreaSize() const;
	int GetConquestProbability() const;
	int GetHealRateChange() const;
#ifdef LEKMOD_DEFENSE_BUILDINGS
	int GetCityHealRate() const;
	int GetAdjacentEnemyDamage() const;
	int GetHillCityStrength() const;
	int GetMountainCityStrength() const;
	int GetCityAttackRangeChange() const;
	int GetNukeUnitDamageFixed() const;
	bool IsAirportRebase() const;
#ifdef LEKMOD_CANAL_PROJECT
	int GetTradeRouteOriginYieldModifier() const;
	int GetLekmodTradeRecipientGoldPerEra() const;
	int GetLekmodInternalTradePerPartnerMod() const;
#endif
#ifdef LEKMOD_PORTUGAL
	int GetLekmodEffectsNeedClass1() const;
	int GetLekmodEffectsNeedClass2() const;
	int GetLekmodCapitalYieldType() const;
	int GetLekmodCapitalYield() const;
	int GetLekmodTradeToCapitalGoldPerEra() const;
	int GetLekmodTradeFromCapitalFood() const;
#endif
#ifdef LEKMOD_POST_CHANGES
	int GetLekmodBuildingProductionPerCity() const;
	int GetLekmodInstantSciencePerPop() const;
	bool IsLekmodYieldsOnCityTile() const;
#ifdef LEKMOD_MINOR_TRAIT_BUILDINGS
	int GetLekmodMinorCivTrait() const;
	int GetLekmodEraLevel(EraTypes eEra) const;
#endif
#endif
	bool IsNearRiver() const;
	bool IsNoMaintenanceOnRiver() const;
	int GetRevealResource() const;
	bool IsWorshipHouse() const { return m_bLekmodWorshipHouse; }
	int GetGreatWorkYieldModifier() const { return m_iLekmodGreatWorkYieldModifier; }
#endif
#ifdef LEKMOD_GREAT_WORK_WONDER_EFFECTS
	const std::vector<LekmodGreatWorkFilledYield>& GetLekmodGreatWorkFilledYields() const { return m_aLekmodGreatWorkFilledYields; }
	const std::vector<std::pair<int, int> >& GetLekmodEraHappiness() const { return m_aLekmodEraHappiness; }
	int GetGreatWorkFilledGPRateModifier() const { return m_iLekmodGreatWorkFilledGPRateModifier; }
#ifdef LEKMOD_SPECS_2026_10_24
	bool IsLekmodLockedGreatWorkSlots() const { return m_bLekmodLockedGreatWorkSlots; }
	BuildingTypes GetLekmodFreeBuildingThisCityType() const;
#endif
	int GetGreatWorkFilledNearbyTourismMod() const { return m_iLekmodGreatWorkFilledNearbyTourismMod; }
	int GetGreatWorkFilledNearbyTourismRange() const { return m_iLekmodGreatWorkFilledNearbyTourismRange; }
	int GetNearbyMinorRestingInfluence() const { return m_iLekmodNearbyMinorRestingInfluence; }
	int GetNearbyMinorRange() const { return m_iLekmodNearbyMinorRange; }
	int GetNearbyEnemyCombatMod() const { return m_iLekmodNearbyEnemyCombatMod; }
	int GetNearbyEnemyCombatRange() const { return m_iLekmodNearbyEnemyCombatRange; }
	int GetClosestCoastalMinorInfluence() const { return m_iLekmodClosestCoastalMinorInfluence; }
	bool IsClosestCoastalMinorTradeQuest() const { return m_bLekmodClosestCoastalMinorTradeQuest; }
	int GetGoldenAgePopulationChange() const { return m_iLekmodGoldenAgePopulationChange; }
#ifdef LEKMOD_SPY_WONDERS
	int GetEnemySpyStealSlower() const { return m_iLekmodEnemySpyStealSlower; }
	int GetGuardLevelChange() const { return m_iLekmodGuardLevelChange; }
	bool IsExecuteCaughtSpies() const { return m_bLekmodExecuteCaughtSpies; }
	bool IsBlockForeignSpies() const { return m_bLekmodBlockForeignSpies; }
	bool IsFastSpyEstablish() const { return m_bLekmodFastSpyEstablish; }
	bool IsDemographicsBlackout() const { return m_bLekmodDemographicsBlackout; }
	int GetSpyReviveTurnsChange() const { return m_iLekmodSpyReviveTurnsChange; }
	bool IsStolenScienceGold() const { return m_bLekmodStolenScienceGold; }
	int GetCoupGoldPerEra() const { return m_iLekmodCoupGoldPerEra; }
#ifdef LEKMOD_CITY_VISION_BUILDINGS
	int GetCityVisionChange() const { return m_iLekmodCityVisionChange; }
#endif
	bool IsExtraWorldLeaderVote() const { return m_bLekmodExtraWorldLeaderVote; }
#endif
	const std::vector<LekmodFreshWaterImprovementYield>& GetLekmodFreshWaterImprovementYields() const { return m_aLekmodFreshWaterImprovementYields; }
	bool HasLekmodWonderEffects() const
	{
		return !m_aLekmodGreatWorkFilledYields.empty() || !m_aLekmodEraHappiness.empty() || m_iLekmodGreatWorkFilledGPRateModifier != 0
			|| m_iLekmodGoldenAgePopulationChange != 0 || !m_aLekmodFreshWaterImprovementYields.empty()
			|| m_iLekmodGreatWorkFilledNearbyTourismMod != 0 || m_iLekmodNearbyMinorRestingInfluence != 0 || m_iLekmodNearbyEnemyCombatMod != 0;
	}
#endif
#ifdef LEKMOD_TERRITORY_HEAL
	int GetTerritoryHealChange() const;
#endif
	int GetHappiness() const;
	int GetUnmoddedHappiness() const;
	int GetUnhappinessModifier() const;
	int GetHappinessPerCity() const;
	int GetHappinessPerXPolicies() const;
	int GetCityCountUnhappinessMod() const;
	bool IsNoOccupiedUnhappiness() const;
	int GetGlobalPopulationChange() const;
#ifdef NQ_LOCAL_POPULATION_CHANGE_FROM_BUILDING
	int GetLocalPopulationChange() const;
#endif
	int GetTechShare() const;
	int GetFreeTechs() const;
	int GetFreePolicies() const;
	int GetFreeFlatFaith() const; // NQMP GJS - New Stonehenge
	int GetFreeGreatPeople() const;
	int GetMedianTechPercentChange() const;
	int GetGold() const;
	bool IsNearbyMountainRequired() const;
	bool IsAllowsRangeStrike() const;
	int GetDefenseModifier() const;
#ifdef NQ_BUILDING_DEFENSE_FROM_CITIZENS
	int GetDefensePerCitizen() const;
#endif
	int GetGlobalDefenseModifier() const;
	int GetExtraCityHitPoints() const;
	int GetMinorFriendshipChange() const;
	int GetVictoryPoints() const;
	int GetExtraMissionarySpreads() const;
	int GetReligiousPressureModifier() const;
	int GetEspionageModifier() const;
	int GetGlobalEspionageModifier() const;
	int GetExtraSpies() const;
	int GetSpyRankChange() const;
	int GetTradeRouteRecipientBonus() const;
	int GetTradeRouteTargetBonus() const;
	int GetNumTradeRouteBonus() const;
	int GetInstantSpyRankChange() const;
	int GetLandmarksTourismPercent() const;
	int GetInstantMilitaryIncrease() const;
	int GetGreatWorksTourismModifier() const;
	int GetXBuiltTriggersIdeologyChoice() const;
	int GetTradeRouteSeaDistanceModifier() const;
	int GetTradeRouteSeaGoldBonus() const;
	int GetTradeRouteLandDistanceModifier() const;
	int GetTradeRouteLandGoldBonus() const;
	int GetCityStateTradeRouteProductionModifier() const;
	int GetCityStateTradeRouteGoldModifier() const; // NQMP GJS - new Economic Union
	int GetGreatScientistBeakerModifier() const;
	int GetExtraLeagueVotes() const;
	int GetExtraLeagueVotesAtomic() const;
#if defined(LEKMOD_GARRISON_YIELD_EFFECTS)
	int GetGarrisonStrengthBonus() const;
	int IsGarrisonMaintenanceFree() const { return m_bGarrisonMaintenanceFree; };
#endif
#if defined(LEKMOD_GREAT_WORK_YIELD_EFFECTS)
	int GetGreatWorkHappiness() const;
#ifdef LEKMOD_POLICY_REWORK
	bool IsLekmodPolicyGranted() const;
#endif
#endif
	int GetPreferredDisplayPosition() const;
	int GetPortraitIndex() const;
	bool IsTeamShare() const;
	bool IsWater() const;
	bool IsRiver() const;
	bool IsFreshWater() const;
#if defined(LEKMOD_BUILDING_LAKE_REQ)
	bool IsLake() const;
#endif
	bool IsMountain() const;
	bool IsHill() const;
	bool IsFlat() const;
	bool IsFoundsReligion() const;
	bool IsReligious() const;
	bool IsBorderObstacle() const;
	bool IsPlayerBorderObstacle() const;
	bool IsCityWall() const;
	bool IsCapital() const;
	bool IsGoldenAge() const;
	bool IsGrantsFreeCulturalGreatPersonWithTrait() const; // NQMP GJS - New France UA
	bool IsMapCentering() const;
	bool IsNeverCapture() const;
	bool IsNukeImmune() const;
	bool IsExtraLuxuries() const;
	bool IsDiplomaticVoting() const;
	bool AllowsWaterRoutes() const;
	bool IsScienceBuilding() const;
	bool IsUnlockedByBelief() const;
	bool IsUnlockedByLeague() const;
	bool IsRequiresHolyCity() const;
	bool AffectSpiesNow() const;
	bool IsEspionage() const;
#ifdef NQ_MALI_TREASURY
	bool IsMalianTreasury() const;
#endif
	bool AllowsFoodTradeRoutes() const;
	bool AllowsProductionTradeRoutes() const;
	bool NullifyInfluenceModifier() const;
#if defined(LEKMOD_BUILDING_FIRST_PURCHASE_DISCOUNT)
	int GetFirstPurchaseDiscount() const { return m_iFirstPurchaseDiscount; };
#endif

	const char* GetArtDefineTag() const;
	void SetArtDefineTag(const char* szVal);
	const bool GetArtInfoCulturalVariation() const;
	const bool GetArtInfoEraVariation() const;
	const bool GetArtInfoRandomVariation() const;

	const char* GetWonderSplashAudio() const;
	CvString GetThemingBonusHelp() const;

	// Accessor Functions (Arrays)

	int GetYieldChange(int i) const;
	int* GetYieldChangeArray() const;
	int GetYieldChangePerPop(int i) const;
	int* GetYieldChangePerPopArray() const;
	int GetYieldChangePerReligion(int i) const;
	int* GetYieldChangePerReligionArray() const;
	int GetYieldModifier(int i) const;;
	int* GetYieldModifierArray() const;
	int GetAreaYieldModifier(int i) const;
	int* GetAreaYieldModifierArray() const;
	int GetGlobalYieldModifier(int i) const;
	int* GetGlobalYieldModifierArray() const;
	int GetTechEnhancedYieldChange(int i) const;
	int* GetTechEnhancedYieldChangeArray() const;
#if defined(LEKMOD_ERA_ENHANCED_YIELDS)
	int GetEraEnhancedYieldChange(int i, int j) const;
	int** GetEraEnhancedYieldChangeArray() const;
#endif
	int GetSeaPlotYieldChange(int i) const;
	int* GetSeaPlotYieldChangeArray() const;
	int GetRiverPlotYieldChange(int i) const;
	int* GetRiverPlotYieldChangeArray() const;
	int GetLakePlotYieldChange(int i) const;
	int* GetLakePlotYieldChangeArray() const;
	int GetSeaResourceYieldChange(int i) const;
	int* GetSeaResourceYieldChangeArray() const;
	int GetSpecialistCount(int i) const;
	int GetFreeSpecialistCount(int i) const;
	int GetUnitCombatFreeExperience(int i) const;
#ifdef LEKMOD_GLOBAL_UNITCOMBAT_XP_BUILDINGS
	int GetLekmodGlobalUnitCombatFreeExperience(int i) const;
#endif
	int GetUnitCombatProductionModifier(int i) const;
#ifdef LEKMOD_v34
	int GetUnitCombatProductionCostModifier(int i) const;
	int GetUnitCombatExtraProduction(int i) const;
#endif
	int GetDomainFreeExperience(int i) const;
	int GetDomainFreeExperiencePerGreatWork(int i) const;
#if defined(LEKMOD_GREAT_WORK_YIELD_EFFECTS)
	int GetGreatWorkMilitaryProductionModifier() const;
	int GetBuildingGreatWorkYieldChange(int i) const;
	int GetCityGreatWorkYieldChange(int i) const;
	int GetCityGreatWorkClassYieldChange(int i, int y) const;
#endif
	int GetDomainProductionModifier(int i) const;
	int GetLockedBuildingClasses(int i) const;
	int GetPrereqAndTechs(int i) const;
	int GetResourceQuantityRequirement(int i) const;
	int GetResourceQuantity(int i) const;
#if !defined(LEKMOD_FIX_BUILDING_RESOURCE_YIELD_CHANGE)
	int GetResourceCultureChange(int i) const;
	int GetResourceFaithChange(int i) const;
#else
	int GetBuildingLocalResourceYieldChange(int i, int j) const;
#endif
	int GetProductionTraits(int i) const;
	int GetPrereqNumOfBuildingClass(int i) const;
	int GetFlavorValue(int i) const;
	int GetLocalResourceAnd(int i) const;
	int GetLocalResourceOr(int i) const;
	int GetHurryModifier(int i) const;
	bool IsBuildingClassNeededInCity(int i) const;
	int GetNumFreeUnits(int i) const;
#if defined(TRADE_REFACTOR)
	// Yield for SENDER if creating a Trade Route from a city with this building
	int GetTradeConnectionOriginLandYieldChange(int i, int j) const;
	int GetTradeConnectionOriginSeaYieldChange(int i, int j) const;
	// Yield for RECEIVER for having a Trade Route sent to a city with this building
	int GetTradeConnectionDestinationLandYieldChange(int i, int j) const;
	int GetTradeConnectionDestinationSeaYieldChange(int i, int j) const;
	// Yield for the SENDER if they send a Trade Route to a city with this building, if international, else to destination city. its a bit complicated...
	int GetIncomingTradeConnectionLandYieldChange(int i, int j) const;
	int GetIncomingTradeConnectionSeaYieldChange(int i, int j) const;
#endif
#if defined(MISC_CHANGES) // CvBuildingClasses arrays
	int GetResourceClassYieldChange(int i, int j) const;
#endif
#if defined(LEKMOD_v34)
	int GetGarrisonYieldChange(int j) const;
#endif
#if defined(LEKMOD_AREA_BASED_CITY_YIELD)
	int GetSameLandMassYieldChange(int i) const;
	int GetDifferentLandMassYieldChange(int i) const;
#endif
#if defined(LEKMOD_NEARBY_TERRAIN_FREE_YIELDS)
	const std::vector<BuildingFreeTerrainYields>& GetFreeTerrainYields() const;
#ifdef LEKMOD_BUILDING_TECH_TERRAIN_YIELDS
	const std::vector<LekmodBuildingTechTerrainYield>& GetLekmodTechTerrainYields() const;
#endif
#ifdef LEKMOD_BUILDING_ADJACENT_CITY_YIELDS
	const std::vector<LekmodBuildingAdjacentYield>& GetLekmodAdjacentCityYields() const;
#endif
#ifdef LEKMOD_CONDITIONAL_BUILDING_YIELDS
	const std::vector<LekmodBuildingConditionalYield>& GetLekmodConditionalYields() const;
#endif
#ifdef LEKMOD_BUILDING_START_TURN_MOVES
	int GetLekmodStartTurnMovesMountedCivilian() const;
#endif
#ifdef LEKMOD_CIV_ONLY_BUILDINGS
	int GetLekmodRequiredCivilization() const;
	int GetLekmodPrereqTechOr() const;
#endif
#ifdef LEKMOD_BUILDING_FILLED_SLOT_TOURISM
	int GetLekmodGreatWorkFilledTourismModifier() const;
#endif
#ifdef LEKMOD_BUILDING_PLOT_YIELDS
	const std::vector<LekmodBuildingPlotYield>& GetLekmodPlotYields() const;
#endif
#ifdef LEKMOD_CIV_TRAIT_FLAGS
	bool IsLekmodFreePlotPurchase() const;
#endif
#ifdef LEKMOD_CITY_TIMED_BUILDINGS
	const std::vector<std::pair<int, std::pair<int, int> > >& GetLekmodLocalSpecialistYields() const; // specialist, (yield, value)
	bool IsLekmodSpreadCapitalReligionOnBuild() const;
	int GetLekmodStartTurnMovesAround() const;
	int GetLekmodIsolatedPlotCultureCostMod() const;
	int GetLekmodIsolatedRange() const;
	int GetLekmodTimedBuilding() const;
	int GetLekmodTimedBuildingTurns() const;
	int GetLekmodWLTKDTurnsOnBuild() const;
	int GetLekmodTrainedUnitStackBuilding() const;
	int GetLekmodTrainedUnitStackMax() const;
#endif
#endif

	int GetResourceYieldChange(int i, int j) const;
	int* GetResourceYieldChangeArray(int i) const;
	int GetFeatureYieldChange(int i, int j) const;
	int* GetFeatureYieldChangeArray(int i) const;
	int GetResourceYieldChangeGlobal(int iResource, int iYieldType) const;
	int GetImprovementYieldChange(int i, int j) const;
	int* GetImprovementYieldChangeArray(int i) const;

	int GetImprovementYieldChangeGlobal(int i, int j) const;
	int* GetImprovementYieldChangeGlobalArray(int i) const;
#ifdef AUI_WARNING_FIXES
	int GetSpecialistYieldChange(uint i, int j) const;
#else
	int GetSpecialistYieldChange(int i, int j) const;
#endif
	int* GetSpecialistYieldChangeArray(int i) const;
	int GetResourceYieldModifier(int i, int j) const;
	int* GetResourceYieldModifierArray(int i) const;
	int GetTerrainYieldChange(int i, int j) const;
	int* GetTerrainYieldChangeArray(int i) const;
	int GetBuildingClassYieldChange(int i, int j) const;
#ifdef LEKMOD_BUILDING_GP_EXPEND_YIELD
	int GetGreatPersonExpendYield(int i) const;
#endif
	int GetBuildingClassHappiness(int i) const;

	CvThemingBonusInfo *GetThemingBonusInfo(int i) const;
	int GetNumThemingBonuses() const {return m_iNumThemingBonuses;};

private:
	int m_iBuildingClassType;
	const CvBuildingClassInfo* m_pkBuildingClassInfo;

	int m_iNearbyTerrainRequired;
	int m_iProhibitedCityTerrain;
	int m_iVictoryPrereq;
	int m_iFreeStartEra;
	int m_iMaxStartEra;
	int m_iObsoleteTech;
	int m_iEnhancedYieldTech;
	int m_iTechEnhancedTourism;
	int m_iGoldMaintenance;
#if defined(BEE)
	bool m_bNoSell;
#endif
	int m_iMutuallyExclusiveGroup;
	int m_iReplacementBuildingClass;
	int m_iPrereqAndTech;
	int m_iPolicyBranchType;
	int m_iSpecialistType;
	int m_iSpecialistCount;
	int m_iSpecialistExtraCulture;
	int m_iGreatPeopleRateChange;
	GreatWorkSlotType m_eGreatWorkSlotType;
#ifdef AUI_WARNING_FIXES
	uint m_iGreatWorkCount;
#else
	int m_iGreatWorkCount;
#endif
	GreatWorkType m_eFreeGreatWork;
#ifdef LEKMOD_v34
	int m_iFreeGreatWorkCount;
#endif
	int m_iFreeBuildingClass;
	int m_iFreeBuildingThisCity;
	int m_iFreePromotion;
	int m_iTrainedFreePromotion;
	int m_iFreePromotionRemoved;
	int m_iProductionCost;
#ifdef LEKMOD_BUILDING_GOLD_COST
	int m_iGoldCost;
	bool m_bRequiresGoldPurchase;
#endif
	int m_iFaithCost;
	int m_iLeagueCost;
	int m_iNumCityCostMod;
	int m_iHurryCostModifier;
	int m_iNumCitiesPrereq;
	int m_iUnitLevelPrereq;
	int m_iCultureRateModifier;
	int m_iGlobalCultureRateModifier;
	int m_iGreatPeopleRateModifier;
	int m_iGlobalGreatPeopleRateModifier;
	int m_iGreatGeneralRateModifier;
	int m_iGreatPersonExpendGold;
	int m_iUnitUpgradeCostMod;
	int m_iGoldenAgeModifier;
	int m_iFreeExperience;
	int m_iGlobalFreeExperience;
	int m_iFoodKept;
#if defined(LEKMOD_BUILDING_EXCESS_GROWTH)
	int m_iExcessGrowth;
#endif
	bool m_bAirlift;
	int m_iAirModifier;
	int m_iNukeModifier;
	int m_iNukeExplosionRand;
	int m_iWorkerSpeedModifier;
	int m_iMilitaryProductionModifier;
#if defined(LEKMOD_BUILDING_MILITARY_PRODUCTION_MOD)
	int m_iMilitaryProductionMod;
#endif
	int m_iSpaceProductionModifier;
	int m_iGlobalSpaceProductionModifier;
	int m_iBuildingProductionModifier;
	int m_iWonderProductionModifier;
	int m_iCityConnectionTradeRouteModifier;
	int m_iCapturePlunderModifier;
	int m_iPolicyCostModifier;
	int m_iGlobalPlotCultureCostModifier;
	int m_iPlotCultureCostModifier;
	int m_iGlobalPlotBuyCostModifier;
	int m_iPlotBuyCostModifier;
	int m_iMinAreaSize;
	int m_iConquestProbability;
	int m_iHealRateChange;
#ifdef LEKMOD_DEFENSE_BUILDINGS
	int m_iCityHealRate;
	int m_iAdjacentEnemyDamage;
	int m_iHillCityStrength;
	int m_iMountainCityStrength;
	int m_iCityAttackRangeChange;
	int m_iNukeUnitDamageFixed;
	bool m_bAirportRebase;
#ifdef LEKMOD_CANAL_PROJECT
	int m_iTradeRouteOriginYieldModifier;
	int m_iLekmodTradeRecipientGoldPerEra;
	int m_iLekmodInternalTradePerPartnerMod;
#endif
#ifdef LEKMOD_PORTUGAL
	int m_iLekmodEffectsNeedClass1;
	int m_iLekmodEffectsNeedClass2;
	int m_iLekmodCapitalYieldType;
	int m_iLekmodCapitalYield;
	int m_iLekmodTradeToCapitalGoldPerEra;
	int m_iLekmodTradeFromCapitalFood;
#endif
#ifdef LEKMOD_POST_CHANGES
	int m_iLekmodBuildingProductionPerCity;
	int m_iLekmodInstantSciencePerPop;
	bool m_bLekmodYieldsOnCityTile;
#endif
#ifdef LEKMOD_MINOR_TRAIT_BUILDINGS
	int m_iLekmodMinorCivTrait;
	CvString m_astrLekmodEraLevel[3];
#endif
	bool m_bNearRiver;
	bool m_bNoMaintenanceOnRiver;
	int m_iRevealResource;
	bool m_bLekmodWorshipHouse;
	int m_iLekmodGreatWorkYieldModifier;
#endif
#ifdef LEKMOD_GREAT_WORK_WONDER_EFFECTS
	std::vector<LekmodGreatWorkFilledYield> m_aLekmodGreatWorkFilledYields;
	std::vector<std::pair<int, int> > m_aLekmodEraHappiness;
	int m_iLekmodGreatWorkFilledGPRateModifier;
#ifdef LEKMOD_SPECS_2026_10_24
	bool m_bLekmodLockedGreatWorkSlots;
	CvString m_strLekmodFreeBuildingThisCityType;
#endif
	int m_iLekmodGreatWorkFilledNearbyTourismMod;
	int m_iLekmodGreatWorkFilledNearbyTourismRange;
	int m_iLekmodNearbyMinorRestingInfluence;
	int m_iLekmodNearbyMinorRange;
	int m_iLekmodNearbyEnemyCombatMod;
	int m_iLekmodNearbyEnemyCombatRange;
	int m_iLekmodClosestCoastalMinorInfluence;
	bool m_bLekmodClosestCoastalMinorTradeQuest;
	int m_iLekmodGoldenAgePopulationChange;
	std::vector<LekmodFreshWaterImprovementYield> m_aLekmodFreshWaterImprovementYields;
#endif
#ifdef LEKMOD_SPY_WONDERS
	int m_iLekmodEnemySpyStealSlower;
	int m_iLekmodGuardLevelChange;
	bool m_bLekmodExecuteCaughtSpies;
	bool m_bLekmodBlockForeignSpies;
	bool m_bLekmodFastSpyEstablish;
	bool m_bLekmodDemographicsBlackout;
	int m_iLekmodSpyReviveTurnsChange; // MI6: dead spies return this many turns sooner (negative)
	bool m_bLekmodStolenScienceGold; // MI6: stolen Science also paid out as Gold
	int m_iLekmodCoupGoldPerEra; // MI6: Gold x (era + 1) for the first successful coup in each City-State
#ifdef LEKMOD_CITY_VISION_BUILDINGS
	int m_iLekmodCityVisionChange; // the city sees this many tiles further, ignoring terrain (Tunisia's Castle)
#endif
	bool m_bLekmodExtraWorldLeaderVote;
#endif
#ifdef LEKMOD_TERRITORY_HEAL
	int m_iTerritoryHealChange;
#endif
	int m_iHappiness;
	int m_iUnmoddedHappiness;
	int m_iUnhappinessModifier;
	int m_iHappinessPerCity;
	int m_iHappinessPerXPolicies;
	int m_iCityCountUnhappinessMod;
	bool m_bNoOccupiedUnhappiness;
	int m_iGlobalPopulationChange;
#ifdef NQ_LOCAL_POPULATION_CHANGE_FROM_BUILDING
	int m_iLocalPopulationChange;
#endif
	int m_iTechShare;
	int m_iFreeTechs;
	int m_iFreePolicies;
	int m_iFreeFlatFaith; // NQMP GJS - New Stonehenge
	int m_iFreeGreatPeople;
	int m_iMedianTechPercentChange;
	int m_iGold;
	bool m_bNearbyMountainRequired;
	bool m_bAllowsRangeStrike;
	int m_iDefenseModifier;
#ifdef NQ_BUILDING_DEFENSE_FROM_CITIZENS
	int m_iDefensePerCitizen;
#endif
	int m_iGlobalDefenseModifier;
	int m_iExtraCityHitPoints;
	int m_iMissionType;
	int m_iMinorFriendshipChange;
	int m_iVictoryPoints;
	int m_iExtraMissionarySpreads;
	int m_iReligiousPressureModifier;
	int m_iEspionageModifier;
	int m_iGlobalEspionageModifier;
	int m_iExtraSpies;
	int m_iSpyRankChange;
	int m_iInstantSpyRankChange;
	int m_iLandmarksTourismPercent;
	int m_iInstantMilitaryIncrease;
	int m_iGreatWorksTourismModifier;
	int m_iXBuiltTriggersIdeologyChoice;
	int m_iTradeRouteRecipientBonus;
	int m_iTradeRouteTargetBonus;
	int m_iNumTradeRouteBonus;
	int m_iTradeRouteSeaDistanceModifier;
	int m_iTradeRouteSeaGoldBonus;
	int m_iTradeRouteLandDistanceModifier;
	int m_iTradeRouteLandGoldBonus;
	int m_iCityStateTradeRouteProductionModifier;
	int m_iCityStateTradeRouteGoldModifier; // NQMP GJS - new Economic Union
	int m_iGreatScientistBeakerModifier;
	int m_iExtraLeagueVotes;
	int m_iExtraLeagueVotesAtomic;
#if defined(LEKMOD_GARRISON_YIELD_EFFECTS)
	int m_iGarrisonStrengthBonus;
	bool m_bGarrisonMaintenanceFree;
#endif
#if defined(LEKMOD_GREAT_WORK_YIELD_EFFECTS)
	int m_iGreatWorkHappiness;
#ifdef LEKMOD_POLICY_REWORK
	bool m_bLekmodPolicyGranted;
#endif
#endif
	int m_iPreferredDisplayPosition;
	int m_iPortraitIndex;

	bool m_bTeamShare;
	bool m_bWater;
	bool m_bRiver;
	bool m_bFreshWater;
#if defined(LEKMOD_BUILDING_LAKE_REQ)
	bool m_bLake;
#endif
	bool m_bMountain;
	bool m_bHill;
	bool m_bFlat;
	bool m_bFoundsReligion;
	bool m_bIsReligious;
	bool m_bBorderObstacle;
	bool m_bPlayerBorderObstacle;
	bool m_bCapital;
	bool m_bGoldenAge;
	bool m_bGrantsFreeCulturalGreatPersonWithTrait; // NQMP GJS - New France UA
	bool m_bMapCentering;
	bool m_bNeverCapture;
	bool m_bNukeImmune;
	bool m_bExtraLuxuries;
	bool m_bDiplomaticVoting;
	bool m_bAllowsWaterRoutes;
	bool m_bCityWall;
	bool m_bUnlockedByBelief;
	bool m_bUnlockedByLeague;
	bool m_bRequiresHolyCity;
	bool m_bAffectSpiesNow;
	bool m_bEspionage;
#ifdef NQ_MALI_TREASURY
	bool m_bMalianTreasury;
#endif
	bool m_bAllowsFoodTradeRoutes;
	bool m_bAllowsProductionTradeRoutes;
	bool m_bNullifyInfluenceModifier;
#if defined(LEKMOD_BUILDING_FIRST_PURCHASE_DISCOUNT)
	int m_iFirstPurchaseDiscount;
#endif

	bool m_bArtInfoCulturalVariation;
	bool m_bArtInfoEraVariation;
	bool m_bArtInfoRandomVariation;

	CvString m_strArtDefineTag;
	CvString m_strWonderSplashAudio;
	CvString m_strThemingBonusHelp;

	// Arrays

	int* m_piLockedBuildingClasses;
	int* m_piPrereqAndTechs;
	int* m_piResourceQuantityRequirements;
	int* m_piResourceQuantity;
#if !defined(LEKMOD_FIX_BUILDING_RESOURCE_YIELD_CHANGE)
	int* m_piResourceCultureChanges;
	int* m_piResourceFaithChanges;
#else
	int** m_paiBuildingLocalResourceYieldChanges;
#endif
	int* m_piProductionTraits;
	int* m_piSeaPlotYieldChange;
	int* m_piRiverPlotYieldChange;
	int* m_piLakePlotYieldChange;
	int* m_piSeaResourceYieldChange;
	int* m_piYieldChange;
	int* m_piYieldChangePerPop;
	int* m_piYieldChangePerReligion;
	int* m_piYieldModifier;
	int* m_piAreaYieldModifier;
	int* m_piGlobalYieldModifier;
	int* m_piTechEnhancedYieldChange;
#if defined(LEKMOD_ERA_ENHANCED_YIELDS)
	int** m_ppiEraEnhancedYieldChange;
#endif
	int* m_piUnitCombatFreeExperience;
#ifdef LEKMOD_GLOBAL_UNITCOMBAT_XP_BUILDINGS
	int* m_piLekmodGlobalUnitCombatFreeExperience;
#endif
	int* m_piUnitCombatProductionModifiers;
#ifdef LEKMOD_v34
	int* m_piUnitCombatProductionCostModifiers;
	int* m_piUnitCombatExtraProduction;
#endif
	int* m_piDomainFreeExperience;
	int* m_piDomainFreeExperiencePerGreatWork;
#if defined(LEKMOD_GREAT_WORK_YIELD_EFFECTS)
	int m_iGreatWorkMilitaryProductionModifier;
	int* m_piBuildingGreatWorkYieldChange;
	int* m_piCityGreatWorkYieldChange;
	int** m_ppiCityGreatWorkClassYieldChange;
#endif
	int* m_piDomainProductionModifier;
	int* m_piPrereqNumOfBuildingClass;
	int* m_piFlavorValue;
	int* m_piLocalResourceAnds;
	int* m_piLocalResourceOrs;
	int* m_paiHurryModifier;

	bool* m_pbBuildingClassNeededInCity;
	int* m_piNumFreeUnits;

	int** m_ppaiResourceYieldChange;
#if defined(TRADE_REFACTOR)
	int** m_ppaiTradeConnectionOriginLandYieldChange;
	int** m_ppaiTradeConnectionOriginSeaYieldChange;
	int** m_ppaiTradeConnectionDestinationLandYieldChange;
	int** m_ppaiTradeConnectionDestinationSeaYieldChange;
	int** m_ppaiIncomingTradeConnectionLandYieldChange;
	int** m_ppaiIncomingTradeConnectionSeaYieldChange;
#endif
	#if defined(MISC_CHANGES) // CvBuildingClasses arrays
	int** m_ppaiResourceClassYieldChange;
#endif
#if defined(LEKMOD_v34)
	int* m_piGarrisonYieldChange;
#endif
#if defined(LEKMOD_AREA_BASED_CITY_YIELD)
	int* m_piSameLandMassYieldChange;
	int* m_piDifferentLandMassYieldChange;
#endif
#if defined(LEKMOD_NEARBY_TERRAIN_FREE_YIELDS)
	std::vector<BuildingFreeTerrainYields> m_aFreeTerrainYields;
#endif
#ifdef LEKMOD_BUILDING_TECH_TERRAIN_YIELDS
	std::vector<LekmodBuildingTechTerrainYield> m_aLekmodTechTerrainYields;
#endif
#ifdef LEKMOD_BUILDING_ADJACENT_CITY_YIELDS
	std::vector<LekmodBuildingAdjacentYield> m_aLekmodAdjacentCityYields;
#endif
#ifdef LEKMOD_CONDITIONAL_BUILDING_YIELDS
	std::vector<LekmodBuildingConditionalYield> m_aLekmodConditionalYields;
#endif
#ifdef LEKMOD_BUILDING_START_TURN_MOVES
	int m_iLekmodStartTurnMovesMountedCivilian;
#endif
#ifdef LEKMOD_CIV_ONLY_BUILDINGS
	int m_iLekmodRequiredCivilization;
	int m_iLekmodPrereqTechOr;
#endif
#ifdef LEKMOD_BUILDING_FILLED_SLOT_TOURISM
	int m_iLekmodGreatWorkFilledTourismModifier;
#endif
#ifdef LEKMOD_BUILDING_PLOT_YIELDS
	std::vector<LekmodBuildingPlotYield> m_aLekmodPlotYields;
#endif
#ifdef LEKMOD_CIV_TRAIT_FLAGS
	bool m_bLekmodFreePlotPurchase;
#endif
#ifdef LEKMOD_CITY_TIMED_BUILDINGS
	std::vector<std::pair<int, std::pair<int, int> > > m_aLekmodLocalSpecialistYields;
	bool m_bLekmodSpreadCapitalReligionOnBuild;
	int m_iLekmodStartTurnMovesAround;
	int m_iLekmodIsolatedPlotCultureCostMod;
	int m_iLekmodIsolatedRange;
	int m_iLekmodTimedBuilding;
	int m_iLekmodTimedBuildingTurns;
	int m_iLekmodWLTKDTurnsOnBuild;
	int m_iLekmodTrainedUnitStackBuilding;
	int m_iLekmodTrainedUnitStackMax;
#endif
	int** m_ppaiFeatureYieldChange;
	std::map<int, std::map<int, int>> m_ppiResourceYieldChangeGlobal;
	int** m_ppaiImprovementYieldChange;
	int** m_ppaiImprovementYieldChangeGlobal;
	int** m_ppaiSpecialistYieldChange;
	int** m_ppaiResourceYieldModifier;
	int** m_ppaiTerrainYieldChange;
	int** m_ppiBuildingClassYieldChanges;
#ifdef LEKMOD_BUILDING_GP_EXPEND_YIELD
	int* m_piGreatPersonExpendYield;
#endif

	int* m_paiBuildingClassHappiness;

	CvThemingBonusInfo* m_paThemingBonusInfo;
	int m_iNumThemingBonuses;
};

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  CLASS:      CvBuildingXMLEntries
//!  \brief		Game-wide information about buildings
//
//! Key Attributes:
//! - Plan is it will be contained in CvGameRules object within CvGame class
//! - Populated from XML\Buildings\CIV5BuildingInfos.xml
//! - Contains an array of CvBuildingEntry from the above XML file
//! - One instance for the entire game
//! - Accessed heavily by CvCityBuildings class (which stores the building state for 1 city)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
class CvBuildingXMLEntries
{
public:
	CvBuildingXMLEntries(void);
	~CvBuildingXMLEntries(void);

	// Accessor functions
	std::vector<CvBuildingEntry*>& GetBuildingEntries();
#ifdef AUI_WARNING_FIXES
	uint GetNumBuildings() const;
	_Ret_maybenull_ CvBuildingEntry* GetEntry(uint index);
#else
	int GetNumBuildings();
	_Ret_maybenull_ CvBuildingEntry* GetEntry(int index);
#endif

	void DeleteArray();

private:
	std::vector<CvBuildingEntry*> m_paBuildingEntries;
};

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  CLASS:      CvCityBuildings
//!  \brief		Information about the buildings constructed in a single city
//
//!  Key Attributes:
//!  - Plan is it will be contained in CvCityState object within CvCity class
//!  - One instance for each city
//!  - Accessed by any class that needs to check building construction status
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
class CvCityBuildings
{
public:
#ifdef AUI_CITY_FIX_COMPONENT_CONSTRUCTORS_CONTAIN_POINTERS
	CvCityBuildings(CvCity* pCity);
#else
	CvCityBuildings(void);
#endif
	~CvCityBuildings(void);
	void Init(CvBuildingXMLEntries* pBuildings, CvCity* pCity);
	void Uninit();
	void Reset();
	void Read(FDataStream& kStream);
	void Write(FDataStream& kStream);

	// Accessor functions
	CvBuildingXMLEntries* GetBuildings() const;

	int GetNumBuildings() const;
	void ChangeNumBuildings(int iChange);

	int GetNumBuilding(BuildingTypes eIndex) const;

	/// CMP
	bool HasBuildingClass(BuildingClassTypes eIndex) const;
	BuildingTypes GetBuildingTypeFromClass(BuildingClassTypes eIndex) const;

	int GetNumActiveBuilding(BuildingTypes eIndex) const;

	bool IsBuildingSellable(const CvBuildingEntry& kBuilding) const;
	void DoSellBuilding(BuildingTypes eIndex);
	int GetSellBuildingRefund(BuildingTypes eIndex) const;

	bool IsSoldBuildingThisTurn() const;
	void SetSoldBuildingThisTurn(bool bValue);

	int GetTotalBaseBuildingMaintenance() const;

	int GetBuildingProduction(BuildingTypes eIndex) const;
	int GetBuildingProductionTimes100(BuildingTypes eIndex) const;
	void SetBuildingProduction(BuildingTypes eIndex, int iNewValue);
	void SetBuildingProductionTimes100(BuildingTypes eIndex, int iNewValue);
	void ChangeBuildingProduction(BuildingTypes eIndex, int iChange);
	void ChangeBuildingProductionTimes100(BuildingTypes eIndex, int iChange);

	int GetBuildingProductionTime(BuildingTypes eIndex) const;
	void SetBuildingProductionTime(BuildingTypes eIndex, int iNewValue);
	void ChangeBuildingProductionTime(BuildingTypes eIndex, int iChange);

	int GetBuildingOriginalOwner(BuildingTypes eIndex) const;
	void SetBuildingOriginalOwner(BuildingTypes eIndex, int iNewValue);
	int GetBuildingOriginalTime(BuildingTypes eIndex) const;
	void SetBuildingOriginalTime(BuildingTypes eIndex, int iNewValue);

	int GetNumRealBuilding(BuildingTypes eIndex) const;
	void SetNumRealBuilding(BuildingTypes eIndex, int iNewValue);
	void SetNumRealBuildingTimed(BuildingTypes eIndex, int iNewValue, bool bFirst, PlayerTypes eOriginalOwner, int iOriginalTime);

	int GetNumFreeBuilding(BuildingTypes eIndex) const;
	void SetNumFreeBuilding(BuildingTypes eIndex, int iNewValue);

	int GetBuildingYieldChange(BuildingClassTypes eBuildingClass, YieldTypes eYield) const;
	void SetBuildingYieldChange(BuildingClassTypes eBuildingClass, YieldTypes eYield, int iChange);
	void ChangeBuildingYieldChange(BuildingClassTypes eBuildingClass, YieldTypes eYield, int iChange);

#ifdef AUI_WARNING_FIXES
	int GetBuildingGreatWork(BuildingClassTypes eBuildingClass, uint iSlot) const;
	void SetBuildingGreatWork(BuildingClassTypes eBuildingClass, uint iSlot, int iGreatWorkIndex);
#else
	int GetBuildingGreatWork(BuildingClassTypes eBuildingClass, int iSlot) const;
	void SetBuildingGreatWork(BuildingClassTypes eBuildingClass, int iSlot, int iGreatWorkIndex);
#endif
	bool IsHoldingGreatWork(BuildingClassTypes eBuildingClass) const;
#ifdef AUI_WARNING_FIXES
	uint GetNumGreatWorksInBuilding(BuildingClassTypes eBuildingClass) const;
#else
	int GetNumGreatWorksInBuilding(BuildingClassTypes eBuildingClass) const;
#endif
  
	bool HasAnyAvailableGreatWorkSlot() const;
	bool HasAvailableGreatWorkSlot(GreatWorkSlotType eGreatWorkSlot) const;
#ifdef AUI_WARNING_FIXES
	uint GetNumAvailableGreatWorkSlots() const;
	uint GetNumAvailableGreatWorkSlots(GreatWorkSlotType eGreatWorkSlot) const;
	bool GetNextAvailableGreatWorkSlot(BuildingClassTypes *eBuildingClass, uint *iSlot) const;
	bool GetNextAvailableGreatWorkSlot(GreatWorkSlotType eGreatWorkSlot, BuildingClassTypes *eBuildingClass, uint *iSlot) const;
#else
	int GetNumAvailableGreatWorkSlots() const;
	int GetNumAvailableGreatWorkSlots(GreatWorkSlotType eGreatWorkSlot) const;
	bool GetNextAvailableGreatWorkSlot(BuildingClassTypes *eBuildingClass, int *iSlot) const;
	bool GetNextAvailableGreatWorkSlot(GreatWorkSlotType eGreatWorkSlot, BuildingClassTypes *eBuildingClass, int *iSlot) const;
#endif

	int GetYieldFromGreatWorks(YieldTypes eIndex) const; // NQMP GJS - Artistic Genius fix to add science to Great Works
	int GetCultureFromGreatWorks() const;
#if !defined(LEKMOD_GREAT_WORK_YIELD_EFFECTS)
	int GetThemingBonuses() const;
#else
	int GetNumGreatWorks(GreatWorkClass eGreatWorkClass) const;
	const std::map<GreatWorkClass, int>& GetGreatWorkClassCounts() const;
	void rebuildGreatWorkYields(GreatWorkClass eGreatWorkClass);
	int countNumThemesActive() const;
	int GetThemingBonuses(YieldTypes eYield) const;
	int GetGreatWorkClassGreatPersonPoints(SpecialistTypes eSpecialist) const;
	int GetHappinessFromGreatWorks() const;
	void calculateHappinessFromGreatWorks();
#endif
#if defined(LEK_YIELD_TOURISM)
	int GetYieldFromLandmarks(YieldTypes eYield) const;
#endif
#ifdef AUI_WARNING_FIXES
	uint GetNumGreatWorks() const;
	uint GetNumGreatWorks(GreatWorkSlotType eGreatWorkSlot) const;
#else
	int GetNumGreatWorks() const;
	int GetNumGreatWorks(GreatWorkSlotType eGreatWorkSlot) const;
#endif

	int GetLandmarksTourismPercent() const;
	void ChangeLandmarksTourismPercent(int iChange);
	int GetGreatWorksTourismModifier() const;
	void ChangeGreatWorksTourismModifier(int iChange);

	int GetThemingBonuses() const;
	int GetNumBuildingsFromFaith() const;

	int GetCityStateTradeRouteProductionModifier() const;
	int GetCityStateTradeRouteGoldModifier() const; // NQMP GJS - new Economic Union

	int GetBuildingProductionModifier() const;
	void ChangeBuildingProductionModifier(int iChange);
#if defined(LEKMOD_AREA_BASED_CITY_YIELD)
	int GetSameLandMassYieldChange(YieldTypes eYield) const;
	void ChangeSameLandMassYieldChange(YieldTypes eYield, int iChange);
	int GetDifferentLandMassYieldChange(YieldTypes eYield) const;
	void ChangeDifferentLandMassYieldChange(YieldTypes eYield, int iChange);
#endif
#if defined(LEKMOD_NEARBY_TERRAIN_FREE_YIELDS)
	int GetFreeTerrainYieldChange(YieldTypes eYield) const;
	void ChangeFreeTerrainYieldChange(YieldTypes eYield, int iChange);
#endif
	int GetBuildingDefense() const;
	void ChangeBuildingDefense(int iChange);
#if defined(LEKMOD_GARRISON_YIELD_EFFECTS)
	int GetGarrisonStrengthBonus() const;
	void ChangeGarrisonStrengthBonus(int iChange);
	bool IsGarrisonMaintenanceFree() const { return m_iGarrisonMaintenanceFreeCount > 0; };
	int getGarrisonMaintenanceFreeCount() const { return m_iGarrisonMaintenanceFreeCount; };
	void ChangeGarrisonMaintenanceFreeCount(int iChange) { m_iGarrisonMaintenanceFreeCount += iChange; };
#endif
#if defined(LEKMOD_BUILDING_FIRST_PURCHASE_DISCOUNT)
	int GetFirstPurchaseDiscount() const { return m_iFirstPurchaseDiscount; };
	void ChangeFirstPurchaseDiscount(int iChange);
#endif
#if defined(LEKMOD_GREAT_WORK_YIELD_EFFECTS)
	int GetCityGreatWorkClassYieldChanges(GreatWorkClass eClass, YieldTypes eYield) const;
	void ChangeCityGreatWorkClassYieldChanges(GreatWorkClass eClass, YieldTypes eYield, int iChange);
	void ChangeCityGreatWorkYieldChange(YieldTypes eYield, int iChange);
#endif
#ifdef NQ_BUILDING_DEFENSE_FROM_CITIZENS
	int GetBuildingDefensePerCitizen() const;
	void ChangeBuildingDefensePerCitizen(int iChange);
#endif
	int GetBuildingDefenseMod() const;
	void ChangeBuildingDefenseMod(int iChange);

	int GetMissionaryExtraSpreads() const;
	void ChangeMissionaryExtraSpreads(int iChange);

	void IncrementWonderStats(BuildingClassTypes eIndex);
	bool CheckForAllWondersBuilt();
	bool CheckForSevenAncientWondersBuilt();

	/// CMP
	const std::vector<BuildingTypes>& GetAllBuildingsHere() const { return m_buildingsThatExistAtLeastOnce; }


private:
	void NotifyNewBuildingStarted(BuildingTypes eIndex);

	int m_iNumBuildings;
	int m_iBuildingProductionModifier;
	int m_iBuildingDefense;
#if defined(LEKMOD_GARRISON_YIELD_EFFECTS)
	int m_iBuildingGarrisonStrengthBonus;
	int m_iGarrisonMaintenanceFreeCount;
#endif
#ifdef NQ_BUILDING_DEFENSE_FROM_CITIZENS
	int m_iBuildingDefensePerCitizen;
#endif
	int m_iBuildingDefenseMod;
	int m_iMissionaryExtraSpreads;
	int m_iLandmarksTourismPercent;
	int m_iGreatWorksTourismModifier;
#if defined(LEKMOD_AREA_BASED_CITY_YIELD)
	int* m_paiSameLandMassYieldChange;
	int* m_paiDifferentLandMassYieldChange;
#endif
#if defined(LEKMOD_NEARBY_TERRAIN_FREE_YIELDS)
	int* m_paiFreeTerrainYieldChange;
#endif
#if defined(LEKMOD_BUILDING_FIRST_PURCHASE_DISCOUNT)
	int m_iFirstPurchaseDiscount;
#endif
	bool m_bSoldBuildingThisTurn;

	int* m_paiBuildingProduction;
	int* m_paiBuildingProductionTime;
	int* m_paiBuildingOriginalOwner;
	int* m_paiBuildingOriginalTime;
	int* m_paiNumRealBuilding;
	int* m_paiNumFreeBuilding;
#if defined(LEKMOD_GREAT_WORK_YIELD_EFFECTS)
	mutable std::map<GreatWorkClass, int> m_cachedGreatWorkClassCounts;
	mutable bool m_bGreatWorkClassMapDirty;
	int m_iHappinessFromGreatWorks;
	std::vector< Firaxis::Array<int, NUM_YIELD_TYPES > > m_aaiCityGreatWorkClassYieldChange;
#endif
/// CMP

	std::vector<BuildingTypes> m_buildingsThatExistAtLeastOnce;
	///

	std::vector<BuildingYieldChange> m_aBuildingYieldChange;
	std::vector<BuildingGreatWork> m_aBuildingGreatWork;

	CvBuildingXMLEntries* m_pBuildings;
	CvCity* m_pCity;
};

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Helper Functions to serialize arrays of variable length (based on number of buildings defined in game)
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
namespace BuildingArrayHelpers
{
void Read(FDataStream& kStream, int* paiBuildingArray);
void Write(FDataStream& kStream, int* paiBuildingArray, int iArraySize);
}

#endif //CIV5_BUILDING_CLASSES_H