local addonName, ns = ...

if addonName ~= "NomTools" then
    ns = _G.NomTools
    addonName = ns and ns.ADDON_NAME or "NomTools"
end

if not ns then
    return
end

local CONFIG_KEY = "reminder"
local PADDING_X = 12
local PADDING_Y = 10
local DURATION_HEIGHT = 14
local LABEL_HEIGHT = 30
local TEXT_RESERVED_PADDING = 20
local EMPTY_WIDTH = 210
local EMPTY_HEIGHT = 56
local CLOSE_BUTTON_SIZE = 18
local CLOSE_BUTTON_PADDING = 6
local EDIT_MODE_LABEL = "NomTools Consumables"
local EMPTY_BORDER_SEGMENTS = {}

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local reminderFrame
local buttons = {}
local registeredWithLEM = false
local callbacksRegistered = false
local consumableEventFrame = CreateFrame("Frame")
local consumableEventsRegistered = false
local readyCheckClearToken = 0
local consumableAuraDirty = false
local consumableAuraThrottled = false
local GLOW_KEY = "NomTools"
local FRAME_BG_ALPHA = 0.80
local lastAppearancePreviewState
local glowContextRefreshPending = false
local suppressGlowUntilRefresh = false
local dismissedEntriesSignature
local CONSUMABLE_AURA_THROTTLE_SECONDS = 1
local CONSUMABLE_EVENT_NAMES = {
    "BAG_UPDATE_DELAYED",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "CHALLENGE_MODE_START",
    "ENCOUNTER_END",
    "ENCOUNTER_START",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "READY_CHECK",
    "READY_CHECK_FINISHED",
    "ZONE_CHANGED_NEW_AREA",
}

local function IsConsumableModuleActive()
    if not ns.db then
        return false
    end

    if ns.IsModuleRuntimeEnabled then
        return ns.IsModuleRuntimeEnabled("consumables", ns.db.enabled)
    end

    return ns.db.enabled ~= false
end

local function RequestConsumablesRefresh()
    if ns.RequestRefresh then
        ns.RequestRefresh("consumables")
    elseif ns.RefreshUI then
        ns.RefreshUI()
    end
end

local function RunConsumableAuraRefresh()
    consumableAuraThrottled = false
    if consumableAuraDirty then
        consumableAuraDirty = false
        RequestConsumablesRefresh()
    end
end

local function OnConsumableEvent(_, event)
    if not IsConsumableModuleActive() then
        return
    end

    if event == "READY_CHECK" then
        readyCheckClearToken = readyCheckClearToken + 1
        ns.readyCheckActive = true
        RequestConsumablesRefresh()
        return
    end

    if event == "READY_CHECK_FINISHED" then
        readyCheckClearToken = readyCheckClearToken + 1

        local appearance = ns.GetConsumableAppearance and ns.GetConsumableAppearance() or nil
        local lingerDuration = tonumber(appearance and appearance.readyCheckGlowDuration) or 0

        if lingerDuration > 0 and C_Timer and C_Timer.After then
            local token = readyCheckClearToken
            C_Timer.After(lingerDuration, function()
                if token ~= readyCheckClearToken or not IsConsumableModuleActive() then
                    return
                end

                ns.readyCheckActive = false
                RequestConsumablesRefresh()
            end)
        else
            ns.readyCheckActive = false
        end

        RequestConsumablesRefresh()
        return
    end

    if event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
        if not consumableAuraThrottled then
            consumableAuraThrottled = true
            RequestConsumablesRefresh()
            if C_Timer and C_Timer.After then
                C_Timer.After(CONSUMABLE_AURA_THROTTLE_SECONDS, RunConsumableAuraRefresh)
            else
                RunConsumableAuraRefresh()
            end
        else
            consumableAuraDirty = true
        end
        return
    end

    if event == "BAG_UPDATE_DELAYED"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "CHALLENGE_MODE_COMPLETED"
        or event == "CHALLENGE_MODE_RESET"
        or event == "CHALLENGE_MODE_START"
    then
        RequestConsumablesRefresh()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        readyCheckClearToken = readyCheckClearToken + 1
        ns.readyCheckActive = false
        ns.encounterActive = false
        if not ns.isEditMode then
            RequestConsumablesRefresh()
        end
        return
    end

    if event == "ENCOUNTER_START" then
        ns.encounterActive = true
        RequestConsumablesRefresh()
        return
    end

    if event == "ENCOUNTER_END" then
        ns.encounterActive = false
        RequestConsumablesRefresh()
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        if not ns.isEditMode then
            RequestConsumablesRefresh()
        end
    end
end

local function UpdateConsumableEventRegistration(shouldRegister)
    if shouldRegister and not consumableEventsRegistered then
        for _, eventName in ipairs(CONSUMABLE_EVENT_NAMES) do
            consumableEventFrame:RegisterEvent(eventName)
        end
        consumableEventFrame:RegisterUnitEvent("UNIT_AURA", "player")
        consumableEventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
        consumableEventFrame:SetScript("OnEvent", OnConsumableEvent)
        consumableEventsRegistered = true
        return
    end

    if not shouldRegister and consumableEventsRegistered then
        for _, eventName in ipairs(CONSUMABLE_EVENT_NAMES) do
            consumableEventFrame:UnregisterEvent(eventName)
        end
        consumableEventFrame:UnregisterEvent("UNIT_AURA")
        consumableEventFrame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        consumableEventFrame:SetScript("OnEvent", nil)
        consumableEventsRegistered = false
    end

    if not shouldRegister then
        readyCheckClearToken = readyCheckClearToken + 1
        consumableAuraDirty = false
        consumableAuraThrottled = false
        ns.readyCheckActive = false
        ns.encounterActive = false
    end
end

local function EnsureBlizzardEditModeLoaded()
    return ns.EnsureBlizzardEditModeLoaded and ns.EnsureBlizzardEditModeLoaded() or false
end

local function GetDefaultConfig()
    return ns.DEFAULTS and ns.DEFAULTS.editMode and ns.DEFAULTS.editMode.reminder or {
        point = "TOP",
        x = 0,
        y = -140,
        scale = 1,
        strata = "HIGH",
    }
end

local function GetConfig(layoutName)
    return ns.GetEditModeConfig(CONFIG_KEY, GetDefaultConfig(), layoutName)
end

local function GetAppearanceDefaults()
    return ns.DEFAULTS and ns.DEFAULTS.consumables and ns.DEFAULTS.consumables.appearance or {
        showBorder = true,
        borderTexture = ns.GLOBAL_CHOICE_KEY,
        borderSize = 1,
        borderColor = {
            r = 0,
            g = 0,
            b = 0,
            a = 1,
        },
        iconSize = 40,
        spacing = 5,
        iconZoom = 0.30,
        font = "frizqt",
        fontSize = 12,
        labelTextEnabled = true,
        labelFontSize = 12,
        labelAnchor = "bottom",
        labelOffsetY = 0,
        durationTextEnabled = true,
        durationFontSize = 12,
        durationAnchor = "top",
        durationOffsetY = 0,
        countTextEnabled = true,
        countFontSize = 11,
        countAnchor = "bottom_right",
        countOffsetX = 0,
        countOffsetY = 0,
        fontOutline = "OUTLINE",
        glowMode = "ready_check",
        glowType = "proc",
        readyCheckGlowDuration = 5,
        glowFrequency = 0.5,
        glowSize = 1.5,
        glowPixelLines = 8,
        glowPixelLength = 10,
        glowPixelThickness = 2,
        glowAutocastParticles = 4,
        glowProcStartAnimation = true,
        glowColor = {
            r = 0.95,
            g = 0.95,
            b = 0.32,
            a = 1,
        },
    }
end

local function GetAppearanceConfig()
    return ns.GetConsumableAppearance and ns.GetConsumableAppearance() or GetAppearanceDefaults()
end

