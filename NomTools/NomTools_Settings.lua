local addonName, ns = ...

local CopyDefaults = ns.CopyDefaults
local CopyTableRecursive = ns.CopyTableRecursive
local EnsureCharacterRoot = ns.EnsureCharacterRoot
local EnsureEditModeRoot = ns.EnsureEditModeRoot

local MODULE_DISABLE_RELOAD_POPUP_KEY = addonName .. "ModuleDisableReload"
local MODULE_ENABLE_RELOAD_POPUP_KEY = addonName .. "ModuleEnableReload"
local MODULE_RELOAD_POPUP_PREFERRED_INDEX = rawget(_G, "STATICPOPUP_NUMDIALOGS")
local pendingModuleDisableReloads = {}
local pendingModuleEnableReloads = {}
local sessionModuleRuntimeEnabled = {}
local LIVE_TOGGLE_MODULES = {
    characterStats = true,
}
local EMPTY_DEFAULTS = {}
local RefreshModuleReloadPopups

local function IsLiveToggleModule(moduleKey)
    return moduleKey and LIVE_TOGGLE_MODULES[moduleKey] == true or false
end

local function GetSessionModuleRuntimeEnabled(moduleKey, fallbackEnabled)
    if not moduleKey then
        return fallbackEnabled ~= false
    end
    local runtimeEnabled = sessionModuleRuntimeEnabled[moduleKey]
    if runtimeEnabled == nil then
        return fallbackEnabled ~= false
    end
    return runtimeEnabled == true
end

local function SetSessionModuleRuntimeEnabled(moduleKey, enabled)
    if not moduleKey then
        return
    end

    sessionModuleRuntimeEnabled[moduleKey] = enabled == true
end

local function GetDefaultsRoot()
    return type(ns.DEFAULTS) == "table" and ns.DEFAULTS or EMPTY_DEFAULTS
end

local function GetDefaultSection(sectionKey)
    local defaults = GetDefaultsRoot()[sectionKey]
    if type(defaults) == "table" then
        return defaults
    end

    return EMPTY_DEFAULTS
end

local function BuildFallbackConsumableTrackingDefaults()
    local defaults = ns.DEFAULTS and ns.DEFAULTS.consumables or {}
    local copyTableRecursive = ns.CopyTableRecursive
    local function copyValue(value)
        if copyTableRecursive then
            return copyTableRecursive(value)
        end
        return value
    end

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
        flaskChoices = copyValue(defaults.flaskChoices),
        foodChoices = copyValue(defaults.foodChoices),
        weaponChoices = copyValue(defaults.weaponChoices),
        weaponPoisonChoices = copyValue(defaults.weaponPoisonChoices),
        reapply = copyValue(defaults.reapply),
        visibility = copyValue(defaults.visibility),
        secondary = copyValue(defaults.secondary),
        reapplyDefaultsVersion = defaults.reapplyDefaultsVersion,
    }
end

if not ns.BuildConsumableTrackingDefaults then
    ns.BuildConsumableTrackingDefaults = BuildFallbackConsumableTrackingDefaults
end

if ns.MAX_CONSUMABLE_TRACKER_SETUPS == nil then
    ns.MAX_CONSUMABLE_TRACKER_SETUPS = 2
end

if ns.CONSUMABLE_REAPPLY_DEFAULTS_VERSION == nil then
    ns.CONSUMABLE_REAPPLY_DEFAULTS_VERSION = 2
end

