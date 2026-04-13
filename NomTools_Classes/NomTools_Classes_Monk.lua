local addonName, ns = ...
local _G = _G

if addonName ~= "NomTools" then
    ns = _G["NomTools"]
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

local CreateFrame = CreateFrame
local C_AddOns = C_AddOns
local InCombatLockdown = InCombatLockdown
local IsMounted = IsMounted
local pcall = pcall
local UIParent = UIParent
local UnitAffectingCombat = UnitAffectingCombat
local UnitClassBase = UnitClassBase
local UnitClass = UnitClass
local C_SpecializationInfo = C_SpecializationInfo
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local floor = math.floor
local ceil = math.ceil
local abs = math.abs
local max = math.max
local min = math.min
local next = next
local select = select
local strgmatch = string.gmatch
local strmatch = string.match
local tonumber = tonumber
local type = type
local C_Spell = C_Spell
local C_PlayerInfo = C_PlayerInfo
local C_Timer = C_Timer
local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G["IsAddOnLoaded"]
local IsPlayerSkyriding = _G["IsPlayerSkyriding"]
local IsPlayerGliding = _G["IsPlayerGliding"]

local CONFIG_KEY = "monkChiBar"
local EDIT_MODE_LABEL = "Brewmaster Expel Harm Bar"
local BAR_FRAME_NAME = "NomToolsMonkChiBar"
local SPEC_MONK_BREWMASTER = 268
local BREWMASTER_RESOURCE_SPELL_ID = 322101
local BETTER_COOLDOWN_MANAGER_ADDON = "BetterCooldownManager"
local RUNTIME_SAMPLE_INTERVAL = 0.066
local SEGMENT_COUNT = 5
local PREVIEW_CURRENT_COUNT = 3
local PREVIEW_MAX_COUNT = 5
local DEFAULT_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local DEFAULT_BORDER_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local SECURE_VISIBILITY_COMBAT_CONDITION = "[combat] show; hide"
local DEFAULT_BACKGROUND_COLOR = { r = 0.05, g = 0.05, b = 0.05, a = 1 }
local DEFAULT_ACTIVE_COLOR = { r = 0.38, g = 0.86, b = 0.62, a = 1 }
local DEFAULT_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 1 }
local DEFAULT_DIVIDER_COLOR = { r = 0, g = 0, b = 0, a = 1 }
local VALID_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}
local ATTACH_TARGET_ORDER = {
    "none",
    "custom",
    "ui_parent",
    "player_frame",
    "target_frame",
    "focus_frame",
    "cast_bar",
    "power_bar",
    "secondary_power_bar",
    "bcdm_power_bar",
    "bcdm_secondary_power_bar",
}
local ATTACH_TARGETS_BY_KEY = {
    none = { key = "none", name = "Standalone" },
    custom = { key = "custom", name = "Custom" },
    ui_parent = { key = "ui_parent", name = "UI Parent", frameName = "UIParent" },
    player_frame = { key = "player_frame", name = "Player Frame", frameName = "PlayerFrame" },
    target_frame = { key = "target_frame", name = "Target Frame", frameName = "TargetFrame" },
    focus_frame = { key = "focus_frame", name = "Focus Frame", frameName = "FocusFrame" },
    cast_bar = { key = "cast_bar", name = "Cast Bar", resolverKey = "cast_bar" },
    power_bar = { key = "power_bar", name = "Power Bar", resolverKey = "power_bar" },
    secondary_power_bar = { key = "secondary_power_bar", name = "Secondary Power Bar", resolverKey = "secondary_power_bar" },
    bcdm_power_bar = {
        key = "bcdm_power_bar",
        name = "|cFF8080FFBCDM|r: Primary Resource Bar",
        frameName = "BCDM_PowerBar",
        addon = BETTER_COOLDOWN_MANAGER_ADDON,
    },
    bcdm_secondary_power_bar = {
        key = "bcdm_secondary_power_bar",
        name = "|cFF8080FFBCDM|r: Secondary Resource Bar",
        frameName = "BCDM_SecondaryPowerBar",
        addon = BETTER_COOLDOWN_MANAGER_ADDON,
    },
}

ns.MONK_CHI_BAR_VISIBILITY_CHOICES = {
    { key = "always", name = "Always" },
    { key = "combat", name = "Only In Combat" },
}

local barFrame
local fillFrame
local overlayFrame
local borderFrame
local backgroundTexture
local brewmasterStatusBar
local brewmasterTickTextures = {}
local eventFrame = CreateFrame("Frame")
local eventsRegistered = false
local registeredWithEditMode = false
local cachedSettings
local attachedTargetFrame
local pendingProtectedRefresh = false
local pendingVisibilityDriverRefresh = false
local IsForbiddenAttachFrame
local lastShown = false
local lastChi = -1
local lastMaxChi = -1
local lastLayoutWidth = -1
local lastLayoutHeight = -1
local lastLayoutGap = -1
local hookedTargetFrames = {}
local runtimeTicker
local runtimeTickerActive = false
local registeredSpecID
local activeVisibilityDriverCondition
local OnRuntimeTickerTick
local OnEvent
local UpdateEventRegistration

local function IsBetterCooldownManagerAvailable(frameName)
    local frame = frameName and _G[frameName] or nil
    return type(frame) == "table" and frame.GetObjectType ~= nil
end

local function IsAttachTargetChoiceAvailable(targetKey)
    local descriptor = ATTACH_TARGETS_BY_KEY[targetKey]
    if not descriptor then
        return false
    end

    if descriptor.addon == BETTER_COOLDOWN_MANAGER_ADDON then
        return IsBetterCooldownManagerAvailable(descriptor.frameName)
    end

    return true
end

local function IsKnownAttachTargetKey(targetKey)
    return type(targetKey) == "string" and ATTACH_TARGETS_BY_KEY[targetKey] ~= nil
end

local function BuildUnavailableAttachTargetChoice(targetKey)
    local descriptor = ATTACH_TARGETS_BY_KEY[targetKey]
    if not descriptor then
        return nil
    end

    return {
        key = descriptor.key,
        name = string.format("%s (unavailable)", descriptor.name),
        icon = descriptor.icon,
    }
end

local function RoundWholeNumber(value, fallback)
    value = tonumber(value)
    if value == nil then
        value = tonumber(fallback) or 0
    end

    if value >= 0 then
        return floor(value + 0.5)
    end

    return ceil(value - 0.5)
end

