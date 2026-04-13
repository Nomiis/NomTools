local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

local DEFAULT_ICON = 134400
local CONFIG_KEY = "talentLoadout"
local EDIT_MODE_LABEL = "Talent Loadout Reminder"
local MIN_TEXT_WIDTH = 220
local MAX_TEXT_WIDTH = 360
local FRAME_TOP_PADDING = 16
local FRAME_BOTTOM_PADDING = 16
local FRAME_LEFT_PADDING = 14
local FRAME_RIGHT_PADDING = 14
local FRAME_CLOSE_BUTTON_SIZE = 18
local FRAME_CLOSE_BUTTON_GAP = 6
local MIN_ICON_SIZE = 42
local MAX_ICON_SIZE = 72
local FRAME_ICON_GAP = 12
local FRAME_BG_ALPHA = 0.80
local BLIZZARD_FRAME_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local NOMTOOLS_FRAME_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local BLIZZARD_FRAME_BACKGROUND_COLOR = {
    r = 0.10,
    g = 0.11,
    b = 0.13,
    a = 0.98,
}
local BLIZZARD_FRAME_BORDER_COLOR = {
    r = 0.28,
    g = 0.30,
    b = 0.34,
    a = 1,
}

local reminderFrame
local eventsRegistered = false
local registeredWithLEM = false
local eventFrame = CreateFrame("Frame")
local dismissedReminderSignature
local cachedLoadoutList

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

local function NormalizeBorderSize(value, fallback)
    local resolved = tonumber(value)
    if resolved == nil then
        resolved = tonumber(fallback) or 1
    end

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

local function ApplyReminderBorder(borderFrame, target, borderSize, textureKey, color)
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

---@param s string
---@return string stripped String with WoW UI escape sequences removed
local function StripEscapeCodes(s)
    if type(s) ~= "string" then
        return s or ""
    end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|T[^|]+|t", "")
    s = s:gsub("|H[^|]+|h([^|]*)|h", "%1")
    s = s:gsub("|n", " ")
    return s
end

local function GetSettings()
    if ns.GetTalentLoadoutSettings then
        return ns.GetTalentLoadoutSettings()
    end

    return {
        enabled = true,
    }
end

local function IsModuleEnabled(settings)
    local resolvedSettings = settings or GetSettings()
    local enabled = resolvedSettings and resolvedSettings.enabled
    if ns.IsModuleRuntimeEnabled then
        return ns.IsModuleRuntimeEnabled("talentLoadout", enabled)
    end

    return enabled ~= false
end

local function IsOptionsPreviewActive()
    return ns.GetActiveOptionsPreviewPage and (ns.GetActiveOptionsPreviewPage() == "talent_loadout" or ns.GetActiveOptionsPreviewPage() == "reminders_appearance")
end

local function GetDefaultConfig()
    return ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.talentLoadout or {
        point = "TOP",
        x = 0,
        y = -428,
    }
end

local function GetConfig(layoutName)
    return ns.GetEditModeConfig and ns.GetEditModeConfig(CONFIG_KEY, GetDefaultConfig(), layoutName) or GetDefaultConfig()
end