do
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
            return CopyTableRecursive(ns.BuildConsumableTrackingDefaults())
        end

        local characterRoot = EnsureCharacterRoot()
        local legacyConsumables = type(ns.db.consumables) == "table" and ns.db.consumables or {}

        if type(characterRoot) ~= "table" then
            CopyDefaults(legacyConsumables, ns.BuildConsumableTrackingDefaults())
            return legacyConsumables
        end

        if type(characterRoot.consumablesTracking) ~= "table" then
            characterRoot.consumablesTracking = {}
            CopyConsumableTrackingSettings(characterRoot.consumablesTracking, legacyConsumables)
        end

        CopyDefaults(characterRoot.consumablesTracking, ns.BuildConsumableTrackingDefaults())
        return characterRoot.consumablesTracking
    end

    local function IsValidChoiceKey(kind, key)
        if key == "auto" or key == "none" then
            return true
        end

        return ns.GetChoiceEntry and ns.GetChoiceEntry(kind, key) ~= nil
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
            return CopyTableRecursive(defaults)
        end

        if type(settings.secondary) ~= "table" then
            settings.secondary = {}
        end

        if type(settings.secondary[kind]) ~= "table" then
            settings.secondary[kind] = {}
        end

        CopyDefaults(settings.secondary[kind], defaults)
        return settings.secondary[kind]
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

    local function NormalizeRoguePoisonChoice(poisonCategory, value, allowNone)
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

    function ns.GetEntryItemCount()
        return 0
    end

    function ns.GetChoiceMenuEntries(kind)
        local owned = {}
        local missing = {}

        for _, entry in ipairs(ns.GetChoiceEntries and ns.GetChoiceEntries(kind) or {}) do
            local count = ns.GetEntryItemCount(entry)
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
        for key in pairs(settings) do
            settings[key] = nil
        end

        CopyConsumableTrackingSettings(settings, sourceCharacter.consumablesTracking)
        CopyDefaults(settings, ns.BuildConsumableTrackingDefaults())
        return true
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
            local trackerConfig = EnsureSecondaryConsumableTrackerConfig(kind)
            trackerConfig.choices = NormalizePriorityChoices(kind, trackerConfig.choices, "none", true)
            return trackerConfig.choices
        end

        local fallbackKey = settings and settings[kind .. "Choice"] or "auto"
        local list = NormalizePriorityChoices(kind, settings and settings[kind .. "Choices"], fallbackKey, false)

        if settings then
            settings[kind .. "Choices"] = list
        end

        return list
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

    function ns.GetRoguePoisonChoice(poisonCategory, setupIndex)
        setupIndex = tonumber(setupIndex) or 1
        local settings = EnsureConsumableTrackingSettings()

        if setupIndex == 2 then
            local trackerConfig = EnsureSecondaryConsumableTrackerConfig("poisons")
            if type(trackerConfig.choices) ~= "table" then
                trackerConfig.choices = {}
            end

            local defaultChoices = GetConsumableSetupDefaults("poisons", 2).choices or {}
            local defaultChoice = NormalizeRoguePoisonChoice(poisonCategory, defaultChoices[poisonCategory] or "none", true)
            local normalizedChoice = NormalizeRoguePoisonChoice(poisonCategory, trackerConfig.choices[poisonCategory] or defaultChoice, true)
            trackerConfig.choices[poisonCategory] = normalizedChoice
            return normalizedChoice
        end

        local defaults = ns.DEFAULTS and ns.DEFAULTS.consumables and ns.DEFAULTS.consumables.weaponPoisonChoices or {}
        local defaultChoice = NormalizeRoguePoisonChoice(poisonCategory, defaults[poisonCategory] or "auto", false)

        if not settings then
            return defaultChoice
        end

        if type(settings.weaponPoisonChoices) ~= "table" then
            settings.weaponPoisonChoices = {}
        end

        local normalizedChoice = NormalizeRoguePoisonChoice(poisonCategory, settings.weaponPoisonChoices[poisonCategory] or defaultChoice, false)
        settings.weaponPoisonChoices[poisonCategory] = normalizedChoice
        return normalizedChoice
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
            local trackerConfig = EnsureSecondaryConsumableTrackerConfig(kind)
            trackerConfig.choice = NormalizeSingleChoice(kind, trackerConfig.choice, "none", true)
            return trackerConfig.choice
        end

        local defaults = ns.DEFAULTS and ns.DEFAULTS.consumables or {}
        if not settings then
            return NormalizeSingleChoice(kind, defaults[kind .. "Choice"] or "auto", "auto", false)
        end

        settings[kind .. "Choice"] = NormalizeSingleChoice(kind, settings[kind .. "Choice"] or defaults[kind .. "Choice"] or "auto", "auto", false)
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
        local consumableDefaults = GetDefaultSection("consumables")
        local appearanceDefaults = type(consumableDefaults.appearance) == "table" and consumableDefaults.appearance or EMPTY_DEFAULTS

        if not ns.db then
            return CopyTableRecursive(appearanceDefaults)
        end

        if type(ns.db.consumables) ~= "table" then
            ns.db.consumables = {}
        end

        if type(ns.db.consumables.appearance) ~= "table" then
            ns.db.consumables.appearance = {}
        end

        CopyDefaults(ns.db.consumables.appearance, appearanceDefaults)
        return ns.db.consumables.appearance
    end

    function ns.GetConsumableVisibility(kind, setupIndex)
        setupIndex = tonumber(setupIndex) or 1
        local consumableDefaults = GetDefaultSection("consumables")
        local defaults = type(consumableDefaults.visibility) == "table" and consumableDefaults.visibility or EMPTY_DEFAULTS
        local settings = EnsureConsumableTrackingSettings()

        if setupIndex == 2 and kind then
            local trackerConfig = EnsureSecondaryConsumableTrackerConfig(kind)
            local secondaryDefaults = GetConsumableSetupDefaults(kind, 2).visibility or {}

            if type(trackerConfig.visibility) ~= "table" then
                trackerConfig.visibility = {}
            end

            CopyDefaults(trackerConfig.visibility, secondaryDefaults)
            if type(trackerConfig.visibility.enabledFilters) == "table" then
                trackerConfig.visibility.enabledFilters.party_mythic_plus = nil
            end
            return trackerConfig.visibility
        end

        if not settings then
            if kind then
                return CopyTableRecursive(defaults[kind] or EMPTY_DEFAULTS)
            end

            return CopyTableRecursive(defaults)
        end

        if type(settings.visibility) ~= "table" then
            settings.visibility = {}
        end

        CopyDefaults(settings.visibility, defaults)

        if kind then
            if type(settings.visibility[kind]) ~= "table" then
                settings.visibility[kind] = {}
            end
            CopyDefaults(settings.visibility[kind], defaults[kind] or {})
            if type(settings.visibility[kind].enabledFilters) == "table" then
                settings.visibility[kind].enabledFilters.party_mythic_plus = nil
            end
            return settings.visibility[kind]
        end

        for _, trackerKind in ipairs(CONSUMABLE_TRACKER_KEYS) do
            local trackerVisibility = settings.visibility[trackerKind]
            if type(trackerVisibility) == "table" and type(trackerVisibility.enabledFilters) == "table" then
                trackerVisibility.enabledFilters.party_mythic_plus = nil
            end
        end

        return settings.visibility
    end

    function ns.GetConsumableReapplyConfig(kind, setupIndex)
        setupIndex = tonumber(setupIndex) or 1
        local settings = EnsureConsumableTrackingSettings()

        if setupIndex == 2 then
            local trackerConfig = EnsureSecondaryConsumableTrackerConfig(kind)
            local defaults = GetConsumableSetupDefaults(kind, 2).reapply or {
                enabled = false,
                thresholdSeconds = 1800,
            }

            if type(trackerConfig.reapply) ~= "table" then
                trackerConfig.reapply = {}
            end

            CopyDefaults(trackerConfig.reapply, defaults)
            return trackerConfig.reapply
        end

        local consumableDefaults = GetDefaultSection("consumables")
        local reapplyDefaults = type(consumableDefaults.reapply) == "table" and consumableDefaults.reapply or EMPTY_DEFAULTS
        local defaults = reapplyDefaults[kind] or {
            enabled = true,
            thresholdSeconds = 1800,
        }

        if not settings then
            return defaults
        end

        if type(settings.reapply) ~= "table" then
            settings.reapply = {}
        end

        if type(settings.reapply[kind]) ~= "table" then
            settings.reapply[kind] = {}
        end

        CopyDefaults(settings.reapply[kind], defaults)
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
end

