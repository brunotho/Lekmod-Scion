"""UB tooltip audit (POST 2026-10-16, done 2026-10-17): every unique building's Help in the layout
'Replaces the X. <cost / availability>' + 'Like the X:' (what it shares) + 'In addition:' (its own effects).
Written from tools/dev/ubdiff.py against the loaded DB. Rerunnable: it sets the Help texts (all definitions of each tag).
usage: python tools/dev/ub_texts_2026_10_17.py
"""
import re
import sqlite3
import os

T = r"C:/Users/bbruno/civ-tools/lek/LEKMOD/Override/CIV5Units_Mongol.xml"
DB = os.path.expanduser("~/Documents/My Games/Sid Meier's Civilization 5/cache/Civ5DebugDatabase.db")

N = "[NEWLINE]"
P, F, G, C, S, R, H, TO, GP = ("[ICON_PRODUCTION] Production", "[ICON_FOOD] Food", "[ICON_GOLD] Gold", "[ICON_CULTURE] Culture",
                               "[ICON_RESEARCH] Science", "[ICON_PEACE] Faith", "[ICON_HAPPINESS_1] Happiness", "[ICON_TOURISM] Tourism",
                               "[ICON_GREAT_PEOPLE] Great People generation")
NW = "[COLOR_CULTURE_STORED]* Unique National Wonder (only a specific civ may build one)[ENDCOLOR]"


def ub(first, like_name, like, extra, header=None):
    parts = []
    if header:
        parts.append(header)
    parts.append(first)
    if like:
        parts.append("Like the %s:%s%s" % (like_name, N, N.join(like)))
    if extra:
        parts.append("In addition:" + N + N.join(extra))
    return (N + N).join(parts)


# what the base buildings do (Lekmod values, quick speed)
GW_TOURISM = "Great Works in this city yield +1 %s." % TO
ART_SLOT = "1 slot for a Great Work of Art or an Artifact."
LIBRARY = ["+1 %s for every 2 [ICON_CITIZEN] Citizens in this city." % S]
MARKET_TRADE = "Trade routes other players make to this city give you +1 %s and the route's owner +1 %s." % (G, G)
WALLS = ["Makes the city harder to capture: more Defense and Hit Points, faster healing, and damage to enemy units next to the city.",
         "Strongest on a Hill or next to a Mountain."]
STABLE = ["+15%% %s when building Mounted units." % P,
          "[ICON_RES_HORSE] Horses, [ICON_RES_SHEEP] Sheep and [ICON_RES_COW] Cattle worked by this city yield +1 %s; [ICON_RES_MAIZE] Maize +1 %s." % (P, F)]
STABLE_NEED = "City must have one of these resources improved."
GRANARY = ["+2 %s." % F,
           "[ICON_RES_WHEAT] Wheat, [ICON_RES_BANANA] Bananas, [ICON_RES_DEER] Deer and [ICON_RES_BISON] Bison worked by this city yield +1 %s." % F,
           "Allows %s trade routes from this city to your other cities." % F]
CARAVANSARY = ["+2 %s." % G, "Land trade routes from this city reach 50%% farther and give +2 %s when they go to another civilization." % G]
TEMPLE = ["+2 %s." % R]
AMPHI = ["+2 %s." % C, ART_SLOT, GW_TOURISM]
COLOSSEUM = ["+2 %s (no more than the city has [ICON_CITIZEN] Citizens)." % H]
WORKSHOP = ["+2 %s and +10%% %s." % (P, P), "1 Engineer specialist slot.", "Allows %s trade routes from this city to your other cities." % P]
WATERMILL_NEED = "City must be next to a river."
CASTLE = ["More Defense and Hit Points, faster healing, +3 [ICON_STRENGTH] City Strength next to a Mountain.", "Provides 3 [ICON_RES_HORSE] Horses."]
OPERA = AMPHI
BANK = ["+2 %s and +25%% %s." % (G, G), "1 Merchant specialist slot.", MARKET_TRADE]

