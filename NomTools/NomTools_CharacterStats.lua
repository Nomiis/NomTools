local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

local GetCombatRatingBonus = GetCombatRatingBonus
local GetCritChance = GetCritChance
local GetHaste = GetHaste
local GetMasteryEffect = GetMasteryEffect
local GetVersatilityBonus = GetVersatilityBonus
local GetLifesteal = GetLifesteal
local GetAvoidance = GetAvoidance
local GetSpeed = GetSpeed
local GetDodgeChance = GetDodgeChance
local GetParryChance = GetParryChance
local GetBlockChance = GetBlockChance
local UnitStat = UnitStat
local UnitArmor = UnitArmor
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local CreateFrame = CreateFrame
local UIParent = UIParent
local floor = math.floor
local format = string.format

local CONFIG_KEY = "characterStats"
local EDIT_MODE_LABEL = "Character Stats"
local FRAME_PADDING = 10
local LINE_HEIGHT = 16
local LINE_SPACING = 2
local BLIZZARD_FRAME_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local BLIZZARD_FRAME_BG_COLOR = { r = 0, g = 0, b = 0, a = 0.75 }
local BLIZZARD_FRAME_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 1 }

local NOMTOOLS_FRAME_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true,
    tileSize = 1,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local STAT_DEFINITIONS = {
    {
        key = "mainStat",
        label = nil,
        getValue = function()
            local spec = GetSpecialization()
            if not spec then return 0 end
            local _, _, _, _, _, primaryStat = GetSpecializationInfo(spec)
            if not primaryStat then return 0 end
            return floor(UnitStat("player", primaryStat))
        end,
        isAbsolute = true,
    },
    { key = "stamina", label = "Stamina", getValue = function() return floor(UnitStat("player", 3)) end, isAbsolute = true },
    { key = "criticalStrike", label = "Crit", getValue = function() return GetCritChance() end },
    { key = "haste", label = "Haste", getValue = function() return GetHaste() end },
    { key = "mastery", label = "Mastery", getValue = function() return (GetMasteryEffect()) end },
    { key = "versatility", label = "Vers", isDualPercent = true, getValue = function() return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE or 29) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE or 29), GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_TAKEN or 31) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_TAKEN or 31) end },
    { key = "leech", label = "Leech", getValue = function() return GetLifesteal() end },
    { key = "avoidance", label = "Avoidance", getValue = function() return GetAvoidance() end },
    { key = "speed", label = "Speed", getValue = function() return GetSpeed() end },
    { key = "dodge", label = "Dodge", getValue = function() return GetDodgeChance() end },
    { key = "parry", label = "Parry", getValue = function() return GetParryChance() end },
    { key = "block", label = "Block", getValue = function() return GetBlockChance() end },
    { key = "armor", label = "Armor", getValue = function() local _, effectiveArmor = UnitArmor("player") return floor(effectiveArmor or 0) end, isAbsolute = true },
}

local PRIMARY_STAT_NAMES = {
    [1] = "Strength",
    [2] = "Agility",
    [3] = "Stamina",
    [4] = "Intellect",
}

local function GetMainStatLabel()
    local spec = GetSpecialization()
    if not spec then return "Main Stat" end
    local _, _, _, _, _, primaryStat = GetSpecializationInfo(spec)
    return PRIMARY_STAT_NAMES[primaryStat] or "Main Stat"
end

local function NormalizeColor(color, fallback)
    fallback = fallback or { r = 1, g = 1, b = 1, a = 1 }
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

local function Clamp(value, minVal, maxVal, fallback)
    local resolved = tonumber(value)
    if resolved == nil then resolved = tonumber(fallback) or minVal end
    if resolved < minVal then return minVal end
    if resolved > maxVal then return maxVal end
    return resolved
end

local function NormalizeBorderSize(value, fallback)
    local resolved = tonumber(value)
    if resolved == nil then resolved = tonumber(fallback) or 1 end
    if resolved >= 0 then
        resolved = math.floor(resolved + 0.5)
    else
        resolved = math.ceil(resolved - 0.5)
    end
    return math.max(-10, math.min(10, resolved))
end

