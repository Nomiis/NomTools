local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = rawget(_G, "NomTools")
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

if ns._menuBarImplementationLoaded then
    return
end

ns._menuBarImplementationLoaded = true

local MENU_BAR_CONFIG_KEY = "menuBar"
local QUEUE_EYE_CONFIG_KEY = "queueEye"
local MENU_BAR_EDIT_MODE_LABEL = "Menu Bar"
local QUEUE_EYE_EDIT_MODE_LABEL = "Queue Eye"
local MENU_BAR_SCALE_MIN = 0.7
local MENU_BAR_SCALE_MAX = 1.6
local EDIT_MODE_OFFSET_LIMIT = 10000

-- Prefer Blizzard's default menu owner so Blizzard remains the visibility
-- authority and NomTools only overrides placement.
local MENU_BAR_TARGET_NAMES = {
    "MicroMenuContainer",
    "MicroMenu",
    "MicroButtonAndBagsBar",
}

-- QueueStatusMinimapButton does not exist in retail mainline; only QueueStatusButton.
local QUEUE_EYE_TARGET_NAME = "QueueStatusButton"

local VALID_ANCHOR_POINTS = {
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    CENTER = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local MICRO_BUTTON_NAMES = {
    "CharacterMicroButton",
    "ProfessionMicroButton",
    "PlayerSpellsMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
}

local eventFrame = CreateFrame("Frame")
local menuBarHolder
local queueEyeHolder
local frameStates = {}
local pendingRefresh = false
local eventsRegistered = false
local menuBarRegisteredWithLEM = false
local queueEyeRegisteredWithLEM = false
local anchorState = {
    menuBarTarget = false,
    isLayouting = false,
}

-- Whether our hooks are currently blocking Blizzard's queue-eye self-anchoring.
local queueEyeHooksActive = false

local RestoreFrameState
local ReanchorFrameToHolder
local ReassertFrameAnchors

local function GetSettings()
    if ns.GetMenuBarSettings then
        return ns.GetMenuBarSettings()
    end

    return ns.DEFAULTS and ns.DEFAULTS.menuBar or {}
end

local function IsOptionsPreviewActive()
    return ns.GetActiveOptionsPreviewPage and ns.GetActiveOptionsPreviewPage() == "menu_bar"
end

local function IsModuleEnabled(settings)
    local miscSettings = ns.GetMiscellaneousSettings and ns.GetMiscellaneousSettings() or nil
    if not miscSettings or miscSettings.enabled == false then
        if ns.IsModuleRuntimeEnabled then
            return ns.IsModuleRuntimeEnabled("miscellaneous", false)
        end
        return false
    end

    local resolvedSettings = settings or GetSettings()
    local enabled = resolvedSettings and resolvedSettings.enabled
    if ns.IsModuleRuntimeEnabled then
        return ns.IsModuleRuntimeEnabled("menuBar", enabled)
    end

    return enabled ~= false
end

local function IsModuleActive()
    return IsModuleEnabled() or IsOptionsPreviewActive()
end

local function GetDefaultMenuBarConfig()
    return ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.menuBar or {
        point = "CENTER",
        x = 0,
        y = 0,
    }
end

local function GetDefaultQueueEyeConfig()
    return ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.queueEye or {
        point = "CENTER",
        x = 0,
        y = 0,
    }
end

local function GetMenuBarConfig(layoutName)
    return ns.GetEditModeConfig and ns.GetEditModeConfig(MENU_BAR_CONFIG_KEY, GetDefaultMenuBarConfig(), layoutName) or GetDefaultMenuBarConfig()
end

local function GetQueueEyeConfig(layoutName)
    return ns.GetEditModeConfig and ns.GetEditModeConfig(QUEUE_EYE_CONFIG_KEY, GetDefaultQueueEyeConfig(), layoutName) or GetDefaultQueueEyeConfig()
end

local function GetQueueEyeAttachSettings()
    local settings = GetSettings()
    if settings and settings.queueEye then
        return settings.queueEye
    end
    return ns.DEFAULTS and ns.DEFAULTS.menuBar and ns.DEFAULTS.menuBar.queueEye or {}
end

local function ClampScale(value)
    local numeric = tonumber(value)
    if not numeric then
        return 1
    end
    if numeric < MENU_BAR_SCALE_MIN then
        return MENU_BAR_SCALE_MIN
    end
    if numeric > MENU_BAR_SCALE_MAX then
        return MENU_BAR_SCALE_MAX
    end
    return numeric
end

local function GetMenuBarScale()
    local settings = GetSettings()
    local fallback = ns.DEFAULTS and ns.DEFAULTS.menuBar and ns.DEFAULTS.menuBar.scale or 1
    local value = settings and settings.scale
    if value == nil then
        value = fallback
    end
    return ClampScale(value)
end

local function GetQueueEyeScale()
    local attach = GetQueueEyeAttachSettings()
    local defaults = ns.DEFAULTS and ns.DEFAULTS.menuBar and ns.DEFAULTS.menuBar.queueEye or nil
    local fallback = defaults and defaults.scale or 1
    local value = attach and attach.scale
    if value == nil then
        value = fallback
    end
    return ClampScale(value)
end

local function ApplyFrameScale(frame, scale)
    if frame and frame.SetScale then
        frame:SetScale(ClampScale(scale))
    end
end

local function ApplyMenuBarTargetScale(target)
    ApplyFrameScale(target, GetMenuBarScale())
end

local function ApplyQueueEyeTargetScale(target)
    ApplyFrameScale(target, GetQueueEyeScale())
end

local function NormalizeAnchorPoint(point, fallback)
    local fallbackPoint = type(fallback) == "string" and fallback or "CENTER"
    if type(point) ~= "string" then
        return fallbackPoint
    end

    local normalizedPoint = string.upper(point)
    if VALID_ANCHOR_POINTS[normalizedPoint] then
        return normalizedPoint
    end

    return fallbackPoint
end

local function NormalizeEditModeOffset(value, fallback)
    local numeric = tonumber(value)
    if not numeric or numeric ~= numeric then
        numeric = tonumber(fallback) or 0
    end

    if numeric < -EDIT_MODE_OFFSET_LIMIT then
        return -EDIT_MODE_OFFSET_LIMIT
    end
    if numeric > EDIT_MODE_OFFSET_LIMIT then
        return EDIT_MODE_OFFSET_LIMIT
    end

    return numeric
end

local function FinalizeDefaultEditModePosition(configKey, defaults)
    if not configKey or not ns.MarkLegacyEditModePositionMigrated then
        return
    end

    if ns.ShouldMigrateLegacyEditModePosition and ns.ShouldMigrateLegacyEditModePosition(configKey) then
        if ns.GetEditModeConfig then
            ns.GetEditModeConfig(configKey, defaults or {})
        end
        ns.MarkLegacyEditModePositionMigrated(configKey)
    end
end

local function ApplyMenuBarPosition(layoutName)
    if not menuBarHolder then
        return
    end

    local config = GetMenuBarConfig(layoutName)
    local point = NormalizeAnchorPoint(config.point, "BOTTOMRIGHT")
    local offsetX = NormalizeEditModeOffset(config.x, -290)
    local offsetY = NormalizeEditModeOffset(config.y, 40)
    menuBarHolder:SetParent(UIParent)
    menuBarHolder:ClearAllPoints()
    menuBarHolder:SetPoint(point, UIParent, point, offsetX, offsetY)
end

local function ApplyQueueEyePosition(layoutName)
    if not queueEyeHolder then
        return
    end

    local attach = GetQueueEyeAttachSettings()
    if attach.attachToMinimap ~= false then
        -- Snap to the minimap frame using the configured anchor point.
        local minimap = _G.Minimap
        if minimap then
            local anchor = NormalizeAnchorPoint(attach.minimapAnchor, "BOTTOMLEFT")
            local offsetX = NormalizeEditModeOffset(attach.minimapOffsetX, 0)
            local offsetY = NormalizeEditModeOffset(attach.minimapOffsetY, 0)
            queueEyeHolder:SetParent(UIParent)
            queueEyeHolder:ClearAllPoints()
            queueEyeHolder:SetPoint(anchor, minimap, anchor, offsetX, offsetY)
            return
        end
    end

    -- Fallback: absolute Edit Mode position.
    local config = GetQueueEyeConfig(layoutName)
    local point = NormalizeAnchorPoint(config.point, "BOTTOMLEFT")
    local offsetX = NormalizeEditModeOffset(config.x, 10)
    local offsetY = NormalizeEditModeOffset(config.y, 10)
    queueEyeHolder:SetParent(UIParent)
    queueEyeHolder:ClearAllPoints()
    queueEyeHolder:SetPoint(point, UIParent, point, offsetX, offsetY)
end

local function GetMenuBarTarget()
    for _, frameName in ipairs(MENU_BAR_TARGET_NAMES) do
        local frame = _G[frameName]
        if frame then
            return frame, frameName
        end
    end
    return nil, nil
end

local function GetQueueEyeTarget()
    return _G[QUEUE_EYE_TARGET_NAME]
end

local function CaptureFrameState(key, frame)
    if not key or not frame then
        return
    end

    local existing = frameStates[key]
    if existing and existing.frame == frame then
        return
    end

    if existing then
        RestoreFrameState(key)
    end

    local state = {
        frame = frame,
        parent = frame.GetParent and frame:GetParent() or nil,
        scale = frame.GetScale and frame:GetScale() or 1,
        ignoreParentAlpha = frame.IsIgnoringParentAlpha and frame:IsIgnoringParentAlpha() or false,
        points = {},
    }

    if frame.GetNumPoints and frame.GetPoint then
        for pointIndex = 1, frame:GetNumPoints() do
            local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(pointIndex)
            state.points[pointIndex] = {
                point,
                relativeTo,
                relativePoint,
                offsetX,
                offsetY,
            }
        end
    end

    frameStates[key] = state
end

RestoreFrameState = function(key)
    local state = frameStates[key]
    if not state or not state.frame then
        return
    end

    local frame = state.frame

    if frame.SetParent and state.parent then
        frame:SetParent(state.parent)
    end
    if frame.SetScale then
        frame:SetScale(state.scale or 1)
    end
    if frame.ClearAllPoints then
        frame:ClearAllPoints()
    end
    if frame.SetIgnoreParentAlpha then
        frame:SetIgnoreParentAlpha(state.ignoreParentAlpha == true)
    end
    if frame.SetPoint then
        for _, pointData in ipairs(state.points) do
            frame:SetPoint(pointData[1], pointData[2], pointData[3], pointData[4], pointData[5])
        end
    end

    frameStates[key] = nil
end

local function SetFrameMouseEnabled(frame, enabled)
    if frame and frame.EnableMouse then
        frame:EnableMouse(enabled == true)
    end
end

local function SetMicroMenuMouseEnabled(enabled)
    for _, frameName in ipairs(MICRO_BUTTON_NAMES) do
        SetFrameMouseEnabled(_G[frameName], enabled)
    end
end

local function GetEffectiveFrameSize(frame, fallbackWidth, fallbackHeight)
    local width = frame and frame.GetWidth and frame:GetWidth() or nil
    local height = frame and frame.GetHeight and frame:GetHeight() or nil
    local scale = frame and frame.GetScale and frame:GetScale() or 1

    if type(width) ~= "number" or width <= 1 then
        width = fallbackWidth
    else
        width = math.floor((width * scale) + 0.5)
    end

    if type(height) ~= "number" or height <= 1 then
        height = fallbackHeight
    else
        height = math.floor((height * scale) + 0.5)
    end

    return math.max(1, width), math.max(1, height)
end

local function GetRenderedFrameSize(frame, fallbackWidth, fallbackHeight, relativeFrame)
    local width = frame and frame.GetWidth and frame:GetWidth() or nil
    local height = frame and frame.GetHeight and frame:GetHeight() or nil
    local frameScale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or nil
    local relativeScale = relativeFrame and relativeFrame.GetEffectiveScale and relativeFrame:GetEffectiveScale() or 1

    if type(width) ~= "number" or width <= 1 then
        width = fallbackWidth
    else
        local scaleRatio = 1
        if type(frameScale) == "number" and frameScale > 0 and type(relativeScale) == "number" and relativeScale > 0 then
            scaleRatio = frameScale / relativeScale
        end
        width = math.floor((width * scaleRatio) + 0.5)
    end

    if type(height) ~= "number" or height <= 1 then
        height = fallbackHeight
    else
        local scaleRatio = 1
        if type(frameScale) == "number" and frameScale > 0 and type(relativeScale) == "number" and relativeScale > 0 then
            scaleRatio = frameScale / relativeScale
        end
        height = math.floor((height * scaleRatio) + 0.5)
    end

    return width, height
end

local function HidePlaceholder(frame)
    if ns.HideEditModePlaceholder and frame then
        ns.HideEditModePlaceholder(frame)
    end
end

local function ShowPlaceholder(frame, label, width, height)
    if ns.ShowEditModePlaceholder and frame then
        ns.ShowEditModePlaceholder(frame, label, width, height)
    end
end

local function GetMenuBarMeasuredFrame(target)
    local microMenu = _G["MicroMenu"]
    if target == _G["MicroMenuContainer"] and microMenu and microMenu:GetParent() == target then
        return microMenu
    end

    return target
end

local function ResizeMenuBarContainer()
    local container = _G["MicroMenuContainer"]
    local microMenu = _G["MicroMenu"]
    if not queueEyeHooksActive or not container or not microMenu or microMenu:GetParent() ~= container then
        return
    end

    local width, height = GetEffectiveFrameSize(microMenu, 180, 32)
    container:SetSize(width, height)
    if microMenu.Layout and container:GetCenter() then
        microMenu:Layout()
    end
end

local function ReassertMenuBarTargetAnchor()
    local state = frameStates["menuBarTarget"]
    local frame = state and state.frame or nil
    if not frame or not menuBarHolder or not IsModuleActive() then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingRefresh = true
        return
    end

    if anchorState.menuBarTarget then
        return
    end

    anchorState.menuBarTarget = true

    if not ns.isEditMode then
        ApplyMenuBarPosition(ns.activeLayoutName)
    end

    ApplyMenuBarTargetScale(frame)

    ReanchorFrameToHolder("menuBarTarget", menuBarHolder)
    ResizeMenuBarContainer()

    anchorState.menuBarTarget = false
end

-- ─ Blizzard hook intercepts ───────────────────────────────────────────────────
--
-- Two Blizzard routines fight NomTools's independent queue-eye placement:
--
--   1. QueueStatusButton:UpdatePosition()  - re-anchors the eye to MicroMenu's
--      edge every time a queue event fires or MicroMenu lays out.
--
--   2. MicroMenuContainer:Layout()         - sizes the container to include the
--      eye button (with an offset gap), so the holder gets the wrong width.
--
-- We install thin wrappers that short-circuit both when our module is active.
-- The wrappers are installed once; queueEyeHooksActive gates their effect.

local function InstallBlizzardHooks()
    -- Hook QueueStatusButton:UpdatePosition
    -- Use hooksecurefunc so Blizzard keeps control and NomTools only reapplies
    -- its detached placement after Blizzard updates the default anchor.
    local qsb = _G[QUEUE_EYE_TARGET_NAME]
    if qsb and qsb.UpdatePosition and not qsb._nomToolsUpdatePositionHooked then
        qsb._nomToolsUpdatePositionHooked = true
        hooksecurefunc(qsb, "UpdatePosition", function(self)
            if queueEyeHooksActive then
                if InCombatLockdown and InCombatLockdown() then
                    pendingRefresh = true
                    return
                end
                ApplyQueueEyeTargetScale(self)
                ApplyQueueEyePosition()
                ReanchorFrameToHolder("queueEyeTarget", queueEyeHolder)
            end
        end)
    end

    local menuFrame = _G["MicroMenu"]
    local container = _G["MicroMenuContainer"]
    if menuFrame and menuFrame.ResetMicroMenuPosition and not menuFrame._nomToolsResetHooked then
        menuFrame._nomToolsResetHooked = true
        hooksecurefunc(menuFrame, "ResetMicroMenuPosition", function(self)
            if queueEyeHooksActive then
                ReassertFrameAnchors()
            end
        end)
    end

    -- Blizzard sizes MicroMenuContainer around both the button strip and the
    -- queue eye. When NomTools detaches the eye, shrink the container back to
    -- the actual menu strip after Blizzard finishes its normal layout.
    if container and container.Layout and not container._nomToolsLayoutHooked then
        container._nomToolsLayoutHooked = true
        hooksecurefunc(container, "Layout", function(self)
            if queueEyeHooksActive then
                if InCombatLockdown and InCombatLockdown() then
                    pendingRefresh = true
                    return
                end
                ResizeMenuBarContainer()
            end
        end)
    end

    -- MicroMenuContainer is itself a Blizzard edit-mode system. When action-bar
    -- transitions or Blizzard layout restores call ApplySystemAnchor(), the
    -- frame receives a fresh SetPoint to Blizzard's default owner chain. Re-pin
    -- it to the NomTools holder immediately after those external anchor writes.
    if container and container.SetPoint and not container._nomToolsSetPointHooked then
        container._nomToolsSetPointHooked = true
        hooksecurefunc(container, "SetPoint", function(self)
            if not anchorState.isLayouting then
                ReassertMenuBarTargetAnchor()
            end
        end)
    end
end

local function EnsureHolders()
    if not menuBarHolder then
        menuBarHolder = CreateFrame("Frame", addonName .. "MenuBarHolder", UIParent)
        menuBarHolder.editModeName = MENU_BAR_EDIT_MODE_LABEL
        menuBarHolder:SetFrameStrata("MEDIUM")
        menuBarHolder:EnableMouse(true)
        menuBarHolder:Hide()
        if ns.AttachEditModeSelectionProxy then
            ns.AttachEditModeSelectionProxy(menuBarHolder)
        end
    end

    if not queueEyeHolder then
        queueEyeHolder = CreateFrame("Frame", addonName .. "QueueEyeHolder", UIParent)
        queueEyeHolder.editModeName = QUEUE_EYE_EDIT_MODE_LABEL
        queueEyeHolder:SetFrameStrata("MEDIUM")
        queueEyeHolder:EnableMouse(true)
        queueEyeHolder:Hide()
        if ns.AttachEditModeSelectionProxy then
            ns.AttachEditModeSelectionProxy(queueEyeHolder)
        end
    end
end

local function MigratePositionFromFrame(configKey, frame, defaults)
    if not frame or not ns.MigrateLegacyEditModePosition or not ns.ShouldMigrateLegacyEditModePosition then
        return
    end

    if ns.ShouldMigrateLegacyEditModePosition(configKey) then
        ns.MigrateLegacyEditModePosition(configKey, frame, defaults)
    end
end

local function MigrateQueueEyeFallback()
    if not queueEyeHolder or not ns.MigrateLegacyEditModePosition or not ns.ShouldMigrateLegacyEditModePosition then
        return
    end

    if not ns.ShouldMigrateLegacyEditModePosition(QUEUE_EYE_CONFIG_KEY) then
        return
    end

    -- Fallback starting position: bottom-right corner, away from the menu bar.
    queueEyeHolder:SetParent(UIParent)
    queueEyeHolder:ClearAllPoints()
    queueEyeHolder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -200, 2)
    ns.MigrateLegacyEditModePosition(QUEUE_EYE_CONFIG_KEY, queueEyeHolder, GetDefaultQueueEyeConfig())