local function GetAppearanceSettings(settings)
    local resolvedSettings = ns.GetRemindersSettings and ns.GetRemindersSettings() or {}
    local defaultAppearance = ns.DEFAULTS and ns.DEFAULTS.reminders and ns.DEFAULTS.reminders.appearance or {}
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

        profile.titleFontSize = math.floor(Clamp(profile.titleFontSize, 8, 30, profileDefaults.titleFontSize or 14) + 0.5)
        profile.primaryFontSize = math.floor(Clamp(profile.primaryFontSize, 8, 30, profileDefaults.primaryFontSize or 13) + 0.5)
        profile.hintFontSize = math.floor(Clamp(profile.hintFontSize, 8, 30, profileDefaults.hintFontSize or 11) + 0.5)

        profile.titleColor = NormalizeColor(profile.titleColor, profileDefaults.titleColor or { r = 1, g = 0.82, b = 0, a = 1 })
        profile.primaryColor = NormalizeColor(profile.primaryColor, profileDefaults.primaryColor or { r = 1, g = 1, b = 1, a = 1 })
        profile.hintColor = NormalizeColor(profile.hintColor, profileDefaults.hintColor or { r = 0.75, g = 0.78, b = 0.82, a = 1 })

        if includeNomToolsExtras then
            profile.opacity = math.floor(Clamp(profile.opacity, 0, 100, profileDefaults.opacity or 80) + 0.5)
            if type(profile.texture) ~= "string" or profile.texture == "" then
                profile.texture = profileDefaults.texture or ns.GLOBAL_CHOICE_KEY
            end
            if profile.showAccent == nil then
                profile.showAccent = profileDefaults.showAccent ~= false
            else
                profile.showAccent = profile.showAccent ~= false
            end
            profile.accentColor = NormalizeColor(profile.accentColor, profileDefaults.accentColor or { r = 0.96, g = 0.64, b = 0.22, a = 1 })
            profile.backgroundColor = NormalizeColor(profile.backgroundColor, profileDefaults.backgroundColor or { r = 0, g = 0, b = 0, a = 1 })
            profile.borderColor = NormalizeColor(profile.borderColor, profileDefaults.borderColor or BLIZZARD_FRAME_BORDER_COLOR)
            if type(profile.borderTexture) ~= "string" or profile.borderTexture == "" then
                profile.borderTexture = profileDefaults.borderTexture or ns.GLOBAL_CHOICE_KEY
            end
            profile.borderSize = NormalizeBorderSize(profile.borderSize, profileDefaults.borderSize or 1)
        end

        return profile
    end

    NormalizeProfile("blizzard", false)
    NormalizeProfile("nomtools", true)

    return appearance.preset, appearance[appearance.preset]
end

local function ApplyReminderAppearance(settings)
    if not reminderFrame then
        return "blizzard", nil
    end

    local preset, appearance = GetAppearanceSettings(settings)
    local fontPath = ns.GetFontPath and ns.GetFontPath(appearance.font) or STANDARD_TEXT_FONT
    local fontOutline = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(appearance.fontOutline) or "OUTLINE"

    reminderFrame.titleText:SetFont(fontPath or STANDARD_TEXT_FONT, appearance.titleFontSize or 14, fontOutline)
    reminderFrame.specText:SetFont(fontPath or STANDARD_TEXT_FONT, appearance.primaryFontSize or 13, fontOutline)
    reminderFrame.hintText:SetFont(fontPath or STANDARD_TEXT_FONT, appearance.hintFontSize or 11, fontOutline)

    local titleColor = NormalizeColor(appearance.titleColor, { r = 1, g = 0.82, b = 0, a = 1 })
    local primaryColor = NormalizeColor(appearance.primaryColor, { r = 1, g = 1, b = 1, a = 1 })
    local hintColor = NormalizeColor(appearance.hintColor, { r = 0.75, g = 0.78, b = 0.82, a = 1 })

    reminderFrame.titleText:SetTextColor(titleColor.r, titleColor.g, titleColor.b, titleColor.a)
    reminderFrame.specText:SetTextColor(primaryColor.r, primaryColor.g, primaryColor.b, primaryColor.a)
    reminderFrame.hintText:SetTextColor(hintColor.r, hintColor.g, hintColor.b, hintColor.a)

    if preset == "nomtools" then
        local showAccent = appearance.showAccent ~= false
        local accentColor = NormalizeColor(appearance.accentColor, { r = 0.96, g = 0.64, b = 0.22, a = 1 })
        local backgroundColor = NormalizeColor(appearance.backgroundColor, { r = 0, g = 0, b = 0, a = 1 })
        local texturePath = ns.GetStatusBarTexturePath and ns.GetStatusBarTexturePath(appearance.texture) or "Interface\\Buttons\\WHITE8x8"
        local opacity = Clamp(appearance.opacity, 0, 100) / 100

        reminderFrame:SetBackdrop(NOMTOOLS_FRAME_BACKDROP)
        reminderFrame:SetBackdropColor(0, 0, 0, 0)
        reminderFrame:SetBackdropBorderColor(0, 0, 0, 0)
        reminderFrame.backgroundTexture:SetTexture(texturePath)
        reminderFrame.backgroundTexture:SetVertexColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, 1)
        reminderFrame.backgroundTexture:SetAlpha(opacity)
        reminderFrame.backgroundTexture:Show()
        if showAccent then
            reminderFrame.accent:SetColorTexture(accentColor.r, accentColor.g, accentColor.b, accentColor.a)
            reminderFrame.accent:Show()
        else
            reminderFrame.accent:Hide()
        end
        ApplyReminderBorder(
            reminderFrame.borderFrame,
            reminderFrame,
            appearance.borderSize,
            appearance.borderTexture,
            NormalizeColor(appearance.borderColor, BLIZZARD_FRAME_BORDER_COLOR)
        )
    else
        reminderFrame:SetBackdrop(BLIZZARD_FRAME_BACKDROP)
        reminderFrame:SetBackdropColor(BLIZZARD_FRAME_BACKGROUND_COLOR.r, BLIZZARD_FRAME_BACKGROUND_COLOR.g, BLIZZARD_FRAME_BACKGROUND_COLOR.b, BLIZZARD_FRAME_BACKGROUND_COLOR.a)
        reminderFrame:SetBackdropBorderColor(BLIZZARD_FRAME_BORDER_COLOR.r, BLIZZARD_FRAME_BORDER_COLOR.g, BLIZZARD_FRAME_BORDER_COLOR.b, BLIZZARD_FRAME_BORDER_COLOR.a)
        reminderFrame.backgroundTexture:Hide()
        reminderFrame.accent:Hide()
        if reminderFrame.borderFrame then
            reminderFrame.borderFrame:Hide()
        end
    end

    return preset, appearance
