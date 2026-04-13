local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

local CONFIG_KEY = "objectiveTracker"
local FOCUSED_TRACKER_NAME = addonName .. "FocusedObjectiveTracker"
local FOCUSED_TRACKER_HEADER = "Focused Quest"
local ZONE_TRACKER_NAME = addonName .. "ZoneObjectiveTracker"
local ZONE_TRACKER_HEADER = ZONE or "Zone"
local TRACK_ALL_BUTTON_TEXT = QUEST_LOG_TRACK_ALL or "Track All"
-- Frequently-referenced layout constants kept as top-level locals for readability.
local TRACKER_SCROLL_CLIP_LEFT_PADDING = 20
local TRACKER_MODULE_HEADER_RIGHT_EXTENSION = 0
local DEFAULT_STATUSBAR_TEXTURE_PATH = "Interface\\TargetingFrame\\UI-StatusBar"

-- All other constants live in a single table to stay under the 200-local chunk limit.
local K = {
    TRACKER_SCROLL_STEP = 48,
    TRACKER_MAX_LAYOUT_HEIGHT = 10000,
    TRACKER_LAYOUT_INITIAL_BUDGET = 1200,
    TRACKER_LAYOUT_BUDGET_PADDING = 400,
    ZONE_TASK_RETRY_INTERVAL_SECONDS = 0.4,
    ZONE_TASK_RETRY_MAX_ATTEMPTS = 20,
    TRACKER_BUTTON_WIDTH = 78,
    TRACKER_BUTTON_HEIGHT = 18,
    QUEST_LOG_BUTTON_WIDTH = 78,
    QUEST_LOG_BUTTON_HEIGHT = 20,
    SCROLL_BAR_DEFAULT_WIDTH = 4,
    SCROLL_BAR_MIN_WIDTH = 1,
    SCROLL_BAR_MAX_WIDTH = 24,
    SCROLL_BAR_MIN_THUMB_HEIGHT = 24,
    TRACKER_RIGHT_INSET_PADDING = 10,
    TRACKER_HEADER_BUTTON_RIGHT_INSET = 4,
    TRACKER_VISUAL_LEFT_EXTENSION = 10,
    TRACKER_HEADER_TEXT = "Objective Tracker",
    LEVEL_PREFIX_MODE_ALL = "all",
    LEVEL_PREFIX_MODE_TRIVIAL = "trivial",
    LEVEL_PREFIX_MODE_NONE = "none",
    WARBAND_COMPLETION_TOOLTIP = ACCOUNT_COMPLETED_QUEST_NOTICE or "Your Warband previously completed this quest.",
    WARBAND_COMPLETION_ICON_SIZE = 20,
    WARBAND_COMPLETION_ICON_ATLASES = {
        "warbands-icon",
        "questlog-questtypeicon-account",
    },
    WARBAND_COMPLETION_CHECK_ATLASES = {
        "common-icon-checkmark-yellow",
        "common-icon-checkmark",
    },
    DEFAULT_PROGRESS_BORDER_SIZE = 1,
    MIN_PROGRESS_BORDER_SIZE = -10,
    MAX_PROGRESS_BORDER_SIZE = 10,
    DEFAULT_CHROME_BORDER_SIZE = 1,
    MIN_CHROME_BORDER_SIZE = -10,
    MAX_CHROME_BORDER_SIZE = 10,
    DEFAULT_SCROLL_BAR_COLOR = {
        r = 1,
        g = 0.82,
        b = 0,
        a = 0.9,
    },
    LEGACY_SCROLL_BAR_COLOR = {
        r = 0.88,
        g = 0.88,
        b = 0.88,
        a = 0.9,
    },
    DEFAULT_SCROLL_BAR_BACKGROUND_COLOR = {
        r = 0,
        g = 0,
        b = 0,
        a = 0.8,
    },
    DEFAULT_SCROLL_BAR_BORDER_COLOR = {
        r = 0,
        g = 0,
        b = 0,
        a = 1,
    },
    DEFAULT_UNCOMPLETED_COLOR = {
        r = 1,
        g = 1,
        b = 1,
        a = 1,
    },
    DEFAULT_COMPLETED_COLOR = {
        r = 0.36,
        g = 0.95,
        b = 0.45,
        a = 1,
    },
    DEFAULT_PROGRESS_FILL_COLOR = {
        r = 0.26,
        g = 0.42,
        b = 1,
        a = 1,
    },
    DEFAULT_PROGRESS_LOW_FILL_COLOR = {
        r = 0.90,
        g = 0.18,
        b = 0.18,
        a = 1,
    },
    DEFAULT_PROGRESS_MEDIUM_FILL_COLOR = {
        r = 0.95,
        g = 0.82,
        b = 0.18,
        a = 1,
    },
    DEFAULT_PROGRESS_HIGH_FILL_COLOR = {
        r = 0.28,
        g = 0.82,
        b = 0.32,
        a = 1,
    },
    DEFAULT_PROGRESS_BACKGROUND_COLOR = {
        r = 0.04,
        g = 0.07,
        b = 0.18,
        a = 0.85,
    },
    LEGACY_PROGRESS_BORDER_COLOR = {
        r = 0.96,
        g = 0.82,
        b = 0.28,
        a = 1,
    },
    DEFAULT_PROGRESS_BORDER_COLOR = {
        r = 0,
        g = 0,
        b = 0,
        a = 1,
    },
    DEFAULT_HEADER_BACKGROUND_COLOR = {
        r = 0,
        g = 0,
        b = 0,
        a = 1,
    },
    DEFAULT_HEADER_BORDER_COLOR = {
        r = 0,
        g = 0,
        b = 0,
        a = 1,
    },
    DEFAULT_ZONE_DIVIDER_BG_COLOR = {
        r = 0.05,
        g = 0.05,
        b = 0.05,
        a = 0.6,
    },
    DEFAULT_ZONE_DIVIDER_BORDER_COLOR = {
        r = 0.3,
        g = 0.3,
        b = 0.3,
        a = 1,
    },
    DEFAULT_ZONE_DIVIDER_TEXT_COLOR = {
        r = 0.8,
        g = 0.72,
        b = 0.42,
        a = 1,
    },
    DEFAULT_ZONE_DIVIDER_LINE_COLOR = {
        r = 0.8,
        g = 0.72,
        b = 0.42,
        a = 0.5,
    },
}
K.GRADIENT_SOLID = CreateColor(1, 1, 1, 1)
K.GRADIENT_TRANSPARENT = CreateColor(1, 1, 1, 0)
K.DEFAULT_QUEST_KIND_TITLE_COLORS = {
    quest = {
        r = 1,
        g = 0.82,
        b = 0,
        a = 1,
    },
    worldQuest = {
        r = 0.46,
        g = 0.84,
        b = 1,
        a = 1,
    },
    bonusObjective = {
        r = 0.18,
        g = 0.88,
        b = 0.76,
        a = 1,
    },
}
K.DEFAULT_SPECIAL_TITLE_COLORS = {
    quest = K.DEFAULT_QUEST_KIND_TITLE_COLORS.quest,
    worldQuest = K.DEFAULT_QUEST_KIND_TITLE_COLORS.worldQuest,
    bonusObjective = K.DEFAULT_QUEST_KIND_TITLE_COLORS.bonusObjective,
    daily = {
        r = 0.32,
        g = 0.63,
        b = 1,
        a = 1,
    },
    weekly = {
        r = 0.32,
        g = 0.63,
        b = 1,
        a = 1,
    },
    meta = {
        r = 0.32,
        g = 0.63,
        b = 1,
        a = 1,
    },
    important = {
        r = 0.52,
        g = 0.38,
        b = 0.74,
        a = 1,
    },
    prey = {
        r = 0.92,
        g = 0.18,
        b = 0.18,
        a = 1,
    },
    campaign = {
        r = 1,
        g = 0.4,
        b = 0.7,
        a = 1,
    },
    trivial = {
        r = 0.58,
        g = 0.58,
        b = 0.58,
        a = 1,
    },
    legendary = {
        r = 1,
        g = 0.5,
        b = 0,
        a = 1,
    },
}
K.LEGACY_ZONE_TITLE_COLOR_KEYS = {
    "quest",
    "worldQuest",
    "bonusObjective",
}
K.UIPANEL_BUTTON_ART_REGION_KEYS = {
    "Left",
    "Middle",
    "Right",
    "LeftDisabled",
    "MiddleDisabled",
    "RightDisabled",
    "LeftHighlight",
    "MiddleHighlight",
    "RightHighlight",
}

K.DEFAULT_ORDER = {
    "search",
    "scenario",
    "uiWidget",
    "focusedQuest",
    "campaign",
    "zone",
    "quest",
    "adventure",
    "achievement",
    "monthlyActivities",
    "initiativeTasks",
    "professionsRecipe",
    "bonusObjective",
    "worldQuest",
}

K.LEGACY_DEFAULT_ORDER = {
    "scenario",
    "uiWidget",
    "campaign",
    "zone",
    "focusedQuest",
    "quest",
    "adventure",
    "achievement",
    "monthlyActivities",
    "initiativeTasks",
    "professionsRecipe",
    "bonusObjective",
    "worldQuest",
}

local RoundNearestInteger
local NormalizeBorderSize