end

local function RegisterMenuBarFrame()
    if menuBarRegisteredWithLEM or not menuBarHolder or not ns.RegisterEditModeFrame then
        return
    end

    local defaults = GetMenuBarConfig()
    menuBarRegisteredWithLEM = ns.RegisterEditModeFrame(menuBarHolder, {
        label = MENU_BAR_EDIT_MODE_LABEL,
        defaults = {
            point = defaults.point,
            x = defaults.x,
            y = defaults.y,
        },
        applyLayout = ApplyMenuBarPosition,
        onPositionChanged = function(layoutName, point, x, y)
            local config = GetMenuBarConfig(layoutName)
            config.point = point
            config.x = x
            config.y = y
            ApplyMenuBarPosition(layoutName)
        end,
    }) == true
end

local function RegisterQueueEyeFrame()
    if queueEyeRegisteredWithLEM or not queueEyeHolder or not ns.RegisterEditModeFrame then
        return
    end

    local defaults = GetQueueEyeConfig()
    queueEyeRegisteredWithLEM = ns.RegisterEditModeFrame(queueEyeHolder, {
        label = QUEUE_EYE_EDIT_MODE_LABEL,
        defaults = {
            point = defaults.point,
            x = defaults.x,
            y = defaults.y,
        },
        applyLayout = ApplyQueueEyePosition,
        onPositionChanged = function(layoutName, point, x, y)
            local config = GetQueueEyeConfig(layoutName)
            config.point = point
            config.x = x
            config.y = y
            ApplyQueueEyePosition(layoutName)
        end,
    }) == true