local function GetItemIconSafe(itemID)
    if not itemID then
        return 134400
    end

    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then
            return icon
        end
    end

    local getItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if getItemInfoInstant then
        local _, _, _, _, icon = getItemInfoInstant(itemID)
        if icon then
            return icon
        end
    end

    local icon = select(10, GetItemInfo(itemID))
    if icon then
        return icon
    end

    return 134400
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

local function GetPreviewSetupIndex(kind)
    if ns.GetActiveConsumableTrackerSetup then
        local activeSetupIndex = ns.GetActiveConsumableTrackerSetup(kind)
        if activeSetupIndex then
            return activeSetupIndex
        end
    end

    local maxSetups = ns.MAX_CONSUMABLE_TRACKER_SETUPS or 2
    for setupIndex = 1, maxSetups do
        if ns.GetConsumableTrackerEnabled
            and ns.GetConsumableTrackerEnabled(kind, setupIndex)
            and ns.IsConsumableTrackerSetupConfigured
            and ns.IsConsumableTrackerSetupConfigured(kind, setupIndex)
        then
            return setupIndex
        end
    end

    return nil
end

local function GetPreferredChoice(kind, setupIndex)
    local resolvedSetupIndex = tonumber(setupIndex) or 1

    if kind == "rune" then
        local runeKey = ns.GetConsumableChoice and ns.GetConsumableChoice(kind, resolvedSetupIndex) or "auto"
        return ns.GetChoiceEntry(kind, runeKey)
    end

    local choices = ns.GetPriorityChoices and ns.GetPriorityChoices(kind, resolvedSetupIndex) or nil
    for _, key in ipairs(choices or {}) do
        if key ~= "none" then
            local entry = ns.GetChoiceEntry(kind, key)
            if entry then
                return entry
            end

            if key == "auto" then
                break
            end
        end
    end

    return ns.GetChoiceEntry(kind, "auto")
end

local function GetPreferredPoisonPreviewChoice(poisonCategory, setupIndex)
    if ns.GetRoguePoisonChoice then
        local selectedKey = ns.GetRoguePoisonChoice(poisonCategory, setupIndex)
        if selectedKey == "none" then
            return nil
        end

        local selectedEntry = selectedKey and ns.GetChoiceEntry and ns.GetChoiceEntry("poisons", selectedKey) or nil
        if selectedEntry and selectedEntry.poisonCategory == poisonCategory then
            return selectedEntry
        end
    end

    for _, entry in ipairs(ns.GetChoiceEntries and ns.GetChoiceEntries("poisons") or {}) do
        if entry.poisonCategory == poisonCategory then
            return entry
        end
    end

    return nil
end

local function GetPreviewReapplyRemaining(kind, setupIndex, fallbackSeconds)
    local reapplyConfig = ns.GetConsumableReapplyConfig and ns.GetConsumableReapplyConfig(kind, setupIndex) or nil
    if not reapplyConfig or reapplyConfig.enabled == false then
        return nil
    end

    local thresholdSeconds = tonumber(reapplyConfig.thresholdSeconds)
    if thresholdSeconds and thresholdSeconds > 0 then
        return math.max(30, math.floor(thresholdSeconds))
    end

    return fallbackSeconds
end

local function BuildPreviewEntry(kind, label, choice, targetSlot, setupIndex)
    local itemID = choice and choice.items and choice.items[1] or nil
    local spellID = choice and choice.spellID or nil
    local reapplyKind = kind
    if kind == "weapon-main" or kind == "weapon-off" then
        reapplyKind = "weapon"
    elseif kind == "poison-lethal" or kind == "poison-non-lethal" then
        reapplyKind = "poisons"
    end

    local previewRemaining = GetPreviewReapplyRemaining(
        reapplyKind,
        setupIndex,
        (kind == "weapon-main" or kind == "weapon-off") and 720 or 900
    )

    return {
        kind = kind,
        label = label,
        name = choice and choice.name or label,
        itemID = itemID,
        spellID = spellID,
        icon = spellID and GetSpellIconSafe(spellID) or GetItemIconSafe(itemID),
        count = (choice and not spellID and ns.GetEntryItemCount and ns.GetEntryItemCount(choice)) or nil,
        reapplyRemainingSeconds = previewRemaining,
        targetSlot = targetSlot,
        available = itemID ~= nil or spellID ~= nil,
        reason = "Edit Mode preview.",
    }
end