local MODULE_SETTING_GETTERS = {
    consumables = function()
        return ns.db and ns.db.enabled
    end,
    reminders = function()
        local settings = ns.GetRemindersSettings and ns.GetRemindersSettings() or nil
        return settings and settings.enabled
    end,
    dungeonDifficulty = function()
        local reminders = ns.GetRemindersSettings and ns.GetRemindersSettings() or nil
        if reminders and reminders.enabled == false then return false end
        local settings = ns.GetDungeonDifficultySettings and ns.GetDungeonDifficultySettings() or nil
        return settings and settings.enabled
    end,
    objectiveTracker = function()
        local settings = ns.GetObjectiveTrackerSettings and ns.GetObjectiveTrackerSettings() or nil
        return settings and settings.enabled
    end,
    menuBar = function()
        local settings = ns.GetMenuBarSettings and ns.GetMenuBarSettings() or nil
        return settings and settings.enabled
    end,
    greatVault = function()
        local reminders = ns.GetRemindersSettings and ns.GetRemindersSettings() or nil
        if reminders and reminders.enabled == false then return false end
        local settings = ns.GetGreatVaultSettings and ns.GetGreatVaultSettings() or nil
        return settings and settings.enabled
    end,
    talentLoadout = function()
        local reminders = ns.GetRemindersSettings and ns.GetRemindersSettings() or nil
        if reminders and reminders.enabled == false then return false end
        local settings = ns.GetTalentLoadoutSettings and ns.GetTalentLoadoutSettings() or nil
        return settings and settings.enabled
    end,
    housing = function()
        local settings = ns.GetHousingSettings and ns.GetHousingSettings() or nil
        return settings and settings.enabled
    end,
    characterStats = function()
        local settings = ns.GetCharacterStatsSettings and ns.GetCharacterStatsSettings() or nil
        return settings and settings.enabled
    end,
    worldQuests = function()
        local settings = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or nil
        return settings and settings.enabled
    end,
    classesMonk = function()
        local settings = ns.GetClassesSettings and ns.GetClassesSettings() or nil
        return settings and settings.enabled
    end,
    miscellaneous = function()
        local settings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
        return settings and settings.enabled
    end,
}

local function CaptureSessionModuleRuntimeEnabled()
    for moduleKey in pairs(sessionModuleRuntimeEnabled) do
        sessionModuleRuntimeEnabled[moduleKey] = nil
    end

    for moduleKey, getter in pairs(MODULE_SETTING_GETTERS) do
        if type(getter) == "function" then
            sessionModuleRuntimeEnabled[moduleKey] = getter() ~= false
        end
    end
end

local function MigrateLegacyReminderConfig()
    local defaultLayoutName = ns.DEFAULT_EDIT_MODE_LAYOUT or "_Global"
    local editModeRoot, layouts = EnsureEditModeRoot()
    local editModeDefaults = GetDefaultSection("editMode")
    local reminderDefaults = type(editModeDefaults.reminder) == "table" and editModeDefaults.reminder or EMPTY_DEFAULTS

    if type(editModeRoot.reminder) == "table" then
        layouts[defaultLayoutName] = layouts[defaultLayoutName] or {}
        if type(layouts[defaultLayoutName].reminder) ~= "table" then
            layouts[defaultLayoutName].reminder = CopyTableRecursive(editModeRoot.reminder)
        end
        editModeRoot.reminder = nil
    end

    if type(layouts[defaultLayoutName]) ~= "table" then
        layouts[defaultLayoutName] = {}
    end

    local reminderConfig = layouts[defaultLayoutName].reminder
    if type(reminderConfig) ~= "table" then
        reminderConfig = {}
        layouts[defaultLayoutName].reminder = reminderConfig
    end

    CopyDefaults(reminderConfig, reminderDefaults)

    if type(ns.db.anchor) == "table" then
        if reminderConfig.point == reminderDefaults.point
            and reminderConfig.x == reminderDefaults.x
            and reminderConfig.y == reminderDefaults.y
        then
            reminderConfig.point = ns.db.anchor.point or reminderConfig.point
            reminderConfig.x = ns.db.anchor.x or reminderConfig.x
            reminderConfig.y = ns.db.anchor.y or reminderConfig.y
        end
    end

    if type(ns.db.scale) == "number" and reminderConfig.scale == reminderDefaults.scale then
        reminderConfig.scale = ns.db.scale
    end

    ns.db.anchor = nil
    ns.db.scale = nil
end

local function RemoveLegacyMinimapConfig()
    if not ns.db then
        return
    end

    ns.db.minimap = nil

    local _, layouts = EnsureEditModeRoot()
    for _, layout in pairs(layouts) do
        if type(layout) == "table" then
            layout.minimapUtilityBar = nil
        end
    end
end

