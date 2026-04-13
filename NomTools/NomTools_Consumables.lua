local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
end

if not ns then
    return
end

local CopyDefaults = ns.CopyDefaults
local CopyMissingTableValues = ns.CopyMissingTableValues
local CopyTableRecursive = ns.CopyTableRecursive
local EnsureCharacterRoot = ns.EnsureCharacterRoot

local KNOWN_WEAPON_SUBCLASSES = {
    BLADED = {
        [0] = true,
        [1] = true,
        [6] = true,
        [7] = true,
        [8] = true,
        [9] = true,
        [15] = true,
    },
    BLUNT = {
        [4] = true,
        [5] = true,
        [10] = true,
        [13] = true,
    },
    RANGED = {
        [2] = true,
        [3] = true,
        [18] = true,
    },
}

local PRIORITY_KINDS = {
    "flask",
    "food",
    "weapon",
}

local CONSUMABLE_TRACKER_KEYS = {
    "flask",
    "food",
    "weapon",
    "poisons",
    "rune",
}

local CONSUMABLE_TRACKING_SETTING_KEYS = {
    "flaskEnabled",
    "foodEnabled",
    "weaponEnabled",
    "poisonsEnabled",
    "runeEnabled",
    "flaskChoice",
    "foodChoice",
    "weaponChoice",
    "runeChoice",
    "flaskChoices",
    "foodChoices",
    "weaponChoices",
    "weaponPoisonChoices",
    "reapply",
    "visibility",
    "secondary",
    "reapplyDefaultsVersion",
}

local MAX_PRIORITY_CHOICES = ns.MAX_PRIORITY_CHOICES or 3
local MAX_CONSUMABLE_TRACKER_SETUPS = 2
local CONSUMABLE_REAPPLY_DEFAULTS_VERSION = 2

ns.MAX_CONSUMABLE_TRACKER_SETUPS = MAX_CONSUMABLE_TRACKER_SETUPS
ns.CONSUMABLE_REAPPLY_DEFAULTS_VERSION = CONSUMABLE_REAPPLY_DEFAULTS_VERSION

function ns.BuildConsumableTrackingDefaults()
    local defaults = ns.DEFAULTS and ns.DEFAULTS.consumables or {}

    return {
        flaskEnabled = defaults.flaskEnabled,
        foodEnabled = defaults.foodEnabled,
        weaponEnabled = defaults.weaponEnabled,
        poisonsEnabled = defaults.poisonsEnabled,
        runeEnabled = defaults.runeEnabled,
        flaskChoice = defaults.flaskChoice,
        foodChoice = defaults.foodChoice,
        weaponChoice = defaults.weaponChoice,
        runeChoice = defaults.runeChoice,
        flaskChoices = CopyTableRecursive(defaults.flaskChoices),
        foodChoices = CopyTableRecursive(defaults.foodChoices),
        weaponChoices = CopyTableRecursive(defaults.weaponChoices),
        weaponPoisonChoices = CopyTableRecursive(defaults.weaponPoisonChoices),
        reapply = CopyTableRecursive(defaults.reapply),
        visibility = CopyTableRecursive(defaults.visibility),
        secondary = CopyTableRecursive(defaults.secondary),
        reapplyDefaultsVersion = defaults.reapplyDefaultsVersion,
    }
end

local preparedConsumableTables = setmetatable({}, { __mode = "k" })
local consumableTrackingDefaultsTemplate = ns.BuildConsumableTrackingDefaults()
local PrepareConsumableTrackingSettings
local PrepareSecondaryConsumableTrackerConfig
local NormalizeRoguePoisonChoice
local EMPTY_PRIORITY_CHOICES = {}

local function GetConfiguredInstanceFilters()
    if ns.GetInstanceFilters then
        return ns.GetInstanceFilters() or EMPTY_PRIORITY_CHOICES
    end

    return ns.INSTANCE_FILTERS or EMPTY_PRIORITY_CHOICES
end

local function ForgetPreparedConsumableTable(tableRef)
    if type(tableRef) == "table" then
        preparedConsumableTables[tableRef] = nil
    end
end