end

local function ApplyFramePosition(layoutName)
    if not reminderFrame then
        return
    end

    local config = GetConfig(layoutName)
    reminderFrame:ClearAllPoints()
    reminderFrame:SetPoint(config.point or "CENTER", UIParent, config.point or "CENTER", config.x or 0, config.y or 0)
end

local function RegisterWithEditMode()
    if registeredWithLEM or not reminderFrame or not ns.RegisterEditModeFrame then
        return
    end

    local defaults = GetConfig()
    registeredWithLEM = ns.RegisterEditModeFrame(reminderFrame, {
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

---@return boolean inInstance
---@return string instanceType
---@return string instanceName
---@return number difficultyID
local function GetInstanceState()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return false, "none", "", 0
    end
    local instanceName, _, difficultyID = GetInstanceInfo()
    return true, instanceType or "none", instanceName or "", difficultyID or 0
end

local function GetConfiguredInstanceFilters()
    if ns.GetInstanceFilters then
        return ns.GetInstanceFilters() or ns.INSTANCE_FILTERS or {}
    end
    return ns.INSTANCE_FILTERS or {}
end

local function DoesFilterMatchCurrentInstance(filter, instanceType, difficultyID)
    if not filter then return false end
    if filter.instanceTypes then
        for _, candidateType in ipairs(filter.instanceTypes) do
            if candidateType == "other" then
                local isRecognized = instanceType == "party"
                    or instanceType == "raid"
                    or instanceType == "scenario"
                    or instanceType == "pvp"
                    or instanceType == "arena"
                if not isRecognized then
                    return true
                end
            elseif candidateType == instanceType then
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

---@param settings table|nil
---@return boolean
local function IsInEnabledInstance(settings)
    local enabledFilters = settings and settings.enabledFilters
    if not enabledFilters then
        -- Fallback when no filters configured: show in party + raid only
        local inInstance, instanceType = IsInInstance()
        return inInstance and (instanceType == "party" or instanceType == "raid")
    end

    local inInstance, instanceType, _, difficultyID = GetInstanceState()

    if not inInstance then
        if enabledFilters.city_rest_area and (IsResting and IsResting() or false) then
            return true
        end
        return enabledFilters.open_world == true
    end

    for _, filter in ipairs(GetConfiguredInstanceFilters()) do
        if enabledFilters[filter.key] and DoesFilterMatchCurrentInstance(filter, instanceType, difficultyID) then
            return true
        end
    end

    return false
end

---@return table|nil loadouts List of {configID, name} for current spec
local function GetCurrentSpecLoadouts()
    if cachedLoadoutList then
        return cachedLoadoutList
    end

    local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
    if not specID then return nil end

    local configIDs = C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_ClassTalents.GetConfigIDsBySpecID(specID) or nil
    if not configIDs or #configIDs == 0 then return nil end

    local loadouts = {}
    for _, configID in ipairs(configIDs) do
        local configInfo = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID) or nil
        if configInfo and configInfo.ID and configInfo.name and configInfo.name ~= "" then
            loadouts[#loadouts + 1] = {
                configID = configInfo.ID,
                name = StripEscapeCodes(configInfo.name),
            }
        end
    end

    if #loadouts > 0 then
        cachedLoadoutList = loadouts
        return loadouts
    end

    return nil
end

---@return number|nil configID The last selected saved loadout config ID
local function GetCurrentLoadoutConfigID()
    local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
    if not specID then return nil end
    return C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID and C_ClassTalents.GetLastSelectedSavedConfigID(specID) or nil
end

---@return string name Current loadout name or "Unknown"
local function GetCurrentLoadoutName()
    local configID = GetCurrentLoadoutConfigID()
    if not configID then return UNKNOWN or "Unknown" end
    local configInfo = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID) or nil
    return (configInfo and configInfo.name and configInfo.name ~= "") and StripEscapeCodes(configInfo.name) or (UNKNOWN or "Unknown")