local function MigrateLegacyOTPosition()
    if not ns.db or type(ns.db._otPos) ~= "table" then
        return
    end

    local defaultLayoutName = ns.DEFAULT_EDIT_MODE_LAYOUT or "_Global"
    local pos = ns.db._otPos
    local defaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.objectiveTracker
        or { point = "RIGHT", x = -5, y = 0 }
    local _, layouts = EnsureEditModeRoot()

    for _, layoutData in pairs(layouts) do
        if type(layoutData) == "table" then
            if type(layoutData.objectiveTracker) ~= "table" then
                layoutData.objectiveTracker = {}
            end
            local config = layoutData.objectiveTracker
            if config.point == nil or (config.point == defaults.point and config.x == defaults.x and config.y == defaults.y) then
                config.point = pos.point or defaults.point
                config.x = pos.x or defaults.x
                config.y = pos.y or defaults.y
            end
        end
    end

    if type(layouts[defaultLayoutName]) ~= "table" then
        layouts[defaultLayoutName] = {}
    end
    if type(layouts[defaultLayoutName].objectiveTracker) ~= "table" then
        layouts[defaultLayoutName].objectiveTracker = {
            point = pos.point or defaults.point,
            x = pos.x or defaults.x,
            y = pos.y or defaults.y,
        }
    end

    ns.db._otPos = nil
end

local function MigrateLegacyDebugMode()
    if type(ns.db.globalSettings) ~= "table" then
        return
    end

    local gs = ns.db.globalSettings
    if gs.debugMode == nil then
        return
    end

    local wasEnabled = gs.debugMode == true
    if wasEnabled then
        if gs.debugModeCPU == nil then
            gs.debugModeCPU = true
        end
        if gs.debugModeMemory == nil then
            gs.debugModeMemory = true
        end
    end

    gs.debugMode = nil
end

local function MigrateTalentLoadoutSeasonSnapshot()
    if not ns.db then return end
    if type(ns.db.talentLoadout) ~= "table" then return end
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then return end

    local mapIDs = C_ChallengeMode.GetMapTable() or {}
    local names = {}
    for _, mapID in ipairs(mapIDs) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if type(name) == "string" and name ~= "" then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    local snapshot = table.concat(names, "|")

    local stored = ns.db.talentLoadout.seasonSnapshot
    if stored ~= nil and stored ~= snapshot then
        ns.db.talentLoadout.dungeonPreferences = nil
    end
    ns.db.talentLoadout.seasonSnapshot = snapshot
end

local function MigrateSharedReminderAppearanceStorage(needsMigration)
    if not ns.db then return end

    if needsMigration then
        local candidateOrder = {
            { key = "dungeonDifficulty", state = ns.db.dungeonDifficulty },
            { key = "greatVault", state = ns.db.greatVault },
            { key = "talentLoadout", state = ns.db.talentLoadout },
        }

        local selectedAppearance

        for _, candidate in ipairs(candidateOrder) do
            if type(candidate.state) == "table"
                and candidate.state.enabled == true
                and type(candidate.state.appearance) == "table"
            then
                selectedAppearance = candidate.state.appearance
                break
            end
        end

        if type(selectedAppearance) ~= "table" then
            for _, candidate in ipairs(candidateOrder) do
                if type(candidate.state) == "table" and type(candidate.state.appearance) == "table" then
                    selectedAppearance = candidate.state.appearance
                    break
                end
            end
        end

        if type(selectedAppearance) == "table" then
            if type(ns.db.reminders) ~= "table" then
                ns.db.reminders = {}
            end
            ns.db.reminders.appearance = CopyTableRecursive(selectedAppearance)
        end
    end
end

local function MigrateRemindersModuleEnabled(needsMigration)
    if not needsMigration then return end
    if not ns.db then return end
    if type(ns.db.reminders) ~= "table" then ns.db.reminders = {} end
    -- Enable parent if any individual reminder was previously enabled
    local anyEnabled = false
    if type(ns.db.dungeonDifficulty) == "table" and ns.db.dungeonDifficulty.enabled == true then
        anyEnabled = true
    end
    if type(ns.db.greatVault) == "table" and ns.db.greatVault.enabled == true then
        anyEnabled = true
    end
    if type(ns.db.talentLoadout) == "table" and ns.db.talentLoadout.enabled == true then
        anyEnabled = true
    end
    ns.db.reminders.enabled = anyEnabled
end

function ns.InitializeDatabase()
    local isFreshInstall = type(NomToolsDB) ~= "table"
    local defaultsRoot = GetDefaultsRoot()
    local automationDefaults = GetDefaultSection("automation")

    if isFreshInstall then
        NomToolsDB = {}
    end

    local needsRemindersMigration = not NomToolsDB or type(NomToolsDB.reminders) ~= "table" or NomToolsDB.reminders.enabled == nil
    local needsSharedReminderAppearanceMigration = not NomToolsDB
        or type(NomToolsDB.reminders) ~= "table"
        or type(NomToolsDB.reminders.appearance) ~= "table"
        or next(NomToolsDB.reminders.appearance) == nil

    CopyDefaults(NomToolsDB, defaultsRoot)
    ns.db = NomToolsDB

    if not isFreshInstall then
        ns.db.setupComplete = true
    end

    if type(ns.db.automation) ~= "table" then
        ns.db.automation = {}
    end
    CopyDefaults(ns.db.automation, automationDefaults)

    MigrateLegacyReminderConfig()
    if ns.MigrateLegacyConsumableConfig then
        ns.MigrateLegacyConsumableConfig()
    end
    RemoveLegacyMinimapConfig()
    MigrateLegacyOTPosition()
    MigrateLegacyDebugMode()
    MigrateRemindersModuleEnabled(needsRemindersMigration)
    MigrateTalentLoadoutSeasonSnapshot()
    MigrateSharedReminderAppearanceStorage(needsSharedReminderAppearanceMigration)
    CaptureSessionModuleRuntimeEnabled()
end

function ns.GetAutomationSettings()
    local automationDefaults = GetDefaultSection("automation")

    if not ns.db then
        return CopyTableRecursive(automationDefaults)
    end

    if type(ns.db.automation) ~= "table" then
        ns.db.automation = {}
    end

    CopyDefaults(ns.db.automation, automationDefaults)
    return ns.db.automation
end

