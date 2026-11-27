@ECHO off
pushd "%~dp0"
set patchfolder=%cd%
cd ..
IF EXIST "%patchfolder%\Lua\UI\CityStatePersonalityHelper.lua" (
  copy /y "%patchfolder%\Lua\UI\CityStatePersonalityHelper.lua" "%patchfolder%\CityStatePersonalityHelper.lua.bak" > nul
)
IF EXIST "%patchfolder%\Lua\UI\LegalScreen.lua" (
  copy /y "%patchfolder%\Lua\UI\LegalScreen.lua" "%patchfolder%\LegalScreen.lua.bak" > nul
)
IF EXIST "%patchfolder%\Lua\UI\LegalScreen.xml" (
  copy /y "%patchfolder%\Lua\UI\LegalScreen.xml" "%patchfolder%\LegalScreen.xml.bak" > nul
)
DEL /q "%patchfolder%\Lua\UI\"
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\AncientRuins\GoodyHutPopup.lua.ignore" "%patchfolder%\Lua\UI\GoodyHutPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\AncientRuins\GoodyHutPopup.xml.ignore" "%patchfolder%\Lua\UI\GoodyHutPopup.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\AncientRuins\ChooseGoodyHutReward.lua.ignore" "%patchfolder%\Lua\UI\ChooseGoodyHutReward.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\AncientRuins\ChooseGoodyHutReward.xml.ignore" "%patchfolder%\Lua\UI\ChooseGoodyHutReward.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Religion\ChooseReligionPopup.lua.ignore" "%patchfolder%\Lua\UI\ChooseReligionPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Religion\ChooseReligionPopup.xml.ignore" "%patchfolder%\Lua\UI\ChooseReligionPopup.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Religion\ChoosePantheonPopup.lua.ignore" "%patchfolder%\Lua\UI\ChoosePantheonPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Religion\ChoosePantheonPopup.xml.ignore" "%patchfolder%\Lua\UI\ChoosePantheonPopup.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Civilopedia\CivilopediaScreen.lua.ignore" "%patchfolder%\Lua\UI\CivilopediaScreen.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Civilopedia\CivilopediaScreen.xml.ignore" "%patchfolder%\Lua\UI\CivilopediaScreen.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\LeagueOverview\LeagueOverview.lua.ignore" "%patchfolder%\Lua\UI\LeagueOverview.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Espionage\EspionageOverview.lua.ignore" "%patchfolder%\Lua\UI\EspionageOverview.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Espionage\EspionageOverview.xml.ignore" "%patchfolder%\Lua\UI\EspionageOverview.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\CityBanners\CityBannerManager.lua.ignore" "%patchfolder%\Lua\UI\CityBannerManager.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CityBanners\CityBannerManager.xml.ignore" "%patchfolder%\Lua\UI\CityBannerManager.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\CityStatePopup\CityStateDiploPopup.lua.ignore" "%patchfolder%\Lua\UI\CityStateDiploPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CityStatePopup\CityStateDiploPopup.xml.ignore" "%patchfolder%\Lua\UI\CityStateDiploPopup.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\CityView\CityView.lua.ignore" "%patchfolder%\Lua\UI\CityView.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CityView\CityView.xml.ignore" "%patchfolder%\Lua\UI\CityView.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CityView\CityView_small.xml.ignore" "%patchfolder%\Lua\UI\CityView_small.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CityView\ProductionPopup.lua.ignore" "%patchfolder%\Lua\UI\ProductionPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CityView\ProductionPopup.xml.ignore" "%patchfolder%\Lua\UI\ProductionPopup.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\Core\CityStateStatusHelper.lua.ignore" "%patchfolder%\Lua\UI\CityStateStatusHelper.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Core\IconSupport.lua.ignore" "%patchfolder%\Lua\UI\IconSupport.lua" > nul
IF NOT EXIST "%patchfolder%\Lua\UI\IconSupport.lua" (
  copy /y "%patchfolder%\Lua\tmp\ui\Core\IconSupport.lua" "%patchfolder%\Lua\UI\IconSupport.lua" > nul
)
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\CultureOverview\CultureOverview.lua.ignore" "%patchfolder%\Lua\UI\CultureOverview.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CultureOverview\CultureOverview.xml.ignore" "%patchfolder%\Lua\UI\CultureOverview.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CultureOverview\EconomicGeneralInfo.lua.ignore" "%patchfolder%\Lua\UI\EconomicGeneralInfo.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\CultureOverview\EconomicGeneralInfo.xml.ignore" "%patchfolder%\Lua\UI\EconomicGeneralInfo.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\EULA.lua.ignore" "%patchfolder%\Lua\UI\EULA.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\FrontEnd.lua.ignore" "%patchfolder%\Lua\UI\FrontEnd.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\MainMenu.lua.ignore" "%patchfolder%\Lua\UI\MainMenu.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\MainMenu.xml.ignore" "%patchfolder%\Lua\UI\MainMenu.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\MultiplayerSelect.lua.ignore" "%patchfolder%\Lua\UI\MultiplayerSelect.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\MultiplayerSelect.xml.ignore" "%patchfolder%\Lua\UI\MultiplayerSelect.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\OtherMenu.lua.ignore" "%patchfolder%\Lua\UI\OtherMenu.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\OtherMenu.xml.ignore" "%patchfolder%\Lua\UI\OtherMenu.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\LoadScreen.lua.ignore" "%patchfolder%\Lua\UI\LoadScreen.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\FrontEnd\LoadScreen.xml.ignore" "%patchfolder%\Lua\UI\LoadScreen.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\GameSetup\UniqueBonuses.lua.ignore" "%patchfolder%\Lua\UI\UniqueBonuses.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\GameSetup\GameSetupScreen.lua.ignore" "%patchfolder%\Lua\UI\GameSetupScreen.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\GameSetup\SelectCivilization.lua.ignore" "%patchfolder%\Lua\UI\SelectCivilization.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\GameSetup\SelectCivilization.xml.ignore" "%patchfolder%\Lua\UI\SelectCivilization.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\GPList\GPList.lua.ignore" "%patchfolder%\Lua\UI\GPList.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\GPList\GPList.xml.ignore" "%patchfolder%\Lua\UI\GPList.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\Improvements\WorldView.lua.ignore" "%patchfolder%\Lua\UI\WorldView.lua" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\LeaderHead\TradeLogic.lua.ignore" "%patchfolder%\Lua\UI\TradeLogic.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\LeaderHead\SimpleDiploTrade.lua.ignore" "%patchfolder%\Lua\UI\SimpleDiploTrade.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\LeaderHead\SimpleDiploTrade.xml.ignore" "%patchfolder%\Lua\UI\SimpleDiploTrade.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\AdvancedSetup.lua.ignore" "%patchfolder%\Lua\UI\AdvancedSetup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\JoiningRoom.lua.ignore" "%patchfolder%\Lua\UI\JoiningRoom.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\JoiningRoom.xml.ignore" "%patchfolder%\Lua\UI\JoiningRoom.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\LoadMenu.lua.ignore" "%patchfolder%\Lua\UI\LoadMenu.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\Lobby.lua.ignore" "%patchfolder%\Lua\UI\Lobby.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\Lobby.xml.ignore" "%patchfolder%\Lua\UI\Lobby.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\MPGameOptions.lua.ignore" "%patchfolder%\Lua\UI\MPGameOptions.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\MPGameSetupScreen.lua.ignore" "%patchfolder%\Lua\UI\MPGameSetupScreen.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\MPGameSetupScreen.xml.ignore" "%patchfolder%\Lua\UI\MPGameSetupScreen.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\StagingRoom.lua.ignore" "%patchfolder%\Lua\UI\StagingRoom.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Lobby\StagingRoom.xml.ignore" "%patchfolder%\Lua\UI\StagingRoom.xml" > nul
 copy /y "%patchfolder%\Lua\tmp\ui\PlotMouseoverInclude.lua.ignore" "%patchfolder%\Lua\UI\PlotMouseoverInclude.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\PlotHelpText.lua.ignore" "%patchfolder%\Lua\UI\PlotHelpText.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\PlotHelpText.xml.ignore" "%patchfolder%\Lua\UI\PlotHelpText.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\MilitaryOverview\MilitaryOverview.lua.ignore" "%patchfolder%\Lua\UI\MilitaryOverview.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\MilitaryOverview\MilitaryOverview.xml.ignore" "%patchfolder%\Lua\UI\MilitaryOverview.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\MiniMapPanel\MiniMapPanel.lua.ignore" "%patchfolder%\Lua\UI\MiniMapPanel.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\MiniMapPanel\MiniMapPanel.xml.ignore" "%patchfolder%\Lua\UI\MiniMapPanel.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\MPTurnPanel\MPTurnPanel.lua.ignore" "%patchfolder%\Lua\UI\MPTurnPanel.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\MPTurnPanel\MPTurnPanel.xml.ignore" "%patchfolder%\Lua\UI\MPTurnPanel.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\NotificationPanel\DiploCorner.lua.ignore" "%patchfolder%\Lua\UI\DiploCorner.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\NotificationPanel\DiploCorner.xml.ignore" "%patchfolder%\Lua\UI\DiploCorner.xml" > nul