RoundNearestInteger = function(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

NormalizeBorderSize = function(value, defaultValue, minimum, maximum)
    local resolvedValue = tonumber(value)
    if resolvedValue == nil then
        resolvedValue = tonumber(defaultValue) or 1
    end

    resolvedValue = RoundNearestInteger(resolvedValue)
    if resolvedValue < minimum then
        return minimum
    end
    if resolvedValue > maximum then
        return maximum
    end

    return resolvedValue
end

K.ORDER_LABELS = {
    focusedQuest = FOCUSED_TRACKER_HEADER,
    scenario = TRACKER_HEADER_SCENARIO or "Scenario",
    uiWidget = "Zone Widgets",
    campaign = TRACKER_HEADER_CAMPAIGN_QUESTS or "Campaign Quests",
    zone = ZONE_TRACKER_HEADER,
    quest = TRACKER_HEADER_QUESTS or "Quests",
    adventure = ADVENTURE_TRACKING_MODULE_HEADER_TEXT or "Adventure",
    achievement = TRACKER_HEADER_ACHIEVEMENTS or "Achievements",
    monthlyActivities = TRACKER_HEADER_MONTHLY_ACTIVITIES or "Monthly Activities",
    initiativeTasks = TRACKER_HEADER_INITIATIVE_TASKS or "Initiative Tasks",
    professionsRecipe = "Professions",
    bonusObjective = TRACKER_HEADER_BONUS_OBJECTIVES or "Bonus Objectives",
    worldQuest = TRACKER_HEADER_WORLD_QUESTS or "World Quests",
    search = "Search",
}

K.ZONE_FILTER_LABELS = {
    regularQuests = "Regular quests",
    campaignQuests = "Campaign quests",
    worldQuests = "World quests",
    bonusObjectives = "Bonus objectives",
}

K.ZONE_FILTER_KEYS = {
    "regularQuests",
    "campaignQuests",
    "worldQuests",
    "bonusObjectives",
}

K.SEARCH_FRAME_HEIGHT = 16
K.SEARCH_DEBOUNCE_INTERVAL = 0.25
K.SEARCH_PLACEHOLDER_TEXT = "Search quests..."

K.FILTER_QUEST_TYPE_KEYS = {
    "regular",
    "campaign",
    "daily",
    "weekly",
    "prey",
    "legendary",
    "important",
    "meta",
    "bonusObjective",
    "worldQuest",
}

K.FILTER_QUEST_TYPE_LABELS = {
    regular = "Regular",
    campaign = TRACKER_HEADER_CAMPAIGN_QUESTS or "Campaign",
    daily = DAILY or "Daily",
    weekly = WEEKLY or "Weekly",
    prey = "Prey",
    legendary = "Legendary",
    important = "Important",
    meta = "Meta",
    bonusObjective = TRACKER_HEADER_BONUS_OBJECTIVES or "Bonus Objectives",
    worldQuest = TRACKER_HEADER_WORLD_QUESTS or "World Quests",
}

K.SORT_MODE_KEYS = {
    "default",
    "name",
}

K.SORT_MODE_LABELS = {
    default = "Default (Blizzard)",
    name = "Name (Alphabetical)",
}

K.FILTER_DROP_WIDTH = 200

K.ZONE_TRACKER_SETTINGS = {
    headerText = ZONE_TRACKER_HEADER,
    events = {
        "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED",
        "QUEST_LOG_UPDATE",
        "QUEST_DATA_LOAD_RESULT",
        "QUEST_WATCH_LIST_CHANGED",
        "QUEST_AUTOCOMPLETE",
        "SUPER_TRACKING_CHANGED",
        "QUEST_TURNED_IN",
        "QUEST_POI_UPDATE",
        "CRITERIA_COMPLETE",
        "SCENARIO_BONUS_VISIBILITY_UPDATE",
        "SCENARIO_CRITERIA_UPDATE",
        "SCENARIO_UPDATE",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
    },
    lineTemplate = "QuestObjectiveLineTemplate",
    blockTemplate = "ObjectiveTrackerQuestPOIBlockTemplate",
    progressBarTemplate = "BonusTrackerProgressBarTemplate",
    rightEdgeFrameSpacing = 2,
    questItemButtonSettings = {
        template = "QuestObjectiveItemButtonTemplate",
        offsetX = 0,
        offsetY = 0,
    },
    findGroupButtonSettings = {
        template = "QuestObjectiveFindGroupButtonTemplate",
        offsetX = 5,
        offsetY = 2,
    },
    completedSupersededObjectives = {},
}

K.FOCUSED_TRACKER_SETTINGS = {
    headerText = FOCUSED_TRACKER_HEADER,
    events = {
        "SUPER_TRACKING_CHANGED",
        "QUEST_LOG_UPDATE",
        "QUEST_DATA_LOAD_RESULT",
        "QUEST_TURNED_IN",
        "QUEST_REMOVED",
        "QUEST_POI_UPDATE",
        "QUEST_WATCH_LIST_CHANGED",
        "QUEST_AUTOCOMPLETE",
    },
    lineTemplate = K.ZONE_TRACKER_SETTINGS.lineTemplate,
    blockTemplate = K.ZONE_TRACKER_SETTINGS.blockTemplate,
    progressBarTemplate = K.ZONE_TRACKER_SETTINGS.progressBarTemplate,
    rightEdgeFrameSpacing = K.ZONE_TRACKER_SETTINGS.rightEdgeFrameSpacing,
    questItemButtonSettings = K.ZONE_TRACKER_SETTINGS.questItemButtonSettings,
    findGroupButtonSettings = K.ZONE_TRACKER_SETTINGS.findGroupButtonSettings,
    completedSupersededObjectives = K.ZONE_TRACKER_SETTINGS.completedSupersededObjectives,
}

local eventFrame = CreateFrame("Frame")
local state = {
    trackerHooksInstalled = false,
    frameHooksInstalled = false,
    managerInitHookInstalled = false,
    worldMapHooksInstalled = false,
    blockHooksInstalled = false,
    collapseHooksInstalled = false,
    focusedQuestModule = nil,
    zoneModule = nil,
    trackerButton = nil,
    questLogButton = nil,
    scrollClipFrame = nil,
    scrollBar = nil,
    scrollOffset = 0,
    scrollActive = false,
    originalTrackerUpdate = nil,
    originalGetAvailableHeight = nil,
    updatingScrollBar = false,
    currentRightInset = 0,
    layoutRefreshPending = false,
    trackerStyleRefreshPending = false,
    trackerStyleRefreshVersion = 0,
    captureCollapseAfterStyleRefresh = false,
    needsExpandedLayoutPass = true,
    layoutHeightBudget = 0,
    lastTypographySignature = nil,
    cachedTrackerStyleSignature = nil,
    cachedTrackerStyles = nil,
    pendingScrollAnchor = nil,
    applyingCollapseStates = false,
    savedCollapseStatesInitialized = false,
    collapsePersistenceReady = false,
    pendingRewardDataQuestIDs = {},
    lastContentHeight = 0,
    originalModuleOrders = {},
    originalQuestShouldDisplayQuest = nil,
    originalCampaignShouldDisplayQuest = nil,
    originalBonusAddQuest = nil,
    originalWorldQuestAddQuest = nil,
    resolvedWarbandCompletionAtlas = nil,
    resolvedWarbandCompletionCheckAtlas = nil,
    nomToolsEnforcingHeight = false,
    lastTrackerSizeWidth = nil,
    lastTrackerSizeHeight = nil,
    postLayoutStyleDirty = true,
    searchFrame = nil,
    searchEditBox = nil,
    searchText = "",
    searchDebounceTimer = nil,
    filterButton = nil,
    filterDropFrame = nil,
    filterDropCloseListener = nil,
}

local BuildTrackerStyleData
local ShouldApplyModuleContentStyling
local ApplyBlockStyle
local BuildBlockHeaderColorStyle
local ApplyTrackerStyles
local RequestCustomModuleRefresh
local RequestTrackerLayoutRefresh
local RequestTrackerStyleRefresh
local RefreshObjectiveTrackerDisplay
local styleHelpers = {}

local function CopyArray(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for index, value in ipairs(source) do
        copy[index] = value
    end
    return copy
end

local function CopyColor(source)
    if type(source) ~= "table" then
        return nil
    end

    return {
        r = source.r,
        g = source.g,
        b = source.b,
        a = source.a,
    }
end

local function DoesOrderMatchTemplate(order, template)
    if type(order) ~= "table" or type(template) ~= "table" or #order ~= #template then
        return false
    end

    for index, key in ipairs(template) do
        if order[index] ~= key then
            return false
        end
    end

    return true
end

local function AreColorsEquivalent(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    local epsilon = 0.001
    local function Resolve(color, key, index)
        return tonumber(color[key] or color[index]) or 0
    end

    return math.abs(Resolve(left, "r", 1) - Resolve(right, "r", 1)) <= epsilon
        and math.abs(Resolve(left, "g", 2) - Resolve(right, "g", 2)) <= epsilon
        and math.abs(Resolve(left, "b", 3) - Resolve(right, "b", 3)) <= epsilon
        and math.abs(Resolve(left, "a", 4) - Resolve(right, "a", 4)) <= epsilon
end

local function NormalizeLevelPrefixMode(mode, legacyShowLevelPrefix)
    if mode == K.LEVEL_PREFIX_MODE_ALL
        or mode == K.LEVEL_PREFIX_MODE_TRIVIAL
        or mode == K.LEVEL_PREFIX_MODE_NONE
    then
        return mode
    end

    if legacyShowLevelPrefix == false then
        return K.LEVEL_PREFIX_MODE_NONE
    end

    return K.LEVEL_PREFIX_MODE_TRIVIAL
end

local function LoadBlizzardAddon(addonKey)
    local loader = (C_AddOns and C_AddOns.LoadAddOn) or UIParentLoadAddOn
    if loader and addonKey then
        pcall(loader, addonKey)
    end
end

local function GetSettings()
    local settings = ns.GetObjectiveTrackerSettings and ns.GetObjectiveTrackerSettings() or (ns.DEFAULTS and ns.DEFAULTS.objectiveTracker) or {}
    settings.focusedQuest = settings.focusedQuest or {}
    settings.typography = settings.typography or {}
    settings.zone = settings.zone or {}
    settings.scrollBar = settings.scrollBar or {}
    settings.progressBar = settings.progressBar or {}
    settings.appearance = settings.appearance or {}
    settings.search = settings.search or {}

    local defaultFocusedQuest = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.focusedQuest or {}
    if settings.focusedQuest.enabled == nil then
        settings.focusedQuest.enabled = defaultFocusedQuest.enabled ~= false
    end

    local defaultZone = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.zone or {}
    for key, value in pairs(defaultZone) do
        if settings.zone[key] == nil then
            settings.zone[key] = value
        end
    end

    settings.zone.titleColors = settings.zone.titleColors or {}
    local defaultZoneTitleColors = defaultZone.titleColors or K.DEFAULT_QUEST_KIND_TITLE_COLORS
    for key, value in pairs(defaultZoneTitleColors) do
        if type(settings.zone.titleColors[key]) ~= "table" then
            settings.zone.titleColors[key] = {
                r = value.r,
                g = value.g,
                b = value.b,
                a = value.a,
            }
        end
    end

    settings.typography.titleColors = settings.typography.titleColors or {}
    local defaultTypography = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.typography or {}
    local defaultSpecialTitleColors = defaultTypography.titleColors or K.DEFAULT_SPECIAL_TITLE_COLORS
    settings.typography.levelPrefixMode = NormalizeLevelPrefixMode(settings.typography.levelPrefixMode, settings.typography.showLevelPrefix)
    if settings.typography.showWarbandCompletedIndicator == nil then
        settings.typography.showWarbandCompletedIndicator = defaultTypography.showWarbandCompletedIndicator ~= false
    end
    if settings.typography.showQuestLogCount == nil then
        settings.typography.showQuestLogCount = defaultTypography.showQuestLogCount ~= false
    end
    for key, value in pairs(defaultSpecialTitleColors) do
        if type(value) == "table" and type(settings.typography.titleColors[key]) ~= "table" then
            settings.typography.titleColors[key] = {
                r = value.r,
                g = value.g,
                b = value.b,
                a = value.a,
            }
        end
    end
    -- Always initialize keys that exist in K.DEFAULT_SPECIAL_TITLE_COLORS but may be absent
    -- from an older DEFAULTS table (e.g. legendary was added later).
    for key, value in pairs(K.DEFAULT_SPECIAL_TITLE_COLORS) do
        if type(settings.typography.titleColors[key]) ~= "table" then
            settings.typography.titleColors[key] = {
                r = value.r,
                g = value.g,
                b = value.b,
                a = value.a,
            }
        end
    end

    for _, key in ipairs(K.LEGACY_ZONE_TITLE_COLOR_KEYS) do
        local legacyColor = settings.zone.titleColors[key]
        local defaultColor = defaultSpecialTitleColors[key]
        if type(legacyColor) == "table"
            and type(defaultColor) == "table"
            and AreColorsEquivalent(settings.typography.titleColors[key], defaultColor)
        then
            settings.typography.titleColors[key] = CopyColor(legacyColor)
        end
    end

    local defaultAppearance = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.appearance or {}
    if settings.appearance.preset ~= "nomtools" then
        settings.appearance.preset = defaultAppearance.preset or "blizzard"
    end
    -- Per-section appearance (main header / category headers / buttons).
    -- On first load, migrate from old flat settings so existing users keep their customisation.
    if settings.appearance.mainHeader == nil then
        local tex = (type(settings.appearance.texture) == "string" and settings.appearance.texture ~= "" and settings.appearance.texture)
            or defaultAppearance.texture or "blizzard"
        local op  = Clamp(tonumber(settings.appearance.opacity) or tonumber(defaultAppearance.opacity) or 80, 0, 100)
        local col = type(settings.appearance.color) == "table" and settings.appearance.color
            or defaultAppearance.color or K.DEFAULT_HEADER_BACKGROUND_COLOR
        local bdr = type(settings.appearance.borderColor) == "table" and settings.appearance.borderColor
            or defaultAppearance.borderColor or K.DEFAULT_HEADER_BORDER_COLOR
        local borderSize = NormalizeBorderSize(defaultAppearance.borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE)
        local borderTexture = defaultAppearance.borderTexture or tex or "blizzard"
        settings.appearance.mainHeader     = { texture = tex, opacity = op, color = CopyColor(col), borderColor = CopyColor(bdr), borderTexture = borderTexture, borderSize = borderSize }
        settings.appearance.categoryHeader = { texture = tex, opacity = op, color = CopyColor(col), borderColor = CopyColor(bdr), borderTexture = borderTexture, borderSize = borderSize }
        settings.appearance.button         = { texture = tex, opacity = op, color = CopyColor(col), borderColor = CopyColor(bdr), borderTexture = borderTexture, borderSize = borderSize }
    end
    for _, sectionKey in ipairs({ "mainHeader", "categoryHeader", "button" }) do
        local s  = settings.appearance[sectionKey] or {}
        settings.appearance[sectionKey] = s
        local sd = (type(defaultAppearance[sectionKey]) == "table" and defaultAppearance[sectionKey]) or {}
        if type(s.texture) ~= "string" or s.texture == "" then
            s.texture = sd.texture or defaultAppearance.texture or "blizzard"
        end
        s.opacity = Clamp(tonumber(s.opacity) or tonumber(sd.opacity) or tonumber(defaultAppearance.opacity) or 80, 0, 100)
        if type(s.color) ~= "table" then
            s.color = CopyColor(sd.color or defaultAppearance.color or K.DEFAULT_HEADER_BACKGROUND_COLOR)
        end
        if type(s.borderColor) ~= "table" then
            s.borderColor = CopyColor(sd.borderColor or defaultAppearance.borderColor or K.DEFAULT_HEADER_BORDER_COLOR)
        end
        if s.borderEnabled == false and tonumber(s.borderSize or sd.borderSize or defaultAppearance.borderSize or K.DEFAULT_CHROME_BORDER_SIZE) ~= 0 then
            s.borderSize = 0
        end
        if type(s.borderTexture) ~= "string" or s.borderTexture == "" then
            s.borderTexture = sd.borderTexture or defaultAppearance.borderTexture or s.texture or defaultAppearance.texture or "blizzard"
        end
        s.borderSize = NormalizeBorderSize(
            tonumber(s.borderSize) or tonumber(sd.borderSize) or tonumber(defaultAppearance.borderSize) or K.DEFAULT_CHROME_BORDER_SIZE,
            K.DEFAULT_CHROME_BORDER_SIZE,
            K.MIN_CHROME_BORDER_SIZE,
            K.MAX_CHROME_BORDER_SIZE
        )
    end
    -- Tracker background
    if type(settings.appearance.trackerBackground) ~= "table" then
        settings.appearance.trackerBackground = {}
    end
    local tbgDef = (type(defaultAppearance.trackerBackground) == "table" and defaultAppearance.trackerBackground) or {}
    local tbg = settings.appearance.trackerBackground
    if tbg.enabled == nil then
        tbg.enabled = settings.appearance.preset == "nomtools"
    end
    if type(tbg.texture) ~= "string" or tbg.texture == "" then
        tbg.texture = tbgDef.texture or defaultAppearance.texture or ns.GLOBAL_CHOICE_KEY
    end
    tbg.opacity = Clamp(tonumber(tbg.opacity) or tonumber(tbgDef.opacity) or 60, 0, 100)
    if type(tbg.color) ~= "table" then
        tbg.color = CopyColor(type(tbgDef.color) == "table" and tbgDef.color or K.DEFAULT_HEADER_BACKGROUND_COLOR)
    end
    if type(tbg.borderColor) ~= "table" then
        tbg.borderColor = CopyColor(type(tbgDef.borderColor) == "table" and tbgDef.borderColor or K.DEFAULT_HEADER_BORDER_COLOR)
    end
    if tbg.borderEnabled == false and tonumber(tbg.borderSize or tbgDef.borderSize or K.DEFAULT_CHROME_BORDER_SIZE) ~= 0 then
        tbg.borderSize = 0
    end
    if type(tbg.borderTexture) ~= "string" or tbg.borderTexture == "" then
        tbg.borderTexture = tbgDef.borderTexture or defaultAppearance.borderTexture or tbg.texture or ns.GLOBAL_CHOICE_KEY
    end
    tbg.borderSize = NormalizeBorderSize(
        tonumber(tbg.borderSize) or tonumber(tbgDef.borderSize) or K.DEFAULT_CHROME_BORDER_SIZE,
        K.DEFAULT_CHROME_BORDER_SIZE,
        K.MIN_CHROME_BORDER_SIZE,
        K.MAX_CHROME_BORDER_SIZE
    )
    -- Header typography overrides (nil fields inherit from the global typography settings).
    settings.typography.mainHeader = settings.typography.mainHeader or {}
    settings.typography.mainHeader.xOffset = Clamp(tonumber(settings.typography.mainHeader.xOffset) or 0, -200, 200)
    settings.typography.mainHeader.yOffset = Clamp(tonumber(settings.typography.mainHeader.yOffset) or 0, -200, 200)
    if type(settings.typography.mainHeader.textColor) ~= "table" then
        settings.typography.mainHeader.textColor = nil
    end
    settings.typography.categoryHeader = settings.typography.categoryHeader or {}
    if type(settings.typography.categoryHeader.textColor) ~= "table" then
        settings.typography.categoryHeader.textColor = nil
    end

    local defaultProgressBar = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.progressBar or {}
    local hadLegacyProgressBarSettings = settings.progressBar.fillMode == nil
        and settings.progressBar.borderSize == nil
    if settings.progressBar.fillMode ~= "static" then
        settings.progressBar.fillMode = defaultProgressBar.fillMode or "progress"
    end
    if type(settings.progressBar.fillColor) ~= "table" then
        settings.progressBar.fillColor = CopyColor(defaultProgressBar.fillColor or K.DEFAULT_PROGRESS_FILL_COLOR)
    end
    if type(settings.progressBar.lowFillColor) ~= "table" then
        settings.progressBar.lowFillColor = CopyColor(defaultProgressBar.lowFillColor or K.DEFAULT_PROGRESS_LOW_FILL_COLOR)
    end
    if type(settings.progressBar.mediumFillColor) ~= "table" then
        settings.progressBar.mediumFillColor = CopyColor(defaultProgressBar.mediumFillColor or K.DEFAULT_PROGRESS_MEDIUM_FILL_COLOR)
    end
    if type(settings.progressBar.highFillColor) ~= "table" then
        settings.progressBar.highFillColor = CopyColor(defaultProgressBar.highFillColor or K.DEFAULT_PROGRESS_HIGH_FILL_COLOR)
    end
    if type(settings.progressBar.backgroundColor) ~= "table" then
        settings.progressBar.backgroundColor = CopyColor(defaultProgressBar.backgroundColor or K.DEFAULT_PROGRESS_BACKGROUND_COLOR)
    end
    if settings.progressBar.borderEnabled == false and tonumber(settings.progressBar.borderSize or defaultProgressBar.borderSize or K.DEFAULT_PROGRESS_BORDER_SIZE) ~= 0 then
        settings.progressBar.borderSize = 0
    end
    settings.progressBar.borderSize = NormalizeBorderSize(
        tonumber(settings.progressBar.borderSize) or tonumber(defaultProgressBar.borderSize) or K.DEFAULT_PROGRESS_BORDER_SIZE,
        K.DEFAULT_PROGRESS_BORDER_SIZE,
        K.MIN_PROGRESS_BORDER_SIZE,
        K.MAX_PROGRESS_BORDER_SIZE
    )
    if type(settings.progressBar.borderColor) ~= "table" then
        settings.progressBar.borderColor = CopyColor(defaultProgressBar.borderColor or K.DEFAULT_PROGRESS_BORDER_COLOR)
    elseif hadLegacyProgressBarSettings and AreColorsEquivalent(settings.progressBar.borderColor, K.LEGACY_PROGRESS_BORDER_COLOR) then
        settings.progressBar.borderColor = CopyColor(defaultProgressBar.borderColor or K.DEFAULT_PROGRESS_BORDER_COLOR)
    end
    if type(settings.progressBar.borderTexture) ~= "string" or settings.progressBar.borderTexture == "" then
        settings.progressBar.borderTexture = defaultProgressBar.borderTexture or settings.progressBar.texture or "blizzard"
    end

    if type(settings.scrollBar.color) ~= "table" then
        settings.scrollBar.color = CopyColor(K.DEFAULT_SCROLL_BAR_COLOR)
    elseif AreColorsEquivalent(settings.scrollBar.color, K.LEGACY_SCROLL_BAR_COLOR) then
        settings.scrollBar.color = CopyColor(K.DEFAULT_SCROLL_BAR_COLOR)
    end

    if type(settings.scrollBar.backgroundColor) ~= "table" then
        settings.scrollBar.backgroundColor = CopyColor(K.DEFAULT_SCROLL_BAR_BACKGROUND_COLOR)
    end

    if type(settings.scrollBar.borderColor) ~= "table" then
        settings.scrollBar.borderColor = CopyColor(K.DEFAULT_SCROLL_BAR_BORDER_COLOR)
    end
    if settings.scrollBar.borderSize == nil then
        settings.scrollBar.borderSize = K.DEFAULT_CHROME_BORDER_SIZE
    end

    if type(settings.order) ~= "table" then
        settings.order = CopyArray(K.DEFAULT_ORDER)
    elseif DoesOrderMatchTemplate(settings.order, K.LEGACY_DEFAULT_ORDER) then
        settings.order = CopyArray(K.DEFAULT_ORDER)
    end

    settings.layout = settings.layout or {}
    local defaultLayout = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.layout or {}
    settings.layout.width = Clamp(
        tonumber(settings.layout.width) or tonumber(defaultLayout.width) or 235,
        150, 500
    )
    settings.layout.height = Clamp(
        tonumber(settings.layout.height) or tonumber(defaultLayout.height) or 800,
        200, 1400
    )
    if settings.layout.matchMinimapWidth == nil then
        settings.layout.matchMinimapWidth = defaultLayout.matchMinimapWidth == true
    end
    if settings.layout.attachToMinimap == nil then
        settings.layout.attachToMinimap = defaultLayout.attachToMinimap == true
    end
    settings.layout.minimapYOffset = Clamp(
        tonumber(settings.layout.minimapYOffset) or tonumber(defaultLayout.minimapYOffset) or 0,
        -200, 200
    )
    local attachEdge = settings.layout.minimapAttachEdge
    if attachEdge ~= "top" and attachEdge ~= "bottom" then
        settings.layout.minimapAttachEdge = defaultLayout.minimapAttachEdge or "bottom"
    end

    -- Normalize header settings.
    settings.header = settings.header or {}
    local defaultHeader = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.header or {}
    if settings.header.enabled == nil then
        settings.header.enabled = defaultHeader.enabled ~= false
    end
    if settings.header.showBackground == nil then
        settings.header.showBackground = defaultHeader.showBackground ~= false
    end
    if settings.header.showTitle == nil then
        settings.header.showTitle = defaultHeader.showTitle ~= false
    end

    -- Normalize buttons and migrate the legacy shared trackAll toggle.
    settings.buttons = settings.buttons or {}
    local defaultButtons = ns.DEFAULTS and ns.DEFAULTS.objectiveTracker and ns.DEFAULTS.objectiveTracker.buttons or {}
    if settings.buttons.minimize == nil then
        settings.buttons.minimize = defaultButtons.minimize ~= false
    end
    if settings.buttons.trackerTrackAll == nil then
        if settings.buttons.trackAll ~= nil then
            settings.buttons.trackerTrackAll = settings.buttons.trackAll ~= false
        else
            settings.buttons.trackerTrackAll = defaultButtons.trackAll ~= false
        end
    end
    if settings.buttons.questLogTrackAll == nil then
        if settings.buttons.trackAll ~= nil then
            settings.buttons.questLogTrackAll = settings.buttons.trackAll ~= false
        else
            settings.buttons.questLogTrackAll = defaultButtons.trackAll ~= false
        end
    end

    -- Migrate removed "completion" sort mode to "default".
    if settings.filter and settings.filter.sortBy == "completion" then
        settings.filter.sortBy = "default"
    end

    -- Migrate removed "trivial" quest type to separate showTrivial toggle.
    if settings.filter and settings.filter.questTypes and settings.filter.questTypes.trivial then
        settings.filter.questTypes.trivial = nil
        if settings.filter.showTrivial == nil then
            settings.filter.showTrivial = false
        end
    end

    -- Migrate zone divider settings from filter to zoneDivider.
    if settings.filter then
        if not settings.zoneDivider then
            settings.zoneDivider = {}
        end
        if settings.filter.zoneDividerAlign and not settings.zoneDivider.align then
            settings.zoneDivider.align = settings.filter.zoneDividerAlign
        end
        if settings.filter.zoneDividerShowLines ~= nil and settings.zoneDivider.showLines == nil then
            settings.zoneDivider.showLines = settings.filter.zoneDividerShowLines
        end
    end

    return settings
end

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function NormalizeColor(color, fallback)
    fallback = fallback or K.DEFAULT_UNCOMPLETED_COLOR
    if type(color) ~= "table" then
        return {
            r = fallback.r,
            g = fallback.g,
            b = fallback.b,
            a = fallback.a,
        }
    end

    return {
        r = tonumber(color.r or color[1]) or fallback.r,
        g = tonumber(color.g or color[2]) or fallback.g,
        b = tonumber(color.b or color[3]) or fallback.b,
        a = tonumber(color.a or color[4]) or fallback.a,
    }
end

local function BrightenColor(color, amount)
    amount = Clamp(tonumber(amount) or 0.16, 0, 1)
    color = NormalizeColor(color, K.DEFAULT_UNCOMPLETED_COLOR)

    return {
        r = color.r + (1 - color.r) * amount,
        g = color.g + (1 - color.g) * amount,
        b = color.b + (1 - color.b) * amount,
        a = color.a,
    }
end

local function DarkenColor(color, amount)
    amount = Clamp(tonumber(amount) or 0.24, 0, 1)
    color = NormalizeColor(color, K.DEFAULT_UNCOMPLETED_COLOR)

    return {
        r = color.r * (1 - amount),
        g = color.g * (1 - amount),
        b = color.b * (1 - amount),
        a = color.a,
    }
end

local function GetColorLuminance(color)
    color = NormalizeColor(color, K.DEFAULT_UNCOMPLETED_COLOR)
    return (color.r * 0.2126) + (color.g * 0.7152) + (color.b * 0.0722)
end

local function GetHoverColor(color)
    local normalized = NormalizeColor(color, K.DEFAULT_UNCOMPLETED_COLOR)

    if GetColorLuminance(normalized) >= 0.60 then
        return DarkenColor(normalized, 0.26)
    end

    return BrightenColor(normalized, 0.22)
end

local GetZoneFilters

local function GetQuestKindTitleColor(questKind, styles, isHighlighted)
    if not questKind then
        return nil
    end

    local color
    if questKind == "quest" then
        color = styles and styles.questTitleColor or nil
    elseif questKind == "worldQuest" then
        color = styles and styles.worldQuestTitleColor or nil
    elseif questKind == "bonusObjective" then
        color = styles and styles.bonusObjectiveTitleColor or nil
    end

    if not color then
        return nil
    end

    if isHighlighted then
        return GetHoverColor(color)
    end

    return color
end

local function GetTypographySettings()
    return GetSettings().typography or {}
end

local function GetLevelPrefixMode(typography)
    local resolved = typography or GetTypographySettings()
    return NormalizeLevelPrefixMode(resolved.levelPrefixMode, resolved.showLevelPrefix)
end

local function IsWarbandIndicatorEnabled(typography)
    local resolved = typography or GetTypographySettings()
    return resolved.showWarbandCompletedIndicator ~= false
end

local function IsQuestLogCountEnabled(typography)
    local resolved = typography or GetTypographySettings()
    return resolved.showQuestLogCount ~= false
end

local function GetFocusedQuestSettings()
    return GetSettings().focusedQuest or {}
end

local function GetScrollBarSettings()
    return GetSettings().scrollBar or {}
end

local function GetProgressBarSettings()
    return GetSettings().progressBar or {}
end

local function GetHeaderAppearanceSettings()
    return GetSettings().appearance or {}
end

local function IsTrackerTrackAllButtonEnabled()
    local buttons = GetSettings().buttons or {}
    return buttons.trackerTrackAll ~= false
end

local function IsQuestLogTrackAllButtonEnabled()
    local buttons = GetSettings().buttons or {}
    return buttons.questLogTrackAll ~= false
end

local function IsMainHeaderEnabled()
    local h = GetSettings().header or {}
    return h.enabled ~= false
end

local function IsHeaderBackgroundShown()
    local h = GetSettings().header or {}
    return h.showBackground ~= false
end

local function IsHeaderTitleShown()
    local h = GetSettings().header or {}
    return h.showTitle ~= false
end

local function IsMinimizeButtonEnabled()
    local b = GetSettings().buttons or {}
    return b.minimize ~= false
end

local function IsFocusedQuestEnabled(settings)
    local focusedQuest = settings and settings.focusedQuest or GetFocusedQuestSettings()
    return focusedQuest.enabled ~= false
end

local function IsSearchEnabled()
    local search = GetSettings().search or {}
    return search.enabled ~= false
end

local function IsScrollEnabled()
    return GetScrollBarSettings().enabled ~= false
end

local function IsScrollBarVisible()
    return GetScrollBarSettings().visible ~= false
end

local function GetScrollBarWidth(settings)
    local resolved = settings or GetScrollBarSettings()
    return Clamp(tonumber(resolved.width) or K.SCROLL_BAR_DEFAULT_WIDTH, K.SCROLL_BAR_MIN_WIDTH, K.SCROLL_BAR_MAX_WIDTH)
end

local function IsModuleEnabled(settings)
    local resolvedSettings = settings or GetSettings()
    local enabled = resolvedSettings and resolvedSettings.enabled
    if ns.IsModuleRuntimeEnabled then
        return ns.IsModuleRuntimeEnabled(CONFIG_KEY, enabled)
    end

    return enabled ~= false
end

GetZoneFilters = function()
    return GetSettings().zone
end

local function GetNormalizedOrder(order)
    local normalized = {}
    local seen = {}

    if type(order) == "table" then
        for _, key in ipairs(order) do
            if K.ORDER_LABELS[key] and not seen[key] then
                normalized[#normalized + 1] = key
                seen[key] = true
            end
        end
    end

    if not seen.focusedQuest and K.ORDER_LABELS.focusedQuest then
        local insertIndex = #normalized + 1
        local passedFocusedQuest = false
        local keysAfterFocusedQuest = {}

        for _, defaultKey in ipairs(K.DEFAULT_ORDER) do
            if defaultKey == "focusedQuest" then
                passedFocusedQuest = true
            elseif passedFocusedQuest then
                keysAfterFocusedQuest[defaultKey] = true
            end
        end

        for index, existingKey in ipairs(normalized) do
            if keysAfterFocusedQuest[existingKey] then
                insertIndex = index
                break
            end
        end

        table.insert(normalized, insertIndex, "focusedQuest")
        seen.focusedQuest = true
    end

    if not seen.search and K.ORDER_LABELS.search then
        table.insert(normalized, 1, "search")
        seen.search = true
    end

    for _, key in ipairs(K.DEFAULT_ORDER) do
        if not seen[key] then
            normalized[#normalized + 1] = key
        end
    end

    return normalized
end

function ns.GetObjectiveTrackerCategoryOrder()
    return CopyArray(GetNormalizedOrder(GetSettings().order))
end

function ns.GetObjectiveTrackerCategoryLabel(key)
    return K.ORDER_LABELS[key] or key
end

function ns.GetObjectiveTrackerZoneFilterKeys()
    return CopyArray(K.ZONE_FILTER_KEYS)
end

function ns.GetObjectiveTrackerZoneFilterLabel(key)
    return K.ZONE_FILTER_LABELS[key] or key
end

function ns.MoveObjectiveTrackerOrderEntry(position, delta)
    local order = GetNormalizedOrder(GetSettings().order)
    local swapIndex = (position or 0) + (delta or 0)
    if swapIndex < 1 or swapIndex > #order then
        return false
    end

    order[position], order[swapIndex] = order[swapIndex], order[position]
    GetSettings().order = order
    return true
end

function ns.ResetObjectiveTrackerOrder()
    GetSettings().order = CopyArray(K.DEFAULT_ORDER)
end

local function GetModuleByKey(key)
    if key == "search" then
        return state.searchFrame
    elseif key == "focusedQuest" then
        return state.focusedQuestModule
    elseif key == "scenario" then
        return ScenarioObjectiveTracker
    elseif key == "uiWidget" then
        return UIWidgetObjectiveTracker
    elseif key == "campaign" then
        return CampaignQuestObjectiveTracker
    elseif key == "zone" then
        return state.zoneModule
    elseif key == "quest" then
        return QuestObjectiveTracker
    elseif key == "adventure" then
        return AdventureObjectiveTracker
    elseif key == "achievement" then
        return AchievementObjectiveTracker
    elseif key == "monthlyActivities" then
        return MonthlyActivitiesObjectiveTracker
    elseif key == "initiativeTasks" then
        return InitiativeTasksObjectiveTracker
    elseif key == "professionsRecipe" then
        return ProfessionsRecipeTracker
    elseif key == "bonusObjective" then
        return BonusObjectiveTracker
    elseif key == "worldQuest" then
        return WorldQuestObjectiveTracker
    end

    return nil
end

local function GetKeyForModule(module)
    if not module then
        return nil
    end

    if module.nomtoolsObjectiveTrackerKey then
        return module.nomtoolsObjectiveTrackerKey
    end

    if module == state.searchFrame then
        return "search"
    elseif module == state.focusedQuestModule then
        return "focusedQuest"
    elseif module == ScenarioObjectiveTracker then
        return "scenario"
    elseif module == UIWidgetObjectiveTracker then
        return "uiWidget"
    elseif module == CampaignQuestObjectiveTracker then
        return "campaign"
    elseif module == state.zoneModule then
        return "zone"
    elseif module == QuestObjectiveTracker then
        return "quest"
    elseif module == AdventureObjectiveTracker then
        return "adventure"
    elseif module == AchievementObjectiveTracker then
        return "achievement"
    elseif module == MonthlyActivitiesObjectiveTracker then
        return "monthlyActivities"
    elseif module == InitiativeTasksObjectiveTracker then
        return "initiativeTasks"
    elseif module == ProfessionsRecipeTracker then
        return "professionsRecipe"
    elseif module == BonusObjectiveTracker then
        return "bonusObjective"
    elseif module == WorldQuestObjectiveTracker then
        return "worldQuest"
    end

    return nil
end

local function GetQuestLogCountText()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        return nil
    end

    local entryCount = C_QuestLog.GetNumQuestLogEntries()
    if type(entryCount) ~= "number" or entryCount <= 0 then
        return "0"
    end

    local questCount = 0
    for questLogIndex = 1, entryCount do
        local info = C_QuestLog.GetInfo(questLogIndex)
        local questID = C_QuestLog.GetQuestIDForLogIndex and C_QuestLog.GetQuestIDForLogIndex(questLogIndex) or (info and info.questID) or nil
        if info
            and type(questID) == "number"
            and questID > 0
            and not info.isHeader
            and not info.isHidden
            and info.isTask ~= true
            and info.isBounty ~= true
            and (not C_QuestLog.IsQuestTask or not C_QuestLog.IsQuestTask(questID))
            and (not C_QuestLog.IsQuestBounty or not C_QuestLog.IsQuestBounty(questID))
        then
            questCount = questCount + 1
        end
    end

    local maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or nil
    if type(maxQuests) == "number" and maxQuests > 0 then
        return string.format("%d/%d", questCount, maxQuests)
    end

    return tostring(questCount)
end

local function BuildQuestModuleHeaderText(module, fallbackText)
    if GetKeyForModule(module) ~= "quest" then
        return fallbackText
    end

    local baseText = K.ORDER_LABELS.quest or TRACKER_HEADER_QUESTS or "Quests"
    if type(baseText) ~= "string" or baseText == "" then
        baseText = fallbackText
    end

    if not IsQuestLogCountEnabled() then
        return baseText
    end

    local questCountText = GetQuestLogCountText()
    if not questCountText or questCountText == "" then
        return baseText
    end

    return string.format("%s (%s)", baseText, questCountText)
end

local function TagKnownModules()
    for _, key in ipairs(K.DEFAULT_ORDER) do
        local module = GetModuleByKey(key)
        if module then
            module.nomtoolsObjectiveTrackerKey = key
        end
    end
end

local function GetCharacterTrackerState()
    return ns.GetObjectiveTrackerCharacterSettings and ns.GetObjectiveTrackerCharacterSettings() or nil
end

local function GetCollapsedSections()
    local characterState = GetCharacterTrackerState()
    return characterState and characterState.collapsedSections or nil
end

local function GetSavedSectionCollapsed(key)
    local collapsedSections = GetCollapsedSections()
    if not collapsedSections then
        return nil
    end

    local value = collapsedSections[key]
    if value == nil then
        return nil
    end

    return value == true
end

local function SetSavedSectionCollapsed(key, collapsed)
    local collapsedSections = GetCollapsedSections()
    if collapsedSections and key then
        collapsedSections[key] = collapsed == true
    end
end

local function CaptureCurrentSectionCollapseStates()
    local collapsedSections = GetCollapsedSections()
    if not collapsedSections then
        return false
    end

    local changed = false

    for _, key in ipairs(GetNormalizedOrder(GetSettings().order)) do
        local module = GetModuleByKey(key)
        if module and module.parentContainer == ObjectiveTrackerFrame and module.IsCollapsed then
            local collapsed = module:IsCollapsed() == true
            if collapsedSections[key] ~= collapsed then
                collapsedSections[key] = collapsed
                changed = true
            end
        end
    end

    return changed
end

local function ApplySavedSectionCollapsedState(module)
    if not module or module.parentContainer ~= ObjectiveTrackerFrame or not module.SetCollapsed or not module.IsCollapsed then
        return false
    end

    local moduleKey = GetKeyForModule(module)
    local collapsed = moduleKey and GetSavedSectionCollapsed(moduleKey) or nil
    if collapsed == nil or module:IsCollapsed() == collapsed then
        return false
    end

    state.applyingCollapseStates = true
    module:SetCollapsed(collapsed)
    state.applyingCollapseStates = false
    return true
end

local function ApplySavedSectionCollapseStates()
    if not ObjectiveTrackerFrame then
        return false
    end

    if not GetCharacterTrackerState() then
        return false
    end

    local changed = false
    state.applyingCollapseStates = true

    for _, key in ipairs(GetNormalizedOrder(GetSettings().order)) do
        local module = GetModuleByKey(key)
        local collapsed = GetSavedSectionCollapsed(key)
        if module and collapsed ~= nil and module.SetCollapsed and module.IsCollapsed and module:IsCollapsed() ~= collapsed then
            module:SetCollapsed(collapsed)
            changed = true
        end
    end

    state.applyingCollapseStates = false
    state.savedCollapseStatesInitialized = true
    return changed
end

local function EnsureObjectiveTrackerLoaded()
    if ObjectiveTrackerFrame and ObjectiveTrackerManager then
        return true
    end

    LoadBlizzardAddon("Blizzard_ObjectiveTracker")
    return ObjectiveTrackerFrame ~= nil and ObjectiveTrackerManager ~= nil
end

local function HookObjectiveTrackerManagerInit()
    if state.managerInitHookInstalled then
        return
    end

    state.managerInitHookInstalled = true

    if ObjectiveTrackerFrame and ObjectiveTrackerManager then
        local function DeferredRefreshOT()
            if ns.RefreshObjectiveTrackerUI then
                ns.RefreshObjectiveTrackerUI()
            end
        end
        hooksecurefunc(ObjectiveTrackerManager, "Init", function()
            if ns.RefreshObjectiveTrackerUI then
                C_Timer.After(0, DeferredRefreshOT)
            end
        end)
        return
    end

    eventFrame:UnregisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(_, event, addonNameLoaded)
        if event ~= "ADDON_LOADED" or addonNameLoaded ~= "Blizzard_ObjectiveTracker" then
            return
        end

        eventFrame:UnregisterEvent("ADDON_LOADED")
        eventFrame:SetScript("OnEvent", nil)

        if ns.RefreshObjectiveTrackerUI then
            ns.RefreshObjectiveTrackerUI()
        end
    end)
    eventFrame:RegisterEvent("ADDON_LOADED")
end

local function BuildMapAncestors(mapID)
    local ancestors = {}
    local currentMapID = mapID

    while type(currentMapID) == "number" and currentMapID > 0 and not ancestors[currentMapID] do
        ancestors[currentMapID] = true
        local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(currentMapID) or nil
        currentMapID = mapInfo and mapInfo.parentMapID or nil
    end

    return ancestors
end

local function IsQuestInCurrentZone(questID)
    if type(questID) ~= "number" then
        return false
    end

    local currentMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    if not currentMapID then
        return false
    end

    local questMapID = C_TaskQuest and C_TaskQuest.GetQuestZoneID and C_TaskQuest.GetQuestZoneID(questID) or nil
    if not questMapID or questMapID == 0 then
        questMapID = GetQuestUiMapID and GetQuestUiMapID(questID, true) or nil
    end
    if not questMapID or questMapID == 0 then
        return false
    end

    local currentAncestors = BuildMapAncestors(currentMapID)
    if currentAncestors[questMapID] then
        return true
    end

    local questAncestors = BuildMapAncestors(questMapID)
    return questAncestors[currentMapID] == true
end

local function IsTaskQuestReadyForZoneTracker(questID)
    if type(questID) ~= "number" or not GetTaskInfo then
        return false
    end

    local isInArea = GetTaskInfo(questID)
    return isInArea == true
end

local function IsCampaignQuest(questID, quest)
    if quest and quest.GetQuestClassification then
        return quest:GetQuestClassification() == Enum.QuestClassification.Campaign
    end

    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        return C_QuestInfoSystem.GetQuestClassification(questID) == Enum.QuestClassification.Campaign
    end

    return false
end

local function GetQuestClassification(questID, quest)
    if quest and quest.GetQuestClassification then
        return quest:GetQuestClassification()
    end

    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        return C_QuestInfoSystem.GetQuestClassification(questID)
    end

    return nil
end

local function IsTaskQuest(questID, quest)
    if quest and (quest.isTask or quest.isBounty) then
        return true
    end

    if C_QuestLog and C_QuestLog.IsQuestTask and C_QuestLog.IsQuestTask(questID) then
        return true
    end

    if C_QuestLog and C_QuestLog.IsQuestBounty and C_QuestLog.IsQuestBounty(questID) then
        return true
    end

    return false
end

local function GetQuestKind(questID, quest)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    if (quest and quest.IsDisabledForSession and quest:IsDisabledForSession())
        or (C_QuestLog and C_QuestLog.IsQuestDisabledForSession and C_QuestLog.IsQuestDisabledForSession(questID))
    then
        return nil
    end

    if IsTaskQuest(questID, quest) then
        if QuestUtils_IsQuestWorldQuest and QuestUtils_IsQuestWorldQuest(questID) then
            return "worldQuest"
        end

        return "bonusObjective"
    end

    return IsCampaignQuest(questID, quest) and "campaign" or "quest"
end

local function IsDailyQuest(questID)
    if type(QuestIsDaily) == "function" then
        return QuestIsDaily(questID) == true
    end

    if C_QuestLog and C_QuestLog.IsDailyQuest then
        return C_QuestLog.IsDailyQuest(questID) == true
    end

    return false
end

local function IsWeeklyQuest(questID)
    if type(QuestIsWeekly) == "function" then
        return QuestIsWeekly(questID) == true
    end

    if C_QuestLog and C_QuestLog.IsWeeklyQuest then
        return C_QuestLog.IsWeeklyQuest(questID) == true
    end

    return false
end

local function GetRecurringQuestType(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    local classification = GetQuestClassification(questID)
    if Enum
        and Enum.QuestClassification
        and Enum.QuestClassification.Meta ~= nil
        and classification == Enum.QuestClassification.Meta
    then
        return nil
    end

    if IsWeeklyQuest(questID) then
        return "weekly"
    end

    if IsDailyQuest(questID) then
        return "daily"
    end

    -- Note: frequency is checked via C_QuestLog.GetInfo below

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo then
        local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if questLogIndex and questLogIndex > 0 then
            local info = C_QuestLog.GetInfo(questLogIndex)
            if info then
                if info.isWeekly == true then
                    return "weekly"
                end

                if info.isDaily == true then
                    return "daily"
                end

                local frequency = info.frequency or info.questFrequency
                local dailyFrequency = _G.LE_QUEST_FREQUENCY_DAILY or (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily) or nil
                local weeklyFrequency = _G.LE_QUEST_FREQUENCY_WEEKLY or (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly) or nil
                if frequency ~= nil then
                    if weeklyFrequency ~= nil and frequency == weeklyFrequency then
                        return "weekly"
                    end

                    if dailyFrequency ~= nil and frequency == dailyFrequency then
                        return "daily"
                    end
                end
            end
        end
    end

    if C_QuestLog and C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) then
        -- Repeatable quests can be daily or weekly; without a reliable signal
        -- fall through to the classification check below rather than guessing.
    end

    if Enum
        and Enum.QuestClassification
        and (
            classification == Enum.QuestClassification.Recurring
            or classification == Enum.QuestClassification.Calling
        )
    then
        return "weekly"
    end

    return nil
end

local function IsPreyQuest(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        return C_QuestLog.GetActivePreyQuest() == questID
    end

    return false
end

local function IsTrivialQuest(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsQuestTrivial then
        return C_QuestLog.IsQuestTrivial(questID) == true
    end

    return false
end

local function GetQuestLogInfoByQuestID(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo then
        local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if questLogIndex and questLogIndex > 0 then
            return C_QuestLog.GetInfo(questLogIndex)
        end
    end

    return nil
end

local function BuildRuntimeQuestEntry(questID)
    local info = GetQuestLogInfoByQuestID(questID)
    if not info then
        return nil
    end

    local questLogIndex = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID) or nil
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    local classification = C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification and C_QuestInfoSystem.GetQuestClassification(questID) or nil
    local disabledForSession = C_QuestLog and C_QuestLog.IsQuestDisabledForSession and C_QuestLog.IsQuestDisabledForSession(questID) == true or false

    local quest = {
        questID = questID,
        questLogIndex = questLogIndex,
        title = info.title or (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)) or nil,
        requiredMoney = tonumber(info.requiredMoney) or 0,
        isAutoComplete = info.isAutoComplete == true,
        isTask = info.isTask == true,
        isBounty = info.isBounty == true,
        overridesSortOrder = info.overridesSortOrder,
        classification = classification,
        disabledForSession = disabledForSession,
    }

    function quest:GetID()
        return self.questID
    end

    function quest:GetQuestLogIndex()
        return self.questLogIndex
    end

    function quest:IsComplete()
        return C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(self.questID) == true or false
    end

    function quest:IsDisabledForSession()
        return self.disabledForSession == true
    end

    function quest:GetQuestClassification()
        return self.classification
    end

    return quest
end

local function GetQuestHeaderTitle(questID)
    local info = GetQuestLogInfoByQuestID(questID)
    local title = info and info.title or nil
    if type(title) == "string" and title ~= "" then
        return title
    end

    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        title = C_QuestLog.GetTitleForQuestID(questID)
        if type(title) == "string" and title ~= "" then
            return title
        end
    end

    return nil
end

local function GetQuestDisplayLevel(questID)
    local info = GetQuestLogInfoByQuestID(questID)
    local level = info and (info.level or info.questLevel or info.difficultyLevel) or nil
    if type(level) ~= "number" and type(GetQuestDifficultyLevel) == "function" then
        level = GetQuestDifficultyLevel(questID)
    end

    if type(level) == "number" and level > 0 then
        return level
    end

    return nil
end

local function ShouldShowQuestLevelPrefix(questID)
    local mode = GetLevelPrefixMode()
    if mode == K.LEVEL_PREFIX_MODE_ALL then
        return true
    end

    if mode == K.LEVEL_PREFIX_MODE_TRIVIAL then
        return IsTrivialQuest(questID)
    end

    return false
end

local function IsQuestWarbandCompleted(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    return C_QuestLog
        and C_QuestLog.IsQuestFlaggedCompletedOnAccount
        and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID) == true
        or false
end

local function GetWarbandCompletionAtlas()
    if state.resolvedWarbandCompletionAtlas ~= nil then
        return state.resolvedWarbandCompletionAtlas or nil
    end

    local atlasInfoGetter = C_Texture and C_Texture.GetAtlasInfo or nil
    for _, atlas in ipairs(K.WARBAND_COMPLETION_ICON_ATLASES) do
        if not atlasInfoGetter or atlasInfoGetter(atlas) then
            state.resolvedWarbandCompletionAtlas = atlas
            return atlas
        end
    end

    state.resolvedWarbandCompletionAtlas = false
    return nil
end

local function GetWarbandCompletionCheckAtlas()
    if state.resolvedWarbandCompletionCheckAtlas ~= nil then
        return state.resolvedWarbandCompletionCheckAtlas or nil
    end

    local atlasInfoGetter = C_Texture and C_Texture.GetAtlasInfo or nil
    for _, atlas in ipairs(K.WARBAND_COMPLETION_CHECK_ATLASES) do
        if not atlasInfoGetter or atlasInfoGetter(atlas) then
            state.resolvedWarbandCompletionCheckAtlas = atlas
            return atlas
        end
    end

    state.resolvedWarbandCompletionCheckAtlas = false
    return nil
end

local function IsQuestLikeModule(module)
    local key = GetKeyForModule(module)
    return key == "focusedQuest"
        or key == "campaign"
        or key == "zone"
        or key == "quest"
        or key == "bonusObjective"
        or key == "worldQuest"
end

local function ShouldShowWarbandCompletedIndicator(questID, module)
    return IsWarbandIndicatorEnabled()
        and IsQuestLikeModule(module)
        and IsQuestWarbandCompleted(questID)
        and GetWarbandCompletionAtlas() ~= nil
end

local function BuildQuestHeaderText(questID, fallbackText)
    if type(questID) ~= "number" or questID <= 0 then
        return fallbackText
    end

    local title = GetQuestHeaderTitle(questID) or fallbackText
    if type(title) ~= "string" or title == "" then
        return fallbackText
    end

    if ShouldShowQuestLevelPrefix(questID) then
        local level = GetQuestDisplayLevel(questID)
        if level then
            title = string.format("[%d] %s", level, title)
        end
    end

    return title
end

local function GetSuperTrackedQuestID()
    local questID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() or 0
    if type(questID) == "number" and questID > 0 then
        return questID
    end

    return nil
end

local function IsZoneEligibleQuest(questID, questType)
    if not IsModuleEnabled() then
        return false
    end

    local zone = GetZoneFilters()
    if questType == "quest" then
        return zone.regularQuests == true and IsQuestInCurrentZone(questID)
    elseif questType == "campaign" then
        return zone.campaignQuests == true and IsQuestInCurrentZone(questID)
    elseif questType == "worldQuest" then
        return zone.worldQuests == true and IsTaskQuestReadyForZoneTracker(questID)
    elseif questType == "trackedWorldQuest" then
        -- Tracked world quests: use map-based zone check instead of isInArea.
        -- Blizzard's WorldQuestObjectiveTracker bypasses isInArea for watched quests
        -- (treatAsInArea = isTrackedWorldQuest or isInArea). We match that by checking
        -- map geography only, so tracked quests appear immediately on zone entry
        -- without waiting for the server isInArea flag.
        return zone.worldQuests == true and IsQuestInCurrentZone(questID)
    elseif questType == "bonusObjective" then
        return zone.bonusObjectives == true and IsTaskQuestReadyForZoneTracker(questID)
    end

    return false
end

local function GetZoneQuestType(quest)
    if not quest or not quest.GetID then
        return nil
    end

    local questID = quest:GetID()
    if quest.isTask or quest.isBounty then
        return nil
    end

    if quest.IsDisabledForSession and quest:IsDisabledForSession() then
        return nil
    end

    local questType = GetQuestKind(questID, quest)
    if (questType == "quest" or questType == "campaign") and IsZoneEligibleQuest(questID, questType) then
        return questType
    end

    return nil
end

local function BuildZoneQuestLists()
    local campaignQuests = {}
    local regularQuests = {}

    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then
        return campaignQuests, regularQuests
    end

    for index = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
        if questID then
            local quest = BuildRuntimeQuestEntry(questID)
            local questType = GetZoneQuestType(quest)
            if questType == "campaign" then
                campaignQuests[#campaignQuests + 1] = quest
            elseif questType == "quest" then
                regularQuests[#regularQuests + 1] = quest
            end
        end
    end

    return campaignQuests, regularQuests
end

local function CompareTrackedWorldQuestIDs(leftQuestID, rightQuestID)
    local leftInArea, leftOnMap = GetTaskInfo(leftQuestID)
    local rightInArea, rightOnMap = GetTaskInfo(rightQuestID)

    if leftInArea ~= rightInArea then
        return leftInArea
    end

    if leftOnMap ~= rightOnMap then
        return leftOnMap
    end

    return leftQuestID < rightQuestID
end

local function GetSortedTrackedWorldQuestIDs()
    local trackedWorldQuestIDs = {}

    if not C_QuestLog
        or not C_QuestLog.GetNumWorldQuestWatches
        or not C_QuestLog.GetQuestIDForWorldQuestWatchIndex
    then
        return trackedWorldQuestIDs
    end

    for index = 1, C_QuestLog.GetNumWorldQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForWorldQuestWatchIndex(index)
        if type(questID) == "number" and questID > 0 then
            trackedWorldQuestIDs[#trackedWorldQuestIDs + 1] = questID
        end
    end

    table.sort(trackedWorldQuestIDs, CompareTrackedWorldQuestIDs)
    return trackedWorldQuestIDs
end

local function TrackAllQuestLogQuests()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
        return
    end

    local maxQuestWatches = Constants and Constants.QuestWatchConsts and Constants.QuestWatchConsts.MAX_QUEST_WATCHES or math.huge
    local suppressWatchUpdates = QuestMapFrame ~= nil

    if suppressWatchUpdates then
        QuestMapFrame.ignoreQuestWatchListChanged = true
    end

    local shownWatchLimitError = false
    for questLogIndex = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(questLogIndex)
        if info and not info.isHeader and info.questID and not C_QuestLog.IsQuestDisabledForSession(info.questID) then
            if not QuestUtils_IsQuestWatched(info.questID) then
                if C_QuestLog.GetNumQuestWatches() >= maxQuestWatches then
                    if not shownWatchLimitError and UIErrorsFrame and OBJECTIVES_WATCH_TOO_MANY then
                        UIErrorsFrame:AddMessage(OBJECTIVES_WATCH_TOO_MANY, 1.0, 0.1, 0.1, 1.0)
                    end
                    shownWatchLimitError = true
                    break
                end

                C_QuestLog.AddQuestWatch(info.questID)
            end
        end
    end

    if suppressWatchUpdates then
        QuestMapFrame.ignoreQuestWatchListChanged = false
        if QuestMapFrame_UpdateAll then
            QuestMapFrame_UpdateAll()
        end
    end

    if ObjectiveTrackerManager and ObjectiveTrackerManager.UpdateAll then
        ObjectiveTrackerManager:UpdateAll()
    elseif ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
        ObjectiveTrackerFrame:Update()
    end
end

local NomToolsZoneObjectiveTrackerMixin = {}
for key, value in pairs(K.ZONE_TRACKER_SETTINGS) do
    NomToolsZoneObjectiveTrackerMixin[key] = value
end

function NomToolsZoneObjectiveTrackerMixin:InitModule()
    if QuestObjectiveTrackerMixin and QuestObjectiveTrackerMixin.InitModule then
        QuestObjectiveTrackerMixin.InitModule(self)
        return
    end

    self:AddTag("quest")
    self:WatchMoney(false)
end

local function StopModuleTicker(module)
    if not module then
        return
    end

    if module.ticker then
        module.ticker:Cancel()
        module.ticker = nil
    end

    module.nomtoolsTickerSeconds = 0
end

local function StopZoneTaskRetry(module)
    if not module then
        return
    end

    if module.nomtoolsZoneTaskRetryTicker then
        module.nomtoolsZoneTaskRetryTicker:Cancel()
        module.nomtoolsZoneTaskRetryTicker = nil
    end

    module.nomtoolsZoneTaskRetryAttemptsRemaining = 0
end

local function ShouldRunZoneTaskRetry(module)
    if module ~= state.zoneModule or not IsModuleEnabled() then
        return false
    end

    local zone = GetZoneFilters()
    return zone and (zone.worldQuests == true or zone.bonusObjectives == true) or false
end

local function StartZoneTaskRetry(module)
    if not ShouldRunZoneTaskRetry(module) or not C_Timer or not C_Timer.NewTicker then
        StopZoneTaskRetry(module)
        return
    end

    StopZoneTaskRetry(module)
    module.nomtoolsZoneTaskRetryAttemptsRemaining = K.ZONE_TASK_RETRY_MAX_ATTEMPTS
    module.nomtoolsZoneTaskRetryTicker = C_Timer.NewTicker(K.ZONE_TASK_RETRY_INTERVAL_SECONDS, function()
        local remaining = (module.nomtoolsZoneTaskRetryAttemptsRemaining or 0) - 1
        module.nomtoolsZoneTaskRetryAttemptsRemaining = remaining
        RequestCustomModuleRefresh(module)
        if remaining <= 0 then
            StopZoneTaskRetry(module)
        end
    end)
end

local function UpdateModuleTicker(module)
    if not module then
        return
    end

    local desiredTickerSeconds = tonumber(module.tickerSeconds) or 0
    if desiredTickerSeconds <= 0 or not C_Timer or not C_Timer.NewTicker then
        StopModuleTicker(module)
        return
    end

    if module.ticker and module.nomtoolsTickerSeconds == desiredTickerSeconds then
        return
    end

    StopModuleTicker(module)
    module.nomtoolsTickerSeconds = desiredTickerSeconds
    module.ticker = C_Timer.NewTicker(desiredTickerSeconds, function()
        RequestCustomModuleRefresh(module)
    end)
end

local function FinalizeModuleLayout(module)
    UpdateModuleTicker(module)
end

local function WithTaskTrackerTemplates(module, questKind, callback)
    if not module or type(callback) ~= "function" then
        return false
    end

    local previousShowWorldQuests = module.showWorldQuests
    local previousBlockTemplate = module.blockTemplate
    local previousLineTemplate = module.lineTemplate
    local previousProgressBarTemplate = module.progressBarTemplate
    local previousHeaderText = module.headerText

    module.showWorldQuests = questKind == "worldQuest"
    module.blockTemplate = "BonusObjectiveTrackerBlockTemplate"
    module.lineTemplate = "ObjectiveTrackerAnimLineTemplate"
    module.progressBarTemplate = "BonusTrackerProgressBarTemplate"

    local ok, result = pcall(callback)

    module.showWorldQuests = previousShowWorldQuests
    module.blockTemplate = previousBlockTemplate
    module.lineTemplate = previousLineTemplate
    module.progressBarTemplate = previousProgressBarTemplate
    module.headerText = previousHeaderText

    if not ok then
        error(result)
    end

    return result
end

local function EnsureQuestRewardData(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return true
    end

    if type(HaveQuestRewardData) ~= "function"
        or not C_TaskQuest
        or not C_TaskQuest.RequestPreloadRewardData
    then
        return true
    end

    if HaveQuestRewardData(questID) then
        state.pendingRewardDataQuestIDs[questID] = nil
        return true
    end

    if not state.pendingRewardDataQuestIDs[questID] then
        state.pendingRewardDataQuestIDs[questID] = true
        C_TaskQuest.RequestPreloadRewardData(questID)
    end

    return false
end

RequestCustomModuleRefresh = function(module)
    state.postLayoutStyleDirty = true

    if module and module.MarkDirty then
        module:MarkDirty()
    end
    -- Do NOT call RequestTrackerLayoutRefresh() here. That calls
    -- ObjectiveTrackerManager.UpdateAll() which forces every tracker module
    -- (including Blizzard's QuestObjectiveTracker) to re-layout, resetting
    -- all block HeaderTexts to plain titles. On high-frequency events like
    -- QUEST_POI_UPDATE or SCENARIO_CRITERIA_UPDATE this creates a
    -- continuous every-frame flicker when regularQuests are shown in the
    -- normal quest tracker (regularQuests zone filter disabled). Just
    -- marking the module dirty is enough: Blizzard's container OnUpdate will
    -- call ObjectiveTrackerFrame:Update() on the next frame, which only
    -- re-layouts dirty modules and triggers RunTrackerPostLayout so
    -- ApplyTrackerStyles re-applies level prefixes and other styling.
end

function NomToolsZoneObjectiveTrackerMixin:OnHide()
    StopZoneTaskRetry(self)
    StopModuleTicker(self)

    if ObjectiveTrackerModuleMixin and ObjectiveTrackerModuleMixin.OnHide then
        ObjectiveTrackerModuleMixin.OnHide(self)
    end
end

function NomToolsZoneObjectiveTrackerMixin:OnEvent(event, ...)
    local questID = ...
    if (event == "QUEST_DATA_LOAD_RESULT" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED")
        and type(questID) == "number"
        and questID > 0
    then
        state.pendingRewardDataQuestIDs[questID] = nil
    end

    if self == state.zoneModule then
        if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
            StartZoneTaskRetry(self)
        end
    end

    RequestCustomModuleRefresh(self)
end

function NomToolsZoneObjectiveTrackerMixin:WatchMoney(watch)
    if QuestObjectiveTrackerMixin and QuestObjectiveTrackerMixin.WatchMoney then
        QuestObjectiveTrackerMixin.WatchMoney(self, watch)
    end
end

function NomToolsZoneObjectiveTrackerMixin:DoQuestObjectives(block, questCompleted, questSequenced, isExistingBlock, useFullHeight)
    if QuestObjectiveTrackerMixin and QuestObjectiveTrackerMixin.DoQuestObjectives then
        return QuestObjectiveTrackerMixin.DoQuestObjectives(self, block, questCompleted, questSequenced, isExistingBlock, useFullHeight)
    end

    return false
end

function NomToolsZoneObjectiveTrackerMixin:TryAddingExpirationWarningLine(block, questID)
    if WorldQuestObjectiveTrackerMixin and WorldQuestObjectiveTrackerMixin.TryAddingExpirationWarningLine then
        WorldQuestObjectiveTrackerMixin.TryAddingExpirationWarningLine(self, block, questID)
    end
end

function NomToolsZoneObjectiveTrackerMixin:SetUpQuestBlock(block, forceShowCompleted)
    if BonusObjectiveTrackerMixin and BonusObjectiveTrackerMixin.SetUpQuestBlock then
        BonusObjectiveTrackerMixin.SetUpQuestBlock(self, block, forceShowCompleted)
    end
end

function NomToolsZoneObjectiveTrackerMixin:ShouldDisplayQuest(quest)
    return GetZoneQuestType(quest) ~= nil
end

function NomToolsZoneObjectiveTrackerMixin:AddWatchedQuest(quest)
    local didLayout = QuestObjectiveTrackerMixin and QuestObjectiveTrackerMixin.UpdateSingle and QuestObjectiveTrackerMixin.UpdateSingle(self, quest)
    if didLayout ~= false and quest and quest.GetID then
        local block = self:GetExistingBlock(quest:GetID())
        if block then
            block.nomtoolsQuestKind = GetZoneQuestType(quest)
        end
    end

    return didLayout ~= false
end

function NomToolsZoneObjectiveTrackerMixin:AddTaskQuest(questID, questKind, isTrackedWorldQuest)
    local didLayout = false

    WithTaskTrackerTemplates(self, questKind, function()
        if questKind == "worldQuest" then
            EnsureQuestRewardData(questID)
        end

        if BonusObjectiveTrackerMixin and BonusObjectiveTrackerMixin.AddQuest then
            didLayout = BonusObjectiveTrackerMixin.AddQuest(self, questID, isTrackedWorldQuest) ~= false
        end
    end)

    if didLayout then
        local block = self:GetExistingBlock(questID, "BonusObjectiveTrackerBlockTemplate")
        if block then
            block.nomtoolsQuestKind = questKind
        end
    end

    return didLayout
end

function NomToolsZoneObjectiveTrackerMixin:AddZoneTask(questID, questKind, forceShowInArea)
    local isTrackedWorldQuest = questKind == "worldQuest" and forceShowInArea == true or false
    return self:AddTaskQuest(questID, questKind, isTrackedWorldQuest)
end

local zoneTrackerLayoutDeps = {
    buildZoneQuestLists = BuildZoneQuestLists,
    finalizeModuleLayout = FinalizeModuleLayout,
    getSortedTrackedWorldQuestIDs = GetSortedTrackedWorldQuestIDs,
    getZoneFilters = GetZoneFilters,
    isModuleEnabled = IsModuleEnabled,
    isZoneEligibleQuest = IsZoneEligibleQuest,
    zoneTrackerHeader = ZONE_TRACKER_HEADER,
}

function NomToolsZoneObjectiveTrackerMixin:LayoutContents()
    local deps = zoneTrackerLayoutDeps

    self.tickerSeconds = 0

    if not deps.isModuleEnabled() then
        return deps.finalizeModuleLayout(self)
    end

    self:SetHeader(deps.zoneTrackerHeader)
    self:AddAutoQuestObjectives()
    if self:HasSkippedBlocks() then
        return deps.finalizeModuleLayout(self)
    end

    self:WatchMoney(false)

    local campaignQuests, regularQuests = deps.buildZoneQuestLists()
    for _, quest in ipairs(campaignQuests) do
        if not ns.ShouldFilterQuest(quest:GetID(), quest) then
            if not self:AddWatchedQuest(quest) then
                return deps.finalizeModuleLayout(self)
            end
        end
    end

    for _, quest in ipairs(regularQuests) do
        if not ns.ShouldFilterQuest(quest:GetID(), quest) then
            if not self:AddWatchedQuest(quest) then
                return deps.finalizeModuleLayout(self)
            end
        end
    end

    local zone = deps.getZoneFilters()
    if zone.worldQuests then
        local tasksTable = GetTasksTable and GetTasksTable() or nil
        if tasksTable then
            for index = 1, #tasksTable do
                local questID = tasksTable[index]
                if questID
                    and QuestUtils_IsQuestWorldQuest(questID)
                    and not QuestUtils_IsQuestWatched(questID)
                    and deps.isZoneEligibleQuest(questID, "worldQuest")
                    and not ns.ShouldFilterQuest(questID)
                then
                    if not self:AddZoneTask(questID, "worldQuest", false) then
                        return deps.finalizeModuleLayout(self)
                    end
                end
            end
        end
        

        for _, questID in ipairs(deps.getSortedTrackedWorldQuestIDs()) do
            if deps.isZoneEligibleQuest(questID, "trackedWorldQuest") and not ns.ShouldFilterQuest(questID) then
                if not self:AddZoneTask(questID, "worldQuest", true) then
                    return deps.finalizeModuleLayout(self)
                end
            end
        end
    end

    if zone.bonusObjectives and GetTasksTable then
        local tasksTable = GetTasksTable()
        if tasksTable then
            for index = 1, #tasksTable do
                local questID = tasksTable[index]
                if questID
                    and not QuestUtils_IsQuestWorldQuest(questID)
                    and not QuestUtils_IsQuestWatched(questID)
                    and deps.isZoneEligibleQuest(questID, "bonusObjective")
                    and not ns.ShouldFilterQuest(questID)
                then
                    if not self:AddZoneTask(questID, "bonusObjective") then
                        return deps.finalizeModuleLayout(self)
                    end
                end
            end
        end
    end

    return deps.finalizeModuleLayout(self)
end

function NomToolsZoneObjectiveTrackerMixin:OnBlockHeaderClick(block, mouseButton)
    if block and (block.nomtoolsQuestKind == "worldQuest" or block.nomtoolsQuestKind == "bonusObjective") then
        local previousShowWorldQuests = self.showWorldQuests
        self.showWorldQuests = block.nomtoolsQuestKind == "worldQuest"
        if BonusObjectiveTrackerMixin and BonusObjectiveTrackerMixin.OnBlockHeaderClick then
            BonusObjectiveTrackerMixin.OnBlockHeaderClick(self, block, mouseButton)
        end
        self.showWorldQuests = previousShowWorldQuests
        return
    end

    if QuestObjectiveTrackerMixin and QuestObjectiveTrackerMixin.OnBlockHeaderClick then
        QuestObjectiveTrackerMixin.OnBlockHeaderClick(self, block, mouseButton)
    end
end

function NomToolsZoneObjectiveTrackerMixin:OnBlockHeaderEnter(block)
    if block and (block.nomtoolsQuestKind == "worldQuest" or block.nomtoolsQuestKind == "bonusObjective") then
        local previousShowWorldQuests = self.showWorldQuests
        self.showWorldQuests = block.nomtoolsQuestKind == "worldQuest"
        if BonusObjectiveTrackerMixin and BonusObjectiveTrackerMixin.OnBlockHeaderEnter then
            BonusObjectiveTrackerMixin.OnBlockHeaderEnter(self, block)
        end
        self.showWorldQuests = previousShowWorldQuests
        return
    end

    if QuestObjectiveTrackerMixin and QuestObjectiveTrackerMixin.OnBlockHeaderEnter then
        QuestObjectiveTrackerMixin.OnBlockHeaderEnter(self, block)
    end
end

function NomToolsZoneObjectiveTrackerMixin:OnBlockHeaderLeave(block)
    if block and (block.nomtoolsQuestKind == "worldQuest" or block.nomtoolsQuestKind == "bonusObjective") then
        if BonusObjectiveTrackerMixin and BonusObjectiveTrackerMixin.OnBlockHeaderLeave then
            BonusObjectiveTrackerMixin.OnBlockHeaderLeave(self, block)
        elseif GameTooltip then
            GameTooltip:Hide()
        end
        return
    end

    if QuestObjectiveTrackerMixin and QuestObjectiveTrackerMixin.OnBlockHeaderLeave then
        QuestObjectiveTrackerMixin.OnBlockHeaderLeave(self, block)
    elseif GameTooltip then
        GameTooltip:Hide()
    end
end

function NomToolsZoneObjectiveTrackerMixin:OnFreeBlock(block)
    block.ItemButton = nil
    block.nomtoolsQuestKind = nil
    block.numObjectives = nil
    block.taskName = nil
    block.nomtoolsSortData = nil
end

local NomToolsFocusedQuestTrackerMixin = {}
for key, value in pairs(K.FOCUSED_TRACKER_SETTINGS) do
    NomToolsFocusedQuestTrackerMixin[key] = value
end

NomToolsFocusedQuestTrackerMixin.InitModule = NomToolsZoneObjectiveTrackerMixin.InitModule
NomToolsFocusedQuestTrackerMixin.OnHide = NomToolsZoneObjectiveTrackerMixin.OnHide
NomToolsFocusedQuestTrackerMixin.OnEvent = NomToolsZoneObjectiveTrackerMixin.OnEvent
NomToolsFocusedQuestTrackerMixin.WatchMoney = NomToolsZoneObjectiveTrackerMixin.WatchMoney
NomToolsFocusedQuestTrackerMixin.DoQuestObjectives = NomToolsZoneObjectiveTrackerMixin.DoQuestObjectives
NomToolsFocusedQuestTrackerMixin.TryAddingExpirationWarningLine = NomToolsZoneObjectiveTrackerMixin.TryAddingExpirationWarningLine
NomToolsFocusedQuestTrackerMixin.SetUpQuestBlock = NomToolsZoneObjectiveTrackerMixin.SetUpQuestBlock
NomToolsFocusedQuestTrackerMixin.AddWatchedQuest = NomToolsZoneObjectiveTrackerMixin.AddWatchedQuest
NomToolsFocusedQuestTrackerMixin.AddTaskQuest = NomToolsZoneObjectiveTrackerMixin.AddTaskQuest
NomToolsFocusedQuestTrackerMixin.AddZoneTask = NomToolsZoneObjectiveTrackerMixin.AddZoneTask
NomToolsFocusedQuestTrackerMixin.OnBlockHeaderClick = NomToolsZoneObjectiveTrackerMixin.OnBlockHeaderClick
NomToolsFocusedQuestTrackerMixin.OnBlockHeaderEnter = NomToolsZoneObjectiveTrackerMixin.OnBlockHeaderEnter
NomToolsFocusedQuestTrackerMixin.OnBlockHeaderLeave = NomToolsZoneObjectiveTrackerMixin.OnBlockHeaderLeave
NomToolsFocusedQuestTrackerMixin.OnFreeBlock = NomToolsZoneObjectiveTrackerMixin.OnFreeBlock

function NomToolsFocusedQuestTrackerMixin:OnEvent(event, ...)
    if not IsModuleEnabled() or not IsFocusedQuestEnabled() then
        return
    end

    local questID = ...
    if (event == "QUEST_DATA_LOAD_RESULT" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED")
        and type(questID) == "number"
        and questID > 0
    then
        state.pendingRewardDataQuestIDs[questID] = nil
    end

    RequestCustomModuleRefresh(self)
end

local function RegisterCustomModuleEvents(module)
    if not module or module.nomtoolsEventsRegistered or type(module.events) ~= "table" then
        return
    end

    for _, event in ipairs(module.events) do
        module:RegisterEvent(event)
    end

    module.nomtoolsEventsRegistered = true
end

local function UnregisterCustomModuleEvents(module)
    if not module or not module.nomtoolsEventsRegistered or type(module.events) ~= "table" then
        return
    end

    for _, event in ipairs(module.events) do
        module:UnregisterEvent(event)
    end

    module.nomtoolsEventsRegistered = false
end

function NomToolsFocusedQuestTrackerMixin:ShouldDisplayQuest(quest)
    if not IsFocusedQuestEnabled() then
        return false
    end

    local focusedQuestID = GetSuperTrackedQuestID()
    return quest and quest.GetID and focusedQuestID and quest:GetID() == focusedQuestID or false
end

function NomToolsFocusedQuestTrackerMixin:LayoutContents()
    self.tickerSeconds = 0

    if not IsModuleEnabled() or not IsFocusedQuestEnabled() then
        return FinalizeModuleLayout(self)
    end

    self:SetHeader(FOCUSED_TRACKER_HEADER)
    self:WatchMoney(false)

    local focusedQuestID = GetSuperTrackedQuestID()
    if not focusedQuestID then
        return FinalizeModuleLayout(self)
    end

    if ns.ShouldFilterQuest(focusedQuestID) then
        return FinalizeModuleLayout(self)
    end

    local quest = BuildRuntimeQuestEntry(focusedQuestID)
    local questKind = GetQuestKind(focusedQuestID, quest)
    if questKind == "quest" or questKind == "campaign" then
        if not quest or not self:AddWatchedQuest(quest) then
            return FinalizeModuleLayout(self)
        end
    elseif questKind == "worldQuest" or questKind == "bonusObjective" then
        if not self:AddZoneTask(focusedQuestID, questKind, true) then
            return FinalizeModuleLayout(self)
        end
    else
        return FinalizeModuleLayout(self)
    end

    return FinalizeModuleLayout(self)
end

local function EnsureFocusedQuestModule()
    if state.focusedQuestModule or not ObjectiveTrackerFrame then
        return state.focusedQuestModule
    end

    local focusedQuestModule = CreateFrame("Frame", FOCUSED_TRACKER_NAME, ObjectiveTrackerFrame, "ObjectiveTrackerModuleTemplate")
    if QuestObjectiveTrackerMixin then
        Mixin(focusedQuestModule, QuestObjectiveTrackerMixin)
    end
    Mixin(focusedQuestModule, NomToolsFocusedQuestTrackerMixin)
    focusedQuestModule:SetScript("OnEvent", focusedQuestModule.OnEvent)
    if not focusedQuestModule.usedBlocks and ObjectiveTrackerModuleMixin and ObjectiveTrackerModuleMixin.OnLoad then
        ObjectiveTrackerModuleMixin.OnLoad(focusedQuestModule)
    end
    focusedQuestModule:SetHeader(FOCUSED_TRACKER_HEADER)

    state.focusedQuestModule = focusedQuestModule
    return focusedQuestModule
end

local function EnsureZoneModule()
    if state.zoneModule or not ObjectiveTrackerFrame then
        return state.zoneModule
    end

    local zoneModule = CreateFrame("Frame", ZONE_TRACKER_NAME, ObjectiveTrackerFrame, "ObjectiveTrackerModuleTemplate")
    if QuestObjectiveTrackerMixin then
        Mixin(zoneModule, QuestObjectiveTrackerMixin)
    end
    Mixin(zoneModule, NomToolsZoneObjectiveTrackerMixin)
    zoneModule:SetScript("OnEvent", zoneModule.OnEvent)
    if not zoneModule.usedBlocks and ObjectiveTrackerModuleMixin and ObjectiveTrackerModuleMixin.OnLoad then
        ObjectiveTrackerModuleMixin.OnLoad(zoneModule)
    end
    zoneModule:SetHeader(ZONE_TRACKER_HEADER)

    state.zoneModule = zoneModule
    return zoneModule
end

do -- EnsureSearchFrame (scoped to avoid the 200-local-per-chunk limit)

---@return table|nil searchFrame
local function _CreateSearchFrame()
    if not ObjectiveTrackerFrame then
        return nil
    end
    if InCombatLockdown() then return nil end

    local searchFrame = CreateFrame("Frame", addonName .. "ObjectiveTrackerSearchFrame", ObjectiveTrackerFrame)
    searchFrame:SetHeight(K.SEARCH_FRAME_HEIGHT)
    searchFrame.nomtoolsSearchFrame = true
    searchFrame.nomtoolsObjectiveTrackerKey = "search"

    local bg = searchFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(searchFrame)
    bg:SetColorTexture(0, 0, 0, 0.1)
    searchFrame.bg = bg

    local borderFrame = CreateFrame("Frame", nil, searchFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    borderFrame:SetAllPoints(searchFrame)
    borderFrame:SetFrameLevel((searchFrame:GetFrameLevel() or 0) + 1)
    borderFrame:EnableMouse(false)
    searchFrame.borderFrame = borderFrame

    local editBox = CreateFrame("EditBox", nil, searchFrame, "InputBoxTemplate")
    -- Chrome visibility is managed dynamically by ApplySearchBarSettings based on preset
    editBox:SetAutoFocus(false)
    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", searchFrame, "TOPLEFT", 8, 0)
    editBox:SetPoint("BOTTOMRIGHT", searchFrame, "BOTTOMRIGHT", -8, 0)
    editBox:SetFontObject(GameFontHighlightSmall)

    local placeholder = editBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", editBox, "LEFT", 0, 0)
    placeholder:SetText(K.SEARCH_PLACEHOLDER_TEXT)
    editBox.placeholder = placeholder
    searchFrame.editBox = editBox
    searchFrame.placeholder = placeholder

    editBox:SetScript("OnTextChanged", function(self)
        local text = strtrim(self:GetText() or ""):lower()
        state.searchText = text
        if text == "" then
            placeholder:Show()
        else
            placeholder:Hide()
        end
        if state.searchDebounceTimer then
            state.searchDebounceTimer:Cancel()
            state.searchDebounceTimer = nil
        end
        if text == "" then
            RequestTrackerLayoutRefresh()
            state.postLayoutStyleDirty = true
        else
            state.searchDebounceTimer = C_Timer.NewTimer(K.SEARCH_DEBOUNCE_INTERVAL, function()
                state.searchDebounceTimer = nil
                RequestTrackerLayoutRefresh()
                state.postLayoutStyleDirty = true
            end)
        end
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    state.searchFrame = searchFrame
    state.searchEditBox = editBox
    return searchFrame
end

ns.EnsureSearchFrame = function()
    if state.searchFrame then
        return state.searchFrame
    end
    return _CreateSearchFrame()
end

end -- do: EnsureSearchFrame

do -- EnsureFilterButton / EnsureFilterDropdown (scoped to avoid the 200-local-per-chunk limit)

local function GetFilterSettings()
    local settings = GetSettings()
    settings.filter = settings.filter or {}
    return settings.filter
end

local function IsFilterButtonEnabled()
    local b = GetSettings().buttons or {}
    return b.filterButton ~= false
end

-- Tables to hold dropdown row buttons for checkmark updates.
local typeButtons = {}
local sortButtons = {}
local directionButtons = {}
local zoneDirectionButtons = {}
local groupByZoneButton = nil
local showTrivialButton = nil

local function UpdateTypeChecks()
    local filterSettings = GetFilterSettings()
    local questTypes = filterSettings.questTypes or {}
    for _, tb in ipairs(typeButtons) do
        tb.checkmark:SetShown(not questTypes[tb.typeKey])
    end
end

local function UpdateSortChecks()
    local filterSettings = GetFilterSettings()
    for _, sb in ipairs(sortButtons) do
        sb.checkmark:SetShown(filterSettings.sortBy == sb.sortKey)
    end
end

local function UpdateDirectionChecks()
    local filterSettings = GetFilterSettings()
    for _, db in ipairs(directionButtons) do
        db.checkmark:SetShown(filterSettings.sortDirection == db.directionKey)
    end
end

local function UpdateZoneDirectionChecks()
    local filterSettings = GetFilterSettings()
    local zoneSortDir = filterSettings.zoneSortDirection or "asc"
    for _, db in ipairs(zoneDirectionButtons) do
        db.checkmark:SetShown(zoneSortDir == db.directionKey)
    end
end

local function UpdateGroupByZoneCheck()
    if not groupByZoneButton then return end
    local filterSettings = GetFilterSettings()
    groupByZoneButton.checkmark:SetShown(filterSettings.groupByZone == true)
end

local function UpdateShowTrivialCheck()
    if not showTrivialButton then return end
    local filterSettings = GetFilterSettings()
    showTrivialButton.checkmark:SetShown(filterSettings.showTrivial ~= false)
end

local function UpdateDirectionButtonsEnabled()
    local fs = GetFilterSettings()
    -- Quest sort direction: only relevant when sorting by name (not default)
    local questEnabled = fs.sortBy ~= "default"
    for _, db in ipairs(directionButtons) do
        if questEnabled then
            db:Enable()
            db.label:SetTextColor(1, 1, 1, 1)
        else
            db:Disable()
            db.label:SetTextColor(0.45, 0.45, 0.45, 1)
        end
    end
    -- Zone sort direction: only relevant when zone grouping is on
    local zoneEnabled = fs.groupByZone == true
    for _, db in ipairs(zoneDirectionButtons) do
        if zoneEnabled then
            db:Enable()
            db.label:SetTextColor(1, 1, 1, 1)
        else
            db:Disable()
            db.label:SetTextColor(0.45, 0.45, 0.45, 1)
        end
    end
end

local function IsFilterDefault()
    local fs = GetFilterSettings()
    if fs.questTypes and next(fs.questTypes) then return false end
    if fs.sortBy and fs.sortBy ~= "default" then return false end
    if fs.sortDirection and fs.sortDirection ~= "asc" then return false end
    if fs.groupByZone then return false end
    if fs.zoneSortDirection and fs.zoneSortDirection ~= "asc" then return false end
    if fs.showTrivial == false then return false end
    return true
end

local function UpdateFilterResetState()
    -- No-op: reset is now inside the dropdown menu
end

local function ResetFiltersToDefault()
    local fs = GetFilterSettings()
    wipe(fs)
    UpdateTypeChecks()
    UpdateSortChecks()
    UpdateDirectionChecks()
    UpdateZoneDirectionChecks()
    UpdateDirectionButtonsEnabled()
    UpdateGroupByZoneCheck()
    UpdateShowTrivialCheck()
    UpdateFilterResetState()
    RequestTrackerLayoutRefresh()
end

---@param yPos number
---@param text string
---@param parent table
---@return table header
local function AddDropHeader(yPos, text, parent)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yPos)
    lbl:SetText(text)
    lbl:SetTextColor(0.8, 0.72, 0.42)
    return lbl
end

---@param anchor table
---@param yOff number
---@param labelText string
---@param onClick function
---@param parent table
---@return table btn
local function AddDropButton(anchor, yOff, labelText, onClick, parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(18)
    btn:SetPoint("TOP",   anchor, "BOTTOM",  0, yOff)
    btn:SetPoint("LEFT",  parent, "LEFT",    4, 0)
    btn:SetPoint("RIGHT", parent, "RIGHT",  -4, 0)

    local check = btn:CreateTexture(nil, "ARTWORK")
    check:SetSize(14, 14)
    check:SetPoint("LEFT", btn, "LEFT", 10, 0)
    check:SetAtlas("checkmark-minimal")
    check:Hide()
    btn.checkmark = check

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", check, "RIGHT", 4, 0)
    lbl:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(labelText)
    btn.label = lbl

    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "ADD")
    btn:SetScript("OnClick", onClick)
    return btn
end

---@param parent table
---@return table divider
local function AddDivider(parent, curY)
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  parent, "TOPLEFT",  8, curY - 4)
    div:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, curY - 4)
    div:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    return div
end

ns.EnsureFilterDropdown = function()
    if InCombatLockdown() then return nil end
    if state.filterDropFrame then
        return state.filterDropFrame
    end
    if not ObjectiveTrackerFrame or not ObjectiveTrackerFrame.Header then
        return nil
    end

    local header = ObjectiveTrackerFrame.Header
    local dropFrame = CreateFrame("Frame", addonName .. "ObjectiveTrackerFilterDrop",
                                  ObjectiveTrackerFrame, "BackdropTemplate")
    dropFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dropFrame:SetWidth(K.FILTER_DROP_WIDTH)
    dropFrame:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
    dropFrame:SetFrameStrata("DIALOG")
    dropFrame:SetFrameLevel(100)
    dropFrame:Hide()
    dropFrame:EnableMouse(true)

    -- Close listener — fullscreen invisible frame behind dropdown
    local dropCloseListener = CreateFrame("Frame", nil, UIParent)
    dropCloseListener:EnableMouse(true)
    dropCloseListener:SetAllPoints(UIParent)
    dropCloseListener:SetFrameStrata("DIALOG")
    dropCloseListener:SetFrameLevel(50)
    dropCloseListener:Hide()
    dropCloseListener:SetScript("OnMouseDown", function()
        dropFrame:Hide()
        dropCloseListener:Hide()
    end)

    local filterSettings = GetFilterSettings()
    local curY = -8

    -- ── Section 1: Quest Types (multi-select, exclusion-set) ──────────
    local typeHeader = AddDropHeader(curY, "Quest Types", dropFrame)
    curY = curY - 18

    local lastTypeAnchor = typeHeader
    for _, key in ipairs(K.FILTER_QUEST_TYPE_KEYS) do
        local lbl = K.FILTER_QUEST_TYPE_LABELS[key] or key
        local tb = AddDropButton(lastTypeAnchor, -2, lbl, function()
            local fs = GetFilterSettings()
            fs.questTypes = fs.questTypes or {}
            if fs.questTypes[key] then
                fs.questTypes[key] = nil
            else
                fs.questTypes[key] = true
            end
            UpdateTypeChecks()
            UpdateFilterResetState()
            RequestTrackerLayoutRefresh()
        end, dropFrame)
        tb.typeKey = key
        typeButtons[#typeButtons + 1] = tb
        lastTypeAnchor = tb
        curY = curY - 20
    end

    AddDivider(dropFrame, curY)
    curY = curY - 12

    -- ── Section 2: Other Filters ──────────────────────────────────────
    local otherHeader = AddDropHeader(curY, "Other Filters", dropFrame)
    curY = curY - 18

    showTrivialButton = AddDropButton(otherHeader, -2, "Show Trivial Quests", function()
        local fs = GetFilterSettings()
        fs.showTrivial = fs.showTrivial == false
        UpdateShowTrivialCheck()
        UpdateFilterResetState()
        RequestTrackerLayoutRefresh()
    end, dropFrame)
    curY = curY - 20

    AddDivider(dropFrame, curY)
    curY = curY - 12

    -- ── Section 3: Sort By (radio) ────────────────────────────────────
    local sortHeader = AddDropHeader(curY, "Sort By", dropFrame)
    curY = curY - 18

    local lastSortAnchor = sortHeader
    for _, key in ipairs(K.SORT_MODE_KEYS) do
        local lbl = K.SORT_MODE_LABELS[key] or key
        local sb = AddDropButton(lastSortAnchor, -2, lbl, function()
            local fs = GetFilterSettings()
            fs.sortBy = key
            UpdateSortChecks()
            UpdateDirectionButtonsEnabled()
            UpdateFilterResetState()
            RequestTrackerLayoutRefresh()
        end, dropFrame)
        sb.sortKey = key
        sortButtons[#sortButtons + 1] = sb
        lastSortAnchor = sb
        curY = curY - 20
    end

    AddDivider(dropFrame, curY)
    curY = curY - 12

    -- ── Section 4: Quest Sort Direction (radio) ─────────────────────────────
    local dirHeader = AddDropHeader(curY, "Quest Sort Direction", dropFrame)
    curY = curY - 18

    local DIRECTION_DEFS = {
        { key = "asc",  label = "Ascending" },
        { key = "desc", label = "Descending" },
    }

    local lastDirAnchor = dirHeader
    for _, def in ipairs(DIRECTION_DEFS) do
        local db = AddDropButton(lastDirAnchor, -2, def.label, function()
            local fs = GetFilterSettings()
            fs.sortDirection = def.key
            UpdateDirectionChecks()
            UpdateFilterResetState()
            RequestTrackerLayoutRefresh()
        end, dropFrame)
        db.directionKey = def.key
        directionButtons[#directionButtons + 1] = db
        lastDirAnchor = db
        curY = curY - 20
    end

    AddDivider(dropFrame, curY)
    curY = curY - 12

    -- ── Section 5: Group By Zone (single checkbox) ────────────────────
    local groupHeader = AddDropHeader(curY, "Group By Zone", dropFrame)
    curY = curY - 18

    groupByZoneButton = AddDropButton(groupHeader, -2, "Separate by Zone", function()
        local fs = GetFilterSettings()
        fs.groupByZone = not fs.groupByZone
        UpdateGroupByZoneCheck()
        UpdateDirectionButtonsEnabled()
        UpdateFilterResetState()
        RequestTrackerLayoutRefresh()
    end, dropFrame)
    curY = curY - 20

    AddDivider(dropFrame, curY)
    curY = curY - 12

    -- ── Section 6: Zone Sort Direction (radio) ───────────────────────
    local zoneDirHeader = AddDropHeader(curY, "Zone Sort Direction", dropFrame)
    curY = curY - 18

    local lastZoneDirAnchor = zoneDirHeader
    for _, def in ipairs(DIRECTION_DEFS) do
        local zdb = AddDropButton(lastZoneDirAnchor, -2, def.label, function()
            local fs = GetFilterSettings()
            fs.zoneSortDirection = def.key
            UpdateZoneDirectionChecks()
            UpdateFilterResetState()
            RequestTrackerLayoutRefresh()
        end, dropFrame)
        zdb.directionKey = def.key
        zoneDirectionButtons[#zoneDirectionButtons + 1] = zdb
        lastZoneDirAnchor = zdb
        curY = curY - 20
    end

    -- ── Reset Filters button at bottom ────────────────────────────────
    AddDivider(dropFrame, curY)
    curY = curY - 12

    local resetBtn = CreateFrame("Button", nil, dropFrame)
    resetBtn:SetHeight(20)
    resetBtn:SetPoint("TOPLEFT", dropFrame, "TOPLEFT", 8, curY)
    resetBtn:SetPoint("TOPRIGHT", dropFrame, "TOPRIGHT", -8, curY)
    local resetLabel = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetLabel:SetPoint("CENTER")
    resetLabel:SetText(RESET)
    resetLabel:SetTextColor(1, 0.82, 0)
    resetBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "ADD")
    resetBtn:SetScript("OnClick", function()
        ResetFiltersToDefault()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    resetBtn:SetScript("OnEnter", function(self)
        if IsFilterDefault() then
            resetLabel:SetTextColor(0.5, 0.5, 0.5)
        else
            resetLabel:SetTextColor(1, 1, 1)
        end
    end)
    resetBtn:SetScript("OnLeave", function()
        resetLabel:SetTextColor(1, 0.82, 0)
    end)
    state.filterResetButton = resetBtn
    curY = curY - 22

    dropFrame:SetHeight(math.abs(curY) + 12)

    state.filterDropFrame = dropFrame
    state.filterDropCloseListener = dropCloseListener

    dropFrame:SetScript("OnHide", function()
        state.filterDropCloseListener:Hide()
    end)

    return dropFrame
end

ns.EnsureFilterButton = function()
    if state.filterButton then
        return state.filterButton
    end
    if not ObjectiveTrackerFrame or not ObjectiveTrackerFrame.Header then
        return nil
    end
    if InCombatLockdown() then return nil end

    local header = ObjectiveTrackerFrame.Header
    local button = CreateFrame("Button", nil, header)
    button:SetSize(18, 19)

    button:SetPoint("RIGHT", header.MinimizeButton or header, "LEFT", -4, 0)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 19)
    icon:SetPoint("CENTER")
    icon:SetAtlas("ui-questtrackerbutton-filter", false)
    button.icon = icon

    button:SetScript("OnMouseDown", function(self)
        if self.icon then
            self.icon:SetAtlas("ui-questtrackerbutton-filter-pressed", true)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        if self.icon then
            self.icon:SetAtlas("ui-questtrackerbutton-filter", true)
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Quest Filter", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        local dropFrame = ns.EnsureFilterDropdown()
        if not dropFrame then return end
        if dropFrame:IsShown() then
            dropFrame:Hide()
            if state.filterDropCloseListener then
                state.filterDropCloseListener:Hide()
            end
        else
            UpdateTypeChecks()
            UpdateSortChecks()
            UpdateDirectionChecks()
            UpdateZoneDirectionChecks()
            UpdateDirectionButtonsEnabled()
            UpdateGroupByZoneCheck()
            UpdateShowTrivialCheck()
            dropFrame:Show()
            if state.filterDropCloseListener then
                state.filterDropCloseListener:Show()
            end
        end
    end)


    state.filterButton = button
    return button
end

ns.RefreshFilterButton = function()
    local button = ns.EnsureFilterButton()
    if not button then
        return
    end

    local shouldShow = IsFilterButtonEnabled()
        and IsModuleEnabled()
        and ObjectiveTrackerFrame
        and ObjectiveTrackerFrame.Header
        and ObjectiveTrackerFrame.Header:IsShown()
    if InCombatLockdown() then return end
    button:SetShown(shouldShow)
    UpdateFilterResetState()

    -- Re-anchor in case the tracker button visibility changed.
    button:ClearAllPoints()
    local anchorTo = ObjectiveTrackerFrame.Header.MinimizeButton or ObjectiveTrackerFrame.Header
    button:SetPoint("RIGHT", anchorTo, "LEFT", -4, 0)
end

end -- do: EnsureFilterButton / EnsureFilterDropdown

do -- ShouldFilterQuest (scoped to stay under 200-local chunk limit)

---@param questID number
---@param quest table|nil
---@return boolean shouldHide true if the quest should be filtered out
ns.ShouldFilterQuest = function(questID, quest)
    if not IsModuleEnabled() then
        return false
    end

    local settings = GetSettings()
    settings.filter = settings.filter or {}
    local filterSettings = settings.filter
    local questTypes = filterSettings.questTypes or {}
    local searchText = state.searchText

    -- Classify quest into a type key (priority matches the title color system).
    local typeKey
    local isTrivial = IsTrivialQuest(questID)
    if IsPreyQuest(questID) then
        typeKey = "prey"
    else
        local recurring = GetRecurringQuestType(questID)
        if recurring then
            typeKey = recurring -- "daily" or "weekly"
        else
            local classification = GetQuestClassification(questID, quest)
            if classification and Enum and Enum.QuestClassification then
                if classification == Enum.QuestClassification.Meta then
                    typeKey = "meta"
                elseif classification == Enum.QuestClassification.Legendary then
                    typeKey = "legendary"
                elseif classification == Enum.QuestClassification.Campaign then
                    typeKey = "campaign"
                elseif classification == Enum.QuestClassification.Important then
                    typeKey = "important"
                end
            end
            if not typeKey then
                local kind = GetQuestKind(questID, quest)
                if kind == "campaign" then
                    typeKey = "campaign"
                elseif kind == "worldQuest" then
                    typeKey = "worldQuest"
                elseif kind == "bonusObjective" then
                    typeKey = "bonusObjective"
                else
                    typeKey = "regular"
                end
            end
        end
    end

    -- (a) Quest type exclusion filter.
    if typeKey and questTypes[typeKey] then
        return true
    end

    -- (a2) Trivial filter (independent of type classification).
    if isTrivial and filterSettings.showTrivial == false then
        return true
    end

    -- (b) Search text filter.
    if searchText and searchText ~= "" then
        local title = GetQuestHeaderTitle(questID)
        if title and title:lower():find(searchText, 1, true) then
            return false
        end

        local label = K.FILTER_QUEST_TYPE_LABELS[typeKey]
        if label and label:lower():find(searchText, 1, true) then
            return false
        end

        if isTrivial and ("trivial"):find(searchText, 1, true) then
            return false
        end

        if GetQuestObjectiveInfo then
            for i = 1, 10 do
                local text = GetQuestObjectiveInfo(questID, i, false)
                if not text then break end
                if text:lower():find(searchText, 1, true) then
                    return false
                end
            end
        end

        -- Zone name match
        do
            local mapID = C_TaskQuest and C_TaskQuest.GetQuestZoneID and C_TaskQuest.GetQuestZoneID(questID) or nil
            if not mapID or mapID == 0 then
                mapID = GetQuestUiMapID and GetQuestUiMapID(questID, true) or nil
            end
            if mapID and mapID ~= 0 then
                local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID) or nil
                local zoneName = mapInfo and mapInfo.name or nil
                if zoneName and zoneName:lower():find(searchText, 1, true) then
                    return false
                end
            end
        end

        return true
    end

    return false
end

end -- do: ShouldFilterQuest

local function InstallTrackerHooks()
    if state.trackerHooksInstalled or not QuestObjectiveTrackerMixin or not CampaignQuestObjectiveTrackerMixin or not WorldQuestObjectiveTrackerMixin or not BonusObjectiveTrackerMixin then

        return
    end

    state.trackerHooksInstalled = true

    state.originalQuestShouldDisplayQuest = QuestObjectiveTrackerMixin.ShouldDisplayQuest
    QuestObjectiveTrackerMixin.ShouldDisplayQuest = function(self, quest)
        local shouldDisplay = state.originalQuestShouldDisplayQuest and state.originalQuestShouldDisplayQuest(self, quest)
        if not shouldDisplay then
            return false
        end

        if not IsModuleEnabled() then
            return true
        end

        local questID = quest:GetID()
        if IsZoneEligibleQuest(questID, "quest") then return false end
        if ns.ShouldFilterQuest(questID, quest) then return false end
        return true
    end
    if QuestObjectiveTracker then
        QuestObjectiveTracker.ShouldDisplayQuest = QuestObjectiveTrackerMixin.ShouldDisplayQuest
    end

    state.originalCampaignShouldDisplayQuest = CampaignQuestObjectiveTrackerMixin.ShouldDisplayQuest
    CampaignQuestObjectiveTrackerMixin.ShouldDisplayQuest = function(self, quest)
        local shouldDisplay = state.originalCampaignShouldDisplayQuest and state.originalCampaignShouldDisplayQuest(self, quest)
        if not shouldDisplay then
            return false
        end

        if not IsModuleEnabled() then
            return true
        end

        local questID = quest:GetID()
        if IsZoneEligibleQuest(questID, "campaign") then return false end
        if ns.ShouldFilterQuest(questID, quest) then return false end
        return true
    end
    if CampaignQuestObjectiveTracker then
        CampaignQuestObjectiveTracker.ShouldDisplayQuest = CampaignQuestObjectiveTrackerMixin.ShouldDisplayQuest
    end

    state.originalBonusAddQuest = BonusObjectiveTrackerMixin.AddQuest
    BonusObjectiveTrackerMixin.AddQuest = function(self, questID, isTrackedWorldQuest)
        if self == BonusObjectiveTracker and IsModuleEnabled() then
            if IsZoneEligibleQuest(questID, "bonusObjective") then return true end
            if ns.ShouldFilterQuest(questID) then return true end
        end

        return state.originalBonusAddQuest(self, questID, isTrackedWorldQuest)
    end
    if BonusObjectiveTracker then
        BonusObjectiveTracker.AddQuest = BonusObjectiveTrackerMixin.AddQuest
    end

    -- WorldQuestObjectiveTrackerMixin is built with CreateFromMixins which copies
    -- AddQuest at mixin time, so overriding BonusObjectiveTrackerMixin.AddQuest above
    -- has no effect on it. Hook it directly so zone-eligible world quests are filtered
    -- out of the stock world-quest section and shown only in NomTools's zone section.
    state.originalWorldQuestAddQuest = WorldQuestObjectiveTrackerMixin.AddQuest
    WorldQuestObjectiveTrackerMixin.AddQuest = function(self, questID, isTrackedWorldQuest)
        if IsModuleEnabled() then
            -- For tracked world quests use the map-based eligibility check so that
            -- zone-eligible quests are suppressed from Blizzard's section at the same
            -- moment the NomTools zone section would display them (immediately on zone
            -- entry, without waiting for the server isInArea flag to propagate).
            local eligibleType = isTrackedWorldQuest and "trackedWorldQuest" or "worldQuest"
            if IsZoneEligibleQuest(questID, eligibleType) then
                return true
            end
            if ns.ShouldFilterQuest(questID) then
                return true
            end
        end
        return state.originalWorldQuestAddQuest(self, questID, isTrackedWorldQuest)
    end
    if WorldQuestObjectiveTracker then
        WorldQuestObjectiveTracker.AddQuest = WorldQuestObjectiveTrackerMixin.AddQuest
    end
end

local function moduleOrderComparator(left, right)
    return (left.uiOrder or math.huge) < (right.uiOrder or math.huge)
end

local cachedContainerModules = {}
local cachedContainerModulesTime = -1

local function GetOrderedContainerModules()
    local now = GetTime()
    if now == cachedContainerModulesTime then
        return cachedContainerModules
    end
    cachedContainerModulesTime = now

    local modules = cachedContainerModules
    for k in pairs(modules) do modules[k] = nil end

    if not ObjectiveTrackerFrame or type(ObjectiveTrackerFrame.modules) ~= "table" then
        return modules
    end

    for _, module in ipairs(ObjectiveTrackerFrame.modules) do
        modules[#modules + 1] = module
    end

    if state.searchFrame and state.searchFrame.uiOrder then
        modules[#modules + 1] = state.searchFrame
    end

    table.sort(modules, moduleOrderComparator)

    return modules
end

local function BuildOrderedModules(includeCustomModules)
    local modules = {}
    local seen = {}
    local order = GetNormalizedOrder(GetSettings().order)

    for _, key in ipairs(order) do
        local includeKey = ((key ~= "zone" and key ~= "focusedQuest" and key ~= "search") or includeCustomModules)
            and (key ~= "focusedQuest" or IsFocusedQuestEnabled())
            and (key ~= "search" or IsSearchEnabled())
        if includeKey then
            if key == "search" then
                ns.EnsureSearchFrame()
            end
            local module = GetModuleByKey(key)
            if module and not seen[module] then
                modules[#modules + 1] = module
                seen[module] = true
            end
        end
    end

    for _, key in ipairs(K.DEFAULT_ORDER) do
        local includeKey = ((key ~= "zone" and key ~= "focusedQuest" and key ~= "search") or includeCustomModules)
            and (key ~= "focusedQuest" or IsFocusedQuestEnabled())
            and (key ~= "search" or IsSearchEnabled())
        if includeKey then
            if key == "search" then
                ns.EnsureSearchFrame()
            end
            local module = GetModuleByKey(key)
            if module and not seen[module] then
                modules[#modules + 1] = module
                seen[module] = true
            end
        end
    end

    return modules
end

local function ApplyCategoryOrder()
    if not ObjectiveTrackerFrame or not ObjectiveTrackerManager then
        return
    end

    if next(state.originalModuleOrders) == nil and type(ObjectiveTrackerFrame.modules) == "table" then
        for _, module in ipairs(ObjectiveTrackerFrame.modules) do
            state.originalModuleOrders[module] = module and module.uiOrder or nil
        end
    end

    local orderedModules = BuildOrderedModules(IsModuleEnabled())
    if #orderedModules == 0 then
        return
    end

    ObjectiveTrackerManager:AssignModulesOrder(orderedModules)
    ObjectiveTrackerFrame.needsSorting = true
end

local function RestoreOriginalModuleOrder()
    if not ObjectiveTrackerFrame or next(state.originalModuleOrders) == nil then
        return
    end

    for module, uiOrder in pairs(state.originalModuleOrders) do
        if module then
            module.uiOrder = uiOrder
        end
    end

    ObjectiveTrackerFrame.needsSorting = true
end

local function RefreshLayoutCallback()
    state.layoutRefreshPending = false
    if ObjectiveTrackerManager and ObjectiveTrackerManager.UpdateAll then
        ObjectiveTrackerManager:UpdateAll()
    elseif ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
        ObjectiveTrackerFrame:Update()
    end
end

RequestTrackerLayoutRefresh = function()
    if state.layoutRefreshPending then
        return
    end

    if IsModuleEnabled() and IsScrollEnabled() then
        state.needsExpandedLayoutPass = true
    end

    state.layoutRefreshPending = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, RefreshLayoutCallback)
    else
        RefreshLayoutCallback()
    end
end

local function GetDesiredRightInset(shouldScroll)
    return 0
end

local function GetExpandedLayoutBudget(availableHeight)
    local normalizedAvailableHeight = math.max(0, math.floor((tonumber(availableHeight) or 0) + 0.5))
    local budget = math.max(normalizedAvailableHeight, state.layoutHeightBudget or 0)

    if budget <= 0 then
        budget = math.max(normalizedAvailableHeight * 2, K.TRACKER_LAYOUT_INITIAL_BUDGET)
    end

    if state.lastContentHeight and state.lastContentHeight > 0 then
        budget = math.max(budget, math.floor(state.lastContentHeight + K.TRACKER_LAYOUT_BUDGET_PADDING + 0.5))
    end

    return math.min(K.TRACKER_MAX_LAYOUT_HEIGHT, budget)
end

local function UpdateLayoutHeightBudget(visibleHeight, contentHeight)
    local normalizedVisibleHeight = math.max(0, math.floor((tonumber(visibleHeight) or 0) + 0.5))
    local normalizedContentHeight = math.max(0, math.floor((tonumber(contentHeight) or 0) + 0.5))
    local padding = math.max(K.TRACKER_LAYOUT_BUDGET_PADDING, normalizedVisibleHeight)
    local currentBudget = math.max(normalizedVisibleHeight, state.layoutHeightBudget or 0)
    local desiredBudget = math.min(
        K.TRACKER_MAX_LAYOUT_HEIGHT,
        math.max(normalizedVisibleHeight, normalizedContentHeight + padding)
    )

    if currentBudget <= 0 then
        currentBudget = math.max(normalizedVisibleHeight * 2, K.TRACKER_LAYOUT_INITIAL_BUDGET)
    end

    local contentNearBudgetLimit = normalizedContentHeight >= math.max(0, currentBudget - math.floor(padding * 0.5))
    if contentNearBudgetLimit and currentBudget < K.TRACKER_MAX_LAYOUT_HEIGHT then
        local grownBudget = math.min(
            K.TRACKER_MAX_LAYOUT_HEIGHT,
            math.max(desiredBudget, currentBudget * 2, K.TRACKER_LAYOUT_INITIAL_BUDGET)
        )
        if grownBudget > currentBudget then
            state.layoutHeightBudget = grownBudget
            state.needsExpandedLayoutPass = true
            return true
        end
    end

    state.layoutHeightBudget = desiredBudget
    state.needsExpandedLayoutPass = false
    return false
end

local function GetTrackerFrameWidth()
    if not ObjectiveTrackerFrame then
        return 0
    end

    -- Do not call GetLeft()/GetRight() here.  When OTF is briefly positioned by
    -- UIParentRightManagedFrameContainer (Blizzard's secure edit-mode managed
    -- container), those methods return "secret" tainted values.  Subtracting them
    -- propagates taint into targetWidth, which then contaminates every module that
    -- receives SetWidth(targetWidth) – including UIWidgetObjectiveTracker whose
    -- UIWidget-managed frames share frame state with the GameTooltip
    -- EmbeddedItemTooltip hierarchy.  A tainted width on those frames causes
    -- "attempt to perform arithmetic on a secret number" failures in Blizzard's
    -- tooltip sizing code when hovering map task POIs.
    -- GetWidth() is safe: NomTools always calls SetWidth() on OTF with a plain
    -- non-secret value (ApplyTrackerDimensions).  In the dual-Minimap-anchor case
    -- GetWidth() returns the anchor-computed rendered width, which is also non-secret.
    return ObjectiveTrackerFrame.GetWidth and ObjectiveTrackerFrame:GetWidth() or 0
end

local function GetTargetModuleWidth(module)
    if not module then
        return 0
    end

    local trackerWidth = GetTrackerFrameWidth()
    if trackerWidth <= 0 then
        return 0
    end

    return math.max(trackerWidth - (module.leftMargin or 0) - (state.currentRightInset or 0), 1)
end

local function PrepareModuleForLayout(module)
    if not module or module.parentContainer ~= ObjectiveTrackerFrame then
        return
    end

    -- UIWidgetObjectiveTracker contains UIWidget-managed frames whose dimensions
    -- feed into Blizzard's EmbeddedItemTooltip/tooltip layout hierarchy.  Setting
    -- SetWidth on those frames with a potentially tainted targetWidth taints the
    -- tooltip chain and causes "secret number" arithmetic failures when map POI
    -- tooltips are shown.  Blizzard sizes this module itself; skip it here.
    if module == UIWidgetObjectiveTracker then
        return
    end

    local targetWidth = GetTargetModuleWidth(module)
    if targetWidth <= 0 then
        return
    end

    if module.SetWidth then
        module:SetWidth(targetWidth)
    end

    local contentsFrame = module.ContentsFrame
    if contentsFrame and contentsFrame.SetWidth then
        local pointCount = contentsFrame.GetNumPoints and contentsFrame:GetNumPoints() or 0
        if pointCount <= 1 then
            contentsFrame:SetWidth(targetWidth)
        end
    end
end

local function PrepareModulesForLayout(container)
    if container ~= ObjectiveTrackerFrame then
        return
    end

    for _, module in ipairs(GetOrderedContainerModules()) do
        PrepareModuleForLayout(module)
    end
end

local function GetModuleEffectiveHeight(module)
    if not module then
        return 0
    end

    if module.IsShown and not module:IsShown() then
        return 0
    end

    local frameHeight = module.GetHeight and module:GetHeight() or 0
    local contentsHeight = module.GetContentsHeight and module:GetContentsHeight() or 0
    local headerHeight = module.headerHeight or 0

    if module.Header and module.Header.IsShown and module.Header:IsShown() and module.Header.GetHeight then
        headerHeight = math.max(headerHeight, module.Header:GetHeight() or 0)
    end

    return math.max(frameHeight or 0, contentsHeight or 0, headerHeight or 0)
end

-- Returns the effective top padding for content modules.  When the main header
-- is disabled by the player we collapse this to zero so there is no gap at the
-- top of the tracker; otherwise we use the actual rendered pixel height of the
-- header frame so the clip frame starts exactly at the header's bottom edge.
local function GetEffectiveTopPadding()
    local header = ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header or nil
    if not header or not header.IsShown or not header:IsShown() then
        return 0
    end
    return (header.GetHeight and header:GetHeight()) or ObjectiveTrackerFrame.topModulePadding or 0
end

local layoutScratch = {}
local layoutEntryPool = {}
local layoutEntryPoolUsed = 0

local function BuildVisibleModuleLayout()
    local layout = layoutScratch
    for k in pairs(layout) do layout[k] = nil end
    layoutEntryPoolUsed = 0
    if not ObjectiveTrackerFrame then
        return layout, 0
    end

    local topPadding = GetEffectiveTopPadding()
    local bottomPadding = ObjectiveTrackerFrame.bottomModulePadding or 0
    local moduleSpacing = ObjectiveTrackerFrame.moduleSpacing or 0
    local contentHeight = topPadding
    local hasVisibleModules = false

    local prevModuleInHeight
    for _, module in ipairs(GetOrderedContainerModules()) do
        local moduleHeight = GetModuleEffectiveHeight(module)
        if moduleHeight > 0 then
            if hasVisibleModules then
                local prevCollapsed = prevModuleInHeight and prevModuleInHeight.IsCollapsed and prevModuleInHeight:IsCollapsed()
                local spacingY = (module.nomtoolsSearchFrame or (prevModuleInHeight and prevModuleInHeight.nomtoolsSearchFrame) or prevCollapsed) and 0 or moduleSpacing
                contentHeight = contentHeight + spacingY
            end

            local top = contentHeight
            local bottom = top + moduleHeight
            layoutEntryPoolUsed = layoutEntryPoolUsed + 1
            local entry = layoutEntryPool[layoutEntryPoolUsed]
            if not entry then
                entry = {}
                layoutEntryPool[layoutEntryPoolUsed] = entry
            end
            entry.module = module
            entry.top = top
            entry.bottom = bottom
            entry.height = moduleHeight
            layout[#layout + 1] = entry

            contentHeight = bottom
            hasVisibleModules = true
            prevModuleInHeight = module
        end
    end

    if hasVisibleModules then
        contentHeight = contentHeight + bottomPadding
    end

    return layout, contentHeight
end

local function ClampScrollAnchorOffset(moduleHeight, offset)
    local normalizedHeight = math.max(0, math.floor((tonumber(moduleHeight) or 0) + 0.5))
    local maxOffset = 0
    if normalizedHeight > 0 then
        maxOffset = normalizedHeight - 1
    end

    local normalizedOffset = math.floor((tonumber(offset) or 0) + 0.5)
    if normalizedOffset < 0 then
        return 0
    end

    if normalizedOffset > maxOffset then
        return maxOffset
    end

    return normalizedOffset
end

local function CaptureScrollAnchor()
    if not IsModuleEnabled() or not IsScrollEnabled() then
        return nil
    end

    local layout = BuildVisibleModuleLayout()
    if #layout == 0 then
        return nil
    end

    local scrollOffset = state.scrollOffset or 0
    local anchor = layout[#layout]
    local offset = ClampScrollAnchorOffset(anchor and anchor.height or 0, scrollOffset - (anchor and anchor.top or 0))

    for _, entry in ipairs(layout) do
        if scrollOffset < entry.top then
            anchor = entry
            offset = 0
            break
        end

        anchor = entry
        if scrollOffset < entry.bottom then
            offset = ClampScrollAnchorOffset(entry.height, scrollOffset - entry.top)
            break
        end

        offset = ClampScrollAnchorOffset(entry.height, scrollOffset - entry.top)
    end

    return {
        module = anchor.module,
        offset = offset,
    }
end

local function RestorePendingScrollAnchor()
    local anchor = state.pendingScrollAnchor
    if not anchor then
        return
    end

    state.pendingScrollAnchor = nil

    if not anchor.module then
        return
    end

    local layout = BuildVisibleModuleLayout()
    for _, entry in ipairs(layout) do
        if entry.module == anchor.module then
            local offset = ClampScrollAnchorOffset(entry.height, anchor.offset)

            state.scrollOffset = math.max(0, math.floor((entry.top + offset) + 0.5))
            return
        end
    end
end

local function EnsureScrollClipFrame()
    if state.scrollClipFrame or not ObjectiveTrackerFrame then
        return state.scrollClipFrame
    end

    local clipFrame = CreateFrame("Frame", addonName .. "ObjectiveTrackerScrollClipFrame", ObjectiveTrackerFrame)
    clipFrame:SetClipsChildren(true)
    state.scrollClipFrame = clipFrame
    return clipFrame
end

local function RefreshScrollClipFrame()
    local clipFrame = EnsureScrollClipFrame()
    if not clipFrame or not ObjectiveTrackerFrame then
        return nil
    end

    local trackerFrameLevel = ObjectiveTrackerFrame:GetFrameLevel() or 0
    local nineSliceFrameLevel = ObjectiveTrackerFrame.NineSlice and ObjectiveTrackerFrame.NineSlice:GetFrameLevel() or trackerFrameLevel
    local contentFrameLevel = math.max(trackerFrameLevel, nineSliceFrameLevel) + 1
    local topPadding = GetEffectiveTopPadding()
    clipFrame:SetFrameStrata(ObjectiveTrackerFrame:GetFrameStrata())
    clipFrame:SetFrameLevel(contentFrameLevel)
    clipFrame:ClearAllPoints()
    clipFrame:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT", -TRACKER_SCROLL_CLIP_LEFT_PADDING, -topPadding)
    clipFrame:SetPoint("BOTTOMRIGHT", ObjectiveTrackerFrame, "BOTTOMRIGHT", TRACKER_MODULE_HEADER_RIGHT_EXTENSION, 0)
    clipFrame:SetShown(IsModuleEnabled())
    clipFrame:SetClipsChildren(IsModuleEnabled())
    return clipFrame
end

local function RestoreBlizzardModuleAnchors(clearPoints)
    if not ObjectiveTrackerFrame or type(ObjectiveTrackerFrame.modules) ~= "table" then
        return
    end

    for _, module in ipairs(ObjectiveTrackerFrame.modules) do
        if module and module.parentContainer == ObjectiveTrackerFrame then
            if module:GetParent() ~= ObjectiveTrackerFrame then
                module:SetParent(ObjectiveTrackerFrame)
            end
            if clearPoints and module.ClearAllPoints then
                module:ClearAllPoints()
            end
        end
    end
end

local function ApplyModuleAnchors()
    if not ObjectiveTrackerFrame then
        return
    end

    if not IsModuleEnabled() then
        return
    end

    local clipFrame = RefreshScrollClipFrame()
    if not clipFrame then
        return
    end

    local previousModule
    local bottomModulePadding = ObjectiveTrackerFrame.bottomModulePadding or 0
    local moduleSpacing = ObjectiveTrackerFrame.moduleSpacing or 0
    local moduleFrameLevel = (clipFrame:GetFrameLevel() or 0) + 1

    for _, module in ipairs(GetOrderedContainerModules()) do
        local isSearch = module.nomtoolsSearchFrame
        local moduleHeight = isSearch and K.SEARCH_FRAME_HEIGHT or GetModuleEffectiveHeight(module)
        if moduleHeight > 0 and (not isSearch or IsSearchEnabled()) then
            if module:GetParent() ~= clipFrame then
                module:SetParent(clipFrame)
            end
            if module.SetFrameStrata and module:GetFrameStrata() ~= clipFrame:GetFrameStrata() then
                module:SetFrameStrata(clipFrame:GetFrameStrata())
            end
            if module.SetFrameLevel and (module:GetFrameLevel() or 0) < moduleFrameLevel then
                module:SetFrameLevel(moduleFrameLevel)
            end

            if not isSearch then
                PrepareModuleForLayout(module)
            end

            module:ClearAllPoints()
            local leftMargin = module.leftMargin or 0
            local rightInset = state.currentRightInset or 0
            if previousModule then
                local previousLeftMargin = previousModule.leftMargin or 0
                local prevCollapsed = previousModule.IsCollapsed and previousModule:IsCollapsed()
                local spacingY = (isSearch or (previousModule and previousModule.nomtoolsSearchFrame) or prevCollapsed) and 0 or moduleSpacing
                module:SetPoint("TOPLEFT", previousModule, "BOTTOMLEFT", leftMargin - previousLeftMargin, -spacingY)
                module:SetPoint("TOPRIGHT", previousModule, "BOTTOMRIGHT", 0, -spacingY)
            else
                module:SetPoint("TOPLEFT", clipFrame, "TOPLEFT", TRACKER_SCROLL_CLIP_LEFT_PADDING + leftMargin, state.scrollOffset or 0)
                module:SetPoint("TOPRIGHT", clipFrame, "TOPRIGHT", -rightInset - TRACKER_MODULE_HEADER_RIGHT_EXTENSION, state.scrollOffset or 0)
            end

            if isSearch then
                module:Show()
            end

            previousModule = module
        elseif isSearch then
            module:Hide()
        end
    end

    if ObjectiveTrackerFrame.NineSlice then
        if state.scrollActive and clipFrame then
            ObjectiveTrackerFrame.NineSlice:SetPoint("BOTTOM", clipFrame, "BOTTOM", 0, 0)
        elseif previousModule then
            ObjectiveTrackerFrame.NineSlice:SetPoint("BOTTOM", previousModule, "BOTTOM", 0, -bottomModulePadding)
        else
            ObjectiveTrackerFrame.NineSlice:SetPoint("BOTTOM", ObjectiveTrackerFrame, "BOTTOM", 0, 0)
        end
    end
end

do -- SortModuleBlocks (scoped to avoid the 200-local-per-chunk limit)

local SORTABLE_MODULE_KEYS = {
    quest = true,
    campaign = true,
    zone = true,
    focusedQuest = true,
    bonusObjective = true,
    worldQuest = true,
}

local sortScratch = {}
local sortPassID = 0

local function GetZoneDividerSettings()
    local settings = GetSettings()
    return settings and settings.zoneDivider or {}
end

local function GetSearchBarSettings()
    local settings = GetSettings()
    return settings and settings.search or {}
end

---@param questID number
---@return string
local function GetQuestZoneName(questID)
    if type(questID) ~= "number" then
        return ""
    end
    local mapID = C_TaskQuest and C_TaskQuest.GetQuestZoneID and C_TaskQuest.GetQuestZoneID(questID) or nil
    if not mapID or mapID == 0 then
        mapID = GetQuestUiMapID and GetQuestUiMapID(questID, true) or nil
    end
    if not mapID or mapID == 0 then
        return ""
    end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID) or nil
    return info and info.name or ""
end

---@param block table
---@return table
local function GetBlockSortData(block)
    local cached = block.nomtoolsSortData
    if cached and cached.passID == sortPassID then
        return cached
    end
    if not cached then
        cached = {}
        block.nomtoolsSortData = cached
    end
    cached.passID = sortPassID
    cached.block = block
    local questID = block.id or block.questID or block.poiQuestID or 0
    cached.questID = questID
    cached.title = (block.HeaderText and block.HeaderText.GetText and block.HeaderText:GetText()) or GetQuestHeaderTitle(questID) or ""
    cached.zoneName = GetQuestZoneName(questID)
    return cached
end

local function AcquireZoneDivider(module, index)
    local pool = module.nomtoolsZoneDividers
    if not pool then
        pool = {}
        module.nomtoolsZoneDividers = pool
    end
    local divider = pool[index]
    if divider then
        divider:Show()
        return divider
    end
    local parent = module.ContentsFrame or module
    divider = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)

    local label = divider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    divider.label = label

    local lineLeft = divider:CreateTexture(nil, "ARTWORK")
    divider.lineLeft = lineLeft

    local lineRight = divider:CreateTexture(nil, "ARTWORK")
    divider.lineRight = lineRight

    -- Pre-allocate reusable backdrop tables (zero allocation on subsequent calls)
    divider.nomtoolsBackdrop = { bgFile = nil }
    divider.nomtoolsBackdropInsets = { left = 0, right = 0, top = 0, bottom = 0 }

    pool[index] = divider
    return divider
end

---@param divider table
local function ApplyZoneDividerSettings(divider)
    local zdSettings = GetZoneDividerSettings()

    -- Height
    divider:SetHeight(zdSettings.height or 20)

    -- Background
    if divider.SetBackdrop then
        if zdSettings.showBackground == true then
            local bgTextureKey = zdSettings.backgroundTexture
            local bgTexture = ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(bgTextureKey) or "Interface\\Buttons\\WHITE8x8"
            local borderTextureKey = zdSettings.borderTexture
            local borderSize = zdSettings.borderSize or 1

            local backdrop = divider.nomtoolsBackdrop
            backdrop.bgFile = bgTexture
            backdrop.edgeFile = nil
            backdrop.edgeSize = nil
            backdrop.insets = nil

            if borderTextureKey and borderTextureKey ~= "none" then
                local borderPath = ns.GetBorderTexturePath and ns.GetBorderTexturePath(borderTextureKey) or borderTextureKey
                backdrop.edgeFile = borderPath
                backdrop.edgeSize = math.max(borderSize, 1)
                local insets = divider.nomtoolsBackdropInsets
                insets.left = borderSize
                insets.right = borderSize
                insets.top = borderSize
                insets.bottom = borderSize
                backdrop.insets = insets
            end
            divider:SetBackdrop(nil)
            divider:SetBackdrop(backdrop)

            local bgColor = zdSettings.backgroundColor or K.DEFAULT_ZONE_DIVIDER_BG_COLOR
            divider:SetBackdropColor(bgColor.r or 0.05, bgColor.g or 0.05, bgColor.b or 0.05, bgColor.a or 0.6)

            if backdrop.edgeFile then
                local borderColor = zdSettings.borderColor or K.DEFAULT_ZONE_DIVIDER_BORDER_COLOR
                divider:SetBackdropBorderColor(borderColor.r or 0.3, borderColor.g or 0.3, borderColor.b or 0.3, borderColor.a or 1)
            end
        else
            divider:SetBackdrop(nil)
        end
    end

    -- Label font
    local label = divider.label
    if label then
        local fontPath = ns.GetFontPath and ns.GetFontPath(zdSettings.font) or STANDARD_TEXT_FONT
        local fontSize = zdSettings.fontSize or 12
        local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(zdSettings.fontOutline) or ""

        if fontPath then
            label:SetFont(fontPath, fontSize, fontOutline)
        else
            local existingFont, _, existingFlags = label:GetFont()
            if existingFont then
                label:SetFont(existingFont, fontSize, fontOutline ~= "" and fontOutline or existingFlags or "")
            end
        end

        local textColor = zdSettings.textColor or K.DEFAULT_ZONE_DIVIDER_TEXT_COLOR
        label:SetTextColor(textColor.r or 0.8, textColor.g or 0.72, textColor.b or 0.42, textColor.a or 1)
    end

    -- Line styling
    local lineColor = zdSettings.lineColor or K.DEFAULT_ZONE_DIVIDER_LINE_COLOR
    local lineThickness = zdSettings.lineThickness or 1

    if divider.lineLeft then
        divider.lineLeft:SetHeight(lineThickness)
        divider.lineLeft:SetColorTexture(lineColor.r or 0.8, lineColor.g or 0.72, lineColor.b or 0.42, lineColor.a or 0.5)
    end
    if divider.lineRight then
        divider.lineRight:SetHeight(lineThickness)
        divider.lineRight:SetColorTexture(lineColor.r or 0.8, lineColor.g or 0.72, lineColor.b or 0.42, lineColor.a or 0.5)
    end
end

local function ApplyDividerStyle(divider, align, showLines, fade)
    local label = divider.label
    local ll = divider.lineLeft
    local lr = divider.lineRight
    local pad = 4
    local gap = 8

    label:ClearAllPoints()
    ll:ClearAllPoints()
    lr:ClearAllPoints()

    if align == "left" then
        label:SetPoint("LEFT", divider, "LEFT", pad, 0)
        ll:Hide()
        if showLines then
            lr:SetPoint("LEFT", label, "RIGHT", gap, 0)
            lr:SetPoint("RIGHT", divider, "RIGHT", -pad, 0)
            lr:Show()
            if fade then
                lr:SetGradient("HORIZONTAL", K.GRADIENT_SOLID, K.GRADIENT_TRANSPARENT)
            else
                lr:SetGradient("HORIZONTAL", K.GRADIENT_SOLID, K.GRADIENT_SOLID)
            end
        else
            lr:Hide()
        end
    elseif align == "right" then
        label:SetPoint("RIGHT", divider, "RIGHT", -pad, 0)
        lr:Hide()
        if showLines then
            ll:SetPoint("LEFT", divider, "LEFT", pad, 0)
            ll:SetPoint("RIGHT", label, "LEFT", -gap, 0)
            ll:Show()
            if fade then
                ll:SetGradient("HORIZONTAL", K.GRADIENT_TRANSPARENT, K.GRADIENT_SOLID)
            else
                ll:SetGradient("HORIZONTAL", K.GRADIENT_SOLID, K.GRADIENT_SOLID)
            end
        else
            ll:Hide()
        end
    else -- "center"
        label:SetPoint("CENTER", divider, "CENTER", 0, 0)
        if showLines then
            ll:SetPoint("LEFT", divider, "LEFT", pad, 0)
            ll:SetPoint("RIGHT", label, "LEFT", -gap, 0)
            ll:Show()
            lr:SetPoint("LEFT", label, "RIGHT", gap, 0)
            lr:SetPoint("RIGHT", divider, "RIGHT", -pad, 0)
            lr:Show()
            if fade then
                ll:SetGradient("HORIZONTAL", K.GRADIENT_TRANSPARENT, K.GRADIENT_SOLID)
                lr:SetGradient("HORIZONTAL", K.GRADIENT_SOLID, K.GRADIENT_TRANSPARENT)
            else
                ll:SetGradient("HORIZONTAL", K.GRADIENT_SOLID, K.GRADIENT_SOLID)
                lr:SetGradient("HORIZONTAL", K.GRADIENT_SOLID, K.GRADIENT_SOLID)
            end
        else
            ll:Hide()
            lr:Hide()
        end
    end
end

local function ApplySearchBarSettings(searchFrame)
    if not searchFrame then return end
    local settings = GetSearchBarSettings()
    local trackerSettings = GetSettings()
    local useCustom = trackerSettings and trackerSettings.appearance and trackerSettings.appearance.preset == "nomtools"

    -- Height
    searchFrame:SetHeight(settings.height or 16)

    local editBox = searchFrame.editBox or state.searchEditBox
    local placeholder = searchFrame.placeholder or (editBox and editBox.placeholder)
    local bg = searchFrame.bg
    local borderFrame = searchFrame.borderFrame

    if not useCustom then
        -- Native Blizzard look: show InputBoxTemplate chrome, hide custom bg/border
        if editBox then
            if editBox.Left   then editBox.Left:Show()   end
            if editBox.Right  then editBox.Right:Show()  end
            if editBox.Middle then editBox.Middle:Show() end
            editBox:ClearAllPoints()
            editBox:SetPoint("TOPLEFT",     searchFrame, "TOPLEFT",     12, 0)
            editBox:SetPoint("BOTTOMRIGHT", searchFrame, "BOTTOMRIGHT", -5, 0)
        end
        if bg then bg:Hide() end
        if borderFrame then borderFrame:Hide() end

        -- Reset to standard Blizzard font/color
        if editBox then
            editBox:SetFontObject(GameFontHighlightSmall)
            editBox:SetTextColor(1, 1, 1, 1)
        end
        if placeholder then
            placeholder:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    else
        -- Custom preset: hide InputBoxTemplate chrome, use custom bg/border/font
        if editBox then
            if editBox.Left   then editBox.Left:Hide()   end
            if editBox.Right  then editBox.Right:Hide()  end
            if editBox.Middle then editBox.Middle:Hide() end
            editBox:ClearAllPoints()
            editBox:SetPoint("TOPLEFT",     searchFrame, "TOPLEFT",     8, 0)
            editBox:SetPoint("BOTTOMRIGHT", searchFrame, "BOTTOMRIGHT", -8, 0)
        end

        -- Background texture
        if bg then
            if settings.showBackground ~= false then
                local bgTextureKey = settings.backgroundTexture
                if ns.GetStatusBarTexturePath then
                    local texturePath = ns.GetStatusBarTexturePath(bgTextureKey)
                    if texturePath then
                        styleHelpers.ApplyTexturePath(bg, texturePath)
                    else
                        bg:SetColorTexture(0, 0, 0, 1)
                    end
                else
                    bg:SetColorTexture(0, 0, 0, 1)
                end
                local bgColor = settings.backgroundColor or { r = 0, g = 0, b = 0, a = 0.1 }
                styleHelpers.ApplyRegionColor(bg, bgColor)
                bg:ClearAllPoints()
                bg:SetPoint("TOPLEFT", searchFrame, "TOPLEFT", -K.TRACKER_VISUAL_LEFT_EXTENSION, 0)
                bg:SetPoint("BOTTOMRIGHT", searchFrame, "BOTTOMRIGHT", 0, 0)
                bg:Show()
            else
                bg:Hide()
            end
        end

        -- Border via canonical helper
        if borderFrame then
            local borderColor = settings.borderColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
            local _, borderThickness = styleHelpers.ApplyBackdropBorder(
                borderFrame,
                searchFrame,
                settings.borderSize,
                settings.borderTexture,
                borderColor,
                -K.TRACKER_VISUAL_LEFT_EXTENSION, 0
            )
            if borderThickness == 0 then
                borderFrame:Hide()
            end
        end

        -- Font for edit box
        if editBox and editBox.SetFont then
            local fontPath = ns.GetFontPath and ns.GetFontPath(settings.font) or nil
            local fontSize = settings.fontSize or 11
            local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(settings.fontOutline) or ""
            if fontPath then
                editBox:SetFont(fontPath, fontSize, fontOutline)
            end

            local textColor = settings.textColor or { r = 1, g = 1, b = 1, a = 1 }
            editBox:SetTextColor(textColor.r or 1, textColor.g or 1, textColor.b or 1, textColor.a or 1)
        end

        -- Placeholder font
        if placeholder then
            local fontPath = ns.GetFontPath and ns.GetFontPath(settings.font) or nil
            local fontSize = settings.fontSize or 11
            local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(settings.fontOutline) or ""
            if fontPath then
                placeholder:SetFont(fontPath, fontSize, fontOutline)
            end

            local phColor = settings.placeholderColor or { r = 0.5, g = 0.5, b = 0.5, a = 1 }
            placeholder:SetTextColor(phColor.r or 0.5, phColor.g or 0.5, phColor.b or 0.5, phColor.a or 1)
        end
    end
end

local function HideAllZoneDividers(module)
    local pool = module.nomtoolsZoneDividers
    if not pool then
        return
    end
    for i = 1, #pool do
        pool[i]:Hide()
    end
end

local compareSortBy, compareGroupByZone, compareQuestDescMul, compareZoneDescMul

local function blockComparator(a, b)
    local da = GetBlockSortData(a)
    local db = GetBlockSortData(b)

    if compareGroupByZone then
        local za, zb = da.zoneName, db.zoneName
        if za ~= zb then
            if za < zb then return compareZoneDescMul == 1 end
            return compareZoneDescMul ~= 1
        end
    end

    if compareSortBy == "name" then
        local ta, tb = da.title or "", db.title or ""
        if ta ~= tb then
            if ta < tb then return compareQuestDescMul == 1 end
            return compareQuestDescMul ~= 1
        end
        return da.origIndex < db.origIndex
    end

    return da.origIndex < db.origIndex
end

---@param module table
---@return boolean heightChanged  true if the module's height was updated
ns.SortModuleBlocks = function(module)
    if not module then
        return false
    end

    local moduleKey = GetKeyForModule(module)
    if not moduleKey or not SORTABLE_MODULE_KEYS[moduleKey] then
        return false
    end

    local filterSettings = GetSettings().filter or {}
    local sortBy = filterSettings.sortBy or "default"
    local sortDirection = filterSettings.sortDirection or "asc"
    local groupByZone = filterSettings.groupByZone == true

    if sortBy == "default" and not groupByZone then
        HideAllZoneDividers(module)
        return false
    end

    -- Collect visible blocks
    local scratch = sortScratch
    local count = 0
    if module.EnumerateActiveBlocks then
        module:EnumerateActiveBlocks(function(block)
            if block and (not block.IsShown or block:IsShown()) and block.GetHeight and block:GetHeight() > 0 then
                count = count + 1
                scratch[count] = block
            end
        end)
    elseif type(module.usedBlocks) == "table" then
        for _, blocksByID in pairs(module.usedBlocks) do
            if type(blocksByID) == "table" then
                for _, block in pairs(blocksByID) do
                    if block and (not block.IsShown or block:IsShown()) and block.GetHeight and block:GetHeight() > 0 then
                        count = count + 1
                        scratch[count] = block
                    end
                end
            end
        end
    end
    -- Clean trailing entries from previous passes
    for i = count + 1, #scratch do
        scratch[i] = nil
    end

    if count <= 1 then
        HideAllZoneDividers(module)
        return false
    end

    -- Cache the original block spacing before any sorting modifies anchors
    local blockSpacingY = module.nomtoolsBlockSpacingY
    if not blockSpacingY then
        -- Try to read from the second block's vertical anchor
        local spacing = nil
        if count >= 2 then
            local secondBlock = scratch[2]
            for i = 1, secondBlock:GetNumPoints() do
                local point, _, relPoint, _, yOfs = secondBlock:GetPoint(i)
                if point == "TOP" or point == "TOPLEFT" then
                    spacing = yOfs
                    break
                end
            end
        end
        blockSpacingY = spacing or -6
        module.nomtoolsBlockSpacingY = blockSpacingY
    end

    -- Bump sort pass and extract sort data
    sortPassID = sortPassID + 1
    -- Record original index for stable sorting
    for i = 1, count do
        local data = GetBlockSortData(scratch[i])
        data.origIndex = i
    end

    compareSortBy = sortBy
    compareGroupByZone = groupByZone
    compareQuestDescMul = (sortDirection == "desc") and -1 or 1
    local zoneSortDir = filterSettings.zoneSortDirection or "asc"
    compareZoneDescMul = (zoneSortDir == "desc") and -1 or 1

    table.sort(scratch, blockComparator)

    local contentsFrame = module.ContentsFrame or module
    local absSpacing = math.abs(blockSpacingY)

    -- Re-anchor blocks in sorted order, inserting zone dividers if needed
    -- and compute the actual total content height
    HideAllZoneDividers(module)
    local zdSettings = GetZoneDividerSettings()
    local dividerIndex = 0
    local previousElement = nil
    local totalHeight = 0

    for i = 1, count do
        local block = scratch[i]
        local data = GetBlockSortData(block)
        local blockHeight = block:GetHeight()

        -- Insert zone divider between groups (or before the first block)
        if groupByZone and data.zoneName ~= "" then
            local needsDivider = false
            if i == 1 then
                needsDivider = true
            else
                local prevData = GetBlockSortData(scratch[i - 1])
                needsDivider = data.zoneName ~= prevData.zoneName
            end
            if needsDivider then
                dividerIndex = dividerIndex + 1
                local divider = AcquireZoneDivider(module, dividerIndex)
                divider.label:SetText(data.zoneName)
                ApplyZoneDividerSettings(divider)
                ApplyDividerStyle(divider, zdSettings.align or "center", zdSettings.showLines ~= false, zdSettings.lineFadeOut ~= false)
                divider:ClearAllPoints()
                if previousElement then
                    divider:SetPoint("TOP", previousElement, "BOTTOM", 0, blockSpacingY)
                    totalHeight = totalHeight + absSpacing
                else
                    divider:SetPoint("TOP", contentsFrame, "TOP", 0, 0)
                end
                -- Match section header width: extend left by scroll clip padding, right by module header extension
                divider:SetPoint("LEFT", -K.TRACKER_VISUAL_LEFT_EXTENSION, 0)
                divider:SetPoint("RIGHT", TRACKER_MODULE_HEADER_RIGHT_EXTENSION, 0)
                totalHeight = totalHeight + divider:GetHeight()
                previousElement = divider
            end
        end

        block:ClearAllPoints()
        -- Vertical positioning
        if previousElement then
            block:SetPoint("TOP", previousElement, "BOTTOM", 0, blockSpacingY)
            totalHeight = totalHeight + absSpacing
        else
            block:SetPoint("TOP", contentsFrame, "TOP", 0, 0)
        end
        -- Horizontal positioning (matching Blizzard's pattern)
        local leftOffset = block.offsetX or module.blockOffsetX or 20
        block:SetPoint("LEFT", leftOffset, 0)
        if not block.fixedWidth then
            block:SetPoint("RIGHT")
        end
        totalHeight = totalHeight + blockHeight
        previousElement = block
    end

    -- Update module height to reflect the re-anchored content
    local oldHeight = module.GetHeight and module:GetHeight() or 0
    local headerHeight = 0
    if module.Header and module.Header.IsShown and module.Header:IsShown() and module.Header.GetHeight then
        headerHeight = module.Header:GetHeight() or 0
    else
        headerHeight = module.headerHeight or 0
    end

    if contentsFrame ~= module and contentsFrame.SetHeight then
        contentsFrame:SetHeight(totalHeight)
    end
    local newModuleHeight = totalHeight + headerHeight
    if module.SetHeight then
        module:SetHeight(newModuleHeight)
    end

    return math.abs(newModuleHeight - oldHeight) > 0.5
end

ns.RefreshZoneDividerAndSearchStyles = function()
    local zdSettings = GetZoneDividerSettings()
    for _, module in ipairs(GetOrderedContainerModules()) do
        local pool = module.nomtoolsZoneDividers
        if pool then
            for i = 1, #pool do
                local divider = pool[i]
                if divider and divider:IsShown() then
                    ApplyZoneDividerSettings(divider)
                    ApplyDividerStyle(divider, zdSettings.align or "center", zdSettings.showLines ~= false, zdSettings.lineFadeOut ~= false)
                end
            end
        end
    end
    ApplySearchBarSettings(state.searchFrame)
end

end -- do: SortModuleBlocks

local function EnsureScrollBar()
    if state.scrollBar or not ObjectiveTrackerFrame then
        return state.scrollBar
    end

    local scrollBar = CreateFrame("Slider", addonName .. "ObjectiveTrackerScrollBar", ObjectiveTrackerFrame)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetObeyStepOnDrag(true)
    scrollBar:SetValueStep(1)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    scrollBar:Hide()

    local background = scrollBar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    scrollBar.background = background

    local thumb = scrollBar:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(DEFAULT_STATUSBAR_TEXTURE_PATH)
    thumb:SetSize(K.SCROLL_BAR_DEFAULT_WIDTH, K.SCROLL_BAR_MIN_THUMB_HEIGHT)
    scrollBar:SetThumbTexture(thumb)
    scrollBar.thumb = thumb

    local borderFrame = CreateFrame("Frame", nil, scrollBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
    borderFrame:SetAllPoints(scrollBar)
    borderFrame:SetFrameLevel((scrollBar:GetFrameLevel() or 0) + 1)
    borderFrame:EnableMouse(false)
    scrollBar.borderFrame = borderFrame

    scrollBar:SetScript("OnValueChanged", function(_, value)
        if state.updatingScrollBar then
            return
        end

        state.scrollOffset = math.floor((value or 0) + 0.5)
        ApplyModuleAnchors()
    end)

    state.scrollBar = scrollBar
    return scrollBar
end

local function RefreshTrackerHeader()
    if not ObjectiveTrackerFrame or not ObjectiveTrackerFrame.Header then
        return
    end

    if not IsModuleEnabled() then
        return
    end

    local header = ObjectiveTrackerFrame.Header
    local shouldShowHeader = ObjectiveTrackerFrame.ShouldShowHeader and ObjectiveTrackerFrame:ShouldShowHeader() or header:IsShown()

    if header.NomToolsTitle then
        header.NomToolsTitle:Hide()
    end

    local title = header.Text or header.Title or header.NomToolsTitle

    ObjectiveTrackerFrame.headerText = K.TRACKER_HEADER_TEXT

    if title then
        title:SetText(K.TRACKER_HEADER_TEXT)
        if title.SetTextColor then
            title:SetTextColor(1, 1, 1, 1)
        end
        -- Hide the title text when the header background is suppressed.
        title:SetShown(shouldShowHeader and IsHeaderTitleShown())
    end

    local clipFrame = state.scrollClipFrame
    if clipFrame then
        local minHeaderLevel = clipFrame:GetFrameLevel() + 2
        header:SetFrameLevel(math.max(header:GetFrameLevel(), minHeaderLevel))
    end

    -- Enforce the header-enabled setting; the hook on Header.Show handles re-shows from
    -- Blizzard, but we also need to act here for both directions of the toggle.
    if IsMainHeaderEnabled() then
        header:SetShown(shouldShowHeader)
    else
        header:Hide()
    end
end

local function RefreshScrollState()
    if not ObjectiveTrackerFrame then
        return
    end

    local scrollBar = EnsureScrollBar()
    if not scrollBar then
        return
    end

    local clipFrame = state.scrollClipFrame
    if clipFrame then
        scrollBar:SetFrameStrata(clipFrame:GetFrameStrata())
        scrollBar:SetFrameLevel((clipFrame:GetFrameLevel() or 0) + 3)
    end

    if not IsModuleEnabled() or not IsScrollEnabled() then
        state.scrollOffset = 0
        state.scrollActive = false
        state.needsExpandedLayoutPass = false
        state.layoutHeightBudget = 0
        state.currentRightInset = 0
        state.lastContentHeight = 0
        if state.scrollClipFrame then
            state.scrollClipFrame:SetShown(false)
            state.scrollClipFrame:SetClipsChildren(false)
        end
        scrollBar:Hide()
        scrollBar:EnableMouse(false)
        scrollBar:GetScript("OnValueChanged")(scrollBar, 0)
        return
    end

    local visibleHeight = ObjectiveTrackerFrame:GetHeight() or 0
    if visibleHeight <= 0 then
        state.scrollActive = false
        scrollBar:Hide()
        scrollBar:EnableMouse(false)
        return
    end

    local layout, contentHeight = BuildVisibleModuleLayout()
    state.lastContentHeight = contentHeight
    local hasVisibleModules = #layout > 0
    local budgetGrew = UpdateLayoutHeightBudget(visibleHeight, contentHeight)

    local maxOffset = math.max(0, math.floor(contentHeight - visibleHeight + 0.5))
    if state.scrollOffset > maxOffset then
        state.scrollOffset = maxOffset
    end

    local shouldScroll = maxOffset > 0
    state.scrollActive = shouldScroll
    local desiredRightInset = GetDesiredRightInset(shouldScroll)
    if state.currentRightInset ~= desiredRightInset then
        state.currentRightInset = desiredRightInset
        RequestTrackerLayoutRefresh()
    end

    if budgetGrew then
        RequestTrackerLayoutRefresh()
    end

    if state.scrollClipFrame then
        state.scrollClipFrame:SetShown(true)
        state.scrollClipFrame:SetClipsChildren(true)
    end

    if not shouldScroll then
        state.scrollOffset = 0
        scrollBar:Hide()
        scrollBar:EnableMouse(false)
        state.updatingScrollBar = true
        scrollBar:SetMinMaxValues(0, 0)
        scrollBar:SetValue(0)
        state.updatingScrollBar = false
        scrollBar:GetScript("OnValueChanged")(scrollBar, 0)
        return
    end

    local scrollSettings = GetScrollBarSettings()
    local scrollBarWidth = GetScrollBarWidth(scrollSettings)
    local scrollBarTexture = ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(scrollSettings.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH
    local rawColor = scrollSettings.color
    local fallbackColor = K.DEFAULT_SCROLL_BAR_COLOR
    local scrollBarR, scrollBarG, scrollBarB, scrollBarA
    if type(rawColor) == "table" then
        scrollBarR = tonumber(rawColor.r or rawColor[1]) or fallbackColor.r
        scrollBarG = tonumber(rawColor.g or rawColor[2]) or fallbackColor.g
        scrollBarB = tonumber(rawColor.b or rawColor[3]) or fallbackColor.b
        scrollBarA = tonumber(rawColor.a or rawColor[4]) or fallbackColor.a
    else
        scrollBarR = fallbackColor.r
        scrollBarG = fallbackColor.g
        scrollBarB = fallbackColor.b
        scrollBarA = fallbackColor.a
    end
    local contentH = state.lastContentHeight or 0
    local frameH = (ObjectiveTrackerFrame.GetHeight and ObjectiveTrackerFrame:GetHeight()) or 0
    local effectiveH = (contentH > 0) and math.min(contentH, frameH) or frameH
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPRIGHT", 0, 0)
    scrollBar:SetHeight(effectiveH)
    scrollBar:SetWidth(scrollBarWidth)

    scrollBar.background:SetTexture(scrollBarTexture)
    local rawBgColor = scrollSettings.backgroundColor
    if type(rawBgColor) == "table" then
        local bgR = tonumber(rawBgColor.r or rawBgColor[1]) or (scrollBarR * 0.22)
        local bgG = tonumber(rawBgColor.g or rawBgColor[2]) or (scrollBarG * 0.22)
        local bgB = tonumber(rawBgColor.b or rawBgColor[3]) or (scrollBarB * 0.22)
        local bgA = tonumber(rawBgColor.a or rawBgColor[4]) or math.min(scrollBarA, 0.35)
        scrollBar.background:SetVertexColor(bgR, bgG, bgB, bgA)
    else
        scrollBar.background:SetVertexColor(scrollBarR * 0.22, scrollBarG * 0.22, scrollBarB * 0.22, math.min(scrollBarA, 0.35))
    end
    scrollBar.thumb:SetTexture(scrollBarTexture)
    scrollBar.thumb:SetVertexColor(scrollBarR, scrollBarG, scrollBarB, scrollBarA)

    local ratio = visibleHeight / math.max(contentHeight, visibleHeight)
    local thumbHeight = math.max(K.SCROLL_BAR_MIN_THUMB_HEIGHT, math.floor((scrollBar:GetHeight() or visibleHeight) * ratio))
    scrollBar.thumb:SetSize(scrollBarWidth, thumbHeight)

    -- Scrollbar border
    if scrollBar.borderFrame then
        local rawBorderColor = scrollSettings.borderColor
        local fallbackBorderColor = K.DEFAULT_SCROLL_BAR_BORDER_COLOR
        local borderColor
        if type(rawBorderColor) == "table" then
            borderColor = {
                r = tonumber(rawBorderColor.r or rawBorderColor[1]) or fallbackBorderColor.r,
                g = tonumber(rawBorderColor.g or rawBorderColor[2]) or fallbackBorderColor.g,
                b = tonumber(rawBorderColor.b or rawBorderColor[3]) or fallbackBorderColor.b,
                a = tonumber(rawBorderColor.a or rawBorderColor[4]) or fallbackBorderColor.a,
            }
        else
            borderColor = fallbackBorderColor
        end
        local borderTexturePath = ns.GetBorderTexturePath and ns.GetBorderTexturePath(scrollSettings.borderTexture) or nil
        styleHelpers.ApplyBackdropBorder(
            scrollBar.borderFrame,
            scrollBar,
            scrollSettings.borderSize,
            borderTexturePath,
            borderColor,
            0, 0
        )
    end

    state.updatingScrollBar = true
    scrollBar:SetMinMaxValues(0, maxOffset)
    scrollBar:SetValue(state.scrollOffset)
    state.updatingScrollBar = false
    scrollBar:GetScript("OnValueChanged")(scrollBar, state.scrollOffset)

    if IsScrollBarVisible() then
        scrollBar:EnableMouse(true)
        scrollBar:Show()
    else
        scrollBar:EnableMouse(false)
        scrollBar:Hide()
    end
end

local function OnTrackerMouseWheel(_, delta)
    if not state.scrollBar or not IsModuleEnabled() or not IsScrollEnabled() then
        return
    end

    local currentValue = state.scrollOffset or 0
    local minValue, maxValue = state.scrollBar:GetMinMaxValues()
    if (maxValue or 0) <= (minValue or 0) then
        return
    end

    local newValue = math.max(minValue or 0, math.min(maxValue or 0, currentValue - ((delta or 0) * K.TRACKER_SCROLL_STEP)))

    state.updatingScrollBar = true
    state.scrollBar:SetValue(newValue)
    state.updatingScrollBar = false
    state.scrollOffset = newValue
    state.scrollBar:GetScript("OnValueChanged")(state.scrollBar, newValue)
end

local function EnsureTrackerButton()
    if state.trackerButton or not ObjectiveTrackerFrame or not ObjectiveTrackerFrame.Header then
        return state.trackerButton
    end

    local button = CreateFrame("Button", addonName .. "ObjectiveTrackerTrackAllButton", ObjectiveTrackerFrame.Header)
    button:SetSize(18, 19)

    local anchor = state.filterButton or ObjectiveTrackerFrame.Header.MinimizeButton or ObjectiveTrackerFrame.Header
    button:SetPoint("RIGHT", anchor, "LEFT", -4, 0)

    local trackIcon = button:CreateTexture(nil, "ARTWORK")
    trackIcon:SetSize(18, 19)
    trackIcon:SetPoint("CENTER")
    trackIcon:SetAtlas("Waypoint-MapPin-Tracked", false)
    button.icon = trackIcon

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:GetHighlightTexture():SetAllPoints()

    button:SetScript("OnClick", TrackAllQuestLogQuests)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TRACK_ALL_BUTTON_TEXT, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    state.trackerButton = button
    return button
end

local function RefreshTrackerButton()
    local button = EnsureTrackerButton()
    if not button then
        return
    end

    local shouldShow = IsTrackerTrackAllButtonEnabled()
        and IsModuleEnabled()
        and ObjectiveTrackerFrame
        and ObjectiveTrackerFrame.Header
        and ObjectiveTrackerFrame.Header:IsShown()
    button:SetShown(shouldShow)

    button:ClearAllPoints()
    local anchor = state.filterButton or ObjectiveTrackerFrame.Header.MinimizeButton or ObjectiveTrackerFrame.Header
    button:SetPoint("RIGHT", anchor, "LEFT", -4, 0)

    RefreshTrackerHeader()
end

local function GetQuestLogFrame()
    if WorldMapFrame and WorldMapFrame.QuestLog and WorldMapFrame.QuestLog.QuestsFrame then
        return WorldMapFrame.QuestLog.QuestsFrame
    end

    if QuestMapFrame and QuestMapFrame.QuestsFrame then
        return QuestMapFrame.QuestsFrame
    end

    return nil
end

local function GetQuestLogToolbarAnchor(questLogFrame)
    if not questLogFrame then
        return nil
    end

    return questLogFrame.SearchBox
        or questLogFrame.SettingsDropdown
        or (questLogFrame.ScrollFrame and questLogFrame.ScrollFrame.SearchBox)
        or (questLogFrame.ScrollFrame and questLogFrame.ScrollFrame.SettingsDropdown)
end

local function GetQuestLogSearchBox(questLogFrame)
    if not questLogFrame then
        return nil
    end

    return questLogFrame.SearchBox or (questLogFrame.ScrollFrame and questLogFrame.ScrollFrame.SearchBox)
end

local function GetQuestLogSettingsDropdown(questLogFrame)
    if not questLogFrame then
        return nil
    end

    return questLogFrame.SettingsDropdown or (questLogFrame.ScrollFrame and questLogFrame.ScrollFrame.SettingsDropdown)
end

local function GetQuestLogButtonParent()
    return GetQuestLogFrame()
end

local function LayoutQuestLogButton(button)
    if not button then
        return
    end

    local questLogFrame = GetQuestLogFrame()
    if not questLogFrame then
        return
    end

    if button:GetParent() ~= questLogFrame then
        button:SetParent(questLogFrame)
    end

    local toolbarAnchor = GetQuestLogToolbarAnchor(questLogFrame)
    local searchBox = GetQuestLogSearchBox(questLogFrame)
    local settingsDropdown = GetQuestLogSettingsDropdown(questLogFrame)

    button:ClearAllPoints()
    if settingsDropdown then
        button:SetPoint("RIGHT", settingsDropdown, "LEFT", -6, 0)
        button:SetPoint("TOP", searchBox or settingsDropdown, "TOP", 0, 0)
    elseif searchBox then
        button:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
        button:SetPoint("TOP", searchBox, "TOP", 0, 0)
    else
        button:SetPoint("TOPRIGHT", questLogFrame, "TOPRIGHT", -30, -6)
    end

    local layerAnchor = settingsDropdown or searchBox or toolbarAnchor or questLogFrame
    if layerAnchor then
        button:SetFrameStrata(layerAnchor:GetFrameStrata())
        button:SetFrameLevel((layerAnchor:GetFrameLevel() or 0) + 2)
    end
end

local function EnsureQuestLogButton()
    local parent = GetQuestLogButtonParent()
    if state.questLogButton or not QuestMapFrame or not parent then
        return state.questLogButton
    end

    local button = CreateFrame("Button", addonName .. "QuestLogTrackAllButton", parent)
    button:SetSize(18, 19)

    local trackIcon = button:CreateTexture(nil, "ARTWORK")
    trackIcon:SetSize(18, 19)
    trackIcon:SetPoint("CENTER")
    trackIcon:SetAtlas("Waypoint-MapPin-Tracked", false)
    button.icon = trackIcon

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:GetHighlightTexture():SetAllPoints()

    button:SetScript("OnClick", TrackAllQuestLogQuests)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TRACK_ALL_BUTTON_TEXT, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    LayoutQuestLogButton(button)

    state.questLogButton = button

    if not state.worldMapHooksInstalled then
        state.worldMapHooksInstalled = true
        QuestMapFrame:HookScript("OnShow", function()
            if ns.RefreshObjectiveTrackerUI then
                ns.RefreshObjectiveTrackerUI("soft")
            end
        end)
        QuestMapFrame:HookScript("OnHide", function()
            if state.questLogButton then
                state.questLogButton:Hide()
            end
        end)
        if QuestMapFrame_UpdateAll then
            hooksecurefunc("QuestMapFrame_UpdateAll", function()
                if ns.RefreshObjectiveTrackerUI then
                    ns.RefreshObjectiveTrackerUI("soft")
                end
            end)
        end
    end

    return button
end

local function RefreshQuestLogButton()
    local button = EnsureQuestLogButton()
    if not button then
        return
    end

    LayoutQuestLogButton(button)

    local shouldShow = IsQuestLogTrackAllButtonEnabled()
        and IsModuleEnabled()
        and QuestMapFrame
        and QuestMapFrame:IsShown()
        and QuestMapFrame.QuestsFrame
        and QuestMapFrame.QuestsFrame.ScrollFrame
        and QuestMapFrame.QuestsFrame.ScrollFrame:IsShown()

    button:SetShown(shouldShow)
end

local function InstallBlockHooks()
    if state.blockHooksInstalled or not ObjectiveTrackerBlockMixin then
        return
    end

    state.blockHooksInstalled = true

    hooksecurefunc(ObjectiveTrackerBlockMixin, "Reset", function(block)
        if IsModuleEnabled() then
            state.postLayoutStyleDirty = true
        end

        if block and block.AdjustRightEdgeOffset and (state.currentRightInset or 0) > 0 then
            block:AdjustRightEdgeOffset(-(state.currentRightInset or 0))
        end
    end)

    if ObjectiveTrackerModuleMixin then
        hooksecurefunc(ObjectiveTrackerModuleMixin, "BeginLayout", function(module)
            if IsModuleEnabled() and module and module.parentContainer == ObjectiveTrackerFrame then
                state.postLayoutStyleDirty = true
            end
        end)
    end

    -- Blizzard's DoQuestObjectives calls block:AddProgressBar(questID) and immediately
    -- calls progressBar:SetPercent(...) on the result during edit-mode transitions
    -- triggered by AccWideUILayoutSelection + BetterCooldownManager (via secureexecuterange).
    -- When GetAvailableHeight returns 10000 Blizzard processes every tracked quest,
    -- exhausting the progress bar pool and allocating fresh frames that can be missing
    -- SetPercent if the pool is created before full mixin initialization.
    --
    -- Root cause of the hook miss: quest blocks use ObjectiveTrackerQuestPOIBlockTemplate
    -- whose mixin is ObjectiveTrackerQuestPOIBlockMixin. That mixin is built via:
    --   ObjectiveTrackerBlockMixin
    --     â†’ CreateFromMixins â†’ ObjectiveTrackerAnimBlockMixin  (flat copy)
    --       â†’ CreateFromMixins â†’ ObjectiveTrackerQuestPOIBlockMixin  (flat copy)
    -- Each CreateFromMixins call copies AddProgressBar into a NEW table entry that is
    -- independent of ObjectiveTrackerBlockMixin.AddProgressBar. Hooking only
    -- ObjectiveTrackerBlockMixin therefore never intercepts quest block calls.
    -- We must hook every mixin table that holds its own copy of AddProgressBar.
    if not state.progressBarSetPercentPatched then
        state.progressBarSetPercentPatched = true
        local function PatchProgressBarSetPercent(block)
            local progressBar = block.lastRegion
            if progressBar and progressBar.SetPercent == nil then
                progressBar.SetPercent = function(self, percent)
                    self.Bar:SetValue(percent)
                    self.Bar.Label:SetFormattedText(PERCENTAGE_STRING, percent)
                end
            end
        end
        for _, mixin in ipairs({
            ObjectiveTrackerBlockMixin,
            ObjectiveTrackerAnimBlockMixin,
            ObjectiveTrackerQuestPOIBlockMixin,
        }) do
            if mixin and mixin.AddProgressBar then
                hooksecurefunc(mixin, "AddProgressBar", PatchProgressBarSetPercent)
            end
        end
    end
end

local function InstallCollapseHooks()
    if state.collapseHooksInstalled then
        return
    end

    if ObjectiveTrackerModuleMixin then
        hooksecurefunc(ObjectiveTrackerModuleMixin, "SetCollapsed", function(module, collapsed)
            if not module or module.parentContainer ~= ObjectiveTrackerFrame or state.applyingCollapseStates or not state.collapsePersistenceReady then
                return
            end

            local moduleKey = GetKeyForModule(module)
            if moduleKey then
                local isCollapsed = module.IsCollapsed and module:IsCollapsed()
                if isCollapsed == nil then
                    isCollapsed = collapsed == true
                end
                SetSavedSectionCollapsed(moduleKey, isCollapsed)
            end

            -- Re-apply minimize button chrome so +/- reflects the new state immediately.
            local moduleHeader = module.Header
            if moduleHeader and moduleHeader.MinimizeButton then
                local styles = BuildTrackerStyleData and BuildTrackerStyleData() or nil
                if styles then
                    local isNowCollapsed = module.IsCollapsed and module:IsCollapsed() == true or false
                    styleHelpers.ApplyMinimizeButtonChrome(moduleHeader.MinimizeButton, styles.buttonAppearance, isNowCollapsed)
                end
            end
        end)
        state.collapseHooksInstalled = true
    end

    if ObjectiveTrackerContainerMixin then
        hooksecurefunc(ObjectiveTrackerContainerMixin, "AddModule", function(container, module)
            if container ~= ObjectiveTrackerFrame or state.applyingCollapseStates then
                return
            end

            ApplySavedSectionCollapsedState(module)
        end)
        state.collapseHooksInstalled = true

        if ObjectiveTrackerContainerMixin.SetCollapsed then
            hooksecurefunc(ObjectiveTrackerContainerMixin, "SetCollapsed", function(container)
                if container ~= ObjectiveTrackerFrame then
                    return
                end

                local header = ObjectiveTrackerFrame.Header
                if header and header.MinimizeButton then
                    local styles = BuildTrackerStyleData and BuildTrackerStyleData() or nil
                    if styles then
                        local isCollapsed = ObjectiveTrackerFrame.IsCollapsed and ObjectiveTrackerFrame:IsCollapsed() == true or false
                        styleHelpers.ApplyMinimizeButtonChrome(header.MinimizeButton, styles.buttonAppearance, isCollapsed)
                    end
                end
            end)
        end
    end

end

do

function styleHelpers.SetFontAppearance(fontString, fontPath, fontSize, fontOutline)
    if not fontString or not fontString.SetFont then
        return
    end

    if fontString:SetFont(fontPath or STANDARD_TEXT_FONT, fontSize or 13, fontOutline or "") then
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT, fontSize or 13, fontOutline or "")
end

function styleHelpers.ApplyRegionColor(region, color)
    if not region or not color then
        return
    end

    if region.SetTextColor then
        region:SetTextColor(color.r, color.g, color.b, color.a)
        return
    end

    if region.SetVertexColor then
        region:SetVertexColor(color.r, color.g, color.b, color.a)
    end
end

function styleHelpers.ApplyTexturePath(textureRegion, texturePath)
    if not textureRegion or not texturePath or not textureRegion.SetTexture or textureRegion.SetTextColor then
        return
    end

    if textureRegion.GetAtlas and textureRegion:GetAtlas() then
        return
    end

    textureRegion:SetTexture(texturePath)
end

function styleHelpers.ApplyEdgeTexture(edges, texturePath)
    if not edges then
        return
    end

    for _, edge in ipairs(edges) do
        styleHelpers.ApplyTexturePath(edge, texturePath)
    end
end

local BORDER_TEXTURE_FALLBACK_PATH = "Interface\\Buttons\\WHITE8x8"

local function CopyBackdropInsets(insets, fallback)
    fallback = Clamp(tonumber(fallback) or 0, 0, 128)
    if type(insets) ~= "table" then
        return {
            left = fallback,
            right = fallback,
            top = fallback,
            bottom = fallback,
        }
    end

    return {
        left = Clamp(tonumber(insets.left) or fallback, 0, 128),
        right = Clamp(tonumber(insets.right) or fallback, 0, 128),
        top = Clamp(tonumber(insets.top) or fallback, 0, 128),
        bottom = Clamp(tonumber(insets.bottom) or fallback, 0, 128),
    }
end

local function ResolveBackdropBorderStyle(texturePath, thickness)
    local borderDefinition = ns.GetBorderTextureDefinition and ns.GetBorderTextureDefinition(texturePath) or nil
    local baseEdgeSize = Clamp(tonumber(borderDefinition and borderDefinition.edgeSize) or 1, 1, 128)
    local scaleStep = Clamp(tonumber(borderDefinition and borderDefinition.scaleStep) or 1, 0, 32)
    local renderedEdgeSize = baseEdgeSize
    if thickness > 0 and (not borderDefinition or borderDefinition.supportsVariableThickness ~= false) then
        renderedEdgeSize = renderedEdgeSize + (math.max(thickness - 1, 0) * scaleStep)
    end

    renderedEdgeSize = Clamp(renderedEdgeSize, 1, 128)
    return {
        edgeFile = (borderDefinition and borderDefinition.path) or texturePath or BORDER_TEXTURE_FALLBACK_PATH,
        tile = borderDefinition and borderDefinition.tile ~= false or true,
        tileSize = Clamp(tonumber(borderDefinition and borderDefinition.tileSize) or 8, 1, 128),
        baseEdgeSize = baseEdgeSize,
        edgeSize = renderedEdgeSize,
        preserveColor = borderDefinition and borderDefinition.preserveColor == true or false,
        insets = CopyBackdropInsets(borderDefinition and borderDefinition.insets, math.max(1, math.floor(renderedEdgeSize / 4))),
    }
end

function styleHelpers.ApplyBackdropBorderLayout(borderFrame, target, borderSize, edgeSize, baseEdgeSize, leftOffset, rightOffset)
    if not borderFrame or not target then
        return 0, 0, 0
    end

    local signedSize = NormalizeBorderSize(borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE)
    local thickness = math.abs(signedSize)
    local renderedEdgeSize = Clamp(tonumber(edgeSize) or thickness, 0, 128)
    local nativeEdgeSize = Clamp(tonumber(baseEdgeSize) or renderedEdgeSize, 0, 128)
    if thickness == 0 or renderedEdgeSize == 0 then
        return signedSize, thickness, 0
    end

    local left = tonumber(leftOffset) or 0
    local right = tonumber(rightOffset) or 0
    local layoutPadding = math.max(renderedEdgeSize - nativeEdgeSize, 0)

    borderFrame:ClearAllPoints()
    if signedSize > 0 then
        borderFrame:SetPoint("TOPLEFT", target, "TOPLEFT", left - layoutPadding, layoutPadding)
        borderFrame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", right + layoutPadding, -layoutPadding)
    elseif signedSize < 0 then
        borderFrame:SetPoint("TOPLEFT", target, "TOPLEFT", left + layoutPadding, -layoutPadding)
        borderFrame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", right - layoutPadding, layoutPadding)
    else
        borderFrame:SetPoint("TOPLEFT", target, "TOPLEFT", left, 0)
        borderFrame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", right, 0)
    end

    return signedSize, thickness, renderedEdgeSize
end

function styleHelpers.ApplyBackdropBorder(borderFrame, target, borderSize, texturePath, color, leftOffset, rightOffset)
    if not borderFrame or not target then
        return 0, 0
    end

    local signedSize = NormalizeBorderSize(borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE)
    local thickness = math.abs(signedSize)
    if thickness == 0 then
        borderFrame:Hide()
        return signedSize, thickness
    end

    local borderStyle = ResolveBackdropBorderStyle(texturePath, thickness)
    local _, _, renderedEdgeSize = styleHelpers.ApplyBackdropBorderLayout(
        borderFrame,
        target,
        signedSize,
        borderStyle.edgeSize,
        borderStyle.baseEdgeSize,
        leftOffset,
        rightOffset
    )
    if renderedEdgeSize == 0 then
        borderFrame:Hide()
        return signedSize, 0
    end

    local previousBackdropInfo = borderFrame.nomtoolsBackdropInfo
    local backdropInfo = {
        tile = false,
        insets = {},
    }
    backdropInfo.bgFile = nil
    backdropInfo.edgeFile = borderStyle.edgeFile
    backdropInfo.tile = borderStyle.tile
    backdropInfo.tileSize = borderStyle.tileSize
    backdropInfo.edgeSize = renderedEdgeSize
    backdropInfo.insets.left = borderStyle.insets.left
    backdropInfo.insets.right = borderStyle.insets.right
    backdropInfo.insets.top = borderStyle.insets.top
    backdropInfo.insets.bottom = borderStyle.insets.bottom
    borderFrame.nomtoolsBackdropInfo = backdropInfo

    if previousBackdropInfo and previousBackdropInfo.edgeFile ~= backdropInfo.edgeFile then
        borderFrame:SetBackdrop(nil)
    end

    borderFrame:SetBackdrop(backdropInfo)
    borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    borderFrame:Show()
    return signedSize, renderedEdgeSize
end

function styleHelpers.ApplyBorderLayout(container, target, borderSize, leftOffset, rightOffset)
    if not container or not target then
        return 0, 0
    end

    local signedSize = NormalizeBorderSize(borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE)
    local thickness = math.abs(signedSize)
    if thickness == 0 then
        return signedSize, thickness
    end

    local left = tonumber(leftOffset) or 0
    local right = tonumber(rightOffset) or 0

    if signedSize > 0 then
        container.top:ClearAllPoints()
        container.top:SetPoint("TOPLEFT", target, "TOPLEFT", left - thickness, thickness)
        container.top:SetPoint("TOPRIGHT", target, "TOPRIGHT", right + thickness, thickness)
        container.top:SetHeight(thickness)

        container.bottom:ClearAllPoints()
        container.bottom:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", left - thickness, -thickness)
        container.bottom:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", right + thickness, -thickness)
        container.bottom:SetHeight(thickness)

        container.left:ClearAllPoints()
        container.left:SetPoint("TOPLEFT", target, "TOPLEFT", left - thickness, thickness)
        container.left:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", left - thickness, -thickness)
        container.left:SetWidth(thickness)

        container.right:ClearAllPoints()
        container.right:SetPoint("TOPRIGHT", target, "TOPRIGHT", right + thickness, thickness)
        container.right:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", right + thickness, -thickness)
        container.right:SetWidth(thickness)
    else
        container.top:ClearAllPoints()
        container.top:SetPoint("TOPLEFT", target, "TOPLEFT", left, 0)
        container.top:SetPoint("TOPRIGHT", target, "TOPRIGHT", right, 0)
        container.top:SetHeight(thickness)

        container.bottom:ClearAllPoints()
        container.bottom:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", left, 0)
        container.bottom:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", right, 0)
        container.bottom:SetHeight(thickness)

        container.left:ClearAllPoints()
        container.left:SetPoint("TOPLEFT", target, "TOPLEFT", left, 0)
        container.left:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", left, 0)
        container.left:SetWidth(thickness)

        container.right:ClearAllPoints()
        container.right:SetPoint("TOPRIGHT", target, "TOPRIGHT", right, 0)
        container.right:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", right, 0)
        container.right:SetWidth(thickness)
    end

    return signedSize, thickness
end

function styleHelpers.GetStatusBarAnonymousRegions(statusBar, excludedRegion, drawLayer, subLevel)
    local regions = {}
    if not statusBar or not statusBar.GetRegions then
        return regions
    end

    for _, region in ipairs({ statusBar:GetRegions() }) do
        if region
            and region ~= excludedRegion
            and region.GetObjectType
            and region:GetObjectType() == "Texture"
        then
            local regionDrawLayer, regionSubLevel = region:GetDrawLayer()
            if (not drawLayer or regionDrawLayer == drawLayer)
                and (subLevel == nil or regionSubLevel == subLevel)
            then
                regions[#regions + 1] = region
            end
        end
    end

    return regions
end

function styleHelpers.BuildTrackerColorStyle(color, highlightColor, isComplete)
    local baseColor = NormalizeColor(color, K.DEFAULT_UNCOMPLETED_COLOR)
    local hoverColor = NormalizeColor(highlightColor, baseColor)
    local style = {
        r = baseColor.r,
        g = baseColor.g,
        b = baseColor.b,
        nomtoolsIsComplete = isComplete == true,
    }

    if hoverColor.r == style.r and hoverColor.g == style.g and hoverColor.b == style.b then
        style.reverse = style
        return style
    end

    local reverseStyle = {
        r = hoverColor.r,
        g = hoverColor.g,
        b = hoverColor.b,
        nomtoolsIsComplete = isComplete == true,
    }
    style.reverse = reverseStyle
    reverseStyle.reverse = style
    return style
end

function styleHelpers.ApplyFontStringColorStyle(fontString, colorStyle, useHighlight)
    if not fontString or not colorStyle then
        return
    end

    local appliedColorStyle = colorStyle
    if useHighlight and colorStyle.reverse then
        appliedColorStyle = colorStyle.reverse
    end

    fontString.nomtoolsColorStyle = colorStyle
    fontString:SetTextColor(appliedColorStyle.r, appliedColorStyle.g, appliedColorStyle.b)
end

local function AppendColorSignature(parts, color, fallback)
    fallback = fallback or K.DEFAULT_UNCOMPLETED_COLOR
    local r, g, b, a
    if type(color) == "table" then
        r = tonumber(color.r or color[1]) or fallback.r
        g = tonumber(color.g or color[2]) or fallback.g
        b = tonumber(color.b or color[3]) or fallback.b
        a = tonumber(color.a or color[4]) or fallback.a
    else
        r, g, b, a = fallback.r, fallback.g, fallback.b, fallback.a
    end
    parts[#parts + 1] = string.format("%.3f,%.3f,%.3f,%.3f", r, g, b, a)
end

local styleSignatureParts = {}

local function GetTrackerStyleSignature()
    local typography = GetTypographySettings()
    local progressBar = GetProgressBarSettings()
    local appearance = GetHeaderAppearanceSettings()
    local titleColors = typography.titleColors or {}
    local parts = styleSignatureParts
    for k in pairs(parts) do parts[k] = nil end

    parts[1] = tostring(ns.GetFontPath and ns.GetFontPath(typography.font) or STANDARD_TEXT_FONT)
    parts[2] = tostring(Clamp(tonumber(typography.fontSize) or 13, 8, 24))
    parts[3] = tostring(ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(typography.fontOutline) or "OUTLINE")
    parts[4] = tostring(GetLevelPrefixMode(typography))
    parts[5] = tostring(IsWarbandIndicatorEnabled(typography) and true or false)
    parts[6] = tostring(appearance.preset == "nomtools" and true or false)
    parts[7] = tostring(ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath((appearance.mainHeader or {}).texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[8] = tostring(Clamp(tonumber((appearance.mainHeader or {}).opacity) or 80, 0, 100))
    parts[9] = tostring(ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath((appearance.categoryHeader or {}).texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[10] = tostring(Clamp(tonumber((appearance.categoryHeader or {}).opacity) or 80, 0, 100))
    parts[11] = tostring(ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath((appearance.button or {}).texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[12] = tostring(Clamp(tonumber((appearance.button or {}).opacity) or 80, 0, 100))
    -- Main header typography overrides
    parts[13] = tostring((typography.mainHeader or {}).font or "")
    parts[14] = tostring((typography.mainHeader or {}).fontSize or "")
    parts[15] = tostring((typography.mainHeader or {}).fontOutline or "")
    parts[16] = tostring((typography.mainHeader or {}).overrideTypography and true or false)
    parts[17] = tostring(Clamp(tonumber((typography.mainHeader or {}).xOffset) or 0, -200, 200))
    parts[18] = tostring(Clamp(tonumber((typography.mainHeader or {}).yOffset) or 0, -200, 200))
    -- Category header typography overrides
    parts[19] = tostring((typography.categoryHeader or {}).font or "")
    parts[20] = tostring((typography.categoryHeader or {}).fontSize or "")
    parts[21] = tostring((typography.categoryHeader or {}).fontOutline or "")
    parts[22] = tostring((typography.categoryHeader or {}).overrideTypography and true or false)
    parts[23] = tostring(Clamp(tonumber((typography.categoryHeader or {}).xOffset) or 0, -200, 200))
    parts[24] = tostring(Clamp(tonumber((typography.categoryHeader or {}).yOffset) or 0, -200, 200))
    parts[25] = tostring(progressBar.fillMode == "static" and "static" or "progress")
    parts[26] = tostring(ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(progressBar.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[27] = tostring(NormalizeBorderSize(progressBar.borderSize, K.DEFAULT_PROGRESS_BORDER_SIZE, K.MIN_PROGRESS_BORDER_SIZE, K.MAX_PROGRESS_BORDER_SIZE))
    parts[28] = tostring(ns.GetBorderTexturePath and ns.GetBorderTexturePath(progressBar.borderTexture or progressBar.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[29] = tostring(progressBar.hideRewardIcon == true)
    parts[30] = tostring(NormalizeBorderSize((appearance.mainHeader or {}).borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE))
    parts[31] = tostring(NormalizeBorderSize((appearance.categoryHeader or {}).borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE))
    parts[32] = tostring(NormalizeBorderSize((appearance.button or {}).borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE))
    parts[33] = tostring(NormalizeBorderSize((appearance.trackerBackground or {}).borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE))
    parts[34] = tostring(ns.GetBorderTexturePath and ns.GetBorderTexturePath((appearance.mainHeader or {}).borderTexture or (appearance.mainHeader or {}).texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[35] = tostring(ns.GetBorderTexturePath and ns.GetBorderTexturePath((appearance.categoryHeader or {}).borderTexture or (appearance.categoryHeader or {}).texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[36] = tostring(ns.GetBorderTexturePath and ns.GetBorderTexturePath((appearance.button or {}).borderTexture or (appearance.button or {}).texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[37] = tostring(ns.GetBorderTexturePath and ns.GetBorderTexturePath((appearance.trackerBackground or {}).borderTexture or (appearance.trackerBackground or {}).texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)

    AppendColorSignature(parts, typography.uncompletedColor, K.DEFAULT_UNCOMPLETED_COLOR)
    AppendColorSignature(parts, typography.completedColor, K.DEFAULT_COMPLETED_COLOR)
    AppendColorSignature(parts, titleColors.quest, K.DEFAULT_SPECIAL_TITLE_COLORS.quest)
    AppendColorSignature(parts, titleColors.worldQuest, K.DEFAULT_SPECIAL_TITLE_COLORS.worldQuest)
    AppendColorSignature(parts, titleColors.bonusObjective, K.DEFAULT_SPECIAL_TITLE_COLORS.bonusObjective)
    AppendColorSignature(parts, titleColors.daily, K.DEFAULT_SPECIAL_TITLE_COLORS.daily)
    AppendColorSignature(parts, titleColors.weekly, K.DEFAULT_SPECIAL_TITLE_COLORS.weekly)
    AppendColorSignature(parts, titleColors.meta, K.DEFAULT_SPECIAL_TITLE_COLORS.meta)
    AppendColorSignature(parts, titleColors.important, K.DEFAULT_SPECIAL_TITLE_COLORS.important)
    AppendColorSignature(parts, titleColors.prey, K.DEFAULT_SPECIAL_TITLE_COLORS.prey)
    AppendColorSignature(parts, titleColors.campaign, K.DEFAULT_SPECIAL_TITLE_COLORS.campaign)
    AppendColorSignature(parts, titleColors.legendary, K.DEFAULT_SPECIAL_TITLE_COLORS.legendary)
    parts[#parts + 1] = tostring(titleColors.useTrivialColor ~= false)
    AppendColorSignature(parts, titleColors.trivial, K.DEFAULT_SPECIAL_TITLE_COLORS.trivial)
    AppendColorSignature(parts, progressBar.fillColor, K.DEFAULT_PROGRESS_FILL_COLOR)
    AppendColorSignature(parts, progressBar.lowFillColor, K.DEFAULT_PROGRESS_LOW_FILL_COLOR)
    AppendColorSignature(parts, progressBar.mediumFillColor, K.DEFAULT_PROGRESS_MEDIUM_FILL_COLOR)
    AppendColorSignature(parts, progressBar.highFillColor, K.DEFAULT_PROGRESS_HIGH_FILL_COLOR)
    AppendColorSignature(parts, progressBar.backgroundColor, K.DEFAULT_PROGRESS_BACKGROUND_COLOR)
    AppendColorSignature(parts, progressBar.borderColor, K.DEFAULT_PROGRESS_BORDER_COLOR)
    AppendColorSignature(parts, (appearance.mainHeader or {}).color, K.DEFAULT_HEADER_BACKGROUND_COLOR)
    AppendColorSignature(parts, (appearance.mainHeader or {}).borderColor, K.DEFAULT_HEADER_BORDER_COLOR)
    AppendColorSignature(parts, (appearance.categoryHeader or {}).color, K.DEFAULT_HEADER_BACKGROUND_COLOR)
    AppendColorSignature(parts, (appearance.categoryHeader or {}).borderColor, K.DEFAULT_HEADER_BORDER_COLOR)
    AppendColorSignature(parts, (appearance.button or {}).color, K.DEFAULT_HEADER_BACKGROUND_COLOR)
    AppendColorSignature(parts, (appearance.button or {}).borderColor, K.DEFAULT_HEADER_BORDER_COLOR)
    AppendColorSignature(parts, (typography.mainHeader or {}).textColor, K.DEFAULT_HEADER_BACKGROUND_COLOR)
    AppendColorSignature(parts, (typography.categoryHeader or {}).textColor, K.DEFAULT_HEADER_BACKGROUND_COLOR)
    local tbg = appearance.trackerBackground or {}
    parts[#parts + 1] = tostring(tbg.enabled and true or false)
    parts[#parts + 1] = tostring(ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(tbg.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)
    parts[#parts + 1] = tostring(Clamp(tonumber(tbg.opacity) or 60, 0, 100))
    AppendColorSignature(parts, tbg.color, K.DEFAULT_HEADER_BACKGROUND_COLOR)
    AppendColorSignature(parts, tbg.borderColor, K.DEFAULT_HEADER_BORDER_COLOR)
    parts[#parts + 1] = tostring(ns.GetBorderTexturePath and ns.GetBorderTexturePath(tbg.borderTexture or tbg.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH)

    local settings = GetSettings()
    local filterSettings = settings.filter or {}
    parts[#parts + 1] = tostring(filterSettings.sortBy or "default")
    parts[#parts + 1] = tostring(filterSettings.sortDirection or "asc")
    parts[#parts + 1] = tostring(filterSettings.groupByZone or false)
    parts[#parts + 1] = tostring(settings.search and settings.search.enabled ~= false)
    parts[#parts + 1] = tostring(settings.buttons and settings.buttons.filterButton ~= false)

    return table.concat(parts, "|")
end

BuildTrackerStyleData = function()
    local styleSignature = GetTrackerStyleSignature()
    if state.cachedTrackerStyleSignature == styleSignature and state.cachedTrackerStyles then
        return state.cachedTrackerStyles
    end

    local typography = GetTypographySettings()
    local progressBar = GetProgressBarSettings()
    local appearance = GetHeaderAppearanceSettings()
    local fontPath = ns.GetFontPath and ns.GetFontPath(typography.font) or STANDARD_TEXT_FONT
    local fontSize = Clamp(tonumber(typography.fontSize) or 13, 8, 24)
    local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(typography.fontOutline) or "OUTLINE"
    local uncompletedColor = NormalizeColor(typography.uncompletedColor, K.DEFAULT_UNCOMPLETED_COLOR)
    local completedColor = NormalizeColor(typography.completedColor, K.DEFAULT_COMPLETED_COLOR)
    local titleColors = typography.titleColors or {}
    local headerUseNomTools = appearance.preset == "nomtools"
    local progressUseNomTools = appearance.preset == "nomtools"
    local progressFillMode = progressBar.fillMode == "static" and "static" or "progress"

    -- Build one appearance block per visual section from its sub-table.
    local function BuildSectionAppearance(section)
        local s = type(section) == "table" and section or {}
        local opacity = Clamp(tonumber(s.opacity) or 80, 0, 100) / 100
        local bgColor = NormalizeColor(s.color, K.DEFAULT_HEADER_BACKGROUND_COLOR)
        bgColor.a = opacity
        return {
            useNomTools = headerUseNomTools,
            texture = ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(s.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH,
            backgroundColor = bgColor,
            borderColor = NormalizeColor(s.borderColor, K.DEFAULT_HEADER_BORDER_COLOR),
            borderTexture = ns.GetBorderTexturePath and ns.GetBorderTexturePath(s.borderTexture or s.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH,
            borderSize = NormalizeBorderSize(s.borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE),
        }
    end

    -- Resolve header-specific font overrides, falling back to the global typography.
    local function ResolveHeaderFont(override, base)
        local o = type(override) == "table" and override or {}
        local useOverride = o.overrideTypography == true
        return {
            fontPath = (useOverride and o.font and ns.GetFontPath and ns.GetFontPath(o.font)) or base.fontPath,
            fontSize = (useOverride and o.fontSize and Clamp(tonumber(o.fontSize), 8, 24)) or base.fontSize,
            fontOutline = (useOverride and o.fontOutline and ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(o.fontOutline)) or base.fontOutline,
            textColor = type(o.textColor) == "table" and NormalizeColor(o.textColor) or nil,
        }
    end

    local baseFont = { fontPath = fontPath, fontSize = fontSize, fontOutline = fontOutline }
    local defaultHeaderColor = NormalizeColor(OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR.Header or nil, {
        r = 1,
        g = 0.82,
        b = 0,
        a = 1,
    })

    local styles = {
        fontPath = fontPath or STANDARD_TEXT_FONT,
        fontSize = fontSize,
        fontOutline = fontOutline,
        levelPrefixMode = GetLevelPrefixMode(typography),
        showWarbandCompletedIndicator = IsWarbandIndicatorEnabled(typography),
        uncompletedColor = uncompletedColor,
        completedColor = completedColor,
        questTitleColor = NormalizeColor(titleColors.quest, K.DEFAULT_SPECIAL_TITLE_COLORS.quest),
        worldQuestTitleColor = NormalizeColor(titleColors.worldQuest, K.DEFAULT_SPECIAL_TITLE_COLORS.worldQuest),
        bonusObjectiveTitleColor = NormalizeColor(titleColors.bonusObjective, K.DEFAULT_SPECIAL_TITLE_COLORS.bonusObjective),
        dailyTitleColor = NormalizeColor(titleColors.daily, K.DEFAULT_SPECIAL_TITLE_COLORS.daily),
        weeklyTitleColor = NormalizeColor(titleColors.weekly, K.DEFAULT_SPECIAL_TITLE_COLORS.weekly),
        metaTitleColor = NormalizeColor(titleColors.meta, K.DEFAULT_SPECIAL_TITLE_COLORS.meta),
        importantTitleColor = NormalizeColor(titleColors.important, K.DEFAULT_SPECIAL_TITLE_COLORS.important),
        preyTitleColor = NormalizeColor(titleColors.prey, K.DEFAULT_SPECIAL_TITLE_COLORS.prey),
        campaignTitleColor = NormalizeColor(titleColors.campaign, K.DEFAULT_SPECIAL_TITLE_COLORS.campaign),
        legendaryTitleColor = NormalizeColor(titleColors.legendary, K.DEFAULT_SPECIAL_TITLE_COLORS.legendary),
        trivialTitleColor = NormalizeColor(titleColors.trivial, K.DEFAULT_SPECIAL_TITLE_COLORS.trivial),
        useTrivialTitleColor = titleColors.useTrivialColor ~= false,
        uncompletedStyle = styleHelpers.BuildTrackerColorStyle(uncompletedColor, uncompletedColor, false),
        completedStyle = styleHelpers.BuildTrackerColorStyle(completedColor, completedColor, true),
        progressUseNomTools = progressUseNomTools,
        progressTexture = ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(progressBar.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH,
        progressFillMode = progressFillMode,
        progressFillColor = NormalizeColor(progressBar.fillColor, K.DEFAULT_PROGRESS_FILL_COLOR),
        progressLowFillColor = NormalizeColor(progressBar.lowFillColor, K.DEFAULT_PROGRESS_LOW_FILL_COLOR),
        progressMediumFillColor = NormalizeColor(progressBar.mediumFillColor, K.DEFAULT_PROGRESS_MEDIUM_FILL_COLOR),
        progressHighFillColor = NormalizeColor(progressBar.highFillColor, K.DEFAULT_PROGRESS_HIGH_FILL_COLOR),
        progressBackgroundColor = NormalizeColor(progressBar.backgroundColor, K.DEFAULT_PROGRESS_BACKGROUND_COLOR),
        progressBorderTexture = ns.GetBorderTexturePath and ns.GetBorderTexturePath(progressBar.borderTexture or progressBar.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH,
        progressBorderSize = NormalizeBorderSize(progressBar.borderSize, K.DEFAULT_PROGRESS_BORDER_SIZE, K.MIN_PROGRESS_BORDER_SIZE, K.MAX_PROGRESS_BORDER_SIZE),
        progressBorderColor = NormalizeColor(progressBar.borderColor, K.DEFAULT_PROGRESS_BORDER_COLOR),
        progressHideRewardIcon = progressBar.hideRewardIcon == true,
        -- Per-section header chrome appearances
        mainHeaderAppearance = BuildSectionAppearance(appearance.mainHeader),
        categoryHeaderAppearance = BuildSectionAppearance(appearance.categoryHeader),
        buttonAppearance = BuildSectionAppearance(appearance.button),
        -- Per-section header text fonts (resolved from overrides or global typography)
        mainHeaderFont = ResolveHeaderFont(typography.mainHeader, baseFont),
        categoryHeaderFont = ResolveHeaderFont(typography.categoryHeader, baseFont),
        mainHeaderXOffset = Clamp(tonumber((typography.mainHeader or {}).xOffset) or 0, -200, 200),
        mainHeaderYOffset = Clamp(tonumber((typography.mainHeader or {}).yOffset) or 0, -200, 200),
        categoryHeaderXOffset = Clamp(tonumber((typography.categoryHeader or {}).xOffset) or 0, -200, 200),
        categoryHeaderYOffset = Clamp(tonumber((typography.categoryHeader or {}).yOffset) or 0, -200, 200),
        trackerBackground = (function()
            local tbg = appearance.trackerBackground or {}
            if tbg.enabled ~= true then return { enabled = false } end
            local opacity = Clamp(tonumber(tbg.opacity) or 60, 0, 100) / 100
            local bgColor = NormalizeColor(tbg.color, K.DEFAULT_HEADER_BACKGROUND_COLOR)
            bgColor.a = opacity
            return {
                enabled = true,
                texture = ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(tbg.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH,
                backgroundColor = bgColor,
                borderColor = NormalizeColor(tbg.borderColor, K.DEFAULT_HEADER_BORDER_COLOR),
                borderTexture = ns.GetBorderTexturePath and ns.GetBorderTexturePath(tbg.borderTexture or tbg.texture) or DEFAULT_STATUSBAR_TEXTURE_PATH,
                borderSize = NormalizeBorderSize(tbg.borderSize, K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE),
            }
        end)(),
    }

    styles.defaultHeaderStyle = styleHelpers.BuildTrackerColorStyle(defaultHeaderColor, GetHoverColor(defaultHeaderColor))
    styles.questHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.questTitleColor, GetHoverColor(styles.questTitleColor))
    styles.worldQuestHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.worldQuestTitleColor, GetHoverColor(styles.worldQuestTitleColor))
    styles.bonusObjectiveHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.bonusObjectiveTitleColor, GetHoverColor(styles.bonusObjectiveTitleColor))
    styles.dailyHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.dailyTitleColor, GetHoverColor(styles.dailyTitleColor))
    styles.weeklyHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.weeklyTitleColor, GetHoverColor(styles.weeklyTitleColor))
    styles.metaHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.metaTitleColor, GetHoverColor(styles.metaTitleColor))
    styles.importantHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.importantTitleColor, GetHoverColor(styles.importantTitleColor))
    styles.preyHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.preyTitleColor, GetHoverColor(styles.preyTitleColor))
    styles.campaignHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.campaignTitleColor, GetHoverColor(styles.campaignTitleColor))
    styles.legendaryHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.legendaryTitleColor, GetHoverColor(styles.legendaryTitleColor))
    styles.trivialHeaderStyle = styleHelpers.BuildTrackerColorStyle(styles.trivialTitleColor, GetHoverColor(styles.trivialTitleColor))

    state.cachedTrackerStyleSignature = styleSignature
    state.cachedTrackerStyles = styles
    return styles
end

function styleHelpers.SetRegionShown(region, shown)
    if not region then
        return
    end

    if region.SetShown then
        region:SetShown(shown)
    elseif shown then
        region:Show()
    else
        region:Hide()
    end
end

function styleHelpers.ApplyModuleHeaderLayout(frame)
    -- Blizzard initialises module-header frames with an explicit SetWidth equal
    -- to the tracker size at the time of creation.  When the user adjusts the
    -- tracker width those headers are never updated, so their chrome textures
    -- (anchored to frame.BOTTOMRIGHT) stay at the original size.  Force the
    -- header to span its parent module so chrome extents stay correct.
    local ownerModule = frame.GetParent and frame:GetParent() or nil
    if not ownerModule then return end
    local moduleWidth = ownerModule.GetWidth and ownerModule:GetWidth() or 0
    if moduleWidth > 0 then
        frame:SetWidth(moduleWidth)
    end
end

function styleHelpers.GetHeaderVisualExtensions(frame)
    if not frame or not ObjectiveTrackerFrame then
        return 0, 0
    end

    if frame == ObjectiveTrackerFrame.Header then
        return K.TRACKER_VISUAL_LEFT_EXTENSION, 0
    end

    local ownerModule = frame.GetParent and frame:GetParent() or nil
    if ownerModule and ownerModule.parentContainer == ObjectiveTrackerFrame then
        return K.TRACKER_VISUAL_LEFT_EXTENSION, TRACKER_MODULE_HEADER_RIGHT_EXTENSION
    end

    return 0, 0
end

function styleHelpers.ApplyHeaderVisualExtents(frame, region)
    if not frame or not region then
        return
    end

    local leftExtension, rightExtension = styleHelpers.GetHeaderVisualExtensions(frame)
    local ownerModule = frame:GetParent()
    local anchorRef = (ownerModule and ownerModule.parentContainer == ObjectiveTrackerFrame) and ownerModule or frame
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", anchorRef, "TOPLEFT", -leftExtension, 0)
    region:SetPoint("TOPRIGHT", anchorRef, "TOPRIGHT", rightExtension, 0)
    region:SetHeight(frame:GetHeight())
end

function styleHelpers.ApplyHeaderButtonInset(frame)
    if not frame or not frame.MinimizeButton then
        return
    end

    local button = frame.MinimizeButton
    if not button.nomtoolsOriginalAnchor then
        local point, relativeTo, relativePoint, xOfs, yOfs = button:GetPoint(1)
        if not point then
            return
        end

        button.nomtoolsOriginalAnchor = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs or 0,
            yOfs = yOfs or 0,
        }
    end

    local anchor = button.nomtoolsOriginalAnchor
    button:ClearAllPoints()
    button:SetPoint(
        anchor.point,
        anchor.relativeTo,
        anchor.relativePoint,
        (anchor.xOfs or 0) - K.TRACKER_HEADER_BUTTON_RIGHT_INSET,
        anchor.yOfs or 0
    )
end

function styleHelpers.ApplyHeaderChromeExtents(frame, chrome)
    if not frame or not chrome then
        return
    end

    local leftExtension, rightExtension = styleHelpers.GetHeaderVisualExtensions(frame)
    local ownerModule = frame:GetParent()
    local anchorRef = (ownerModule and ownerModule.parentContainer == ObjectiveTrackerFrame) and ownerModule or frame

    chrome.background:ClearAllPoints()
    chrome.background:SetPoint("TOPLEFT", anchorRef, "TOPLEFT", -leftExtension, 0)
    chrome.background:SetPoint("TOPRIGHT", anchorRef, "TOPRIGHT", rightExtension, 0)
    chrome.background:SetHeight(frame:GetHeight())
end

function styleHelpers.EnsureFrameChrome(frame)
    if not frame then
        return nil
    end

    if frame.NomToolsChrome then
        return frame.NomToolsChrome
    end

    local chrome = {}
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetAllPoints()
    chrome.background = background

    local borderHost = CreateFrame("Frame", nil, frame)
    borderHost:SetAllPoints(frame)
    borderHost:SetFrameStrata(frame:GetFrameStrata())
    borderHost:SetFrameLevel((frame:GetFrameLevel() or 0) + 30)
    borderHost:EnableMouse(false)
    chrome.borderHost = borderHost

    local borderFrame = CreateFrame("Frame", nil, borderHost, BackdropTemplateMixin and "BackdropTemplate" or nil)
    borderFrame:SetAllPoints(frame)
    borderFrame:EnableMouse(false)
    chrome.borderFrame = borderFrame
    chrome.edges = {}

    frame.NomToolsChrome = chrome
    return chrome
end

function styleHelpers.ApplyChromeEdgeThickness(chrome, thickness)
    if not chrome then
        return
    end

    local resolvedThickness = Clamp(tonumber(thickness) or K.DEFAULT_CHROME_BORDER_SIZE, K.MIN_CHROME_BORDER_SIZE, K.MAX_CHROME_BORDER_SIZE)
    if chrome.top then
        chrome.top:SetHeight(resolvedThickness)
    end
    if chrome.bottom then
        chrome.bottom:SetHeight(resolvedThickness)
    end
    if chrome.left then
        chrome.left:SetWidth(resolvedThickness)
    end
    if chrome.right then
        chrome.right:SetWidth(resolvedThickness)
    end
end

function styleHelpers.ApplyFrameChrome(frame, appearance)
    local chrome = styleHelpers.EnsureFrameChrome(frame)
    if not chrome then
        return
    end

    local useNomTools = appearance and appearance.useNomTools == true
    if not useNomTools then
        styleHelpers.SetRegionShown(chrome.background, false)
        if chrome.borderFrame then
            chrome.borderFrame:Hide()
        end
        return
    end

    styleHelpers.ApplyTexturePath(chrome.background, appearance.texture)
    styleHelpers.ApplyRegionColor(chrome.background, appearance.backgroundColor)
    local _, borderThickness = styleHelpers.ApplyBackdropBorder(
        chrome.borderFrame,
        frame,
        appearance.borderSize,
        appearance.borderTexture or appearance.texture,
        appearance.borderColor,
        0,
        0
    )
    chrome.background:Show()

    if borderThickness == 0 and chrome.borderFrame then
        chrome.borderFrame:Hide()
    end
end

function styleHelpers.EnsureTrackerBackground()
    if state.trackerBackgroundChrome then
        return state.trackerBackgroundChrome
    end
    if not ObjectiveTrackerFrame then
        return nil
    end

    local chrome = {}
    local bg = ObjectiveTrackerFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT", -K.TRACKER_VISUAL_LEFT_EXTENSION, 0)
    bg:SetPoint("BOTTOMRIGHT", ObjectiveTrackerFrame, "BOTTOMRIGHT", 0, 0)
    chrome.background = bg

    local borderHost = CreateFrame("Frame", nil, ObjectiveTrackerFrame)
    borderHost:SetAllPoints(ObjectiveTrackerFrame)
    borderHost:SetFrameStrata(ObjectiveTrackerFrame:GetFrameStrata())
    borderHost:SetFrameLevel((ObjectiveTrackerFrame:GetFrameLevel() or 0) + 60)
    borderHost:EnableMouse(false)
    chrome.borderHost = borderHost

    local borderFrame = CreateFrame("Frame", nil, borderHost, BackdropTemplateMixin and "BackdropTemplate" or nil)
    borderFrame:SetAllPoints(ObjectiveTrackerFrame)
    borderFrame:EnableMouse(false)
    chrome.borderFrame = borderFrame
    chrome.edges = {}
    state.trackerBackgroundChrome = chrome
    return chrome
end

function styleHelpers.ApplyTrackerBackground(tbgStyle)
    local chrome = styleHelpers.EnsureTrackerBackground()
    if not chrome then
        return
    end

    if not tbgStyle or not tbgStyle.enabled then
        chrome.background:Hide()
        if chrome.borderFrame then
            chrome.borderFrame:Hide()
        end
        return
    end

    -- Compute effective height: cap at actual content height so the background
    -- does not extend into the empty space below the last quest/section.
    local frameH = (ObjectiveTrackerFrame.GetHeight and ObjectiveTrackerFrame:GetHeight()) or 0
    local contentH = state.lastContentHeight or 0
    local effectiveH = (contentH > 0) and math.min(contentH, frameH) or frameH

    -- Re-anchor background to the effective height every time so it updates
    -- dynamically when content is added/removed or sections are collapsed.
    chrome.background:ClearAllPoints()
    chrome.background:SetPoint("TOPLEFT",  ObjectiveTrackerFrame, "TOPLEFT",  -K.TRACKER_VISUAL_LEFT_EXTENSION, 0)
    chrome.background:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPRIGHT", 0, 0)
    chrome.background:SetHeight(effectiveH)

    styleHelpers.ApplyTexturePath(chrome.background, tbgStyle.texture)
    styleHelpers.ApplyRegionColor(chrome.background, tbgStyle.backgroundColor)
    local _, borderThickness = styleHelpers.ApplyBackdropBorder(
        chrome.borderFrame,
        chrome.background,
        tbgStyle.borderSize,
        tbgStyle.borderTexture or tbgStyle.texture,
        tbgStyle.borderColor,
        0,
        0
    )
    chrome.background:Show()

    if borderThickness == 0 and chrome.borderFrame then
        chrome.borderFrame:Hide()
    end
end

function styleHelpers.ApplyBlizzardHeaderBackground(frame)
    if not frame or not frame.Background then
        return
    end
    local background = frame.Background
    local atlas = background.GetAtlas and background:GetAtlas() or nil
    if atlas and background.SetAtlas then
        background:SetAtlas(atlas, false)
    end
    styleHelpers.ApplyHeaderVisualExtents(frame, background)
    background:Show()
end

function styleHelpers.ApplyHeaderChrome(frame, appearance)
    local chrome = styleHelpers.EnsureFrameChrome(frame)
    if not chrome then
        return
    end

    local useNomTools = appearance and appearance.useNomTools == true
    if not useNomTools then
        styleHelpers.SetRegionShown(chrome.background, false)
        if chrome.borderFrame then
            chrome.borderFrame:Hide()
        end
        return
    end

    if frame.Background then
        styleHelpers.SetRegionShown(frame.Background, false)
    end

    styleHelpers.ApplyHeaderChromeExtents(frame, chrome)
    styleHelpers.ApplyTexturePath(chrome.background, appearance.texture)
    styleHelpers.ApplyRegionColor(chrome.background, appearance.backgroundColor)
    local _, borderThickness = styleHelpers.ApplyBackdropBorder(
        chrome.borderFrame,
        chrome.background,
        appearance.borderSize,
        appearance.borderTexture or appearance.texture,
        appearance.borderColor,
        0,
        0
    )
    chrome.background:Show()

    if borderThickness == 0 and chrome.borderFrame then
        chrome.borderFrame:Hide()
    end
end

function styleHelpers.SetUIPanelButtonArtVisible(button, visible)
    if not button then
        return
    end

    local alpha = visible and 1 or 0
    for _, key in ipairs(K.UIPANEL_BUTTON_ART_REGION_KEYS) do
        local region = button[key]
        if region and region.SetAlpha then
            region:SetAlpha(alpha)
        end
    end

    for _, texture in ipairs({
        button.GetNormalTexture and button:GetNormalTexture() or nil,
        button.GetPushedTexture and button:GetPushedTexture() or nil,
        button.GetHighlightTexture and button:GetHighlightTexture() or nil,
        button.GetDisabledTexture and button:GetDisabledTexture() or nil,
    }) do
        if texture and texture.SetAlpha then
            texture:SetAlpha(alpha)
        end
    end
end

-- Like SetUIPanelButtonArtVisible but preserves the NormalTexture/PushedTexture icon.
-- Used for MinimizeButtons where the -/+ icon must remain visible.
function styleHelpers.SetMinimizeButtonBorderVisible(button, visible)
    if not button then
        return
    end

    local alpha = visible and 1 or 0
    for _, key in ipairs(K.UIPANEL_BUTTON_ART_REGION_KEYS) do
        local region = button[key]
        if region and region.SetAlpha then
            region:SetAlpha(alpha)
        end
    end
end

-- Creates an OVERLAY-layer chrome + HIGHLIGHT-layer icon label on a minimize button.
-- This is necessary because the standard EnsureFrameChrome background sits at BACKGROUND -8
-- and border edges at BORDER â€” both below ARTWORK where the button's NormalTexture lives.
-- The overlay approach draws above the NormalTexture and fully controls the visual.
function styleHelpers.EnsureMinimizeButtonOverlay(button)
    if not button then
        return nil
    end
    if button.NomToolsMinimizeOverlay then
        return button.NomToolsMinimizeOverlay
    end

    local overlay = {}

    local bg = button:CreateTexture(nil, "OVERLAY", nil, -2)
    bg:SetAllPoints()
    overlay.background = bg

    local borderFrame = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate" or nil)
    borderFrame:SetAllPoints(button)
    borderFrame:SetFrameStrata(button:GetFrameStrata())
    borderFrame:SetFrameLevel((button:GetFrameLevel() or 0) + 2)
    borderFrame:EnableMouse(false)
    overlay.borderFrame = borderFrame
    overlay.edges = {}

    local icon = button:CreateFontString(nil, "OVERLAY", nil)
    icon:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    icon:SetAllPoints()
    icon:SetJustifyH("CENTER")
    icon:SetJustifyV("MIDDLE")
    overlay.icon = icon

    button.NomToolsMinimizeOverlay = overlay
    return overlay
end

function styleHelpers.ApplyMinimizeButtonChrome(button, appearance, isCollapsed)
    if not button then
        return
    end

    local overlay = styleHelpers.EnsureMinimizeButtonOverlay(button)
    if not overlay then
        return
    end

    local useNomTools = appearance and appearance.useNomTools == true

    local normalTex   = button.GetNormalTexture   and button:GetNormalTexture()   or nil
    local pushedTex   = button.GetPushedTexture   and button:GetPushedTexture()   or nil
    local highlightTex = button.GetHighlightTexture and button:GetHighlightTexture() or nil

    if not useNomTools then
        if normalTex   then normalTex:SetAlpha(1)   end
        if pushedTex   then pushedTex:SetAlpha(1)   end
        if highlightTex then highlightTex:SetAlpha(1) end
        overlay.background:Hide()
        if overlay.borderFrame then overlay.borderFrame:Hide() end
        overlay.icon:Hide()
        return
    end

    if normalTex   then normalTex:SetAlpha(0)   end
    if pushedTex   then pushedTex:SetAlpha(0)   end
    if highlightTex then highlightTex:SetAlpha(0) end

    styleHelpers.ApplyTexturePath(overlay.background, appearance.texture)
    styleHelpers.ApplyRegionColor(overlay.background, appearance.backgroundColor)
    local _, borderThickness = styleHelpers.ApplyBackdropBorder(
        overlay.borderFrame,
        button,
        appearance.borderSize,
        appearance.borderTexture or appearance.texture,
        appearance.borderColor,
        0,
        0
    )
    overlay.background:Show()

    if borderThickness == 0 and overlay.borderFrame then
        overlay.borderFrame:Hide()
    end

    overlay.icon:SetTextColor(1, 1, 1, 1)
    overlay.icon:SetText(isCollapsed and "+" or "-")
    overlay.icon:Show()
end

function styleHelpers.IsCompleteColorStyle(colorStyle)
    if not colorStyle then
        return false
    end

    if colorStyle.nomtoolsIsComplete ~= nil then
        return colorStyle.nomtoolsIsComplete == true
    end

    local completeStyle = OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR.Complete or nil
    if not completeStyle then
        return false
    end

    return colorStyle == completeStyle
        or colorStyle == completeStyle.reverse
        or completeStyle == colorStyle.reverse
end

    function styleHelpers.ForEachBlockLine(block, callback)
    if not block or type(callback) ~= "function" then
        return
    end

    if block.ForEachUsedLine then
        block:ForEachUsedLine(callback)
        return
    end

    if type(block.usedLines) == "table" then
        for line in pairs(block.usedLines) do
            callback(line)
        end
    end
end

local forEachBlockSeen = {}
local currentBlockCallback = nil

local function VisitBlockShared(block)
    if block and not forEachBlockSeen[block] and (not block.IsShown or block:IsShown()) then
        forEachBlockSeen[block] = true
        currentBlockCallback(block)
    end
end

function styleHelpers.ForEachModuleBlock(module, callback)
    if not module or type(callback) ~= "function" then
        return
    end

    local seen = forEachBlockSeen
    for k in pairs(seen) do seen[k] = nil end
    currentBlockCallback = callback

    if module.EnumerateActiveBlocks then
        module:EnumerateActiveBlocks(VisitBlockShared)
    elseif type(module.usedBlocks) == "table" then
        for _, blocksByID in pairs(module.usedBlocks) do
            if type(blocksByID) == "table" then
                for _, block in pairs(blocksByID) do
                    VisitBlockShared(block)
                end
            end
        end
    end

    if type(module.FixedBlocks) == "table" then
        for _, block in ipairs(module.FixedBlocks) do
            VisitBlockShared(block)
        end
    end
end

local collectProgressBarsScratch = {}
local collectProgressBarsSeen = {}

local function AddProgressBarShared(progressBar)
    if progressBar and not collectProgressBarsSeen[progressBar] then
        collectProgressBarsSeen[progressBar] = true
        collectProgressBarsScratch[#collectProgressBarsScratch + 1] = progressBar
    end
end

local function CollectLineProgressBarsCallback(line)
    AddProgressBarShared(line and line.progressBar or nil)
    AddProgressBarShared(line and line.statusBar or nil)
    AddProgressBarShared(line and line.ProgressBar or nil)
    AddProgressBarShared(line and line.StatusBar or nil)
    AddProgressBarShared(line and line.Bar or nil)
end

function styleHelpers.CollectBlockProgressBars(block)
    local progressBars = collectProgressBarsScratch
    for k in pairs(progressBars) do progressBars[k] = nil end
    local seen = collectProgressBarsSeen
    for k in pairs(seen) do seen[k] = nil end

    if not block then
        return progressBars
    end

    AddProgressBarShared(block.progressBar)
    AddProgressBarShared(block.statusBar)
    AddProgressBarShared(block.ProgressBar)
    AddProgressBarShared(block.StatusBar)
    AddProgressBarShared(block.Bar)

    styleHelpers.ForEachBlockLine(block, CollectLineProgressBarsCallback)

    return progressBars
end

local forEachProgressBarSeen = {}
local currentProgressBarCallback = nil

local function VisitProgressBarShared(progressBar)
    if progressBar and not forEachProgressBarSeen[progressBar] and (not progressBar.IsShown or progressBar:IsShown()) then
        forEachProgressBarSeen[progressBar] = true
        currentProgressBarCallback(progressBar)
    end
end

local function ForEachProgressBarBlockCallback(block)
    for _, progressBar in ipairs(styleHelpers.CollectBlockProgressBars(block)) do
        VisitProgressBarShared(progressBar)
    end
end

function styleHelpers.ForEachModuleProgressBar(module, callback)
    if not module or type(callback) ~= "function" then
        return
    end

    local seen = forEachProgressBarSeen
    for k in pairs(seen) do seen[k] = nil end
    currentProgressBarCallback = callback

    styleHelpers.ForEachModuleBlock(module, ForEachProgressBarBlockCallback)

    if type(module.usedProgressBars) == "table" then
        for _, progressBar in pairs(module.usedProgressBars) do
            VisitProgressBarShared(progressBar)
        end
    end
end

function styleHelpers.GetBlockQuestID(block)
    local questID = block and (block.id or block.questID or block.poiQuestID) or nil
    if type(questID) == "number" and questID > 0 then
        return questID
    end

    return nil
end

function styleHelpers.GetQuestBackedBlockQuestID(block, module)
    if not block then
        return nil
    end

    local resolvedModule = module or block.parentModule
    if block.nomtoolsQuestKind == nil and not IsQuestLikeModule(resolvedModule) then
        return nil
    end

    return styleHelpers.GetBlockQuestID(block)
end

function styleHelpers.GetLineCompletionFromQuestData(line, block)
    if not line then
        return nil
    end

    local questID = styleHelpers.GetQuestBackedBlockQuestID(block)
    local objectiveIndex = tonumber(line.objectiveKey)
    if not questID or not objectiveIndex or objectiveIndex < 1 then
        return nil
    end

    if GetQuestObjectiveInfo then
        local _, _, finished = GetQuestObjectiveInfo(questID, objectiveIndex, false)
        if finished ~= nil then
            return finished == true
        end
    end

    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local objectives = C_QuestLog.GetQuestObjectives(questID)
        local objective = objectives and objectives[objectiveIndex]
        if objective and objective.finished ~= nil then
            return objective.finished == true
        end
    end

    return nil
end

function styleHelpers.IsLineCompleted(line, block)
    if not line then
        return false
    end

    if line.objectiveKey == "QuestComplete" or line.objectiveKey == "ClickComplete" then
        return true
    end

    local objectiveCompleted = styleHelpers.GetLineCompletionFromQuestData(line, block)
    if objectiveCompleted ~= nil then
        return objectiveCompleted
    end

    if line.finished ~= nil then
        return line.finished == true
    end

    if ObjectiveTrackerAnimLineState and line.state then
        if line.state == ObjectiveTrackerAnimLineState.Completed
            or line.state == ObjectiveTrackerAnimLineState.Completing
            or line.state == ObjectiveTrackerAnimLineState.Fading
        then
            return true
        end

        if line.state == ObjectiveTrackerAnimLineState.Present
            or line.state == ObjectiveTrackerAnimLineState.Adding
            or line.state == ObjectiveTrackerAnimLineState.Faded
        then
            return false
        end
    end

    return false
end

function styleHelpers.IsProgressBarCompleted(progressBar)
    local statusBar = progressBar and (progressBar.Bar or progressBar) or nil
    if not statusBar or not statusBar.GetMinMaxValues or not statusBar.GetValue then
        return false
    end

    local minValue, maxValue = statusBar:GetMinMaxValues()
    local resolvedMinValue = tonumber(minValue) or 0
    local resolvedMaxValue = tonumber(maxValue)
    if not resolvedMaxValue or resolvedMaxValue <= resolvedMinValue then
        return false
    end

    return (tonumber(statusBar:GetValue()) or resolvedMinValue) >= resolvedMaxValue
end

function styleHelpers.GetProgressBarPercent(progressBar)
    local statusBar = progressBar and (progressBar.Bar or progressBar) or nil
    if not statusBar or not statusBar.GetMinMaxValues or not statusBar.GetValue then
        return nil
    end

    local minValue, maxValue = statusBar:GetMinMaxValues()
    local resolvedMinValue = tonumber(minValue) or 0
    local resolvedMaxValue = tonumber(maxValue)
    if not resolvedMaxValue or resolvedMaxValue <= resolvedMinValue then
        return nil
    end

    local value = tonumber(statusBar:GetValue()) or resolvedMinValue
    return Clamp((value - resolvedMinValue) / (resolvedMaxValue - resolvedMinValue), 0, 1)
end

function styleHelpers.GetProgressBarFillColor(progressBar, styles)
    if not styles then
        return K.DEFAULT_PROGRESS_FILL_COLOR
    end

    if styles.progressFillMode ~= "progress" then
        return styles.progressFillColor
    end

    local progressPercent = styleHelpers.GetProgressBarPercent(progressBar)
    if not progressPercent then
        return styles.progressFillColor
    end

    if progressPercent < 0.33 then
        return styles.progressLowFillColor
    end

    if progressPercent < 0.66 then
        return styles.progressMediumFillColor
    end

    return styles.progressHighFillColor
end

function styleHelpers.EnsureCustomProgressBarBorder(progressBar, statusBar)
    if not progressBar or not statusBar then
        return nil
    end

    local parent = progressBar ~= statusBar and progressBar or statusBar
    if parent.NomToolsCustomBorder then
        return parent.NomToolsCustomBorder
    end

    local border = CreateFrame("Frame", nil, parent)
    border:SetFrameStrata(parent:GetFrameStrata())
    border:SetFrameLevel(math.max(parent:GetFrameLevel() or 0, statusBar:GetFrameLevel() or 0) + 30)
    parent.NomToolsCustomBorder = border
    if border.SetBackdrop == nil and BackdropTemplateMixin then
        Mixin(border, BackdropTemplateMixin)
    end

    return border
end

function styleHelpers.SetCustomProgressBarBorderThickness(border, statusBar, thickness)
    if not border or not statusBar then
        return
    end

    local signedSize = NormalizeBorderSize(thickness, K.DEFAULT_PROGRESS_BORDER_SIZE, K.MIN_PROGRESS_BORDER_SIZE, K.MAX_PROGRESS_BORDER_SIZE)
    local magnitude = math.abs(signedSize)
    local borderStyle = ResolveBackdropBorderStyle(border.texturePath or BORDER_TEXTURE_FALLBACK_PATH, magnitude)
    local _, _, renderedEdgeSize = styleHelpers.ApplyBackdropBorderLayout(
        border,
        statusBar,
        signedSize,
        borderStyle.edgeSize,
        borderStyle.baseEdgeSize,
        0,
        0
    )
    border.thickness = renderedEdgeSize
    border.signedThickness = signedSize
end

function styleHelpers.HideCustomProgressBarBorder(progressBar, statusBar)
    local parent = progressBar ~= statusBar and progressBar or statusBar
    local border = parent and parent.NomToolsCustomBorder or nil
    if border then
        border:Hide()
    end

    return border
end

function styleHelpers.ApplyCustomProgressBarBorder(progressBar, statusBar, color, texturePath, thickness)
    local signedSize = NormalizeBorderSize(thickness, K.DEFAULT_PROGRESS_BORDER_SIZE, K.MIN_PROGRESS_BORDER_SIZE, K.MAX_PROGRESS_BORDER_SIZE)
    if signedSize == 0 then
        styleHelpers.HideCustomProgressBarBorder(progressBar, statusBar)
        return
    end

    local border = styleHelpers.EnsureCustomProgressBarBorder(progressBar, statusBar)
    if not border then
        return
    end

    border.texturePath = texturePath or BORDER_TEXTURE_FALLBACK_PATH
    styleHelpers.ApplyBackdropBorder(border, statusBar, signedSize, border.texturePath, color, 0, 0)
    border:Show()
end

function styleHelpers.CaptureTextureRegionState(region)
    if not region then
        return nil
    end

    local state = {
        atlas = region.GetAtlas and region:GetAtlas() or nil,
        texture = region.GetTexture and region:GetTexture() or nil,
        shown = region.IsShown and region:IsShown() or nil,
    }

    if region.GetVertexColor then
        local r, g, b, a = region:GetVertexColor()
        state.color = { r = r, g = g, b = b, a = a }
    end

    return state
end

function styleHelpers.RestoreTextureRegionState(region, state)
    if not region or not state then
        return
    end

    if state.atlas and region.SetAtlas then
        region:SetAtlas(state.atlas, false)
    elseif region.SetTexture then
        region:SetTexture(state.texture)
    end

    if state.color and region.SetVertexColor then
        region:SetVertexColor(state.color.r, state.color.g, state.color.b, state.color.a)
    end

    if state.shown ~= nil and region.SetShown then
        region:SetShown(state.shown)
    end
end

function styleHelpers.CaptureFontStringState(fontString)
    if not fontString then
        return nil
    end

    local fontPath, fontSize, fontOutline
    if fontString.GetFont then
        fontPath, fontSize, fontOutline = fontString:GetFont()
    end

    local r, g, b, a = 1, 1, 1, 1
    if fontString.GetTextColor then
        r, g, b, a = fontString:GetTextColor()
    end

    return {
        fontPath = fontPath,
        fontSize = fontSize,
        fontOutline = fontOutline,
        color = { r = r, g = g, b = b, a = a },
        shown = fontString.IsShown and fontString:IsShown() or nil,
    }
end

function styleHelpers.RestoreFontStringState(fontString, state)
    if not fontString or not state then
        return
    end

    if state.fontPath and fontString.SetFont then
        fontString:SetFont(state.fontPath, state.fontSize or 13, state.fontOutline or "")
    end

    if state.color and fontString.SetTextColor then
        fontString:SetTextColor(state.color.r, state.color.g, state.color.b, state.color.a)
    end

    if state.shown ~= nil and fontString.SetShown then
        fontString:SetShown(state.shown)
    end
end

function styleHelpers.CaptureProgressBarStyleState(progressBar, statusBar)
    if not progressBar or not statusBar then
        return nil
    end

    if progressBar.nomtoolsOriginalStyleState then
        return progressBar.nomtoolsOriginalStyleState
    end

    local statusBarTexture = statusBar.GetStatusBarTexture and statusBar:GetStatusBarTexture() or nil
    local rewardIconExclusion = statusBar.Icon
    local backgroundRegions = {
        statusBar.BarBG,
        statusBar.Background,
        statusBar.BG,
        progressBar.BarBG,
        progressBar.Background,
        progressBar.BG,
    }
    for _, region in ipairs(styleHelpers.GetStatusBarAnonymousRegions(statusBar, statusBarTexture, "BACKGROUND", -1)) do
        if region ~= rewardIconExclusion then
            backgroundRegions[#backgroundRegions + 1] = region
        end
    end

    local borderRegions = {
        statusBar.BarFrame,
        statusBar.BarFrame2,
        statusBar.BarFrame3,
        statusBar.BorderLeft,
        statusBar.BorderMid,
        statusBar.BorderRight,
        statusBar.LeftBorder,
        statusBar.MiddleBorder,
        statusBar.RightBorder,
    }

    local glowRegions = {
        statusBar.Sheen,
        statusBar.Starburst,
    }

    local function CaptureRegionList(regions)
        local captured = {}
        local seen = {}
        for _, region in ipairs(regions) do
            if region and not seen[region] then
                seen[region] = true
                captured[#captured + 1] = {
                    region = region,
                    state = styleHelpers.CaptureTextureRegionState(region),
                }
            end
        end
        return captured
    end

    local state = {
        statusBarTexturePath = statusBarTexture and statusBarTexture.GetTexture and statusBarTexture:GetTexture() or nil,
        statusBarTextureState = styleHelpers.CaptureTextureRegionState(statusBarTexture),
        backgroundRegions = CaptureRegionList(backgroundRegions),
        borderRegions = CaptureRegionList(borderRegions),
        glowRegions = CaptureRegionList(glowRegions),
        label = (function()
            local label = statusBar.Label or statusBar.TimeLeft or progressBar.Label or progressBar.TimeLeft
            if not label then
                return nil
            end

            return {
                fontString = label,
                state = styleHelpers.CaptureFontStringState(label),
            }
        end)(),
        rewardIcon = (function()
            if not statusBar.Icon then
                return nil
            end

            return {
                onEnter = statusBar.Icon.GetScript and statusBar.Icon:GetScript("OnEnter") or nil,
                onLeave = statusBar.Icon.GetScript and statusBar.Icon:GetScript("OnLeave") or nil,
                mouseEnabled = statusBar.Icon.IsMouseEnabled and statusBar.Icon:IsMouseEnabled() or nil,
            }
        end)(),
    }

    if statusBar.GetStatusBarColor then
        local r, g, b, a = statusBar:GetStatusBarColor()
        state.statusBarColor = { r = r, g = g, b = b, a = a }
    end

    progressBar.nomtoolsOriginalStyleState = state
    return state
end

function styleHelpers.RestoreProgressBarStyle(progressBar, keepRewardTooltip)
    if not progressBar then
        return
    end

    local statusBar = progressBar.Bar or progressBar
    local state = progressBar.nomtoolsOriginalStyleState
    if not statusBar or not state then
        return
    end

    if state.statusBarTexturePath and statusBar.SetStatusBarTexture then
        statusBar:SetStatusBarTexture(state.statusBarTexturePath)
    end

    if state.statusBarColor and statusBar.SetStatusBarColor then
        statusBar:SetStatusBarColor(
            state.statusBarColor.r,
            state.statusBarColor.g,
            state.statusBarColor.b,
            state.statusBarColor.a
        )
    end

    local currentStatusBarTexture = statusBar.GetStatusBarTexture and statusBar:GetStatusBarTexture() or nil
    styleHelpers.RestoreTextureRegionState(currentStatusBarTexture, state.statusBarTextureState)

    for _, entry in ipairs(state.backgroundRegions or {}) do
        styleHelpers.RestoreTextureRegionState(entry.region, entry.state)
    end
    for _, entry in ipairs(state.borderRegions or {}) do
        styleHelpers.RestoreTextureRegionState(entry.region, entry.state)
    end
    for _, entry in ipairs(state.glowRegions or {}) do
        styleHelpers.RestoreTextureRegionState(entry.region, entry.state)
    end

    styleHelpers.HideCustomProgressBarBorder(progressBar, statusBar)

    if progressBar.UpdateReward then
        progressBar:UpdateReward()
    elseif statusBar.Icon then
        statusBar.Icon:Show()
        if statusBar.IconBG then
            statusBar.IconBG:Show()
        end
    end

    progressBar.nomtoolsCachedRewardTexture = nil
    progressBar.nomtoolsCachedRewardQuestID = nil

    if state.rewardIcon and statusBar.Icon then
        if statusBar.Icon.SetScript then
            statusBar.Icon:SetScript("OnEnter", state.rewardIcon.onEnter)
            statusBar.Icon:SetScript("OnLeave", state.rewardIcon.onLeave)
        end
        if state.rewardIcon.mouseEnabled ~= nil and statusBar.Icon.EnableMouse then
            statusBar.Icon:EnableMouse(state.rewardIcon.mouseEnabled)
        end
    end
    progressBar.nomtoolsIconHookInstalled = false

    if keepRewardTooltip
        and statusBar.Icon
        and state.rewardIcon
        and not state.rewardIcon.onEnter
        and not state.rewardIcon.onLeave
    then
        styleHelpers.InstallProgressBarRewardTooltip(progressBar, statusBar)
    end

    if state.label then
        styleHelpers.RestoreFontStringState(state.label.fontString, state.label.state)
    end

    progressBar.nomtoolsCustomStyleApplied = false
end

function styleHelpers.InstallProgressBarRewardTooltip(progressBar, statusBar)
    if not progressBar or not statusBar or not statusBar.Icon or progressBar.nomtoolsIconHookInstalled then
        return false
    end

    statusBar.Icon:EnableMouse(true)
    statusBar.Icon:SetScript("OnEnter", function()
        local qid = progressBar.questID
        if not qid then return end
        local block = progressBar.parentLine and progressBar.parentLine.parentBlock
        local isWorldQuest = block and block.parentModule and block.parentModule.showWorldQuests
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPRIGHT", statusBar.Icon, "TOPLEFT", 0, 0)
        GameTooltip:SetOwner(progressBar, "ANCHOR_PRESERVE")
        if HaveQuestRewardData(qid) then
            if isWorldQuest then
                QuestUtils_AddQuestTypeToTooltip(GameTooltip, qid, NORMAL_FONT_COLOR)
                GameTooltip:AddLine(REWARDS, NORMAL_FONT_COLOR:GetRGB())
            else
                GameTooltip:SetText(REWARDS, NORMAL_FONT_COLOR:GetRGB())
            end
            GameTooltip:AddLine(isWorldQuest and WORLD_QUEST_TOOLTIP_DESCRIPTION or BONUS_OBJECTIVE_TOOLTIP_DESCRIPTION, 1, 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip_AddQuestRewardsToTooltip(GameTooltip, qid, TOOLTIP_QUEST_REWARDS_STYLE_NONE)
            GameTooltip_SetTooltipWaitingForData(GameTooltip, false)
        else
            GameTooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
            GameTooltip_SetTooltipWaitingForData(GameTooltip, true)
        end
        GameTooltip:Show()
    end)
    statusBar.Icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    progressBar.nomtoolsIconHookInstalled = true
    return true
end

function styleHelpers.IsBlockCompleted(block)
    if not block then
        return false
    end

    local questID = styleHelpers.GetQuestBackedBlockQuestID(block)
    if questID and C_QuestLog and C_QuestLog.IsComplete then
        local isComplete = C_QuestLog.IsComplete(questID)
        if isComplete ~= nil then
            return isComplete == true
        end
    end

    local hasLines = false
    local allLinesComplete = true
    styleHelpers.ForEachBlockLine(block, function(line)
        if line and (not line.IsShown or line:IsShown()) then
            hasLines = true
            if not styleHelpers.IsLineCompleted(line, block) then
                allLinesComplete = false
            end
        end
    end)
    if hasLines then
        return allLinesComplete
    end

    for _, progressBar in ipairs(styleHelpers.CollectBlockProgressBars(block)) do
        if styleHelpers.IsProgressBarCompleted(progressBar) then
            return true
        end
    end

    return false
end

function styleHelpers.IsQuestReadyForTurnIn(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.ReadyForTurnIn then
        local readyForTurnIn = C_QuestLog.ReadyForTurnIn(questID)
        if readyForTurnIn ~= nil then
            return readyForTurnIn == true
        end
    end

    if C_QuestLog and C_QuestLog.IsComplete then
        local isComplete = C_QuestLog.IsComplete(questID)
        if isComplete ~= nil then
            return isComplete == true
        end
    end

    return false
end

function styleHelpers.RefreshQuestBlockPOI(block, module)
    if not block or not block.SetPOIInfo then
        return
    end

    local questID = styleHelpers.GetQuestBackedBlockQuestID(block, module)
    if not questID then
        return
    end

    local questKind = block.nomtoolsQuestKind or GetQuestKind(questID)
    if questKind ~= "quest" and questKind ~= "campaign" and questKind ~= "worldQuest" then
        return
    end

    local isSuperTracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and questID == C_SuperTrack.GetSuperTrackedQuestID() or false
    block:SetPOIInfo(questID, styleHelpers.IsQuestReadyForTurnIn(questID), isSuperTracked, questKind == "worldQuest")

    if questKind == "worldQuest" and block.poiButton and block.poiButton.SetMapPinInfo and block.poiButton.SetStyle then
        block.poiButton:SetMapPinInfo(nil)
        block.poiButton:SetStyle(POIButtonUtil.Style.WorldQuest)
        block.poiButton:UpdateButtonStyle()
    end
end

function styleHelpers.GetQuestTitleColorOverride(questID, styles, isHighlighted)
    if not questID or not styles then
        return nil
    end

    local color
    if IsPreyQuest(questID) then
        color = styles.preyTitleColor
    elseif IsTrivialQuest(questID) and styles.useTrivialTitleColor and not IsCampaignQuest(questID) then
        color = styles.trivialTitleColor
    else
        local recurringType = GetRecurringQuestType(questID)
        if recurringType == "weekly" then
            color = styles.weeklyTitleColor
        elseif recurringType == "daily" then
            color = styles.dailyTitleColor
        else
            local classification = GetQuestClassification(questID)
            if Enum
                and Enum.QuestClassification
                and Enum.QuestClassification.Meta ~= nil
                and classification == Enum.QuestClassification.Meta
            then
                color = styles.metaTitleColor
            elseif classification == Enum.QuestClassification.Legendary then
                color = styles.legendaryTitleColor
            elseif classification == Enum.QuestClassification.Campaign then
                color = styles.campaignTitleColor
            elseif Enum
                and Enum.QuestClassification
                and Enum.QuestClassification.Important ~= nil
                and classification == Enum.QuestClassification.Important
            then
                color = styles.importantTitleColor
            end
        end
    end

    if not color then
        return nil
    end

    if isHighlighted then
        return GetHoverColor(color)
    end

    return color
end

function styleHelpers.GetQuestKindTitleColorOverride(questKind, styles, isHighlighted)
    local color = GetQuestKindTitleColor(questKind, styles, false)
    if not color then
        return nil
    end

    if isHighlighted then
        return GetQuestKindTitleColor(questKind, styles, true) or GetHoverColor(color)
    end

    return color
end

function styleHelpers.EnsureWarbandIndicator(block)
    if not block then
        return nil
    end

    if block.NomToolsWarbandIndicator then
        return block.NomToolsWarbandIndicator
    end

    local indicator = CreateFrame("Frame", nil, block)
    indicator:SetSize(K.WARBAND_COMPLETION_ICON_SIZE, K.WARBAND_COMPLETION_ICON_SIZE)
    indicator:SetFrameStrata(block:GetFrameStrata())
    indicator:SetFrameLevel((block:GetFrameLevel() or 0) + 8)
    indicator:EnableMouse(true)
    indicator:SetHitRectInsets(-2, -2, -2, -2)

    local icon = indicator:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    indicator.Icon = icon

    local check = indicator:CreateTexture(nil, "OVERLAY")
    check:SetSize(12, 12)
    check:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", 2, -1)
    indicator.Check = check

    indicator:SetScript("OnEnter", function(self)
        if not self.questID then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_AddHighlightLine(GameTooltip, K.WARBAND_COMPLETION_TOOLTIP)
        GameTooltip:Show()
    end)
    indicator:SetScript("OnLeave", GameTooltip_Hide)
    indicator:Hide()

    if indicator.SetPropagateMouseClicks then
        indicator:SetPropagateMouseClicks(true)
    end

    block.NomToolsWarbandIndicator = indicator
    return indicator
end

function styleHelpers.UpdateWarbandIndicator(block, questID, module)
        if not block or not block.HeaderText then
        return
    end

    local shouldShow = ShouldShowWarbandCompletedIndicator(questID, module)
        local indicator = block.NomToolsWarbandIndicator
        if not shouldShow then
            if indicator then
                indicator.questID = nil
                indicator:Hide()
            end
            return
        end

        indicator = indicator or styleHelpers.EnsureWarbandIndicator(block)
        if not indicator then
            return
        end

    if shouldShow and block.HeaderText:IsShown() then
        local iconAtlas = GetWarbandCompletionAtlas()
        local checkAtlas = GetWarbandCompletionCheckAtlas()
        indicator.questID = questID
        indicator:ClearAllPoints()
        indicator:SetPoint("RIGHT", block.HeaderText, "RIGHT", 0, 0)
        indicator.Icon:SetAtlas(iconAtlas, false)
        indicator.Icon:SetSize(K.WARBAND_COMPLETION_ICON_SIZE, K.WARBAND_COMPLETION_ICON_SIZE)
        if checkAtlas then
            indicator.Check:SetAtlas(checkAtlas, false)
            indicator.Check:Show()
        else
            indicator.Check:Hide()
        end
        indicator:Show()
    else
        indicator.questID = nil
        indicator:Hide()
    end
end

function styleHelpers.ApplyProgressBarStyle(progressBar, styles)
    if not progressBar or not styles then
        return
    end

    local statusBar = progressBar.Bar or progressBar
    if not statusBar then
        return
    end

    if styles.progressUseNomTools ~= true then
        if progressBar.nomtoolsCustomStyleApplied then
            styleHelpers.RestoreProgressBarStyle(progressBar, true)
        elseif statusBar.Icon and not progressBar.nomtoolsIconHookInstalled then
            local rewardState = progressBar.nomtoolsOriginalStyleState and progressBar.nomtoolsOriginalStyleState.rewardIcon or nil
            if not rewardState or (not rewardState.onEnter and not rewardState.onLeave) then
                styleHelpers.InstallProgressBarRewardTooltip(progressBar, statusBar)
            end
        end
        return
    end

    styleHelpers.CaptureProgressBarStyleState(progressBar, statusBar)
    progressBar.nomtoolsCustomStyleApplied = true

    local statusBarTexture = statusBar.GetStatusBarTexture and statusBar:GetStatusBarTexture() or nil
    local fillColor = styleHelpers.GetProgressBarFillColor(progressBar, styles)

    if statusBar.SetStatusBarTexture then
        statusBar:SetStatusBarTexture(styles.progressTexture)
    end
    if statusBar.SetStatusBarColor then
        statusBar:SetStatusBarColor(
            fillColor.r,
            fillColor.g,
            fillColor.b,
            fillColor.a
        )
    end
    styleHelpers.ApplyTexturePath(statusBarTexture, styles.progressTexture)
    styleHelpers.ApplyRegionColor(statusBarTexture, fillColor)

    -- Exclude the reward icon from the anonymous background scan; it lives at
    -- BACKGROUND sublevel -1 alongside BarBG and would be overwritten otherwise.
    local rewardIconExclusion = statusBar.Icon
    local backgroundRegions = {
        statusBar.BarBG,
        statusBar.Background,
        statusBar.BG,
        progressBar.BarBG,
        progressBar.Background,
        progressBar.BG,
    }
    for _, region in ipairs(styleHelpers.GetStatusBarAnonymousRegions(statusBar, statusBarTexture, "BACKGROUND", -1)) do
        if region ~= rewardIconExclusion then
            backgroundRegions[#backgroundRegions + 1] = region
        end
    end
    for _, region in ipairs(backgroundRegions) do
        styleHelpers.ApplyTexturePath(region, styles.progressTexture)
        styleHelpers.ApplyRegionColor(region, styles.progressBackgroundColor)
    end

    -- Re-apply after background pass so Icon texture and visibility aren't clobbered.
    if progressBar.UpdateReward then
        progressBar:UpdateReward()
        -- Cache the reward texture when data is available, and restore it on subsequent
        -- refreshes where HaveQuestRewardData momentarily returns false (prevents flicker).
        if statusBar.Icon then
            local currentQuestID = progressBar.questID
            if statusBar.Icon:IsShown() then
                progressBar.nomtoolsCachedRewardTexture = statusBar.Icon:GetTexture()
                progressBar.nomtoolsCachedRewardQuestID = currentQuestID
            elseif progressBar.nomtoolsCachedRewardTexture
                   and progressBar.nomtoolsCachedRewardQuestID == currentQuestID then
                statusBar.Icon:SetTexture(progressBar.nomtoolsCachedRewardTexture)
                statusBar.Icon:Show()
                if statusBar.IconBG then statusBar.IconBG:Show() end
            end
        end

        -- Honour the "Hide Reward Icon" setting.
        if styles.progressHideRewardIcon and statusBar.Icon then
            statusBar.Icon:Hide()
            if statusBar.IconBG then statusBar.IconBG:Hide() end
            progressBar.nomtoolsCachedRewardTexture = nil
            progressBar.nomtoolsCachedRewardQuestID = nil
        end
    end

    -- Install reward icon hover tooltip once per pooled progress bar frame.
    if statusBar.Icon and not progressBar.nomtoolsIconHookInstalled and not styles.progressHideRewardIcon then
        styleHelpers.InstallProgressBarRewardTooltip(progressBar, statusBar)
    end

    local borderRegions = {
        statusBar.BarFrame,
        statusBar.BarFrame2,
        statusBar.BarFrame3,
        statusBar.BorderLeft,
        statusBar.BorderMid,
        statusBar.BorderRight,
        statusBar.LeftBorder,
        statusBar.MiddleBorder,
        statusBar.RightBorder,
    }
    local hiddenBorderColor = {
        r = styles.progressBorderColor.r,
        g = styles.progressBorderColor.g,
        b = styles.progressBorderColor.b,
        a = 0,
    }
    for _, region in ipairs(borderRegions) do
        styleHelpers.ApplyRegionColor(region, hiddenBorderColor)
    end

    local glowRegions = {
        statusBar.Sheen,
        statusBar.Starburst,
    }
    for _, region in ipairs(glowRegions) do
        styleHelpers.ApplyRegionColor(region, hiddenBorderColor)
    end

    styleHelpers.ApplyCustomProgressBarBorder(
        progressBar,
        statusBar,
        styles.progressBorderColor,
        styles.progressBorderTexture,
        styles.progressBorderSize
    )

    local label = statusBar.Label or statusBar.TimeLeft or progressBar.Label or progressBar.TimeLeft
    if label then
        styleHelpers.SetFontAppearance(label, styles.fontPath, styles.fontSize, styles.fontOutline)
        styleHelpers.ApplyRegionColor(label, styleHelpers.IsProgressBarCompleted(progressBar) and styles.completedColor or styles.uncompletedColor)
    end
end

ShouldApplyModuleContentStyling = function(module)
    return module ~= UIWidgetObjectiveTracker
end

function styleHelpers.ApplyLineStyle(line, styles, block)
    if not line or not styles then
        return
    end

    if line and line.Text then
        line.Text.nomtoolsColorStyle = nil
    end

    local isCompleted = styleHelpers.IsLineCompleted(line, block)
    local colorStyle = isCompleted and styles.completedStyle or styles.uncompletedStyle
    local color = (block and block.isHighlighted and colorStyle.reverse) or colorStyle

    if line.Text then
        styleHelpers.SetFontAppearance(line.Text, styles.fontPath, styles.fontSize, styles.fontOutline)
        styleHelpers.ApplyFontStringColorStyle(line.Text, colorStyle, block and block.isHighlighted)
    end

    styleHelpers.ApplyRegionColor(line.Dash, color)
end

BuildBlockHeaderColorStyle = function(block, styles, module, questID)
    local headerStyle = styles and styles.defaultHeaderStyle or nil
    local isQuestModule = IsQuestLikeModule(module) or (block and block.nomtoolsQuestKind ~= nil)
    local zoneQuestKind = block and block.nomtoolsQuestKind or nil
    local questKind = isQuestModule and zoneQuestKind or nil

    if isQuestModule and not questKind and questID then
        local derivedQuestKind = GetQuestKind(questID)
        if derivedQuestKind == "quest" or derivedQuestKind == "worldQuest" or derivedQuestKind == "bonusObjective" then
            questKind = derivedQuestKind
        end
    end

    if isQuestModule and questID then
        if IsPreyQuest(questID) then
            headerStyle = styles.preyHeaderStyle or headerStyle
        elseif IsTrivialQuest(questID) and styles.useTrivialTitleColor and not IsCampaignQuest(questID) then
            headerStyle = styles.trivialHeaderStyle or headerStyle
        else
            local recurringType = GetRecurringQuestType(questID)
            if recurringType == "weekly" then
                headerStyle = styles.weeklyHeaderStyle or headerStyle
            elseif recurringType == "daily" then
                headerStyle = styles.dailyHeaderStyle or headerStyle
            else
                local classification = GetQuestClassification(questID)
                if Enum
                    and Enum.QuestClassification
                    and Enum.QuestClassification.Meta ~= nil
                    and classification == Enum.QuestClassification.Meta
                then
                    headerStyle = styles.metaHeaderStyle or headerStyle
                elseif classification == Enum.QuestClassification.Legendary then
                    headerStyle = styles.legendaryHeaderStyle or headerStyle
                elseif classification == Enum.QuestClassification.Campaign then
                    headerStyle = styles.campaignHeaderStyle or headerStyle
                elseif Enum
                    and Enum.QuestClassification
                    and Enum.QuestClassification.Important ~= nil
                    and classification == Enum.QuestClassification.Important
                then
                    headerStyle = styles.importantHeaderStyle or headerStyle
                end
            end
        end
    end

    if headerStyle == styles.defaultHeaderStyle and isQuestModule then
        if questKind == "quest" then
            headerStyle = styles.questHeaderStyle or headerStyle
        elseif questKind == "worldQuest" then
            headerStyle = styles.worldQuestHeaderStyle or headerStyle
        elseif questKind == "bonusObjective" then
            headerStyle = styles.bonusObjectiveHeaderStyle or headerStyle
        end
    end

    return headerStyle
end

function styleHelpers.ReapplyLiveBlockStyle(block)
    if not block or not IsModuleEnabled() then
        return
    end

    local module = block.parentModule
    if not module or module.parentContainer ~= ObjectiveTrackerFrame then
        return
    end

    if not ShouldApplyModuleContentStyling or not ShouldApplyModuleContentStyling(module) then
        return
    end

    local styles = BuildTrackerStyleData and BuildTrackerStyleData() or nil
    if styles and ApplyBlockStyle then
        ApplyBlockStyle(block, styles, module)
    end
end

function styleHelpers.SyncLiveBlockHeaderText(block)
    if not block or not block.HeaderText or not IsModuleEnabled() then
        return
    end

    local module = block.parentModule
    if not module or module.parentContainer ~= ObjectiveTrackerFrame then
        return
    end

    local questID = styleHelpers.GetQuestBackedBlockQuestID(block, module)
    if not questID then
        return
    end

    local currentText = block.HeaderText:GetText()
    local desiredText = BuildQuestHeaderText(questID, currentText)
    if not desiredText or desiredText == currentText then
        return
    end

    block.NomToolsHeaderTextSyncing = true
    block.HeaderText:SetText(desiredText)
    block.NomToolsHeaderTextSyncing = nil
end

local pendingRestyleBlocks = {}
local pendingRestyleScheduled = false

local function RunPendingBlockRestyles()
    pendingRestyleScheduled = false
    for block in pairs(pendingRestyleBlocks) do
        pendingRestyleBlocks[block] = nil
        if block then
            block.NomToolsLiveRestylePending = nil
        end
        if block and block.IsShown and block:IsShown() then
            styleHelpers.ReapplyLiveBlockStyle(block)
        end
    end
end

function styleHelpers.QueueLiveBlockRestyle(block)
    if not block or not C_Timer or not C_Timer.After or block.NomToolsLiveRestylePending then
        return
    end

    block.NomToolsLiveRestylePending = true
    pendingRestyleBlocks[block] = true

    if not pendingRestyleScheduled then
        pendingRestyleScheduled = true
        C_Timer.After(0, RunPendingBlockRestyles)
    end
end

function styleHelpers.HoverStyleUpdater_OnUpdate(self)
    local block = self.block
    if not block or not block.IsShown or not block:IsShown() or not block.isHighlighted then
        self.block = nil
        self:SetScript("OnUpdate", nil)
        return
    end

    styleHelpers.ReapplyLiveBlockStyle(block)
end

function styleHelpers.EnsureHoverStyleUpdater()
    if state.hoverStyleUpdater then
        return state.hoverStyleUpdater
    end

    local updater = CreateFrame("Frame")
    state.hoverStyleUpdater = updater
    return updater
end

function styleHelpers.StartHoverStyleUpdater(block)
    styleHelpers.StopHoverStyleUpdater(block)
end

function styleHelpers.StopHoverStyleUpdater(block)
    local updater = state.hoverStyleUpdater
    if not updater then
        return
    end

    if updater.block == block then
        updater.block = nil
        updater:SetScript("OnUpdate", nil)
    end
end

function styleHelpers.EnsureLiveBlockHooks(block)
    if not block or block.NomToolsLiveHooksInstalled then
        return
    end

    block.NomToolsLiveHooksInstalled = true

    if type(block.UpdateHighlight) == "function" then
        block.NomToolsOriginalUpdateHighlight = block.UpdateHighlight
        block.UpdateHighlight = function(self, ...)
            local result = self.NomToolsOriginalUpdateHighlight(self, ...)
            styleHelpers.ReapplyLiveBlockStyle(self)
            return result
        end
    end

    if block.HeaderText and not block.NomToolsHeaderTextHooksInstalled then
        block.NomToolsHeaderTextHooksInstalled = true

        if type(block.HeaderText.SetText) == "function" then
            hooksecurefunc(block.HeaderText, "SetText", function()
                if block.NomToolsHeaderTextSyncing then
                    return
                end

                styleHelpers.SyncLiveBlockHeaderText(block)
            end)
        end

        if type(block.HeaderText.SetFormattedText) == "function" then
            hooksecurefunc(block.HeaderText, "SetFormattedText", function()
                if block.NomToolsHeaderTextSyncing then
                    return
                end

                styleHelpers.SyncLiveBlockHeaderText(block)
            end)
        end
    end

    if type(block.OnHeaderEnter) == "function" then
        block.NomToolsOriginalOnHeaderEnter = block.OnHeaderEnter
        block.OnHeaderEnter = function(self, ...)
            local result = self.NomToolsOriginalOnHeaderEnter(self, ...)
            styleHelpers.ReapplyLiveBlockStyle(self)
            styleHelpers.QueueLiveBlockRestyle(self)
            styleHelpers.StartHoverStyleUpdater(self)
            return result
        end
    end

    if type(block.OnHeaderLeave) == "function" then
        block.NomToolsOriginalOnHeaderLeave = block.OnHeaderLeave
        block.OnHeaderLeave = function(self, ...)
            local result = self.NomToolsOriginalOnHeaderLeave(self, ...)
            styleHelpers.StopHoverStyleUpdater(self)
            styleHelpers.ReapplyLiveBlockStyle(self)
            styleHelpers.QueueLiveBlockRestyle(self)
            return result
        end
    end
end

-- Hoisted callback for ApplyBlockStyle to avoid per-block closure allocations.
local currentLineStyles = nil
local currentLineBlock = nil

local function ApplyLineStyleCallback(line)
    styleHelpers.ApplyLineStyle(line, currentLineStyles, currentLineBlock)
end

ApplyBlockStyle = function(block, styles, module)
    if not block or not styles then
        return
    end

    if block.HeaderText then
        block.HeaderText.nomtoolsColorStyle = nil
    end

    styleHelpers.EnsureLiveBlockHooks(block)

    local questID = styleHelpers.GetQuestBackedBlockQuestID(block, module)
    if questID then
        styleHelpers.RefreshQuestBlockPOI(block, module)
    end

    if block.HeaderText then
        if questID then
            local headerText = BuildQuestHeaderText(questID, block.HeaderText:GetText())
            if headerText and block.HeaderText:GetText() ~= headerText then
                block.HeaderText:SetText(headerText)
            end
        end

        local headerColorStyle = BuildBlockHeaderColorStyle(block, styles, module, questID)

        styleHelpers.SetFontAppearance(block.HeaderText, styles.fontPath, styles.fontSize, styles.fontOutline)
        styleHelpers.ApplyFontStringColorStyle(block.HeaderText, headerColorStyle, block.isHighlighted)
    end

    styleHelpers.UpdateWarbandIndicator(block, questID, module)

    currentLineStyles = styles
    currentLineBlock = block
    styleHelpers.ForEachBlockLine(block, ApplyLineStyleCallback)
    currentLineStyles = nil
    currentLineBlock = nil
end

-- Hoisted callbacks for ApplyTrackerStyles to avoid per-module closure allocations.
local currentApplyStyles = nil
local currentApplyModule = nil

local function ApplyBlockStyleCallback(block)
    ApplyBlockStyle(block, currentApplyStyles, currentApplyModule)
end

local function ApplyProgressBarStyleCallback(progressBar)
    styleHelpers.ApplyProgressBarStyle(progressBar, currentApplyStyles)
end

ApplyTrackerStyles = function()
    if not ObjectiveTrackerFrame or not IsModuleEnabled() then
        return
    end

    local styles = BuildTrackerStyleData()
    styleHelpers.ApplyTrackerBackground(styles.trackerBackground)
    local typoSigParts = styleSignatureParts
    for k in pairs(typoSigParts) do typoSigParts[k] = nil end
    typoSigParts[1] = tostring(styles.fontPath or "")
    typoSigParts[2] = tostring(styles.fontSize or 13)
    typoSigParts[3] = tostring(styles.fontOutline or "")
    typoSigParts[4] = tostring(styles.levelPrefixMode or "")
    typoSigParts[5] = tostring(styles.showWarbandCompletedIndicator and true or false)
    typoSigParts[6] = tostring(styles.mainHeaderFont and styles.mainHeaderFont.fontSize or "")
    typoSigParts[7] = tostring(styles.categoryHeaderFont and styles.categoryHeaderFont.fontSize or "")
    typoSigParts[8] = tostring(styles.mainHeaderXOffset or 0)
    typoSigParts[9] = tostring(styles.mainHeaderYOffset or 0)
    typoSigParts[10] = tostring(styles.categoryHeaderXOffset or 0)
    typoSigParts[11] = tostring(styles.categoryHeaderYOffset or 0)
    local typographySignature = table.concat(typoSigParts, "|")
    local needsRelayout = state.lastTypographySignature ~= typographySignature
    state.lastTypographySignature = typographySignature
    local mainHdrAppearance    = styles.mainHeaderAppearance
    local catHdrAppearance     = styles.categoryHeaderAppearance
    local btnAppearance        = styles.buttonAppearance
    local useMainNomTools         = mainHdrAppearance and mainHdrAppearance.useNomTools == true
    local useCategoryNomTools     = catHdrAppearance  and catHdrAppearance.useNomTools  == true
    local useButtonNomTools       = btnAppearance     and btnAppearance.useNomTools     == true

    if ObjectiveTrackerFrame.Header then
        -- Blizzard anchors the header's right edge with a built-in inset that reserves
        -- space for its native scroll indicator.  The inset persists whether the
        -- indicator shows or not, and SetWidth() is a no-op on dual-anchored frames.
        -- Force the TOPRIGHT anchor directly so the header always fills the full OTF width.
        local header = ObjectiveTrackerFrame.Header
        local numPoints = header.GetNumPoints and header:GetNumPoints() or 0
        if numPoints >= 2 then
            -- Preserve the TOPLEFT anchor; replace only the right-side anchor.
            header:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPRIGHT", 0, 0)
        else
            local otfWidth = ObjectiveTrackerFrame:GetWidth()
            if otfWidth and otfWidth > 0 then
                header:SetWidth(otfWidth)
            end
        end
        local showBg = IsHeaderBackgroundShown()
        styleHelpers.ApplyHeaderChrome(ObjectiveTrackerFrame.Header, mainHdrAppearance)
        -- If the player disabled the header background, suppress the NomTools chrome too.
        if not showBg then
            local chrome = styleHelpers.EnsureFrameChrome(header)
            if chrome then
                styleHelpers.SetRegionShown(chrome.background, false)
                if chrome.borderFrame then
                    chrome.borderFrame:Hide()
                end
            end
        end
        styleHelpers.SetUIPanelButtonArtVisible(ObjectiveTrackerFrame.Header, not useMainNomTools)
        if ObjectiveTrackerFrame.Header.Background then
            if useMainNomTools or not showBg then
                styleHelpers.SetRegionShown(ObjectiveTrackerFrame.Header.Background, false)
            else
                styleHelpers.ApplyBlizzardHeaderBackground(ObjectiveTrackerFrame.Header)
            end
        end
        if ObjectiveTrackerFrame.Header.MinimizeButton then
            styleHelpers.ApplyHeaderButtonInset(ObjectiveTrackerFrame.Header)
            local trackerCollapsed = ObjectiveTrackerFrame.IsCollapsed and ObjectiveTrackerFrame:IsCollapsed() == true or false
            styleHelpers.ApplyMinimizeButtonChrome(ObjectiveTrackerFrame.Header.MinimizeButton, btnAppearance, trackerCollapsed)
            ObjectiveTrackerFrame.Header.MinimizeButton:SetShown(IsMinimizeButtonEnabled())
        end
    end

    if state.trackerButton then
        styleHelpers.ApplyFrameChrome(state.trackerButton, btnAppearance)
        styleHelpers.SetUIPanelButtonArtVisible(state.trackerButton, not useButtonNomTools)
    end

    local trackerHeaderText = ObjectiveTrackerFrame.Header and (ObjectiveTrackerFrame.Header.Text or ObjectiveTrackerFrame.Header.Title or ObjectiveTrackerFrame.Header.NomToolsTitle) or nil
    if trackerHeaderText then
        local mhFont = styles.mainHeaderFont or {}
        styleHelpers.SetFontAppearance(trackerHeaderText, mhFont.fontPath, mhFont.fontSize, mhFont.fontOutline)
        if mhFont.textColor then
            trackerHeaderText:SetTextColor(mhFont.textColor.r, mhFont.textColor.g, mhFont.textColor.b, mhFont.textColor.a or 1)
        end
        -- Apply per-user x/y text offset anchored to the original Blizzard position.
        local xOff = styles.mainHeaderXOffset or 0
        local yOff = styles.mainHeaderYOffset or 0
        if not trackerHeaderText.nomtoolsOriginalAnchor then
            local pt, rel, relPt, x, y = trackerHeaderText:GetPoint(1)
            if pt then
                trackerHeaderText.nomtoolsOriginalAnchor = { pt, rel, relPt, x or 0, y or 0 }
            end
        end
        if trackerHeaderText.nomtoolsOriginalAnchor then
            local a = trackerHeaderText.nomtoolsOriginalAnchor
            trackerHeaderText:ClearAllPoints()
            trackerHeaderText:SetPoint(a[1], a[2], a[3], a[4] + xOff, a[5] + yOff)
        end
    end

    for _, module in ipairs(GetOrderedContainerModules()) do
        local moduleHeader = module.Header
        if moduleHeader then
            styleHelpers.ApplyModuleHeaderLayout(moduleHeader)
            styleHelpers.ApplyHeaderChrome(moduleHeader, catHdrAppearance)
            styleHelpers.SetUIPanelButtonArtVisible(moduleHeader, not useCategoryNomTools)
            if moduleHeader.Background then
                if useCategoryNomTools then
                    styleHelpers.SetRegionShown(moduleHeader.Background, false)
                else
                    styleHelpers.ApplyBlizzardHeaderBackground(moduleHeader)
                end
            end
            if moduleHeader.MinimizeButton then
                styleHelpers.ApplyHeaderButtonInset(moduleHeader)
                local isCollapsed = module.IsCollapsed and module:IsCollapsed() == true or false
                styleHelpers.ApplyMinimizeButtonChrome(moduleHeader.MinimizeButton, btnAppearance, isCollapsed)
            end
        end

        local moduleHeaderText = moduleHeader and (moduleHeader.Text or moduleHeader.Title) or nil
        if moduleHeaderText then
            local headerText = BuildQuestModuleHeaderText(module, moduleHeaderText:GetText())
            if headerText and moduleHeaderText:GetText() ~= headerText then
                moduleHeaderText:SetText(headerText)
            end
            local chFont = styles.categoryHeaderFont or {}
            styleHelpers.SetFontAppearance(moduleHeaderText, chFont.fontPath, chFont.fontSize, chFont.fontOutline)
            if chFont.textColor then
                moduleHeaderText:SetTextColor(chFont.textColor.r, chFont.textColor.g, chFont.textColor.b, chFont.textColor.a or 1)
            end
            local cxOff = styles.categoryHeaderXOffset or 0
            local cyOff = styles.categoryHeaderYOffset or 0
            if not moduleHeaderText.nomtoolsOriginalAnchor then
                local pt, rel, relPt, x, y = moduleHeaderText:GetPoint(1)
                if pt then
                    moduleHeaderText.nomtoolsOriginalAnchor = { pt, rel, relPt, x or 0, y or 0 }
                end
            end
            if moduleHeaderText.nomtoolsOriginalAnchor then
                local a = moduleHeaderText.nomtoolsOriginalAnchor
                moduleHeaderText:ClearAllPoints()
                moduleHeaderText:SetPoint(a[1], a[2], a[3], a[4] + cxOff, a[5] + cyOff)
            end
        end

        if ShouldApplyModuleContentStyling(module) then
            currentApplyStyles = styles
            currentApplyModule = module
            styleHelpers.ForEachModuleBlock(module, ApplyBlockStyleCallback)
            styleHelpers.ForEachModuleProgressBar(module, ApplyProgressBarStyleCallback)
            currentApplyStyles = nil
            currentApplyModule = nil
        end
    end

    if needsRelayout then
        RequestTrackerLayoutRefresh()
    end
end

end

local function StyleRefreshCallback()
    local shouldCaptureCollapseStates = state.captureCollapseAfterStyleRefresh
    state.trackerStyleRefreshPending = false
    state.captureCollapseAfterStyleRefresh = false
    state.postLayoutStyleDirty = false
    ApplyTrackerStyles()

    if shouldCaptureCollapseStates and state.collapsePersistenceReady and not state.applyingCollapseStates then
        CaptureCurrentSectionCollapseStates()
    end
end

RequestTrackerStyleRefresh = function(captureCollapseStates, immediate)
    if captureCollapseStates then
        state.captureCollapseAfterStyleRefresh = true
    end

    if immediate then
        state.trackerStyleRefreshVersion = state.trackerStyleRefreshVersion + 1
        StyleRefreshCallback()
        return
    end

    if state.trackerStyleRefreshPending then
        return
    end

    state.trackerStyleRefreshPending = true
    state.trackerStyleRefreshVersion = state.trackerStyleRefreshVersion + 1

    if C_Timer and C_Timer.After then
        C_Timer.After(0, StyleRefreshCallback)
    else
        StyleRefreshCallback()
    end
end

local function RunTrackerPostLayout(container)
    if container ~= ObjectiveTrackerFrame then
        return
    end

    if not state.savedCollapseStatesInitialized then
        local changed = ApplySavedSectionCollapseStates()
        if changed then
            RequestTrackerLayoutRefresh()
        else
            state.collapsePersistenceReady = true
        end
    elseif not state.collapsePersistenceReady then
        state.collapsePersistenceReady = true
    end

    if IsModuleEnabled() then
        RefreshTrackerHeader()
    end

    RestorePendingScrollAnchor()
    RefreshScrollState()

    if not IsModuleEnabled() then
        ns.RefreshFilterButton()
        RefreshTrackerButton()
        RefreshQuestLogButton()
        return
    end

    ApplyModuleAnchors()

    if IsModuleEnabled() and not state.sortingInProgress then
        state.sortingInProgress = true
        local sortOk, sortErr = pcall(function()
            local sortingApplied = false
            for _, module in ipairs(GetOrderedContainerModules()) do
                if module and not module.nomtoolsSearchFrame then
                    if ns.SortModuleBlocks(module) then
                        sortingApplied = true
                    end
                end
            end
            -- If sorting changed any module heights, re-anchor modules and
            -- recalculate scroll content height to eliminate gaps.
            if sortingApplied then
                ApplyModuleAnchors()
                RefreshScrollState()
            end
        end)
        state.sortingInProgress = false
        if not sortOk and ns.IsDebugEnabled and ns.IsDebugEnabled() then
            ns.DebugPrint("Sort error: " .. tostring(sortErr))
        end
    end

    ns.RefreshFilterButton()
    RefreshTrackerButton()
    RefreshQuestLogButton()
    RefreshTrackerHeader()

    if state.postLayoutStyleDirty or state.captureCollapseAfterStyleRefresh then
        -- Apply styles only when tracker content actually changed.
        -- Blizzard's container can update for reasons other than fresh block
        -- content, and restyling the entire tracker on every one of those idle
        -- updates creates large transient allocation churn.

        -- Re-apply zone divider and search bar settings when styles are dirty
        if ns.RefreshZoneDividerAndSearchStyles then
            ns.RefreshZoneDividerAndSearchStyles()
        end

        RequestTrackerStyleRefresh(true)
    end
end

RefreshObjectiveTrackerDisplay = function(immediateStyleRefresh)
    if IsModuleEnabled() then
        RefreshTrackerHeader()
    end

    RefreshScrollClipFrame()
    RefreshScrollState()
    ns.RefreshFilterButton()
    RefreshTrackerButton()
    RefreshQuestLogButton()

    if not IsModuleEnabled() then
        return
    end

    RefreshTrackerHeader()

    if immediateStyleRefresh and ns.RefreshZoneDividerAndSearchStyles then
        ns.RefreshZoneDividerAndSearchStyles()
    end

    RequestTrackerStyleRefresh(false, immediateStyleRefresh == true)
end

local function HandleTrackerFrameSizeChanged(self, width, height)
    if not self then
        return
    end

    local resolvedWidth = tonumber(width) or (self.GetWidth and self:GetWidth()) or 0
    local resolvedHeight = tonumber(height) or (self.GetHeight and self:GetHeight()) or 0
    local lastWidth = state.lastTrackerSizeWidth
    local lastHeight = state.lastTrackerSizeHeight

    state.lastTrackerSizeWidth = resolvedWidth
    state.lastTrackerSizeHeight = resolvedHeight

    if state.nomToolsEnforcingHeight then
        return
    end

    if IsModuleEnabled()
        and lastWidth ~= nil
        and math.abs(resolvedWidth - lastWidth) <= 0.5
        and lastHeight ~= nil
        and math.abs(resolvedHeight - lastHeight) > 0.5
    then
        return
    end

    RefreshObjectiveTrackerDisplay(true)
end

local function GetMinimapEffectiveWidth()
    local mm = Minimap
    if not mm then return nil end
    local w = mm.GetWidth and mm:GetWidth() or nil
    if not w or w <= 0 then return nil end
    -- Convert Minimap logical width to OTF coordinate space accounting for any scale differences
    -- (e.g. another addon making the minimap square or changing its scale).
    local mmScale  = mm:GetEffectiveScale()
    local otfScale = (ObjectiveTrackerFrame and ObjectiveTrackerFrame:GetEffectiveScale()) or UIParent:GetEffectiveScale()
    if mmScale and mmScale > 0 and otfScale and otfScale > 0 then
        w = w * mmScale / otfScale
    end
    return w
end

do -- OT position helpers (scoped to avoid the 200-local-per-chunk limit)

local OT_POSITION_CONFIG_KEY = "objectiveTracker"

-- Returns the position config table {point, x, y} from NomTools edit mode config.
local function GetOTPositionConfig(layoutName)
    local defaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.objectiveTracker
        or { point = "RIGHT", x = -5, y = 0 }
    if not ns.GetEditModeConfig then return defaults end
    return ns.GetEditModeConfig(OT_POSITION_CONFIG_KEY, defaults, layoutName)
end

-- Apply the saved position from edit mode config to ObjectiveTrackerFrame.
-- Skips when minimap-attached (minimap mode owns position) or during combat.
-- Sets the reentrancy guard so the SetPoint hook does not recurse.
local function ApplyTrackerPosition(layoutName)
    if not ObjectiveTrackerFrame then return end
    if InCombatLockdown() then return end
    local settings = GetSettings()
    local layout = settings.layout or {}
    if layout.attachToMinimap == true then return end
    local config = GetOTPositionConfig(layoutName)
    local pt = config.point or "RIGHT"
    local px = config.x or -5
    local py = config.y or 0
    state.nomToolsEnforcingPosition = true
    ObjectiveTrackerFrame:ClearAllPoints()
    ObjectiveTrackerFrame:SetPoint(pt, UIParent, pt, px, py)
    state.nomToolsEnforcingPosition = false
end

ns.GetObjectiveTrackerPositionConfig = GetOTPositionConfig
ns.ApplyObjectiveTrackerPosition     = ApplyTrackerPosition

end -- do: OT position helpers

local function ApplyTrackerDimensions()
    if not ObjectiveTrackerFrame then return end
    local settings = GetSettings()
    local layout = settings.layout or {}
    local attachToMinimap = layout.attachToMinimap == true

    state.nomToolsEnforcingHeight = true
    ObjectiveTrackerFrame:SetHeight(layout.height or 800)
    state.nomToolsEnforcingHeight = false

    -- While edit mode is active, LibEditMode owns OTF's position.
    if ns.isEditMode then return end

    -- OTF inherits EditModeObjectiveTrackerSystemTemplate.  Blizzard's
    -- ApplySystemAnchor can reparent OTF into UIParentRightManagedFrameContainer
    -- and let the container's Layout() manage its position.  Break out of that
    -- so NomTools controls placement exclusively.
    ObjectiveTrackerFrame.ignoreFramePositionManager = true
    if UIParentRightManagedFrameContainer
        and UIParentRightManagedFrameContainer.RemoveManagedFrame then
        UIParentRightManagedFrameContainer:RemoveManagedFrame(ObjectiveTrackerFrame)
    end
    if ObjectiveTrackerFrame:GetParent() ~= UIParent then
        state.nomToolsEnforcingPosition = true
        ObjectiveTrackerFrame:SetParent(UIParent)
        state.nomToolsEnforcingPosition = false
    end

    if attachToMinimap and Minimap then
        -- Minimap-attached mode: NomTools owns position entirely.
        state.nomToolsEnforcingPosition = true
        ObjectiveTrackerFrame:ClearAllPoints()
        local yOff = -(tonumber(layout.minimapYOffset) or 0)
        local attachEdge = layout.minimapAttachEdge
        local matchWidth = layout.matchMinimapWidth == true
        if matchWidth then
            if attachEdge == "top" then
                ObjectiveTrackerFrame:SetPoint("BOTTOMLEFT",  Minimap, "TOPLEFT",  K.TRACKER_VISUAL_LEFT_EXTENSION,       -yOff)
                ObjectiveTrackerFrame:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", -TRACKER_MODULE_HEADER_RIGHT_EXTENSION, -yOff)
            else
                ObjectiveTrackerFrame:SetPoint("TOPLEFT",  Minimap, "BOTTOMLEFT",  K.TRACKER_VISUAL_LEFT_EXTENSION,       yOff)
                ObjectiveTrackerFrame:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", -TRACKER_MODULE_HEADER_RIGHT_EXTENSION, yOff)
            end
        else
            ObjectiveTrackerFrame:SetWidth(layout.width or 235)
            if attachEdge == "top" then
                ObjectiveTrackerFrame:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", -TRACKER_MODULE_HEADER_RIGHT_EXTENSION, -yOff)
            else
                ObjectiveTrackerFrame:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", -TRACKER_MODULE_HEADER_RIGHT_EXTENSION, yOff)
            end
        end
        state.nomToolsEnforcingPosition = false
    else
        local w
        if layout.matchMinimapWidth and Minimap then
            local mmW = GetMinimapEffectiveWidth()
            if mmW then
                w = math.floor(mmW - K.TRACKER_VISUAL_LEFT_EXTENSION - TRACKER_MODULE_HEADER_RIGHT_EXTENSION + 0.5)
                if w < 60 then w = nil end
            end
        end
        ObjectiveTrackerFrame:SetWidth(w or layout.width or 235)
        -- Apply position from NomTools edit mode config.
        ns.ApplyObjectiveTrackerPosition()
    end
end

local function InstallFrameHooks()
    if state.frameHooksInstalled or not ObjectiveTrackerFrame then
        return
    end

    state.frameHooksInstalled = true

    if not state.originalTrackerUpdate and ObjectiveTrackerFrame.Update then
        state.originalTrackerUpdate = ObjectiveTrackerFrame.Update
        ObjectiveTrackerFrame.Update = function(self, ...)
            PrepareModulesForLayout(self)
            return state.originalTrackerUpdate(self, ...)
        end
    end

    state.originalGetAvailableHeight = ObjectiveTrackerFrame.GetAvailableHeight
    ObjectiveTrackerFrame.GetAvailableHeight = function(self)
        local availableHeight = state.originalGetAvailableHeight and state.originalGetAvailableHeight(self) or (self:GetHeight() or 0)
        if IsModuleEnabled() and IsScrollEnabled() then
            local budget = GetExpandedLayoutBudget(availableHeight)
            if state.needsExpandedLayoutPass or state.scrollActive or (state.lastContentHeight or 0) > availableHeight then
                return math.max(availableHeight, budget)
            end
        end

        return availableHeight
    end

    -- After every SetHeight call (including Blizzard's edit-mode layout apply which collapses
    -- the frame to content height), re-enforce NomTools's desired height.  The reentrancy guard
    -- prevents our own corrective call from looping.
    hooksecurefunc(ObjectiveTrackerFrame, "SetHeight", function(self, newHeight)
        if state.nomToolsEnforcingHeight or not IsModuleEnabled() then return end
        local desiredHeight = GetSettings().layout.height or 800
        if math.abs((newHeight or 0) - desiredHeight) > 0.5 then
            state.nomToolsEnforcingHeight = true
            self:SetHeight(desiredHeight)
            state.nomToolsEnforcingHeight = false
        end
    end)

    -- Blizzard's edit-mode system (EditModeObjectiveTrackerSystemTemplate) repositions OTF
    -- asynchronously on reload and during layout updates, overriding NomTools.  This hook
    -- re-asserts NomTools position after any external SetPoint call.  Skipped when LEM
    -- owns the position (edit mode active), when NomTools module is disabled, or when
    -- NomTools itself is setting the position (reentrancy guard).
    hooksecurefunc(ObjectiveTrackerFrame, "SetPoint", function(self)
        if state.nomToolsEnforcingPosition or ns.isEditMode or not IsModuleEnabled() then return end
        if InCombatLockdown() then return end
        local settings = GetSettings()
        local layout = settings.layout or {}
        if layout.attachToMinimap == true then return end
        state.nomToolsEnforcingPosition = true
        ns.ApplyObjectiveTrackerPosition()
        state.nomToolsEnforcingPosition = false
    end)

    -- Hook Blizzard's ApplySystemAnchor (fired via EDIT_MODE_LAYOUTS_UPDATED on
    -- login/reload and whenever the active edit-mode layout changes).  Path A of
    -- that method reparents OTF into UIParentRightManagedFrameContainer and clears
    -- ignoreFramePositionManager; Path B calls SetPoint directly.  Either way, we
    -- must re-break OTF from the container and re-apply NomTools position.
    if ObjectiveTrackerFrame.ApplySystemAnchor then
        hooksecurefunc(ObjectiveTrackerFrame, "ApplySystemAnchor", function(self)
            if ns.isEditMode or not IsModuleEnabled() then return end
            if InCombatLockdown() then return end
            self.ignoreFramePositionManager = true
            if UIParentRightManagedFrameContainer
                and UIParentRightManagedFrameContainer.RemoveManagedFrame then
                UIParentRightManagedFrameContainer:RemoveManagedFrame(self)
            end
            if self:GetParent() ~= UIParent then
                state.nomToolsEnforcingPosition = true
                self:SetParent(UIParent)
                state.nomToolsEnforcingPosition = false
            end
            ApplyTrackerDimensions()
        end)
    end

    ObjectiveTrackerFrame:EnableMouseWheel(true)
    ObjectiveTrackerFrame:HookScript("OnMouseWheel", OnTrackerMouseWheel)
    ObjectiveTrackerFrame:HookScript("OnSizeChanged", function(self, width, height)
        HandleTrackerFrameSizeChanged(self, width, height)
    end)

    hooksecurefunc(ObjectiveTrackerContainerMixin, "Update", function(container)
        if container ~= ObjectiveTrackerFrame then
            return
        end

        if state.inPostLayout then
            return
        end
        state.inPostLayout = true
        local ok, err = pcall(RunTrackerPostLayout, container)
        state.inPostLayout = false
        if not ok and ns.IsDebugEnabled and ns.IsDebugEnabled() then
            ns.DebugPrint("PostLayout error: " .. tostring(err))
        end
    end)

    -- Hook Header.Show so Blizzard re-shows can be immediately suppressed when the
    -- player has disabled the header or minimize button in NomTools options.
    if ObjectiveTrackerFrame.Header then
        hooksecurefunc(ObjectiveTrackerFrame.Header, "Show", function(self)
            if not IsModuleEnabled() then
                return
            end

            if not IsMainHeaderEnabled() then
                self:Hide()
            end
        end)
        if ObjectiveTrackerFrame.Header.MinimizeButton then
            hooksecurefunc(ObjectiveTrackerFrame.Header.MinimizeButton, "Show", function(self)
                if not IsModuleEnabled() then
                    return
                end

                if not IsMinimizeButtonEnabled() then
                    self:Hide()
                end
            end)
        end
    end
end

do -- OT edit mode registration (scoped to avoid the 200-local-per-chunk limit)

local registeredWithLEM = false

local function RegisterWithEditMode()
    if registeredWithLEM or not ObjectiveTrackerFrame or not ns.RegisterEditModeFrame then
        return
    end

    local defaults = ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.objectiveTracker
        or { point = "RIGHT", x = -5, y = 0 }

    registeredWithLEM = ns.RegisterEditModeFrame(ObjectiveTrackerFrame, {
        label = "Objective Tracker",
        defaults = {
            point = defaults.point,
            x = defaults.x,
            y = defaults.y,
        },
        applyLayout = function(layoutName)
            ApplyTrackerDimensions()
        end,
        onPositionChanged = function(layoutName, point, x, y)
            local config = ns.GetObjectiveTrackerPositionConfig(layoutName)
            config.point = point
            config.x = x
            config.y = y
            if ns.RefreshObjectiveTrackerOptionsSliders then
                ns.RefreshObjectiveTrackerOptionsSliders()
            end
        end,
    }) == true
end

ns.RegisterObjectiveTrackerEditMode = RegisterWithEditMode

end -- do: OT edit mode registration

local function RefreshObjectiveTrackerState(refreshMode)
    if not EnsureObjectiveTrackerLoaded() then
        return
    end

    InstallTrackerHooks()
    InstallBlockHooks()
    InstallCollapseHooks()
    InstallFrameHooks()
    ApplyTrackerDimensions()
    if ns.RegisterObjectiveTrackerEditMode then
        ns.RegisterObjectiveTrackerEditMode()
    end
    RefreshScrollClipFrame()

    if IsModuleEnabled() and IsScrollEnabled() then
        state.needsExpandedLayoutPass = true
    elseif not IsModuleEnabled() then
        state.layoutHeightBudget = 0
        state.needsExpandedLayoutPass = false
    end

    if refreshMode == "soft" then
        state.postLayoutStyleDirty = true
        RefreshObjectiveTrackerDisplay(true)
        return
    end

    local focusedQuestModule = EnsureFocusedQuestModule()
    local zoneModule = EnsureZoneModule()
    if IsModuleEnabled() and IsSearchEnabled() then
        ns.EnsureSearchFrame()
    end

    local function SetCustomModuleAttached(module, shouldAttach)
        if not module then
            return
        end

        local hasModule = ObjectiveTrackerFrame.HasModule and ObjectiveTrackerFrame:HasModule(module)
        if shouldAttach then
            RegisterCustomModuleEvents(module)
            if not hasModule then
                if ObjectiveTrackerManager and ObjectiveTrackerManager.SetModuleContainer then
                    ObjectiveTrackerManager:SetModuleContainer(module, ObjectiveTrackerFrame)
                end
                hasModule = ObjectiveTrackerFrame:HasModule(module)
                if not hasModule then
                    ObjectiveTrackerFrame:AddModule(module)
                end
            end
            if module.Show then
                module:Show()
            end
            if module.MarkDirty then
                module:MarkDirty()
            end
            return
        end

        UnregisterCustomModuleEvents(module)

        if hasModule and ObjectiveTrackerFrame.RemoveModule then
            ObjectiveTrackerFrame:RemoveModule(module)
        end

        StopZoneTaskRetry(module)
        StopModuleTicker(module)
        module.tickerSeconds = 0

        if module.Hide then
            module:Hide()
        end
        if module.SetHeight then
            module:SetHeight(0)
        end
    end

    if IsModuleEnabled() then
        SetCustomModuleAttached(focusedQuestModule, IsFocusedQuestEnabled())
        SetCustomModuleAttached(zoneModule, true)
        TagKnownModules()
        ApplyCategoryOrder()
        RefreshTrackerHeader()
    else
        SetCustomModuleAttached(focusedQuestModule, false)
        SetCustomModuleAttached(zoneModule, false)
        RestoreOriginalModuleOrder()
        RestoreBlizzardModuleAnchors(true)
        state.searchText = ""
        if state.searchEditBox then
            state.searchEditBox:SetText("")
        end
        if state.searchFrame then
            state.searchFrame:Hide()
        end
        if state.filterDropFrame then state.filterDropFrame:Hide() end
        if state.filterDropCloseListener then state.filterDropCloseListener:Hide() end
        if state.filterButton then state.filterButton:Hide() end
    end

    if ObjectiveTrackerManager and ObjectiveTrackerManager.UpdateAll then
        ObjectiveTrackerManager:UpdateAll()
    elseif ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
        ObjectiveTrackerFrame:Update()
    end

    state.postLayoutStyleDirty = true
    RefreshObjectiveTrackerDisplay(true)
end

function ns.RefreshObjectiveTrackerUI(refreshMode)
    HookObjectiveTrackerManagerInit()
    RefreshObjectiveTrackerState(refreshMode)
end

function ns.CaptureObjectiveTrackerUIState()
    if not state.collapsePersistenceReady or state.applyingCollapseStates then
        return false
    end

    return CaptureCurrentSectionCollapseStates()
end

ns.InitializeObjectiveTrackerUI = ns.RefreshObjectiveTrackerUI