function ns.GetGlobalSettings()
    local defaults = GetDefaultSection("globalSettings")

    if not ns.db then
        local resolvedDefaults = CopyTableRecursive(defaults)
        if resolvedDefaults.font == ns.GLOBAL_STYLE_FONT_AUTO_KEY and ns.GetPreferredGlobalFontKey then
            resolvedDefaults.font = ns.GetPreferredGlobalFontKey()
        end
        if resolvedDefaults.texture == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY and ns.GetPreferredGlobalTextureKey then
            resolvedDefaults.texture = ns.GetPreferredGlobalTextureKey()
        end
        if resolvedDefaults.borderTexture == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY and ns.GetPreferredGlobalBorderTextureKey then
            resolvedDefaults.borderTexture = ns.GetPreferredGlobalBorderTextureKey()
        end
        return resolvedDefaults
    end

    if type(ns.db.globalSettings) ~= "table" then
        ns.db.globalSettings = {}
    end

    CopyDefaults(ns.db.globalSettings, defaults)

    if ns.db.globalSettings.font == ns.GLOBAL_STYLE_FONT_AUTO_KEY and ns.GetPreferredGlobalFontKey then
        ns.db.globalSettings.font = ns.GetPreferredGlobalFontKey()
    end

    if ns.db.globalSettings.texture == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY and ns.GetPreferredGlobalTextureKey then
        ns.db.globalSettings.texture = ns.GetPreferredGlobalTextureKey()
    end

    if ns.db.globalSettings.borderTexture == ns.GLOBAL_STYLE_TEXTURE_AUTO_KEY and ns.GetPreferredGlobalBorderTextureKey then
        ns.db.globalSettings.borderTexture = ns.GetPreferredGlobalBorderTextureKey()
    end

    return ns.db.globalSettings
end

function ns.GetOptionsWindowSettings()
    local defaults = GetDefaultSection("optionsWindow")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    if type(ns.db.optionsWindow) ~= "table" then
        ns.db.optionsWindow = {}
    end

    CopyDefaults(ns.db.optionsWindow, defaults)
    return ns.db.optionsWindow
end

local function EnsureChangelogSettingsTable()
    local defaults = GetDefaultSection("changelog")

    if not ns.db then
        return nil
    end

    if type(ns.db.changelog) ~= "table" then
        ns.db.changelog = {}
    end

    CopyDefaults(ns.db.changelog, defaults)

    local popupMode = ns.db.changelog.popupMode
    if popupMode ~= "off" and popupMode ~= "all" then
        ns.db.changelog.popupMode = "important"
    end

    ns.db.changelog.lastSeenEntryId = tonumber(ns.db.changelog.lastSeenEntryId) or 0
    return ns.db.changelog
end

function ns.GetChangelogSettings()
    local defaults = GetDefaultSection("changelog")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    return EnsureChangelogSettingsTable()
end

function ns.SetChangelogSetting(settingKey, value)
    if type(settingKey) ~= "string" or settingKey == "" then
        return nil
    end

    local settings = EnsureChangelogSettingsTable()
    if not settings then
        return nil
    end

    if settingKey == "popupMode" then
        if value ~= "off" and value ~= "all" then
            value = "important"
        end
    elseif settingKey == "lastSeenEntryId" then
        value = tonumber(value) or 0
    end

    settings[settingKey] = value

    if type(NomToolsDB) == "table" then
        if type(NomToolsDB.changelog) ~= "table" then
            NomToolsDB.changelog = {}
        end
        NomToolsDB.changelog[settingKey] = value
    end

    return value
end

function ns.ResetChangelogSettingsToDefaults(options)
    if not ns.db then
        return nil
    end

    local preserveSeenState = type(options) == "table" and options.preserveSeenState == true
    local preservedLastSeenEntryId = 0
    if preserveSeenState and type(ns.db.changelog) == "table" then
        preservedLastSeenEntryId = tonumber(ns.db.changelog.lastSeenEntryId) or 0
    end

    ns.db.changelog = CopyTableRecursive(GetDefaultSection("changelog"))
    if preserveSeenState then
        ns.db.changelog.lastSeenEntryId = preservedLastSeenEntryId
    end

    if type(NomToolsDB) == "table" then
        NomToolsDB.changelog = CopyTableRecursive(ns.db.changelog)
    end

    return ns.db.changelog
end

function ns.GetDungeonDifficultySettings()
    local defaults = GetDefaultSection("dungeonDifficulty")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    if type(ns.db.dungeonDifficulty) ~= "table" then
        ns.db.dungeonDifficulty = {}
    end

    ns.db.dungeonDifficulty.demoMode = nil
    CopyDefaults(ns.db.dungeonDifficulty, defaults)
    return ns.db.dungeonDifficulty
end

function ns.GetMiscellaneousSettings()
    local defaults = GetDefaultSection("miscellaneous")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    if type(ns.db.miscellaneous) ~= "table" then
        ns.db.miscellaneous = {}
    end

    CopyDefaults(ns.db.miscellaneous, defaults)
    return ns.db.miscellaneous
end

function ns.GetCharacterStatsSettings()
    local defaults = GetDefaultSection("characterStats")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    if type(ns.db.characterStats) ~= "table" then
        ns.db.characterStats = {}
    end

    CopyDefaults(ns.db.characterStats, defaults)
    return ns.db.characterStats
end

function ns.GetObjectiveTrackerSettings()
    local defaults = GetDefaultSection("objectiveTracker")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    if type(ns.db.objectiveTracker) ~= "table" then
        ns.db.objectiveTracker = {}
    end

    CopyDefaults(ns.db.objectiveTracker, defaults)
    return ns.db.objectiveTracker
end