REM --------------------------------------------------------------------------------------------------
REM LEKMOD (2026-10-27): GenericPopup includes LekmodAnnexCityPopup (Raze on puppets); standard UI only
copy /y "%patchfolder%\Lua\tmp\ui\Popups\GenericPopup.lua.ignore" "%patchfolder%\Lua\UI\GenericPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\NotificationPanel\DiploList.lua.ignore" "%patchfolder%\Lua\UI\DiploList.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\NotificationPanel\NotificationPanel.lua.ignore" "%patchfolder%\Lua\UI\NotificationPanel.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\NotificationPanel\NotificationPanel.xml.ignore" "%patchfolder%\Lua\UI\NotificationPanel.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\Options\OptionsMenu.lua.ignore" "%patchfolder%\Lua\UI\OptionsMenu.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Options\OptionsMenu.xml.ignore" "%patchfolder%\Lua\UI\OptionsMenu.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\Replays\Demographics.lua.ignore" "%patchfolder%\Lua\UI\Demographics.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Replays\Demographics.xml.ignore" "%patchfolder%\Lua\UI\Demographics.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Replays\GameMenu.lua.ignore" "%patchfolder%\Lua\UI\GameMenu.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Replays\ReplayViewer.lua.ignore" "%patchfolder%\Lua\UI\ReplayViewer.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Replays\ReplayViewer.xml.ignore" "%patchfolder%\Lua\UI\ReplayViewer.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\TechTree\TechPopup.lua.ignore" "%patchfolder%\Lua\UI\TechPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\TechTree\TechTree.lua.ignore" "%patchfolder%\Lua\UI\TechTree.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\TechTree\TechTree.xml.ignore" "%patchfolder%\Lua\UI\TechTree.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\TechTree\TechHelpInclude.lua.ignore" "%patchfolder%\Lua\UI\TechHelpInclude.lua" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\ToolTips\TechButtonInclude.lua.ignore" "%patchfolder%\Lua\UI\TechButtonInclude.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\ToolTips\InfoTooltipInclude.lua.ignore" "%patchfolder%\Lua\UI\InfoTooltipInclude.lua" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\UnitFlagManager\UnitFlagManager.lua.ignore" "%patchfolder%\Lua\UI\UnitFlagManager.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\UnitFlagManager\UnitFlagManager.xml.ignore" "%patchfolder%\Lua\UI\UnitFlagManager.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\UnitList\UnitList.lua.ignore" "%patchfolder%\Lua\UI\UnitList.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\UnitList\UnitList.xml.ignore" "%patchfolder%\Lua\UI\UnitList.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\UnitPanel\EnemyUnitPanel.lua.ignore" "%patchfolder%\Lua\UI\EnemyUnitPanel.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\UnitPanel\EnemyUnitPanel.xml.ignore" "%patchfolder%\Lua\UI\EnemyUnitPanel.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\UnitPanel\EnemyUnitPanel_small.xml.ignore" "%patchfolder%\Lua\UI\EnemyUnitPanel_small.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\UnitPanel\UnitPanel.lua.ignore" "%patchfolder%\Lua\UI\UnitPanel.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\UnitPanel\UnitPanel.xml.ignore" "%patchfolder%\Lua\UI\UnitPanel.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\UnitPanel\UnitPanel_small.xml.ignore" "%patchfolder%\Lua\UI\UnitPanel_small.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\VotingSystem\CCVotePopup.lua.ignore" "%patchfolder%\Lua\UI\CCVotePopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\VotingSystem\CCVotePopup.xml.ignore" "%patchfolder%\Lua\UI\CCVotePopup.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\VotingSystem\NetworkKickedPopup.lua.ignore" "%patchfolder%\Lua\UI\NetworkKickedPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\VotingSystem\ProposalChartPopup.lua.ignore" "%patchfolder%\Lua\UI\ProposalChartPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\VotingSystem\ProposalChartPopup.xml.ignore" "%patchfolder%\Lua\UI\ProposalChartPopup.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\VotingSystem\VictoryProgress.lua.ignore" "%patchfolder%\Lua\UI\VictoryProgress.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\VotingSystem\VictoryProgress.xml.ignore" "%patchfolder%\Lua\UI\VictoryProgress.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\Bombardment.lua.ignore" "%patchfolder%\Lua\UI\Bombardment.lua" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\DiscussionDialog.lua.ignore" "%patchfolder%\Lua\UI\DiscussionDialog.lua" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\EndGameMenu.lua.ignore" "%patchfolder%\Lua\UI\EndGameMenu.lua" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\Highlights.xml.ignore" "%patchfolder%\Lua\UI\Highlights.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\InGame.lua.ignore" "%patchfolder%\Lua\UI\InGame.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\ActionInfoPanel.lua.ignore" "%patchfolder%\Lua\UI\ActionInfoPanel.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\ActionInfoPanel.xml.ignore" "%patchfolder%\Lua\UI\ActionInfoPanel.xml" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\prophetreplace.lua.ignore" "%patchfolder%\Lua\UI\prophetreplace.lua" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\YieldIconManager.lua.ignore" "%patchfolder%\Lua\UI\YieldIconManager.lua" > nul
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\TopPanel.lua.ignore" "%patchfolder%\Lua\UI\TopPanel.lua" > nul
REM --------------------------------------------------------------------------------------------------
REM --------------------------------------------------------------------------------------------------
REM LEKMOD (2026-11-26): no EUI support. These are plain copies of base-game screens that EUI replaces by file name;
REM Lekmod Scion loads with a higher priority than EUI, so with these (and our own screens) no EUI file is ever used.
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\CityStateGreetingPopup.lua.ignore" "%patchfolder%\Lua\UI\CityStateGreetingPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\ConfirmCityTaskPopup.lua.ignore" "%patchfolder%\Lua\UI\ConfirmCityTaskPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\ConfirmCommandPopup.lua.ignore" "%patchfolder%\Lua\UI\ConfirmCommandPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\DiploList.xml.ignore" "%patchfolder%\Lua\UI\DiploList.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\DiploTrade.lua.ignore" "%patchfolder%\Lua\UI\DiploTrade.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\GameSetupScreen.xml.ignore" "%patchfolder%\Lua\UI\GameSetupScreen.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\LeaderHeadRoot.lua.ignore" "%patchfolder%\Lua\UI\LeaderHeadRoot.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\LeaderHeadRoot.xml.ignore" "%patchfolder%\Lua\UI\LeaderHeadRoot.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\PlotHelpManager.lua.ignore" "%patchfolder%\Lua\UI\PlotHelpManager.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\PlotHelpManager.xml.ignore" "%patchfolder%\Lua\UI\PlotHelpManager.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\TechPopup.xml.ignore" "%patchfolder%\Lua\UI\TechPopup.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\TopPanel.xml.ignore" "%patchfolder%\Lua\UI\TopPanel.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\WorldView.xml.ignore" "%patchfolder%\Lua\UI\WorldView.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\BaseGame\YieldIconManager.xml.ignore" "%patchfolder%\Lua\UI\YieldIconManager.xml" > nul
IF EXIST "%patchfolder%\CityStatePersonalityHelper.lua.bak" (
  copy /y "%patchfolder%\CityStatePersonalityHelper.lua.bak" "%patchfolder%\Lua\UI\CityStatePersonalityHelper.lua" > nul
  del "%patchfolder%\CityStatePersonalityHelper.lua.bak"
)
IF EXIST "%patchfolder%\LegalScreen.lua.bak" (
  copy /y "%patchfolder%\LegalScreen.lua.bak" "%patchfolder%\Lua\UI\LegalScreen.lua" > nul
  del "%patchfolder%\LegalScreen.lua.bak"
)
IF EXIST "%patchfolder%\LegalScreen.xml.bak" (
  copy /y "%patchfolder%\LegalScreen.xml.bak" "%patchfolder%\Lua\UI\LegalScreen.xml" > nul
  del "%patchfolder%\LegalScreen.xml.bak"
)
echo LekmodUiConfigured = true> "%patchfolder%\Lua\UI\LekmodUiConfigured.lua"
echo LekmodUiConfigured = true> "%patchfolder%\Lua\Utilities\LekmodUiConfigured.lua"
set "LEKMOD_FRONTEND=%patchfolder%\Lua\UI\FrontEnd.lua"
powershell -NoProfile -Command "$p=$env:LEKMOD_FRONTEND; if([IO.File]::Exists($p)){ $c=[IO.File]::ReadAllText($p); $n=$c.Replace('local LEKMOD_UI_CHECK_DONE = false','local LEKMOD_UI_CHECK_DONE = true'); if($n -ne $c){ [IO.File]::WriteAllText($p,$n) } }"
REM --------------------------------------------------------------------------------------------------
copy /y "%patchfolder%\Lua\tmp\ui\Popups\SocialPolicyPopup.lua.ignore" "%patchfolder%\Lua\UI\SocialPolicyPopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Popups\SocialPolicyPopup.xml.ignore" "%patchfolder%\Lua\UI\SocialPolicyPopup.xml" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Popups\ChooseInternationalTradeRoutePopup.lua.ignore" "%patchfolder%\Lua\UI\ChooseInternationalTradeRoutePopup.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\Popups\TradeRouteOverview.lua.ignore" "%patchfolder%\Lua\UI\TradeRouteOverview.lua" > nul
copy /y "%patchfolder%\Lua\tmp\ui\ToolTips\TradeRouteHelpers.lua.ignore" "%patchfolder%\Lua\UI\TradeRouteHelpers.lua" > nul
REM --------------------------------------------------------------------------------------------------
EXIT