end

local seasonalDungeonNameCache = nil

local function GetSeasonalDungeonNameSet()
    if seasonalDungeonNameCache then
        return seasonalDungeonNameCache
    end
    local set = {}
    local mapIDs = C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable() or {}
    for _, mapID in ipairs(mapIDs) do
        local name = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID) or nil
        if type(name) == "string" and name ~= "" then
            set[name] = true
        end
    end
    seasonalDungeonNameCache = set
    return set
end

---@param settings table|nil Module settings table
---@return number|nil preferredConfigID The preferred loadout configID for the current instance, or nil if not configured
local function GetPreferredLoadoutForCurrentInstance(settings)
    if not settings or not settings.checkPreferredLoadout then
        return nil
    end
    local prefs = settings.dungeonPreferences
    if type(prefs) ~= "table" then
        return nil
    end
    local _, _, instanceName = GetInstanceState()
    if instanceName == "" then
        return nil
    end
    -- Only apply preferred loadout suppression for seasonal M+ dungeons
    local seasonalDungeons = GetSeasonalDungeonNameSet()
    if not seasonalDungeons[instanceName] then
        return nil
    end
    local configID = prefs[instanceName]
    if not configID or configID == 0 then
        return nil
    end
    -- Validate that the configID still exists
    local configInfo = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID) or nil
    if not configInfo or not configInfo.ID then
        return nil
    end
    return configID
end

local function GetBlockedReason()
    if InCombatLockdown and InCombatLockdown() then
        return "combat"
    end

    return nil
end

---@param inInstance boolean
---@param instanceType string
---@param difficultyID number
---@param loadoutConfigID number|nil
---@return string
local function BuildReminderStateSignature(inInstance, instanceType, difficultyID, loadoutConfigID)
    return table.concat({
        inInstance and "1" or "0",
        tostring(instanceType or "none"),
        tostring(difficultyID or 0),
        tostring(loadoutConfigID or 0),
    }, ":")
end

local function DismissReminder()
    local inInstance, instanceType, _, difficultyID = GetInstanceState()
    local loadoutConfigID = GetCurrentLoadoutConfigID()
    if inInstance then
        dismissedReminderSignature = BuildReminderStateSignature(inInstance, instanceType, difficultyID, loadoutConfigID)
    else
        dismissedReminderSignature = nil
    end

    if reminderFrame then
        reminderFrame:Hide()
    end
end

local function ShowError(message)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1)
    end
end

local function ShowBlockedReason(blockedReason)
    if blockedReason == "combat" then
        ShowError("Cannot switch talent loadout while in combat.")
    end
end

local function RequestDelayedRefresh()
    C_Timer.After(0.2, function()
        if ns.RequestRefresh then
            ns.RequestRefresh("talentLoadout")
        end
    end)
end