TEXTS = {
    "BUILDING_AKKAD_LIBRARY": ub("Replaces the Library. Costs less and needs no %s maintenance." % G, "Library", LIBRARY,
                                 ["+1 %s." % S]),
    "BUILDING_ASKUM_NATIONAL_EPIC": ub("Replaces the National Epic.", "National Epic",
                                       ["[ICON_GREAT_WORK] 3 Great Work slots, 2 of them come filled.", "All 3 slots filled: +25%% %s in this city." % GP,
                                        "Must have built a Monument in all cities.", "The cost goes up the more cities there are in the empire."],
                                       ["+4 %s." % R, "Every Monument in the empire yields +1 %s, +1 %s, +1 %s and +1 %s." % (F, P, R, G)], NW),
    "BUILDING_BAZAAR": ub("Replaces the Market.", "Market", ["+25%% %s." % G, "1 Merchant specialist slot.", MARKET_TRADE],
                          ["+2 %s (instead of +1) and +1 %s." % (G, H), "Luxury resources worked by this city yield +1 %s." % G,
                           "[ICON_RES_OIL] Oil and Oasis tiles worked by this city yield +2 %s." % G]),
    "BUILDING_ARGENTINA_STABLE": ub("Replaces the Stable. Needs no %s maintenance." % G, "Stable", STABLE + [STABLE_NEED],
                                    ["[ICON_RES_HORSE] Horses, [ICON_RES_SHEEP] Sheep and [ICON_RES_COW] Cattle also yield +1 %s; [ICON_RES_MAIZE] Maize +1 %s." % (F, P)]),
    "BUILDING_ARMENIA_OBSERVATORY": ub("Replaces the Observatory.", "Observatory",
                                       ["+4 %s." % S, "Mountains worked by this city yield +5 %s (mountain Natural Wonders too)." % S,
                                        "Tundra worked by this city yields +1 %s." % S],
                                       ["+4 %s." % C, "Mountains worked by this city also yield +2 %s (mountain Natural Wonders too)." % C]),
    "BUILDING_ROYAL_LIBRARY": ub("Replaces the Library.", "Library", LIBRARY,
                                 ["+1 %s and +1 %s." % (S, C), ART_SLOT]),
    "BUILDING_COFFEE_HOUSE": ub("Replaces the Windmill. Costs much less and is available with Printing Press (instead of Economics).", "Windmill",
                                ["+2 %s." % P, "1 Engineer specialist slot.", "Lake and Oasis tiles worked by this city yield +1 %s." % P],
                                ["+5%% %s (instead of +10%% %s towards buildings)." % (P, P), "+20%% %s in this city." % GP]),
    "BUILDING_AYYUBIDS_UNIVERSITY": ub("Replaces the University.", "University",
                                       ["+33%% %s." % S, "2 Scientist specialist slots.", "Jungle tiles worked by this city yield +2 %s." % S,
                                        "Allows Archaeologists to be built in this city.", "City must have a Library."],
                                       ["Flood Plains worked by this city yield +1 %s, Oasis tiles +2 %s." % (S, S), "Gives 30 %s once when it is built." % R]),
    "BUILDING_FLOATING_GARDENS": ub("Replaces the Water Mill. Costs 1 %s maintenance (instead of 2). City must be next to a river or a lake (instead of a river)." % G,
                                    "Water Mill", ["+2 %s and +1 %s." % (F, P)],
                                    ["+10%% %s." % F, "Lake tiles worked by this city yield +1 %s." % F]),
    "BUILDING_WALLS_OF_BABYLON": ub("Replaces the Walls. Costs less.", "Walls", WALLS,
                                    ["+5 Defense (instead of +4).", "+1 %s and +1 %s." % (R, S), "Buying tiles in this city costs 25%% less %s." % G]),
    "BUILDING_BELGIUM_ZOO": ub("Replaces the Zoo. Costs less, needs no %s maintenance and no Colosseum." % G, "Zoo", [],
                               ["+3 %s (instead of +2; no more than the city has [ICON_CITIZEN] Citizens)." % H, "+1 %s and +1 %s." % (C, G)]),
    "BUILDING_BOERS_OPERA_HOUSE": ub("Replaces the Opera House. Costs less.", "Opera House", [ART_SLOT, GW_TOURISM],
                                     ["+3 %s (instead of +2)." % C, "1 Artist specialist slot."]),
    "BUILDING_KHAMBAR": ub("Replaces the Granary. Costs less.", "Granary", GRANARY,
                           ["[ICON_RES_COW] Cattle and [ICON_RES_WHEAT] Wheat worked by this city yield +1 %s." % G]),
    "BUILDING_KYAWWAT": ub("Replaces the Stone Works. Needs no improved resource near the city.", "Stone Works",
                           ["+1 %s and +1 %s." % (P, H), "[ICON_RES_MARBLE] Marble, [ICON_RES_OBSIDIAN] Obsidian and [ICON_RES_STONE] Stone worked by this city yield +1 %s." % P],
                           ["[ICON_RES_SALT] Salt and [ICON_RES_IRON] Iron worked by this city yield +1 %s." % P]),
    "BUILDING_HIPPODROME": ub("Replaces the Amphitheater. Needs no %s maintenance." % G, "Amphitheater", [ART_SLOT, GW_TOURISM],
                              ["+3 %s (instead of +2) and +3 %s." % (C, R)]),
    "BUILDING_TIMMYS": ub("Replaces the Stock Exchange. Costs less.", "Stock Exchange",
                          ["+3 %s and +25%% %s." % (G, G), "2 Merchant specialist slots.", MARKET_TRADE, "City must have a Bank."],
                          ["+2 %s." % H, "River tiles worked by this city yield +1 %s." % G]),
    "BUILDING_COTHON": ub("Replaces the Lighthouse. Costs less. Can also be built in a city next to a lake.", "Lighthouse",
                          ["[ICON_RES_FISH] Fish worked by this city yield +1 %s." % F,
                           "[ICON_RES_AMBER] Amber and Atolls worked by this city yield +1 %s." % C,
                           "Coast tiles worked by this city yield +1 %s." % P, "Buying tiles in this city costs 33%% less %s." % G],
                          ["Its +1 %s on Coast tiles needs no Construction." % P]),
    "BUILDING_SILVERSMITH": ub("Replaces the Mint. Costs less and needs no mined resource near the city.", "Mint",
                               ["[ICON_RES_GOLD] Gold, [ICON_RES_SILVER] Silver and [ICON_RES_COPPER] Copper worked by this city yield +2 %s." % G,
                                "Mountains worked by this city yield +2 %s (not Natural Wonders)." % G],
                               ["+1 %s (instead of +2) and +2 %s." % (G, P)]),
    "BUILDING_COOPERATIVE": ub("Replaces the Factory. Needs no %s maintenance." % G, "Factory",
                               ["+4 %s and +10%% %s." % (P, P), "[ICON_RES_RUBBER] Rubber worked by this city yields +2 %s." % G,
                                "Needs 2 [ICON_RES_COAL] Coal and 1 [ICON_RES_IRON] Iron.", "City must have a Workshop."],
                               ["+2 %s." % H, "3 Engineer specialist slots (instead of 2).", "1 Cooperative is enough to choose an Ideology (instead of 3 Factories)."]),
    "BUILDING_PAPER_MAKER": ub("Replaces the Library. Needs no %s maintenance." % G, "Library", LIBRARY, ["+2 %s." % G]),
    "BUILDING_COLOMBIAN_GRANARY": ub("Replaces the Granary. Costs a bit more and needs no %s maintenance." % G, "Granary", GRANARY,
                                     ["+1 %s." % P, "Allows %s trade routes from this city to your other cities." % P]),
    "BUILDING_DANCE_HALL": ub("Replaces the Opera House. Costs less.", "Opera House", [ART_SLOT, GW_TOURISM],
                              ["+3 %s (instead of +2)." % C, "Its Great Work slot filled: +20%% %s in this city." % TO, "Units trained in this city start with +15 XP."]),
    "BUILDING_CZECHIA_MINT": ub("Replaces the Mint. Costs less.", "Mint",
                                ["+2 %s." % G, "[ICON_RES_GOLD] Gold, [ICON_RES_SILVER] Silver and [ICON_RES_COPPER] Copper worked by this city yield +2 %s." % G,
                                 "Mountains worked by this city yield +2 %s (not Natural Wonders)." % G, "City must have one of these resources mined nearby."],
                                ["[ICON_RES_IRON] Iron worked by this city yields +2 %s, and a mined Iron also counts for the requirement." % G,
                                 "1 Merchant specialist slot."]),
    "BUILDING_LEKMOD_RUNESTONE": ub("Replaces the Shrine. Costs more.", "Shrine", [],
                                    ["+2 %s (instead of +1)." % R, "Units trained in this city start with +5 XP."]),
    "BUILDING_BURIAL_TOMB": ub("Replaces the Temple. Costs less, is available with Construction (instead of Philosophy) and needs no Shrine.", "Temple", [],
                               ["+3 %s (instead of +2)." % R]),
    "BUILDING_LEKMOD_FULLING_MILL": ub("Replaces the Water Mill.", "Water Mill", ["+2 %s and +1 %s." % (F, P), WATERMILL_NEED],
                                       ["[ICON_RES_SHEEP] Sheep, [ICON_RES_COTTON] Cotton, [ICON_RES_DYE] Dyes and [ICON_RES_SILK] Silk next to the city yield +1 %s." % P]),
    "BUILDING_LEKMOD_MI6": ub("Replaces the National Intelligence Agency.", "National Intelligence Agency",
                              ["Provides 1 more spy and levels up all your existing spies.", "Enemy spies are 15% less effective.",
                               "Must have a Constabulary in all cities."],
                              ["A dead [ICON_SPY] Spy is replaced 1 turn sooner.", "%s stolen by your spies also gives the same amount of %s." % (S, G),
                               "The first successful coup in each [ICON_CITY_STATE] City-State gives 150 %s per era (150 in the Ancient Era, 300 in the Classical Era, ...)." % G],
                              "[COLOR_CYAN]* National Wonder (each player may build one)[ENDCOLOR]"),
    "BUILDING_STELE": ub("Replaces the Monument.", "Monument", ["+2 %s." % C], ["+2 %s." % R]),
    "BUILDING_FINNISH_SAUNA": ub("Replaces the Shrine. Costs less and needs no %s maintenance." % G, "Shrine", ["+1 %s." % R],
                                 ["Lake tiles worked by this city yield +2 %s." % C, "Snow tiles of the city next to a lake yield +2 %s and +2 %s." % (F, C),
                                  "Units trained in this city heal +10 HP per turn in your territory."]),
    "BUILDING_LEKMOD_EIFFEL_TOWER_FRANCE": ub("France's Eiffel Tower: twice the yields.", "Eiffel Tower", ["Comes with a free Broadcast Tower."],
                                              ["+2 %s (instead of +1)." % C,
                                               "+30 %s and +6 %s in the Modern Era (instead of +15 and +3)." % (TO, H),
                                               "+60 %s and +12 %s in the Atomic Era (instead of +30 and +6)." % (TO, H),
                                               "+120 %s and +24 %s in the Information Era (instead of +60 and +12)." % (TO, H)]),
    "BUILDING_MEADHALLL": ub("Replaces the Colosseum. Costs less and needs no %s maintenance." % G, "Colosseum", [],
                             ["+3 %s (instead of +2; no more than the city has [ICON_CITIZEN] Citizens)." % H, "+1 %s." % C]),
    "BUILDING_MURUS_GALLICUS": ub("Replaces the Walls. Costs less.", "Walls", WALLS,
                                  ["+5 Defense (instead of +4).", "+1 %s." % H, "+1 %s, +1 more with Metal Casting." % P]),
    "BUILDING_GEORGIA_TSIKHE": ub("Replaces the Walls.", "Walls", WALLS,
                                  ["+3 %s." % R, "Strategic resources worked by this city yield +1 %s." % C,
                                   "Units trained in this city earn [ICON_GOLDEN_AGE] Golden Age points equal to the Strength of the Pre-Industrial units they kill."]),
    "BUILDING_HANSE": ub("Replaces the Bank.", "Bank", BANK + ["City must have a Market."],
                         ["+5%% %s for each trade route your civilization has with a City-State." % P,
                          "Whoever receives a [ICON_INTERNATIONAL_TRADE] Trade Route from this city gets +2 %s per era (2 in the Ancient Era)." % G,
                          "[ICON_INTERNATIONAL_TRADE] Trade Routes from this city to your own cities yield +50% for each foreign civilization or City-State that receives a Trade Route from one of your cities with a Hanse."]),
    "BUILDING_HORDE_YAM_ROUTE": ub("Replaces the Caravansary. Only the Golden Horde may build it. Available with the Wheel (instead of Horseback Riding).", "Caravansary",
                                   CARAVANSARY[1:],
                                   ["+3 %s (instead of +2)." % G, "+3 %s if the city is connected to the [ICON_CAPITAL] Capital." % S,
                                    "Mounted units and civilians that start their turn in the city get +2 [ICON_MOVES] Movement."]),
    "BUILDING_ODEON": ub("Replaces the Amphitheater. Available with Writing (instead of Drama) and needs no %s maintenance." % G, "Amphitheater",
                         [ART_SLOT, GW_TOURISM], ["+4 %s (instead of +2)." % C, "1 Writer specialist slot."]),
    "BUILDING_LIONS_GATE": ub("Replaces the Walls. Costs less.", "Walls", WALLS, ["+2 %s and +2 %s." % (C, G)]),
    "BUILDING_ORSZ": ub("Replaces the Palace. A second Palace can be built in another city to move the [ICON_CAPITAL] Capital there, and it may be sold. Available with Mathematics; 1 %s maintenance." % G,
                        "Palace", ["Marks the city as your [ICON_CAPITAL] Capital.", "+3 %s, +3 %s and +1 %s." % (P, S, C), ART_SLOT,
                                   "[ICON_CONNECTED] Cities connected to the [ICON_CAPITAL] Capital by road produce extra %s." % G],
                        ["+4 %s (instead of +3)." % G, "+25%% %s." % GP, "+10%% %s towards buildings." % P]),
    "BUILDING_QARA": ub("Replaces the Stable.", "Stable", STABLE + [STABLE_NEED], ["[ICON_RES_HORSE] Horses also yield +2 %s." % R]),
    "BUILDING_MUGHAL_FORT": ub("Replaces the Castle. Costs less and needs no Walls.", "Castle", CASTLE, ["+4 %s and +2 %s." % (C, H)]),
    "BUILDING_CANDI": ub("Replaces the Water Mill. Costs more, is available with Masonry (instead of the Wheel) and needs no %s maintenance. City must be next to fresh water (river, lake or oasis) instead of a river." % G,
                         "Water Mill", ["+2 %s." % F], ["+2 %s and +2 %s (but not the Water Mill's +1 %s)." % (C, R, P)]),
    "BUILDING_IRISH_PUB": ub("Replaces the Zoo. Needs no %s maintenance." % G, "Zoo",
                             ["+2 %s (no more than the city has [ICON_CITIZEN] Citizens)." % H, "City must have a Colosseum."],
                             ["+3 %s." % F, "[ICON_RES_TEA] Tea, [ICON_RES_WINE] Wine, [ICON_RES_COFFEE] Coffee and [ICON_RES_TOBACCO] Tobacco worked by this city yield +1 %s." % P]),
    "BUILDING_LONGHOUSE": ub("Replaces the Workshop. Costs less.", "Workshop", WORKSHOP,
                             ["Forest and Jungle tiles worked by this city yield +1 %s." % P, "[ICON_RES_HARDWOOD] Hardwood worked by this city yields +1 %s." % P]),
    "BUILDING_ISRAEL_NATIONAL_COLLEGE": ub("Replaces the National College. Cannot be built with %s: buy it with %s or %s. Its cost does not go up with more cities." % (P, G, R),
                                           "National College", ["+3 %s, +1 %s and +50%% %s." % (S, C, S), "Must have built a Library in all cities."],
                                           ["Whenever you expend a [ICON_GREAT_PEOPLE] Great Person: 50 %s." % S], NW),
    "BUILDING_BASIL": ub("Replaces the Museum. Costs less; available with Industrialization (instead of Archaeology).", "Museum", ["+2 %s." % C, ART_SLOT],
                         ["+15%% %s (instead of +10%%)." % C, "+20%% %s in this city." % GP, "2 Artist specialist slots and +2 Great Artist points."]),
    "BUILDING_OUTREMER": ub("Replaces the Courthouse.", "Courthouse", ["No extra [ICON_HAPPINESS_4] Unhappiness from an [ICON_OCCUPIED] Occupied City."],
                            ["When built: spreads your [ICON_CAPITAL] Capital's [ICON_RELIGION] Religion here like a Great Prophet, and units in or next to the city get +2 [ICON_MOVES] Movement for one turn."]),
    "BUILDING_BARAY": ub("Replaces the Garden. Needs no %s maintenance and no river or lake." % G, "Garden", [],
                         ["+25%% %s in this city (instead of +20%%)." % GP, "+2 %s and +2 %s." % (F, R), "10%% of %s is carried over after a new [ICON_CITIZEN] Citizen is born." % F]),
    "BUILDING_CORALSHOP": ub("Replaces the Workshop.", "Workshop", WORKSHOP,
                             ["+1 %s." % F, "[ICON_RES_CORAL] Coral worked by this city yields +2 %s." % P,
                              "[ICON_RES_FISH] Fish, [ICON_RES_PEARLS] Pearls and [ICON_RES_CRAB] Crab worked by this city yield +1 %s." % C,
                              "[ICON_RES_WHALE] Whales worked by this city yield +2 %s." % G]),
    "BUILDING_SLAVE": ub("Replaces the Colosseum. Only Kongo may build it. Needs no %s maintenance. Gives no %s." % (G, H), "Colosseum", [],
                         ["+4 %s and +4 %s, +3 more of each with Industrialization." % (P, G), "Removes 1 [ICON_CITIZEN] Citizen from the city when built."]),
    "BUILDING_LEKMOD_JONGMYO": ub("Replaces the Temple. Costs less, needs no Shrine and no %s maintenance." % G, "Temple", TEMPLE,
                                  ["1 slot for a [ICON_GREAT_WORK] Great Work of Music.", "When built: +4 %s and +4 %s in this city for 7 turns." % (C, R)]),
    "BUILDING_VILNIUS": ub("Replaces the Grand Temple. Costs less and can be built in any city (not only the Holy City).", "Grand Temple",
                           ["+8 %s." % R, "Doubles religious pressure from this city.", "Must have built a Temple in all cities.",
                            "The cost goes up the more cities there are in the empire."], [], NW),
    "BUILDING_LEKMOD_GYMNASIUM": ub("Replaces the Aqueduct.", "Aqueduct", ["40%% of %s is carried over after a new [ICON_CITIZEN] Citizen is born." % F],
                                    ["1 Merchant and 1 Artist specialist slot."]),
    "BUILDING_ROVA": ub("Replaces the Walls. Can also be bought with %s." % R, "Walls", WALLS, ["+2 %s and +2 %s." % (F, R)]),
    "BUILDING_MALI_NATIONAL_TREASURY": ub("Replaces the East India Company. Needs a Market only in this city (not in all cities).", "East India Company",
                                          ["+4 %s and +10%% %s." % (G, G), "1 more trade route.",
                                           "Trade routes other players make to this city give you +4 %s and the route's owner +2 %s." % (G, G),
                                           "The cost goes up the more cities there are in the empire."],
                                          ["+5 %s." % R, "The first unit or building bought in this city each turn with %s or %s costs 25%% less." % (G, R)], NW),
    "BUILDING_CANTON": ub("Replaces the Bank. Costs half as much.", "Bank", ["+2 %s." % G, MARKET_TRADE, "City must have a Market."],
                          ["+35%% %s (instead of +25%%)." % G, "2 Merchant specialist slots (instead of 1)."]),
    "BUILDING_ASHOKA": ub("Replaces the Monument. Costs half as much and needs no %s maintenance, but needs Pottery." % G, "Monument", ["+2 %s." % C], []),
    "BUILDING_LEKMOD_MAHAMATRAS_OFFICE": ub("Replaces the Amphitheater. Costs more.", "Amphitheater", AMPHI,
                                            ["+2 %s and +1 %s." % (F, H), "When built, the city starts an 8-turn 'We Love the King Day'."]),
    "BUILDING_MAYA_PYRAMID": ub("Replaces the Shrine.", "Shrine", [], ["+2 %s (instead of +1) and +1 %s." % (R, S)]),
    "BUILDING_HACIENDA": ub("Replaces the Windmill. Needs no %s maintenance." % G, "Windmill",
                            ["+2 %s and +10%% %s towards buildings." % (P, P), "1 Engineer specialist slot.", "Lake and Oasis tiles worked by this city yield +1 %s." % P],
                            ["Bonus resources worked by this city yield +1 %s, Luxury resources +1 %s, Strategic resources +1 %s." % (G, P, F)]),
    "BUILDING_ALCAZABA": ub("Replaces the Castle.", "Castle", CASTLE + ["City must have Walls."],
                            ["Forts worked by this city yield +1 %s, Citadels +5 %s." % (S, S),
                             "+5 %s for every city of another civilization within 4 tiles (not City-States)." % S]),
    "BUILDING_MUGHALS_CARAVANSARY": ub("Replaces the Caravansary. Costs more; available with Currency (instead of Horseback Riding).", "Caravansary", CARAVANSARY[1:],
                                       ["+3 %s (instead of +2)." % G, "With a garrison: +5 Defense, +3 %s, and the garrison costs no %s maintenance." % (C, G),
                                        "From turn 80 the %s needs no garrison." % C.split("] ")[1]]),
    "BUILDING_MYSORE_PALACE": ub("Replaces the Hermitage. Only the Mysore may build it. Available with Chivalry (instead of Architecture); needs Walls in all cities (instead of Opera Houses).",
                                 "Hermitage", ["+2 %s and +50%% %s in this city." % (C, C), "[ICON_GREAT_WORK] 3 slots for Great Works of Art or Artifacts.",
                                               "The cost goes up the more cities there are in the empire."],
                                 ["+3 %s, +3 %s and +3 %s." % (P, G, S), "Starts a [ICON_GOLDEN_AGE] Golden Age when built."], NW),
    "BUILDING_MC_KOKH": ub("Replaces the Caravansary.", "Caravansary", CARAVANSARY[1:],
                           ["+3 %s (instead of +2) and +2 %s." % (G, F), "Every trade route from this city gives it +1 %s (+0.5 for sea %s routes)." % (F, F.split("] ")[1])]),
    "BUILDING_STAVE": ub("Replaces the Temple. Costs less, needs no Shrine and no %s maintenance." % G, "Temple", TEMPLE,
                         ["Tundra tiles worked by this city yield +1 %s." % P]),
    "BUILDING_BLAST_FURNACE": ub("Replaces the Forge. Costs less, needs no %s maintenance and no mined Iron near the city." % G, "Forge",
                                 ["+15%% %s when building land units." % P, "[ICON_RES_IRON] Iron worked by this city yields +1 %s." % P,
                                  "Mountains worked by this city yield +1 %s (not Natural Wonders)." % P],
                                 ["+2 %s, and [ICON_RES_IRON] Iron also yields +2 %s." % (C, C), "Units trained in this city start with Accuracy I."]),
    "BUILDING_MC_OMANI_MINAA": ub("Replaces the Caravansary. Available with the Wheel (instead of Horseback Riding).", "Caravansary", CARAVANSARY,
                                  ["+2 %s if the city is connected to the [ICON_CAPITAL] Capital." % F, "+4 %s while a Caravan's route ends here." % C,
                                   "+4 %s while a Cargo Ship's route ends here." % G]),
    "BUILDING_LEKMOD_SU_KEMERI": ub("Replaces the Aqueduct.", "Aqueduct", ["40%% of %s is carried over after a new [ICON_CITIZEN] Citizen is born." % F],
                                    ["+1 %s and +1 %s if the city is next to fresh water or a mountain." % (R, S), "+3 %s and +3 %s if it is next to both." % (R, S)]),
    "BUILDING_PALMYRA_FORUM": ub("Replaces the Amphitheater. Needs no %s maintenance." % G, "Amphitheater", AMPHI,
                                 ["+2 %s." % G, "Oasis tiles worked by this city yield +1 %s, +1 %s and +1 %s." % (P, C, G), "Lake tiles worked by this city yield +1 %s." % P]),
    "BUILDING_SATRAPS_COURT": ub("Replaces the Bank.", "Bank", ["+25%% %s." % G, "1 Merchant specialist slot.", MARKET_TRADE, "City must have a Market."],
                                 ["+3 %s (instead of +2) and +1 %s." % (G, H)]),
    "BUILDING_NATIONALCHURCH": ub("Replaces the Colosseum. Costs less.", "Colosseum", COLOSSEUM,
                                  ["+2 %s if another of your cities is within 4 tiles." % R, "+2 %s if two or more of your other cities are within 4 tiles." % P]),
    "BUILDING_TRADE_HARBOUR": ub("Replaces the Harbor.", "Harbor",
                                 ["Forms a [ICON_CONNECTED] City Connection with the [ICON_CAPITAL] Capital over water.",
                                  "Sea trade routes from this city reach 50%% farther and give +1 %s when they go to another civilization." % G, "City must be on the coast."],
                                 ["+15%% %s when building naval units." % P, "Sea resources worked by this city yield +1 %s." % P]),
    "BUILDING_DUCAL_STABLE": ub("Replaces the Stable. Costs less and needs no %s maintenance." % G, "Stable", STABLE + [STABLE_NEED],
                                ["[ICON_RES_HORSE] Horses, [ICON_RES_SHEEP] Sheep, [ICON_RES_COW] Cattle and [ICON_RES_MAIZE] Maize also yield +1 %s." % G,
                                 "Mounted units trained in this city start with +15 XP."]),
    "BUILDING_FEITORIA": ub("Replaces the Harbor. Costs less, needs no coast and no %s maintenance." % G, "Harbor",
                            ["In a coastal city: forms a [ICON_CONNECTED] City Connection over water, and sea trade routes from this city reach 50% farther."],
                            ["+1 %s on your [ICON_CAPITAL] Capital's city tile." % G, "With a Courthouse or Crown Office in the city:",
                             "Luxury resources worked by the city yield +2 %s." % G, "Trade routes from this city to your [ICON_CAPITAL] Capital give +1 %s per era." % G,
                             "Trade routes from your [ICON_CAPITAL] Capital to this city give +3 %s." % F]),
    "BUILDING_PRUSSIAN_FACTORY": ub("Replaces the Factory. Costs 25% less.", "Factory",
                                    ["+4 %s and +10%% %s." % (P, P), "2 Engineer specialist slots.", "[ICON_RES_RUBBER] Rubber worked by this city yields +2 %s." % G,
                                     "Needs 2 [ICON_RES_COAL] Coal and 1 [ICON_RES_IRON] Iron.", "City must have a Workshop."], []),
    "BUILDING_MC_ROMANIAN_PAINTED_MONASTERY": ub("Replaces the Garden. Costs less and needs no river or lake.", "Garden", ["+20%% %s in this city." % GP],
                                                 ["+2 %s and +1 %s." % (R, P), "+1 Great Artist point."]),
    "BUILDING_KREPOST": ub("Replaces the Barracks. Costs more, 2 %s maintenance (instead of 1); available with Mining (instead of Bronze Working)." % G, "Barracks",
                           ["Units trained in this city start with +15 XP."],
                           ["+1 %s and +1 %s." % (C, F), "New tiles cost 25%% less %s and %s in this city." % (C, G)]),
    "BUILDING_CEILIDH_HALL": ub("Replaces the Opera House.", "Opera House", [ART_SLOT, GW_TOURISM], ["+3 %s (instead of +2) and +3 %s." % (C, H)]),
    "BUILDING_WAT": ub("Replaces the University. Costs less and needs no %s maintenance." % G, "University",
                       ["+33%% %s." % S, "2 Scientist specialist slots.", "Jungle tiles worked by this city yield +2 %s." % S,
                        "Allows Archaeologists to be built in this city.", "City must have a Library."], ["+3 %s." % C]),
    "BUILDING_MUD_PYRAMID_MOSQUE": ub("Replaces the Temple. Costs less and needs no %s maintenance." % G, "Temple", TEMPLE + ["City must have a Shrine."], ["+2 %s." % C]),
    "BUILDING_PLAZA_DE_TOROS": ub("Replaces the Circus. An improved [ICON_RES_COW] Cattle near the city also meets its requirement.", "Circus",
                                   COLOSSEUM + ["City must have an improved [ICON_RES_HORSE] Horses or [ICON_RES_IVORY] Ivory nearby."], ["+2 %s." % C]),
    "BUILDING_FALU_GRUVA": ub("Replaces the Ironworks. Available with Metal Casting (instead of Machinery).", "Ironworks",
                              ["+8 %s." % P, "Provides 8 [ICON_RES_IRON] Iron.", "Mountains worked by this city yield +2 %s (not Natural Wonders)." % P,
                               "Must have built a Workshop in all cities.", "The cost goes up the more cities there are in the empire."], [], NW),
    "BUILDING_SWISS_REISLAUFER": ub("Replaces the Armory. Needs no %s maintenance." % G, "Armory", ["Units trained in this city start with +15 XP.", "City must have a Barracks."],
                                    ["Units trained in this city, civilians included, start with Altitude Training (Hills cost less movement).",
                                     "When built, a Reisläufer appears in the city."]),
    "BUILDING_SWISS_SKI_RESORT": ub("Replaces the Stadium. Costs less, needs no %s maintenance and no Zoo; available with Electricity (instead of Refrigeration)." % G, "Stadium", [],
                                    ["+3 %s (instead of +2)." % H, "Mountain tiles worked by the city yield +5 %s, +5 %s and +5 %s." % (C, G, TO)]),
    "BUILDING_SERAI": ub("Replaces the Caravansary. Available with the Wheel (instead of Horseback Riding).", "Caravansary", CARAVANSARY,
                         ["+1 %s for every other Serai of yours within 4 tiles." % F, "If no other Serai of yours is within 5 tiles: +3 %s and borders grow 15%% faster." % C]),
    "BUILDING_MC_TONGAN_MALAE": ub("Replaces the Granary. Available with Sailing or Bronze Working (instead of Pottery).", "Granary", GRANARY,
                                   ["+1 %s." % C, "If 3 or more Coast tiles are next to the city: [ICON_RES_FISH] Fish yield +1 %s, +1 %s and +1 %s." % (G, C, R),
                                    "If 3 or more Jungle tiles are next to the city: Jungle yields +1 %s." % P]),
    "BUILDING_TUNISIA_CASTLE": ub("Replaces the Castle. Costs 20%% less and needs no Walls, but costs 4 %s maintenance." % G, "Castle", CASTLE,
                                  ["With a garrison: +4 %s and +4 %s." % (R, C), "The city sees 2 tiles farther, and terrain does not block its view."]),
    "BUILDING_UC_HALKEVLERI": ub("Replaces the Public School. Costs 30%% more, available with Industrialization (instead of Scientific Theory), and gives no %s of its own." % S,
                                 "Public School", ["1 Scientist specialist slot.", "City must have a University."],
                                 ["With a Broadcast Tower in the city: +1 %s and +1 %s for every 5 [ICON_CITIZEN] Citizens." % (S, C)]),
    "BUILDING_BURJ": ub("Replaces the Hotel. Available with Radio (instead of Refrigeration).", "Hotel",
                        ["50%% of the %s from World Wonders, Natural Wonders and worked tiles with any improvement in this city is added to its %s." % (C, TO),
                         "%s from Great Works +50%%." % TO],
                        ["+7 %s and +7 %s (but not the Hotel's extra %s from Natural Wonders, Lakes and Oases)." % (G, C, C)]),
    "BUILDING_KNYAZ": ub("Replaces the Market.", "Market", ["+25%% %s." % G, "1 Merchant specialist slot.", MARKET_TRADE],
                         ["+2 %s (instead of +1)." % G, "Whenever you expend a [ICON_GREAT_PEOPLE] Great Person: 20 %s for each Knyaz Court." % G]),
    "BUILDING_STPETERS": ub("Replaces the Grand Temple. Needs no Temples.", "Grand Temple",
                            ["+8 %s." % R, "Doubles religious pressure from this city.", "Must be built in a Holy City.",
                             "The cost goes up the more cities there are in the empire."],
                            ["Comes with a free [ICON_BUILDING_CATHEDRAL] Cathedral.", "+2 [ICON_GREAT_ARTIST] Great Artist points.",
                             "+2 Delegates in the [COLOR_POSITIVE_TEXT]World Congress[ENDCOLOR]."],
                            "[COLOR_CYAN]* National Wonder (each player may build one)[ENDCOLOR]"),
    "BUILDING_LEKMOD_WATER_PUPPET_THEATRE": ub("Replaces the Amphitheater.", "Amphitheater", AMPHI,
                                               ["Flood Plains, Marsh and Lake tiles next to the city yield +1 %s and +1 %s." % (C, G),
                                                "While a Festival (Great Musician) is next to the city, these tiles also yield +1 %s." % F]),
    "BUILDING_YUGO_SPOMENIK": ub("Replaces the Museum. Costs more.", "Museum", ["+2 %s and +10%% %s." % (C, C), ART_SLOT], ["+20%% %s." % S]),
    "BUILDING_STONE_MASON": ub("Replaces the Stone Works.", "Stone Works",
                               ["+1 %s and +1 %s." % (P, H), "[ICON_RES_MARBLE] Marble, [ICON_RES_OBSIDIAN] Obsidian and [ICON_RES_STONE] Stone worked by this city yield +1 %s." % P,
                                "City must have one of these resources improved with a Quarry."],
                               ["These resources also yield +2 %s." % C, "+2 Defense."]),
    "BUILDING_IKANDA": ub("Replaces the Stable. Costs more; available with Civil Service (instead of Horseback Riding).", "Stable", STABLE + [STABLE_NEED],
                          ["Pastures next to the city yield +2 %s." % F]),
}