end

local function AttachFrameToHolder(key, frame, holder)
    if not key or not frame or not holder then
        return false
    end

    CaptureFrameState(key, frame)

    if frame.ClearAllPoints and frame.SetPoint then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", holder, "CENTER")
    end

    return true
end

ReanchorFrameToHolder = function(key, holder)
    local state = key and frameStates[key] or nil
    local frame = state and state.frame or nil
    if not frame or not holder or not frame.ClearAllPoints or not frame.SetPoint then
        return false
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", holder, "CENTER")
    return true
end

local function DisableModule()
    queueEyeHooksActive = false

    SetMicroMenuMouseEnabled(true)
    SetFrameMouseEnabled(GetQueueEyeTarget(), true)

    RestoreFrameState("menuBarTarget")
    RestoreFrameState("queueEyeTarget")

    local container = _G["MicroMenuContainer"]
    if container and container.Layout then
        pcall(container.Layout, container)
    end

    HidePlaceholder(menuBarHolder)
    HidePlaceholder(queueEyeHolder)

    if menuBarHolder then
        menuBarHolder:Hide()
    end
    if queueEyeHolder then
        queueEyeHolder:Hide()
    end
end

local function LayoutMenuBar()
    local target = GetMenuBarTarget()
    anchorState.isLayouting = true

    -- First-time activation should use NomTools's default split-bar position,
    -- not Blizzard's current micro menu anchor.
    FinalizeDefaultEditModePosition(MENU_BAR_CONFIG_KEY, GetDefaultMenuBarConfig())
    RegisterMenuBarFrame()
    if not ns.isEditMode then
        ApplyMenuBarPosition()
    end

    if not target then
        RestoreFrameState("menuBarTarget")
        SetMicroMenuMouseEnabled(true)

        if ns.isEditMode or IsOptionsPreviewActive() then
            menuBarHolder:SetSize(180, 32)
            ShowPlaceholder(menuBarHolder, MENU_BAR_EDIT_MODE_LABEL, 180, 32)
            menuBarHolder:Show()
        else
            HidePlaceholder(menuBarHolder)
            menuBarHolder:Hide()
        end
        anchorState.isLayouting = false
        return
    end

    AttachFrameToHolder("menuBarTarget", target, menuBarHolder)

    local measuredFrame = GetMenuBarMeasuredFrame(target)
    ApplyMenuBarTargetScale(target)
    local width, height = GetRenderedFrameSize(measuredFrame, 180, 32, UIParent)
    menuBarHolder:SetSize(width, height)

    ResizeMenuBarContainer()

    SetMicroMenuMouseEnabled(not (ns.isEditMode or IsOptionsPreviewActive()))

    if ns.isEditMode or IsOptionsPreviewActive() then
        ShowPlaceholder(menuBarHolder, MENU_BAR_EDIT_MODE_LABEL, width, height)
        menuBarHolder:Show()
        anchorState.isLayouting = false
        return
    end

    HidePlaceholder(menuBarHolder)
    menuBarHolder:Hide()
    anchorState.isLayouting = false