local function BuildPreviewEntries()
    local entries = {}

    local flaskSetupIndex = GetPreviewSetupIndex("flask")
    if flaskSetupIndex then
        entries[#entries + 1] = BuildPreviewEntry("flask", "Flask", GetPreferredChoice("flask", flaskSetupIndex), nil, flaskSetupIndex)
    end

    local foodSetupIndex = GetPreviewSetupIndex("food")
    if foodSetupIndex then
        entries[#entries + 1] = BuildPreviewEntry("food", "Food", GetPreferredChoice("food", foodSetupIndex), nil, foodSetupIndex)
    end

    local runeSetupIndex = GetPreviewSetupIndex("rune")
    if runeSetupIndex then
        entries[#entries + 1] = BuildPreviewEntry("rune", "Rune", GetPreferredChoice("rune", runeSetupIndex), nil, runeSetupIndex)
    end

    local weaponSetupIndex = GetPreviewSetupIndex("weapon")
    if weaponSetupIndex then
        local weaponChoice = GetPreferredChoice("weapon", weaponSetupIndex)
        entries[#entries + 1] = BuildPreviewEntry("weapon-main", "Main Hand", weaponChoice, 16, weaponSetupIndex)
        entries[#entries + 1] = BuildPreviewEntry("weapon-off", "Off Hand", weaponChoice, 17, weaponSetupIndex)
    end

    local poisonSetupIndex = GetPreviewSetupIndex("poisons")
    if poisonSetupIndex then
        local lethalChoice = GetPreferredPoisonPreviewChoice("lethal", poisonSetupIndex)
        if lethalChoice then
            entries[#entries + 1] = BuildPreviewEntry("poison-lethal", "Lethal Poison", lethalChoice, nil, poisonSetupIndex)
        end

        local nonLethalChoice = GetPreferredPoisonPreviewChoice("non_lethal", poisonSetupIndex)
        if nonLethalChoice then
            entries[#entries + 1] = BuildPreviewEntry("poison-non-lethal", "Non-Lethal Poison", nonLethalChoice, nil, poisonSetupIndex)
        end
    end

    return entries
end

local function IsOptionsAppearancePreviewActive()
    return ns.GetActiveOptionsPreviewPage and ns.GetActiveOptionsPreviewPage() == "consumables"
end

local function ClearButtonAttributes(button)
    button:SetAttribute("type", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("target-slot", nil)
end

local function ApplyFrameConfig(layoutName)
    if not reminderFrame then
        return
    end

    local config = GetConfig(layoutName)
    reminderFrame:SetClampedToScreen(true)
    reminderFrame:SetScale(config.scale or 1)
    reminderFrame:SetFrameStrata(config.strata or "HIGH")

    reminderFrame:ClearAllPoints()
    reminderFrame:SetPoint(config.point or "CENTER", UIParent, config.point or "CENTER", config.x or 0, config.y or 0)

    for _, button in ipairs(buttons) do
        button:EnableMouse(not (ns.isEditMode or IsOptionsAppearancePreviewActive()))
    end
end

local function ApplyFrameVisualConfig(layoutName)
    if not reminderFrame then
        return
    end

    local config = GetConfig(layoutName)
    reminderFrame:SetClampedToScreen(true)
    reminderFrame:SetScale(config.scale or 1)
    reminderFrame:SetFrameStrata(config.strata or "HIGH")

    for _, button in ipairs(buttons) do
        button:EnableMouse(not (ns.isEditMode or IsOptionsAppearancePreviewActive()))
    end
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function ShowButtonTooltip(self)
    local entry = self.entry
    if not entry or ns.isEditMode or IsOptionsAppearancePreviewActive() then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    if entry.itemID then
        GameTooltip:SetItemByID(entry.itemID)
    elseif entry.spellID and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(entry.spellID)
    else
        GameTooltip:SetText(entry.name or entry.label)
    end

    GameTooltip:AddLine(" ")
    if entry.targetSlot == 16 then
        GameTooltip:AddLine("Click to apply this to your main hand.", 0.8, 0.9, 1, true)
    elseif entry.targetSlot == 17 then
        GameTooltip:AddLine("Click to apply this to your off hand.", 0.8, 0.9, 1, true)
    elseif entry.available and entry.spellID then
        GameTooltip:AddLine("Click to cast this poison.", 0.8, 0.9, 1, true)
    elseif entry.available then
        GameTooltip:AddLine("Click to use this consumable.", 0.8, 0.9, 1, true)
    end

    if entry.reason then
        GameTooltip:AddLine(entry.reason, 1, 0.35, 0.35, true)
    end

    GameTooltip:Show()
end

local function DeferredRefreshConsumables()
    if ns.RequestRefresh then
        ns.RequestRefresh("consumables")
    end
end

local function PostClickRefreshConsumables()
    C_Timer.After(0.2, DeferredRefreshConsumables)
end

local function RoundBorderSize(value, defaultValue)
    local resolved = tonumber(value)
    if resolved == nil then
        resolved = tonumber(defaultValue) or 1
    end

    if resolved >= 0 then
        resolved = math.floor(resolved + 0.5)
    else
        resolved = math.ceil(resolved - 0.5)
    end

    return math.max(-10, math.min(10, resolved))
end

local function NormalizeConsumableBorderColor(color, fallback)
    fallback = fallback or { r = 0, g = 0, b = 0, a = 1 }
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

local function BuildConsumableBorderBackdrop(textureKey, borderSize)
    local definition = ns.GetBorderTextureDefinition and ns.GetBorderTextureDefinition(textureKey) or nil
    local magnitude = math.abs(borderSize)
    local baseEdgeSize = math.max(1, tonumber(definition and definition.edgeSize) or 1)
    local scaleStep = math.max(0, tonumber(definition and definition.scaleStep) or 1)
    local edgeSize = baseEdgeSize

    if magnitude > 0 and (not definition or definition.supportsVariableThickness ~= false) then
        edgeSize = edgeSize + (math.max(magnitude - 1, 0) * scaleStep)
    end

    local insets = definition and definition.insets or nil
    local fallbackInset = math.max(1, math.floor(edgeSize / 4))
    return {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = (definition and definition.path) or textureKey or "Interface\\Buttons\\WHITE8x8",
        tile = definition and definition.tile ~= false or true,
        tileSize = math.max(1, tonumber(definition and definition.tileSize) or 8),
        edgeSize = math.max(1, edgeSize),
        insets = {
            left = tonumber(insets and insets.left) or fallbackInset,
            right = tonumber(insets and insets.right) or fallbackInset,
            top = tonumber(insets and insets.top) or fallbackInset,
            bottom = tonumber(insets and insets.bottom) or fallbackInset,
        },
    }
end

local function SetButtonBorderShown(button, shown, appearance, alpha)
    local borderFrame = button and button.borderFrame or nil
    if not borderFrame then
        return
    end

    if not shown then
        borderFrame:Hide()
        return
    end

    local defaults = GetAppearanceDefaults()
    local borderSize = RoundBorderSize(appearance and appearance.borderSize, defaults.borderSize or 1)
    if borderSize == 0 then
        borderFrame:Hide()
        return
    end

    local magnitude = math.abs(borderSize)
    borderFrame:ClearAllPoints()
    if borderSize > 0 then
        borderFrame:SetPoint("TOPLEFT", button, "TOPLEFT", -magnitude, magnitude)
        borderFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", magnitude, -magnitude)
    elseif borderSize < 0 then
        borderFrame:SetPoint("TOPLEFT", button, "TOPLEFT", magnitude, -magnitude)
        borderFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -magnitude, magnitude)
    else
        borderFrame:SetAllPoints(button)
    end

    local textureKey = type(appearance and appearance.borderTexture) == "string" and appearance.borderTexture ~= ""
        and appearance.borderTexture
        or defaults.borderTexture
        or ns.GLOBAL_CHOICE_KEY
    local backdropInfo = BuildConsumableBorderBackdrop(textureKey, borderSize)
    if borderFrame.nomtoolsBorderEdgeFile ~= backdropInfo.edgeFile then
        borderFrame:SetBackdrop(nil)
    end
    borderFrame.nomtoolsBorderEdgeFile = backdropInfo.edgeFile
    borderFrame:SetBackdrop(backdropInfo)
    borderFrame:SetBackdropColor(0, 0, 0, 0)

    local color = NormalizeConsumableBorderColor(appearance and appearance.borderColor, defaults.borderColor)
    local borderAlpha = tonumber(alpha) or 1
    borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, (color.a or 1) * borderAlpha)
    borderFrame:Show()
end

local glowColorScratch = { 0, 0, 0, 0 }

local function GetGlowColor(appearance)
    local defaults = GetAppearanceDefaults().glowColor or { r = 0.95, g = 0.95, b = 0.32, a = 1 }
    local configured = appearance and appearance.glowColor or nil

    glowColorScratch[1] = tonumber(configured and (configured.r or configured[1])) or defaults.r
    glowColorScratch[2] = tonumber(configured and (configured.g or configured[2])) or defaults.g
    glowColorScratch[3] = tonumber(configured and (configured.b or configured[3])) or defaults.b
    glowColorScratch[4] = tonumber(configured and (configured.a or configured[4])) or defaults.a

    return glowColorScratch
end

local glowSigParts = {}

local function GetGlowSignature(glowType, color, appearance)
    local n = 0
    n = n + 1; glowSigParts[n] = glowType or "button"
    n = n + 1; glowSigParts[n] = string.format("%.3f", color[1] or 0)
    n = n + 1; glowSigParts[n] = string.format("%.3f", color[2] or 0)
    n = n + 1; glowSigParts[n] = string.format("%.3f", color[3] or 0)
    n = n + 1; glowSigParts[n] = string.format("%.3f", color[4] or 0)
    n = n + 1; glowSigParts[n] = string.format("%.3f", tonumber(appearance and appearance.glowFrequency) or 0)
    n = n + 1; glowSigParts[n] = string.format("%.3f", tonumber(appearance and appearance.glowSize) or 0)
    n = n + 1; glowSigParts[n] = tostring(tonumber(appearance and appearance.glowPixelLines) or 0)
    n = n + 1; glowSigParts[n] = tostring(tonumber(appearance and appearance.glowPixelLength) or 0)
    n = n + 1; glowSigParts[n] = string.format("%.3f", tonumber(appearance and appearance.glowPixelThickness) or 0)
    n = n + 1; glowSigParts[n] = tostring(tonumber(appearance and appearance.glowAutocastParticles) or 0)
    n = n + 1; glowSigParts[n] = tostring(not not (appearance and appearance.glowProcStartAnimation))
    for i = n + 1, #glowSigParts do glowSigParts[i] = nil end
    return table.concat(glowSigParts, ":")
end

local glowCtxSigParts = {}

local function BuildGlowContextSignature(button, optionsPreviewActive)
    glowCtxSigParts[1] = optionsPreviewActive and "preview" or "live"
    glowCtxSigParts[2] = tostring(math.floor(((button and button:GetWidth()) or 0) + 0.5))
    glowCtxSigParts[3] = tostring(math.floor(((button and button:GetHeight()) or 0) + 0.5))
    for i = 4, #glowCtxSigParts do glowCtxSigParts[i] = nil end
    return table.concat(glowCtxSigParts, ":")
end

local glowOptionsScratch = {}

local function GetGlowOptions(appearance, button)
    local defaults = GetAppearanceDefaults()
    local width = (button and button:GetWidth()) or defaults.iconSize or 40
    local height = (button and button:GetHeight()) or defaults.iconSize or 40
    local size = tonumber(appearance and appearance.glowSize) or defaults.glowSize or 1
    local frequency = tonumber(appearance and appearance.glowFrequency) or defaults.glowFrequency or 1.2
    local procDuration = math.max(0.2, math.min(3, 1 / math.max(0.1, frequency)))
    local pixelLines = tonumber(appearance and appearance.glowPixelLines) or defaults.glowPixelLines or 8
    local pixelLength = tonumber(appearance and appearance.glowPixelLength) or defaults.glowPixelLength or 10
    local pixelThickness = tonumber(appearance and appearance.glowPixelThickness) or defaults.glowPixelThickness or 2
    local autocastParticles = tonumber(appearance and appearance.glowAutocastParticles) or defaults.glowAutocastParticles or 4

    glowOptionsScratch.frequency = math.max(0.1, frequency)
    glowOptionsScratch.buttonFrequency = math.max(0.1, frequency * math.max(0.7, math.min(2.5, size)))
    glowOptionsScratch.pixelLines = math.max(4, math.floor(pixelLines + 0.5))
    glowOptionsScratch.pixelLength = math.max(4, math.floor(pixelLength + 0.5))
    glowOptionsScratch.pixelThickness = math.max(1, math.min(6, pixelThickness))
    glowOptionsScratch.autocastParticles = math.max(2, math.floor(autocastParticles + 0.5))
    glowOptionsScratch.autocastScale = math.max(0.6, math.min(2.5, size))
    glowOptionsScratch.procDuration = procDuration
    glowOptionsScratch.procOffsetX = math.floor((width * 0.2) * math.max(0, size - 1) + 0.5)
    glowOptionsScratch.procOffsetY = math.floor((height * 0.2) * math.max(0, size - 1) + 0.5)
    glowOptionsScratch.procStartAnimation = appearance and appearance.glowProcStartAnimation ~= false or defaults.glowProcStartAnimation ~= false

    return glowOptionsScratch
end

local function StopCustomProcGlow(button)
    local glowFrame = button and button.nomtoolsProcGlow or nil
    if not glowFrame then
        return
    end

    if glowFrame.startAnim:IsPlaying() then
        glowFrame.startAnim:Stop()
    end
    if glowFrame.loopAnim:IsPlaying() then
        glowFrame.loopAnim:Stop()
    end

    glowFrame.startTexture:Hide()
    glowFrame.startTexture:SetAlpha(1)
    glowFrame.loopTexture:Hide()
    glowFrame.loopTexture:SetAlpha(0)
    glowFrame:Hide()
    glowFrame:ClearAllPoints()
end

local function EnsureCustomProcGlow(button)
    if button.nomtoolsProcGlow then
        return button.nomtoolsProcGlow
    end

    local glowFrame = CreateFrame("Frame", nil, button)

    local startTexture = glowFrame:CreateTexture(nil, "ARTWORK")
    startTexture:SetBlendMode("ADD")
    startTexture:SetAtlas("UI-HUD-ActionBar-Proc-Start-Flipbook")
    startTexture:SetAlpha(1)
    startTexture:SetSize(150, 150)
    startTexture:SetPoint("CENTER")
    glowFrame.startTexture = startTexture

    local loopTexture = glowFrame:CreateTexture(nil, "ARTWORK")
    loopTexture:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
    loopTexture:SetAlpha(0)
    loopTexture:SetAllPoints()
    glowFrame.loopTexture = loopTexture

    local loopAnim = glowFrame:CreateAnimationGroup()
    loopAnim:SetLooping("REPEAT")
    loopAnim:SetToFinalAlpha(true)

    local alphaRepeat = loopAnim:CreateAnimation("Alpha")
    alphaRepeat:SetChildKey("loopTexture")
    alphaRepeat:SetFromAlpha(1)
    alphaRepeat:SetToAlpha(1)
    alphaRepeat:SetDuration(0.001)
    alphaRepeat:SetOrder(0)

    local flipbookRepeat = loopAnim:CreateAnimation("FlipBook")
    flipbookRepeat:SetChildKey("loopTexture")
    flipbookRepeat:SetDuration(1)
    flipbookRepeat:SetOrder(0)
    flipbookRepeat:SetFlipBookRows(6)
    flipbookRepeat:SetFlipBookColumns(5)
    flipbookRepeat:SetFlipBookFrames(30)
    flipbookRepeat:SetFlipBookFrameWidth(0)
    flipbookRepeat:SetFlipBookFrameHeight(0)
    loopAnim.flipbookRepeat = flipbookRepeat
    glowFrame.loopAnim = loopAnim

    local startAnim = glowFrame:CreateAnimationGroup()
    startAnim:SetToFinalAlpha(true)

    local startAlphaIn = startAnim:CreateAnimation("Alpha")
    startAlphaIn:SetChildKey("startTexture")
    startAlphaIn:SetDuration(0.001)
    startAlphaIn:SetOrder(0)
    startAlphaIn:SetFromAlpha(1)
    startAlphaIn:SetToAlpha(1)

    local startFlipbook = startAnim:CreateAnimation("FlipBook")
    startFlipbook:SetChildKey("startTexture")
    startFlipbook:SetDuration(0.7)
    startFlipbook:SetOrder(1)
    startFlipbook:SetFlipBookRows(6)
    startFlipbook:SetFlipBookColumns(5)
    startFlipbook:SetFlipBookFrames(30)
    startFlipbook:SetFlipBookFrameWidth(0)
    startFlipbook:SetFlipBookFrameHeight(0)

    local startAlphaOut = startAnim:CreateAnimation("Alpha")
    startAlphaOut:SetChildKey("startTexture")
    startAlphaOut:SetDuration(0.001)
    startAlphaOut:SetOrder(2)
    startAlphaOut:SetFromAlpha(1)
    startAlphaOut:SetToAlpha(0)

    startAnim:SetScript("OnFinished", function(self)
        local frame = self:GetParent()
        if not frame:IsShown() then
            return
        end

        frame.startTexture:Hide()
        frame.loopTexture:SetAlpha(1)
        frame.loopTexture:Show()
        if not frame.loopAnim:IsPlaying() then
            frame.loopAnim:Play()
        end
    end)
    glowFrame.startAnim = startAnim

    glowFrame:SetScript("OnHide", function(self)
        if self.startAnim:IsPlaying() then
            self.startAnim:Stop()
        end
        if self.loopAnim:IsPlaying() then
            self.loopAnim:Stop()
        end

        self.startTexture:Hide()
        self.startTexture:SetAlpha(1)
        self.loopTexture:Hide()
        self.loopTexture:SetAlpha(0)
    end)

    button.nomtoolsProcGlow = glowFrame
    return glowFrame
end

local function StartCustomProcGlow(button, glowColor, glowOptions, frameLevel)
    if not button then
        return
    end

    local glowFrame = EnsureCustomProcGlow(button)
    local width, height = button:GetSize()
    local xOffset = glowOptions.procOffsetX + (width * 0.2)
    local yOffset = glowOptions.procOffsetY + (height * 0.2)

    StopCustomProcGlow(button)

    glowFrame:SetParent(button)
    glowFrame:SetFrameLevel(button:GetFrameLevel() + frameLevel)
    glowFrame:ClearAllPoints()
    glowFrame:SetPoint("TOPLEFT", button, "TOPLEFT", -xOffset, yOffset)
    glowFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", xOffset, -yOffset)

    if not glowColor then
        glowFrame.startTexture:SetDesaturated(nil)
        glowFrame.startTexture:SetVertexColor(1, 1, 1, 1)
        glowFrame.loopTexture:SetDesaturated(nil)
        glowFrame.loopTexture:SetVertexColor(1, 1, 1, 1)
    else
        glowFrame.startTexture:SetDesaturated(1)
        glowFrame.startTexture:SetVertexColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4])
        glowFrame.loopTexture:SetDesaturated(1)
        glowFrame.loopTexture:SetVertexColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4])
    end

    glowFrame.loopAnim.flipbookRepeat:SetDuration(glowOptions.procDuration)
    glowFrame:Show()

    if glowOptions.procStartAnimation then
        local frameWidth, frameHeight = glowFrame:GetSize()
        glowFrame.startTexture:SetSize((frameWidth / 42 * 150) / 1.4, (frameHeight / 42 * 150) / 1.4)
        glowFrame.startTexture:SetAlpha(1)
        glowFrame.startTexture:Show()
        glowFrame.loopTexture:SetAlpha(0)
        glowFrame.loopTexture:Hide()
        glowFrame.startAnim:Play()
    else
        glowFrame.startTexture:Hide()
        glowFrame.loopTexture:SetAlpha(1)
        glowFrame.loopTexture:Show()
        glowFrame.loopAnim:Play()
    end
end

local function ForceReleaseGlowFrame(button, fieldName, pool)
    if not button or not fieldName or not pool or not pool.Release then
        return
    end

    local glowFrame = button[fieldName]
    if not glowFrame then
        return
    end

    if glowFrame.animIn and glowFrame.animIn.IsPlaying and glowFrame.animIn:IsPlaying() then
        glowFrame.animIn:Stop()
    end
    if glowFrame.animOut and glowFrame.animOut.IsPlaying and glowFrame.animOut:IsPlaying() then
        glowFrame.animOut:Stop()
    end
    if glowFrame.ProcStartAnim and glowFrame.ProcStartAnim.IsPlaying and glowFrame.ProcStartAnim:IsPlaying() then
        glowFrame.ProcStartAnim:Stop()
    end
    if glowFrame.ProcLoopAnim and glowFrame.ProcLoopAnim.IsPlaying and glowFrame.ProcLoopAnim:IsPlaying() then
        glowFrame.ProcLoopAnim:Stop()
    end

    glowFrame:Hide()
    glowFrame:ClearAllPoints()
    pool:Release(glowFrame)
end

local function ForceReleaseAllGlowFrames(button)
    if not button or not LCG then
        return
    end

    ForceReleaseGlowFrame(button, "_ButtonGlow", LCG.ButtonGlowPool)
    ForceReleaseGlowFrame(button, "_PixelGlow" .. GLOW_KEY, LCG.GlowFramePool)
    ForceReleaseGlowFrame(button, "_AutoCastGlow" .. GLOW_KEY, LCG.GlowFramePool)
    ForceReleaseGlowFrame(button, "_ProcGlow" .. GLOW_KEY, LCG.ProcGlowPool)
end

local function StopButtonGlow(button)
    if not button then
        return
    end

    StopCustomProcGlow(button)

    if LCG then
        LCG.PixelGlow_Stop(button, GLOW_KEY)
        LCG.AutoCastGlow_Stop(button, GLOW_KEY)
        LCG.ProcGlow_Stop(button, GLOW_KEY)
        LCG.ButtonGlow_Stop(button)
        ForceReleaseAllGlowFrames(button)
    elseif ActionButton_HideOverlayGlow then
        ActionButton_HideOverlayGlow(button)
    end

    button.nomtoolsGlowActive = false
    button.nomtoolsGlowSignature = nil
end

local function StopAllButtonGlows()
    for _, button in ipairs(buttons) do
        StopButtonGlow(button)
    end
end

local function RunGlowContextRefresh()
    glowContextRefreshPending = false
    suppressGlowUntilRefresh = false
    if ns.RequestRefresh then
        ns.RequestRefresh("consumables")
    end
end

local function QueueGlowContextRefresh()
    if glowContextRefreshPending then
        return
    end

    glowContextRefreshPending = true
    C_Timer.After(0, RunGlowContextRefresh)
end

local function StartButtonGlow(button, appearance, signature)
    if not button then
        return
    end

    local glowType = appearance and appearance.glowType or GetAppearanceDefaults().glowType or "button"
    local glowColor = GetGlowColor(appearance)
    local frameLevel = 10
    local glowOptions = GetGlowOptions(appearance, button)

    if LCG then
        if glowType == "pixel" then
            LCG.PixelGlow_Start(button, glowColor, glowOptions.pixelLines, glowOptions.frequency, glowOptions.pixelLength, glowOptions.pixelThickness, 0, 0, false, GLOW_KEY, frameLevel)
        elseif glowType == "autocast" then
            LCG.AutoCastGlow_Start(button, glowColor, glowOptions.autocastParticles, glowOptions.frequency, glowOptions.autocastScale, 0, 0, GLOW_KEY, frameLevel)
        elseif glowType == "proc" then
            StartCustomProcGlow(button, glowColor, glowOptions, frameLevel)
        else
            -- ButtonGlow_Start stores f.color = color; use a per-button copy
            -- so the shared scratch table is safe for other callers.
            if not button.nomtoolsGlowColorCopy then
                button.nomtoolsGlowColorCopy = { glowColor[1], glowColor[2], glowColor[3], glowColor[4] }
            else
                button.nomtoolsGlowColorCopy[1] = glowColor[1]
                button.nomtoolsGlowColorCopy[2] = glowColor[2]
                button.nomtoolsGlowColorCopy[3] = glowColor[3]
                button.nomtoolsGlowColorCopy[4] = glowColor[4]
            end
            LCG.ButtonGlow_Start(button, button.nomtoolsGlowColorCopy, glowOptions.buttonFrequency, frameLevel)
        end
    elseif glowType == "proc" then
        StartCustomProcGlow(button, glowColor, glowOptions, frameLevel)
    elseif ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(button)
    end

    button.nomtoolsGlowActive = true
    button.nomtoolsGlowSignature = signature or GetGlowSignature(glowType, glowColor, appearance)
end

local glowShownSigParts = {}

local function SetButtonGlowShown(button, shown, appearance, contextSignature)
    if not shown then
        StopButtonGlow(button)
        return
    end

    GetGlowColor(appearance)
    glowShownSigParts[1] = GetGlowSignature(appearance and appearance.glowType, glowColorScratch, appearance)
    glowShownSigParts[2] = contextSignature or "live:0:0"
    for i = 3, #glowShownSigParts do glowShownSigParts[i] = nil end
    local signature = table.concat(glowShownSigParts, ":")
    if button.nomtoolsGlowActive and button.nomtoolsGlowSignature == signature then
        return
    end

    StopButtonGlow(button)
    StartButtonGlow(button, appearance, signature)
end

local function ApplyButtonAppearance(button, entry, iconSize)
    local appearance = GetAppearanceConfig()
    local zoom = appearance.iconZoom or GetAppearanceDefaults().iconZoom
    local fontPath = ns.GetFontPath and ns.GetFontPath(appearance.font) or "Fonts\\FRIZQT__.TTF"
    local defaults = GetAppearanceDefaults()
    local labelFontSize = appearance.labelFontSize or appearance.fontSize or defaults.labelFontSize or defaults.fontSize
    local countFontSize = appearance.countFontSize or math.max(9, labelFontSize - 1)
    local durationFontSize = appearance.durationFontSize or appearance.fontSize or defaults.durationFontSize or defaults.fontSize
    local outlineFlags = ns.GetFontOutlineFlags and ns.GetFontOutlineFlags(appearance.fontOutline) or "OUTLINE"
    local shouldGlow = false
    local optionsPreviewActive = IsOptionsAppearancePreviewActive()

    zoom = math.max(0, math.min(0.45, zoom))
    button.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    button.label:SetFont(fontPath, labelFontSize, outlineFlags)
    button.count:SetFont(fontPath, countFontSize, outlineFlags)
    button.duration:SetFont(fontPath, durationFontSize, outlineFlags)
    button.label:SetWidth(iconSize)
    button.duration:SetWidth(iconSize + 12)

    if appearance.glowMode == "always" then
        shouldGlow = entry ~= nil and (entry.available or ns.isEditMode or optionsPreviewActive)
    elseif appearance.glowMode == "ready_check" then
        shouldGlow = entry ~= nil and entry.available and ((ns.readyCheckActive and not ns.isEditMode and not optionsPreviewActive) or optionsPreviewActive)
    end

    if suppressGlowUntilRefresh then
        shouldGlow = false
    end

    SetButtonBorderShown(button, entry ~= nil, appearance, 1)
    SetButtonGlowShown(button, shouldGlow, appearance, BuildGlowContextSignature(button, optionsPreviewActive))
end

local function GetLabelBlockHeight(appearance)
    local defaults = GetAppearanceDefaults()
    local size = appearance.labelFontSize or appearance.fontSize or defaults.labelFontSize or defaults.fontSize
    return math.max(LABEL_HEIGHT, math.floor((size * 2) + 6))
end

local function GetDurationBlockHeight(appearance)
    local defaults = GetAppearanceDefaults()
    local size = appearance.durationFontSize or appearance.fontSize or defaults.durationFontSize or defaults.fontSize
    return math.max(DURATION_HEIGHT, math.floor(size + 4))
end

local function GetSideTextHeights(appearance)
    local topHeight = 0
    local bottomHeight = 0

    if appearance.durationTextEnabled ~= false then
        if (appearance.durationAnchor or "top") == "top" then
            topHeight = topHeight + GetDurationBlockHeight(appearance)
        else
            bottomHeight = bottomHeight + GetDurationBlockHeight(appearance)
        end
    end

    if appearance.labelTextEnabled ~= false then
        if (appearance.labelAnchor or "bottom") == "top" then
            topHeight = topHeight + GetLabelBlockHeight(appearance)
        else
            bottomHeight = bottomHeight + GetLabelBlockHeight(appearance)
        end
    end

    if topHeight > 0 then
        topHeight = topHeight + TEXT_RESERVED_PADDING
    end
    if bottomHeight > 0 then
        bottomHeight = bottomHeight + TEXT_RESERVED_PADDING
    end

    return topHeight, bottomHeight
end

local function LayoutButtonText(button, appearance)
    local countAnchor = appearance.countAnchor or "bottom_right"
    local countOffsetX = tonumber(appearance.countOffsetX) or 0
    local countOffsetY = tonumber(appearance.countOffsetY) or 0
    local labelAnchor = appearance.labelAnchor or "bottom"
    local labelOffsetY = tonumber(appearance.labelOffsetY) or 0
    local durationAnchor = appearance.durationAnchor or "top"
    local durationOffsetY = tonumber(appearance.durationOffsetY) or 0
    local topCursor = 0
    local bottomCursor = 0

    button.count:ClearAllPoints()
    if countAnchor == "top_left" then
        button.count:SetPoint("TOPLEFT", button, "TOPLEFT", 2 + countOffsetX, -2 + countOffsetY)
        button.count:SetJustifyH("LEFT")
    elseif countAnchor == "top_right" then
        button.count:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2 + countOffsetX, -2 + countOffsetY)
        button.count:SetJustifyH("RIGHT")
    elseif countAnchor == "bottom_left" then
        button.count:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2 + countOffsetX, 2 + countOffsetY)
        button.count:SetJustifyH("LEFT")
    else
        button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2 + countOffsetX, 2 + countOffsetY)
        button.count:SetJustifyH("RIGHT")
    end

    button.duration:ClearAllPoints()
    button.duration:SetJustifyH("CENTER")
    button.duration:SetJustifyV("BOTTOM")
    if durationAnchor ~= "bottom" then
        button.duration:SetPoint("BOTTOM", button, "TOP", 0, 2 + durationOffsetY + topCursor)
        topCursor = topCursor + GetDurationBlockHeight(appearance)
    end

    button.label:ClearAllPoints()
    button.label:SetJustifyH("CENTER")
    button.label:SetJustifyV("TOP")
    if labelAnchor == "top" then
        button.label:SetPoint("BOTTOM", button, "TOP", 0, 2 + labelOffsetY + topCursor)
        topCursor = topCursor + GetLabelBlockHeight(appearance)
    else
        button.label:SetPoint("TOP", button, "BOTTOM", 0, -2 + labelOffsetY - bottomCursor)
        bottomCursor = bottomCursor + GetLabelBlockHeight(appearance)
    end

    if durationAnchor == "bottom" then
        button.duration:SetPoint("TOP", button, "BOTTOM", 0, -2 + durationOffsetY - bottomCursor)
        bottomCursor = bottomCursor + GetDurationBlockHeight(appearance)
    end