local function Clamp(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if value == nil then
        value = tonumber(fallback)
    end
    if value == nil then
        value = minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end

    return value
end

local function NormalizeColor(color, fallback)
    fallback = fallback or DEFAULT_ACTIVE_COLOR
    if type(color) ~= "table" then
        return {
            r = fallback.r,
            g = fallback.g,
            b = fallback.b,
            a = fallback.a,
        }
    end

    return {
        r = Clamp(color.r or color[1], 0, 1, fallback.r),
        g = Clamp(color.g or color[2], 0, 1, fallback.g),
        b = Clamp(color.b or color[3], 0, 1, fallback.b),
        a = Clamp(color.a or color[4], 0, 1, fallback.a),
    }
end

local function NormalizePoint(point, fallback)
    if type(point) == "string" and VALID_POINTS[point] then
        return point
    end

    return fallback or "CENTER"
end

local function NormalizeAttachTarget(targetKey, fallback)
    if IsKnownAttachTargetKey(targetKey) then
        return targetKey
    end

    if IsKnownAttachTargetKey(fallback) then
        return fallback
    end

    return "none"
end

local function NormalizeFramePath(value, fallback)
    if type(value) ~= "string" then
        value = fallback
    end

    if type(value) ~= "string" then
        return ""
    end

    value = strmatch(value, "^%s*(.-)%s*$") or ""
    if value == "" then
        return ""
    end

    return value
end

local function NormalizeVisibilityMode(mode)
    if mode == "always" then
        return "always"
    end

    return "combat"
end

local function NormalizeBorderSize(value, fallback)
    local resolved = RoundWholeNumber(value, fallback or 1)
    return max(-10, min(10, resolved))
end

local function CopyBorderInsets(insets, fallback)
    fallback = max(1, tonumber(fallback) or 1)
    if type(insets) ~= "table" then
        return {
            left = fallback,
            right = fallback,
            top = fallback,
            bottom = fallback,
        }
    end

    return {
        left = max(0, tonumber(insets.left) or fallback),
        right = max(0, tonumber(insets.right) or fallback),
        top = max(0, tonumber(insets.top) or fallback),
        bottom = max(0, tonumber(insets.bottom) or fallback),
    }
end

local function ResolveBorderStyle(textureKey, borderSize)
    local definition = ns.GetBorderTextureDefinition and ns.GetBorderTextureDefinition(textureKey) or nil
    local magnitude = max(1, abs(borderSize))
    local baseEdgeSize = max(1, tonumber(definition and definition.edgeSize) or 1)
    local scaleStep = max(0, tonumber(definition and definition.scaleStep) or 1)
    local edgeSize = baseEdgeSize

    if magnitude > 1 and (not definition or definition.supportsVariableThickness ~= false) then
        edgeSize = edgeSize + ((magnitude - 1) * scaleStep)
    end

    return {
        edgeFile = (definition and definition.path) or (ns.GetBorderTexturePath and ns.GetBorderTexturePath(textureKey)) or textureKey or DEFAULT_BORDER_TEXTURE,
        tile = definition and definition.tile ~= false or true,
        tileSize = max(1, tonumber(definition and definition.tileSize) or 8),
        baseEdgeSize = baseEdgeSize,
        edgeSize = max(1, edgeSize),
        insets = CopyBorderInsets(definition and definition.insets, max(1, floor(edgeSize / 4))),
    }
end

local function ApplyBorderLayout(target, signedSize, borderStyle)
    local magnitude = abs(signedSize)
    if magnitude == 0 or not target or not borderStyle then
        return 0
    end

    local layoutPadding = max(borderStyle.edgeSize - borderStyle.baseEdgeSize, 0)
    target:ClearAllPoints()
    if signedSize > 0 then
        target:SetPoint("TOPLEFT", barFrame, "TOPLEFT", -layoutPadding, layoutPadding)
        target:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", layoutPadding, -layoutPadding)
    else
        target:SetPoint("TOPLEFT", barFrame, "TOPLEFT", layoutPadding, -layoutPadding)
        target:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -layoutPadding, layoutPadding)
    end

    return borderStyle.edgeSize
end

local function ApplyBorderAppearance(borderSize, textureKey, color)
    if not borderFrame or not barFrame then
        return
    end

    local signedSize = NormalizeBorderSize(borderSize, 1)
    if signedSize == 0 then
        borderFrame:Hide()
        return
    end

    local borderStyle = ResolveBorderStyle(textureKey, signedSize)
    local renderedEdgeSize = ApplyBorderLayout(borderFrame, signedSize, borderStyle)
    if renderedEdgeSize == 0 then
        borderFrame:Hide()
        return
    end

    local previousBackdropInfo = borderFrame.nomtoolsBackdropInfo
    local backdropInfo = {
        edgeFile = borderStyle.edgeFile,
        tile = borderStyle.tile,
        tileSize = borderStyle.tileSize,
        edgeSize = renderedEdgeSize,
        insets = {
            left = borderStyle.insets.left,
            right = borderStyle.insets.right,
            top = borderStyle.insets.top,
            bottom = borderStyle.insets.bottom,
        },
    }
    borderFrame.nomtoolsBackdropInfo = backdropInfo

    if previousBackdropInfo and previousBackdropInfo.edgeFile ~= backdropInfo.edgeFile then
        borderFrame:SetBackdrop(nil)
    end

    borderFrame:SetBackdrop(backdropInfo)
    borderFrame:SetBackdropColor(0, 0, 0, 0)
    borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    borderFrame:Show()
end

local function GetDefaultSettings()
    return ns.DEFAULTS and ns.DEFAULTS.classes and ns.DEFAULTS.classes.monk or {
        moduleEnabled = true,
        enabled = false,
        visibility = {
            mode = "always",
            hideWhileSkyriding = false,
        },
        attach = {
            target = "secondary_power_bar",
            customFrameName = "",
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = -160,
            matchWidth = false,
        },
        appearance = {
            width = 180,
            height = 18,
            segmentGap = 2,
            texture = ns.GLOBAL_CHOICE_KEY,
            borderTexture = ns.GLOBAL_CHOICE_KEY,
            activeColor = DEFAULT_ACTIVE_COLOR,
            backgroundColor = DEFAULT_BACKGROUND_COLOR,
            borderColor = DEFAULT_BORDER_COLOR,
            dividerColor = DEFAULT_DIVIDER_COLOR,
            borderSize = 1,
        },
    }
end

local function GetDefaultStandaloneConfig()
    return ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.monkChiBar or {
        point = "CENTER",
        x = 0,
        y = -160,
    }
end

local function GetSettings()
    if ns.GetMonkChiBarSettings then
        return ns.GetMonkChiBarSettings()
    end

    return GetDefaultSettings()
end