end

local function LayoutQueueEye()
    local target = GetQueueEyeTarget()

    if not target then
        MigrateQueueEyeFallback()
    else
        MigratePositionFromFrame(QUEUE_EYE_CONFIG_KEY, target, GetDefaultQueueEyeConfig())
    end

    RegisterQueueEyeFrame()
    if not ns.isEditMode then
        ApplyQueueEyePosition()
    end

    if not target then
        RestoreFrameState("queueEyeTarget")

        if ns.isEditMode or IsOptionsPreviewActive() then
            queueEyeHolder:SetSize(32, 32)
            ShowPlaceholder(queueEyeHolder, QUEUE_EYE_EDIT_MODE_LABEL, 32, 32)
            queueEyeHolder:Show()
        else
            HidePlaceholder(queueEyeHolder)
            queueEyeHolder:Hide()
        end
        return
    end

    AttachFrameToHolder("queueEyeTarget", target, queueEyeHolder)

    ApplyQueueEyeTargetScale(target)
    local width, height = GetEffectiveFrameSize(target, 24, 24)
    queueEyeHolder:SetSize(width, height)
    SetFrameMouseEnabled(target, not (ns.isEditMode or IsOptionsPreviewActive()))

    if ns.isEditMode or IsOptionsPreviewActive() then
        ShowPlaceholder(queueEyeHolder, QUEUE_EYE_EDIT_MODE_LABEL, width, height)
        queueEyeHolder:Show()
        return
    end

    HidePlaceholder(queueEyeHolder)
    queueEyeHolder:Hide()