local function CopyBorderInsets(insets, fallback)
    fallback = math.max(1, tonumber(fallback) or 1)
    if type(insets) ~= "table" then
        return {
            left = fallback,
            right = fallback,
            top = fallback,
            bottom = fallback,
        }
    end

    return {
        left = math.max(0, tonumber(insets.left) or fallback),
        right = math.max(0, tonumber(insets.right) or fallback),
        top = math.max(0, tonumber(insets.top) or fallback),
        bottom = math.max(0, tonumber(insets.bottom) or fallback),
    }
end

local function ResolveBorderStyle(textureKey, borderSize)
    local definition = ns.GetBorderTextureDefinition and ns.GetBorderTextureDefinition(textureKey) or nil
    local magnitude = math.abs(borderSize)
    local baseEdgeSize = math.max(1, tonumber(definition and definition.edgeSize) or 1)
    local scaleStep = math.max(0, tonumber(definition and definition.scaleStep) or 1)
    local edgeSize = baseEdgeSize

    if magnitude > 0 and (not definition or definition.supportsVariableThickness ~= false) then
        edgeSize = edgeSize + (math.max(magnitude - 1, 0) * scaleStep)
    end

    local fallbackInset = math.max(1, math.floor(edgeSize / 4))
    return {
        edgeFile = (definition and definition.path) or textureKey or "Interface\\Buttons\\WHITE8x8",
        tile = definition and definition.tile ~= false or true,
        tileSize = math.max(1, tonumber(definition and definition.tileSize) or 8),
        baseEdgeSize = baseEdgeSize,
        edgeSize = math.max(1, edgeSize),
        insets = CopyBorderInsets(definition and definition.insets, fallbackInset),
    }
end

local function ApplyBorderLayout(borderFrame, target, borderSize, edgeSize, baseEdgeSize)
    local signedSize = NormalizeBorderSize(borderSize, 1)
    local thickness = math.abs(signedSize)
    local renderedEdgeSize = math.max(0, tonumber(edgeSize) or thickness)
    local nativeEdgeSize = math.max(0, tonumber(baseEdgeSize) or renderedEdgeSize)
    if not borderFrame or not target or thickness == 0 or renderedEdgeSize == 0 then
        return signedSize, 0
    end

    local layoutPadding = math.max(renderedEdgeSize - nativeEdgeSize, 0)
    borderFrame:ClearAllPoints()
    if signedSize > 0 then
        borderFrame:SetPoint("TOPLEFT", target, "TOPLEFT", -layoutPadding, layoutPadding)
        borderFrame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", layoutPadding, -layoutPadding)
    else
        borderFrame:SetPoint("TOPLEFT", target, "TOPLEFT", layoutPadding, -layoutPadding)
        borderFrame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -layoutPadding, layoutPadding)
    end

    return signedSize, renderedEdgeSize
end

local function ApplyCharStatsBorder(borderFrame, target, borderSize, textureKey, color)
    local signedSize = NormalizeBorderSize(borderSize, 1)
    if not borderFrame or not target or signedSize == 0 then
        if borderFrame then
            borderFrame:Hide()
        end
        return
    end

    local borderStyle = ResolveBorderStyle(textureKey, signedSize)
    local _, renderedEdgeSize = ApplyBorderLayout(borderFrame, target, signedSize, borderStyle.edgeSize, borderStyle.baseEdgeSize)
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

local function GetSettings()
    if ns.GetCharacterStatsSettings then
        return ns.GetCharacterStatsSettings()
    end

    return { enabled = false }
end

local function GetDefaultConfig()
    return ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.characterStats or {
        point = "TOPLEFT",
        x = 20,
        y = -200,
    }
end

local function GetConfig(layoutName)
    return ns.GetEditModeConfig and ns.GetEditModeConfig(CONFIG_KEY, GetDefaultConfig(), layoutName) or GetDefaultConfig()
end