end

local function CreateReminderButton(index)
    local button = CreateFrame("Button", "NomToolsReminderButton" .. index, reminderFrame, "SecureActionButtonTemplate")
    local iconSize = GetAppearanceConfig().iconSize or GetAppearanceDefaults().iconSize
    button:SetSize(iconSize, iconSize)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", false)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, FRAME_BG_ALPHA)
    button.background = background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local borderFrame = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate" or nil)
    borderFrame:SetAllPoints(button)
    borderFrame:SetFrameLevel(button:GetFrameLevel() + 3)
    borderFrame:EnableMouse(false)
    borderFrame:Hide()
    button.borderFrame = borderFrame

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    count:SetJustifyH("RIGHT")
    button.count = count

    local duration = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    duration:SetJustifyH("CENTER")
    duration:SetJustifyV("BOTTOM")
    duration:SetTextColor(1, 0.2, 0.2)
    duration:SetWordWrap(false)
    duration:Hide()
    button.duration = duration

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetTextColor(0.9, 0.9, 0.9)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("TOP")
    label:SetWordWrap(true)
    if label.SetNonSpaceWrap then
        label:SetNonSpaceWrap(false)
    end
    button.label = label

    button:SetScript("OnEnter", ShowButtonTooltip)
    button:SetScript("OnLeave", HideTooltip)
    button:HookScript("PostClick", PostClickRefreshConsumables)

    ApplyButtonAppearance(button, nil, iconSize)
    button:Hide()
    return button