end

-- Re-asserts holder positions and target-to-holder anchors one frame after a
-- refresh, catching any same-frame Blizzard layout resets (e.g. PLAYER_ENTERING_WORLD).
ReassertFrameAnchors = function()
    if not menuBarHolder or not queueEyeHolder then
        return
    end

    if not IsModuleEnabled() and not IsOptionsPreviewActive() then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    -- In live mode re-apply saved positions; in edit mode LibEditMode owns
    -- the holders so leave them alone.
    if not ns.isEditMode then
        ApplyMenuBarPosition(ns.activeLayoutName)
        ApplyQueueEyePosition(ns.activeLayoutName)
    end

    local mbState = frameStates["menuBarTarget"]
    if mbState and mbState.frame then
        ApplyMenuBarTargetScale(mbState.frame)
        ReanchorFrameToHolder("menuBarTarget", menuBarHolder)
    end

    local qeState = frameStates["queueEyeTarget"]
    if qeState and qeState.frame then
        ApplyQueueEyeTargetScale(qeState.frame)
        ReanchorFrameToHolder("queueEyeTarget", queueEyeHolder)
    end

    ResizeMenuBarContainer()
end

local function DeferredMenuBarRefresh()
    if ns.RequestRefresh then
        ns.RequestRefresh("menuBar")
    end