local function GetAppearanceSettings(settings)
    local resolvedSettings = settings or GetSettings()
    local defaultAppearance = ns.DEFAULTS and ns.DEFAULTS.characterStats and ns.DEFAULTS.characterStats.appearance or {}
    local appearance = resolvedSettings.appearance

    if type(appearance) ~= "table" then
        appearance = {}
        resolvedSettings.appearance = appearance
    end

    if appearance.preset ~= "nomtools" then
        appearance.preset = defaultAppearance.preset or "blizzard"
    end

    local function NormalizeProfile(profileKey, includeNomToolsExtras)
        local profileDefaults = defaultAppearance[profileKey] or {}
        local profile = appearance[profileKey]
        if type(profile) ~= "table" then
            profile = {}
            appearance[profileKey] = profile
        end

        if type(profile.font) ~= "string" or profile.font == "" then
            profile.font = profileDefaults.font or ns.GLOBAL_CHOICE_KEY
        end
        if type(profile.fontOutline) ~= "string" or profile.fontOutline == "" then
            profile.fontOutline = profileDefaults.fontOutline or ns.GLOBAL_CHOICE_KEY
        end
        profile.fontSize = math.floor(Clamp(profile.fontSize, 6, 48, profileDefaults.fontSize or 12) + 0.5)

        if includeNomToolsExtras then
            profile.backgroundOpacity = math.floor(Clamp(profile.backgroundOpacity, 0, 100, profileDefaults.backgroundOpacity or 80) + 0.5)
            profile.backgroundColor = NormalizeColor(profile.backgroundColor, profileDefaults.backgroundColor or { r = 0, g = 0, b = 0, a = 1 })
            profile.borderColor = NormalizeColor(profile.borderColor, profileDefaults.borderColor or { r = 0, g = 0, b = 0, a = 1 })
            profile.borderSize = NormalizeBorderSize(profile.borderSize, profileDefaults.borderSize or 1)
            if type(profile.texture) ~= "string" or profile.texture == "" then
                profile.texture = profileDefaults.texture or ns.GLOBAL_CHOICE_KEY
            end
            if type(profile.borderTexture) ~= "string" or profile.borderTexture == "" then
                profile.borderTexture = profileDefaults.borderTexture or ns.GLOBAL_CHOICE_KEY
            end
        end

        return profile
    end

    NormalizeProfile("blizzard", false)
    NormalizeProfile("nomtools", true)

    return appearance.preset, appearance[appearance.preset]
end

local function IsModuleEnabled(settings)
    local resolvedSettings = settings or GetSettings()
    local enabled = resolvedSettings and resolvedSettings.enabled
    if ns.IsModuleRuntimeEnabled then
        return ns.IsModuleRuntimeEnabled("characterStats", enabled)
    end
    return enabled ~= false
end

local statsFrame = nil
local statLines = {}
local registeredWithLEM = false
local eventsRegistered = false
local eventFrame = nil
local updateThrottleTimer = nil

local function ApplyFramePosition(layoutName)
    if not statsFrame then return end
    local config = GetConfig(layoutName)
    statsFrame:ClearAllPoints()
    statsFrame:SetPoint(config.point or "TOPLEFT", UIParent, config.point or "TOPLEFT", config.x or 20, config.y or -200)
end

local function RegisterWithEditMode()
    if registeredWithLEM or not statsFrame or not ns.RegisterEditModeFrame then
        return
    end

    local defaults = GetConfig()
    registeredWithLEM = ns.RegisterEditModeFrame(statsFrame, {
        label = EDIT_MODE_LABEL,
        defaults = {
            point = defaults.point,
            x = defaults.x,
            y = defaults.y,
        },
        applyLayout = ApplyFramePosition,
        onPositionChanged = function(layoutName, point, x, y)
            local config = GetConfig(layoutName)
            config.point = point
            config.x = x
            config.y = y
            ApplyFramePosition(layoutName)
        end,
    }) == true
end