function ns.GetObjectiveTrackerCharacterSettings()
    if not ns.db then
        return nil
    end

    local characterRoot = EnsureCharacterRoot()
    if type(characterRoot) ~= "table" then
        return nil
    end

    if type(characterRoot.objectiveTracker) ~= "table" then
        characterRoot.objectiveTracker = {}
    end

    if type(characterRoot.objectiveTracker.collapsedSections) ~= "table" then
        characterRoot.objectiveTracker.collapsedSections = {}
    end

    return characterRoot.objectiveTracker
end

function ns.GetMenuBarSettings()
    local defaults = GetDefaultSection("menuBar")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    if type(ns.db.menuBar) ~= "table" then
        ns.db.menuBar = {}
    end

    CopyDefaults(ns.db.menuBar, defaults)
    return ns.db.menuBar
end

function ns.GetGreatVaultSettings()
    local defaults = GetDefaultSection("greatVault")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    if type(ns.db.greatVault) ~= "table" then
        ns.db.greatVault = {}
    end

    ns.db.greatVault.demoMode = nil
    CopyDefaults(ns.db.greatVault, defaults)
    return ns.db.greatVault
end

function ns.GetRemindersSettings()
    local defaults = GetDefaultSection("reminders")
    if not ns.db then return CopyTableRecursive(defaults) end
    if type(ns.db.reminders) ~= "table" then ns.db.reminders = {} end
    CopyDefaults(ns.db.reminders, defaults)
    return ns.db.reminders
end

function ns.GetTalentLoadoutSettings()
    local defaults = GetDefaultSection("talentLoadout")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    if type(ns.db.talentLoadout) ~= "table" then
        ns.db.talentLoadout = {}
    end

    ns.db.talentLoadout.demoMode = nil
    CopyDefaults(ns.db.talentLoadout, defaults)
    return ns.db.talentLoadout
end

local function EnsureHousingSettingsTable()
    local defaults = GetDefaultSection("housing")

    if not ns.db then
        return nil
    end

    if type(ns.db.housing) ~= "table" then
        ns.db.housing = {}
    end

    CopyDefaults(ns.db.housing, defaults)
    return ns.db.housing
end

function ns.GetHousingSettings()
    local defaults = GetDefaultSection("housing")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    return EnsureHousingSettingsTable()
end

function ns.SetHousingSetting(settingKey, value)
    if type(settingKey) ~= "string" or settingKey == "" then
        return nil
    end

    local housingSettings = EnsureHousingSettingsTable()
    if not housingSettings then
        return nil
    end

    housingSettings[settingKey] = value
    if type(NomToolsDB) == "table" then
        if type(NomToolsDB.housing) ~= "table" then
            NomToolsDB.housing = {}
        end
        NomToolsDB.housing[settingKey] = value
    end
    return value
end

function ns.CommitHousingSettings()
    local housingSettings = EnsureHousingSettingsTable()
    if not housingSettings then
        return
    end

    housingSettings.enabled = housingSettings.enabled == true
    housingSettings.customSort = housingSettings.customSort ~= false
    housingSettings.showNewMarkers = housingSettings.showNewMarkers ~= false
    housingSettings.newMarkersFirstOwnershipOnly = housingSettings.newMarkersFirstOwnershipOnly == true
end

local function EnsureWorldQuestsSettingsTable()
    local defaults = GetDefaultSection("worldQuests")

    if not ns.db then
        return nil
    end

    if type(ns.db.worldQuests) ~= "table" then
        ns.db.worldQuests = {}
    end

    CopyDefaults(ns.db.worldQuests, defaults)
    return ns.db.worldQuests
end

function ns.GetWorldQuestsSettings()
    local defaults = GetDefaultSection("worldQuests")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    return EnsureWorldQuestsSettingsTable()
end

local function EnsureClassesSettingsTable()
    local defaults = GetDefaultSection("classes")

    if not ns.db then
        return nil
    end

    if type(ns.db.classes) ~= "table" then
        ns.db.classes = {}
    end

    local classesSettings = ns.db.classes
    local hadExplicitEnabled = classesSettings.enabled ~= nil
    local legacyMonkModuleEnabled = nil
    if type(classesSettings.monk) == "table" and classesSettings.monk.moduleEnabled ~= nil then
        legacyMonkModuleEnabled = classesSettings.monk.moduleEnabled == true
    end

    CopyDefaults(classesSettings, defaults)

    if not hadExplicitEnabled then
        if legacyMonkModuleEnabled ~= nil then
            classesSettings.enabled = legacyMonkModuleEnabled
        else
            classesSettings.enabled = defaults.enabled == true
        end
    else
        classesSettings.enabled = classesSettings.enabled == true
    end

    if type(classesSettings.monk) ~= "table" then
        classesSettings.monk = {}
    end

    CopyDefaults(classesSettings.monk, defaults.monk or EMPTY_DEFAULTS)
    return classesSettings
end

function ns.GetClassesSettings()
    local defaults = GetDefaultSection("classes")

    if not ns.db then
        return CopyTableRecursive(defaults)
    end

    return EnsureClassesSettingsTable()
end

function ns.GetMonkChiBarSettings()
    local defaults = GetDefaultSection("classes")

    if not ns.db then
        return CopyTableRecursive(defaults.monk or EMPTY_DEFAULTS)
    end

    local classesSettings = EnsureClassesSettingsTable()
    if type(classesSettings) ~= "table" then
        return CopyTableRecursive(defaults.monk or EMPTY_DEFAULTS)
    end

    if type(classesSettings.monk) ~= "table" then
        classesSettings.monk = {}
    end

    CopyDefaults(classesSettings.monk, defaults.monk or EMPTY_DEFAULTS)
    return classesSettings.monk
end

