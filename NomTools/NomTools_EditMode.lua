local addonName, ns = ...

local LEM = LibStub and LibStub("LibEditMode", true)
local callbacksRegistered = false
local registeredFrames = {}
local EDIT_MODE_REFRESH_MODULES = {
    "consumables",
    "menuBar",
    "dungeonDifficulty",
    "greatVault",
    "characterStats",
    "classesMonk",
    "objectiveTracker",
}

local LEGACY_POSITION_FLAGS_KEY = "_editModeLegacyPositions"

local function RoundNearest(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

local function CopyTableRecursive(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CopyTableRecursive(value)
    end
    return copy
end

local function GetResolvedLayoutName(layoutName)
    if ns.GetEditModeLayoutName then
        return ns.GetEditModeLayoutName(layoutName)
    end

    return layoutName
end

local function ApplyRegisteredFrameLayouts(layoutName)
    local resolvedLayoutName = GetResolvedLayoutName(layoutName)
    for _, registration in pairs(registeredFrames) do
        if registration and registration.applyLayout then
            registration.applyLayout(resolvedLayoutName, ns.isEditMode == true)
        end
    end
end

function ns.EnsureBlizzardEditModeLoaded()
    if EditModeManagerFrame and EditModeSystemSettingsDialog then
        return true
    end

    local loader = (C_AddOns and C_AddOns.LoadAddOn) or UIParentLoadAddOn
    if loader then
        pcall(loader, "Blizzard_EditMode")
    end

    LEM = LEM or (LibStub and LibStub("LibEditMode", true))
    return EditModeManagerFrame ~= nil and EditModeSystemSettingsDialog ~= nil
end

function ns.GetEditModeLib()
    LEM = LEM or (LibStub and LibStub("LibEditMode", true))
    return LEM
end

function ns.GetEditModeSelection(frame)
    local lib = ns.GetEditModeLib()
    if not lib or not lib.frameSelections then
        return nil
    end

    return lib.frameSelections[frame]
end

function ns.AttachEditModeSelectionProxy(frame)
    if not frame or frame.nomToolsEditModeProxyAttached then
        return
    end

    frame.nomToolsEditModeProxyAttached = true

    if frame.RegisterForDrag then
        frame:RegisterForDrag("LeftButton")
    end

    frame:HookScript("OnMouseDown", function(self, button)
        if not ns.isEditMode or button ~= "LeftButton" then
            return
        end

        local selection = ns.GetEditModeSelection(self)
        local onMouseDown = selection and selection:GetScript("OnMouseDown") or nil
        if onMouseDown then
            onMouseDown(selection)
        end
    end)

    frame:HookScript("OnDragStart", function(self)
        if not ns.isEditMode then
            return
        end

        local selection = ns.GetEditModeSelection(self)
        if not selection then
            return
        end

        local onMouseDown = selection:GetScript("OnMouseDown")
        if onMouseDown then
            onMouseDown(selection)
        end

        local onDragStart = selection:GetScript("OnDragStart")
        if onDragStart then
            onDragStart(selection)
        end
    end)

    frame:HookScript("OnDragStop", function(self)
        if not ns.isEditMode then
            return
        end

        local selection = ns.GetEditModeSelection(self)
        local onDragStop = selection and selection:GetScript("OnDragStop") or nil
        if onDragStop then
            onDragStop(selection)
        end
    end)
end

function ns.GetAbsoluteFramePositionDefaults(frame, fallback)
    local defaults = CopyTableRecursive(fallback or {
        point = "CENTER",
        x = 0,
        y = 0,
    })

    if not frame or not frame.GetCenter or not UIParent or not UIParent.GetCenter then
        return defaults
    end

    local frameCenterX, frameCenterY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not frameCenterX or not frameCenterY or not parentCenterX or not parentCenterY or scale == 0 then
        return defaults
    end

    defaults.point = "CENTER"
    defaults.x = RoundNearest((frameCenterX - parentCenterX) / scale)
    defaults.y = RoundNearest((frameCenterY - parentCenterY) / scale)
    return defaults
end

local function GetLegacyPositionFlags()
    if not ns.db then
        return nil
    end

    if type(ns.db[LEGACY_POSITION_FLAGS_KEY]) ~= "table" then
        ns.db[LEGACY_POSITION_FLAGS_KEY] = {}
    end

    return ns.db[LEGACY_POSITION_FLAGS_KEY]
end

function ns.ShouldMigrateLegacyEditModePosition(configKey)
    if not configKey then
        return false
    end

    local flags = GetLegacyPositionFlags()
    if not flags then
        return false
    end

    return flags[configKey] ~= true
end

function ns.MarkLegacyEditModePositionMigrated(configKey)
    local flags = GetLegacyPositionFlags()
    if flags and configKey then
        flags[configKey] = true
    end
end

function ns.MigrateLegacyEditModePosition(configKey, frame, defaults, layoutName)
    local config = ns.GetEditModeConfig and ns.GetEditModeConfig(configKey, defaults or {}, layoutName) or CopyTableRecursive(defaults or {})
    if not configKey or not ns.ShouldMigrateLegacyEditModePosition(configKey) then
        return config
    end

    local resolved = ns.GetAbsoluteFramePositionDefaults(frame, defaults)
    config.point = resolved.point
    config.x = resolved.x
    config.y = resolved.y
    ns.MarkLegacyEditModePositionMigrated(configKey)
    return config
end

local function EnsurePlaceholder(frame)
    if not frame or frame.nomToolsEditModePlaceholder then
        return frame and frame.nomToolsEditModePlaceholder or nil
    end

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    overlay:SetFrameStrata(frame:GetFrameStrata() or "DIALOG")
    overlay:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    overlay:EnableMouse(false)
    overlay:Hide()

    local background = overlay:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.35)
    overlay.background = background

    local borderColor = { r = 0.40, g = 0.75, b = 0.95, a = 1 }
    local function CreateBorder(name)
        local texture = overlay:CreateTexture(nil, "BORDER")
        texture:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
        overlay[name] = texture
        return texture
    end

    local topBorder = CreateBorder("topBorder")
    topBorder:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
    topBorder:SetHeight(2)

    local bottomBorder = CreateBorder("bottomBorder")
    bottomBorder:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetHeight(2)

    local leftBorder = CreateBorder("leftBorder")
    leftBorder:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, -2)
    leftBorder:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 2)
    leftBorder:SetWidth(2)

    local rightBorder = CreateBorder("rightBorder")
    rightBorder:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, -2)
    rightBorder:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 2)
    rightBorder:SetWidth(2)

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    label:SetTextColor(0.92, 0.92, 0.92)
    overlay.label = label

    frame.nomToolsEditModePlaceholder = overlay
    return overlay