local function UpdateStatDisplay()
    if not statsFrame then return end
    local settings = GetSettings()
    local statSettings = settings and settings.stats or {}
    local fontPath = statsFrame.nomtoolsFontPath or "Fonts\\FRIZQT__.TTF"
    local fontOutline = statsFrame.nomtoolsFontOutline or "OUTLINE"
    local fontSize = statsFrame.nomtoolsFontSize or 12
    local visibleCount = 0

    for i, def in ipairs(STAT_DEFINITIONS) do
        local statConfig = statSettings[def.key]
        local line = statLines[i]
        if not line then break end

        if statConfig and statConfig.enabled ~= false then
            local label = def.key == "mainStat" and GetMainStatLabel() or def.label
            local color = NormalizeColor(statConfig.color)
            local valueText
            if def.isDualPercent then
                local dmgBonus, drBonus = def.getValue()
                valueText = format("%s:  %.2f%% / %.2f%%", label, dmgBonus, drBonus)
            elseif def.isAbsolute then
                local value = def.getValue()
                valueText = format("%s:  %d", label, value)
            else
                local value = def.getValue()
                valueText = format("%s:  %.2f%%", label, value)
            end
            line:SetText(valueText)
            line:SetTextColor(color.r, color.g, color.b, color.a or 1)
            line:SetFont(fontPath, fontSize, fontOutline)
            line:Show()
            visibleCount = visibleCount + 1
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", FRAME_PADDING, -(FRAME_PADDING + (visibleCount - 1) * (LINE_HEIGHT + LINE_SPACING)))
        else
            line:Hide()
        end
    end

    local totalHeight = FRAME_PADDING * 2 + visibleCount * LINE_HEIGHT + (visibleCount > 1 and (visibleCount - 1) * LINE_SPACING or 0)
    local maxWidth = 60
    for _, line in ipairs(statLines) do
        if line:IsShown() then
            local w = line:GetStringWidth()
            if w > maxWidth then maxWidth = w end
        end
    end
    statsFrame:SetSize(maxWidth + FRAME_PADDING * 2, totalHeight)
end

local function ScheduleStatUpdate()
    if updateThrottleTimer then return end
    updateThrottleTimer = C_Timer.After(0.1, function()
        updateThrottleTimer = nil
        UpdateStatDisplay()
    end)
end

local function OnStatEvent(self, event, arg1)
    if event == "UNIT_STATS" and arg1 ~= "player" then return end
    ScheduleStatUpdate()
end

local STAT_EVENTS = {
    "UNIT_STATS",
    "COMBAT_RATING_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_AVG_ITEM_LEVEL_UPDATE",
}

local function UpdateEventRegistration(enabled)
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", OnStatEvent)
    end
    if enabled and not eventsRegistered then
        for _, event in ipairs(STAT_EVENTS) do
            eventFrame:RegisterEvent(event)
        end
        eventsRegistered = true
    elseif not enabled and eventsRegistered then
        eventFrame:UnregisterAllEvents()
        eventsRegistered = false
    end
end

local function EnsureFrame()
    if statsFrame then return end

    statsFrame = CreateFrame("Frame", "NomToolsCharacterStatsFrame", UIParent, "BackdropTemplate")
    statsFrame:SetSize(160, 100)
    statsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
    statsFrame:SetFrameStrata("MEDIUM")
    statsFrame:SetClampedToScreen(true)
    statsFrame:EnableMouse(false)

    statsFrame:SetBackdrop(BLIZZARD_FRAME_BACKDROP)
    statsFrame:SetBackdropColor(BLIZZARD_FRAME_BG_COLOR.r, BLIZZARD_FRAME_BG_COLOR.g, BLIZZARD_FRAME_BG_COLOR.b, BLIZZARD_FRAME_BG_COLOR.a)
    statsFrame:SetBackdropBorderColor(BLIZZARD_FRAME_BORDER_COLOR.r, BLIZZARD_FRAME_BORDER_COLOR.g, BLIZZARD_FRAME_BORDER_COLOR.b, BLIZZARD_FRAME_BORDER_COLOR.a)

    local backgroundTexture = statsFrame:CreateTexture(nil, "BACKGROUND")
    backgroundTexture:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 1, -1)
    backgroundTexture:SetPoint("BOTTOMRIGHT", statsFrame, "BOTTOMRIGHT", -1, 1)
    backgroundTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    backgroundTexture:SetVertexColor(0, 0, 0, 1)
    backgroundTexture:SetAlpha(0.8)
    backgroundTexture:Hide()
    statsFrame.backgroundTexture = backgroundTexture

    local borderFrame = CreateFrame("Frame", nil, statsFrame, "BackdropTemplate")
    borderFrame:SetFrameLevel((statsFrame:GetFrameLevel() or 0) + 1)
    borderFrame:Hide()
    statsFrame.borderFrame = borderFrame

    for i = 1, #STAT_DEFINITIONS do
        local line = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        line:SetJustifyH("LEFT")
        line:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", FRAME_PADDING, -(FRAME_PADDING + (i - 1) * (LINE_HEIGHT + LINE_SPACING)))
        statLines[i] = line
    end

    if ns.AttachEditModeSelectionProxy then
        ns.AttachEditModeSelectionProxy(statsFrame)
    end
    ns.characterStatsFrame = statsFrame
    statsFrame.editModeName = EDIT_MODE_LABEL
    ApplyFramePosition()
    statsFrame:Hide()