function ns.ResetStandaloneWindowPositions()
    if not ns.db or type(ns.DEFAULTS) ~= "table" then
        return
    end

    ns.db.optionsWindow = CopyTableRecursive(ns.DEFAULTS.optionsWindow or {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    })

    if ns.ResetOptionsWindowPosition then
        ns.ResetOptionsWindowPosition()
    end

    if ns.ResetSetupWizardWindowPositions then
        ns.ResetSetupWizardWindowPositions()
    end

    if ns.ResetChangelogPopupWindowPositions then
        ns.ResetChangelogPopupWindowPositions()
    end
end

function ns.SetWorldQuestsSetting(settingKey, value)
    if type(settingKey) ~= "string" or settingKey == "" then
        return nil
    end

    local settings = EnsureWorldQuestsSettingsTable()
    if not settings then
        return nil
    end

    settings[settingKey] = value
    if type(NomToolsDB) == "table" then
        if type(NomToolsDB.worldQuests) ~= "table" then
            NomToolsDB.worldQuests = {}
        end
        NomToolsDB.worldQuests[settingKey] = value
    end
    return value
end

local function UpdatePendingModuleReloadState(moduleKey, enabled, options)
    local normalizedEnabled = enabled ~= false
    local forceReloadPrompt = type(options) == "table" and options.forceReloadPrompt == true
    local liveToggleModule = IsLiveToggleModule(moduleKey) and not forceReloadPrompt

    if type(moduleKey) ~= "string" or moduleKey == "" then
        return normalizedEnabled, liveToggleModule
    end

    if liveToggleModule then
        pendingModuleEnableReloads[moduleKey] = nil
        pendingModuleDisableReloads[moduleKey] = nil
        return normalizedEnabled, true
    end

    local runtimeEnabled = GetSessionModuleRuntimeEnabled(moduleKey, normalizedEnabled)

    if normalizedEnabled == runtimeEnabled then
        pendingModuleEnableReloads[moduleKey] = nil
        pendingModuleDisableReloads[moduleKey] = nil
    elseif normalizedEnabled then
        pendingModuleDisableReloads[moduleKey] = nil
        pendingModuleEnableReloads[moduleKey] = true
    else
        pendingModuleEnableReloads[moduleKey] = nil
        pendingModuleDisableReloads[moduleKey] = true
    end

    return normalizedEnabled, false
end

function ns.ResetOptionsToDefaults()
    if not ns.db then
        return
    end

    if type(ns.DEFAULTS) ~= "table" then
        return
    end

    local savedEnabled = ns.db.enabled
    local savedSetupComplete = ns.db.setupComplete
    local savedClassesEnabled = type(ns.db.classes) == "table" and ns.db.classes.enabled or nil
    local savedModuleEnabled = {}
    local moduleKeys = { "dungeonDifficulty", "objectiveTracker", "menuBar", "greatVault", "housing", "worldQuests", "reminders", "talentLoadout" }
    for _, key in ipairs(moduleKeys) do
        if type(ns.db[key]) == "table" then
            savedModuleEnabled[key] = ns.db[key].enabled
        end
    end

    ns.db.automation = CopyTableRecursive(ns.DEFAULTS.automation)
    ns.db.globalSettings = CopyTableRecursive(ns.DEFAULTS.globalSettings)
    ns.db.dungeonDifficulty = CopyTableRecursive(ns.DEFAULTS.dungeonDifficulty)
    ns.db.objectiveTracker = CopyTableRecursive(ns.DEFAULTS.objectiveTracker)
    ns.db.minimap = nil
    ns.db.menuBar = CopyTableRecursive(ns.DEFAULTS.menuBar)
    ns.db.greatVault = CopyTableRecursive(ns.DEFAULTS.greatVault)
    ns.db.reminders = CopyTableRecursive(ns.DEFAULTS.reminders)
    ns.db.talentLoadout = CopyTableRecursive(ns.DEFAULTS.talentLoadout)
    if ns.ResetChangelogSettingsToDefaults then
        ns.ResetChangelogSettingsToDefaults({ preserveSeenState = true })
    else
        local preservedLastSeenEntryId = type(ns.db.changelog) == "table" and tonumber(ns.db.changelog.lastSeenEntryId) or 0
        ns.db.changelog = CopyTableRecursive(GetDefaultSection("changelog"))
        ns.db.changelog.lastSeenEntryId = preservedLastSeenEntryId
    end
    ns.db.consumables = CopyTableRecursive(ns.DEFAULTS.consumables)
    ns.db.consumables.reapplyDefaultsVersion = ns.CONSUMABLE_REAPPLY_DEFAULTS_VERSION or ns.db.consumables.reapplyDefaultsVersion
    do
        local characterRoot = EnsureCharacterRoot()
        if type(characterRoot) == "table" and ns.BuildConsumableTrackingDefaults then
            characterRoot.consumablesTracking = ns.BuildConsumableTrackingDefaults()
            characterRoot.consumablesTracking.reapplyDefaultsVersion = ns.CONSUMABLE_REAPPLY_DEFAULTS_VERSION or characterRoot.consumablesTracking.reapplyDefaultsVersion
        end
    end
    if ns.db.housing then
        ns.db.housing.customSort = ns.DEFAULTS.housing.customSort
        ns.db.housing.showNewMarkers = ns.DEFAULTS.housing.showNewMarkers
        ns.db.housing.newMarkersFirstOwnershipOnly = ns.DEFAULTS.housing.newMarkersFirstOwnershipOnly
    end
    ns.db.classes = CopyTableRecursive(GetDefaultSection("classes"))
    ns.db.worldQuests = CopyTableRecursive(GetDefaultSection("worldQuests"))
    ns.db.editMode = CopyTableRecursive(ns.DEFAULTS.editMode)
    ns.ResetStandaloneWindowPositions()

    ns.db.enabled = savedEnabled
    ns.db.setupComplete = savedSetupComplete
    if savedClassesEnabled ~= nil and type(ns.db.classes) == "table" then
        ns.db.classes.enabled = savedClassesEnabled
    end
    for _, key in ipairs(moduleKeys) do
        if savedModuleEnabled[key] ~= nil and type(ns.db[key]) == "table" then
            ns.db[key].enabled = savedModuleEnabled[key]
        end
    end

    for moduleKey in pairs(pendingModuleDisableReloads) do
        pendingModuleDisableReloads[moduleKey] = nil
    end
    for moduleKey in pairs(pendingModuleEnableReloads) do
        pendingModuleEnableReloads[moduleKey] = nil
    end
    for moduleKey, getter in pairs(MODULE_SETTING_GETTERS) do
        if type(getter) == "function" then
            UpdatePendingModuleReloadState(moduleKey, getter())
        end
    end

    if RefreshModuleReloadPopups then
        RefreshModuleReloadPopups()
    end