end

function ns.ShowEditModePlaceholder(frame, labelText, width, height)
    if not frame then
        return
    end

    if width and height and (
        math.abs((frame:GetWidth() or 0) - width) > 0.01
        or math.abs((frame:GetHeight() or 0) - height) > 0.01
    ) then
        frame:SetSize(width, height)
    end

    local overlay = EnsurePlaceholder(frame)
    if not overlay then
        return
    end

    overlay.label:SetText(labelText or frame.editModeName or addonName)
    overlay:Show()
    frame:Show()
end

function ns.HideEditModePlaceholder(frame)
    if frame and frame.nomToolsEditModePlaceholder then
        frame.nomToolsEditModePlaceholder:Hide()
    end
end

function ns.InitializeEditModeSystem()
    local lib = ns.GetEditModeLib()
    if callbacksRegistered then
        return true
    end

    if not lib or not ns.EnsureBlizzardEditModeLoaded() then
        return false
    end

    callbacksRegistered = true
    ns.editModeLib = lib

    lib:RegisterCallback("enter", function()
        ns.isEditMode = true
        local activeLayoutName = lib.GetActiveLayoutName and lib:GetActiveLayoutName() or nil
        ns.activeLayoutName = GetResolvedLayoutName(activeLayoutName)
        ApplyRegisteredFrameLayouts(ns.activeLayoutName)
        if ns.RequestRefresh then
            ns.RequestRefresh(EDIT_MODE_REFRESH_MODULES)
        end
    end)

    lib:RegisterCallback("exit", function()
        ns.isEditMode = false
        ApplyRegisteredFrameLayouts(ns.activeLayoutName)
        if ns.RequestRefresh then
            ns.RequestRefresh(EDIT_MODE_REFRESH_MODULES)
        end
    end)

    lib:RegisterCallback("layout", function(layoutName)
        ns.activeLayoutName = GetResolvedLayoutName(layoutName)
        ApplyRegisteredFrameLayouts(ns.activeLayoutName)
        if ns.RequestRefresh then
            ns.RequestRefresh(EDIT_MODE_REFRESH_MODULES)
        end
    end)

    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        ns.isEditMode = true
    end

    local initialLayoutName = lib.GetActiveLayoutName and lib:GetActiveLayoutName() or nil
    ns.activeLayoutName = GetResolvedLayoutName(initialLayoutName)

    ApplyRegisteredFrameLayouts(ns.activeLayoutName)
    return true
end

function ns.RegisterEditModeFrame(frame, options)
    local lib = ns.GetEditModeLib()
    if not frame or not options or registeredFrames[frame] or not lib then
        return false
    end

    if not ns.InitializeEditModeSystem() then
        return false
    end

    local defaults = CopyTableRecursive(options.defaults or ns.GetAbsoluteFramePositionDefaults(frame, {
        point = "CENTER",
        x = 0,
        y = 0,
    }))

    lib:AddFrame(frame, function(_, layoutName, point, x, y)
        if options.onPositionChanged then
            options.onPositionChanged(layoutName, point, x, y)
        end
    end, {
        point = defaults.point,
        x = defaults.x,
        y = defaults.y,
    }, options.label or frame.editModeName or frame:GetName() or addonName)

    if type(options.settings) == "table" and #options.settings > 0 then
        lib:AddFrameSettings(frame, options.settings)
    end

    if type(options.buttons) == "table" and #options.buttons > 0 then
        lib:AddFrameSettingsButtons(frame, options.buttons)
    end

    registeredFrames[frame] = {
        applyLayout = options.applyLayout,
    }

    if options.applyLayout then
        options.applyLayout(ns.activeLayoutName, ns.isEditMode == true)
    end

    if lib.isEditing and lib.frameSelections and lib.frameSelections[frame] then
        lib.frameSelections[frame]:Show()
        lib.frameSelections[frame]:ShowHighlighted()
    end

    return true
end