local function ShowLoadoutMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end

    local loadouts = GetCurrentSpecLoadouts()
    if not loadouts then return end

    local currentConfigID = GetCurrentLoadoutConfigID()
    local settings = GetSettings()
    local preferredConfigID = settings.checkPreferredLoadout and GetPreferredLoadoutForCurrentInstance(settings) or nil

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Talent Loadout")

        for _, loadout in ipairs(loadouts) do
            local displayName = (preferredConfigID and loadout.configID == preferredConfigID)
                and (loadout.name .. "  |TInterface\\AddOns\\NomTools\\media\\White_Star_Icon.png:12:12|t")
                or loadout.name
            local radio = rootDescription:CreateRadio(displayName, function()
                return currentConfigID == loadout.configID
            end, function()
                if InCombatLockdown and InCombatLockdown() then
                    ShowBlockedReason("combat")
                    return
                end

                local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
                if specID and C_ClassTalents and C_ClassTalents.LoadConfig then
                    C_ClassTalents.LoadConfig(loadout.configID, true)
                    if C_ClassTalents.UpdateLastSelectedSavedConfigID then
                        C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, loadout.configID)
                    end
                end

                if ns.RequestRefresh then
                    ns.RequestRefresh("talentLoadout")
                end
                RequestDelayedRefresh()
                return MenuResponse and MenuResponse.Close
            end, loadout.configID)

            if InCombatLockdown and InCombatLockdown() then
                radio:SetEnabled(false)
            end
        end
    end)
end

local function GetHintText()
    local blockedReason = GetBlockedReason()
    if blockedReason == "combat" then
        return "Talent loadout cannot be changed while in combat."
    end

    local settings = GetSettings()
    if settings and settings.checkPreferredLoadout then
        local preferredConfigID = GetPreferredLoadoutForCurrentInstance(settings)
        if preferredConfigID then
            local configInfo = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(preferredConfigID) or nil
            local preferredName = (configInfo and configInfo.name and configInfo.name ~= "")
                and StripEscapeCodes(configInfo.name)
                or "your preferred loadout"
            return string.format("Preferred: \"%s\". Left-click to switch.", preferredName)
        end
    end

    return "Left-click to choose a talent loadout."
end

local function ApplyReminderIcon(texture)
    if not texture then return end
    local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
    if specID then
        local _, _, _, icon = GetSpecializationInfoByID(specID)
        if icon then
            texture:SetAtlas(nil)
            texture:SetTexture(icon)
            texture:SetTexCoord(0, 1, 0, 1)
            return
        end
    end
    texture:SetAtlas(nil)
    texture:SetTexture(DEFAULT_ICON)
    texture:SetTexCoord(0, 1, 0, 1)
end

local function LayoutReminderFrame()
    local firstRowHeight = reminderFrame.titleText:GetStringHeight() or 0
    local textBlockHeight = firstRowHeight + 8 + (reminderFrame.specText:GetStringHeight() or 0) + 6 + (reminderFrame.hintText:GetStringHeight() or 0)
    local iconSize = math.max(MIN_ICON_SIZE, math.min(MAX_ICON_SIZE, math.ceil(textBlockHeight)))
    local titleWidth = math.ceil(reminderFrame.titleText:GetStringWidth() or 0)
    local specWidth = math.ceil(reminderFrame.specText:GetStringWidth() or 0)
    local preferredTextWidth = math.max(MIN_TEXT_WIDTH, math.min(MAX_TEXT_WIDTH, math.max(titleWidth + FRAME_CLOSE_BUTTON_SIZE + FRAME_CLOSE_BUTTON_GAP + 12, specWidth, 260)))
    local frameWidth = FRAME_LEFT_PADDING + iconSize + FRAME_ICON_GAP + preferredTextWidth + FRAME_RIGHT_PADDING

    reminderFrame:SetWidth(frameWidth)

    reminderFrame.icon:ClearAllPoints()
    reminderFrame.icon:SetPoint("TOPLEFT", reminderFrame, "TOPLEFT", FRAME_LEFT_PADDING, -FRAME_TOP_PADDING)
    reminderFrame.icon:SetSize(iconSize, iconSize)

    reminderFrame.closeButton:ClearAllPoints()
    reminderFrame.closeButton:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", 2, 2)
    reminderFrame.closeButton:SetSize(FRAME_CLOSE_BUTTON_SIZE, FRAME_CLOSE_BUTTON_SIZE)

    reminderFrame.titleText:ClearAllPoints()
    reminderFrame.titleText:SetPoint("TOPLEFT", reminderFrame.icon, "TOPRIGHT", FRAME_ICON_GAP, 0)
    reminderFrame.titleText:SetPoint("TOPRIGHT", reminderFrame.closeButton, "TOPLEFT", -FRAME_CLOSE_BUTTON_GAP, -2)
    reminderFrame.titleText:SetJustifyH("LEFT")

    reminderFrame.specText:ClearAllPoints()
    reminderFrame.specText:SetPoint("TOPLEFT", reminderFrame.titleText, "BOTTOMLEFT", 0, -8)
    reminderFrame.specText:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", -FRAME_RIGHT_PADDING, -(FRAME_TOP_PADDING + 18))

    reminderFrame.hintText:ClearAllPoints()
    reminderFrame.hintText:SetPoint("TOPLEFT", reminderFrame.specText, "BOTTOMLEFT", 0, -6)
    reminderFrame.hintText:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", -FRAME_RIGHT_PADDING, -(FRAME_TOP_PADDING + 36))

    local frameHeight = FRAME_TOP_PADDING + math.max(iconSize, textBlockHeight) + FRAME_BOTTOM_PADDING
    reminderFrame:SetHeight(math.ceil(frameHeight))
