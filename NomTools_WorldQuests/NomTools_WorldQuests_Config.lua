local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G and _G["NomTools"]
end

if not ns then
    return
end

-- Hierarchy of maps to scan for world quests.
-- Starts with the broadest zoom level (World) and works its way down.
-- Maps not selected in the options UI are skipped.
ns.WORLD_QUEST_SCAN_HIERARCHY = {
    mapID = 946,  -- Cosmic / World
    children = {
        {
            mapID = 947,  -- Azeroth
            children = {
                {
                    mapID = 13,  -- Eastern Kingdoms
                    children = {
                        { mapID = 2537 },  -- Quel'Thalas (Midnight)
                    },
                },
                { mapID = 619 },   -- Broken Isles (Legion)
                { mapID = 875 },   -- Zandalar (BFA)
                { mapID = 876 },   -- Kul Tiras (BFA)
                { mapID = 1978 },  -- Dragon Isles (Dragonflight)
                { mapID = 2274 },  -- Khaz Algar (The War Within)
            },
        },
        { mapID = 1550 },  -- Shadowlands
    },
}

-- Labels for maps in the scan hierarchy.
-- Used by the options UI and in-panel filter menus.
ns.WORLD_QUEST_SCAN_MAP_LABELS = {
    [946]  = "World",
    [947]  = "Azeroth",
    [13]   = "Eastern Kingdoms",
    [2537] = "Quel'Thalas",
    [619]  = "Broken Isles",
    [875]  = "Zandalar",
    [876]  = "Kul Tiras",
    [1978] = "Dragon Isles",
    [2274] = "Khaz Algar",
    [1550] = "Shadowlands",
}

-- Ordered list of map IDs for the excluded-maps UI.
-- Matches the hierarchy order: World → Azeroth → continents → Shadowlands.
ns.WORLD_QUEST_SCAN_MAP_ORDER = {
    946, 947, 13, 2537, 619, 875, 876, 1978, 2274, 1550,
}

-- Default excluded maps. World (946) and Azeroth (947) are excluded by
-- default because scanning all continents at those zoom levels causes
-- noticeable lag.
ns.WORLD_QUEST_DEFAULT_EXCLUDED_MAPS = {
    [946] = true,
    [947] = true,
}

ns.WORLD_QUEST_CONTRACTS = {
    -- Battle for Azeroth
    { key = "proudmoore_admiralty", label = "Proudmoore Admiralty", buffIDs = { 256434 } },
    { key = "order_of_embers", label = "Order of Embers", buffIDs = { 256451 } },
    { key = "storms_wake", label = "Storm's Wake", buffIDs = { 256452 } },
    { key = "zandalari_empire", label = "Zandalari Empire", buffIDs = { 256453 } },
    { key = "talanjis_expedition", label = "Talanji's Expedition", buffIDs = { 256455 } },
    { key = "voldunai", label = "Voldunai", buffIDs = { 256456 } },
    { key = "tortollan_seekers", label = "Tortollan Seekers", buffIDs = { 256459 } },
    { key = "champions_of_azeroth", label = "Champions of Azeroth", buffIDs = { 256460 } },
    { key = "seventh_legion", label = "7th Legion", buffIDs = { 284275 } },
    { key = "the_honorbound", label = "The Honorbound", buffIDs = { 284277 } },
    { key = "ankoan", label = "Ankoan", buffIDs = { 299661 } },
    { key = "the_unshackled", label = "The Unshackled", buffIDs = { 299662 } },
    { key = "rustbolt_resistance", label = "Rustbolt Resistance", buffIDs = { 299664 } },
    { key = "rajani", label = "Rajani", buffIDs = { 308188 } },
    { key = "uldum_accord", label = "Uldum Accord", buffIDs = { 308189 } },

    -- Shadowlands
    { key = "court_of_harvesters", label = "Court of Harvesters", buffIDs = { 311457 } },
    { key = "the_ascended", label = "The Ascended", buffIDs = { 311458 } },
    { key = "the_wild_hunt", label = "The Wild Hunt", buffIDs = { 311459 } },
    { key = "the_undying_army", label = "The Undying Army", buffIDs = { 311460 } },
    { key = "deaths_advance", label = "Death's Advance", buffIDs = { 353999 } },
    { key = "the_enlightened", label = "The Enlightened", buffIDs = { 359731 } },

    -- Dragonflight
    { key = "dragonscale_expedition", label = "Dragonscale Expedition", buffIDs = { 384468, 384469, 384470 } },
    { key = "maruuk_centaur", label = "Maruuk Centaur", buffIDs = { 384465, 384466, 384467 } },
    { key = "iskaara_tuskarr", label = "Iskaara Tuskarr", buffIDs = { 384459, 384460, 384461 } },
    { key = "valdrakken_accord", label = "Valdrakken Accord", buffIDs = { 384462, 384463, 384464 } },
    { key = "loamm_niffen", label = "Loamm Niffen", buffIDs = { 409664, 409665, 409666 } },
    { key = "dream_wardens", label = "Dream Wardens", buffIDs = { 425305, 425306, 425308 } },

    -- The War Within
    { key = "council_of_dornogal", label = "Council of Dornogal", buffIDs = { 454931, 454932, 454933 } },
    { key = "assembly_of_the_deeps", label = "Assembly of the Deeps", buffIDs = { 454934, 454935, 454936 } },
    { key = "hallowfall_arathi", label = "Hallowfall Arathi", buffIDs = { 454937, 454938, 454939 } },
    { key = "the_severed_threads", label = "The Severed Threads", buffIDs = { 454940, 454941, 454942 } },
    { key = "the_karesh_trust", label = "The K'aresh Trust", buffIDs = { 1235985, 1235987, 1235988 } },

    -- Midnight
    { key = "the_singularity", label = "The Singularity", buffIDs = { 1241983, 1241986 } },
    { key = "the_harati", label = "The Hara'ti", buffIDs = { 1241982, 1241985 } },
    { key = "the_amani_tribe", label = "The Amani Tribe", buffIDs = { 1241981, 1241984 } },
    { key = "the_silvermoon_court", label = "The Silvermoon Court", buffIDs = { 1241690, 1241691 } },
}