# these two used their base building's Help tag; CIV5Units.xml gives them their own (end of the file)
OWN_TAGS = {"BUILDING_HIPPODROME": "TXT_KEY_LEKMOD_BUILDING_HIPPODROME_HELP", "BUILDING_CANTON": "TXT_KEY_LEKMOD_BUILDING_CANTON_HELP"}


def main():
    db = sqlite3.connect(DB)
    s = open(T, "rb").read().decode("utf-8")
    cr = "\r\n" in s[:5000]
    s = s.replace("\r\n", "\n")
    for b, text in TEXTS.items():
        row = db.execute("select Help from Buildings where Type=?", (b,)).fetchone()
        assert row and row[0], b
        tag = OWN_TAGS.get(b, row[0])
        assert db.execute("select count(*) from Buildings where Help=? and Type!=?", (tag, b)).fetchone()[0] == 0, (b, tag)
        ms = list(re.finditer(r'<(Row|Replace) Tag="%s"[^>]*>\s*<Text>(.*?)</Text>' % re.escape(tag), s, re.S))
        assert ms, (b, tag)
        for m in reversed(ms):
            s = s[:m.start(2)] + text + s[m.end(2):]
    open(T, "wb").write((s.replace("\n", "\r\n") if cr else s).encode("utf-8"))
    missing = [r[0] for r in db.execute("""select o.BuildingType from Civilization_BuildingClassOverrides o
        where o.BuildingType is not null and o.BuildingType != ''""") if r[0] not in TEXTS]
    print("set", len(TEXTS), "texts; UBs without a text here:", missing)


if __name__ == "__main__":
    main()