end

function ns.ClearPendingModuleDisableReloads()
    for moduleKey in pairs(pendingModuleDisableReloads) do
        pendingModuleDisableReloads[moduleKey] = nil
    end

    if StaticPopup_Hide then
        StaticPopup_Hide(MODULE_DISABLE_RELOAD_POPUP_KEY)
    end
end

function ns.ClearPendingModuleEnableReloads()
    for moduleKey in pairs(pendingModuleEnableReloads) do
        pendingModuleEnableReloads[moduleKey] = nil
    end

    if StaticPopup_Hide then
        StaticPopup_Hide(MODULE_ENABLE_RELOAD_POPUP_KEY)
    end
end

function ns.IsModulePendingDisableReload(moduleKey)
    return moduleKey and pendingModuleDisableReloads[moduleKey] == true or false
end

function ns.IsModulePendingEnableReload(moduleKey)
    return moduleKey and pendingModuleEnableReloads[moduleKey] == true or false
end

function ns.IsModuleConfiguredEnabled(moduleKey)
    local getter = moduleKey and MODULE_SETTING_GETTERS[moduleKey] or nil
    if type(getter) ~= "function" then
        return true
    end

    local enabled = getter()
    return enabled ~= false
end

function ns.IsModuleRuntimeEnabled(moduleKey, enabled)
    if not GetSessionModuleRuntimeEnabled(moduleKey, enabled) then
        return false
    end

    if ns.IsModuleAddonAvailable and not ns.IsModuleAddonAvailable(moduleKey) then
        return false
    end

    return true
end

function ns.IsModuleActiveInSession(moduleKey)
    if type(moduleKey) ~= "string" or moduleKey == "" then
        return true
    end

    return ns.IsModuleRuntimeEnabled(moduleKey, ns.IsModuleConfiguredEnabled(moduleKey))
end

local function EnsureModuleEnableReloadPopupRegistered()
    if not StaticPopupDialogs then
        return
    end

    StaticPopupDialogs[MODULE_ENABLE_RELOAD_POPUP_KEY] = {
        text = "A NomTools module has been enabled.\n\nA UI reload is required for the change to take full effect.",
        button1 = RELOADUI or "Reload",
        button2 = rawget(_G, "LATER") or "Later",
        OnAccept = function()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = MODULE_RELOAD_POPUP_PREFERRED_INDEX,
    }
end

local function EnsureModuleDisableReloadPopupRegistered()
    if not StaticPopupDialogs then
        return
    end

    StaticPopupDialogs[MODULE_DISABLE_RELOAD_POPUP_KEY] = {
        text = "A NomTools module has been disabled.\n\nA UI reload is required for the change to take full effect.",
        button1 = RELOADUI or "Reload",
        button2 = rawget(_G, "LATER") or "Later",
        OnAccept = function()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = MODULE_RELOAD_POPUP_PREFERRED_INDEX,
    }
end

RefreshModuleReloadPopups = function()
    local hasPendingEnableReloads = next(pendingModuleEnableReloads) ~= nil
    local hasPendingDisableReloads = next(pendingModuleDisableReloads) ~= nil

    if StaticPopup_Hide then
        if not hasPendingEnableReloads then
            StaticPopup_Hide(MODULE_ENABLE_RELOAD_POPUP_KEY)
        end
        if not hasPendingDisableReloads then
            StaticPopup_Hide(MODULE_DISABLE_RELOAD_POPUP_KEY)
        end
    end

    if not StaticPopup_Show then
        return
    end

    if hasPendingEnableReloads then
        EnsureModuleEnableReloadPopupRegistered()
        StaticPopup_Show(MODULE_ENABLE_RELOAD_POPUP_KEY)
    end

    if hasPendingDisableReloads then
        EnsureModuleDisableReloadPopupRegistered()
        StaticPopup_Show(MODULE_DISABLE_RELOAD_POPUP_KEY)
    end
end

function ns.SetModuleEnabled(moduleKey, enabled, applySetting, options)
    if type(applySetting) ~= "function" then
        return true
    end

    local normalizedEnabled = enabled ~= false
    local liveToggleModule
    applySetting(normalizedEnabled and true or false)

    normalizedEnabled, liveToggleModule = UpdatePendingModuleReloadState(moduleKey, normalizedEnabled, options)

    if liveToggleModule then
        SetSessionModuleRuntimeEnabled(moduleKey, normalizedEnabled)
    end

    if liveToggleModule and ns.ApplyModuleRuntimeState then
        ns.ApplyModuleRuntimeState(moduleKey)
    end

    RefreshModuleReloadPopups()

    if ns.RequestRefresh then
        if liveToggleModule and moduleKey then
            ns.RequestRefresh(normalizedEnabled and "options" or { moduleKey, "options" })
        else
            ns.RequestRefresh("options")
        end
    end

    if not liveToggleModule then
        return false
    end

    return normalizedEnabled
end