local function CopyConsumableTrackingSettings(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    for _, key in ipairs(CONSUMABLE_TRACKING_SETTING_KEYS) do
        if source[key] ~= nil then
            target[key] = CopyTableRecursive(source[key])
        end
    end

    return target
end

local function EnsureConsumableTrackingSettings()
    if not ns.db then
        return CopyTableRecursive(consumableTrackingDefaultsTemplate)
    end

    local characterRoot = EnsureCharacterRoot()
    local legacyConsumables = type(ns.db.consumables) == "table" and ns.db.consumables or {}

    if type(characterRoot) ~= "table" then
        return PrepareConsumableTrackingSettings(legacyConsumables)
    end

    if type(characterRoot.consumablesTracking) ~= "table" then
        characterRoot.consumablesTracking = {}
        CopyConsumableTrackingSettings(characterRoot.consumablesTracking, legacyConsumables)
    end

    return PrepareConsumableTrackingSettings(characterRoot.consumablesTracking)
end

ns.EnsureConsumableTrackingSettings = EnsureConsumableTrackingSettings

function ns.GetConsumableTrackingSettings()
    return EnsureConsumableTrackingSettings()
end

function ns.GetConsumableTrackingCharacterSources()
    if not ns.db or type(ns.db.characters) ~= "table" then
        return {}
    end

    local _, currentCharacterKey = EnsureCharacterRoot()
    local entries = {}

    for characterKey, characterState in pairs(ns.db.characters) do
        if characterKey ~= currentCharacterKey
            and type(characterState) == "table"
            and type(characterState.consumablesTracking) == "table"
        then
            entries[#entries + 1] = {
                key = characterKey,
                name = characterKey,
            }
        end
    end

    table.sort(entries, function(left, right)
        return string.lower(left.name or "") < string.lower(right.name or "")
    end)

    return entries
end

function ns.CopyConsumableTrackingSettingsFromCharacter(sourceCharacterKey)
    if type(sourceCharacterKey) ~= "string" or sourceCharacterKey == "" then
        return false
    end

    if not ns.db or type(ns.db.characters) ~= "table" then
        return false
    end

    local sourceCharacter = ns.db.characters[sourceCharacterKey]
    if type(sourceCharacter) ~= "table" or type(sourceCharacter.consumablesTracking) ~= "table" then
        return false
    end

    local settings = EnsureConsumableTrackingSettings()
    ForgetPreparedConsumableTable(settings)
    for key in pairs(settings) do
        settings[key] = nil
    end

    CopyConsumableTrackingSettings(settings, sourceCharacter.consumablesTracking)
    PrepareConsumableTrackingSettings(settings)
    return true
end

local function IsValidChoiceKey(kind, key)
    if key == "auto" or key == "none" then
        return true
    end

    return ns.GetChoiceEntry(kind, key) ~= nil
end

local function NormalizePriorityChoices(kind, list, fallbackKey, allowAllNone)
    local normalized = {}
    local seen = {}
    local resolvedFallback = IsValidChoiceKey(kind, fallbackKey) and fallbackKey or "auto"

    if type(list) ~= "table" then
        list = { resolvedFallback }
    end

    for index = 1, MAX_PRIORITY_CHOICES do
        local value = list[index]

        if type(value) ~= "string" or not IsValidChoiceKey(kind, value) then
            value = index == 1 and resolvedFallback or "none"
        end

        if value ~= "none" then
            if seen[value] then
                value = "none"
            else
                seen[value] = true
            end
        end

        normalized[index] = value
    end

    local hasConfiguredChoice = false
    for _, value in ipairs(normalized) do
        if value ~= "none" then
            hasConfiguredChoice = true
            break
        end
    end

    if not hasConfiguredChoice then
        if allowAllNone then
            return normalized
        end

        normalized[1] = resolvedFallback ~= "none" and resolvedFallback or "auto"
    end

    return normalized
end

local function GetConsumableSetupDefaults(kind, setupIndex)
    if tonumber(setupIndex) == 2 then
        return ns.DEFAULTS
            and ns.DEFAULTS.consumables
            and ns.DEFAULTS.consumables.secondary
            and ns.DEFAULTS.consumables.secondary[kind]
            or {}
    end

    return ns.DEFAULTS and ns.DEFAULTS.consumables or {}
end

local function EnsureSecondaryConsumableTrackerConfig(kind)
    local defaults = GetConsumableSetupDefaults(kind, 2)
    local settings = EnsureConsumableTrackingSettings()

    if type(settings) ~= "table" then
        return PrepareSecondaryConsumableTrackerConfig(kind, CopyTableRecursive(defaults))
    end

    if type(settings.secondary) ~= "table" then
        settings.secondary = {}
    end

    if type(settings.secondary[kind]) ~= "table" then
        settings.secondary[kind] = {}
    end

    return PrepareSecondaryConsumableTrackerConfig(kind, settings.secondary[kind])
end

local function NormalizeSingleChoice(kind, value, fallback, allowNone)
    if value == "auto" then
        return "auto"
    end

    if allowNone and value == "none" then
        return "none"
    end

    if IsValidChoiceKey(kind, value) then
        return value
    end

    return fallback
end

PrepareSecondaryConsumableTrackerConfig = function(kind, trackerConfig)
    if type(trackerConfig) ~= "table" or preparedConsumableTables[trackerConfig] then
        return trackerConfig
    end

    local defaults = GetConsumableSetupDefaults(kind, 2)
    CopyDefaults(trackerConfig, defaults)

    if kind == "poisons" then
        if type(trackerConfig.choices) ~= "table" then
            trackerConfig.choices = {}
        end

        local defaultChoices = defaults.choices or {}
        trackerConfig.choices.lethal = NormalizeRoguePoisonChoice("lethal", trackerConfig.choices.lethal or defaultChoices.lethal or "none", true)
        trackerConfig.choices.non_lethal = NormalizeRoguePoisonChoice("non_lethal", trackerConfig.choices.non_lethal or defaultChoices.non_lethal or "none", true)
    elseif kind == "rune" then
        trackerConfig.choice = NormalizeSingleChoice(kind, trackerConfig.choice or defaults.choice or "none", "none", true)
    elseif kind == "flask" or kind == "food" or kind == "weapon" then
        trackerConfig.choices = NormalizePriorityChoices(kind, trackerConfig.choices, "none", true)
    end

    if type(trackerConfig.visibility) ~= "table" then
        trackerConfig.visibility = {}
    end
    if type(trackerConfig.visibility.enabledFilters) == "table" then
        trackerConfig.visibility.enabledFilters.party_mythic_plus = nil
    end

    preparedConsumableTables[trackerConfig] = true
    return trackerConfig
end

PrepareConsumableTrackingSettings = function(settings)
    if type(settings) ~= "table" or preparedConsumableTables[settings] then
        return settings
    end

    CopyDefaults(settings, consumableTrackingDefaultsTemplate)

    for _, kind in ipairs(PRIORITY_KINDS) do
        local singleKey = kind .. "Choice"
        local listKey = kind .. "Choices"
        settings[listKey] = NormalizePriorityChoices(
            kind,
            settings[listKey],
            settings[singleKey] or consumableTrackingDefaultsTemplate[singleKey] or "auto",
            false
        )
    end

    settings.runeChoice = NormalizeSingleChoice(
        "rune",
        settings.runeChoice or consumableTrackingDefaultsTemplate.runeChoice or "auto",
        "auto",
        false
    )

    if type(settings.weaponPoisonChoices) ~= "table" then
        settings.weaponPoisonChoices = {}
    end

    local defaultPoisonChoices = consumableTrackingDefaultsTemplate.weaponPoisonChoices or {}
    settings.weaponPoisonChoices.lethal = NormalizeRoguePoisonChoice(
        "lethal",
        settings.weaponPoisonChoices.lethal or defaultPoisonChoices.lethal or "auto",
        false
    )
    settings.weaponPoisonChoices.non_lethal = NormalizeRoguePoisonChoice(
        "non_lethal",
        settings.weaponPoisonChoices.non_lethal or defaultPoisonChoices.non_lethal or "auto",
        false
    )

    if type(settings.visibility) ~= "table" then
        settings.visibility = {}
    end

    for _, trackerKind in ipairs(CONSUMABLE_TRACKER_KEYS) do
        if type(settings.visibility[trackerKind]) ~= "table" then
            settings.visibility[trackerKind] = {}
        end
        if type(settings.visibility[trackerKind].enabledFilters) == "table" then
            settings.visibility[trackerKind].enabledFilters.party_mythic_plus = nil
        end
    end

    if type(settings.secondary) ~= "table" then
        settings.secondary = {}
    end

    preparedConsumableTables[settings] = true
    return settings
end

local function FindLegacyRoguePoisonChoice(consumables, poisonCategory)
    if type(consumables.weaponChoices) == "table" then
        for _, key in ipairs(consumables.weaponChoices) do
            if key ~= "auto" and key ~= "none" then
                for _, entry in ipairs(ns.ROGUE_POISONS or {}) do
                    if entry.key == key and entry.poisonCategory == poisonCategory then
                        return key
                    end
                end
            end
        end
    end

    return "auto"
end

local function DoesBooleanMapMatchExpected(map, expected)
    for key, expectedValue in pairs(expected or {}) do
        if (map and map[key] == true or false) ~= (expectedValue == true) then
            return false
        end
    end

    for key, value in pairs(map or {}) do
        if expected[key] == nil and value == true then
            return false
        end
    end

    return true
end

local function IsEmptySecondaryChoiceConfig(kind, trackerConfig)
    if type(trackerConfig) ~= "table" then
        return true
    end

    if kind == "poisons" then
        local choices = trackerConfig.choices or {}
        return (choices.lethal or "none") == "none" and (choices.non_lethal or "none") == "none"
    end

    if kind == "rune" then
        return (trackerConfig.choice or "none") == "none"
    end

    for _, value in ipairs(trackerConfig.choices or {}) do
        if value ~= "none" then
            return false
        end
    end

    return true
end

local function NormalizeSecondaryConsumableDefaults(consumables)
    local secondaryDefaults = ns.DEFAULTS and ns.DEFAULTS.consumables and ns.DEFAULTS.consumables.secondary or {}
    local legacyFilterDefaults = ns.DEFAULTS and ns.DEFAULTS.consumables and ns.DEFAULTS.consumables.visibility and ns.DEFAULTS.consumables.visibility.flask and ns.DEFAULTS.consumables.visibility.flask.enabledFilters or {}

    if type(consumables.secondary) ~= "table" then
        consumables.secondary = {}
    end

    for _, kind in ipairs(CONSUMABLE_TRACKER_KEYS) do
        local trackerDefaults = secondaryDefaults[kind] or {}
        if type(consumables.secondary[kind]) ~= "table" then
            consumables.secondary[kind] = CopyTableRecursive(trackerDefaults)
        else
            local trackerConfig = consumables.secondary[kind]
            CopyDefaults(trackerConfig, trackerDefaults)

            local visibility = trackerConfig.visibility
            local expectedEmptyFilters = trackerDefaults.visibility and trackerDefaults.visibility.enabledFilters or {}
            local currentFilters = visibility and visibility.enabledFilters or nil
            local shouldResetLegacyFilters = trackerConfig.enabled ~= true
                and IsEmptySecondaryChoiceConfig(kind, trackerConfig)
                and type(visibility) == "table"
                and visibility.showDuringCombat ~= true
                and visibility.showDuringMythicPlus ~= true
                and DoesBooleanMapMatchExpected(currentFilters, legacyFilterDefaults)

            if shouldResetLegacyFilters then
                trackerConfig.visibility = CopyTableRecursive(trackerDefaults.visibility or {})
            end
        end
    end
end

function ns.MigrateLegacyConsumableConfig()
    local globalConsumables = ns.db.consumables or {}
    ns.db.consumables = globalConsumables
    local consumables = EnsureConsumableTrackingSettings()
    local legacyOnlyInInstances = ns.db.onlyInInstances
    local legacyShowDuringCombat
    local legacyShowDuringMythicPlus
    local hadLegacyPoisonsVisibility = type(consumables.visibility) == "table" and type(consumables.visibility.poisons) == "table"

    if consumables.showDuringCombat ~= nil or consumables.showDuringMythicPlus ~= nil or consumables.showDuringEncounters ~= nil then
        if consumables.showDuringCombat ~= nil then
            consumables.showDuringCombat = consumables.showDuringCombat and true or false
            legacyShowDuringCombat = consumables.showDuringCombat
        end

        if consumables.showDuringMythicPlus ~= nil then
            legacyShowDuringMythicPlus = consumables.showDuringMythicPlus
        elseif consumables.showDuringEncounters ~= nil then
            consumables.showDuringMythicPlus = consumables.showDuringEncounters and true or false
            legacyShowDuringMythicPlus = consumables.showDuringMythicPlus
        end
    elseif consumables.showDuringCombatEncounter ~= nil then
        local legacyCombined = consumables.showDuringCombatEncounter and true or false
        consumables.showDuringCombat = legacyCombined
        consumables.showDuringMythicPlus = legacyCombined
        legacyShowDuringCombat = legacyCombined
        legacyShowDuringMythicPlus = legacyCombined
    end
    consumables.showDuringCombatEncounter = nil
    consumables.showDuringEncounters = nil

    for _, kind in ipairs(PRIORITY_KINDS) do
        local listKey = kind .. "Choices"
        local singleKey = kind .. "Choice"
        consumables[listKey] = NormalizePriorityChoices(kind, consumables[listKey], consumables[singleKey] or "auto", false)
    end

    if type(consumables.weaponPoisonChoices) ~= "table" then
        consumables.weaponPoisonChoices = {}
    end
    if consumables.poisonsEnabled == nil then
        consumables.poisonsEnabled = consumables.weaponEnabled ~= false
    end
    if consumables.weaponPoisonChoices.lethal == nil then
        consumables.weaponPoisonChoices.lethal = FindLegacyRoguePoisonChoice(consumables, "lethal")
    end
    if consumables.weaponPoisonChoices.non_lethal == nil then
        consumables.weaponPoisonChoices.non_lethal = FindLegacyRoguePoisonChoice(consumables, "non_lethal")
    end

    if type(globalConsumables.appearance) ~= "table" then
        globalConsumables.appearance = {}
    end
    if globalConsumables.appearance.labelFontSize == nil and type(globalConsumables.appearance.fontSize) == "number" then
        globalConsumables.appearance.labelFontSize = globalConsumables.appearance.fontSize
    end
    if globalConsumables.appearance.durationFontSize == nil and type(globalConsumables.appearance.fontSize) == "number" then
        globalConsumables.appearance.durationFontSize = globalConsumables.appearance.fontSize
    end
    if globalConsumables.appearance.countFontSize == nil and type(globalConsumables.appearance.fontSize) == "number" then
        globalConsumables.appearance.countFontSize = math.max(9, globalConsumables.appearance.fontSize - 1)
    end
    if globalConsumables.appearance.borderSize == nil and globalConsumables.appearance.showBorder == false then
        globalConsumables.appearance.borderSize = 0
    end

    local legacyEnabledFilters = nil
    if type(consumables.visibility) ~= "table" then
        consumables.visibility = {}
    end

    if type(consumables.visibility.enabledFilters) == "table" then
        legacyEnabledFilters = CopyTableRecursive(consumables.visibility.enabledFilters)
    end

    for _, kind in ipairs(CONSUMABLE_TRACKER_KEYS) do
        if type(consumables.visibility[kind]) ~= "table" then
            consumables.visibility[kind] = {}
        end

        local trackerVisibility = consumables.visibility[kind]
        if legacyShowDuringCombat ~= nil and trackerVisibility.showDuringCombat == nil then
            trackerVisibility.showDuringCombat = legacyShowDuringCombat and true or false
        end
        if legacyShowDuringMythicPlus ~= nil and trackerVisibility.showDuringMythicPlus == nil then
            trackerVisibility.showDuringMythicPlus = legacyShowDuringMythicPlus and true or false
        end
        if type(trackerVisibility.enabledFilters) ~= "table" then
            trackerVisibility.enabledFilters = {}
        end
        if legacyEnabledFilters then
            CopyMissingTableValues(trackerVisibility.enabledFilters, legacyEnabledFilters)
        end
        if kind == "poisons" and not hadLegacyPoisonsVisibility then
            trackerVisibility.enabledFilters = CopyTableRecursive((ns.DEFAULTS.consumables.visibility.poisons or {}).enabledFilters or {})
        end
        trackerVisibility.enabledFilters.party_mythic_plus = nil
    end

    consumables.showDuringCombat = nil
    consumables.showDuringMythicPlus = nil
    consumables.visibility.enabledFilters = nil

    if type(consumables.reapply) ~= "table" then
        consumables.reapply = {}
    end
    if type(consumables.reapply.poisons) ~= "table" and type(consumables.reapply.weapon) == "table" then
        consumables.reapply.poisons = CopyTableRecursive(consumables.reapply.weapon)
    end

    if tonumber(consumables.reapplyDefaultsVersion) ~= CONSUMABLE_REAPPLY_DEFAULTS_VERSION then
        for _, kind in ipairs({ "flask", "food", "weapon", "rune" }) do
            local reapplyConfig = consumables.reapply[kind]
            local newDefaults = ns.DEFAULTS.consumables
                and ns.DEFAULTS.consumables.reapply
                and ns.DEFAULTS.consumables.reapply[kind]
                or nil
            if type(reapplyConfig) == "table"
                and type(newDefaults) == "table"
                and reapplyConfig.enabled == false
                and tonumber(reapplyConfig.thresholdSeconds) == 300
            then
                reapplyConfig.enabled = newDefaults.enabled ~= false
                reapplyConfig.thresholdSeconds = tonumber(newDefaults.thresholdSeconds) or 1800
            end
        end
        consumables.reapplyDefaultsVersion = CONSUMABLE_REAPPLY_DEFAULTS_VERSION
    end

    if legacyOnlyInInstances == false then
        for _, kind in ipairs(CONSUMABLE_TRACKER_KEYS) do
            consumables.visibility[kind].enabledFilters = {}
        end
    end
    ns.db.onlyInInstances = nil

    local legacyReminder = ns.GetEditModeConfig and ns.GetEditModeConfig("reminder", ns.DEFAULTS.editMode.reminder) or nil
    if type(legacyReminder) == "table" then
        if globalConsumables.appearance.iconSize == nil and type(legacyReminder.iconSize) == "number" then
            globalConsumables.appearance.iconSize = legacyReminder.iconSize
        end
        if globalConsumables.appearance.spacing == nil and type(legacyReminder.spacing) == "number" then
            globalConsumables.appearance.spacing = legacyReminder.spacing
        end
        legacyReminder.iconSize = nil
        legacyReminder.spacing = nil
    end

    CopyDefaults(globalConsumables.appearance, ns.DEFAULTS.consumables.appearance or {})
    CopyDefaults(consumables, ns.BuildConsumableTrackingDefaults())
    NormalizeSecondaryConsumableDefaults(consumables)
end

function ns.GetConsumableTrackerEnabled(kind, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if setupIndex == 2 then
        local trackerConfig = EnsureSecondaryConsumableTrackerConfig(kind)
        return trackerConfig.enabled == true
    end

    local defaults = ns.DEFAULTS and ns.DEFAULTS.consumables or {}
    local enabledKey = kind .. "Enabled"

    if not settings then
        return defaults[enabledKey] ~= false
    end

    if settings[enabledKey] == nil then
        settings[enabledKey] = defaults[enabledKey] ~= false
    end

    return settings[enabledKey] ~= false
end

function ns.SetConsumableTrackerEnabled(kind, setupIndex, enabled)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if not settings then
        return
    end

    if setupIndex == 2 then
        EnsureSecondaryConsumableTrackerConfig(kind).enabled = enabled and true or false
        return
    end

    settings[kind .. "Enabled"] = enabled and true or false
end

function ns.GetPriorityChoices(kind, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if setupIndex == 2 then
        return EnsureSecondaryConsumableTrackerConfig(kind).choices or EMPTY_PRIORITY_CHOICES
    end

    if not settings then
        local defaults = consumableTrackingDefaultsTemplate
        return NormalizePriorityChoices(kind, defaults[kind .. "Choices"], defaults[kind .. "Choice"] or "auto", false)
    end

    return settings[kind .. "Choices"]
end

function ns.SetPriorityChoice(kind, index, value, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if not settings or type(index) ~= "number" then
        return
    end

    if index < 1 or index > MAX_PRIORITY_CHOICES then
        return
    end

    local choices = ns.GetPriorityChoices(kind, setupIndex)
    choices[index] = value

    if setupIndex == 2 then
        local trackerConfig = EnsureSecondaryConsumableTrackerConfig(kind)
        trackerConfig.choices = NormalizePriorityChoices(kind, choices, "none", true)
        return
    end

    settings[kind .. "Choices"] = NormalizePriorityChoices(kind, choices, choices[1] or "auto", false)
end

NormalizeRoguePoisonChoice = function(poisonCategory, value, allowNone)
    if value == "auto" then
        return "auto"
    end

    if allowNone and value == "none" then
        return "none"
    end

    for _, entry in ipairs(ns.ROGUE_POISONS or {}) do
        if entry.key == value and entry.poisonCategory == poisonCategory then
            return value
        end
    end

    return allowNone and "none" or "auto"
end

local function GetRoguePoisonEntry(poisonCategory, key)
    if key == "auto" or key == "none" then
        return nil
    end

    for _, entry in ipairs(ns.ROGUE_POISONS or {}) do
        if entry.poisonCategory == poisonCategory and entry.key == key then
            return entry
        end
    end

    return nil
end

function ns.GetRoguePoisonChoice(poisonCategory, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if setupIndex == 2 then
        local trackerConfig = EnsureSecondaryConsumableTrackerConfig("poisons")
        return trackerConfig.choices and trackerConfig.choices[poisonCategory] or "none"
    end

    if not settings then
        local defaults = consumableTrackingDefaultsTemplate.weaponPoisonChoices or {}
        return NormalizeRoguePoisonChoice(poisonCategory, defaults[poisonCategory] or "auto", false)
    end

    return settings.weaponPoisonChoices and settings.weaponPoisonChoices[poisonCategory] or "auto"
end

function ns.SetRoguePoisonChoice(poisonCategory, value, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if not settings then
        return
    end

    if setupIndex == 2 then
        local trackerConfig = EnsureSecondaryConsumableTrackerConfig("poisons")
        if type(trackerConfig.choices) ~= "table" then
            trackerConfig.choices = {}
        end
        trackerConfig.choices[poisonCategory] = NormalizeRoguePoisonChoice(poisonCategory, value, true)
        return
    end

    if type(settings.weaponPoisonChoices) ~= "table" then
        settings.weaponPoisonChoices = {}
    end

    settings.weaponPoisonChoices[poisonCategory] = NormalizeRoguePoisonChoice(poisonCategory, value, false)
end

function ns.GetConsumableChoice(kind, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if kind ~= "rune" then
        return nil
    end

    if setupIndex == 2 then
        return EnsureSecondaryConsumableTrackerConfig(kind).choice or "none"
    end

    if not settings then
        return NormalizeSingleChoice(kind, consumableTrackingDefaultsTemplate[kind .. "Choice"] or "auto", "auto", false)
    end

    return settings[kind .. "Choice"]
end

function ns.SetConsumableChoice(kind, value, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if kind ~= "rune" or not settings then
        return
    end

    if setupIndex == 2 then
        local trackerConfig = EnsureSecondaryConsumableTrackerConfig(kind)
        trackerConfig.choice = NormalizeSingleChoice(kind, value, "none", true)
        return
    end

    settings[kind .. "Choice"] = NormalizeSingleChoice(kind, value, "auto", false)
end

function ns.GetConsumableAppearance()
    if not ns.db or not ns.db.consumables then
        return ns.DEFAULTS.consumables.appearance
    end

    if type(ns.db.consumables.appearance) ~= "table" then
        ns.db.consumables.appearance = {}
    end

    if not preparedConsumableTables[ns.db.consumables.appearance] then
        CopyDefaults(ns.db.consumables.appearance, ns.DEFAULTS.consumables.appearance)
        preparedConsumableTables[ns.db.consumables.appearance] = true
    end

    return ns.db.consumables.appearance
end

function ns.GetConsumableVisibility(kind, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local defaults = ns.DEFAULTS.consumables.visibility or {}
    local settings = EnsureConsumableTrackingSettings()

    if setupIndex == 2 and kind then
        return EnsureSecondaryConsumableTrackerConfig(kind).visibility or {}
    end

    if not settings then
        return kind and defaults[kind] or defaults
    end

    if kind then
        return settings.visibility[kind]
    end

    return settings.visibility
end

function ns.GetConsumableReapplyConfig(kind, setupIndex)
    setupIndex = tonumber(setupIndex) or 1
    local settings = EnsureConsumableTrackingSettings()

    if setupIndex == 2 then
        return EnsureSecondaryConsumableTrackerConfig(kind).reapply or {
            enabled = false,
            thresholdSeconds = 1800,
        }
    end

    local defaults = ns.DEFAULTS.consumables.reapply and ns.DEFAULTS.consumables.reapply[kind] or {
        enabled = true,
        thresholdSeconds = 1800,
    }

    if not settings then
        return defaults
    end

    return settings.reapply[kind]
end

function ns.IsConsumableTrackerFilterEnabled(kind, filterKey, setupIndex)
    local visibility = ns.GetConsumableVisibility(kind, setupIndex)
    return visibility.enabledFilters and visibility.enabledFilters[filterKey] == true
end

function ns.SetConsumableTrackerFilterEnabled(kind, filterKey, enabled, setupIndex)
    local visibility = ns.GetConsumableVisibility(kind, setupIndex)
    visibility.enabledFilters[filterKey] = enabled and true or false
end

local function GetAuraBySpellID(spellID)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    end
    if AuraUtil and AuraUtil.FindAuraBySpellID then
        return AuraUtil.FindAuraBySpellID(spellID, "player", "HELPFUL")
    end
    return nil
end

local function GetAuraRemainingSeconds(aura)
    if type(aura) ~= "table" then
        return nil
    end

    local expirationTime = aura.expirationTime or aura.expirationTimeMs
    if type(expirationTime) ~= "number" or expirationTime <= 0 then
        return nil
    end

    if aura.expirationTimeMs and not aura.expirationTime then
        expirationTime = expirationTime / 1000
    end

    return math.max(0, expirationTime - GetTime())
end

local EMPTY_SPELL_IDS = {}

local function GetBestAuraRemainingSeconds(spellIDs)
    local bestRemaining

    for _, spellID in ipairs(spellIDs or EMPTY_SPELL_IDS) do
        local remaining = GetAuraRemainingSeconds(GetAuraBySpellID(spellID))
        if remaining ~= nil and (bestRemaining == nil or remaining > bestRemaining) then
            bestRemaining = remaining
        end
    end

    return bestRemaining
end

local function GetItemCountSafe(itemID)
    return (itemID and GetItemCount(itemID, false)) or 0
end

local function WipeTable(tableRef)
    for key in pairs(tableRef) do
        tableRef[key] = nil
    end
end

local entryItemCountSeen = {}
local reminderRefreshContext = {
    itemCountCache = {},
    entryCountCache = {},
    choiceAvailabilityResolved = {},
    choiceAvailableItemByEntry = {},
    choiceAvailableSpellByEntry = {},
    resolvedChoiceSeen = {},
    resolvedChoiceEntry = {},
    resolvedChoiceItemID = {},
    resolvedChoiceSpellID = {},
    resolvedChoiceUsedAuto = {},
    resolvedChoiceSawAuto = {},
    resolvedChoiceSawExplicit = {},
    resolvedChoiceHasCompatible = {},
    resolvedChoicePoisonCategory = {},
    setupIndexByKind = {},
    weaponSubclassBySlot = {},
    weaponTypeBySlot = {},
}

local function ResetReminderRefreshContext()
    local context = reminderRefreshContext
    WipeTable(context.itemCountCache)
    WipeTable(context.entryCountCache)
    WipeTable(context.choiceAvailabilityResolved)
    WipeTable(context.choiceAvailableItemByEntry)
    WipeTable(context.choiceAvailableSpellByEntry)
    WipeTable(context.resolvedChoiceSeen)
    WipeTable(context.resolvedChoiceEntry)
    WipeTable(context.resolvedChoiceItemID)
    WipeTable(context.resolvedChoiceSpellID)
    WipeTable(context.resolvedChoiceUsedAuto)
    WipeTable(context.resolvedChoiceSawAuto)
    WipeTable(context.resolvedChoiceSawExplicit)
    WipeTable(context.resolvedChoiceHasCompatible)
    WipeTable(context.resolvedChoicePoisonCategory)
    WipeTable(context.setupIndexByKind)
    WipeTable(context.weaponSubclassBySlot)
    WipeTable(context.weaponTypeBySlot)

    context.inCombatLockdown = InCombatLockdown()
    context.playerInCombat = context.inCombatLockdown or UnitAffectingCombat("player")
    context.inChallengeMode = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() or false
    context.inInstance = IsInInstance()
    context.isResting = IsResting and IsResting() or false
    context.weaponTrackingRoguePoisons = ns.IsRoguePoisonMode and ns.IsRoguePoisonMode() or false
    context.hasRoguePoisonWeaponEquipped = nil

    if context.inInstance then
        local _, instanceType, difficultyID = GetInstanceInfo()
        context.instanceType = instanceType
        context.difficultyID = difficultyID
    else
        context.instanceType = nil
        context.difficultyID = nil
    end

    return context
end

local function GetCachedItemCount(itemID, refreshContext)
    if not refreshContext or not itemID then
        return GetItemCountSafe(itemID)
    end

    local cachedCount = refreshContext.itemCountCache[itemID]
    if cachedCount ~= nil then
        return cachedCount
    end

    cachedCount = GetItemCountSafe(itemID)
    refreshContext.itemCountCache[itemID] = cachedCount
    return cachedCount
end

local function GetEntryItemCount(entry, refreshContext)
    if not entry or type(entry.items) ~= "table" then
        return 0
    end

    if refreshContext then
        local cachedCount = refreshContext.entryCountCache[entry]
        if cachedCount ~= nil then
            return cachedCount
        end
    end

    local total = 0
    WipeTable(entryItemCountSeen)
    for _, itemID in ipairs(entry.items) do
        if itemID and not entryItemCountSeen[itemID] then
            total = total + GetCachedItemCount(itemID, refreshContext)
            entryItemCountSeen[itemID] = true
        end
    end

    if refreshContext then
        refreshContext.entryCountCache[entry] = total
    end

    return total
end

function ns.GetEntryItemCount(entry)
    return GetEntryItemCount(entry, nil)
end

function ns.GetChoiceMenuEntries(kind)
    local owned = {}
    local missing = {}

    for _, entry in ipairs(ns.GetChoiceEntries(kind)) do
        local count = GetEntryItemCount(entry)
        local bucket = (ns.IsChoiceEntryAvailable and ns.IsChoiceEntryAvailable(entry)) and owned or missing
        bucket[#bucket + 1] = {
            entry = entry,
            key = entry.key,
            name = entry.name,
            count = count,
        }
    end

    return owned, missing
end

local function GetItemInstantDetails(itemID)
    if not itemID then
        return nil, nil, nil, nil
    end

    local getItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not getItemInfoInstant then
        return nil, nil, nil, nil
    end

    local _, _, _, itemEquipLoc, icon, classID, subclassID = getItemInfoInstant(itemID)
    return icon, classID, subclassID, itemEquipLoc
end

local function GetItemIconSafe(itemID)
    if not itemID then
        return 134400
    end

    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID) or nil
    if icon then
        return icon
    end

    icon = GetItemInstantDetails(itemID)
    return icon or 134400
end

local function GetSpellIconSafe(spellID)
    if not spellID then
        return 134400
    end

    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    if spellInfo and spellInfo.iconID then
        return spellInfo.iconID
    end

    local icon = GetSpellTexture and GetSpellTexture(spellID) or nil
    return icon or 134400
end

local function GetFirstOwnedItem(itemIDs, refreshContext)
    for _, itemID in ipairs(itemIDs or {}) do
        if GetCachedItemCount(itemID, refreshContext) > 0 then
            return itemID
        end
    end
    return nil
end

local function GetEntryByKey(entries, key)
    for _, entry in ipairs(entries) do
        if entry.key == key then
            return entry
        end
    end
    return nil
end

local function GetWeaponSubclassForSlot(slotID, refreshContext)
    if refreshContext then
        local cachedSubclass = refreshContext.weaponSubclassBySlot[slotID]
        if cachedSubclass ~= nil then
            return cachedSubclass ~= false and cachedSubclass or nil
        end
    end

    local itemID = GetInventoryItemID("player", slotID)
    if not itemID then
        if refreshContext then
            refreshContext.weaponSubclassBySlot[slotID] = false
        end
        return nil
    end

    local _, classID, subclassID = GetItemInstantDetails(itemID)
    local weaponClassID = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
    if classID ~= weaponClassID then
        if refreshContext then
            refreshContext.weaponSubclassBySlot[slotID] = false
        end
        return nil
    end

    if refreshContext then
        refreshContext.weaponSubclassBySlot[slotID] = subclassID
    end

    return subclassID
end

local function GetWeaponTypeForSlot(slotID, refreshContext)
    if refreshContext then
        local cachedWeaponType = refreshContext.weaponTypeBySlot[slotID]
        if cachedWeaponType ~= nil then
            return cachedWeaponType ~= false and cachedWeaponType or nil
        end
    end

    local subclassID = GetWeaponSubclassForSlot(slotID, refreshContext)
    if subclassID == nil then
        if refreshContext then
            refreshContext.weaponTypeBySlot[slotID] = false
        end
        return nil
    end

    if KNOWN_WEAPON_SUBCLASSES.BLADED[subclassID] then
        if refreshContext then
            refreshContext.weaponTypeBySlot[slotID] = "BLADED"
        end
        return "BLADED"
    end
    if KNOWN_WEAPON_SUBCLASSES.BLUNT[subclassID] then
        if refreshContext then
            refreshContext.weaponTypeBySlot[slotID] = "BLUNT"
        end
        return "BLUNT"
    end
    if KNOWN_WEAPON_SUBCLASSES.RANGED[subclassID] then
        if refreshContext then
            refreshContext.weaponTypeBySlot[slotID] = "RANGED"
        end
        return "RANGED"
    end

    if refreshContext then
        refreshContext.weaponTypeBySlot[slotID] = false
    end

    return nil
end

local function IsMeleeWeaponType(weaponType)
    return weaponType == "BLADED" or weaponType == "BLUNT"
end

local function IsWeaponTrackingRoguePoisons(refreshContext)
    if refreshContext and refreshContext.weaponTrackingRoguePoisons ~= nil then
        return refreshContext.weaponTrackingRoguePoisons
    end

    return ns.IsRoguePoisonMode and ns.IsRoguePoisonMode() or false
end

local function HasAnyRoguePoisonWeaponEquipped(refreshContext)
    if refreshContext and refreshContext.hasRoguePoisonWeaponEquipped ~= nil then
        return refreshContext.hasRoguePoisonWeaponEquipped
    end

    local hasEquipped = IsMeleeWeaponType(GetWeaponTypeForSlot(16, refreshContext)) or IsMeleeWeaponType(GetWeaponTypeForSlot(17, refreshContext))
    if refreshContext then
        refreshContext.hasRoguePoisonWeaponEquipped = hasEquipped
    end

    return hasEquipped
end

local function IsWeaponChoiceCompatible(choice, slotID, poisonCategory, refreshContext)
    if not choice then
        return false
    end

    if choice.poisonCategory then
        if not IsWeaponTrackingRoguePoisons(refreshContext) or not HasAnyRoguePoisonWeaponEquipped(refreshContext) then
            return false
        end

        return poisonCategory == nil or choice.poisonCategory == poisonCategory
    end

    local slotWeaponType = GetWeaponTypeForSlot(slotID, refreshContext)
    if slotWeaponType == nil then
        return false
    end

    if choice.weaponType == "NEUTRAL" then
        return slotWeaponType ~= "RANGED"
    end

    return slotWeaponType == choice.weaponType
end

local function ResolveChoiceAvailability(entry, refreshContext)
    if not entry then
        return nil, nil
    end

    if refreshContext and refreshContext.choiceAvailabilityResolved[entry] then
        return refreshContext.choiceAvailableItemByEntry[entry], refreshContext.choiceAvailableSpellByEntry[entry]
    end

    local itemID
    local spellID

    if entry.spellID then
        if ns.IsChoiceEntryAvailable and ns.IsChoiceEntryAvailable(entry) then
            spellID = entry.spellID
        end
    else
        itemID = GetFirstOwnedItem(entry.items, refreshContext)
    end

    if refreshContext then
        refreshContext.choiceAvailabilityResolved[entry] = true
        refreshContext.choiceAvailableItemByEntry[entry] = itemID
        refreshContext.choiceAvailableSpellByEntry[entry] = spellID
    end

    return itemID, spellID
end

local function IsConsumableTrackerSetupConfigured(kind, setupIndex)
    if kind == "poisons" then
        return (ns.GetRoguePoisonChoice("lethal", setupIndex) or "none") ~= "none"
            or (ns.GetRoguePoisonChoice("non_lethal", setupIndex) or "none") ~= "none"
    end

    if kind == "rune" then
        return (ns.GetConsumableChoice(kind, setupIndex) or "none") ~= "none"
    end

    for _, choiceKey in ipairs(ns.GetPriorityChoices(kind, setupIndex) or {}) do
        if choiceKey ~= "none" then
            return true
        end
    end

    return false
end

local DoesVisibilityMatchCurrentContext

local function DoesConsumableSetupMatchCurrentContext(kind, setupIndex, refreshContext)
    local visibility = ns.GetConsumableVisibility(kind, setupIndex)
    if not visibility then
        return true
    end

    local context = refreshContext or ResetReminderRefreshContext()
    if context.inChallengeMode then
        if visibility.showDuringMythicPlus ~= true then
            return false
        end

        if visibility.showDuringCombat == true then
            return not context.playerInCombat
        end

        return true
    end

    if visibility.showDuringCombat ~= true and context.playerInCombat then
        return false
    end

    return DoesVisibilityMatchCurrentContext(visibility, context)
end

local function GetActiveConsumableSetupIndex(kind, refreshContext)
    local context = refreshContext or ResetReminderRefreshContext()
    if context.setupIndexByKind[kind] ~= nil then
        return context.setupIndexByKind[kind] ~= false and context.setupIndexByKind[kind] or nil
    end

    for setupIndex = 1, MAX_CONSUMABLE_TRACKER_SETUPS do
        if ns.GetConsumableTrackerEnabled(kind, setupIndex)
            and IsConsumableTrackerSetupConfigured(kind, setupIndex)
            and DoesConsumableSetupMatchCurrentContext(kind, setupIndex, context)
        then
            context.setupIndexByKind[kind] = setupIndex
            return setupIndex
        end
    end

    context.setupIndexByKind[kind] = false

    return nil
end

function ns.IsConsumableTrackerSetupConfigured(kind, setupIndex)
    return IsConsumableTrackerSetupConfigured(kind, tonumber(setupIndex) or 1)
end

function ns.GetActiveConsumableTrackerSetup(kind)
    return GetActiveConsumableSetupIndex(kind, nil)
end

local resolutionScratch = {}
local singleKeyScratch = {}

local function MakeResolution(usedAuto, sawAuto, sawExplicit, hasCompatibleConfigured, poisonCategory)
    resolutionScratch.usedAuto = usedAuto
    resolutionScratch.sawAuto = sawAuto
    resolutionScratch.sawExplicit = sawExplicit
    resolutionScratch.hasCompatibleConfigured = hasCompatibleConfigured
    resolutionScratch.poisonCategory = poisonCategory
    return resolutionScratch
end

local function StoreResolvedChoice(refreshContext, cacheKey, entry, itemID, spellID, usedAuto, sawAuto, sawExplicit, hasCompatibleConfigured, poisonCategory)
    if not refreshContext or not cacheKey then
        return entry, itemID, MakeResolution(usedAuto, sawAuto, sawExplicit, hasCompatibleConfigured, poisonCategory), spellID
    end

    refreshContext.resolvedChoiceSeen[cacheKey] = true
    refreshContext.resolvedChoiceEntry[cacheKey] = entry
    refreshContext.resolvedChoiceItemID[cacheKey] = itemID
    refreshContext.resolvedChoiceSpellID[cacheKey] = spellID
    refreshContext.resolvedChoiceUsedAuto[cacheKey] = usedAuto
    refreshContext.resolvedChoiceSawAuto[cacheKey] = sawAuto
    refreshContext.resolvedChoiceSawExplicit[cacheKey] = sawExplicit
    refreshContext.resolvedChoiceHasCompatible[cacheKey] = hasCompatibleConfigured
    refreshContext.resolvedChoicePoisonCategory[cacheKey] = poisonCategory

    return entry, itemID, MakeResolution(usedAuto, sawAuto, sawExplicit, hasCompatibleConfigured, poisonCategory), spellID
end

local function ResolveConfiguredChoice(kind, slotID, poisonCategory, setupIndex, refreshContext)
    local entries
    local configuredKeys
    local resolvedSetupIndex = tonumber(setupIndex) or 1
    local cacheKey

    if refreshContext then
        cacheKey = (kind or "") .. ":" .. tostring(slotID or 0) .. ":" .. (poisonCategory or "") .. ":" .. tostring(resolvedSetupIndex)
        if refreshContext.resolvedChoiceSeen[cacheKey] then
            return refreshContext.resolvedChoiceEntry[cacheKey],
                refreshContext.resolvedChoiceItemID[cacheKey],
                MakeResolution(
                    refreshContext.resolvedChoiceUsedAuto[cacheKey],
                    refreshContext.resolvedChoiceSawAuto[cacheKey],
                    refreshContext.resolvedChoiceSawExplicit[cacheKey],
                    refreshContext.resolvedChoiceHasCompatible[cacheKey],
                    refreshContext.resolvedChoicePoisonCategory[cacheKey]
                ),
                refreshContext.resolvedChoiceSpellID[cacheKey]
        end
    end

    if kind == "flask" then
        entries = ns.FLASKS
        configuredKeys = ns.GetPriorityChoices("flask", resolvedSetupIndex)
    elseif kind == "food" then
        entries = ns.FOODS
        configuredKeys = ns.GetPriorityChoices("food", resolvedSetupIndex)
    elseif kind == "weapon" then
        entries = ns.GetChoiceEntries("weapon")
        if poisonCategory and IsWeaponTrackingRoguePoisons(refreshContext) then
            singleKeyScratch[1] = ns.GetRoguePoisonChoice(poisonCategory, resolvedSetupIndex)
            singleKeyScratch[2] = nil
            configuredKeys = singleKeyScratch
        else
            configuredKeys = ns.GetPriorityChoices("weapon", resolvedSetupIndex)
        end
    elseif kind == "poisons" then
        entries = ns.GetChoiceEntries("poisons")
        singleKeyScratch[1] = ns.GetRoguePoisonChoice(poisonCategory, resolvedSetupIndex)
        singleKeyScratch[2] = nil
        configuredKeys = singleKeyScratch
    elseif kind == "rune" then
        entries = ns.RUNES
        singleKeyScratch[1] = ns.GetConsumableChoice("rune", resolvedSetupIndex) or "auto"
        singleKeyScratch[2] = nil
        configuredKeys = singleKeyScratch
    end

    if not entries then
        return nil, nil, nil
    end

    local firstConfiguredEntry
    local firstCompatibleConfiguredEntry
    local sawExplicitChoice = false
    local sawAutoChoice = false

    for _, configuredKey in ipairs(configuredKeys or {}) do
        if configuredKey == "auto" then
            sawAutoChoice = true
        elseif configuredKey ~= "none" then
            sawExplicitChoice = true

            local configuredEntry = GetEntryByKey(entries, configuredKey)
            if configuredEntry then
                firstConfiguredEntry = firstConfiguredEntry or configuredEntry

                if kind ~= "weapon" or IsWeaponChoiceCompatible(configuredEntry, slotID, poisonCategory, refreshContext) then
                    firstCompatibleConfiguredEntry = firstCompatibleConfiguredEntry or configuredEntry

                    local itemID, spellID = ResolveChoiceAvailability(configuredEntry, refreshContext)
                    if itemID or spellID then
                        return StoreResolvedChoice(refreshContext, cacheKey, configuredEntry, itemID, spellID, false, sawAutoChoice, sawExplicitChoice, true, poisonCategory)
                    end
                end
            end
        end
    end

    if sawAutoChoice or not sawExplicitChoice then
        for _, entry in ipairs(entries) do
            if kind ~= "weapon" or IsWeaponChoiceCompatible(entry, slotID, poisonCategory, refreshContext) then
                local itemID, spellID = ResolveChoiceAvailability(entry, refreshContext)
                if itemID or spellID then
                    return StoreResolvedChoice(refreshContext, cacheKey, entry, itemID, spellID, true, sawAutoChoice, sawExplicitChoice, firstCompatibleConfiguredEntry ~= nil, poisonCategory)
                end
            end
        end

        for _, entry in ipairs(entries) do
            if kind ~= "weapon" or IsWeaponChoiceCompatible(entry, slotID, poisonCategory, refreshContext) then
                return StoreResolvedChoice(refreshContext, cacheKey, entry, nil, nil, true, sawAutoChoice, sawExplicitChoice, firstCompatibleConfiguredEntry ~= nil, poisonCategory)
            end
        end
    end

    return StoreResolvedChoice(
        refreshContext,
        cacheKey,
        firstCompatibleConfiguredEntry or firstConfiguredEntry or entries[1],
        nil,
        nil,
        false,
        sawAutoChoice,
        sawExplicitChoice,
        firstCompatibleConfiguredEntry ~= nil,
        poisonCategory
    )
end

local function HasAnyEnabledVisibilityFilters(enabledFilters)
    for _, filter in ipairs(GetConfiguredInstanceFilters()) do
        if enabledFilters[filter.key] then
            return true
        end
    end

    return false
end

local function DoesFilterMatchInstance(filter, instanceType, difficultyID, inInstance)
    if not filter or not inInstance then
        return false
    end

    if filter.instanceTypes then
        for _, candidateInstanceType in ipairs(filter.instanceTypes) do
            if candidateInstanceType == "other" then
                local recognizedType = instanceType == "party"
                    or instanceType == "raid"
                    or instanceType == "scenario"
                    or instanceType == "pvp"
                    or instanceType == "arena"
                if not recognizedType then
                    return true
                end
            elseif candidateInstanceType == instanceType then
                return true
            end
        end
    end

    if filter.difficulties then
        for _, candidateDifficultyID in ipairs(filter.difficulties) do
            if candidateDifficultyID == difficultyID then
                return true
            end
        end
    end

    return false
end

DoesVisibilityMatchCurrentContext = function(visibility, refreshContext)
    local enabledFilters = visibility.enabledFilters or {}
    if not HasAnyEnabledVisibilityFilters(enabledFilters) then
        return false
    end

    local context = refreshContext or ResetReminderRefreshContext()
    if not context.inInstance then
        if enabledFilters.city_rest_area and context.isResting then
            return true
        end

        return enabledFilters.open_world == true
    end

    for _, filter in ipairs(GetConfiguredInstanceFilters()) do
        if enabledFilters[filter.key] and DoesFilterMatchInstance(filter, context.instanceType, context.difficultyID, context.inInstance) then
            return true
        end
    end

    return false
end

local function ShouldShowConsumables()
    if not ns.db then
        return false
    end

    local moduleEnabled = ns.IsModuleRuntimeEnabled and ns.IsModuleRuntimeEnabled("consumables", ns.db.enabled) or ns.db.enabled ~= false
    if not moduleEnabled then
        return false
    end

    if UnitIsDeadOrGhost("player") then
        return false
    end

    return true
end

local reminderEntriesScratch = {}
local reminderEntryPool = {}
local reminderEntryPoolUsed = 0

local function AcquireReminderEntry()
    reminderEntryPoolUsed = reminderEntryPoolUsed + 1
    local entry = reminderEntryPool[reminderEntryPoolUsed]
    if not entry then
        entry = {}
        reminderEntryPool[reminderEntryPoolUsed] = entry
    else
        for k in pairs(entry) do entry[k] = nil end
    end
    return entry
end

local function BuildReminderEntry(kind, label, choice, itemID, targetSlot, available, reason, refreshContext)
    local iconItemID = itemID or (choice and choice.items and choice.items[1]) or nil
    local spellID = choice and choice.spellID or nil
    local entry = AcquireReminderEntry()

    entry.kind = kind
    entry.label = label
    entry.name = choice and choice.name or label
    entry.itemID = itemID
    entry.spellID = spellID
    entry.icon = spellID and GetSpellIconSafe(spellID) or GetItemIconSafe(iconItemID)
    entry.count = (choice and not spellID) and GetEntryItemCount(choice, refreshContext) or 0
    entry.targetSlot = targetSlot
    entry.available = available
    entry.reason = reason
    entry.reapplyRemainingSeconds = nil

    return entry
end

local POISON_UNAVAILABLE_STRINGS = {
    lethal = {
        no_match = "None of your selected lethal poison choices match this tracker.",
        not_known = "None of your selected lethal poison choices are currently known.",
        not_found = "No known lethal poison was found.",
    },
    non_lethal = {
        no_match = "None of your selected non-lethal poison choices match this tracker.",
        not_known = "None of your selected non-lethal poison choices are currently known.",
        not_found = "No known non-lethal poison was found.",
    },
}

local function GetUnavailableReason(kind, resolution, targetSlot)
    if (kind == "weapon" or kind == "poisons") and resolution and resolution.poisonCategory then
        local poisonStrings = POISON_UNAVAILABLE_STRINGS[resolution.poisonCategory] or POISON_UNAVAILABLE_STRINGS.non_lethal

        if resolution.sawExplicit and not resolution.hasCompatibleConfigured then
            return poisonStrings.no_match
        end

        if resolution.sawExplicit and not resolution.usedAuto then
            return poisonStrings.not_known
        end

        return poisonStrings.not_found
    end

    if kind == "weapon" and resolution and resolution.sawExplicit and not resolution.hasCompatibleConfigured then
        if targetSlot == 16 then
            return "None of your selected weapon buffs match your main hand weapon type."
        end

        return "None of your selected weapon buffs match your off hand weapon type."
    end

    if kind == "weapon" then
        if resolution and resolution.sawExplicit and not resolution.usedAuto then
            if targetSlot == 16 then
                return "None of your selected main hand buffs are in your bags."
            end

            return "None of your selected off hand buffs are in your bags."
        end

        if targetSlot == 16 then
            return "No compatible main hand buff was found in your bags."
        end

        return "No compatible off hand buff was found in your bags."
    end

    if kind == "flask" then
        if resolution and resolution.sawExplicit and not resolution.usedAuto then
            return "None of your selected flasks are in your bags."
        end

        return "No tracked flasks are in your bags."
    end

    if kind == "food" then
        if resolution and resolution.sawExplicit and not resolution.usedAuto then
            return "None of your selected foods are in your bags."
        end

        return "No tracked foods are in your bags."
    end

    if resolution and resolution.sawExplicit and not resolution.usedAuto then
        return "None of your selected augment runes are in your bags."
    end

    return "No tracked augment runes are in your bags."
end

local function GetAuraReminderState(spellIDs, reapplyConfig)
    local remaining = GetBestAuraRemainingSeconds(spellIDs)
    if remaining == nil then
        return true, nil
    end

    if reapplyConfig and reapplyConfig.enabled then
        local threshold = math.max(0, tonumber(reapplyConfig.thresholdSeconds) or 0)
        if remaining <= threshold then
            return true, remaining
        end
    end

    return false, nil
end

local function GetFoodReminderState(reapplyConfig)
    local remaining = GetBestAuraRemainingSeconds(ns.FOOD_BUFF_IDS)

    if remaining == nil then
        return true, nil
    end

    if reapplyConfig and reapplyConfig.enabled then
        local threshold = math.max(0, tonumber(reapplyConfig.thresholdSeconds) or 0)
        if remaining <= threshold then
            return true, remaining
        end
    end

    return false, nil
end

local function GetWeaponReminderStateForSlot(slotID, reapplyConfig)
    local hasMainHandEnchant, mainHandExpiration, _, _, hasOffHandEnchant, offHandExpiration = GetWeaponEnchantInfo()
    local hasEnchant = slotID == 16 and hasMainHandEnchant or hasOffHandEnchant
    local expirationMS = slotID == 16 and mainHandExpiration or offHandExpiration

    if not hasEnchant then
        return true, nil
    end

    if reapplyConfig and reapplyConfig.enabled then
        local threshold = math.max(0, tonumber(reapplyConfig.thresholdSeconds) or 0)
        local remaining = math.max(0, (tonumber(expirationMS) or 0) / 1000)
        if remaining <= threshold then
            return true, remaining
        end
    end

    return false, nil
end

local function GetRoguePoisonReminderState(poisonCategory, reapplyConfig)
    local spellIDs = ns.ROGUE_POISON_BUFF_IDS and ns.ROGUE_POISON_BUFF_IDS[poisonCategory] or nil
    return GetAuraReminderState(spellIDs or EMPTY_SPELL_IDS, reapplyConfig)
end

function ns.GetReminderEntries()
    reminderEntryPoolUsed = 0
    local entries = reminderEntriesScratch
    for k in pairs(entries) do entries[k] = nil end
    local settings = EnsureConsumableTrackingSettings()

    if type(settings) ~= "table" or not ShouldShowConsumables() then
        return entries
    end

    local refreshContext = ResetReminderRefreshContext()

    local flaskSetupIndex = GetActiveConsumableSetupIndex("flask", refreshContext)
    if flaskSetupIndex then
        local choice, itemID, resolution = ResolveConfiguredChoice("flask", nil, nil, flaskSetupIndex, refreshContext)
        local reapplyConfig = ns.GetConsumableReapplyConfig("flask", flaskSetupIndex)
        local shouldShow, remaining = GetAuraReminderState(ns.FLASK_BUFF_IDS, reapplyConfig)
        if shouldShow then
            local entry = BuildReminderEntry(
                "flask",
                "Flask",
                choice,
                itemID,
                nil,
                itemID ~= nil,
                itemID and nil or GetUnavailableReason("flask", resolution),
                refreshContext
            )
            entry.reapplyRemainingSeconds = remaining
            entries[#entries + 1] = entry
        end
    end

    local foodSetupIndex = GetActiveConsumableSetupIndex("food", refreshContext)
    if foodSetupIndex then
        local shouldShow, remaining = GetFoodReminderState(ns.GetConsumableReapplyConfig("food", foodSetupIndex))
        if shouldShow then
            local choice, itemID, resolution = ResolveConfiguredChoice("food", nil, nil, foodSetupIndex, refreshContext)
            local entry = BuildReminderEntry(
                "food",
                "Food",
                choice,
                itemID,
                nil,
                itemID ~= nil,
                itemID and nil or GetUnavailableReason("food", resolution),
                refreshContext
            )
            entry.reapplyRemainingSeconds = remaining
            entries[#entries + 1] = entry
        end
    end

    local runeSetupIndex = GetActiveConsumableSetupIndex("rune", refreshContext)
    if runeSetupIndex then
        local shouldShow, remaining = GetAuraReminderState(ns.RUNE_BUFF_IDS, ns.GetConsumableReapplyConfig("rune", runeSetupIndex))
        if shouldShow then
            local choice, itemID, resolution = ResolveConfiguredChoice("rune", nil, nil, runeSetupIndex, refreshContext)
            local entry = BuildReminderEntry(
                "rune",
                "Rune",
                choice,
                itemID,
                nil,
                itemID ~= nil,
                itemID and nil or GetUnavailableReason("rune", resolution),
                refreshContext
            )
            entry.reapplyRemainingSeconds = remaining
            entries[#entries + 1] = entry
        end
    end

    local weaponSetupIndex = GetActiveConsumableSetupIndex("weapon", refreshContext)
    if weaponSetupIndex then
        local reapplyConfig = ns.GetConsumableReapplyConfig("weapon", weaponSetupIndex)
        if not IsWeaponTrackingRoguePoisons(refreshContext) then
            local mainHandShouldShow, mainHandRemaining = GetWeaponReminderStateForSlot(16, reapplyConfig)
            if GetWeaponTypeForSlot(16, refreshContext) and mainHandShouldShow then
                local choice, itemID, resolution = ResolveConfiguredChoice("weapon", 16, nil, weaponSetupIndex, refreshContext)
                local entry = BuildReminderEntry(
                    "weapon-main",
                    "Main Hand",
                    choice,
                    itemID,
                    16,
                    itemID ~= nil,
                    itemID and nil or GetUnavailableReason("weapon", resolution, 16),
                    refreshContext
                )
                entry.reapplyRemainingSeconds = mainHandRemaining
                entries[#entries + 1] = entry
            end

            local offHandShouldShow, offHandRemaining = GetWeaponReminderStateForSlot(17, reapplyConfig)
            if GetWeaponTypeForSlot(17, refreshContext) and offHandShouldShow then
                local choice, itemID, resolution = ResolveConfiguredChoice("weapon", 17, nil, weaponSetupIndex, refreshContext)
                local entry = BuildReminderEntry(
                    "weapon-off",
                    "Off Hand",
                    choice,
                    itemID,
                    17,
                    itemID ~= nil,
                    itemID and nil or GetUnavailableReason("weapon", resolution, 17),
                    refreshContext
                )
                entry.reapplyRemainingSeconds = offHandRemaining
                entries[#entries + 1] = entry
            end
        end
    end

    local poisonsSetupIndex = GetActiveConsumableSetupIndex("poisons", refreshContext)
    if poisonsSetupIndex then
        local reapplyConfig = ns.GetConsumableReapplyConfig("poisons", poisonsSetupIndex)

        if IsWeaponTrackingRoguePoisons(refreshContext) and HasAnyRoguePoisonWeaponEquipped(refreshContext) then
            local lethalShouldShow, lethalRemaining = GetRoguePoisonReminderState("lethal", reapplyConfig)
            if lethalShouldShow then
                local choice, itemID, resolution, spellID = ResolveConfiguredChoice("poisons", nil, "lethal", poisonsSetupIndex, refreshContext)
                local entry = BuildReminderEntry(
                    "poison-lethal",
                    "Lethal Poison",
                    choice,
                    itemID,
                    nil,
                    itemID ~= nil or spellID ~= nil,
                    (itemID or spellID) and nil or GetUnavailableReason("poisons", resolution),
                    refreshContext
                )
                entry.reapplyRemainingSeconds = lethalRemaining
                entries[#entries + 1] = entry
            end

            local utilityShouldShow, utilityRemaining = GetRoguePoisonReminderState("non_lethal", reapplyConfig)
            if utilityShouldShow then
                local choice, itemID, resolution, spellID = ResolveConfiguredChoice("poisons", nil, "non_lethal", poisonsSetupIndex, refreshContext)
                local entry = BuildReminderEntry(
                    "poison-non-lethal",
                    "Non-Lethal Poison",
                    choice,
                    itemID,
                    nil,
                    itemID ~= nil or spellID ~= nil,
                    (itemID or spellID) and nil or GetUnavailableReason("poisons", resolution),
                    refreshContext
                )
                entry.reapplyRemainingSeconds = utilityRemaining
                entries[#entries + 1] = entry
            end
        end
    end

    return entries
end