---@param settings table
---@return table
local function NormalizeSettings(settings)
    local defaults = GetDefaultSettings()
    settings.visibility = type(settings.visibility) == "table" and settings.visibility or {}
    settings.attach = type(settings.attach) == "table" and settings.attach or {}
    settings.appearance = type(settings.appearance) == "table" and settings.appearance or {}

    if settings.moduleEnabled == nil then
        settings.moduleEnabled = defaults.moduleEnabled ~= false
    else
        settings.moduleEnabled = settings.moduleEnabled == true
    end
    settings.enabled = settings.enabled == true

    settings.visibility.mode = NormalizeVisibilityMode(settings.visibility.mode or defaults.visibility.mode)
    if settings.visibility.hideWhileSkyriding == nil then
        settings.visibility.hideWhileSkyriding = defaults.visibility.hideWhileSkyriding == true
    else
        settings.visibility.hideWhileSkyriding = settings.visibility.hideWhileSkyriding == true
    end

    settings.attach.target = NormalizeAttachTarget(settings.attach.target, defaults.attach.target)
    settings.attach.customFrameName = NormalizeFramePath(settings.attach.customFrameName, defaults.attach.customFrameName)
    settings.attach.point = NormalizePoint(settings.attach.point, defaults.attach.point)
    settings.attach.relativePoint = NormalizePoint(settings.attach.relativePoint, defaults.attach.relativePoint)
    settings.attach.x = RoundWholeNumber(Clamp(settings.attach.x, -4000, 4000, defaults.attach.x))
    settings.attach.y = RoundWholeNumber(Clamp(settings.attach.y, -4000, 4000, defaults.attach.y))
    settings.attach.matchWidth = settings.attach.matchWidth == true

    settings.appearance.width = RoundWholeNumber(Clamp(settings.appearance.width, 60, 1200, defaults.appearance.width))
    settings.appearance.height = RoundWholeNumber(Clamp(settings.appearance.height, 4, 64, defaults.appearance.height))
    settings.appearance.segmentGap = RoundWholeNumber(Clamp(settings.appearance.segmentGap, 0, 16, defaults.appearance.segmentGap))
    if type(settings.appearance.texture) ~= "string" or settings.appearance.texture == "" then
        settings.appearance.texture = defaults.appearance.texture
    end
    if type(settings.appearance.borderTexture) ~= "string" or settings.appearance.borderTexture == "" then
        settings.appearance.borderTexture = defaults.appearance.borderTexture
    end
    settings.appearance.activeColor = NormalizeColor(settings.appearance.activeColor, defaults.appearance.activeColor or DEFAULT_ACTIVE_COLOR)
    settings.appearance.backgroundColor = NormalizeColor(settings.appearance.backgroundColor, defaults.appearance.backgroundColor or DEFAULT_BACKGROUND_COLOR)
    settings.appearance.borderColor = NormalizeColor(settings.appearance.borderColor, defaults.appearance.borderColor or DEFAULT_BORDER_COLOR)
    settings.appearance.dividerColor = NormalizeColor(
        settings.appearance.dividerColor,
        defaults.appearance.dividerColor or defaults.appearance.borderColor or DEFAULT_DIVIDER_COLOR
    )
    settings.appearance.borderSize = NormalizeBorderSize(settings.appearance.borderSize, defaults.appearance.borderSize or 1)

    return settings
end

