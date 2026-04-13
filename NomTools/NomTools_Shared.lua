local _, ns = ...

local DEFAULT_EDIT_MODE_LAYOUT = "_Global"
local resolvedCharacterKey
local resolvedCharacterName
local DEFAULT_PANEL_VIGNETTE_LEFT_TEX_COORD = 0.2404

local function EnsureDefaultPanelVignette(frame)
    if not frame then
        return nil
    end

    if frame.nomtoolsDefaultPanelVignette then
        return frame.nomtoolsDefaultPanelVignette
    end

    local vignette = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    vignette:SetAtlas("Options_InnerFrame", false)
    vignette:SetTexCoord(DEFAULT_PANEL_VIGNETTE_LEFT_TEX_COORD, 1, 0, 1)
    vignette:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    vignette:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    frame.nomtoolsDefaultPanelVignette = vignette
    return frame.nomtoolsDefaultPanelVignette
end

ns.DEFAULT_EDIT_MODE_LAYOUT = DEFAULT_EDIT_MODE_LAYOUT

function ns.CopyDefaults(target, defaults)
    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ns.CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns.CopyTableRecursive(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = ns.CopyTableRecursive(value)
    end
    return copy
end

function ns.CopyMissingTableValues(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = ns.CopyTableRecursive(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            ns.CopyMissingTableValues(target[key], value)
        end
    end
end

local function GetCurrentCharacterKey()
    local name
    local realm

    if UnitFullName then
        name, realm = UnitFullName("player")
    end

    if type(name) ~= "string" or name == "" then
        name = UnitName and UnitName("player") or nil
    end

    if type(name) ~= "string" or name == "" then
        return nil
    end

    if type(resolvedCharacterKey) == "string" and resolvedCharacterKey ~= "" and resolvedCharacterName == name then
        return resolvedCharacterKey, name
    end

    if type(realm) ~= "string" or realm == "" then
        if GetNormalizedRealmName then
            realm = GetNormalizedRealmName()
        elseif GetRealmName then
            realm = GetRealmName()
        end
    end

    if type(realm) == "string" and realm ~= "" then
        resolvedCharacterName = name
        resolvedCharacterKey = name .. "-" .. realm
        return resolvedCharacterKey, name
    end

    return nil, name
end

function ns.EnsureCharacterRoot()
    if not ns.db then
        return nil
    end

    if type(ns.db.characters) ~= "table" then
        ns.db.characters = {}
    end

    local characterKey, legacyCharacterKey = GetCurrentCharacterKey()
    if not characterKey then
        return nil
    end

    if type(ns.db.characters[characterKey]) ~= "table" then
        ns.db.characters[characterKey] = {}
    end

    if legacyCharacterKey and legacyCharacterKey ~= characterKey and type(ns.db.characters[legacyCharacterKey]) == "table" then
        ns.CopyMissingTableValues(ns.db.characters[characterKey], ns.db.characters[legacyCharacterKey])
    end

    return ns.db.characters[characterKey], characterKey
end

function ns.EnsureEditModeRoot()
    ns.db.editMode = ns.db.editMode or {}
    ns.db.editMode.layouts = ns.db.editMode.layouts or {}
    return ns.db.editMode, ns.db.editMode.layouts
end

function ns.GetEditModeLayoutName(layoutName)
    if type(layoutName) == "string" and layoutName ~= "" then
        return layoutName
    end

    if ns.activeLayoutName and ns.activeLayoutName ~= "" then
        return ns.activeLayoutName
    end

    if ns.editModeLib and ns.editModeLib.GetActiveLayoutName then
        local activeLayoutName = ns.editModeLib:GetActiveLayoutName()
        if type(activeLayoutName) == "string" and activeLayoutName ~= "" then
            return activeLayoutName
        end
    end

    if C_EditMode and C_EditMode.GetLayouts then
        local info = C_EditMode.GetLayouts()
        if info and type(info.activeLayout) == "number" then
            local idx = info.activeLayout
            if idx == 1 then return "Modern" end
            if idx == 2 then return "Classic" end
            if type(info.layouts) == "table" and info.layouts[idx - 2] then
                return info.layouts[idx - 2].layoutName
            end
        end
    end

    return DEFAULT_EDIT_MODE_LAYOUT
end

function ns.GetEditModeConfig(configKey, defaults, layoutName)
    if not ns.db then
        return defaults or {}
    end

    local resolvedLayoutName = ns.GetEditModeLayoutName(layoutName)
    local _, layouts = ns.EnsureEditModeRoot()

    if type(layouts[resolvedLayoutName]) ~= "table" then
        layouts[resolvedLayoutName] = {}
    end

    if type(layouts[resolvedLayoutName][configKey]) ~= "table" then
        local fallbackLayout = layouts[DEFAULT_EDIT_MODE_LAYOUT]
        if resolvedLayoutName ~= DEFAULT_EDIT_MODE_LAYOUT
            and type(fallbackLayout) == "table"
            and type(fallbackLayout[configKey]) == "table"
        then
            layouts[resolvedLayoutName][configKey] = ns.CopyTableRecursive(fallbackLayout[configKey])
        else
            layouts[resolvedLayoutName][configKey] = {}
        end
    end

    local config = layouts[resolvedLayoutName][configKey]
    for key, value in pairs(defaults or {}) do
        if config[key] == nil then
            config[key] = ns.CopyTableRecursive(value)
        end
    end

    return config
end

function ns.ApplyDefaultPanelChrome(frame, options)
    if not frame then
        return
    end

    local vignette = EnsureDefaultPanelVignette(frame)
    if vignette then
        vignette:Show()
    end
end

function ns.SetDefaultPanelChromeShown(frame, shown, options)
    if not frame then
        return
    end

    local vignette = EnsureDefaultPanelVignette(frame)
    if vignette then
        vignette:SetShown(shown)
    end
end