end

local function EnsureFrame()
    if reminderFrame then
        return
    end

    reminderFrame = CreateFrame("Button", "NomToolsTalentLoadoutReminderFrame", UIParent, "BackdropTemplate")
    reminderFrame:SetSize(336, 90)
    reminderFrame:SetPoint("TOP", UIParent, "TOP", 0, -428)
    reminderFrame:SetFrameStrata("MEDIUM")
    reminderFrame:SetClampedToScreen(true)
    reminderFrame:EnableMouse(true)
    reminderFrame:RegisterForClicks("LeftButtonUp")
    reminderFrame:SetBackdrop(NOMTOOLS_FRAME_BACKDROP)
    reminderFrame:SetBackdropColor(0, 0, 0, FRAME_BG_ALPHA)
    reminderFrame:SetBackdropBorderColor(0.28, 0.30, 0.34, 1)
    reminderFrame:Hide()

    local backgroundTexture = reminderFrame:CreateTexture(nil, "BACKGROUND")
    backgroundTexture:SetPoint("TOPLEFT", reminderFrame, "TOPLEFT", 1, -1)
    backgroundTexture:SetPoint("BOTTOMRIGHT", reminderFrame, "BOTTOMRIGHT", -1, 1)
    backgroundTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    backgroundTexture:SetVertexColor(0, 0, 0, 1)
    backgroundTexture:SetAlpha(FRAME_BG_ALPHA)
    reminderFrame.backgroundTexture = backgroundTexture

    local accent = reminderFrame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", reminderFrame, "TOPLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", 0, 0)
    accent:SetHeight(2)
    accent:SetColorTexture(0.96, 0.64, 0.22, 0.95)
    reminderFrame.accent = accent

    local borderFrame = CreateFrame("Frame", nil, reminderFrame, "BackdropTemplate")
    borderFrame:SetFrameLevel((reminderFrame:GetFrameLevel() or 0) + 1)
    borderFrame:Hide()
    reminderFrame.borderFrame = borderFrame

    local icon = reminderFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", reminderFrame, "TOPLEFT", FRAME_LEFT_PADDING, -FRAME_TOP_PADDING)
    icon:SetSize(MIN_ICON_SIZE, MIN_ICON_SIZE)
    reminderFrame.icon = icon
    ApplyReminderIcon(icon)

    local title = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", FRAME_ICON_GAP, 0)
    title:SetText("Talent Loadout")
    title:SetTextColor(1, 0.88, 0.74)
    reminderFrame.titleText = title

    local spec = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spec:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    spec:SetPoint("RIGHT", reminderFrame, "RIGHT", -FRAME_RIGHT_PADDING, 0)
    spec:SetJustifyH("LEFT")
    spec:SetTextColor(1, 1, 1)
    reminderFrame.specText = spec

    local hint = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", spec, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", reminderFrame, "RIGHT", -FRAME_RIGHT_PADDING, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.72, 0.78, 0.88)
    hint:SetText("Left-click to choose a talent loadout.")
    reminderFrame.hintText = hint

    local closeButton = CreateFrame("Button", nil, reminderFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", 2, 2)
    closeButton:SetSize(FRAME_CLOSE_BUTTON_SIZE, FRAME_CLOSE_BUTTON_SIZE)
    closeButton:SetScript("OnClick", function()
        DismissReminder()
    end)
    reminderFrame.closeButton = closeButton

    reminderFrame:SetScript("OnClick", function(self)
        if ns.isEditMode or IsOptionsPreviewActive() then
            return
        end

        local blockedReason = GetBlockedReason()
        if blockedReason then
            ShowBlockedReason(blockedReason)
            return
        end

        ShowLoadoutMenu(self)
    end)
    if ns.AttachEditModeSelectionProxy then
        ns.AttachEditModeSelectionProxy(reminderFrame)
    end

    ns.talentLoadoutReminderFrame = reminderFrame
    reminderFrame.editModeName = EDIT_MODE_LABEL
    ApplyFramePosition()
end

local function ShouldShowReminder()
    local settings = GetSettings()
    if not IsModuleEnabled(settings) then
        return false
    end

    if not IsInEnabledInstance(settings) then
        return false
    end

    -- If "check preferred loadout" is enabled and the player already has the preferred
    -- loadout active for this instance, suppress the reminder entirely.
    if settings.checkPreferredLoadout then
        local preferredConfigID = GetPreferredLoadoutForCurrentInstance(settings)
        if preferredConfigID then
            local currentConfigID = GetCurrentLoadoutConfigID()
            if currentConfigID == preferredConfigID then
                return false
            end
        end
    end

    return true
end

local function UpdateEventRegistration(shouldRegister)
    if shouldRegister and not eventsRegistered then
        eventsRegistered = true
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
        eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
        eventFrame:SetScript("OnEvent", function(_, event)
            if event == "TRAIT_CONFIG_LIST_UPDATED" then
                cachedLoadoutList = nil
            end
            if event == "ACTIVE_COMBAT_CONFIG_CHANGED" then
                dismissedReminderSignature = nil
            end
            if ns.RequestRefresh then
                ns.RequestRefresh("talentLoadout")
            end
        end)
        return
    end

    if not shouldRegister and eventsRegistered then
        eventsRegistered = false
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        eventFrame:UnregisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
        eventFrame:UnregisterEvent("TRAIT_CONFIG_LIST_UPDATED")
        eventFrame:SetScript("OnEvent", nil)
    end
end

function ns.InitializeTalentLoadoutUI()
    EnsureFrame()
    RegisterWithEditMode()
    UpdateEventRegistration(IsModuleEnabled(GetSettings()))
end

function ns.RefreshTalentLoadoutUI()
    EnsureFrame()
    RegisterWithEditMode()

    local settings = GetSettings()
    local optionsPreviewActive = IsOptionsPreviewActive()
    UpdateEventRegistration(IsModuleEnabled(settings))
    if not IsModuleEnabled(settings) and not optionsPreviewActive then
        reminderFrame:Hide()
        return
    end

    reminderFrame:EnableMouse(not (ns.isEditMode or optionsPreviewActive))
    ApplyReminderAppearance(settings)

    local loadoutName = GetCurrentLoadoutName()
    ApplyReminderIcon(reminderFrame.icon)
    reminderFrame.specText:SetText(string.format("Active: %s", loadoutName))

    if ns.isEditMode or optionsPreviewActive then
        dismissedReminderSignature = nil
        reminderFrame.closeButton:Hide()
        if optionsPreviewActive then
            reminderFrame.hintText:SetText("Preview shown while the Talent Loadout settings page is open.")
        else
            reminderFrame.hintText:SetText("Preview shown in Edit Mode.")
        end
        LayoutReminderFrame()
        ApplyFramePosition()
        reminderFrame:Show()
        return
    end

    local shouldShow = ShouldShowReminder()
    if not shouldShow then
        dismissedReminderSignature = nil
        reminderFrame:Hide()
        return
    end

    local inInstance, instanceType, _, difficultyID = GetInstanceState()
    local loadoutConfigID = GetCurrentLoadoutConfigID()
    local reminderSignature = BuildReminderStateSignature(inInstance, instanceType, difficultyID, loadoutConfigID)
    if dismissedReminderSignature and dismissedReminderSignature ~= reminderSignature then
        dismissedReminderSignature = nil
    end
    if dismissedReminderSignature == reminderSignature then
        reminderFrame:Hide()
        return
    end

    reminderFrame.closeButton:Show()
    reminderFrame.hintText:SetText(GetHintText())
    LayoutReminderFrame()
    ApplyFramePosition()
    reminderFrame:Show()
end

function ns.RefreshRemindersUI()
    if ns.RefreshDungeonDifficultyUI then ns.RefreshDungeonDifficultyUI() end
    if ns.RefreshGreatVaultUI then ns.RefreshGreatVaultUI() end
    ns.RefreshTalentLoadoutUI()
end
