local addonName, ns = ...

-- Resolve the NomTools namespace when loaded from a sub-addon TOC.
if addonName ~= "NomTools" then
    ns = _G and _G["NomTools"]
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

-- =============================================
-- Cached globals
-- =============================================
local C_Timer               = C_Timer
local C_TaskQuest           = C_TaskQuest
local C_QuestLog            = C_QuestLog
local C_Map                 = C_Map
local C_SuperTrack          = C_SuperTrack
local C_Item                = C_Item
local C_Reputation          = C_Reputation
local C_UnitAuras           = C_UnitAuras
local C_Spell               = C_Spell
local CreateFrame           = CreateFrame
local GameTooltip           = GameTooltip
local WorldMapFrame         = WorldMapFrame
local InCombatLockdown      = InCombatLockdown
local HaveQuestData         = HaveQuestData
local HaveQuestRewardData   = HaveQuestRewardData
local GetQuestObjectiveInfo = GetQuestObjectiveInfo
local GetQuestLogQuestText  = GetQuestLogQuestText
local GetQuestUiMapIDCompat = _G and _G["GetQuestUiMapID"]
local GetTime               = GetTime
local GetServerTime         = GetServerTime
local QuestUtils_IsQuestWorldQuest = QuestUtils_IsQuestWorldQuest
local GetQuestLogRewardInfo = GetQuestLogRewardInfo
local GetQuestLogRewardMoney = GetQuestLogRewardMoney
-- Legacy globals (GetNumQuestLogRewardCurrencies, GetQuestLogRewardCurrencyInfo,
-- GetFactionInfoByID, etc.) removed — replaced with C_QuestLog / C_Reputation
-- questID-specific equivalents for Midnight 12.0.
local math_floor            = math.floor
local string_find           = string.find
local string_format         = string.format
local string_gsub           = string.gsub
local string_lower          = string.lower
local table_sort            = table.sort

-- =============================================
-- Constants
-- =============================================
-- Display mode key for QuestMapFrame tab registration
local DISPLAY_MODE         = "NOMTOOLS_WorldQuests"
local ROW_HEIGHT           = 64
local LOCKED_ROW_HEIGHT    = 82
local ZONE_HEADER_HEIGHT   = 22
local DOT_SIZE             = 10
local POI_BUTTON_SIZE      = 22
local CONTRACT_ICON_SIZE   = 10
local REWARD_ICON_SIZE     = 22
local REWARD_ICON_SPACING  = 3
local MAX_REWARD_ICONS     = 4
local TIME_RED             = 3600    -- < 1 hour
local TIME_ORANGE          = 21600   -- < 6 hours
local TIME_YELLOW          = 43200   -- < 12 hours
local QUEST_DATA_RETRY_COOLDOWN = 30

-- Color palette stored as { r, g, b [,a] } tables.
local COL = {
    dotRed       = { 1.0,  0.15, 0.15 },
    dotOrange    = { 1.0,  0.55, 0.15 },
    dotYellow    = { 1.0,  0.85, 0.0  },
    dotOk        = { 0.35, 0.75, 0.35 },
    zoneHeaderBg = { 0.06, 0.07, 0.10, 0.85 },
    zoneLabel    = { 0.78, 0.78, 0.82 },
    rowTitle     = { 1.0,  1.0,  1.0  },
    rowTitleLocked = { 0.62, 0.62, 0.68 },
    rowFaction   = { 0.70, 0.78, 0.88 },
    rowFactionActiveContract = { 0.52, 0.84, 1.0 },
    rowLockedRequirement = { 0.90, 0.68, 0.48 },
    rowTime      = { 0.72, 0.72, 0.76 },
    rewardCount  = { 0.75, 0.75, 0.75 },
    rowHover     = { 1,    1,    1,    0.06 },
    separator    = { 0.15, 0.17, 0.21, 1    },
    noQuests     = { 0.60, 0.60, 0.65 },
    superTrackOn = { 1.0,  0.85, 0.20 },
    superTrackOff= { 0.55, 0.58, 0.64 },
    contractNotice = { 0.62, 0.88, 1.0 },
    contractNoticeNone = { 1.0, 0.32, 0.32 },
}

-- UI map type values (Enum.UIMapType) used for overview query scheduling.
local MAP_TYPE_WORLD     = Enum and Enum.UIMapType and Enum.UIMapType.World or 1

-- =============================================
-- Scan hierarchy registry
-- Instead of walking every descendant zone from the top-level map, the
-- hierarchy defines specific "scan root" zones whose C_Map descendants
-- contain world quests.  Intermediate nodes (with children) are waypoints
-- the scanner skips through; leaf nodes (no children) are scan roots whose
-- actual map descendants are walked via C_Map.GetMapChildrenInfo.
-- =============================================
local hierarchyNodeSet   = {}   -- [mapID] = true for all hierarchy nodes
local hierarchyScanRoots = {}   -- [mapID] = { scanRootID, ... } for waypoints only

do
    ---@param node table
    ---@return number[]
    local function BuildScanHierarchyLookups(node)
        if not node or type(node.mapID) ~= "number" then
            return {}
        end

        hierarchyNodeSet[node.mapID] = true

        if not node.children or #node.children == 0 then
            return { node.mapID }
        end

        local leafRoots = {}
        for childIndex = 1, #node.children do
            local childLeaves = BuildScanHierarchyLookups(node.children[childIndex])
            for leafIndex = 1, #childLeaves do
                leafRoots[#leafRoots + 1] = childLeaves[leafIndex]
            end
        end

        hierarchyScanRoots[node.mapID] = leafRoots
        return leafRoots
    end

    local scanHierarchy = ns.WORLD_QUEST_SCAN_HIERARCHY
    if type(scanHierarchy) == "table" then
        BuildScanHierarchyLookups(scanHierarchy)
    end
end

-- =============================================
-- Module state
-- =============================================
local questMapPanel          -- content frame parented to QuestMapFrame
local questMapTab            -- QuestLogTabButtonTemplate tab button
local worldQuestSearchBox    -- world quests search edit box
local RebuildTabAnchor       -- forward declaration; defined after module state
local ScheduleRefresh        -- forward declaration; defined after layout functions
local EnsureMinuteAlignedTimeUpdates
local StopMinuteAlignedTimeUpdates
local EnsureQuestDataRetryRefresh
local StopQuestDataRetryRefresh
local scrollFrame
local scrollChild
local noQuestsLabel
local contractNoticeFrame
local contractNoticeLabel
local UpdateContractNoticeLayout
local activeTooltipAnchor
local activeTooltipQuestID
local activeTooltipShowTrackHint = false

function DebugHoverTrace(tag, fmt, ...)
    if not ns.IsDebugEnabled() then
        return
    end

    local message
    local count = select("#", ...)

    if type(fmt) == "string" then
        if count > 0 then
            local ok, formatted = pcall(string_format, fmt, ...)
            if ok then
                message = formatted
            else
                local parts = { fmt }
                for index = 1, count do
                    parts[#parts + 1] = tostring(select(index, ...))
                end
                message = table.concat(parts, " ")
            end
        else
            message = fmt
        end
    elseif fmt == nil then
        if count > 0 then
            local parts = {}
            for index = 1, count do
                parts[index] = tostring(select(index, ...))
            end
            message = table.concat(parts, " ")
        else
            message = ""
        end
    elseif count > 0 then
        local parts = { tostring(fmt) }
        for index = 1, count do
            parts[#parts + 1] = tostring(select(index, ...))
        end
        message = table.concat(parts, " ")
    else
        message = tostring(fmt)
    end

    if message and message ~= "" then
        ns.DebugPrint(string_format("WQ Hover: %s %s", tostring(tag), message))
    else
        ns.DebugPrint("WQ Hover: " .. tostring(tag))
    end
end

---@param row Frame?
---@return string
function GetHoverRowIdentity(row)
    if not ns.IsDebugEnabled() then
        return ""
    end

    if not row then
        return "nil"
    end

    local rowQuestID = rawget(row, "questID")
    return string_format("%s(q=%s)", tostring(row), tostring(rowQuestID))
end

local activeHoverState = {
    pinMisses = 0,
    surfaceMisses = 0,
    stopToken = 0,
    fxPin = nil,
}
local questRowPool       = {}  -- inactive (recycled) quest row frames
local zoneHeaderPool     = {}  -- inactive zone header frames
local activeContent      = {}  -- ordered list of { type="zone"|"row", frame=f }
local collapseState      = {}  -- collapseState[zoneName] = true when zone is collapsed
local refreshPending         = false
local refreshPendingAnimateRows = true
local displayHookRegistered  = false
local eventFrame             = CreateFrame("Frame")
eventFrame._activeWorldQuestRawIDs = {}
eventFrame._descendantGatherGeneration = 0
eventFrame._descendantGatherSession = nil
eventFrame._currentQuestEntriesByID = {}
eventFrame._sessionScannedQueryMapIDs = {}
eventFrame._sessionRawEntries = {}
eventFrame._sessionRawEntriesSeen = {}
eventFrame._sessionEnrichedEntries = {}
eventFrame._sessionEnrichedEntriesSeen = {}
eventFrame._sessionQueryStateCache = {}
eventFrame._excludedMaps = {}
eventFrame._typographyVersion = 0
local currentRelevantContract
local currentQuestEntries    = {}
local minuteUpdateGeneration = 0
local minuteUpdateActive     = false
local retryRefreshGeneration = 0
local retryRefreshDueAt
local pendingDisplayModeSource
local pendingBuiltinDisplayModeFallback

-- ── Performance caches ───────────────────────────────────────────────────────
-- mapDescendantsCache: stable per mapID — the map hierarchy never changes
-- at runtime, so we compute each entry once and keep it for the session.
local mapDescendantsCache = {}
-- Incremented each LayoutScrollContent call.  Batch callbacks capture their
-- generation at creation time and self-cancel if it no longer matches.
local layoutGeneration  = 0

-- ── Pending quest data tracking ──────────────────────────────────────────────
-- Set of questIDs visible in the current panel whose data has NOT fully loaded.
-- Each entry tracks quest-data readiness separately from reward-data readiness
-- so the first non-animated rebuild can happen as soon as ordering inputs are
-- usable, while still allowing one later rebuild if reward-derived state lands.
local pendingQuestIDs   = {}   -- [questID] = { needsQuestData, needsRewardData, questDataRefreshDone, searchRefreshOnRewardReady }
-- Tracks which questIDs have been requested via RequestLoadQuestByID this
-- session to avoid redundant server requests.
local requestedQuestData = {}  -- [questID] = true
local questDataRetrySuppressedUntil = {} -- [questID] = GetTime() + cooldown after load failure
local rewardPreloadState = {
    queuedQuestIDs = {},
    requestedQuestIDs = {},
    requestRetryCooldown = 5,
    queue = {},
    queueHead = 1,
    queueTail = 0,
    drainScheduled = false,
    drainGeneration = 0,
    pollGeneration = 0,
    pollActive = false,
    drainCycleCounter = 0,  -- Anti-starvation counter: cycles through [0-4], pop from tail when 4
    itemLoadState = {
        pending = {},
        completed = {},
    },
}

-- ── Filter / sort state ───────────────────────────────────────────────────────
-- These are runtime copies of  ns.db.worldQuests.filter* / sort* values,
-- kept in locals so the hot path (GatherQuestsForCurrentMap) does not call
-- GetSettings() on every refresh.
local filterSearch      = ""   -- text typed in the search bar (session-only)
local filterTypes       = {}   -- set of quest-type strings to EXCLUDE (empty = show all)
local filterRewards     = {}   -- set of reward-type strings to EXCLUDE (empty = show all)
local sortMode          = "time"  -- quest sort: "time" | "alpha" | "reward" | "faction"
local zoneSortMode      = "time"  -- zone sort: "time" | "alpha"

-- Called once at startup and whenever settings are loaded/changed.
local function SyncFilterState(clearSearch)
    local s = ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or {}
    if clearSearch then
        filterSearch = ""  -- never persisted; always starts empty
        if worldQuestSearchBox then
            local currentText = worldQuestSearchBox:GetText()
            if currentText and currentText ~= "" then
                worldQuestSearchBox:SetText("")
            end
        end
    end
    -- filterVersion guards against loading saved data that was written by the
    -- old inclusion-set logic (version < 2).  If absent or stale, clear all
    -- filter sets so the exclusion-set defaults (empty = show all) take effect.
    if not s.filterVersion or s.filterVersion < 2 then
        filterTypes   = {}
        filterRewards = {}
        sortMode      = "time"
        zoneSortMode  = "time"
        -- Initialize excluded maps from defaults
        wipe(eventFrame._excludedMaps)
        local defaults = ns.WORLD_QUEST_DEFAULT_EXCLUDED_MAPS
        if defaults then
            for mapID, excluded in pairs(defaults) do
                if excluded then
                    eventFrame._excludedMaps[mapID] = true
                end
            end
        end
        if ns.SetWorldQuestsSetting then
            ns.SetWorldQuestsSetting("filterVersion", 2)
            ns.SetWorldQuestsSetting("filterTypes",   filterTypes)
            ns.SetWorldQuestsSetting("filterRewards", filterRewards)
            ns.SetWorldQuestsSetting("sortMode",      sortMode)
            ns.SetWorldQuestsSetting("zoneSortMode",  zoneSortMode)
            local excludedMapsCopy = {}
            for mapID, excluded in pairs(eventFrame._excludedMaps) do
                excludedMapsCopy[mapID] = excluded
            end
            ns.SetWorldQuestsSetting("excludedMaps", excludedMapsCopy)
        end
    else
        local normalizedFilters = false
        if type(s.filterTypes) == "table" then
            filterTypes = s.filterTypes
        else
            filterTypes = {}
            normalizedFilters = s.filterTypes ~= nil
        end

        if type(s.filterRewards) == "table" then
            filterRewards = s.filterRewards
        else
            filterRewards = {}
            normalizedFilters = normalizedFilters or s.filterRewards ~= nil
        end

        sortMode      = s.sortMode      or "time"
        zoneSortMode  = s.zoneSortMode  or "time"

        if normalizedFilters and ns.SetWorldQuestsSetting then
            ns.SetWorldQuestsSetting("filterTypes", filterTypes)
            ns.SetWorldQuestsSetting("filterRewards", filterRewards)
        end

        -- Load excluded maps from settings, falling back to defaults
        if type(s.excludedMaps) == "table" then
            wipe(eventFrame._excludedMaps)
            for mapID, excluded in pairs(s.excludedMaps) do
                if excluded then
                    eventFrame._excludedMaps[mapID] = true
                end
            end
        else
            wipe(eventFrame._excludedMaps)
            local defaults = ns.WORLD_QUEST_DEFAULT_EXCLUDED_MAPS
            if defaults then
                for mapID, excluded in pairs(defaults) do
                    if excluded then
                        eventFrame._excludedMaps[mapID] = true
                    end
                end
            end
            -- Persist the defaults so they show up correctly in the options UI
            if ns.SetWorldQuestsSetting then
                local toSave = {}
                for mapID, excluded in pairs(eventFrame._excludedMaps) do
                    toSave[mapID] = excluded
                end
                ns.SetWorldQuestsSetting("excludedMaps", toSave)
            end
        end
    end
end

local function SaveFilterState()
    if not ns.SetWorldQuestsSetting then return end
    -- filterSearch is intentionally not saved (session-only)
    ns.SetWorldQuestsSetting("filterTypes",   filterTypes)
    ns.SetWorldQuestsSetting("filterRewards", filterRewards)
    ns.SetWorldQuestsSetting("sortMode",      sortMode)
    ns.SetWorldQuestsSetting("zoneSortMode",  zoneSortMode)
    local excludedMapsCopy = {}
    for mapID, excluded in pairs(eventFrame._excludedMaps) do
        if excluded then
            excludedMapsCopy[mapID] = true
        end
    end
    ns.SetWorldQuestsSetting("excludedMaps", excludedMapsCopy)
end

function eventFrame:IsWQFilterDefault()
    if next(filterTypes) then return false end
    if next(filterRewards) then return false end
    if sortMode ~= "time" then return false end
    if zoneSortMode ~= "time" then return false end
    return true
end

function eventFrame:UpdateWQFilterResetState()
    -- No-op: reset is now inside the dropdown menu
end

---@param mapID number
---@return boolean
function eventFrame:IsWorldQuestMapExcluded(mapID)
    return self._excludedMaps[mapID] == true
end

---@param mapID number
---@param excluded boolean|nil
function eventFrame:SetWorldQuestMapExcluded(mapID, excluded)
    if excluded then
        self._excludedMaps[mapID] = true
    else
        self._excludedMaps[mapID] = nil
    end
    SaveFilterState()
    wipe(self._sessionQueryStateCache)
    wipe(self._sessionScannedQueryMapIDs)
    self._sessionEnrichedEntries = {}
    self._sessionEnrichedEntriesSeen = {}
    rewardPreloadState.StopPoll()
    ScheduleRefresh(false, "Excluded maps changed")
end

ns.IsWorldQuestMapExcluded = function(mapID)
    return eventFrame:IsWorldQuestMapExcluded(mapID)
end

ns.SetWorldQuestMapExcluded = function(mapID, excluded)
    eventFrame:SetWorldQuestMapExcluded(mapID, excluded)
end

local function UpdateQuestLogUpdateRegistration()
    local shouldRegister = false
    local hasVisibleLockedAreaPOI = false
    local isRefreshContextActive = ns.IsWorldQuestsRefreshContextActive()
    local visibleLockedAreaPOIWidgetSetIDs = eventFrame._visibleLockedAreaPOIWidgetSetIDs or {}
    local visibleLockedAreaPOIWidgetSetCount = 0

    eventFrame._visibleLockedAreaPOIWidgetSetIDs = visibleLockedAreaPOIWidgetSetIDs
    wipe(visibleLockedAreaPOIWidgetSetIDs)

    if isRefreshContextActive then
        shouldRegister = next(pendingQuestIDs) ~= nil
        if currentQuestEntries and #currentQuestEntries > 0 then
            for _, entry in ipairs(currentQuestEntries) do
                local questID = entry.questID
                if entry.isAreaPOI and entry.isLocked then
                    hasVisibleLockedAreaPOI = true

                    local widgetSetID = entry.tooltipWidgetSet
                    if widgetSetID and widgetSetID > 0
                        and not visibleLockedAreaPOIWidgetSetIDs[widgetSetID]
                    then
                        visibleLockedAreaPOIWidgetSetIDs[widgetSetID] = true
                        visibleLockedAreaPOIWidgetSetCount =
                            visibleLockedAreaPOIWidgetSetCount + 1
                    end

                    if not shouldRegister then
                        shouldRegister = true
                    end
                elseif not shouldRegister and questID and questID > 0
                    and not entry.isAreaPOI
                then
                    shouldRegister = true
                end
            end
        end
    end

    eventFrame._visibleLockedAreaPOIWidgetSetCount = visibleLockedAreaPOIWidgetSetCount

    if not hasVisibleLockedAreaPOI then
        eventFrame._visibleLockedAreaPOISnapshot = nil
    end

    local shouldRegisterWidgetUpdates = isRefreshContextActive
        and (visibleLockedAreaPOIWidgetSetCount > 0
            or (eventFrame._liveRelevantAreaPOIWidgetSetCount or 0) > 0)

    if shouldRegister then
        if not eventFrame._questLogUpdateRegistered then
            eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
            eventFrame._questLogUpdateRegistered = true
        end
    elseif eventFrame._questLogUpdateRegistered then
        eventFrame:UnregisterEvent("QUEST_LOG_UPDATE")
        eventFrame._questLogUpdateRegistered = false
    end

    if shouldRegisterWidgetUpdates then
        if not eventFrame._uiWidgetUpdateRegistered then
            eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
            eventFrame._uiWidgetUpdateRegistered = true
        end
        if not eventFrame._allUiWidgetUpdatesRegistered then
            eventFrame:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
            eventFrame._allUiWidgetUpdatesRegistered = true
        end
    else
        if eventFrame._uiWidgetUpdateRegistered then
            eventFrame:UnregisterEvent("UPDATE_UI_WIDGET")
            eventFrame._uiWidgetUpdateRegistered = false
        end
        if eventFrame._allUiWidgetUpdatesRegistered then
            eventFrame:UnregisterEvent("UPDATE_ALL_UI_WIDGETS")
            eventFrame._allUiWidgetUpdatesRegistered = false
        end
    end
end

local function PruneQuestRequestBookkeeping(activeQuestIDs)
    local activeRawQuestIDs = eventFrame._activeWorldQuestRawIDs
    local completedItemLoads = rewardPreloadState.itemLoadState.completed

    if not activeQuestIDs then
        rewardPreloadState.CancelDrain()
        wipe(activeRawQuestIDs)
        wipe(pendingQuestIDs)
        wipe(requestedQuestData)
        wipe(questDataRetrySuppressedUntil)
        wipe(rewardPreloadState.requestedQuestIDs)
        wipe(rewardPreloadState.queuedQuestIDs)
        wipe(rewardPreloadState.queue)
        wipe(completedItemLoads)
        rewardPreloadState.queueHead = 1
        rewardPreloadState.queueTail = 0
        return
    end

    for questID in pairs(activeRawQuestIDs) do
        if not activeQuestIDs[questID] then
            activeRawQuestIDs[questID] = nil
        end
    end

    for questID in pairs(activeQuestIDs) do
        activeRawQuestIDs[questID] = true
    end

    for questID in pairs(pendingQuestIDs) do
        if not activeQuestIDs[questID] then
            pendingQuestIDs[questID] = nil
        end
    end

    for questID in pairs(requestedQuestData) do
        if not activeQuestIDs[questID] then
            requestedQuestData[questID] = nil
        end
    end

    for questID in pairs(questDataRetrySuppressedUntil) do
        if not activeQuestIDs[questID] then
            questDataRetrySuppressedUntil[questID] = nil
        end
    end

    for questID in pairs(rewardPreloadState.requestedQuestIDs) do
        if not activeQuestIDs[questID] then
            rewardPreloadState.requestedQuestIDs[questID] = nil
            rewardPreloadState.queuedQuestIDs[questID] = nil
        end
    end

    for questID in pairs(rewardPreloadState.queuedQuestIDs) do
        if not activeQuestIDs[questID] then
            rewardPreloadState.queuedQuestIDs[questID] = nil
        end
    end

    for key in pairs(completedItemLoads) do
        local questID = tonumber(key:match("^(%d+):"))
        if not questID or not activeQuestIDs[questID] then
            completedItemLoads[key] = nil
        end
    end
end

local function ResolvePendingQuestDataState(questID)
    local state = pendingQuestIDs[questID]
    if not state then
        return false, false, false
    end

    local hasQuestData = eventFrame:IsQuestCoreDataReady(questID)
    local hasRewardData = not HaveQuestRewardData or HaveQuestRewardData(questID)
    local rowNeedsUpdate = false
    local needsFullRefresh = false
    local searchRefreshOnRewardReady = false

    if state.needsQuestData and hasQuestData then
        state.needsQuestData = false
        rowNeedsUpdate = true
        if not state.questDataRefreshDone then
            state.questDataRefreshDone = true
            needsFullRefresh = true
        end
    end

    if hasQuestData then
        requestedQuestData[questID] = nil
        questDataRetrySuppressedUntil[questID] = nil
    end

    if state.needsRewardData and hasRewardData then
        state.needsRewardData = false
        searchRefreshOnRewardReady = state.searchRefreshOnRewardReady == true
        state.searchRefreshOnRewardReady = nil
        rewardPreloadState.requestedQuestIDs[questID] = nil
        rewardPreloadState.queuedQuestIDs[questID] = nil
        rowNeedsUpdate = true
    end

    if not state.needsRewardData then
        state.searchRefreshOnRewardReady = nil
    end

    if not state.needsQuestData and not state.needsRewardData then
        pendingQuestIDs[questID] = nil
    end

    return rowNeedsUpdate, needsFullRefresh, searchRefreshOnRewardReady
end

function rewardPreloadState.IsQuestRewardDisplayReady(questOrEntry)
    local questID = questOrEntry

    if type(questOrEntry) == "table" then
        if questOrEntry.isAreaPOI == true or questOrEntry.isLocked then
            return true
        end
        questID = questOrEntry.questID
    end

    if type(questID) ~= "number" or questID <= 0 then
        return true
    end

    if not HaveQuestRewardData then
        return true
    end

    return HaveQuestRewardData(questID)
end

function rewardPreloadState.HasFreshRequest(questID, now)
    local requestedAt = rewardPreloadState.requestedQuestIDs[questID]
    if not requestedAt then
        return false
    end

    if type(requestedAt) ~= "number" then
        rewardPreloadState.requestedQuestIDs[questID] = nil
        return false
    end

    if requestedAt + rewardPreloadState.requestRetryCooldown > (now or GetTime()) then
        return true
    end

    rewardPreloadState.requestedQuestIDs[questID] = nil
    return false
end

function rewardPreloadState.ResetQueue()
    wipe(rewardPreloadState.queue)
    rewardPreloadState.queueHead = 1
    rewardPreloadState.queueTail = 0
    rewardPreloadState.drainCycleCounter = 0
end

function rewardPreloadState.CancelDrain()
    rewardPreloadState.drainGeneration = rewardPreloadState.drainGeneration + 1
    rewardPreloadState.drainScheduled = false
    rewardPreloadState.drainCycleCounter = 0
end

function rewardPreloadState.CompactQueue()
    local head = rewardPreloadState.queueHead
    local tail = rewardPreloadState.queueTail

    if head <= 1 then
        return
    end

    if head > tail then
        rewardPreloadState.ResetQueue()
        return
    end

    local newTail = tail - head + 1
    for index = 1, newTail do
        rewardPreloadState.queue[index] = rewardPreloadState.queue[head + index - 1]
    end

    for index = newTail + 1, tail do
        rewardPreloadState.queue[index] = nil
    end

    rewardPreloadState.queueHead = 1
    rewardPreloadState.queueTail = newTail
end

function rewardPreloadState.PopQueuedQuestID()
    local head = rewardPreloadState.queueHead
    local tail = rewardPreloadState.queueTail

    if head > tail then
        return nil
    end

    local questID = rewardPreloadState.queue[head]
    rewardPreloadState.queue[head] = nil
    rewardPreloadState.queueHead = head + 1

    if rewardPreloadState.queueHead > tail then
        rewardPreloadState.ResetQueue()
    else
        local remainingCount = tail - rewardPreloadState.queueHead + 1
        if rewardPreloadState.queueHead > 32
            and rewardPreloadState.queueHead > remainingCount
        then
            rewardPreloadState.CompactQueue()
        end
    end

    return questID
end

function rewardPreloadState.PopQuestFromTail()
    local head = rewardPreloadState.queueHead
    local tail = rewardPreloadState.queueTail

    if head > tail then
        return nil
    end

    local questID = rewardPreloadState.queue[tail]
    rewardPreloadState.queue[tail] = nil
    rewardPreloadState.queueTail = tail - 1

    if rewardPreloadState.queueHead > rewardPreloadState.queueTail then
        rewardPreloadState.ResetQueue()
    end

    return questID
end

function rewardPreloadState.ScheduleDrain()
    if rewardPreloadState.drainScheduled
        or not C_TaskQuest
        or not C_TaskQuest.RequestPreloadRewardData
    then
        return
    end

    local myGeneration = rewardPreloadState.drainGeneration
    rewardPreloadState.drainScheduled = true
    C_Timer.After(0.02, function()
        if rewardPreloadState.drainGeneration ~= myGeneration then
            return
        end

        rewardPreloadState.drainScheduled = false

        if not ns.IsWorldQuestsRefreshContextActive() then
            return
        end

        local now = GetTime()
        local DRAIN_BATCH_SIZE = 5
        for _ = 1, DRAIN_BATCH_SIZE do
            -- Anti-starvation: every 5th item, pop from tail (low-priority)
            -- Otherwise pop from head (high-priority)
            local questID
            if rewardPreloadState.drainCycleCounter == 4 then
                questID = rewardPreloadState.PopQuestFromTail()
                rewardPreloadState.drainCycleCounter = 0
            else
                questID = rewardPreloadState.PopQueuedQuestID()
                rewardPreloadState.drainCycleCounter = rewardPreloadState.drainCycleCounter + 1
            end

            if not questID then
                rewardPreloadState.drainCycleCounter = 0  -- Reset counter when queue empties
                break
            end

            rewardPreloadState.queuedQuestIDs[questID] = nil

            local retrySuppressedUntil = questDataRetrySuppressedUntil[questID]
            local questDataSuppressed = retrySuppressedUntil
                and retrySuppressedUntil > now

            if not rewardPreloadState.IsQuestRewardDisplayReady(questID)
                and not rewardPreloadState.HasFreshRequest(questID, now)
                and not (questDataSuppressed and not eventFrame:IsQuestCoreDataReady(questID))
            then
                rewardPreloadState.requestedQuestIDs[questID] = now
                C_TaskQuest.RequestPreloadRewardData(questID)
                EnsureQuestDataRetryRefresh()
            end
        end

        if rewardPreloadState.queueHead <= rewardPreloadState.queueTail then
            rewardPreloadState.ScheduleDrain()
        end
    end)
end

function rewardPreloadState.QueueQuestRewardPreload(questID, prioritize)
    if type(questID) ~= "number" or questID <= 0 then
        return true
    end

    local now = GetTime()

    if not HaveQuestRewardData
        or not C_TaskQuest
        or not C_TaskQuest.RequestPreloadRewardData
    then
        return true
    end

    if rewardPreloadState.IsQuestRewardDisplayReady(questID) then
        rewardPreloadState.queuedQuestIDs[questID] = nil
        rewardPreloadState.requestedQuestIDs[questID] = nil
        return true
    end

    local retrySuppressedUntil = questDataRetrySuppressedUntil[questID]
    if retrySuppressedUntil and retrySuppressedUntil > now
        and not eventFrame:IsQuestCoreDataReady(questID)
    then
        return false
    end

    if rewardPreloadState.HasFreshRequest(questID, now) then
        return false
    end

    if rewardPreloadState.queuedQuestIDs[questID] then
        if prioritize then
            local head = rewardPreloadState.queueHead
            for index = head, rewardPreloadState.queueTail do
                if rewardPreloadState.queue[index] == questID then
                    if index > head then
                        for shiftIndex = index, head + 1, -1 do
                            rewardPreloadState.queue[shiftIndex] = rewardPreloadState.queue[shiftIndex - 1]
                        end
                        rewardPreloadState.queue[head] = questID
                    end
                    break
                end
            end
        end

        rewardPreloadState.ScheduleDrain()
        return false
    end

    rewardPreloadState.queuedQuestIDs[questID] = true
    if prioritize then
        local head = rewardPreloadState.queueHead
        local tail = rewardPreloadState.queueTail
        if head > tail then
            rewardPreloadState.queueHead = 1
            rewardPreloadState.queueTail = 1
            rewardPreloadState.queue[1] = questID
        elseif head > 1 then
            head = head - 1
            rewardPreloadState.queueHead = head
            rewardPreloadState.queue[head] = questID
        else
            for index = tail, head, -1 do
                rewardPreloadState.queue[index + 1] = rewardPreloadState.queue[index]
            end
            rewardPreloadState.queue[head] = questID
            rewardPreloadState.queueTail = tail + 1
        end
    else
        local nextTail = rewardPreloadState.queueTail + 1
        rewardPreloadState.queueTail = nextTail
        rewardPreloadState.queue[nextTail] = questID
    end

    rewardPreloadState.ScheduleDrain()
    return false
end

function rewardPreloadState.StartPoll()
    if rewardPreloadState.pollActive then return end
    rewardPreloadState.pollActive = true
    rewardPreloadState.pollGeneration = rewardPreloadState.pollGeneration + 1
    local myGeneration = rewardPreloadState.pollGeneration

    local function tick()
        if rewardPreloadState.pollGeneration ~= myGeneration then return end
        if not ns.IsWorldQuestsRefreshContextActive() then
            rewardPreloadState.pollActive = false
            return
        end
        if rewardPreloadState.PollPendingRewardData() then
            C_Timer.After(1.0, tick)
        else
            rewardPreloadState.pollActive = false
        end
    end

    C_Timer.After(1.0, tick)
end

function rewardPreloadState.StopPoll()
    rewardPreloadState.pollGeneration = rewardPreloadState.pollGeneration + 1
    rewardPreloadState.pollActive = false
end

local function SuppressPendingQuestDataAfterFailure(questID)
    requestedQuestData[questID] = nil

    if not ns.IsWorldQuestsRefreshContextActive() then
        return
    end

    if not eventFrame._activeWorldQuestRawIDs[questID] then
        return
    end

    questDataRetrySuppressedUntil[questID] = GetTime() + QUEST_DATA_RETRY_COOLDOWN
    local pendingState = pendingQuestIDs[questID]
    if pendingState then
        pendingState.needsQuestData = true
        pendingState.questDataRefreshDone = false
    else
        pendingQuestIDs[questID] = {
            needsQuestData = true,
            needsRewardData = false,
            questDataRefreshDone = false,
        }
    end
end

-- Repositions questMapTab below the last visible tab that isn't ours.
-- Defined at module scope so both CreateQuestMapTab and the OnShow hook
-- (in a different function scope) can reference it.
RebuildTabAnchor = function()
    if not questMapTab then return end
    local anchor
    if QuestMapFrame and QuestMapFrame.TabButtons then
        for i = #QuestMapFrame.TabButtons, 1, -1 do
            local b = QuestMapFrame.TabButtons[i]
            if b and b ~= questMapTab and b:IsShown() then
                anchor = b
                break
            end
        end
    end
    anchor = anchor
             or (QuestMapFrame and QuestMapFrame.MapLegendTab)
             or (QuestMapFrame and QuestMapFrame.QuestsTab)
    questMapTab:ClearAllPoints()
    if anchor then
        questMapTab:SetPoint("TOP", anchor, "BOTTOM", 0, -3)
    else
        questMapTab:SetPoint("TOPRIGHT", QuestMapFrame, "TOPRIGHT", -6, -100)
    end
end



-- =============================================
-- Settings access
-- =============================================
local function GetSettings()
    return ns.GetWorldQuestsSettings and ns.GetWorldQuestsSettings() or {}
end

local function IsModuleEnabled(settings)
    local resolvedSettings = settings or GetSettings()
    local enabled = resolvedSettings and resolvedSettings.enabled
    if ns.IsModuleRuntimeEnabled then
        return ns.IsModuleRuntimeEnabled("worldQuests", enabled)
    end

    return enabled ~= false
end

local function HasOpenQuestDetailsFrame()
    if not QuestMapFrame then
        return false
    end

    local detailsFrame = QuestMapFrame.DetailsFrame
    return detailsFrame and detailsFrame.IsShown and detailsFrame:IsShown() or false
end

local function UpdateDisplayModeRetryRegistration()
    if pendingDisplayModeSource or pendingBuiltinDisplayModeFallback then
        if not eventFrame._displayModeRetryRegistered then
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            eventFrame._displayModeRetryRegistered = true
        end
    elseif eventFrame._displayModeRetryRegistered then
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame._displayModeRetryRegistered = false
    end
end

local function ClearPendingDisplayModeRequest()
    pendingDisplayModeSource = nil
    UpdateDisplayModeRetryRegistration()
end

local function ClearPendingBuiltinDisplayModeFallback()
    pendingBuiltinDisplayModeFallback = nil
    UpdateDisplayModeRetryRegistration()
end

local function IsCustomWorldQuestsDisplayModeActive()
    return eventFrame.isWorldQuestsDisplayActive == true
end

function ns.IsWorldQuestsRefreshContextActive()
    return (WorldMapFrame and WorldMapFrame:IsShown() or false)
        and (questMapPanel and questMapPanel:IsShown() or false)
        and IsCustomWorldQuestsDisplayModeActive()
end

function eventFrame:ResetWorldQuestsRefreshGateState()
    self:CancelWorldQuestDescendantGather()
    self._lastScheduledWorldQuestsMapID = nil
    self._lastLiveRelevantAreaPOISnapshotCount = nil
    self._lastLiveRelevantAreaPOISnapshotParts = nil
    self._liveRelevantAreaPOIWidgetSetCount = nil
    self._visibleLockedAreaPOIWidgetSetCount = nil
    self._activeRelevantWorldQuestMapID = nil
    self._activeRelevantWorldQuestQuerySignature = nil
    self._visibleLockedAreaPOISnapshot = nil
    if self._liveRelevantAreaPOIWidgetSetIDs then
        wipe(self._liveRelevantAreaPOIWidgetSetIDs)
    end
    if self._visibleLockedAreaPOIWidgetSetIDs then
        wipe(self._visibleLockedAreaPOIWidgetSetIDs)
    end
    wipe(self._sessionScannedQueryMapIDs)
    wipe(self._sessionRawEntries)
    wipe(self._sessionRawEntriesSeen)
    wipe(self._sessionEnrichedEntries)
    wipe(self._sessionEnrichedEntriesSeen)
    wipe(self._sessionQueryStateCache)
    self:InvalidateActiveWorldQuestsLayout()
    rewardPreloadState.StopPoll()
    PruneQuestRequestBookkeeping()
end

function eventFrame:DebugWorldQuestsRefreshTrace(message, detail)
    if not ns.IsDebugEnabled() then
        return
    end

    local safeMessage = tostring(message)
    local isWorldMapShown = WorldMapFrame and WorldMapFrame:IsShown() or false
    local isQuestMapPanelShown = questMapPanel and questMapPanel:IsShown() or false
    local isDisplayActive = IsCustomWorldQuestsDisplayModeActive()
    local suffix = detail and detail ~= "" and (" " .. detail) or ""

    ns.DebugPrint(string_format(
        "WorldQuests: %s%s worldMapShown=%s panelShown=%s displayActive=%s",
        safeMessage,
        suffix,
        tostring(isWorldMapShown),
        tostring(isQuestMapPanelShown),
        tostring(isDisplayActive)))
end

local function ShouldKeepCustomWorldQuestsVisible()
    return pendingBuiltinDisplayModeFallback and IsCustomWorldQuestsDisplayModeActive()
end

local function ResolveFallbackDisplayMode()
    if not QuestMapFrame then
        return nil
    end

    local questsTab = QuestMapFrame.QuestsTab
    if questsTab then
        return questsTab.displayMode or "Quests"
    end

    local mapLegendTab = QuestMapFrame.MapLegendTab
    if mapLegendTab then
        return mapLegendTab.displayMode or "MapLegend"
    end

    local eventsTab = QuestMapFrame.EventsTab
    if eventsTab and eventsTab.IsShown and eventsTab:IsShown() then
        return eventsTab.displayMode or "Events"
    end

    return nil
end

local function RestoreBuiltinDisplayModeIfNeeded()
    if not QuestMapFrame or not QuestMapFrame.SetDisplayMode then
        return false
    end
    if not IsCustomWorldQuestsDisplayModeActive() then
        ClearPendingBuiltinDisplayModeFallback()
        return false
    end

    local fallbackMode = ResolveFallbackDisplayMode()
    if not fallbackMode or fallbackMode == DISPLAY_MODE then
        ClearPendingBuiltinDisplayModeFallback()
        return false
    end

    if InCombatLockdown() then
        pendingBuiltinDisplayModeFallback = true
        UpdateDisplayModeRetryRegistration()
        return false
    end

    ClearPendingBuiltinDisplayModeFallback()
    QuestMapFrame:SetDisplayMode(fallbackMode)
    return true
end

local function CanRequestWorldQuestsDisplayMode(source)
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return false
    end
    if not QuestMapFrame or not QuestMapFrame.SetDisplayMode then
        return false
    end
    local settings = GetSettings()
    if not IsModuleEnabled(settings) then
        return false
    end
    if source == "auto" then
        if settings.openOnWorldQuestsTab ~= true then
            return false
        end
        if HasOpenQuestDetailsFrame() then
            return false
        end
    end
    return true
end

local function RequestWorldQuestsDisplayMode(source)
    source = source == "auto" and "auto" or "manual"

    if not CanRequestWorldQuestsDisplayMode(source) then
        ClearPendingDisplayModeRequest()
        return false
    end

    if QuestMapFrame.GetDisplayMode and QuestMapFrame:GetDisplayMode() == DISPLAY_MODE then
        ClearPendingDisplayModeRequest()
        return true
    end

    if InCombatLockdown() then
        pendingDisplayModeSource = source
        UpdateDisplayModeRetryRegistration()
        return false
    end

    local settings = GetSettings()
    if not IsModuleEnabled(settings) then
        ClearPendingDisplayModeRequest()
        return false
    end

    ClearPendingDisplayModeRequest()
    QuestMapFrame:SetDisplayMode(DISPLAY_MODE)
    return true
end

local function GetCurrentServerTime()
    if GetServerTime then
        return GetServerTime()
    end
    return 0
end

local function ClampWorldQuestFontSize(value, fallback)
    local size = tonumber(value) or fallback
    if not size then
        return 12
    end
    return math.max(8, math.min(30, math_floor(size + 0.5)))
end

local function GetWorldQuestFontConfig()
    local settings = GetSettings()
    local defaults = ns.DEFAULTS and ns.DEFAULTS.worldQuests or {}
    return {
        font = settings.font or defaults.font or ns.GLOBAL_CHOICE_KEY,
        fontOutline = settings.fontOutline or defaults.fontOutline or ns.GLOBAL_CHOICE_KEY,
        titleFontSize = ClampWorldQuestFontSize(settings.titleFontSize, defaults.titleFontSize or 14),
        detailFontSize = ClampWorldQuestFontSize(settings.detailFontSize, defaults.detailFontSize or 11),
        rewardFontSize = ClampWorldQuestFontSize(settings.rewardFontSize, defaults.rewardFontSize or 10),
    }
end

local function ApplyWorldQuestFont(fontString, fontPath, fontSize, fontOutline)
    if fontString and fontString.SetFont then
        fontString:SetFont(fontPath, fontSize, fontOutline)
    end
end

local function ApplyWorldQuestTypographyToRow(row)
    if not row then return end
    if row._typographyVersion == eventFrame._typographyVersion
        and eventFrame._typographyVersion > 0 then
        return
    end
    local config = GetWorldQuestFontConfig()
    local fontPath = ns.GetFontPath and ns.GetFontPath(config.font) or STANDARD_TEXT_FONT
    local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(config.fontOutline) or "OUTLINE"

    ApplyWorldQuestFont(row.titleText, fontPath, config.titleFontSize, fontOutline)
    ApplyWorldQuestFont(row.timeText, fontPath, config.detailFontSize, fontOutline)
    ApplyWorldQuestFont(row.factionText, fontPath, config.detailFontSize, fontOutline)
    ApplyWorldQuestFont(row.moneyText, fontPath, config.detailFontSize, fontOutline)

    for _, rewardButton in ipairs(row.rewardIcons or {}) do
        ApplyWorldQuestFont(rewardButton.countText, fontPath, config.rewardFontSize, fontOutline)
    end
    row._typographyVersion = eventFrame._typographyVersion
end

local function ApplyWorldQuestTypographyToHeader(header)
    if not header then return end
    local config = GetWorldQuestFontConfig()
    local fontPath = ns.GetFontPath and ns.GetFontPath(config.font) or STANDARD_TEXT_FONT
    local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(config.fontOutline) or "OUTLINE"

    ApplyWorldQuestFont(header.label, fontPath, config.titleFontSize, fontOutline)
    ApplyWorldQuestFont(header.countLabel, fontPath, config.detailFontSize, fontOutline)
end

local function ApplyWorldQuestTypography()
    eventFrame._typographyVersion = (eventFrame._typographyVersion or 0) + 1
    local config = GetWorldQuestFontConfig()
    local fontPath = ns.GetFontPath and ns.GetFontPath(config.font) or STANDARD_TEXT_FONT
    local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(config.fontOutline) or "OUTLINE"

    ApplyWorldQuestFont(noQuestsLabel, fontPath, config.detailFontSize, fontOutline)
    ApplyWorldQuestFont(contractNoticeLabel, fontPath, config.detailFontSize, fontOutline)

    for _, row in ipairs(questRowPool) do
        ApplyWorldQuestTypographyToRow(row)
    end
    for _, header in ipairs(zoneHeaderPool) do
        ApplyWorldQuestTypographyToHeader(header)
    end
    for _, item in ipairs(activeContent) do
        if item.type == "row" and item.frame then
            ApplyWorldQuestTypographyToRow(item.frame)
        elseif item.type == "zone" then
            ApplyWorldQuestTypographyToHeader(item.frame)
        end
    end
end

-- =============================================
-- Time utilities
-- =============================================

local function GetQuestExpirySnapshot(questID, serverTime, fallbackEntry)
    local now = serverTime or GetCurrentServerTime()
    local timeLeft
    if C_TaskQuest and C_TaskQuest.GetQuestTimeLeftSeconds then
        timeLeft = C_TaskQuest.GetQuestTimeLeftSeconds(questID)
    else
        local legacyGetQuestTimeLeftMinutes = _G and _G["GetQuestTimeLeftMinutes"] or nil
        local mins = legacyGetQuestTimeLeftMinutes and legacyGetQuestTimeLeftMinutes(questID)
        timeLeft = mins and (mins * 60) or nil
    end
    if timeLeft and timeLeft > 0 then
        return timeLeft, now + timeLeft
    end
    if fallbackEntry then
        local fallbackExpiresAt = fallbackEntry.expiresAt
        if fallbackEntry.rawTimeLeftSeconds and fallbackExpiresAt and fallbackExpiresAt > 0 then
            fallbackEntry.rawTimeLeftSecondsConsumed = true
        end
        if fallbackExpiresAt and fallbackExpiresAt > now then
            return fallbackExpiresAt - now, fallbackExpiresAt
        end

        if fallbackEntry.rawTimeLeftSecondsConsumed ~= true
            and (not fallbackExpiresAt or fallbackExpiresAt <= 0)
        then
            local fallbackTimeLeft = fallbackEntry.rawTimeLeftSeconds
            if fallbackTimeLeft and fallbackTimeLeft > 0 then
                local derivedExpiresAt = now + fallbackTimeLeft
                fallbackEntry.rawTimeLeftSecondsConsumed = true
                fallbackEntry.expiresAt = derivedExpiresAt
                return fallbackTimeLeft, derivedExpiresAt
            end
        end
    end
    return timeLeft, nil
end

-- Formats seconds into a human-readable string: "47m", "2h 36m", "3d".
local function FormatTimeLeft(seconds)
    if not seconds or seconds <= 0 then
        return "---"
    end
    local s = math_floor(seconds)
    if s < 3600 then
        return math_floor(s / 60) .. "m"
    elseif s < 86400 then
        local h = math_floor(s / 3600)
        local m = math_floor((s % 3600) / 60)
        return m > 0 and (h .. "h " .. m .. "m") or (h .. "h")
    else
        local d = math_floor(s / 86400)
        local h = math_floor((s % 86400) / 3600)
        return h > 0 and (d .. "d " .. h .. "h") or (d .. "d")
    end
end

local function GetRemainingTimeLeft(timeLeft, expiresAt, now)
    if timeLeft and timeLeft > 0 then
        return timeLeft
    end
    if expiresAt and expiresAt > now then
        return expiresAt - now
    end
    return nil
end

local function ClearActiveQuestTooltip(anchorFrame)
    if anchorFrame and activeTooltipAnchor ~= anchorFrame then
        return
    end

    activeTooltipAnchor = nil
    activeTooltipQuestID = nil
    activeTooltipShowTrackHint = false
    GameTooltip:Hide()
end

do
local HIGHLIGHT_STATUS_OK = 1
local HIGHLIGHT_STATUS_TRANSIENT_MISS = 2
local HIGHLIGHT_STATUS_INVALID = 3

---@param pin table?
---@return string
function GetHoverPinIdentity(pin)
    if not ns.IsDebugEnabled() then
        return ""
    end

    if not pin then
        return "nil"
    end

    local pinQuestID = rawget(pin, "questID")
    return string_format("%s(q=%s)", tostring(pin), tostring(pinQuestID))
end

---@param status number
---@return string
function GetHoverHighlightStatusName(status)
    if type(status) == "string" then
        return status
    end

    if status == HIGHLIGHT_STATUS_OK then
        return "ok"
    elseif status == HIGHLIGHT_STATUS_TRANSIENT_MISS then
        return "miss"
    elseif status == HIGHLIGHT_STATUS_INVALID then
        return "invalid"
    end

    return tostring(status)
end

function DebugRebindTransition(success, source, questID, row, rowQuestID, reason, hasPOI)
    local rowIdentity = GetHoverRowIdentity(row)
    if activeHoverState._dbgLastRebindResult == success
        and activeHoverState._dbgLastRebindSource == source
        and activeHoverState._dbgLastRebindRowIdentity == rowIdentity
    then
        return
    end

    DebugHoverTrace(
        "Rebind",
        "result=%s source=%s questID=%s row=%s rowQuestID=%s reason=%s poi=%s",
        success and "success" or "failure",
        tostring(source),
        tostring(questID),
        rowIdentity,
        tostring(rowQuestID),
        tostring(reason or ""),
        tostring(hasPOI == true))

    activeHoverState._dbgLastRebindResult = success
    activeHoverState._dbgLastRebindSource = source
    activeHoverState._dbgLastRebindRowIdentity = rowIdentity
end

---@param questID number?
---@return table?
local function FindWorldQuestPinByQuestID(questID)
    if not questID
        or questID <= 0
        or not WorldMapFrame
        or not WorldMapFrame.IsVisible
        or not WorldMapFrame:IsVisible()
        or not WorldMapFrame.EnumeratePinsByTemplate
    then
        return nil
    end

    for pin in WorldMapFrame:EnumeratePinsByTemplate("WorldMap_WorldQuestPinTemplate") do
        if pin and pin.questID == questID then
            return pin
        end
    end

    return nil
end

---@param button Button?
---@return boolean
local function IsChildHoverButtonActuallyHovered(button)
    if not button
        or not button.IsShown
        or not button:IsShown()
        or not button.IsMouseOver
    then
        return false
    end

    return button:IsMouseOver()
end

---@param rewardIcons Button[]?
---@return boolean
local function IsAnyQuestRewardButtonActuallyHovered(rewardIcons)
    if not rewardIcons then
        return false
    end

    for iconIndex = 1, #rewardIcons do
        if IsChildHoverButtonActuallyHovered(rewardIcons[iconIndex]) then
            return true
        end
    end

    return false
end

---@param poiBtn Button?
---@return boolean
local function IsPOIButtonActuallyHovered(poiBtn)
    if not poiBtn then
        return false
    end

    return IsChildHoverButtonActuallyHovered(poiBtn)
end

---@param row Frame?
---@return boolean
local function IsQuestRowActuallyHovered(row)
    if not row
        or not row.IsShown
        or not row:IsShown()
    then
        return false
    end

    if row.IsMouseOver and row:IsMouseOver() then
        return true
    end

    if IsPOIButtonActuallyHovered(rawget(row, "poiBtn")) then
        return true
    end

    if IsChildHoverButtonActuallyHovered(rawget(row, "contractBtn")) then
        return true
    end

    return IsAnyQuestRewardButtonActuallyHovered(rawget(row, "rewardIcons"))
end

local function ResetActiveWorldQuestHoverPinMisses()
    activeHoverState.pinMisses = 0
    activeHoverState.pinMissStart = nil
end

local function ResetActiveWorldQuestHoverSurfaceMisses()
    activeHoverState.surfaceMisses = 0
    activeHoverState.surfaceMissStart = nil
end

---@param row Frame?
local function SetActiveWorldQuestHoverRow(row)
    local previousRow = activeHoverState.row
    local previousHoverBg = previousRow and rawget(previousRow, "hoverBg") or nil
    if previousRow and previousRow ~= row and previousHoverBg then
        previousHoverBg:Hide()
    end

    activeHoverState.row = row
    activeHoverState.poiBtn = row and rawget(row, "poiBtn") or nil

    local hoverBg = row and rawget(row, "hoverBg") or nil
    if hoverBg then
        hoverBg:Show()
    end
end

---@param pin table?
local function ClearNomToolsPinHoverFX(pin)
    if not pin then
        return
    end

    local fx = rawget(pin, "_nomToolsHoverFX")
    if not fx then
        return
    end

    local pulse = fx.pulse
    if pulse and pulse.IsPlaying and pulse:IsPlaying() then
        pulse:Stop()
    end

    local frame = fx.frame
    if frame and frame.Hide then
        frame:Hide()
    end
end

---@param pin table?
---@return table?
local function EnsureNomToolsPinHoverFX(pin)
    if not pin or not pin.CreateTexture then
        return nil
    end

    local fx = rawget(pin, "_nomToolsHoverFX")
    if fx
        and fx.frame
        and fx.innerTexture
        and fx.outerTexture
        and fx.pulse
        and fx.frame.GetParent
        and fx.frame:GetParent() == pin
    then
        return fx
    end

    local frame = CreateFrame("Frame", nil, pin)
    if not frame then
        return nil
    end

    frame:SetAllPoints(pin)
    if frame.SetIgnoreParentAlpha then
        frame:SetIgnoreParentAlpha(true)
    end
    if frame.SetFrameStrata then
        frame:SetFrameStrata("HIGH")
    end
    if frame.SetFrameLevel and pin.GetFrameLevel then
        frame:SetFrameLevel(pin:GetFrameLevel() + 6)
    end

    local outerTexture = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    outerTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)
    outerTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -6)
    outerTexture:SetBlendMode("ADD")
    outerTexture:SetVertexColor(1.00, 0.82, 0.28, 0.75)
    outerTexture:SetTexture("Interface\\Buttons\\WHITE8x8")

    local innerTexture = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    innerTexture:SetAllPoints(frame)
    innerTexture:SetBlendMode("ADD")
    innerTexture:SetVertexColor(1.00, 0.95, 0.55, 1.0)
    innerTexture:SetTexture("Interface\\Buttons\\WHITE8x8")

    local pulse = frame:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")

    local fadeOut = pulse:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetDuration(0.34)
    fadeOut:SetFromAlpha(0.95)
    fadeOut:SetToAlpha(0.42)
    if fadeOut.SetSmoothing then
        fadeOut:SetSmoothing("IN_OUT")
    end

    local fadeIn = pulse:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetDuration(0.24)
    fadeIn:SetFromAlpha(0.42)
    fadeIn:SetToAlpha(0.95)
    if fadeIn.SetSmoothing then
        fadeIn:SetSmoothing("IN_OUT")
    end

    frame:Hide()
    fx = {
        frame = frame,
        outerTexture = outerTexture,
        innerTexture = innerTexture,
        pulse = pulse,
    }
    pin._nomToolsHoverFX = fx
    return fx
end

---@param pin table?
---@return boolean fxReady
local function ApplyNomToolsPinHoverFX(pin)
    if not pin then
        return false
    end

    local fx = EnsureNomToolsPinHoverFX(pin)
    if not fx then
        return false
    end

    local innerTexture = fx.innerTexture
    local outerTexture = fx.outerTexture
    local normalTexture = rawget(pin, "NormalTexture")
    local textureApplied = false

    if innerTexture and outerTexture and normalTexture and normalTexture.GetAtlas then
        local atlas = normalTexture:GetAtlas()
        if atlas and atlas ~= "" then
            innerTexture:SetAtlas(atlas, true)
            outerTexture:SetAtlas(atlas, false)
            textureApplied = true
        end
    end

    if not textureApplied and innerTexture and outerTexture and normalTexture and normalTexture.GetTexture then
        local sourceTexture = normalTexture:GetTexture()
        if sourceTexture then
            innerTexture:SetTexture(sourceTexture)
            outerTexture:SetTexture(sourceTexture)
            textureApplied = true
        end
    end

    if not textureApplied and innerTexture and outerTexture then
        innerTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        outerTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    end

    if activeHoverState.fxPin and activeHoverState.fxPin ~= pin then
        ClearNomToolsPinHoverFX(activeHoverState.fxPin)
    end

    activeHoverState.fxPin = pin
    if fx.frame and fx.frame.Show then
        fx.frame:Show()
    end
    if fx.pulse and fx.pulse.IsPlaying and not fx.pulse:IsPlaying() then
        fx.pulse:Play()
    end

    return true
end

---@param reason string?
local function StopActiveWorldQuestHover(reason)
    local debugEnabled = ns.IsDebugEnabled()
    local stopToken = (activeHoverState.stopToken or 0) + 1
    if debugEnabled then
        local row = activeHoverState.row
        local rowQuestID = row and rawget(row, "questID") or nil
        DebugHoverTrace(
            "Stop",
            "reason=%s questID=%s row=%s rowQuestID=%s ticker=%s stopToken=%s pinMisses=%s surfaceMisses=%s",
            tostring(reason or "unspecified"),
            tostring(activeHoverState.questID),
            GetHoverRowIdentity(row),
            tostring(rowQuestID),
            tostring(activeHoverState.ticker ~= nil),
            tostring(stopToken),
            tostring(activeHoverState.pinMisses or 0),
            tostring(activeHoverState.surfaceMisses or 0))
    end

    activeHoverState.stopToken = (activeHoverState.stopToken or 0) + 1

    local ticker = activeHoverState.ticker
    if ticker then
        ticker:Cancel()
        activeHoverState.ticker = nil
    end

    local row = activeHoverState.row
    local hoverBg = row and rawget(row, "hoverBg") or nil
    if hoverBg then
        hoverBg:Hide()
    end

    activeHoverState.questID = nil
    activeHoverState.row = nil
    activeHoverState.poiBtn = nil
    if activeHoverState.fxPin then
        ClearNomToolsPinHoverFX(activeHoverState.fxPin)
    end
    activeHoverState.fxPin = nil
    ResetActiveWorldQuestHoverPinMisses()
    ResetActiveWorldQuestHoverSurfaceMisses()

    if debugEnabled then
        activeHoverState._dbgLastHovered = nil
        activeHoverState._dbgLastHighlightStatus = nil
        activeHoverState._dbgLastPinFound = nil
        activeHoverState._dbgLastPinIdentity = nil
        activeHoverState._dbgLastTickLogTime = nil
        activeHoverState._dbgLastRebindResult = nil
        activeHoverState._dbgLastRebindSource = nil
        activeHoverState._dbgLastRebindRowIdentity = nil
    end
end

---@return boolean hovered
---@return string source
---@return Frame? row
local function TryRebindActiveWorldQuestHoverRow()
    local questID = activeHoverState.questID
    if not questID or questID <= 0 then
        DebugRebindTransition(false, "none", questID, nil, nil, "invalid-quest", false)
        return false, "none", nil
    end

    local row = activeHoverState.row
    local rowQuestID = row and rawget(row, "questID") or nil
    if row and rowQuestID == questID and IsQuestRowActuallyHovered(row) then
        activeHoverState.poiBtn = rawget(row, "poiBtn")
        DebugRebindTransition(true, "active-row", questID, row, rowQuestID, nil, true)
        return true, "active-row", row
    end

    local poiBtn = activeHoverState.poiBtn
    if poiBtn and IsPOIButtonActuallyHovered(poiBtn) then
        local parentRow = poiBtn.GetParent and poiBtn:GetParent() or nil
        local parentQuestID = parentRow and rawget(parentRow, "questID") or nil
        if parentRow and parentQuestID == questID then
            SetActiveWorldQuestHoverRow(parentRow)
            DebugRebindTransition(true, "poi-parent", questID, parentRow, parentQuestID, nil, true)
            return true, "poi-parent", parentRow
        end
    end

    for itemIndex = 1, #activeContent do
        local item = activeContent[itemIndex]
        local itemRow = item and item.type == "row" and item.frame or nil
        local itemQuestID = itemRow and rawget(itemRow, "questID") or nil
        if itemRow and itemQuestID == questID and IsQuestRowActuallyHovered(itemRow) then
            SetActiveWorldQuestHoverRow(itemRow)
            DebugRebindTransition(true, "activeContent-scan", questID, itemRow, itemQuestID, nil, true)
            return true, "activeContent-scan", itemRow
        end
    end

    if row and rowQuestID ~= questID then
        activeHoverState.row = nil
    end
    if poiBtn then
        local parentRow = poiBtn.GetParent and poiBtn:GetParent() or nil
        local parentQuestID = parentRow and rawget(parentRow, "questID") or nil
        if not parentRow or parentQuestID ~= questID then
            activeHoverState.poiBtn = nil
        end
    end

    DebugRebindTransition(false, "none", questID, row, rowQuestID, "no-hovered-surface", poiBtn ~= nil)
    return false, "none", nil
end

---@param questID number?
---@param forceReplay boolean?
---@return number status
---@return boolean countsAsPinMiss
local function UpdateWorldQuestPinHighlightState(questID, forceReplay)
    if not questID
        or questID <= 0
    then
        return HIGHLIGHT_STATUS_INVALID, false
    end

    local pin = FindWorldQuestPinByQuestID(questID)
    local pinFound = pin ~= nil
    local pinIdentity = GetHoverPinIdentity(pin)
    if not pin then
        if activeHoverState.fxPin then
            ClearNomToolsPinHoverFX(activeHoverState.fxPin)
            activeHoverState.fxPin = nil
        end

        activeHoverState.pinMisses = (activeHoverState.pinMisses or 0) + 1
        if not activeHoverState.pinMissStart then
            activeHoverState.pinMissStart = GetTime and GetTime() or 0
        end
        local statusName = GetHoverHighlightStatusName(HIGHLIGHT_STATUS_TRANSIENT_MISS)
        if activeHoverState._dbgLastHighlightStatus ~= statusName
            or activeHoverState._dbgLastPinFound ~= pinFound
            or activeHoverState._dbgLastPinIdentity ~= pinIdentity
        then
            DebugHoverTrace(
                "PinHighlight",
                "status=%s questID=%s pinFound=%s pin=%s pinMisses=%s forceReplay=%s countsAsPinMiss=true",
                statusName,
                tostring(questID),
                tostring(pinFound),
                pinIdentity,
                tostring(activeHoverState.pinMisses or 0),
                tostring(forceReplay == true))
            activeHoverState._dbgLastHighlightStatus = statusName
            activeHoverState._dbgLastPinFound = pinFound
            activeHoverState._dbgLastPinIdentity = pinIdentity
        end
        return HIGHLIGHT_STATUS_TRANSIENT_MISS, true
    end

    ResetActiveWorldQuestHoverPinMisses()

    local pinChanged = activeHoverState.fxPin ~= pin
    local fxReady = ApplyNomToolsPinHoverFX(pin)
    local statusName
    if not fxReady then
        statusName = GetHoverHighlightStatusName(HIGHLIGHT_STATUS_TRANSIENT_MISS)
    elseif pinChanged then
        statusName = "fx-pin-changed"
    elseif forceReplay then
        statusName = "fx-applied"
    else
        statusName = "fx-running"
    end

    if activeHoverState._dbgLastHighlightStatus ~= statusName
        or activeHoverState._dbgLastPinFound ~= pinFound
        or activeHoverState._dbgLastPinIdentity ~= pinIdentity
    then
        local fx = rawget(pin, "_nomToolsHoverFX")
        local isPlaying = fx and fx.pulse and fx.pulse.IsPlaying and fx.pulse:IsPlaying() or false
        DebugHoverTrace(
            "PinHighlight",
            "status=%s questID=%s pinFound=%s pin=%s pinChanged=%s forceReplay=%s isPlaying=%s countsAsPinMiss=false",
            statusName,
            tostring(questID),
            tostring(pinFound),
            pinIdentity,
            tostring(pinChanged),
            tostring(forceReplay == true),
            tostring(isPlaying))
        activeHoverState._dbgLastHighlightStatus = statusName
        activeHoverState._dbgLastPinFound = pinFound
        activeHoverState._dbgLastPinIdentity = pinIdentity
    end

    if not fxReady then
        return HIGHLIGHT_STATUS_TRANSIENT_MISS, false
    end

    return HIGHLIGHT_STATUS_OK, false
end

---@param forceReplay boolean?
local function TickActiveWorldQuestHover(forceReplay)
    local questID = activeHoverState.questID
    if not questID or questID <= 0 then
        DebugHoverTrace("Tick", "stop-trigger=invalid-quest")
        StopActiveWorldQuestHover("invalid-quest")
        return
    end

    local hovered, rebindSource, rebindRow = TryRebindActiveWorldQuestHoverRow()
    if hovered ~= activeHoverState._dbgLastHovered then
        DebugHoverTrace(
            "Tick",
            "hovered=%s questID=%s source=%s row=%s",
            tostring(hovered),
            tostring(questID),
            tostring(rebindSource),
            GetHoverRowIdentity(rebindRow))
        activeHoverState._dbgLastHovered = hovered
    end

    if hovered then
        ResetActiveWorldQuestHoverSurfaceMisses()
    else
        local now = GetTime and GetTime() or 0
        activeHoverState.surfaceMisses = (activeHoverState.surfaceMisses or 0) + 1
        if activeHoverState.surfaceMisses == 1
            or activeHoverState.surfaceMisses == 4
            or activeHoverState.surfaceMisses == 8
        then
            DebugHoverTrace(
                "Tick",
                "surface-miss milestone=%s questID=%s start=%.2f",
                tostring(activeHoverState.surfaceMisses),
                tostring(questID),
                tonumber(activeHoverState.surfaceMissStart or now) or 0)
        end
        if not activeHoverState.surfaceMissStart then
            activeHoverState.surfaceMissStart = now
        end
        if (now - activeHoverState.surfaceMissStart) > 1.0
            or activeHoverState.surfaceMisses >= 8
        then
            DebugHoverTrace(
                "Tick",
                "stop-trigger=hover-miss questID=%s surfaceMisses=%s elapsed=%.2f",
                tostring(questID),
                tostring(activeHoverState.surfaceMisses or 0),
                now - (activeHoverState.surfaceMissStart or now))
            StopActiveWorldQuestHover("hover-miss")
            return
        end
    end

    local status, countsAsPinMiss = UpdateWorldQuestPinHighlightState(questID, forceReplay)
    if status == HIGHLIGHT_STATUS_INVALID then
        DebugHoverTrace("Tick", "stop-trigger=invalid-highlight")
        StopActiveWorldQuestHover("invalid-highlight")
        return
    end

    if status == HIGHLIGHT_STATUS_TRANSIENT_MISS and countsAsPinMiss then
        local now = GetTime and GetTime() or 0
        local missStart = activeHoverState.pinMissStart or now
        local pinMisses = activeHoverState.pinMisses or 0
        if pinMisses == 1 or pinMisses == 4 or pinMisses == 8 then
            DebugHoverTrace(
                "Tick",
                "pin-miss milestone=%s questID=%s start=%.2f",
                tostring(pinMisses),
                tostring(questID),
                tonumber(missStart) or 0)
        end
        if (now - missStart) > 1.0 or activeHoverState.pinMisses >= 8 then
            DebugHoverTrace(
                "Tick",
                "stop-trigger=pin-miss questID=%s pinMisses=%s elapsed=%.2f",
                tostring(questID),
                tostring(activeHoverState.pinMisses or 0),
                now - missStart)
            StopActiveWorldQuestHover("pin-miss")
        end
    end

    local now = GetTime and GetTime() or 0
    if not activeHoverState._dbgLastTickLogTime
        or (now - activeHoverState._dbgLastTickLogTime) >= 1.0
    then
        DebugHoverTrace(
            "TickHeartbeat",
            "questID=%s hovered=%s status=%s pinMisses=%s surfaceMisses=%s",
            tostring(questID),
            tostring(hovered),
            tostring(activeHoverState._dbgLastHighlightStatus or "none"),
            tostring(activeHoverState.pinMisses or 0),
            tostring(activeHoverState.surfaceMisses or 0))
        activeHoverState._dbgLastTickLogTime = now
    end
end

local function EnsureActiveWorldQuestHoverTicker()
    local questID = activeHoverState.questID
    if activeHoverState.ticker
        or not questID
        or questID <= 0
        or not C_Timer
        or not C_Timer.NewTicker
    then
        if activeHoverState.ticker and questID and questID > 0 then
            DebugHoverTrace("Ticker", "already-running questID=%s", tostring(questID))
        end
        return
    end

    DebugHoverTrace("Ticker", "create questID=%s", tostring(questID))
    activeHoverState.ticker = C_Timer.NewTicker(0.15, function()
        TickActiveWorldQuestHover(false)
    end)
end

---@param row Frame?
---@param questID number?
---@param forceReplay boolean?
activeHoverState.StartOrResume = function(row, questID, forceReplay, source, context)
    if not questID or questID <= 0 then
        return
    end

    local previousQuestID = activeHoverState.questID
    local rowQuestID = row and rawget(row, "questID") or nil
    local rowHovered = IsQuestRowActuallyHovered(row)
    DebugHoverTrace(
        "StartOrResume",
        "source=%s context=%s questID=%s previousQuestID=%s forceReplay=%s questSwitch=%s row=%s rowQuestID=%s rowHovered=%s",
        tostring(source or "unknown"),
        tostring(context or ""),
        tostring(questID),
        tostring(previousQuestID),
        tostring(forceReplay == true),
        tostring(previousQuestID ~= questID),
        GetHoverRowIdentity(row),
        tostring(rowQuestID),
        tostring(rowHovered))

    activeHoverState.stopToken = (activeHoverState.stopToken or 0) + 1

    if activeHoverState.questID ~= questID then
        StopActiveWorldQuestHover("quest-changed")
        activeHoverState.questID = questID
    end

    if row and rowQuestID == questID then
        SetActiveWorldQuestHoverRow(row)
    else
        local activeRow = activeHoverState.row
        local activeRowQuestID = activeRow and rawget(activeRow, "questID") or nil
        if activeRow and activeRowQuestID ~= questID then
            activeHoverState.row = nil
            activeHoverState.poiBtn = nil
        end
    end

    ResetActiveWorldQuestHoverSurfaceMisses()
    EnsureActiveWorldQuestHoverTicker()
    TickActiveWorldQuestHover(forceReplay)
end

---@param questID number?
activeHoverState.DeferStop = function(questID, reason)
    if not questID or questID <= 0 then
        return
    end

    local stopToken = (activeHoverState.stopToken or 0) + 1
    activeHoverState.stopToken = stopToken
    DebugHoverTrace(
        "DeferStop",
        "scheduled token=%s reason=%s questID=%s",
        tostring(stopToken),
        tostring(reason or "leave"),
        tostring(questID))

    if not C_Timer or not C_Timer.After then
        if activeHoverState.questID == questID and not TryRebindActiveWorldQuestHoverRow() then
            DebugHoverTrace("DeferStop", "callback outcome=stopped reason=no-timer")
            StopActiveWorldQuestHover("leave")
        else
            DebugHoverTrace("DeferStop", "callback outcome=kept reason=rebind-or-quest-mismatch")
        end
        return
    end

    C_Timer.After(0, function()
        if activeHoverState.stopToken ~= stopToken or activeHoverState.questID ~= questID then
            DebugHoverTrace(
                "DeferStop",
                "callback outcome=kept reason=token-or-quest-changed token=%s liveToken=%s liveQuestID=%s",
                tostring(stopToken),
                tostring(activeHoverState.stopToken),
                tostring(activeHoverState.questID))
            return
        end
        if TryRebindActiveWorldQuestHoverRow() then
            ResetActiveWorldQuestHoverSurfaceMisses()
            DebugHoverTrace("DeferStop", "callback outcome=kept reason=rebind-hovered")
            return
        end
        DebugHoverTrace("DeferStop", "callback outcome=stopped reason=leave")
        StopActiveWorldQuestHover("leave")
    end)
end

---@param row Frame?
activeHoverState.ResumeForShownRow = function(row, source)
    local rowQuestID = row and rawget(row, "questID") or nil
    if not row
        or not activeHoverState.questID
        or rowQuestID ~= activeHoverState.questID
    then
        return
    end

    local isHovered = IsQuestRowActuallyHovered(row)
    DebugHoverTrace(
        "ResumeForShownRow",
        "source=%s questID=%s row=%s hovered=%s",
        tostring(source or "unknown"),
        tostring(rowQuestID),
        GetHoverRowIdentity(row),
        tostring(isHovered))

    if isHovered then
        activeHoverState.StartOrResume(row, rowQuestID, false, "resume-for-shown-row", source)
    end
end
end

local function BuildContractAuraFactionMap()
    local auraMap = {}
    local contractConfigs = ns.WORLD_QUEST_CONTRACTS or {}

    for _, contract in ipairs(contractConfigs) do
        if type(contract) == "table" and type(contract.label) == "string" then
            for _, spellID in ipairs(contract.buffIDs or {}) do
                if type(spellID) == "number" and spellID > 0 then
                    auraMap[spellID] = contract.label
                end
            end
        end
    end

    return auraMap
end

local CONTRACT_AURA_FACTIONS = BuildContractAuraFactionMap()

local function GetContractDisplayName(name)
    if type(name) ~= "string" then
        return ""
    end
    return (string_gsub(name, "^The%s+", ""))
end

local function NormalizeFactionName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    local normalized = string_lower(name)
    normalized = string_gsub(normalized, "^the%s+", "")
    normalized = string_gsub(normalized, "[%s%'%-]", "")
    return normalized ~= "" and normalized or nil
end

local function DoesFactionMatchContract(contractInfo, factionName)
    return contractInfo
        and contractInfo.normalizedFactionName
        and NormalizeFactionName(factionName) == contractInfo.normalizedFactionName
end

local function GetActiveContractAura()
    if not C_UnitAuras then
        return nil
    end

    for spellID, factionName in pairs(CONTRACT_AURA_FACTIONS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID
            and C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if not aura and AuraUtil and AuraUtil.FindAuraBySpellID then
            aura = AuraUtil.FindAuraBySpellID(spellID, "player", "HELPFUL")
        end
        if aura then
            return {
                aura = aura,
                spellID = spellID,
                factionName = factionName,
                displayName = GetContractDisplayName(factionName),
                normalizedFactionName = NormalizeFactionName(factionName),
            }
        end
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

local function FindRelevantActiveContract()
    local activeContract = GetActiveContractAura()
    if not activeContract or not activeContract.normalizedFactionName then
        return nil
    end

    return {
        factionName = activeContract.factionName,
        displayName = activeContract.displayName,
        normalizedFactionName = activeContract.normalizedFactionName,
        auraName = activeContract.aura.name,
        spellID = activeContract.spellID,
        auraInstanceID = activeContract.aura.auraInstanceID,
        remainingSeconds = GetAuraRemainingSeconds(activeContract.aura),
    }
end

local function RefreshContractNotice()
    currentRelevantContract = FindRelevantActiveContract()

    if not contractNoticeFrame or not contractNoticeLabel
        or not UpdateContractNoticeLayout
    then
        return
    end

    if currentRelevantContract then
        local message = "Active Contract: " .. currentRelevantContract.displayName
        if currentRelevantContract.remainingSeconds
            and currentRelevantContract.remainingSeconds > 0
        then
            message = message .. " (" .. FormatTimeLeft(currentRelevantContract.remainingSeconds) .. " remaining)"
        end
        message = message .. "."
        contractNoticeLabel:SetText(message)
        contractNoticeLabel:SetTextColor(
            COL.contractNotice[1], COL.contractNotice[2], COL.contractNotice[3])
    else
        contractNoticeLabel:SetText("No active contract.")
        contractNoticeLabel:SetTextColor(
            COL.contractNoticeNone[1], COL.contractNoticeNone[2], COL.contractNoticeNone[3])
    end
end

-- Returns r, g, b values for the expiry dot based on seconds remaining.
local function GetDotColor(seconds)
    local dotColor
    if not seconds then
        dotColor = COL.dotOk
    elseif seconds < TIME_RED then
        dotColor = COL.dotRed
    elseif seconds < TIME_ORANGE then
        dotColor = COL.dotOrange
    elseif seconds < TIME_YELLOW then
        dotColor = COL.dotYellow
    else
        dotColor = COL.dotOk
    end
    return dotColor[1], dotColor[2], dotColor[3]
end

-- =============================================
-- Quest classification helpers  (tag, expansion, reward type)
-- =============================================

-- World quest activity type constants from Enum.QuestTagType.
-- info.worldQuestType (NOT info.tagID) is the correct discriminator for world
-- quest activity type.  Values from Blizzard's Enum.QuestTagType global at
-- addon load; numeric fallbacks verified from WorldQuestTracker's in-game dump:
--   TAG=0, PROF=1, NORMAL=2, PVP=3, PET_BATTLE=4, BOUNTY=5, DUNGEON=6,
--   INVASION=7, RAID=8, INVASION_WRAPPER=11, CAPSTONE=17
local WQT_PVP, WQT_PET, WQT_DUNGEON, WQT_RAID, WQT_DELVE, WQT_CAPSTONE
do
    local e = Enum.QuestTagType
    WQT_PVP     = (e and e.PvP)       or 3
    WQT_PET     = (e and e.PetBattle) or 4
    WQT_DUNGEON = (e and e.Dungeon)   or 6
    WQT_RAID    = (e and e.Raid)      or 8
    WQT_DELVE   = e and rawget(e, "Delve") -- nil if not defined in this client version
    WQT_CAPSTONE = (e and e.Capstone) or 17
end
-- Dragon-racing / skyriding uses tagID not worldQuestType (confirmed: WQT IsRacingQuest).
-- Keep the legacy special-assignment tagID as a fallback, but prefer capstone
-- worldQuestType / questTagType for both classification and gather-time admission.
local TAG_ID_SPECIAL_ASSIGNMENT = 286
local TAG_ID_SPECIAL_ASSIGNMENT_BLOCKER = 287
local TAG_ID_RACING = 281

local function IsSpecialAssignmentTagID(rawTagID)
    return rawTagID == TAG_ID_SPECIAL_ASSIGNMENT
        or rawTagID == TAG_ID_SPECIAL_ASSIGNMENT_BLOCKER
end

local function IsSpecialAssignmentFromMetadata(rawQuestTagType, rawTagID, questType)
    return questType == "special_assignment"
        or rawQuestTagType == WQT_CAPSTONE
        or IsSpecialAssignmentTagID(rawTagID)
end

local function IsSpecialAssignmentQuest(questID, rawQuestTagType, rawTagID, questType, returnConfirmationState)
    if IsSpecialAssignmentFromMetadata(rawQuestTagType, rawTagID, questType) then
        if returnConfirmationState then
            return true, true
        end
        return true
    end

    if questID and C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local info = C_QuestLog.GetQuestTagInfo(questID)
        if info then
            local isSpecialAssignment = IsSpecialAssignmentFromMetadata(
                info.worldQuestType,
                info.tagID,
                questType)
            if returnConfirmationState then
                return isSpecialAssignment, true
            end
            return isSpecialAssignment
        end
    end

    if returnConfirmationState then
        return false, false
    end

    return false
end

local function ResolveQuestLockedState(questID, baseEntry)
    local isLocked = baseEntry and baseEntry.isLocked == true or false
    if not isLocked then
        return false
    end

    if baseEntry.isAreaPOI then
        return true
    end

    if not IsSpecialAssignmentFromMetadata(
        baseEntry.rawQuestTagType,
        baseEntry.rawTagID,
        baseEntry.questType)
    then
        return true
    end

    if C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(questID) then
        return false
    end

    return true
end

local function GetPersistedLockedSpecialAssignmentExpiresAt(
    questID,
    isLocked,
    rawQuestTagType,
    rawTagID,
    questType,
    timeLeft,
    expiresAt)
    if expiresAt or timeLeft ~= nil then
        return expiresAt
    end

    if not isLocked or not currentQuestEntries or #currentQuestEntries == 0 then
        return nil
    end

    if not IsSpecialAssignmentFromMetadata(rawQuestTagType, rawTagID, questType) then
        return nil
    end

    local currentServerTime
    for _, existingEntry in ipairs(currentQuestEntries) do
        if existingEntry.questID == questID and existingEntry.expiresAt then
            currentServerTime = currentServerTime or GetCurrentServerTime()
            if existingEntry.expiresAt > currentServerTime then
                return existingEntry.expiresAt
            end
        end
    end

    return nil
end

-- Human-readable labels kept in display order (used by the filter UI).
local QUEST_TYPE_ORDER = {
    "account_wide", "special_assignment", "normal", "raid", "dungeon",
    "delve", "pvp", "skyriding", "pet_battle",
}
local QUEST_TYPE_LABEL = {
    account_wide = "Account-Wide",
    special_assignment = "Special Assignment",
    normal       = "Regular",
    raid         = "Raid",
    dungeon      = "Dungeon",
    delve        = "Delve",
    pvp          = "PvP",
    skyriding    = "Skyriding / Race",
    pet_battle   = "Pet Battle",
}

-- Cache: cleared per-quest by QUEST_DATA_LOAD_RESULT so stale "normal"
-- defaults from unloaded data don't persist.
local questTypeCache = {}

local function GetQuestType(questID, rawQuestTagType, rawTagID)
    if questTypeCache[questID] then return questTypeCache[questID] end

    -- Guard: if quest data hasn't loaded, tag info will be nil and we'd
    -- permanently mis-classify the quest as "normal".  Return nil to signal
    -- "unknown" rather than poison the cache.
    if not eventFrame:IsQuestCoreDataReady(questID) then
        if IsSpecialAssignmentQuest(questID, rawQuestTagType, rawTagID) then
            return "special_assignment"
        end
        return nil
    end

    local t = "normal"
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local info = C_QuestLog.GetQuestTagInfo(questID)
        if info then
            local wqt = info.worldQuestType
            if     wqt == WQT_CAPSTONE then t = "special_assignment"
            elseif wqt == WQT_PVP     then t = "pvp"
            elseif wqt == WQT_PET     then t = "pet_battle"
            elseif wqt == WQT_DUNGEON then t = "dungeon"
            elseif wqt == WQT_RAID    then t = "raid"
            elseif WQT_DELVE and wqt == WQT_DELVE then t = "delve"
            end
            if t == "normal" then
                if IsSpecialAssignmentTagID(info.tagID) then
                    t = "special_assignment"
                elseif info.tagID == TAG_ID_RACING then
                    t = "skyriding"
                end
            end
        end
    end
    if t == "normal" and IsSpecialAssignmentQuest(questID, rawQuestTagType, rawTagID) then
        t = "special_assignment"
    end
    if t == "normal" and C_QuestLog and C_QuestLog.IsAccountQuest then
        if C_QuestLog.IsAccountQuest(questID) then t = "account_wide" end
    end
    questTypeCache[questID] = t
    return t
end

-- Reward type priority order (highest first) for sort-by-reward.
-- "currency" covers both general currency and progression resources.
local REWARD_TYPE_PRIORITY = {
    gear = 1, currency = 2, rep = 3,
    pet  = 4, gold = 5, other = 6,
}
local REWARD_TYPE_ORDER = {
    "gear", "currency", "rep", "pet", "gold", "other",
}
local REWARD_TYPE_LABEL = {
    gear     = "Gear",
    currency = "Currency / Resources",
    rep      = "Reputation",
    pet      = "Pet",
    gold     = "Gold",
    other    = "Other Items",
}

do
    local function IsActualGearRewardClass(classID, subclassID)
        local itemClass = Enum and Enum.ItemClass
        if not itemClass then
            return false
        end

        if classID == itemClass.Weapon or classID == itemClass.Armor then
            return true
        end

        local itemGemSubclass = Enum and Enum.ItemGemSubclass
        return itemGemSubclass
            and itemClass.Gem
            and itemGemSubclass.Artifactrelic
            and classID == itemClass.Gem
            and subclassID == itemGemSubclass.Artifactrelic
    end

    ns._WorldQuestsIsActualGearRewardItem = function(itemID)
        if not itemID or not C_Item or not C_Item.GetItemInfoInstant then
            return false
        end

        local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
        return IsActualGearRewardClass(classID, subclassID)
    end

    ns._WorldQuestsShouldShowRewardItemLevel = function(rewardData)
        return rewardData
            and rewardData.rewardType == "item"
            and rewardData.ilvl and rewardData.ilvl > 0
            and ns._WorldQuestsIsActualGearRewardItem(rewardData.itemID)
    end
end

-- Maps a single reward entry to a canonical reward-type string.
local function ClassifyRewardEntry(rd)
    if rd.rewardType == "gold" then return "gold" end
    if rd.rewardType == "rep"  then return "rep"  end
    if rd.rewardType == "currency" then
        -- Currency and resource currencies are combined into a single filter type.
        return "currency"
    end
    if rd.rewardType == "item" then
        if rd.itemID then
            local _, _, itemSubType = C_Item.GetItemInfoInstant(rd.itemID)
            if ns._WorldQuestsIsActualGearRewardItem(rd.itemID) then
                return "gear"
            end
            if itemSubType == "Battle Pets" or itemSubType == "Companion Pets" then
                return "pet"
            end
        end
        return "other"
    end
    return "other"
end

-- Returns the single highest-priority reward type for a quest's reward list.
-- Used for sorting and display filtering.
local function GetPrimaryRewardType(rewards)
    local best = "other"
    local bestPrio = REWARD_TYPE_PRIORITY["other"]
    for _, rd in ipairs(rewards) do
        local rtype = ClassifyRewardEntry(rd)
        local prio = REWARD_TYPE_PRIORITY[rtype] or 99
        if prio < bestPrio then
            best = rtype
            bestPrio = prio
        end
    end
    return best
end

-- ── Expansion detection ───────────────────────────────────────────────────────
-- Uses QuestUtils_GetQuestExpansion when available (Retail 10.1+).
-- Falls back to C_QuestLog.GetQuestExpansion.
local function GetQuestExpansionID(questID)
    local getQuestExpansion = _G and _G["QuestUtils_GetQuestExpansion"]
    if getQuestExpansion then
        return getQuestExpansion(questID)
    end
    if C_QuestLog and C_QuestLog.GetQuestExpansion then
        return C_QuestLog.GetQuestExpansion(questID)
    end
    return nil
end

-- Human-readable expansion names keyed by Blizzard's LE_EXPANSION_* values.
local EXPANSION_LABELS = {}
do
    -- Populate from Blizzard's own LE_EXPANSION_* globals if present.
    local map = {
        [0]  = "Classic",
        [1]  = "The Burning Crusade",
        [2]  = "Wrath of the Lich King",
        [3]  = "Cataclysm",
        [4]  = "Mists of Pandaria",
        [5]  = "Warlords of Draenor",
        [6]  = "Legion",
        [7]  = "Battle for Azeroth",
        [8]  = "Shadowlands",
        [9]  = "Dragonflight",
        [10] = "The War Within",
        [11] = "Midnight",
    }
    for k, v in pairs(map) do EXPANSION_LABELS[k] = v end
end

-- =============================================
-- Quest data gathering
-- =============================================

-- Returns the display title for a quest, or nil when quest data has not
-- loaded yet.  Intentionally never caches — pre-data-load fallbacks like
-- "Quest #12345" would persist permanently in the old cache and never be
-- replaced by the real title when it arrived.
-- questID: number
local function GetQuestTitle(questID)
    -- Primary: C_QuestLog is the authoritative title source in 12.0.
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title and title ~= "" then return title end
    end
    -- Secondary: C_TaskQuest variant (task-quest specific, returns title
    -- as first return value).  Only useful once the server has sent data.
    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local title = C_TaskQuest.GetQuestInfoByQuestID(questID)
        if title and title ~= "" then return title end
    end
    -- No data yet — return nil so callers know the title is pending.
    return nil
end

function eventFrame:IsQuestCoreDataReady(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return true
    end

    if HaveQuestData and not HaveQuestData(questID) then
        return false
    end

    local title = GetQuestTitle(questID)
    return title ~= nil and title ~= ""
end

function eventFrame:QueueQuestCoreDataLoad(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return true
    end

    if self:IsQuestCoreDataReady(questID) then
        requestedQuestData[questID] = nil
        questDataRetrySuppressedUntil[questID] = nil
        return true
    end

    if not C_QuestLog or not C_QuestLog.RequestLoadQuestByID then
        return false
    end

    local now = GetTime()
    local retryAt = questDataRetrySuppressedUntil[questID]
    if retryAt and retryAt <= now then
        questDataRetrySuppressedUntil[questID] = nil
        retryAt = nil
    end

    if retryAt and retryAt > now then
        EnsureQuestDataRetryRefresh()
        return false
    end

    if requestedQuestData[questID] then
        return false
    end

    C_QuestLog.RequestLoadQuestByID(questID)
    requestedQuestData[questID] = true
    return false
end

local function NormalizeInlineQuestText(text)
    if not text or text == "" then
        return nil
    end

    local normalized = string_gsub(text, "[\r\n]+", " ")
    normalized = string_gsub(normalized, "%s+", " ")
    normalized = string_gsub(normalized, "^%s+", "")
    normalized = string_gsub(normalized, "%s+$", "")
    if normalized == "" then
        return nil
    end

    return normalized
end

do
    local function CompareAreaPOITimeWidgets(leftWidget, rightWidget)
        local leftOrder = leftWidget.orderIndex or 0
        local rightOrder = rightWidget.orderIndex or 0
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end

        local leftType = leftWidget.widgetType or 0
        local rightType = rightWidget.widgetType or 0
        if leftType ~= rightType then
            return leftType < rightType
        end

        return (leftWidget.widgetID or 0) < (rightWidget.widgetID or 0)
    end

    function eventFrame:IsAreaPOITimeText(text)
        if not text or text == "" or not string_find(text, "%d") then
            return false
        end

        local lowerText = string_lower(text)
        return string_find(lowerText, "^%d+:%d%d$") ~= nil
            or string_find(lowerText, "^%d+:%d%d:%d%d$") ~= nil
            or string_find(lowerText, "^%d+%s*[dhms]$") ~= nil
            or string_find(lowerText, "^%d+%s*[dhms]%s+%d+%s*[dhms]$") ~= nil
            or string_find(lowerText, "^%d+%s*[dhms]%s+%d+%s*[dhms]%s+%d+%s*[dhms]$") ~= nil
            or string_find(lowerText, "^%d+%s*day[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*hour[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*hr[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*min[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*minute[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*sec[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*second[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*day[s]?%s+%d+%s*hour[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*hour[s]?%s+%d+%s*min[s]?$") ~= nil
            or string_find(lowerText, "^%d+%s*hr[s]?%s+%d+%s*min[s]?$") ~= nil
    end

    function eventFrame:GetAreaPOITimeTextFromStatusBarWidgetInfo(info)
        if not info or not info.hasTimer then
            return nil
        end

        if info.overrideBarText and info.overrideBarText ~= "" then
            return NormalizeInlineQuestText(info.overrideBarText)
        end

        if info.text and info.text ~= "" then
            return NormalizeInlineQuestText(info.text)
        end

        return nil
    end

    function eventFrame:GetAreaPOITimeTextFromTextWithStateWidgetInfo(info)
        if not info or not info.text or info.text == "" then
            return nil
        end

        local text = NormalizeInlineQuestText(info.text)
        if self:IsAreaPOITimeText(text) then
            return text
        end

        return nil
    end

    function eventFrame:GetCurrentAreaPOITimeText(widgetSetID)
        if not widgetSetID or widgetSetID <= 0 or not C_UIWidgetManager
            or not C_UIWidgetManager.GetAllWidgetsBySetID
        then
            return nil
        end

        local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID)
        if not widgets or #widgets == 0 then
            return nil
        end

        local orderedWidgets = self._currentAreaPOITimeWidgets or {}
        local widgetCount = #widgets

        self._currentAreaPOITimeWidgets = orderedWidgets

        for index = 1, widgetCount do
            orderedWidgets[index] = widgets[index]
        end

        for index = widgetCount + 1, #orderedWidgets do
            orderedWidgets[index] = nil
        end

        table_sort(orderedWidgets, CompareAreaPOITimeWidgets)

        for index = 1, widgetCount do
            local widgetInfo = orderedWidgets[index]
            if widgetInfo.widgetType == 2 and C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo then
                local timeText = self:GetAreaPOITimeTextFromStatusBarWidgetInfo(
                    C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetInfo.widgetID))
                if timeText then
                    return timeText
                end
            elseif widgetInfo.widgetType == 8
                and C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo
            then
                local timeText = self:GetAreaPOITimeTextFromTextWithStateWidgetInfo(
                    C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgetInfo.widgetID))
                if timeText then
                    return timeText
                end
            end
        end

        return nil
    end
end

local function GetLockedSpecialAssignmentUnlockText(questID)
    local numObjectives = C_QuestLog and C_QuestLog.GetNumQuestObjectives
        and C_QuestLog.GetNumQuestObjectives(questID) or 0
    if numObjectives and numObjectives > 0 then
        for objectiveIndex = 1, numObjectives do
            local objectiveText
            if GetQuestObjectiveInfo then
                objectiveText = GetQuestObjectiveInfo(questID, objectiveIndex, false)
            end
            objectiveText = NormalizeInlineQuestText(objectiveText)
            if objectiveText then
                return objectiveText
            end
        end
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID and GetQuestLogQuestText then
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if logIndex and logIndex > 0 then
            local questDescription, questObjectives = GetQuestLogQuestText(logIndex)
            questObjectives = NormalizeInlineQuestText(questObjectives)
            if questObjectives then
                return questObjectives
            end

            questDescription = NormalizeInlineQuestText(questDescription)
            if questDescription then
                return questDescription
            end
        end
    end

    return "Unlock requirements not available yet."
end

do
    local function WithSelectedQuestLogEntry(questID, callback)
        if not questID or questID <= 0 or type(callback) ~= "function"
            or not C_QuestLog or not C_QuestLog.GetLogIndexForQuestID
        then
            return nil
        end

        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local getSelection = _G and _G["GetQuestLogSelection"]
        local selectEntry = _G and _G["SelectQuestLogEntry"]
        if not logIndex or logIndex <= 0
            or type(getSelection) ~= "function"
            or type(selectEntry) ~= "function"
        then
            return nil
        end

        local previousSelection = getSelection()
        if previousSelection ~= nil and type(previousSelection) ~= "number" then
            return nil
        end
        previousSelection = previousSelection or 0

        local didSelect = pcall(selectEntry, logIndex)
        if not didSelect then
            return nil
        end

        local ok, result = pcall(callback, logIndex)
        pcall(selectEntry, previousSelection)

        if not ok then
            return nil
        end
        return result
    end

    local function ParseLegacyQuestRewardFactionEntry(...)
        local values = { ... }
        local label
        local icon
        local factionID
        local numericCandidates = {}

        for _, value in ipairs(values) do
            if type(value) == "string" and value ~= "" then
                if not label
                    and not string_find(value, "\\", 1, true)
                    and not string_find(value, "/", 1, true)
                then
                    label = value
                elseif not icon
                    and (string_find(value, "\\", 1, true)
                        or string_find(value, "/", 1, true))
                then
                    icon = value
                end
            elseif type(value) == "number" and value > 0 then
                numericCandidates[#numericCandidates + 1] = value
                if not icon and value >= 10000 then
                    icon = value
                end
            end
        end

        local normalizedLabel = NormalizeFactionName(label)
        if C_Reputation and C_Reputation.GetFactionDataByID then
            for _, value in ipairs(numericCandidates) do
                if value < 10000 then
                    local data = C_Reputation.GetFactionDataByID(value)
                    if data and data.name and data.name ~= "" then
                        local normalizedDataName = NormalizeFactionName(data.name)
                        if not normalizedLabel or normalizedDataName == normalizedLabel then
                            factionID = value
                            label = data.name
                            if data["texture"] then
                                icon = data["texture"]
                            end
                            break
                        end
                    end
                end
            end
        end

        local smallestAmountCandidate
        local amountCandidateCount = 0
        for _, value in ipairs(numericCandidates) do
            if value ~= factionID and value < 10000 then
                amountCandidateCount = amountCandidateCount + 1
                if not smallestAmountCandidate or value < smallestAmountCandidate then
                    smallestAmountCandidate = value
                end
            end
        end

        local amount = nil
        if amountCandidateCount > 0 then
            amount = smallestAmountCandidate
        end

        if not label or label == "" then
            return nil
        end

        return {
            label = label,
            icon = icon,
            amount = amount,
            factionID = factionID,
        }
    end

    ns._WorldQuestsGetLegacySelectedQuestRewardFactions = function(questID)
        return WithSelectedQuestLogEntry(questID, function()
            local entries = {}
            local entryByKey = {}

            local function MergeEntry(parsed)
                if not parsed or not parsed.label or parsed.label == "" then
                    return
                end

                local key = nil
                if parsed.factionID and parsed.factionID > 0 then
                    key = "id:" .. parsed.factionID
                else
                    local normalizedLabel = NormalizeFactionName(parsed.label)
                    if normalizedLabel then
                        key = "name:" .. normalizedLabel
                    end
                end
                if not key then
                    return
                end

                local existing = entryByKey[key]
                if existing then
                    if parsed.amount and parsed.amount ~= 0 then
                        existing.amount = (existing.amount or 0) + parsed.amount
                    end
                    if not existing.icon and parsed.icon then
                        existing.icon = parsed.icon
                    end
                    if not existing.factionID and parsed.factionID then
                        existing.factionID = parsed.factionID
                    end
                    return
                end

                local entry = {
                    label = parsed.label,
                    icon = parsed.icon,
                    amount = parsed.amount,
                    factionID = parsed.factionID,
                }
                entries[#entries + 1] = entry
                entryByKey[key] = entry
            end

            local function ConsumeProvider(provider)
                if type(provider) ~= "function" then
                    return
                end

                for rewardIndex = 1, 8 do
                    local ok, value1, value2, value3, value4, value5, value6, value7 =
                        pcall(provider, rewardIndex)
                    if not ok then
                        break
                    end
                    if value1 == nil and value2 == nil and value3 == nil and value4 == nil
                        and value5 == nil and value6 == nil and value7 == nil
                    then
                        break
                    end

                    MergeEntry(ParseLegacyQuestRewardFactionEntry(
                        value1, value2, value3, value4, value5, value6, value7))
                end
            end

            ConsumeProvider(_G and _G["GetQuestLogRewardFactionInfo"])
            ConsumeProvider(_G and _G["GetQuestLogChoiceRewardFactionInfo"])

            if #entries == 1 and (not entries[1].amount or entries[1].amount == 0) then
                local getQuestRewardReputation = _G and _G["GetQuestRewardReputation"]
                if type(getQuestRewardReputation) == "function" then
                    local ok, amount = pcall(getQuestRewardReputation)
                    if ok and type(amount) == "number" and amount > 0 then
                        entries[1].amount = amount
                    end
                end
            end

            return entries
        end)
    end
end

local function GetQuestFactionLabel(questID)
    -- No caching — queries are cheap C-side lookups once data is loaded.
    --
    -- Match Blizzard's world-map tooltip behaviour first: contracts can
    -- intentionally rewrite the displayed world-quest faction for the
    -- relevant cluster, and that association comes from C_TaskQuest.
    if HaveQuestData and not HaveQuestData(questID) then
        return nil
    end

    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local _, factionID = C_TaskQuest.GetQuestInfoByQuestID(questID)
        if factionID and factionID > 0
            and C_Reputation and C_Reputation.GetFactionDataByID
        then
            local data = C_Reputation.GetFactionDataByID(factionID)
            if data and data.name and data.name ~= "" then
                return data.name
            end
        end
    end

    if HaveQuestRewardData and not HaveQuestRewardData(questID) then
        return nil
    end

    -- Fallback 1: major-faction reward entries when no task faction exists.
    if C_QuestLog and C_QuestLog.GetQuestLogMajorFactionReputationRewards
    then
        local reps = C_QuestLog.GetQuestLogMajorFactionReputationRewards(questID)
        if reps and #reps > 0 then
            for i = #reps, 1, -1 do
                local entry = reps[i]
                if entry and entry.factionID and entry.factionID > 0
                    and C_Reputation and C_Reputation.GetFactionDataByID
                then
                    local data = C_Reputation.GetFactionDataByID(entry.factionID)
                    if data and data.name and data.name ~= "" then
                        return data.name
                    end
                end
            end
        end
    end

    -- Fallback 2: reputation currencies tied to this quest.
    if C_CurrencyInfo and C_CurrencyInfo.GetFactionGrantedByCurrency
        and C_QuestLog
    then
        local function GetFactionNameFromCurrencyReward(currencyInfo)
            if not currencyInfo or not currencyInfo.currencyID then
                return nil
            end

            local fid = C_CurrencyInfo.GetFactionGrantedByCurrency(currencyInfo.currencyID)
            if fid and fid > 0
                and C_Reputation and C_Reputation.GetFactionDataByID
            then
                local data = C_Reputation.GetFactionDataByID(fid)
                if data and data.name and data.name ~= "" then
                    return data.name
                end
            end

            return nil
        end

        local currRewards = C_QuestLog.GetQuestRewardCurrencies
            and C_QuestLog.GetQuestRewardCurrencies(questID)
        if currRewards then
            for _, cur in ipairs(currRewards) do
                local factionName = GetFactionNameFromCurrencyReward(cur)
                if factionName then
                    return factionName
                end
            end
        end

        if C_QuestLog.GetQuestRewardCurrencyInfo then
            local numChoices = GetNumQuestLogChoices and GetNumQuestLogChoices(questID, true) or 0
            for choiceIndex = 1, numChoices do
                local factionName = GetFactionNameFromCurrencyReward(
                    C_QuestLog.GetQuestRewardCurrencyInfo(questID, choiceIndex, true))
                if factionName then
                    return factionName
                end
            end
        end
    end

    local legacyFactionRewards = ns._WorldQuestsGetLegacySelectedQuestRewardFactions(questID)
    if legacyFactionRewards then
        for _, rewardData in ipairs(legacyFactionRewards) do
            if rewardData.label and rewardData.label ~= "" then
                return rewardData.label
            end
        end
    end

    return nil
end

-- Recursively builds a set of map IDs that are descendants of mapID
-- (including mapID itself) using the World Map parent/child hierarchy only.
local function CollectDescendantMapIDs(mapID, set, depth)
    if (depth or 0) > 6 or set[mapID] then return end
    set[mapID] = true
    if not C_Map then return end

    local children = C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(mapID)
    if not children then return end

    for i = 1, #children do
        local child   = children[i]
        local childID = child and child.mapID
        if childID then
            CollectDescendantMapIDs(childID, set, (depth or 0) + 1)
        end
    end
end

-- Returns the cached descendant map ID set for mapID, computing it once per
-- unique mapID.  The WoW map hierarchy is static for the session, so the cache
-- entry is valid indefinitely.
local function GetDescendantMapSet(mapID)
    if not mapDescendantsCache[mapID] then
        local set = {}
        CollectDescendantMapIDs(mapID, set, 0)
        mapDescendantsCache[mapID] = set
    end
    return mapDescendantsCache[mapID]
end

function eventFrame:GetDescendantMapList(mapID)
    self._mapDescendantListCache = self._mapDescendantListCache or {}

    if not self._mapDescendantListCache[mapID] then
        local set = GetDescendantMapSet(mapID)
        local mapIDs = {}

        for descendantMapID in pairs(set) do
            mapIDs[#mapIDs + 1] = descendantMapID
        end

        table_sort(mapIDs)
        self._mapDescendantListCache[mapID] = mapIDs
    end

    return self._mapDescendantListCache[mapID]
end

function eventFrame:IsRelevantLockedAreaPOIInfo(poiInfo)
    return poiInfo and poiInfo.atlasName
        and string_find(poiInfo.atlasName, "Capstone", 1, true)
end

function eventFrame:ShouldAdmitLockedAreaPOIForQuery(mapsToQuery, poiInfo, allowOutsideHierarchy)
    if allowOutsideHierarchy == true then
        return true
    end

    local linkedUiMapID = poiInfo and poiInfo.linkedUiMapID or nil
    local isOwnedByQueryTree = poiInfo and poiInfo.isPrimaryMapForPOI == true or false

    if not isOwnedByQueryTree and linkedUiMapID and linkedUiMapID > 0 then
        isOwnedByQueryTree = mapsToQuery and mapsToQuery[linkedUiMapID] == true
    end

    return isOwnedByQueryTree
end

function eventFrame:IsOverviewOrClusterMapQuery(mapID)
    if type(mapID) ~= "number" or mapID <= 0 then
        return false
    end

    if hierarchyNodeSet[mapID] == true then
        return true
    end

    if C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(mapID)
        return mapInfo and mapInfo.mapType == MAP_TYPE_WORLD or false
    end

    return false
end

local function IsOverviewStyleLockedQuestRow(q, queryMapID, mapsToQuery, allowOutsideHierarchy)
    if not q then
        return false
    end

    if allowOutsideHierarchy ~= true then
        return false
    end

    if q.isMapIndicatorQuest == true then
        return true
    end

    local questMapID = q.mapID
    if questMapID and questMapID ~= 0
        and queryMapID and questMapID ~= queryMapID
        and not mapsToQuery[questMapID]
    then
        return true
    end

    return false
end

local function IsProvisionalLockedSpecialAssignmentCandidate(
    q,
    queryMapID,
    mapsToQuery,
    allowOutsideHierarchy)
    local questID = q and q.questID
    if not questID then
        return false
    end

    if C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(questID) then
        return false
    end

    if IsSpecialAssignmentFromMetadata(q.questTagType, q.tagID) then
        return true
    end

    return IsOverviewStyleLockedQuestRow(q, queryMapID, mapsToQuery, allowOutsideHierarchy)
end

local function ResolveQuestMapIDForList(questID, fallbackMapID)
    if questID then
        if C_TaskQuest and C_TaskQuest.GetQuestZoneID then
            local questZoneMapID = C_TaskQuest.GetQuestZoneID(questID)
            if questZoneMapID and questZoneMapID ~= 0 then
                return questZoneMapID
            end
        end

        if GetQuestUiMapIDCompat then
            local ok, questUiMapID = pcall(GetQuestUiMapIDCompat, questID, true)
            if ok and questUiMapID and questUiMapID ~= 0 then
                return questUiMapID
            end
        end
    end

    return fallbackMapID
end

local function IsInactiveSpecialAssignmentQuestID(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(questID) then
        return false
    end

    return IsSpecialAssignmentQuest(questID)
end

local function UpgradeExistingBountyLockedQuestEntry(
    rawEntries,
    mapsToQuery,
    questID,
    queryMapID,
    allowOutsideHierarchy)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    local questMapID = ResolveQuestMapIDForList(
        questID,
        allowOutsideHierarchy == true and queryMapID or nil)
    if not mapsToQuery[questMapID] and allowOutsideHierarchy == true then
        questMapID = queryMapID
    end

    if not mapsToQuery[questMapID] then
        return false
    end

    local qInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(questMapID)
    local tagInfo = C_QuestLog and C_QuestLog.GetQuestTagInfo
        and C_QuestLog.GetQuestTagInfo(questID)

    for _, entry in ipairs(rawEntries) do
        if entry.questID == questID then
            if entry.isLocked == true then
                entry.mapID = questMapID
                entry.mapName = qInfo and qInfo.name or entry.mapName or ""
                entry.rawQuestTagType = tagInfo and tagInfo.worldQuestType or entry.rawQuestTagType
                entry.rawTagID = tagInfo and tagInfo.tagID or entry.rawTagID
                entry.bountyLockedCandidate = true
                return true
            end
            return false
        end
    end

    return false
end

local function AppendLockedQuestByID(
    rawEntries,
    seen,
    mapsToQuery,
    questID,
    queryMapID,
    bountyLockedCandidate,
    allowOutsideHierarchy)
    if seen[questID] then
        if bountyLockedCandidate == true then
            UpgradeExistingBountyLockedQuestEntry(
                rawEntries,
                mapsToQuery,
                questID,
                queryMapID,
                allowOutsideHierarchy)
        end
        return
    end

    if bountyLockedCandidate == true then
        if type(questID) ~= "number" or questID <= 0 then
            return
        end

        if C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(questID) then
            return
        end
    elseif not IsInactiveSpecialAssignmentQuestID(questID) then
        return
    end

    local questMapID = ResolveQuestMapIDForList(
        questID,
        allowOutsideHierarchy == true and queryMapID or nil)
    if not mapsToQuery[questMapID] and allowOutsideHierarchy == true then
        questMapID = queryMapID
    end
    if not mapsToQuery[questMapID] then
        return
    end

    seen[questID] = true
    local qInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(questMapID)
    local tagInfo = C_QuestLog and C_QuestLog.GetQuestTagInfo
        and C_QuestLog.GetQuestTagInfo(questID)
    rawEntries[#rawEntries + 1] = {
        questID = questID,
        mapID = questMapID,
        mapName = qInfo and qInfo.name or "",
        rawQuestTagType = tagInfo and tagInfo.worldQuestType,
        rawTagID = tagInfo and tagInfo.tagID,
        isMapIndicatorQuest = false,
        isLocked = true,
        bountyLockedCandidate = bountyLockedCandidate == true,
    }
end

local function GetExistingQuestEntry(questID)
    if not questID then
        return nil
    end

    return eventFrame._currentQuestEntriesByID[questID] or nil
end

local function GetLockedSpecialAssignmentBountyQuestID(queryMapID)
    if not C_QuestLog or not C_QuestLog.GetBountySetInfoForMapID then
        return nil
    end

    local displayLocation, lockQuestID, bountySetID, isActivitySet =
        C_QuestLog.GetBountySetInfoForMapID(queryMapID)
    if type(lockQuestID) == "number" and lockQuestID > 0
        and not (C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(lockQuestID))
    then
        return lockQuestID
    end

    return nil
end

local function AppendRawQuestEntry(
    rawEntries,
    seen,
    mapsToQuery,
    q,
    queryMapID,
    isLocked,
    allowOutsideHierarchy)
    local questID = q and q.questID
    if not questID or seen[questID] then
        return
    end

    local rawQuestMapID = (q.mapID and q.mapID ~= 0) and q.mapID or nil
    local useQueryMapAssociation = isLocked == true
        and rawQuestMapID
        and not mapsToQuery[rawQuestMapID]
        and IsOverviewStyleLockedQuestRow(q, queryMapID, mapsToQuery, allowOutsideHierarchy)
    local questMapID = useQueryMapAssociation and queryMapID
        or rawQuestMapID
        or (isLocked == true and allowOutsideHierarchy == true and queryMapID or nil)
    if not mapsToQuery[questMapID] then
        return
    end

    seen[questID] = true
    local qInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(questMapID)
    local existingEntry = GetExistingQuestEntry(questID)
    rawEntries[#rawEntries + 1] = {
        questID = questID,
        mapID = questMapID,
        mapName = qInfo and qInfo.name or "",
        rawQuestTagType = q.questTagType,
        rawTagID = q.tagID,
        rawTimeLeftSeconds = q.timeLeftSeconds
            or q.secondsLeft
            or ((q.timeLeftMinutes or q.minutesLeft) and ((q.timeLeftMinutes or q.minutesLeft) * 60))
            or nil,
        rawTimeLeftSecondsConsumed = existingEntry and existingEntry.rawTimeLeftSecondsConsumed == true or false,
        expiresAt = existingEntry and existingEntry.expiresAt or nil,
        isMapIndicatorQuest = q.isMapIndicatorQuest == true,
        isLocked = isLocked == true,
    }
end

-- Forward declaration — defined after this function but called inside it for
-- reward-type filtering/sorting.
local GetQuestRewards

-- Compares two enriched quest entries using the active quest sort mode.
-- a, b: table — enriched entries from GatherQuestsForCurrentMap.
-- Returns: boolean — true when a should sort before b.
local function CompareQuestEntries(a, b)
    if sortMode == "alpha" then
        local at = a.title or ""
        local bt = b.title or ""
        if at ~= bt then return at < bt end
    elseif sortMode == "reward" then
        local pa = REWARD_TYPE_PRIORITY[a.primReward] or 99
        local pb = REWARD_TYPE_PRIORITY[b.primReward] or 99
        if pa ~= pb then return pa < pb end

        local ta = a.timeLeft or math.huge
        local tb = b.timeLeft or math.huge
        if ta ~= tb then return ta < tb end
    elseif sortMode == "faction" then
        local fa = a.faction or ""
        local fb = b.faction or ""
        if fa ~= fb then return fa < fb end

        local ta = a.timeLeft or math.huge
        local tb = b.timeLeft or math.huge
        if ta ~= tb then return ta < tb end
    else
        local ta = a.timeLeft or math.huge
        local tb = b.timeLeft or math.huge
        if ta ~= tb then return ta < tb end
    end

    if a.mapName ~= b.mapName then
        return a.mapName < b.mapName
    end

    local at = a.title or ""
    local bt = b.title or ""
    if at ~= bt then
        return at < bt
    end

    return (a.questID or 0) < (b.questID or 0)
end

-- Groups quest entries by zone and sorts the zone buckets independently.
-- quests: table[] — enriched quest entries.
-- Returns: table[] — array of { name, quests, earliestTimeLeft } zone groups.
local function BuildSortedZoneGroups(quests)
    local zoneGroups = {}
    local zoneIndex = {}

    for _, entry in ipairs(quests) do
        local zoneName = entry.mapName or ""
        local zoneGroup = zoneIndex[zoneName]
        if not zoneGroup then
            zoneGroup = {
                name = zoneName,
                quests = {},
                earliestTimeLeft = math.huge,
            }
            zoneIndex[zoneName] = zoneGroup
            zoneGroups[#zoneGroups + 1] = zoneGroup
        end

        zoneGroup.quests[#zoneGroup.quests + 1] = entry

        local remaining = entry.timeLeft or math.huge
        if remaining < zoneGroup.earliestTimeLeft then
            zoneGroup.earliestTimeLeft = remaining
        end
    end

    for _, zoneGroup in ipairs(zoneGroups) do
        if #zoneGroup.quests > 1 then
            table_sort(zoneGroup.quests, CompareQuestEntries)
        end
    end

    if zoneSortMode == "alpha" then
        table_sort(zoneGroups, function(a, b)
            if a.name ~= b.name then
                return a.name < b.name
            end
            return a.earliestTimeLeft < b.earliestTimeLeft
        end)
    else
        table_sort(zoneGroups, function(a, b)
            if a.earliestTimeLeft ~= b.earliestTimeLeft then
                return a.earliestTimeLeft < b.earliestTimeLeft
            end
            return a.name < b.name
        end)
    end

    return zoneGroups
end

do
local function IsMapWithinParentChain(candidateMapID, rootMapID)
    if candidateMapID == rootMapID then
        return true
    end

    if not C_Map or not C_Map.GetMapInfo then
        return false
    end

    local currentMapID = candidateMapID
    for _ = 1, 16 do
        local mapInfo = currentMapID and C_Map.GetMapInfo(currentMapID) or nil
        currentMapID = mapInfo and mapInfo.parentMapID or nil
        if not currentMapID or currentMapID == 0 then
            break
        end
        if currentMapID == rootMapID then
            return true
        end
    end

    return false
end

local function IsMapWithinDiscoveryRoot(candidateMapID, rootMapID)
    if type(candidateMapID) ~= "number" or candidateMapID <= 0
        or type(rootMapID) ~= "number" or rootMapID <= 0
    then
        return false
    end

    return IsMapWithinParentChain(candidateMapID, rootMapID)
end

---@param rootMapID number
---@param questID number?
---@param fallbackMapID number
---@param explicitMapID number?
---@return number
local function SelectDiscoveredQuestMapID(rootMapID, questID, fallbackMapID, explicitMapID)
    local outsideRootMapID = nil

    local function Consider(candidateMapID)
        if type(candidateMapID) ~= "number" or candidateMapID <= 0 then
            return nil
        end

        if candidateMapID == rootMapID
            or IsMapWithinDiscoveryRoot(candidateMapID, rootMapID)
        then
            return candidateMapID
        end

        if not outsideRootMapID then
            outsideRootMapID = candidateMapID
        end

        return nil
    end

    local resolvedMapID = Consider(explicitMapID)
    if resolvedMapID then
        return resolvedMapID
    end

    if questID and C_TaskQuest and C_TaskQuest.GetQuestZoneID then
        resolvedMapID = Consider(C_TaskQuest.GetQuestZoneID(questID))
        if resolvedMapID then
            return resolvedMapID
        end
    end

    if questID and GetQuestUiMapIDCompat then
        local ok, questUiMapID = pcall(GetQuestUiMapIDCompat, questID, true)
        if ok then
            resolvedMapID = Consider(questUiMapID)
            if resolvedMapID then
                return resolvedMapID
            end
        end
    end

    return outsideRootMapID or fallbackMapID or rootMapID
end

local function CloneMapIDSet(sourceSet)
    local clonedSet = {}

    if sourceSet then
        for memberMapID in pairs(sourceSet) do
            clonedSet[memberMapID] = true
        end
    end

    return clonedSet
end

local function EnsureRelevantQueryMapsToQueryMutable(queryState)
    if queryState._mapsToQueryDetached ~= true then
        queryState.mapsToQuery = CloneMapIDSet(queryState.mapsToQuery)
        queryState._mapsToQueryDetached = true
    end

    return queryState.mapsToQuery
end

local function AddRelevantQueryMap(queryState, candidateMapID, allowOutsideHierarchy)
    if type(candidateMapID) ~= "number" or candidateMapID <= 0 then
        return
    end

    if not queryState.mapsToQuery[candidateMapID] then
        if allowOutsideHierarchy ~= true or queryState.allowOutsideHierarchy ~= true then
            return
        end

        EnsureRelevantQueryMapsToQueryMutable(queryState)[candidateMapID] = true
    end

    if queryState.queryMapSet[candidateMapID] then
        return
    end

    queryState.queryMapSet[candidateMapID] = true
    queryState.queryMapIDs[#queryState.queryMapIDs + 1] = candidateMapID
end

local function IsRelevantDiscoveryQuestInfo(q)
    local questID = q and q.questID
    if not questID then
        return false
    end

    local isMapIndicator = q.isMapIndicatorQuest == true
        and not (C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(questID))
    if isMapIndicator then
        return true
    end

    if IsSpecialAssignmentFromMetadata(q.questTagType, q.tagID) then
        return true
    end

    return not QuestUtils_IsQuestWorldQuest
        or QuestUtils_IsQuestWorldQuest(questID)
end

local function DiscoverQuestOwnerMaps(queryState, questInfos, queryMapID)
    if not questInfos then
        return
    end

    for _, q in ipairs(questInfos) do
        if IsRelevantDiscoveryQuestInfo(q) then
            local ownerMapID = SelectDiscoveredQuestMapID(
                queryState.mapID,
                q.questID,
                queryMapID,
                q.mapID)
            AddRelevantQueryMap(
                queryState,
                ownerMapID,
                ownerMapID ~= queryState.mapID
                    and not IsMapWithinDiscoveryRoot(ownerMapID, queryState.mapID))
        end
    end
end

local function FinalizeRelevantQueryMapIDs(queryState)
    if queryState.expandDescendantQueryMapIDs == true then
        for targetMapID in pairs(queryState.mapsToQuery) do
            AddRelevantQueryMap(queryState, targetMapID, false)
        end
    end

    local signatureMapIDs = eventFrame._relevantWorldQuestQuerySignatureMapIDs or {}
    local signatureMapIDCount = 0

    eventFrame._relevantWorldQuestQuerySignatureMapIDs = signatureMapIDs

    for queryMapID in pairs(queryState.queryMapSet) do
        signatureMapIDCount = signatureMapIDCount + 1
        signatureMapIDs[signatureMapIDCount] = queryMapID
    end

    for index = signatureMapIDCount + 1, #signatureMapIDs do
        signatureMapIDs[index] = nil
    end

    if signatureMapIDCount > 0 then
        table_sort(signatureMapIDs)
        queryState.querySignature = table.concat(signatureMapIDs, ":", 1, signatureMapIDCount)
    else
        queryState.querySignature = nil
    end

    return queryState
end

---@param mapID number
---@return table?
function eventFrame:BuildRelevantWorldQuestMapQueryState(mapID)
    if type(mapID) ~= "number" or mapID <= 0 then
        return nil
    end

    local cached = self._sessionQueryStateCache[mapID]
    if cached then
        return cached
    end

    local scanRoots = hierarchyScanRoots[mapID]
    local expandDescendantQueryMapIDs = self:IsOverviewOrClusterMapQuery(mapID)

    local mapsToQuery
    if scanRoots then
        mapsToQuery = { [mapID] = true }
        for scanIndex = 1, #scanRoots do
            local descendants = GetDescendantMapSet(scanRoots[scanIndex])
            for descendantMapID in pairs(descendants) do
                mapsToQuery[descendantMapID] = true
            end
        end
    else
        mapsToQuery = GetDescendantMapSet(mapID)
    end

    local queryState = {
        mapID = mapID,
        mapsToQuery = mapsToQuery,
        _mapsToQueryDetached = scanRoots ~= nil,
        queryMapSet = { [mapID] = true },
        queryMapIDs = { mapID },
        allowOutsideHierarchy = expandDescendantQueryMapIDs,
        expandDescendantQueryMapIDs = expandDescendantQueryMapIDs,
    }

    if C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
        DiscoverQuestOwnerMaps(queryState, C_TaskQuest.GetQuestsOnMap(mapID), mapID)
    end

    if C_QuestLog and C_QuestLog.SetMapForQuestPOIs then
        C_QuestLog.SetMapForQuestPOIs(mapID)
    end
    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        DiscoverQuestOwnerMaps(queryState, C_QuestLog.GetQuestsOnMap(mapID), mapID)
    end

    local bountySetID = nil
    if C_QuestLog and C_QuestLog.GetBountySetInfoForMapID then
        local _, lockQuestID, discoveredBountySetID = C_QuestLog.GetBountySetInfoForMapID(mapID)
        bountySetID = discoveredBountySetID

        if type(lockQuestID) == "number" and lockQuestID > 0 then
            local lockMapID = SelectDiscoveredQuestMapID(mapID, lockQuestID, mapID, nil)
            AddRelevantQueryMap(
                queryState,
                lockMapID,
                lockMapID ~= mapID and not IsMapWithinDiscoveryRoot(lockMapID, mapID))
        end
    end

    if bountySetID and bountySetID > 0 and C_Map and C_Map.GetBountySetMaps then
        local bountySetMaps = C_Map.GetBountySetMaps(bountySetID)
        if bountySetMaps then
            for _, bountyMapID in ipairs(bountySetMaps) do
                AddRelevantQueryMap(queryState, bountyMapID, false)
            end
        end
    end

    if C_QuestLog and C_QuestLog.GetActiveThreatMaps then
        local threatMaps = C_QuestLog.GetActiveThreatMaps()
        if threatMaps then
            for _, threatMapID in ipairs(threatMaps) do
                local includeThreatMap = true
                if bountySetID and bountySetID > 0 and C_QuestLog.GetBountySetInfoForMapID then
                    local _, _, threatBountySetID = C_QuestLog.GetBountySetInfoForMapID(threatMapID)
                    includeThreatMap = threatBountySetID == bountySetID
                end

                if includeThreatMap then
                    AddRelevantQueryMap(queryState, threatMapID, false)
                end
            end
        end
    end

    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo then
        local poiIDs = C_AreaPoiInfo.GetAreaPOIForMap(mapID)
        if poiIDs then
            for _, poiID in ipairs(poiIDs) do
                local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
                if self:IsRelevantLockedAreaPOIInfo(poiInfo) then
                    local ownerMapID = mapID
                    local allowOutsideHierarchy = false

                    if poiInfo and poiInfo.isPrimaryMapForPOI == true then
                        ownerMapID = mapID
                    elseif poiInfo and poiInfo.linkedUiMapID and poiInfo.linkedUiMapID > 0 then
                        ownerMapID = poiInfo.linkedUiMapID
                        allowOutsideHierarchy = not IsMapWithinDiscoveryRoot(ownerMapID, mapID)
                    end

                    AddRelevantQueryMap(queryState, ownerMapID, allowOutsideHierarchy)
                end
            end
        end
    end

    local result = FinalizeRelevantQueryMapIDs(queryState)
    self._sessionQueryStateCache[mapID] = result
    return result
end

local function GetRelevantWorldQuestQuerySignature(queryState, mapID)
    if queryState and queryState.querySignature and queryState.querySignature ~= "" then
        return queryState.querySignature
    end

    if type(mapID) == "number" and mapID > 0 then
        return tostring(mapID)
    end

    return nil
end

function eventFrame:HasRelevantWorldQuestQuerySignatureChange(mapID, queryState)
    if type(mapID) ~= "number" or mapID <= 0 then
        return false, nil, nil
    end

    if self._activeRelevantWorldQuestMapID ~= mapID then
        return false, nil, nil
    end

    local previousSignature = self._activeRelevantWorldQuestQuerySignature
    if not previousSignature then
        return false, nil, nil
    end

    local discoveredSignature = GetRelevantWorldQuestQuerySignature(
        queryState or self:BuildRelevantWorldQuestMapQueryState(mapID),
        mapID)

    if not discoveredSignature then
        return false, previousSignature, discoveredSignature
    end

    return discoveredSignature ~= previousSignature, previousSignature,
        discoveredSignature
end

function eventFrame:CancelWorldQuestDescendantGather()
    self._descendantGatherGeneration = (self._descendantGatherGeneration or 0) + 1
    self._descendantGatherSession = nil
end

function eventFrame:IsWorldQuestDescendantGatherPending(mapID)
    local session = self._descendantGatherSession
    return session ~= nil
        and session.mapID == mapID
        and session.isComplete ~= true
end

local function GetLockedAreaPOIOwnerScore(poiInfo, queryMapID)
    if not poiInfo then
        return 0
    end

    if poiInfo.isPrimaryMapForPOI == true then
        return 3
    end

    local linkedUiMapID = poiInfo.linkedUiMapID
    if linkedUiMapID and linkedUiMapID > 0 then
        if linkedUiMapID == queryMapID then
            return 2
        end
        return 0
    end

    return 1
end

local function ShouldPreferLockedAreaPOIEntry(currentEntry, candidateEntry)
    local currentScore = currentEntry and currentEntry.areaPOIOwnerScore or 0
    local candidateScore = candidateEntry and candidateEntry.areaPOIOwnerScore or 0
    if candidateScore ~= currentScore then
        return candidateScore > currentScore
    end

    local currentMapID = currentEntry and currentEntry.mapID or 0
    local candidateMapID = candidateEntry and candidateEntry.mapID or 0
    if currentMapID ~= candidateMapID then
        local currentIsParent = currentMapID ~= 0
            and candidateMapID ~= 0
            and GetDescendantMapSet(currentMapID)[candidateMapID]
        local candidateIsParent = currentMapID ~= 0
            and candidateMapID ~= 0
            and GetDescendantMapSet(candidateMapID)[currentMapID]
        if currentIsParent ~= candidateIsParent then
            return currentIsParent and true or false
        end
    end

    return candidateMapID > currentMapID
end

local function AppendLockedAreaPOIRawEntry(
    rawEntries,
    seen,
    mapsToQuery,
    queryMapID,
    poiID,
    poiInfo,
    allowOutsideHierarchy)
    if not eventFrame:ShouldAdmitLockedAreaPOIForQuery(
        mapsToQuery,
        poiInfo,
        allowOutsideHierarchy)
    then
        return
    end

    local syntheticID = -poiID
    local existingEntry = GetExistingQuestEntry(syntheticID)
    local qInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(queryMapID)
    local candidateEntry = {
        questID = syntheticID,
        mapID = queryMapID,
        mapName = qInfo and qInfo.name or "",
        rawQuestTagType = WQT_CAPSTONE,
        rawTagID = TAG_ID_SPECIAL_ASSIGNMENT,
        isMapIndicatorQuest = false,
        isLocked = true,
        isAreaPOI = true,
        poiID = poiID,
        poiName = poiInfo and poiInfo.name or nil,
        poiDescription = poiInfo and poiInfo.description or nil,
        tooltipWidgetSet = poiInfo and poiInfo.tooltipWidgetSet or nil,
        areaPOIInfo = poiInfo,
        linkedUiMapID = poiInfo and poiInfo.linkedUiMapID or nil,
        isPrimaryAreaPOI = poiInfo and poiInfo.isPrimaryMapForPOI == true or false,
        areaPOIOwnerScore = GetLockedAreaPOIOwnerScore(poiInfo, queryMapID),
        expiresAt = existingEntry and existingEntry.expiresAt or nil,
        _syntheticID = syntheticID,
    }

    local existingIndex = seen[syntheticID]
    if existingIndex then
        local currentEntry = rawEntries[existingIndex]
        if currentEntry and ShouldPreferLockedAreaPOIEntry(currentEntry, candidateEntry) then
            rawEntries[existingIndex] = candidateEntry
        end
        return
    end

    rawEntries[#rawEntries + 1] = candidateEntry
    seen[syntheticID] = #rawEntries
end

local function AppendRawQuestEntriesForMap(
    rawEntries,
    seen,
    mapsToQuery,
    queryMapID,
    rootMapID,
    allowOutsideHierarchy)
    local activeQuestProvider = C_TaskQuest and C_TaskQuest.GetQuestsOnMap
    if activeQuestProvider then
        local quests = activeQuestProvider(queryMapID)
        if quests then
            for _, q in ipairs(quests) do
                local qid = q.questID
                if qid and not seen[qid] then
                    local isMapIndicator = q.isMapIndicatorQuest == true
                        and not (C_TaskQuest and C_TaskQuest.IsActive
                                 and C_TaskQuest.IsActive(qid))
                    local rawTagID = q["tagID"]
                    local isWorldQuest = not QuestUtils_IsQuestWorldQuest
                        or QuestUtils_IsQuestWorldQuest(qid)
                    local isSpecialAssignment = IsSpecialAssignmentFromMetadata(
                        q.questTagType,
                        rawTagID)
                    if isWorldQuest or isSpecialAssignment or isMapIndicator then
                        AppendRawQuestEntry(
                            rawEntries,
                            seen,
                            mapsToQuery,
                            q,
                            queryMapID,
                            isMapIndicator,
                            allowOutsideHierarchy)
                    end
                end
            end
        end
    end

    local mapQuests = nil
    if C_QuestLog and C_QuestLog.SetMapForQuestPOIs then
        C_QuestLog.SetMapForQuestPOIs(queryMapID)
    end
    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        mapQuests = C_QuestLog.GetQuestsOnMap(queryMapID)
    end
    if C_QuestLog and C_QuestLog.SetMapForQuestPOIs and rootMapID then
        C_QuestLog.SetMapForQuestPOIs(rootMapID)
    end

    if mapQuests then
        for _, q in ipairs(mapQuests) do
            if q.questID and not seen[q.questID]
                and IsProvisionalLockedSpecialAssignmentCandidate(
                    q,
                    queryMapID,
                    mapsToQuery,
                    allowOutsideHierarchy)
            then
                AppendRawQuestEntry(
                    rawEntries,
                    seen,
                    mapsToQuery,
                    q,
                    queryMapID,
                    true,
                    allowOutsideHierarchy)
            end
        end
    end

    local lockedQuestID = GetLockedSpecialAssignmentBountyQuestID(queryMapID)
    if lockedQuestID then
        AppendLockedQuestByID(
            rawEntries,
            seen,
            mapsToQuery,
            lockedQuestID,
            queryMapID,
                true,
                allowOutsideHierarchy)
    end

    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo then
        local poiIDs = C_AreaPoiInfo.GetAreaPOIForMap(queryMapID)
        if poiIDs then
            for _, poiID in ipairs(poiIDs) do
                local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(queryMapID, poiID)
                if eventFrame:IsRelevantLockedAreaPOIInfo(poiInfo) then
                    AppendLockedAreaPOIRawEntry(
                        rawEntries,
                        seen,
                        mapsToQuery,
                        queryMapID,
                        poiID,
                        poiInfo,
                        allowOutsideHierarchy)
                end
            end
        end
    end
end

local function IsQuestEntryStillVisible(entry)
    local questID = entry and entry.questID or nil
    return entry
        and (entry.isAreaPOI == true
            or entry.isLocked == true
            or not (questID and questID > 0 and C_TaskQuest and C_TaskQuest.IsActive)
            or C_TaskQuest.IsActive(questID))
end

local function IsAreaPOIWidgetShown(widgetInfo)
    local shownState = widgetInfo and widgetInfo.shownState
    return shownState ~= false and shownState ~= 0
end

local function BuildQuestEntriesFromRawEntries(rawEntries, mapsToQuery)
    local activePendingQuestIDs = {}
    local gatherTime = GetTime()

    for _, entry in ipairs(rawEntries) do
        local questID = entry.questID
        entry.isLocked = ResolveQuestLockedState(questID, entry)

        if IsQuestEntryStillVisible(entry) then
            activePendingQuestIDs[questID] = true

            if entry.isAreaPOI then
                pendingQuestIDs[questID] = nil
            else
                local hasQuestData = eventFrame:IsQuestCoreDataReady(questID)
                if hasQuestData then
                    requestedQuestData[questID] = nil
                    questDataRetrySuppressedUntil[questID] = nil
                end

                local retrySuppressedUntil = questDataRetrySuppressedUntil[questID]
                if retrySuppressedUntil and retrySuppressedUntil <= gatherTime then
                    questDataRetrySuppressedUntil[questID] = nil
                    retrySuppressedUntil = nil
                end

                local needsQuestData = not hasQuestData
                local needsRewardData = not entry.isLocked
                    and HaveQuestRewardData and not HaveQuestRewardData(questID)
                if retrySuppressedUntil and needsRewardData then
                    needsRewardData = false
                end

                if needsQuestData then
                    local pendingState = pendingQuestIDs[questID]
                    if pendingState then
                        pendingState.needsQuestData = true
                        pendingState.questDataRefreshDone = false
                    else
                        pendingQuestIDs[questID] = {
                            needsQuestData = true,
                            needsRewardData = false,
                            questDataRefreshDone = false,
                        }
                    end

                    eventFrame:QueueQuestCoreDataLoad(questID)
                end

                if needsRewardData then
                    local pendingState = pendingQuestIDs[questID]
                    if pendingState then
                        pendingState.needsRewardData = true
                    else
                        pendingQuestIDs[questID] = {
                            needsQuestData = false,
                            needsRewardData = true,
                            questDataRefreshDone = true,
                        }
                    end
                elseif not HaveQuestRewardData or HaveQuestRewardData(questID) then
                    rewardPreloadState.requestedQuestIDs[questID] = nil
                    rewardPreloadState.queuedQuestIDs[questID] = nil
                end

                if not needsQuestData and not needsRewardData then
                    pendingQuestIDs[questID] = nil
                end
            end
        else
            pendingQuestIDs[questID] = nil
            requestedQuestData[questID] = nil
            questDataRetrySuppressedUntil[questID] = nil
            rewardPreloadState.requestedQuestIDs[questID] = nil
            rewardPreloadState.queuedQuestIDs[questID] = nil
        end
    end

    PruneQuestRequestBookkeeping(activePendingQuestIDs)
    UpdateQuestLogUpdateRegistration()

    local result = {}
    local hiddenRewardPreloadQuestIDs
    local searchLower = filterSearch ~= "" and filterSearch:lower() or nil
    local serverTime = GetCurrentServerTime()

    for _, entry in ipairs(rawEntries) do
        if IsQuestEntryStillVisible(entry) then
            local questID = entry.questID
            local dataReady = entry.isAreaPOI or eventFrame:IsQuestCoreDataReady(questID)
            local rewardDataReady = entry.isAreaPOI
                or entry.isLocked
                or rewardPreloadState.IsQuestRewardDisplayReady(questID)
            local timeLeft, expiresAt
            if entry.isAreaPOI then
                if entry.poiID and C_AreaPoiInfo and C_AreaPoiInfo.IsAreaPOITimed
                    and C_AreaPoiInfo.GetAreaPOISecondsLeft
                    and C_AreaPoiInfo.IsAreaPOITimed(entry.poiID)
                then
                    timeLeft = C_AreaPoiInfo.GetAreaPOISecondsLeft(entry.poiID)
                    if timeLeft and timeLeft > 0 then
                        expiresAt = serverTime + timeLeft
                    elseif entry.expiresAt and entry.expiresAt > serverTime then
                        expiresAt = entry.expiresAt
                    end
                elseif entry.expiresAt and entry.expiresAt > serverTime then
                    expiresAt = entry.expiresAt
                end
            else
                timeLeft, expiresAt = GetQuestExpirySnapshot(questID, serverTime, entry)
            end

            local title = entry.isAreaPOI and entry.poiName or GetQuestTitle(questID)
            local faction = not entry.isAreaPOI and GetQuestFactionLabel(questID) or nil
            local questType = entry.isAreaPOI and "special_assignment" or GetQuestType(
                questID,
                entry.rawQuestTagType,
                entry.rawTagID)
            if not entry.isAreaPOI then
                expiresAt = GetPersistedLockedSpecialAssignmentExpiresAt(
                    questID,
                    entry.isLocked,
                    entry.rawQuestTagType,
                    entry.rawTagID,
                    questType,
                    timeLeft,
                    expiresAt)
            end
            timeLeft = GetRemainingTimeLeft(timeLeft, expiresAt, serverTime)
            local expID = not entry.isAreaPOI and GetQuestExpansionID(questID) or nil
            local expLabel = expID and EXPANSION_LABELS[expID] or nil

            local excluded = false
            local excludedBySearch = false
            if entry.isLocked then
                if entry.isAreaPOI then
                    excluded = false
                elseif entry.isMapIndicatorQuest then
                    excluded = false
                elseif entry.bountyLockedCandidate == true then
                    local isSpecialAssignment, isConfirmed = IsSpecialAssignmentQuest(
                        questID,
                        entry.rawQuestTagType,
                        entry.rawTagID,
                        questType,
                        true)
                    excluded = isConfirmed and not isSpecialAssignment
                else
                    excluded = not IsSpecialAssignmentQuest(
                        questID,
                        entry.rawQuestTagType,
                        entry.rawTagID,
                        questType)
                end
            end

            local unlockText = nil
            local rewardText = nil
            local areaPOIRewards = {}
            local areaPOITimeText = nil
            local primReward = nil
            if not excluded then
                if entry.isLocked then
                    if entry.isAreaPOI and entry.tooltipWidgetSet and C_UIWidgetManager then
                        local widgets = C_UIWidgetManager.GetAllWidgetsBySetID
                            and C_UIWidgetManager.GetAllWidgetsBySetID(entry.tooltipWidgetSet)
                        if widgets and #widgets > 0 then
                            local ordered = {}
                            for _, widgetInfo in ipairs(widgets) do
                                ordered[#ordered + 1] = widgetInfo
                            end
                            table_sort(ordered, function(leftWidget, rightWidget)
                                local leftOrder = leftWidget.orderIndex or 0
                                local rightOrder = rightWidget.orderIndex or 0
                                if leftOrder ~= rightOrder then
                                    return leftOrder < rightOrder
                                end
                                return (leftWidget.widgetID or 0) < (rightWidget.widgetID or 0)
                            end)

                            local sawRewardHeader = false
                            local selectedRewardWidget = false
                            for _, widgetInfo in ipairs(ordered) do
                                if IsAreaPOIWidgetShown(widgetInfo) then
                                    local text = nil
                                    local rewardWidgetExpressed = false
                                    local widgetRewards = nil
                                    local widgetRewardParts = nil
                                    if widgetInfo.widgetType == 2
                                        and C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo
                                    then
                                        local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetInfo.widgetID)
                                        if info then
                                            if info.hasTimer then
                                                if not areaPOITimeText then
                                                    areaPOITimeText = eventFrame:GetAreaPOITimeTextFromStatusBarWidgetInfo(info)
                                                end
                                            else
                                                if info.overrideBarText and info.overrideBarText ~= "" then
                                                    text = NormalizeInlineQuestText(info.overrideBarText)
                                                end
                                                if not text and info.text and info.text ~= "" then
                                                    text = NormalizeInlineQuestText(info.text)
                                                end
                                            end
                                        end
                                    elseif widgetInfo.widgetType == 8
                                        and C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo
                                    then
                                        local info = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgetInfo.widgetID)
                                        if info and info.text and info.text ~= "" then
                                            text = NormalizeInlineQuestText(info.text)
                                            if not areaPOITimeText and eventFrame:IsAreaPOITimeText(text) then
                                                areaPOITimeText = text
                                                text = nil
                                            end
                                        end
                                    elseif widgetInfo.widgetType == 7
                                        and C_UIWidgetManager.GetIconTextAndCurrenciesWidgetVisualizationInfo
                                    then
                                        local info = C_UIWidgetManager.GetIconTextAndCurrenciesWidgetVisualizationInfo(widgetInfo.widgetID)
                                        if info then
                                            if info.text and info.text ~= "" then
                                                text = NormalizeInlineQuestText(info.text)
                                            end
                                            if info.currencies then
                                                for _, currency in ipairs(info.currencies) do
                                                    local currencyID = currency["currencyID"] or nil
                                                    local currencyText = NormalizeInlineQuestText(
                                                        currency.text or currency.leadingText or info.text)
                                                    if currency.iconFileID or currencyText or currencyID then
                                                        widgetRewards = widgetRewards or {}
                                                        widgetRewards[#widgetRewards + 1] = {
                                                            rewardType = "currency",
                                                            icon = currency.iconFileID,
                                                            label = currencyText,
                                                            amount = nil,
                                                            currencyID = currencyID,
                                                        }
                                                        rewardWidgetExpressed = true
                                                    end
                                                end
                                            end
                                        end
                                    elseif widgetInfo.widgetType == 9
                                        and C_UIWidgetManager.GetHorizontalCurrenciesWidgetVisualizationInfo
                                    then
                                        local info = C_UIWidgetManager.GetHorizontalCurrenciesWidgetVisualizationInfo(widgetInfo.widgetID)
                                        if info and info.currencies then
                                            local infoText = info["text"]
                                            for _, currency in ipairs(info.currencies) do
                                                local currencyID = currency["currencyID"] or nil
                                                local currencyText = NormalizeInlineQuestText(
                                                    currency.text or currency.leadingText or infoText)
                                                if currency.iconFileID or currencyText or currencyID then
                                                    widgetRewards = widgetRewards or {}
                                                    widgetRewards[#widgetRewards + 1] = {
                                                        rewardType = "currency",
                                                        icon = currency.iconFileID,
                                                        label = currencyText,
                                                        amount = nil,
                                                        currencyID = currencyID,
                                                    }
                                                    rewardWidgetExpressed = true
                                                end
                                            end
                                        end
                                    elseif widgetInfo.widgetType == 13
                                        and C_UIWidgetManager.GetSpellDisplayVisualizationInfo
                                    then
                                        local info = C_UIWidgetManager.GetSpellDisplayVisualizationInfo(widgetInfo.widgetID)
                                        if info and info.spellInfo and info.spellInfo.text and info.spellInfo.text ~= "" then
                                            text = NormalizeInlineQuestText(info.spellInfo.text)
                                        end
                                    elseif widgetInfo.widgetType == 27
                                        and C_UIWidgetManager.GetItemDisplayVisualizationInfo
                                    then
                                        local info = C_UIWidgetManager.GetItemDisplayVisualizationInfo(widgetInfo.widgetID)
                                        if info and info.itemInfo then
                                            local itemID = info.itemInfo.itemID or nil
                                            if info.itemInfo.overrideItemName and info.itemInfo.overrideItemName ~= "" then
                                                text = NormalizeInlineQuestText(info.itemInfo.overrideItemName)
                                            end
                                            if not text and itemID and C_Item and C_Item.GetItemNameByID then
                                                text = NormalizeInlineQuestText(C_Item.GetItemNameByID(itemID))
                                            end
                                            if not text and info.itemInfo.infoText and info.itemInfo.infoText ~= "" then
                                                text = NormalizeInlineQuestText(info.itemInfo.infoText)
                                            end
                                            local icon = C_Item and C_Item.GetItemIconByID and itemID
                                                and C_Item.GetItemIconByID(itemID) or nil
                                            if itemID or icon or text then
                                                widgetRewards = widgetRewards or {}
                                                widgetRewards[#widgetRewards + 1] = {
                                                    rewardType = "item",
                                                    itemID = itemID,
                                                    icon = icon,
                                                    label = text,
                                                    amount = info.itemInfo.stackCount or nil,
                                                }
                                                rewardWidgetExpressed = true
                                            end
                                        end
                                    end

                                    if text and text ~= "" then
                                        local lowerText = text:lower()
                                        local headerText = string_gsub(lowerText, "[:：]+$", "")
                                        local rewardsLabel = REWARDS and REWARDS:lower() or "rewards"
                                        local rewardLabel = REWARD and REWARD:lower() or "reward"
                                        if headerText == rewardsLabel or headerText == rewardLabel then
                                            sawRewardHeader = true
                                        elseif widgetInfo.widgetType == 2 or widgetInfo.widgetType == 8 then
                                            if not unlockText then
                                                unlockText = text
                                            end
                                        elseif (widgetInfo.widgetType == 7
                                                or widgetInfo.widgetType == 9
                                                or widgetInfo.widgetType == 27)
                                            and not rewardWidgetExpressed
                                        then
                                            widgetRewardParts = widgetRewardParts or {}
                                            widgetRewardParts[#widgetRewardParts + 1] = text
                                        elseif widgetInfo.widgetType == 13 and sawRewardHeader then
                                            widgetRewardParts = widgetRewardParts or {}
                                            widgetRewardParts[#widgetRewardParts + 1] = text
                                        end
                                    end

                                    local hasRewardContent = rewardWidgetExpressed
                                        or (widgetRewardParts and #widgetRewardParts > 0)
                                    if hasRewardContent and not selectedRewardWidget then
                                        selectedRewardWidget = true
                                        if widgetRewards then
                                            for _, rewardData in ipairs(widgetRewards) do
                                                areaPOIRewards[#areaPOIRewards + 1] = rewardData
                                            end
                                        end
                                        if widgetRewardParts and #widgetRewardParts > 0 then
                                            rewardText = table.concat(widgetRewardParts, "  ")
                                        end
                                    end
                                end
                            end
                        end
                    end

                    if not unlockText and entry.isAreaPOI and entry.poiDescription and entry.poiDescription ~= "" then
                        unlockText = NormalizeInlineQuestText(entry.poiDescription)
                    end
                    if not unlockText then
                        if entry.isAreaPOI then
                            unlockText = "Unlock requirements not available yet."
                        else
                            unlockText = GetLockedSpecialAssignmentUnlockText(questID)
                        end
                    end
                end

                local rawRewards = (not entry.isLocked and rewardDataReady) and GetQuestRewards(questID) or {}
                primReward = (#rawRewards > 0) and GetPrimaryRewardType(rawRewards) or nil
            end

            if next(filterTypes) and questType and filterTypes[questType] then
                excluded = true
            end
            if not excluded and next(filterRewards) and primReward and filterRewards[primReward] then
                excluded = true
            end
            if not excluded and searchLower then
                local matched =
                    (title and title:lower():find(searchLower, 1, true))
                    or (faction and faction:lower():find(searchLower, 1, true))
                    or (unlockText and unlockText:lower():find(searchLower, 1, true))
                    or (entry.mapName and entry.mapName:lower():find(searchLower, 1, true))
                    or (questType and QUEST_TYPE_LABEL[questType]
                        and QUEST_TYPE_LABEL[questType]:lower():find(searchLower, 1, true))
                    or (primReward and REWARD_TYPE_LABEL[primReward]
                        and REWARD_TYPE_LABEL[primReward]:lower():find(searchLower, 1, true))
                if not matched then
                    excluded = true
                    excludedBySearch = true
                end
            end

            local pendingState = pendingQuestIDs[questID]
            local needsHiddenRewardPreload = pendingState
                and pendingState.needsRewardData
                and excludedBySearch
                and dataReady
                and not entry.isLocked
                and entry.isAreaPOI ~= true
            if pendingState then
                pendingState.searchRefreshOnRewardReady = needsHiddenRewardPreload and true or nil
            end
            if needsHiddenRewardPreload then
                hiddenRewardPreloadQuestIDs = hiddenRewardPreloadQuestIDs or {}
                hiddenRewardPreloadQuestIDs[#hiddenRewardPreloadQuestIDs + 1] = questID
            end

            if not excluded then
                local timeText
                if entry.isAreaPOI and areaPOITimeText then
                    timeText = areaPOITimeText
                else
                    timeText = FormatTimeLeft(timeLeft)
                end

                result[#result + 1] = {
                    questID = questID,
                    mapID = entry.mapID,
                    mapName = entry.mapName,
                    title = title,
                    faction = faction,
                    timeLeft = timeLeft,
                    timeText = timeText,
                    expiresAt = expiresAt,
                    questType = questType,
                    expID = expID,
                    expLabel = expLabel,
                    rawTimeLeftSeconds = entry.rawTimeLeftSeconds,
                    rawTimeLeftSecondsConsumed = entry.rawTimeLeftSecondsConsumed == true,
                    rawQuestTagType = entry.rawQuestTagType,
                    rawTagID = entry.rawTagID,
                    isMapIndicatorQuest = entry.isMapIndicatorQuest,
                    bountyLockedCandidate = entry.bountyLockedCandidate == true,
                    isAreaPOI = entry.isAreaPOI == true,
                    areaPOITimeText = areaPOITimeText,
                    areaPOIRewards = areaPOIRewards,
                    poiID = entry.poiID,
                    tooltipWidgetSet = entry.tooltipWidgetSet,
                    poiDescription = entry.poiDescription,
                    areaPOIInfo = entry.areaPOIInfo,
                    linkedUiMapID = entry.linkedUiMapID,
                    isPrimaryAreaPOI = entry.isPrimaryAreaPOI == true,
                    areaPOIOwnerScore = entry.areaPOIOwnerScore,
                    isLocked = entry.isLocked,
                    unlockText = unlockText,
                    rewardText = rewardText,
                    primReward = primReward,
                    rewardDataReady = rewardDataReady,
                    dataReady = dataReady,
                }
            end
        end
    end

    do
        local function GetRelatedSpecialAssignmentMapState(leftMapID, rightMapID)
            if not leftMapID or not rightMapID then
                return false, false, false
            end

            local leftIsParent = leftMapID ~= rightMapID
                and GetDescendantMapSet(leftMapID)[rightMapID]
            local rightIsParent = leftMapID ~= rightMapID
                and GetDescendantMapSet(rightMapID)[leftMapID]
            local sharesMapGroup = false

            if leftMapID ~= rightMapID
                and not leftIsParent
                and not rightIsParent
                and C_Map
                and C_Map.GetMapGroupID
                and C_Map.GetMapGroupMembersInfo
            then
                local groupID = C_Map.GetMapGroupID(leftMapID)
                if groupID then
                    local members = C_Map.GetMapGroupMembersInfo(groupID)
                    if members then
                        for index = 1, #members do
                            local memberID = members[index] and members[index].mapID
                            if memberID == rightMapID then
                                sharesMapGroup = true
                                break
                            end
                        end
                    end
                end
            end

            return leftMapID == rightMapID or leftIsParent or rightIsParent or sharesMapGroup,
                leftIsParent,
                rightIsParent,
                sharesMapGroup
        end

        local function GetLockedSpecialAssignmentSiblingDropIndex(
            leftEntry,
            rightEntry,
            leftIndex,
            rightIndex)
            local leftQuestBacked = leftEntry.questID and leftEntry.questID > 0
            local rightQuestBacked = rightEntry.questID and rightEntry.questID > 0
            if leftQuestBacked ~= rightQuestBacked then
                return leftQuestBacked and rightIndex or leftIndex
            end

            local leftAreaPOI = leftEntry.isAreaPOI == true
            local rightAreaPOI = rightEntry.isAreaPOI == true
            if leftAreaPOI ~= rightAreaPOI then
                return leftAreaPOI and leftIndex or rightIndex
            end

            local leftOwnerScore = leftEntry.areaPOIOwnerScore or 0
            local rightOwnerScore = rightEntry.areaPOIOwnerScore or 0
            if leftOwnerScore ~= rightOwnerScore then
                return leftOwnerScore < rightOwnerScore and leftIndex or rightIndex
            end

            local leftStableID = leftAreaPOI and (leftEntry.poiID or 0) or (leftEntry.questID or 0)
            local rightStableID = rightAreaPOI and (rightEntry.poiID or 0) or (rightEntry.questID or 0)
            if leftStableID ~= rightStableID then
                return leftStableID < rightStableID and rightIndex or leftIndex
            end

            local leftMapID = leftEntry.mapID or 0
            local rightMapID = rightEntry.mapID or 0
            if leftMapID ~= rightMapID then
                return leftMapID < rightMapID and rightIndex or leftIndex
            end

            return rightIndex
        end

        local function GetSpecialAssignmentSourcePriority(entry)
            if not entry then
                return 0
            end

            if entry.isLocked ~= true then
                if entry.questID and entry.questID > 0 then
                    return 4
                end
                return 0
            end

            if entry.isAreaPOI then
                local isPrimaryAreaPOI = entry.isPrimaryAreaPOI == true
                if not isPrimaryAreaPOI then
                    local linkedUiMapID = entry.linkedUiMapID
                    if linkedUiMapID and linkedUiMapID > 0 and linkedUiMapID == entry.mapID then
                        isPrimaryAreaPOI = true
                    end
                end
                if isPrimaryAreaPOI then
                    return 3
                end
                return 1
            end

            if entry.questID and entry.questID > 0 then
                return 2
            end

            return 0
        end

        local function GetPendingTitleSpecialAssignmentAreaPOIDropIndex(
            leftEntry,
            rightEntry,
            leftIndex,
            rightIndex)
            local leftTitlePending = not leftEntry.title or leftEntry.title == ""
            local rightTitlePending = not rightEntry.title or rightEntry.title == ""
            if leftTitlePending == rightTitlePending then
                return nil
            end

            local pendingEntry = leftTitlePending and leftEntry or rightEntry
            local otherEntry = leftTitlePending and rightEntry or leftEntry
            if pendingEntry.questID and pendingEntry.questID > 0
                and pendingEntry.isAreaPOI ~= true
                and pendingEntry.dataReady == false
                and otherEntry.isAreaPOI and otherEntry.isLocked
            then
                local pendingPriority = GetSpecialAssignmentSourcePriority(pendingEntry)
                local otherPriority = GetSpecialAssignmentSourcePriority(otherEntry)
                if pendingPriority >= otherPriority then
                    return leftTitlePending and rightIndex or leftIndex
                end
            end

            return nil
        end

        local dropIndexes = nil
        for i = 1, #result do
            local leftEntry = result[i]
            if leftEntry and IsSpecialAssignmentFromMetadata(
                    leftEntry.rawQuestTagType,
                    leftEntry.rawTagID,
                    leftEntry.questType)
            then
                for j = i + 1, #result do
                    local rightEntry = result[j]
                    if rightEntry and IsSpecialAssignmentFromMetadata(
                            rightEntry.rawQuestTagType,
                            rightEntry.rawTagID,
                            rightEntry.questType)
                    then
                        local mapsRelated, leftIsParent, rightIsParent, sharesMapGroup =
                            GetRelatedSpecialAssignmentMapState(
                                leftEntry.mapID,
                                rightEntry.mapID)
                        if mapsRelated then
                            local dropIndex = nil
                            local leftTitleKnown = leftEntry.title and leftEntry.title ~= ""
                            local rightTitleKnown = rightEntry.title and rightEntry.title ~= ""

                            if leftTitleKnown and rightTitleKnown then
                                if string_lower(rightEntry.title) == string_lower(leftEntry.title) then
                                    local leftPriority = GetSpecialAssignmentSourcePriority(leftEntry)
                                    local rightPriority = GetSpecialAssignmentSourcePriority(rightEntry)
                                    if leftPriority ~= rightPriority then
                                        dropIndex = leftPriority < rightPriority and i or j
                                    elseif leftEntry.isAreaPOI and rightEntry.isAreaPOI then
                                        local leftOwnerScore = leftEntry.areaPOIOwnerScore or 0
                                        local rightOwnerScore = rightEntry.areaPOIOwnerScore or 0
                                        if leftOwnerScore ~= rightOwnerScore then
                                            dropIndex = leftOwnerScore < rightOwnerScore and i or j
                                        elseif leftIsParent then
                                            dropIndex = i
                                        elseif rightIsParent then
                                            dropIndex = j
                                        end
                                    elseif leftIsParent then
                                        dropIndex = i
                                    elseif rightIsParent then
                                        dropIndex = j
                                    end

                                    if not dropIndex
                                        and sharesMapGroup
                                        and leftEntry.isLocked
                                        and rightEntry.isLocked
                                    then
                                        dropIndex = GetLockedSpecialAssignmentSiblingDropIndex(
                                            leftEntry,
                                            rightEntry,
                                            i,
                                            j)
                                    end
                                end
                            else
                                dropIndex = GetPendingTitleSpecialAssignmentAreaPOIDropIndex(
                                    leftEntry,
                                    rightEntry,
                                    i,
                                    j)
                            end

                            if dropIndex then
                                dropIndexes = dropIndexes or {}
                                dropIndexes[dropIndex] = true
                            end
                        end
                    end
                end
            end
        end

        if dropIndexes then
            local dedupedResult = {}
            for i = 1, #result do
                if not dropIndexes[i] then
                    dedupedResult[#dedupedResult + 1] = result[i]
                end
            end
            result = dedupedResult
        end
    end

    if #result > 1 then
        table_sort(result, CompareQuestEntries)
    end

    return result, hiddenRewardPreloadQuestIDs
end

local function ShouldStageDescendantGather(queryState)
    local queryMapIDs = queryState and queryState.queryMapIDs or nil
    return queryMapIDs and #queryMapIDs > 8 or false
end

local function BuildRawQuestMembershipSignature(rawEntries)
    local signatureParts = eventFrame._rawQuestMembershipSignatureParts or {}
    local partCount = 0

    eventFrame._rawQuestMembershipSignatureParts = signatureParts

    if rawEntries then
        for _, entry in ipairs(rawEntries) do
            if not entry.isAreaPOI then
                partCount = partCount + 1
                signatureParts[partCount] = string_format(
                    "%s:%s:%s:%s:%s:%s:%s",
                    tostring(entry.questID or 0),
                    tostring(entry.mapID or 0),
                    entry.isLocked == true and "1" or "0",
                    entry.isMapIndicatorQuest == true and "1" or "0",
                    entry.bountyLockedCandidate == true and "1" or "0",
                    tostring(entry.rawQuestTagType or 0),
                    tostring(entry.rawTagID or 0))
            end
        end
    end

    for index = partCount + 1, #signatureParts do
        signatureParts[index] = nil
    end

    if partCount == 0 then
        return ""
    end

    table_sort(signatureParts)
    return table.concat(signatureParts, "\031", 1, partCount)
end

local function BuildLiveDescendantGatherQuestMembershipSignature(mapID, queryState)
    local mapsToQuery = queryState and queryState.mapsToQuery or { [mapID] = true }
    local queryMapIDs = queryState and queryState.queryMapIDs or { mapID }
    local allowOutsideHierarchy = queryState and queryState.allowOutsideHierarchy
        or eventFrame:IsOverviewOrClusterMapQuery(mapID)
    local rawEntries = eventFrame._liveDescendantGatherMembershipRawEntries or {}
    local seen = eventFrame._liveDescendantGatherMembershipSeen or {}

    eventFrame._liveDescendantGatherMembershipRawEntries = rawEntries
    eventFrame._liveDescendantGatherMembershipSeen = seen

    wipe(rawEntries)
    wipe(seen)

    for index = 1, #queryMapIDs do
        AppendRawQuestEntriesForMap(
            rawEntries,
            seen,
            mapsToQuery,
            queryMapIDs[index],
            mapID,
            allowOutsideHierarchy)
    end

    return BuildRawQuestMembershipSignature(rawEntries)
end

local function FinalizeStagedDescendantGatherSession(session)
    session.rawQuestMembershipSignature = BuildRawQuestMembershipSignature(session.rawEntries)
    session.isComplete = true
end

local function CreateStagedDescendantGatherSession(mapID, animateRows, queryState)
    local mapsToQuery = queryState and queryState.mapsToQuery or { [mapID] = true }
    local queryMapIDs = queryState and queryState.queryMapIDs or { mapID }
    local querySignature = GetRelevantWorldQuestQuerySignature(queryState, mapID)
    local allowOutsideHierarchy = queryState and queryState.allowOutsideHierarchy
        or eventFrame:IsOverviewOrClusterMapQuery(mapID)

    eventFrame._descendantGatherGeneration = (eventFrame._descendantGatherGeneration or 0) + 1
    local myGeneration = eventFrame._descendantGatherGeneration
    local session = {
        mapID = mapID,
        mapsToQuery = mapsToQuery,
        queryMapIDs = queryMapIDs,
        querySignature = querySignature,
        allowOutsideHierarchy = allowOutsideHierarchy,
        rawEntries = {},
        seen = {},
        nextIndex = 1,
        isComplete = false,
        finalAnimateRows = animateRows ~= false,
    }
    eventFrame._descendantGatherSession = session

    local function finalize()
        FinalizeStagedDescendantGatherSession(session)
        if ns.IsWorldQuestsRefreshContextActive()
            and WorldMapFrame and WorldMapFrame.mapID == session.mapID
        then
            ScheduleRefresh(session.finalAnimateRows, "Staged descendant gather complete", true)
        end
    end

    local function processNext()
        if eventFrame._descendantGatherGeneration ~= myGeneration or session.isComplete then
            return
        end
        if not ns.IsWorldQuestsRefreshContextActive()
            or not WorldMapFrame
            or WorldMapFrame.mapID ~= session.mapID
        then
            return
        end

        local debugprofilestop = debugprofilestop
        local budgetStart = debugprofilestop()
        local BATCH_TIME_BUDGET_MS = 4

        while session.nextIndex <= #session.queryMapIDs do
            local queryMapID = session.queryMapIDs[session.nextIndex]
            if not queryMapID then
                break
            end

            AppendRawQuestEntriesForMap(
                session.rawEntries,
                session.seen,
                session.mapsToQuery,
                queryMapID,
                session.mapID,
                session.allowOutsideHierarchy)
            session.nextIndex = session.nextIndex + 1

            if debugprofilestop() - budgetStart > BATCH_TIME_BUDGET_MS * 1000 then
                break
            end
        end

        if session.nextIndex > #session.queryMapIDs then
            finalize()
            return
        end

        C_Timer.After(0.01, processNext)
    end

    if session.queryMapIDs[1] then
        local debugprofilestop = debugprofilestop
        local budgetStart = debugprofilestop()
        local INITIAL_TIME_BUDGET_MS = 4

        while session.nextIndex <= #session.queryMapIDs do
            local queryMapID = session.queryMapIDs[session.nextIndex]
            if not queryMapID then
                break
            end

            AppendRawQuestEntriesForMap(
                session.rawEntries,
                session.seen,
                session.mapsToQuery,
                queryMapID,
                session.mapID,
                session.allowOutsideHierarchy)
            session.nextIndex = session.nextIndex + 1

            if debugprofilestop() - budgetStart > INITIAL_TIME_BUDGET_MS * 1000 then
                break
            end
        end
    else
        FinalizeStagedDescendantGatherSession(session)
    end

    if not session.isComplete and session.nextIndex > #session.queryMapIDs then
        FinalizeStagedDescendantGatherSession(session)
    end

    if not session.isComplete then
        C_Timer.After(0.01, processNext)
    end

    return session
end

local function GetStagedDescendantGatherSession(mapID, animateRows, queryState)
    local querySignature = GetRelevantWorldQuestQuerySignature(queryState, mapID)
    local session = eventFrame._descendantGatherSession
    if session and session.mapID == mapID and session.querySignature == querySignature then
        if animateRows == true then
            session.finalAnimateRows = true
        end
        return session
    end

    return CreateStagedDescendantGatherSession(mapID, animateRows, queryState)
end

ns.HasCompletedStagedDescendantGatherQuestMembershipChange = function(mapID, queryState)
    local session = eventFrame._descendantGatherSession
    if not session or session.mapID ~= mapID or session.isComplete ~= true then
        return false
    end

    local querySignature = GetRelevantWorldQuestQuerySignature(queryState, mapID)
    if session.querySignature ~= querySignature then
        return false
    end

    local previousMembershipSignature = session.rawQuestMembershipSignature
        or BuildRawQuestMembershipSignature(session.rawEntries)
    local liveMembershipSignature = BuildLiveDescendantGatherQuestMembershipSignature(mapID, queryState)

    session.rawQuestMembershipSignature = previousMembershipSignature

    return liveMembershipSignature ~= previousMembershipSignature
end

function eventFrame:GatherQuestsForCurrentMap(animateRows)
    if not WorldMapFrame then return {}, nil, nil end
    local mapID = WorldMapFrame.mapID
    if not mapID then return {}, nil, nil end
    if not C_TaskQuest or not C_TaskQuest.GetQuestsOnMap then
        return {}, nil, nil
    end

    -- Walk up from micro/cave sub-zone maps to their parent zone so
    -- world quests appear even when standing inside a cave entrance.
    if C_Map and C_Map.GetMapInfo and Enum and Enum.UIMapType then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.mapType == Enum.UIMapType.Micro
            and mapInfo.parentMapID
        then
            mapID = mapInfo.parentMapID
        end
    end

    -- Skip scanning if the current map is excluded by user preference
    if eventFrame._excludedMaps[mapID] then
        return {}, nil, nil
    end

    local queryStateStart = debugprofilestop()
    local queryState = self:BuildRelevantWorldQuestMapQueryState(mapID)
    local queryStateElapsed = debugprofilestop() - queryStateStart
    if ns.IsDebugEnabled() then
        ns.DebugPrint(string_format(
            "WorldQuests: BuildQueryState mapID=%s elapsed=%.2fms cached=%s",
            tostring(mapID), queryStateElapsed / 1000,
            tostring(self._sessionQueryStateCache[mapID] == queryState and queryStateElapsed < 100)))
    end
    local querySignature = GetRelevantWorldQuestQuerySignature(queryState, mapID)
    local mapsToQuery = queryState and queryState.mapsToQuery or { [mapID] = true }
    local queryMapIDs = queryState and queryState.queryMapIDs or { mapID }
    local allowOutsideHierarchy = queryState and queryState.allowOutsideHierarchy
        or self:IsOverviewOrClusterMapQuery(mapID)

    -- ── Session cache: check which query maps still need scanning ────────────
    local newQueryMapIDs
    local allMapsCached = true
    for queryIndex = 1, #queryMapIDs do
        local queryMapID = queryMapIDs[queryIndex]
        if not self._sessionScannedQueryMapIDs[queryMapID] then
            allMapsCached = false
            if not newQueryMapIDs then
                newQueryMapIDs = {}
            end
            newQueryMapIDs[#newQueryMapIDs + 1] = queryMapID
        end
    end

    if allMapsCached and next(self._sessionEnrichedEntries) then
        -- ── Fast path: all maps already scanned — filter cached entries ──────
        self:CancelWorldQuestDescendantGather()

        local cached = self._sessionEnrichedEntries
        local filtered = {}
        local hiddenRewardPreloadQuestIDs
        local searchLower = filterSearch ~= "" and filterSearch:lower() or nil

        for cacheIndex = 1, #cached do
            local entry = cached[cacheIndex]
            if mapsToQuery[entry.mapID] and IsQuestEntryStillVisible(entry) then
                -- Refresh time-sensitive fields
                local serverTime = GetCurrentServerTime()
                if entry.isAreaPOI then
                    if entry.poiID and C_AreaPoiInfo
                        and C_AreaPoiInfo.IsAreaPOITimed
                        and C_AreaPoiInfo.GetAreaPOISecondsLeft
                        and C_AreaPoiInfo.IsAreaPOITimed(entry.poiID)
                    then
                        local remaining = C_AreaPoiInfo.GetAreaPOISecondsLeft(entry.poiID)
                        if remaining and remaining > 0 then
                            entry.timeLeft = remaining
                            entry.expiresAt = serverTime + remaining
                        end
                    end
                else
                    local timeLeft, expiresAt = GetQuestExpirySnapshot(
                        entry.questID, serverTime, entry)
                    entry.timeLeft = timeLeft
                    entry.expiresAt = expiresAt
                end
                entry.timeLeft = GetRemainingTimeLeft(
                    entry.timeLeft, entry.expiresAt, serverTime)
                if entry.areaPOITimeText then
                    entry.timeText = entry.areaPOITimeText
                else
                    entry.timeText = FormatTimeLeft(entry.timeLeft)
                end

                -- Re-check reward data readiness (may have loaded async)
                if not entry.isAreaPOI and not entry.isLocked then
                    entry.rewardDataReady = rewardPreloadState.IsQuestRewardDisplayReady(
                        entry.questID)
                    if entry.rewardDataReady and not entry.primReward then
                        local rawRewards = GetQuestRewards(entry.questID)
                        if rawRewards and #rawRewards > 0 then
                            entry.primReward = GetPrimaryRewardType(rawRewards)
                        end
                    end
                end

                -- Apply current filters
                local excluded = false
                if next(filterTypes) and entry.questType
                    and filterTypes[entry.questType]
                then
                    excluded = true
                end
                if not excluded and next(filterRewards) and entry.primReward
                    and filterRewards[entry.primReward]
                then
                    excluded = true
                end
                if not excluded and searchLower then
                    local matched =
                        (entry.title and entry.title:lower():find(searchLower, 1, true))
                        or (entry.faction and entry.faction:lower():find(searchLower, 1, true))
                        or (entry.unlockText and entry.unlockText:lower():find(searchLower, 1, true))
                        or (entry.mapName and entry.mapName:lower():find(searchLower, 1, true))
                        or (entry.questType and QUEST_TYPE_LABEL[entry.questType]
                            and QUEST_TYPE_LABEL[entry.questType]:lower():find(searchLower, 1, true))
                        or (entry.primReward and REWARD_TYPE_LABEL[entry.primReward]
                            and REWARD_TYPE_LABEL[entry.primReward]:lower():find(searchLower, 1, true))
                    if not matched then
                        excluded = true
                    end
                end

                if not excluded then
                    filtered[#filtered + 1] = entry
                end
            end
        end

        if #filtered > 1 then
            table_sort(filtered, CompareQuestEntries)
        end

        return filtered, hiddenRewardPreloadQuestIDs, querySignature
    end

    -- ── Incremental path: scan only new maps, merge with cached raw data ────
    if newQueryMapIDs and #newQueryMapIDs > 0 then
        local newMapCount = #newQueryMapIDs

        if newMapCount > 8 then
            -- Stage the gather for large map sets — but only for new maps
            local stagedQueryMapIDs = newQueryMapIDs
            local stagedQueryState = {
                mapID = mapID,
                mapsToQuery = mapsToQuery,
                queryMapSet = {},
                queryMapIDs = stagedQueryMapIDs,
                allowOutsideHierarchy = allowOutsideHierarchy,
                expandDescendantQueryMapIDs = false,
                _mapsToQueryDetached = true,
            }
            for _, stagedMapID in ipairs(stagedQueryMapIDs) do
                stagedQueryState.queryMapSet[stagedMapID] = true
            end

            local session = GetStagedDescendantGatherSession(
                mapID, animateRows, stagedQueryState)
            if not session or not session.isComplete then
                return {}, nil, querySignature
            end

            -- Merge new raw entries into session cache
            for _, rawEntry in ipairs(session.rawEntries) do
                local entryKey = rawEntry.isAreaPOI
                    and rawEntry._syntheticID or rawEntry.questID
                if entryKey and not self._sessionRawEntriesSeen[entryKey] then
                    self._sessionRawEntries[#self._sessionRawEntries + 1] = rawEntry
                    self._sessionRawEntriesSeen[entryKey] = #self._sessionRawEntries
                end
            end
            for _, scannedMapID in ipairs(stagedQueryMapIDs) do
                self._sessionScannedQueryMapIDs[scannedMapID] = true
            end
        else
            -- Synchronous gather for small new map sets
            self:CancelWorldQuestDescendantGather()

            for newIndex = 1, newMapCount do
                AppendRawQuestEntriesForMap(
                    self._sessionRawEntries,
                    self._sessionRawEntriesSeen,
                    mapsToQuery,
                    newQueryMapIDs[newIndex],
                    mapID,
                    allowOutsideHierarchy)
                self._sessionScannedQueryMapIDs[newQueryMapIDs[newIndex]] = true
            end
        end
    else
        self:CancelWorldQuestDescendantGather()
    end

    -- ── Build enriched entries from session raw cache ────────────────────────
    -- Filter raw entries to only those relevant to current mapsToQuery
    local relevantRawEntries = {}
    local relevantSeen = {}
    for rawIndex = 1, #self._sessionRawEntries do
        local rawEntry = self._sessionRawEntries[rawIndex]
        if rawEntry and mapsToQuery[rawEntry.mapID] then
            local entryKey = rawEntry.isAreaPOI
                and rawEntry._syntheticID or rawEntry.questID
            if entryKey and not relevantSeen[entryKey] then
                relevantRawEntries[#relevantRawEntries + 1] = rawEntry
                relevantSeen[entryKey] = true
            end
        end
    end

    local quests, hiddenRewardPreloadQuestIDs = BuildQuestEntriesFromRawEntries(
        relevantRawEntries,
        mapsToQuery)

    -- Merge enriched entries into cumulative cache for fast-path reuse
    for enrichIndex = 1, #quests do
        local entry = quests[enrichIndex]
        local entryKey = entry.isAreaPOI and entry._syntheticID or entry.questID
        if entryKey then
            local existingIndex = self._sessionEnrichedEntriesSeen[entryKey]
            if existingIndex then
                self._sessionEnrichedEntries[existingIndex] = entry
            else
                local newIndex = #self._sessionEnrichedEntries + 1
                self._sessionEnrichedEntries[newIndex] = entry
                self._sessionEnrichedEntriesSeen[entryKey] = newIndex
            end
        end
    end

    return quests, hiddenRewardPreloadQuestIDs, querySignature
end
end

local function ClearPOIButtonAreaPOIState(poiBtn)
    if not poiBtn then
        return
    end

    poiBtn.areaPOIInfo = nil
    if poiBtn.SetAreaPOIID then
        poiBtn:SetAreaPOIID(nil)
    else
        poiBtn.areaPOIID = nil
    end
    poiBtn.areaPoiID = nil
end

-- =============================================
-- Reward data helpers
-- =============================================

local function QueueQuestRewardItemLoadRefresh(questID, itemID, rewardIndex, questRewardType)
    local itemLoadState = rewardPreloadState.itemLoadState
    if type(questID) ~= "number" or questID <= 0
        or type(itemID) ~= "number" or itemID <= 0
        or not Item or not Item.CreateFromItemID
    then
        return
    end

    local key = string_format(
        "%d:%s:%d:%d",
        questID,
        questRewardType or "reward",
        rewardIndex or 0,
        itemID)

    if itemLoadState.pending[key] or itemLoadState.completed[key] then
        return
    end

    local item = Item:CreateFromItemID(itemID)
    if not item or not item.ContinueOnItemLoad then
        return
    end

    itemLoadState.pending[key] = true
    item:ContinueOnItemLoad(function()
        C_Timer.After(0, function()
            itemLoadState.pending[key] = nil

            if not ns.IsWorldQuestsRefreshContextActive()
                or not eventFrame._activeWorldQuestRawIDs[questID]
            then
                return
            end

            itemLoadState.completed[key] = true

            local rowUpdated, needsFullRefresh = eventFrame:UpdateQuestRow(questID)
            if needsFullRefresh or not rowUpdated then
                ScheduleRefresh(false, "Quest reward item load")
            end
            eventFrame:RefreshActiveQuestTooltipIfReady(questID)
        end)
    end)
end

function ns.FormatCompactRewardAmount(amount)
    local numericAmount = tonumber(amount)
    if not numericAmount then
        return nil
    end

    local absAmount = math.abs(numericAmount)
    if absAmount <= 0 then
        return nil
    end

    if absAmount >= 1000 then
        local abbreviateLargeNumbers = _G and _G["AbbreviateLargeNumbers"]
        if type(abbreviateLargeNumbers) == "function" then
            local abbreviated = abbreviateLargeNumbers(absAmount)
            if abbreviated and abbreviated ~= "" then
                return abbreviated
            end
        end

        local suffix = "k"
        local divisor = 1000
        if absAmount >= 1000000 then
            suffix = "m"
            divisor = 1000000
        end

        local roundedAmount = math_floor(((absAmount / divisor) * 10) + 0.5) / 10
        local compact = string_format("%.1f%s", roundedAmount, suffix)
        compact = string_gsub(compact, "%.0([km])$", "%1")
        return compact
    end

    return tostring(absAmount)
end

-- Returns the reward list for a quest, queried fresh each call.
-- Each entry: { rewardType, icon, label, amount, itemID, currencyID, factionID, currencyLabel, ilvl }
--   rewardType: "item" | "currency" | "gold" | "rep"
-- Returns an empty table when reward data has not been preloaded yet.
GetQuestRewards = function(questID)
    -- Reward APIs return partial or default values before the server has
    -- finished loading data.  Gate all queries behind HaveQuestRewardData.
    if HaveQuestRewardData and not HaveQuestRewardData(questID) then
        return {}
    end

    local rewards = {}
    local repRewards = {}
    local genericCurrencyRewards = {}
    local currencyRewardSources = {}

    local function GetCurrencyRewardSourceAmount(currencyInfo)
        if not currencyInfo then
            return nil
        end

        return currencyInfo.totalRewardAmount
            or currencyInfo.quantity
            or currencyInfo.rewardAmount
            or currencyInfo.amount
            or currencyInfo.totalAmount
    end

    local function GetDisplayedCurrencyRewardInfo(currencyInfo)
        if not currencyInfo or not currencyInfo.currencyID then
            return nil, nil, nil, nil, nil
        end

        local displayName = currencyInfo.name
        local displayIcon = currencyInfo.texture
        local sourceAmount = GetCurrencyRewardSourceAmount(currencyInfo)
        local displayAmount = sourceAmount
        local displayQuality = currencyInfo.quality

        if CurrencyContainerUtil
            and CurrencyContainerUtil.GetCurrencyContainerInfo
        then
            displayName, displayIcon, displayAmount, displayQuality =
                CurrencyContainerUtil.GetCurrencyContainerInfo(
                    currencyInfo.currencyID,
                    displayAmount,
                    displayName,
                    displayIcon,
                    displayQuality)
        end

        return displayName, displayIcon, displayAmount, displayQuality, sourceAmount
    end

    local function GetFactionRewardDisplayInfo(factionID, fallbackName, fallbackIcon)
        local label = fallbackName
        local icon = fallbackIcon

        if factionID and factionID > 0
            and C_Reputation and C_Reputation.GetFactionDataByID
        then
            local data = C_Reputation.GetFactionDataByID(factionID)
            if data then
                if data.name and data.name ~= "" then
                    label = data.name
                end
                if data["texture"] then
                    icon = data["texture"]
                end
            end
        end

        return label, icon
    end

    local function AddItemReward(name, texture, stackCount, quality, itemID, itemLevel, rewardIndex, questRewardType)
        if not name or not texture then
            QueueQuestRewardItemLoadRefresh(
                questID,
                itemID,
                rewardIndex,
                questRewardType)
            return
        end

        local amount = nil
        local isGearReward = ns._WorldQuestsIsActualGearRewardItem(itemID)
        if type(stackCount) == "number" and stackCount > 0 then
            amount = stackCount
        end

        rewards[#rewards + 1] = {
            rewardType = "item",
            icon = texture,
            label = name,
            amount = amount,
            itemID = itemID,
            ilvl = isGearReward and itemLevel and itemLevel > 0 and itemLevel or nil,
            quality = quality,
            rewardIndex = rewardIndex,
            questRewardType = questRewardType or "reward",
        }

        QueueQuestRewardItemLoadRefresh(
            questID,
            itemID,
            rewardIndex,
            questRewardType)
    end

    local function AddCurrencyRewardSource(currencyInfo, rewardIndex, questRewardType)
        if not currencyInfo or not currencyInfo.currencyID then
            return false
        end

        currencyRewardSources[#currencyRewardSources + 1] = {
            info = currencyInfo,
            rewardIndex = rewardIndex,
            questRewardType = questRewardType or "reward",
        }
        return true
    end

    local numItems = GetNumQuestLogRewards and GetNumQuestLogRewards(questID) or 0
    for i = 1, numItems do
        local name, texture, numStacks, quality, _, itemID, itemLevel =
            GetQuestLogRewardInfo(i, questID)
        AddItemReward(name, texture, numStacks, quality, itemID, itemLevel, i, "reward")
    end

    local currencyRewards = C_QuestLog and C_QuestLog.GetQuestRewardCurrencies
        and C_QuestLog.GetQuestRewardCurrencies(questID)
    if currencyRewards then
        for rewardIndex, currencyInfo in ipairs(currencyRewards) do
            AddCurrencyRewardSource(currencyInfo, rewardIndex, "reward")
        end
    end

    local numChoices = GetNumQuestLogChoices and GetNumQuestLogChoices(questID, true) or 0
    for choiceIndex = 1, numChoices do
        local choiceCurrencyInfo = C_QuestLog
            and C_QuestLog.GetQuestRewardCurrencyInfo
            and C_QuestLog.GetQuestRewardCurrencyInfo(questID, choiceIndex, true)
            or nil
        if not AddCurrencyRewardSource(choiceCurrencyInfo, choiceIndex, "choice") then
            local name, texture, numStacks, quality, ignoredUsable, itemID, itemLevel
            if GetQuestLogChoiceInfo then
                name, texture, numStacks, quality, ignoredUsable, itemID, itemLevel =
                    GetQuestLogChoiceInfo(choiceIndex, questID)
            end
            AddItemReward(name, texture, numStacks, quality, itemID, itemLevel, choiceIndex, "choice")
        end
    end

    local directRepOrder = {}
    local directRepAmounts = {}
    local directRepLabels = {}
    local directRepIcons = {}

    if C_QuestLog and C_QuestLog.GetQuestLogMajorFactionReputationRewards then
        local majorFactionRewards = C_QuestLog.GetQuestLogMajorFactionReputationRewards(questID)
        if majorFactionRewards then
            for _, repInfo in ipairs(majorFactionRewards) do
                local factionID = repInfo and repInfo.factionID or nil
                local rewardAmount = repInfo
                    and (repInfo.rewardAmount or repInfo["totalRewardAmount"] or repInfo["amount"] or repInfo["quantity"])
                    or nil
                if factionID and factionID > 0 and rewardAmount and rewardAmount ~= 0 then
                    if not directRepAmounts[factionID] then
                        directRepOrder[#directRepOrder + 1] = factionID
                    end
                    directRepAmounts[factionID] = (directRepAmounts[factionID] or 0) + rewardAmount

                    local label, icon = GetFactionRewardDisplayInfo(
                        factionID,
                        repInfo["name"],
                        repInfo["texture"])
                    if label and label ~= "" then
                        directRepLabels[factionID] = label
                    end
                    if icon then
                        directRepIcons[factionID] = icon
                    end
                end
            end
        end
    end

    local mappedRepOrder = {}
    local mappedRepAmounts = {}
    local mappedRepLabels = {}
    local mappedRepIcons = {}
    local mappedRepCurrencyLabels = {}
    local knownRepLabels = {}

    local function RememberRepLabel(label)
        local normalizedLabel = NormalizeFactionName(label)
        if normalizedLabel then
            knownRepLabels[normalizedLabel] = true
        end
    end

    for _, source in ipairs(currencyRewardSources) do
        local currencyInfo = source.info
        local displayName, displayIcon, displayAmount, _, sourceAmount =
            GetDisplayedCurrencyRewardInfo(currencyInfo)
        local factionID = C_CurrencyInfo
            and C_CurrencyInfo.GetFactionGrantedByCurrency
            and currencyInfo.currencyID
            and C_CurrencyInfo.GetFactionGrantedByCurrency(currencyInfo.currencyID)
            or nil

        if factionID and factionID > 0 then
            if not directRepAmounts[factionID] and sourceAmount and sourceAmount ~= 0 then
                if not mappedRepAmounts[factionID] then
                    mappedRepOrder[#mappedRepOrder + 1] = factionID
                end
                mappedRepAmounts[factionID] = (mappedRepAmounts[factionID] or 0) + sourceAmount

                local label, icon = GetFactionRewardDisplayInfo(factionID, nil, displayIcon)
                if label and label ~= "" then
                    mappedRepLabels[factionID] = label
                end
                if icon then
                    mappedRepIcons[factionID] = icon
                end

                if displayName and displayName ~= "" then
                    local currentLabel = mappedRepCurrencyLabels[factionID]
                    if currentLabel == nil then
                        mappedRepCurrencyLabels[factionID] = displayName
                    elseif currentLabel ~= false and currentLabel ~= displayName then
                        mappedRepCurrencyLabels[factionID] = false
                    end
                end
            end
        elseif displayName and displayIcon then
            genericCurrencyRewards[#genericCurrencyRewards + 1] = {
                rewardType = "currency",
                icon = displayIcon,
                label = displayName,
                amount = displayAmount,
                currencyID = currencyInfo.currencyID,
                rewardIndex = source.rewardIndex,
                questRewardType = source.questRewardType,
            }
        end
    end

    for _, factionID in ipairs(directRepOrder) do
        local label = directRepLabels[factionID]
        local amount = directRepAmounts[factionID]
        if label and label ~= "" and amount and amount ~= 0 then
            repRewards[#repRewards + 1] = {
                rewardType = "rep",
                icon = directRepIcons[factionID] or "Interface\\Icons\\Achievement_Reputation_01",
                label = label,
                amount = amount,
                factionID = factionID,
            }
            RememberRepLabel(label)
        end
    end

    for _, factionID in ipairs(mappedRepOrder) do
        local label = mappedRepLabels[factionID]
        local amount = mappedRepAmounts[factionID]
        if label and label ~= "" and amount and amount ~= 0 then
            local currencyLabel = mappedRepCurrencyLabels[factionID]
            if currencyLabel == false then
                currencyLabel = nil
            end

            repRewards[#repRewards + 1] = {
                rewardType = "rep",
                icon = mappedRepIcons[factionID] or "Interface\\Icons\\Achievement_Reputation_01",
                label = label,
                amount = amount,
                factionID = factionID,
                currencyLabel = currencyLabel,
            }
            RememberRepLabel(label)
        end
    end

    local legacyRepRewards = ns._WorldQuestsGetLegacySelectedQuestRewardFactions(questID)
    if legacyRepRewards then
        for _, legacyRewardData in ipairs(legacyRepRewards) do
            local label = legacyRewardData.label
            local amount = legacyRewardData.amount
            local factionID = legacyRewardData.factionID
            local normalizedLabel = NormalizeFactionName(label)
            local skipLegacy = false

            if factionID and (directRepAmounts[factionID] or mappedRepAmounts[factionID]) then
                skipLegacy = true
            elseif normalizedLabel and knownRepLabels[normalizedLabel] then
                skipLegacy = true
            end

            if not skipLegacy and label and label ~= "" and amount and amount ~= 0 then
                local resolvedLabel, resolvedIcon = GetFactionRewardDisplayInfo(
                    factionID,
                    label,
                    legacyRewardData.icon)
                repRewards[#repRewards + 1] = {
                    rewardType = "rep",
                    icon = resolvedIcon or "Interface\\Icons\\Achievement_Reputation_01",
                    label = resolvedLabel,
                    amount = amount,
                    factionID = factionID,
                }
                RememberRepLabel(resolvedLabel)
            end
        end
    end

    for _, rewardData in ipairs(repRewards) do
        rewards[#rewards + 1] = rewardData
    end

    for _, rewardData in ipairs(genericCurrencyRewards) do
        rewards[#rewards + 1] = rewardData
    end

    -- ── Gold reward ───────────────────────────────────────────────────────
    local money = GetQuestLogRewardMoney and GetQuestLogRewardMoney(questID) or 0
    if money and money > 0 then
        local gold   = math_floor(money / 10000)
        local silver = math_floor((money % 10000) / 100)
        local copper = money % 100
        local parts = {}
        if gold   > 0 then parts[#parts + 1] = gold   .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t" end
        if silver > 0 then parts[#parts + 1] = silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t" end
        if copper > 0 then parts[#parts + 1] = copper .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t" end
        rewards[#rewards + 1] = {
            rewardType = "gold",
            label      = table.concat(parts, " "),
        }
    end

    return rewards
end

function ns.ShowReputationRewardTooltip(anchorFrame, label, amount, currencyLabel)
    GameTooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(label or REPUTATION or "Reputation", 0.4, 0.8, 1, true)

    local numericAmount = tonumber(amount)
    if numericAmount and numericAmount ~= 0 then
        local absAmount = math.abs(numericAmount)
        local formattedAmount = BreakUpLargeNumbers and BreakUpLargeNumbers(absAmount)
            or tostring(absAmount)
        GameTooltip:AddLine("+" .. formattedAmount .. " " .. (REPUTATION or "Reputation"), 1, 1, 1)
    end

    if currencyLabel and currencyLabel ~= "" and currencyLabel ~= label then
        GameTooltip:AddLine(currencyLabel, 0.72, 0.72, 0.76, true)
    end

    GameTooltip:Show()
end

do
    local function TooltipHasContent(tooltip)
        if not tooltip then
            return false
        end

        if tooltip.GetItem then
            local itemName = tooltip:GetItem()
            if itemName then
                return true
            end
        end

        return tooltip.NumLines and tooltip:NumLines() > 0 or false
    end

    ns._WorldQuestsTryPopulateQuestRewardTooltip = function(setter, ...)
        if type(setter) ~= "function" then
            return false
        end

        if GameTooltip.ClearLines then
            GameTooltip:ClearLines()
        end

        local ok = pcall(setter, GameTooltip, ...)
        if not ok then
            if GameTooltip.ClearLines then
                GameTooltip:ClearLines()
            end
            return false
        end

        if TooltipHasContent(GameTooltip) then
            return true
        end

        if GameTooltip.ClearLines then
            GameTooltip:ClearLines()
        end
        return false
    end
end

-- =============================================
-- Quest tooltip helper
-- =============================================

-- Shows a world-quest tooltip anchored to anchorFrame.
-- Mirrors Blizzard's TaskPOI_OnEnter → GameTooltip_AddQuest flow:
--   core-ready gate → quality-colored title → faction → time → objectives
--   → GameTooltip_AddQuestRewardsToTooltip for full reward display.
local function ShowQuestTooltip(anchorFrame, questID, showTrackHint)
    activeTooltipAnchor = anchorFrame
    activeTooltipQuestID = questID
    activeTooltipShowTrackHint = showTrackHint == true
    GameTooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")

    local row = anchorFrame
    if row and row.GetParent and not row.questEntry then
        row = row:GetParent()
    end

    if questID and questID < 0 then
        local questEntry = row and row.questEntry or nil
        local now = GetCurrentServerTime()
        local liveTimerSeconds = questEntry and GetRemainingTimeLeft(
            questEntry.timeLeft,
            questEntry.expiresAt,
            now) or nil
        local tooltipWidgetSet = questEntry and questEntry.tooltipWidgetSet or nil
        local addWidgetSet = GameTooltip_AddWidgetSet
        GameTooltip:AddLine(row and row.poiTitle or "Special Assignment", 1, 0.82, 0, true)
        local descriptionText = questEntry and questEntry.poiDescription
            and NormalizeInlineQuestText(questEntry.poiDescription) or nil
        if descriptionText and descriptionText ~= "" then
            GameTooltip:AddLine(descriptionText, 1, 1, 1, true)
        end
        if row and row.poiUnlockText and row.poiUnlockText ~= descriptionText then
            GameTooltip:AddLine(row.poiUnlockText, 1, 1, 1, true)
        end
        if tooltipWidgetSet and addWidgetSet then
            GameTooltip:AddLine(" ")
            addWidgetSet(GameTooltip, tooltipWidgetSet, 0)
        elseif not tooltipWidgetSet then
            local fallbackTimeText = questEntry and questEntry.timeText or nil
            if liveTimerSeconds and fallbackTimeText and fallbackTimeText ~= "" and fallbackTimeText ~= "---" then
                GameTooltip:AddLine("Time left: " .. fallbackTimeText, 0.72, 0.72, 0.76)
            end
            if questEntry and questEntry.rewardText and questEntry.rewardText ~= "" then
                GameTooltip:AddLine(questEntry.rewardText, 1, 1, 1, true)
            end
        end
        GameTooltip:Show()
        return
    end

    -- Gate: show "Retrieving data" until the quest has real core metadata.
    if not eventFrame:IsQuestCoreDataReady(questID) then
        eventFrame:QueueQuestCoreDataLoad(questID)
        GameTooltip:AddLine(RETRIEVING_DATA or "Retrieving data\226\128\166",
            1, 0, 0)
        GameTooltip:Show()
        return
    end

    -- Title + factionID from the authoritative task quest API.
    local title, factionID = C_TaskQuest.GetQuestInfoByQuestID(questID)
    title = title or GetQuestTitle(questID)
    if not title or title == "" then
        eventFrame:QueueQuestCoreDataLoad(questID)
        GameTooltip:AddLine(RETRIEVING_DATA or "Retrieving data\226\128\166",
            1, 0, 0)
        GameTooltip:Show()
        return
    end

    -- Quality-colored title for world quests (mirrors GameTooltip_AddQuest).
    local titleR, titleG, titleB = 1, 0.82, 0
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
        if tagInfo and tagInfo.quality then
            local color = WORLD_QUEST_QUALITY_COLORS
                and WORLD_QUEST_QUALITY_COLORS[tagInfo.quality]
            if color then
                titleR, titleG, titleB = color.r, color.g, color.b
            end
        end
    end
    GameTooltip:AddLine(title, titleR, titleG, titleB, true)

    -- Faction name (direct association from C_TaskQuest, same as Blizzard).
    if factionID and factionID > 0
        and C_Reputation and C_Reputation.GetFactionDataByID
    then
        local factionData = C_Reputation.GetFactionDataByID(factionID)
        if factionData and factionData.name then
            -- Gray out capped factions, same as GameTooltip_AddQuest.
            local isCapped = false
            if C_QuestLog.DoesQuestAwardReputationWithFaction then
                isCapped = not C_QuestLog.DoesQuestAwardReputationWithFaction(
                    questID, factionID)
            end
            if not isCapped
                and C_Reputation.IsFactionParagonForCurrentPlayer
            then
                isCapped = C_Reputation.IsFactionParagonForCurrentPlayer(factionID)
            end
            if isCapped then
                GameTooltip:AddLine(factionData.name, 0.50, 0.50, 0.50)
            else
                GameTooltip:AddLine(factionData.name, 0.70, 0.78, 0.88)
            end
        end
    end

    -- Time remaining, colour-coded like the expiry dot.
    local secs = GetQuestExpirySnapshot(
        questID,
        GetCurrentServerTime(),
        row and row.questEntry or nil)
    if secs and secs > 0 then
        local r, g, b
        if     secs < TIME_RED    then r, g, b = 1.0,  0.30, 0.30
        elseif secs < TIME_ORANGE then r, g, b = 1.0,  0.65, 0.20
        elseif secs < TIME_YELLOW then r, g, b = 1.0,  0.90, 0.30
        else                           r, g, b = 0.72, 0.72, 0.76
        end
        GameTooltip:AddLine("Time left: " .. FormatTimeLeft(secs), r, g, b)
    end

    -- Objectives
    local numObj = C_QuestLog and C_QuestLog.GetNumQuestObjectives
        and C_QuestLog.GetNumQuestObjectives(questID) or 0
    if numObj and numObj > 0 then
        for i = 1, numObj do
            local objText, _, finished
            if GetQuestObjectiveInfo then
                objText, _, finished = GetQuestObjectiveInfo(questID, i, false)
            end
            if objText and #objText > 0 then
                local r, g, b = finished and 0.5 or 1,
                                finished and 0.5 or 1,
                                finished and 0.5 or 1
                GameTooltip:AddLine(
                    (QUEST_DASH or "- ") .. objText, r, g, b, true)
            end
        end
    end

    -- Full reward details (ilvl, currency amounts, rarity, collection text).
    -- Only add the reward section once reward data is ready; otherwise request
    -- a preload and show an explicit loading line instead of a partially empty
    -- tooltip that requires a second hover to populate.
    if HaveQuestRewardData and not HaveQuestRewardData(questID) then
        rewardPreloadState.QueueQuestRewardPreload(questID, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(RETRIEVING_DATA or "Loading rewards...", 1, 0.82, 0)
    elseif GameTooltip_AddQuestRewardsToTooltip then
        GameTooltip_AddQuestRewardsToTooltip(GameTooltip, questID,
            TOOLTIP_QUEST_REWARDS_STYLE_WORLD_QUEST
            or TOOLTIP_QUEST_REWARDS_STYLE_DEFAULT)
    end

    -- Optional tracking hint
    if showTrackHint then
        local cur = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
            and C_SuperTrack.GetSuperTrackedQuestID() or nil
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            cur == questID and "Click to stop tracking" or "Click to track",
            0.60, 0.60, 0.60)
    end
    GameTooltip:Show()
end

function eventFrame:RefreshActiveQuestTooltipIfReady(questID)
    if activeTooltipQuestID ~= questID
        or not activeTooltipAnchor
        or not activeTooltipAnchor:IsShown()
    then
        return
    end

    if not self:IsQuestCoreDataReady(questID) then
        return
    end

    ShowQuestTooltip(activeTooltipAnchor, questID, activeTooltipShowTrackHint)
end

-- =============================================
-- Frame pooling helpers
-- =============================================

-- Returns an inactive quest row frame or creates a new one.
-- parent: Frame
local function AcquireQuestRow(parent)
    local row = table.remove(questRowPool)
    if row then
        row:SetParent(parent)
        row:ClearAllPoints()
        if row.fadeIn then
            row.fadeIn:Stop()
        end
        row:SetAlpha(1)
        ApplyWorldQuestTypographyToRow(row)
        -- Do NOT show here; PopulateQuestRow calls row:Show() once all content
        -- has been written.  Showing an empty recycled frame causes a blank-row
        -- flash between Phase 1 (frame placement) and Phase 2 (data fill-in).
        return row
    end

    -- Create a new row frame.  Layout: 3 visual lines in ROW_HEIGHT pixels.
    -- Line 1 (top):   [Title text ...]              [● time text]
    -- Line 2 (mid):   [Faction / type text]
    -- Line 3 (bot):   [Reward icons x4 with amount overlays]
    row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Hover background
    local hover = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    hover:SetAllPoints()
    hover:SetColorTexture(COL.rowHover[1], COL.rowHover[2], COL.rowHover[3], COL.rowHover[4])
    hover:Hide()
    row.hoverBg = hover

    -- POI tracking button.  Use the native Blizzard template
    -- ObjectiveTrackerPOIButtonTemplate (defined in Blizzard_ObjectiveTracker,
    -- inherits POIButtonTemplate).  Creating a frame with this template
    -- pre-builds all XML children (NormalTexture etc.) that POIButtonMixin's
    -- UpdateButtonStyle() requires, which is why plain CreateFrame without a
    -- template produces an invisible button.
    local poiBtn = CreateFrame("Button", nil, row, "ObjectiveTrackerPOIButtonTemplate")
    poiBtn:SetSize(POI_BUTTON_SIZE, POI_BUTTON_SIZE)
    poiBtn:SetPoint("LEFT", row, "LEFT", 8, 0)
    poiBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    -- The C-level Button engine swaps NormalTexture→PushedTexture before any Lua
    -- fires, causing the quest-type ring to briefly vanish on click.
    -- Fix: do the tracking toggle in OnMouseDown (which always fires), then
    -- immediately call SetButtonState("NORMAL") so the engine never renders the
    -- Toggle super-tracking on mouse-down so the action fires immediately and
    -- SetButtonState("NORMAL") suppresses the unwanted PUSHED texture swap.
    -- In WoW 12.0 SetButtonState no longer blocks the inherited OnClick from
    -- POIButtonMixin, so OnClick is explicitly cleared to prevent the Blizzard
    -- template from double-toggling tracking and playing unwanted sounds.
    poiBtn:SetScript("OnMouseDown", function(self)
        self:SetButtonState("NORMAL", false)
        if self.areaPoiID and self.areaPoiID > 0
            and C_SuperTrack and C_SuperTrack.SetSuperTrackedMapPin
        then
            local mapPinType = Enum and Enum.SuperTrackingMapPinType
                and Enum.SuperTrackingMapPinType.AreaPOI or 0
            local trackedType, trackedID
            if C_SuperTrack.GetSuperTrackedMapPin then
                trackedType, trackedID = C_SuperTrack.GetSuperTrackedMapPin()
            end
            if trackedType == mapPinType and trackedID == self.areaPoiID then
                if C_SuperTrack.ClearAllSuperTracked then
                    C_SuperTrack.ClearAllSuperTracked()
                end
            else
                C_SuperTrack.SetSuperTrackedMapPin(mapPinType, self.areaPoiID)
            end
            return
        end
        if not C_SuperTrack or not C_SuperTrack.SetSuperTrackedQuestID then return end
        local cur = C_SuperTrack.GetSuperTrackedQuestID
            and C_SuperTrack.GetSuperTrackedQuestID() or nil
        if not self.questID or self.questID <= 0 then return end
        if cur == self.questID then
            C_SuperTrack.SetSuperTrackedQuestID(0)
        else
            C_SuperTrack.SetSuperTrackedQuestID(self.questID)
        end
    end)
    poiBtn:SetScript("OnMouseUp", nil)
    poiBtn:SetScript("OnClick",    nil)
    poiBtn:SetScript("OnEnter", function(self)
        -- Fall back to the row's questID when poiBtn.questID has been cleared on release
        -- but Phase 2 hasn't re-populated it yet (pool LIFO shuffle can leave stale IDs).
        local rowParent = self:GetParent()
        local qid = self.questID or (rowParent and rowParent.questID) or nil
        local rowHovered = rowParent and rowParent.IsMouseOver and rowParent:IsMouseOver() or false
        local poiHovered = self.IsMouseOver and self:IsMouseOver() or false
        local contractBtn = rowParent and rowParent.contractBtn or nil
        local contractHovered = contractBtn
            and contractBtn.IsShown
            and contractBtn:IsShown()
            and contractBtn.IsMouseOver
            and contractBtn:IsMouseOver()
            or false
        local rewardHovered = false
        local rewardIcons = rowParent and rowParent.rewardIcons or nil
        if rewardIcons then
            for iconIndex = 1, #rewardIcons do
                local rewardButton = rewardIcons[iconIndex]
                if rewardButton
                    and rewardButton.IsShown
                    and rewardButton:IsShown()
                    and rewardButton.IsMouseOver
                    and rewardButton:IsMouseOver()
                then
                    rewardHovered = true
                    break
                end
            end
        end
        DebugHoverTrace(
            "POI.OnEnter",
            "questID=%s rowHovered=%s poiHovered=%s contractHovered=%s rewardHovered=%s call=StartOrResume",
            tostring(qid),
            tostring(rowHovered),
            tostring(poiHovered),
            tostring(contractHovered),
            tostring(rewardHovered))
        if qid then
            ShowQuestTooltip(self, qid, true)
            activeHoverState.StartOrResume(rowParent, qid, true, "poi-onenter", "tooltip")
        end
    end)
    poiBtn:SetScript("OnLeave", function(self)
        local rowParent = self:GetParent()
        local qid = self.questID or (rowParent and rowParent.questID) or nil
        local rowHovered = rowParent and rowParent.IsMouseOver and rowParent:IsMouseOver() or false
        local poiHovered = self.IsMouseOver and self:IsMouseOver() or false
        local contractBtn = rowParent and rowParent.contractBtn or nil
        local contractHovered = contractBtn
            and contractBtn.IsShown
            and contractBtn:IsShown()
            and contractBtn.IsMouseOver
            and contractBtn:IsMouseOver()
            or false
        local rewardHovered = false
        local rewardIcons = rowParent and rowParent.rewardIcons or nil
        if rewardIcons then
            for iconIndex = 1, #rewardIcons do
                local rewardButton = rewardIcons[iconIndex]
                if rewardButton
                    and rewardButton.IsShown
                    and rewardButton:IsShown()
                    and rewardButton.IsMouseOver
                    and rewardButton:IsMouseOver()
                then
                    rewardHovered = true
                    break
                end
            end
        end
        DebugHoverTrace(
            "POI.OnLeave",
            "questID=%s rowHovered=%s poiHovered=%s contractHovered=%s rewardHovered=%s call=DeferStop",
            tostring(qid),
            tostring(rowHovered),
            tostring(poiHovered),
            tostring(contractHovered),
            tostring(rewardHovered))
        ClearActiveQuestTooltip(self)
        activeHoverState.DeferStop(qid, "poi-onleave")
    end)
    row.poiBtn = poiBtn
    local areaPoiIcon = poiBtn:CreateTexture(nil, "ARTWORK", nil, 1)
    areaPoiIcon:SetAllPoints()
    areaPoiIcon:Hide()
    poiBtn.nomtoolsAreaPOIIcon = areaPoiIcon

    -- Title (top line, left) — left margin accounts for POI button + gap; right for time
    local titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -9)
    titleText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -70, -9)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    titleText:SetTextColor(1, 0.82, 0)
    row.titleText = titleText

    -- Time remaining (top line, right-aligned)
    local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -21, -12)
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(COL.rowTime[1], COL.rowTime[2], COL.rowTime[3])
    row.timeText = timeText

    -- Expiry dot — circular, placed to the right of the time text
    local dot = row:CreateTexture(nil, "ARTWORK")
    dot:SetSize(9, 9)
    dot:SetPoint("LEFT", timeText, "RIGHT", 4, 0)
    dot:SetTexture("Interface\\Buttons\\WHITE8x8")
    -- Circular mask so the square texture appears as a solid disc
    local dotMask = row:CreateMaskTexture(nil, "ARTWORK")
    dotMask:SetAllPoints(dot)
    dotMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                       "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    dot:AddMaskTexture(dotMask)
    row.timeDot = dot

    -- Faction / quest-type label (second line)
    local factionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    factionText:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -23)
    factionText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -20, -23)
    factionText:SetJustifyH("LEFT")
    factionText:SetWordWrap(false)
    factionText:SetTextColor(COL.rowFaction[1], COL.rowFaction[2], COL.rowFaction[3])
    row.factionText = factionText

    local contractBtn = CreateFrame("Button", nil, row)
    contractBtn:SetSize(CONTRACT_ICON_SIZE, CONTRACT_ICON_SIZE)
    contractBtn:Hide()

    local contractIcon = contractBtn:CreateTexture(nil, "ARTWORK")
    contractIcon:SetAllPoints()
    contractIcon:SetTexture("Interface\\AddOns\\NomTools\\media\\Contract_Icon_No_BG.png")
    contractBtn.icon = contractIcon

    contractBtn:SetScript("OnEnter", function(self)
        local rowParent = self:GetParent()
        local qid = self.questID or (rowParent and rowParent.questID) or nil
        local setAuraTooltip = GameTooltip["SetUnitAuraByAuraInstanceID"]
            or GameTooltip["SetUnitBuffByAuraInstanceID"]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.auraInstanceID and setAuraTooltip then
            setAuraTooltip(GameTooltip, "player", self.auraInstanceID)
        elseif self.spellID and GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(self.spellID)
        end
        GameTooltip:Show()
        if qid then
            activeHoverState.StartOrResume(rowParent, qid, false, "contract-onenter", "tooltip")
        end
    end)
    contractBtn:SetScript("OnLeave", function(self)
        local rowParent = self:GetParent()
        local qid = self.questID or (rowParent and rowParent.questID) or nil
        GameTooltip:Hide()
        activeHoverState.DeferStop(qid, "contract-onleave")
    end)
    row.contractBtn = contractBtn

    -- Reward icons (bottom line, left-aligned)
    local rewardIcons = {}
    for iconIdx = 1, MAX_REWARD_ICONS do
        local btn = CreateFrame("Button", nil, row)
        btn:SetSize(REWARD_ICON_SIZE, REWARD_ICON_SIZE)
        if iconIdx == 1 then
            btn:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -37)
        else
            btn:SetPoint("LEFT", rewardIcons[iconIdx - 1], "RIGHT", 3, 0)
        end

        local iconTex = btn:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.iconTex = iconTex

        local countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -1)
        countText:SetJustifyH("RIGHT")
        btn.countText = countText

        local borderTop = btn:CreateTexture(nil, "OVERLAY")
        borderTop:SetTexture("Interface\\Buttons\\WHITE8x8")
        borderTop:SetPoint("TOPLEFT",  btn, "TOPLEFT",  0, 0)
        borderTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        borderTop:SetHeight(1)
        borderTop:Hide()
        btn.borderTop = borderTop

        local borderBottom = btn:CreateTexture(nil, "OVERLAY")
        borderBottom:SetTexture("Interface\\Buttons\\WHITE8x8")
        borderBottom:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, 0)
        borderBottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        borderBottom:SetHeight(1)
        borderBottom:Hide()
        btn.borderBottom = borderBottom

        local borderLeft = btn:CreateTexture(nil, "OVERLAY")
        borderLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
        borderLeft:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, 0)
        borderLeft:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        borderLeft:SetWidth(1)
        borderLeft:Hide()
        btn.borderLeft = borderLeft

        local borderRight = btn:CreateTexture(nil, "OVERLAY")
        borderRight:SetTexture("Interface\\Buttons\\WHITE8x8")
        borderRight:SetPoint("TOPRIGHT",    btn, "TOPRIGHT",    0, 0)
        borderRight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        borderRight:SetWidth(1)
        borderRight:Hide()
        btn.borderRight = borderRight

        btn:SetScript("OnEnter", function(self)
            local parentRow = self:GetParent()
            local qid = self.questID or (parentRow and parentRow.questID) or nil
            if not self.rewardType then return end
            activeTooltipAnchor = nil
            activeTooltipQuestID = nil
            activeTooltipShowTrackHint = false
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.questID and not rewardPreloadState.IsQuestRewardDisplayReady(self.questID) then
                rewardPreloadState.QueueQuestRewardPreload(self.questID, true)
                GameTooltip:AddLine(RETRIEVING_DATA or "Loading rewards...", 1, 0.82, 0)
                GameTooltip:Show()
                if qid then
                    activeHoverState.StartOrResume(parentRow, qid, false, "reward-onenter", "reward-tooltip")
                end
                return
            end
            if self.rewardType == "item" then
                local usedQuestTooltip = false
                local canUseQuestRewardContext = self.questID
                    and self.rewardIndex
                    and self.questRewardType
                local setQuestLogItem = GameTooltip.SetQuestLogItem
                if setQuestLogItem and canUseQuestRewardContext then
                    usedQuestTooltip = ns._WorldQuestsTryPopulateQuestRewardTooltip(
                        setQuestLogItem,
                        self.questRewardType,
                        self.rewardIndex,
                        self.questID,
                        true)
                end
                if not usedQuestTooltip and canUseQuestRewardContext then
                    GameTooltip:SetText(self.label or (RETRIEVING_DATA or "Retrieving data..."), 1, 1, 1)
                    if self.ilvl and self.ilvl > 0 then
                        GameTooltip:AddLine("Item level " .. self.ilvl, 1, 1, 1)
                    end
                    GameTooltip:AddLine(RETRIEVING_DATA or "Reward details are still loading...", 1, 0.82, 0, true)
                elseif not usedQuestTooltip and self.itemID then
                    GameTooltip:SetHyperlink("item:" .. self.itemID)
                elseif not usedQuestTooltip then
                    GameTooltip:SetText(self.label or "", 1, 1, 1)
                    if self.ilvl and self.ilvl > 0 then
                        GameTooltip:AddLine("Item level " .. self.ilvl, 1, 1, 1)
                    end
                end
                if GameTooltip_ShowCompareItem
                    and (usedQuestTooltip or (not canUseQuestRewardContext and self.itemID))
                then
                    GameTooltip_ShowCompareItem(GameTooltip)
                end
            elseif self.rewardType == "rep" then
                ns.ShowReputationRewardTooltip(self, self.label, self.amount, self.currencyLabel)
                if qid then
                    activeHoverState.StartOrResume(parentRow, qid, false, "reward-onenter", "reward-tooltip")
                end
                return
            elseif self.rewardType == "currency" then
                local usedQuestTooltip = false
                local setQuestLogCurrency = GameTooltip.SetQuestLogCurrency or GameTooltip.SetQuestCurrency
                if setQuestLogCurrency and self.rewardIndex and self.questRewardType then
                    usedQuestTooltip = ns._WorldQuestsTryPopulateQuestRewardTooltip(
                        setQuestLogCurrency,
                        self.questRewardType,
                        self.rewardIndex,
                        self.questID)
                    if not usedQuestTooltip then
                        usedQuestTooltip = ns._WorldQuestsTryPopulateQuestRewardTooltip(
                            setQuestLogCurrency,
                            self.questRewardType,
                            self.rewardIndex)
                    end
                end
                if not usedQuestTooltip and self.currencyID and GameTooltip.SetCurrencyByID then
                    GameTooltip:SetCurrencyByID(self.currencyID)
                    local numericAmount = tonumber(self.amount)
                    if numericAmount and numericAmount ~= 0 then
                        local formattedAmount = BreakUpLargeNumbers
                            and BreakUpLargeNumbers(math.abs(numericAmount))
                            or tostring(math.abs(numericAmount))
                        GameTooltip:AddLine((REWARD or "Reward") .. ": " .. formattedAmount, 1, 1, 1)
                    end
                elseif not usedQuestTooltip then
                    GameTooltip:SetText(self.label or "", 1, 1, 1)
                    local numericAmount = tonumber(self.amount)
                    if numericAmount and numericAmount ~= 0 then
                        local formattedAmount = BreakUpLargeNumbers
                            and BreakUpLargeNumbers(math.abs(numericAmount))
                            or tostring(math.abs(numericAmount))
                        GameTooltip:AddLine((REWARD or "Reward") .. ": " .. formattedAmount, 1, 1, 1)
                    end
                end
            else
                GameTooltip:SetText(self.label or "", 1, 1, 1)
            end
            GameTooltip:Show()
            if qid then
                activeHoverState.StartOrResume(parentRow, qid, false, "reward-onenter", "reward-tooltip")
            end
        end)
        btn:SetScript("OnLeave", function(self)
            local parentRow = self:GetParent()
            local qid = self.questID or (parentRow and parentRow.questID) or nil
            GameTooltip:Hide()
            if GameTooltip_HideShoppingTooltips then
                GameTooltip_HideShoppingTooltips()
            end
            activeHoverState.DeferStop(qid, "reward-onleave")
        end)
        btn:Hide()

        rewardIcons[iconIdx] = btn
    end
    row.rewardIcons = rewardIcons

    -- Money text (bottom line): shown as a left-aligned text label in place of
    -- a gold icon so the full denomination (g / s / c) has room to display.
    -- Anchored dynamically in PopulateQuestRow based on icon count.
    local moneyText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    moneyText:SetJustifyH("LEFT")
    moneyText:SetTextColor(1, 1, 1)  -- per-denomination colours are baked into the label string
    moneyText:Hide()
    row.moneyText = moneyText

    -- Bottom separator line
    local sep = row:CreateTexture(nil, "BACKGROUND")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    sep:SetColorTexture(
        COL.separator[1], COL.separator[2],
        COL.separator[3], COL.separator[4])
    row.separator = sep

    -- Row hover: show/hide the hover background and the quest tooltip.
    row:SetScript("OnEnter", function(self)
        local rowHovered = self.IsMouseOver and self:IsMouseOver() or false
        local poiHovered = self.poiBtn and self.poiBtn.IsMouseOver and self.poiBtn:IsMouseOver() or false
        local contractBtn = self.contractBtn
        local contractHovered = contractBtn
            and contractBtn.IsShown
            and contractBtn:IsShown()
            and contractBtn.IsMouseOver
            and contractBtn:IsMouseOver()
            or false
        local rewardHovered = false
        local rewardIcons = self.rewardIcons
        if rewardIcons then
            for iconIndex = 1, #rewardIcons do
                local rewardButton = rewardIcons[iconIndex]
                if rewardButton
                    and rewardButton.IsShown
                    and rewardButton:IsShown()
                    and rewardButton.IsMouseOver
                    and rewardButton:IsMouseOver()
                then
                    rewardHovered = true
                    break
                end
            end
        end
        DebugHoverTrace(
            "Row.OnEnter",
            "questID=%s rowHovered=%s poiHovered=%s contractHovered=%s rewardHovered=%s call=StartOrResume",
            tostring(self.questID),
            tostring(rowHovered),
            tostring(poiHovered),
            tostring(contractHovered),
            tostring(rewardHovered))
        if self.questID then
            ShowQuestTooltip(self, self.questID, false)
        end
        activeHoverState.StartOrResume(self, self.questID, true, "row-onenter", "tooltip")
    end)
    row:SetScript("OnLeave", function(self)
        local rowHovered = self.IsMouseOver and self:IsMouseOver() or false
        local poiHovered = self.poiBtn and self.poiBtn.IsMouseOver and self.poiBtn:IsMouseOver() or false
        local contractBtn = self.contractBtn
        local contractHovered = contractBtn
            and contractBtn.IsShown
            and contractBtn:IsShown()
            and contractBtn.IsMouseOver
            and contractBtn:IsMouseOver()
            or false
        local rewardHovered = false
        local rewardIcons = self.rewardIcons
        if rewardIcons then
            for iconIndex = 1, #rewardIcons do
                local rewardButton = rewardIcons[iconIndex]
                if rewardButton
                    and rewardButton.IsShown
                    and rewardButton:IsShown()
                    and rewardButton.IsMouseOver
                    and rewardButton:IsMouseOver()
                then
                    rewardHovered = true
                    break
                end
            end
        end
        DebugHoverTrace(
            "Row.OnLeave",
            "questID=%s rowHovered=%s poiHovered=%s contractHovered=%s rewardHovered=%s call=DeferStop",
            tostring(self.questID),
            tostring(rowHovered),
            tostring(poiHovered),
            tostring(contractHovered),
            tostring(rewardHovered))
        ClearActiveQuestTooltip(self)
        activeHoverState.DeferStop(self.questID, "row-onleave")
    end)

    row:SetScript("OnClick", function(self, button)
        -- Toggle super-tracking (mirrors poiBtn OnMouseDown logic).
        local poiBtn = self.poiBtn
        if poiBtn then
            if poiBtn.areaPoiID and poiBtn.areaPoiID > 0
                and C_SuperTrack and C_SuperTrack.SetSuperTrackedMapPin
            then
                local mapPinType = Enum and Enum.SuperTrackingMapPinType
                    and Enum.SuperTrackingMapPinType.AreaPOI or 0
                local trackedType, trackedID
                if C_SuperTrack.GetSuperTrackedMapPin then
                    trackedType, trackedID = C_SuperTrack.GetSuperTrackedMapPin()
                end
                if trackedType == mapPinType and trackedID == poiBtn.areaPoiID then
                    if C_SuperTrack.ClearAllSuperTracked then
                        C_SuperTrack.ClearAllSuperTracked()
                    end
                else
                    C_SuperTrack.SetSuperTrackedMapPin(mapPinType, poiBtn.areaPoiID)
                end
            elseif poiBtn.questID and poiBtn.questID > 0
                and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID
            then
                local cur = C_SuperTrack.GetSuperTrackedQuestID
                    and C_SuperTrack.GetSuperTrackedQuestID() or nil
                if cur == poiBtn.questID then
                    C_SuperTrack.SetSuperTrackedQuestID(0)
                else
                    C_SuperTrack.SetSuperTrackedQuestID(poiBtn.questID)
                end
            end
        end
        -- Navigate the world map (both left and right click).
        if not self.mapID or not WorldMapFrame then return end
        if not WorldMapFrame:IsVisible() then
            ShowUIPanel(WorldMapFrame)
        end
        if WorldMapFrame:GetMapID() ~= self.mapID then
            WorldMapFrame:SetMapID(self.mapID)
        end
    end)

    local fadeIn = row:CreateAnimationGroup()
    local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(0.2)
    if fadeInAlpha.SetSmoothing then
        fadeInAlpha:SetSmoothing("OUT")
    end
    fadeIn:SetScript("OnFinished", function(self)
        self:GetParent():SetAlpha(1)
    end)
    row.fadeIn = fadeIn
    ApplyWorldQuestTypographyToRow(row)

    -- Start fully hidden; PopulateQuestRow shows the row once all content is set.
    row:Hide()
    return row
end

-- Returns a row to the pool after hiding and detaching it.
-- row: Frame
local function ReleaseQuestRow(row, skipTooltipCheck)
    if row.fadeIn then
        row.fadeIn:Stop()
    end
    if activeHoverState.row == row then
        DebugHoverTrace(
            "ReleaseQuestRow",
            "releasing-active-row rowQuestID=%s activeQuestID=%s row=%s",
            tostring(rawget(row, "questID")),
            tostring(activeHoverState.questID),
            GetHoverRowIdentity(row))
    end
    if activeHoverState.row == row then
        activeHoverState.row = nil
        if activeHoverState.poiBtn == row.poiBtn then
            activeHoverState.poiBtn = nil
        end
    end
    row._hlLastPin = nil
    row._hlMisses = nil
    row._hlMissStart = nil
    if not skipTooltipCheck then
        local ownsTooltip = activeTooltipAnchor == row
            or activeTooltipAnchor == row.poiBtn
            or activeTooltipAnchor == row.contractBtn

        if not ownsTooltip and activeTooltipAnchor and activeTooltipAnchor.GetParent then
            ownsTooltip = activeTooltipAnchor:GetParent() == row
        end

        if not ownsTooltip and GameTooltip and GameTooltip.IsOwned then
            ownsTooltip = GameTooltip:IsOwned(row)
                or (row.poiBtn and GameTooltip:IsOwned(row.poiBtn))
                or (row.contractBtn and GameTooltip:IsOwned(row.contractBtn))

            if not ownsTooltip and row.rewardIcons then
                for _, rewardButton in ipairs(row.rewardIcons) do
                    if GameTooltip:IsOwned(rewardButton) then
                        ownsTooltip = true
                        break
                    end
                end
            end
        end

        if ownsTooltip then
            ClearActiveQuestTooltip()
        end
    end
    row:Hide()
    row:SetAlpha(1)
    if row.hoverBg then
        row.hoverBg:Hide()
    end
    row:SetParent(nil)
    row:ClearAllPoints()
    row.questID          = nil
    row.mapID            = nil
    row.mapName          = nil
    row.questEntry       = nil
        row.isAreaPOI        = nil
        row.poiTitle         = nil
        row.poiUnlockText    = nil
        if row.poiBtn.Reset then
            row.poiBtn:Reset()
        end
        ClearPOIButtonAreaPOIState(row.poiBtn)
        if row.poiBtn.Display and row.poiBtn.Display.SetIconShown then
            row.poiBtn.Display:SetIconShown(true)
        elseif row.poiBtn.Display and row.poiBtn.Display.Icon then
            row.poiBtn.Display.Icon:SetAlpha(1)
        end
        row.poiBtn.questID   = nil  -- poiBtn.questID is only set in Phase 2; clear here so that if the
                                    -- pooled frame is re-assigned to a different quest and OnEnter fires
                                    -- before Phase 2 runs, it falls back to row.questID (set in Phase 1)
        row.poiBtn.areaPoiID = nil
        row.poiBtn:Hide()
    if row.poiBtn.nomtoolsAreaPOIIcon then
        row.poiBtn.nomtoolsAreaPOIIcon:Hide()
    end
    row.contractBtn.auraInstanceID = nil
    row.contractBtn.spellID = nil
    row.contractBtn:Hide()
    questRowPool[#questRowPool + 1] = row
end

-- Returns an inactive zone header frame or creates a new one.
-- parent: Frame
local function AcquireZoneHeader(parent)
    local hdr = table.remove(zoneHeaderPool)
    if hdr then
        hdr:SetParent(parent)
        hdr:ClearAllPoints()
        hdr:Show()
        ApplyWorldQuestTypographyToHeader(hdr)
        return hdr
    end

    -- QuestLogHeaderTemplate inherits both ListHeaderVisualTemplate (visual)
    -- and QuestLogHeaderCodeTemplate / ListHeaderCodeTemplate (behaviour).
    -- We need ListHeaderCodeTemplate too, so ListHeaderMixin:OnLoad fires and
    -- sets the initial DISABLED_FONT_COLOR (grey) text, and OnEnter/OnLeave
    -- toggle it to HIGHLIGHT_FONT_COLOR (white) on hover.
    hdr = CreateFrame("Button", nil, parent, "ListHeaderVisualTemplate, ListHeaderCodeTemplate")
    hdr:SetHeight(ZONE_HEADER_HEIGHT)

    -- Add a quest count label docked just left of the CollapseButton.
    local countLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countLabel:SetPoint("RIGHT", hdr.CollapseButton, "LEFT", -4, 0)
    countLabel:SetJustifyH("RIGHT")
    countLabel:SetAlpha(0.7)
    hdr.countLabel = countLabel

    -- The template anchors ButtonText.RIGHT to CollapseButton.LEFT - 4.
    -- Re-anchor it to end before countLabel so the two don't overlap.
    hdr.ButtonText:ClearAllPoints()
    hdr.ButtonText:SetPoint("LEFT", hdr, "LEFT", 8, 1)
    hdr.ButtonText:SetPoint("RIGHT", countLabel, "LEFT", -4, 1)

    -- Keep .label pointing at ButtonText for LayoutScrollContent compatibility.
    hdr.label = hdr.ButtonText

    -- SetCollapsed: delegates to CollapseButtonMixin.UpdateCollapsedState, which
    -- switches questlog-icon-expand (collapsed) / questlog-icon-shrink (expanded).
    hdr.SetCollapsed = function(self, collapsed)
        self.isCollapsed = collapsed
        if self.CollapseButton then
            self.CollapseButton:UpdateCollapsedState(collapsed)
        end
    end

    -- Use SetClickHandler (ListHeaderMixin's click dispatch) instead of
    -- SetScript so the mixin's OnLoad/OnEnter/OnLeave chain is not broken.
    hdr:SetClickHandler(function(self)
        if not self.zoneName then return end
        local newCollapsed = not (collapseState[self.zoneName] or false)
        collapseState[self.zoneName] = newCollapsed
        self:SetCollapsed(newCollapsed)
        ScheduleRefresh()
    end)

    ApplyWorldQuestTypographyToHeader(hdr)

    return hdr
end

-- Returns a zone header to the pool.
-- hdr: Frame
local function ReleaseZoneHeader(hdr)
    hdr:Hide()
    hdr:SetParent(nil)
    hdr:ClearAllPoints()
    zoneHeaderPool[#zoneHeaderPool + 1] = hdr
end

-- =============================================
-- Populating a quest row with data
-- =============================================

local function UpdateQuestRowTimeDisplay(row, entry)
    local now = GetCurrentServerTime()

    if entry.isAreaPOI and entry.areaPOITimeText
        and ((entry.timeLeft and entry.timeLeft > 0) or (entry.expiresAt and entry.expiresAt > now))
    then
        entry.timeText = entry.areaPOITimeText
    elseif entry.timeLeft and entry.timeLeft > 0 then
        entry.timeText = FormatTimeLeft(entry.timeLeft)
    elseif entry.expiresAt and entry.expiresAt > 0 then
        local remaining = entry.expiresAt - now
        entry.timeText = remaining > 0 and FormatTimeLeft(remaining) or FormatTimeLeft(nil)
    elseif not entry.timeText or entry.timeText == "" then
        entry.timeText = FormatTimeLeft(nil)
    end

    local dotR, dotG, dotB = GetDotColor(entry.timeLeft)
    row.timeDot:SetColorTexture(dotR, dotG, dotB)
    row.timeText:SetText(entry.timeText or "")
    row.timeText:Show()
    row.timeDot:Show()
end

local function GetQuestRowHeight(entry)
    if entry and entry.isAreaPOI == true then
        return ROW_HEIGHT
    end

    if entry and entry.isLocked then
        return LOCKED_ROW_HEIGHT
    end

    return ROW_HEIGHT
end

local function ApplyQuestRowLayout(row, entry)
    local isLocked = entry and entry.isLocked == true

    row:SetHeight(GetQuestRowHeight(entry))

    row.titleText:ClearAllPoints()
    row.titleText:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -9)
    row.titleText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -70, -9)
    row.titleText:SetWordWrap(false)

    row.timeText:ClearAllPoints()
    row.timeText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -21, -12)
    row.timeDot:ClearAllPoints()
    row.timeDot:SetPoint("LEFT", row.timeText, "RIGHT", 4, 0)

    row.factionText:ClearAllPoints()
    row.factionText:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -23)
    if entry and entry.isAreaPOI == true then
        row.factionText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -20, -23)
        row.factionText:SetWordWrap(false)
        row.factionText:SetJustifyV("MIDDLE")
        if row.factionText.SetMaxLines then
            row.factionText:SetMaxLines(1)
        end
    elseif isLocked then
        row.factionText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -20, 9)
        row.factionText:SetWordWrap(true)
        row.factionText:SetJustifyV("TOP")
        if row.factionText.SetMaxLines then
            row.factionText:SetMaxLines(2)
        end
    else
        row.factionText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -20, -23)
        row.factionText:SetWordWrap(false)
        row.factionText:SetJustifyV("MIDDLE")
        if row.factionText.SetMaxLines then
            row.factionText:SetMaxLines(1)
        end
    end
end

local function ResetQuestRowRewards(row)
    for iconIdx = 1, MAX_REWARD_ICONS do
        local btn = row.rewardIcons[iconIdx]
        btn:Hide()
        btn.rewardType = nil
        btn.questRewardType = nil
        btn.amount     = nil
        btn.itemID     = nil
        btn.currencyID = nil
        btn.factionID  = nil
        btn.currencyLabel = nil
        btn.label      = nil
        btn.ilvl       = nil
        btn.quality    = nil
        btn.questID    = nil
        btn.rewardIndex = nil
        if btn.SetID then
            btn:SetID(0)
        end
        btn.countText:SetText("")
        if btn.borderTop then
            btn.borderTop:Hide()
            btn.borderBottom:Hide()
            btn.borderLeft:Hide()
            btn.borderRight:Hide()
        end
    end

    row.moneyText:SetText("")
    row.moneyText:Hide()
end

local function ApplyQuestRowTitleColor(titleText, questID, isLocked, isPendingTitle)
    local superTrackedID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID() or nil

    if superTrackedID and superTrackedID == questID then
        titleText:SetTextColor(
            COL.superTrackOn[1], COL.superTrackOn[2], COL.superTrackOn[3])
    elseif isLocked then
        titleText:SetTextColor(
            COL.rowTitleLocked[1], COL.rowTitleLocked[2], COL.rowTitleLocked[3])
    elseif isPendingTitle then
        titleText:SetTextColor(0.55, 0.55, 0.55)
    else
        titleText:SetTextColor(1, 0.82, 0)
    end
end

local function IsLockedSpecialAssignmentEntry(entry)
    if not entry or entry.isLocked ~= true then
        return false
    end

    return IsSpecialAssignmentFromMetadata(
        entry.rawQuestTagType,
        entry.rawTagID,
        entry.questType)
end

local function HasVisibleLockedSpecialAssignmentUnlock()
    if not questMapPanel or not questMapPanel:IsShown() then
        return false
    end

    if not C_TaskQuest or not C_TaskQuest.IsActive then
        return false
    end

    for _, item in ipairs(activeContent) do
        if item.type == "row" then
            local entry = item._entry or (item.frame and item.frame.questEntry)
            local questID = (item.frame and item.frame.questID) or (entry and entry.questID)
            if questID and questID > 0 and IsLockedSpecialAssignmentEntry(entry)
                and C_TaskQuest.IsActive(questID)
            then
                return true
            end
        end
    end

    return false
end

do
    local GetLiveLockedAreaPOIWidgetFingerprint

    local function BuildVisibleLockedAreaPOISnapshotPart(questID, mapID, poiID, poiInfo,
        fallbackName, fallbackDescription, fallbackWidgetSetID)
        local poiName = poiInfo and poiInfo.name or fallbackName or ""
        local poiDescription = poiInfo and poiInfo.description or fallbackDescription or ""
        local atlasName = poiInfo and poiInfo.atlasName or ""
        local widgetSetID = poiInfo and poiInfo.tooltipWidgetSet
            or fallbackWidgetSetID or 0
        local widgetCount, widgetFingerprint, widgetPayloadFingerprint =
            GetLiveLockedAreaPOIWidgetFingerprint(widgetSetID)

        return string_format(
            "%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s",
            tostring(questID or 0),
            tostring(mapID or 0),
            tostring(poiID or 0),
            poiInfo and "1" or "0",
            atlasName,
            tostring(widgetSetID or 0),
            tostring(widgetCount),
            tostring(widgetFingerprint),
            tostring(widgetPayloadFingerprint),
            poiName,
            NormalizeInlineQuestText(poiDescription) or "")
    end

    local function CompareLockedAreaPOIWidgets(leftWidget, rightWidget)
        local leftOrder = leftWidget.orderIndex or 0
        local rightOrder = rightWidget.orderIndex or 0
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end

        local leftType = leftWidget.widgetType or 0
        local rightType = rightWidget.widgetType or 0
        if leftType ~= rightType then
            return leftType < rightType
        end

        return (leftWidget.widgetID or 0) < (rightWidget.widgetID or 0)
    end

    local function AccumulateLockedAreaPOIWidgetHash(hash, value)
        return ((hash * 131) + (value or 0) + 1) % 2147483647
    end

    do
        local LOCKED_AREA_POI_TIMER_TEXT_HASH = "__timer__"

        local function AccumulateLockedAreaPOIWidgetTextHash(hash, text, normalizeTimerText)
            local normalizedText = NormalizeInlineQuestText(text)
            if normalizeTimerText and normalizedText then
                normalizedText = LOCKED_AREA_POI_TIMER_TEXT_HASH
            end

                normalizedText = normalizedText or ""

            hash = AccumulateLockedAreaPOIWidgetHash(hash, #normalizedText)
            for index = 1, #normalizedText do
                hash = AccumulateLockedAreaPOIWidgetHash(hash, normalizedText:byte(index))
            end

            return hash
        end

        local function AccumulateLockedAreaPOICurrencyPayloadHash(hash, currencies)
            local currencyCount = currencies and #currencies or 0

            hash = AccumulateLockedAreaPOIWidgetHash(hash, currencyCount)

            if currencies then
                for currencyIndex = 1, currencyCount do
                    local currencyInfo = currencies[currencyIndex]

                    hash = AccumulateLockedAreaPOIWidgetHash(
                        hash,
                        currencyInfo and currencyInfo.currencyID or 0)
                    hash = AccumulateLockedAreaPOIWidgetHash(
                        hash,
                        currencyInfo and currencyInfo.iconFileID or 0)
                    hash = AccumulateLockedAreaPOIWidgetHash(
                        hash,
                        currencyInfo and (currencyInfo.quantity or currencyInfo.amount) or 0)
                    hash = AccumulateLockedAreaPOIWidgetTextHash(
                        hash,
                        currencyInfo and currencyInfo.leadingText or nil)
                    hash = AccumulateLockedAreaPOIWidgetTextHash(
                        hash,
                        currencyInfo and currencyInfo.text or nil)
                end
            end

            return hash
        end

        local function AccumulateLockedAreaPOIWidgetPayloadHash(hash, widgetInfo)
            local shownState = widgetInfo and widgetInfo.shownState
            if shownState == false or shownState == 0 then
                return AccumulateLockedAreaPOIWidgetHash(hash, 0)
            end

            hash = AccumulateLockedAreaPOIWidgetHash(hash, 1)

            local widgetType = widgetInfo.widgetType
            local widgetID = widgetInfo.widgetID

            if widgetType == 2 and C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo then
                local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetID)
                local hasTimer = info and info.hasTimer == true
                    local overrideBarText = info and info.overrideBarText or nil
                    local infoText = info and info.text or nil
                    local normalizedOverrideBarText = NormalizeInlineQuestText(overrideBarText)
                    local normalizedInfoText = NormalizeInlineQuestText(infoText)
                    local overrideBarTextIsTimer = hasTimer and normalizedOverrideBarText
                        and eventFrame:IsAreaPOITimeText(normalizedOverrideBarText) or false
                    local infoTextIsTimer = hasTimer and normalizedInfoText
                        and eventFrame:IsAreaPOITimeText(normalizedInfoText) or false

                hash = AccumulateLockedAreaPOIWidgetHash(hash, info and 1 or 0)
                hash = AccumulateLockedAreaPOIWidgetHash(hash, hasTimer and 1 or 0)
                hash = AccumulateLockedAreaPOIWidgetTextHash(
                    hash,
                        overrideBarText,
                        overrideBarTextIsTimer)
                hash = AccumulateLockedAreaPOIWidgetTextHash(
                    hash,
                        infoText,
                        infoTextIsTimer)
            elseif widgetType == 8 and C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo then
                local info = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgetID)
                local normalizedText = info and NormalizeInlineQuestText(info.text) or nil
                local isTimerText = normalizedText and eventFrame:IsAreaPOITimeText(normalizedText) or false

                hash = AccumulateLockedAreaPOIWidgetHash(hash, info and 1 or 0)
                hash = AccumulateLockedAreaPOIWidgetTextHash(hash, normalizedText, isTimerText)
            elseif widgetType == 7 and C_UIWidgetManager.GetIconTextAndCurrenciesWidgetVisualizationInfo then
                local info = C_UIWidgetManager.GetIconTextAndCurrenciesWidgetVisualizationInfo(widgetID)

                hash = AccumulateLockedAreaPOIWidgetHash(hash, info and 1 or 0)
                hash = AccumulateLockedAreaPOIWidgetTextHash(hash, info and info.text or nil)
                hash = AccumulateLockedAreaPOICurrencyPayloadHash(hash, info and info.currencies or nil)
            elseif widgetType == 9 and C_UIWidgetManager.GetHorizontalCurrenciesWidgetVisualizationInfo then
                local info = C_UIWidgetManager.GetHorizontalCurrenciesWidgetVisualizationInfo(widgetID)

                hash = AccumulateLockedAreaPOIWidgetHash(hash, info and 1 or 0)
                hash = AccumulateLockedAreaPOICurrencyPayloadHash(hash, info and info.currencies or nil)
            elseif widgetType == 13 and C_UIWidgetManager.GetSpellDisplayVisualizationInfo then
                local info = C_UIWidgetManager.GetSpellDisplayVisualizationInfo(widgetID)
                local spellInfo = info and info.spellInfo or nil

                hash = AccumulateLockedAreaPOIWidgetHash(hash, spellInfo and 1 or 0)
                hash = AccumulateLockedAreaPOIWidgetHash(hash, spellInfo and spellInfo.spellID or 0)
                hash = AccumulateLockedAreaPOIWidgetTextHash(hash, spellInfo and spellInfo.text or nil)
            elseif widgetType == 27 and C_UIWidgetManager.GetItemDisplayVisualizationInfo then
                local info = C_UIWidgetManager.GetItemDisplayVisualizationInfo(widgetID)
                local itemInfo = info and info.itemInfo or nil

                hash = AccumulateLockedAreaPOIWidgetHash(hash, itemInfo and 1 or 0)
                hash = AccumulateLockedAreaPOIWidgetHash(hash, itemInfo and itemInfo.itemID or 0)
                hash = AccumulateLockedAreaPOIWidgetHash(hash, itemInfo and itemInfo.stackCount or 0)
                hash = AccumulateLockedAreaPOIWidgetTextHash(hash, itemInfo and itemInfo.overrideItemName or nil)
                hash = AccumulateLockedAreaPOIWidgetTextHash(hash, itemInfo and itemInfo.infoText or nil)
            end

            return hash
        end

        GetLiveLockedAreaPOIWidgetFingerprint = function(widgetSetID)
            if not widgetSetID or widgetSetID <= 0 or not C_UIWidgetManager
                or not C_UIWidgetManager.GetAllWidgetsBySetID
            then
                return 0, 0, 0
            end

            local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID)
            if not widgets or #widgets == 0 then
                return 0, 0, 0
            end

            local orderedWidgets = eventFrame._liveRelevantAreaPOIWidgetFingerprintWidgets or {}
            local widgetCount = #widgets

            eventFrame._liveRelevantAreaPOIWidgetFingerprintWidgets = orderedWidgets

            for index = 1, widgetCount do
                orderedWidgets[index] = widgets[index]
            end

            for index = widgetCount + 1, #orderedWidgets do
                orderedWidgets[index] = nil
            end

            table_sort(orderedWidgets, CompareLockedAreaPOIWidgets)

            local hash = widgetCount
            local payloadHash = widgetCount
            for index = 1, widgetCount do
                local widgetInfo = orderedWidgets[index]
                local shownState = widgetInfo.shownState
                if shownState == true then
                    shownState = 1
                elseif shownState == false then
                    shownState = 0
                end

                hash = AccumulateLockedAreaPOIWidgetHash(hash, widgetInfo.orderIndex or 0)
                hash = AccumulateLockedAreaPOIWidgetHash(hash, widgetInfo.widgetType or 0)
                hash = AccumulateLockedAreaPOIWidgetHash(hash, widgetInfo.widgetID or 0)
                hash = AccumulateLockedAreaPOIWidgetHash(hash, shownState or 0)
                payloadHash = AccumulateLockedAreaPOIWidgetPayloadHash(payloadHash, widgetInfo)
            end

            return widgetCount, hash, payloadHash
        end
    end

    local function BuildLiveRelevantAreaPOISnapshotPart(questID, mapID, poiID, poiInfo)
        local widgetSetID = poiInfo and poiInfo.tooltipWidgetSet or 0
        local widgetCount, widgetFingerprint, widgetPayloadFingerprint =
            GetLiveLockedAreaPOIWidgetFingerprint(widgetSetID)

        return string_format(
            "%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s",
            tostring(questID or 0),
            tostring(mapID or 0),
            tostring(poiID or 0),
            poiInfo and "1" or "0",
            poiInfo and poiInfo.atlasName or "",
            tostring(widgetSetID or 0),
            tostring(widgetCount),
            tostring(widgetFingerprint),
            tostring(widgetPayloadFingerprint),
            poiInfo and poiInfo.name or "",
            poiInfo and poiInfo.description or "")
    end

    local function SetLiveRelevantAreaPOISnapshotParts(parts, partCount)
        local previousParts = eventFrame._lastLiveRelevantAreaPOISnapshotParts or {}
        local widgetSetIDs = eventFrame._liveRelevantAreaPOIWidgetSetIDs or {}
        local entries = eventFrame._liveRelevantAreaPOISnapshotEntries
        local widgetSetCount = 0

        eventFrame._lastLiveRelevantAreaPOISnapshotParts = previousParts
        eventFrame._lastLiveRelevantAreaPOISnapshotCount = partCount
        eventFrame._liveRelevantAreaPOIWidgetSetIDs = widgetSetIDs

        wipe(widgetSetIDs)

        for index = 1, partCount do
            previousParts[index] = parts[index]
        end

        for index = partCount + 1, #previousParts do
            previousParts[index] = nil
        end

        if entries then
            for index = 1, partCount do
                local entry = entries[index]
                local widgetSetID = entry and entry.areaPOIInfo
                    and entry.areaPOIInfo.tooltipWidgetSet or 0
                if widgetSetID and widgetSetID > 0 and not widgetSetIDs[widgetSetID] then
                    widgetSetIDs[widgetSetID] = true
                    widgetSetCount = widgetSetCount + 1
                end
            end
        end

        eventFrame._liveRelevantAreaPOIWidgetSetCount = widgetSetCount
    end

    local function HasLiveRelevantAreaPOISnapshotDifference(parts, partCount)
        local previousCount = eventFrame._lastLiveRelevantAreaPOISnapshotCount or 0
        local previousParts = eventFrame._lastLiveRelevantAreaPOISnapshotParts

        if partCount ~= previousCount then
            return true
        end

        if not previousParts then
            return false
        end

        for index = 1, partCount do
            if parts[index] ~= previousParts[index] then
                return true
            end
        end

        return false
    end

    local function BuildVisibleLockedAreaPOISnapshot()
        if not currentQuestEntries or #currentQuestEntries == 0 then
            return nil
        end

        local parts = eventFrame._visibleLockedAreaPOISnapshotParts or {}
        local partCount = 0
        eventFrame._visibleLockedAreaPOISnapshotParts = parts

        for _, entry in ipairs(currentQuestEntries) do
            if entry.isAreaPOI and entry.isLocked then
                partCount = partCount + 1

                local poiInfo = nil
                if entry.mapID and entry.poiID and C_AreaPoiInfo
                    and C_AreaPoiInfo.GetAreaPOIInfo
                then
                    poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(entry.mapID, entry.poiID)
                end

                parts[partCount] = BuildVisibleLockedAreaPOISnapshotPart(
                    entry.questID,
                    entry.mapID,
                    entry.poiID,
                    poiInfo,
                    entry.poiName or entry.title,
                    entry.poiDescription,
                    entry.tooltipWidgetSet)
            end
        end

        for index = partCount + 1, #parts do
            parts[index] = nil
        end

        if partCount == 0 then
            return nil
        end

        return table.concat(parts, "\031", 1, partCount)
    end

    local function BuildLiveRelevantAreaPOISnapshot(mapID)
        if not mapID
            or not C_AreaPoiInfo
            or not C_AreaPoiInfo.GetAreaPOIForMap
            or not C_AreaPoiInfo.GetAreaPOIInfo
        then
            return nil, 0
        end

        local queryState = eventFrame:BuildRelevantWorldQuestMapQueryState(mapID)
        local queryMapIDs = queryState and queryState.queryMapIDs or nil
    local mapsToQuery = queryState and queryState.mapsToQuery or nil
    local allowOutsideHierarchy = queryState and queryState.allowOutsideHierarchy or nil
        local parts = eventFrame._liveRelevantAreaPOISnapshotParts or {}
        local entries = eventFrame._liveRelevantAreaPOISnapshotEntries or {}
        local seen = eventFrame._liveRelevantAreaPOISnapshotSeen or {}
        local partCount = 0

        eventFrame._liveRelevantAreaPOISnapshotParts = parts
        eventFrame._liveRelevantAreaPOISnapshotEntries = entries
        eventFrame._liveRelevantAreaPOISnapshotSeen = seen

        for syntheticID in pairs(seen) do
            seen[syntheticID] = nil
        end

        if not queryMapIDs then
            return parts, 0
        end

        for index = 1, #queryMapIDs do
            local queryMapID = queryMapIDs[index]
            local poiIDs = C_AreaPoiInfo.GetAreaPOIForMap(queryMapID)
            if poiIDs then
                for _, poiID in ipairs(poiIDs) do
                    local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(queryMapID, poiID)
                    if eventFrame:IsRelevantLockedAreaPOIInfo(poiInfo)
                        and eventFrame:ShouldAdmitLockedAreaPOIForQuery(
                            mapsToQuery,
                            poiInfo,
                            allowOutsideHierarchy)
                    then
                        local linkedUiMapID = poiInfo and poiInfo.linkedUiMapID or nil
                        local isPrimaryAreaPOI = poiInfo and poiInfo.isPrimaryMapForPOI == true
                            or false
                        local areaPOIOwnerScore = 0
                        if isPrimaryAreaPOI then
                            areaPOIOwnerScore = 3
                        elseif linkedUiMapID and linkedUiMapID > 0 then
                            if linkedUiMapID == queryMapID then
                                areaPOIOwnerScore = 2
                            end
                        else
                            areaPOIOwnerScore = 1
                        end

                        local candidateEntry = {
                            questID = -poiID,
                            mapID = queryMapID,
                            poiID = poiID,
                            areaPOIInfo = poiInfo,
                            linkedUiMapID = linkedUiMapID,
                            isPrimaryAreaPOI = isPrimaryAreaPOI,
                            areaPOIOwnerScore = areaPOIOwnerScore,
                        }
                        local syntheticID = candidateEntry.questID
                        local existingIndex = seen[syntheticID]
                        if existingIndex then
                            local currentEntry = entries[existingIndex]
                            local shouldReplace = not currentEntry
                            if not shouldReplace then
                                local currentScore = currentEntry.areaPOIOwnerScore or 0
                                local candidateScore = candidateEntry.areaPOIOwnerScore or 0
                                if candidateScore ~= currentScore then
                                    shouldReplace = candidateScore > currentScore
                                else
                                    local currentMapID = currentEntry.mapID or 0
                                    local candidateMapID = candidateEntry.mapID or 0
                                    if currentMapID ~= candidateMapID then
                                        local currentIsParent = currentMapID ~= 0
                                            and candidateMapID ~= 0
                                            and GetDescendantMapSet(currentMapID)[candidateMapID]
                                        local candidateIsParent = currentMapID ~= 0
                                            and candidateMapID ~= 0
                                            and GetDescendantMapSet(candidateMapID)[currentMapID]
                                        if currentIsParent ~= candidateIsParent then
                                            shouldReplace = currentIsParent and true or false
                                        else
                                            shouldReplace = candidateMapID > currentMapID
                                        end
                                    end
                                end
                            end

                            if shouldReplace then
                                entries[existingIndex] = candidateEntry
                                parts[existingIndex] = BuildLiveRelevantAreaPOISnapshotPart(
                                    candidateEntry.questID,
                                    candidateEntry.mapID,
                                    candidateEntry.poiID,
                                    candidateEntry.areaPOIInfo)
                            end
                        else
                            partCount = partCount + 1
                            seen[syntheticID] = partCount
                            entries[partCount] = candidateEntry
                            parts[partCount] = BuildLiveRelevantAreaPOISnapshotPart(
                                candidateEntry.questID,
                                candidateEntry.mapID,
                                candidateEntry.poiID,
                                candidateEntry.areaPOIInfo)
                        end
                    end
                end
            end
        end

        for index = partCount + 1, #parts do
            parts[index] = nil
        end

        for index = partCount + 1, #entries do
            entries[index] = nil
        end

        if partCount == 0 then
            return parts, 0
        end

        table_sort(parts)
        return parts, partCount
    end

    function eventFrame:SyncLiveRelevantAreaPOISnapshot(mapID)
        local parts, partCount = BuildLiveRelevantAreaPOISnapshot(mapID)
        SetLiveRelevantAreaPOISnapshotParts(parts or {}, partCount or 0)
    end

    function eventFrame:HasLiveRelevantAreaPOIStateChange(mapID)
        local parts, partCount = BuildLiveRelevantAreaPOISnapshot(mapID)
        parts = parts or {}
        partCount = partCount or 0

        if HasLiveRelevantAreaPOISnapshotDifference(parts, partCount) then
            SetLiveRelevantAreaPOISnapshotParts(parts, partCount)
            return true
        end

        return false
    end

    function eventFrame:SyncVisibleLockedAreaPOISnapshot()
        self._visibleLockedAreaPOISnapshot = BuildVisibleLockedAreaPOISnapshot()
    end

    function eventFrame:HasVisibleLockedAreaPOIStateChange()
        local snapshot = BuildVisibleLockedAreaPOISnapshot()
        if snapshot ~= self._visibleLockedAreaPOISnapshot then
            self._visibleLockedAreaPOISnapshot = snapshot
            return true
        end

        return false
    end
end

function ns.HasVisibleQuestRemoval()
    if not ns.IsWorldQuestsRefreshContextActive()
        or not currentQuestEntries
        or #currentQuestEntries == 0
        or not C_TaskQuest
        or not C_TaskQuest.IsActive
    then
        return false
    end

    for _, entry in ipairs(currentQuestEntries) do
        local questID = entry.questID
        if questID and questID > 0
            and not entry.isLocked
            and not entry.isAreaPOI
            and not C_TaskQuest.IsActive(questID)
        then
            return true
        end
    end

    return false
end

-- Applies quest data to a row frame.
-- row: Frame from AcquireQuestRow()
-- entry: enriched quest entry from GatherQuestsForCurrentMap()
local function PopulateQuestRow(row, entry, animate)
    local questID = entry.questID
    local rewardTopOffset = -37
    row.questID = questID
    row.questEntry = entry
    row.isAreaPOI = entry.isAreaPOI == true
    row.poiTitle = entry.isAreaPOI and (entry.title or entry.poiName) or nil
    row.poiUnlockText = entry.isAreaPOI and entry.unlockText or nil
    ApplyQuestRowLayout(row, entry)

    UpdateQuestRowTimeDisplay(row, entry)

    -- Title; super-tracked overrides locked styling everywhere.
    -- If title is nil (data not loaded yet), show a grey "Loading..." placeholder.
    local superTrackedID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID() or nil
    local displayTitle = entry.title
    if displayTitle and displayTitle ~= "" then
        ApplyQuestRowTitleColor(row.titleText, questID, entry.isLocked, false)
        row.titleText:SetText(displayTitle)
    elseif entry.isLocked then
        ApplyQuestRowTitleColor(row.titleText, questID, true, false)
        row.titleText:SetText(QUEST_TYPE_LABEL.special_assignment)
    else
        ApplyQuestRowTitleColor(row.titleText, questID, false, true)
        row.titleText:SetText("Loading\226\128\166")
    end

    -- POI button: sync quest ID and tracking-state visual.
    -- Always use WorldQuest style; POIButtonUtil.Style.SuperTracked does not
    -- exist in 12.0 and would be nil, which causes POIButton_UpdateNormalStyle
    -- to skip the WorldQuest branch and never re-set questTagInfo — leaving
    -- elite/boss POI dragon borders permanently hidden after a tracking change.
    local isSuperTracked = superTrackedID and (superTrackedID == questID)
    if entry.isAreaPOI then
        row.poiBtn.questID = nil
        row.poiBtn.areaPoiID = entry.poiID
        if POIButtonUtil and row.poiBtn.SetStyle then
            row.poiBtn:SetStyle(POIButtonUtil.Style.AreaPOI)
        end
        if row.poiBtn.SetAreaPOIInfo and entry.areaPOIInfo then
            row.poiBtn:SetAreaPOIInfo(entry.areaPOIInfo)
        end
        if row.poiBtn.nomtoolsAreaPOIIcon then
            local atlas = entry.areaPOIInfo and entry.areaPOIInfo.atlasName
            if atlas and row.poiBtn.nomtoolsAreaPOIIcon.SetAtlas then
                row.poiBtn.nomtoolsAreaPOIIcon:SetAtlas(atlas, true)
                row.poiBtn.nomtoolsAreaPOIIcon:Show()
            else
                row.poiBtn.nomtoolsAreaPOIIcon:Hide()
            end
        end
        do
            local trackedType, trackedID
            if C_SuperTrack and C_SuperTrack.GetSuperTrackedMapPin then
                trackedType, trackedID = C_SuperTrack.GetSuperTrackedMapPin()
            end
            local mapPinType = Enum and Enum.SuperTrackingMapPinType
                and Enum.SuperTrackingMapPinType.AreaPOI or 0
            local isTrackedPOI = trackedType == mapPinType and trackedID == entry.poiID
            if row.poiBtn.SetSelected then
                row.poiBtn:SetSelected(isTrackedPOI and true or false)
            end
            if row.poiBtn.UpdateSelected then
                row.poiBtn:UpdateSelected()
            end
        end
        if row.poiBtn.UpdateButtonStyle then
            row.poiBtn:UpdateButtonStyle()
        end
        if row.poiBtn.Display and row.poiBtn.Display.SetIconShown then
            row.poiBtn.Display:SetIconShown(false)
        elseif row.poiBtn.Display and row.poiBtn.Display.Icon then
            row.poiBtn.Display.Icon:SetAlpha(0)
        end
        if row.poiBtn.Display and row.poiBtn.Display.SubTypeIcon then
            row.poiBtn.Display.SubTypeIcon:Hide()
        end
        row.poiBtn:Show()
    else
        ClearPOIButtonAreaPOIState(row.poiBtn)
        if row.poiBtn.SetQuestID then
            row.poiBtn:SetQuestID(questID)
        end
        row.poiBtn.questID = questID
        row.poiBtn.areaPoiID = nil
        if POIButtonUtil and row.poiBtn.SetStyle then
            row.poiBtn:SetStyle(POIButtonUtil.Style.WorldQuest)
            row.poiBtn:SetSelected(isSuperTracked and true or false)
            if row.poiBtn.UpdateButtonStyle then row.poiBtn:UpdateButtonStyle() end
        end
        if row.poiBtn.Display and row.poiBtn.Display.SetIconShown then
            row.poiBtn.Display:SetIconShown(true)
        elseif row.poiBtn.Display and row.poiBtn.Display.Icon then
            row.poiBtn.Display.Icon:SetAlpha(1)
        end
        if row.poiBtn.nomtoolsAreaPOIIcon then
            row.poiBtn.nomtoolsAreaPOIIcon:Hide()
        end
        row.poiBtn:Show()
    end

    row.contractBtn.auraInstanceID = nil
    row.contractBtn.spellID = nil
    row.contractBtn:Hide()
    ResetQuestRowRewards(row)

    if entry.isLocked then
        local lockedText = entry.unlockText
        if not lockedText and not entry.isAreaPOI then
            lockedText = GetLockedSpecialAssignmentUnlockText(questID)
        end
        row.factionText:SetText("Locked: " .. (lockedText or "Unlock requirements not available yet."))
        row.factionText:SetTextColor(
            COL.rowLockedRequirement[1],
            COL.rowLockedRequirement[2],
            COL.rowLockedRequirement[3])
        row.factionText:Show()
        if entry.isAreaPOI and entry.areaPOIRewards and #entry.areaPOIRewards > 0 then
            local goldReward = nil
            local nonGoldIdx = 0
            for _, rewardData in ipairs(entry.areaPOIRewards) do
                if rewardData.rewardType == "gold" then
                    goldReward = rewardData
                else
                    nonGoldIdx = nonGoldIdx + 1
                    if nonGoldIdx <= MAX_REWARD_ICONS then
                        local btn = row.rewardIcons[nonGoldIdx]
                        btn.iconTex:SetTexture(rewardData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                        btn.rewardType = rewardData.rewardType
                        btn.amount = rewardData.amount
                        btn.itemID = rewardData.itemID
                        btn.currencyID = rewardData.currencyID
                        btn.factionID = rewardData.factionID
                        btn.currencyLabel = rewardData.currencyLabel
                        btn.label = rewardData.label
                        btn.ilvl = rewardData.ilvl
                        btn.quality = rewardData.quality
                        btn.questRewardType = rewardData.questRewardType
                        btn.questID = nil
                        btn.rewardIndex = rewardData.rewardIndex
                        if btn.SetID then
                            btn:SetID(rewardData.rewardIndex or 0)
                        end
                        if rewardData.rewardType == "item" then
                            if ns._WorldQuestsShouldShowRewardItemLevel(rewardData) then
                                btn.countText:SetText(rewardData.ilvl)
                                btn.countText:SetTextColor(1, 1, 1)
                            elseif rewardData.amount and rewardData.amount > 1 then
                                btn.countText:SetText(rewardData.amount)
                                btn.countText:SetTextColor(1, 1, 1)
                            else
                                btn.countText:SetText("")
                            end
                        elseif rewardData.rewardType == "currency" then
                            local displayAmount = ns.FormatCompactRewardAmount(rewardData.amount)
                            if displayAmount then
                                btn.countText:SetText(displayAmount)
                                btn.countText:SetTextColor(1, 1, 1)
                            else
                                btn.countText:SetText("")
                            end
                        elseif rewardData.rewardType == "rep" then
                            local displayAmount = ns.FormatCompactRewardAmount(rewardData.amount)
                            if displayAmount then
                                btn.countText:SetText(displayAmount)
                                btn.countText:SetTextColor(0.4, 0.8, 1)
                            else
                                btn.countText:SetText("")
                            end
                        else
                            btn.countText:SetText("")
                        end
                        btn:Show()
                        if btn.quality and ITEM_QUALITY_COLORS
                            and ITEM_QUALITY_COLORS[btn.quality]
                        then
                            local qc = ITEM_QUALITY_COLORS[btn.quality]
                            btn.borderTop:SetColorTexture(qc.r, qc.g, qc.b, 1)
                            btn.borderBottom:SetColorTexture(qc.r, qc.g, qc.b, 1)
                            btn.borderLeft:SetColorTexture(qc.r, qc.g, qc.b, 1)
                            btn.borderRight:SetColorTexture(qc.r, qc.g, qc.b, 1)
                            btn.borderTop:Show()
                            btn.borderBottom:Show()
                            btn.borderLeft:Show()
                            btn.borderRight:Show()
                        end
                    end
                end
            end
            if goldReward then
                row.moneyText:ClearAllPoints()
                if nonGoldIdx == 0 then
                    row.moneyText:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -37)
                    row.moneyText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -20, -37)
                else
                    local lastBtn = row.rewardIcons[math.min(nonGoldIdx, MAX_REWARD_ICONS)]
                    row.moneyText:SetPoint("LEFT", lastBtn, "RIGHT", 6, 0)
                end
                row.moneyText:SetText(goldReward.label or "")
                row.moneyText:SetTextColor(1, 1, 1)
                row.moneyText:Show()
            else
                row.moneyText:SetText("")
                row.moneyText:Hide()
            end
        elseif entry.isAreaPOI and entry.rewardText and entry.rewardText ~= "" then
            row.moneyText:ClearAllPoints()
            row.moneyText:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -37)
            row.moneyText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -20, -37)
            if row.moneyText.SetWordWrap then
                row.moneyText:SetWordWrap(false)
            end
            if row.moneyText.SetMaxLines then
                row.moneyText:SetMaxLines(1)
            end
            row.moneyText:SetText(entry.rewardText)
            row.moneyText:SetTextColor(1, 1, 1)
            row.moneyText:Show()
        else
            row.moneyText:SetText("")
            row.moneyText:Hide()
        end
    else
        -- Faction / tag line — prefer a fresh query so the row mirrors Blizzard's
        -- current task-quest faction label, including active-contract overrides.
        local faction = GetQuestFactionLabel(questID) or entry.faction
        if faction and faction ~= "" then
            row.factionText:SetText(faction)
            local factionColor = COL.rowFaction
            local hasActiveContract = DoesFactionMatchContract(currentRelevantContract, faction)
            if hasActiveContract then
                factionColor = COL.rowFactionActiveContract
            end
            row.factionText:SetTextColor(
                factionColor[1], factionColor[2], factionColor[3])
            row.factionText:Show()

            if hasActiveContract then
                local textWidth = row.factionText.GetUnboundedStringWidth
                    and row.factionText:GetUnboundedStringWidth()
                    or row.factionText:GetStringWidth()
                    or 0
                local maxOffset = math.max(0, row:GetWidth() - 54)
                row.contractBtn:ClearAllPoints()
                row.contractBtn:SetPoint(
                    "LEFT", row.factionText, "LEFT", math.min(textWidth + 4, maxOffset), 0)
                row.contractBtn.auraInstanceID = currentRelevantContract.auraInstanceID
                row.contractBtn.spellID = currentRelevantContract.spellID
                row.contractBtn:Show()
            end
        else
            row.factionText:SetText("")
            row.factionText:SetTextColor(
                COL.rowFaction[1], COL.rowFaction[2], COL.rowFaction[3])
            row.factionText:Hide()
            rewardTopOffset = -23
        end
    end

    if row.rewardIcons and row.rewardIcons[1] then
        row.rewardIcons[1]:ClearAllPoints()
        row.rewardIcons[1]:SetPoint("TOPLEFT", row, "TOPLEFT", 36, rewardTopOffset)
    end

    -- Rewards with amount overlays.
    -- Gold is separated out and shown as a text label (moneyText) so the full
    -- denomination fits.  All other reward types fill the icon slots.
    if not entry.isLocked then
        if not rewardPreloadState.IsQuestRewardDisplayReady(entry) then
            rewardPreloadState.QueueQuestRewardPreload(questID, animate == true)
            row.moneyText:ClearAllPoints()
            row.moneyText:SetPoint("TOPLEFT", row, "TOPLEFT", 36, rewardTopOffset)
            row.moneyText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -20, rewardTopOffset)
            if row.moneyText.SetWordWrap then
                row.moneyText:SetWordWrap(false)
            end
            if row.moneyText.SetMaxLines then
                row.moneyText:SetMaxLines(1)
            end
            row.moneyText:SetText(RETRIEVING_DATA or "Loading rewards...")
            row.moneyText:SetTextColor(COL.rowTime[1], COL.rowTime[2], COL.rowTime[3])
            row.moneyText:Show()
        else
            local rewards = GetQuestRewards(questID)
            local goldReward = nil
            local nonGoldIdx = 0
            for _, rewardData in ipairs(rewards) do
                if rewardData.rewardType == "gold" then
                    goldReward = rewardData
                else
                    nonGoldIdx = nonGoldIdx + 1
                    if nonGoldIdx <= MAX_REWARD_ICONS then
                        local btn = row.rewardIcons[nonGoldIdx]
                        btn.iconTex:SetTexture(rewardData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                        btn.rewardType = rewardData.rewardType
                        btn.amount = rewardData.amount
                        btn.itemID = rewardData.itemID
                        btn.currencyID = rewardData.currencyID
                        btn.factionID = rewardData.factionID
                        btn.currencyLabel = rewardData.currencyLabel
                        btn.label = rewardData.label
                        btn.ilvl = rewardData.ilvl
                        btn.quality = rewardData.quality
                        btn.questRewardType = rewardData.questRewardType
                        btn.questID = questID
                        btn.rewardIndex = rewardData.rewardIndex
                        if btn.SetID then
                            btn:SetID(rewardData.rewardIndex or 0)
                        end
                        if rewardData.rewardType == "item" then
                            if ns._WorldQuestsShouldShowRewardItemLevel(rewardData) then
                                btn.countText:SetText(rewardData.ilvl)
                                btn.countText:SetTextColor(1, 1, 1)
                            elseif rewardData.amount and rewardData.amount > 1 then
                                btn.countText:SetText(rewardData.amount)
                                btn.countText:SetTextColor(1, 1, 1)
                            else
                                btn.countText:SetText("")
                            end
                        elseif rewardData.rewardType == "currency" then
                            local displayAmount = ns.FormatCompactRewardAmount(rewardData.amount)
                            if displayAmount then
                                btn.countText:SetText(displayAmount)
                                btn.countText:SetTextColor(1, 1, 1)
                            else
                                btn.countText:SetText("")
                            end
                        elseif rewardData.rewardType == "rep" then
                            local displayAmount = ns.FormatCompactRewardAmount(rewardData.amount)
                            if displayAmount then
                                btn.countText:SetText(displayAmount)
                                btn.countText:SetTextColor(0.4, 0.8, 1)
                            else
                                btn.countText:SetText("")
                            end
                        else
                            btn.countText:SetText("")
                        end
                        btn:Show()
                        if btn.quality and ITEM_QUALITY_COLORS
                            and ITEM_QUALITY_COLORS[btn.quality]
                        then
                            local qc = ITEM_QUALITY_COLORS[btn.quality]
                            btn.borderTop:SetColorTexture(qc.r, qc.g, qc.b, 1)
                            btn.borderBottom:SetColorTexture(qc.r, qc.g, qc.b, 1)
                            btn.borderLeft:SetColorTexture(qc.r, qc.g, qc.b, 1)
                            btn.borderRight:SetColorTexture(qc.r, qc.g, qc.b, 1)
                            btn.borderTop:Show()
                            btn.borderBottom:Show()
                            btn.borderLeft:Show()
                            btn.borderRight:Show()
                        end
                    end
                end
            end

            if goldReward then
                row.moneyText:ClearAllPoints()
                if nonGoldIdx == 0 then
                    row.moneyText:SetPoint("TOPLEFT", row, "TOPLEFT", 36, rewardTopOffset)
                else
                    local lastBtn = row.rewardIcons[math.min(nonGoldIdx, MAX_REWARD_ICONS)]
                    row.moneyText:SetPoint("LEFT", lastBtn, "RIGHT", 6, 0)
                end
                row.moneyText:SetText(goldReward.label or "")
                row.moneyText:SetTextColor(1, 1, 1)
                row.moneyText:Show()
            else
                row.moneyText:SetText("")
                row.moneyText:Hide()
            end
        end
    end

    -- Show the row now that all content is applied (suppresses blank-row flash).
    if animate == true then
        if row.fadeIn then
            row.fadeIn:Stop()
        end
        row:SetAlpha(0)
        row:Show()
        if row.fadeIn then
            row.fadeIn:Play()
        else
            row:SetAlpha(1)
        end
    elseif animate == false then
        row:SetAlpha(1)
        row:Show()
    end

    if activeHoverState.questID and row.questID == activeHoverState.questID then
        DebugHoverTrace(
            "RowShow",
            "phase=populate questID=%s animate=%s row=%s",
            tostring(row.questID),
            tostring(animate),
            GetHoverRowIdentity(row))
    end

    if activeHoverState.questID == questID then
        activeHoverState.ResumeForShownRow(row, "populate")
    end

    -- When animate is nil: data populated, visibility unchanged (deferred reveal).
end

-- =============================================
-- Panel layout
-- =============================================

-- Clears all active content rows and headers back to pools.
local function ClearActiveContent()
    local activeRowCount = 0
    local activeZoneCount = 0
    for _, item in ipairs(activeContent) do
        if item.type == "row" then
            activeRowCount = activeRowCount + 1
        elseif item.type == "zone" then
            activeZoneCount = activeZoneCount + 1
        end
    end
    if #activeContent > 0 then
        DebugHoverTrace(
            "ClearActiveContent",
            "items=%s rows=%s zones=%s hoverQuestID=%s",
            tostring(#activeContent),
            tostring(activeRowCount),
            tostring(activeZoneCount),
            tostring(activeHoverState.questID))
    end

    if #activeContent > 0 and activeTooltipAnchor then
        ClearActiveQuestTooltip()
    end
    for _, item in ipairs(activeContent) do
        if item.type == "row" and item.frame then
            ReleaseQuestRow(item.frame, true)
        elseif item.type == "zone" then
            ReleaseZoneHeader(item.frame)
        end
    end
    wipe(activeContent)
end

function eventFrame:InvalidateActiveWorldQuestsLayout()
    layoutGeneration = layoutGeneration + 1
    ClearActiveContent()
    currentQuestEntries = {}
    wipe(eventFrame._currentQuestEntriesByID)
    if noQuestsLabel then
        noQuestsLabel:Hide()
    end
    if scrollChild then
        scrollChild:SetHeight(60)
    end
    if scrollFrame and scrollFrame.UpdateScrollChildRect then
        scrollFrame:UpdateScrollChildRect()
    end
end

-- Rebuilds the scroll child contents from the provided quest list.
-- quests: array of enriched entries from GatherQuestsForCurrentMap()
local function LayoutScrollContent(quests, animateRows)
    -- Bump generation so any in-flight batch from a previous layout self-cancels.
    layoutGeneration = layoutGeneration + 1
    local myGen = layoutGeneration

    local clearStart = debugprofilestop()
    ClearActiveContent()
    local clearElapsed = debugprofilestop() - clearStart

    -- Derive content width from the scroll frame; fall back if not sized yet.
    local contentWidth = scrollFrame and scrollFrame:GetWidth() or 220
    if contentWidth < 60 then contentWidth = 220 end

    if not quests or #quests == 0 then
        if noQuestsLabel then
            local mapID = WorldMapFrame and WorldMapFrame.mapID or nil
            if eventFrame:IsWorldQuestDescendantGatherPending(mapID) then
                noQuestsLabel:SetText(RETRIEVING_DATA or "Loading world quests...")
            else
                noQuestsLabel:SetText("No active world quests in this zone.")
            end
        end
        noQuestsLabel:Show()
        scrollChild:SetHeight(60)
        return
    end
    noQuestsLabel:SetText("No active world quests in this zone.")
    noQuestsLabel:Hide()

    local zoneGroupsStart = debugprofilestop()
    local zoneGroups = BuildSortedZoneGroups(quests)
    local zoneGroupsElapsed = debugprofilestop() - zoneGroupsStart
    local isMultiZone = #zoneGroups > 1
    local pendingRowItems = {}

    -- ── Phase 1: acquire frames and set positions (synchronous, fast) ────────
    -- No heavy WoW API calls here — the scroll skeleton (zone headers + row
    -- placeholders) appears instantly in the same frame as the layout command.
    -- Per-quest data (reward icons, text, POI styling) fills in via Phase 2.
    -- Compute viewport bounds BEFORE Phase 1 for lazy frame creation.
    local scrollOffset
    if animateRows then
        scrollOffset = 0
    else
        scrollOffset = scrollFrame and scrollFrame:GetVerticalScroll() or 0
    end
    local viewportHeight = scrollFrame and scrollFrame:GetHeight() or 420
    if viewportHeight < 1 then viewportHeight = 420 end
    local viewportBottom = scrollOffset + viewportHeight

    local skeletonStart = debugprofilestop()
    local currentY = 8
    for _, zoneGroup in ipairs(zoneGroups) do
        local zoneName = zoneGroup.name
        local zoneEntries = zoneGroup.quests
        local isZoneCollapsed = false

        if isMultiZone then
            isZoneCollapsed = collapseState[zoneName] or false

            local hdr = AcquireZoneHeader(scrollChild)
            hdr:SetWidth(contentWidth - 15)
            hdr:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 9, -currentY)
            hdr.label:SetText(zoneName)
            hdr.countLabel:SetText(#zoneEntries .. " quest"
                .. (#zoneEntries ~= 1 and "s" or ""))
            hdr.zoneName = zoneName
            hdr:SetCollapsed(isZoneCollapsed)
            currentY = currentY + ZONE_HEADER_HEIGHT
            activeContent[#activeContent + 1] = { type = "zone", frame = hdr }
        end

        if not isMultiZone or not isZoneCollapsed then
            for _, entry in ipairs(zoneEntries) do
                local rowHeight = GetQuestRowHeight(entry)
                local rowTop = currentY
                local rowBottom = currentY + rowHeight
                local isInViewport = rowTop < viewportBottom and rowBottom > scrollOffset

                local row = nil
                if isInViewport then
                    row = AcquireQuestRow(scrollChild)
                    row:SetWidth(contentWidth)
                    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -currentY)
                    row:SetHeight(rowHeight)
                    row.questID = entry.questID
                    row.mapID   = entry.mapID
                    row.mapName = entry.mapName
                end

                local rowItem = {
                    type = "row", frame = row, _entry = entry, _animate = animateRows == true,
                    _top = currentY, _bottom = currentY + rowHeight,
                    _height = rowHeight, _contentWidth = contentWidth }
                activeContent[#activeContent + 1] = rowItem
                pendingRowItems[#pendingRowItems + 1] = rowItem
                currentY = currentY + rowHeight
            end
        end
    end
    local skeletonElapsed = debugprofilestop() - skeletonStart

    if ns.IsDebugEnabled() then
        ns.DebugPrint(string_format(
            "WorldQuests: Phase1 clear=%.1fms zoneGroups=%.1fms skeleton=%.1fms rows=%d",
            clearElapsed / 1000, zoneGroupsElapsed / 1000, skeletonElapsed / 1000, #pendingRowItems))
    end

    scrollChild:SetHeight(math.max(currentY + 4, 60))
    if scrollFrame and scrollFrame.UpdateScrollChildRect then
        scrollFrame:UpdateScrollChildRect()
    end

    -- Reset scroll to the top when displaying new content (map change).
    if animateRows and scrollFrame then
        scrollFrame:SetVerticalScroll(0)
        if scrollFrame.ScrollBar and scrollFrame.ScrollBar.SetScrollPercentage then
            scrollFrame.ScrollBar:SetScrollPercentage(0)
        end
    end

    if ns.IsDebugEnabled() and scrollFrame then
        ns.DebugPrint(string_format(
            "WorldQuests: LayoutScrollContent pre-split scrollPos=%.0f frameH=%.0f contentH=%.0f rows=%d",
            scrollFrame:GetVerticalScroll(),
            scrollFrame:GetHeight(),
            scrollChild:GetHeight(),
            #pendingRowItems))
    end

    -- ── Viewport split: prioritize visible rows ──────────────────────────────
    local visibleRowItems = {}
    local deferredRowItems = {}

    for _, item in ipairs(pendingRowItems) do
        if item._top < viewportBottom and item._bottom > scrollOffset then
            visibleRowItems[#visibleRowItems + 1] = item
        else
            deferredRowItems[#deferredRowItems + 1] = item
        end
    end

    if ns.IsDebugEnabled() then
        ns.DebugPrint(string_format(
            "WorldQuests: LayoutScrollContent total=%d visible=%d deferred=%d scrollOffset=%.0f viewportH=%.0f viewportBottom=%.0f animate=%s",
            #pendingRowItems, #visibleRowItems, #deferredRowItems,
            scrollOffset, viewportHeight, viewportBottom,
            tostring(animateRows)))
        if #visibleRowItems > 0 then
            local firstVis = visibleRowItems[1]
            local lastVis = visibleRowItems[#visibleRowItems]
            ns.DebugPrint(string_format(
                "WorldQuests:   visible range: top=%.0f..%.0f  questIDs: first=%s last=%s",
                firstVis._top, lastVis._bottom,
                tostring(firstVis.frame.questID), tostring(lastVis.frame.questID)))
        end
        if #deferredRowItems > 0 then
            local firstDef = deferredRowItems[1]
            local lastDef = deferredRowItems[#deferredRowItems]
            ns.DebugPrint(string_format(
                "WorldQuests:   deferred range: top=%.0f..%.0f  count=%d",
                firstDef._top, lastDef._bottom, #deferredRowItems))
        end
    end

    if eventFrame._hoverLastLayoutGenLogged ~= myGen then
        eventFrame._hoverLastLayoutGenLogged = myGen
        DebugHoverTrace(
            "LayoutSummary",
            "gen=%s reason=%s questCount=%s visible=%s deferred=%s animateRows=%s activeHoverQuestID=%s",
            tostring(myGen),
            tostring(eventFrame._lastLayoutReason or "unspecified"),
            tostring(quests and #quests or 0),
            tostring(#visibleRowItems),
            tostring(#deferredRowItems),
            tostring(animateRows == true),
            tostring(activeHoverState.questID))
    end

    -- ── Phase 2: populate visible rows only ──────────────────────────────────
    do
        local debugprofilestop = debugprofilestop
        local POPULATE_BUDGET_MS = 6

        local visIdx = 1
        local function populateVisibleBatch()
            if layoutGeneration ~= myGen then return end
            local budgetStart = debugprofilestop()
            while visIdx <= #visibleRowItems do
                local item = visibleRowItems[visIdx]
                if item._entry ~= nil then
                    PopulateQuestRow(item.frame, item._entry, nil)
                    item._entry = nil
                end
                visIdx = visIdx + 1
                if debugprofilestop() - budgetStart > POPULATE_BUDGET_MS * 1000 then
                    return false
                end
            end
            return true
        end

        local p2Start = debugprofilestop()
        local allVisibleDone = populateVisibleBatch()
        local p2Elapsed = debugprofilestop() - p2Start
        if ns.IsDebugEnabled() then
            ns.DebugPrint(string_format(
                "WorldQuests: Phase2 sync elapsed=%.1fms rows=%d allDone=%s",
                p2Elapsed / 1000, #visibleRowItems, tostring(allVisibleDone)))
        end
        if not allVisibleDone then
            local function continueVisible()
                if layoutGeneration ~= myGen then return end
                local done = populateVisibleBatch()
                if not done then
                    C_Timer.After(0.01, continueVisible)
                end
            end
            C_Timer.After(0.01, continueVisible)
        end
    end

    -- ── On-scroll: populate deferred rows entering the viewport on demand ────
    scrollFrame._nomtoolsOnScroll = function()
        if layoutGeneration ~= myGen then
            scrollFrame._nomtoolsOnScroll = nil
            return
        end
        local scrollOff = scrollFrame:GetVerticalScroll()
        local viewH = scrollFrame:GetHeight()
        if viewH < 1 then return end
        local viewBot = scrollOff + viewH
        for i = 1, #pendingRowItems do
            local item = pendingRowItems[i]
            if item._entry ~= nil and item._top < viewBot and item._bottom > scrollOff then
                if not item.frame then
                    local row = AcquireQuestRow(scrollChild)
                    row:SetWidth(item._contentWidth)
                    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -item._top)
                    row:SetHeight(item._height)
                    row.questID = item._entry.questID
                    row.mapID = item._entry.mapID
                    row.mapName = item._entry.mapName
                    item.frame = row
                end
                PopulateQuestRow(item.frame, item._entry, false)
                item._entry = nil
                if ns.IsDebugEnabled() then
                    ns.DebugPrint(string_format(
                        "WorldQuests: OnScroll populate questID=%s top=%.0f",
                        tostring(item.frame.questID), item._top))
                end
            end
        end
    end

    if not scrollFrame._nomtoolsScrollHooked then
        scrollFrame:HookScript("OnVerticalScroll", function()
            if scrollFrame._nomtoolsOnScroll then scrollFrame._nomtoolsOnScroll() end
        end)
        scrollFrame._nomtoolsScrollHooked = true
    end

    -- ── Idle pre-populate: very slowly process off-screen rows ───────────────
    local idleIdx = 1
    local IDLE_INTERVAL = 0.05
    local IDLE_BATCH = 8

    local function idlePopulate()
        if layoutGeneration ~= myGen then return end
        local processed = 0
        while idleIdx <= #deferredRowItems and processed < IDLE_BATCH do
            local item = deferredRowItems[idleIdx]
            if item._entry ~= nil then
                if not item.frame then
                    local row = AcquireQuestRow(scrollChild)
                    row:SetWidth(item._contentWidth)
                    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -item._top)
                    row:SetHeight(item._height)
                    row.questID = item._entry.questID
                    row.mapID = item._entry.mapID
                    row.mapName = item._entry.mapName
                    item.frame = row
                end
                PopulateQuestRow(item.frame, item._entry, false)
                item._entry = nil
                if ns.IsDebugEnabled() then
                    ns.DebugPrint(string_format(
                        "WorldQuests: Idle populate questID=%s idx=%d",
                        tostring(item.frame.questID), idleIdx))
                end
                processed = processed + 1
            end
            idleIdx = idleIdx + 1
        end
        if idleIdx <= #deferredRowItems then
            C_Timer.After(IDLE_INTERVAL, idlePopulate)
        end
    end

    -- ── Phase 3: reveal visible rows only ────────────────────────────────────
    if animateRows then
        local ROW_REVEAL_INTERVAL = 0.025
        local populateRetryCount = 0

        local function PrimeRevealPreload(item)
            local row = item and item.frame or nil
            if row and row.questID then
                rewardPreloadState.QueueQuestRewardPreload(row.questID, true)
            end
        end

        local visRevealIdx = 1
        local function revealNextVisibleRow()
            if layoutGeneration ~= myGen or not ns.IsWorldQuestsRefreshContextActive() then
                return
            end

            if visRevealIdx > #visibleRowItems then
                -- All visible rows revealed; start idle pre-populate for off-screen
                if #deferredRowItems > 0 then
                    C_Timer.After(IDLE_INTERVAL, idlePopulate)
                end
                return
            end

            local item = visibleRowItems[visRevealIdx]

            if item._entry ~= nil then
                populateRetryCount = populateRetryCount + 1
                if populateRetryCount > 100 then
                    if #deferredRowItems > 0 then
                        C_Timer.After(IDLE_INTERVAL, idlePopulate)
                    end
                    return
                end
                C_Timer.After(0.01, revealNextVisibleRow)
                return
            end
            populateRetryCount = 0

            local row = item.frame
            if row.fadeIn then row.fadeIn:Stop() end
            row:SetAlpha(0)
            row:Show()
            if row.fadeIn then
                row.fadeIn:Play()
            else
                row:SetAlpha(1)
            end
            if activeHoverState.questID and row.questID == activeHoverState.questID then
                DebugHoverTrace(
                    "RowShow",
                    "phase=reveal-visible questID=%s row=%s",
                    tostring(row.questID),
                    GetHoverRowIdentity(row))
            end
            activeHoverState.ResumeForShownRow(row, "reveal-visible")

            visRevealIdx = visRevealIdx + 1

            if visRevealIdx <= #visibleRowItems then
                PrimeRevealPreload(visibleRowItems[visRevealIdx])
                C_Timer.After(ROW_REVEAL_INTERVAL, revealNextVisibleRow)
            else
                -- All visible revealed; start idle pre-populate
                if #deferredRowItems > 0 then
                    C_Timer.After(IDLE_INTERVAL, idlePopulate)
                end
            end
        end

        if visibleRowItems[1] then
            PrimeRevealPreload(visibleRowItems[1])
            revealNextVisibleRow()
        elseif #deferredRowItems > 0 then
            C_Timer.After(IDLE_INTERVAL, idlePopulate)
        end
    else
        -- Non-animated: show visible rows immediately, idle pre-populate deferred
        local readyWaitCount = 0
        local function showReadyRows()
            if layoutGeneration ~= myGen then return end
            local allShown = true
            for _, item in ipairs(visibleRowItems) do
                if item._entry == nil then
                    local row = item.frame
                    if row:GetAlpha() ~= 1 or not row:IsShown() then
                        row:SetAlpha(1)
                        row:Show()
                    end
                    if activeHoverState.questID and row.questID == activeHoverState.questID then
                        DebugHoverTrace(
                            "RowShow",
                            "phase=show-ready questID=%s row=%s",
                            tostring(row.questID),
                            GetHoverRowIdentity(row))
                    end
                    activeHoverState.ResumeForShownRow(row, "show-ready")
                else
                    allShown = false
                end
            end
            if not allShown then
                readyWaitCount = readyWaitCount + 1
                if readyWaitCount > 100 then return end
                C_Timer.After(0.01, showReadyRows)
            else
                -- All visible shown; start idle pre-populate
                if #deferredRowItems > 0 then
                    C_Timer.After(IDLE_INTERVAL, idlePopulate)
                end
            end
        end
        showReadyRows()
    end
end

-- =============================================
-- Panel refresh
-- =============================================

-- Refreshes the panel contents from the current map.
local function RefreshPanel(animateRows, reason)
    if not ns.IsWorldQuestsRefreshContextActive() then return end

    local s = GetSettings()
    if not IsModuleEnabled(s) then
        eventFrame:ResetWorldQuestsRefreshGateState()
        ClearPendingDisplayModeRequest()
        return
    end

    local mapID = WorldMapFrame and WorldMapFrame.mapID or nil
    local previousRelevantWorldQuestMapID = eventFrame._activeRelevantWorldQuestMapID
    local previousRelevantWorldQuestQuerySignature =
        eventFrame._activeRelevantWorldQuestQuerySignature
    local gatherStart = debugprofilestop()
    local quests, hiddenRewardPreloadQuestIDs, querySignature =
        eventFrame:GatherQuestsForCurrentMap(animateRows)
    local gatherElapsed = debugprofilestop() - gatherStart
    local isDescendantGatherPending = eventFrame:IsWorldQuestDescendantGatherPending(mapID)
    local activeRelevantWorldQuestQuerySignature = querySignature
        or (mapID and tostring(mapID) or nil)
    local relevantWorldQuestQuerySignatureChanged =
        previousRelevantWorldQuestMapID ~= mapID
        or previousRelevantWorldQuestQuerySignature ~= activeRelevantWorldQuestQuerySignature

    eventFrame._lastScheduledWorldQuestsMapID = mapID
    eventFrame._activeRelevantWorldQuestMapID = mapID
    eventFrame._activeRelevantWorldQuestQuerySignature =
        activeRelevantWorldQuestQuerySignature
    currentQuestEntries = quests
    wipe(eventFrame._currentQuestEntriesByID)
    for entryIndex = 1, #quests do
        local entry = quests[entryIndex]
        if entry.questID then
            eventFrame._currentQuestEntriesByID[entry.questID] = entry
        end
    end
    rewardPreloadState.CancelDrain()
    wipe(rewardPreloadState.queuedQuestIDs)
    wipe(rewardPreloadState.queue)
    rewardPreloadState.queueHead = 1
    rewardPreloadState.queueTail = 0
    if quests and #quests > 0 then
        for _, entry in ipairs(quests) do
            if entry and not entry.isLocked and entry.isAreaPOI ~= true
                and entry.rewardDataReady == false
            then
                local questID = entry.questID
                if not pendingQuestIDs[questID] then
                    pendingQuestIDs[questID] = {
                        needsQuestData = false,
                        needsRewardData = true,
                        questDataRefreshDone = true,
                    }
                elseif not pendingQuestIDs[questID].needsRewardData then
                    pendingQuestIDs[questID].needsRewardData = true
                end
                if animateRows == false then
                    rewardPreloadState.QueueQuestRewardPreload(questID, false)
                end
            end
        end
    end
    if hiddenRewardPreloadQuestIDs then
        for _, questID in ipairs(hiddenRewardPreloadQuestIDs) do
            rewardPreloadState.QueueQuestRewardPreload(questID, false)
        end
    end
    rewardPreloadState.StartPoll()
    local syncPOIElapsed = 0
    if not isDescendantGatherPending then
        local shouldSyncLiveAreaPOIs = eventFrame._lastLiveRelevantAreaPOISnapshotCount == nil
            or relevantWorldQuestQuerySignatureChanged
            or reason == "OnMapChanged"
            or reason == "AREA_POIS_UPDATED"
            or reason == "Staged descendant gather complete"
        if shouldSyncLiveAreaPOIs then
            local syncPOIStart = debugprofilestop()
            eventFrame:SyncLiveRelevantAreaPOISnapshot(mapID)
            syncPOIElapsed = debugprofilestop() - syncPOIStart
        end
    end
    local syncVisibleStart = debugprofilestop()
    eventFrame:SyncVisibleLockedAreaPOISnapshot()
    local syncVisibleElapsed = debugprofilestop() - syncVisibleStart
    if ns.IsDebugEnabled() then
        eventFrame:DebugWorldQuestsRefreshTrace(
            "RefreshPanel execute",
            string_format(
                "reason=%s animate=%s mapID=%s questCount=%s",
                tostring(reason or "unspecified"),
                tostring(animateRows ~= false),
                tostring(mapID),
                tostring(#quests)))
    end
    if ns.IsDebugEnabled() then
        ns.DebugPrint(string_format(
            "WorldQuests: RefreshPanel timing gather=%.1fms syncPOI=%.1fms syncVisible=%.1fms",
            gatherElapsed / 1000, syncPOIElapsed / 1000, syncVisibleElapsed / 1000))
    end
    UpdateQuestLogUpdateRegistration()
    EnsureQuestDataRetryRefresh()
    local typoStart = debugprofilestop()
    ApplyWorldQuestTypography()
    local typoElapsed = debugprofilestop() - typoStart
    if ns.IsDebugEnabled() then
        ns.DebugPrint(string_format(
            "WorldQuests: RefreshPanel typography=%.1fms",
            typoElapsed / 1000))
    end
    RefreshContractNotice()
    eventFrame._lastLayoutReason = reason or "unspecified"
    LayoutScrollContent(quests, not isDescendantGatherPending and animateRows ~= false)
end

local function GetDelayUntilNextServerMinute()
    local serverTime = GetCurrentServerTime()
    local delay = 60 - (serverTime % 60)
    if delay <= 0 then
        delay = 60
    end
    return delay
end

local function UpdateCurrentQuestTimeState()
    if not currentQuestEntries or #currentQuestEntries == 0 then
        RefreshContractNotice()
        EnsureQuestDataRetryRefresh()
        return
    end

    local now = GetCurrentServerTime()
    local needsAreaPOITextRefresh = false

    for _, entry in ipairs(currentQuestEntries) do
        if entry.isAreaPOI then
            local previousExpiresAt = entry.expiresAt
            local previousTimeText = entry.timeText
            local previousAreaPOITimeText = entry.areaPOITimeText
            if entry.poiID and C_AreaPoiInfo and C_AreaPoiInfo.IsAreaPOITimed
                and C_AreaPoiInfo.GetAreaPOISecondsLeft
                and C_AreaPoiInfo.IsAreaPOITimed(entry.poiID)
            then
                local remaining = C_AreaPoiInfo.GetAreaPOISecondsLeft(entry.poiID)
                if remaining and remaining > 0 then
                    entry.timeLeft = remaining
                    entry.expiresAt = now + remaining
                elseif previousExpiresAt and previousExpiresAt > now then
                    entry.timeLeft = previousExpiresAt - now
                    entry.expiresAt = previousExpiresAt
                else
                    entry.timeLeft = nil
                    entry.expiresAt = nil
                end
            elseif previousExpiresAt and previousExpiresAt > now then
                entry.timeLeft = previousExpiresAt - now
                entry.expiresAt = previousExpiresAt
            else
                entry.timeLeft = nil
                entry.expiresAt = nil
            end

            local hasRemainingAreaPOITime = (entry.timeLeft and entry.timeLeft > 0)
                or (entry.expiresAt and entry.expiresAt > now)
            if entry.tooltipWidgetSet then
                local refreshedAreaPOITimeText = eventFrame:GetCurrentAreaPOITimeText(entry.tooltipWidgetSet)
                if refreshedAreaPOITimeText ~= nil then
                    entry.areaPOITimeText = refreshedAreaPOITimeText
                elseif not hasRemainingAreaPOITime then
                    entry.areaPOITimeText = nil
                end
            end

            local hadAreaPOITimerDisplay = (previousAreaPOITimeText and previousAreaPOITimeText ~= "")
                or (previousExpiresAt and previousExpiresAt > now)
            local hasAreaPOITimerDisplay = (entry.areaPOITimeText and entry.areaPOITimeText ~= "")
                or hasRemainingAreaPOITime

            if hadAreaPOITimerDisplay and not hasAreaPOITimerDisplay then
                needsAreaPOITextRefresh = true
            end

            if entry.areaPOITimeText then
                entry.timeText = entry.areaPOITimeText
            elseif entry.timeLeft and entry.timeLeft > 0 then
                entry.timeText = FormatTimeLeft(entry.timeLeft)
            elseif entry.expiresAt and entry.expiresAt > now and previousTimeText and previousTimeText ~= "" then
                entry.timeText = previousTimeText
            else
                entry.timeText = FormatTimeLeft(nil)
            end
        else
            local previousExpiresAt = entry.expiresAt
            local remaining, expiresAt = GetQuestExpirySnapshot(entry.questID, now, entry)
            if remaining and remaining > 0 then
                entry.timeLeft = remaining
                entry.timeText = FormatTimeLeft(remaining)
                entry.expiresAt = expiresAt
            elseif previousExpiresAt and previousExpiresAt > now then
                entry.timeLeft = previousExpiresAt - now
                entry.timeText = FormatTimeLeft(entry.timeLeft)
                entry.expiresAt = previousExpiresAt
            else
                entry.timeLeft = nil
                entry.expiresAt = nil
                entry.timeText = FormatTimeLeft(nil)
            end
        end
    end

    RefreshContractNotice()
    EnsureQuestDataRetryRefresh()

    if needsAreaPOITextRefresh then
        ScheduleRefresh(false)
    end

    for _, item in ipairs(activeContent) do
        if item.type == "row" then
            local entry = item._entry or (item.frame and item.frame.questEntry)
            if entry then
                if item._entry then
                    item._entry.timeLeft = entry.timeLeft
                    item._entry.timeText = entry.timeText
                elseif item.frame then
                    UpdateQuestRowTimeDisplay(item.frame, entry)
                end
            end
        end
    end
end

local function GetNextPendingQuestDataRetryTime()
    if not next(pendingQuestIDs) then
        return nil
    end

    local now = GetTime()
    local nextRetryAt
    for questID, _ in pairs(pendingQuestIDs) do
        local retryAt = questDataRetrySuppressedUntil[questID]
        if retryAt and (not nextRetryAt or retryAt < nextRetryAt) then
            nextRetryAt = retryAt
        end

    end

    return nextRetryAt
end

StopQuestDataRetryRefresh = function()
    retryRefreshGeneration = retryRefreshGeneration + 1
    retryRefreshDueAt = nil
end

EnsureQuestDataRetryRefresh = function()
    local nextRetryAt = GetNextPendingQuestDataRetryTime()
    if not nextRetryAt then
        StopQuestDataRetryRefresh()
        return
    end

    if retryRefreshDueAt and nextRetryAt == retryRefreshDueAt then
        return
    end

    retryRefreshGeneration = retryRefreshGeneration + 1
    local myGeneration = retryRefreshGeneration
    retryRefreshDueAt = nextRetryAt

    local delay = nextRetryAt - GetTime()
    if delay < 0.3 then
        delay = 0.3
    end

    C_Timer.After(delay, function()
        if retryRefreshGeneration ~= myGeneration then
            return
        end

        retryRefreshDueAt = nil

        if not ns.IsWorldQuestsRefreshContextActive() then
            return
        end

        ScheduleRefresh(false)
    end)
end

EnsureMinuteAlignedTimeUpdates = function()
    if minuteUpdateActive then
        return
    end

    minuteUpdateActive = true
    minuteUpdateGeneration = minuteUpdateGeneration + 1
    local myGeneration = minuteUpdateGeneration

    local function tick()
        if minuteUpdateGeneration ~= myGeneration then
            return
        end
        if not ns.IsWorldQuestsRefreshContextActive() then
            minuteUpdateActive = false
            return
        end

        UpdateCurrentQuestTimeState()
        C_Timer.After(GetDelayUntilNextServerMinute(), tick)
    end

    C_Timer.After(GetDelayUntilNextServerMinute(), tick)
end

StopMinuteAlignedTimeUpdates = function()
    minuteUpdateGeneration = minuteUpdateGeneration + 1
    minuteUpdateActive = false
end

-- Schedules a refresh on the next frame to debounce rapid event bursts.
ScheduleRefresh = function(animateRows, reason, immediate)
    if animateRows == nil then
        animateRows = true
    end

    local refreshReason = reason or "unspecified"

    if not ns.IsWorldQuestsRefreshContextActive() then
        if ns.IsDebugEnabled() then
            eventFrame:DebugWorldQuestsRefreshTrace(
                "ScheduleRefresh skipped inactive",
                string_format("reason=%s animate=%s", refreshReason, tostring(animateRows)))
        end
        return
    end

    if refreshPending then
        if animateRows == true then
            refreshPendingAnimateRows = true
        elseif refreshPendingAnimateRows ~= true then
            refreshPendingAnimateRows = false
        end

        if reason then
            eventFrame._refreshPendingReason = reason
        end

        if ns.IsDebugEnabled() then
            eventFrame:DebugWorldQuestsRefreshTrace(
                "ScheduleRefresh coalesced",
                string_format(
                    "reason=%s animate=%s pendingAnimate=%s pendingReason=%s",
                    refreshReason,
                    tostring(animateRows),
                    tostring(refreshPendingAnimateRows),
                    tostring(eventFrame._refreshPendingReason)))
        end
        if activeHoverState.questID then
            DebugHoverTrace(
                "ScheduleRefresh",
                "phase=coalesced reason=%s animate=%s pendingAnimate=%s pendingReason=%s activeQuestID=%s",
                refreshReason,
                tostring(animateRows),
                tostring(refreshPendingAnimateRows),
                tostring(eventFrame._refreshPendingReason),
                tostring(activeHoverState.questID))
        end
        return
    end

    refreshPending = true
    refreshPendingAnimateRows = animateRows
    eventFrame._refreshPendingReason = refreshReason
    if ns.IsDebugEnabled() then
        eventFrame:DebugWorldQuestsRefreshTrace(
            "ScheduleRefresh scheduled",
            string_format("reason=%s animate=%s", refreshReason, tostring(animateRows)))
    end
    if activeHoverState.questID then
        DebugHoverTrace(
            "ScheduleRefresh",
            "phase=scheduled reason=%s animate=%s immediate=%s activeQuestID=%s",
            refreshReason,
            tostring(animateRows),
            tostring(immediate == true),
            tostring(activeHoverState.questID))
    end
    C_Timer.After(immediate == true and 0 or 0.25, function()
        local shouldAnimate = refreshPendingAnimateRows
        local pendingReason = eventFrame._refreshPendingReason
        refreshPending = false
        refreshPendingAnimateRows = true
        eventFrame._refreshPendingReason = "unspecified"
        if not ns.IsWorldQuestsRefreshContextActive() then
            if ns.IsDebugEnabled() then
                eventFrame:DebugWorldQuestsRefreshTrace(
                    "ScheduleRefresh skipped inactive",
                    string_format(
                        "reason=%s animate=%s phase=timer",
                        tostring(pendingReason),
                        tostring(shouldAnimate)))
            end
            return
        end
        RefreshPanel(shouldAnimate, pendingReason)
    end)
end

function eventFrame:HandleWorldMapChanged()
    local mapID = WorldMapFrame and WorldMapFrame.mapID or nil

    if ns.IsDebugEnabled() then
        self:DebugWorldQuestsRefreshTrace(
            "OnMapChanged entry",
            string_format(
                "mapID=%s lastMapID=%s",
                tostring(mapID),
                tostring(self._lastScheduledWorldQuestsMapID)))
    end

    if not ns.IsWorldQuestsRefreshContextActive() then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "OnMapChanged skipped inactive",
                string_format("mapID=%s", tostring(mapID)))
        end
        return
    end

    if not mapID then
        self:DebugWorldQuestsRefreshTrace("OnMapChanged skipped no-map", "mapID=nil")
        return
    end

    if mapID == self._lastScheduledWorldQuestsMapID then
        local hasRelevantWorldQuestQuerySignatureChange,
            previousRelevantWorldQuestQuerySignature,
            discoveredRelevantWorldQuestQuerySignature =
                self:HasRelevantWorldQuestQuerySignatureChange(mapID)

        if hasRelevantWorldQuestQuerySignatureChange then
            layoutGeneration = layoutGeneration + 1
            self:CancelWorldQuestDescendantGather()
            if ns.IsDebugEnabled() then
                self:DebugWorldQuestsRefreshTrace(
                    "OnMapChanged relevant-map signature",
                    string_format(
                        "mapID=%s previousSignature=%s discoveredSignature=%s",
                        tostring(mapID),
                        tostring(previousRelevantWorldQuestQuerySignature),
                        tostring(discoveredRelevantWorldQuestQuerySignature)))
            end
            if activeHoverState.questID then
                DebugHoverTrace(
                    "HandleWorldMapChanged",
                    "trigger-refresh reason=OnMapChanged signature-change mapID=%s activeQuestID=%s",
                    tostring(mapID),
                    tostring(activeHoverState.questID))
            end
            ScheduleRefresh(true, "OnMapChanged")
            return
        end

        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "OnMapChanged skipped duplicate",
                string_format("mapID=%s", tostring(mapID)))
        end
        return
    end

    self._lastScheduledWorldQuestsMapID = mapID
    layoutGeneration = layoutGeneration + 1
    self:CancelWorldQuestDescendantGather()
    if ns.IsDebugEnabled() then
        self:DebugWorldQuestsRefreshTrace(
            "OnMapChanged scheduled",
            string_format("mapID=%s", tostring(mapID)))
    end
    if activeHoverState.questID then
        DebugHoverTrace(
            "HandleWorldMapChanged",
            "trigger-refresh reason=OnMapChanged mapID=%s activeQuestID=%s",
            tostring(mapID),
            tostring(activeHoverState.questID))
    end
    ScheduleRefresh(true, "OnMapChanged")
end

function eventFrame:HandleAreaPOIsUpdated()
    local mapID = WorldMapFrame and WorldMapFrame.mapID or nil

    if ns.IsDebugEnabled() then
        self:DebugWorldQuestsRefreshTrace(
            "AREA_POIS_UPDATED entry",
            string_format("mapID=%s", tostring(mapID)))
    end

    if not ns.IsWorldQuestsRefreshContextActive() then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "AREA_POIS_UPDATED skipped inactive",
                string_format("mapID=%s", tostring(mapID)))
        end
        return
    end

    if not mapID then
        self:DebugWorldQuestsRefreshTrace("AREA_POIS_UPDATED skipped no-map", "mapID=nil")
        return
    end

    if self:IsWorldQuestDescendantGatherPending(mapID) then
        self:CancelWorldQuestDescendantGather()
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "AREA_POIS_UPDATED staged restart",
                string_format("mapID=%s", tostring(mapID)))
        end
        if activeHoverState.questID then
            DebugHoverTrace(
                "HandleAreaPOIsUpdated",
                "trigger-refresh reason=AREA_POIS_UPDATED staged-restart mapID=%s activeQuestID=%s",
                tostring(mapID),
                tostring(activeHoverState.questID))
        end
        ScheduleRefresh(true, "AREA_POIS_UPDATED")
        return
    end

    local hasRelevantWorldQuestQuerySignatureChange,
        previousRelevantWorldQuestQuerySignature,
        discoveredRelevantWorldQuestQuerySignature =
            self:HasRelevantWorldQuestQuerySignatureChange(mapID)

    if hasRelevantWorldQuestQuerySignatureChange then
        layoutGeneration = layoutGeneration + 1
        rewardPreloadState.CancelDrain()
        self:CancelWorldQuestDescendantGather()
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "AREA_POIS_UPDATED relevant-map signature",
                string_format(
                    "mapID=%s previousSignature=%s discoveredSignature=%s",
                    tostring(mapID),
                    tostring(previousRelevantWorldQuestQuerySignature),
                    tostring(discoveredRelevantWorldQuestQuerySignature)))
        end
        if activeHoverState.questID then
            DebugHoverTrace(
                "HandleAreaPOIsUpdated",
                "trigger-refresh reason=AREA_POIS_UPDATED signature-change mapID=%s activeQuestID=%s",
                tostring(mapID),
                tostring(activeHoverState.questID))
        end
        ScheduleRefresh(true, "AREA_POIS_UPDATED")
        return
    end

    if not self:HasLiveRelevantAreaPOIStateChange(mapID) then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "AREA_POIS_UPDATED skipped unchanged",
                string_format("mapID=%s", tostring(mapID)))
        end
        return
    end

    layoutGeneration = layoutGeneration + 1
    rewardPreloadState.CancelDrain()
    self:CancelWorldQuestDescendantGather()
    if ns.IsDebugEnabled() then
        self:DebugWorldQuestsRefreshTrace(
            "AREA_POIS_UPDATED scheduled",
            string_format("mapID=%s", tostring(mapID)))
    end
    if activeHoverState.questID then
        DebugHoverTrace(
            "HandleAreaPOIsUpdated",
            "trigger-refresh reason=AREA_POIS_UPDATED live-state-change mapID=%s activeQuestID=%s",
            tostring(mapID),
            tostring(activeHoverState.questID))
    end
    ScheduleRefresh(true, "AREA_POIS_UPDATED")
end

function eventFrame:GetLockedAreaPOIWidgetUpdateScope(widgetInfo)
    local function ScanTrackedLockedAreaPOIWidgetSetsForWidgetID(widgetID, widgetSetIDs)
        if not widgetID or widgetID <= 0 or not widgetSetIDs
            or not C_UIWidgetManager
            or not C_UIWidgetManager.GetAllWidgetsBySetID
        then
            return false
        end

        for widgetSetID in pairs(widgetSetIDs) do
            local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID)
            if widgets then
                for index = 1, #widgets do
                    local currentWidgetInfo = widgets[index]
                    if currentWidgetInfo and currentWidgetInfo.widgetID == widgetID then
                        return true
                    end
                end
            end
        end

        return false
    end

    if type(widgetInfo) ~= "table" then
        return false, false
    end

    local widgetSetID = widgetInfo.widgetSetID or 0
    local widgetID = widgetInfo.widgetID or 0
    local hasVisibleMatch = false
    local hasLiveMatch = false

    if widgetSetID > 0 then
        hasVisibleMatch = self._visibleLockedAreaPOIWidgetSetIDs
            and self._visibleLockedAreaPOIWidgetSetIDs[widgetSetID] == true or false
        hasLiveMatch = self._liveRelevantAreaPOIWidgetSetIDs
            and self._liveRelevantAreaPOIWidgetSetIDs[widgetSetID] == true or false
    elseif widgetID > 0 then
        hasVisibleMatch = ScanTrackedLockedAreaPOIWidgetSetsForWidgetID(
            widgetID,
            self._visibleLockedAreaPOIWidgetSetIDs)
        hasLiveMatch = ScanTrackedLockedAreaPOIWidgetSetsForWidgetID(
            widgetID,
            self._liveRelevantAreaPOIWidgetSetIDs)
    end

    return hasVisibleMatch, hasLiveMatch
end

function eventFrame:HandleLockedAreaPOIWidgetUpdated(widgetInfo)
    local mapID = WorldMapFrame and WorldMapFrame.mapID or nil
    local widgetSetID = widgetInfo and widgetInfo.widgetSetID or nil
    local widgetID = widgetInfo and widgetInfo.widgetID or nil

    if ns.IsDebugEnabled() then
        self:DebugWorldQuestsRefreshTrace(
            "UPDATE_UI_WIDGET entry",
            string_format(
                "mapID=%s widgetSetID=%s widgetID=%s",
                tostring(mapID),
                tostring(widgetSetID),
                tostring(widgetID)))
    end

    if not ns.IsWorldQuestsRefreshContextActive() then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_UI_WIDGET skipped inactive",
                string_format(
                    "mapID=%s widgetSetID=%s widgetID=%s",
                    tostring(mapID),
                    tostring(widgetSetID),
                    tostring(widgetID)))
        end
        return
    end

    if not mapID then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_UI_WIDGET skipped no-map",
                string_format(
                    "widgetSetID=%s widgetID=%s",
                    tostring(widgetSetID),
                    tostring(widgetID)))
        end
        return
    end

    if self._activeRelevantWorldQuestMapID ~= mapID then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_UI_WIDGET skipped unsynced-map",
                string_format(
                    "mapID=%s activeMapID=%s widgetSetID=%s widgetID=%s",
                    tostring(mapID),
                    tostring(self._activeRelevantWorldQuestMapID),
                    tostring(widgetSetID),
                    tostring(widgetID)))
        end
        return
    end

    if (self._visibleLockedAreaPOIWidgetSetCount or 0) == 0
        and (self._liveRelevantAreaPOIWidgetSetCount or 0) == 0
    then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_UI_WIDGET skipped untracked",
                string_format(
                    "mapID=%s widgetSetID=%s widgetID=%s",
                    tostring(mapID),
                    tostring(widgetSetID),
                    tostring(widgetID)))
        end
        return
    end

    local hasVisibleMatch, hasLiveMatch = self:GetLockedAreaPOIWidgetUpdateScope(widgetInfo)
    if not hasVisibleMatch and not hasLiveMatch then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_UI_WIDGET skipped irrelevant",
                string_format(
                    "mapID=%s widgetSetID=%s widgetID=%s",
                    tostring(mapID),
                    tostring(widgetSetID),
                    tostring(widgetID)))
        end
        return
    end

    if hasVisibleMatch and self:HasVisibleLockedAreaPOIStateChange() then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_UI_WIDGET scheduled visible",
                string_format(
                    "mapID=%s widgetSetID=%s widgetID=%s",
                    tostring(mapID),
                    tostring(widgetSetID),
                    tostring(widgetID)))
        end
        ScheduleRefresh(false, "UPDATE_UI_WIDGET visible locked area POI")
        return
    end

    if self:IsWorldQuestDescendantGatherPending(mapID) then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_UI_WIDGET deferred staged gather",
                string_format(
                    "mapID=%s widgetSetID=%s widgetID=%s",
                    tostring(mapID),
                    tostring(widgetSetID),
                    tostring(widgetID)))
        end
        return
    end

    if hasLiveMatch and self:HasLiveRelevantAreaPOIStateChange(mapID) then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_UI_WIDGET scheduled live",
                string_format(
                    "mapID=%s widgetSetID=%s widgetID=%s",
                    tostring(mapID),
                    tostring(widgetSetID),
                    tostring(widgetID)))
        end
        ScheduleRefresh(false, "UPDATE_UI_WIDGET live locked area POI")
        return
    end

    if ns.IsDebugEnabled() then
        self:DebugWorldQuestsRefreshTrace(
            "UPDATE_UI_WIDGET skipped unchanged",
            string_format(
                "mapID=%s widgetSetID=%s widgetID=%s",
                tostring(mapID),
                tostring(widgetSetID),
                tostring(widgetID)))
    end
end

function eventFrame:HandleAllLockedAreaPOIWidgetsUpdated()
    local mapID = WorldMapFrame and WorldMapFrame.mapID or nil

    if ns.IsDebugEnabled() then
        self:DebugWorldQuestsRefreshTrace(
            "UPDATE_ALL_UI_WIDGETS entry",
            string_format("mapID=%s", tostring(mapID)))
    end

    if not ns.IsWorldQuestsRefreshContextActive() then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_ALL_UI_WIDGETS skipped inactive",
                string_format("mapID=%s", tostring(mapID)))
        end
        return
    end

    if not mapID then
        self:DebugWorldQuestsRefreshTrace(
            "UPDATE_ALL_UI_WIDGETS skipped no-map",
            "mapID=nil")
        return
    end

    if self._activeRelevantWorldQuestMapID ~= mapID then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_ALL_UI_WIDGETS skipped unsynced-map",
                string_format(
                    "mapID=%s activeMapID=%s",
                    tostring(mapID),
                    tostring(self._activeRelevantWorldQuestMapID)))
        end
        return
    end

    if (self._visibleLockedAreaPOIWidgetSetCount or 0) == 0
        and (self._liveRelevantAreaPOIWidgetSetCount or 0) == 0
    then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_ALL_UI_WIDGETS skipped untracked",
                string_format("mapID=%s", tostring(mapID)))
        end
        return
    end

    if (self._visibleLockedAreaPOIWidgetSetCount or 0) > 0
        and self:HasVisibleLockedAreaPOIStateChange()
    then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_ALL_UI_WIDGETS scheduled visible",
                string_format("mapID=%s", tostring(mapID)))
        end
        ScheduleRefresh(false, "UPDATE_ALL_UI_WIDGETS visible locked area POI")
        return
    end

    if self:IsWorldQuestDescendantGatherPending(mapID) then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_ALL_UI_WIDGETS deferred staged gather",
                string_format("mapID=%s", tostring(mapID)))
        end
        return
    end

    if (self._liveRelevantAreaPOIWidgetSetCount or 0) > 0
        and self:HasLiveRelevantAreaPOIStateChange(mapID)
    then
        if ns.IsDebugEnabled() then
            self:DebugWorldQuestsRefreshTrace(
                "UPDATE_ALL_UI_WIDGETS scheduled live",
                string_format("mapID=%s", tostring(mapID)))
        end
        ScheduleRefresh(false, "UPDATE_ALL_UI_WIDGETS live locked area POI")
        return
    end

    if ns.IsDebugEnabled() then
        self:DebugWorldQuestsRefreshTrace(
            "UPDATE_ALL_UI_WIDGETS skipped unchanged",
            string_format("mapID=%s", tostring(mapID)))
    end
end

-- Updates the super-track highlight on all active quest rows without
-- rebuilding the full layout.
-- POI button style is only updated once Phase 2 has populated the row
-- (item._entry == nil), preventing stale internal questID state from causing
-- POIButton_UpdateNormalStyle to clear the elite dragon border underlay.
local function UpdateSuperTrackHighlights()
    local superTrackedID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID() or nil
    for _, item in ipairs(activeContent) do
        if item.type == "row" and item.frame then
            local row = item.frame
            local entry = item._entry or row.questEntry
            -- Skip rows that are still showing "Loading..." — their title
            -- colour is managed by PopulateQuestRow once data arrives.
                local hasTitle = not (entry and entry.isAreaPOI)
                    and row.questID and GetQuestTitle(row.questID)
            local isLocked = entry and entry.isLocked == true
            local isTracked = superTrackedID and (superTrackedID == row.questID)
            if hasTitle or isLocked then
                ApplyQuestRowTitleColor(row.titleText, row.questID, isLocked, false)
            end
            -- POI button style update (guarded by Phase 2 completion).
            if item._entry == nil and row.poiBtn then
                if entry and entry.isAreaPOI then
                    if row.poiBtn.SetSelected then
                        local trackedType, trackedID
                        if C_SuperTrack and C_SuperTrack.GetSuperTrackedMapPin then
                            trackedType, trackedID = C_SuperTrack.GetSuperTrackedMapPin()
                        end
                        local mapPinType = Enum and Enum.SuperTrackingMapPinType
                            and Enum.SuperTrackingMapPinType.AreaPOI or 0
                        local isTrackedPOI = trackedType == mapPinType and trackedID == entry.poiID
                        row.poiBtn:SetSelected(isTrackedPOI and true or false)
                    end
                    if row.poiBtn.UpdateSelected then row.poiBtn:UpdateSelected() end
                    if row.poiBtn.nomtoolsAreaPOIIcon then
                        local atlas = entry.areaPOIInfo and entry.areaPOIInfo.atlasName
                        if atlas and row.poiBtn.nomtoolsAreaPOIIcon.SetAtlas then
                            row.poiBtn.nomtoolsAreaPOIIcon:SetAtlas(atlas, true)
                            row.poiBtn.nomtoolsAreaPOIIcon:Show()
                        else
                            row.poiBtn.nomtoolsAreaPOIIcon:Hide()
                        end
                    end
                    if row.poiBtn.Display and row.poiBtn.Display.SetIconShown then
                        row.poiBtn.Display:SetIconShown(false)
                    elseif row.poiBtn.Display and row.poiBtn.Display.Icon then
                        row.poiBtn.Display.Icon:SetAlpha(0)
                    end
                    if row.poiBtn.Display and row.poiBtn.Display.SubTypeIcon then
                        row.poiBtn.Display.SubTypeIcon:Hide()
                    end
                elseif POIButtonUtil and row.poiBtn.SetStyle then
                    ClearPOIButtonAreaPOIState(row.poiBtn)
                    row.poiBtn:SetStyle(POIButtonUtil.Style.WorldQuest)
                    row.poiBtn:SetSelected(isTracked and true or false)
                    if row.poiBtn.UpdateButtonStyle then row.poiBtn:UpdateButtonStyle() end
                    if row.poiBtn.Display and row.poiBtn.Display.SetIconShown then
                        row.poiBtn.Display:SetIconShown(true)
                    elseif row.poiBtn.Display and row.poiBtn.Display.Icon then
                        row.poiBtn.Display.Icon:SetAlpha(1)
                    end
                end
            end
        end
    end
end

function eventFrame:UpdateQuestRow(questID)
    local function BuildQuestRowEntry(questID, mapID, mapName, baseEntry)
        local now = GetCurrentServerTime()
        local isAreaPOI = baseEntry and baseEntry.isAreaPOI == true or false
        local rawQuestTagType = baseEntry and baseEntry.rawQuestTagType or nil
        local rawTagID = baseEntry and baseEntry.rawTagID or nil
        local isLocked = ResolveQuestLockedState(questID, baseEntry)
        local rewardDataReady = isAreaPOI or isLocked or rewardPreloadState.IsQuestRewardDisplayReady(questID)
        local rawTimeLeftSeconds = baseEntry and baseEntry.rawTimeLeftSeconds or nil
        local rawTimeLeftSecondsConsumed = baseEntry and baseEntry.rawTimeLeftSecondsConsumed == true or false
        local areaPOITimeText = baseEntry and baseEntry.areaPOITimeText or nil
        local previousExpiresAt = baseEntry and baseEntry.expiresAt or nil
        local previousTimeText = baseEntry and baseEntry.timeText or nil

        local timeLeft, expiresAt
        if isAreaPOI then
            if baseEntry and baseEntry.poiID and C_AreaPoiInfo and C_AreaPoiInfo.IsAreaPOITimed
                and C_AreaPoiInfo.GetAreaPOISecondsLeft
                and C_AreaPoiInfo.IsAreaPOITimed(baseEntry.poiID)
            then
                timeLeft = C_AreaPoiInfo.GetAreaPOISecondsLeft(baseEntry.poiID)
                if timeLeft and timeLeft > 0 then
                    expiresAt = now + timeLeft
                elseif previousExpiresAt and previousExpiresAt > now then
                    timeLeft = previousExpiresAt - now
                    expiresAt = previousExpiresAt
                end
            elseif previousExpiresAt and previousExpiresAt > now then
                timeLeft = previousExpiresAt - now
                expiresAt = previousExpiresAt
            end
        else
            timeLeft, expiresAt = GetQuestExpirySnapshot(questID, now, baseEntry)
            rawTimeLeftSecondsConsumed = baseEntry and baseEntry.rawTimeLeftSecondsConsumed == true or false
        end

        if isAreaPOI and baseEntry and baseEntry.tooltipWidgetSet then
            local refreshedAreaPOITimeText = eventFrame:GetCurrentAreaPOITimeText(baseEntry.tooltipWidgetSet)
            if refreshedAreaPOITimeText ~= nil then
                areaPOITimeText = refreshedAreaPOITimeText
            elseif not ((timeLeft and timeLeft > 0) or (expiresAt and expiresAt > now)) then
                areaPOITimeText = nil
            end
        end

        local questType = isAreaPOI and "special_assignment" or GetQuestType(questID, rawQuestTagType, rawTagID)

        if not isAreaPOI then
            expiresAt = GetPersistedLockedSpecialAssignmentExpiresAt(
                questID,
                isLocked,
                rawQuestTagType,
                rawTagID,
                questType,
                timeLeft,
                expiresAt)
        end

        local rawRewards = (not isLocked and rewardDataReady) and GetQuestRewards(questID) or {}
        local expID = not isAreaPOI and GetQuestExpansionID(questID) or nil

        local title = isAreaPOI and (baseEntry.title or baseEntry.poiName) or GetQuestTitle(questID)
        local unlockText = isLocked and (isAreaPOI and baseEntry.unlockText or GetLockedSpecialAssignmentUnlockText(questID)) or nil
        local faction = not isAreaPOI and GetQuestFactionLabel(questID) or nil
        local timeText
        if isAreaPOI and areaPOITimeText then
            timeText = areaPOITimeText
        elseif timeLeft and timeLeft > 0 then
            timeText = FormatTimeLeft(timeLeft)
        elseif expiresAt and expiresAt > now and previousTimeText and previousTimeText ~= "" then
            timeText = previousTimeText
        else
            timeText = FormatTimeLeft(nil)
        end

        return {
            questID  = questID,
            mapID    = mapID or 0,
            mapName  = mapName or "",
            title    = title,
            faction  = faction,
            timeLeft = timeLeft,
            timeText = timeText,
            expiresAt = expiresAt,
            questType = questType,
            expID = expID,
            expLabel = expID and EXPANSION_LABELS[expID] or nil,
            rawTimeLeftSeconds = rawTimeLeftSeconds,
            rawTimeLeftSecondsConsumed = rawTimeLeftSecondsConsumed,
            rawQuestTagType = rawQuestTagType,
            rawTagID = rawTagID,
            isMapIndicatorQuest = baseEntry and baseEntry.isMapIndicatorQuest == true or false,
            bountyLockedCandidate = baseEntry and baseEntry.bountyLockedCandidate == true or false,
            isLocked = isLocked,
            isAreaPOI = isAreaPOI,
            areaPOITimeText = areaPOITimeText,
            areaPOIRewards = baseEntry and baseEntry.areaPOIRewards or nil,
            rewardText = baseEntry and baseEntry.rewardText or nil,
            poiID = baseEntry and baseEntry.poiID or nil,
            tooltipWidgetSet = baseEntry and baseEntry.tooltipWidgetSet or nil,
            poiDescription = baseEntry and baseEntry.poiDescription or nil,
            areaPOIInfo = baseEntry and baseEntry.areaPOIInfo or nil,
            linkedUiMapID = baseEntry and baseEntry.linkedUiMapID or nil,
            isPrimaryAreaPOI = baseEntry and baseEntry.isPrimaryAreaPOI == true or false,
            areaPOIOwnerScore = baseEntry and baseEntry.areaPOIOwnerScore or nil,
            unlockText = unlockText,
            primReward = (#rawRewards > 0) and GetPrimaryRewardType(rawRewards) or nil,
            rewardDataReady = rewardDataReady,
            dataReady = isAreaPOI or eventFrame:IsQuestCoreDataReady(questID),
        }
    end

    local function CopyQuestRowEntry(target, source)
        target.questID = source.questID
        target.mapID = source.mapID
        target.mapName = source.mapName
        target.title = source.title
        target.faction = source.faction
        target.timeLeft = source.timeLeft
        target.timeText = source.timeText
        target.expiresAt = source.expiresAt
        target.questType = source.questType
        target.expID = source.expID
        target.expLabel = source.expLabel
        target.rawTimeLeftSeconds = source.rawTimeLeftSeconds
        target.rawTimeLeftSecondsConsumed = source.rawTimeLeftSecondsConsumed
        target.rawQuestTagType = source.rawQuestTagType
        target.rawTagID = source.rawTagID
        target.isMapIndicatorQuest = source.isMapIndicatorQuest
        target.bountyLockedCandidate = source.bountyLockedCandidate
        target.isLocked = source.isLocked
        target.isAreaPOI = source.isAreaPOI
        target.areaPOITimeText = source.areaPOITimeText
        target.areaPOIRewards = source.areaPOIRewards
        target.rewardText = source.rewardText
        target.poiID = source.poiID
        target.tooltipWidgetSet = source.tooltipWidgetSet
        target.poiDescription = source.poiDescription
        target.areaPOIInfo = source.areaPOIInfo
        target.linkedUiMapID = source.linkedUiMapID
        target.isPrimaryAreaPOI = source.isPrimaryAreaPOI
        target.areaPOIOwnerScore = source.areaPOIOwnerScore
        target.unlockText = source.unlockText
        target.primReward = source.primReward
        target.rewardDataReady = source.rewardDataReady
        target.dataReady = source.dataReady
    end

    local function DoesRewardDataAffectDisplayedResult(previousEntry, refreshedEntry)
        if not previousEntry or not refreshedEntry then
            return false
        end

        local function DoesQuestEntryMatchSearch(entry, searchLower, primReward, faction)
            if not searchLower or searchLower == "" then
                return true
            end

            local factionLabel = faction ~= nil and faction or (entry and entry.faction or nil)
            local rewardType = primReward ~= nil and primReward or (entry and entry.primReward or nil)
            local questType = entry and entry.questType or nil

            return (entry and entry.title and string_lower(entry.title):find(searchLower, 1, true))
                or (factionLabel and string_lower(factionLabel):find(searchLower, 1, true))
                or (entry and entry.unlockText and string_lower(entry.unlockText):find(searchLower, 1, true))
                or (entry and entry.mapName and string_lower(entry.mapName):find(searchLower, 1, true))
                or (questType and QUEST_TYPE_LABEL[questType]
                    and string_lower(QUEST_TYPE_LABEL[questType]):find(searchLower, 1, true))
                or (rewardType and REWARD_TYPE_LABEL[rewardType]
                    and string_lower(REWARD_TYPE_LABEL[rewardType]):find(searchLower, 1, true))
        end

        local previousPrimReward = previousEntry.primReward
        local refreshedPrimReward = refreshedEntry.primReward
        local previousFaction = previousEntry.faction
        local refreshedFaction = refreshedEntry.faction

        if sortMode == "reward" and previousPrimReward ~= refreshedPrimReward then
            return true
        end

        if sortMode == "faction" and previousFaction ~= refreshedFaction then
            return true
        end

        if next(filterRewards) then
            local previousExcluded = previousPrimReward and filterRewards[previousPrimReward] or false
            local refreshedExcluded = refreshedPrimReward and filterRewards[refreshedPrimReward] or false
            if previousExcluded ~= refreshedExcluded then
                return true
            end
        end

        if filterSearch ~= "" then
            local searchLower = string_lower(filterSearch)
            local previousMatched = DoesQuestEntryMatchSearch(
                previousEntry,
                searchLower,
                previousPrimReward,
                previousFaction) and true or false
            local refreshedMatched = DoesQuestEntryMatchSearch(
                refreshedEntry,
                searchLower,
                refreshedPrimReward,
                refreshedFaction) and true or false
            if previousMatched ~= refreshedMatched then
                return true
            end
        end

        return false
    end

    questTypeCache[questID] = nil

    local existingEntry = GetExistingQuestEntry(questID)
    local rowItem = nil
    for _, item in ipairs(activeContent) do
        if item.type == "row" and item.frame and item.frame.questID == questID then
            rowItem = item
            break
        end
    end

    local row = rowItem and rowItem.frame or nil
    local rowQuestEntry = row and row["questEntry"] or nil
    local currentEntry = rowItem and (rowItem._entry or rowQuestEntry) or existingEntry
    if not currentEntry and not existingEntry then
        return false, false
    end

    local previousEntry = existingEntry or currentEntry
    local previousRewardDataReady = previousEntry and previousEntry.rewardDataReady
    local refreshedEntry = BuildQuestRowEntry(
        questID,
        row and row.mapID or (currentEntry and currentEntry.mapID) or nil,
        row and row.mapName or (currentEntry and currentEntry.mapName) or nil,
        currentEntry or existingEntry)
    local needsFullRefresh = previousEntry
        and DoesRewardDataAffectDisplayedResult(previousEntry, refreshedEntry)
        or false

    if existingEntry then
        CopyQuestRowEntry(existingEntry, refreshedEntry)
    end
    if currentEntry and currentEntry ~= existingEntry then
        CopyQuestRowEntry(currentEntry, refreshedEntry)
    end

    if rowItem and rowItem._entry == nil and row then
        local rowEntry = rowQuestEntry or existingEntry or currentEntry or refreshedEntry
        if rowEntry ~= existingEntry and rowEntry ~= currentEntry then
            CopyQuestRowEntry(rowEntry, refreshedEntry)
        end
        PopulateQuestRow(
            row,
            rowEntry,
            previousRewardDataReady == false and rowEntry.rewardDataReady == true)
    end

    return rowItem ~= nil, needsFullRefresh
end

function rewardPreloadState.PollPendingRewardData()
    local anyStillPending = false
    local anyResolved = false
    local anyNeedsFullRefresh = false
    local now = GetTime()

    for questID, pendingState in pairs(pendingQuestIDs) do
        if pendingState and pendingState.needsRewardData then
            if rewardPreloadState.IsQuestRewardDisplayReady(questID) then
                local rowNeedsUpdate, _, searchRefreshOnRewardReady =
                    ResolvePendingQuestDataState(questID)
                if rowNeedsUpdate then
                    local _, rowNeedsFullRefresh = eventFrame:UpdateQuestRow(questID)
                    eventFrame:RefreshActiveQuestTooltipIfReady(questID)
                    if rowNeedsFullRefresh then
                        anyNeedsFullRefresh = true
                    end
                end
                if searchRefreshOnRewardReady then
                    anyNeedsFullRefresh = true
                end
                anyResolved = true
            else
                anyStillPending = true
                local requestedAt = rewardPreloadState.requestedQuestIDs[questID]
                local isExpired = not requestedAt
                    or (type(requestedAt) == "number"
                        and requestedAt + rewardPreloadState.requestRetryCooldown <= now)
                if isExpired then
                    local retryAt = questDataRetrySuppressedUntil[questID]
                    if not (retryAt and retryAt > now) then
                        if C_TaskQuest and C_TaskQuest.RequestPreloadRewardData then
                            rewardPreloadState.requestedQuestIDs[questID] = now
                            C_TaskQuest.RequestPreloadRewardData(questID)
                        end
                    end
                end
            end
        end
    end

    if anyResolved then
        UpdateQuestLogUpdateRegistration()
    end
    if anyNeedsFullRefresh then
        ScheduleRefresh(false)
    end

    return anyStillPending
end

-- =============================================
-- Tab + panel creation (QuestMapFrame native tab system)
-- =============================================

-- Creates the content panel parented to QuestMapFrame and registers it as a
-- native side-panel tab (alongside Quests, Events, Map Legend, etc.).
-- Safe to call multiple times — returns immediately if already created.
local function CreateQuestMapTab()
    if questMapPanel then return end
    if not QuestMapFrame then return end

    -- ── Content panel ──────────────────────────────────────────────────────
    local panel = CreateFrame("Frame", "NomToolsWorldQuestPanel", QuestMapFrame)
    panel:Hide()
    panel.displayMode = DISPLAY_MODE
    panel:HookScript("OnShow", function()
        EnsureMinuteAlignedTimeUpdates()
        ScheduleRefresh()
    end)
    panel:HookScript("OnHide", function()
        eventFrame:ResetWorldQuestsRefreshGateState()
        StopMinuteAlignedTimeUpdates()
        StopQuestDataRetryRefresh()
        UpdateQuestLogUpdateRegistration()
    end)

    -- Anchor to ContentsAnchor once it has dimensions; re-anchor on resize.
    local function AnchorPanel()
        panel:ClearAllPoints()
        local ca = QuestMapFrame.ContentsAnchor
        if ca and ca:GetWidth() > 0 and ca:GetHeight() > 0 then
            panel:SetPoint("TOPLEFT",     ca, "TOPLEFT",     0,    -4)
            panel:SetPoint("BOTTOMRIGHT", ca, "BOTTOMRIGHT", -22,   0)
        else
            panel:SetAllPoints(QuestMapFrame)
        end
    end
    AnchorPanel()
    C_Timer.After(0,   AnchorPanel)
    C_Timer.After(0.1, AnchorPanel)

    -- Native QuestLog background atlas
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if bg.SetAtlas then bg:SetAtlas("QuestLog-main-background", true) end

    -- ── Search bar + cogwheel ─────────────────────────────────────────────
    local SEARCH_H = 28   -- height of the search bar row

    worldQuestSearchBox = CreateFrame("EditBox", "NomToolsWQSearchBox", panel,
                                      "SearchBoxTemplate")
    local searchBox = worldQuestSearchBox
    searchBox:SetPoint("TOPLEFT",  panel, "TOPLEFT",   6, -4)
    searchBox:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -30, -4)
    searchBox:SetHeight(SEARCH_H)
    searchBox:SetAutoFocus(false)
    if searchBox.Left then searchBox.Left:SetAlpha(0) end
    if searchBox.Middle then searchBox.Middle:SetAlpha(0) end
    if searchBox.Right then searchBox.Right:SetAlpha(0) end
    -- Search starts empty every session (filterSearch is not persisted).
    searchBox:HookScript("OnTextChanged", function(self)
        local newText = self:GetText() or ""
        if newText == filterSearch then
            return
        end
        filterSearch = newText
        ScheduleRefresh()
    end)
    searchBox:HookScript("OnEscapePressed", function(self)
        self:SetText("")
        -- filterSearch updated by OnTextChanged hook above; just clear focus
        self:ClearFocus()
    end)

    -- Filter button (opens the filter dropdown)
    local cogBtn = CreateFrame("Button", nil, panel)
    cogBtn:SetSize(22, 22)
    cogBtn:SetPoint("LEFT", searchBox, "RIGHT", 2, 0)

    local function CreateTransparentButtonTexture()
        local tex = cogBtn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetColorTexture(1, 1, 1, 0)
        return tex
    end

    cogBtn:SetNormalTexture(CreateTransparentButtonTexture())
    cogBtn:SetPushedTexture(CreateTransparentButtonTexture())
    cogBtn:SetHighlightTexture(CreateTransparentButtonTexture())

    local cogBtnIcon = cogBtn:CreateTexture(nil, "ARTWORK")
    cogBtnIcon:SetAllPoints()
    cogBtnIcon:SetAtlas("Map-Filter-Button", true)
    cogBtn.icon = cogBtnIcon

    cogBtn:SetScript("OnMouseDown", function(self)
        if self.icon then
            self.icon:SetAtlas("Map-Filter-Button-down", true)
        end
    end)
    cogBtn:SetScript("OnMouseUp", function(self)
        if self.icon then
            self.icon:SetAtlas("Map-Filter-Button", true)
        end
    end)
    cogBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("World Quest Filter", 1, 1, 1)
        GameTooltip:Show()
    end)
    cogBtn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- ── Filter/sort dropdown (shown/hidden by cogBtn) ─────────────────────
    local DROP_W = 200
    local dropFrame = CreateFrame("Frame", "NomToolsWQFilterDrop", panel,
                                  "BackdropTemplate")
    dropFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dropFrame:SetWidth(DROP_W)
    dropFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -(SEARCH_H + 8))
    dropFrame:SetFrameLevel((panel:GetFrameLevel() or 2) + 20)
    dropFrame:Hide()

    -- Close dropdown when clicking anywhere outside it
    dropFrame:EnableMouse(true)
    local dropCloseListener = CreateFrame("Frame", nil, UIParent)
    dropCloseListener:EnableMouse(true)
    dropCloseListener:SetAllPoints(UIParent)
    dropCloseListener:SetFrameLevel(dropFrame:GetFrameLevel() - 1)
    dropCloseListener:Hide()
    dropCloseListener:SetScript("OnMouseDown", function()
        dropFrame:Hide()
        dropCloseListener:Hide()
    end)

    -- Helper: create a section header label inside the dropdown.
    local function AddDropHeader(yPos, text)
        local lbl = dropFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", dropFrame, "TOPLEFT", 8, yPos)
        lbl:SetText(text)
        lbl:SetTextColor(0.8, 0.72, 0.42)
        return lbl
    end

    -- Helper: build one row in the dropdown.
    -- Anchors TOP to anchor.BOTTOM (vertical position) and LEFT/RIGHT to
    -- dropFrame (full-width span — avoids text truncation from FontString anchors).
    local function AddDropButton(anchor, yOff, labelText, onClick)
        local btn = CreateFrame("Button", nil, dropFrame)
        btn:SetHeight(18)
        btn:SetPoint("TOP",   anchor,    "BOTTOM",  0, yOff)
        btn:SetPoint("LEFT",  dropFrame, "LEFT",    4, 0)
        btn:SetPoint("RIGHT", dropFrame, "RIGHT",  -4, 0)

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

    -- Build dropdown content.
    -- Section order: Zone Sort → Quest Sort → Quest Type → Reward Type.
    local curY = -8

    -- ── Zone sort section ─────────────────────────────────────────────────
    local zoneSortHeader = AddDropHeader(curY, "Zone Sort")
    curY = curY - 18

    local zoneSortButtons = {}
    local ZONE_SORT_DEFS = {
        { key = "time",  label = "Time Left" },
        { key = "alpha", label = "Alphabetical" },
    }

    local function UpdateZoneSortChecks()
        for _, zb in ipairs(zoneSortButtons) do
            zb.checkmark:SetShown(zb.sortKey == zoneSortMode)
        end
    end

    local lastZoneSortAnchor = zoneSortHeader
    for _, def in ipairs(ZONE_SORT_DEFS) do
        local zb = AddDropButton(lastZoneSortAnchor, -2, def.label, function()
            zoneSortMode = def.key
            SaveFilterState()
            UpdateZoneSortChecks()
            ScheduleRefresh()
            eventFrame:UpdateWQFilterResetState()
        end)
        zb.sortKey = def.key
        zoneSortButtons[#zoneSortButtons + 1] = zb
        lastZoneSortAnchor = zb
        curY = curY - 20
    end

    local divZoneSort = dropFrame:CreateTexture(nil, "ARTWORK")
    divZoneSort:SetHeight(1)
    divZoneSort:SetPoint("TOPLEFT",  dropFrame, "TOPLEFT",  8, curY - 4)
    divZoneSort:SetPoint("TOPRIGHT", dropFrame, "TOPRIGHT", -8, curY - 4)
    divZoneSort:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    curY = curY - 12

    -- ── Quest sort section ────────────────────────────────────────────────
    local sortHeader = AddDropHeader(curY, "Quest Sort")
    curY = curY - 18

    local sortButtons = {}
    local SORT_DEFS = {
        { key = "time",    label = "Time Left" },
        { key = "alpha",   label = "Alphabetical" },
        { key = "reward",  label = "Reward Type" },
        { key = "faction", label = "Faction" },
    }

    local function UpdateQuestSortChecks()
        for _, sb in ipairs(sortButtons) do
            sb.checkmark:SetShown(sb.sortKey == sortMode)
        end
    end

    local lastSortAnchor = sortHeader
    for _, def in ipairs(SORT_DEFS) do
        local sb = AddDropButton(lastSortAnchor, -2, def.label, function()
            sortMode = def.key
            SaveFilterState()
            UpdateQuestSortChecks()
            ScheduleRefresh()
            eventFrame:UpdateWQFilterResetState()
        end)
        sb.sortKey = def.key
        sortButtons[#sortButtons + 1] = sb
        lastSortAnchor = sb
        curY = curY - 20
    end

    -- Divider 1
    local div1 = dropFrame:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT",  dropFrame, "TOPLEFT",  8, curY - 4)
    div1:SetPoint("TOPRIGHT", dropFrame, "TOPRIGHT", -8, curY - 4)
    div1:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    curY = curY - 12

    -- ── Quest type filter section (multi-select) ──────────────────────────
    local typeHeader = AddDropHeader(curY, "Quest Type")
    curY = curY - 18

    local typeButtons = {}
    local function UpdateTypeChecks()
        for _, tb in ipairs(typeButtons) do
            -- Checkmark = shown (not excluded); exclusion-set semantics.
            tb.checkmark:SetShown(not filterTypes[tb.typeKey])
        end
    end

    local lastTypeAnchor = typeHeader
    for _, typeKey in ipairs(QUEST_TYPE_ORDER) do
        local lbl = QUEST_TYPE_LABEL[typeKey]
        local tb = AddDropButton(lastTypeAnchor, -2, lbl, function()
            if filterTypes[typeKey] then
                filterTypes[typeKey] = nil   -- remove from exclusion → show
            else
                filterTypes[typeKey] = true  -- add to exclusion → hide
            end
            SaveFilterState()
            UpdateTypeChecks()
            ScheduleRefresh()
            eventFrame:UpdateWQFilterResetState()
        end)
        tb.typeKey = typeKey
        typeButtons[#typeButtons + 1] = tb
        lastTypeAnchor = tb
        curY = curY - 20
    end

    -- Divider 2
    local div2 = dropFrame:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT",  dropFrame, "TOPLEFT",  8, curY - 4)
    div2:SetPoint("TOPRIGHT", dropFrame, "TOPRIGHT", -8, curY - 4)
    div2:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    curY = curY - 12

    -- ── Reward type filter section (multi-select) ─────────────────────────
    local rewardHeader = AddDropHeader(curY, "Reward Type")
    curY = curY - 18

    local rewardButtons = {}
    local function UpdateRewardChecks()
        for _, rb in ipairs(rewardButtons) do
            -- Checkmark = shown (not excluded); exclusion-set semantics.
            rb.checkmark:SetShown(not filterRewards[rb.rewardKey])
        end
    end

    local lastRewardAnchor = rewardHeader
    for _, rewardKey in ipairs(REWARD_TYPE_ORDER) do
        local lbl = REWARD_TYPE_LABEL[rewardKey]
        local rb = AddDropButton(lastRewardAnchor, -2, lbl, function()
            if filterRewards[rewardKey] then
                filterRewards[rewardKey] = nil   -- remove from exclusion → show
            else
                filterRewards[rewardKey] = true  -- add to exclusion → hide
            end
            SaveFilterState()
            UpdateRewardChecks()
            ScheduleRefresh()
            eventFrame:UpdateWQFilterResetState()
        end)
        rb.rewardKey = rewardKey
        rewardButtons[#rewardButtons + 1] = rb
        lastRewardAnchor = rb
        curY = curY - 20
    end

    -- ── Reset Filters button at bottom ────────────────────────────────
    local divReset = dropFrame:CreateTexture(nil, "ARTWORK")
    divReset:SetHeight(1)
    divReset:SetPoint("TOPLEFT",  dropFrame, "TOPLEFT",  8, curY - 4)
    divReset:SetPoint("TOPRIGHT", dropFrame, "TOPRIGHT", -8, curY - 4)
    divReset:SetColorTexture(0.3, 0.3, 0.3, 0.8)
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
        wipe(filterTypes)
        wipe(filterRewards)
        sortMode     = "time"
        zoneSortMode = "time"
        SaveFilterState()
        UpdateZoneSortChecks()
        UpdateQuestSortChecks()
        UpdateTypeChecks()
        UpdateRewardChecks()
        eventFrame:UpdateWQFilterResetState()
        ScheduleRefresh()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    resetBtn:SetScript("OnEnter", function()
        if not eventFrame:IsWQFilterDefault() then
            resetLabel:SetTextColor(1, 1, 1)
        else
            resetLabel:SetTextColor(0.5, 0.5, 0.5)
        end
    end)
    resetBtn:SetScript("OnLeave", function()
        resetLabel:SetTextColor(1, 0.82, 0)
    end)
    curY = curY - 22

    dropFrame:SetHeight(math.abs(curY) + 12)

    -- Cogwheel click: toggle dropdown and refresh all check states.
    cogBtn:SetScript("OnClick", function()
        if dropFrame:IsShown() then
            dropFrame:Hide()
            dropCloseListener:Hide()
        else
            UpdateZoneSortChecks()
            UpdateQuestSortChecks()
            UpdateTypeChecks()
            UpdateRewardChecks()
            dropFrame:Show()
            dropCloseListener:Show()
        end
        eventFrame:UpdateWQFilterResetState()
    end)

    -- ── Scroll frame (ScrollFrameTemplate provides a WowTrimScrollBar) ─────
    local sf = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")

    local FOOTER_H = 34
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(FOOTER_H)
    footer:Show()

    local footerText = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerText:SetPoint("TOPLEFT", footer, "TOPLEFT", 10, -6)
    footerText:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -10, 6)
    footerText:SetJustifyH("LEFT")
    footerText:SetJustifyV("MIDDLE")
    footerText:SetWordWrap(true)
    footerText:SetTextColor(
        COL.contractNotice[1], COL.contractNotice[2], COL.contractNotice[3])

    UpdateContractNoticeLayout = function()
        sf:ClearAllPoints()
        sf:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(SEARCH_H + 8))
        sf:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    end

    UpdateContractNoticeLayout()

    -- Reposition the scroll bar to float just outside the right edge so it
    -- does not eat into the content width (see EnhanceQoL DungeonPortals).
    if sf.ScrollBar then
        sf.ScrollBar:ClearAllPoints()
        sf.ScrollBar:SetPoint("TOPLEFT",    sf, "TOPRIGHT",    8,  2)
        sf.ScrollBar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 8, -4)
    end

    -- Scroll child
    local sc = CreateFrame("Frame", nil, sf)
    sc:SetSize(1, 1)
    sf:SetScrollChild(sc)

    -- "No active world quests" placeholder
    local noQuestsText = sc:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    noQuestsText:SetPoint("TOPLEFT", sc, "TOPLEFT", 14, -20)
    noQuestsText:SetText("No active world quests in this zone.")
    noQuestsText:SetTextColor(COL.noQuests[1], COL.noQuests[2], COL.noQuests[3])
    noQuestsText:Hide()

    -- Native QuestLog border frame
    local bf = CreateFrame("Frame", nil, panel, "QuestLogBorderFrameTemplate")
    bf:SetPoint("TOPLEFT",     sf, "TOPLEFT",     -3,  7)
    bf:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT",  3, -6)
    bf:SetFrameLevel((panel:GetFrameLevel() or 2) + 3)
    bf:EnableMouse(false)

    -- Mouse-wheel scrolling forwarded to the scroll frame controller
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        local ctrl = sf.GetScrollController and sf:GetScrollController()
        if ctrl and ctrl.OnMouseWheel then
            ctrl:OnMouseWheel(delta)
        else
            sf:SetVerticalScroll(
                math.max(0, sf:GetVerticalScroll() - delta * ROW_HEIGHT))
        end
    end)

    -- Re-anchor when QuestMapFrame or its ContentsAnchor resize
    if not QuestMapFrame._nomtoolsWQSizeHook then
        QuestMapFrame:HookScript("OnSizeChanged", AnchorPanel)
        QuestMapFrame._nomtoolsWQSizeHook = true
    end
    if QuestMapFrame.ContentsAnchor
        and not QuestMapFrame.ContentsAnchor._nomtoolsWQSizeHook then
        QuestMapFrame.ContentsAnchor:HookScript("OnSizeChanged", AnchorPanel)
        QuestMapFrame.ContentsAnchor._nomtoolsWQSizeHook = true
    end
    questMapPanel = panel
    scrollFrame   = sf
    scrollChild   = sc
    noQuestsLabel = noQuestsText
    contractNoticeFrame = footer
    contractNoticeLabel = footerText

    -- ── Tab button (uses Blizzard QuestLogTabButtonTemplate) ───────────────
    local tab = CreateFrame("Button", "NomToolsWQTab", QuestMapFrame,
                            "QuestLogTabButtonTemplate")
    -- Use valid atlases so the mixin's state machine doesn't log errors,
    -- but we'll keep the template Icon hidden and overlay our own texture.
    tab.activeAtlas   = "questlog-tab-icon-maplegend"
    tab.inactiveAtlas = "questlog-tab-icon-maplegend-inactive"
    tab.tooltipText   = "World Quests"
    tab.displayMode   = DISPLAY_MODE
    if tab.SetChecked then tab:SetChecked(false) end

    -- Hide the mixin-managed Icon and keep it hidden even if the mixin
    -- tries to Show() it or swap its atlas (same pattern as EnhanceQoL).
    if tab.Icon then
        tab.Icon:SetAlpha(0)
        if not tab.Icon._nomtoolsHook then
            hooksecurefunc(tab.Icon, "Show",     function(icon) icon:SetAlpha(0) end)
            hooksecurefunc(tab.Icon, "SetAtlas", function(icon) icon:SetAlpha(0) end)
            tab.Icon._nomtoolsHook = true
        end
    end

    -- Persistent custom icon texture.
    local WQ_ICON_PATH = "Interface\\AddOns\\NomTools\\media\\WorldQuest_POI.png"
    local customIcon = tab:CreateTexture(nil, "ARTWORK")
    customIcon:SetPoint("CENTER", -2, 0)
    customIcon:SetSize(20, 20)
    customIcon:SetTexture(WQ_ICON_PATH)
    tab.CustomIcon = customIcon

    -- Match Blizzard tab behavior: selected state uses highlight/checked visuals;
    -- icon desaturation reflects disabled state only.
    if not tab._nomtoolsStateHooks then
        hooksecurefunc(tab, "Disable", function(self)
            if self.CustomIcon then self.CustomIcon:SetDesaturated(true) end
        end)
        hooksecurefunc(tab, "Enable", function(self)
            if self.CustomIcon then self.CustomIcon:SetDesaturated(false) end
        end)
        tab._nomtoolsStateHooks = true
    end

    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText or "World Quests", 1, 1, 1)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tab:SetScript("OnMouseUp", function(self, btn, upInside)
        if btn ~= "LeftButton" or not upInside then return end
        RequestWorldQuestsDisplayMode("manual")
    end)

    questMapTab = tab

    -- Initial anchor + two deferred retries so that EQOL's tab (created in
    -- the same OnShow chain) is found even if it fires after our hook.
    RebuildTabAnchor()
    C_Timer.After(0,   RebuildTabAnchor)
    C_Timer.After(0.3, RebuildTabAnchor)

    -- ── Register with QuestMapFrame management tables ──────────────────────
    if QuestMapFrame.ContentFrames then
        local found = false
        for _, f in ipairs(QuestMapFrame.ContentFrames) do
            if f == panel then found = true; break end
        end
        if not found then table.insert(QuestMapFrame.ContentFrames, panel) end
    end

    if QuestMapFrame.TabButtons then
        local found = false
        for _, b in ipairs(QuestMapFrame.TabButtons) do
            if b == tab then found = true; break end
        end
        if not found then table.insert(QuestMapFrame.TabButtons, tab) end
    end

    if QuestMapFrame.ValidateTabs then QuestMapFrame:ValidateTabs() end

    -- ── React to display-mode changes ─────────────────────────────────────
    -- Primary: EventRegistry callback (fires for all SetDisplayMode calls)
    if EventRegistry and not displayHookRegistered then
        displayHookRegistered = true
        EventRegistry:RegisterCallback("QuestLog.SetDisplayMode",
            function(_, mode)
                if mode == DISPLAY_MODE then
                    eventFrame.isWorldQuestsDisplayActive = true
                    local settings = GetSettings()
                    if not IsModuleEnabled(settings) then
                        ClearPendingDisplayModeRequest()
                        RestoreBuiltinDisplayModeIfNeeded()
                        if not ShouldKeepCustomWorldQuestsVisible() then
                            if tab.SetChecked then tab:SetChecked(false) end
                            panel:Hide()
                        end
                        return
                    end
                    if tab.SetChecked then tab:SetChecked(true) end
                    panel:Show()
                    ScheduleRefresh()
                else
                    eventFrame.isWorldQuestsDisplayActive = false
                    ClearPendingBuiltinDisplayModeFallback()
                    if tab.SetChecked then tab:SetChecked(false) end
                    panel:Hide()
                end
            end, questMapPanel)
    end

    -- Secondary: hooksecurefunc as belt-and-suspenders
    if QuestMapFrame.SetDisplayMode
        and not QuestMapFrame._nomtoolsWQDisplayHook then
        hooksecurefunc(QuestMapFrame, "SetDisplayMode", function(_, mode)
            if mode == DISPLAY_MODE then
                eventFrame.isWorldQuestsDisplayActive = true
                local settings = GetSettings()
                if not IsModuleEnabled(settings) then
                    ClearPendingDisplayModeRequest()
                    RestoreBuiltinDisplayModeIfNeeded()
                    if not ShouldKeepCustomWorldQuestsVisible() then
                        panel:Hide()
                    end
                    return
                end
                panel:Show()
                ScheduleRefresh()
            else
                eventFrame.isWorldQuestsDisplayActive = false
                ClearPendingBuiltinDisplayModeFallback()
                panel:Hide()
            end
        end)
        QuestMapFrame._nomtoolsWQDisplayHook = true
    end
end

-- =============================================
-- Public API
-- =============================================

-- Called by the options panel after resetting settings so that the runtime
-- filter locals re-sync from the DB and the quest list refreshes.
function ns.SyncAndRefreshWorldQuests(clearSearch)
    SyncFilterState(clearSearch == true)
    eventFrame:UpdateWQFilterResetState()
    ApplyWorldQuestTypography()
    if questMapPanel and questMapPanel:IsShown() then
        ScheduleRefresh()
    end
end

-- Public refresh callback (called by NomTools core)
function ns.RefreshWorldQuestsUI()
    local s = GetSettings()
    if not IsModuleEnabled(s) then
        eventFrame:ResetWorldQuestsRefreshGateState()
        ClearPendingDisplayModeRequest()
        RestoreBuiltinDisplayModeIfNeeded()
        if not ShouldKeepCustomWorldQuestsVisible() then
            if questMapPanel then questMapPanel:Hide() end
            if questMapTab   then questMapTab:Hide()   end
        end
        return
    end

    -- Ensure tab exists; show it
    if not questMapPanel then
        CreateQuestMapTab()
    end
    if questMapTab then questMapTab:Show() end

    -- Content refresh only while the panel is visible
    if questMapPanel and questMapPanel:IsShown() then
        ScheduleRefresh()
    end
end

-- =============================================
-- Module initialization (called by NomTools core after addon load)
-- =============================================
function ns.InitializeWorldQuestsModule()
    eventFrame.isWorldQuestsDisplayActive = false

    local s = GetSettings()
    if not IsModuleEnabled(s) then
        return
    end

    -- Load persisted filter/sort state before first refresh.
    SyncFilterState(true)
    eventFrame:UpdateWQFilterResetState()

    -- Build the tab and panel (deferred by one tick if QuestMapFrame children
    -- are not fully initialised yet — ContentsAnchor may have zero size).
    if QuestMapFrame then
        CreateQuestMapTab()
    else
        -- QuestMapFrame is always present in retail but guard just in case.
        eventFrame:RegisterEvent("PLAYER_LOGIN")
    end

    -- Re-inject whenever the World Map first opens (handles deferred loads and
    -- ensures ValidateTabs is called after Blizzard finishes building its tab list).
    -- A short deferred anchor re-check corrects positions when EQOL or other
    -- addons create their own tabs in a later OnShow hook in the same frame.
    WorldMapFrame:HookScript("OnShow", function()
        local settings = GetSettings()
        if not IsModuleEnabled(settings) then
            ClearPendingDisplayModeRequest()
            return
        end
        CreateQuestMapTab()   -- no-op if already created
        if QuestMapFrame and QuestMapFrame.ValidateTabs then
            QuestMapFrame:ValidateTabs()
        end
        -- Re-anchor after all addons' OnShow hooks have had a chance to run
        -- and register their own tabs into QuestMapFrame.TabButtons.
        if questMapTab then
            C_Timer.After(0, RebuildTabAnchor)
        end
        if settings.openOnWorldQuestsTab == true and QuestMapFrame and QuestMapFrame.SetDisplayMode then
            C_Timer.After(0, function()
                RequestWorldQuestsDisplayMode("auto")
            end)
        end
        if ns.IsWorldQuestsRefreshContextActive() then
            ScheduleRefresh()
        end
    end)

    WorldMapFrame:HookScript("OnHide", function()
        eventFrame.isWorldQuestsDisplayActive = false
        eventFrame:ResetWorldQuestsRefreshGateState()
        ClearPendingDisplayModeRequest()
    end)

    -- Hook map navigation so the panel refreshes on zone/continent changes.
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        eventFrame:HandleWorldMapChanged()
    end)

    -- Register events.
    -- QUEST_LOG_UPDATE and UI widget update events are registered/unregistered
    -- dynamically while the visible World Quests panel has relevant rows or
    -- pending data.
    eventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
    eventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    eventFrame:RegisterEvent("AREA_POIS_UPDATED")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LOGIN" then
            eventFrame:UnregisterEvent("PLAYER_LOGIN")
            CreateQuestMapTab()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingBuiltinDisplayModeFallback then
                RestoreBuiltinDisplayModeIfNeeded()
            end
            if pendingDisplayModeSource then
                RequestWorldQuestsDisplayMode(pendingDisplayModeSource)
            else
                UpdateDisplayModeRetryRegistration()
            end
            local settings = GetSettings()
            if not IsModuleEnabled(settings) and not ShouldKeepCustomWorldQuestsVisible() then
                if questMapPanel then questMapPanel:Hide() end
                if questMapTab   then questMapTab:Hide()   end
            end
        elseif event == "SUPER_TRACKING_CHANGED" then
            if ns.IsWorldQuestsRefreshContextActive() then
                UpdateSuperTrackHighlights()
            end
        elseif event == "QUEST_DATA_LOAD_RESULT" then
            local questID, success = ...
            if questID then
                if success then
                    -- Clear stale cache so re-query picks up real data.
                    questTypeCache[questID] = nil
                    if eventFrame:IsQuestCoreDataReady(questID) then
                        requestedQuestData[questID] = nil
                        questDataRetrySuppressedUntil[questID] = nil
                    else
                        requestedQuestData[questID] = nil
                        questDataRetrySuppressedUntil[questID] = GetTime() + 1
                    end

                    local rowNeedsUpdate, needsFullRefresh, searchRefreshOnRewardReady = ResolvePendingQuestDataState(questID)
                    if rowNeedsUpdate and ns.IsWorldQuestsRefreshContextActive() then
                        local rowUpdated, rowNeedsFullRefresh = eventFrame:UpdateQuestRow(questID)
                        if rowNeedsFullRefresh
                            or (searchRefreshOnRewardReady and not rowUpdated)
                        then
                            needsFullRefresh = true
                        end
                    elseif searchRefreshOnRewardReady and ns.IsWorldQuestsRefreshContextActive() then
                        needsFullRefresh = true
                    end
                    if needsFullRefresh then
                        ScheduleRefresh(false)
                    end
                    if ns.IsWorldQuestsRefreshContextActive() then
                        eventFrame:RefreshActiveQuestTooltipIfReady(questID)
                    end
                else
                    SuppressPendingQuestDataAfterFailure(questID)
                end
                EnsureQuestDataRetryRefresh()
                UpdateQuestLogUpdateRegistration()
            end
        elseif event == "QUEST_LOG_UPDATE" then
            if not ns.IsWorldQuestsRefreshContextActive() then
                EnsureQuestDataRetryRefresh()
                UpdateQuestLogUpdateRegistration()
                return
            end

            local activeMapID = WorldMapFrame and WorldMapFrame.mapID or nil
            local queryState = activeMapID
                and eventFrame:BuildRelevantWorldQuestMapQueryState(activeMapID)
                or nil
            local hasRelevantWorldQuestQuerySignatureChange,
                previousRelevantWorldQuestQuerySignature,
                discoveredRelevantWorldQuestQuerySignature =
                    eventFrame:HasRelevantWorldQuestQuerySignatureChange(activeMapID, queryState)

            if hasRelevantWorldQuestQuerySignatureChange then
                layoutGeneration = layoutGeneration + 1
                rewardPreloadState.CancelDrain()
                eventFrame:CancelWorldQuestDescendantGather()
                wipe(eventFrame._sessionScannedQueryMapIDs)
                wipe(eventFrame._sessionRawEntries)
                wipe(eventFrame._sessionRawEntriesSeen)
                wipe(eventFrame._sessionEnrichedEntries)
                wipe(eventFrame._sessionEnrichedEntriesSeen)
                wipe(eventFrame._sessionQueryStateCache)
                if ns.IsDebugEnabled() then
                    eventFrame:DebugWorldQuestsRefreshTrace(
                        "QUEST_LOG_UPDATE relevant-map signature",
                        string_format(
                            "mapID=%s previousSignature=%s discoveredSignature=%s",
                            tostring(activeMapID),
                            tostring(previousRelevantWorldQuestQuerySignature),
                            tostring(discoveredRelevantWorldQuestQuerySignature)))
                end
                if activeHoverState.questID then
                    DebugHoverTrace(
                        "QUEST_LOG_UPDATE",
                        "trigger-refresh reason=relevant-map-signature mapID=%s activeQuestID=%s",
                        tostring(activeMapID),
                        tostring(activeHoverState.questID))
                end
                ScheduleRefresh(false, "QUEST_LOG_UPDATE relevant-map signature")
                EnsureQuestDataRetryRefresh()
                UpdateQuestLogUpdateRegistration()
                return
            end

            if ns.HasCompletedStagedDescendantGatherQuestMembershipChange(activeMapID, queryState) then
                layoutGeneration = layoutGeneration + 1
                rewardPreloadState.CancelDrain()
                eventFrame:CancelWorldQuestDescendantGather()
                wipe(eventFrame._sessionScannedQueryMapIDs)
                wipe(eventFrame._sessionRawEntries)
                wipe(eventFrame._sessionRawEntriesSeen)
                wipe(eventFrame._sessionEnrichedEntries)
                wipe(eventFrame._sessionEnrichedEntriesSeen)
                wipe(eventFrame._sessionQueryStateCache)
                if ns.IsDebugEnabled() then
                    eventFrame:DebugWorldQuestsRefreshTrace(
                        "QUEST_LOG_UPDATE staged quest membership",
                        string_format("mapID=%s", tostring(activeMapID)))
                end
                if activeHoverState.questID then
                    DebugHoverTrace(
                        "QUEST_LOG_UPDATE",
                        "trigger-refresh reason=staged-quest-membership mapID=%s activeQuestID=%s",
                        tostring(activeMapID),
                        tostring(activeHoverState.questID))
                end
                ScheduleRefresh(false, "QUEST_LOG_UPDATE staged quest membership")
                EnsureQuestDataRetryRefresh()
                UpdateQuestLogUpdateRegistration()
                return
            end

            -- QUEST_LOG_UPDATE fires broadly.  Only act for the active World
            -- Quests panel when visible rows can change or pending data resolves.
            local needsUnlockRefresh = HasVisibleLockedSpecialAssignmentUnlock()
            local needsLockedAreaPOIRefresh = eventFrame:HasVisibleLockedAreaPOIStateChange()
            local needsVisibleQuestRefresh = ns.HasVisibleQuestRemoval()
            if next(pendingQuestIDs) then
                local needsFullRefresh = false
                for qid in pairs(pendingQuestIDs) do
                    local pendingState = pendingQuestIDs[qid]
                    if rewardPreloadState.pollActive
                        and pendingState
                        and pendingState.needsRewardData
                        and not pendingState.needsQuestData
                    then
                        -- Poll handles reward-data-only resolution
                    else
                        local rowNeedsUpdate, questNeedsFullRefresh, searchRefreshOnRewardReady = ResolvePendingQuestDataState(qid)
                        if rowNeedsUpdate then
                            local rowUpdated, rowNeedsFullRefresh = eventFrame:UpdateQuestRow(qid)
                            eventFrame:RefreshActiveQuestTooltipIfReady(qid)
                            if rowNeedsFullRefresh
                                or (searchRefreshOnRewardReady and not rowUpdated)
                            then
                                needsFullRefresh = true
                            end
                        elseif searchRefreshOnRewardReady then
                            needsFullRefresh = true
                        end
                        if questNeedsFullRefresh then
                            needsFullRefresh = true
                        end
                    end
                end
                if needsFullRefresh or needsUnlockRefresh
                    or needsLockedAreaPOIRefresh or needsVisibleQuestRefresh
                then
                    if activeHoverState.questID then
                        DebugHoverTrace(
                            "QUEST_LOG_UPDATE",
                            "trigger-refresh reason=visible-or-pending-change mapID=%s activeQuestID=%s",
                            tostring(activeMapID),
                            tostring(activeHoverState.questID))
                    end
                    ScheduleRefresh(false)
                end
                EnsureQuestDataRetryRefresh()
                UpdateQuestLogUpdateRegistration()
            else
                if needsUnlockRefresh or needsLockedAreaPOIRefresh
                    or needsVisibleQuestRefresh
                then
                    if activeHoverState.questID then
                        DebugHoverTrace(
                            "QUEST_LOG_UPDATE",
                            "trigger-refresh reason=visible-change-no-pending mapID=%s activeQuestID=%s",
                            tostring(activeMapID),
                            tostring(activeHoverState.questID))
                    end
                    ScheduleRefresh(false)
                end
                EnsureQuestDataRetryRefresh()
                UpdateQuestLogUpdateRegistration()
            end
        elseif event == "UPDATE_UI_WIDGET" then
            local widgetInfo = ...
            eventFrame:HandleLockedAreaPOIWidgetUpdated(widgetInfo)
        elseif event == "UPDATE_ALL_UI_WIDGETS" then
            eventFrame:HandleAllLockedAreaPOIWidgetsUpdated()
        elseif event == "AREA_POIS_UPDATED" then
            if activeHoverState.questID then
                DebugHoverTrace(
                    "AREA_POIS_UPDATED",
                    "event-branch activeQuestID=%s dispatch=HandleAreaPOIsUpdated",
                    tostring(activeHoverState.questID))
            end
            eventFrame:HandleAreaPOIsUpdated()
        elseif event == "UNIT_AURA" then
            local previousSpellID = currentRelevantContract and currentRelevantContract.spellID or nil
            local previousAuraInstanceID = currentRelevantContract and currentRelevantContract.auraInstanceID or nil
            local previousFactionName = currentRelevantContract and currentRelevantContract.normalizedFactionName or nil
            RefreshContractNotice()
            local currentSpellID = currentRelevantContract and currentRelevantContract.spellID or nil
            local currentAuraInstanceID = currentRelevantContract and currentRelevantContract.auraInstanceID or nil
            local currentFactionName = currentRelevantContract and currentRelevantContract.normalizedFactionName or nil
            if previousSpellID ~= currentSpellID
                or previousAuraInstanceID ~= currentAuraInstanceID
            then
                if ns.IsWorldQuestsRefreshContextActive() then
                    local needsFullRefresh = false
                    for _, item in ipairs(activeContent) do
                        if item.type == "row" and item.frame and item.frame.questID then
                            local _, rowNeedsFullRefresh = eventFrame:UpdateQuestRow(item.frame.questID)
                            if rowNeedsFullRefresh then
                                needsFullRefresh = true
                            end
                        end
                    end
                    if previousFactionName ~= currentFactionName
                        and (sortMode == "faction" or filterSearch ~= "")
                    then
                        needsFullRefresh = true
                    end
                    if needsFullRefresh then
                        ScheduleRefresh(false, "UNIT_AURA contract change")
                    end
                end
            end
        end
    end)

    -- If the World Map is already open at load time, populate immediately.
    if WorldMapFrame and WorldMapFrame:IsShown() then
        CreateQuestMapTab()
        if ns.IsWorldQuestsRefreshContextActive() then
            ScheduleRefresh()
        end
    end
end