end

local function ApplyAppearance(settings)
    if not statsFrame then return end
    local preset, appearance = GetAppearanceSettings(settings)

    local fontPath = ns.GetFontPath and ns.GetFontPath(appearance.font) or "Fonts\\FRIZQT__.TTF"
    local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(appearance.fontOutline) or "OUTLINE"
    local fontSize = appearance.fontSize or 12

    -- Store resolved font info for UpdateStatDisplay to use
    statsFrame.nomtoolsFontPath = fontPath
    statsFrame.nomtoolsFontOutline = fontOutline
    statsFrame.nomtoolsFontSize = fontSize

    if preset == "nomtools" then
        local bgColor = NormalizeColor(appearance.backgroundColor, { r = 0.05, g = 0.05, b = 0.05, a = 1 })
        local borderColor = NormalizeColor(appearance.borderColor, { r = 0.25, g = 0.25, b = 0.25, a = 1 })
        local opacity = Clamp(appearance.backgroundOpacity, 0, 100, 80) / 100
        local borderSize = NormalizeBorderSize(appearance.borderSize, 1)
        local texturePath = ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(appearance.texture) or "Interface\\Buttons\\WHITE8x8"
        statsFrame:SetBackdrop(NOMTOOLS_FRAME_BACKDROP)
        statsFrame:SetBackdropColor(0, 0, 0, 0)
        statsFrame:SetBackdropBorderColor(0, 0, 0, 0)
        statsFrame.backgroundTexture:SetTexture(texturePath)
        statsFrame.backgroundTexture:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, 1)
        statsFrame.backgroundTexture:SetAlpha(opacity)
        statsFrame.backgroundTexture:Show()
        ApplyCharStatsBorder(statsFrame.borderFrame, statsFrame, borderSize, appearance.borderTexture, borderColor)
    else
        statsFrame:SetBackdrop(BLIZZARD_FRAME_BACKDROP)
        statsFrame:SetBackdropColor(BLIZZARD_FRAME_BG_COLOR.r, BLIZZARD_FRAME_BG_COLOR.g, BLIZZARD_FRAME_BG_COLOR.b, BLIZZARD_FRAME_BG_COLOR.a)
        statsFrame:SetBackdropBorderColor(BLIZZARD_FRAME_BORDER_COLOR.r, BLIZZARD_FRAME_BORDER_COLOR.g, BLIZZARD_FRAME_BORDER_COLOR.b, BLIZZARD_FRAME_BORDER_COLOR.a)
        if statsFrame.backgroundTexture then statsFrame.backgroundTexture:Hide() end
        if statsFrame.borderFrame then statsFrame.borderFrame:Hide() end
    end
end

function ns.InitializeCharacterStatsUI()
    EnsureFrame()
    RegisterWithEditMode()
    UpdateEventRegistration(IsModuleEnabled(GetSettings()))
end

function ns.RefreshCharacterStatsUI()
    EnsureFrame()
    RegisterWithEditMode()

    local settings = GetSettings()
    local enabled = IsModuleEnabled(settings)
    UpdateEventRegistration(enabled)

    if not enabled and not ns.isEditMode then
        statsFrame:Hide()
        return
    end

    statsFrame:EnableMouse(ns.isEditMode == true)
    ApplyAppearance(settings)
    UpdateStatDisplay()
    ApplyFramePosition()
    statsFrame:Show()
end

function ns.RefreshMiscellaneousUI()
    ns.RefreshCharacterStatsUI()
end