end

local function UpdateEventRegistration(shouldRegister)
    if shouldRegister and not eventsRegistered then
        eventsRegistered = true
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("LFG_UPDATE")
        eventFrame:RegisterEvent("PET_BATTLE_QUEUE_STATUS")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
        eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_REGEN_ENABLED" and pendingRefresh then
                pendingRefresh = false
            end

            if event == "ADDON_LOADED" then
                local loadedAddon = ...
                if loadedAddon == "Blizzard_HouseEditor" then
                    eventFrame:RegisterEvent("HOUSE_EDITOR_MODE_CHANGED")
                end
                if loadedAddon and loadedAddon ~= addonName and not string.match(loadedAddon, "^Blizzard_") then
                    return
                end
            end

            if event == "HOUSE_EDITOR_MODE_CHANGED" then
                local mode = ...
                local noneMode = Enum.HouseEditorMode and Enum.HouseEditorMode.None
                local isExiting = (noneMode ~= nil and mode == noneMode) or (noneMode == nil and mode == nil)
                if isExiting then
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, DeferredMenuBarRefresh)
                    end
                else
                    if ns.RequestRefresh then
                        ns.RequestRefresh("menuBar")
                    end
                end
                return
            end

            if ns.RequestRefresh then
                ns.RequestRefresh("menuBar")
            end
        end)
        return
    end

    if not shouldRegister and eventsRegistered then
        eventsRegistered = false
        eventFrame:UnregisterEvent("ADDON_LOADED")
        eventFrame:UnregisterEvent("HOUSE_EDITOR_MODE_CHANGED")
        eventFrame:UnregisterEvent("LFG_UPDATE")
        eventFrame:UnregisterEvent("PET_BATTLE_QUEUE_STATUS")
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:UnregisterEvent("UPDATE_BATTLEFIELD_STATUS")
        eventFrame:SetScript("OnEvent", nil)
    end
end

function ns.InitializeMenuBarUI()
    EnsureHolders()
    UpdateEventRegistration(IsModuleActive())
end

function ns.RefreshMenuBarUI()
    EnsureHolders()
    UpdateEventRegistration(IsModuleActive())

    if InCombatLockdown and InCombatLockdown() then
        pendingRefresh = true
        return
    end

    if not IsModuleEnabled() and not IsOptionsPreviewActive() then
        pendingRefresh = false
        DisableModule()
        return
    end

    -- Install the one-time Blizzard hooks (idempotent after first call).
    InstallBlizzardHooks()
    -- Activate hook interception before layout so any Blizzard Layout() that
    -- fires during SetParent/attach already excludes the eye from sizing.
    queueEyeHooksActive = true

    pendingRefresh = false
    LayoutMenuBar()
    LayoutQueueEye()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, ReassertFrameAnchors)
    end
end