end

local function EnsureReminderButtons(requiredCount)
    if type(requiredCount) ~= "number" or requiredCount <= #buttons then
        return
    end

    for index = #buttons + 1, requiredCount do
        buttons[index] = CreateReminderButton(index)
    end
end

local function RegisterEditModeCallbacks()
    if ns.InitializeEditModeSystem then
        callbacksRegistered = ns.InitializeEditModeSystem() == true
    end
end

local function RegisterWithEditMode()
    if registeredWithLEM or not reminderFrame or not EnsureBlizzardEditModeLoaded() or not ns.RegisterEditModeFrame then
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
        onPositionChanged = function(layoutName, point, x, y)
            local config = GetConfig(layoutName)
            config.point = point
            config.x = x
            config.y = y
            ApplyFrameVisualConfig(layoutName)
        end,
    }) == true
end

local function EnsureFrame()
    if reminderFrame then
        return
    end

    reminderFrame = CreateFrame("Frame", "NomToolsReminderFrame", UIParent)
    reminderFrame.editModeName = EDIT_MODE_LABEL
    reminderFrame:SetMovable(true)
    reminderFrame:SetClampedToScreen(true)
    reminderFrame:SetFrameStrata("HIGH")

    local editModeLabel = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editModeLabel:SetPoint("CENTER", reminderFrame, "CENTER", 0, 0)
    editModeLabel:SetText(EDIT_MODE_LABEL)
    editModeLabel:SetTextColor(0.92, 0.92, 0.92)
    editModeLabel:Hide()
    reminderFrame.editModeLabel = editModeLabel

    local closeButton = CreateFrame("Button", nil, reminderFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", 2, 2)
    closeButton:SetSize(CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE)
    closeButton:SetScript("OnClick", function()
        dismissedEntriesSignature = reminderFrame.nomtoolsDismissCandidateSignature
        if not InCombatLockdown() then
            StopAllButtonGlows()
            reminderFrame:Hide()
        end
        if ns.RequestRefresh then
            ns.RequestRefresh("consumables")
        end
    end)
    closeButton:Hide()
    reminderFrame.closeButton = closeButton

    EnsureReminderButtons(5)

    ns.reminderFrame = reminderFrame
    ApplyFrameConfig()
    RegisterEditModeCallbacks()
    RegisterWithEditMode()
end

function ns.InitializeConsumablesModule()
    if ns.MigrateLegacyConsumableConfig and ns.db then
        ns.MigrateLegacyConsumableConfig()
    end

    EnsureFrame()
    UpdateConsumableEventRegistration(IsConsumableModuleActive())
end

ns.InitializeUI = ns.InitializeConsumablesModule

local function FormatReapplyRemaining(remainingSeconds)
    if type(remainingSeconds) ~= "number" then
        return nil
    end

    local remaining = math.max(0, remainingSeconds)
    if remaining >= 3600 then
        return string.format("%dh", math.ceil(remaining / 3600))
    end
    if remaining >= 60 then
        return string.format("%dm", math.ceil(remaining / 60))
    end

    return string.format("%ds", math.ceil(remaining))
end

local entriesSigParts = {}
local entriesSigEntry = {}

local function BuildReminderEntriesSignature(entries)
    local parts = entriesSigParts
    for k in pairs(parts) do parts[k] = nil end
    parts[1] = tostring(#entries)

    local ep = entriesSigEntry
    for index, entry in ipairs(entries) do
        for k in pairs(ep) do ep[k] = nil end
        ep[1] = tostring(index)
        ep[2] = tostring(entry.kind or "")
        ep[3] = tostring(entry.label or "")
        ep[4] = tostring(entry.name or "")
        ep[5] = tostring(entry.itemID or 0)
        ep[6] = tostring(entry.icon or 0)
        ep[7] = tostring(entry.count or 0)
        ep[8] = tostring(entry.targetSlot or 0)
        ep[9] = entry.available and "1" or "0"
        ep[10] = tostring(entry.reason or "")
        ep[11] = type(entry.reapplyRemainingSeconds) == "number" and string.format("%.1f", entry.reapplyRemainingSeconds) or ""
        parts[#parts + 1] = table.concat(ep, "\31")
    end

    return table.concat(parts, "\30")
end

local dismissSigParts = {}
local dismissSigEntry = {}

local function BuildReminderDismissSignature(entries)
    local parts = dismissSigParts
    for k in pairs(parts) do parts[k] = nil end
    parts[1] = tostring(#entries)

    local ep = dismissSigEntry
    for index, entry in ipairs(entries) do
        for k in pairs(ep) do ep[k] = nil end
        ep[1] = tostring(index)
        ep[2] = tostring(entry.kind or "")
        ep[3] = tostring(entry.label or "")
        ep[4] = tostring(entry.itemID or 0)
        ep[5] = tostring(entry.spellID or 0)
        ep[6] = tostring(entry.targetSlot or 0)
        ep[7] = entry.available and "1" or "0"
        parts[#parts + 1] = table.concat(ep, "\31")
    end

    return table.concat(parts, "\30")
end

local appearanceSigParts = {}

local function BuildReminderAppearanceSignature(appearance, iconSize, spacing)
    local defaults = GetAppearanceDefaults()
    local glowColor = GetGlowColor(appearance)
    local p = appearanceSigParts
    for k in pairs(p) do p[k] = nil end

    p[1] = tostring(RoundBorderSize(appearance.borderSize, defaults.borderSize or 1) ~= 0)
    p[2] = tostring(iconSize or defaults.iconSize or 40)
    p[3] = tostring(spacing or defaults.spacing or 5)
    p[4] = string.format("%.3f", tonumber(appearance.iconZoom) or tonumber(defaults.iconZoom) or 0)
    p[5] = tostring(appearance.font or defaults.font or "frizqt")
    p[6] = tostring(appearance.fontOutline or defaults.fontOutline or "OUTLINE")
    p[7] = tostring(appearance.labelTextEnabled ~= false)
    p[8] = tostring(tonumber(appearance.labelFontSize) or tonumber(appearance.fontSize) or tonumber(defaults.labelFontSize) or tonumber(defaults.fontSize) or 12)
    p[9] = tostring(appearance.labelAnchor or defaults.labelAnchor or "bottom")
    p[10] = string.format("%.3f", tonumber(appearance.labelOffsetY) or tonumber(defaults.labelOffsetY) or 0)
    p[11] = tostring(appearance.durationTextEnabled ~= false)
    p[12] = tostring(tonumber(appearance.durationFontSize) or tonumber(appearance.fontSize) or tonumber(defaults.durationFontSize) or tonumber(defaults.fontSize) or 12)
    p[13] = tostring(appearance.durationAnchor or defaults.durationAnchor or "top")
    p[14] = string.format("%.3f", tonumber(appearance.durationOffsetY) or tonumber(defaults.durationOffsetY) or 0)
    p[15] = tostring(appearance.countTextEnabled ~= false)
    p[16] = tostring(tonumber(appearance.countFontSize) or tonumber(defaults.countFontSize) or 11)
    p[17] = tostring(appearance.countAnchor or defaults.countAnchor or "bottom_right")
    p[18] = string.format("%.3f", tonumber(appearance.countOffsetX) or tonumber(defaults.countOffsetX) or 0)
    p[19] = string.format("%.3f", tonumber(appearance.countOffsetY) or tonumber(defaults.countOffsetY) or 0)
    p[20] = tostring(appearance.glowMode or defaults.glowMode or "ready_check")
    p[21] = tostring(appearance.glowType or defaults.glowType or "proc")
    p[22] = string.format("%.3f", tonumber(appearance.glowFrequency) or tonumber(defaults.glowFrequency) or 0)
    p[23] = string.format("%.3f", tonumber(appearance.glowSize) or tonumber(defaults.glowSize) or 0)
    p[24] = tostring(tonumber(appearance.glowPixelLines) or tonumber(defaults.glowPixelLines) or 0)
    p[25] = tostring(tonumber(appearance.glowPixelLength) or tonumber(defaults.glowPixelLength) or 0)
    p[26] = string.format("%.3f", tonumber(appearance.glowPixelThickness) or tonumber(defaults.glowPixelThickness) or 0)
    p[27] = tostring(tonumber(appearance.glowAutocastParticles) or tonumber(defaults.glowAutocastParticles) or 0)
    p[28] = tostring(appearance.glowProcStartAnimation ~= false)
    p[29] = string.format("%.3f", glowColor[1] or 0)
    p[30] = string.format("%.3f", glowColor[2] or 0)
    p[31] = string.format("%.3f", glowColor[3] or 0)
    p[32] = string.format("%.3f", glowColor[4] or 0)
    p[33] = tostring(appearance.borderTexture or defaults.borderTexture or ns.GLOBAL_CHOICE_KEY)
    p[34] = tostring(RoundBorderSize(appearance.borderSize, defaults.borderSize or 1))
    local borderColor = NormalizeConsumableBorderColor(appearance.borderColor, defaults.borderColor)
    p[35] = string.format("%.3f", borderColor.r or 0)
    p[36] = string.format("%.3f", borderColor.g or 0)
    p[37] = string.format("%.3f", borderColor.b or 0)
    p[38] = string.format("%.3f", borderColor.a or 0)

    return table.concat(p, ":")
end

local renderSigParts = {}

local frameConfigSigParts = {}

local function BuildFrameConfigSignature(nonInteractivePreview, optionsPreviewActive)
    local config = GetConfig()
    local p = frameConfigSigParts
    for k in pairs(p) do p[k] = nil end

    p[1] = tostring(config.point or "CENTER")
    p[2] = tostring(config.x or 0)
    p[3] = tostring(config.y or 0)
    p[4] = string.format("%.3f", tonumber(config.scale) or 1)
    p[5] = tostring(config.strata or "HIGH")
    p[6] = nonInteractivePreview and "1" or "0"
    p[7] = optionsPreviewActive and "1" or "0"
    p[8] = ns.isEditMode and "1" or "0"

    return table.concat(p, ":")
end

local function BuildReminderRenderSignature(entries, appearance, iconSize, spacing, nonInteractivePreview, optionsPreviewActive)
    local p = renderSigParts
    for k in pairs(p) do p[k] = nil end
    p[1] = BuildReminderEntriesSignature(entries)
    p[2] = BuildReminderAppearanceSignature(appearance, iconSize, spacing)
    p[3] = nonInteractivePreview and "1" or "0"
    p[4] = optionsPreviewActive and "1" or "0"
    p[5] = ns.readyCheckActive and "1" or "0"
    p[6] = suppressGlowUntilRefresh and "1" or "0"
    return table.concat(p, "#")
end

function ns.RefreshUI()
    EnsureFrame()

    local moduleActive = IsConsumableModuleActive()
    UpdateConsumableEventRegistration(moduleActive)

    if not callbacksRegistered then
        RegisterEditModeCallbacks()
    end
    if not registeredWithLEM then
        RegisterWithEditMode()
    end

    if InCombatLockdown() then
        ns.pendingRefresh = true
        return
    end

    if not moduleActive then
        dismissedEntriesSignature = nil
        suppressGlowUntilRefresh = false
        lastAppearancePreviewState = nil
        StopAllButtonGlows()
        if reminderFrame then
            reminderFrame.closeButton:Hide()
            reminderFrame.nomtoolsRenderSignature = "disabled"
            reminderFrame:Hide()
        end
        for _, button in ipairs(buttons) do
            ClearButtonAttributes(button)
            button.entry = nil
            SetButtonGlowShown(button, false)
            SetButtonBorderShown(button, false)
            button:Hide()
        end
        return
    end

    local optionsPreviewActive = IsOptionsAppearancePreviewActive()
    local nonInteractivePreview = ns.isEditMode or optionsPreviewActive

    if lastAppearancePreviewState == nil then
        lastAppearancePreviewState = optionsPreviewActive
    elseif lastAppearancePreviewState ~= optionsPreviewActive then
        lastAppearancePreviewState = optionsPreviewActive
        suppressGlowUntilRefresh = true
        StopAllButtonGlows()
        QueueGlowContextRefresh()
    end

    local entries
    if optionsPreviewActive then
        entries = BuildPreviewEntries()
    else
        entries = ns.GetReminderEntries and ns.GetReminderEntries() or {}
        if ns.isEditMode and #entries == 0 then
            entries = BuildPreviewEntries()
        end
    end

    local dismissSignature = BuildReminderDismissSignature(entries)
    reminderFrame.nomtoolsDismissCandidateSignature = dismissSignature
    if dismissedEntriesSignature and dismissedEntriesSignature ~= dismissSignature then
        dismissedEntriesSignature = nil
    end

    if #entries == 0 and not nonInteractivePreview then
        dismissedEntriesSignature = nil
        reminderFrame.closeButton:Hide()
        if reminderFrame.nomtoolsRenderSignature == "hidden" and not reminderFrame:IsShown() then
            return
        end

        for _, button in ipairs(buttons) do
            ClearButtonAttributes(button)
            button.entry = nil
            SetButtonGlowShown(button, false)
            SetButtonBorderShown(button, false)
            button:Hide()
        end
        reminderFrame.nomtoolsRenderSignature = "hidden"
        reminderFrame:Hide()
        return
    end

    if not nonInteractivePreview and dismissedEntriesSignature == dismissSignature then
        reminderFrame.closeButton:Hide()
        reminderFrame.nomtoolsRenderSignature = "dismissed:" .. dismissSignature
        reminderFrame:Hide()
        return
    end

    EnsureReminderButtons(#entries)

    local appearance = GetAppearanceConfig()
    local iconSize = appearance.iconSize or GetAppearanceDefaults().iconSize
    local spacing = appearance.spacing or GetAppearanceDefaults().spacing

    local totalWidth
    local totalHeight

    if #entries > 0 then
        totalWidth = (PADDING_X * 2) + (#entries * iconSize) + ((#entries - 1) * spacing) + CLOSE_BUTTON_SIZE + CLOSE_BUTTON_PADDING
        totalHeight = iconSize + (PADDING_Y * 2)
    else
        totalWidth = EMPTY_WIDTH
        totalHeight = EMPTY_HEIGHT
    end

    local renderSignature = BuildReminderRenderSignature(entries, appearance, iconSize, spacing, nonInteractivePreview, optionsPreviewActive)
    local frameConfigSignature = BuildFrameConfigSignature(nonInteractivePreview, optionsPreviewActive)
    if reminderFrame.nomtoolsRenderSignature == renderSignature
        and reminderFrame.nomtoolsFrameConfigSignature == frameConfigSignature
        and reminderFrame:IsShown()
    then
        return
    end

    if ns.isEditMode then
        ApplyFrameVisualConfig()
    else
        ApplyFrameConfig()
    end

    reminderFrame:SetSize(totalWidth, totalHeight)
    reminderFrame.editModeLabel:SetText(optionsPreviewActive and "Options Preview" or EDIT_MODE_LABEL)
    reminderFrame.editModeLabel:SetShown(nonInteractivePreview and #entries == 0)
    reminderFrame.closeButton:SetShown((not nonInteractivePreview) and #entries > 0)
    reminderFrame.closeButton:ClearAllPoints()
    reminderFrame.closeButton:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", 2, 2)

    for index, button in ipairs(buttons) do
        local entry = entries[index]
        ClearButtonAttributes(button)
        button:ClearAllPoints()
        button.entry = entry

        if entry then
            button:SetSize(iconSize, iconSize)
            if index == 1 then
                button:SetPoint("TOPLEFT", reminderFrame, "TOPLEFT", PADDING_X, -PADDING_Y)
            else
                button:SetPoint("LEFT", buttons[index - 1], "RIGHT", spacing, 0)
            end

            button.icon:SetTexture(entry.icon or 134400)
            button.icon:SetDesaturated((not entry.available) and not nonInteractivePreview)
            button.icon:SetAlpha((entry.available or nonInteractivePreview) and 1 or 0.45)
            if appearance.labelTextEnabled ~= false then
                button.label:SetText(entry.label or "")
                button.label:Show()
            else
                button.label:SetText("")
                button.label:Hide()
            end

            if appearance.countTextEnabled ~= false and entry.count and entry.count > 1 then
                button.count:SetText(entry.count)
                button.count:Show()
            else
                button.count:SetText("")
                button.count:Hide()
            end

            if appearance.durationTextEnabled ~= false and entry.reapplyRemainingSeconds then
                button.duration:SetText(FormatReapplyRemaining(entry.reapplyRemainingSeconds))
                button.duration:Show()
            else
                button.duration:SetText("")
                button.duration:Hide()
            end

            ApplyButtonAppearance(button, entry, iconSize)
            LayoutButtonText(button, appearance)

            if entry.available and not nonInteractivePreview then
                if entry.itemID then
                    button:SetAttribute("type", "item")
                    button:SetAttribute("item", "item:" .. entry.itemID)
                    if entry.targetSlot then
                        button:SetAttribute("target-slot", entry.targetSlot)
                    end
                elseif entry.spellID then
                    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(entry.spellID)
                    button:SetAttribute("type", "spell")
                    button:SetAttribute("spell", (spellInfo and spellInfo.name) or entry.spellID)
                end
            end

            button:Show()
        else
            button.entry = nil
            SetButtonGlowShown(button, false)
            SetButtonBorderShown(button, false)
            button.duration:SetText("")
            button.duration:Hide()
            button:Hide()
        end
    end

    reminderFrame.nomtoolsRenderSignature = renderSignature
    reminderFrame.nomtoolsFrameConfigSignature = frameConfigSignature
    reminderFrame:Show()
end