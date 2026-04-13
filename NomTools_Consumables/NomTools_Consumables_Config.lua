local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
end

if not ns then
    return
end

ns.CONSUMABLE_CATALOG = {
    flask = {
        { key = "blood_knights", label = "Flask of the Blood Knights", buffIDs = { 1235110 }, itemIDs = { 245931, 245930, 241324, 241325 } },
        { key = "magisters", label = "Flask of the Magisters", buffIDs = { 1235108 }, itemIDs = { 245933, 245932, 241322, 241323 } },
        { key = "shattered_sun", label = "Flask of the Shattered Sun", buffIDs = { 1235111 }, itemIDs = { 245929, 245928, 241326, 241327 } },
        { key = "thalassian_resistance", label = "Flask of Thalassian Resistance", buffIDs = { 1235057 }, itemIDs = { 245926, 245927, 241320, 241321 } },
        { key = "honor", label = "Vicious Thalassian Flask of Honor", buffIDs = { 1239355 }, itemIDs = { 241334 } },
    },

    -- Foods are tracked by item ID here.
    -- The actual active buff check uses the shared Midnight food aura list below,
    -- so most food entries do not need their own buffIDs.
    --
    -- When Blizzard adds new foods later:
    -- - Add the new item IDs here.
    -- - If the reminder still does not recognize the buff, check whether the aura
    --   spell ID needs to be added to sharedBuffIDs.food.
    --
    -- Best source for that shared aura list:
    -- - Wowhead spell 1219179, "Become Well Fed"
    -- - Its Triggered By list shows the real Well Fed / Hearty Well Fed aura IDs.
    --
    -- If anything looks off, the in-game player aura spellId is still the final
    -- source of truth.
    food = {
        { key = "royal_roast", label = "Royal Roast", itemIDs = { 242275 } },
        { key = "hearty_royal_roast", label = "Hearty Royal Roast", itemIDs = { 242747 } },
        { key = "impossibly_royal_roast", label = "Impossibly Royal Roast", itemIDs = { 255847 } },
        { key = "hearty_impossibly_royal_roast", label = "Hearty Impossibly Royal Roast", itemIDs = { 268679 } },
        { key = "flora_frenzy", label = "Flora Frenzy", itemIDs = { 255848 } },
        { key = "hearty_flora_frenzy", label = "Hearty Flora Frenzy", itemIDs = { 267000, 268680 } },
        { key = "champions_bento", label = "Champion's Bento", itemIDs = { 242274 } },
        { key = "hearty_champions_bento", label = "Hearty Champion's Bento", itemIDs = { 242746 } },
        { key = "warped_wise_wings", label = "Warped Wise Wings", itemIDs = { 242285 } },
        { key = "hearty_warped_wise_wings", label = "Hearty Warped Wise Wings", itemIDs = { 242757 } },
        { key = "void_kissed_fish_rolls", label = "Void-Kissed Fish Rolls", itemIDs = { 242284 } },
        { key = "hearty_void_kissed_fish_rolls", label = "Hearty Void-Kissed Fish Rolls", itemIDs = { 242756 } },
        { key = "sun_seared_lumifin", label = "Sun-Seared Lumifin", itemIDs = { 242283 } },
        { key = "hearty_sun_seared_lumifin", label = "Hearty Sun-Seared Lumifin", itemIDs = { 242755 } },
        { key = "null_and_void_plate", label = "Null and Void Plate", itemIDs = { 242282 } },
        { key = "hearty_null_and_void_plate", label = "Hearty Null and Void Plate", itemIDs = { 242754 } },
        { key = "glitter_skewers", label = "Glitter Skewers", itemIDs = { 242281 } },
        { key = "hearty_glitter_skewers", label = "Hearty Glitter Skewers", itemIDs = { 242753 } },
        { key = "fel_kissed_filet", label = "Fel-Kissed Filet", itemIDs = { 242286 } },
        { key = "hearty_fel_kissed_filet", label = "Hearty Fel-Kissed Filet", itemIDs = { 242758 } },
        { key = "buttered_root_crab", label = "Buttered Root Crab", itemIDs = { 242280 } },
        { key = "hearty_buttered_root_crab", label = "Hearty Buttered Root Crab", itemIDs = { 242752 } },
        { key = "arcano_cutlets", label = "Arcano Cutlets", itemIDs = { 242287 } },
        { key = "hearty_arcano_cutlets", label = "Hearty Arcano Cutlets", itemIDs = { 242759 } },
        { key = "tasty_smoked_tetra", label = "Tasty Smoked Tetra", itemIDs = { 242278 } },
        { key = "hearty_tasty_smoked_tetra", label = "Hearty Tasty Smoked Tetra", itemIDs = { 242750 } },
        { key = "crimson_calamari", label = "Crimson Calamari", itemIDs = { 242277 } },
        { key = "hearty_crimson_calamari", label = "Hearty Crimson Calamari", itemIDs = { 242749 } },
        { key = "braised_blood_hunter", label = "Braised Blood Hunter", itemIDs = { 242276 } },
        { key = "hearty_braised_blood_hunter", label = "Hearty Braised Blood Hunter", itemIDs = { 242748 } },
        { key = "harandar_celebration", label = "Harandar Celebration", itemIDs = { 255846 } },
        { key = "hearty_harandar_celebration", label = "Hearty Harandar Celebration", itemIDs = { 266996 } },
        { key = "silvermoon_parade", label = "Silvermoon Parade", itemIDs = { 255845 } },
        { key = "hearty_silvermoon_parade", label = "Hearty Silvermoon Parade", itemIDs = { 266985 } },
        { key = "queldorei_medley", label = "Quel'dorei Medley", itemIDs = { 242272 } },
        { key = "hearty_queldorei_medley", label = "Hearty Quel'dorei Medley", itemIDs = { 242744, 266986 } },
        { key = "blooming_feast", label = "Blooming Feast", itemIDs = { 242273 } },
        { key = "hearty_blooming_feast", label = "Hearty Blooming Feast", itemIDs = { 242745 } },
    },
    weapon = {
        { key = "phoenix_oil", label = "Thalassian Phoenix Oil", weaponType = "NEUTRAL", itemIDs = { 243733, 243734 } },
        { key = "oil_of_dawn", label = "Oil of Dawn", weaponType = "NEUTRAL", itemIDs = { 243735, 243736 } },
        { key = "smugglers_edge", label = "Smuggler's Enchanted Edge", weaponType = "NEUTRAL", itemIDs = { 243737, 243738 } },
        { key = "weightstone", label = "Refulgent Weightstone", weaponType = "BLUNT", itemIDs = { 237367, 237369 } },
        { key = "whetstone", label = "Refulgent Whetstone", weaponType = "BLADED", itemIDs = { 237370, 237371 } },
        { key = "laced_zoomshots", label = "Laced Zoomshots", weaponType = "RANGED", itemIDs = { 257749, 257750 } },
        { key = "weighted_boomshots", label = "Weighted Boomshots", weaponType = "RANGED", itemIDs = { 257751, 257752 } },
    },
    poisons = {
        { key = "instant_poison", label = "Instant Poison", poisonCategory = "lethal", spellID = 315584 },
        { key = "wound_poison", label = "Wound Poison", poisonCategory = "lethal", spellID = 8679 },
        { key = "deadly_poison", label = "Deadly Poison", poisonCategory = "lethal", spellID = 2823 },
        { key = "crippling_poison", label = "Crippling Poison", poisonCategory = "non_lethal", spellID = 3408 },
        { key = "atrophic_poison", label = "Atrophic Poison", poisonCategory = "non_lethal", spellID = 381637 },
        { key = "numbing_poison", label = "Numbing Poison", poisonCategory = "non_lethal", spellID = 5761 },
    },
    rune = {
        { key = "void_touched", label = "Void-Touched Augment Rune", itemIDs = { 259085 } },
        { key = "ethereal", label = "Ethereal Augment Rune", itemIDs = { 243191 } },
    },

    -- Midnight food uses a shared buff list because one generic food spell can lead
    -- to many different Well Fed / Hearty Well Fed auras.
    -- Runes also use a shared buff list for the same general reason.
    sharedBuffIDs = {
        food = {
            1219182, 1219183, 1219184, 1219185,
            1232076, 1232078, 1232080, 1232082,
            1232086, 1232087, 1232089, 1232091,
            1232313, 1232316, 1232317, 1232318,
            1232320, 1232321, 1232324, 1232325,
            1232490, 1232491, 1232492, 1232493,
            1232496, 1232498, 1232500, 1232501,
            1232582, 1232584, 1232585,
            1233400, 1233401, 1233402, 1233403, 1233404,
            1233405, 1233406, 1233407, 1233408,
            1233703, 1233704, 1233705, 1233706, 1233707,
            1233708, 1233709, 1233710, 1233711, 1233712,
            1233713, 1233714, 1233715, 1233716, 1233717,
            1233718, 1233719, 1233720, 1233721, 1233722,
            1233723, 1233724, 1233725, 1233726, 1233727,
            1233728, 1233729, 1233730, 1233731, 1233732,
            1233733,
            1283372,
            1284616, 1284617, 1284618, 1284619,
            1284641, 1284642, 1284643, 1284644,
            1284647, 1284648, 1284649, 1284650,
            1285644,
        },
        rune = { 347901, 393438, 453250, 1234969, 1242347, 1264426 },
    },
}