function ns.GetMonkChiBarAttachTargetChoices(selectedTargetKey)
    local choices = {}

    for _, key in ipairs(ATTACH_TARGET_ORDER) do
        if IsAttachTargetChoiceAvailable(key) then
            choices[#choices + 1] = ATTACH_TARGETS_BY_KEY[key]
        elseif key == selectedTargetKey and IsKnownAttachTargetKey(selectedTargetKey) then
            local unavailableChoice = BuildUnavailableAttachTargetChoice(selectedTargetKey)
            if unavailableChoice then
                choices[#choices + 1] = unavailableChoice
            end
        end
    end

    return choices
end

local function GetFrameCandidate(frame, frameName)
    if type(frame) == "table" and frame.GetObjectType then
        return frame, frameName
    end

    return nil, frameName
end

local function GetNamedFrame(frameName)
    return GetFrameCandidate(frameName and _G[frameName] or nil, frameName)
end

local function ResolveCustomNamedFrame(framePath)
    framePath = NormalizeFramePath(framePath, "")
    if framePath == "" then
        return nil, nil
    end

    local current = _G
    for segment in strgmatch(framePath, "[^%.]+") do
        if type(current) ~= "table" then
            return nil, framePath
        end

        current = current[segment]
        if current == nil then
            return nil, framePath
        end
    end

    return GetFrameCandidate(current, framePath)
end

local function CallFrameResolver(helperName)
    local helper = helperName and _G[helperName] or nil
    if type(helper) ~= "function" then
        return nil, helperName
    end

    local ok, frame = pcall(helper)
    if ok then
        return GetFrameCandidate(frame, helperName)
    end

    return nil, helperName
end

local function ResolveCastBarFrame()
    local frame, frameName = GetNamedFrame("PlayerCastingBarFrame")
    if frame then
        return frame, frameName
    end

    return GetNamedFrame("CastingBarFrame")
end

local function ResolvePrimaryPowerBarFrame()
    local frame, frameName = CallFrameResolver("PlayerFrame_GetManaBar")
    if frame then
        return frame, frameName
    end

    frame, frameName = GetNamedFrame("PlayerFrameManaBar")
    if frame then
        return frame, frameName
    end

    local playerFrame = _G["PlayerFrame"]
    local playerFrameContent = playerFrame and playerFrame.PlayerFrameContent or nil
    local playerFrameMain = playerFrameContent and playerFrameContent.PlayerFrameContentMain or nil
    local manaBarArea = playerFrameMain and playerFrameMain.ManaBarArea or nil

    frame, frameName = GetFrameCandidate(
        manaBarArea and manaBarArea.ManaBar or nil,
        "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar"
    )
    if frame then
        return frame, frameName
    end

    frame, frameName = GetFrameCandidate(
        manaBarArea and manaBarArea.PowerBar or nil,
        "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.PowerBar"
    )
    if frame then
        return frame, frameName
    end

    frame, frameName = GetFrameCandidate(manaBarArea, "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea")
    if frame then
        return frame, frameName
    end

    local personalResourceDisplay = _G["PersonalResourceDisplayFrame"]
    frame, frameName = GetFrameCandidate(
        personalResourceDisplay and personalResourceDisplay.PowerBar or nil,
        "PersonalResourceDisplayFrame.PowerBar"
    )
    if frame then
        return frame, frameName
    end

    return GetNamedFrame("UIWidgetPowerBarContainerFrame")
end

local function ResolveSecondaryPowerBarFrame()
    local frame, frameName = GetNamedFrame("MonkStaggerBar")
    if frame then
        return frame, frameName
    end

    frame, frameName = GetNamedFrame("MonkHarmonyBarFrame")
    if frame then
        return frame, frameName
    end

    frame, frameName = GetNamedFrame("EssencePlayerFrame")
    if frame then
        return frame, frameName
    end

    frame, frameName = GetNamedFrame("RuneFrame")
    if frame then
        return frame, frameName
    end

    frame, frameName = GetNamedFrame("PaladinPowerBarFrame")
    if frame then
        return frame, frameName
    end

    return nil, nil
end

local function ResolveDescriptorFrame(descriptor, settings)
    if not descriptor then
        return nil, nil
    end

    if descriptor.key == "custom" then
        local attach = settings and settings.attach or nil
        return ResolveCustomNamedFrame(attach and attach.customFrameName or nil)
    end

    if descriptor.resolverKey == "cast_bar" then
        return ResolveCastBarFrame()
    end

    if descriptor.resolverKey == "power_bar" then
        return ResolvePrimaryPowerBarFrame()
    end

    if descriptor.resolverKey == "secondary_power_bar" then
        return ResolveSecondaryPowerBarFrame()
    end

    return GetNamedFrame(descriptor.frameName)
end

---@param settings table|nil
---@return table|nil, string|nil, boolean
function ns.ResolveMonkChiBarAttachFrame(settings)
    local resolvedSettings = NormalizeSettings(settings or GetSettings())
    local attach = resolvedSettings.attach

    if attach.target == "none" then
        return nil, nil, true
    end

    local descriptor = ATTACH_TARGETS_BY_KEY[attach.target]
    local frame, frameName = ResolveDescriptorFrame(descriptor, resolvedSettings)
    if frame then
        if IsForbiddenAttachFrame(frame, frameName) then
            return nil, frameName, false
        end
        return frame, frameName, true
    end

    if attach.target == "custom" then
        return nil, frameName or attach.customFrameName, false
    end

    return nil, frameName or (descriptor and descriptor.frameName or nil), false
end

local function IsModuleEnabled(settings)
    local classesSettings = ns.GetClassesSettings and ns.GetClassesSettings() or nil
    if not classesSettings then
        return false
    end

    if ns.IsModuleActiveInSession then
        if not ns.IsModuleActiveInSession("classesMonk") then
            return false
        end
    else
        if classesSettings.enabled ~= true then
            return false
        end

        if ns.IsModuleRuntimeEnabled and not ns.IsModuleRuntimeEnabled("classesMonk", classesSettings.enabled) then
            return false
        end
    end

    local resolvedSettings = settings or GetSettings()
    return resolvedSettings and resolvedSettings.moduleEnabled == true or false
end

local function IsBarEnabled(settings)
    local resolvedSettings = settings or GetSettings()
    return resolvedSettings and resolvedSettings.enabled == true or false
end

local function IsOptionsPreviewActive()
    return ns.GetActiveOptionsPreviewPage and ns.GetActiveOptionsPreviewPage() == "classes_monk"
end

local function IsMonkCharacter()
    local classFile

    if UnitClassBase then
        local _, baseClassFile = UnitClassBase("player")
        if type(baseClassFile) == "string" then
            classFile = baseClassFile
        end
    end

    if classFile == nil and UnitClass then
        classFile = select(2, UnitClass("player"))
    end

    return classFile == "MONK"
end

local function GetPlayerSpecializationIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end

    if GetSpecialization then
        return GetSpecialization()
    end

    return nil
end

local function GetSpecializationInfoForIndex(index)
    if not index then
        return nil
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        return C_SpecializationInfo.GetSpecializationInfo(index)
    end

    if GetSpecializationInfo then
        return GetSpecializationInfo(index)
    end

    return nil
end

local function GetCurrentMonkSpecID()
    if not IsMonkCharacter() then
        return nil
    end

    local specIndex = GetPlayerSpecializationIndex()
    if not specIndex then
        return nil
    end

    return GetSpecializationInfoForIndex(specIndex)
end

local function IsSupportedMonkSpecID(specID)
    return specID == SPEC_MONK_BREWMASTER
end

local function IsPlayerSkyridingActive()
    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local ok, isGliding, canGlide = pcall(C_PlayerInfo.GetGlidingInfo)
        if ok then
            if isGliding == true then
                return true
            end

            if IsMounted and IsMounted() and canGlide == true then
                return true
            end
        end
    end

    if IsPlayerSkyriding then
        return IsPlayerSkyriding() == true
    end
    if C_PlayerInfo then
        if C_PlayerInfo.IsPlayerSkyriding then
            return C_PlayerInfo.IsPlayerSkyriding() == true
        end
        if C_PlayerInfo.IsGliding then
            return C_PlayerInfo.IsGliding() == true
        end
        if C_PlayerInfo.IsPlayerGliding then
            return C_PlayerInfo.IsPlayerGliding() == true
        end
    end
    if IsPlayerGliding then
        return IsPlayerGliding() == true
    end

    return false
end

local function GetBrewmasterResourceCount()
    if not (C_Spell and C_Spell.GetSpellCastCount) then
        return 0
    end

    return C_Spell.GetSpellCastCount(BREWMASTER_RESOURCE_SPELL_ID) or 0
end

local function GetPreviewBrewmasterDisplayState()
    return true, PREVIEW_CURRENT_COUNT, PREVIEW_MAX_COUNT
end

local function ShouldShowForRuntimeGates(settings)
    if not settings then
        return false
    end

    if settings.visibility.hideWhileSkyriding and IsPlayerSkyridingActive() then
        return false
    end

    return true
end

local function ShouldShowForVisibility(settings, ignoreCombatVisibility)
    if not settings then
        return false
    end

    if not IsBarEnabled(settings) then
        return false
    end

    if not ShouldShowForRuntimeGates(settings) then
        return false
    end

    if not ignoreCombatVisibility and settings.visibility.mode == "combat"
        and not (UnitAffectingCombat and UnitAffectingCombat("player")) then
        return false
    end

    return true
end

local function GetPreviewDisplayState()
    if ns.isEditMode then
        return true, PREVIEW_CURRENT_COUNT + 1, PREVIEW_MAX_COUNT
    end

    return GetPreviewBrewmasterDisplayState()
end

local function GetLiveDisplayState(settings, specID, ignoreCombatVisibility)
    if not settings or not IsModuleEnabled(settings) or not IsMonkCharacter() then
        return false, 0, 0
    end

    if specID == nil then
        specID = GetCurrentMonkSpecID()
    end

    if specID == SPEC_MONK_BREWMASTER then
        return ShouldShowForVisibility(settings, ignoreCombatVisibility), GetBrewmasterResourceCount(), SEGMENT_COUNT
    end

    return false, 0, 0
end

local function ShouldRunRuntimeTicker(settings, specID, optionsPreviewActive)
    if ns.isEditMode or not IsMonkCharacter() then
        return false
    end

    if optionsPreviewActive or settings == nil or not IsModuleEnabled(settings) then
        return false
    end

    if specID == nil then
        specID = GetCurrentMonkSpecID()
    end

    return specID == SPEC_MONK_BREWMASTER and ShouldShowForVisibility(settings)
end

local function GetStandaloneConfig(layoutName)
    return ns.GetEditModeConfig and ns.GetEditModeConfig(CONFIG_KEY, GetDefaultStandaloneConfig(), layoutName) or GetDefaultStandaloneConfig()
end

local function NormalizeStandaloneConfig(config)
    local defaults = GetDefaultStandaloneConfig()

    if type(config) ~= "table" then
        return {
            point = NormalizePoint(defaults.point, "CENTER"),
            x = RoundWholeNumber(Clamp(defaults.x, -4000, 4000, 0)),
            y = RoundWholeNumber(Clamp(defaults.y, -4000, 4000, 0)),
        }
    end

    config.point = NormalizePoint(config.point, defaults.point)
    config.x = RoundWholeNumber(Clamp(config.x, -4000, 4000, defaults.x))
    config.y = RoundWholeNumber(Clamp(config.y, -4000, 4000, defaults.y))

    return config
end

local function GetResolvedTexturePath(textureKey)
    local texturePath = ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(textureKey) or textureKey
    if type(texturePath) ~= "string" or texturePath == "" then
        return DEFAULT_TEXTURE
    end

    return texturePath
end

local function GetEffectiveSegmentGap(width, gap)
    width = max(SEGMENT_COUNT, RoundWholeNumber(width, 180))
    gap = max(0, RoundWholeNumber(gap, 2))

    local maxGap = floor(max(0, width - SEGMENT_COUNT) / (SEGMENT_COUNT - 1))
    if gap > maxGap then
        return maxGap
    end

    return gap
end

IsForbiddenAttachFrame = function(frame, frameName)
    if frameName == BAR_FRAME_NAME then
        return true
    end

    if not frame or not barFrame then
        return false
    end

    local current = frame
    while current do
        if current == barFrame then
            return true
        end
        current = current.GetParent and current:GetParent() or nil
    end

    return false
end

local function IsProtectedAttachFrame(frame)
    return frame and frame.IsProtected and frame:IsProtected() == true
end

local function GetRequestedAttachTargetFrame(settings)
    if ns.isEditMode or not settings or settings.attach.target == "none" then
        return nil
    end

    return ns.ResolveMonkChiBarAttachFrame and ns.ResolveMonkChiBarAttachFrame(settings) or nil
end

local function GetEffectiveAttachTargetFrame()
    if attachedTargetFrame then
        return attachedTargetFrame
    end

    return GetRequestedAttachTargetFrame(cachedSettings)
end

local function GetSafeMatchWidth(targetFrame, fallbackWidth)
    fallbackWidth = RoundWholeNumber(fallbackWidth, 180)
    if not targetFrame or not targetFrame.GetWidth then
        return fallbackWidth
    end

    if InCombatLockdown and InCombatLockdown() then
        if lastLayoutWidth and lastLayoutWidth > 0 then
            return lastLayoutWidth
        end

        return fallbackWidth
    end

    local ok, resolvedWidth = pcall(targetFrame.GetWidth, targetFrame)
    if not ok then
        return fallbackWidth
    end

    return RoundWholeNumber(resolvedWidth, fallbackWidth)
end

local function ShouldDeferProtectedAttachMutations(targetFrame)
    if not (InCombatLockdown and InCombatLockdown()) then
        return false
    end

    if activeVisibilityDriverCondition ~= nil then
        return true
    end

    return IsProtectedAttachFrame(targetFrame or GetEffectiveAttachTargetFrame())
end

local function EnsureRegenRefreshListener()
    if eventsRegistered then
        return
    end

    eventFrame:UnregisterAllEvents()
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", OnEvent)
    eventsRegistered = true
    registeredSpecID = nil
end

local function MarkProtectedRefreshPending()
    pendingProtectedRefresh = true
    EnsureRegenRefreshListener()
end

local function MarkVisibilityDriverRefreshPending()
    pendingVisibilityDriverRefresh = true
    EnsureRegenRefreshListener()
end

---@param settings table|nil
---@param specID number|nil
---@param optionsPreviewActive boolean|nil
---@return boolean
local function ShouldUseSecureVisibilityDriver(settings, specID, optionsPreviewActive)
    if not settings or ns.isEditMode then
        return false
    end

    if optionsPreviewActive == nil then
        optionsPreviewActive = IsOptionsPreviewActive()
    end

    if optionsPreviewActive or settings.visibility.mode ~= "combat" then
        return false
    end

    if not IsModuleEnabled(settings) or not IsBarEnabled(settings) or not IsMonkCharacter() then
        return false
    end

    if specID == nil then
        specID = GetCurrentMonkSpecID()
    end

    if not IsSupportedMonkSpecID(specID) then
        return false
    end

    if not ShouldShowForRuntimeGates(settings) then
        return false
    end

    return IsProtectedAttachFrame(GetRequestedAttachTargetFrame(settings))
end

---@param specID number|nil
---@param optionsPreviewActive boolean|nil
---@return boolean
local function UpdateSecureVisibilityDriver(specID, optionsPreviewActive)
    if not barFrame then
        activeVisibilityDriverCondition = nil
        return false
    end

    local desiredCondition = nil
    if RegisterStateDriver and UnregisterStateDriver and ShouldUseSecureVisibilityDriver(cachedSettings, specID, optionsPreviewActive) then
        desiredCondition = SECURE_VISIBILITY_COMBAT_CONDITION
    end

    if activeVisibilityDriverCondition == desiredCondition then
        pendingVisibilityDriverRefresh = false
        return desiredCondition ~= nil
    end

    if InCombatLockdown and InCombatLockdown() then
        MarkVisibilityDriverRefreshPending()
        return activeVisibilityDriverCondition ~= nil
    end

    pendingVisibilityDriverRefresh = false

    if activeVisibilityDriverCondition and UnregisterStateDriver then
        pcall(UnregisterStateDriver, barFrame, "visibility")
        activeVisibilityDriverCondition = nil
    end

    if desiredCondition and RegisterStateDriver then
        local ok = pcall(RegisterStateDriver, barFrame, "visibility", desiredCondition)
        if ok then
            activeVisibilityDriverCondition = desiredCondition
        end
    end

    return activeVisibilityDriverCondition ~= nil
end

local function IsSecureVisibilityDriverActive()
    return activeVisibilityDriverCondition ~= nil
end

local function UpdateSegmentLayout(width, height, gap)
    if not barFrame then
        return
    end

    width = max(60, RoundWholeNumber(width, 180))
    height = max(4, RoundWholeNumber(height, 18))
    gap = GetEffectiveSegmentGap(width, gap)

    if lastLayoutWidth == width and lastLayoutHeight == height and lastLayoutGap == gap then
        return
    end

    lastLayoutWidth = width
    lastLayoutHeight = height
    lastLayoutGap = gap

    barFrame:SetSize(width, height)

    local totalGap = gap * (SEGMENT_COUNT - 1)
    local availableWidth = max(SEGMENT_COUNT, width - totalGap)
    local baseSegmentWidth = floor(availableWidth / SEGMENT_COUNT)
    local remainder = availableWidth - (baseSegmentWidth * SEGMENT_COUNT)
    local currentOffset = 0
    local tickWidth = gap

    for index = 1, SEGMENT_COUNT do
        local segmentWidth = baseSegmentWidth
        if remainder > 0 then
            segmentWidth = segmentWidth + 1
            remainder = remainder - 1
        end
        segmentWidth = max(1, segmentWidth)

        if index < SEGMENT_COUNT then
            local tick = brewmasterTickTextures[index]
            tick:ClearAllPoints()
            if tickWidth > 0 then
                tick:SetPoint("TOPLEFT", barFrame, "TOPLEFT", currentOffset + segmentWidth, 0)
                tick:SetSize(tickWidth, height)
                tick:Show()
            else
                tick:Hide()
            end
        end

        currentOffset = currentOffset + segmentWidth + gap
    end
end

local function HookTargetFrame(frame)
    if not frame or hookedTargetFrames[frame] or not frame.HookScript then
        return
    end

    hookedTargetFrames[frame] = true
    frame:HookScript("OnSizeChanged", function(self)
        if self ~= attachedTargetFrame or not cachedSettings or ns.isEditMode then
            return
        end
        if cachedSettings.attach.matchWidth ~= true then
            return
        end

        if InCombatLockdown and InCombatLockdown() then
            MarkProtectedRefreshPending()
            return
        end

        if ShouldDeferProtectedAttachMutations(self) then
            MarkProtectedRefreshPending()
            return
        end

        if ns.RefreshMonkChiBar then
            ns.RefreshMonkChiBar()
        end
    end)
end

local function EnsureFrame()
    if barFrame then
        return
    end

    barFrame = CreateFrame("Frame", BAR_FRAME_NAME, UIParent)
    barFrame:SetClampedToScreen(true)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:EnableMouse(false)
    barFrame:Hide()

    fillFrame = CreateFrame("Frame", nil, barFrame)
    fillFrame:SetAllPoints()
    fillFrame:SetFrameLevel(barFrame:GetFrameLevel())

    backgroundTexture = fillFrame:CreateTexture(nil, "BACKGROUND")
    backgroundTexture:SetAllPoints()
    backgroundTexture:SetTexture(DEFAULT_TEXTURE)
    backgroundTexture:SetVertexColor(DEFAULT_BACKGROUND_COLOR.r, DEFAULT_BACKGROUND_COLOR.g, DEFAULT_BACKGROUND_COLOR.b, DEFAULT_BACKGROUND_COLOR.a)

    brewmasterStatusBar = CreateFrame("StatusBar", nil, fillFrame)
    brewmasterStatusBar:SetAllPoints()
    brewmasterStatusBar:SetFrameLevel(fillFrame:GetFrameLevel())
    brewmasterStatusBar:SetStatusBarTexture(DEFAULT_TEXTURE)
    brewmasterStatusBar:SetStatusBarColor(DEFAULT_ACTIVE_COLOR.r, DEFAULT_ACTIVE_COLOR.g, DEFAULT_ACTIVE_COLOR.b, DEFAULT_ACTIVE_COLOR.a)
    brewmasterStatusBar:SetMinMaxValues(0, SEGMENT_COUNT)
    brewmasterStatusBar:SetValue(0)

    overlayFrame = CreateFrame("Frame", nil, barFrame)
    overlayFrame:SetAllPoints()
    overlayFrame:SetFrameLevel((fillFrame:GetFrameLevel() or 1) + 1)

    for index = 1, SEGMENT_COUNT - 1 do
        local tick = overlayFrame:CreateTexture(nil, "OVERLAY")
        tick:SetTexture(DEFAULT_TEXTURE)
        brewmasterTickTextures[index] = tick
    end

    borderFrame = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    borderFrame:SetFrameLevel((overlayFrame:GetFrameLevel() or (barFrame:GetFrameLevel() or 1)) + 1)
    borderFrame:Hide()

    if ns.AttachEditModeSelectionProxy then
        ns.AttachEditModeSelectionProxy(barFrame)
    end

    barFrame.editModeName = EDIT_MODE_LABEL
    ns.monkChiBarFrame = barFrame
end

local function GetDisplayState(specID, optionsPreviewActive, ignoreCombatVisibility)
    local settings = cachedSettings or NormalizeSettings(GetSettings())
    if specID == nil then
        specID = GetCurrentMonkSpecID()
    end
    if optionsPreviewActive == nil then
        optionsPreviewActive = IsOptionsPreviewActive()
    end

    if ns.isEditMode then
        return GetPreviewDisplayState()
    end

    if optionsPreviewActive then
        if IsModuleEnabled(settings) and IsBarEnabled(settings) then
            return GetPreviewDisplayState()
        end

        return false, 0, 0
    end

    return GetLiveDisplayState(settings, specID, ignoreCombatVisibility)
end

local function ApplyAppearance()
    if not barFrame or not cachedSettings then
        return
    end

    if ShouldDeferProtectedAttachMutations() then
        MarkProtectedRefreshPending()
        return
    end

    local appearance = cachedSettings.appearance
    local texturePath = GetResolvedTexturePath(appearance.texture)

    backgroundTexture:SetTexture(texturePath)
    backgroundTexture:SetVertexColor(
        appearance.backgroundColor.r,
        appearance.backgroundColor.g,
        appearance.backgroundColor.b,
        appearance.backgroundColor.a
    )

    brewmasterStatusBar:SetStatusBarTexture(texturePath)
    brewmasterStatusBar:SetStatusBarColor(
        appearance.activeColor.r,
        appearance.activeColor.g,
        appearance.activeColor.b,
        appearance.activeColor.a
    )

    for index = 1, SEGMENT_COUNT - 1 do
        brewmasterTickTextures[index]:SetTexture(texturePath)
        brewmasterTickTextures[index]:SetVertexColor(
            appearance.dividerColor.r,
            appearance.dividerColor.g,
            appearance.dividerColor.b,
            appearance.dividerColor.a
        )
    end

    ApplyBorderAppearance(appearance.borderSize, appearance.borderTexture, appearance.borderColor)
    lastChi = -1
    lastMaxChi = -1
end

local function ApplyLayout(layoutName)
    if not barFrame or not cachedSettings then
        return
    end

    local targetFrame = nil
    if not ns.isEditMode and cachedSettings.attach.target ~= "none" then
        local resolvedFrame = ns.ResolveMonkChiBarAttachFrame and ns.ResolveMonkChiBarAttachFrame(cachedSettings) or nil
        targetFrame = resolvedFrame
    end

    if ShouldDeferProtectedAttachMutations(targetFrame) then
        MarkProtectedRefreshPending()
        return false
    end

    pendingProtectedRefresh = false
    attachedTargetFrame = targetFrame
    HookTargetFrame(targetFrame)

    local width = cachedSettings.appearance.width
    if targetFrame and cachedSettings.attach.matchWidth == true then
        width = GetSafeMatchWidth(targetFrame, width)
    end

    UpdateSegmentLayout(width, cachedSettings.appearance.height, cachedSettings.appearance.segmentGap)
    barFrame:ClearAllPoints()
    if targetFrame then
        barFrame:SetPoint(
            cachedSettings.attach.point,
            targetFrame,
            cachedSettings.attach.relativePoint,
            cachedSettings.attach.x,
            cachedSettings.attach.y
        )
        return true
    end

    local config = NormalizeStandaloneConfig(GetStandaloneConfig(layoutName))
    barFrame:SetPoint(config.point, UIParent, config.point, config.x, config.y)
    return true
end

local function UpdateBrewmasterStatusBar(value, force)
    if not brewmasterStatusBar then
        return
    end

    local displayValue = value or 0
    lastChi = -1
    lastMaxChi = -1

    pcall(function()
        brewmasterStatusBar:SetValue(displayValue)
    end)
end

local function HideBar()
    if not barFrame then
        lastShown = false
        lastChi = -1
        lastMaxChi = -1
        return true
    end

    if barFrame:IsShown() and ShouldDeferProtectedAttachMutations() then
        MarkProtectedRefreshPending()
        return false
    end

    if barFrame:IsShown() then
        barFrame:Hide()
    end
    lastShown = false
    lastChi = -1
    lastMaxChi = -1
    return true
end

local function ApplyBarVisibilityState(shouldShow, currentChi, forceSegments, visibilityDriverActive)
    if not barFrame then
        return
    end

    if visibilityDriverActive then
        if shouldShow then
            UpdateBrewmasterStatusBar(currentChi, forceSegments or lastShown ~= true)
            lastShown = true
        end
        return
    end

    if not shouldShow then
        HideBar()
        return
    end

    UpdateBrewmasterStatusBar(currentChi, forceSegments or lastShown ~= true)

    if not barFrame:IsShown() then
        if ShouldDeferProtectedAttachMutations() then
            MarkProtectedRefreshPending()
            return
        end

        barFrame:Show()
    end

    lastShown = true
end

local function ApplyLightweightDisplayState(specID, shouldShow, currentChi, maxChi)
    if not barFrame or not cachedSettings then
        return
    end

    ApplyBarVisibilityState(shouldShow, currentChi, lastShown ~= true, IsSecureVisibilityDriverActive())
end

local function SetRuntimeTickerActive(active)
    if runtimeTickerActive == active then
        return
    end

    runtimeTickerActive = active
    if active then
        if runtimeTicker == nil and C_Timer and C_Timer.NewTicker then
            runtimeTicker = C_Timer.NewTicker(RUNTIME_SAMPLE_INTERVAL, OnRuntimeTickerTick)
        end
        return
    end

    if runtimeTicker then
        runtimeTicker:Cancel()
        runtimeTicker = nil
    end
end

OnRuntimeTickerTick = function()
    local settings = cachedSettings
    local optionsPreviewActive = IsOptionsPreviewActive()
    local specID = GetCurrentMonkSpecID()
    if not ShouldRunRuntimeTicker(settings, specID, optionsPreviewActive) then
        SetRuntimeTickerActive(false)
        return
    end

    local shouldShow, currentChi, maxChi = GetDisplayState(specID, optionsPreviewActive)
    ApplyLightweightDisplayState(specID, shouldShow, currentChi, maxChi)
end

local function UpdateRuntimeTicker(specID, optionsPreviewActive)
    local settings = cachedSettings
    if optionsPreviewActive == nil then
        optionsPreviewActive = IsOptionsPreviewActive()
    end

    if specID == nil then
        specID = GetCurrentMonkSpecID()
    end

    SetRuntimeTickerActive(ShouldRunRuntimeTicker(settings, specID, optionsPreviewActive))
end

local function UpdateDisplay(forceSegments, refreshLayout, specID, optionsPreviewActive)
    EnsureFrame()
    if not barFrame or not cachedSettings then
        return
    end

    if specID == nil then
        specID = GetCurrentMonkSpecID()
    end
    if optionsPreviewActive == nil then
        optionsPreviewActive = IsOptionsPreviewActive()
    end

    UpdateRuntimeTicker(specID, optionsPreviewActive)

    if refreshLayout then
        ApplyLayout()
    end

    local visibilityDriverActive = UpdateSecureVisibilityDriver(specID, optionsPreviewActive)

    local shouldShow, currentChi, maxChi = GetDisplayState(specID, optionsPreviewActive, visibilityDriverActive)
    if not shouldShow then
        ApplyBarVisibilityState(false, currentChi, forceSegments, visibilityDriverActive)
        return
    end

    ApplyBarVisibilityState(true, currentChi, forceSegments, visibilityDriverActive)
end

local function RegisterWithEditMode()
    if registeredWithEditMode or not ns.RegisterEditModeFrame or not IsMonkCharacter() then
        return
    end

    EnsureFrame()
    local defaults = GetDefaultStandaloneConfig()
    registeredWithEditMode = ns.RegisterEditModeFrame(barFrame, {
        label = EDIT_MODE_LABEL,
        defaults = {
            point = defaults.point,
            x = defaults.x,
            y = defaults.y,
        },
        applyLayout = function(layoutName)
            ApplyLayout(layoutName)
        end,
        onPositionChanged = function(layoutName, point, x, y)
            local config = NormalizeStandaloneConfig(GetStandaloneConfig(layoutName))
            config.point = NormalizePoint(point, config.point)
            config.x = RoundWholeNumber(Clamp(x, -4000, 4000, config.x))
            config.y = RoundWholeNumber(Clamp(y, -4000, 4000, config.y))
            ApplyLayout(layoutName)
        end,
    }) == true
end

local function ShouldRegisterEvents(settings)
    return IsMonkCharacter() and ((IsModuleEnabled(settings) and IsBarEnabled(settings)) or IsOptionsPreviewActive())
end

OnEvent = function(_, event, ...)
    if event == "UNIT_AURA" then
        local unitToken = ...
        if unitToken ~= "player" then
            return
        end
        if GetCurrentMonkSpecID() ~= SPEC_MONK_BREWMASTER then
            return
        end

        UpdateDisplay(false, false)
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitToken, _, spellID = ...
        if unitToken ~= "player" or spellID ~= BREWMASTER_RESOURCE_SPELL_ID then
            return
        end
        if GetCurrentMonkSpecID() ~= SPEC_MONK_BREWMASTER then
            return
        end

        UpdateDisplay(false, false)
        return
    end

    if event == "SPELL_UPDATE_CHARGES" then
        if GetCurrentMonkSpecID() ~= SPEC_MONK_BREWMASTER then
            return
        end

        UpdateDisplay(false, false)
        return
    end

    local unitToken = ...
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unitToken ~= nil and unitToken ~= "player" then
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and (pendingProtectedRefresh or pendingVisibilityDriverRefresh) then
        pendingProtectedRefresh = false
        pendingVisibilityDriverRefresh = false
        if ns.RefreshMonkChiBar then
            ns.RefreshMonkChiBar()
        else
            UpdateDisplay(true, true)
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        local specID = GetCurrentMonkSpecID()
        local optionsPreviewActive = IsOptionsPreviewActive()
        UpdateEventRegistration(ShouldRegisterEvents(cachedSettings), specID)
        UpdateDisplay(true, true, specID, optionsPreviewActive)
        return
    end

    UpdateDisplay(false, false)
end

UpdateEventRegistration = function(shouldRegister, specID)
    if not shouldRegister then
        if eventsRegistered then
            eventsRegistered = false
            registeredSpecID = nil
            eventFrame:UnregisterAllEvents()
            eventFrame:SetScript("OnEvent", nil)
        end
        return
    end

    if not IsSupportedMonkSpecID(specID) then
        specID = nil
    end

    if eventsRegistered and registeredSpecID == specID then
        return
    end

    eventFrame:UnregisterAllEvents()
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("PLAYER_IS_GLIDING_CHANGED")
    eventFrame:RegisterEvent("PLAYER_CAN_GLIDE_CHANGED")

    if specID == SPEC_MONK_BREWMASTER then
        eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    end

    eventsRegistered = true
    registeredSpecID = specID
    eventFrame:SetScript("OnEvent", OnEvent)
end

function ns.InitializeClassesModule()
    cachedSettings = NormalizeSettings(GetSettings())
    UpdateEventRegistration(ShouldRegisterEvents(cachedSettings), GetCurrentMonkSpecID())

    if IsMonkCharacter() then
        EnsureFrame()
        RegisterWithEditMode()
        ApplyAppearance()
        UpdateDisplay(true, true)
    elseif barFrame then
        pendingProtectedRefresh = false
        pendingVisibilityDriverRefresh = false
        UpdateSecureVisibilityDriver(nil, false)
        ApplyBarVisibilityState(false, 0, true, IsSecureVisibilityDriverActive())
        UpdateRuntimeTicker(nil, false)
    end
end

function ns.RefreshMonkChiBar()
    cachedSettings = NormalizeSettings(GetSettings())

    local specID = GetCurrentMonkSpecID()
    local optionsPreviewActive = IsOptionsPreviewActive()
    UpdateRuntimeTicker(specID, optionsPreviewActive)

    UpdateEventRegistration(ShouldRegisterEvents(cachedSettings), specID)

    if not IsMonkCharacter() and not optionsPreviewActive then
        pendingProtectedRefresh = false
        pendingVisibilityDriverRefresh = false
        UpdateSecureVisibilityDriver(specID, optionsPreviewActive)
        if barFrame then
            ApplyBarVisibilityState(false, 0, true, IsSecureVisibilityDriverActive())
        end
        return
    end

    EnsureFrame()
    RegisterWithEditMode()

    if not IsModuleEnabled(cachedSettings) then
        pendingProtectedRefresh = false
        UpdateRuntimeTicker(specID, optionsPreviewActive)
        UpdateSecureVisibilityDriver(specID, optionsPreviewActive)
        ApplyBarVisibilityState(false, 0, true, IsSecureVisibilityDriverActive())
        return
    end

    if not IsBarEnabled(cachedSettings) then
        pendingProtectedRefresh = false
        UpdateRuntimeTicker(specID, optionsPreviewActive)
        UpdateSecureVisibilityDriver(specID, optionsPreviewActive)
        ApplyBarVisibilityState(false, 0, true, IsSecureVisibilityDriverActive())
        return
    end

    if not optionsPreviewActive and not ns.isEditMode and not IsSupportedMonkSpecID(specID) then
        pendingProtectedRefresh = false
        UpdateRuntimeTicker(specID, optionsPreviewActive)
        UpdateSecureVisibilityDriver(specID, optionsPreviewActive)
        ApplyBarVisibilityState(false, 0, true, IsSecureVisibilityDriverActive())
        return
    end

    local targetFrame = nil
    if not ns.isEditMode and cachedSettings.attach.target ~= "none" then
        targetFrame = ns.ResolveMonkChiBarAttachFrame and ns.ResolveMonkChiBarAttachFrame(cachedSettings) or nil
    end

    local deferProtectedRefresh = ShouldDeferProtectedAttachMutations(targetFrame)
    if deferProtectedRefresh then
        MarkProtectedRefreshPending()
    else
        pendingProtectedRefresh = false
        ApplyAppearance()
    end

    UpdateDisplay(true, not deferProtectedRefresh, specID, optionsPreviewActive)
end